import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../../services/camera_service.dart';
import '../../app_theme.dart';
import 'package:flutter/foundation.dart';

class LivenessDetectorWidget extends StatefulWidget {
  final VoidCallback onBlinkDetected;

  const LivenessDetectorWidget({super.key, required this.onBlinkDetected});

  @override
  State<LivenessDetectorWidget> createState() => _LivenessDetectorWidgetState();
}

class _LivenessDetectorWidgetState extends State<LivenessDetectorWidget> {
  CameraController? _controller;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  String? _error;

  Future<void> _initCamera() async {
    try {
      if (globalCameras.isEmpty) await initCameras();
      if (globalCameras.isEmpty) {
        if (mounted) setState(() => _error = 'No cameras found on device.');
        return;
      }

      var camera = globalCameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => globalCameras.first,
      );

      _controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _controller!.initialize();
      if (!mounted) return;

      setState(() {});
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Camera init failed: $e';
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Text(_error!, style: const TextStyle(color: Colors.red)),
        ),
      );
    }

    if (_controller == null || !_controller!.value.isInitialized) {
      return const Center(
          child: Padding(
        padding: EdgeInsets.all(32.0),
        child: CircularProgressIndicator(),
      ));
    }

    return Column(
      children: [
        Container(
          height: 300,
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.primary, width: 2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: CameraPreview(_controller!),
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: widget.onBlinkDetected,
          icon: const Icon(Icons.check_circle),
          label: const Text('Simulate Liveness (To be replaced)'),
        )
      ],
    );
  }
}
