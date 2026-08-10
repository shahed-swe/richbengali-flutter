import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'refresh_in_place.dart';
import '../models/user.dart';
import '../data/relations_repository.dart';

class FavoritesNotifier extends AsyncNotifier<List<User>> {
  @override
  Future<List<User>> build() async {
    return ref.read(relationsRepositoryProvider).getFavorites();
  }

  /// Refetch without tearing the current data off the screen.
  Future<void> refresh() async {
    state = await refreshedState(
      state,
      () => ref.read(relationsRepositoryProvider).getFavorites(),
    );
  }
}

final favoritesProvider =
    AsyncNotifierProvider<FavoritesNotifier, List<User>>(FavoritesNotifier.new);
