import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;

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
      final options = InterpreterOptions();
      try {
        if (Platform.isAndroid) {
          options.addDelegate(GpuDelegateV2());
        } else if (Platform.isIOS) {
          options.addDelegate(GpuDelegate());
        }
      } catch (e) {
        debugPrint("FaceMatchService: GPU delegate failed to load: $e");
      }

      _interpreter = await Interpreter.fromAsset('assets/models/mobilefacenet.tflite', options: options);
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

      // 2. Decode using package:image to properly handle EXIF orientation
      final bytes = await imageFile.readAsBytes();
      img.Image? decodedImage = img.decodeImage(bytes);
      if (decodedImage == null) return null;

      // Bake orientation so coordinates match ML Kit's bounding box
      decodedImage = img.bakeOrientation(decodedImage);

      // 3. Crop to the exact face bounding box safely
      int cropX = max(0, boundingBox.left.toInt());
      int cropY = max(0, boundingBox.top.toInt());
      int cropRight = min(decodedImage.width, boundingBox.right.toInt());
      int cropBottom = min(decodedImage.height, boundingBox.bottom.toInt());
      int cropWidth = cropRight - cropX;
      int cropHeight = cropBottom - cropY;

      if (cropWidth <= 0 || cropHeight <= 0) {
        debugPrint("FaceMatchService: Invalid crop dimensions.");
        return null;
      }

      final croppedImg = img.copyCrop(
        decodedImage,
        x: cropX,
        y: cropY,
        width: cropWidth,
        height: cropHeight,
      );

      // 4. Scale to 112x112 for the model
      final resizedImg = img.copyResize(croppedImg, width: 112, height: 112);

      // 5. Convert image to float32 tensor [1, 112, 112, 3] with normalization
      var input = List.generate(1, (i) => List.generate(112, (y) => List.generate(112, (x) => List.generate(3, (c) => 0.0))));
      
      for (int py = 0; py < 112; py++) {
        for (int px = 0; px < 112; px++) {
          final pixel = resizedImg.getPixel(px, py);
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
