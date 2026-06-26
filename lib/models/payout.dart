import '../core/json_parse.dart';

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
      amountUsd: asDouble(json['amount_usd'] ?? json['amount']),
      createdAt: json['created_at']?.toString(),
    );
  }
}
