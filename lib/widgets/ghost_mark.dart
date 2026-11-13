import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// What the ghost's face says.
enum GhostMood {
  /// A small smile: all is well.
  happy,

  /// Eyes closed, a tiny "o": nothing is going on here yet.
  sleepy,

  /// Eyes turned to one side, a tiny "o": looking for something.
  curious,

  /// A wobbly mouth and a drop of sweat: something did not work out.
  oops,
}

/// The app's little ghost: a soft glass ghost with a rim of light, as at home on
/// the deep-blue glass of the rest of the app as the bubble of the icon is.
/// It keeps people company where there is nothing to show yet (empty chats,
/// empty search results), and says, in a corner, that public messages fade away.
///
/// It is drawn, not an image, so it is sharp at any size and weighs nothing. At
/// small sizes the cheeks and the glint are left out. With [float] it bobs very
/// gently (about three pixels in a bit more than three seconds) - only for the
/// large ones on empty screens, and not at all when the person has asked the
/// system to reduce motion. Without a [semanticLabel] it is decoration and screen
/// readers skip it.
class GhostMark extends StatefulWidget {
  const GhostMark({
    super.key,
    this.size = 96,
    this.mood = GhostMood.happy,
    this.float = false,
    this.semanticLabel,
  });

  final double size;
  final GhostMood mood;
  final bool float;
  final String? semanticLabel;

  @override
  State<GhostMark> createState() => _GhostMarkState();
}

class _GhostMarkState extends State<GhostMark> with SingleTickerProviderStateMixin {
  late final AnimationController _bob =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 3600), value: 0.5);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(GhostMark old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final move = widget.float && !MediaQuery.disableAnimationsOf(context);
    if (move) {
      if (!_bob.isAnimating) _bob.repeat(reverse: true);
    } else {
      _bob.stop();
      _bob.value = 0.5;
    }
  }

  @override
  void dispose() {
    _bob.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final ghost = RepaintBoundary(
      child: AnimatedBuilder(
        animation: _bob,
        builder: (context, _) => CustomPaint(
          size: Size.square(widget.size),
          // -1 (lowest) .. 1 (highest), eased so it slows at both ends.
          painter: _GhostPainter(
            mood: widget.mood,
            lift: Curves.easeInOut.transform(_bob.value) * 2 - 1,
            accent: palette.accent,
            onLight: !palette.isDark,
          ),
        ),
      ),
    );
    if (widget.semanticLabel == null) return ExcludeSemantics(child: ghost);
    return Semantics(image: true, label: widget.semanticLabel, child: ghost);
  }
}

class _GhostPainter extends CustomPainter {
  _GhostPainter({
    required this.mood,
    required this.lift,
    required this.accent,
    required this.onLight,
  });

  final GhostMood mood;
  final double lift;

  /// The brand blue of the theme: the glow, and on a light page the rim.
  final Color accent;

  /// Drawn on a pale page: the glass is more solid and has a blue rim, or it would melt
  /// into the page (on the dark one it is a light shape on a dark ground).
  final bool onLight;

  static const Color _ink = Color(0xFF1B2A48);

