import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import '../../state/me_provider.dart';
import '../../state/transactions_provider.dart';
import '../../state/payouts_provider.dart';
import '../../models/transaction.dart';
import '../../models/payout.dart';
import '../../models/user.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/payout_modal.dart';
import '../../theme/theme.dart';

class EarningsScreen extends ConsumerStatefulWidget {
  const EarningsScreen({super.key});

  @override
  ConsumerState<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends ConsumerState<EarningsScreen> {
  int _tab = 0; // 0 = Earnings, 1 = Withdrawals
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200) {
      if (_tab == 0) {
        ref.read(transactionsProvider.notifier).loadMore();
      } else {
        ref.read(payoutsProvider.notifier).loadMore();
      }
    }
  }

  Future<void> _onRefresh() async {
    if (_tab == 0) {
      await ref.read(transactionsProvider.notifier).refresh();
    } else {
      await ref.read(payoutsProvider.notifier).refresh();
    }
    await ref.read(meProvider.notifier).refresh();
  }

  void _openPayoutModal(Me me) {
    showPayoutModal(context, me);
  }

  @override
  Widget build(BuildContext context) {
    final meAsync = ref.watch(meProvider);
    final me = meAsync.asData?.value;

    // Guard: only for female (creator) users
    if (meAsync.hasValue && me != null && me.gender != 'female') {
      return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: EmptyState(
            icon: LucideIcons.trendingUp,
            title: 'Creators Only',
            description: 'This page is only available for creators.',
            actionLabel: 'Go Back',
            onAction: () => context.pop(),
          ),
        ),
      );
    }

    final balance = me?.walletBalanceUsd ?? 0.0;
    final today = me?.todayEarnedUsd ?? 0.0;
    final lifetime = me?.lifetimeEarningsUsd ?? 0.0;
    final minCap = me?.minWithdrawalCap ?? 10.0;
    final canWithdraw = balance >= minCap;

    final txState = ref.watch(transactionsProvider);
    final payState = ref.watch(payoutsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFf9fafb),
      body: Column(
        children: [
          // ── Green gradient header ──
          Container(
            decoration: const BoxDecoration(
              gradient: AppGradients.earningsHeader,
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top bar: back arrow + title
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => context.pop(),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              LucideIcons.arrowLeft,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'My Earnings',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Stats row: Balance | Today | Lifetime | Withdraw
                    meAsync.isLoading
                        ? const Skeleton(width: double.infinity, height: 52)
                        : Row(
                            children: [
                              // Balance
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '\$${balance.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const Text(
                                      'BALANCE',
                                      style: TextStyle(
                                        color: Color(0xA6FFFFFF),
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Divider
                              Container(
                                width: 1,
                                height: 36,
                                color: Colors.white.withValues(alpha: 0.2),
                              ),
                              const SizedBox(width: 12),

                              // Today
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(
                                      '\$${today.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const Text(
                                      'TODAY',
                                      style: TextStyle(
                                        color: Color(0xA6FFFFFF),
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Divider
                              Container(
                                width: 1,
                                height: 36,
                                color: Colors.white.withValues(alpha: 0.2),
                              ),
                              const SizedBox(width: 12),

                              // Lifetime
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(
                                      '\$${lifetime.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const Text(
                                      'LIFETIME',
                                      style: TextStyle(
                                        color: Color(0xA6FFFFFF),
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(width: 12),

                              // Withdraw button
                              GestureDetector(
                                onTap: (canWithdraw && me != null)
                                    ? () => _openPayoutModal(me)
                                    : null,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: canWithdraw
                                        ? Colors.white
                                        : Colors.white.withValues(alpha: 0.92),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        LucideIcons.arrowUpRight,
                                        size: 14,
                                        color: canWithdraw
                                            ? AppColors.emerald700
                                            : AppColors.gray400,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Withdraw',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: canWithdraw
                                              ? AppColors.emerald700
                                              : AppColors.gray400,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ],
                ),
              ),
            ),
          ),

          // ── Tab switcher ──
          Container(
            color: Colors.white,
            child: Row(
              children: [
                _TabButton(
                  label: 'Earnings',
                  icon: LucideIcons.trendingUp,
                  selected: _tab == 0,
                  onTap: () => setState(() => _tab = 0),
                ),
                _TabButton(
                  label: 'Withdrawals',
                  icon: LucideIcons.history,
                  selected: _tab == 1,
                  onTap: () => setState(() => _tab = 1),
                ),
              ],
            ),
          ),

          // ── "Transaction History" section title ──
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Transaction History',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.gray900,
                ),
              ),
            ),
          ),

          // ── List ──
          Expanded(
            child: RefreshIndicator(
              onRefresh: _onRefresh,
              color: AppColors.emerald500,
              child: _tab == 0
                  ? _buildEarningsList(txState)
                  : _buildWithdrawalsList(payState),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEarningsList(TransactionsState txState) {
    if (txState.isLoading) {
      return ListView(
        children: List.generate(
          6,
          (_) => const Padding(
            padding: EdgeInsets.symmetric(vertical: 6, horizontal: 16),
            child: Skeleton(width: double.infinity, height: 52),
          ),
        ),
      );
    }

    if (txState.items.isEmpty) {
      return const EmptyState(
        icon: LucideIcons.trendingUp,
        title: 'No Earnings Yet',
        description: 'Your call earnings will appear here.',
      );
    }

    return ListView.separated(
      controller: _scrollCtrl,
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: txState.items.length + (txState.isLoadingMore ? 1 : 0),
      separatorBuilder: (context2, index2) => const Divider(
        height: 1,
        indent: 34,
        color: Color(0xFFf3f4f6),
      ),
      itemBuilder: (ctx, i) {
        if (i >= txState.items.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.emerald500,
              ),
            ),
          );
        }
        return _EarningRow(item: txState.items[i]);
      },
    );
  }

  Widget _buildWithdrawalsList(PayoutsState payState) {
    if (payState.isLoading) {
      return ListView(
        children: List.generate(
          6,
          (_) => const Padding(
            padding: EdgeInsets.symmetric(vertical: 6, horizontal: 16),
            child: Skeleton(width: double.infinity, height: 52),
          ),
        ),
      );
    }

    if (payState.items.isEmpty) {
      return const EmptyState(
        icon: LucideIcons.wallet,
        title: 'No Withdrawals Yet',
        description: 'Your payout requests will appear here.',
      );
    }

    return ListView.separated(
      controller: _scrollCtrl,
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: payState.items.length + (payState.isLoadingMore ? 1 : 0),
      separatorBuilder: (context2, index2) => const Divider(
        height: 1,
        indent: 34,
        color: Color(0xFFf3f4f6),
      ),
      itemBuilder: (ctx, i) {
        if (i >= payState.items.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.emerald500,
              ),
            ),
          );
        }
        return _WithdrawalRow(item: payState.items[i]);
      },
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected
                    ? AppColors.emerald500
                    : Colors.transparent,
                width: 2,
              ),
              top: const BorderSide(color: Color(0xFFe5e7eb)),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: selected
                    ? AppColors.emerald500
                    : AppColors.gray500,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? AppColors.emerald500
                      : AppColors.gray500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EarningRow extends StatelessWidget {
  const _EarningRow({required this.item});
  final Transaction item;

  @override
  Widget build(BuildContext context) {
    final durationMins = item.durationSeconds ~/ 60;
    final durationSecs = item.durationSeconds % 60;
    final dt = DateTime.tryParse(item.createdAt ?? '');
    final timeStr = dt != null
        ? TimeOfDay.fromDateTime(dt).format(context)
        : '';
    final dateStr = dt != null
        ? '${_monthAbbr(dt.month)} ${dt.day}'
        : '';
    final isPositive = item.amount >= 0;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      child: Row(
        children: [
          // Green dot
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.emerald500,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),

          // Peer name + duration
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.peerName ?? 'Unknown',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.gray900,
                  ),
                ),
                Text(
                  '${durationMins}m ${durationSecs}s',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.gray400,
                  ),
                ),
              ],
            ),
          ),

          // Amount + date
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isPositive ? '+' : ''}\$${item.amount.abs().toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isPositive
                      ? AppColors.emerald600
                      : AppColors.danger,
                ),
              ),
              Text(
                '$dateStr $timeStr',
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.gray400,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WithdrawalRow extends StatelessWidget {
  const _WithdrawalRow({required this.item});
  final Payout item;

  Color get _statusColor {
    switch (item.status) {
      case 'completed':
        return AppColors.emerald600;
      case 'failed':
        return AppColors.danger;
      default:
        return const Color(0xFFd97706);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dt = DateTime.tryParse(item.createdAt ?? '');
    final dateStr = dt != null ? '${_monthAbbr(dt.month)} ${dt.day}' : '';

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      child: Row(
        children: [
          // Status dot
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: _statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),

          // Provider + status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.provider ?? 'Payout',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.gray900,
                  ),
                ),
                Text(
                  item.status[0].toUpperCase() + item.status.substring(1),
                  style: TextStyle(
                    fontSize: 11,
                    color: _statusColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Amount + date
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '-\$${item.amountUsd.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.danger,
                ),
              ),
              Text(
                dateStr,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.gray400,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _monthAbbr(int m) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  return months[(m - 1).clamp(0, 11)];
}
