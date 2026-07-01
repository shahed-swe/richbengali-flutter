import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/auth_repository.dart';
import '../../theme/theme.dart';
import '../../widgets/widgets.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  String _tab = 'email';

  // Common fields
  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController(text: '18');
  final _cityCtrl = TextEditingController();
  String _gender = 'male';

  // Email-specific
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _showPassword = false;

  // Phone-specific
  final _phoneCtrl = TextEditingController();

  // OTP
  final _otpCtrl = TextEditingController();
  bool _otpSent = false;
  int _cooldown = 0;
  Timer? _cooldownTimer;

  // State
  bool _loading = false;
  Map<String, String> _errors = {};
  String? _globalError;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _cityCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    _cooldown = 60;
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_cooldown <= 0) {
        t.cancel();
      } else {
        setState(() => _cooldown--);
      }
    });
  }

  bool _isValidE164(String v) {
    return RegExp(r'^\+[1-9]\d{6,14}$').hasMatch(v.trim());
  }

  Map<String, String> _validateCommon() {
    final e = <String, String>{};
    if (_nameCtrl.text.trim().isEmpty) e['name'] = 'Name is required';
    final age = int.tryParse(_ageCtrl.text);
    if (age == null || age < 18) e['age'] = 'Must be 18+';
    if (_cityCtrl.text.trim().isEmpty) e['city'] = 'City is required';
    return e;
  }

  Future<void> _handleSendCode() async {
    setState(() {
      _errors = {};
      _globalError = null;
    });

    final errs = _validateCommon();

    if (_tab == 'email') {
      final emailOk = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$').hasMatch(_emailCtrl.text.trim());
      if (_emailCtrl.text.trim().isEmpty) {
        errs['email'] = 'Email is required';
      } else if (!emailOk) {
        errs['email'] = 'Enter a valid email address';
      }
      if (_passwordCtrl.text.length < 8) errs['password'] = 'Min 8 chars required';
    } else {
      if (!_isValidE164(_phoneCtrl.text)) errs['phone'] = 'Format: +880...';
    }

    if (errs.isNotEmpty) {
      setState(() => _errors = errs);
      return;
    }

    setState(() => _loading = true);
    try {
      final target = _tab == 'email' ? _emailCtrl.text.trim() : _phoneCtrl.text.trim();
      await ref.read(authRepositoryProvider).requestOtp(
            target: target,
            channel: _tab,
            purpose: 'register',
          );
      setState(() => _otpSent = true);
      _startCooldown();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Code sent to your $_tab'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      setState(() => _globalError = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleVerifyAndRegister() async {
    if (_otpCtrl.text.length != 6) {
      setState(() => _errors = {'otp': 'Enter 6-digit code'});
      return;
    }
    setState(() {
      _loading = true;
      _globalError = null;
    });

    try {
      if (_tab == 'email') {
        await ref.read(authRepositoryProvider).register(
              name: _nameCtrl.text.trim(),
              email: _emailCtrl.text.trim(),
              password: _passwordCtrl.text,
              age: _ageCtrl.text.trim(),
              gender: _gender,
              city: _cityCtrl.text.trim(),
              code: _otpCtrl.text.trim(),
            );
      } else {
        await ref.read(authRepositoryProvider).verifyOtp(
              target: _phoneCtrl.text.trim(),
              channel: 'phone',
              purpose: 'register',
              code: _otpCtrl.text.trim(),
              profile: {
                'name': _nameCtrl.text.trim(),
                'age': int.tryParse(_ageCtrl.text) ?? 18,
                'gender': _gender,
                'city': _cityCtrl.text.trim(),
              },
            );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account created successfully!'), backgroundColor: Colors.green),
        );
        context.go('/home');
      }
    } catch (e) {
      setState(() => _globalError = e.toString().replaceFirst('Exception: ', ''));
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
                    const SizedBox(height: 24),
                    Text(
                      'Create account',
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
                          // Tab toggle
                          _TabToggle(
                            active: _tab,
                            onChanged: (t) => setState(() {
                              _tab = t;
                              _errors = {};
                              _globalError = null;
                              _otpSent = false;
                              _otpCtrl.clear();
                            }),
                          ),
                          const SizedBox(height: 16),

                          // Common fields (only before OTP)
                          if (!_otpSent) ...[
                            _InputField(
                              controller: _nameCtrl,
                              label: 'Full Name',
                              placeholder: 'John Doe',
                              prefixIcon: LucideIcons.user,
                              error: _errors['name'],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _InputField(
                                    controller: _ageCtrl,
                                    label: 'Age',
                                    placeholder: '25',
                                    keyboardType: TextInputType.number,
                                    error: _errors['age'],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _GenderDropdown(
                                    value: _gender,
                                    onChanged: (v) => setState(() => _gender = v),
                                    error: _errors['gender'],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            CityAutocompleteField(
                              initialValue: _cityCtrl.text,
                              onChanged: (city) => _cityCtrl.text = city,
                              label: 'City',
                              hint: 'Dhaka',
                              errorText: _errors['city'],
                            ),
                            const SizedBox(height: 12),

                            // Tab-specific fields
                            if (_tab == 'email') ...[
                              _InputField(
                                controller: _emailCtrl,
                                label: 'Email Address',
                                placeholder: 'you@example.com',
                                prefixIcon: LucideIcons.mail,
                                keyboardType: TextInputType.emailAddress,
                                autocapitalize: false,
                                error: _errors['email'],
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
                                error: _errors['password'],
                              ),
                            ] else ...[
                              _InputField(
                                controller: _phoneCtrl,
                                label: 'Phone Number',
                                placeholder: '+88017...',
                                prefixIcon: LucideIcons.phone,
                                keyboardType: TextInputType.phone,
                                error: _errors['phone'],
                              ),
                            ],
                          ],

                          // OTP entry
                          if (_otpSent) ...[
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF0F8),
                                borderRadius: AppRadius.border12,
                                border: Border.all(color: const Color(0xFFFFD6EC)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Verify your $_tab',
                                    style: AppTextStyles.textSmBold.copyWith(color: AppColors.brandPink700),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Enter the 6-digit code sent to ${_tab == 'email' ? _emailCtrl.text : _phoneCtrl.text}.',
                                    style: AppTextStyles.textSm.copyWith(color: AppColors.gray600),
                                  ),
                                  const SizedBox(height: 12),
                                  _InputField(
                                    controller: _otpCtrl,
                                    label: '',
                                    placeholder: '000000',
                                    keyboardType: TextInputType.number,
                                    maxLength: 6,
                                    error: _errors['otp'],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      GestureDetector(
                                        onTap: () => setState(() {
                                          _otpSent = false;
                                          _otpCtrl.clear();
                                        }),
                                        child: Text(
                                          'Change info',
                                          style: AppTextStyles.textSm.copyWith(
                                            color: AppColors.gray500,
                                            decoration: TextDecoration.underline,
                                          ),
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: _cooldown > 0 ? null : _handleSendCode,
                                        child: Text(
                                          _cooldown > 0 ? 'Resend ($_cooldown s)' : 'Resend Code',
                                          style: AppTextStyles.textSmBold.copyWith(
                                            color: _cooldown > 0 ? AppColors.gray400 : AppColors.brandPink,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],

                          if (_globalError != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF1F1),
                                borderRadius: AppRadius.border8,
                                border: Border.all(color: const Color(0xFFFFD5D5)),
                              ),
                              child: Text(
                                _globalError!,
                                textAlign: TextAlign.center,
                                style: AppTextStyles.textSm.copyWith(color: AppColors.danger),
                              ),
                            ),
                          ],

                          const SizedBox(height: 16),

                          // Action button
                          _PinkButton(
                            label: _otpSent ? 'Verify & Create Account' : 'Send Verification Code',
                            loading: _loading,
                            onPressed: _otpSent ? _handleVerifyAndRegister : _handleSendCode,
                          ),

                          const SizedBox(height: 12),
                          GestureDetector(
                            onTap: () => context.go('/login'),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: RichText(
                                textAlign: TextAlign.center,
                                text: TextSpan(
                                  style: AppTextStyles.textBase.copyWith(color: AppColors.gray500),
                                  children: [
                                    const TextSpan(text: 'Already have an account? '),
                                    TextSpan(
                                      text: 'Sign In',
                                      style: AppTextStyles.textBaseBold.copyWith(color: AppColors.brandPink),
                                    ),
                                  ],
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
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _TabToggle extends StatelessWidget {
  final String active;
  final ValueChanged<String> onChanged;

  const _TabToggle({required this.active, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: AppColors.gray100, borderRadius: AppRadius.border12),
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
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? AppColors.white : Colors.transparent,
            borderRadius: AppRadius.border8,
            boxShadow: isActive
                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 1))]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: isActive ? AppColors.brandPink : AppColors.gray500),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppTextStyles.textBaseBold.copyWith(
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
  final IconData? prefixIcon;
  final bool obscure;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixTap;
  final TextInputType keyboardType;
  final bool autocapitalize;
  final int? maxLength;
  final String? error;

  const _InputField({
    required this.controller,
    required this.label,
    required this.placeholder,
    this.prefixIcon,
    this.obscure = false,
    this.suffixIcon,
    this.onSuffixTap,
    this.keyboardType = TextInputType.text,
    this.autocapitalize = true,
    this.maxLength,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
          Text(label, style: AppTextStyles.textSm.copyWith(color: AppColors.gray700, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
        ],
        Container(
          decoration: BoxDecoration(
            color: AppColors.gray100,
            borderRadius: AppRadius.border8,
            border: error != null ? Border.all(color: AppColors.danger) : null,
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
              prefixIcon: prefixIcon != null
                  ? Icon(prefixIcon, size: 18, color: AppColors.gray400)
                  : null,
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
        if (error != null && error!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(error!, style: AppTextStyles.textXs.copyWith(color: AppColors.danger)),
        ],
      ],
    );
  }
}

class _GenderDropdown extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final String? error;

  const _GenderDropdown({required this.value, required this.onChanged, this.error});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Gender', style: AppTextStyles.textSm.copyWith(color: AppColors.gray700, fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.gray100,
            borderRadius: AppRadius.border8,
            border: error != null ? Border.all(color: AppColors.danger) : null,
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              style: AppTextStyles.textBase.copyWith(color: AppColors.gray900),
              dropdownColor: AppColors.white,
              items: const [
                DropdownMenuItem(value: 'male', child: Text('Male')),
                DropdownMenuItem(value: 'female', child: Text('Female')),
                DropdownMenuItem(value: 'other', child: Text('Other')),
              ],
              onChanged: (v) => onChanged(v ?? 'male'),
            ),
          ),
        ),
        if (error != null && error!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(error!, style: AppTextStyles.textXs.copyWith(color: AppColors.danger)),
        ],
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
