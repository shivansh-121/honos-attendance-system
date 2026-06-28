class Advance {
  final String id;
  final String userId;
  final String userType; // 'guard', 'supervisor', 'executive'
  final double amount;
  final String date;
  final String reason;
  final String type; // 'advance', 'uniform', 'mess', 'other'
  final String otherExpenseName;

  const Advance({
    required this.id,
    required this.userId,
    required this.userType,
    required this.amount,
    required this.date,
    this.reason = '',
    this.type = 'advance',
    this.otherExpenseName = '',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'userType': userType,
    'amount': amount,
    'date': date,
    'reason': reason,
    'type': type,
    'otherExpenseName': otherExpenseName,
  };

  factory Advance.fromJson(Map<String, dynamic> j) => Advance(
    id: j['id'] ?? '',
    userId: j['userId'] ?? '',
    userType: j['userType'] ?? 'guard',
    amount: (j['amount'] ?? 0).toDouble(),
    date: j['date'] ?? '',
    reason: j['reason'] ?? '',
    type: j['type'] ?? 'advance',
    otherExpenseName: j['otherExpenseName'] ?? '',
  );
}
