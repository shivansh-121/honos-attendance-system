// Stub for web platform — flutter_local_notifications is not supported on web.

class FlutterLocalNotificationsPlugin {
  Future<void> initialize(dynamic initSettings, {dynamic onDidReceiveNotificationResponse}) async {}

  T? resolvePlatformSpecificImplementation<T>() => null;
}

class AndroidFlutterLocalNotificationsPlugin {
  Future<void> createNotificationChannel(dynamic channel) async {}
}

class AndroidNotificationChannel {
  final String id;
  final String name;
  final String? description;
  final dynamic importance;
  const AndroidNotificationChannel(this.id, this.name, {this.description, this.importance});
}

class Importance {
  static const low = Importance._();
  static const high = Importance._();
  const Importance._();
}
