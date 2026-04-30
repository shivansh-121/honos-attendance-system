// Stub for web platform — flutter_background_service is not supported on web.
// This file satisfies the conditional import in background_location_service.dart.

class FlutterBackgroundService {
  Future<bool> startService() async => false;
  void invoke(String method, [Map<String, dynamic>? args]) {}
  Stream<Map<String, dynamic>?> on(String method) => const Stream.empty();
  Future<bool> isRunning() async => false;
  Future<void> configure({
    required AndroidConfiguration androidConfiguration,
    required IosConfiguration iosConfiguration,
  }) async {}
}

class ServiceInstance {
  void stopSelf() {}
  void invoke(String method, [Map<String, dynamic>? args]) {}
  Stream<Map<String, dynamic>?> on(String method) => const Stream.empty();
}

class AndroidServiceInstance extends ServiceInstance {
  void setAsForegroundService() {}
  void setAsBackgroundService() {}
  void setForegroundNotificationInfo({String? title, String? content}) {}
}

class AndroidConfiguration {
  final Function onStart;
  final bool autoStart;
  final bool isForegroundMode;
  final String? notificationChannelId;
  final String? initialNotificationTitle;
  final String? initialNotificationContent;
  final int? foregroundServiceNotificationId;
  final List<AndroidForegroundType>? foregroundServiceTypes;

  AndroidConfiguration({
    required this.onStart,
    this.autoStart = true,
    this.isForegroundMode = true,
    this.notificationChannelId,
    this.initialNotificationTitle,
    this.initialNotificationContent,
    this.foregroundServiceNotificationId,
    this.foregroundServiceTypes,
  });
}

class IosConfiguration {
  final bool autoStart;
  final Function onForeground;
  final Function onBackground;

  IosConfiguration({
    this.autoStart = true,
    required this.onForeground,
    required this.onBackground,
  });
}

enum AndroidForegroundType {
  location,
  microphone,
  camera,
}
