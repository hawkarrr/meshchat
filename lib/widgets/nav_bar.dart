import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../theme/app_theme.dart';
import '../l10n/l10n.dart';

/// One place of the app the bottom bar can take you to.
class NavDestination {
  const NavDestination({
    required this.id,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    this.badge = 0,
  });

  /// Used for the item's key (`nav-<id>`).
  final String id;
  final String label;

  /// Outlined while the destination is not the current one, filled when it is.
  final IconData icon;
  final IconData selectedIcon;

  /// An unread count shown on the icon; nothing is shown for zero.
  final int badge;
}

/// The bottom bar of the home screen: a rounded charcoal pill that floats above the
/// page, with one icon and one word per place and a soft blue pill behind the
/// current one.
///
/// How it behaves, and why:
///  * It answers the touch at once. The item shrinks the moment a finger is on
///    it (before the tap is finished), so the bar feels like it is listening.
///  * Switching place is a thing people do all day, so the page itself changes
///    at once. Only the highlight moves, on a critically damped spring: no
///    bounce, a third of a second, and it starts from wherever it is and
///    whatever speed it has, so tapping another item mid-move never jumps.
///  * The colour of each icon and word, and the size of each icon, follow the
///    highlight (they are worked out from its position), so they never disagree
///    with it. Every item is the same size whether it is chosen or not: nothing
///    shifts when the choice changes.
///  * The first place sits at the start of the bar: at the right in Kurdish and
///    Arabic, at the left in English. The highlight knows which.
///  * With "remove animations" switched on the highlight jumps; with high
///    contrast switched on the bar gets an outline.
///  * It floats clear of the phone's own bottom bar (it keeps to the safe area),
///    and when the keyboard is up the screen leaves it underneath.
class AppNavBar extends StatefulWidget {
  const AppNavBar({
    super.key,
    required this.destinations,
    required this.index,
    required this.onChanged,
  });

  final List<NavDestination> destinations;
  final int index;
  final ValueChanged<int> onChanged;

  /// Height of the row of items.
  static const double height = 64;

  /// The space around the pill: the bar's own height plus this is what the page
  /// above it leaves free.
  static const EdgeInsets margin = EdgeInsets.fromLTRB(AppSpace.l, 4, AppSpace.l, AppSpace.m);

  @override
  State<AppNavBar> createState() => _AppNavBarState();
}

class _AppNavBarState extends State<AppNavBar> with SingleTickerProviderStateMixin {
  static const double _pillInset = 4;
  static const double _pillHeight = AppNavBar.height - 2 * _pillInset;

  /// Critically damped (no overshoot), settling in about a third of a second.
  static final SpringDescription _spring =
      SpringDescription.withDampingRatio(mass: 1, stiffness: 380, ratio: 1);

  late final AnimationController _position =
      AnimationController.unbounded(vsync: this, value: widget.index.toDouble());

  int? _pressed;

