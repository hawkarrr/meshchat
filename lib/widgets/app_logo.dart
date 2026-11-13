import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The Damatqe mark: the glass bubble of the app icon. Falls back to a
/// drawn bubble if the image cannot be loaded (for example in tests that do not
/// bundle assets).
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 72});

  final double size;

  static const String asset = 'assets/branding/logo.png';

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.24),
      child: Image.asset(
        asset,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) => _Fallback(size: size),
      ),
    );
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [context.palette.surfaceHigh, context.palette.backgroundDeep],
        ),
        border: Border.all(color: context.palette.outline),
      ),
      child: Icon(Icons.chat_bubble_rounded, color: context.palette.accentSoft, size: size * 0.5),
    );
  }
}
