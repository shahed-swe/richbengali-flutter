import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/me_repository.dart';
import '../../models/user.dart';
import '../../state/auth_provider.dart';
import '../../state/me_provider.dart';
import '../../theme/theme.dart';
import '../../widgets/animated_logo.dart';
import '../../widgets/city_autocomplete_field.dart';
import '../../widgets/image_viewer.dart';
import '../../widgets/me/extended_fields.dart';
import '../../widgets/me/photos_grid.dart';

class MeScreen extends ConsumerStatefulWidget {
  const MeScreen({super.key});

  @override
  ConsumerState<MeScreen> createState() => _MeScreenState();
}

class _MeScreenState extends ConsumerState<MeScreen> {
  // Basic Info controllers
  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();

  // Extended fields patch (reported by ExtendedFields widget via onChanged)
  Map<String, dynamic> _extendedPatch = {};

  bool _saving = false;
  bool _avatarLoading = false;
  String? _viewedImage;

  // Track which user id the controllers were last seeded from.
  // Re-seed whenever a different user's data loads (e.g. after account switch).
  String? _seededForId;

  final _picker = ImagePicker();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  void _seedFrom(Me me) {
    if (_seededForId == me.id) return;
    _seededForId = me.id;
    _nameCtrl.text = me.name;
    _ageCtrl.text = me.age?.toString() ?? '';
    _cityCtrl.text = me.city ?? '';
    _extendedPatch = {};
  }

  bool _hasTags(String v) => RegExp(r'<[^>]*>?').hasMatch(v);

  bool get _basicValid =>
      !_hasTags(_nameCtrl.text) && !_hasTags(_cityCtrl.text);

  Map<String, dynamic> _buildPatch() {
    final age = int.tryParse(_ageCtrl.text.trim());
    return {
      'name': _nameCtrl.text.trim(),
      'age': age,
      'city': _cityCtrl.text.trim(),
      ..._extendedPatch,
    };
  }

  Future<void> _handleSave() async {
    if (!_basicValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('HTML/Script tags not allowed in fields')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(meProvider.notifier).patchMe(_buildPatch());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update profile: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _handleLogout() async {
    await ref.read(authProvider.notifier).logout();
    if (mounted) context.go('/login');
  }

  Future<void> _handlePickAvatar() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (file == null) return;

    setState(() => _avatarLoading = true);
    try {
      final repo = ref.read(meRepositoryProvider);
      final photo = await repo.uploadPhoto(file.path);
      await repo.setPrimaryPhoto(photo.id);
      await ref.read(meProvider.notifier).refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Avatar updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload avatar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _avatarLoading = false);
    }
  }

