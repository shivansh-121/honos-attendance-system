import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../../app_theme.dart';
import '../../models/site.dart';
import '../../models/attendance.dart';
import '../../models/app_user.dart';
import '../../services/db_service.dart';
import '../../services/auth_service.dart';
import '../../services/permission_service.dart';
import '../../services/camera_service.dart';
import '../../services/face_match_service.dart';
import '../../services/mobile_attendance_guard.dart';
import '../supervisor/liveness_detector_widget.dart';

enum _Step { location, liveness, confirmation }

class EmployeeTakeAttendanceScreen extends ConsumerStatefulWidget {
  final bool isCheckOutFlow;

  const EmployeeTakeAttendanceScreen({
    super.key,
    this.isCheckOutFlow = false,
  });

  @override
  ConsumerState<EmployeeTakeAttendanceScreen> createState() =>
      _EmployeeTakeAttendanceScreenState();
}

class _EmployeeTakeAttendanceScreenState
    extends ConsumerState<EmployeeTakeAttendanceScreen> {
  _Step _step = _Step.location;
  bool _checkingGps = true;
  bool _gpsOk = false;
  String _gpsError = '';
  Site? _closestSite;
  String? _livePhotoBase64;
  bool _isSubmitting = false;

  Attendance? _existingRecord;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initializeFlow());
  }

  Future<void> _initializeFlow() async {
    // Attendance capture is only supported on the mobile app.
    if (!isMobileAttendanceDevice) {
      if (mounted) {
        Navigator.pop(context);
        await Future.delayed(const Duration(milliseconds: 200));
        if (mounted) {
          showMobileAttendanceRequiredDialog(context,
              isCheckOut: widget.isCheckOutFlow);
        }
      }
      return;
    }

    final user = ref.read(authProvider);
    if (user == null) return;

    if (widget.isCheckOutFlow) {
      try {
        final records =
            await ref.read(dbProvider).attendanceStreamForGuard(user.id).first;
        final myRecords = records.where((r) => r.checkOutTime.isEmpty).toList();

        if (myRecords.isNotEmpty) {
          // Sort descending by markedAt
          myRecords.sort((a, b) {
            final da = DateTime.tryParse(a.markedAt) ?? DateTime(2000);
            final db = DateTime.tryParse(b.markedAt) ?? DateTime(2000);
            return db.compareTo(da);
          });
          _existingRecord = myRecords.first;
        } else {
          if (mounted) {
            setState(() {
              _checkingGps = false;
              _gpsError =
                  'No pending Check-In record found. Please Check-In first.';
            });
          }
          return;
        }
      } catch (e) {
        if (mounted) setState(() => _gpsError = 'Error fetching records: $e');
        return;
      }
    }

    await _checkGps();
  }

  Future<void> _checkGps() async {
    if (!mounted) return;

    if (!isMobileAttendanceDevice) {
      showMobileAttendanceRequiredDialog(context,
          isCheckOut: widget.isCheckOutFlow);
      return;
    }

    setState(() {
      _checkingGps = true;
      _gpsError = '';
    });

    try {
      final gpsEnabled = await PermissionService.isGpsEnabled();
      if (!gpsEnabled) throw Exception('GPS is disabled. Please turn it on.');

      final hasPerms = await PermissionService.requestSupervisorPermissions();
      if (!hasPerms)
        throw Exception('Location and Camera permissions are required.');

      Position pos = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.high)
          .timeout(const Duration(seconds: 10));

      if (pos.isMocked) {
        throw Exception(
            'Mock Location detected. Please disable Fake GPS apps.');
      }

      // Find the assigned site
      final sites = await ref.read(sitesStreamProvider.future);
      final user = ref.read(authProvider)!;

      // STRICT PROTOCOL: Office Employees must be at their assigned site
      if (user.siteId.isEmpty) {
        throw Exception('You are not assigned to a site. Please contact Admin.');
      }
      
      final assignedSite = sites.firstWhere((s) => s.id == user.siteId, 
          orElse: () => throw Exception('Your assigned site was not found. Please contact Admin.'));

      final dist = Geolocator.distanceBetween(
          pos.latitude, pos.longitude, assignedSite.lat, assignedSite.lng);

      if (dist <= assignedSite.radius) {
        if (mounted) {
          setState(() {
            _closestSite = assignedSite;
            _gpsOk = true;
          });
        }
      } else {
        throw Exception('You are ${dist.toInt()}m from your assigned site (${assignedSite.name}). You must be within ${assignedSite.radius.toInt()}m to check in.');
      }
    } catch (e) {
      if (mounted) setState(() => _gpsError = e.toString());
    } finally {
      if (mounted) setState(() => _checkingGps = false);
    }
  }

  Future<void> _submitAttendance() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      final db = ref.read(dbProvider);
      final user = ref.read(authProvider)!;
      final now = DateTime.now();
      final date = DateFormat('yyyy-MM-dd').format(now);
      final time = DateFormat('HH:mm:ss').format(now);

      String photoUrl = '';
      if (_livePhotoBase64 != null && _livePhotoBase64!.isNotEmpty) {
        photoUrl = _livePhotoBase64!;
      }

      if (!widget.isCheckOutFlow) {
        // CHECK IN
        final att = Attendance(
          id: const Uuid().v4(),
          guardId: user.id, // Using guardId to represent the staff who attended
          siteId: _closestSite!.id,
          supervisorId: user.id, // Self supervised
          date: date,
          time: time,
          status: 'Present',
          photoPath: photoUrl,
          markedAt: now.toIso8601String(),
        );
        db
            .saveAttendance(att)
            .catchError((e) => debugPrint('Att in error: $e'));
      } else {
        // CHECK OUT
        final existing = _existingRecord!;
        final updated = Attendance(
          id: existing.id,
          guardId: existing.guardId,
          siteId: existing.siteId,
          supervisorId: existing.supervisorId,
          date: existing.date,
          time: existing.time,
          status: existing.status,
          photoPath: existing.photoPath,
          markedAt: existing.markedAt,
          lat: existing.lat,
          lng: existing.lng,
          checkOutTime: time,
          checkOutPhotoPath: photoUrl,
        );
        db
            .saveAttendance(updated)
            .catchError((e) => debugPrint('Att out error: $e'));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(widget.isCheckOutFlow
              ? 'Check-Out successful!'
              : 'Check-In successful!'),
          backgroundColor: context.colors.green,
        ));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed: $e'),
          backgroundColor: context.colors.red,
        ));
      }
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.bgBase,
      appBar: AppBar(
        backgroundColor: context.colors.bgSurface,
        iconTheme: IconThemeData(color: context.colors.txtPrimary),
        title: Text(
            widget.isCheckOutFlow ? 'Employee Check-Out' : 'Employee Check-In',
            style: TextStyle(
                color: context.colors.txtPrimary, fontWeight: FontWeight.bold)),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
              color: context.colors.bord.withValues(alpha: 0.5), height: 1),
        ),
      ),
      body: _buildCurrentStep(),
    );
  }

  Widget _buildCurrentStep() {
    switch (_step) {
      case _Step.location:
        return _buildLocationStep();
      case _Step.liveness:
        return _buildLivenessStep();
      case _Step.confirmation:
        return _buildConfirmationStep();
    }
  }

  // --- LOCATION STEP ---
  Widget _buildLocationStep() {
    if (_checkingGps) {
      return Center(
          child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: context.colors.primary),
          const SizedBox(height: 16),
          Text('Verifying location...',
              style: TextStyle(color: context.colors.txtPrimary)),
        ],
      ));
    }

    if (!_gpsOk) {
      return Center(
          child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_off, size: 64, color: context.colors.red),
            const SizedBox(height: 16),
            Text('Location Verification Failed',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: context.colors.txtPrimary)),
            const SizedBox(height: 8),
            Text(_gpsError,
                textAlign: TextAlign.center,
                style: TextStyle(color: context.colors.txtMuted)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: context.colors.red,
                  foregroundColor: Colors.white),
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              onPressed: _initializeFlow,
            )
          ],
        ),
      ));
    }

    return Center(
        child: Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.location_on, size: 64, color: context.colors.green),
          const SizedBox(height: 16),
          Text('Location Verified',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: context.colors.txtPrimary)),
          const SizedBox(height: 8),
          Text('You are at: ${_closestSite?.name}',
              style: TextStyle(color: context.colors.primary)),
          const SizedBox(height: 24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: context.colors.primary,
                foregroundColor: context.colors.bgBase,
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 16)),
            onPressed: () => setState(() => _step = _Step.liveness),
            child:
                const Text('Proceed to Photo', style: TextStyle(fontSize: 16)),
          )
        ],
      ),
    ));
  }

  // --- LIVENESS STEP ---
  Widget _buildLivenessStep() {
    final user = ref.watch(authProvider)!;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text('Liveness & Face Match',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: context.colors.txtPrimary)),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _FaceMatchStep(
              user: user,
              isCheckOut: widget.isCheckOutFlow,
              onVerified: (photoBase64) {
                setState(() {
                  _livePhotoBase64 = photoBase64;
                  _step = _Step.confirmation;
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  // --- CONFIRMATION STEP ---
  Widget _buildConfirmationStep() {
    final user = ref.watch(authProvider)!;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Confirm Attendance',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: context.colors.txtPrimary),
              textAlign: TextAlign.center),
          const SizedBox(height: 24),
          if (_livePhotoBase64 != null)
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.memory(base64Decode(_livePhotoBase64!),
                    height: 200, width: 200, fit: BoxFit.cover),
              ),
            ),
          const SizedBox(height: 24),
          Card(
            color: context.colors.bgSurface,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(Icons.person, color: context.colors.primary),
                    title: Text(user.name,
                        style: TextStyle(
                            color: context.colors.txtPrimary,
                            fontWeight: FontWeight.bold)),
                    subtitle: Text('Office Employee',
                        style: TextStyle(color: context.colors.txtMuted)),
                  ),
                  Divider(color: context.colors.bord),
                  ListTile(
                    leading:
                        Icon(Icons.location_on, color: context.colors.primary),
                    title: Text(_closestSite?.name ?? '',
                        style: TextStyle(color: context.colors.txtPrimary)),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.isCheckOutFlow
                  ? context.colors.red
                  : context.colors.green,
              foregroundColor: context.colors.bgBase,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onPressed: _isSubmitting ? null : _submitAttendance,
            child: _isSubmitting
                ? const CircularProgressIndicator(color: Colors.white)
                : Text(
                    widget.isCheckOutFlow
                        ? 'Confirm Check-Out'
                        : 'Confirm Check-In',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _FaceMatchStep extends StatefulWidget {
  final AppUser user;
  final bool isCheckOut;
  final Function(String photoBase64) onVerified;
  const _FaceMatchStep(
      {required this.user, required this.isCheckOut, required this.onVerified});
  @override
  State<_FaceMatchStep> createState() => _FaceMatchStepState();
}

class _FaceMatchStepState extends State<_FaceMatchStep> {
  CameraController? _ctrl;
  bool _ready = false;
  bool _busy = false;
  String _msg = 'Ready...';
  bool _blinked = false;
  CameraLensDirection _currentDirection = CameraLensDirection.front;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _init() async {
    await Future.delayed(const Duration(milliseconds: 800));

    if (globalCameras.isEmpty) await initCameras();
    if (globalCameras.isEmpty) return;
    final camera = globalCameras.firstWhere(
        (c) => c.lensDirection == _currentDirection,
        orElse: () => globalCameras.first);
    _ctrl = CameraController(camera, ResolutionPreset.low, enableAudio: false);

    try {
      await _ctrl!.initialize();
      if (mounted) setState(() => _ready = true);
    } catch (e) {
      if (mounted) setState(() => _msg = 'Camera Error: $e');
    }
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _msg = 'Capturing photo...';
    });
    try {
      final xFile = await _ctrl!.takePicture();
      final bytes = await xFile.readAsBytes();
      final b64 = base64Encode(bytes);

      await FaceMatchService.init();

      final liveEmbedding =
          await FaceMatchService.getEmbeddings(File(xFile.path));
      if (liveEmbedding == null) {
        setState(() {
          _msg = 'Could not extract face from live photo.';
          _busy = false;
        });
        return;
      }

      if (widget.user.photo.length < 200) {
        setState(() => _msg = 'Optimizing verification photo...');
        final compressedBytes = await compute(_compressImageBytes, bytes);
        final finalB64 =
            compressedBytes != null ? base64Encode(compressedBytes) : b64;
        widget.onVerified(finalB64);
        return;
      }

      final refBytes = base64Decode(widget.user.photo);
      final tempDir = await getTemporaryDirectory();
      final refFile = File(p.join(tempDir.path, 'ref_temp.jpg'));
      await refFile.writeAsBytes(refBytes);

      final refEmbedding = await FaceMatchService.getEmbeddings(refFile);
      if (refEmbedding == null) {
        setState(() {
          _msg = 'Invalid reference photo. Please contact Admin.';
          _busy = false;
        });
        return;
      }

      final score = FaceMatchService.compareFaces(refEmbedding, liveEmbedding);

      if (score >= 0.75) {
        setState(() => _msg = 'Optimizing verification photo...');
        final compressedBytes = await compute(_compressImageBytes, bytes);
        final finalB64 =
            compressedBytes != null ? base64Encode(compressedBytes) : b64;
        widget.onVerified(finalB64);
      } else {
        setState(() {
          _msg =
              'Identity Mismatch! (Score: ${(score * 100).toStringAsFixed(1)}%)';
          _busy = false;
        });
      }
    } catch (e) {
      setState(() {
        _msg = 'Error: $e';
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (!_blinked)
            Expanded(
              child: LivenessDetectorWidget(onBlinkDetected: () {
                setState(() => _blinked = true);
                _init();
              }),
            )
          else ...[
            if (_ready)
              Stack(
                children: [
                  ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: SizedBox(
                          height: 300,
                          width: double.infinity,
                          child: CameraPreview(_ctrl!))),
                ],
              ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(12)),
              child: Text(_msg,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.white),
                  textAlign: TextAlign.center),
            ),
            const SizedBox(height: 20),
            if (!_busy && _ready)
              ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: context.colors.primary,
                      foregroundColor: Colors.white),
                  onPressed: _verify,
                  child: Text(widget.isCheckOut
                      ? 'Capture & Verify Check-Out'
                      : 'Capture & Verify Check-In')),
          ]
        ],
      ),
    );
  }
}

Uint8List? _compressImageBytes(Uint8List bytes) {
  try {
    final image = img.decodeImage(bytes);
    if (image == null) return null;

    img.Image resized;
    if (image.width > image.height) {
      resized = img.copyResize(image, width: 400);
    } else {
      resized = img.copyResize(image, height: 400);
    }

    return img.encodeJpg(resized, quality: 70);
  } catch (e) {
    debugPrint('Error in background photo compression: $e');
    return null;
  }
}
