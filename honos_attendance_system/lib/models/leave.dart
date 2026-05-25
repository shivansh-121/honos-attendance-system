class Leave {
  final String id;
  final String employeeId;
  final String employeeName;
  final String fromDate;
  final String toDate;
  final String reason;
  final String status; // 'pending', 'approved', 'declined'
  final String createdAt;

  const Leave({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.fromDate,
    required this.toDate,
    required this.reason,
    this.status = 'pending',
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'employeeId': employeeId,
        'employeeName': employeeName,
        'fromDate': fromDate,
        'toDate': toDate,
        'reason': reason,
        'status': status,
        'createdAt': createdAt,
      };

  factory Leave.fromJson(Map<String, dynamic> j) => Leave(
        id: j['id'] ?? '',
        employeeId: j['employeeId'] ?? '',
        employeeName: j['employeeName'] ?? '',
        fromDate: j['fromDate'] ?? '',
        toDate: j['toDate'] ?? '',
        reason: j['reason'] ?? '',
        status: j['status'] ?? 'pending',
        createdAt: j['createdAt'] ?? '',
      );
}
