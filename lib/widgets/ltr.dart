import 'package:flutter/widgets.dart';

/// Keeps what is inside reading left to right, in any language of the app.
///
/// Identifiers, fingerprints, versions and file sizes are written with Latin
/// letters and digits; inside a right-to-left screen their punctuation ("#", ".",
/// "/") would jump to the wrong end of the text.
class Ltr extends StatelessWidget {
  const Ltr({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Directionality(textDirection: TextDirection.ltr, child: child);
}
