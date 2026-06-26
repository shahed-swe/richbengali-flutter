// ignore_for_file: use_null_aware_elements
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/dio_client.dart';
import '../models/user.dart';
import '../state/auth_provider.dart';

// ---------------------------------------------------------------------------
// Auth result type
// ---------------------------------------------------------------------------

class AuthResult {
  final String token;
  final User user;
  const AuthResult({required this.token, required this.user});
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

String _extractMessage(DioException e, String fallback) {
  try {
    final data = e.response?.data;
    if (data is String && data.isNotEmpty) return data;
    if (data is Map) {
      // errors[] array takes priority: join all entry messages
      final errors = data['errors'];
      if (errors is List && errors.isNotEmpty) {
        final parts = errors
            .whereType<Map>()
            .map((err) {
              final msg = err['message']?.toString() ?? '';
              final path = err['path']?.toString() ?? '';
              return (path.isNotEmpty && msg.isNotEmpty)
                  ? '$path: $msg'
                  : msg.isNotEmpty
                      ? msg
                      : path;
            })
            .where((s) => s.isNotEmpty)
            .toList();
        if (parts.isNotEmpty) return parts.join('; ');
      }
      // single message field
      final msg = data['message']?.toString() ?? '';
      if (msg.isNotEmpty && msg != 'Validation failed') return msg;
      // error field
      final err = data['error']?.toString() ?? '';
      if (err.isNotEmpty) return err;
      // fall back to message even if it says "Validation failed"
      if (msg.isNotEmpty) return msg;
    }
  } catch (_) {}
  return fallback;
}

AuthResult _parseAuthResponse(dynamic data) {
  final token = (data['token'] ?? '').toString();
  final userMap = data['user'] as Map<String, dynamic>? ?? {};
  final user = User.fromJson(userMap);
  return AuthResult(token: token, user: user);
}

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------

class AuthRepository {
  AuthRepository(this._dio, this._ref);

  final Dio _dio;
  final Ref _ref;

  /// POST /auth/login
  Future<AuthResult> login(String email, String password) async {
    try {
      final resp = await _dio.post('/auth/login', data: {
        'email': email,
        'password': password,
      });
      final result = _parseAuthResponse(resp.data);
      await _ref.read(authProvider.notifier).setAuth(result.token, result.user);
      return result;
    } on DioException catch (e) {
      throw Exception(_extractMessage(e, 'Login failed'));
    }
  }

  /// POST /auth/register
  Future<AuthResult> register({
    required String name,
    String? email,
    String? password,
    required String age,
    required String gender,
    required String city,
    String? phone,
    String? code,
    String? fcmToken,
  }) async {
    try {
      final resp = await _dio.post('/auth/register', data: {
        'name': name,
        if (email != null) 'email': email,
        if (password != null) 'password': password,
        'age': int.tryParse(age) ?? 18,
        'gender': gender,
        'city': city,
        if (phone != null) 'phone': phone,
        if (code != null) 'code': code,
        'profile_picture_url': null,
        if (fcmToken != null) 'fcmToken': fcmToken,
      });
      final result = _parseAuthResponse(resp.data);
      await _ref.read(authProvider.notifier).setAuth(result.token, result.user);
      return result;
    } on DioException catch (e) {
      throw Exception(_extractMessage(e, 'Registration failed'));
    }
  }

  /// POST /auth/password/forgot
  Future<String> forgotPassword(String email) async {
    try {
      final resp = await _dio.post('/auth/password/forgot', data: {'email': email});
      return (resp.data['message'] ?? 'Reset link sent').toString();
    } on DioException catch (e) {
      throw Exception(_extractMessage(e, 'Failed to send reset link'));
    }
  }

  /// POST /auth/otp/request
  Future<String> requestOtp({
    required String target,
    required String channel,
    required String purpose,
  }) async {
    try {
      final resp = await _dio.post('/auth/otp/request', data: {
        'target': target,
        'channel': channel,
        'purpose': purpose,
      });
      return (resp.data['message'] ?? 'OTP sent').toString();
    } on DioException catch (e) {
      throw Exception(_extractMessage(e, 'Failed to send code'));
    }
  }

  /// POST /auth/otp/verify
  Future<AuthResult> verifyOtp({
    required String target,
    required String channel,
    required String purpose,
    required String code,
    Map<String, dynamic>? profile,
  }) async {
    try {
      final resp = await _dio.post('/auth/otp/verify', data: {
        'target': target,
        'channel': channel,
        'purpose': purpose,
        'code': code,
        if (profile != null) 'profile': profile,
      });
      final result = _parseAuthResponse(resp.data);
      await _ref.read(authProvider.notifier).setAuth(result.token, result.user);
      return result;
    } on DioException catch (e) {
      throw Exception(_extractMessage(e, 'Verification failed'));
    }
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return AuthRepository(dio, ref);
});
