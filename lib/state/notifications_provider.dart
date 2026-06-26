import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notification.dart';
import '../data/notifications_repository.dart';

class NotificationsNotifier extends AsyncNotifier<List<NotificationItem>> {
  @override
  Future<List<NotificationItem>> build() async {
    return ref.read(notificationsRepositoryProvider).getNotifications();
  }

  Future<void> refresh() async {
    // Don't reset to AsyncLoading — keep the current items visible while
    // refetching so the bell dropdown never flashes empty mid-open.
    state = await AsyncValue.guard(
      () => ref.read(notificationsRepositoryProvider).getNotifications(),
    );
  }

  Future<void> markRead(String id) async {
    await ref.read(notificationsRepositoryProvider).markRead(id);
    state = state.whenData(
      (items) =>
          items.map((n) => n.id == id ? n.copyWith(isRead: true) : n).toList(),
    );
  }

  Future<void> markAllRead() async {
    await ref.read(notificationsRepositoryProvider).markAllRead();
    state = state.whenData(
      (items) => items.map((n) => n.copyWith(isRead: true)).toList(),
    );
  }
}

final notificationsProvider = AsyncNotifierProvider<NotificationsNotifier,
    List<NotificationItem>>(NotificationsNotifier.new);

/// Derived: count of unread notifications
final unreadNotificationCountProvider = Provider<int>((ref) {
  final notifications = ref.watch(notificationsProvider);
  return notifications.whenOrNull(
        data: (items) => items.where((n) => !n.isRead).length,
      ) ??
      0;
});
