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
