import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user.dart';
import '../data/users_repository.dart';

/// Value object for user list filters
class UserFilters {
  final String? cityStartsWith;
  final int? minAge;
  final int? maxAge;

  const UserFilters({
    this.cityStartsWith,
    this.minAge,
    this.maxAge,
  });

  bool get hasActiveFilters =>
      (cityStartsWith != null && cityStartsWith!.trim().isNotEmpty) ||
      minAge != null ||
      maxAge != null;

  @override
  bool operator ==(Object other) =>
      other is UserFilters &&
      cityStartsWith == other.cityStartsWith &&
      minAge == other.minAge &&
      maxAge == other.maxAge;

  @override
  int get hashCode => Object.hash(cityStartsWith, minAge, maxAge);

  UserFilters copyWith({
    String? cityStartsWith,
    int? minAge,
    int? maxAge,
    bool clearCity = false,
    bool clearMinAge = false,
    bool clearMaxAge = false,
  }) {
    return UserFilters(
      cityStartsWith:
          clearCity ? null : (cityStartsWith ?? this.cityStartsWith),
      minAge: clearMinAge ? null : (minAge ?? this.minAge),
      maxAge: clearMaxAge ? null : (maxAge ?? this.maxAge),
    );
  }
}

/// Holds the active filter state so the Home screen and filter sheet stay in sync
class UserFiltersNotifier extends Notifier<UserFilters> {
  @override
  UserFilters build() => const UserFilters();

  void apply(UserFilters filters) => state = filters;

  void clear() => state = const UserFilters();
}

final userFiltersProvider =
    NotifierProvider<UserFiltersNotifier, UserFilters>(UserFiltersNotifier.new);

/// Fetches users for the given filters
final usersProvider =
    FutureProvider.family<List<User>, UserFilters>((ref, filters) async {
  return ref.read(usersRepositoryProvider).getUsers(
        cityStartsWith: filters.cityStartsWith,
        minAge: filters.minAge,
        maxAge: filters.maxAge,
      );
});

/// User ids to hide from the Home discover grid immediately after favoriting
/// (before the next backend fetch, which already excludes favorites via the
/// `excludeFavorites` rule). Un-hidden on unfavorite so the user reappears.
class HomeHiddenUsersNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => <String>{};

  void hide(String id) => state = {...state, id};
  void unhide(String id) => state = {...state}..remove(id);
  void clear() => state = <String>{};
}

final homeHiddenUsersProvider =
    NotifierProvider<HomeHiddenUsersNotifier, Set<String>>(
  HomeHiddenUsersNotifier.new,
);

/// The Home grid's actual contents: fetched users minus the locally hidden ones.
///
/// Derived here rather than filtered inline in `HomeScreen.build` so the
/// filtering runs once per data change instead of on every widget rebuild.
///
/// When no fetched user is actually hidden, the original list instance is
/// returned unchanged. `Provider` compares with `==`, and a fresh `toList()`
/// never equals the previous one, so without this the grid would rebuild on
/// every unrelated hide/unhide. Returning the same instance lets Riverpod
/// suppress those notifications entirely.
final visibleUsersProvider =
    Provider.family<AsyncValue<List<User>>, UserFilters>((ref, filters) {
  final hidden = ref.watch(homeHiddenUsersProvider);
  return ref.watch(usersProvider(filters)).whenData((users) {
    if (hidden.isEmpty) return users;
    final visible =
        users.where((u) => !hidden.contains(u.id.toString())).toList();
    return visible.length == users.length ? users : visible;
  });
});
