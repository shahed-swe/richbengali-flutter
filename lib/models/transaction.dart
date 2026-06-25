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
      durationSeconds:
          (json['duration_sec'] ?? json['duration_seconds'] ?? 0) is num
              ? ((json['duration_sec'] ??
                          json['duration_seconds'] ??
                          0) as num)
                      .toInt()
              : 0,
      amount:
          (json['amount'] ?? 0) is num
              ? ((json['amount'] ?? 0) as num).toDouble()
              : 0.0,
      type: (json['type'] ?? 'credit').toString(),
      createdAt: json['created_at']?.toString(),
    );
  }
}
