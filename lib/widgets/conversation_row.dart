import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../models/conversation.dart';

/// Mirrors ConversationRow.tsx — 48 px avatar, status dot, name, city, badge.
class ConversationRow extends StatelessWidget {
  const ConversationRow({
    super.key,
    required this.conversation,
    required this.unreadCount,
    required this.onTap,
  });

  final Conversation conversation;
  final int unreadCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final user = conversation.otherUser;
    final isInCall = user.isInCall;
    final isOnline = user.isOnline;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Avatar + status dot
            SizedBox(
              width: 48,
              height: 48,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipOval(
                    child: user.profilePictureUrl != null &&
                            user.profilePictureUrl!.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: user.profilePictureUrl!,
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                            placeholder: (ctx, u) => Container(
                              width: 48,
                              height: 48,
                              color: const Color(0xFFE5E7EB),
                            ),
                            errorWidget: (ctx, u, e) => _avatarFallback(user.name),
                          )
                        : _avatarFallback(user.name),
                  ),
                  if (isOnline || isInCall)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isInCall
                              ? const Color(0xFFEF4444)
                              : const Color(0xFF22C55E),
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Name + city + in-call badge
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          user.name ?? '',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF111827),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isInCall) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(color: const Color(0xFFFEE2E2)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFFEF4444),
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                'IN CALL',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFDC2626),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user.city ?? 'No location',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B7280),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Unread badge
            if (unreadCount > 0) ...[
              Container(
                constraints: const BoxConstraints(minWidth: 20),
                height: 20,
                padding: const EdgeInsets.symmetric(horizontal: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(99),
                ),
                alignment: Alignment.center,
                child: Text(
                  unreadCount > 99 ? '99+' : '$unreadCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Icon(
              LucideIcons.chevronRight,
              size: 20,
              color: const Color(0xFF9CA3AF),
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatarFallback(String? name) {
    return Container(
      width: 48,
      height: 48,
      color: const Color(0xFFE5E7EB),
      alignment: Alignment.center,
      child: Text(
        (name?.isNotEmpty == true) ? name![0].toUpperCase() : '?',
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Color(0xFF6B7280),
        ),
      ),
    );
  }
}
