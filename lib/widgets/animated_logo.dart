import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Animated brand logo matching AnimatedLogo.tsx.
/// Pulses scale 1→1.1 and opacity 0.6→1 on an 800ms loop.
class AnimatedLogo extends StatefulWidget {
  const AnimatedLogo({super.key, this.size = 100});

  final double size;

  @override
  State<AnimatedLogo> createState() => _AnimatedLogoState();
}

class _AnimatedLogoState extends State<AnimatedLogo>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _scale = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _opacity = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // SVG viewBox is 437.23 x 231.56 — maintain aspect ratio
    final logoWidth  = widget.size;
    final logoHeight = widget.size * (231.56 / 437.23);

    return SizedBox(
      width: logoWidth,
      height: logoHeight,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => Opacity(
          opacity: _opacity.value,
          child: Transform.scale(
            scale: _scale.value,
            child: child,
          ),
        ),
        child: SvgPicture.asset(
          'assets/logo.svg',
          width: logoWidth,
          height: logoHeight,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
