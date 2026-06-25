import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/dio_client.dart';
import '../models/notification.dart';

class NotificationsRepository {
  NotificationsRepository(this._dio);
  final Dio _dio;

  Future<List<NotificationItem>> getNotifications() async {
    final resp = await _dio.get('/notifications');
    final data = resp.data;
    final list = (data is Map ? data['data'] : data) as List? ?? [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(NotificationItem.fromJson)
        .toList();
  }

  Future<int> getUnreadCount() async {
    final resp = await _dio.get('/notifications/unread-count');
    final data = resp.data;
    final map = (data is Map && data.containsKey('data'))
        ? data['data'] as Map<String, dynamic>
        : (data is Map
            ? data
            : <String, dynamic>{}) as Map<String, dynamic>;
    return (map['count'] as num?)?.toInt() ?? 0;
  }

  Future<void> markRead(String id) async {
    await _dio.patch('/notifications/$id/read');
  }

  Future<void> markAllRead() async {
    await _dio.post('/notifications/read-all');
  }
}

final notificationsRepositoryProvider =
    Provider<NotificationsRepository>((ref) {
  return NotificationsRepository(ref.watch(dioProvider));
});
