import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_callkit_incoming/entities/android_params.dart';
import 'package:flutter_callkit_incoming/entities/call_event.dart';
import 'package:flutter_callkit_incoming/entities/call_kit_params.dart';
import 'package:flutter_callkit_incoming/entities/ios_params.dart';
import 'package:flutter_callkit_incoming/entities/notification_params.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

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

/// Stores the full accepted-call info (callId + callerId + callType) so a true
/// cold start can re-establish the call — not just the id (the caller id is
/// required to route accept/start to the caller, and the type to join Agora
/// with the right media).
Future<void> _storePendingAnsweredCall(Map<String, dynamic> info) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPendingAnsweredCall, jsonEncode(info));
    await prefs.setInt(
        _kPendingAnsweredCallTime, DateTime.now().millisecondsSinceEpoch);
    debugPrint('[CallKit] Stored pending answered call: $info');
  } catch (e) {
    debugPrint('[CallKit] _storePendingAnsweredCall error: $e');
  }
}

/// Call once after the socket connects — mirrors SocketContext.tsx connect
/// handler's PendingCallManager.consumePendingAnsweredCall() logic. Returns the
/// stored call info map ({callId, callerId, callType}) or null.
Future<Map<String, dynamic>?> consumePendingAnsweredCall() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPendingAnsweredCall);
    final storedAt = prefs.getInt(_kPendingAnsweredCallTime) ?? 0;

    if (raw == null) return null;

    final age = DateTime.now().millisecondsSinceEpoch - storedAt;
    if (age > _kPendingCallMaxAgeMs) {
      await prefs.remove(_kPendingAnsweredCall);
      await prefs.remove(_kPendingAnsweredCallTime);
      debugPrint('[CallKit] Pending answered call is stale — discarding');
      return null;
    }

    await prefs.remove(_kPendingAnsweredCall);
    await prefs.remove(_kPendingAnsweredCallTime);
    debugPrint('[CallKit] Consumed pending answered call: $raw');

    // Newer builds store JSON; older builds stored a bare call-id string.
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return {'callId': raw};
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
  // CallKit (iOS) requires the call id to be a valid UUID. Our backend call ids
  // are NOT UUIDs, and flutter_callkit_incoming force-unwraps
  // `UUID(uuidString: data.uuid)!` on iOS — so passing a non-UUID crashes the
  // app the instant an incoming call is displayed (Android→iPhone crash).
  // We hand CallKit a UUID derived *deterministically* from the backend id (so
  // endCall()/lookups still match) and carry the real id in `extra` so every
  // event can recover it. Ids that are already UUIDs pass through unchanged.
  // ---------------------------------------------------------------------------
  static final _uuid = const Uuid();
  static const _urlNamespace = '6ba7b811-9dad-11d1-80b4-00c04fd430c8';
  static final _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  /// Maps a backend call id to a valid CallKit UUID (deterministic).
  static String callKitId(String backendCallId) {
    if (backendCallId.isEmpty) return _uuid.v4();
    if (_uuidPattern.hasMatch(backendCallId)) return backendCallId;
    return _uuid.v5(_urlNamespace, backendCallId);
  }

  // ---------------------------------------------------------------------------
  // Display an incoming call via flutter_callkit_incoming.
  // Mirrors RNCallKeep.displayIncomingCall + Notifee full-screen notification.
  // ---------------------------------------------------------------------------

  Future<void> displayIncomingCall({
    required String callId,
    required String callerName,
    String callerId = '',
    String? callerAvatar,
    bool isVideo = false,
  }) async {
    try {
      debugPrint('[CallKit] displayIncomingCall: $callId / $callerName');
      await FlutterCallkitIncoming.showCallkitIncoming(_incomingParams(
        callId: callId,
        callerName: callerName,
        callerId: callerId,
        callerAvatar: callerAvatar,
        isVideo: isVideo,
      ));
    } catch (e) {
      debugPrint('[CallKit] displayIncomingCall error: $e');
    }
  }

  /// Show an incoming call directly from a raw FCM/VoIP push payload. Static so
  /// it works from the FCM background isolate (no Riverpod container there).
  /// Reads the backend push key names (`sessionId`, `senderName`) with camelCase
  /// fallbacks so foreground-socket and background-push agree.
  static Future<void> showIncomingFromPush(Map<String, dynamic> data) async {
    final callId = (data['callId'] ?? data['sessionId'] ?? '').toString();
    final callerId = (data['callerId'] ?? data['senderId'] ?? '').toString();
    final callerName =
        (data['callerName'] ?? data['senderName'] ?? 'Unknown').toString();
    final callerAvatar = (data['callerAvatar'] ?? data['avatar'])?.toString();
    final callType = (data['callType'] ?? 'audio').toString();
    try {
      await FlutterCallkitIncoming.showCallkitIncoming(_incomingParams(
        callId: callId,
        callerName: callerName,
        callerId: callerId,
        callerAvatar: callerAvatar,
        isVideo: callType == 'video',
      ));
    } catch (e) {
      debugPrint('[CallKit] showIncomingFromPush error: $e');
    }
  }

  /// End all native calls — static for use from the FCM background isolate.
  static Future<void> endAllFromPush() async {
    try {
      await FlutterCallkitIncoming.endAllCalls();
    } catch (e) {
      debugPrint('[CallKit] endAllFromPush error: $e');
    }
  }

  /// Builds the CallKitParams for an incoming call. Shared by the instance
  /// display path and the static background-push path.
  static CallKitParams _incomingParams({
    required String callId,
    required String callerName,
    String callerId = '',
    String? callerAvatar,
    bool isVideo = false,
  }) {
    return CallKitParams(
      // CallKit needs a real UUID; carry the true backend id + caller info in
      // `extra` so accept (even after a cold start) can route + join correctly.
      id: callKitId(callId),
      extra: <String, dynamic>{
        'callId': callId,
        'callerId': callerId,
        'callType': isVideo ? 'video' : 'audio',
        'callerName': callerName,
      },
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
  }

  // ---------------------------------------------------------------------------
  // End a specific call
  // ---------------------------------------------------------------------------

  Future<void> endCall(String callId) async {
    try {
      await FlutterCallkitIncoming.endCall(callKitId(callId));
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
      // `id` is the CallKit UUID we generated; the real backend call id is in
      // `extra.callId`. Fall back to `id` for ids that were already UUIDs.
      final extra = body['extra'] is Map
          ? Map<String, dynamic>.from(body['extra'] as Map)
          : const <String, dynamic>{};
      final callId = (extra['callId'] ?? body['id'])?.toString() ?? '';

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
      final extra = body['extra'] is Map
          ? Map<String, dynamic>.from(body['extra'] as Map)
          : const <String, dynamic>{};
      final overlay = _ref.read(callOverlayProvider);

      // Prefer the ids carried in the CallKit payload (they survive a cold
      // start); fall back to the live overlay for the warm/foreground path.
      final callerId = (extra['callerId']?.toString().isNotEmpty ?? false)
          ? extra['callerId'].toString()
          : (overlay.otherUser?.id ?? '');
      final callType = (extra['callType']?.toString().isNotEmpty ?? false)
          ? extra['callType'].toString()
          : (overlay.callType ?? 'audio');

      if (overlay.activeCall == null) {
        // App was cold-started or fully closed — store the FULL call info so
        // processPendingCall() (on socket connect) can route + join it.
        await _storePendingAnsweredCall({
          'callId': callId,
          'callerId': callerId,
          'callType': callType,
        });
        debugPrint('[CallKit] App not in call state; stored as pending');
        return;
      }

      final socketService = _ref.read(socketServiceProvider);
      socketService.acceptCall(callId: callId, callerId: callerId);
      socketService.startCall(callId: callId, otherUserId: callerId);

      // Transition overlay to ongoing
      _ref.read(callOverlayProvider.notifier).setCallState('ongoing');

      // Start Agora engine
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
      final info = await consumePendingAnsweredCall();
      if (info == null) return;
      final callId = (info['callId'] ?? '').toString();
      if (callId.isEmpty) return;
      final callerId = (info['callerId'] ?? '').toString();
      final callType = (info['callType'] ?? 'audio').toString();
      final isVideo = callType == 'video';

      debugPrint(
          '[CallKit] processPendingCall: $callId (caller=$callerId, $callType)');

      final socketService = _ref.read(socketServiceProvider);
      socketService.acceptCall(callId: callId, callerId: callerId);
      socketService.startCall(callId: callId, otherUserId: callerId);

      // Show the ongoing call screen.
      _ref.read(callOverlayProvider.notifier).setActiveCall(
            ActiveCall(sessionId: callId),
            callerId.isNotEmpty ? CallOverlayUser(id: callerId, name: '') : null,
            callType: callType,
            callState: 'ongoing',
          );

      // Actually join the Agora channel — the cold-start path previously
      // skipped this, so accepting opened the app but never connected media.
      try {
        final callService = _ref.read(callServiceProvider);
        await callService.initEngine(isVideo: isVideo);
        await callService.joinChannel(
          sessionId: callId,
          isVideo: isVideo,
          isMuted: false,
        );
      } catch (e) {
        debugPrint('[CallKit] processPendingCall join error: $e');
      }
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
