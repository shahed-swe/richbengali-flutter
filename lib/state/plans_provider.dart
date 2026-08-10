import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'refresh_in_place.dart';
import '../data/stripe_repository.dart';
import '../models/plan.dart';

class PlansNotifier extends AsyncNotifier<List<Plan>> {
  @override
  Future<List<Plan>> build() async {
    return ref.read(stripeRepositoryProvider).getPlans();
  }

  /// Refetch without tearing the current data off the screen.
  Future<void> refresh() async {
    state = await refreshedState(
      state,
      () => ref.read(stripeRepositoryProvider).getPlans(),
    );
  }
}

final plansProvider =
    AsyncNotifierProvider<PlansNotifier, List<Plan>>(PlansNotifier.new);
