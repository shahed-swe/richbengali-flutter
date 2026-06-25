import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../theme/theme.dart';

class SubscriptionScreen extends StatefulWidget {
  final String? status;

  const SubscriptionScreen({super.key, this.status});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  @override
  void initState() {
    super.initState();
    // Auto-navigate home after 2000 ms
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) {
        context.go('/home');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isSuccess = widget.status == 'success';

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
                  isSuccess ? 'Payment Successful!' : 'Payment Cancelled',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.gray900,
                  ),
                ),
                const SizedBox(height: 12),

                // Subtitles
                if (isSuccess) ...[
                  const Text(
                    'Adding credits to your wallet...',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: AppColors.gray500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Please pull down to refresh plans screen.',
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
