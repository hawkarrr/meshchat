import 'package:flutter/widgets.dart';

/// Icons the app needs that Material's own set does not draw the way a right-to-left
/// language wants.
abstract final class AppIcons {
  /// The "forward" arrow (Material's `shortcut`). Its neighbours, `reply` and
  /// `arrow_back`, turn around by themselves when the app is right to left; this one
  /// does not, so in Kurdish and Arabic both would point the same way. Same glyph,
  /// with the one flag that makes it turn.
  static const IconData forward = IconData(
    0xf0173,
    fontFamily: 'MaterialIcons',
    matchTextDirection: true,
  );
}
