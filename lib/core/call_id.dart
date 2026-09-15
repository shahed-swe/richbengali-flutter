import 'dart:math' as math;

/// Identifiers for a call session.
///
/// These are generated on the device and used by the backend as the key for
/// the call's billing record. They used to come from
/// `Random().nextInt(999999999)`, which is both small and — because a bare
/// `Random()` is seeded from the clock — prone to handing two devices that
/// start a call in the same millisecond the very same value. A collision meant
/// one pair's call adopting another pair's open transaction, and the wrong
/// person being charged. It happened in production.
///
/// A millisecond timestamp keeps them roughly ordered, and the secure random
/// suffix is what actually makes a clash implausible.
String newCallId() {
  final ms = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
  final rnd = math.Random.secure();
  final suffix = List.generate(6, (_) => _alphabet[rnd.nextInt(_alphabet.length)]).join();
  return 'call_${ms}_$suffix';
}

const _alphabet = '0123456789abcdefghijklmnopqrstuvwxyz';
