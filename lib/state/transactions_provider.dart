import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/stripe_repository.dart';
import '../models/transaction.dart';

const _pageSize = 20;

class TransactionsState {
  final List<Transaction> items;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final int page;
  final Object? error;

  const TransactionsState({
    this.items = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.page = 1,
    this.error,
  });

  TransactionsState copyWith({
    List<Transaction>? items,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    int? page,
    Object? error,
    bool clearError = false,
  }) {
    return TransactionsState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      page: page ?? this.page,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class TransactionsNotifier extends Notifier<TransactionsState> {
  @override
  TransactionsState build() {
    Future.microtask(refresh);
    return const TransactionsState(isLoading: true);
  }

  Future<void> refresh() async {
    state = const TransactionsState(isLoading: true);
    try {
      final items =
          await ref.read(stripeRepositoryProvider).getTransactions(1, _pageSize);
      state = TransactionsState(
        items: items,
        isLoading: false,
        hasMore: items.length >= _pageSize,
        page: 1,
      );
    } catch (e) {
      state = TransactionsState(isLoading: false, error: e);
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore || state.isLoading) return;
    final nextPage = state.page + 1;
    state = state.copyWith(isLoadingMore: true);
    try {
      final newItems = await ref
          .read(stripeRepositoryProvider)
          .getTransactions(nextPage, _pageSize);
      state = state.copyWith(
        items: [...state.items, ...newItems],
        isLoadingMore: false,
        hasMore: newItems.length >= _pageSize,
        page: nextPage,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false, error: e);
    }
  }
}

final transactionsProvider =
    NotifierProvider<TransactionsNotifier, TransactionsState>(
      TransactionsNotifier.new,
    );
