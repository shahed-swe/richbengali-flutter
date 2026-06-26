import '../core/json_parse.dart';

class Transaction {
  final String id;
  final String? peerName;
  final int durationSeconds;
  final double amount;
  final String type; // 'credit' | 'debit'
  final String? createdAt;

  const Transaction({
    required this.id,
    this.peerName,
    this.durationSeconds = 0,
    required this.amount,
    this.type = 'credit',
    this.createdAt,
  });

  bool get isCredit => type == 'credit' || amount >= 0;

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      peerName:
          json['peer_name']?.toString() ??
          json['user_name']?.toString() ??
          json['name']?.toString(),
      durationSeconds: asInt(json['duration_sec'] ?? json['duration_seconds']),
      amount: asDouble(json['amount']),
      type: (json['type'] ?? 'credit').toString(),
      createdAt: json['created_at']?.toString(),
    );
  }
}
