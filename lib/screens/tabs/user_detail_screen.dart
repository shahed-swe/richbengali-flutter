import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../state/user_detail_provider.dart';
import '../../state/favorites_provider.dart';
import '../../models/ref_option.dart';
import '../../data/refs_repository.dart';
import '../../widgets/image_viewer.dart';
import '../../theme/theme.dart';

// Ref data providers (family by type string)
final _refProvider =
    FutureProvider.family<Map<String, String>, String>((ref, type) async {
  final opts = await ref.read(refsRepositoryProvider).getRefs(type);
  return buildRefMap(opts);
});

class UserDetailScreen extends ConsumerStatefulWidget {
  const UserDetailScreen({super.key, required this.userId});
  final String userId;

  @override
  ConsumerState<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends ConsumerState<UserDetailScreen> {
  String? _viewedImage;

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userDetailProvider(widget.userId));
    final statusAsync = ref.watch(relationStatusProvider(widget.userId));
    final status = statusAsync.asData?.value;

    final lfMap =
        ref.watch(_refProvider('looking_for')).asData?.value ?? {};
    final elMap =
        ref.watch(_refProvider('education_level')).asData?.value ?? {};
    final relMap = ref.watch(_refProvider('religion')).asData?.value ?? {};
    final langMap =
        ref.watch(_refProvider('language')).asData?.value ?? {};
    final intMap =
        ref.watch(_refProvider('interest')).asData?.value ?? {};

