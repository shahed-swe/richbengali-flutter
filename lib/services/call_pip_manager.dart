import 'dart:io';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';

/// Wraps Agora's [AgoraPipController] to show the ongoing 1-1 call in a floating
/// Picture-in-Picture window when the app is backgrounded.
///
/// * iOS  — system PiP (AVPictureInPictureController) for video calls.
/// * Android — native PiP mode. Requires MainActivity to extend
///   `AgoraPIPFlutterActivity` and `android:supportsPictureInPicture="true"`.
///
/// Everything is guarded on [supported]; on platforms/OS versions where PiP is
/// unavailable it silently no-ops (audio calls on iOS fall back to the CallKit
/// return-to-call bar, which is the standard iOS behaviour).
class CallPipManager {
  CallPipManager(this._engine);

  final RtcEngine _engine;
  AgoraPipController? _controller;

  bool supported = false;
  bool autoEnterSupported = false;
  bool _setupDone = false;
  bool _active = false;

  bool get isActive => _active;

  /// Notified when PiP starts (true) or stops (false).
  void Function(bool active)? onPipStateChanged;

  Future<void> init() async {
    try {
      final controller = _engine.createPipController();
      _controller = controller;
      supported = await controller.pipIsSupported();
      autoEnterSupported = await controller.pipIsAutoEnterSupported();
      if (!supported) {
        debugPrint('[CallPip] PiP not supported on this device');
        return;
      }
      await controller.registerPipStateChangedObserver(
        AgoraPipStateChangedObserver(
          onPipStateChanged: (state, error) {
            _active = state == AgoraPipState.pipStateStarted;
            if (state == AgoraPipState.pipStateFailed) {
              debugPrint('[CallPip] PiP failed: $error');
            }
            onPipStateChanged?.call(_active);
          },
        ),
      );
    } catch (e) {
      debugPrint('[CallPip] init error: $e');
      supported = false;
    }
  }

  /// Configure the PiP window. Call once the call is ongoing and joined.
  Future<void> setup({
    required String channelId,
    required int localUid,
    int? remoteUid,
    required int width,
    required int height,
    required bool isVideo,
  }) async {
    final controller = _controller;
    if (controller == null || !supported) return;
    try {
      final conn = RtcConnection(channelId: channelId, localUid: localUid);
      final streams = <AgoraPipVideoStream>[
        AgoraPipVideoStream(
          connection: conn,
          canvas: const VideoCanvas(
            uid: 0,
            sourceType: VideoSourceType.videoSourceCamera,
            setupMode: VideoViewSetupMode.videoViewSetupAdd,
            renderMode: RenderModeType.renderModeHidden,
            mirrorMode: VideoMirrorModeType.videoMirrorModeEnabled,
          ),
        ),
        if (remoteUid != null)
          AgoraPipVideoStream(
            connection: conn,
            canvas: VideoCanvas(
              uid: remoteUid,
              sourceType: VideoSourceType.videoSourceRemote,
              setupMode: VideoViewSetupMode.videoViewSetupAdd,
              renderMode: RenderModeType.renderModeHidden,
            ),
          ),
      ];

      final AgoraPipOptions options;
      if (Platform.isAndroid) {
        // Android shows the shrunken activity in PiP; no videoStreams needed.
        options = AgoraPipOptions(
          autoEnterEnabled: autoEnterSupported,
          aspectRatioX: 9,
          aspectRatioY: 16,
          sourceRectHintLeft: 0,
          sourceRectHintTop: 0,
          sourceRectHintRight: 0,
          sourceRectHintBottom: 0,
          seamlessResizeEnabled: true,
          // FlutterActivity does not forward PiP events; poll for state.
          useExternalStateMonitor: true,
          externalStateMonitorInterval: 100,
        );
      } else {
        // iOS renders the given video streams in a native-managed PiP layer.
        options = AgoraPipOptions(
          autoEnterEnabled: autoEnterSupported,
          preferredContentWidth: width,
          preferredContentHeight: height,
          sourceContentView: 0,
          contentView: 0,
          contentViewLayout: AgoraPipContentViewLayout(
            padding: 0,
            spacing: 2,
            row: isVideo ? streams.length : 1,
            column: 1,
          ),
          videoStreams: isVideo ? streams : const <AgoraPipVideoStream>[],
        );
      }

      _setupDone = await controller.pipSetup(options);
      debugPrint('[CallPip] setup done=$_setupDone auto=$autoEnterSupported');
    } catch (e) {
      debugPrint('[CallPip] setup error: $e');
    }
  }

  /// Enter PiP (call when the app is going to background during a call).
  Future<void> start() async {
    if (!supported || !_setupDone) return;
    try {
      await _controller?.pipStart();
    } catch (e) {
      debugPrint('[CallPip] start error: $e');
    }
  }

  /// Exit PiP (iOS). On Android pipStop only backgrounds the activity.
  Future<void> stop() async {
    if (!supported) return;
    try {
      await _controller?.pipStop();
    } catch (e) {
      debugPrint('[CallPip] stop error: $e');
    }
  }

  Future<void> dispose() async {
    try {
      await _controller?.unregisterPipStateChangedObserver();
      await _controller?.pipDispose();
      await _controller?.dispose();
    } catch (e) {
      debugPrint('[CallPip] dispose error: $e');
    }
    _controller = null;
    _setupDone = false;
    _active = false;
  }
}