  Future<void> _handleOpenUrl(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final meAsync = ref.watch(meProvider);
    final topInset = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppColors.white,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // ── Main content ───────────────────────────────────────────────
          meAsync.when(
            loading: () => const Center(child: AnimatedLogo(size: 80)),
            error: (e, _) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Failed to load profile',
                    style: AppTextStyles.textBase.copyWith(color: AppColors.gray600),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => ref.read(meProvider.notifier).refresh(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
            data: (me) {
              _seedFrom(me);
              return _buildScrollableContent(me, topInset);
            },
          ),

          // ── Image viewer overlay ───────────────────────────────────────
          ImageViewer(
            imageUrl: _viewedImage,
            isVisible: _viewedImage != null,
            onClose: () => setState(() => _viewedImage = null),
          ),
        ],
      ),
    );
  }

  Widget _buildScrollableContent(Me me, double topInset) {
    return Stack(
      children: [
        // Scrollable body
        RefreshIndicator(
          color: AppColors.brandPink,
          onRefresh: () => ref.read(meProvider.notifier).refresh(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Gradient header ──────────────────────────────────────
                Container(
                  height: 240 + topInset,
                  decoration: const BoxDecoration(
                    gradient: AppGradients.meHeader,
                  ),
                  padding: EdgeInsets.only(
                    top: topInset + 16,
                    left: 24,
                    right: 24,
                    bottom: 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(LucideIcons.user, color: AppColors.white, size: 28),
                          const SizedBox(width: 8),
                          Text(
                            'Edit Profile',
                            style: AppTextStyles.textXlBold.copyWith(color: AppColors.white),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Keep your profile fresh to get more matches',
                        style: AppTextStyles.textBase.copyWith(
                          color: AppColors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Cards — overlap the header by 64px ──────────────────
                Transform.translate(
                  offset: const Offset(0, -64),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                    child: Column(
                      children: [
                        // Avatar card
                        _buildAvatarCard(me),
                        const SizedBox(height: 16),

                        // Earnings card (female only)
                        if (me.gender == 'female') ...[
                          _buildEarningsCard(),
                          const SizedBox(height: 16),
                        ],

                        // Basic Info card
                        _buildBasicInfoCard(),
                        const SizedBox(height: 16),

                        // Photos card
                        _buildPhotosCard(me),
                        const SizedBox(height: 16),

                        // More About You card
                        _buildExtendedCard(me),
                        const SizedBox(height: 16),

                        // Legal & Privacy card
                        _buildLegalCard(),

                        // Bottom padding so content clears the sticky bar
                        const SizedBox(height: 130),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Sticky bottom action bar ─────────────────────────────────────
        Positioned(
          bottom: 32,
          left: 32,
          right: 32,
          child: _buildBottomBar(),
        ),
      ],
    );
  }

  // ── Card builders ──────────────────────────────────────────────────────────

  Widget _buildAvatarCard(Me me) {
    return _Card(
      child: Column(
        children: [
          Stack(
            children: [
              GestureDetector(
                onTap: () {
                  final url = me.displayPhotoUrl;
                  if (url != null) setState(() => _viewedImage = url);
                },
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.gray100,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: me.displayPhotoUrl != null
                      ? CachedNetworkImage(
                          imageUrl: me.displayPhotoUrl!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => const Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(AppColors.brandPink),
                            ),
                          ),
                          errorWidget: (context, url, error) => const Icon(
                            LucideIcons.user,
                            size: 48,
                            color: AppColors.gray400,
                          ),
                        )
                      : const Icon(LucideIcons.user, size: 48, color: AppColors.gray400),
                ),
              ),
              // Loading overlay
              if (_avatarLoading)
                Positioned(
                  left: 0,
                  top: 0,
                  width: 120,
                  height: 120,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.brandPink),
                      ),
                    ),
                  ),
                ),
              // Camera button
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _avatarLoading ? null : _handlePickAvatar,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.brandPink,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.white, width: 3),
                    ),
                    child: const Icon(LucideIcons.camera, size: 18, color: AppColors.white),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '${me.name}${me.age != null ? ', ${me.age}' : ''}',
            style: AppTextStyles.text2xlBold.copyWith(color: AppColors.gray900),
          ),
          if (me.city != null && me.city!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              me.city!,
              style: AppTextStyles.textBase.copyWith(color: AppColors.gray500),
            ),
          ],
          if (me.email != null) ...[
            const SizedBox(height: 2),
            Text(
              me.email!,
              style: AppTextStyles.textBase.copyWith(color: AppColors.gray500),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEarningsCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: AppRadius.border24,
        border: Border.all(
          color: AppColors.emerald500.withValues(alpha: 0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(LucideIcons.wallet, color: AppColors.emerald500, size: 22),
              const SizedBox(width: 8),
              Text(
                'Earnings',
                style: AppTextStyles.textLgBold.copyWith(color: AppColors.gray800),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => context.push('/me/earnings'),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFecfdf5),
                borderRadius: AppRadius.border12,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'View Dashboard',
                    style: AppTextStyles.textLgBold.copyWith(color: AppColors.emerald700),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfoCard() {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Basic Info',
            style: AppTextStyles.textLgBold.copyWith(color: AppColors.gray700),
          ),
          const SizedBox(height: 16),
          _FormField(
            label: 'Name',
            controller: _nameCtrl,
            hasError: _hasTags(_nameCtrl.text),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          _FormField(
            label: 'Age',
            controller: _ageCtrl,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          CityAutocompleteField(
            style: CityAutocompleteFieldStyle.outlined,
            label: 'City',
            initialValue: _cityCtrl.text,
            errorText: _hasTags(_cityCtrl.text) ? 'HTML/Script tags not allowed' : null,
            onChanged: (city) => setState(() => _cityCtrl.text = city),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotosCard(Me me) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Photos',
            style: AppTextStyles.textLgBold.copyWith(color: AppColors.gray700),
          ),
          const SizedBox(height: 4),
          Text(
            'Max 5 photos, ≤2MB each',
            style: AppTextStyles.textXs.copyWith(color: AppColors.gray500),
          ),
          const SizedBox(height: 16),
          PhotosGrid(
            photos: me.sortedPhotos,
            onImagePress: (url) => setState(() => _viewedImage = url),
          ),
        ],
      ),
    );
  }

  Widget _buildExtendedCard(Me me) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'More About You',
            style: AppTextStyles.textLgBold.copyWith(color: AppColors.gray700),
          ),
          const SizedBox(height: 16),
          ExtendedFields(
            initialValues: {
              'height_cm': me.heightCm,
              'weight_kg': me.weightKg,
              'work': me.work,
              'education': me.education,
              'looking_for': me.lookingFor,
              'education_level': me.educationLevel,
              'drinking': me.drinking,
              'smoking': me.smoking,
              'religion': me.religion,
              'languages': me.languages,
              'interests': me.interests,
            },
            onChanged: (patch) {
              _extendedPatch = patch;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLegalCard() {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Legal & Privacy',
            style: AppTextStyles.textLgBold.copyWith(color: AppColors.gray700),
          ),
          const SizedBox(height: 4),
          Text(
            'Please review our legal terms and community safety guidelines before continuing.',
            style: AppTextStyles.textXs.copyWith(color: AppColors.gray500),
          ),
          const SizedBox(height: 14),
          _LegalRow(
            icon: LucideIcons.fileText,
            label: 'Terms of Service',
            onTap: () => _handleOpenUrl('https://richbengali.com/terms'),
          ),
          const SizedBox(height: 8),
          _LegalRow(
            icon: LucideIcons.shield,
            label: 'Privacy Policy',
            onTap: () => _handleOpenUrl('https://richbengali.com/privacy'),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Row(
      children: [
        // Logout — red circle
        GestureDetector(
          onTap: _handleLogout,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFfef2f2),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFfee2e2)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                ),
              ],
            ),
            child: const Icon(LucideIcons.logOut, size: 22, color: AppColors.danger),
          ),
        ),
        const SizedBox(width: 12),
        // Save Changes — gradient pill
        Expanded(
          child: GestureDetector(
            onTap: _saving ? null : _handleSave,
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                gradient: AppGradients.saveButton,
                borderRadius: AppRadius.borderFull,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.brandPink.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: _saving
                  ? const Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.white),
                          strokeWidth: 2.5,
                        ),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(LucideIcons.save, size: 20, color: AppColors.white),
                        const SizedBox(width: 8),
                        Text(
                          'Save Changes',
                          style: AppTextStyles.textLgBold.copyWith(color: AppColors.white),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Shared sub-widgets ────────────────────────────────────────────────────────

/// White rounded card with shadow — matches the RN `rounded-3xl shadow-lg p-6`
class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: AppRadius.border24,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _FormField extends StatelessWidget {
  const _FormField({
    required this.label,
    required this.controller,
    this.keyboardType,
    this.hasError = false,
    this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final bool hasError;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.textSm.copyWith(color: AppColors.gray700),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          onChanged: onChanged,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            filled: true,
            fillColor: AppColors.gray50,
            border: OutlineInputBorder(
              borderRadius: AppRadius.border12,
              borderSide: BorderSide(
                color: hasError ? AppColors.danger : AppColors.gray200,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: AppRadius.border12,
              borderSide: BorderSide(
                color: hasError ? AppColors.danger : AppColors.gray200,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: AppRadius.border12,
              borderSide: BorderSide(
                color: hasError ? AppColors.danger : AppColors.brandPink,
              ),
            ),
            errorText: hasError ? 'HTML/Script tags not allowed' : null,
            suffixIcon: hasError
                ? const Icon(LucideIcons.alertCircle, color: AppColors.danger, size: 18)
                : null,
          ),
          style: AppTextStyles.textBase.copyWith(color: AppColors.gray900),
        ),
      ],
    );
  }
}

class _LegalRow extends StatelessWidget {
  const _LegalRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: const Color(0xFFf8fafc),
          borderRadius: AppRadius.border12,
          border: Border.all(color: const Color(0xFFf1f5f9)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: const Color(0xFF475569)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.textBaseBold.copyWith(
                  color: const Color(0xFF334155),
                ),
              ),
            ),
            const Icon(LucideIcons.chevronRight, size: 18, color: Color(0xFF94a3b8)),
          ],
        ),
      ),
    );
  }
}
