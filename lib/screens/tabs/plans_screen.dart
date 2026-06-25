import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../state/plans_provider.dart';
import '../../state/me_provider.dart';
import '../../data/stripe_repository.dart';
import '../../widgets/plan_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/skeleton.dart';
import '../../theme/theme.dart';

class PlansScreen extends ConsumerStatefulWidget {
  const PlansScreen({super.key});

  @override
  ConsumerState<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends ConsumerState<PlansScreen> {
  bool _checkingOut = false;

  Future<void> _handleBuy(String priceId) async {
    if (_checkingOut) return;
    setState(() => _checkingOut = true);
    try {
      final url =
          await ref.read(stripeRepositoryProvider).checkout(priceId);
      if (url.isNotEmpty) {
        await launchUrl(
          Uri.parse(url),
          mode: LaunchMode.externalApplication,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Checkout failed: ${e.toString()}'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _checkingOut = false);
    }
  }

  Future<void> _onRefresh() async {
    await Future.wait([
      ref.read(plansProvider.notifier).refresh(),
      ref.read(meProvider.notifier).refresh(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final plansAsync = ref.watch(plansProvider);
    final meAsync = ref.watch(meProvider);
    final me = meAsync.asData?.value;
    final balance = me?.walletBalanceUsd ?? 0.0;
    final currentPriceId = me?.stripePriceId;

    return Scaffold(
      backgroundColor: const Color(0xFFf9fafb),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        color: AppColors.brandPink,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Gradient header (320 px tall, bottom radius 48) ──
                  Container(
                    height: 320,
                    decoration: const BoxDecoration(
                      gradient: AppGradients.plansHeader,
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(48),
                        bottomRight: Radius.circular(48),
                      ),
                    ),
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // "Secure Payment via Stripe" pill badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.3),
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    LucideIcons.shield,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Secure Payment via Stripe',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              'Call Wallet',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Top up your credits to connect\nwith people worldwide.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // ── Content area: overlaps gradient by 64 px ──
                  Transform.translate(
                    offset: const Offset(0, -64),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Balance card
                          Container(
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.5),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.12),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(
                                      LucideIcons.creditCard,
                                      size: 20,
                                      color: AppColors.gray500,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Current Balance',
                                      style: TextStyle(
                                        color: AppColors.gray500,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                meAsync.isLoading
                                    ? const Skeleton(
                                        width: 120,
                                        height: 36,
                                      )
                                    : Text(
                                        '\$${balance.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontSize: 36,
                                          fontWeight: FontWeight.w900,
                                          color: AppColors.gray900,
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),

                          // "Available Packages" heading
                          const Text(
                            'Available Packages',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppColors.gray900,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Plan cards
                          plansAsync.when(
                            loading: () => Column(
                              children: List.generate(
                                3,
                                (_) => Padding(
                                  padding: const EdgeInsets.only(bottom: 24),
                                  child: Skeleton(
                                    width: double.infinity,
                                    height: 200,
                                    borderRadius: 24,
                                  ),
                                ),
                              ),
                            ),
                            error: (e, _) => EmptyState(
                              icon: LucideIcons.creditCard,
                              title: 'Failed to load plans',
                              description: e.toString(),
                              actionLabel: 'Retry',
                              onAction: () =>
                                  ref.read(plansProvider.notifier).refresh(),
                            ),
                            data: (plans) {
                              if (plans.isEmpty) {
                                return const EmptyState(
                                  title: 'No Plans Available',
                                  description:
                                      'Check back later for new offers.',
                                );
                              }
                              return Column(
                                children: plans.map((plan) {
                                  final isCurrent = currentPriceId != null &&
                                      currentPriceId == plan.priceId;
                                  return PlanCard(
                                    plan: plan,
                                    isCurrent: isCurrent,
                                    onBuy: _handleBuy,
                                    isLoading: _checkingOut,
                                  );
                                }).toList(),
                              );
                            },
                          ),

                          // Bottom padding to clear the nav bar
                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
