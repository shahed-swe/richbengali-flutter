/// Money, shown in taka.
///
/// The ledger is kept in dollars — one currency, so a call's price and a
/// wallet never need converting between them — but nobody here thinks in
/// dollars. $8.13 means nothing to someone who paid ৳1,000 for it, so every
/// figure a person reads is converted on the way out.
///
/// The rate is fixed, not a live feed. A live one would make a balance move on
/// its own: ৳1,000 one morning and ৳980 the next, nothing spent, and nothing
/// useful to say to whoever asks why.
library;

/// Matches the server default in pricing/engine.js. The API sends the real one
/// as `usd_to_bdt` on /pricing/rates; this is what we use until it arrives.
const double kUsdToBdt = 123;

double toBdt(num? usd) => (usd ?? 0).toDouble() * kUsdToBdt;

/// A taka amount as people write it here: ৳1,000.
///
/// Whole taka by default — paisa on a balance reads like an invoice and is
/// never something anyone acts on.
String formatBdt(num? usd, {int decimals = 0}) {
  final taka = toBdt(usd);
  return '৳${_withThousands(taka, decimals)}';
}

/// A per-minute price, where the paisa does carry meaning.
String formatBdtRate(num? usdPerMinute) => formatBdt(usdPerMinute, decimals: 2);

/// A signed amount, for a ledger line: +৳45 / −৳12.
String formatBdtSigned(num? usd, {int decimals = 0}) {
  final v = (usd ?? 0).toDouble();
  final sign = v < 0 ? '-' : '+';
  return '$sign${formatBdt(v.abs(), decimals: decimals)}';
}

String _withThousands(double v, int decimals) {
  final fixed = v.toStringAsFixed(decimals);
  final parts = fixed.split('.');
  final whole = parts[0];
  final buf = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    if (i > 0 && (whole.length - i) % 3 == 0) buf.write(',');
    buf.write(whole[i]);
  }
  return parts.length > 1 ? '$buf.${parts[1]}' : buf.toString();
}
