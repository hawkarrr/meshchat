import 'package:flutter/widgets.dart';

/// How things move in the app.
///
/// A few rules, so that everything feels like one hand made it:
///  * What appears starts fast and settles ([out]); it never starts slowly.
///  * What goes away goes faster than it came ([exit] is shorter than [enter]).
///  * Nothing that people do all day long (switching places, typing, scrolling) is
///    animated beyond a short press; what is animated is what happens a few times a
///    day: a banner above the text field, a pinned message, the first page of a chat.
///  * A person who asked the system to reduce motion gets no movement at all: every
///    duration here goes through [of], which turns it into zero.
abstract final class AppMotion {
  /// A strong ease-out: the first half of the way is nearly all of it.
  static const Curve out = Cubic(0.23, 1, 0.32, 1);

  /// For something that moves from one place on the screen to another.
  static const Curve inOut = Cubic(0.77, 0, 0.175, 1);

  /// The feedback of a press or a tick: it has to feel instant.
  static const Duration press = Duration(milliseconds: 120);

  /// Something coming in: a banner, a card.
  static const Duration enter = Duration(milliseconds: 220);

  /// The same thing going out, which is quicker.
  static const Duration exit = Duration(milliseconds: 140);

  /// [d], or zero when the system asks for less motion.
  static Duration of(BuildContext context, Duration d) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false ? Duration.zero : d;
}
