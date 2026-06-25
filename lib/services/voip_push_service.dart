import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

      // Ask the native side to register for VoIP push
      await _channel.invokeMethod<void>('registerVoip');
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
        // Incoming VoIP push payload → show CallKit UI
        final raw = call.arguments;
        final payload = raw is Map
            ? Map<String, dynamic>.from(raw)
            : <String, dynamic>{};
        await _handleIncomingVoipCall(payload);

      default:
        debugPrint('[VoipPush] Unknown method: ${call.method}');
    }
  }

  Future<void> _handleIncomingVoipCall(Map<String, dynamic> payload) async {
    try {
      final callId = payload['callId']?.toString() ??
          payload['sessionId']?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString();
      final callerName = payload['callerName']?.toString() ?? 'Unknown';
      final callerAvatar = payload['callerAvatar']?.toString();
      final callType = payload['callType']?.toString() ?? 'audio';
      final isVideo = callType == 'video';

      debugPrint('[VoipPush] Incoming VoIP call: $callId from $callerName');

      final callkitService = _ref.read(callkitServiceProvider);
      await callkitService.displayIncomingCall(
        callId: callId,
        callerName: callerName,
        callerAvatar: callerAvatar,
        isVideo: isVideo,
      );
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
