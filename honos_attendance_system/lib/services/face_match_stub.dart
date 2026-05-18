import 'dart:io';

class FaceMatchService {
  static Future<void> init() async {
    // Stub for web: Face recognition is not supported on web in this implementation.
  }

  static Future<List<double>?> getEmbeddings(File imageFile) async {
    return null; // Face detection requires native FFI
  }

  static double compareFaces(List<double> ref, List<double> live) {
    return 0.0;
  }

  static void dispose() {
    // No-op for web
  }
}
