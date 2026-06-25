import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Storage key — mirrors Zustand persist name 'call-overlay-storage'
const _kBeautyStorageKey = 'call-overlay-storage';

// ---------------------------------------------------------------------------
// State — mirrors CallOverlayManager.ts
// ---------------------------------------------------------------------------

class ActiveCall {
  final String sessionId;
  const ActiveCall({required this.sessionId});
}

class CallOverlayUser {
  final String id;
  final String name;
  final String? profilePictureUrl;

  const CallOverlayUser({
    required this.id,
    required this.name,
    this.profilePictureUrl,
  });
}

/// 'audio' | 'video' | null
typedef CallType = String?;

/// 'outgoing' | 'incoming' | 'ongoing' | null
typedef CallStateValue = String?;

class CallOverlayState {
  final ActiveCall? activeCall;
  final bool isMinimized;
  final CallOverlayUser? otherUser;
  final String? callToken;
  final CallType callType;
  final CallStateValue callState;
  final bool isMuted;
  final bool isSpeakerOn;
  // Beauty settings — persisted
  final double beautySmoothness;
  final double beautyBlurDegree;
  final double beautySlimFace;
  final double beautyBigEyes;

  const CallOverlayState({
    this.activeCall,
    this.isMinimized = false,
    this.otherUser,
    this.callToken,
    this.callType,
    this.callState,
    this.isMuted = false,
    this.isSpeakerOn = true,
    this.beautySmoothness = 80,
    this.beautyBlurDegree = 75,
    this.beautySlimFace = 50,
    this.beautyBigEyes = 50,
  });

  CallOverlayState copyWith({
    ActiveCall? activeCall,
    bool? isMinimized,
    CallOverlayUser? otherUser,
    String? callToken,
    CallType callType,
    CallStateValue callState,
    bool? isMuted,
    bool? isSpeakerOn,
    double? beautySmoothness,
    double? beautyBlurDegree,
    double? beautySlimFace,
    double? beautyBigEyes,
    bool clearActiveCall = false,
    bool clearOtherUser = false,
    bool clearCallToken = false,
    bool clearCallType = false,
    bool clearCallState = false,
  }) {
    return CallOverlayState(
      activeCall: clearActiveCall ? null : (activeCall ?? this.activeCall),
      isMinimized: isMinimized ?? this.isMinimized,
      otherUser: clearOtherUser ? null : (otherUser ?? this.otherUser),
      callToken: clearCallToken ? null : (callToken ?? this.callToken),
      callType: clearCallType ? null : (callType ?? this.callType),
      callState: clearCallState ? null : (callState ?? this.callState),
      isMuted: isMuted ?? this.isMuted,
      isSpeakerOn: isSpeakerOn ?? this.isSpeakerOn,
      beautySmoothness: beautySmoothness ?? this.beautySmoothness,
      beautyBlurDegree: beautyBlurDegree ?? this.beautyBlurDegree,
      beautySlimFace: beautySlimFace ?? this.beautySlimFace,
      beautyBigEyes: beautyBigEyes ?? this.beautyBigEyes,
    );
  }
}

// ---------------------------------------------------------------------------
// Notifier — mirrors the Zustand store API
// ---------------------------------------------------------------------------

class CallOverlayNotifier extends Notifier<CallOverlayState> {
  @override
  CallOverlayState build() {
    _loadBeautySettings();
    return const CallOverlayState();
  }

  Future<void> _loadBeautySettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kBeautyStorageKey);
      if (raw != null) {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        state = state.copyWith(
          beautySmoothness: (map['beautySmoothness'] as num?)?.toDouble(),
          beautyBlurDegree: (map['beautyBlurDegree'] as num?)?.toDouble(),
          beautySlimFace: (map['beautySlimFace'] as num?)?.toDouble(),
          beautyBigEyes: (map['beautyBigEyes'] as num?)?.toDouble(),
        );
      }
    } catch (_) {}
  }

  Future<void> _persistBeautySettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _kBeautyStorageKey,
        jsonEncode({
          'beautySmoothness': state.beautySmoothness,
          'beautyBlurDegree': state.beautyBlurDegree,
          'beautySlimFace': state.beautySlimFace,
          'beautyBigEyes': state.beautyBigEyes,
        }),
      );
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Public setters — mirrors Zustand action names
  // ---------------------------------------------------------------------------

  void setActiveCall(
    ActiveCall call,
    CallOverlayUser? otherUser, {
    String? callToken,
    CallType callType,
    CallStateValue callState = 'ongoing',
  }) {
    state = state.copyWith(
      activeCall: call,
      otherUser: otherUser,
      isMinimized: false,
      callToken: callToken,
      callType: callType,
      callState: callState,
    );
  }

  /// Convenience: start an outgoing call from the chat screen.
  /// Socket emit (call:request) is done in the screen; this only updates state.
  void startOutgoingCall(CallOverlayUser otherUser, String callType) {
    final sessionId =
        'call_${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';
    setActiveCall(
      ActiveCall(sessionId: sessionId),
      otherUser,
      callType: callType,
      callState: 'outgoing',
    );
  }

  void clearCall() {
    state = state.copyWith(
      clearActiveCall: true,
      isMinimized: false,
      clearOtherUser: true,
      clearCallToken: true,
      clearCallType: true,
      clearCallState: true,
      isMuted: false,
      isSpeakerOn: true,
    );
  }

  void setCallState(String? callState) {
    state = state.copyWith(callState: callState);
  }

  void setMinimized(bool minimized) {
    state = state.copyWith(isMinimized: minimized);
  }

  void setMuted(bool muted) {
    state = state.copyWith(isMuted: muted);
  }

  void setSpeakerOn(bool speakerOn) {
    state = state.copyWith(isSpeakerOn: speakerOn);
  }

  void setBeautySmoothness(double val) {
    state = state.copyWith(beautySmoothness: val);
    _persistBeautySettings();
  }

  void setBeautyBlurDegree(double val) {
    state = state.copyWith(beautyBlurDegree: val);
    _persistBeautySettings();
  }

  void setBeautySlimFace(double val) {
    state = state.copyWith(beautySlimFace: val);
    _persistBeautySettings();
  }

  void setBeautyBigEyes(double val) {
    state = state.copyWith(beautyBigEyes: val);
    _persistBeautySettings();
  }
}

final callOverlayProvider =
    NotifierProvider<CallOverlayNotifier, CallOverlayState>(
  CallOverlayNotifier.new,
);
