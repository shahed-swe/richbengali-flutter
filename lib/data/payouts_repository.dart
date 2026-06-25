import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/dio_client.dart';
import '../models/payout.dart';

class PayoutsRepository {
  PayoutsRepository(this._dio);
  final Dio _dio;

  Future<({List<Payout> data, bool hasMore})> getHistory(
    int page,
    int limit,
  ) async {
    final resp = await _dio.get<dynamic>(
      '/payouts/history',
      queryParameters: {'page': page, 'limit': limit},
    );
    final raw = resp.data;
    List<dynamic> list;
    bool hasMore;
    if (raw is Map) {
      list = (raw['data'] is List) ? raw['data'] as List : [];
      hasMore = raw['hasMore'] == true || raw['has_more'] == true;
    } else if (raw is List) {
      list = raw;
      hasMore = list.length >= limit;
    } else {
      list = [];
      hasMore = false;
    }
    return (
      data: list.whereType<Map<String, dynamic>>().map(Payout.fromJson).toList(),
      hasMore: hasMore,
    );
  }

  Future<void> setMethod({
    required String currency,
    required String type,
    required Map<String, dynamic> details,
  }) async {
    await _dio.post<void>(
      '/payouts/method',
      data: {'currency': currency, 'type': type, 'details': details},
    );
  }

  /// Returns url if the backend returns one (e.g. for Wise redirect), else null.
  Future<String?> requestPayout({required double amountUsd}) async {
    final platform = Platform.isIOS ? 'ios' : 'android';
    final resp = await _dio.post<dynamic>(
      '/payouts/request',
      data: {'amount_usd': amountUsd, 'platform': platform},
    );
    final raw = resp.data;
    if (raw is Map) {
      return raw['url']?.toString();
    }
    return null;
  }
}

final payoutsRepositoryProvider = Provider<PayoutsRepository>((ref) {
  return PayoutsRepository(ref.watch(dioProvider));
});
