import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class ImageViewer extends StatelessWidget {
  const ImageViewer({
    super.key,
    required this.imageUrl,
    required this.isVisible,
    required this.onClose,
  });

  final String? imageUrl;
  final bool isVisible;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || !isVisible) return const SizedBox.shrink();

    final size = MediaQuery.of(context).size;

    return Dialog.fullscreen(
      backgroundColor: Colors.transparent,
      child: Stack(
        children: [
          // Blurred dark backdrop
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(color: const Color(0xE6000000)),
            ),
          ),

          // Tappable image area
          GestureDetector(
            onTap: onClose,
            child: Center(
              child: CachedNetworkImage(
                imageUrl: imageUrl!,
                width: size.width,
                height: size.height * 0.8,
                fit: BoxFit.contain,
              ),
            ),
          ),

          // Close button (top right)
          Positioned(
            top: 50,
            right: 20,
            child: GestureDetector(
              onTap: onClose,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(LucideIcons.x, size: 24, color: Colors.black),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
