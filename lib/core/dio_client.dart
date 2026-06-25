import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'env.dart';
import 'storage.dart';

Dio _buildDio() {
  final dio = Dio(BaseOptions(
    baseUrl: Env.apiBase,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
    headers: {'Content-Type': 'application/json'},
  ));

  // Auth interceptor — inject Bearer token
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      final token = await AppStorage.getToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      handler.next(options);
    },
    onResponse: (response, handler) {
      handler.next(response);
    },
    onError: (DioException err, handler) async {
      if (err.response?.statusCode == 401) {
        final path = err.requestOptions.path;
        if (!path.contains('/auth/')) {
          await AppStorage.clearAuth();
          // Phase 2 will wire a logout notifier here
        }
      }
      handler.next(err);
    },
  ));

  return dio;
}

final dioProvider = Provider<Dio>((ref) => _buildDio());
