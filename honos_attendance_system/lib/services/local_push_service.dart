import 'dart:io';
import 'dart:ui';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../main.dart';
import '../screens/admin/notifications_screen.dart';
import '../screens/user_profile_screen.dart';
import 'auth_service.dart';
import 'db_service.dart';

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
        if (response.payload != null) {
          try {
            final payload = jsonDecode(response.payload!);
            final role = payload['role'];
            if (role == 'admin') {
              navigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
            } else {
              navigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => const UserProfileScreen()));
            }
          } catch (e) {
            debugPrint('Error parsing notification payload: $e');
          }
        }
      },
    );

    if (Platform.isAndroid) {
      final androidImplementation = _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidImplementation?.requestNotificationsPermission();
      
      // Explicitly request POST_NOTIFICATIONS for Android 13+
      if (await Permission.notification.isDenied) {
        await Permission.notification.request();
      }
    }

    _initialized = true;
  }

  static Future<void> showNotification({required String title, required String body, String? payload}) async {
    if (!_initialized || kIsWeb) return;

    const androidDetails = AndroidNotificationDetails(
      'honos_channel', 
      'Honos Notifications',
      channelDescription: 'Alerts for Honos Attendance System',
      importance: Importance.max,
      priority: Priority.high,
      icon: 'ic_notification',
      color: Color(0xFF3B82F6), // context.colors.primary

      largeIcon: DrawableResourceAndroidBitmap('app_logo'),
      enableVibration: true,
      ledColor: Color(0xFFE63946),
      ledOnMs: 1000,
      ledOffMs: 500,
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
      payload: payload,
    );
  }

  static Future<void> showPeriodicNotification({required String title, required String body}) async {
    if (!_initialized || kIsWeb) return;

    const androidDetails = AndroidNotificationDetails(
      'honos_periodic', 
      'Honos Periodic Alerts',
      channelDescription: 'Periodic alerts for Honos',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      icon: 'ic_notification',
      color: Color(0xFF3B82F6),

      largeIcon: DrawableResourceAndroidBitmap('app_logo'),
    );
    
    const iosDetails = DarwinNotificationDetails();

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.periodicallyShow(
      888, 
      title, 
      body, 
      RepeatInterval.daily, 
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  static Future<void> cancelPeriodicNotification() async {
    if (!_initialized || kIsWeb) return;
    await _notificationsPlugin.cancel(888);
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
        if (user.role == 'admin') {
          shouldNotify = true;
        } else if (user.role == 'supervisor') {
          if (n.supervisorId == user.id && (n.type == 'edit_approved' || n.type == 'edit_rejected')) {
            shouldNotify = true;
          }
        } else {
          // Employee / Executive
          if (n.type != 'edit_request' && (n.supervisorId == user.id || n.guardId == user.id)) {
            shouldNotify = true;
          }
        }

        if (shouldNotify && !n.isRead) {
          LocalPushService.showNotification(
            title: n.title, 
            body: n.message,
            payload: jsonEncode({'type': n.type, 'role': user.role}),
          );
        }
      }
    }
  });
});
