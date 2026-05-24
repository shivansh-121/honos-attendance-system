class Advance {
  final String id;
  final String userId;
  final String userType; // 'guard' or 'supervisor'
  final double amount;
  final String date;
  final String reason;

  const Advance({
    required this.id,
    required this.userId,
    required this.userType,
    required this.amount,
    required this.date,
    this.reason = '',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'userType': userType,
    'amount': amount,
    'date': date,
    'reason': reason,
  };

  factory Advance.fromJson(Map<String, dynamic> j) => Advance(
    id: j['id'] ?? '',
    userId: j['userId'] ?? '',
    userType: j['userType'] ?? 'guard',
    amount: (j['amount'] ?? 0).toDouble(),
    date: j['date'] ?? '',
    reason: j['reason'] ?? '',
  );
}
