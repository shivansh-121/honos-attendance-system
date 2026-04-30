import 'dart:io';
import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../../services/camera_service.dart';
import '../../app_theme.dart';

class LivenessDetectorWidget extends StatefulWidget {
  final VoidCallback onBlinkDetected;

  const LivenessDetectorWidget({super.key, required this.onBlinkDetected});

  @override
  State<LivenessDetectorWidget> createState() => _LivenessDetectorWidgetState();
}

class _LivenessDetectorWidgetState extends State<LivenessDetectorWidget> {
  CameraController? _controller;
  final FaceDetector _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
    enableClassification: true, // Needed for eye open probabilities
    enableLandmarks: false,
    enableContours: false,
    enableTracking: false,
    minFaceSize: 0.15,
    performanceMode: FaceDetectorMode.fast,
  ));

  bool _isProcessingFrame = false;
  bool _blinkDetected = false;
  bool _eyesWereOpen = false;
  DateTime _lastFrameTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    if (globalCameras.isEmpty) await initCameras();
    if (globalCameras.isEmpty) return;

    // Favor front camera for selfies
    var camera = globalCameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => globalCameras.first,
    );

    _controller = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );

    await _controller!.initialize();
    if (!mounted) return;

    _controller!.startImageStream(_processCameraFrame);
    setState(() {});
  }

  Future<void> _processCameraFrame(CameraImage image) async {
    if (_isProcessingFrame || _blinkDetected) return;

    // Throttle to max 4 frames per second to avoid tight loop
    final now = DateTime.now();
    if (now.difference(_lastFrameTime).inMilliseconds < 250) return;
    _lastFrameTime = now;
    _isProcessingFrame = true;

    try {
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) return;

      final faces = await _faceDetector.processImage(inputImage);

      if (faces.isNotEmpty) {
        final face = faces.first;
        final leftEye = face.leftEyeOpenProbability;
        final rightEye = face.rightEyeOpenProbability;

        if (leftEye != null && rightEye != null) {
          // If eyes are mostly open, mark state (relaxed from 0.8 to 0.6)
          if (leftEye > 0.6 && rightEye > 0.6) {
            _eyesWereOpen = true;
          }

          // If eyes close after being open -> BLINK (relaxed from 0.2 to 0.35)
          if (_eyesWereOpen && leftEye < 0.35 && rightEye < 0.35) {
            _blinkDetected = true;
            _controller?.stopImageStream();
            widget.onBlinkDetected();
          }
        }
      }
    } catch (e) {
      debugPrint("Face detection error: $e");
    } finally {
      if (mounted) _isProcessingFrame = false;
    }
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    if (_controller == null) return null;
    final camera = _controller!.description;
    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      var rotationCompensation = 0; // assuming portrait
      if (camera.lensDirection == CameraLensDirection.front) {
        rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
      } else {
        rotationCompensation =
            (sensorOrientation - rotationCompensation + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    }

    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null ||
        (Platform.isAndroid && format != InputImageFormat.nv21) ||
        (Platform.isIOS && format != InputImageFormat.bgra8888)) {
      return null;
    }

    if (image.planes.isEmpty) return null;

    return InputImage.fromBytes(
      bytes: image.planes[0].bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes[0].bytesPerRow,
      ),
    );
  }

  @override
  void dispose() {
    _controller?.stopImageStream();
    _controller?.dispose();
    _faceDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
        const Text(
          'Please look at the camera and BLINK your eyes to verify liveness.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.yellow, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
