import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:richbengali/data/relations_repository.dart';
import 'package:richbengali/models/user.dart';
import 'package:richbengali/state/favorites_provider.dart';

/// Repository stub whose `getFavorites` resolves only when the test allows it,
/// so we can inspect provider state *while* a refresh is in flight.
class _FakeRelationsRepository implements RelationsRepository {
  _FakeRelationsRepository(this._pages);

  final List<List<User>> _pages;
  int _callCount = 0;
  Completer<List<User>>? gate;

  @override
  Future<List<User>> getFavorites() async {
    final page = _pages[_callCount.clamp(0, _pages.length - 1)];
    _callCount++;
    final g = gate;
    if (g != null) {
      gate = null;
      return g.future;
    }
    return page;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not stubbed');
}

User _user(String id) => User(id: id, name: 'User $id');

void main() {
  test('refresh keeps the previous list visible while refetching', () async {
    final repo = _FakeRelationsRepository([
      [_user('1')],
      [_user('1'), _user('2')],
    ]);

    final container = ProviderContainer(
      overrides: [relationsRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    // Initial load.
    expect(await container.read(favoritesProvider.future), hasLength(1));

    // Hold the next fetch open so we can observe the in-flight state.
    final gate = Completer<List<User>>();
    repo.gate = gate;

    final refreshFuture = container.read(favoritesProvider.notifier).refresh();
    await container.pump();

    final inFlight = container.read(favoritesProvider);
    expect(
      inFlight.hasValue,
      isTrue,
      reason:
          'the previous list must stay on screen during a refresh, otherwise '
          'AsyncValue.when takes its loading branch and the screen flashes a '
          'full-screen spinner for the whole round trip',
    );
    expect(inFlight.value, hasLength(1));

    gate.complete([_user('1'), _user('2')]);
    await refreshFuture;

    expect(container.read(favoritesProvider).value, hasLength(2));
    expect(container.read(favoritesProvider).isLoading, isFalse);
  });

  test('a failed refresh keeps the list and always completes', () async {
    final repo = _FakeRelationsRepository([
      [_user('1')],
    ]);

    final container = ProviderContainer(
      overrides: [relationsRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    await container.read(favoritesProvider.future);

    final gate = Completer<List<User>>();
    repo.gate = gate;
    final refreshFuture = container.read(favoritesProvider.notifier).refresh();
    await container.pump();

    // Dio throws DioException, which is an Exception and NOT an Error. An
    // earlier version of refresh() awaited `ref.future`, which never completes
    // for non-Error throwables, so RefreshIndicator.onRefresh would spin
    // forever on any real network failure.
    var completed = false;
    unawaited(refreshFuture.then((_) => completed = true));
    gate.completeError(Exception('network down'), StackTrace.current);
    await refreshFuture.timeout(const Duration(seconds: 2));

    expect(completed, isTrue, reason: 'onRefresh must always settle');

    final state = container.read(favoritesProvider);
    expect(
      state.value,
      hasLength(1),
      reason: 'a failed refresh must not wipe the list the user was reading',
    );
    expect(
      state.hasError,
      isFalse,
      reason: 'with data still on screen, a failed refresh should be silent '
          'rather than replacing the list with an error view',
    );
  });
}
