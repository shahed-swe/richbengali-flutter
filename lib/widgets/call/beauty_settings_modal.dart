import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../services/call_service.dart';
import '../../state/call_overlay_provider.dart';
import '../../theme/theme.dart';

/// Mirrors BeautySettingsModal.tsx â€” bottom-sheet with 4 sliders controlling
/// beauty effects: Smoothness, Background Blur, Slim Face, Big Eyes.
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
            icon: LucideIcons.layers,
            label: 'Background Blur',
            value: overlay.beautyBlurDegree,
            onChanged: (v) {
              notifier.setBeautyBlurDegree(v);
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

