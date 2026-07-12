import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../models/conversation.dart';
import '../../state/conversations_provider.dart';
import '../../state/messages_provider.dart';
import '../../state/notifications_provider.dart';
import '../../data/messages_repository.dart';
import '../../widgets/widgets.dart';

class ChatsScreen extends ConsumerStatefulWidget {
  const ChatsScreen({super.key});

  @override
  ConsumerState<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends ConsumerState<ChatsScreen> {
  String _filter = 'all'; // 'all' | 'unread'

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refetch on focus (equivalent to useFocusEffect in RN)
    _refetch();
  }

  Future<void> _refetch() async {
    try {
      await ref.read(conversationsProvider.notifier).refresh();
      await ref.read(notificationsProvider.notifier).refresh();
    } catch (_) {}
  }

  Future<void> _onRefresh() async {
    await _refetch();
  }

  Map<String, int> _buildUnreadCounts(List notifications) {
    final counts = <String, int>{};
    for (final n in notifications) {
      if (!n.isRead && n.type == 'message' && n.actorId.isNotEmpty) {
        counts[n.actorId] = (counts[n.actorId] ?? 0) + 1;
      }
    }
    return counts;
  }

  Future<void> _handleDeleteChat(Conversation convo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Chat'),
        content: Text(
            'Are you sure you want to delete your conversation with ${convo.otherUser.name ?? 'this user'}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style:
                TextButton.styleFrom(foregroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref
          .read(messagesRepositoryProvider)
          .clearChat(convo.otherUser.id);
      // Also empty the kept-alive message cache for this peer, or reopening the
      // chat (e.g. from their profile) would re-show the deleted messages from
      // the stale in-memory cache (BUG #5b).
      ref.read(messagesProvider(convo.otherUser.id).notifier).clearAll();
      await ref.read(conversationsProvider.notifier).refresh();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete conversation. Please try again.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final convosAsync = ref.watch(conversationsProvider);
    final notificationsAsync = ref.watch(notificationsProvider);

    final notifications = notificationsAsync.asData?.value ?? [];
    final unreadCounts = _buildUnreadCounts(notifications);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: const Text(
                'Messages',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFE91D7C),
                ),
              ),
            ),
            // All / Unread filter pills
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  _FilterPill(
                    label: 'All',
                    selected: _filter == 'all',
                    onTap: () => setState(() => _filter = 'all'),
                  ),
                  const SizedBox(width: 8),
                  _FilterPill(
                    label: 'Unread',
                    selected: _filter == 'unread',
                    onTap: () => setState(() => _filter = 'unread'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFF9FAFB)),
            // List
            Expanded(
              child: convosAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFFE91D7C),
                  ),
                ),
                error: (e, s) => Center(child: Text('Error: $e')),
                data: (convos) {
                  final filtered = _filter == 'unread'
                      ? convos
                          .where((c) =>
                              (unreadCounts[c.otherUser.id] ?? 0) > 0 ||
                              c.unreadCount > 0)
                          .toList()
                      : convos;

                  if (filtered.isEmpty) {
                    return RefreshIndicator(
                      color: const Color(0xFFE91D7C),
                      onRefresh: _onRefresh,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: SizedBox(
                          height: MediaQuery.of(context).size.height * 0.6,
                          child: Center(
                            child: EmptyState(
                              title: _filter == 'unread'
                                  ? 'No Unread Messages'
                                  : 'No Messages',
                              description: _filter == 'unread'
                                  ? "You're all caught up!"
                                  : 'Connect with people to start chatting.',
                            ),
                          ),
                        ),
                      ),
                    );
                  }

                  return RefreshIndicator(
                    color: const Color(0xFFE91D7C),
                    onRefresh: _onRefresh,
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: filtered.length,
                      separatorBuilder: (ctx, i) => const Divider(
                        height: 1,
                        color: Color(0xFFF3F4F6),
                        indent: 76,
                      ),
                      itemBuilder: (ctx, i) {
                        final convo = filtered[i];
                        final unread =
                            unreadCounts[convo.otherUser.id] ?? 0;

                        return Slidable(
                          key: ValueKey(convo.otherUser.id),
                          endActionPane: ActionPane(
                            motion: const DrawerMotion(),
                            extentRatio: 0.22,
                            children: [
                              SlidableAction(
                                onPressed: (_) =>
                                    _handleDeleteChat(convo),
                                backgroundColor: const Color(0xFFEF4444),
                                foregroundColor: Colors.white,
                                icon: LucideIcons.trash2,
                                label: 'Delete',
                                padding: EdgeInsets.zero,
                              ),
                            ],
                          ),
                          child: ConversationRow(
                            conversation: convo,
                            unreadCount: unread,
                            onTap: () =>
                                context.push('/chats/${convo.otherUser.id}'),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color:
              selected ? const Color(0xFFE91D7C) : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : const Color(0xFF4B5563),
          ),
        ),
      ),
    );
  }
}
