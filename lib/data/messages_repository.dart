import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/dio_client.dart';
import '../models/conversation.dart';
import '../models/message.dart';

class MessagesRepository {
  MessagesRepository(this._dio);
  final Dio _dio;

  /// GET /messages — returns conversations list (other users you've chatted with)
  Future<List<Conversation>> getConversations() async {
    final resp = await _dio.get('/messages');
    final data = resp.data;
    final list = data is Map ? data['data'] : data;
    if (list is! List) return [];
    return list
        .whereType<Map>()
        .map((e) => Conversation.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// GET /messages/:otherUserId — returns messages with that user
  Future<List<Message>> getMessages(String otherUserId) async {
    final resp = await _dio.get('/messages/$otherUserId');
    final data = resp.data;
    final list = data is Map ? data['data'] : data;
    if (list is! List) return [];
    return list
        .whereType<Map>()
        .map((e) => Message.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// POST /messages {to, content}
  Future<Message> sendMessage(String to, String content) async {
    final resp = await _dio.post(
      '/messages',
      data: {'to': to, 'content': content},
    );
    final data = resp.data;
    final payload = data is Map ? (data['data'] ?? data) : data;
    return Message.fromJson(Map<String, dynamic>.from(payload as Map));
  }

  /// DELETE /messages/:messageId
  Future<void> deleteMessage(String messageId) async {
    await _dio.delete('/messages/$messageId');
  }

  /// DELETE /messages/chat/:otherUserId
  Future<void> clearChat(String otherUserId) async {
    await _dio.delete('/messages/chat/$otherUserId');
  }
}

final messagesRepositoryProvider = Provider<MessagesRepository>((ref) {
  return MessagesRepository(ref.read(dioProvider));
});
