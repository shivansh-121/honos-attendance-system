class AppNotification {
  final String id;
  final String type; // 'guard_added', 'edit_request', 'edit_approved', 'edit_rejected'
  final String title;
  final String message;
  final String guardId;
  final String supervisorId;
  final String timestamp;
  final bool isRead;
  final String status; // 'pending', 'approved', 'rejected'

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.guardId,
    required this.supervisorId,
    required this.timestamp,
    this.isRead = false,
    this.status = 'pending',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'title': title,
    'message': message,
    'guardId': guardId,
    'supervisorId': supervisorId,
    'timestamp': timestamp,
    'isRead': isRead,
    'status': status,
  };

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
    id: j['id'] ?? '',
    type: j['type'] ?? '',
    title: j['title'] ?? '',
    message: j['message'] ?? '',
    guardId: j['guardId'] ?? '',
    supervisorId: j['supervisorId'] ?? '',
    timestamp: j['timestamp'] ?? '',
    isRead: j['isRead'] ?? false,
    status: j['status'] ?? 'pending',
  );
}
