import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../services/call_service.dart';
import '../../state/call_overlay_provider.dart';
import '../../theme/theme.dart';

// ---------------------------------------------------------------------------
// BeautySettingsModal
// ---------------------------------------------------------------------------

/// Mirrors BeautySettingsModal.tsx — bottom-sheet with background picker and
/// 3 sliders controlling beauty effects: Smoothness, Slim Face, Big Eyes.
class BeautySettingsModal extends ConsumerWidget {
  const BeautySettingsModal({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overlay = ref.watch(callOverlayProvider);
    final notifier = ref.read(callOverlayProvider.notifier);
    final callService = ref.read(callServiceProvider);

    Future<void> reapply() async {
      await callService.reapplyBeauty();
    }

    Future<void> reapplyBg() async {
      await callService.reapplyBackground();
    }

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF18181b),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white30,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          // Header
          Row(
            children: [
              const Icon(LucideIcons.sparkles,
                  size: 20, color: AppColors.brandPink),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Beauty Filters',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              GestureDetector(
                onTap: onClose,
                child: const Icon(LucideIcons.x,
                    size: 22, color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ----------------------------------------------------------------
          // Background section
          // ----------------------------------------------------------------
          _BackgroundPicker(
            overlay: overlay,
            notifier: notifier,
            reapplyBg: reapplyBg,
          ),

          const SizedBox(height: 28),

          // ----------------------------------------------------------------
          // Sliders — Smoothness, Slim Face, Big Eyes
          // ----------------------------------------------------------------
          _BeautySlider(
            icon: LucideIcons.sparkles,
            label: 'Smoothness',
            value: overlay.beautySmoothness,
            onChanged: (v) {
              notifier.setBeautySmoothness(v);
              reapply();
            },
          ),
          const SizedBox(height: 20),
          _BeautySlider(
            icon: LucideIcons.user,
            label: 'Slim Face',
            value: overlay.beautySlimFace,
            onChanged: (v) {
              notifier.setBeautySlimFace(v);
              reapply();
            },
          ),
          const SizedBox(height: 20),
          _BeautySlider(
            icon: LucideIcons.eye,
            label: 'Big Eyes',
            value: overlay.beautyBigEyes,
            onChanged: (v) {
              notifier.setBeautyBigEyes(v);
              reapply();
            },
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Background Picker — None | Blur | Strong only
// ---------------------------------------------------------------------------

class _BackgroundPicker extends StatelessWidget {
  const _BackgroundPicker({
    required this.overlay,
    required this.notifier,
    required this.reapplyBg,
  });

  final CallOverlayState overlay;
  final CallOverlayNotifier notifier;
  final Future<void> Function() reapplyBg;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Background',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 90,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              // ---- None ----
              _BgTile(
                label: 'None',
                isSelected: overlay.bgMode == VirtualBgMode.none,
                onTap: () async {
                  notifier.setBgMode(VirtualBgMode.none);
                  await reapplyBg();
                },
                child: const Icon(LucideIcons.ban,
                    size: 26, color: Colors.white70),
              ),
              const SizedBox(width: 10),

              // ---- Blur (light) ----
              _BgTile(
                label: 'Blur',
                isSelected: overlay.bgMode == VirtualBgMode.blurLight,
                onTap: () async {
                  notifier.setBgMode(VirtualBgMode.blurLight);
                  await reapplyBg();
                },
                child: const Icon(LucideIcons.droplets,
                    size: 26, color: Colors.white70),
              ),
              const SizedBox(width: 10),

              // ---- Blur (strong) ----
              _BgTile(
                label: 'Strong',
                isSelected: overlay.bgMode == VirtualBgMode.blurStrong,
                onTap: () async {
                  notifier.setBgMode(VirtualBgMode.blurStrong);
                  await reapplyBg();
                },
                child: Stack(
                  alignment: Alignment.center,
                  children: const [
                    Icon(LucideIcons.droplets, size: 26, color: Colors.white70),
                    Positioned(
                      right: 6,
                      bottom: 6,
                      child: Icon(LucideIcons.droplets,
                          size: 14, color: Colors.white38),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Generic background tile
// ---------------------------------------------------------------------------

class _BgTile extends StatelessWidget {
  const _BgTile({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.child,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: const Color(0xFF2a2a2e),
              border: isSelected
                  ? Border.all(color: AppColors.brandPink, width: 2.5)
                  : Border.all(color: Colors.white12, width: 1),
            ),
            child: Center(child: child),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isSelected ? AppColors.brandPink : Colors.white54,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Beauty slider
// ---------------------------------------------------------------------------

class _BeautySlider extends StatelessWidget {
  const _BeautySlider({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.white70),
        const SizedBox(width: 10),
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              activeTrackColor: AppColors.brandPink,
              inactiveTrackColor: Colors.white24,
              thumbColor: AppColors.brandPink,
              overlayColor: AppColors.brandPink.withValues(alpha: 0.2),
              trackHeight: 3,
            ),
            child: Slider(
              value: value,
              min: 0,
              max: 100,
              onChanged: onChanged,
            ),
          ),
        ),
        SizedBox(
          width: 32,
          child: Text(
            value.toInt().toString(),
            textAlign: TextAlign.end,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ),
      ],
    );
  }
}
