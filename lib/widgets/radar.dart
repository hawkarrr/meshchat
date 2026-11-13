import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../l10n/l10n.dart';

/// Concentric rings that spread out from a dot: "listening for people nearby".
/// Holds still when the system asks for reduced motion, and when the screen is
/// covered by another one.
class RadarPulse extends StatefulWidget {
  const RadarPulse({super.key, this.size = 76, this.color});

  final double size;

  /// The colour of the rings; the soft blue of the theme unless given.
  final Color? color;

  @override
  State<RadarPulse> createState() => _RadarPulseState();
}

class _RadarPulseState extends State<RadarPulse> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller
        ..stop()
        ..value = 0.35;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: context.l10n.radarListening,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => CustomPaint(
            size: Size.square(widget.size),
            painter: _RadarPainter(_controller.value, widget.color ?? context.palette.accentSoft),
          ),
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter(this.t, this.color);

  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxRadius = size.width / 2;
    for (var i = 0; i < 3; i++) {
      final phase = (t + i / 3) % 1;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = color.withValues(alpha: (1 - phase) * 0.55);
      canvas.drawCircle(center, maxRadius * (0.22 + 0.78 * phase), paint);
    }
    canvas.drawCircle(center, 4.5, Paint()..color = color);
    canvas.drawCircle(
      center,
      9,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = color.withValues(alpha: 0.6),
    );
  }

  @override
  bool shouldRepaint(_RadarPainter old) => old.t != t || old.color != color;
}
