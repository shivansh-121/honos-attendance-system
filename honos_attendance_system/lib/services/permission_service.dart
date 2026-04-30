import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';

class PermissionService {
  /// Request all permissions needed for a supervisor (Camera, Location, Background Location)
  static Future<bool> requestSupervisorPermissions() async {
    if (kIsWeb) return true;

    // 1. Camera (for liveness check)
    final cameraStatus = await Permission.camera.request();
    if (!cameraStatus.isGranted) return false;

    // 2. Location (Foreground)
    final locationStatus = await Permission.location.request();
    if (!locationStatus.isGranted) return false;

    // 3. Background Location (Critical for on-duty tracking)
    // Note: On Android 10+, this MUST be requested AFTER foreground location.
    if (!await Permission.locationAlways.isGranted) {
      final bgStatus = await Permission.locationAlways.request();
      if (!bgStatus.isGranted) {
        // We can still function without background location, but tracking will only work in foreground.
        // For Honos, we prefer it to be granted.
        debugPrint('Background location permission denied');
      }
    }

    // 4. Notifications (For the foreground service on Android 13+)
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }

    return true;
  }

  /// Check if GPS is actually enabled on the device
  static Future<bool> isGpsEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }
}
