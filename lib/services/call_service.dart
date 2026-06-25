import 'dart:async';
import 'dart:math' as math;

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/env.dart';
import '../core/dio_client.dart';
import '../state/call_overlay_provider.dart';
import '../state/me_provider.dart';

// ---------------------------------------------------------------------------
// CallEngineState — lightweight ChangeNotifier the UI watches for joined/uid
// ---------------------------------------------------------------------------

class CallEngineState extends ChangeNotifier {
  bool joined = false;
  int? remoteUid;
  bool engineReady = false;
  String? channelId;

  void _setJoined(bool v) {
    joined = v;
    notifyListeners();
  }

  void _setRemoteUid(int? uid) {
    remoteUid = uid;
    notifyListeners();
  }

  void _setEngineReady(bool v) {
    engineReady = v;
    notifyListeners();
  }

  void _setChannelId(String? id) {
    channelId = id;
  }

  void reset() {
    joined = false;
    remoteUid = null;
    engineReady = false;
    channelId = null;
    notifyListeners();
  }
}

// ---------------------------------------------------------------------------
// CallService — owns the Agora RtcEngine lifecycle
// ---------------------------------------------------------------------------

class CallService {
  CallService(this._ref);

  final Ref _ref;

  RtcEngine? _engine;
  final CallEngineState engineState = CallEngineState();

  RtcEngine? get engine => _engine;

  // -------------------------------------------------------------------------
  // Engine setup — mirrors OngoingCallScreen.tsx initAgoraRtcEngine
  // -------------------------------------------------------------------------

  Future<void> initEngine({required bool isVideo}) async {
    if (_engine != null) return; // already initialised

    final rtcEngine = createAgoraRtcEngine();
    _engine = rtcEngine;

    await rtcEngine.initialize(RtcEngineContext(
      appId: Env.agoraAppId,
      channelProfile: ChannelProfileType.channelProfileCommunication,
    ));

    await rtcEngine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);

