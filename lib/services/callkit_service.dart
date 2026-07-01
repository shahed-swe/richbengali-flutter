import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_callkit_incoming/entities/android_params.dart';
import 'package:flutter_callkit_incoming/entities/call_event.dart';
import 'package:flutter_callkit_incoming/entities/call_kit_params.dart';
import 'package:flutter_callkit_incoming/entities/ios_params.dart';
import 'package:flutter_callkit_incoming/entities/notification_params.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../state/call_overlay_provider.dart';
import 'call_service.dart';
import 'socket_service.dart';

// ---------------------------------------------------------------------------
// Pending answered-call storage — mirrors PendingCallManager.ts
// Persists to SharedPreferences so it survives process death between
// CallKit answer tap (native) and socket reconnect (app foreground).
// ---------------------------------------------------------------------------

const _kPendingAnsweredCall = 'pending_answered_call';
const _kPendingAnsweredCallTime = 'pending_answered_call_time';
const _kPendingCallMaxAgeMs = 2 * 60 * 1000; // 2 minutes

Future<void> _storePendingAnsweredCall(String callId) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPendingAnsweredCall, callId);
    await prefs.setInt(
        _kPendingAnsweredCallTime, DateTime.now().millisecondsSinceEpoch);
    debugPrint('[CallKit] Stored pending answered call: $callId');
  } catch (e) {
    debugPrint('[CallKit] _storePendingAnsweredCall error: $e');
  }
}

/// Call once after the socket connects — mirrors SocketContext.tsx connect
/// handler's PendingCallManager.consumePendingAnsweredCall() logic.
Future<String?> consumePendingAnsweredCall() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final callId = prefs.getString(_kPendingAnsweredCall);
    final storedAt = prefs.getInt(_kPendingAnsweredCallTime) ?? 0;

    if (callId == null) return null;

    final age = DateTime.now().millisecondsSinceEpoch - storedAt;
    if (age > _kPendingCallMaxAgeMs) {
      await prefs.remove(_kPendingAnsweredCall);
      await prefs.remove(_kPendingAnsweredCallTime);
      debugPrint('[CallKit] Pending answered call is stale — discarding');
      return null;
    }

    await prefs.remove(_kPendingAnsweredCall);
    await prefs.remove(_kPendingAnsweredCallTime);
    debugPrint('[CallKit] Consumed pending answered call: $callId');
    return callId;
  } catch (e) {
    debugPrint('[CallKit] consumePendingAnsweredCall error: $e');
    return null;
  }
}

// ---------------------------------------------------------------------------
// CallkitService — mirrors VoipNotificationHandler.ts (Flutter side)
// ---------------------------------------------------------------------------

class CallkitService {
  CallkitService(this._ref);

  final Ref _ref;
  StreamSubscription<CallEvent?>? _eventSub;
  bool _listenersSetUp = false;

  // ---------------------------------------------------------------------------
  // Display an incoming call via flutter_callkit_incoming.
  // Mirrors RNCallKeep.displayIncomingCall + Notifee full-screen notification.
  // ---------------------------------------------------------------------------

