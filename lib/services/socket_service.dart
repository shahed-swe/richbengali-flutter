import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../core/env.dart';
import '../core/jwt.dart';
import '../state/auth_provider.dart';
import '../state/call_overlay_provider.dart';
import '../state/conversations_provider.dart';
import '../state/me_provider.dart';
import '../state/notifications_provider.dart';
import 'call_service.dart';
import 'callkit_service.dart';

// ---------------------------------------------------------------------------
// SocketService — mirrors SocketContext.tsx
// ---------------------------------------------------------------------------

class SocketService {
  io.Socket? _socket;
  bool _connected = false;

  io.Socket? get socket => _socket;
  bool get connected => _connected;

  // Stream controllers for typed events consumed by UI
  final _statusChangeController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _chatMessageController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _chatMessageDeletedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _chatClearController = StreamController<void>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();

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
    if (userId == null) return;

    // Disconnect existing socket before creating a new one
    _socket?.disconnect();
    _socket?.dispose();

    final newSocket = io.io(
      Env.apiBase,
      io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .setAuth({'token': token, 'userId': userId})
          .enableReconnection()
          .setReconnectionDelay(1000)
          .setReconnectionAttempts(10)
          .setTimeout(60000)
          .build(),
    );

    newSocket.onConnect((_) {
      _connected = true;
      _connectionController.add(true);
      // Phase 6: cold-start pending call recovery.
      // Mirrors SocketContext.tsx onConnect → PendingCallManager.consumePendingAnsweredCall
      try {
        ref.read(callkitServiceProvider).processPendingCall();
      } catch (e) {
        debugPrint('[Socket] processPendingCall error: $e');
      }
    });

    newSocket.onDisconnect((_) {
      _connected = false;
      _connectionController.add(false);
    });

    newSocket.onConnectError((_) {
      _connected = false;
      _connectionController.add(false);
    });

    // Chat events — invalidate providers
    newSocket.on('message:new', (_) {
      try {
        ref.invalidate(conversationsProvider);
        ref.invalidate(notificationsProvider);
      } catch (_) {}
    });

    newSocket.on('notification:new', (_) {
      try {
        ref.invalidate(notificationsProvider);
      } catch (_) {}
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

    // Chat room events — broadcast to per-screen listeners
    newSocket.on('chat:message', (data) {
      if (data is Map<String, dynamic>) {
        _chatMessageController.add(data);
      } else if (data is Map) {
        _chatMessageController.add(Map<String, dynamic>.from(data));
      }
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

      // Phase 6: also show native CallKit / ConnectionService UI so the call
      // appears even when the app is backgrounded.
      // Mirrors SocketContext.tsx call:request → voipHandler.displayIncomingCall
      try {
        ref.read(callkitServiceProvider).displayIncomingCall(
          callId: callId,
          callerName: callerName,
          callerAvatar: callerAvatar,
          isVideo: callType == 'video',
        );
      } catch (e) {
        debugPrint('[Socket] callkitService.displayIncomingCall error: $e');
      }

      // Emit call:ringing to let the caller know we received the notification
      emit('call:ringing', {'callId': callId});
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

  void acceptCall({required String callId}) =>
      emit('call:accept', {'callId': callId});

  void startCall({required String callId, required String otherUserId}) =>
      emit('call:start', {'callId': callId, 'otherUserId': otherUserId});

  void cancelCall({required String callId, required String receiverId}) =>
      emit('call:cancel', {'callId': callId, 'receiverId': receiverId});

  void endCall({required String callId}) =>
      emit('call:end', {'callId': callId});

  void rejectCall({required String callId}) =>
      emit('call:reject', {'callId': callId});

  void ringCall({required String callId}) =>
      emit('call:ringing', {'callId': callId});

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
