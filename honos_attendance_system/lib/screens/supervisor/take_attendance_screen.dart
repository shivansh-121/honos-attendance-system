import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../../app_theme.dart';
import '../../models/guard.dart';
import '../../models/site.dart';
import '../../models/attendance.dart';
import '../../services/db_service.dart';
import '../../services/auth_service.dart';
import '../../services/sync_service.dart';
import '../../services/camera_service.dart';
import '../../services/permission_service.dart';
import '../../widgets/base64_image_widget.dart';
import 'liveness_detector_widget.dart';

enum _Step { location, guard, liveness, confirmation }

class TakeAttendanceScreen extends ConsumerStatefulWidget {
  final Site site;
  const TakeAttendanceScreen({super.key, required this.site});

  @override
  ConsumerState<TakeAttendanceScreen> createState() => _TakeAttendanceScreenState();
}

class _TakeAttendanceScreenState extends ConsumerState<TakeAttendanceScreen> {
  _Step _step = _Step.location;
  bool _checkingGps = true;
  bool _gpsOk = false;
  String _gpsError = '';
  Guard? _selectedGuard;
  String? _livePhotoBase64;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkGps());
  }

  Future<void> _checkGps() async {
    if (!mounted) return;
    
    if (kIsWeb) {
      if (mounted) setState(() { _gpsOk = true; _checkingGps = false; });
      return;
    }

    setState(() { _checkingGps = true; _gpsError = ''; });
    
    try {
      final gpsEnabled = await PermissionService.isGpsEnabled();
      if (!gpsEnabled) throw Exception('GPS is disabled. Please turn it on.');
      
      final hasPerms = await PermissionService.requestSupervisorPermissions();
      if (!hasPerms) throw Exception('Location and Camera permissions are required.');

      Position? pos = await Geolocator.getLastKnownPosition();
      if (pos == null) {
        pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium)
            .timeout(const Duration(seconds: 5));
      }
          
      final dist = Geolocator.distanceBetween(pos.latitude, pos.longitude, widget.site.lat, widget.site.lng);
      if (dist <= widget.site.radius) {
        if (mounted) setState(() => _gpsOk = true);
      } else {
        if (mounted) setState(() => _gpsError = 'You are ${dist.toInt()}m from site. Required: within ${widget.site.radius.toInt()}m.');
      }
    } catch (e) {
      if (mounted) setState(() => _gpsError = e.toString());
    } finally {
      if (mounted) setState(() => _checkingGps = false);
    }
  }

  Future<void> _submit() async {
    final db = ref.read(dbProvider);
    final sync = ref.read(syncProvider);
    final supervisor = ref.read(authProvider);

    final record = Attendance(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      guardId: _selectedGuard!.id,
      siteId: widget.site.id,
      date: DateFormat('yyyy-MM-dd').format(DateTime.now()),
      time: DateFormat('HH:mm').format(DateTime.now()),
      status: 'present',
      supervisorId: supervisor?.id ?? '',
      photoPath: _livePhotoBase64 ?? '',
      markedAt: DateTime.now().toIso8601String(),
      lat: widget.site.lat,
      lng: widget.site.lng,
    );

    await db.saveAttendance(record);

    final updatedGuard = Guard(
      id: _selectedGuard!.id,
      name: _selectedGuard!.name,
      empId: _selectedGuard!.empId,
      siteId: widget.site.id,
      supervisorId: supervisor?.id ?? '',
      photo: _selectedGuard!.photo,
      phone: _selectedGuard!.phone,
      joinDate: _selectedGuard!.joinDate,
      salary: _selectedGuard!.salary,
    );
    await db.saveGuard(updatedGuard);

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Attendance marked successfully!'), backgroundColor: AppTheme.green),
      );
    }

    sync.pushAttendance(record).catchError((e) => debugPrint('Firebase sync: $e'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Take Attendance')),
      body: _checkingGps 
        ? const Center(child: CircularProgressIndicator())
        : _buildCurrentStep(),
    );
  }

  Widget _buildCurrentStep() {
    switch (_step) {
      case _Step.location:
        return _LocationStep(
          checking: _checkingGps,
          ok: _gpsOk,
          error: _gpsError,
          onRetry: _checkGps,
          onNext: () => setState(() => _step = _Step.guard),
        );
      case _Step.guard:
        return _GuardStep(
          site: widget.site,
          onNext: (g) => setState(() {
            _selectedGuard = g;
            _step = _Step.liveness;
          }),
        );
      case _Step.liveness:
        return _FaceMatchStep(
          guard: _selectedGuard!,
          onVerified: (photo) => setState(() {
            _livePhotoBase64 = photo;
            _step = _Step.confirmation;
          }),
        );
      case _Step.confirmation:
        return _ConfirmStep(
          guard: _selectedGuard!,
          site: widget.site,
          onSubmit: _submit,
        );
    }
  }
}

