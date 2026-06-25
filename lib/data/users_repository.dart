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
}

final usersRepositoryProvider = Provider<UsersRepository>((ref) {
  return UsersRepository(ref.watch(dioProvider));
});
