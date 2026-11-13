import 'package:flutter/widgets.dart';

/// The smallest size a thumb is asked to hit: 44 x 44 points.
const double kMinTouch = 44;

/// Makes what is inside at least [kMinTouch] high (and wide, unless [minWidth] is
/// given), with the content in the middle and looking the way it did. For tappable
/// text and small icons, whose own size is a few points less than a finger needs.
class MinTouch extends StatelessWidget {
  const MinTouch({super.key, required this.child, this.minWidth = kMinTouch});

  final Widget child;
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: minWidth, minHeight: kMinTouch),
      child: Center(widthFactor: 1, heightFactor: 1, child: child),
    );
  }
}
