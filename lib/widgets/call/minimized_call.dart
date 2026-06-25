import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../services/call_service.dart';
import '../../services/socket_service.dart';
import '../../state/call_overlay_provider.dart';
import '../../theme/theme.dart';

/// Mirrors MinimizedCall.tsx — a sticky bar visible when the call is minimized.
/// Tapping it restores the full-screen call UI.
class MinimizedCallBar extends ConsumerWidget {
  const MinimizedCallBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overlay = ref.watch(callOverlayProvider);

    // Only show when there is an active call AND it is minimized
    if (overlay.activeCall == null || !overlay.isMinimized) {
      return const SizedBox.shrink();
    }

    final notifier = ref.read(callOverlayProvider.notifier);
    final socket = ref.read(socketServiceProvider);
    final callService = ref.read(callServiceProvider);
    final callId = overlay.activeCall!.sessionId;
    final otherUser = overlay.otherUser;
    final name = otherUser?.name ?? 'Unknown';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final isVideo = overlay.callType == 'video';
    final isOutgoing = overlay.callState == 'outgoing';

    Future<void> handleEnd() async {
      if (isOutgoing) {
        socket.cancelCall(
          callId: callId,
          receiverId: otherUser?.id ?? '',
        );
      } else {
        socket.endCall(callId: callId);
      }
      await callService.leaveAndRelease();
      notifier.clearCall();
    }

    void handleMuteToggle() {
      final newMuted = !overlay.isMuted;
      notifier.setMuted(newMuted);
      callService.muteLocalAudio(newMuted);
    }

    return GestureDetector(
      onTap: () => notifier.setMinimized(false),
      child: Material(
        elevation: 10,
        color: const Color(0xFF6f6f6f),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(
                vertical: 12, horizontal: 16),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: Color(0xFF075e54),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Name + status
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        isVideo ? 'Ongoing video' : 'Ongoing audio',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                // Mute toggle
                _ActionButton(
                  icon: overlay.isMuted
                      ? LucideIcons.micOff
                      : LucideIcons.mic,
                  onTap: handleMuteToggle,
                ),
                const SizedBox(width: 8),
                // End call
                _ActionButton(
                  icon: LucideIcons.phone,
                  onTap: handleEnd,
                  backgroundColor: AppColors.dangerIOS,
                  rotate: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.onTap,
    this.backgroundColor,
    this.rotate = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color? backgroundColor;
  final bool rotate;

  @override
  Widget build(BuildContext context) {
    Widget iconWidget = Icon(icon, size: 18, color: Colors.white);
    if (rotate) {
      iconWidget = Transform.rotate(
        angle: 2.356, // ~135 degrees
        child: iconWidget,
      );
    }
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: backgroundColor ?? Colors.black26,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: iconWidget,
      ),
    );
  }
}
