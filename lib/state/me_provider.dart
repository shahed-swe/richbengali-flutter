import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'refresh_in_place.dart';
import '../models/user.dart';
import '../data/me_repository.dart';

class MeNotifier extends AsyncNotifier<Me> {
  @override
  Future<Me> build() async {
    return ref.read(meRepositoryProvider).getMe();
  }

  /// Refetch without tearing the current data off the screen.
  Future<void> refresh() async {
    state = await refreshedState(
      state,
      () => ref.read(meRepositoryProvider).getMe(),
    );
  }

  Future<void> patchMe(Map<String, dynamic> patch) async {
    final updated = await ref.read(meRepositoryProvider).updateMe(patch);
    state = AsyncData(updated);
  }
}

final meProvider = AsyncNotifierProvider<MeNotifier, Me>(MeNotifier.new);
