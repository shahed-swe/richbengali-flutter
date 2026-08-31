import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/dio_client.dart';
import '../models/user.dart';

class UsersRepository {
  UsersRepository(this._dio);
  final Dio _dio;

  /// GET /users  — optional filters
  Future<List<User>> getUsers({
    String? cityStartsWith,
    int? minAge,
    int? maxAge,
  }) async {
    final params = <String, dynamic>{};
    if (cityStartsWith != null && cityStartsWith.isNotEmpty) {
      params['cityStartsWith'] = cityStartsWith;
    }
    if (minAge != null) params['minAge'] = minAge;
    if (maxAge != null) params['maxAge'] = maxAge;

    final resp = await _dio.get(
      '/users',
      queryParameters: params.isEmpty ? null : params,
    );
    final data = resp.data;
    final list = (data is Map ? data['data'] : data) as List? ?? [];
    return list.whereType<Map<String, dynamic>>().map(User.fromJson).toList();
  }

  /// GET /users/:id
  Future<User> getUser(String id) async {
    final resp = await _dio.get('/users/$id');
    final data = resp.data;
    final userMap = (data is Map && data.containsKey('data'))
        ? data['data'] as Map<String, dynamic>
        : data as Map<String, dynamic>;
    return User.fromJson(userMap);
  }

  /// POST /users/:id/block — hides each user from the other + blocks chat/calls.
  Future<void> blockUser(String id) => _dio.post('/users/$id/block');

  /// DELETE /users/:id/block — unblock.
  Future<void> unblockUser(String id) => _dio.delete('/users/$id/block');

  /// POST /users/:id/report — reason ∈ child_safety | harassment | spam_scam |
  /// nudity_sexual | fake_profile | other.
  Future<void> reportUser(String id,
      {required String reason, String? details}) async {
    await _dio.post('/users/$id/report', data: {
      'reason': reason,
      if (details != null && details.trim().isNotEmpty) 'details': details.trim(),
    });
  }

  /// GET /users/me/blocks — ids the current user has blocked.
  Future<List<String>> getBlockedIds() async {
    final resp = await _dio.get('/users/me/blocks');
    final data = resp.data;
    final list = (data is Map ? data['data'] : data) as List? ?? [];
    return list.map((e) => e.toString()).toList();
  }
}

final usersRepositoryProvider = Provider<UsersRepository>((ref) {
  return UsersRepository(ref.watch(dioProvider));
});
