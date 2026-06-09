import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
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

import '../../services/camera_service.dart';
import '../../services/permission_service.dart';
import '../../services/mobile_attendance_guard.dart';
import '../../widgets/base64_image_widget.dart';
import 'liveness_detector_widget.dart';

enum _Step { location, guard, liveness, confirmation }

class TakeAttendanceScreen extends ConsumerStatefulWidget {
  final Site site;
  final bool isCheckOutFlow;
  final Guard? preselectedGuard;
  final Attendance? existingRecord;
  /// When true, skip the GPS check step (GPS already verified by caller).
  final bool skipGpsCheck;

  const TakeAttendanceScreen({
    super.key,
    required this.site,
    this.isCheckOutFlow = false,
    this.preselectedGuard,
    this.existingRecord,
    this.skipGpsCheck = false,
  });

  @override
  ConsumerState<TakeAttendanceScreen> createState() =>
      _TakeAttendanceScreenState();
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
    if (widget.skipGpsCheck) {
      // GPS was already verified by ScanIdentifyScreen — skip to guard step
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() { _gpsOk = true; _checkingGps = false; _step = _Step.guard; });
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkGps());
    }
  }

  Future<void> _checkGps() async {
    if (!mounted) return;

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

    setState(() {
      _checkingGps = true;
      _gpsError = '';
    });

    try {
      final gpsEnabled = await PermissionService.isGpsEnabled();
      if (!gpsEnabled) throw Exception('GPS is disabled. Please turn it on.');

      final hasPerms = await PermissionService.requestSupervisorPermissions();
      if (!hasPerms) {
        throw Exception('Location and Camera permissions are required.');
      }

      Position pos = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.high)
          .timeout(const Duration(seconds: 10));

      if (pos.isMocked) {
        throw Exception(
            'Mock Location detected. Please disable Fake GPS apps.');
      }

      final dist = Geolocator.distanceBetween(
          pos.latitude, pos.longitude, widget.site.lat, widget.site.lng);
      if (dist <= widget.site.radius) {
        if (mounted) setState(() => _gpsOk = true);
      } else {
        if (mounted) {
          setState(() => _gpsError =
              'You are ${dist.toInt()}m from site. Required: within ${widget.site.radius.toInt()}m.');
        }
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

      final updatedGuard = _selectedGuard!.copyWith(
        siteId: widget.site.id,
        supervisorId: supervisor?.id ?? '',
      );
      await db.saveGuard(updatedGuard);

      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(_isCheckOut
                  ? 'Check-Out completed successfully!'
                  : 'Check-In completed successfully!'),
              backgroundColor: context.colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error saving attendance: $e'),
              backgroundColor: context.colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.bgBase,
      appBar: AppBar(
        title: Text(
            widget.isCheckOutFlow
                ? 'Check-Out Attendance'
                : 'Check-In Attendance',
            style: TextStyle(
                color: context.colors.txtPrimary, fontWeight: FontWeight.bold)),
        backgroundColor: context.colors.bgSurface,
        iconTheme: IconThemeData(color: context.colors.txtPrimary),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
              color: context.colors.bord.withValues(alpha: 0.5), height: 1),
        ),
      ),
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
  const _StepShell(
      {required this.stepNumber, required this.title, required this.child});
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            CircleAvatar(
                radius: 18,
                backgroundColor: context.colors.primary,
                child: Text(stepNumber,
                    style: TextStyle(
                        color: context.colors.txtPrimary,
                        fontWeight: FontWeight.bold))),
            const SizedBox(width: 12),
            Text(title,
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: context.colors.txtPrimary,
                    letterSpacing: -0.5))
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
  const _LocationStep(
      {required this.checking,
      required this.ok,
      required this.error,
      required this.onRetry,
      required this.onNext});
  @override
  Widget build(BuildContext context) {
    return _StepShell(
      stepNumber: '1',
      title: 'GPS Verification',
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (checking)
              const CircularProgressIndicator()
            else if (ok) ...[
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                    color: context.colors.green.withValues(alpha: 0.1),
                    shape: BoxShape.circle),
                child: Icon(Icons.check_circle,
                    color: context.colors.green, size: 80),
              ),
              const SizedBox(height: 24),
              Text('Location Verified',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: context.colors.txtPrimary),
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text('You are within the site boundaries.',
                  style: TextStyle(color: context.colors.txtSec),
                  textAlign: TextAlign.center),
              const SizedBox(height: 32),
              ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.colors.primary,
                    foregroundColor: context.colors.bgBase,
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  onPressed: onNext,
                  child: const Text('Continue to Select Guard',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold))),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                    color: context.colors.red.withValues(alpha: 0.1),
                    shape: BoxShape.circle),
                child: Icon(Icons.location_off,
                    color: context.colors.red, size: 80),
              ),
              const SizedBox(height: 24),
              Text('Location Error',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: context.colors.txtPrimary),
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(error,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.colors.txtSec)),
              const SizedBox(height: 32),
              ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.colors.red,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: onRetry,
                  child: const Text('Retry Verification',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold))),
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
  const _GuardStep(
      {required this.site, required this.isCheckOutFlow, required this.onNext});

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
        final supervisor = ref.watch(authProvider);
        return _StepShell(
          stepNumber: '2',
          title: 'Select Guard',
          child: Column(
            children: [
              TextField(
                onChanged: (v) => setState(() => _query = v),
                style: TextStyle(color: context.colors.txtPrimary),
                decoration: InputDecoration(
                  hintText: 'Search guard by name or ID...',
                  hintStyle: TextStyle(color: context.colors.txtMuted),
                  prefixIcon:
                      Icon(Icons.search_rounded, color: context.colors.primary),
                  filled: true,
                  fillColor: context.colors.bgSurface,
                  contentPadding: const EdgeInsets.symmetric(vertical: 18),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(
                          color: context.colors.bord.withValues(alpha: 0.5))),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide:
                          BorderSide(color: context.colors.primary, width: 2)),
                ),
              ),
              const SizedBox(height: 20),
              guardsAsync.when(
                data: (allGuards) {
                  final filtered = allGuards.where((g) {
                    final q = _query.toLowerCase();
                    return g.name.toLowerCase().contains(q) ||
                        g.empId.toLowerCase().contains(q);
                  }).toList();

                  if (filtered.isEmpty) {
                    return Center(
                        child: Padding(
                      padding: const EdgeInsets.all(40.0),
                      child: Column(
                        children: [
                          Icon(Icons.search_off,
                              size: 48,
                              color: context.colors.txtMuted
                                  .withValues(alpha: 0.3)),
                          const SizedBox(height: 16),
                          Text('No matching guards found.',
                              style: TextStyle(
                                  color: context.colors.txtMuted,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          if (_query.isNotEmpty)
                            TextButton(
                                onPressed: () => setState(() => _query = ''),
                                child: const Text('Clear Search')),
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
                        final existingRecord = sortedAtt
                            .where((a) =>
                                a.guardId == g.id &&
                                a.status.toLowerCase() == 'present')
                            .lastOrNull;
                        final isCheckedIn = existingRecord != null &&
                            existingRecord.checkOutTime.isEmpty;

                        if (widget.isCheckOutFlow) {
                          // Only show guards who are currently checked in AT THIS SITE
                          // AND checked in by THIS EXACT supervisor.
                          return isCheckedIn &&
                              existingRecord.siteId == widget.site.id &&
                              existingRecord.supervisorId == supervisor?.id;
                        } else {
                          // Check-In flow: Only show guards who are NOT currently checked in anywhere.
                          // (This allows them to check in again for a second shift if they previously checked out)
                          return !isCheckedIn;
                        }
                      }).toList();

                      if (strictlyFiltered.isEmpty) {
                        return Center(
                            child: Padding(
                          padding: const EdgeInsets.all(40.0),
                          child: Column(
                            children: [
                              Icon(
                                  widget.isCheckOutFlow
                                      ? Icons.logout
                                      : Icons.login,
                                  size: 48,
                                  color: context.colors.txtMuted
                                      .withValues(alpha: 0.3)),
                              const SizedBox(height: 16),
                              Text(
                                  widget.isCheckOutFlow
                                      ? 'No guards available for Check-Out.'
                                      : 'No guards available for Check-In.',
                                  style: TextStyle(
                                      color: context.colors.txtMuted,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center),
                            ],
                          ),
                        ));
                      }

                      return Column(
                        children: strictlyFiltered.map((g) {
                          final isLocal = g.siteId == widget.site.id;
                          final existingRecord = sortedAtt
                              .where((a) =>
                                  a.guardId == g.id &&
                                  a.status.toLowerCase() == 'present')
                              .lastOrNull;
                          final isCheckedIn = existingRecord != null &&
                              existingRecord.checkOutTime.isEmpty;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: context.colors.bgSurface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: context.colors.bord
                                      .withValues(alpha: 0.5)),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              leading: Container(
                                decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: context.colors.primary
                                            .withValues(alpha: 0.5),
                                        width: 2)),
                                child: ClipOval(
                                  child: SizedBox(
                                    width: 44,
                                    height: 44,
                                    child: g.photo.length > 200
                                        ? Base64ImageWidget(
                                            base64String: g.photo)
                                        : Icon(Icons.person,
                                            color: context.colors.txtMuted),
                                  ),
                                ),
                              ),
                              title: Row(
                                children: [
                                  Flexible(
                                      child: Text(g.name,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color:
                                                  context.colors.txtPrimary))),
                                  if (isLocal) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                          color: context.colors.green
                                              .withValues(alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(6)),
                                      child: Text('LOCAL',
                                          style: TextStyle(
                                              color: context.colors.green,
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ],
                              ),
                              subtitle: Text('ID: ${g.empId}',
                                  style: TextStyle(
                                      color: context.colors.txtSec,
                                      fontSize: 13)),
                              trailing: isCheckedIn
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                          color: context.colors.yellow
                                              .withValues(alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                      child: Text('Checked In',
                                          style: TextStyle(
                                              color: context.colors.yellow,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold)))
                                  : Icon(Icons.chevron_right,
                                      color: context.colors.primary),
                              onTap: () =>
                                  widget.onNext(g, isCheckedIn, existingRecord),
                            ),
                          );
                        }).toList(),
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
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
                        Icon(Icons.error_outline,
                            color: context.colors.red, size: 40),
                        const SizedBox(height: 12),
                        Text('Connection error. Please check your internet.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: context.colors.txtSec)),
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
  const _FaceMatchStep(
      {required this.guard,
      required this.isCheckOut,
      required this.onVerified});
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
        orElse: () => globalCameras.first);
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
    setState(() {
      _busy = true;
      _msg = 'Capturing photo...';
    });
    try {
      final xFile = await _ctrl!.takePicture();
      final bytes = await xFile.readAsBytes();
      final b64 = base64Encode(bytes);

      // Initialize FaceMatchService if not already done
      await FaceMatchService.init();

      // Extract embedding from live photo
      final liveEmbedding =
          await FaceMatchService.getEmbeddings(File(xFile.path));
      if (liveEmbedding == null) {
        setState(() {
          _msg = 'Could not extract face from live photo.';
          _busy = false;
        });
        return;
      }

      // Extract embedding from reference photo (guard.photo is base64)
      if (widget.guard.photo.length < 200) {
        // No reference photo, we might just skip verification or fail
        setState(() => _msg = 'Optimizing verification photo...');
        final compressedBytes = await compute(_compressImageBytes, bytes);
        final finalB64 =
            compressedBytes != null ? base64Encode(compressedBytes) : b64;
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
        setState(() {
          _msg = 'Invalid reference photo. Please contact Admin.';
          _busy = false;
        });
        return;
      }

      final score = FaceMatchService.compareFaces(refEmbedding, liveEmbedding);

      // Using a typical threshold for cosine similarity. Lowered to 75% as requested.
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
            LivenessDetectorWidget(onBlinkDetected: () {
              setState(() => _blinked = true);
              _init();
            })
          else ...[
            if (_ready)
              Stack(
                children: [
                  ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: context.colors.primary
                                    .withValues(alpha: 0.3),
                                width: 4),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          height: 300,
                          width: double.infinity,
                          child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: CameraPreview(_ctrl!)))),
                  if (globalCameras.length > 1)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.flip_camera_ios,
                              color: Colors.white),
                          onPressed: _flipCamera,
                          tooltip: 'Flip Camera',
                        ),
                      ),
                    ),
                ],
              ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(12)),
              child: Text(_msg,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.white),
                  textAlign: TextAlign.center),
            ),
            const SizedBox(height: 24),
            if (!_busy && _ready)
              ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.colors.primary,
                    foregroundColor: context.colors.bgBase,
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.camera_alt),
                  onPressed: _verify,
                  label: Text(
                      widget.isCheckOut
                          ? 'Capture & Verify Check-Out'
                          : 'Capture & Verify Check-In',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16))),
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
  const _ConfirmStep(
      {required this.guard,
      required this.site,
      required this.isCheckOut,
      required this.isSubmitting,
      required this.onSubmit});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
                color: context.colors.green.withValues(alpha: 0.1),
                shape: BoxShape.circle),
            child: Icon(Icons.verified_user_rounded,
                color: context.colors.green, size: 80),
          ),
          const SizedBox(height: 24),
          Text(
            isCheckOut
                ? 'Ready to submit Check-Out'
                : 'Ready to submit Check-In',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: context.colors.txtPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            'for ${guard.name}',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: context.colors.txtSec),
          ),
          const SizedBox(height: 40),
          isSubmitting
              ? const CircularProgressIndicator()
              : ElevatedButton.icon(
                  onPressed: onSubmit,
                  icon: const Icon(Icons.cloud_upload),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isCheckOut
                        ? context.colors.yellow
                        : context.colors.green,
                    foregroundColor: isCheckOut ? Colors.black : Colors.white,
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  label: Text(
                      isCheckOut ? 'Submit Check-Out' : 'Submit Check-In',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16))),
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
