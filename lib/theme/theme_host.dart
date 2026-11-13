import 'package:animated_theme_switcher/animated_theme_switcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_theme.dart';

/// How long the circular reveal of a new appearance takes.
const Duration kThemeRevealDuration = Duration(milliseconds: 460);

/// The circle of the reveal: it starts at the button, gathers speed and settles at the
/// corners, instead of growing at one steady pace (which looks mechanical).
class EasedCircleClipper implements ThemeSwitcherClipper {
  const EasedCircleClipper({this.curve = Curves.easeInOutCubic});

  final Curve curve;

  @override
  Path getClip(Size size, Offset offset, double sizeRate) => const ThemeSwitcherCircleClipper()
      .getClip(size, offset, curve.transform(sizeRate.clamp(0.0, 1.0)));

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper, Offset offset, double sizeRate) => true;
}

/// Puts the whole app under the three parts of the `animated_theme_switcher` package:
///
///  * **`ThemeProvider`** holds the theme that is on show and runs the reveal. It is seeded
///    with [initialTheme]; a new [seed] makes it start again from the theme the app now
///    asks for, with no reveal - that is how a change of language, or of the phone's own
///    dark mode, reaches the screen (the package has no way to set a theme without a reveal).
///  * **`ThemeSwitchingArea`** is the area the reveal covers: here, everything under the
///    app's `MaterialApp`, pages, dialogs and sheets alike.
///  * **`ThemeSwitcher`** is the button the reveal starts from (`ThemeToggleButton`, and the
///    options of the Appearance page).
///
/// Things to know about how the package behaves, and what is done about them here:
///
///  * Its area puts its child in another place of the tree while the reveal runs, and back
///    when it ends. A child without a `GlobalKey` would be built again each time and lose
///    its state. Here the child is `MaterialApp`'s Navigator, which has a `GlobalKey` of its
///    own, so Flutter moves it - with every page, the place of the bottom bar, what was typed
///    and where each list is scrolled - instead of rebuilding it. That is checked in
///    `test/ui/theme_switch_ui_test.dart`; it would stop being true of anything put into the
///    area that has no key of its own.
///  * The package cannot set a theme without a reveal. A change that must not be revealed
///    (a language, the phone's own dark mode, "remove animations") gives the provider a new
///    [seed] instead, which starts it again from the theme the app now asks for; the Navigator
///    is moved over then too.
///  * The area paints a `Material` of its own above the child, in the colour of the theme
///    around it; [_ModelTheme] makes that the theme that is on show, so a page transition
///    never uncovers a layer in the other appearance's colour.
///
/// It sits in `MaterialApp.builder`, above the Navigator.
class ThemeHost extends StatefulWidget {
  const ThemeHost({
    super.key,
    required this.initialTheme,
    required this.seed,
    required this.child,
  });

  /// The theme the provider starts from.
  final ThemeData initialTheme;

  /// Changes when the provider is to start again (a language, or a change with no reveal).
  final int seed;

  /// The app: what `MaterialApp.builder` is given.
  final Widget child;

  @override
  State<ThemeHost> createState() => _ThemeHostState();
}

class _ThemeHostState extends State<ThemeHost> {
  @override
  Widget build(BuildContext context) {
    return ThemeProvider(
      key: ValueKey<int>(widget.seed),
      initTheme: widget.initialTheme,
      duration: kThemeRevealDuration,
      child: _ModelTheme(
        child: ThemeSwitchingArea(
          child: _SystemBars(child: widget.child),
        ),
      ),
    );
  }
}

/// The theme that is on show, for what sits between the provider and the area (the area's
/// own `Material`). Rebuilt whenever the provider's model changes.
class _ModelTheme extends StatelessWidget {
  const _ModelTheme({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Theme(data: ThemeModelInheritedNotifier.of(context).theme, child: child);
}

/// The phone's status bar and navigation bar follow the appearance: light icons on the dark
/// page, dark icons on the pale one.
class _SystemBars extends StatelessWidget {
  const _SystemBars({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: systemOverlayFor(context.palette),
        child: child,
      );
}
