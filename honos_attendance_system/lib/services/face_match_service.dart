import 'dart:io';
import 'dart:math';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// Compares a live camera face against a stored guard reference photo.
/// Returns a score from 0.0 (no match) to 1.0 (perfect match).
class FaceMatchService {
  static final FaceDetector _detector = FaceDetector(
    options: FaceDetectorOptions(
      enableLandmarks: true,
      enableContours: true,
      enableClassification: true,
      performanceMode: FaceDetectorMode.accurate,
      minFaceSize: 0.1,
    ),
  );

  /// Detects faces in a file and returns them.
  static Future<List<Face>> detectFromFile(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    return await _detector.processImage(inputImage);
  }

  /// Compares two face lists and returns similarity score (0-1).
  /// Uses inter-eye distance ratio and landmark relative positions.
  static double compareFaces(List<Face> referenceFaces, List<Face> liveFaces) {
    if (referenceFaces.isEmpty || liveFaces.isEmpty) return 0.0;

    final ref = _extractFeatures(referenceFaces.first);
    final live = _extractFeatures(liveFaces.first);

    if (ref == null || live == null) return 0.0;

    // Compare normalized feature vectors
    double similarity = _cosineSimilarity(ref, live);
    return similarity.clamp(0.0, 1.0);
  }

  static List<double>? _extractFeatures(Face face) {
    final landmarks = face.landmarks;

    final leftEye = landmarks[FaceLandmarkType.leftEye];
    final rightEye = landmarks[FaceLandmarkType.rightEye];
    final nose = landmarks[FaceLandmarkType.noseBase];
    final leftMouth = landmarks[FaceLandmarkType.leftMouth];
    final rightMouth = landmarks[FaceLandmarkType.rightMouth];

    if (leftEye == null ||
        rightEye == null ||
        nose == null ||
        leftMouth == null ||
        rightMouth == null) {
      return null;
    }

    // Use inter-eye distance as normalizer
    final eyeDist = _dist(leftEye.position, rightEye.position);
    if (eyeDist < 1) return null;

    // Normalize all feature positions relative to eye center and eye distance
    final eyeCenterX = (leftEye.position.x + rightEye.position.x) / 2;
    final eyeCenterY = (leftEye.position.y + rightEye.position.y) / 2;

    List<double> features = [
      // Nose relative to eye center
      (nose.position.x - eyeCenterX) / eyeDist,
      (nose.position.y - eyeCenterY) / eyeDist,
      // Mouth center relative to eye center
      ((leftMouth.position.x + rightMouth.position.x) / 2 - eyeCenterX) /
          eyeDist,
      ((leftMouth.position.y + rightMouth.position.y) / 2 - eyeCenterY) /
          eyeDist,
      // Mouth width relative to eye distance
      _dist(leftMouth.position, rightMouth.position) / eyeDist,
      // Left eye to nose
      _dist(leftEye.position, nose.position) / eyeDist,
      // Right eye to nose
      _dist(rightEye.position, nose.position) / eyeDist,
    ];

    return features;
  }

  static double _dist(Point a, Point b) {
    final dx = (a.x - b.x).toDouble();
    final dy = (a.y - b.y).toDouble();
    return sqrt(dx * dx + dy * dy);
  }

  static double _cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) return 0.0;
    double dot = 0, magA = 0, magB = 0;
    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      magA += a[i] * a[i];
      magB += b[i] * b[i];
    }
    if (magA == 0 || magB == 0) return 0.0;
    return dot / (sqrt(magA) * sqrt(magB));
  }

  static void dispose() => _detector.close();
}