    return userAsync.when(
      loading: () => const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFe91d7c)),
        ),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.chevronLeft, color: Colors.white),
            ),
          ),
        ),
        body: const Center(child: Text('Could not load profile')),
      ),
      data: (user) {
        final photos = user.sortedPhotos;
        final primaryUrl = photos.isNotEmpty
            ? photos.first.url
            : user.primaryPhotoUrl ?? user.profilePictureUrl ?? '';

        return Scaffold(
          backgroundColor: Colors.white,
          body: Stack(
            children: [
              // Scrollable content
              SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Hero image (450 height)
                    GestureDetector(
                      onTap: () => setState(() =>
                          _viewedImage =
                              primaryUrl.isNotEmpty ? primaryUrl : null),
                      child: SizedBox(
                        height: 450,
                        width: double.infinity,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // Hero image
                            if (primaryUrl.isNotEmpty)
                              CachedNetworkImage(
                                imageUrl: primaryUrl,
                                fit: BoxFit.cover,
                              )
                            else
                              Container(color: AppColors.gray200),

                            // Bottom gradient
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              height: 200,
                              child: Container(
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Color(0xCC000000)
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            // Back button
                            Positioned(
                              top: MediaQuery.of(context).padding.top + 8,
                              left: 16,
                              child: GestureDetector(
                                onTap: () => context.pop(),
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    LucideIcons.chevronLeft,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                              ),
                            ),

                            // Name/age + badges overlay
                            Positioned(
                              bottom: 32,
                              left: 24,
                              right: 24,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  RichText(
                                    text: TextSpan(
                                      children: [
                                        TextSpan(
                                          text: user.name,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 32,
                                            fontWeight: FontWeight.w900,
                                            shadows: [
                                              Shadow(
                                                color: Color(0x80000000),
                                                offset: Offset(0, 1),
                                                blurRadius: 2,
                                              )
                                            ],
                                          ),
                                        ),
                                        if (user.age != null)
                                          TextSpan(
                                            text: '  ${user.age}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 22,
                                              fontWeight: FontWeight.w300,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    children: [
                                      if (user.city != null &&
                                          user.city!.isNotEmpty)
                                        _Badge(
                                          icon: LucideIcons.mapPin,
                                          label: user.city!,
                                        ),
                                      if (user.work != null &&
                                          user.work!.isNotEmpty)
                                        _Badge(
                                          icon: LucideIcons.briefcase,
                                          label: user.work!,
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Photo strip (if > 1 photos)
                    if (photos.length > 1)
                      Container(
                        color: Colors.white,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                          child: Row(
                            children: photos.map((p) {
                              return GestureDetector(
                                onTap: () =>
                                    setState(() => _viewedImage = p.url),
                                child: Container(
                                  margin: const EdgeInsets.only(right: 12),
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border:
                                        Border.all(color: AppColors.gray200),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: CachedNetworkImage(
                                    imageUrl: p.url,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),

                    // Details grid
                    Container(
                      color: Colors.white,
                      padding:
                          const EdgeInsets.fromLTRB(24, 24, 24, 120),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Interests
                          const _SectionLabel('Interests'),
                          const SizedBox(height: 8),
                          user.interests.isEmpty
                              ? Text(
                                  'No interests',
                                  style: TextStyle(
                                    color: AppColors.gray400,
                                    fontStyle: FontStyle.italic,
                                  ),
                                )
                              : Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children:
                                      user.interests.map((slug) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFe0e7ff),
                                        borderRadius:
                                            BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        niceLabel(slug, intMap),
                                        style: const TextStyle(
                                          color: Color(0xFF3730a3),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                          const SizedBox(height: 24),

                          // Looking For
                          _InfoBox(
                            label: 'Looking For',
                            value: niceLabel(user.lookingFor, lfMap),
                            large: true,
                          ),
                          const SizedBox(height: 24),

                          // Stats grid
                          Wrap(
                            spacing: 16,
                            runSpacing: 16,
                            children: [
                              _StatBox(
                                label: 'Height',
                                value: user.heightCm != null
                                    ? '${user.heightCm} cm'
                                    : '-',
                              ),
                              _StatBox(
                                label: 'Weight',
                                value: user.weightKg != null
                                    ? '${user.weightKg} kg'
                                    : '-',
                              ),
                              _StatBox(
                                label: 'Drinking',
                                value: niceLabel(user.drinking),
                              ),
                              _StatBox(
                                label: 'Smoking',
                                value: niceLabel(user.smoking),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Languages
                          const _SectionLabel('Languages'),
                          const SizedBox(height: 8),
                          user.languages.isEmpty
                              ? Text(
                                  '-',
                                  style: TextStyle(
                                    color: AppColors.gray400,
                                    fontStyle: FontStyle.italic,
                                  ),
                                )
                              : Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children:
                                      user.languages.map((slug) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                            color: AppColors.gray200),
                                        borderRadius:
                                            BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        niceLabel(slug, langMap),
                                        style: TextStyle(
                                          color: AppColors.gray600,
                                          fontSize: 13,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                          const SizedBox(height: 24),

                          // Education
                          const _SectionLabel('Education'),
                          const SizedBox(height: 4),
                          Text(
                            niceLabel(user.educationLevel, elMap),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF111827),
                            ),
                          ),
                          const Divider(
                              height: 32, color: Color(0xFFf3f4f6)),

                          // Religion
                          const _SectionLabel('Religion'),
                          const SizedBox(height: 4),
                          Text(
                            niceLabel(user.religion, relMap),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF111827),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom floating action bar
              Positioned(
                bottom: 32,
                left: 24,
                right: 24,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.5)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x26000000),
                          blurRadius: 20,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Favorite toggle
                        GestureDetector(
                          onTap: () async {
                            await ref
                                .read(relationStatusProvider(widget.userId)
                                    .notifier)
                                .toggleFavorite();
                            ref
                                .read(favoritesProvider.notifier)
                                .refresh();
                          },
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppColors.gray50,
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: AppColors.gray100),
                            ),
                            child: Center(
                              child: Icon(
                                LucideIcons.heart,
                                size: 20,
                                color: (status?.isFavorited ?? false)
                                    ? AppColors.rose500
                                    : AppColors.gray400,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Say Hi button
                        GestureDetector(
                          onTap: () =>
                              context.push('/chats/${widget.userId}'),
                          child: Container(
                            height: 48,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFFf43f5e),
                                  Color(0xFFf97316)
                                ],
                              ),
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x4Df97316),
                                  blurRadius: 8,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  LucideIcons.messageCircle,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Say Hi',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Like toggle
                        GestureDetector(
                          onTap: () => ref
                              .read(relationStatusProvider(widget.userId)
                                  .notifier)
                              .toggleLike(),
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppColors.gray50,
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: AppColors.gray100),
                            ),
                            child: Center(
                              child: Icon(
                                LucideIcons.thumbsUp,
                                size: 20,
                                color: (status?.isLiked ?? false)
                                    ? const Color(0xFF3b82f6)
                                    : AppColors.gray400,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Image viewer overlay
              if (_viewedImage != null)
                ImageViewer(
                  imageUrl: _viewedImage,
                  isVisible: true,
                  onClose: () => setState(() => _viewedImage = null),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: Color(0xFF9ca3af),
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 2,
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({
    required this.label,
    required this.value,
    this.large = false,
  });
  final String label;
  final String value;
  final bool large;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFf9fafb),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFf3f4f6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel(label),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: large ? 20 : 15,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: (MediaQuery.of(context).size.width - 80) / 2,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFf9fafb),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFf3f4f6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel(label),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }
}
