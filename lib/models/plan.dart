import '../core/json_parse.dart';

class Plan {
  final String priceId;
  final String label;
  final double amountUsd;
  final int callMinutes;
  final List<String> features;
  final bool isCurrent;

  const Plan({
    required this.priceId,
    required this.label,
    required this.amountUsd,
    required this.callMinutes,
    this.features = const [],
    this.isCurrent = false,
  });

  factory Plan.fromJson(Map<String, dynamic> json) {
    final featuresList = json['features'];
    final List<String> features;
    if (featuresList is List) {
      features = featuresList.map((e) => e.toString()).toList();
    } else {
      features = const [];
    }

    return Plan(
      priceId: (json['stripe_price_id'] ?? json['price_id'] ?? '').toString(),
      label: (json['label'] ?? json['name'] ?? '').toString(),
      amountUsd: asDouble(json['amount_usd'] ?? json['price'] ?? json['amount']),
      callMinutes: asInt(json['call_minutes'] ?? json['minutes']),
      features: features,
      isCurrent: json['is_current'] == true || json['current'] == true,
    );
  }

  Plan copyWith({bool? isCurrent}) {
    return Plan(
      priceId: priceId,
      label: label,
      amountUsd: amountUsd,
      callMinutes: callMinutes,
      features: features,
      isCurrent: isCurrent ?? this.isCurrent,
    );
  }
}
