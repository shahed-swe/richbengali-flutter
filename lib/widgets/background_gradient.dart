import 'package:flutter/material.dart';
import '../theme/theme.dart';

/// Decorative background matching BackgroundGradient.tsx.
/// White base with top-right pink tint and bottom-left purple tint.
class BackgroundGradient extends StatelessWidget {
  const BackgroundGradient({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // White base
        const ColoredBox(color: AppColors.white),
        // Top-right pink (80% w, 50% h)
        Align(
          alignment: Alignment.topRight,
          child: FractionallySizedBox(
            widthFactor: 0.8,
            heightFactor: 0.5,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0x1Fe91d7c), Color(0x00e91d7c)],
                  begin: Alignment.topRight,
                  end: Alignment.centerLeft,
                ),
              ),
            ),
          ),
        ),
        // Bottom-left purple (80% w, 50% h)
        Align(
          alignment: Alignment.bottomLeft,
          child: FractionallySizedBox(
            widthFactor: 0.8,
            heightFactor: 0.5,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0x14402e91), Color(0x00402e91)],
                  begin: Alignment.bottomLeft,
                  end: Alignment.center,
                ),
              ),
            ),
          ),
        ),
        // Content
        child,
      ],
    );
  }
}
