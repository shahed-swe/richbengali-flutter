import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/stripe_repository.dart';
import '../models/plan.dart';

class PlansNotifier extends AsyncNotifier<List<Plan>> {
  @override
  Future<List<Plan>> build() async {
    return ref.read(stripeRepositoryProvider).getPlans();
  }

  /// Refetch without discarding the current data.
  ///
  /// `invalidateSelf` re-runs `build()` while Riverpod keeps the previous
  /// value attached to the new `AsyncLoading`. Because `AsyncValue.when`
  /// defaults to `skipLoadingOnRefresh: true`, the UI keeps rendering the old
  /// list and swaps in the new one when it arrives, instead of flashing a
  /// full-screen spinner on every pull-to-refresh or socket-driven refresh.
  Future<void> refresh() async {
    ref.invalidateSelf();
    try {
      await future;
    } catch (_) {
      // The error is already surfaced through `state` as AsyncError; swallow it
      // here so callers like RefreshIndicator.onRefresh never see an unhandled
      // rejection.
    }
  }
}

final plansProvider =
    AsyncNotifierProvider<PlansNotifier, List<Plan>>(PlansNotifier.new);
