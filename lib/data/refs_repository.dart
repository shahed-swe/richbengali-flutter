import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/dio_client.dart';
import '../models/ref_option.dart';

class RefsRepository {
  RefsRepository(this._dio);
  final Dio _dio;

  /// GET /refs/:type — returns List of RefOption
  Future<List<RefOption>> getRefs(String type) async {
    final resp = await _dio.get('/refs/$type');
    final data = resp.data;
    final list = (data is Map ? data['data'] : data) as List? ?? [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(RefOption.fromJson)
        .toList();
  }
}

final refsRepositoryProvider = Provider<RefsRepository>((ref) {
  return RefsRepository(ref.watch(dioProvider));
});
