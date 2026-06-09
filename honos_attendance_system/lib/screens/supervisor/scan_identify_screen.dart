import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../models/attendance.dart';
import '../../models/guard.dart';
import '../../models/site.dart';
import '../../services/auth_service.dart';
import '../../services/camera_service.dart';
import '../../services/db_service.dart';
import '../../services/face_match_service.dart';
import '../../services/mobile_attendance_guard.dart';
import '../../services/permission_service.dart';
import '../../widgets/base64_image_widget.dart';
import 'liveness_detector_widget.dart';
import 'take_attendance_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Security constants — NEVER lower these without explicit admin approval
// ─────────────────────────────────────────────────────────────────────────────
const double _kConfidenceThreshold = 0.82;
const int _kCountdownSeconds = 15;
const int _kMaxAttemptsBeforeFallback = 2;

// ─────────────────────────────────────────────────────────────────────────────
// State machine
// ─────────────────────────────────────────────────────────────────────────────
enum _ScanState {
  gpsCheck,      // Verifying GPS & permissions
  liveness,      // Liveness / anti-spoofing gate
  scanning,      // Camera live — auto-capture on face detected
  matching,      // 1:N computation running
  notRecognized, // Score < threshold or no face
  confirming,    // Match found — awaiting guard confirmation
  submitting,    // Writing Firestore record
  success,       // Done — redirect imminent
}

// ─────────────────────────────────────────────────────────────────────────────
// Match result
// ─────────────────────────────────────────────────────────────────────────────
class _MatchResult {
  final Guard? guard;
  final double score;
  final bool recognized;
  final bool hadFace;

  const _MatchResult._({
    required this.guard,
    required this.score,
    required this.recognized,
    required this.hadFace,
  });

  factory _MatchResult.matched(Guard guard, double score) =>
      _MatchResult._(guard: guard, score: score, recognized: true, hadFace: true);

  factory _MatchResult.notRecognized(double score) =>
      _MatchResult._(guard: null, score: score, recognized: false, hadFace: true);

  factory _MatchResult.noFace() =>
      _MatchResult._(guard: null, score: 0, recognized: false, hadFace: false);
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen widget
// ─────────────────────────────────────────────────────────────────────────────
class ScanIdentifyScreen extends ConsumerStatefulWidget {
  final Site site;
  final bool isCheckOutFlow;

  const ScanIdentifyScreen({
    super.key,
    required this.site,
    this.isCheckOutFlow = false,
  });

