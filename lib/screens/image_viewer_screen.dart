import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A picture full screen: pinch to zoom, drag to pan, tap the back arrow (or
/// swipe down) to leave.
class ImageViewerScreen extends StatelessWidget {
  const ImageViewerScreen({super.key, required this.bytes, this.title = ''});

  final Uint8List bytes;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.viewerBackground,
      appBar: AppBar(
        backgroundColor: AppColors.mediaBar,
        foregroundColor: AppColors.onMedia,
        title: Text(title, style: const TextStyle(fontSize: 16)),
      ),
      extendBodyBehindAppBar: true,
      body: Center(
        child: InteractiveViewer(
          maxScale: 6,
          child: Image.memory(
            bytes,
            fit: BoxFit.contain,
            gaplessPlayback: true,
            errorBuilder: (context, error, stack) => Icon(
              Icons.broken_image_outlined,
              color: context.palette.textMuted,
              size: 64,
            ),
          ),
        ),
      ),
    );
  }
}
