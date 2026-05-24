import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart'
    if (dart.library.html) 'background_service_stub.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    if (dart.library.html) 'notifications_stub.dart';
import 'package:geolocator/geolocator.dart';
import '../firebase_options.dart';

// ── Notification Channel Constants ───────────────────────────────────────────
const _notifChannelId = 'honos_location_channel';
const _notifChannelName = 'Honos Live Tracking';
const _notifId = 888;

// ── Called once on app startup ────────────────────────────────────────────────
Future<void> initBackgroundService() async {
  if (kIsWeb) return; // Background tracking not supported on web

  final service = FlutterBackgroundService();

  // Create notification channel (Android 8+)
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    _notifChannelId,
    _notifChannelName,
    description: 'Used for Honos supervisor live location tracking.',
    importance: Importance.low,
  );

  final FlutterLocalNotificationsPlugin notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  await notificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onBackgroundServiceStart,
      autoStart: false, // Only starts when we call service.startService()
      isForegroundMode: true,
      notificationChannelId: _notifChannelId,
      initialNotificationTitle: 'Honos Security – On Duty',
      initialNotificationContent: 'Live location is being shared with admin.',
      foregroundServiceNotificationId: _notifId,
      foregroundServiceTypes: [AndroidForegroundType.location],
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onBackgroundServiceStart,
      onBackground: onIosBackground,
    ),
  );
}

// ── iOS background handler (required) ────────────────────────────────────────
@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

// ── Main background isolate entry point ──────────────────────────────────────
@pragma('vm:entry-point')
void onBackgroundServiceStart(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  // Re-initialize Firebase in the background isolate
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    debugPrint('Background Firebase init failed: $e');
    // We cannot continue without Firebase, so we return to let the isolate stop cleanly
    return;
  }

  final firestore = FirebaseFirestore.instance;
  StreamSubscription<Position>? positionSub;

  // Receive supervisorId from the main isolate
  service.on('start_tracking').listen((event) async {
    final supervisorId = event?['supervisorId'] as String?;
    if (supervisorId == null) return;

    // Update notification
    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: 'Honos Security – On Duty',
        content: 'Live tracking active. Tap to open app.',
      );
    }

    // Start listening to GPS stream
    positionSub?.cancel();
    positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 15, // push every 15 metres
      ),
    ).listen((Position pos) async {
      final timestamp = DateTime.now().toIso8601String();
      // 1. Update live dot position
      await firestore
          .collection('live_supervisors')
          .doc(supervisorId)
          .set({
        'lat': pos.latitude,
        'lng': pos.longitude,
        'timestamp': timestamp,
        'status': 'on-duty',
      }, SetOptions(merge: true));

      // 2. Append breadcrumb to path sub-collection
      await firestore
          .collection('live_supervisors')
          .doc(supervisorId)
          .collection('path_points')
          .doc(timestamp)
          .set({
        'lat': pos.latitude,
        'lng': pos.longitude,
        'ts': timestamp,
      });
    });
  });

  // Stop signal from main isolate
  service.on('stop_tracking').listen((event) async {
    final supervisorId = event?['supervisorId'] as String?;
    positionSub?.cancel();
    positionSub = null;

    if (supervisorId != null) {
      // Mark off-duty
      await firestore
          .collection('live_supervisors')
          .doc(supervisorId)
          .update({'status': 'off-duty'});

      // Clear path points for next session
      final pathRef = firestore
          .collection('live_supervisors')
          .doc(supervisorId)
          .collection('path_points');

      final docs = await pathRef.get();
      for (final doc in docs.docs) {
        await doc.reference.delete();
      }
    }

    service.stopSelf();
  });
}

/// Robust, fire-and-forget toggle for tracking.
/// Handles all initialization and error cases silently to prevent UI hangs.
void toggleTracking(bool start, String supervisorId) {
  if (kIsWeb) return;

  // We use a microtask to ensure we don't block the caller (UI thread)
  Future.microtask(() async {
    try {
      final service = FlutterBackgroundService();
      
      if (start) {
        bool isRunning = await service.isRunning();
        if (!isRunning) {
          // ensure it's configured (though main should have done it)
          await service.startService();
        }
        service.invoke('start_tracking', {'supervisorId': supervisorId});
      } else {
        service.invoke('stop_tracking', {'supervisorId': supervisorId});
      }
    } catch (e) {
      debugPrint('🚨 toggleTracking Error: $e');
    }
  });
}

/// Checks if the background service is currently running.
/// Safe to call on all platforms.
Future<bool> isServiceRunning() async {
  if (kIsWeb) return false;
  try {
    final service = FlutterBackgroundService();
    return await service.isRunning();
  } catch (_) {
    return false;
  }
}


