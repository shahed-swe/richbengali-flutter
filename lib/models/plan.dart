import '../core/json_parse.dart';

class Plan {
  /// Our own row id. PayStation is asked for a package by this, not by the
  /// Stripe price id, because it has nothing to do with Stripe.
  final String id;
  final String priceId;
  final String label;
  final double amountUsd;

  /// The taka price, when the package has one. Null means it can only be
  /// bought with a card through Stripe.
  final double? amountBdt;
  final int callMinutes;
  final List<String> features;
  final bool isCurrent;

  const Plan({
    this.id = '',
    required this.priceId,
    required this.label,
    required this.amountUsd,
    this.amountBdt,
    required this.callMinutes,
    this.features = const [],
    this.isCurrent = false,
  });

  /// Whether this package can be paid for in taka.
  bool get supportsPaystation => id.isNotEmpty && (amountBdt ?? 0) > 0;

  factory Plan.fromJson(Map<String, dynamic> json) {
    final featuresList = json['features'];
    final List<String> features;
    if (featuresList is List) {
      features = featuresList.map((e) => e.toString()).toList();
    } else {
      features = const [];
    }

    final bdt = json['amount_bdt'];

    return Plan(
      id: (json['id'] ?? '').toString(),
      priceId: (json['stripe_price_id'] ?? json['price_id'] ?? '').toString(),
      label: (json['label'] ?? json['name'] ?? '').toString(),
      amountUsd: asDouble(json['amount_usd'] ?? json['price'] ?? json['amount']),
      amountBdt: bdt == null ? null : asDouble(bdt),
      callMinutes: asInt(json['call_minutes'] ?? json['minutes']),
      features: features,
      isCurrent: json['is_current'] == true || json['current'] == true,
    );
  }

  Plan copyWith({bool? isCurrent}) {
    return Plan(
      id: id,
      priceId: priceId,
      label: label,
      amountUsd: amountUsd,
      amountBdt: amountBdt,
      callMinutes: callMinutes,
      features: features,
      isCurrent: isCurrent ?? this.isCurrent,
    );
  }
}