class _StepShell extends StatelessWidget {
  final String stepNumber, title;
  final Widget child;
  const _StepShell({required this.stepNumber, required this.title, required this.child});
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            CircleAvatar(radius: 18, child: Text(stepNumber)),
            const SizedBox(width: 12),
            Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold))
          ]),
          const SizedBox(height: 30),
          child,
        ],
      ),
    );
  }
}

class _LocationStep extends StatelessWidget {
  final bool checking, ok;
  final String error;
  final VoidCallback onRetry, onNext;
  const _LocationStep({required this.checking, required this.ok, required this.error, required this.onRetry, required this.onNext});
  @override
  Widget build(BuildContext context) {
    return _StepShell(stepNumber: '1', title: 'GPS Verification',
      child: Column(children: [
        if (checking) const CircularProgressIndicator()
        else if (ok) ...[
          const Icon(Icons.check_circle, color: AppTheme.green, size: 80),
          const SizedBox(height: 16),
          const Text('Location Verified', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 20),
          ElevatedButton(onPressed: onNext, child: const Text('Continue')),
        ] else ...[
          const Icon(Icons.location_off, color: AppTheme.red, size: 80),
          const SizedBox(height: 16),
          Text(error, textAlign: TextAlign.center),
          const SizedBox(height: 20),
          ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
        ]
      ]),
    );
  }
}

class _GuardStep extends StatefulWidget {
  final Site site;
  final Function(Guard) onNext;
  const _GuardStep({required this.site, required this.onNext});

  @override
  State<_GuardStep> createState() => _GuardStepState();
}

