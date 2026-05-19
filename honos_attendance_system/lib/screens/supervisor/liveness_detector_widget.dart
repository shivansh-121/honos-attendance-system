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
  CameraLensDirection _currentDirection = CameraLensDirection.front;

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
        (c) => c.lensDirection == _currentDirection,
        orElse: () => globalCameras.first,
      );

      _controller = CameraController(
        camera,
        ResolutionPreset.low,
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

  Future<void> _flipCamera() async {
    if (globalCameras.length < 2) return;
    
    setState(() {
      _currentDirection = _currentDirection == CameraLensDirection.front 
          ? CameraLensDirection.back 
          : CameraLensDirection.front;
    });

    await _controller?.dispose();
    _controller = null;
    await _initCamera();
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
        Stack(
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
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: widget.onBlinkDetected,
          icon: const Icon(Icons.check_circle),
          label: const Text('Confirm Presence'),
        )
      ],
    );
  }
}
