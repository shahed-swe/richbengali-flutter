import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../core/device_id.dart';
import '../core/env.dart';
import '../core/jwt.dart';
import '../state/active_chat_provider.dart';
import '../state/auth_provider.dart';
import '../state/call_overlay_provider.dart';
import '../state/conversations_provider.dart';
import '../state/me_provider.dart';
import '../state/messages_provider.dart';
import '../state/notifications_provider.dart';
import 'call_service.dart';
import 'callkit_service.dart';
import 'local_notifications_service.dart';

// ---------------------------------------------------------------------------
// SocketService — mirrors SocketContext.tsx
// ---------------------------------------------------------------------------

class SocketService {
  io.Socket? _socket;
  bool _connected = false;

  io.Socket? get socket => _socket;
  bool get connected => _connected;

  // Dedupe: the backend notifies an incoming message via EITHER
  // `notification:new` (chat never opened / receiver not in room) OR only
  // `chat:message` (receiver previously opened the chat so is still joined to
  // the room, but is now on a different tab/screen — see BUG A). Both paths
  // can fire for the same message once the client tracks visibility itself,
  // so we remember the last message id we already showed a banner for and
  // skip the second path for that same id.
  String? _lastNotifiedMessageId;

  // Stream controllers for typed events consumed by UI
  final _statusChangeController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _chatMessageController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _chatMessageDeletedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _chatClearController = StreamController<void>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();
  // Emits the peer user id who just saw our messages (read receipts).
  final _chatSeenController = StreamController<String>.broadcast();

  // Phase 5 — earnings updates
  final _earningsController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get onStatusChange =>
      _statusChangeController.stream;
  Stream<Map<String, dynamic>> get onChatMessage =>
      _chatMessageController.stream;
  Stream<Map<String, dynamic>> get onChatMessageDeleted =>
      _chatMessageDeletedController.stream;
  Stream<void> get onChatClear => _chatClearController.stream;
  Stream<bool> get onConnectionChange => _connectionController.stream;
  /// Emits a peer user id when they have seen our messages (read receipt).
  Stream<String> get onChatSeen => _chatSeenController.stream;

  /// Phase 5 — stream of earnings:update payloads
  Stream<Map<String, dynamic>> get onEarningsUpdate =>
      _earningsController.stream;

