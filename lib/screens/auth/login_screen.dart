import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/auth_repository.dart';
import '../../theme/theme.dart';
import '../../widgets/widgets.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  String _tab = 'email'; // 'email' | 'phone'

  // Email state
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _showPassword = false;
  String _emailError = '';
  bool _emailLoading = false;

  // Phone state
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  bool _otpSent = false;
  String _phoneError = '';
  bool _phoneLoading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleEmailLogin() async {
    setState(() => _emailError = '');
    if (_emailCtrl.text.trim().isEmpty || _passwordCtrl.text.isEmpty) {
      setState(() => _emailError = 'All fields are required');
      return;
    }
    setState(() => _emailLoading = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .login(_emailCtrl.text.trim(), _passwordCtrl.text);
      if (mounted) context.go('/home');
    } catch (e) {
      setState(() => _emailError = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _emailLoading = false);
    }
  }

  Future<void> _handleSendOtp() async {
    setState(() => _phoneError = '');
    final phone = _phoneCtrl.text.trim();
    if (!phone.startsWith('+') || phone.length < 8) {
      setState(() => _phoneError = 'Enter valid phone number with country code (e.g. +1...)');
      return;
    }
    setState(() => _phoneLoading = true);
    try {
      await ref.read(authRepositoryProvider).requestOtp(
            target: phone,
            channel: 'phone',
            purpose: 'login',
          );
      setState(() => _otpSent = true);
    } catch (e) {
      setState(() => _phoneError = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _phoneLoading = false);
    }
  }

  Future<void> _handleVerifyOtp() async {
    setState(() => _phoneError = '');
    setState(() => _phoneLoading = true);
    try {
      await ref.read(authRepositoryProvider).verifyOtp(
            target: _phoneCtrl.text.trim(),
            channel: 'phone',
            purpose: 'login',
            code: _otpCtrl.text.trim(),
          );
      if (mounted) context.go('/home');
    } catch (e) {
      setState(() => _phoneError = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _phoneLoading = false);
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
                    const SizedBox(height: 32),
                    Text(
                      'Welcome back',
                      style: AppTextStyles.text2xlBold.copyWith(color: AppColors.gray900),
                    ),
                    const SizedBox(height: 16),
                    // Card
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
                        children: [
                          _TabToggle(
                            active: _tab,
                            onChanged: (t) => setState(() {
                              _tab = t;
                              _emailError = '';
                              _phoneError = '';
                              _otpSent = false;
                              _otpCtrl.clear();
                            }),
                          ),
                          const SizedBox(height: 16),
                          if (_tab == 'email') _buildEmailTab(),
                          if (_tab == 'phone') _buildPhoneTab(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _LegalFooter(),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmailTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _InputField(
          controller: _emailCtrl,
          label: 'Email',
          placeholder: 'bob@example.com',
          prefixIcon: LucideIcons.mail,
          keyboardType: TextInputType.emailAddress,
          autocapitalize: false,
        ),
        const SizedBox(height: 12),
        _InputField(
          controller: _passwordCtrl,
          label: 'Password',
          placeholder: '••••••••',
          prefixIcon: LucideIcons.lock,
          obscure: !_showPassword,
          suffixIcon: _showPassword ? LucideIcons.eyeOff : LucideIcons.eye,
          onSuffixTap: () => setState(() => _showPassword = !_showPassword),
        ),
        if (_emailError.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            _emailError,
            style: AppTextStyles.textSm.copyWith(color: AppColors.danger),
          ),
        ],
        const SizedBox(height: 16),
        _PinkButton(
          label: 'Sign in',
          loading: _emailLoading,
          onPressed: _handleEmailLogin,
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: () => context.go('/register'),
              child: Text(
                'Create account',
                style: AppTextStyles.textBase.copyWith(
                  color: AppColors.gray600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            GestureDetector(
              onTap: () => context.go('/forgot'),
              child: Text(
                'Forgot password?',
                style: AppTextStyles.textBase.copyWith(
                  color: AppColors.gray600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPhoneTab() {
    if (!_otpSent) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _InputField(
            controller: _phoneCtrl,
            label: 'Phone',
            placeholder: '+15551234567',
            prefixIcon: LucideIcons.phone,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 4),
          Text(
            'You must include country code.',
            style: AppTextStyles.textXs.copyWith(color: AppColors.gray500),
          ),
          if (_phoneError.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              _phoneError,
              style: AppTextStyles.textSm.copyWith(color: AppColors.danger),
            ),
          ],
          const SizedBox(height: 16),
          _PinkButton(
            label: 'Send Code',
            loading: _phoneLoading,
            onPressed: _handleSendOtp,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () => context.go('/register'),
                child: Text(
                  'Create account',
                  style: AppTextStyles.textSm.copyWith(
                    color: AppColors.gray600,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => context.go('/forgot'),
                child: Text(
                  'Forgot password?',
                  style: AppTextStyles.textSm.copyWith(
                    color: AppColors.gray600,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    // OTP entry state
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _InputField(
          controller: _otpCtrl,
          label: 'Verification code',
          placeholder: '123456',
          prefixIcon: LucideIcons.lock,
          keyboardType: TextInputType.number,
          maxLength: 6,
        ),
        if (_phoneError.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            _phoneError,
            style: AppTextStyles.textSm.copyWith(color: AppColors.danger),
          ),
        ],
        const SizedBox(height: 16),
        _PinkButton(
          label: 'Verify & Sign in',
          loading: _phoneLoading,
          onPressed: _handleVerifyOtp,
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => setState(() {
            _otpSent = false;
            _otpCtrl.clear();
            _phoneError = '';
          }),
          child: Text(
            'Change phone',
            style: AppTextStyles.textSm.copyWith(color: AppColors.gray500),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Shared sub-widgets (private to this file)
// ---------------------------------------------------------------------------

class _TabToggle extends StatelessWidget {
  final String active;
  final ValueChanged<String> onChanged;

  const _TabToggle({required this.active, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4F5),
        borderRadius: AppRadius.border8,
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _TabBtn(label: 'Email', icon: LucideIcons.mail, isActive: active == 'email', onTap: () => onChanged('email')),
          _TabBtn(label: 'Phone', icon: LucideIcons.phone, isActive: active == 'phone', onTap: () => onChanged('phone')),
        ],
      ),
    );
  }
}

class _TabBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _TabBtn({required this.label, required this.icon, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? AppColors.white : Colors.transparent,
            borderRadius: AppRadius.border8,
            boxShadow: isActive
                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4)]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isActive ? AppColors.brandPink : AppColors.gray500),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTextStyles.textBase.copyWith(
                  fontWeight: FontWeight.w500,
                  color: isActive ? AppColors.brandPink : AppColors.gray500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String placeholder;
  final IconData prefixIcon;
  final bool obscure;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixTap;
  final TextInputType keyboardType;
  final bool autocapitalize;
  final int? maxLength;

  const _InputField({
    required this.controller,
    required this.label,
    required this.placeholder,
    required this.prefixIcon,
    this.obscure = false,
    this.suffixIcon,
    this.onSuffixTap,
    this.keyboardType = TextInputType.text,
    this.autocapitalize = true,
    this.maxLength,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.textSm.copyWith(color: AppColors.gray700, fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF4F4F5),
            borderRadius: AppRadius.border8,
          ),
          child: TextField(
            controller: controller,
            obscureText: obscure,
            keyboardType: keyboardType,
            maxLength: maxLength,
            textCapitalization: autocapitalize ? TextCapitalization.sentences : TextCapitalization.none,
            style: AppTextStyles.textBase.copyWith(color: AppColors.gray900),
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              prefixIcon: Icon(prefixIcon, size: 18, color: AppColors.gray400),
              suffixIcon: suffixIcon != null
                  ? GestureDetector(
                      onTap: onSuffixTap,
                      child: Icon(suffixIcon, size: 18, color: AppColors.gray400),
                    )
                  : null,
              hintText: placeholder,
              hintStyle: AppTextStyles.textBase.copyWith(color: AppColors.gray400),
              counterText: '',
            ),
          ),
        ),
      ],
    );
  }
}

class _PinkButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback onPressed;

  const _PinkButton({required this.label, required this.loading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brandPink,
          foregroundColor: AppColors.white,
          disabledBackgroundColor: AppColors.brandPink.withValues(alpha: 0.6),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.border8),
          elevation: 0,
        ),
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : Text(label, style: AppTextStyles.textBaseBold.copyWith(color: AppColors.white)),
      ),
    );
  }
}

class _LegalFooter extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
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
    );
  }
}
