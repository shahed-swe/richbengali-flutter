import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../models/message.dart';
import '../../models/user.dart';
import '../../state/active_chat_provider.dart';
import '../../state/auth_provider.dart';
import '../../state/call_overlay_provider.dart';
import '../../state/me_provider.dart';
import '../../state/messages_provider.dart';
import '../../state/notifications_provider.dart';
import '../../data/calls_repository.dart';
import '../../data/messages_repository.dart';
import '../../data/users_repository.dart';
import '../../services/socket_service.dart';

// ---------------------------------------------------------------------------
// ChatDetailScreen
// ---------------------------------------------------------------------------

class ChatDetailScreen extends ConsumerStatefulWidget {
  final String chatId; // otherUserId

  const ChatDetailScreen({super.key, required this.chatId});

  @override
  ConsumerState<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends ConsumerState<ChatDetailScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;

  /// Currently long-pressed / selected message id (for animation)
  String? _selectedMessageId;

  // Socket subscriptions
  StreamSubscription<Map<String, dynamic>>? _chatMessageSub;
  StreamSubscription<Map<String, dynamic>>? _chatMessageDeletedSub;
  StreamSubscription<void>? _chatClearSub;
  StreamSubscription<String>? _chatSeenSub;

  // AnimationControllers keyed by messageId
  final Map<String, AnimationController> _animControllers = {};

  String get _otherUserId => widget.chatId;