    // Register event handlers
    rtcEngine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (connection, elapsed) {
          engineState._setJoined(true);
          debugPrint('[Agora] Joined channel: ${connection.channelId}');
        },
        onUserJoined: (connection, remoteUid, elapsed) {
          engineState._setRemoteUid(remoteUid);
          debugPrint('[Agora] Remote user joined: $remoteUid');
        },
        onUserOffline: (connection, remoteUid, reason) {
          debugPrint('[Agora] Remote user offline: $remoteUid reason: $reason');
          // Signal call end via overlay; the socket call:end will also arrive
          _ref.read(callOverlayProvider.notifier).clearCall();
        },
      ),
    );

    // Apply beauty effects
    await _applyBeautyEffects();

    if (isVideo) {
      await rtcEngine.enableVideo();
      await rtcEngine.enableLocalVideo(true);
      await rtcEngine.muteLocalVideoStream(false);
      try {
        await rtcEngine.startPreview();
      } catch (_) {}
    } else {
      await rtcEngine.enableAudio();
    }

    engineState._setEngineReady(true);
  }

  // -------------------------------------------------------------------------
  // Apply beauty / virtual background from callOverlayProvider
  // -------------------------------------------------------------------------

  Future<void> _applyBeautyEffects() async {
    if (_engine == null) return;
    final overlay = _ref.read(callOverlayProvider);
    final smoothness = overlay.beautySmoothness;
    final blurDegree = overlay.beautyBlurDegree;
    final slimFace = overlay.beautySlimFace;
    final bigEyes = overlay.beautyBigEyes;

    // Basic beauty
    try {
      await _engine!.setBeautyEffectOptions(
        enabled: true,
        options: BeautyOptions(
          lighteningContrastLevel:
              LighteningContrastLevel.lighteningContrastNormal,
          lighteningLevel: 0.7,
          smoothnessLevel: (smoothness / 100).clamp(0.0, 1.0),
          rednessLevel: 0.5,
          sharpnessLevel: 0.3,
        ),
      );
    } catch (e) {
      debugPrint('[Agora] setBeautyEffectOptions error: $e');
    }

    // Virtual background blur
    try {
      if (blurDegree <= 0) {
        await _engine!.enableVirtualBackground(
          enabled: false,
          backgroundSource:
              const VirtualBackgroundSource(backgroundSourceType: BackgroundSourceType.backgroundNone),
          segproperty: const SegmentationProperty(),
        );
      } else {
        final degree = blurDegree < 33
            ? BackgroundBlurDegree.blurDegreeLow
            : blurDegree < 66
                ? BackgroundBlurDegree.blurDegreeMedium
                : BackgroundBlurDegree.blurDegreeHigh;
        await _engine!.enableVirtualBackground(
          enabled: true,
          backgroundSource: VirtualBackgroundSource(
            backgroundSourceType: BackgroundSourceType.backgroundBlur,
            blurDegree: degree,
          ),
          segproperty: const SegmentationProperty(),
        );
      }
    } catch (e) {
      debugPrint('[Agora] enableVirtualBackground error: $e');
    }

    // Face shape beauty
    try {
      await _engine!.setFaceShapeBeautyOptions(
        enabled: true,
        options: const FaceShapeBeautyOptions(
          shapeStyle: FaceShapeBeautyStyle.faceShapeBeautyStyleNatural,
          styleIntensity: 20,
        ),
      );
    } catch (e) {
      debugPrint('[Agora] setFaceShapeBeautyOptions error (may be unsupported): $e');
    }

    // Slim face
    try {
      await _engine!.setFaceShapeAreaOptions(
        options: FaceShapeAreaOptions(
          shapeArea: FaceShapeArea.faceShapeAreaFacecontour,
          shapeIntensity: slimFace.toInt(),
        ),
      );
    } catch (e) {
      debugPrint('[Agora] setFaceShapeAreaOptions (slimFace) error: $e');
    }

    // Big eyes
    try {
      await _engine!.setFaceShapeAreaOptions(
        options: FaceShapeAreaOptions(
          shapeArea: FaceShapeArea.faceShapeAreaEyescale,
          shapeIntensity: bigEyes.toInt(),
        ),
      );
    } catch (e) {
      debugPrint('[Agora] setFaceShapeAreaOptions (bigEyes) error: $e');
    }
  }

  // -------------------------------------------------------------------------
  // Re-apply beauty after slider changes
  // -------------------------------------------------------------------------

  Future<void> reapplyBeauty() => _applyBeautyEffects();

  // -------------------------------------------------------------------------
  // Join channel
  // -------------------------------------------------------------------------

  Future<void> joinChannel({
    required String sessionId,
    required bool isVideo,
    required bool isMuted,
  }) async {
    if (_engine == null) return;
    if (engineState.joined) return;

    final me = _ref.read(meProvider).asData?.value;
    if (me == null) return;

    // Derive numeric UID from me.id — strip non-digits, take first 8 chars
    final idStr = me.id.toString().replaceAll(RegExp(r'[^0-9]'), '');
    final clipped = idStr.isEmpty
        ? '0'
        : idStr.substring(0, math.min(8, idStr.length));
    final numericUid = int.tryParse(clipped) ?? 0;

    // Fetch Agora token
    String token = '';
    try {
      final dio = _ref.read(dioProvider);
      final resp = await dio.get(
        '${Env.apiBase}/api/agora/token',
        queryParameters: {'channelName': sessionId, 'uid': me.id.toString()},
      );
      token = (resp.data is Map ? resp.data['token'] : null) ??
          resp.data.toString();
    } catch (e) {
      debugPrint('[Agora] Token fetch error: $e');
    }

    engineState._setChannelId(sessionId);

    await _engine!.joinChannel(
      token: token,
      channelId: sessionId,
      uid: numericUid,
      options: ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        publishCameraTrack: isVideo,
        publishMicrophoneTrack: !isMuted,
        autoSubscribeAudio: true,
        autoSubscribeVideo: isVideo,
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Controls
  // -------------------------------------------------------------------------

  Future<void> muteLocalAudio(bool mute) async {
    try {
      await _engine?.muteLocalAudioStream(mute);
    } catch (e) {
      debugPrint('[Agora] muteLocalAudioStream error: $e');
    }
  }

  Future<void> toggleLocalVideo(bool enabled) async {
    try {
      await _engine?.enableLocalVideo(enabled);
      await _engine?.muteLocalVideoStream(!enabled);
    } catch (e) {
      debugPrint('[Agora] toggleLocalVideo error: $e');
    }
  }

  Future<void> setSpeakerOn(bool on) async {
    try {
      await _engine?.setEnableSpeakerphone(on);
    } catch (e) {
      debugPrint('[Agora] setEnableSpeakerphone error: $e');
    }
  }

  Future<void> switchCamera() async {
    try {
      await _engine?.switchCamera();
    } catch (e) {
      debugPrint('[Agora] switchCamera error: $e');
    }
  }

  // -------------------------------------------------------------------------
  // Tear-down
  // -------------------------------------------------------------------------

  Future<void> leaveAndRelease() async {
    try {
      await _engine?.leaveChannel();
    } catch (_) {}
    try {
      await _engine?.release();
    } catch (_) {}
    _engine = null;
    engineState.reset();
  }

  void dispose() {
    leaveAndRelease();
    engineState.dispose();
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final callServiceProvider = Provider<CallService>((ref) {
  final service = CallService(ref);
  ref.onDispose(service.dispose);
  return service;
});
