import 'dart:async';
import 'dart:io';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:screen_protector/screen_protector.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../services/call_service.dart';
import '../../services/socket_service.dart';
import '../../state/call_overlay_provider.dart';
import '../../state/me_provider.dart';
import '../../theme/theme.dart';
import '../../widgets/call/beauty_settings_modal.dart';
import '../../widgets/call/earnings_overlay.dart';

// ---------------------------------------------------------------------------
// OngoingCallScreen â€” global overlay widget
// Mirrors OngoingCallScreen.tsx
// ---------------------------------------------------------------------------

class OngoingCallScreen extends ConsumerStatefulWidget {
  const OngoingCallScreen({super.key});

  @override
  ConsumerState<OngoingCallScreen> createState() => _OngoingCallScreenState();
}

class _OngoingCallScreenState extends ConsumerState<OngoingCallScreen>
    with WidgetsBindingObserver {
  // Call timer
  Timer? _timerTick;
  int _durationSeconds = 0;

  // Local PiP drag position
  double _pipX = 0;
  double _pipY = 80;
  bool _pipPositioned = false;

  // Video paused flag (local camera)
  bool _isVideoPaused = false;

  // Beauty modal visible
  bool _isBeautyModalVisible = false;

  // Track previous callState to detect engine-start transitions
  String? _prevCallState;
  bool _engineInitStarted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timerTick?.cancel();
    WakelockPlus.disable().catchError((_) {});
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  // App lifecycle â€” pause/resume
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final overlay = ref.read(callOverlayProvider);
    if (overlay.activeCall == null) return;
    final callId = overlay.activeCall!.sessionId;
    final socket = ref.read(socketServiceProvider);

    if (state == AppLifecycleState.paused) {
      socket.pauseCall(callId: callId);
    } else if (state == AppLifecycleState.resumed) {
      socket.resumeCall(callId: callId);
    }
  }

  // -------------------------------------------------------------------------
  // Screen capture protection — mirrors RN react-native-capture-protection
  // Enabled when a call is active; disabled when the call clears.
  // Guards with try/catch and platform check (ScreenProtector throws on web).
  // -------------------------------------------------------------------------

  Future<void> _enableCaptureProtection() async {
    // Debug builds: never block screenshots/recording so we can capture and
    // inspect the call screen while testing. Protection is release-only.
    if (!kReleaseMode) return;
    if (!Platform.isAndroid && !Platform.isIOS) return;
    try {
      // Prevent screenshots and screen recording (Android + iOS).
      await ScreenProtector.preventScreenshotOn();
      if (Platform.isIOS) {
        // Hide app content in the iOS app-switcher with a solid black overlay.
        // protectDataLeakageWithColor is iOS-only and takes no args on Android,
        // so we guard with platform check.
        await ScreenProtector.protectDataLeakageWithColor(Colors.black);
      } else {
        // Android: FLAG_SECURE already applied by preventScreenshotOn;
        // protectDataLeakageOn adds the same flag — call as belt-and-braces.
        await ScreenProtector.protectDataLeakageOn();
      }
      debugPrint('[OngoingCallScreen] Screen capture protection ENABLED');
    } catch (e) {
      debugPrint('[OngoingCallScreen] enableCaptureProtection error: $e');
    }
  }

  Future<void> _disableCaptureProtection() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    try {
      await ScreenProtector.preventScreenshotOff();
      if (Platform.isIOS) {
        await ScreenProtector.protectDataLeakageWithColorOff();
      } else {
        await ScreenProtector.protectDataLeakageOff();
      }
      debugPrint('[OngoingCallScreen] Screen capture protection DISABLED');
    } catch (e) {
      debugPrint('[OngoingCallScreen] disableCaptureProtection error: $e');
    }
  }

  // -------------------------------------------------------------------------
  // Start timer
  // -------------------------------------------------------------------------

  void _startTimer() {
    _timerTick?.cancel();
    _durationSeconds = 0;
    _timerTick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _durationSeconds++);
    });
    WakelockPlus.enable().catchError((_) {});
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  String get _formattedDuration {
    final h = _durationSeconds ~/ 3600;
    final m = (_durationSeconds % 3600) ~/ 60;
    final s = _durationSeconds % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // -------------------------------------------------------------------------
  // Engine init (permissions + Agora setup)
  // -------------------------------------------------------------------------

  Future<void> _initEngine(bool isVideo) async {
    if (_engineInitStarted) return;
    _engineInitStarted = true;

    // Request permissions
    final permissions = [Permission.microphone];
    if (isVideo) permissions.add(Permission.camera);
    await permissions.request();

    final callService = ref.read(callServiceProvider);
    await callService.initEngine(isVideo: isVideo);
  }

  // -------------------------------------------------------------------------
  // Join channel (called when callState transitions to 'ongoing')
  // -------------------------------------------------------------------------

  Future<void> _joinChannel(String sessionId, bool isVideo, bool isMuted) async {
    final callService = ref.read(callServiceProvider);
    await callService.joinChannel(
      sessionId: sessionId,
      isVideo: isVideo,
      isMuted: isMuted,
    );
    if (mounted) _startTimer();
  }

  // -------------------------------------------------------------------------
  // End / cancel helpers
  // -------------------------------------------------------------------------

  Future<void> _endCall() async {
    final overlay = ref.read(callOverlayProvider);
    if (overlay.activeCall == null) return;
    final socket = ref.read(socketServiceProvider);
    final callId = overlay.activeCall!.sessionId;
    final isOutgoing = overlay.callState == 'outgoing';

    if (isOutgoing) {
      socket.cancelCall(
          callId: callId, receiverId: overlay.otherUser?.id ?? '');
    } else {
      socket.endCall(callId: callId);
    }

    await ref.read(callServiceProvider).leaveAndRelease();
    ref.read(callOverlayProvider.notifier).clearCall();
    _engineInitStarted = false;
    _timerTick?.cancel();
    WakelockPlus.disable().catchError((_) {});
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  Future<void> _rejectCall() async {
    final overlay = ref.read(callOverlayProvider);
    if (overlay.activeCall == null) return;
    ref
        .read(socketServiceProvider)
        .rejectCall(callId: overlay.activeCall!.sessionId);
    ref.read(callOverlayProvider.notifier).clearCall();
    _engineInitStarted = false;
  }

  Future<void> _answerCall() async {
    final overlay = ref.read(callOverlayProvider);
    if (overlay.activeCall == null) return;
    final socket = ref.read(socketServiceProvider);
    final callId = overlay.activeCall!.sessionId;

    // Accept and set state to ongoing
    socket.acceptCall(callId: callId);
    ref.read(callOverlayProvider.notifier).setCallState('ongoing');

    // Init engine
    final isVideo = overlay.callType == 'video';
    await _initEngine(isVideo);
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final overlay = ref.watch(callOverlayProvider);

    // No active call â€” show nothing
    if (overlay.activeCall == null) {
      _engineInitStarted = false;
      return const SizedBox.shrink();
    }

    // Detect callState changes to trigger engine init / join
    final callState = overlay.callState;
    if (callState != _prevCallState) {
      _handleCallStateChange(overlay, callState);
      _prevCallState = callState;
    }

    // If minimized â€” keep mounted (so engine runs) but hide visually
    if (overlay.isMinimized) {
      return const SizedBox.shrink();
    }

    // Fill the entire screen — without this, as a non-positioned Stack child
    // the call UI shrinks to its content width (~the avatar) and the screen
    // behind it shows through. SizedBox.expand forces full width + height.
    return SizedBox.expand(
      child: Material(
        color: AppColors.callDarkBg,
        child: _buildCallUI(context, overlay),
      ),
    );
  }

  void _handleCallStateChange(
      CallOverlayState overlay, String? callState) {
    if (callState == 'outgoing') {
      // Start engine early so it is ready when the call is accepted.
      // Enable capture protection as soon as call begins.
      final isVideo = overlay.callType == 'video';
      _initEngine(isVideo);
      _enableCaptureProtection();
    } else if (callState == 'incoming') {
      // Protect screen on incoming call UI too (peer can share their screen).
      _enableCaptureProtection();
    } else if (callState == 'ongoing') {
      final sessionId = overlay.activeCall?.sessionId ?? '';
      final isVideo = overlay.callType == 'video';
      final isMuted = overlay.isMuted;
      final callService = ref.read(callServiceProvider);
      if (!callService.engineState.joined) {
        _joinChannel(sessionId, isVideo, isMuted);
      }
      // Ensure protection is on (may have come from incoming → ongoing).
      _enableCaptureProtection();
    } else if (callState == null) {
      // Call ended — remove capture protection.
      _disableCaptureProtection();
      _engineInitStarted = false;
      _timerTick?.cancel();
      _durationSeconds = 0;
      WakelockPlus.disable().catchError((_) {});
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }
  }

  Widget _buildCallUI(BuildContext context, CallOverlayState overlay) {
    switch (overlay.callState) {
      case 'outgoing':
        return _OutgoingCallUI(
          overlay: overlay,
          onEnd: _endCall,
        );
      case 'incoming':
        return _IncomingCallUI(
          overlay: overlay,
          onDecline: _rejectCall,
          onAnswer: _answerCall,
        );
      case 'ongoing':
        return _OngoingUI(
          overlay: overlay,
          durationText: _formattedDuration,
          isVideoPaused: _isVideoPaused,
          isBeautyModalVisible: _isBeautyModalVisible,
          pipX: _pipX,
          pipY: _pipY,
          pipPositioned: _pipPositioned,
          onMinimize: () =>
              ref.read(callOverlayProvider.notifier).setMinimized(true),
          onEnd: _endCall,
          onMuteToggle: () {
            final newMuted = !overlay.isMuted;
            ref.read(callOverlayProvider.notifier).setMuted(newMuted);
            ref.read(callServiceProvider).muteLocalAudio(newMuted);
          },
          onSpeakerToggle: () {
            final newSpeaker = !overlay.isSpeakerOn;
            ref.read(callOverlayProvider.notifier).setSpeakerOn(newSpeaker);
            ref.read(callServiceProvider).setSpeakerOn(newSpeaker);
          },
          onVideoToggle: () {
            setState(() => _isVideoPaused = !_isVideoPaused);
            ref
                .read(callServiceProvider)
                .toggleLocalVideo(!_isVideoPaused);
          },
          onBeautyToggle: () =>
              setState(() => _isBeautyModalVisible = !_isBeautyModalVisible),
          onBeautyClose: () =>
              setState(() => _isBeautyModalVisible = false),
          onSwitchCamera: () =>
              ref.read(callServiceProvider).switchCamera(),
          onPipDrag: (dx, dy, screenW, screenH) {
            setState(() {
              _pipPositioned = true;
              _pipX = (_pipX + dx).clamp(0.0, screenW - 120.0);
              _pipY = (_pipY + dy).clamp(0.0, screenH - 160.0);
            });
          },
          onPipPositionInit: (screenW) {
            if (!_pipPositioned) {
              _pipX = screenW - 140.0;
            }
          },
        );
      default:
        // Connecting state (between incoming accepted and joined)
        return _ConnectingCallUI(overlay: overlay);
    }
  }
}

// ---------------------------------------------------------------------------
// OutgoingCallUI
// ---------------------------------------------------------------------------

class _OutgoingCallUI extends StatelessWidget {
  const _OutgoingCallUI({required this.overlay, required this.onEnd});

  final CallOverlayState overlay;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    final name = overlay.otherUser?.name ?? 'Unknown';
    final avatarUrl = overlay.otherUser?.profilePictureUrl;

    return Container(
      color: AppColors.callDarkBg,
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SizedBox(height: 60),
            Column(
              children: [
                _Avatar(url: avatarUrl, name: name, size: 150),
                const SizedBox(height: 20),
                Text(
                  name,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Calling...',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 16),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 60),
              child: _EndCallButton(onTap: onEnd),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// IncomingCallUI
// ---------------------------------------------------------------------------

class _IncomingCallUI extends StatelessWidget {
  const _IncomingCallUI({
    required this.overlay,
    required this.onDecline,
    required this.onAnswer,
  });

  final CallOverlayState overlay;
  final VoidCallback onDecline;
  final VoidCallback onAnswer;

  @override
  Widget build(BuildContext context) {
    final name = overlay.otherUser?.name ?? 'Unknown';
    final avatarUrl = overlay.otherUser?.profilePictureUrl;
    final isVideo = overlay.callType == 'video';

    return Container(
      color: AppColors.callDarkBg,
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SizedBox(height: 60),
            Column(
              children: [
                _Avatar(url: avatarUrl, name: name, size: 150),
                const SizedBox(height: 20),
                Text(
                  name,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Incoming ${isVideo ? 'video' : 'audio'} call...',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6), fontSize: 16),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 60),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Decline
                  _CallActionButton(
                    icon: LucideIcons.phone,
                    color: AppColors.dangerIOS,
                    rotate: true,
                    onTap: onDecline,
                  ),
                  const SizedBox(width: 60),
                  // Answer
                  _CallActionButton(
                    icon: LucideIcons.phone,
                    color: AppColors.green500,
                    onTap: onAnswer,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ConnectingCallUI
// ---------------------------------------------------------------------------

class _ConnectingCallUI extends StatelessWidget {
  const _ConnectingCallUI({required this.overlay});

  final CallOverlayState overlay;

  @override
  Widget build(BuildContext context) {
    final name = overlay.otherUser?.name ?? '';
    final avatarUrl = overlay.otherUser?.profilePictureUrl;

    return Container(
      color: AppColors.callDarkBg,
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _Avatar(url: avatarUrl, name: name, size: 120),
            const SizedBox(height: 24),
            Text(
              name,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            const SizedBox(height: 16),
            const Text(
              'Connecting call...',
              style: TextStyle(color: Colors.white70, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// OngoingUI â€” the main call screen (video + audio)
// ---------------------------------------------------------------------------

class _OngoingUI extends ConsumerWidget {
  const _OngoingUI({
    required this.overlay,
    required this.durationText,
    required this.isVideoPaused,
    required this.isBeautyModalVisible,
    required this.pipX,
    required this.pipY,
    required this.pipPositioned,
    required this.onMinimize,
    required this.onEnd,
    required this.onMuteToggle,
    required this.onSpeakerToggle,
    required this.onVideoToggle,
    required this.onBeautyToggle,
    required this.onBeautyClose,
    required this.onSwitchCamera,
    required this.onPipDrag,
    required this.onPipPositionInit,
  });

  final CallOverlayState overlay;
  final String durationText;
  final bool isVideoPaused;
  final bool isBeautyModalVisible;
  final double pipX;
  final double pipY;
  final bool pipPositioned;
  final VoidCallback onMinimize;
  final VoidCallback onEnd;
  final VoidCallback onMuteToggle;
  final VoidCallback onSpeakerToggle;
  final VoidCallback onVideoToggle;
  final VoidCallback onBeautyToggle;
  final VoidCallback onBeautyClose;
  final VoidCallback onSwitchCamera;
  final void Function(double dx, double dy, double screenW, double screenH)
      onPipDrag;
  final void Function(double screenW) onPipPositionInit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = MediaQuery.of(context).size;
    final isVideo = overlay.callType == 'video';
    final callService = ref.read(callServiceProvider);
    final engineState = callService.engineState;
    final remoteUid = engineState.remoteUid;
    final me = ref.watch(meProvider).asData?.value;

    onPipPositionInit(size.width);

    return Stack(
      children: [
        // Background: remote video or dark bg
        if (isVideo && remoteUid != null && callService.engine != null)
          Positioned.fill(
            child: AgoraVideoView(
              controller: VideoViewController.remote(
                rtcEngine: callService.engine!,
                canvas: VideoCanvas(uid: remoteUid),
                connection:
                    RtcConnection(channelId: overlay.activeCall!.sessionId),
                useAndroidSurfaceView: true,
              ),
            ),
          )
        else
          Positioned.fill(
            child: Container(color: AppColors.callDarkBg),
          ),

        // Audio mode: show avatar
        if (!isVideo)
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Avatar(
                  url: overlay.otherUser?.profilePictureUrl,
                  name: overlay.otherUser?.name ?? '',
                  size: 150,
                ),
                const SizedBox(height: 20),
                Text(
                  overlay.otherUser?.name ?? '',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

        // Top header â€” minimize + timer
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                GestureDetector(
                  onTap: onMinimize,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(LucideIcons.chevronDown,
                        color: Colors.white, size: 22),
                  ),
                ),
                const Spacer(),
                // Timer badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.green500,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        durationText,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Draggable local PiP (video only)
        if (isVideo && callService.engine != null)
          Positioned(
            left: pipX,
            top: pipY,
            child: GestureDetector(
              onPanUpdate: (details) => onPipDrag(
                details.delta.dx,
                details.delta.dy,
                size.width,
                size.height,
              ),
              child: Stack(
                children: [
                  Container(
                    width: 120,
                    height: 160,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.4), width: 2),
                    ),
                    clipBehavior: Clip.hardEdge,
                    child: isVideoPaused
                        ? Container(color: Colors.black)
                        : AgoraVideoView(
                            controller: VideoViewController(
                              rtcEngine: callService.engine!,
                              canvas: const VideoCanvas(uid: 0),
                              useAndroidSurfaceView: true,
                            ),
                          ),
                  ),
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: onSwitchCamera,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(LucideIcons.refreshCw,
                            color: Colors.white, size: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Bottom controls
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // EarningsOverlay
                if (me != null) ...[
                  EarningsOverlay(me: me),
                  const SizedBox(height: 16),
                ],
                // Controls row
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _ControlButton(
                        icon: overlay.isSpeakerOn
                            ? LucideIcons.volume2
                            : LucideIcons.volumeX,
                        onTap: onSpeakerToggle,
                        label: 'Speaker',
                      ),
                      if (isVideo)
                        _ControlButton(
                          icon: isVideoPaused
                              ? LucideIcons.videoOff
                              : LucideIcons.video,
                          onTap: onVideoToggle,
                          label: 'Video',
                        ),
                      if (isVideo)
                        _ControlButton(
                          icon: LucideIcons.sparkles,
                          onTap: onBeautyToggle,
                          label: 'Beauty',
                          iconColor: isBeautyModalVisible
                              ? AppColors.brandPink
                              : null,
                        ),
                      _ControlButton(
                        icon: overlay.isMuted
                            ? LucideIcons.micOff
                            : LucideIcons.mic,
                        onTap: onMuteToggle,
                        label: overlay.isMuted ? 'Unmute' : 'Mute',
                      ),
                      _EndCallButton(onTap: onEnd, size: 70),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Beauty modal
        if (isBeautyModalVisible)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: BeautySettingsModal(onClose: onBeautyClose),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Shared small widgets
// ---------------------------------------------------------------------------

class _Avatar extends StatelessWidget {
  const _Avatar({this.url, required this.name, this.size = 100});

  final String? url;
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF075e54),
        shape: BoxShape.circle,
        image: url != null && url!.isNotEmpty
            ? DecorationImage(
                image: CachedNetworkImageProvider(url!),
                fit: BoxFit.cover,
              )
            : null,
      ),
      alignment: Alignment.center,
      child: (url == null || url!.isEmpty)
          ? Text(
              initial,
              style: TextStyle(
                color: Colors.white,
                fontSize: size * 0.4,
                fontWeight: FontWeight.bold,
              ),
            )
          : null,
    );
  }
}

class _EndCallButton extends StatelessWidget {
  const _EndCallButton({required this.onTap, this.size = 70});

  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.dangerIOS,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
                color: AppColors.dangerIOS.withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 4))
          ],
        ),
        alignment: Alignment.center,
        child: Transform.rotate(
          angle: 2.356, // 135Â° â€” matches RN rotate('135deg')
          child: const Icon(LucideIcons.phone, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}

class _CallActionButton extends StatelessWidget {
  const _CallActionButton({
    required this.icon,
    required this.color,
    required this.onTap,
    this.rotate = false,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool rotate;

  @override
  Widget build(BuildContext context) {
    Widget child = Icon(icon, color: Colors.white, size: 30);
    if (rotate) {
      child = Transform.rotate(angle: 2.356, child: child);
    }
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: child,
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.onTap,
    this.label = '',
    this.iconColor,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String label;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2))
              ],
            ),
            alignment: Alignment.center,
            child: Icon(icon,
                color: iconColor ?? AppColors.callDarkBg, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

