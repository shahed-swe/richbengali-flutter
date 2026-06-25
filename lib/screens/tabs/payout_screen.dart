import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../theme/theme.dart';

class PayoutScreen extends StatefulWidget {
  final String? status;
  final String? payoutStatus;

  const PayoutScreen({super.key, this.status, this.payoutStatus});

  @override
  State<PayoutScreen> createState() => _PayoutScreenState();
}

class _PayoutScreenState extends State<PayoutScreen> {
  @override
  void initState() {
    super.initState();
    // Auto-navigate back to earnings after 2500 ms
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) {
        context.go('/me/earnings');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final resolvedStatus = widget.payoutStatus ?? widget.status;
    final isSuccess = resolvedStatus == 'success';

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Status icon
                Icon(
                  isSuccess
                      ? LucideIcons.checkCircle2
                      : LucideIcons.xCircle,
                  size: 64,
                  color: isSuccess
                      ? AppColors.emerald500
                      : AppColors.danger,
                ),
                const SizedBox(height: 20),

                // Title
                Text(
                  isSuccess
                      ? 'Withdrawal Requested!'
                      : 'Request Failed or Cancelled',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.gray900,
                  ),
                ),
                const SizedBox(height: 12),

                // Subtitle(s)
                if (isSuccess) ...[
                  const Text(
                    'Your request has been submitted successfully.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: AppColors.gray500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Admin will review and process your payment shortly.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: AppColors.gray500,
                    ),
                  ),
                ] else ...[
                  const Text(
                    'Redirecting you back...',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: AppColors.gray500,
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                // Spinner
                const CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.brandPink,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