  // Whether this screen is the currently-visible route (vs. backgrounded via
  // app lifecycle pause). Used to avoid double-marking active/inactive.
  bool _isVisible = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _textController.addListener(() => setState(() {}));
    // Defer socket setup + notification marking until after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) => _setupSocket());
    WidgetsBinding.instance.addPostFrameCallback((_) => _markNotificationsRead());
    WidgetsBinding.instance.addPostFrameCallback((_) => _markChatVisible());
    // Re-fetch history when (re)opening if it wasn't loaded or was cleared, so a
    // one-off failed load or a prior clear never shows a permanently stale/empty
    // thread (BUG #5a / #5b).
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => ref.read(messagesProvider(_otherUserId).notifier).ensureLoaded());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _textController.dispose();
    _scrollController.dispose();
    _chatMessageSub?.cancel();
    _chatMessageDeletedSub?.cancel();
    _chatClearSub?.cancel();
    _chatSeenSub?.cancel();
    for (final c in _animControllers.values) {
      c.dispose();
    }
    _markChatHidden();
    _teardownSocket();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Covers the case where the app is backgrounded/foregrounded while this
    // chat screen is the visible route — the backend must be told chat:active
    // / chat:inactive to match reality (e.g. a push arrives while backgrounded
    // shouldn't be suppressed as "user is looking at it").
    if (state == AppLifecycleState.resumed) {
      if (_isVisible) _markChatVisible();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      if (_isVisible) _markChatHidden(keepVisibleFlag: true);
    }
  }

  /// Marks this chat as the one the user is currently viewing — updates the
  /// client-authoritative [currentChatPeerIdProvider] and tells the backend
  /// via chat:active so its activeByUser tracking (used to gate
  /// notification:new) matches reality.
  void _markChatVisible() {
    _isVisible = true;
    try {
      ref.read(currentChatPeerIdProvider.notifier).set(_otherUserId);
      ref.read(socketServiceProvider).setActiveChat(_otherUserId);
    } catch (_) {}
  }

  /// Marks this chat as no longer visible (pop, tab-switch, or app
  /// backgrounded). [keepVisibleFlag] is used from the lifecycle callback so
  /// we know to re-mark active on resume without needing another signal.
  void _markChatHidden({bool keepVisibleFlag = false}) {
    if (!keepVisibleFlag) _isVisible = false;
    try {
      // Only clear the global "currently viewing" pointer if it's still us —
      // avoids clobbering a different chat that may have become active.
      if (ref.read(currentChatPeerIdProvider) == _otherUserId) {
        ref.read(currentChatPeerIdProvider.notifier).clear();
      }
      ref.read(socketServiceProvider).setInactiveChat(_otherUserId);
    } catch (_) {}
  }

  void _setupSocket() {
    final socket = ref.read(socketServiceProvider);
    socket.joinChat(_otherUserId);
    // Note: chat:active is emitted by _markChatVisible (called separately via
    // postFrameCallback) rather than here, to keep a single source of truth
    // for the visible/hidden signal shared with pop/tab-switch/lifecycle.

    final myId = ref.read(authProvider).user?.id ?? '';

    _chatMessageSub = socket.onChatMessage.listen((data) {
      // Validate room
      final parts = [myId, _otherUserId]..sort();
      final expectedRoom = parts.join(':');
      if (data['room_id'] != null && data['room_id'] != expectedRoom) return;

      final msg = Message.fromJson(data);
      ref.read(messagesProvider(_otherUserId).notifier).appendRealtime(msg);
      _scrollToBottom();
    });

    _chatMessageDeletedSub = socket.onChatMessageDeleted.listen((data) {
      final msgId = (data['messageId'] ?? '').toString();
      if (msgId.isNotEmpty) {
        ref.read(messagesProvider(_otherUserId).notifier).removeMessage(msgId);
      }
    });

    _chatClearSub = socket.onChatClear.listen((_) {
      ref.read(messagesProvider(_otherUserId).notifier).clearAll();
    });

    // Peer opened the chat → mark our messages to them as seen (double tick).
    _chatSeenSub = socket.onChatSeen.listen((byUserId) {
      if (byUserId == _otherUserId) {
        ref.read(messagesProvider(_otherUserId).notifier).markAllSeen();
      }
    });
  }

  void _teardownSocket() {
    try {
      final socket = ref.read(socketServiceProvider);
      socket.leaveChat(_otherUserId);
      // Note: chat:inactive is emitted by _markChatHidden (called from
      // dispose separately) rather than here.
    } catch (_) {}
  }

  Future<void> _markNotificationsRead() async {
    try {
      final notifications = ref.read(notificationsProvider).asData?.value ?? [];
      final unread = notifications.where((n) =>
          !n.isRead &&
          n.type == 'message' &&
          n.actorId == _otherUserId);
      for (final n in unread) {
        await ref.read(notificationsProvider.notifier).markRead(n.id);
      }
    } catch (_) {}
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isSending) return;

    final myId = ref.read(authProvider).user?.id ?? '';
    setState(() => _isSending = true);
    _textController.clear();

    try {
      await ref
          .read(messagesProvider(_otherUserId).notifier)
          .sendMessage(myId, text);
      _scrollToBottom();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send message. Please try again.')),
        );
        _textController.text = text;
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _deleteMessage(String messageId) async {
    setState(() => _selectedMessageId = null);
    try {
      await ref.read(messagesRepositoryProvider).deleteMessage(messageId);
      ref.read(messagesProvider(_otherUserId).notifier).removeMessage(messageId);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete message. Please try again.')),
        );
      }
    }
  }

  Future<void> _clearConversation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Conversation'),
        content: const Text(
            'Are you sure you want to clear all messages in this conversation? This will delete the messages for you.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style:
                TextButton.styleFrom(foregroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(messagesRepositoryProvider).clearChat(_otherUserId);
      ref.read(messagesProvider(_otherUserId).notifier).clearAll();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to clear conversation. Please try again.')),
        );
      }
    }
  }

  void _initiateCall(String callType) {
    final me = ref.read(meProvider).asData?.value;
    final otherUser = ref.read(_otherUserProvider(_otherUserId)).asData?.value;

    final sessionId =
        'call_${math.Random().nextInt(999999999).toRadixString(36)}';

    // Emit call:request via socket
    ref.read(socketServiceProvider).requestCall(
      sessionId: sessionId,
      receiverId: _otherUserId,
      callType: callType,
      callerName: me?.name ?? 'User',
      callerAvatar: me?.displayPhotoUrl,
    );

    // Dispatch FCM push to wake offline callee (fire-and-forget, non-fatal).
    ref.read(callsRepositoryProvider).dispatchCallPush(
      receiverId: _otherUserId,
      callId: sessionId,
      isVideo: callType == 'video',
    );

    // Update call overlay state
    ref.read(callOverlayProvider.notifier).setActiveCall(
      ActiveCall(sessionId: sessionId),
      CallOverlayUser(
        id: _otherUserId,
        name: otherUser?.name ?? 'User',
        profilePictureUrl: otherUser?.displayPhotoUrl,
      ),
      callType: callType,
      callState: 'outgoing',
    );
    ref.read(callOverlayProvider.notifier).setMinimized(false);
  }

  void _onLongPressMessage(Message msg, String myId) {
    if (msg.senderId != myId) return; // only own messages

    setState(() => _selectedMessageId = msg.id);

    // Animate the bubble
    final ctrl = _animControllers[msg.id];
    ctrl?.forward();

    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Message'),
        content: const Text('Are you sure you want to delete this message?'),
        actions: [
          TextButton(
            onPressed: () {
              setState(() => _selectedMessageId = null);
              ctrl?.reverse();
              Navigator.pop(ctx, false);
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            style:
                TextButton.styleFrom(foregroundColor: const Color(0xFFEF4444)),
            onPressed: () {
              Navigator.pop(ctx, true);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true) {
        _deleteMessage(msg.id);
      } else {
        setState(() => _selectedMessageId = null);
        _animControllers[msg.id]?.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(meProvider).asData?.value;
    final myId = ref.watch(authProvider).user?.id ?? me?.id ?? '';
    final otherUserAsync = ref.watch(_otherUserProvider(_otherUserId));
    final otherUser = otherUserAsync.asData?.value;

    // Permission gate — mirrors RN canSend logic
    final isFemale = me?.gender == 'female';
    final isMale = me?.gender == 'male';
    final isPremium = me?.isPremium ?? false;
    final hasBalance = (me?.walletBalanceUsd ?? 0) > 0;
    final canSend = isFemale || (isPremium && hasBalance);

    // Call buttons logic
    final otherGender = otherUser?.gender;
    final showCallButtons = (isFemale && otherGender == 'male') ||
        (isMale && isPremium && hasBalance && otherGender == 'female');

    final isInCall = otherUser?.isInCall ?? false;
    final isOnline = otherUser?.isOnline ?? false;

    // If user can't send messages, show upsell
    if (!canSend && me != null) {
      return _buildUpsellScreen(context, otherUser, isInCall, isOnline);
    }

    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(
              context: context,
              otherUser: otherUser,
              isInCall: isInCall,
              isOnline: isOnline,
              showCallButtons: showCallButtons,
            ),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            Expanded(
              child: _buildMessageList(myId),
            ),
            _buildInputToolbar(myId),
            // Bottom padding for system nav bar
            SizedBox(height: MediaQuery.of(context).viewPadding.bottom),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader({
    required BuildContext context,
    required User? otherUser,
    required bool isInCall,
    required bool isOnline,
    required bool showCallButtons,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: () => context.pop(),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(LucideIcons.chevronLeft,
                  size: 24, color: Color(0xFF374151)),
            ),
          ),
          const SizedBox(width: 8),
          // Avatar + name — tappable, opens the peer's profile within the
          // Chats tab (mirrors home_screen's tap-to-profile behavior).
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: otherUser != null
                  ? () => context.push('/chats/user/${otherUser.id}')
                  : null,
              child: Row(
                children: [
                  ClipOval(
                    child: otherUser?.displayPhotoUrl != null
                        ? CachedNetworkImage(
                            imageUrl: otherUser!.displayPhotoUrl!,
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                            placeholder: (_, u) =>
                                _avatarPlaceholder(otherUser.name),
                            errorWidget: (_, u, e) =>
                                _avatarPlaceholder(otherUser.name),
                          )
                        : _avatarPlaceholder(otherUser?.name),
                  ),
                  const SizedBox(width: 10),
                  // Name + status
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          otherUser?.name ?? 'Chat',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (isInCall)
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.only(right: 4),
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFFEF4444),
                                ),
                              ),
                              const Text(
                                'Busy in a Call',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFFEF4444),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          )
                        else if (isOnline)
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.only(right: 4),
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFF22C55E),
                                ),
                              ),
                              const Text(
                                'Online',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF22C55E),
                                  fontWeight: FontWeight.w600,
                                ),
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
          // Call buttons
          if (showCallButtons) ...[
            GestureDetector(
              onTap: () => _initiateCall('audio'),
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(LucideIcons.phone,
                    size: 22, color: Color(0xFFF43F5E)),
              ),
            ),
            GestureDetector(
              onTap: () => _initiateCall('video'),
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(LucideIcons.video,
                    size: 24, color: Color(0xFFF43F5E)),
              ),
            ),
          ],
          // Clear conversation menu
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Color(0xFF6B7280)),
            onSelected: (value) {
              if (value == 'clear') _clearConversation();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(LucideIcons.trash2,
                        size: 16, color: Color(0xFFEF4444)),
                    SizedBox(width: 8),
                    Text('Clear Conversation',
                        style: TextStyle(color: Color(0xFFEF4444))),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList(String myId) {
    final messagesState = ref.watch(messagesProvider(_otherUserId));

    if (messagesState.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFF43F5E)),
      );
    }

    final messages = messagesState.messages;

    if (messages.isEmpty) {
      return RefreshIndicator(
        color: const Color(0xFFF43F5E),
        onRefresh: () =>
            ref.read(messagesProvider(_otherUserId).notifier).refresh(),
        child: const SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: 400,
            child: Center(
              child: Text(
                'No messages yet.\nSay hello!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ),
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    return RefreshIndicator(
      color: const Color(0xFFF43F5E),
      onRefresh: () =>
          ref.read(messagesProvider(_otherUserId).notifier).refresh(),
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: messages.length,
        itemBuilder: (ctx, i) {
          final msg = messages[i];
          return _buildBubble(msg, myId);
        },
      ),
    );
  }

  Widget _buildBubble(Message msg, String myId) {
    // Call-event system message (e.g. "📞 Call ended · 17m 13s") — centered.
    if (msg.content.startsWith('📞')) {
      return _buildCallEventRow(msg);
    }

    final isOwn = msg.senderId == myId;
    final isSelected = _selectedMessageId == msg.id;

    // Ensure an AnimationController exists for this message
    if (!_animControllers.containsKey(msg.id)) {
      final ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 120),
        reverseDuration: const Duration(milliseconds: 150),
        lowerBound: 0,
        upperBound: 1,
      );
      _animControllers[msg.id] = ctrl;
    }
    final ctrl = _animControllers[msg.id]!;

    final scaleAnim =
        Tween<double>(begin: 1.0, end: 0.95).animate(ctrl);
    final opacityAnim =
        Tween<double>(begin: 1.0, end: 0.85).animate(ctrl);

    return Align(
      alignment: isOwn ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _onLongPressMessage(msg, myId),
        child: AnimatedBuilder(
          animation: ctrl,
          builder: (_, child) => Transform.scale(
            scale: scaleAnim.value,
            child: Opacity(
              opacity: opacityAnim.value,
              child: child,
            ),
          ),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.72,
            ),
            decoration: BoxDecoration(
              color: isOwn
                  ? (isSelected
                      ? const Color(0xFFE11D48)
                      : const Color(0xFFF43F5E))
                  : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(18),
              border: isOwn
                  ? null
                  : Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  msg.content,
                  style: TextStyle(
                    fontSize: 15,
                    color: isOwn ? Colors.white : const Color(0xFF0F172A),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 3),
                // Timestamp (+ read-receipt tick for own messages).
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatMessageTime(msg.createdAt),
                      style: TextStyle(
                        fontSize: 10,
                        color: isOwn
                            ? Colors.white.withValues(alpha: 0.75)
                            : const Color(0xFF94A3B8),
                      ),
                    ),
                    if (isOwn) ...[
                      const SizedBox(width: 3),
                      Icon(
                        msg.seen ? Icons.done_all : Icons.done,
                        size: 13,
                        color: msg.seen
                            ? const Color(0xFF93C5FD)
                            : Colors.white.withValues(alpha: 0.75),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Centered "call ended" system row shown inline in the chat thread.
  Widget _buildCallEventRow(Message msg) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.call, size: 13, color: Color(0xFF64748B)),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                msg.content.replaceFirst('📞', '').trim(),
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              _formatMessageTime(msg.createdAt),
              style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      ),
    );
  }

  /// Formats an ISO-8601 message timestamp as a local "h:mm AM/PM" string.
  String _formatMessageTime(String iso) {
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return '';
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour < 12 ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  Widget _buildInputToolbar(String myId) {
    final hasText = _textController.text.trim().isNotEmpty;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Text input — slate pill
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 60, maxHeight: 120),
              child: TextField(
                controller: _textController,
                maxLines: null,
                maxLength: 1200,
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF0F172A),
                ),
                decoration: const InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle:
                      TextStyle(color: Color(0xFF94A3B8), fontSize: 16),
                  filled: true,
                  fillColor: Color(0xFFF1F5F9),
                  contentPadding: EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(22),
                      bottomLeft: Radius.circular(22),
                    ),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(22),
                      bottomLeft: Radius.circular(22),
                    ),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(22),
                      bottomLeft: Radius.circular(22),
                    ),
                    borderSide: BorderSide.none,
                  ),
                  counterText: '',
                ),
              ),
            ),
          ),
          // Send button — gradient
          GestureDetector(
            onTap: hasText && !_isSending ? _sendMessage : null,
            child: Container(
              width: 54,
              height: 60,
              decoration: BoxDecoration(
                gradient: hasText
                    ? const LinearGradient(
                        colors: [Color(0xFFF43F5E), Color(0xFFFB7185)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : const LinearGradient(
                        colors: [Color(0xFFE2E8F0), Color(0xFFCBD5E1)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(22),
                  bottomRight: Radius.circular(22),
                ),
                boxShadow: hasText
                    ? [
                        BoxShadow(
                          color: const Color(0xFFF43F5E).withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              alignment: Alignment.center,
              child: Icon(
                LucideIcons.send,
                size: 20,
                color: hasText ? Colors.white : const Color(0xFF94A3B8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpsellScreen(
    BuildContext context,
    User? otherUser,
    bool isInCall,
    bool isOnline,
  ) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(
              context: context,
              otherUser: otherUser,
              isInCall: isInCall,
              isOnline: isOnline,
              showCallButtons: false,
            ),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () => context.push('/plans'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE91D7C),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: const Text(
                            'Subscribe to Chat',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'You need an active subscription to send messages',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatarPlaceholder(String? name) {
    return Container(
      width: 40,
      height: 40,
      color: const Color(0xFFE5E7EB),
      alignment: Alignment.center,
      child: Text(
        (name?.isNotEmpty == true) ? name![0].toUpperCase() : '?',
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Color(0xFF6B7280),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helper provider: fetch the other user's profile
// ---------------------------------------------------------------------------

final _otherUserProvider = FutureProvider.family<User, String>((ref, id) async {
  return ref.read(usersRepositoryProvider).getUser(id);
});
