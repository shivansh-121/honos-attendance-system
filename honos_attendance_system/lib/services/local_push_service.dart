import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_service.dart';
import 'db_service.dart';
// Conditionally import flutter_local_notifications to avoid web build errors if needed
// Actually, flutter_local_notifications supports web partially, or we can just ignore it on web.

class LocalPushService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized || kIsWeb) return;

    const androidInitialize = AndroidInitializationSettings('@mipmap/launcher_icon');
    const DarwinInitializationSettings iosInitialize = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initializationSettings = InitializationSettings(
      android: androidInitialize,
      iOS: iosInitialize,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (response) {
        // Handle notification tap here if needed
      },
    );

    if (Platform.isAndroid) {
      final androidImplementation = _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidImplementation?.requestNotificationsPermission();
    }

    _initialized = true;
  }

  static Future<void> showNotification({required String title, required String body}) async {
    if (!_initialized || kIsWeb) return;

    const androidDetails = AndroidNotificationDetails(
      'honos_channel', 
      'Honos Notifications',
      channelDescription: 'Alerts for Honos Attendance System',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/launcher_icon',
      enableVibration: true,
    );
    
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      DateTime.now().millisecond, 
      title, 
      body, 
      notificationDetails,
    );
  }
}

final pushNotificationManagerProvider = Provider<void>((ref) {
  final user = ref.watch(authProvider);
  if (user == null) return;

  final notificationsAsync = ref.watch(notificationsStreamProvider);
  
  // Track known IDs so we don't fire for old ones on load
  Set<String> knownIds = {};
  bool isFirstLoad = true;

  notificationsAsync.whenData((notifications) {
    if (isFirstLoad) {
      for (var n in notifications) {
        knownIds.add(n.id);
      }
      isFirstLoad = false;
      return;
    }

    // After first load, check for newly added notifications
    for (var n in notifications) {
      if (!knownIds.contains(n.id)) {
        knownIds.add(n.id);
        
        // Only notify if it's meant for this user
        bool shouldNotify = false;
        if (user.role == 'admin' && (n.type == 'edit_request' || n.type == 'guard_added')) {
          shouldNotify = true;
        } else if (user.role == 'supervisor' && n.supervisorId == user.id && (n.type == 'edit_approved' || n.type == 'edit_rejected')) {
          shouldNotify = true;
        }

        if (shouldNotify && !n.isRead) {
          LocalPushService.showNotification(title: n.title, body: n.message);
        }
      }
    }
  });
});
