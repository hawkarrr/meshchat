import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/app_theme.dart';

/// Makes the placeholders inside it breathe together while something loads. With
/// "remove animations" switched on they hold still.
class SkeletonPulse extends StatefulWidget {
  const SkeletonPulse({super.key, required this.child});

  final Widget child;

  @override
  State<SkeletonPulse> createState() => _SkeletonPulseState();
}

class _SkeletonPulseState extends State<SkeletonPulse> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller
        ..stop()
        ..value = 0;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 1, end: 0.55)
          .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
      child: widget.child,
    );
  }
}

/// One grey shape of a placeholder.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.width, this.height = 12, this.radius = 6, this.circle = false});

  final double? width;
  final double height;
  final double radius;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: circle ? height : width,
      height: height,
      decoration: BoxDecoration(
        color: context.palette.surfaceHigh,
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(radius),
      ),
    );
  }
}

/// What a conversation shows while its messages are being read: a few grey bubbles,
/// the way they will sit.
///
/// The newest sit at the bottom, as in the chat. When there is not room for all of them
/// (a small phone, large text) the oldest are cut off at the top instead of overflowing.
class ChatSkeleton extends StatelessWidget {
  const ChatSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    Widget bubble(double width, double height, {required bool mine}) => Align(
          alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.m, vertical: 4),
            child: SkeletonBox(width: width, height: height, radius: 18),
          ),
        );
    return Semantics(
      label: context.l10n.commonLoading,
      child: ExcludeSemantics(
        child: SkeletonPulse(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              return ClipRect(
                child: OverflowBox(
                  alignment: Alignment.bottomCenter,
                  minHeight: 0,
                  maxHeight: double.infinity,
                  child: Column(
                    key: const Key('chat-skeleton'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      bubble(w * 0.55, 54, mine: false),
                      bubble(w * 0.42, 40, mine: true),
                      bubble(w * 0.68, 72, mine: false),
                      bubble(w * 0.34, 40, mine: true),
                      bubble(w * 0.5, 54, mine: false),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// What a list of conversations shows while it is being read: rows of a round picture
/// and two lines. Rows that do not fit are cut off at the bottom.
class ListSkeleton extends StatelessWidget {
  const ListSkeleton({super.key, this.rows = 6});

  final int rows;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: context.l10n.commonLoading,
      child: ExcludeSemantics(
        child: SkeletonPulse(
          child: ClipRect(
            child: OverflowBox(
              alignment: Alignment.topCenter,
              minHeight: 0,
              maxHeight: double.infinity,
              child: Column(
                key: const Key('list-skeleton'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < rows; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpace.l, vertical: 10),
                      child: Row(
                        children: [
                          const SkeletonBox(height: AppSizes.avatarList, circle: true),
                          const SizedBox(width: AppSpace.m),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SkeletonBox(width: 120.0 + (i % 3) * 40, height: 14),
                                const SizedBox(height: 8),
                                SkeletonBox(width: 180.0 + (i % 2) * 50, height: 12),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
