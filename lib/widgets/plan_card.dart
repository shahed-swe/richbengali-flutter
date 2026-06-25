import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../models/plan.dart';
import '../theme/theme.dart';

class PlanCard extends StatelessWidget {
  const PlanCard({
    super.key,
    required this.plan,
    required this.isCurrent,
    required this.onBuy,
    this.isLoading = false,
  });

  final Plan plan;
  final bool isCurrent;
  final void Function(String priceId) onBuy;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isCurrent ? AppColors.brandPink : AppColors.gray100,
          width: isCurrent ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isCurrent
                ? AppColors.brandPink.withValues(alpha: 0.2)
                : Colors.black.withValues(alpha: 0.05),
            blurRadius: isCurrent ? 10 : 2,
            spreadRadius: isCurrent ? 1 : 0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label + Price
          Text(
            plan.label.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.gray500,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '\$${plan.amountUsd.toStringAsFixed(plan.amountUsd == plan.amountUsd.roundToDouble() ? 0 : 2)}',
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: AppColors.gray900,
                  height: 1,
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                '/mo',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.gray400,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Feature: call minutes (Zap icon)
          if (plan.callMinutes > 0) ...[
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isCurrent
                        ? AppColors.brandPink.withValues(alpha: 0.1)
                        : AppColors.gray100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    LucideIcons.zap,
                    size: 16,
                    color:
                        isCurrent ? AppColors.brandPink : AppColors.gray500,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${plan.callMinutes} Call Mins',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: AppColors.gray700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],

          // Feature: Rollover (Check icon)
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.gray50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  LucideIcons.check,
                  size: 16,
                  color: AppColors.gray500,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Rollover unused minutes',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.gray500,
                ),
              ),
            ],
          ),

          // Extra features from the features list
          for (final feature in plan.features) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.gray50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    LucideIcons.check,
                    size: 16,
                    color: AppColors.gray500,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    feature,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.gray500,
                    ),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 32),

          // Action button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: isCurrent
                  ? null
                  : (isLoading ? null : () => onBuy(plan.priceId)),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isCurrent ? AppColors.gray100 : AppColors.gray900,
                disabledBackgroundColor:
                    isCurrent ? AppColors.gray100 : AppColors.gray300,
                shape: const StadiumBorder(),
                elevation: 0,
              ),
              child: isLoading && !isCurrent
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      isCurrent ? 'Active Plan' : 'Subscribe Now',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color:
                            isCurrent ? AppColors.gray400 : Colors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
