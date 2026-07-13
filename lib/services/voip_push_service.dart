import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/call_overlay_provider.dart';
import 'callkit_service.dart';

// ---------------------------------------------------------------------------
// VoipPushService — iOS VoIP push (PushKit) handler
//
// flutter_voip_push_notification is NOT null-safe and cannot be used with
// Dart SDK >=3.0. Instead, we expose a MethodChannel stub that can be
// activated from Swift/AppDelegate once you add the iOS native side.
//
// On Android this is a complete no-op.
//
// TODO (Phase 8 / Mac):
//   1. Implement AppDelegate.swift PushKit delegate that calls
//      FlutterMethodChannel(name: 'com.richbengali.voip') with method
//      'onVoipToken' (token string) and 'onVoipCallReceived' (payload map).
//   2. Remove this comment and set _isReady = true once tested on device.
// ---------------------------------------------------------------------------

class VoipPushService {
  VoipPushService(this._ref);

  final Ref _ref;

  static const _channel = MethodChannel('com.richbengali.voip');

  String? _voipToken;
  String? get voipToken => _voipToken;

  // Callback for token — set by PushService after init
  void Function(String token)? onTokenReceived;

  /// Register for VoIP push (iOS only).
  /// On Android this is a no-op.
  Future<void> register() async {
    if (!Platform.isIOS) {
      debugPrint('[VoipPush] Android — no VoIP push registration needed');
      return;
    }

    try {
      // Set method call handler to receive calls from native Swift side
      _channel.setMethodCallHandler(_handleMethodCall);

      // Ask the native side to register for VoIP push. If PushKit already issued
      // a token before this handler existed (startup race), the native side
      // returns the cached token here so we don't miss it.
      final cached = await _channel.invokeMethod<String>('registerVoip');
      if (cached != null && cached.isNotEmpty) {
        _voipToken = cached;
        debugPrint('[VoipPush] VoIP token (cached from native): $cached');
        onTokenReceived?.call(cached);
      }

      // Cold start: the VoIP call arrived before Dart was listening, so its
      // onVoipCallReceived was dropped. Pull the RAW payload now and record the
      // real callId/callerId in the overlay, so the accept below routes to the
      // caller with the right ids.
      try {
        final rawCall = await _channel.invokeMethod('getPendingVoipCall');
        if (rawCall is Map) {
          await _handleIncomingVoipCall(Map<String, dynamic>.from(rawCall));
        }
      } catch (e) {
        debugPrint('[VoipPush] getPendingVoipCall(raw) error: $e');
      }

      // Pull any native CallKit "accept" that happened before Dart was ready
      // (cold start from a VoIP-push call) and connect it now.
      try {
        final pending = await _channel.invokeMethod('getPendingAccept');
        if (pending is Map) {
          final m = Map<String, dynamic>.from(pending);
          final callId = (m['callId'] ?? '').toString();
          if (callId.isNotEmpty) {
            await _ref.read(callkitServiceProvider).acceptIncomingCall(
                  callId: callId,
                  callerId: (m['callerId'] ?? '').toString(),
                  callType: (m['callType'] ?? 'audio').toString(),
                );
          }
        }
      } catch (e) {
        debugPrint('[VoipPush] getPendingAccept error: $e');
      }
      debugPrint('[VoipPush] iOS VoIP registration requested via platform channel');
    } on MissingPluginException {
      // Native side not yet implemented — this is expected until Phase 8
      debugPrint(
        '[VoipPush] Native VoIP channel not found — '
        'implement in AppDelegate.swift (Phase 8/Mac)',
      );
    } catch (e) {
      debugPrint('[VoipPush] register error: $e');
    }
  }

