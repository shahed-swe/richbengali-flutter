import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/dio_client.dart';
import '../models/user.dart';
import '../models/relation_status.dart';

class RelationsRepository {
  RelationsRepository(this._dio);
  final Dio _dio;

  Future<List<User>> getFavorites() async {
    final resp = await _dio.get('/relations/favorites');
    final data = resp.data;
    final list = (data is Map ? data['data'] : data) as List? ?? [];
    return list.whereType<Map<String, dynamic>>().map(User.fromJson).toList();
  }

  Future<RelationStatus> getRelationStatus(String targetId) async {
    final resp = await _dio.get('/relations/status/$targetId');
    final data = resp.data;
    final map = (data is Map && data.containsKey('data'))
        ? data['data'] as Map<String, dynamic>
        : data as Map<String, dynamic>;
    return RelationStatus.fromJson(map);
  }

  Future<void> like(String targetId) async {
    await _dio.post('/relations/$targetId/like');
  }

  Future<void> unlike(String targetId) async {
    await _dio.delete('/relations/$targetId/like');
  }

  Future<void> favorite(String targetId) async {
    await _dio.post('/relations/$targetId/favorite');
  }

  Future<void> unfavorite(String targetId) async {
    await _dio.delete('/relations/$targetId/favorite');
  }

  Future<void> superlike(String targetId) async {
    await _dio.post('/relations/$targetId/superlike');
  }

  Future<List<User>> getVisitors() async {
    final resp = await _dio.get('/relations/visitors');
    final data = resp.data;
    final list = (data is Map ? data['data'] : data) as List? ?? [];
    return list.whereType<Map<String, dynamic>>().map(User.fromJson).toList();
  }

  Future<List<User>> getVisits() async {
    final resp = await _dio.get('/relations/visits');
    final data = resp.data;
    final list = (data is Map ? data['data'] : data) as List? ?? [];
    return list.whereType<Map<String, dynamic>>().map(User.fromJson).toList();
  }

  Future<void> recordVisit(String targetId) async {
    await _dio.post('/visits', data: {'targetId': targetId});
  }
}

final relationsRepositoryProvider = Provider<RelationsRepository>((ref) {
  return RelationsRepository(ref.watch(dioProvider));
});
