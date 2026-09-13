import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../models/message.dart';
import '../image_viewer.dart';

/// A photo message in the thread. Shows the picked file straight off disk
/// while the upload is in flight, then the S3 image once it lands; tapping a
/// delivered photo opens it full screen.
class ChatImage extends StatelessWidget {
  const ChatImage({super.key, required this.message});

  final Message message;

  static const double _width = 220;
  static const double _height = 260;

  void _openFullScreen(BuildContext context) {
    final url = message.attachmentUrl;
    if (url == null || message.isLocalAttachment) return;
    showDialog<void>(
      context: context,
      barrierColor: Colors.transparent,
      builder: (ctx) => ImageViewer(
        imageUrl: url,
        isVisible: true,
        onClose: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final url = message.attachmentUrl;
    if (url == null) return const SizedBox.shrink();

    final uploading = message.isLocalAttachment;

    return GestureDetector(
      onTap: () => _openFullScreen(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: _width,
          height: _height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (uploading)
                Image.file(File(url), fit: BoxFit.cover)
              else
                CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => const ColoredBox(
                    color: Color(0xFFE2E8F0),
                    child: Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
                  errorWidget: (_, _, _) => const ColoredBox(
                    color: Color(0xFFE2E8F0),
                    child: Center(
                      child: Icon(LucideIcons.imageOff,
                          size: 28, color: Color(0xFF94A3B8)),
                    ),
                  ),
                ),

              // Dim + spinner until the upload finishes.
              if (uploading)
                const ColoredBox(
                  color: Color(0x66000000),
                  child: Center(
                    child: SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
