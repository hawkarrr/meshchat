import 'package:flutter/material.dart';

import '../theme/motion.dart';

/// Shows [child] while [show] is true and nothing otherwise, and moves between the
/// two: the space opens (or closes) and the content fades, quickly in and quicker
/// out. Used for what appears above or below the conversation now and then - the
/// reply bar over the text field, the pinned message, the note about deletions -
/// so that the rest of the screen does not jump when it comes or goes.
///
/// With "remove animations" switched on the change is immediate.
///
/// When [show] changes from one child to another (a different [child] key), the
/// new one replaces the old by fading, without the space closing in between.
class Reveal extends StatelessWidget {
  const Reveal({super.key, required this.show, required this.child});

  final bool show;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final enter = AppMotion.of(context, AppMotion.enter);
    final exit = AppMotion.of(context, AppMotion.exit);
    // No movement asked for: no animation widgets at all, so nothing waits to be removed.
    if (enter == Duration.zero) return show ? child : const SizedBox.shrink();
    return AnimatedSize(
      duration: enter,
      reverseDuration: exit,
      curve: AppMotion.out,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: enter,
        reverseDuration: exit,
        switchInCurve: AppMotion.out,
        switchOutCurve: Curves.easeOut,
        transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.topCenter,
          // The one leaving is painted outside the (already empty) stack; the
          // size animation around it is what cuts it off, as the space closes.
          clipBehavior: Clip.none,
          children: [
            // The one leaving stays where it was; only the new one gives the size.
            for (final p in previous) Positioned(top: 0, left: 0, right: 0, child: p),
            ?current,
          ],
        ),
        child: show ? child : const SizedBox.shrink(key: ValueKey<String>('reveal-nothing')),
      ),
    );
  }
}
