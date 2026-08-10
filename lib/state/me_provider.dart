import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user.dart';
import '../data/me_repository.dart';

class MeNotifier extends AsyncNotifier<Me> {
  @override
  Future<Me> build() async {
    return ref.read(meRepositoryProvider).getMe();
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

  Future<void> patchMe(Map<String, dynamic> patch) async {
    final updated = await ref.read(meRepositoryProvider).updateMe(patch);
    state = AsyncData(updated);
  }
}

final meProvider = AsyncNotifierProvider<MeNotifier, Me>(MeNotifier.new);