  /// The body in a 100 x 100 box: a dome for a head, straight sides, and a hem
  /// of three soft scallops.
  static Path _body(double dy) {
    const left = 19.0, right = 81.0, top = 10.0, hem = 80.0;
    const r = (right - left) / 2;
    const w = (right - left) / 3;
    final path = Path()
      ..moveTo(left, hem + dy)
      ..lineTo(left, top + r + dy)
      ..arcTo(Rect.fromCircle(center: const Offset(50, top + r) + Offset(0, dy), radius: r),
          math.pi, math.pi, false)
      ..lineTo(right, hem + dy);
    for (var i = 0; i < 3; i++) {
      final xr = right - i * w;
      final xl = xr - w;
      path.quadraticBezierTo((xr + xl) / 2, hem + 19 + dy, xl, hem + dy);
    }
    return path..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.shortestSide / 100;
    final small = size.shortestSide < 40;
    canvas
      ..save()
      ..translate((size.width - 100 * unit) / 2, (size.height - 100 * unit) / 2)
      ..scale(unit);

    // The ghost rises and falls a few units; its shadow shrinks as it rises.
    final dy = -2.6 * lift;

    // Shadow on the "floor".
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(50, 96.5), width: 33 - 5 * lift, height: 4.6),
      Paint()
        ..color = Color(onLight ? 0x26000000 : 0x40000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.4),
    );

    final body = _body(dy);
    final bounds = Rect.fromLTRB(19, 10 + dy, 81, 90 + dy);

    // A soft glow in the accent colour, enough to lift it off the dark.
    canvas.drawPath(
      body,
      Paint()
        ..color = accent.withValues(alpha: onLight ? 0.2 : 0.30)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.5),
    );

    // The glass: near white at the top, a cool blue towards the hem. On a pale page it is
    // opaque and a little bluer, so that it reads as a shape.
    canvas.drawPath(
      body,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: onLight
              ? const [Color(0xFFFFFFFF), Color(0xFFE3F0FF), Color(0xFFB4D6FF)]
              : const [Color(0xF5F8FCFF), Color(0xE6D4EBFF), Color(0xC79CD1FF)],
          stops: const [0, 0.55, 1],
        ).createShader(bounds),
    );
    // The rim of light: white on the dark page, the brand blue on the pale one.
    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = onLight ? 1.4 : 1.1
        ..color = onLight ? accent.withValues(alpha: 0.6) : const Color(0x99FFFFFF),
    );

    if (!small) {
      // A glint on the dome, and a dot beside it.
      canvas
        ..save()
        ..translate(35.5, 23.5 + dy)
        ..rotate(-0.55)
        ..drawOval(
          Rect.fromCenter(center: Offset.zero, width: 15, height: 6.6),
          Paint()..color = const Color(0xBFFFFFFF),
        )
        ..restore();
      canvas.drawCircle(Offset(27.6, 32.4 + dy), 1.5, Paint()..color = const Color(0x99FFFFFF));
    }

    _face(canvas, dy, small);
    canvas.restore();
  }

  void _face(Canvas canvas, double dy, bool small) {
    final ink = Paint()..color = _ink;
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = small ? 2.2 : 1.7
      ..color = _ink;
    final shine = Paint()..color = const Color(0xF2FFFFFF);

    // How far the eyes look to the side, and how tall they are.
    final look = mood == GhostMood.curious ? 3.0 : 0.0;
    final ry = switch (mood) {
      GhostMood.curious => 6.2,
      GhostMood.oops => 4.8,
      _ => 5.6,
    };
    const eyeY = 44.0;

    if (!small) {
      final cheek = Paint()..color = const Color(0x6BFF8FB1);
      canvas
        ..drawOval(Rect.fromCenter(center: Offset(31.8, 53.4 + dy), width: 8.8, height: 5.2), cheek)
        ..drawOval(Rect.fromCenter(center: Offset(68.2, 53.4 + dy), width: 8.8, height: 5.2), cheek);
    }

    for (final x in const [40.5, 59.5]) {
      final cx = x + look;
      if (mood == GhostMood.sleepy) {
        // Closed eyes: a little downward curve.
        canvas.drawPath(
          Path()
            ..moveTo(cx - 4.2, eyeY - 0.6 + dy)
            ..quadraticBezierTo(cx, eyeY + 5.0 + dy, cx + 4.2, eyeY - 0.6 + dy),
          line,
        );
      } else {
        canvas.drawOval(
            Rect.fromCenter(center: Offset(cx, eyeY + dy), width: 7.8, height: ry * 2), ink);
        canvas.drawCircle(Offset(cx + 1.2, eyeY - ry * 0.38 + dy), 1.55, shine);
        if (!small) {
          canvas.drawCircle(Offset(cx - 1.1, eyeY + ry * 0.4 + dy), 0.75, shine);
        }
      }
    }

    final mouthY = 54.2 + dy;
    switch (mood) {
      case GhostMood.happy:
        canvas.drawPath(
          Path()
            ..moveTo(45.4, mouthY)
            ..quadraticBezierTo(50, mouthY + 5.4, 54.6, mouthY),
          line,
        );
      case GhostMood.sleepy:
        canvas.drawOval(Rect.fromCenter(center: Offset(50, mouthY + 2.6), width: 3.6, height: 4.2), ink);
      case GhostMood.curious:
        canvas.drawOval(
            Rect.fromCenter(center: Offset(52.4, mouthY + 2.4), width: 4.2, height: 4.8), ink);
      case GhostMood.oops:
        canvas.drawPath(
          Path()
            ..moveTo(43.6, mouthY + 2.6)
            ..cubicTo(45.4, mouthY - 0.6, 47.8, mouthY + 5.6, 50, mouthY + 2.6)
            ..cubicTo(52.2, mouthY - 0.6, 54.6, mouthY + 5.6, 56.4, mouthY + 2.6),
          line,
        );
        if (!small) {
          // A drop of sweat on the forehead.
          canvas.drawPath(
            Path()
              ..moveTo(72.5, 27.5 + dy)
              ..quadraticBezierTo(76.2, 33.2 + dy, 72.5, 35.2 + dy)
              ..quadraticBezierTo(68.8, 33.2 + dy, 72.5, 27.5 + dy),
            Paint()..color = const Color(0xCC7FC4F5),
          );
        }
    }
  }

  @override
  bool shouldRepaint(_GhostPainter old) =>
      old.mood != mood || old.lift != lift || old.accent != accent || old.onLight != onLight;
}