  @override
  ConsumerState<ScanIdentifyScreen> createState() => _ScanIdentifyScreenState();
}

class _ScanIdentifyScreenState extends ConsumerState<ScanIdentifyScreen>
    with TickerProviderStateMixin {

  // ── Core state ─────────────────────────────────────────────────────────────
  _ScanState _state = _ScanState.gpsCheck;
  bool _gpsChecking = true;
  String _gpsError = '';
  int _scanAttempts = 0;
  String _errorMessage = '';
  double _lastBestScore = 0.0;

  // ── Matched data ───────────────────────────────────────────────────────────
  Guard? _matchedGuard;
  Attendance? _existingCheckInRecord;
  String _livePhotoBase64 = '';

  // ── Camera ────────────────────────────────────────────────────────────────
  CameraController? _ctrl;
  bool _cameraReady = false;
  bool _isCapturing = false;

  // ── Face detection stream ─────────────────────────────────────────────────
  bool _faceDetected = false;
  bool _processingFrame = false;
  DateTime _lastFrameTime = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _autoCapTimer;
  bool _autoCapturing = false;

  final FaceDetector _streamDetector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.fast,
      enableClassification: false,
      enableContours: false,
      enableLandmarks: false,
    ),
  );

  // ── Embedding cache (guard.id → embedding vector) ─────────────────────────
  final Map<String, List<double>> _embeddingCache = {};
  bool _embeddingsReady = false;

  // ── Countdown ─────────────────────────────────────────────────────────────
  Timer? _countdownTimer;
  int _countdownRemaining = _kCountdownSeconds;
  late AnimationController _countdownAnim;
  late AnimationController _pulseAnim;

  @override
  void initState() {
    super.initState();
    _countdownAnim = AnimationController(
      vsync: this,
      duration: Duration(seconds: _kCountdownSeconds),
    );
    _pulseAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) => _checkGps());
  }

  @override
  void dispose() {
    _autoCapTimer?.cancel();
    _countdownTimer?.cancel();
    _countdownAnim.dispose();
    _pulseAnim.dispose();
    _ctrl?.dispose();
    _streamDetector.close();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Step 1 — GPS & Permission check
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _checkGps() async {
    if (!isMobileAttendanceDevice) {
      if (mounted) Navigator.pop(context);
      return;
    }
    setState(() {
      _gpsChecking = true;
      _gpsError = '';
      _state = _ScanState.gpsCheck;
    });

    try {
      final gpsEnabled = await PermissionService.isGpsEnabled();
      if (!gpsEnabled) throw Exception('GPS is disabled. Please enable it.');

      final hasPerms = await PermissionService.requestSupervisorPermissions();
      if (!hasPerms) throw Exception('Location and Camera permissions are required.');

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 10));

      if (pos.isMocked) throw Exception('Mock location detected. Disable Fake GPS apps.');

      final dist = Geolocator.distanceBetween(
        pos.latitude, pos.longitude, widget.site.lat, widget.site.lng,
      );
      if (dist > widget.site.radius) {
        throw Exception(
          'You are ${dist.toInt()}m from site. Required: within ${widget.site.radius.toInt()}m.',
        );
      }

      // GPS verified — start precomputing guard embeddings in the background
      // so they are ready by the time liveness check completes.
      _precomputeEmbeddings();

      if (mounted) {
        setState(() {
          _gpsChecking = false;
          _state = _ScanState.liveness;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _gpsChecking = false; _gpsError = e.toString(); });
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Background: precompute all active guard face embeddings
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _precomputeEmbeddings() async {
    try {
      await FaceMatchService.init();
      final guards = ref.read(guardsStreamProvider).value ?? [];
      final tempDir = await getTemporaryDirectory();

      for (final guard in guards) {
        if (!mounted) return;
        if (guard.status != 'active') continue;
        if (guard.photo.length < 200) continue;
        if (_embeddingCache.containsKey(guard.id)) continue;

        try {
          final refBytes = base64Decode(guard.photo);
          final refFile = File(p.join(tempDir.path, 'emb_${guard.id}.jpg'));
          await refFile.writeAsBytes(refBytes);
          final embedding = await FaceMatchService.getEmbeddings(refFile);
          if (embedding != null) _embeddingCache[guard.id] = embedding;
        } catch (_) {
          // Skip guards with bad photos — they simply won't appear as candidates
        }
      }
      if (mounted) setState(() => _embeddingsReady = true);
    } catch (e) {
      debugPrint('ScanIdentify: embedding precompute error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Step 2 → 3: Liveness confirmed, open scan camera
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _onLivenessPassed() async {
    setState(() {
      _state = _ScanState.scanning;
      _cameraReady = false;
      _faceDetected = false;
      _autoCapturing = false;
    });
    await _initScanCamera();
  }

  Future<void> _initScanCamera() async {
    // Wait for the liveness camera to fully release hardware resource
    await Future.delayed(const Duration(milliseconds: 800));

    if (globalCameras.isEmpty) await initCameras();
    if (globalCameras.isEmpty) return;

    final camera = globalCameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => globalCameras.first,
    );
    _ctrl = CameraController(camera, ResolutionPreset.medium, enableAudio: false);

    try {
      await _ctrl!.initialize();
      if (!mounted) return;
      setState(() => _cameraReady = true);
      _startFaceDetectionStream();
    } catch (e) {
      if (mounted) {
        setState(() {
          _state = _ScanState.notRecognized;
          _errorMessage = 'Camera error: $e';
          _scanAttempts++;
        });
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Live face detection via image stream (for UI feedback + auto-capture)
  // ─────────────────────────────────────────────────────────────────────────
  void _startFaceDetectionStream() {
    if (_ctrl == null || !_ctrl!.value.isInitialized) return;
    _ctrl!.startImageStream((CameraImage image) async {
      if (_processingFrame || _isCapturing || _state != _ScanState.scanning) return;
      final now = DateTime.now();
      if (now.difference(_lastFrameTime) < const Duration(milliseconds: 600)) return;
      _lastFrameTime = now;
      _processingFrame = true;

      try {
        final inputImage = _toInputImage(image);
        if (inputImage == null) return;
        final faces = await _streamDetector.processImage(inputImage);
        final detected = faces.isNotEmpty;

        if (!mounted || _state != _ScanState.scanning) return;
        setState(() => _faceDetected = detected);

        if (detected && !_autoCapturing) {
          _scheduleAutoCapture();
        } else if (!detected) {
          _autoCapTimer?.cancel();
          _autoCapturing = false;
        }
      } finally {
        _processingFrame = false;
      }
    });
  }

  /// Schedule auto-capture 2 seconds after a stable face is detected
  void _scheduleAutoCapture() {
    _autoCapturing = true;
    _autoCapTimer?.cancel();
    _autoCapTimer = Timer(const Duration(seconds: 2), () {
      if (mounted && _state == _ScanState.scanning && _faceDetected && !_isCapturing) {
        _capture();
      } else {
        _autoCapturing = false;
      }
    });
  }

  InputImage? _toInputImage(CameraImage image) {
    try {
      final camera = globalCameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => globalCameras.first,
      );
      InputImageRotation rotation;
      if (Platform.isIOS) {
        rotation = InputImageRotationValue.fromRawValue(camera.sensorOrientation) ??
            InputImageRotation.rotation0deg;
      } else {
        final orientMap = <DeviceOrientation, int>{
          DeviceOrientation.portraitUp: 0,
          DeviceOrientation.landscapeLeft: 90,
          DeviceOrientation.portraitDown: 180,
          DeviceOrientation.landscapeRight: 270,
        };
        final comp = (camera.sensorOrientation +
                (orientMap[_ctrl!.value.deviceOrientation] ?? 0)) %
            360;
        rotation = InputImageRotationValue.fromRawValue(comp) ??
            InputImageRotation.rotation0deg;
      }
      final format = InputImageFormatValue.fromRawValue(image.format.raw);
      if (format == null) return null;
      final plane = image.planes.first;
      return InputImage.fromBytes(
        bytes: plane.bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: format,
          bytesPerRow: plane.bytesPerRow,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Capture + 1:N identification
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _capture() async {
    if (_isCapturing || _ctrl == null || !_cameraReady) return;
    setState(() { _isCapturing = true; _autoCapturing = false; });
    _autoCapTimer?.cancel();

    try {
      try { await _ctrl!.stopImageStream(); } catch (_) {}

      final xFile = await _ctrl!.takePicture();
      final bytes = await xFile.readAsBytes();
      _livePhotoBase64 = base64Encode(bytes);

      await _ctrl?.dispose();
      _ctrl = null;

      if (mounted) setState(() => _state = _ScanState.matching);

      final result = await _runIdentification(File(xFile.path));
      if (!mounted) return;

      if (result.recognized && result.guard != null) {
        await _handlePositiveMatch(result.guard!, result.score);
      } else {
        _scanAttempts++;
        setState(() {
          _state = _ScanState.notRecognized;
          _lastBestScore = result.score;
          _errorMessage = result.hadFace
              ? 'Face not recognized. Please ensure good lighting and try again.'
              : 'No face detected. Please position your face within the frame.';
        });
      }
    } catch (e) {
      _scanAttempts++;
      if (mounted) {
        setState(() {
          _state = _ScanState.notRecognized;
          _errorMessage = 'Scan error. Please try again.';
        });
        debugPrint('ScanIdentify: capture error: $e');
      }
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  /// 1:N cosine similarity search against all cached guard embeddings
  Future<_MatchResult> _runIdentification(File livePhoto) async {
    final liveEmbedding = await FaceMatchService.getEmbeddings(livePhoto);
    if (liveEmbedding == null) return _MatchResult.noFace();

    final guards = ref.read(guardsStreamProvider).value ?? [];
    Guard? bestGuard;
    double bestScore = 0.0;

    for (final guard in guards) {
      if (guard.status != 'active') continue;
      final cachedEmb = _embeddingCache[guard.id];
      if (cachedEmb == null) continue;

      final score = FaceMatchService.compareFaces(cachedEmb, liveEmbedding);
      if (score > bestScore) {
        bestScore = score;
        bestGuard = guard;
      }
    }

    debugPrint(
      'ScanIdentify[1:N]: best=${(bestScore * 100).toStringAsFixed(1)}% '
      'guard=${bestGuard?.name ?? "none"} '
      'pool=${_embeddingCache.length}',
    );

    if (bestScore >= _kConfidenceThreshold && bestGuard != null) {
      return _MatchResult.matched(bestGuard, bestScore);
    }
    return _MatchResult.notRecognized(bestScore);
  }

  /// After a confident match, validate check-in/out state then show confirmation
  Future<void> _handlePositiveMatch(Guard guard, double score) async {
    if (widget.isCheckOutFlow) {
      // Guard must have a pending check-in today to be eligible for check-out
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final snap = await FirebaseFirestore.instance
          .collection('attendance')
          .where('guardId', isEqualTo: guard.id)
          .where('date', isEqualTo: today)
          .get();

      final openRecord = snap.docs
          .map((d) => Attendance.fromJson(d.data()))
          .where((r) => r.status == 'present' && r.checkOutTime.isEmpty)
          .lastOrNull;

      if (openRecord == null) {
        _scanAttempts++;
        if (mounted) {
          setState(() {
            _state = _ScanState.notRecognized;
            _errorMessage = '${guard.name} has not checked in today. Cannot check out.';
            _lastBestScore = score;
          });
        }
        return;
      }
      _existingCheckInRecord = openRecord;
    }

    _matchedGuard = guard;
    if (mounted) {
      setState(() {
        _state = _ScanState.confirming;
        _countdownRemaining = _kCountdownSeconds;
      });
      _countdownAnim.forward(from: 0);
      _startCountdown();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Countdown timer
  // ─────────────────────────────────────────────────────────────────────────
  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      final next = _countdownRemaining - 1;
      setState(() => _countdownRemaining = next);
      if (next <= 0) {
        t.cancel();
        _submitAttendance();
      }
    });
  }

  void _stopCountdown() {
    _countdownTimer?.cancel();
    _countdownAnim.stop();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Submit attendance (atomic Firestore write via DbService)
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _submitAttendance() async {
    if (_state == _ScanState.submitting || _state == _ScanState.success) return;
    _stopCountdown();
    if (mounted) setState(() => _state = _ScanState.submitting);

    try {
      final db = ref.read(dbProvider);
      final supervisor = ref.read(authProvider);
      final now = DateTime.now();

      if (widget.isCheckOutFlow && _existingCheckInRecord != null) {
        final updated = Attendance(
          id: _existingCheckInRecord!.id,
          guardId: _existingCheckInRecord!.guardId,
          siteId: _existingCheckInRecord!.siteId,
          date: _existingCheckInRecord!.date,
          time: _existingCheckInRecord!.time,
          status: 'present',
          supervisorId: _existingCheckInRecord!.supervisorId,
          photoPath: _existingCheckInRecord!.photoPath,
          markedAt: _existingCheckInRecord!.markedAt,
          lat: _existingCheckInRecord!.lat,
          lng: _existingCheckInRecord!.lng,
          checkOutTime: DateFormat('HH:mm').format(now),
          checkOutPhotoPath: _livePhotoBase64,
        );
        await db.saveAttendance(updated);
      } else {
        final record = Attendance(
          id: now.millisecondsSinceEpoch.toString(),
          guardId: _matchedGuard!.id,
          siteId: widget.site.id,
          date: DateFormat('yyyy-MM-dd').format(now),
          time: DateFormat('HH:mm').format(now),
          status: 'present',
          supervisorId: supervisor?.id ?? '',
          photoPath: _livePhotoBase64,
          markedAt: now.toIso8601String(),
          lat: widget.site.lat,
          lng: widget.site.lng,
        );
        await db.saveAttendance(record);
      }

      if (mounted) setState(() => _state = _ScanState.success);

      // Auto-redirect to dashboard after showing success screen
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to save attendance: $e'),
          backgroundColor: Colors.red,
        ));
        setState(() {
          _state = _ScanState.notRecognized;
          _errorMessage = 'Save failed. Please retry.';
        });
      }
    }
  }

  /// "Not Me" or cancel — wipe session, return to dashboard
  void _cancelSession() {
    _stopCountdown();
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  /// Retry scan (reopen camera)
  Future<void> _retry() async {
    setState(() {
      _errorMessage = '';
      _faceDetected = false;
      _autoCapturing = false;
      _cameraReady = false;
      _state = _ScanState.scanning;
    });
    await _initScanCamera();
  }

  /// Manual guard selection fallback (only available after 2+ failed scans).
  /// Still requires 1:1 face verification — NOT a bypass.
  void _goToManualFallback() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => TakeAttendanceScreen(
          site: widget.site,
          isCheckOutFlow: widget.isCheckOutFlow,
          skipGpsCheck: true, // GPS already verified by this screen
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(child: _buildState()),
    );
  }

  Widget _buildState() {
    switch (_state) {
      case _ScanState.gpsCheck:
        return _buildGpsView();
      case _ScanState.liveness:
        return _buildLivenessView();
      case _ScanState.scanning:
        return _buildScanView();
      case _ScanState.matching:
        return _buildMatchingView();
      case _ScanState.notRecognized:
        return _buildNotRecognizedView();
      case _ScanState.confirming:
        return _buildConfirmationView();
      case _ScanState.submitting:
        return _buildSubmittingView();
      case _ScanState.success:
        return _buildSuccessView();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // GPS view
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildGpsView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_gpsChecking) ...[
              const SizedBox(
                width: 80,
                height: 80,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Verifying Location...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.site.name,
                style: const TextStyle(color: Colors.white54, fontSize: 14),
              ),
            ] else if (_gpsError.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.location_off, color: Colors.red, size: 64),
              ),
              const SizedBox(height: 24),
              const Text(
                'Location Error',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _gpsError,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white60, fontSize: 14),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _cancelSession,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white54,
                        side: const BorderSide(color: Colors.white24),
                        minimumSize: const Size(double.infinity, 52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _checkGps,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        minimumSize: const Size(double.infinity, 52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Liveness view (anti-spoofing gate)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildLivenessView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Row(
            children: [
              IconButton(
                onPressed: _cancelSession,
                icon: const Icon(Icons.arrow_back, color: Colors.white),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.isCheckOutFlow ? 'Face Scan — Check Out' : 'Face Scan — Check In',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    widget.site.name,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _embeddingsReady ? Icons.check_circle : Icons.hourglass_top,
                  color: _embeddingsReady ? Colors.greenAccent : Colors.amber,
                  size: 14,
                ),
                const SizedBox(width: 8),
                Text(
                  _embeddingsReady
                      ? 'Guard database ready (${_embeddingCache.length} profiles)'
                      : 'Preparing guard database...',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          LivenessDetectorWidget(onBlinkDetected: _onLivenessPassed),
          const SizedBox(height: 16),
          const Text(
            'Step 1 of 2: Confirm you are a real person',
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Scan camera view with face detection ring
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildScanView() {
    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          child: Row(
            children: [
              IconButton(
                onPressed: _cancelSession,
                icon: const Icon(Icons.close, color: Colors.white),
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    widget.isCheckOutFlow ? 'Check Out Scan' : 'Check In Scan',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    widget.site.name,
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),

        const Spacer(),

        // Camera preview with animated face oval
        Stack(
          alignment: Alignment.center,
          children: [
            if (_cameraReady && _ctrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: SizedBox(
                  width: 300,
                  height: 380,
                  child: CameraPreview(_ctrl!),
                ),
              )
            else
              Container(
                width: 300,
                height: 380,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),

            // Face detection ring — green when face detected
            AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, __) {
                final opacity = _faceDetected
                    ? 0.6 + (_pulseAnim.value * 0.4)
                    : 0.3;
                return Container(
                  width: 300,
                  height: 380,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: (_faceDetected ? Colors.greenAccent : Colors.white)
                          .withValues(alpha: opacity),
                      width: _faceDetected ? 3 : 2,
                    ),
                  ),
                );
              },
            ),

            // Auto-capture indicator
            if (_autoCapturing)
              Positioned(
                bottom: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.greenAccent.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          color: Colors.black,
                          strokeWidth: 2,
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Capturing...',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),

        const SizedBox(height: 32),

        // Status text
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Text(
            _faceDetected
                ? 'Face detected — holding position...'
                : 'Center your face in the frame',
            key: ValueKey(_faceDetected),
            style: TextStyle(
              color: _faceDetected ? Colors.greenAccent : Colors.white60,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ),

        const SizedBox(height: 24),

        // Manual capture button (fallback if auto-capture doesn't trigger)
        if (_cameraReady && !_isCapturing && !_autoCapturing)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: ElevatedButton.icon(
              onPressed: _capture,
              icon: const Icon(Icons.camera_alt),
              label: const Text(
                'Capture Manually',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),

        const Spacer(),

        // Attempt indicator
        if (_scanAttempts > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              'Attempt $_scanAttempts of $_kMaxAttemptsBeforeFallback',
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Matching animation view
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildMatchingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated scanning circles
          SizedBox(
            width: 180,
            height: 180,
            child: Stack(
              alignment: Alignment.center,
              children: [
                for (int i = 0; i < 3; i++)
                  AnimatedBuilder(
                    animation: _pulseAnim,
                    builder: (_, __) {
                      final scale = 1.0 + (i * 0.25) + (_pulseAnim.value * 0.1);
                      final alpha = (0.4 - (i * 0.12)) * (1 - _pulseAnim.value * 0.3);
                      return Transform.scale(
                        scale: scale,
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.blueAccent.withValues(alpha: alpha.clamp(0, 1)),
                              width: 2,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                const CircleAvatar(
                  radius: 44,
                  backgroundColor: Colors.white10,
                  child: Icon(Icons.face_retouching_natural, color: Colors.white, size: 44),
                ),
              ],
            ),
          )
              .animate(onPlay: (c) => c.repeat())
              .rotate(duration: 4.seconds, curve: Curves.linear),

          const SizedBox(height: 40),
          const Text(
            'Identifying...',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Scanning ${_embeddingCache.length} guard profiles',
            style: const TextStyle(color: Colors.white54, fontSize: 14),
          ),
          const SizedBox(height: 32),
          const SizedBox(
            width: 200,
            child: LinearProgressIndicator(
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation(Colors.blueAccent),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Not recognized view
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildNotRecognizedView() {
    final canUseFallback = _scanAttempts >= _kMaxAttemptsBeforeFallback;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.face_retouching_off,
                color: Colors.redAccent,
                size: 64,
              ),
            ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),

            const SizedBox(height: 28),
            const Text(
              'Not Recognized',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white60, fontSize: 15, height: 1.5),
            ),

            if (_lastBestScore > 0) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Best match: ${(_lastBestScore * 100).toStringAsFixed(1)}% '
                  '(minimum required: ${(_kConfidenceThreshold * 100).toStringAsFixed(0)}%)',
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ),
            ],

            const SizedBox(height: 40),

            // Retry button
            ElevatedButton.icon(
              onPressed: _retry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text(
                'Retry Scan',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Manual fallback — ONLY appears after 2 failed attempts
            // Still routes through 1:1 face verification (not a bypass)
            if (canUseFallback) ...[
              OutlinedButton.icon(
                onPressed: _goToManualFallback,
                icon: const Icon(Icons.list_alt_rounded, size: 18),
                label: const Text(
                  'Select Guard Manually',
                  style: TextStyle(fontSize: 14),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white54,
                  side: const BorderSide(color: Colors.white24),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Face verification still required after manual selection',
                style: TextStyle(color: Colors.white24, fontSize: 11),
                textAlign: TextAlign.center,
              ),
            ],

            const SizedBox(height: 20),

            // Cancel — always available, goes to dashboard
            TextButton(
              onPressed: _cancelSession,
              child: const Text(
                'Cancel — Go to Dashboard',
                style: TextStyle(color: Colors.white38, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Confirmation overlay — "Is this you?"
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildConfirmationView() {
    final guard = _matchedGuard!;
    final progress = _countdownRemaining / _kCountdownSeconds;

    return Container(
      color: Colors.black,
      child: Column(
        children: [
          // Top bar
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 20, 24, 0),
            child: Row(
              children: [
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.isCheckOutFlow ? 'Confirm Check-Out' : 'Confirm Check-In',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    widget.site.name,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          // Countdown ring + guard photo
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 200,
                height: 200,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 6,
                  backgroundColor: Colors.white12,
                  valueColor: AlwaysStoppedAnimation(
                    progress > 0.4 ? Colors.greenAccent : Colors.orange,
                  ),
                ),
              ),
              // Guard profile photo
              ClipOval(
                child: SizedBox(
                  width: 168,
                  height: 168,
                  child: guard.photo.length > 200
                      ? Base64ImageWidget(base64String: guard.photo)
                      : Container(
                          color: Colors.white12,
                          child: const Icon(Icons.person, color: Colors.white, size: 80),
                        ),
                ),
              ),
            ],
          ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),

          const SizedBox(height: 32),

          // "Is this you?" headline
          const Text(
            'Is this you?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),

          // Guard name
          Text(
            guard.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),

          // Employee ID
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'ID: ${guard.empId}',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                letterSpacing: 1,
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Countdown text
          AnimatedBuilder(
            animation: _countdownAnim,
            builder: (_, __) => Text(
              'Auto-submitting in $_countdownRemaining second${_countdownRemaining == 1 ? "" : "s"}',
              style: const TextStyle(color: Colors.white38, fontSize: 13),
            ),
          ),

          const Spacer(),

          // Action buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
            child: Column(
              children: [
                // CONFIRM
                ElevatedButton.icon(
                  onPressed: _submitAttendance,
                  icon: const Icon(Icons.check_circle_rounded, size: 22),
                  label: Text(
                    widget.isCheckOutFlow
                        ? 'Confirm & Mark Check-Out'
                        : 'Confirm & Mark Attendance',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.greenAccent,
                    foregroundColor: Colors.black,
                    minimumSize: const Size(double.infinity, 60),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    elevation: 0,
                  ),
                ),

                const SizedBox(height: 14),

                // NOT ME
                ElevatedButton.icon(
                  onPressed: _cancelSession,
                  icon: const Icon(Icons.close_rounded, size: 20),
                  label: const Text(
                    'Cancel — Not Me',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Submitting spinner
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildSubmittingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 72,
            height: 72,
            child: CircularProgressIndicator(color: Colors.greenAccent, strokeWidth: 4),
          ),
          const SizedBox(height: 28),
          const Text(
            'Saving attendance...',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            _matchedGuard?.name ?? '',
            style: const TextStyle(color: Colors.white54, fontSize: 14),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Success screen
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildSuccessView() {
    final now = DateTime.now();
    final timeStr = DateFormat('hh:mm a').format(now);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.greenAccent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: Colors.greenAccent,
                size: 88,
              ),
            )
                .animate()
                .scale(duration: 500.ms, curve: Curves.elasticOut)
                .fadeIn(duration: 300.ms),

            const SizedBox(height: 32),
            const Text(
              'Attendance Marked!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.3),

            const SizedBox(height: 16),
            Text(
              _matchedGuard?.name ?? '',
              style: const TextStyle(
                color: Colors.greenAccent,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ).animate().fadeIn(delay: 300.ms),

            const SizedBox(height: 8),
            Text(
              widget.isCheckOutFlow ? 'Checked Out at $timeStr' : 'Checked In at $timeStr',
              style: const TextStyle(color: Colors.white54, fontSize: 15),
            ).animate().fadeIn(delay: 400.ms),

            const SizedBox(height: 12),
            Text(
              widget.site.name,
              style: const TextStyle(color: Colors.white30, fontSize: 13),
            ).animate().fadeIn(delay: 500.ms),

            const SizedBox(height: 48),
            const Text(
              'Redirecting to dashboard...',
              style: TextStyle(color: Colors.white24, fontSize: 13),
            ).animate().fadeIn(delay: 600.ms),
          ],
        ),
      ),
    );
  }
}
