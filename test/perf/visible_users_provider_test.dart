import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:richbengali/models/user.dart';
import 'package:richbengali/state/users_provider.dart';

User _user(String id) => User(id: id, name: 'User $id');

void main() {
  group('visibleUsersProvider', () {
    test('filters out locally hidden users', () async {
      final container = ProviderContainer(
        overrides: [
          usersProvider.overrideWith(
            (ref, filters) async => [_user('1'), _user('2'), _user('3')],
          ),
        ],
      );
      addTearDown(container.dispose);

      const filters = UserFilters();
      await container.read(usersProvider(filters).future);

      expect(
        container.read(visibleUsersProvider(filters)).value!.map((u) => u.id),
        ['1', '2', '3'],
      );

      container.read(homeHiddenUsersProvider.notifier).hide('2');

      expect(
        container.read(visibleUsersProvider(filters)).value!.map((u) => u.id),
        ['1', '3'],
        reason: 'hiding a user must remove it from the Home grid immediately',
      );

      container.read(homeHiddenUsersProvider.notifier).unhide('2');

      expect(
        container.read(visibleUsersProvider(filters)).value!.map((u) => u.id),
        ['1', '2', '3'],
        reason: 'unfavoriting must bring the user back',
      );
    });

    test('propagates loading and error states from usersProvider', () async {
      final container = ProviderContainer(
        overrides: [
          usersProvider.overrideWith((ref, filters) async {
            throw StateError('boom');
          }),
        ],
      );
      addTearDown(container.dispose);

      const filters = UserFilters();
      expect(container.read(visibleUsersProvider(filters)).isLoading, isTrue);

      await expectLater(
        container.read(usersProvider(filters).future),
        throwsStateError,
      );

      expect(container.read(visibleUsersProvider(filters)).hasError, isTrue);
    });

    test(
      'does not notify listeners when an unrelated hidden id changes',
      () async {
        final container = ProviderContainer(
          overrides: [
            usersProvider.overrideWith(
              (ref, filters) async => [_user('1'), _user('2')],
            ),
          ],
        );
        addTearDown(container.dispose);

        const filters = UserFilters();
        await container.read(usersProvider(filters).future);

        var notifications = 0;
        container.listen(
          visibleUsersProvider(filters),
          (_, _) => notifications++,
        );

        // '99' is not in the list, so the derived list is unchanged and
        // Riverpod should suppress the notification. This is the property that
        // keeps the Home grid from rebuilding on unrelated state changes.
        container.read(homeHiddenUsersProvider.notifier).hide('99');
        await container.pump();
        expect(notifications, 0);

        // A relevant change must still propagate.
        container.read(homeHiddenUsersProvider.notifier).hide('1');
        await container.pump();
        expect(notifications, 1);
      },
    );
  });
}
