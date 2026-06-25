import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/stripe_repository.dart';
import '../models/plan.dart';

class PlansNotifier extends AsyncNotifier<List<Plan>> {
  @override
  Future<List<Plan>> build() async {
    return ref.read(stripeRepositoryProvider).getPlans();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(stripeRepositoryProvider).getPlans(),
    );
  }
}

final plansProvider =
    AsyncNotifierProvider<PlansNotifier, List<Plan>>(PlansNotifier.new);
