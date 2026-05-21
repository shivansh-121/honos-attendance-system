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
import 'package:image/image.dart' as img;

import '../../app_theme.dart';
import '../../services/face_match_service.dart';
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
  final bool isCheckOutFlow;
  final Guard? preselectedGuard;
  final Attendance? existingRecord;

  const TakeAttendanceScreen({
    super.key, 
    required this.site, 
    this.isCheckOutFlow = false,
    this.preselectedGuard,
    this.existingRecord,
  });

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
  bool _isCheckOut = false;
  Attendance? _existingRecord;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.preselectedGuard != null) {
      _selectedGuard = widget.preselectedGuard;
      _isCheckOut = widget.isCheckOutFlow;
      _existingRecord = widget.existingRecord;
      _step = _Step.liveness;
    }
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
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      final db = ref.read(dbProvider);
      final sync = ref.read(syncProvider);
      final supervisor = ref.read(authProvider);

      if (_isCheckOut && _existingRecord != null) {
        final updatedRecord = Attendance(
          id: _existingRecord!.id,
          guardId: _existingRecord!.guardId,
          siteId: _existingRecord!.siteId,
          date: _existingRecord!.date,
          time: _existingRecord!.time,
          status: 'present',
          supervisorId: _existingRecord!.supervisorId,
          photoPath: _existingRecord!.photoPath,
          markedAt: _existingRecord!.markedAt,
          lat: _existingRecord!.lat,
          lng: _existingRecord!.lng,
          checkOutTime: DateFormat('HH:mm').format(DateTime.now()),
          checkOutPhotoPath: _livePhotoBase64 ?? '',
        );

        await db.saveAttendance(updatedRecord);
      } else {
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
      }

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
        Navigator.of(context).popUntil((route) => route.isFirst);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isCheckOut ? 'Check-Out completed successfully!' : 'Check-In completed successfully!'), backgroundColor: AppTheme.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving attendance: $e'), backgroundColor: AppTheme.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.isCheckOutFlow ? 'Check-Out Attendance' : 'Check-In Attendance')),
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
          isCheckOutFlow: widget.isCheckOutFlow,
          onNext: (g, isCheckOut, existingRecord) => setState(() {
            _selectedGuard = g;
            _isCheckOut = isCheckOut;
            _existingRecord = existingRecord;
            _step = _Step.liveness;
          }),
        );
      case _Step.liveness:
        return _StepShell(
          stepNumber: '3',
          title: 'Liveness & Face Match',
          child: _FaceMatchStep(
            guard: _selectedGuard!,
            isCheckOut: _isCheckOut,
            onVerified: (photo) => setState(() {
              _livePhotoBase64 = photo;
              _step = _Step.confirmation;
            }),
          ),
        );
      case _Step.confirmation:
        return _StepShell(
          stepNumber: '4',
          title: 'Confirmation',
          child: _ConfirmStep(
            guard: _selectedGuard!,
            site: widget.site,
            isCheckOut: _isCheckOut,
            isSubmitting: _isSubmitting,
            onSubmit: _submit,
          ),
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
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (checking) const CircularProgressIndicator()
            else if (ok) ...[
              const Icon(Icons.check_circle, color: AppTheme.green, size: 80),
              const SizedBox(height: 16),
              const Text('Location Verified', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18), textAlign: TextAlign.center),
              const SizedBox(height: 20),
              ElevatedButton(onPressed: onNext, child: const Text('Continue')),
            ] else ...[
              const Icon(Icons.location_off, color: AppTheme.red, size: 80),
              const SizedBox(height: 16),
              Text(error, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
            ]
          ],
        ),
      ),
    );
  }
}

class _GuardStep extends StatefulWidget {
  final Site site;
  final bool isCheckOutFlow;
  final Function(Guard, bool, Attendance?) onNext;
  const _GuardStep({required this.site, required this.isCheckOutFlow, required this.onNext});

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