  Future<void> displayIncomingCall({
    required String callId,
    required String callerName,
    String? callerAvatar,
    bool isVideo = false,
  }) async {
    try {
      debugPrint('[CallKit] displayIncomingCall: $callId / $callerName');
      final params = CallKitParams(
        id: callId,
        nameCaller: callerName,
        appName: 'RichBengali',
        avatar: callerAvatar,
        type: isVideo ? 1 : 0, // 0=audio, 1=video
        textAccept: 'Accept',
        textDecline: 'Decline',
        duration: 45000, // 45 second ring timeout
        missedCallNotification: const NotificationParams(
          showNotification: true,
          count: 1,
        ),
        android: AndroidParams(
          isCustomNotification: true,
          isShowLogo: false,
          ringtonePath: 'system_ringtone_default',
          backgroundColor: '#0955fa',
          backgroundUrl: callerAvatar,
          actionColor: '#4CAF50',
          textColor: '#ffffff',
          incomingCallNotificationChannelName: 'Incoming Calls',
          missedCallNotificationChannelName: 'Missed Calls',
          isShowCallID: false,
        ),
        ios: IOSParams(
          iconName: 'AppIcon',
          handleType: 'generic',
          supportsVideo: isVideo,
          maximumCallGroups: 2,
          maximumCallsPerCallGroup: 1,
          audioSessionMode: 'default',
          audioSessionActive: true,
          audioSessionPreferredSampleRate: 44100.0,
          audioSessionPreferredIOBufferDuration: 0.005,
          supportsDTMF: false,
          supportsHolding: false,
          supportsGrouping: false,
          supportsUngrouping: false,
        ),
      );
      await FlutterCallkitIncoming.showCallkitIncoming(params);
    } catch (e) {
      debugPrint('[CallKit] displayIncomingCall error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // End a specific call
  // ---------------------------------------------------------------------------

  Future<void> endCall(String callId) async {
    try {
      await FlutterCallkitIncoming.endCall(callId);
    } catch (e) {
      debugPrint('[CallKit] endCall error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // End all calls (mirrors RNCallKeep.endAllCalls)
  // ---------------------------------------------------------------------------

  Future<void> endAllCalls() async {
    try {
      await FlutterCallkitIncoming.endAllCalls();
    } catch (e) {
      debugPrint('[CallKit] endAllCalls error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Set up event listeners — idempotent.
  // Mirrors VoipNotificationHandler.setupEventListeners
  // ---------------------------------------------------------------------------

  void setupListeners() {
    if (_listenersSetUp) return;
    _listenersSetUp = true;

    _eventSub = FlutterCallkitIncoming.onEvent.listen((CallEvent? event) async {
      if (event == null) return;
      debugPrint('[CallKit] Event: ${event.event} body=${event.body}');

      final body = event.body is Map
          ? Map<String, dynamic>.from(event.body as Map)
          : <String, dynamic>{};
      final callId = body['id']?.toString() ?? '';

      switch (event.event) {
        // ------------------------------------------------------------------
        // User answered the call (tapped Accept in native CallKit / lock screen)
        // Mirrors VoipNotificationHandler.onAnswerCall
        // ------------------------------------------------------------------
        case Event.actionCallAccept:
          await _onCallAccepted(callId, body);

        // ------------------------------------------------------------------
        // User declined / hung up / call timed out
        // Mirrors VoipNotificationHandler.endCall
        // ------------------------------------------------------------------
        case Event.actionCallDecline:
        case Event.actionCallEnded:
        case Event.actionCallTimeout:
          await _onCallDeclined(callId);

        case Event.actionCallIncoming:
          debugPrint('[CallKit] actionCallIncoming received for $callId');

        case Event.actionCallStart:
          debugPrint('[CallKit] actionCallStart for $callId');

        // iOS VoIP token refresh via CallKit plugin
        case Event.actionDidUpdateDevicePushTokenVoip:
          final token = body['deviceTokenVoIP']?.toString();
          if (token != null && token.isNotEmpty) {
            debugPrint('[CallKit] VoIP token via CallKit plugin: $token');
            // Stored for syncTokens — picked up on next auth sync
          }

        default:
          debugPrint('[CallKit] Unhandled event: ${event.event}');
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Handle ACCEPT — mirror RN onAnswerCall
  // ---------------------------------------------------------------------------

  Future<void> _onCallAccepted(
      String callId, Map<String, dynamic> body) async {
    debugPrint('[CallKit] _onCallAccepted: $callId');

    try {
      final overlay = _ref.read(callOverlayProvider);

      if (overlay.activeCall == null) {
        // App was cold-started or backgrounded — store the call for when
        // the socket reconnects and processPendingCall() is called.
        await _storePendingAnsweredCall(callId);
        debugPrint('[CallKit] App not in call state; stored as pending');
        return;
      }

      final socketService = _ref.read(socketServiceProvider);

      // Emit accept + start to server. callerId = the other party (the caller),
      // required so the backend routes call:accept back to them.
      final otherUserId = overlay.otherUser?.id ?? '';
      socketService.acceptCall(callId: callId, callerId: otherUserId);
      socketService.startCall(callId: callId, otherUserId: otherUserId);

      // Transition overlay to ongoing
      _ref.read(callOverlayProvider.notifier).setCallState('ongoing');

      // Start Agora engine
      final callType = overlay.callType ?? 'audio';
      final isVideo = callType == 'video';
      final callService = _ref.read(callServiceProvider);
      await callService.initEngine(isVideo: isVideo);
      await callService.joinChannel(
        sessionId: callId,
        isVideo: isVideo,
        isMuted: overlay.isMuted,
      );
    } catch (e) {
      debugPrint('[CallKit] _onCallAccepted error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Handle DECLINE / END / TIMEOUT — mirror RN endCall
  // ---------------------------------------------------------------------------

  Future<void> _onCallDeclined(String callId) async {
    debugPrint('[CallKit] _onCallDeclined: $callId');

    try {
      final socketService = _ref.read(socketServiceProvider);
      final overlay = _ref.read(callOverlayProvider);

      // Emit reject if still incoming; end if already ongoing
      if (overlay.callState == 'incoming') {
        socketService.rejectCall(
          callId: callId,
          callerId: overlay.otherUser?.id ?? '',
        );
      } else if (overlay.activeCall != null) {
        socketService.endCall(callId: callId);
      }

      // Leave Agora
      try {
        await _ref.read(callServiceProvider).leaveAndRelease();
      } catch (_) {}

      // Clear overlay
      _ref.read(callOverlayProvider.notifier).clearCall();

      // Dismiss native call UI
      await endAllCalls();
    } catch (e) {
      debugPrint('[CallKit] _onCallDeclined error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Consume cold-start pending call once socket connects.
  // Called from socket_service.dart onConnect.
  // Mirrors SocketContext.tsx connect handler → PendingCallManager logic.
  // ---------------------------------------------------------------------------

  Future<void> processPendingCall() async {
    try {
      final callId = await consumePendingAnsweredCall();
      if (callId == null) return;

      debugPrint('[CallKit] processPendingCall: $callId');

      final socketService = _ref.read(socketServiceProvider);
      // Cold-start: overlay was cleared so we don't have the caller's id here.
      // TODO: persist callerId with the pending call so accept can be routed
      // after a true cold start (only matters once VoIP/FCM push is live).
      socketService.acceptCall(callId: callId, callerId: '');
      socketService.startCall(callId: callId, otherUserId: '');

      // Set minimal ongoing state so the call screen appears.
      // We don't have otherUser info after cold start — overlay was cleared.
      _ref.read(callOverlayProvider.notifier).setActiveCall(
        ActiveCall(sessionId: callId),
        null,
        callType: 'audio',
        callState: 'ongoing',
      );
    } catch (e) {
      debugPrint('[CallKit] processPendingCall error: $e');
    }
  }

  void dispose() {
    _eventSub?.cancel();
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final callkitServiceProvider = Provider<CallkitService>((ref) {
  final service = CallkitService(ref);
  ref.onDispose(service.dispose);
  return service;
});
