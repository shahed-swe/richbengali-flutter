import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import '../models/user.dart';
import '../state/user_detail_provider.dart';
import '../theme/theme.dart';

class UserCard extends ConsumerWidget {
  const UserCard({
    super.key,
    required this.user,
    this.routePrefix = '/home',
  });

  final User user;
  final String routePrefix;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = (screenWidth - 48) / 2;
    final cardHeight = cardWidth * (4 / 3);

    final statusAsync =
        ref.watch(relationStatusProvider(user.id.toString()));
    final status = statusAsync.asData?.value;
    final isLiked = status?.isLiked ?? false;
    final isFavorited = status?.isFavorited ?? false;

    final imgUrl = user.displayPhotoUrl;

    return GestureDetector(
      onTap: () => context.push('$routePrefix/user/${user.id}'),
      child: Container(
        width: cardWidth,
        height: cardHeight,
        decoration: BoxDecoration(
          color: AppColors.gray200,
          borderRadius: BorderRadius.circular(24),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Cover image
            if (imgUrl != null && imgUrl.isNotEmpty)
              CachedNetworkImage(
                imageUrl: imgUrl,
                fit: BoxFit.cover,
                errorWidget: (ctx, url, err) => const _Placeholder(),
              )
            else
              const _Placeholder(),

            // Bottom gradient overlay
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 100,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xCC000000)],
                  ),
                ),
              ),
            ),

            // Name/age + city
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: user.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                            ),
                          ),
                          if (user.age != null)
                            TextSpan(
                              text: '  ${user.age}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w400,
                                fontSize: 16,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (user.city != null && user.city!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          user.city!,
                          style: const TextStyle(
                            color: Color(0xCCFFFFFF),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Action buttons (top right)
            Positioned(
              top: 12,
              right: 12,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _CircleButton(
                    isActive: isLiked,
                    onTap: () => ref
                        .read(relationStatusProvider(user.id.toString())
                            .notifier)
                        .toggleLike(),
                    child: Icon(
                      LucideIcons.thumbsUp,
                      size: 14,
                      color: isLiked ? AppColors.brandPurple : Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _CircleButton(
                    isActive: isFavorited,
                    onTap: () => ref
                        .read(relationStatusProvider(user.id.toString())
                            .notifier)
                        .toggleFavorite(),
                    child: Icon(
                      LucideIcons.heart,
                      size: 14,
                      color: isFavorited ? AppColors.brandPink : Colors.white,
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

class _Placeholder extends StatelessWidget {
  const _Placeholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.gray200,
      child: const Center(
        child: Text(
          '?',
          style: TextStyle(fontSize: 36, color: AppColors.gray400),
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.isActive,
    required this.child,
    required this.onTap,
  });

  final bool isActive;
  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xF2FFFFFF)
              : const Color(0x73000000),
          shape: BoxShape.circle,
        ),
        child: Center(child: child),
      ),
    );
  }
}
