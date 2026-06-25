class Payout {
  final String id;
  final String? provider;
  final String status; // 'pending' | 'completed' | 'failed'
  final double amountUsd;
  final String? createdAt;

  const Payout({
    required this.id,
    this.provider,
    this.status = 'pending',
    required this.amountUsd,
    this.createdAt,
  });

  factory Payout.fromJson(Map<String, dynamic> json) {
    return Payout(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      provider:
          json['provider']?.toString() ??
          json['method']?.toString() ??
          json['type']?.toString(),
      status: (json['status'] ?? 'pending').toString(),
      amountUsd:
          (json['amount_usd'] ?? json['amount'] ?? 0) is num
              ? ((json['amount_usd'] ?? json['amount'] ?? 0) as num).toDouble()
              : 0.0,
      createdAt: json['created_at']?.toString(),
    );
  }
}
