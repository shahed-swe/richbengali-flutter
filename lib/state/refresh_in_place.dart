import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Computes the next state for a refresh that must not tear the current data
/// off the screen. Callers assign the result to their own `state`.
///
/// The obvious implementations both misbehave:
///
/// * `state = const AsyncLoading()` before fetching discards the loaded value,
///   so `AsyncValue.when` takes its loading branch and the screen flashes a
///   full-screen spinner for a whole network round trip on every
///   pull-to-refresh, tab return and socket-driven refresh.
/// * `ref.invalidateSelf()` followed by `await future` keeps the value, but the
///   future never completes when the repository throws a non-`Error` (which is
///   every real failure, since Dio throws `DioException`). A `RefreshIndicator`
///   awaiting it would spin forever.
///
/// So fetch directly and return the outcome. On failure [previous] is kept: a
/// refresh that fails should leave the user reading the list they already had
/// rather than replacing a populated screen with a full-screen error. Errors
/// only surface when there is nothing already on screen.
Future<AsyncValue<T>> refreshedState<T>(
  AsyncValue<T> current,
  Future<T> Function() fetch,
) async {
  final previous = current.asData?.value;
  final result = await AsyncValue.guard(fetch);
  return result.hasError && previous != null ? AsyncData(previous) : result;
}
