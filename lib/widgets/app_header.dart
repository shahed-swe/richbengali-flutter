import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import '../state/me_provider.dart';
import '../state/notifications_provider.dart';
import '../models/notification.dart';
import '../theme/theme.dart';

/// Sticky app header matching AppHeader.tsx + HeaderRight.tsx
class AppHeader extends ConsumerWidget implements PreferredSizeWidget {
  const AppHeader({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topPad = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.only(top: topPad + 10, bottom: 8),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFf3f4f6))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Image.asset(
              'assets/logo.png',
              width: 120,
              height: 32,
              fit: BoxFit.contain,
            ),
          ),
          const _HeaderRight(),
        ],
      ),
    );
  }
}

class _HeaderRight extends ConsumerWidget {
  const _HeaderRight();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meAsync = ref.watch(meProvider);
    final unreadCount = ref.watch(unreadNotificationCountProvider);

    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Balance/minutes pill
          meAsync.when(
            loading: () => const _BalancePillSkeleton(isMale: false),
            error: (e, _) => const SizedBox.shrink(),
            data: (me) {
              final isMale = me.isMale;
              if (isMale) {
                // Green pill — shows call minutes
                final minutes = (me.availableCallMinutes ?? 0).floor();
                return GestureDetector(
                  onTap: () => context.push('/plans'),
                  child: _Pill(
                    bgColor: const Color(0xFFdcfce7),
                    borderColor: const Color(0xFFbbf7d0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          LucideIcons.crown,
                          size: 14,
                          color: Color(0xFF15803d),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$minutes mins',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF15803d),
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              } else {
                // Purple pill — shows wallet balance
                final balance = me.walletBalanceUsd ?? me.balance ?? 0.0;
                return GestureDetector(
                  onTap: () => context.push('/me/earnings'),
                  child: _Pill(
                    bgColor: const Color(0xFFede9fe),
                    borderColor: const Color(0xFFddd6fe),
                    child: Text(
                      '\$${balance.isNaN ? "0.00" : balance.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6d28d9),
                        height: 1,
                      ),
                    ),
                  ),
                );
              }
            },
          ),

          const SizedBox(width: 12),

          // Bell icon + notifications popover
          _NotificationBell(unreadCount: unreadCount),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.bgColor,
    required this.borderColor,
    required this.child,
  });
  final Color bgColor;
  final Color borderColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}

class _BalancePillSkeleton extends StatelessWidget {
  const _BalancePillSkeleton({required this.isMale});
  final bool isMale;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      width: 80,
      decoration: BoxDecoration(
        color: isMale
            ? const Color(0xFFdcfce7)
            : const Color(0xFFede9fe),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _NotificationBell extends ConsumerStatefulWidget {
  const _NotificationBell({required this.unreadCount});
  final int unreadCount;

  @override
  ConsumerState<_NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends ConsumerState<_NotificationBell> {
  void _showNotificationsMenu(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (ctx) => _NotificationsDialog(
        onMarkAll: () {
          ref.read(notificationsProvider.notifier).markAllRead();
        },
        onMarkRead: (id) {
          ref.read(notificationsProvider.notifier).markRead(id);
        },
        onNotificationTap: (n, ctx) {
          Navigator.of(ctx).pop();
          final actorId = n.actor?.id ?? n.actorId;
          final type = n.type.toLowerCase();
          if (type == 'message') {
            context.push('/chats/$actorId');
          } else if (['like', 'favorite', 'superlike', 'visit']
              .contains(type)) {
            context.push('/home/user/$actorId');
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        ref.read(notificationsProvider.notifier).refresh();
        _showNotificationsMenu(context);
      },
      child: SizedBox(
        width: 40,
        height: 40,
        child: Stack(
          children: [
            Center(
              child: Icon(LucideIcons.bell, size: 24, color: AppColors.gray700),
            ),
            if (widget.unreadCount > 0)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: AppColors.danger,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Center(
                    child: Text(
                      widget.unreadCount > 99
                          ? '99+'
                          : '${widget.unreadCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NotificationsDialog extends ConsumerWidget {
  const _NotificationsDialog({
    required this.onMarkAll,
    required this.onMarkRead,
    required this.onNotificationTap,
  });

  final VoidCallback onMarkAll;
  final void Function(String id) onMarkRead;
  final void Function(NotificationItem n, BuildContext ctx) onNotificationTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenWidth = MediaQuery.of(context).size.width;
    // Watch the provider live so the list updates the moment it (re)loads —
    // fixes the "badge shows 2 but dropdown empty" snapshot bug.
    final notifications = ref.watch(notificationsProvider).asData?.value ?? [];
    final sorted = [...notifications]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Align(
      alignment: Alignment.topRight,
      child: Padding(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 64,
          right: 16,
        ),
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: screenWidth * 0.9,
            constraints: const BoxConstraints(maxWidth: 400, maxHeight: 450),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ],
              border: Border.all(color: AppColors.gray100),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Notifications',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827),
                        ),
                      ),
                      GestureDetector(
                        onTap: onMarkAll,
                        child: Text(
                          'Mark all as read',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.brandPink,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: AppColors.gray100),

                // List
                Flexible(
                  child: sorted.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                LucideIcons.bell,
                                size: 32,
                                color: AppColors.gray300,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No notifications yet.',
                                style: TextStyle(
                                  color: AppColors.gray400,
                                  fontSize: 13,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          itemCount: sorted.length,
                          separatorBuilder: (ctx, i) =>
                              Divider(height: 1, color: AppColors.gray100),
                          itemBuilder: (_, i) {
                            final n = sorted[i];
                            return _NotificationRow(
                              notification: n,
                              onTap: () {
                                if (!n.isRead) onMarkRead(n.id);
                                onNotificationTap(n, context);
                              },
                            );
                          },
                        ),
                ),

                Divider(height: 1, color: AppColors.gray100),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    color: AppColors.gray50,
                    child: Center(
                      child: Text(
                        'Dismiss',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.gray500,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
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

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({
    required this.notification,
    required this.onTap,
  });
  final NotificationItem notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final bgColor = n.isRead ? Colors.white : const Color(0xFFfff1f2);
    final actorName = n.actor?.name ?? '?';
    final avatarUrl = n.actor?.profilePictureUrl;
    final typeLabel =
        n.type.toLowerCase() == 'message' ? 'New Message' : n.type.toUpperCase();
    final subLabel = n.type.toLowerCase() == 'message'
        ? 'from $actorName'
        : 'interaction: ${n.type}';

    // Format time
    String timeStr = '';
    try {
      final dt = DateTime.parse(n.createdAt);
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      timeStr = '$h:$m';
    } catch (_) {}

    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: bgColor,
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 36,
              height: 36,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.brandPink.withValues(alpha: 0.15),
              ),
              clipBehavior: Clip.antiAlias,
              child: avatarUrl != null
                  ? Image.network(avatarUrl, fit: BoxFit.cover)
                  : Center(
                      child: Text(
                        actorName.isNotEmpty
                            ? actorName[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          color: AppColors.brandPink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        typeLabel,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: n.isRead
                              ? FontWeight.w400
                              : FontWeight.w700,
                          color: const Color(0xFF1f2937),
                        ),
                      ),
                      Text(
                        timeStr,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.gray400,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subLabel,
                    style:
                        TextStyle(fontSize: 12, color: AppColors.gray500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
