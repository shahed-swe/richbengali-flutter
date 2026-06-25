import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/auth_repository.dart';
import '../../theme/theme.dart';
import '../../widgets/widgets.dart';

class ForgotScreen extends ConsumerStatefulWidget {
  const ForgotScreen({super.key});

  @override
  ConsumerState<ForgotScreen> createState() => _ForgotScreenState();
}

class _ForgotScreenState extends ConsumerState<ForgotScreen> {
  final _emailCtrl = TextEditingController();
  bool _loading = false;
  String _error = '';
  bool _sent = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    setState(() => _error = '');
    final email = _emailCtrl.text.trim();
    final emailOk = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email);
    if (!emailOk) {
      setState(() => _error = 'Please enter a valid email address');
      return;
    }

    setState(() => _loading = true);
    try {
      await ref.read(authRepositoryProvider).forgotPassword(email);
      if (mounted) {
        setState(() => _sent = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Check your email. If we found your account, we will send a reset link.',
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 5),
          ),
        );
        // Navigate back to login after success
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) context.go('/login');
      }
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BackgroundGradient(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 48),
                    Text(
                      'Forgot password',
                      style: AppTextStyles.text2xlBold.copyWith(color: AppColors.gray900),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: AppRadius.border16,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Email field
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Email',
                                style: AppTextStyles.textSm.copyWith(
                                  color: AppColors.gray700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF4F4F5),
                                  borderRadius: AppRadius.border8,
                                ),
                                child: TextField(
                                  controller: _emailCtrl,
                                  autofocus: true,
                                  keyboardType: TextInputType.emailAddress,
                                  textCapitalization: TextCapitalization.none,
                                  style: AppTextStyles.textBase.copyWith(color: AppColors.gray900),
                                  decoration: InputDecoration(
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                                    prefixIcon: Icon(LucideIcons.mail, size: 18, color: AppColors.gray400),
                                    hintText: 'Enter your email',
                                    hintStyle: AppTextStyles.textBase.copyWith(color: AppColors.gray400),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          if (_error.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              _error,
                              style: AppTextStyles.textSm.copyWith(color: AppColors.danger),
                            ),
                          ],

                          const SizedBox(height: 16),

                          SizedBox(
                            height: 44,
                            child: ElevatedButton(
                              onPressed: _loading || _sent ? null : _handleSubmit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.brandPink,
                                foregroundColor: AppColors.white,
                                disabledBackgroundColor: AppColors.brandPink.withValues(alpha: 0.6),
                                shape: RoundedRectangleBorder(borderRadius: AppRadius.border8),
                                elevation: 0,
                              ),
                              child: _loading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                    )
                                  : Text(
                                      'Send reset link',
                                      style: AppTextStyles.textBaseBold.copyWith(color: AppColors.white),
                                    ),
                            ),
                          ),

                          const SizedBox(height: 16),
                          Center(
                            child: GestureDetector(
                              onTap: () => context.go('/login'),
                              child: Text(
                                'Back to sign in',
                                style: AppTextStyles.textBase.copyWith(
                                  color: AppColors.gray600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: () => launchUrl(Uri.parse('https://richbengali.com/terms')),
                          child: Text(
                            'Terms of Service',
                            style: AppTextStyles.textXs.copyWith(
                              color: AppColors.gray500,
                              decoration: TextDecoration.underline,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text('|', style: AppTextStyles.textXs.copyWith(color: AppColors.gray300)),
                        ),
                        GestureDetector(
                          onTap: () => launchUrl(Uri.parse('https://richbengali.com/privacy')),
                          child: Text(
                            'Privacy Policy',
                            style: AppTextStyles.textXs.copyWith(
                              color: AppColors.gray500,
                              decoration: TextDecoration.underline,
                              fontWeight: FontWeight.w500,
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
        ),
      ),
    );
  }
}
