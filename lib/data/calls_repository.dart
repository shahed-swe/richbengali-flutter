import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/dio_client.dart';

class CallsRepository {
  CallsRepository(this._dio);
  final Dio _dio;

  Future<void> dispatchCallPush({
    required String receiverId,
    required String callId,
    required bool isVideo,
  }) async {
    try {
      await _dio.post('/calls/dispatch-push', data: {
        'receiverId': receiverId,
        'callId': callId,
        'isVideo': isVideo,
      });
    } catch (e) {
      debugPrint('[CallsRepository] dispatchCallPush error: $e');
    }
  }
}

final callsRepositoryProvider = Provider<CallsRepository>((ref) {
  return CallsRepository(ref.read(dioProvider));
});
