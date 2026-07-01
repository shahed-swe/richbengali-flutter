import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user.dart';
import '../models/relation_status.dart';
import '../data/users_repository.dart';
import '../data/relations_repository.dart';
import 'favorites_provider.dart';
import 'users_provider.dart';

/// Fetches a user profile by id
final userDetailProvider =
    FutureProvider.family<User, String>((ref, id) async {
  return ref.read(usersRepositoryProvider).getUser(id);
});

/// Holds and mutates the relation status for a given user id
/// In Riverpod 3, family notifiers receive arg in constructor
class RelationStatusNotifier extends AsyncNotifier<RelationStatus> {
  RelationStatusNotifier(this.userId);
  final String userId;

  @override
  Future<RelationStatus> build() async {
    // Keep alive so liked/favorited state survives scrolling off-screen.
    ref.keepAlive();
    return ref.read(relationsRepositoryProvider).getRelationStatus(userId);
  }

  Future<void> toggleLike() async {
    final current = state.asData?.value;
    if (current == null) return;
    // Optimistic update
    state = AsyncData(current.copyWith(isLiked: !current.isLiked));
    try {
      if (current.isLiked) {
        await ref.read(relationsRepositoryProvider).unlike(userId);
      } else {
        await ref.read(relationsRepositoryProvider).like(userId);
      }
    } catch (_) {
      // Revert on error
      state = AsyncData(current);
    }
  }

  Future<void> toggleFavorite() async {
    final current = state.asData?.value;
    if (current == null) return;
    // Optimistic update
    state = AsyncData(current.copyWith(isFavorited: !current.isFavorited));
    try {
      if (current.isFavorited) {
        await ref.read(relationsRepositoryProvider).unfavorite(userId);
        // Un-favorited: allow the user back into the Home discover grid.
        ref.read(homeHiddenUsersProvider.notifier).unhide(userId);
      } else {
        await ref.read(relationsRepositoryProvider).favorite(userId);
        // Favorited: remove from Home immediately (backend also excludes them
        // from the next /users fetch).
        ref.read(homeHiddenUsersProvider.notifier).hide(userId);
      }
      ref.invalidate(favoritesProvider);
      // Also call refresh() to ensure the provider refetches even if keepAlive
      // prevents the invalidation from triggering a rebuild on its own.
      ref.read(favoritesProvider.notifier).refresh();
    } catch (_) {
      // Revert on error
      state = AsyncData(current);
    }
  }
}

final relationStatusProvider = AsyncNotifierProvider.autoDispose
    .family<RelationStatusNotifier, RelationStatus, String>(
  (arg) => RelationStatusNotifier(arg),
);
