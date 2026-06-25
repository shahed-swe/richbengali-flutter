import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/payouts_repository.dart';
import '../models/payout.dart';

const _pageSize = 20;

class PayoutsState {
  final List<Payout> items;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final int page;
  final Object? error;

  const PayoutsState({
    this.items = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.page = 1,
    this.error,
  });

  PayoutsState copyWith({
    List<Payout>? items,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    int? page,
    Object? error,
    bool clearError = false,
  }) {
    return PayoutsState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      page: page ?? this.page,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class PayoutsNotifier extends Notifier<PayoutsState> {
  @override
  PayoutsState build() {
    Future.microtask(refresh);
    return const PayoutsState(isLoading: true);
  }

  Future<void> refresh() async {
    state = const PayoutsState(isLoading: true);
    try {
      final result =
          await ref.read(payoutsRepositoryProvider).getHistory(1, _pageSize);
      state = PayoutsState(
        items: result.data,
        isLoading: false,
        hasMore: result.hasMore,
        page: 1,
      );
    } catch (e) {
      state = PayoutsState(isLoading: false, error: e);
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore || state.isLoading) return;
    final nextPage = state.page + 1;
    state = state.copyWith(isLoadingMore: true);
    try {
      final result = await ref
          .read(payoutsRepositoryProvider)
          .getHistory(nextPage, _pageSize);
      state = state.copyWith(
        items: [...state.items, ...result.data],
        isLoadingMore: false,
        hasMore: result.hasMore,
        page: nextPage,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false, error: e);
    }
  }
}

final payoutsProvider =
    NotifierProvider<PayoutsNotifier, PayoutsState>(PayoutsNotifier.new);
