import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user.dart';
import '../data/relations_repository.dart';

class FavoritesNotifier extends AsyncNotifier<List<User>> {
  @override
  Future<List<User>> build() async {
    return ref.read(relationsRepositoryProvider).getFavorites();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(relationsRepositoryProvider).getFavorites(),
    );
  }
}

final favoritesProvider =
    AsyncNotifierProvider<FavoritesNotifier, List<User>>(FavoritesNotifier.new);
