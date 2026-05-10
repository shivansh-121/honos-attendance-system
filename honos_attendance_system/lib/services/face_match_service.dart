import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// Service for Face Recognition using MobileFaceNet (TFLite) and ML Kit for Cropping.
class FaceMatchService {
  static Interpreter? _interpreter;
  static bool _isInitialized = false;
  static final FaceDetector _detector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: false,
      enableLandmarks: false,
      enableClassification: false,
      performanceMode: FaceDetectorMode.fast,
    ),
  );

  /// Initializes the TFLite interpreter with the MobileFaceNet model.
  static Future<void> init() async {
    if (_isInitialized) return;
    try {
      _interpreter = await Interpreter.fromAsset('assets/models/mobilefacenet.tflite');
      _isInitialized = true;
      debugPrint("FaceMatchService: Model loaded successfully.");
    } catch (e) {
      debugPrint("FaceMatchService: Failed to load model. Error: $e");
    }
  }

  /// Extracts face embeddings from a given image file.
  /// It automatically detects the face, crops it, and extracts the embedding.
  static Future<List<double>?> getEmbeddings(File imageFile) async {
    if (!_isInitialized || _interpreter == null) {
      await init();
      if (!_isInitialized) return null;
    }

    try {
      // 1. Detect Face Bounds using ML Kit
      final inputImage = InputImage.fromFile(imageFile);
      final faces = await _detector.processImage(inputImage);

      if (faces.isEmpty) {
        debugPrint("FaceMatchService: No face detected in image.");
        return null;
      }

      final face = faces.first;
      final boundingBox = face.boundingBox;

      // 2. Read Image for Cropping
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) return null;

      // 3. Crop Image tightly to the face
      int x = max(0, boundingBox.left.toInt());
      int y = max(0, boundingBox.top.toInt());
      int w = min(image.width - x, boundingBox.width.toInt());
      int h = min(image.height - y, boundingBox.height.toInt());

      final croppedImage = img.copyCrop(image, x: x, y: y, width: w, height: h);

      // 4. Resize for MobileFaceNet standard input
      final resizedImage = img.copyResize(croppedImage, width: 112, height: 112);

      // 5. Convert image to float32 tensor [1, 112, 112, 3] with normalization
      var input = List.generate(1, (i) => List.generate(112, (y) => List.generate(112, (x) => List.generate(3, (c) => 0.0))));
      for (int py = 0; py < 112; py++) {
        for (int px = 0; px < 112; px++) {
          final pixel = resizedImage.getPixel(px, py);
          input[0][py][px][0] = (pixel.r - 127.5) / 128.0; 
          input[0][py][px][1] = (pixel.g - 127.5) / 128.0; 
          input[0][py][px][2] = (pixel.b - 127.5) / 128.0; 
        }
      }

      // 6. Run Inference
      final outputShape = _interpreter!.getOutputTensor(0).shape; // typically [1, 192]
      final outputSize = outputShape[1];
      
      var output = List.generate(1, (i) => List.filled(outputSize, 0.0));
      _interpreter!.run(input, output);

      return output[0];
    } catch (e) {
      debugPrint("FaceMatchService: Error extracting embeddings: $e");
      return null;
    }
  }

  /// Compares two embeddings and returns a similarity score (0.0 to 1.0).
  static double compareFaces(List<double> ref, List<double> live) {
    if (ref.length != live.length) return 0.0;
    double dot = 0.0, magA = 0.0, magB = 0.0;
    for (int i = 0; i < ref.length; i++) {
      dot += ref[i] * live[i];
      magA += ref[i] * ref[i];
      magB += live[i] * live[i];
    }
    if (magA == 0 || magB == 0) return 0.0;
    
    // Cosine similarity maps [-1, 1] to [0, 1]
    double cosine = dot / (sqrt(magA) * sqrt(magB));
    return (cosine + 1.0) / 2.0; 
  }

  static void dispose() {
    _interpreter?.close();
    _detector.close();
    _isInitialized = false;
  }
}
