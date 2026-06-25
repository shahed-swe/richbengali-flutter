import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/dio_client.dart';
import '../models/user.dart';

class MeRepository {
  MeRepository(this._dio);
  final Dio _dio;

  /// GET /users/me
  Future<Me> getMe() async {
    final resp = await _dio.get('/users/me');
    final data = resp.data;
    final map = (data is Map && data.containsKey('data'))
        ? data['data'] as Map<String, dynamic>
        : data as Map<String, dynamic>;
    return Me.fromJson(map);
  }

  /// PATCH /users/me
  Future<Me> updateMe(Map<String, dynamic> patch) async {
    final resp = await _dio.patch('/users/me', data: patch);
    final data = resp.data;
    final map = (data is Map && data.containsKey('data'))
        ? data['data'] as Map<String, dynamic>
        : data as Map<String, dynamic>;
    return Me.fromJson(map);
  }

  /// POST /users/me/photos — multipart upload
  Future<UserPhoto> uploadPhoto(String filePath) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
    });
    final resp = await _dio.post(
      '/users/me/photos',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
    final body = resp.data;
    final map = (body is Map && body.containsKey('data'))
        ? body['data'] as Map<String, dynamic>
        : body as Map<String, dynamic>;
    return UserPhoto.fromJson(map);
  }

  /// PUT /users/me/photos/:id — multipart replace
  Future<UserPhoto> replacePhoto(String photoId, String filePath) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
    });
    final resp = await _dio.put(
      '/users/me/photos/$photoId',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
    final body = resp.data;
    final map = (body is Map && body.containsKey('data'))
        ? body['data'] as Map<String, dynamic>
        : body as Map<String, dynamic>;
    return UserPhoto.fromJson(map);
  }

  /// DELETE /users/me/photos/:id
  Future<void> deletePhoto(String photoId) async {
    await _dio.delete('/users/me/photos/$photoId');
  }

  /// PATCH /users/me/photos/:id/primary
  Future<void> setPrimaryPhoto(String photoId) async {
    await _dio.patch('/users/me/photos/$photoId/primary');
  }

  /// PATCH /users/me/photos/reorder
  Future<void> reorderPhotos(List<String> order) async {
    await _dio.patch('/users/me/photos/reorder', data: {'order': order});
  }
}

final meRepositoryProvider = Provider<MeRepository>((ref) {
  return MeRepository(ref.watch(dioProvider));
});