class _GuardStepState extends State<_GuardStep> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final guardsAsync = ref.watch(guardsStreamProvider);
        return _StepShell(
          stepNumber: '2',
          title: 'Select Guard',
          child: Column(
            children: [
              TextField(
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Search guard by name or ID...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: AppTheme.bgSurface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 20),
              guardsAsync.when(
                data: (allGuards) {
                  final filtered = allGuards.where((g) {
                    final q = _query.toLowerCase();
                    return g.name.toLowerCase().contains(q) || g.empId.toLowerCase().contains(q);
                  }).toList();

                  if (filtered.isEmpty) {
                    return Center(child: Padding(
                      padding: const EdgeInsets.all(40.0),
                      child: Column(
                        children: [
                          const Icon(Icons.search_off, size: 48, color: AppTheme.txtMuted),
                          const SizedBox(height: 16),
                          const Text('No matching guards found.', style: TextStyle(color: AppTheme.txtMuted)),
                          const SizedBox(height: 12),
                          if (_query.isNotEmpty) TextButton(onPressed: () => setState(() => _query = ''), child: const Text('Clear Search')),
                        ],
                      ),
                    ));
                  }

                  return Column(
                    children: filtered.map((g) {
                      final isLocal = g.siteId == widget.site.id;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: ClipOval(
                          child: SizedBox(
                            width: 44,
                            height: 44,
                            child: g.photo.length > 200
                                ? Base64ImageWidget(base64String: g.photo)
                                : const Icon(Icons.person, color: AppTheme.txtMuted),
                          ),
                        ),
                        title: Row(
                          children: [
                            Flexible(child: Text(g.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
                            if (isLocal) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: AppTheme.green.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                                child: const Text('LOCAL', style: TextStyle(color: AppTheme.green, fontSize: 9, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Text('ID: ${g.empId}', style: const TextStyle(color: AppTheme.txtSec, fontSize: 12)),
                        trailing: const Icon(Icons.chevron_right, color: AppTheme.txtMuted),
                        onTap: () => widget.onNext(g),
                      );
                    }).toList(),
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        const Icon(Icons.error_outline, color: AppTheme.red, size: 40),
                        const SizedBox(height: 12),
                        const Text('Connection error. Please check your internet.', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.txtSec)),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => ref.invalidate(guardsStreamProvider),
                          child: const Text('Retry Connection'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FaceMatchStep extends StatefulWidget {
  final Guard guard;
  final Function(String photoBase64) onVerified;
  const _FaceMatchStep({required this.guard, required this.onVerified});
  @override
  State<_FaceMatchStep> createState() => _FaceMatchStepState();
}

class _FaceMatchStepState extends State<_FaceMatchStep> {
  CameraController? _ctrl;
  bool _ready = false;
  bool _busy = false;
  String _msg = 'Align face and BLINK to start...';
  bool _blinked = false;
  final _detector = FaceDetector(options: FaceDetectorOptions(enableLandmarks: true, enableClassification: true, performanceMode: FaceDetectorMode.accurate));

  @override
  void initState() { super.initState(); _init(); }

  Future<void> _init() async {
    if (globalCameras.isEmpty) await initCameras();
    final front = globalCameras.firstWhere((c) => c.lensDirection == CameraLensDirection.front, orElse: () => globalCameras.first);
    _ctrl = CameraController(front, ResolutionPreset.medium, enableAudio: false);
    await _ctrl!.initialize();
    if (mounted) setState(() => _ready = true);
  }

  @override
  void dispose() { _ctrl?.dispose(); _detector.close(); super.dispose(); }

  Future<void> _verify() async {
    if (_busy) return;
    setState(() { _busy = true; _msg = 'Analyzing...'; });
    try {
      final xFile = await _ctrl!.takePicture();
      final bytes = await File(xFile.path).readAsBytes();
      final b64 = base64Encode(bytes);
      
      final faces = await _detector.processImage(InputImage.fromFile(File(xFile.path)));
      if (faces.isEmpty) { setState(() { _msg = 'No face found.'; _busy = false; }); return; }
      
      final liveFace = faces.first;
      
      if (widget.guard.photo.length < 200) { widget.onVerified(b64); return; }

      final refBytes = base64Decode(widget.guard.photo);
      final tempDir = await getTemporaryDirectory();
      final refFile = File(p.join(tempDir.path, 'ref.jpg'));
      await refFile.writeAsBytes(refBytes);
      final refFaces = await _detector.processImage(InputImage.fromFile(refFile));

      if (refFaces.isEmpty) { widget.onVerified(b64); return; }

      final score = _compare(refFaces.first, liveFace);
      if (score > 0.93) { widget.onVerified(b64); } 
      else { setState(() { _msg = 'Identity Mismatch!'; _busy = false; }); }
    } catch (e) { setState(() { _msg = 'Error: $e'; _busy = false; }); }
  }

  double _compare(Face a, Face b) {
    final v1 = _profile(a), v2 = _profile(b);
    if (v1.isEmpty || v2.isEmpty) return 0;
    double dot = 0, m1 = 0, m2 = 0;
    for (int i = 0; i < v1.length; i++) { dot += v1[i] * v2[i]; m1 += v1[i] * v1[i]; m2 += v2[i] * v2[i]; }
    return (m1 == 0 || m2 == 0) ? 0 : (dot / (sqrt(m1) * sqrt(m2)));
  }

  List<double> _profile(Face f) {
    final le = f.landmarks[FaceLandmarkType.leftEye]?.position;
    final re = f.landmarks[FaceLandmarkType.rightEye]?.position;
    final n = f.landmarks[FaceLandmarkType.noseBase]?.position;
    final lm = f.landmarks[FaceLandmarkType.leftMouth]?.position;
    final rm = f.landmarks[FaceLandmarkType.rightMouth]?.position;
    if (le == null || re == null || n == null || lm == null || rm == null) return [];
    double d(Point a, Point b) => sqrt(pow(a.x - b.x, 2) + pow(a.y - b.y, 2));
    final unit = d(le, re); if (unit < 1) return [];
    final midX = (le.x + re.x) / 2, midY = (le.y + re.y) / 2;
    return [(n.x - midX) / unit, (n.y - midY) / unit, (lm.x - midX) / unit, (lm.y - midY) / unit, (rm.x - midX) / unit, (rm.y - midY) / unit, d(n, lm) / unit, d(n, rm) / unit];
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      if (!_blinked) LivenessDetectorWidget(onBlinkDetected: () => setState(() => _blinked = true))
      else ...[
        if (_ready) ClipRRect(borderRadius: BorderRadius.circular(20), child: SizedBox(height: 300, child: CameraPreview(_ctrl!))),
        const SizedBox(height: 20),
        Text(_msg, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        if (!_busy) ElevatedButton(onPressed: _verify, child: const Text('Verify Identity')),
        TextButton(onPressed: () => widget.onVerified(''), child: const Text('Supervisor Override', style: TextStyle(color: AppTheme.red))),
      ]
    ]);
  }
}

class _ConfirmStep extends StatelessWidget {
  final Guard guard;
  final Site site;
  final VoidCallback onSubmit;
  const _ConfirmStep({required this.guard, required this.site, required this.onSubmit});
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      const Icon(Icons.verified_user, color: AppTheme.green, size: 60),
      const SizedBox(height: 20),
      Text('Ready to submit for ${guard.name}'),
      const SizedBox(height: 30),
      ElevatedButton(onPressed: onSubmit, style: ElevatedButton.styleFrom(backgroundColor: AppTheme.green, minimumSize: const Size(double.infinity, 50)), child: const Text('Submit Attendance')),
    ]);
  }
}
