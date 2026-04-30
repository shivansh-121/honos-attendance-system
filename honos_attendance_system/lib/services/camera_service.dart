import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

// Provides global access to available cameras to avoid fetching them multiple times.
List<CameraDescription> globalCameras = [];

Future<void> initCameras() async {
  try {
    if (!kIsWeb) {
      globalCameras = await availableCameras();
    }
  } catch (e) {
    debugPrint("Error initializing cameras: $e");
  }
}
