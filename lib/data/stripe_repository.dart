import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/dio_client.dart';
import '../models/plan.dart';
import '../models/transaction.dart';

class StripeRepository {
  StripeRepository(this._dio);
  final Dio _dio;

  Future<List<Plan>> getPlans() async {
    final resp = await _dio.get('/stripe/plans');
    final raw = resp.data;
    List<dynamic> list;
    if (raw is Map && raw['plans'] is List) {
      list = raw['plans'] as List;
    } else if (raw is List) {
      list = raw;
    } else {
      list = [];
    }
    return list
        .whereType<Map<String, dynamic>>()
        .map(Plan.fromJson)
        .toList();
  }

  /// Returns the Stripe checkout URL.
  Future<String> checkout(String priceId) async {
    final platform = Platform.isIOS ? 'ios' : 'android';
    final resp = await _dio.post<Map<String, dynamic>>(
      '/stripe/checkout',
      data: {'price_id': priceId, 'platform': platform},
    );
    final url = resp.data?['url']?.toString() ?? '';
    return url;
  }

  Future<void> cancelSubscription() async {
    await _dio.post<void>('/stripe/subscription/cancel');
  }

  Future<void> resumeSubscription() async {
    await _dio.post<void>('/stripe/subscription/resume');
  }

  Future<List<Transaction>> getTransactions(int page, int limit) async {
    final resp = await _dio.get<dynamic>(
      '/users/me/transactions',
      queryParameters: {'page': page, 'limit': limit},
    );
    final raw = resp.data;
    List<dynamic> list;
    if (raw is Map && raw['data'] is List) {
      list = raw['data'] as List;
    } else if (raw is List) {
      list = raw;
    } else {
      list = [];
    }
    return list
        .whereType<Map<String, dynamic>>()
        .map(Transaction.fromJson)
        .toList();
  }
}

final stripeRepositoryProvider = Provider<StripeRepository>((ref) {
  return StripeRepository(ref.watch(dioProvider));
});