  // Helper to normalise dynamic socket payloads to Map<String,dynamic>
  static Map<String, dynamic> _toMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
  }

  /// Connect using a valid JWT token. Derives userId via AppJwt.
  void connect(String token, Ref ref) {
    final userId = AppJwt.getUserIdFromToken(token);
    if (userId == null) {
      debugPrint('[Socket] connect() ABORTED — no userId from token');
      return;
    }
    debugPrint('[Socket] connect() → ${Env.apiBase} as userId=$userId');

    // Disconnect existing socket before creating a new one
    _socket?.disconnect();
    _socket?.dispose();

    final newSocket = io.io(
      Env.apiBase,
      io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .setAuth({'token': token, 'userId': userId, 'deviceId': DeviceId.value})
          .enableReconnection()
          .setReconnectionDelay(1000)
          .setReconnectionAttempts(10)
          .setTimeout(60000)
          .build(),
    );

    newSocket.onConnect((_) {
      _connected = true;
      _connectionController.add(true);
      debugPrint('[Socket] ✅ CONNECTED');
      // Phase 6: cold-start pending call recovery.
      // Mirrors SocketContext.tsx onConnect → PendingCallManager.consumePendingAnsweredCall
      try {
        ref.read(callkitServiceProvider).processPendingCall();
        // Cold-start: if the app was killed and the user accepted a native call,
        // the accept event was lost — recover it from the persisted active call.
        ref.read(callkitServiceProvider).recoverColdStartCall();
        // Ask the backend for the real call details of any call we were rung for
        // while offline (iOS VoIP cold start loses the push payload ids). The
        // backend replies on 'call:recover' below with the true callId/callerId.
        newSocket.emit('call:recover');
        // Report our actual lifecycle so the backend suppresses call pushes only
        // when we're truly foreground. A headless cold-start connects here while
        // NOT foreground, so this correctly marks the device as background.
        final isForegroundNow =
            WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
        newSocket.emit(isForegroundNow ? 'app:foreground' : 'app:background');
      } catch (e) {
        debugPrint('[Socket] processPendingCall error: $e');
      }
      // BUG #4a: Socket.IO rooms are per-connection, so a reconnect (network
      // blip) silently drops the chat room the user is sitting in — live
      // messages + read receipts stop arriving until they leave/re-enter. Re-join
      // + re-mark-active for whatever chat is open right now.
      try {
        final peerId = ref.read(currentChatPeerIdProvider);
        if (peerId != null && peerId.isNotEmpty) {
          newSocket.emit('chat:join', {'otherUserId': peerId});
          newSocket.emit('chat:active', {'withUserId': peerId});
        }
      } catch (e) {
        debugPrint('[Socket] reconnect re-join error: $e');
      }
    });

    newSocket.onDisconnect((_) {
      _connected = false;
      _connectionController.add(false);
    });

    newSocket.onConnectError((err) {
      _connected = false;
      _connectionController.add(false);
      debugPrint('[Socket] ❌ CONNECT ERROR: $err');
    });

    // Chat events — invalidate providers
    newSocket.on('message:new', (data) {
      try {
        ref.invalidate(conversationsProvider);
        ref.invalidate(notificationsProvider);
        // Refresh (merge, not wipe) the open chat for the sender.
        // Using .notifier.refresh() preserves existing messages and avoids
        // the isLoading flash that ref.invalidate() causes on a NotifierProvider.
        final payload = _toMap(data);
        final senderId = (payload['from'] ??
                payload['sender_id'] ??
                payload['senderId'] ??
                '')
            .toString()
            .trim();
        if (senderId.isNotEmpty) {
          try {
            ref.read(messagesProvider(senderId).notifier).refresh();
          } catch (_) {}
        }
      } catch (_) {}
    });

    newSocket.on('notification:new', (data) {
      final payload = _toMap(data);
      final type = (payload['type'] ?? '').toString().toLowerCase();
      final actorId =
          (payload['actor_id'] ?? payload['actorId'] ?? '').toString();
      final messageId = (payload['id'] ?? '').toString();

      // Derive the sender's name from the current conversation list (before it
      // refreshes) for a nicer banner title.
      String? senderName;
      try {
        final convs = ref.read(conversationsProvider).asData?.value ?? [];
        for (final c in convs) {
          if (c.otherUser.id == actorId) {
            senderName = c.otherUser.name;
            break;
          }
        }
      } catch (_) {}

      // Refresh BOTH the bell badge AND the conversation list so the Chats tab
      // and header update on any page — not just inside the open chat.
      // The backend only emits notification:new when the receiver is NOT active
      // in that chat, so this is exactly the "message arrived elsewhere" case.
      try {
        ref.invalidate(notificationsProvider);
        ref.invalidate(conversationsProvider);
      } catch (_) {}

      // BUG #4a: if this message is for the chat we're currently viewing but
      // arrived via the personal room (e.g. a reconnect dropped the chat room),
      // pull it into the open thread so it doesn't silently go missing.
      try {
        final currentPeer = ref.read(currentChatPeerIdProvider);
        if (actorId.isNotEmpty && currentPeer == actorId) {
          ref.read(messagesProvider(actorId).notifier).refresh();
        }
      } catch (_) {}

      // Show a local notification banner for incoming messages so the user is
      // alerted while on any screen (FCM push covers the backgrounded case once
      // google-services.json is added).
      if (type == 'message') {
        // Record dedupe id BEFORE showing, so a same-id chat:message that
        // arrives right after (same socket tick) doesn't double-banner.
        if (messageId.isNotEmpty) _lastNotifiedMessageId = messageId;
        LocalNotificationsService.showChatNotification(
          title: (senderName != null && senderName.isNotEmpty)
              ? senderName
              : 'New message',
          body: 'You received a new message',
          payload: actorId.isNotEmpty ? '/chats/$actorId' : null,
        );
      }
    });

    // User status changes — broadcast to listeners (used by ConversationRow, header)
    newSocket.on('user:status_change', (data) {
      if (data is Map<String, dynamic>) {
        _statusChangeController.add(data);
        try {
          ref.invalidate(conversationsProvider);
        } catch (_) {}
      } else if (data is Map) {
        _statusChangeController.add(Map<String, dynamic>.from(data));
        try {
          ref.invalidate(conversationsProvider);
        } catch (_) {}
      }
    });

    // Chat room events — broadcast to per-screen listeners, AND (BUG A fix)
    // decide here — independent of the backend's activeByUser tracking —
    // whether the user is actually looking at this chat right now. The
    // backend only suppresses notification:new when it *thinks* the receiver
    // is active in the chat (via chat:active/chat:inactive), but with
    // go_router's IndexedStack the chat screen is never disposed on a tab
    // switch, so that tracking can go stale. currentChatPeerIdProvider is the
    // client's own source of truth for "visible right now" and is kept in
    // sync across pop / tab-switch / app-background (see
    // active_chat_provider.dart, chat_detail_screen.dart, main_shell.dart).
    newSocket.on('chat:message', (data) {
      final payload = _toMap(data);
      if (payload.isNotEmpty) {
        _chatMessageController.add(payload);
      }

      try {
        final messageId = (payload['id'] ?? '').toString();
        final senderId = (payload['sender_id'] ??
                payload['senderId'] ??
                payload['from'] ??
                '')
            .toString()
            .trim();
        final myId = ref.read(authProvider).user?.id ?? '';
        final currentChatPeerId = ref.read(currentChatPeerIdProvider);

        final isFromOther = senderId.isNotEmpty && senderId != myId;
        final isViewingThatChat =
            currentChatPeerId != null && currentChatPeerId == senderId;
        final alreadyNotified =
            messageId.isNotEmpty && messageId == _lastNotifiedMessageId;

        if (isFromOther && !isViewingThatChat && !alreadyNotified) {
          if (messageId.isNotEmpty) _lastNotifiedMessageId = messageId;

          // Derive the sender's name BEFORE invalidating, same as the
          // notification:new handler above.
          String? senderName;
          try {
            final convs = ref.read(conversationsProvider).asData?.value ?? [];
            for (final c in convs) {
              if (c.otherUser.id == senderId) {
                senderName = c.otherUser.name;
                break;
              }
            }
          } catch (_) {}

          ref.invalidate(conversationsProvider);
          ref.invalidate(notificationsProvider);

          final content = (payload['content'] ?? '').toString();
          LocalNotificationsService.showChatNotification(
            title: (senderName != null && senderName.isNotEmpty)
                ? senderName
                : 'New message',
            body: content.isNotEmpty ? content : 'You received a new message',
            payload: '/chats/$senderId',
          );
        }
      } catch (_) {}
    });

    newSocket.on('chat:message_deleted', (data) {
      if (data is Map<String, dynamic>) {
        _chatMessageDeletedController.add(data);
      } else if (data is Map) {
        _chatMessageDeletedController.add(Map<String, dynamic>.from(data));
      }
    });

    newSocket.on('chat:clear', (_) {
      _chatClearController.add(null);
    });

    // chat:seen — the peer opened/viewed the chat, so our messages to them are
    // now read. Payload: { byUserId }.
    newSocket.on('chat:seen', (data) {
      final payload = _toMap(data);
      final by = payload['byUserId']?.toString() ??
          payload['userId']?.toString() ??
          '';
      if (by.isNotEmpty) _chatSeenController.add(by);
    });

    // -----------------------------------------------------------------------
    // Phase 5: Call signalling events — mirrors SocketContext.tsx handlers
    // -----------------------------------------------------------------------

    // call:request — incoming call from another user
    newSocket.on('call:request', (data) {
      final payload = _toMap(data);
      final overlay = ref.read(callOverlayProvider);

      // If already in a call, tell the caller we are busy
      if (overlay.activeCall != null) {
        final callId = payload['callId']?.toString() ?? '';
        final callerId = payload['callerId']?.toString() ?? '';
        emit('call:busy', {'callId': callId, 'receiverId': callerId});
        return;
      }

      // Build incoming call state
      final callId = payload['callId']?.toString() ?? '';
      final callerId = payload['callerId']?.toString() ?? '';
      final callerName = payload['callerName']?.toString() ?? 'Unknown';
      final callType = payload['callType']?.toString() ?? 'audio';
      final callerAvatar = payload['callerAvatar']?.toString();

      ref.read(callOverlayProvider.notifier).setActiveCall(
        ActiveCall(sessionId: callId),
        CallOverlayUser(
          id: callerId,
          name: callerName,
          profilePictureUrl: callerAvatar,
        ),
        callType: callType,
        callState: 'incoming',
      );

      // BUG #3: only raise the native CallKit / full-screen UI when the app is
      // NOT foregrounded. When the app is open the in-app overlay above already
      // shows the incoming call, so native CallKit would just cover it and force
      // the user to answer through the OS UI. When backgrounded, we still show
      // CallKit so the call surfaces. (On terminated devices the call arrives via
      // a push, not this socket event, so CallKit is shown by the push handler.)
      final isForeground =
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
      if (!isForeground) {
        try {
          ref.read(callkitServiceProvider).displayIncomingCall(
            callId: callId,
            callerName: callerName,
            callerId: callerId,
            callerAvatar: callerAvatar,
            isVideo: callType == 'video',
          );
        } catch (e) {
          debugPrint('[Socket] callkitService.displayIncomingCall error: $e');
        }
      }

      // Emit call:ringing to let the caller know we received the notification.
      // Backend routes it to the caller via callerId.
      emit('call:ringing', {'callId': callId, 'callerId': callerId});
    });

    // call:cancel — caller cancelled before we answered
    newSocket.on('call:cancel', (data) {
      try { ref.read(callkitServiceProvider).endAllCalls(); } catch (_) {}
      ref.read(callOverlayProvider.notifier).clearCall();
    });

    // call:reject — callee rejected our outgoing call
    newSocket.on('call:reject', (data) {
      try { ref.read(callkitServiceProvider).endAllCalls(); } catch (_) {}
      ref.read(callOverlayProvider.notifier).clearCall();
      // Phase 6: add a "Call Declined" snackbar via a dedicated stream if needed
    });

    // call:busy — callee is already in another call
    newSocket.on('call:busy', (data) {
      try { ref.read(callkitServiceProvider).endAllCalls(); } catch (_) {}
      ref.read(callOverlayProvider.notifier).clearCall();
    });

    // call:end — remote peer ended the call
    newSocket.on('call:end', (data) async {
      try { ref.read(callkitServiceProvider).endAllCalls(); } catch (_) {}
      try {
        await ref.read(callServiceProvider).leaveAndRelease();
      } catch (_) {}
      ref.read(callOverlayProvider.notifier).clearCall();
    });

    // call:accept — our outgoing call was accepted; transition to ongoing
    newSocket.on('call:accept', (data) {
      final payload = _toMap(data);
      final callId = payload['callId']?.toString();
      final overlay = ref.read(callOverlayProvider);

      if (overlay.callState == 'outgoing' && overlay.activeCall != null) {
        ref.read(callOverlayProvider.notifier).setCallState('ongoing');

        // Emit call:start so the server starts the billing timer
        final otherUserId = overlay.otherUser?.id ?? '';
        emit('call:start', {
          'callId': callId ?? overlay.activeCall!.sessionId,
          'otherUserId': otherUserId,
        });
      }
    });

    // call:recover — backend's reply to our on-connect 'call:recover' emit.
    // Carries the REAL callId/callerId of a call we were rung for while offline
    // (iOS VoIP cold start). Record it in the overlay and, if the user already
    // accepted the native call, finish connecting with the correct ids so both
    // sides join the same Agora channel and the caller leaves "Calling…".
    newSocket.on('call:recover', (data) {
      final payload = _toMap(data);
      final callId = payload['callId']?.toString() ?? '';
      final callerId = payload['callerId']?.toString() ?? '';
      final callerName = payload['callerName']?.toString() ?? 'Unknown';
      final callType = payload['callType']?.toString() ?? 'audio';
      debugPrint('[Socket] call:recover → callId=$callId caller="$callerId"');
      if (callId.isEmpty || callerId.isEmpty) return;

      final overlay = ref.read(callOverlayProvider);
      // Don't clobber a call that's already progressing normally.
      if (overlay.callState != 'ongoing') {
        ref.read(callOverlayProvider.notifier).setActiveCall(
          ActiveCall(sessionId: callId),
          CallOverlayUser(id: callerId, name: callerName),
          callType: callType,
          callState: 'incoming',
        );
      }
      try {
        ref.read(callkitServiceProvider).retryAwaitingAccept();
      } catch (e) {
        debugPrint('[Socket] retryAwaitingAccept error: $e');
      }
    });

    // earnings:update — live earnings/balance update during a call
    newSocket.on('earnings:update', (data) {
      final payload = _toMap(data);
      _earningsController.add(payload);
      // Also refresh the Me provider so wallet balance stays current
      try {
        ref.read(meProvider.notifier).refresh();
      } catch (_) {}
    });

    _socket = newSocket;
  }

  /// Disconnect and clean up. Called on logout.
  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _connected = false;
    _connectionController.add(false);
  }

  // ---------------------------------------------------------------------------
  // Emit helpers
  // ---------------------------------------------------------------------------

  void emit(String event, [dynamic data]) {
    _socket?.emit(event, data);
  }

  /// Join a chat room with the given other user.
  void joinChat(String otherUserId) =>
      emit('chat:join', {'otherUserId': otherUserId});

  /// Leave a chat room with the given other user.
  void leaveChat(String otherUserId) =>
      emit('chat:leave', {'otherUserId': otherUserId});

  /// Mark chat as active (user has the screen open).
  void setActiveChat(String withUserId) =>
      emit('chat:active', {'withUserId': withUserId});

  /// Mark chat as inactive (user navigated away).
  void setInactiveChat(String withUserId) =>
      emit('chat:inactive', {'withUserId': withUserId});

  /// Emit call:request — used by chat call buttons. Full call flow is Phase 5.
  void requestCall({
    required String sessionId,
    required String receiverId,
    required String callType, // 'audio' | 'video'
    String callerName = 'User',
    String? callerAvatar,
  }) {
    final callPayload = <String, dynamic>{
      'callId': sessionId,
      'receiverId': receiverId,
      'callType': callType,
      'callerName': callerName,
    };
    if (callerAvatar != null) callPayload['callerAvatar'] = callerAvatar;
    emit('call:request', callPayload);
  }

  // Phase 5 call emit helpers — mirrors SocketContext.tsx

  // Backend routes call:accept to the original caller via payload.callerId
  // (io.to(payload.callerId)), so callerId is REQUIRED or the caller never
  // receives the accept and stays stuck on "Calling...".
  void acceptCall({required String callId, required String callerId}) =>
      emit('call:accept', {'callId': callId, 'callerId': callerId});

  void startCall({required String callId, required String otherUserId}) =>
      emit('call:start', {'callId': callId, 'otherUserId': otherUserId});

  // Ask the backend to re-send the details of any call we were rung for while
  // offline (iOS VoIP cold start). Backend replies on the 'call:recover' event.
  void requestCallRecover() => emit('call:recover');

  // Tell the backend whether this device's app is foreground. The backend
  // suppresses the native call push (CallKit/FCM) ONLY for foreground devices;
  // a backgrounded/just-killed device (whose socket may linger ~85s) must still
  // receive the push so the call rings. Emitting on lifecycle change keeps this
  // accurate instead of depending on the slow socket ping timeout.
  void notifyForeground() => emit('app:foreground');
  void notifyBackground() => emit('app:background');

  void cancelCall({required String callId, required String receiverId}) =>
      emit('call:cancel', {'callId': callId, 'receiverId': receiverId});

  void endCall({required String callId}) =>
      emit('call:end', {'callId': callId});

  // Backend routes call:reject to the caller via payload.callerId.
  void rejectCall({required String callId, required String callerId}) =>
      emit('call:reject', {'callId': callId, 'callerId': callerId});

  // Backend routes call:ringing to the caller via payload.callerId.
  void ringCall({required String callId, required String callerId}) =>
      emit('call:ringing', {'callId': callId, 'callerId': callerId});

  void pauseCall({required String callId}) =>
      emit('call:pause', {'callId': callId});

  void resumeCall({required String callId}) =>
      emit('call:resume', {'callId': callId});

  void dispose() {
    disconnect();
    _statusChangeController.close();
    _chatMessageController.close();
    _chatMessageDeletedController.close();
    _chatClearController.close();
    _connectionController.close();
    _earningsController.close();
    _chatSeenController.close();
  }
}

// ---------------------------------------------------------------------------
// Provider — singleton SocketService kept alive for the app lifetime.
// Watches auth state: connects on login, disconnects on logout.
// ---------------------------------------------------------------------------

final socketServiceProvider = Provider<SocketService>((ref) {
  final service = SocketService();

  // React to auth state changes
  ref.listen<AuthState>(authProvider, (previous, next) {
    if (next.token != null && next.token!.isNotEmpty) {
      // Only reconnect if the token actually changed
      if (previous?.token != next.token) {
        service.connect(next.token!, ref);
      }
    } else {
      service.disconnect();
    }
  }, fireImmediately: true);

  ref.onDispose(service.dispose);
  return service;
});