  /// Returns the REAL call ids for the current VoIP-pushed call (cached
  /// natively the instant the push arrived): { callId, callerId, callType }.
  /// Used when accepting a call whose overlay/extra weren't populated yet.
  Future<Map<String, dynamic>?> getPendingVoipCall() async {
    if (!Platform.isIOS) return null;
    try {
      final r = await _channel.invokeMethod('getPendingVoipCall');
      if (r is Map) {
        final raw = Map<String, dynamic>.from(r);
        return {
          'callId': (raw['callId'] ?? raw['sessionId'] ?? '').toString(),
          'callerId': (raw['callerId'] ?? raw['senderId'] ?? '').toString(),
          'callType': (raw['callType'] ?? 'audio').toString(),
        };
      }
    } catch (e) {
      debugPrint('[VoipPush] getPendingVoipCall error: $e');
    }
    return null;
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    debugPrint('[VoipPush] Native call: ${call.method} args=${call.arguments}');
    switch (call.method) {
      case 'onVoipToken':
        final token = call.arguments as String?;
        if (token != null && token.isNotEmpty) {
          _voipToken = token;
          debugPrint('[VoipPush] VoIP token received: $token');
          onTokenReceived?.call(token);
        }

      case 'onVoipCallReceived':
        // Incoming VoIP push payload (native AppDelegate already reported it to
        // CallKit) — just log; the accept flows back via onCallKitAnswer.
        final raw = call.arguments;
        final payload = raw is Map
            ? Map<String, dynamic>.from(raw)
            : <String, dynamic>{};
        await _handleIncomingVoipCall(payload);

      case 'onCallKitAnswer':
        // User tapped Accept on the native VoIP CallKit — connect it through
        // the one accept path (joins Agora, routes accept to the caller).
        final raw = call.arguments;
        final m =
            raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
        final callId = (m['callId'] ?? '').toString();
        if (callId.isNotEmpty) {
          await _ref.read(callkitServiceProvider).acceptIncomingCall(
                callId: callId,
                callerId: (m['callerId'] ?? '').toString(),
                callType: (m['callType'] ?? 'audio').toString(),
              );
        }

      default:
        debugPrint('[VoipPush] Unknown method: ${call.method}');
    }
  }

  Future<void> _handleIncomingVoipCall(Map<String, dynamic> payload) async {
    // The native AppDelegate already reports the VoIP call to CallKit; we don't
    // show a second one. But we MUST record the REAL call context (callId +
    // callerId) in the overlay here, so that when the user accepts — whichever
    // CallKit path fires — the accept routes call:accept to the real caller
    // with the real call id (the CallKit event otherwise carries a derived UUID
    // and an empty caller id, leaving the caller stuck on "Calling…").
    try {
      debugPrint('[VoipPush] raw payload: $payload');
      final callId = (payload['callId'] ?? payload['sessionId'] ?? '').toString();
      final callerId = (payload['callerId'] ?? payload['senderId'] ?? '').toString();
      final callerName =
          (payload['callerName'] ?? payload['senderName'] ?? 'Unknown').toString();
      final callerAvatar =
          (payload['callerAvatar'] ?? payload['avatar'])?.toString();
      final callType = (payload['callType'] ?? 'audio').toString();
      debugPrint('[VoipPush] Incoming VoIP call: $callId caller="$callerId"');

      if (callId.isEmpty) return;
      final overlay = _ref.read(callOverlayProvider);
      if (overlay.activeCall == null) {
        _ref.read(callOverlayProvider.notifier).setActiveCall(
              ActiveCall(sessionId: callId),
              CallOverlayUser(
                  id: callerId,
                  name: callerName,
                  profilePictureUrl: callerAvatar),
              callType: callType,
              callState: 'incoming',
            );
      }
    } catch (e) {
      debugPrint('[VoipPush] _handleIncomingVoipCall error: $e');
    }
  }

  void dispose() {
    if (Platform.isIOS) {
      try {
        _channel.setMethodCallHandler(null);
      } catch (_) {}
    }
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final voipPushServiceProvider = Provider<VoipPushService>((ref) {
  final service = VoipPushService(ref);
  ref.onDispose(service.dispose);
  return service;
});
