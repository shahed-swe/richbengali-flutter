/// Tolerant JSON / socket payload parsing helpers.
///
/// The Postgres backend serialises NUMERIC/DECIMAL columns as JSON **strings**
/// (e.g. `"10.00"`, `"25"`).  Plain `as num` / `as int` / `as double` casts
/// throw `_CastError` at runtime when the value is a String.  These helpers
/// accept `num`, `String`, `bool`, or `null` and never throw.
library;

// ---------------------------------------------------------------------------
// double
// ---------------------------------------------------------------------------

/// Returns `null` for null / unparseable input; never throws.
double? asDoubleN(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  if (v is bool) return v ? 1.0 : 0.0;
  final s = v.toString().trim();
  if (s.isEmpty) return null;
  return double.tryParse(s);
}

/// Always returns a [double]; falls back to [fallback] (default 0) on failure.
double asDouble(dynamic v, [double fallback = 0]) =>
    asDoubleN(v) ?? fallback;

// ---------------------------------------------------------------------------
// int
// ---------------------------------------------------------------------------

/// Returns `null` for null / unparseable input; never throws.
int? asIntN(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is bool) return v ? 1 : 0;
  final s = v.toString().trim();
  if (s.isEmpty) return null;
  // Try int first (handles "25"), then double-then-truncate ("25.00")
  return int.tryParse(s) ?? double.tryParse(s)?.toInt();
}

/// Always returns an [int]; falls back to [fallback] (default 0) on failure.
int asInt(dynamic v, [int fallback = 0]) => asIntN(v) ?? fallback;

// ---------------------------------------------------------------------------
// bool
// ---------------------------------------------------------------------------

/// Handles `bool`, `num` (1/0), `String` ("true"/"1"/"yes" → true,
/// "false"/"0"/"no" → false), and `null`.  Never throws.
bool asBool(dynamic v, [bool fallback = false]) {
  if (v == null) return fallback;
  if (v is bool) return v;
  if (v is num) return v != 0;
  final s = v.toString().trim().toLowerCase();
  if (s == 'true' || s == '1' || s == 'yes') return true;
  if (s == 'false' || s == '0' || s == 'no') return false;
  return fallback;
}

// ---------------------------------------------------------------------------
// String
// ---------------------------------------------------------------------------

/// Returns `v?.toString()`.  Safe for any dynamic value.
String? asStringN(dynamic v) => v?.toString();

// ---------------------------------------------------------------------------
// num
// ---------------------------------------------------------------------------

/// Returns a `num?` from num, String, or null.  Never throws.
num? asNumN(dynamic v) {
  if (v == null) return null;
  if (v is num) return v;
  if (v is bool) return v ? 1 : 0;
  final s = v.toString().trim();
  if (s.isEmpty) return null;
  return num.tryParse(s);
}