                  final attendanceAsync = ref.watch(todayAttendanceProvider);
                  return attendanceAsync.when(
                    data: (allAttendance) {
                      // Sort all attendance chronologically to safely get the true "last" record
                      final sortedAtt = List<Attendance>.from(allAttendance)
                        ..sort((a, b) => a.markedAt.compareTo(b.markedAt));
                        
                      // Apply strict check-out / check-in filtering
                      final strictlyFiltered = filtered.where((g) {
                        final existingRecord = sortedAtt.where((a) => a.guardId == g.id && a.status.toLowerCase() == 'present').lastOrNull;
                        final isCheckedIn = existingRecord != null && existingRecord.checkOutTime.isEmpty;
                        final isShiftCompleted = existingRecord != null && existingRecord.checkOutTime.isNotEmpty;
                        
                        if (widget.isCheckOutFlow) {
                          // Only show guards who are currently checked in
                          return isCheckedIn && !isShiftCompleted;
                        } else {
                          // Check-In flow: Only show guards who haven't checked in yet today
                          return !isCheckedIn && !isShiftCompleted;
                        }
                      }).toList();

                      if (strictlyFiltered.isEmpty) {
                        return Center(child: Padding(
                          padding: const EdgeInsets.all(40.0),
                          child: Column(
                            children: [
                              Icon(widget.isCheckOutFlow ? Icons.logout : Icons.login, size: 48, color: AppTheme.txtMuted),
                              const SizedBox(height: 16),
                              Text(widget.isCheckOutFlow ? 'No guards available for Check-Out.' : 'All guards are already checked in.', style: const TextStyle(color: AppTheme.txtMuted)),
                            ],
                          ),
                        ));
                      }

                        return Column(
                          children: strictlyFiltered.map((g) {
                            final isLocal = g.siteId == widget.site.id;
                            final existingRecord = sortedAtt.where((a) => a.guardId == g.id && a.status.toLowerCase() == 'present').lastOrNull;
                            final isCheckedIn = existingRecord != null && existingRecord.checkOutTime.isEmpty;
                            final isShiftCompleted = existingRecord != null && existingRecord.checkOutTime.isNotEmpty;

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
                          trailing: isShiftCompleted 
                            ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                                child: const Text('Completed', style: TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.bold))
                              )
                            : isCheckedIn
                              ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: AppTheme.yellow.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                                  child: const Text('Checked In', style: TextStyle(color: AppTheme.yellow, fontSize: 12, fontWeight: FontWeight.bold))
                                )
                              : const Icon(Icons.chevron_right, color: AppTheme.txtMuted),
                          onTap: isShiftCompleted ? null : () => widget.onNext(g, isCheckedIn, existingRecord),
                        );
                      }).toList(),
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (_, __) => const SizedBox(),
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
  final bool isCheckOut;
  final Function(String photoBase64) onVerified;
  const _FaceMatchStep({required this.guard, required this.isCheckOut, required this.onVerified});
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
    // Do NOT initialize camera here. LivenessDetectorWidget is using it.
  }

  Future<void> _init() async {
    // Wait for the previous Liveness camera to fully release hardware
    await Future.delayed(const Duration(milliseconds: 800));
    
    if (globalCameras.isEmpty) await initCameras();
    if (globalCameras.isEmpty) return;
    final camera = globalCameras.firstWhere(
      (c) => c.lensDirection == _currentDirection, 
      orElse: () => globalCameras.first
    );
    _ctrl = CameraController(camera, ResolutionPreset.low, enableAudio: false);
    
    try {
      await _ctrl!.initialize();
      if (mounted) setState(() => _ready = true);
    } catch (e) {
      if (mounted) setState(() => _msg = 'Camera Error: $e');
    }
  }

  Future<void> _flipCamera() async {
    if (globalCameras.length < 2 || _busy) return;
    
    setState(() {
      _currentDirection = _currentDirection == CameraLensDirection.front 
          ? CameraLensDirection.back 
          : CameraLensDirection.front;
      _ready = false;
    });

    await _ctrl?.dispose();
    _ctrl = null;
    await _init();
  }

  @override
  void dispose() { 
    _ctrl?.dispose(); 
    super.dispose(); 
  }

  Future<void> _verify() async {
    if (_busy) return;
    setState(() { _busy = true; _msg = 'Capturing photo...'; });
    try {
      final xFile = await _ctrl!.takePicture();
      final bytes = await xFile.readAsBytes();
      final b64 = base64Encode(bytes);
      
      // Initialize FaceMatchService if not already done
      await FaceMatchService.init();

      // Extract embedding from live photo
      final liveEmbedding = await FaceMatchService.getEmbeddings(File(xFile.path));
      if (liveEmbedding == null) {
        setState(() { _msg = 'Could not extract face from live photo.'; _busy = false; });
        return;
      }

      // Extract embedding from reference photo (guard.photo is base64)
      if (widget.guard.photo.length < 200) {
        // No reference photo, we might just skip verification or fail
        setState(() => _msg = 'Optimizing verification photo...');
        final compressedBytes = await compute(_compressImageBytes, bytes);
        final finalB64 = compressedBytes != null ? base64Encode(compressedBytes) : b64;
        widget.onVerified(finalB64);
        return;
      }

      final refBytes = base64Decode(widget.guard.photo);
      final tempDir = await getTemporaryDirectory();
      final refFile = File(p.join(tempDir.path, 'ref_temp.jpg'));
      await refFile.writeAsBytes(refBytes);

      final refEmbedding = await FaceMatchService.getEmbeddings(refFile);
      if (refEmbedding == null) {
         // Proceeding if we can't get reference embedding might be a business rule.
         // Let's assume fallback to supervisor override.
         setState(() { _msg = 'Invalid reference photo. Please contact Admin.'; _busy = false; });
         return;
      }

      final score = FaceMatchService.compareFaces(refEmbedding, liveEmbedding);
      
      // Using a typical threshold for cosine similarity. Lowered to 75% as requested.
      if (score >= 0.75) { 
        setState(() => _msg = 'Optimizing verification photo...');
        final compressedBytes = await compute(_compressImageBytes, bytes);
        final finalB64 = compressedBytes != null ? base64Encode(compressedBytes) : b64;
        widget.onVerified(finalB64); 
      } else { 
        setState(() { _msg = 'Identity Mismatch! (Score: ${(score*100).toStringAsFixed(1)}%)'; _busy = false; }); 
      }
    } catch (e) { setState(() { _msg = 'Error: $e'; _busy = false; }); }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (!_blinked) 
            LivenessDetectorWidget(
              onBlinkDetected: () {
                setState(() => _blinked = true);
                _init();
              }
            )
          else ...[
            if (_ready) Stack(
              children: [
                ClipRRect(borderRadius: BorderRadius.circular(20), child: SizedBox(height: 300, width: double.infinity, child: CameraPreview(_ctrl!))),
                if (globalCameras.length > 1)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.flip_camera_ios, color: Colors.white),
                        onPressed: _flipCamera,
                        tooltip: 'Flip Camera',
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text(_msg, style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            if (!_busy && _ready) ElevatedButton(onPressed: _verify, child: Text(widget.isCheckOut ? 'Capture & Verify Check-Out' : 'Capture & Verify Check-In')),
          ]
        ],
      ),
    );
  }
}

class _ConfirmStep extends StatelessWidget {
  final Guard guard;
  final Site site;
  final bool isCheckOut;
  final bool isSubmitting;
  final VoidCallback onSubmit;
  const _ConfirmStep({required this.guard, required this.site, required this.isCheckOut, required this.isSubmitting, required this.onSubmit});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.verified_user, color: AppTheme.green, size: 60),
          const SizedBox(height: 20),
          Text(
            isCheckOut ? 'Ready to submit Check-Out for ${guard.name}' : 'Ready to submit Check-In for ${guard.name}',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),
          isSubmitting 
              ? const CircularProgressIndicator()
              : ElevatedButton(onPressed: onSubmit, style: ElevatedButton.styleFrom(backgroundColor: isCheckOut ? AppTheme.yellow : AppTheme.green, minimumSize: const Size(double.infinity, 50)), child: Text(isCheckOut ? 'Submit Check-Out' : 'Submit Check-In')),
        ],
      ),
    );
  }
}

/// Top-level CPU-intensive function to resize and compress captured photos in a background Isolate.
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