  @override
  void didUpdateWidget(AppNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) _moveTo(widget.index);
  }

  @override
  void dispose() {
    _position.dispose();
    super.dispose();
  }

  void _moveTo(int index) {
    if (MediaQuery.disableAnimationsOf(context)) {
      _position.value = index.toDouble();
      return;
    }
    _position.animateWith(
      SpringSimulation(_spring, _position.value, index.toDouble(), _position.velocity),
    );
  }

  void _press(int? index) {
    if (_pressed != index) setState(() => _pressed = index);
  }

  @override
  Widget build(BuildContext context) {
    final highContrast = MediaQuery.highContrastOf(context);
    final count = widget.destinations.length;
    // Words under the icons stay small however large the system text is.
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.2,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: AppNavBar.margin,
          // Scaffold gives a bottom bar all the height there is; heightFactor makes
          // the bar only as tall as its row of items.
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: context.palette.surface,
                  borderRadius: BorderRadius.circular(AppNavBar.height / 2),
                  border: Border.all(color: highContrast ? context.palette.outline : context.palette.divider),
                  boxShadow: [
                    BoxShadow(color: context.palette.shadow, blurRadius: 18, offset: Offset(0, 6)),
                  ],
                ),
                child: SizedBox(
                  key: const Key('nav-bar-items'),
                  height: AppNavBar.height,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final cell = constraints.maxWidth / count;
                      final rtl = Directionality.of(context) == TextDirection.rtl;
                      return Stack(
                        children: [
                          RepaintBoundary(
                            child: AnimatedBuilder(
                              animation: _position,
                              builder: (context, _) {
                                final fromStart = cell * _position.value + _pillInset;
                                // A child of a Stack starts at the start edge (the right in
                                // Kurdish and Arabic); the offset is measured from there.
                                return Transform.translate(
                                  offset: Offset(rtl ? -fromStart : fromStart, _pillInset),
                                  child: _Pill(width: cell - 2 * _pillInset),
                                );
                              },
                            ),
                          ),
                          Row(
                            children: [
                              for (var i = 0; i < count; i++)
                                Expanded(
                                  child: _NavItem(
                                    key: Key('nav-${widget.destinations[i].id}'),
                                    destination: widget.destinations[i],
                                    index: i,
                                    position: _position,
                                    selected: i == widget.index,
                                    pressed: _pressed == i,
                                    onDown: () => _press(i),
                                    onRelease: () => _press(null),
                                    onTap: () => widget.onChanged(i),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The highlight behind the current item: a soft blue pill.
class _Pill extends StatelessWidget {
  const _Pill({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: _AppNavBarState._pillHeight,
      decoration: BoxDecoration(
        color: context.palette.accent.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(_AppNavBarState._pillHeight / 2),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    super.key,
    required this.destination,
    required this.index,
    required this.position,
    required this.selected,
    required this.pressed,
    required this.onDown,
    required this.onRelease,
    required this.onTap,
  });

  final NavDestination destination;
  final int index;
  final Animation<double> position;
  final bool selected;
  final bool pressed;
  final VoidCallback onDown;
  final VoidCallback onRelease;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final badge = destination.badge;
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: badge > 0 ? context.l10n.navUnreadLabel(destination.label, badge) : destination.label,
      onTap: onTap,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => onDown(),
          onTapUp: (_) => onRelease(),
          onTapCancel: onRelease,
          onTap: onTap,
          child: AnimatedScale(
            scale: pressed ? 0.94 : 1,
            // Quick on the way in, a little slower to let go.
            duration: Duration(milliseconds: pressed ? 90 : 160),
            curve: const Cubic(0.23, 1, 0.32, 1),
            child: Center(
              child: AnimatedBuilder(
                animation: position,
                builder: (context, _) {
                  // 1 when the highlight is exactly here, 0 when it is a whole item away.
                  final here = (1 - (position.value - index).abs()).clamp(0.0, 1.0);
                  // The icon is the brand blue; the word, small text on the blue pill, the
                  // lighter one - it keeps 4.5 : 1 against the pill.
                  final color = Color.lerp(context.palette.textMuted, context.palette.accent, here)!;
                  final wordColor = Color.lerp(context.palette.textMuted, context.palette.accentSoft, here)!;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 40,
                        height: 28,
                        child: Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.center,
                          children: [
                            Transform.scale(
                              scale: 1 + 0.1 * here,
                              child: Icon(
                                here > 0.5 ? destination.selectedIcon : destination.icon,
                                size: AppSizes.icon,
                                color: color,
                              ),
                            ),
                            if (badge > 0)
                              PositionedDirectional(top: -3, end: -2, child: _Badge(count: badge)),
                          ],
                        ),
                      ),
                      Text(
                        destination.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 15 / 11.5,
                          fontWeight: FontWeight.w600,
                          color: wordColor,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      padding: const EdgeInsets.symmetric(horizontal: 4.5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: context.palette.accentFill,
        borderRadius: BorderRadius.circular(9),
        // A ring in the bar's own colour keeps the badge apart from the icon.
        border: Border.all(color: context.palette.surface, width: 1.5),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        maxLines: 1,
        style: TextStyle(
          color: context.palette.onAccent,
          fontSize: 10.5,
          height: 1.1,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
