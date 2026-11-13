import 'dart:async';

import 'package:animated_theme_switcher/animated_theme_switcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_scope.dart';
import '../l10n/l10n.dart';
import '../theme/app_theme.dart';
import '../theme/motion.dart';
import '../theme/theme_host.dart';

/// Changes the appearance to [mode], with the circular reveal that starts at [switcher]'s
/// button, and remembers the choice.
///
/// What it does not animate, it still does: if [mode] looks like what is on show (System, on
/// a phone that is already in that appearance) only the choice is kept; if the phone is
/// asked for less motion, or there is nothing to reveal from, the appearance changes at once.
/// A tap during a reveal that is still running is ignored, so the choice and the screen
/// can never disagree.
Future<void> switchThemeMode(
  BuildContext context,
  ThemeSwitcherState switcher,
  ThemeMode mode,
) async {
  final app = AppScope.read(context);
  final themes = app.theme;
  final shown = Theme.of(context).brightness;
  final target = themes.brightnessFor(MediaQuery.platformBrightnessOf(context), mode);

  if (target == shown) {
    await themes.setMode(mode);
    return;
  }
  final model = context.dependOnInheritedWidgetOfExactType<ThemeModelInheritedNotifier>()?.notifier;
  if (model == null || MediaQuery.disableAnimationsOf(context)) {
    await themes.setMode(mode, silent: true);
    return;
  }
  if (model.controller.isAnimating) return;

  unawaited(HapticFeedback.selectionClick());
  // The reveal takes its picture of the screen as it is now, so it goes first; the choice is
  // recorded right after.
  switcher.changeTheme(theme: buildAppTheme(language: app.language, brightness: target));
  await themes.setMode(mode);
}

/// The sun / moon button: one tap switches between the light and the dark appearance, with
/// the new one spreading out from the button in a circle, as in Telegram.
///
/// It shows what a tap will give: the sun while the page is dark, the moon while it is
/// pale. It is a [ThemeSwitcher] of its own, so it works on any screen under the app:
///
/// ```dart
/// actions: const [ThemeToggleButton()],
/// ```
///
/// The person's choice becomes Light or Dark; "System default" is on the Appearance page.
class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key, this.size = AppSizes.tap});

  /// The side of the touch target; never less than 44.
  final double size;

  @override
  Widget build(BuildContext context) {
    return ThemeSwitcher.switcher(
      clipper: const EasedCircleClipper(),
      builder: (context, switcher) {
        final dark = Theme.of(context).brightness == Brightness.dark;
        final l = context.l10n;
        final tooltip = dark ? l.themeSwitchToLight : l.themeSwitchToDark;
        final side = size < AppSizes.tap ? AppSizes.tap : size;
        return Tooltip(
          message: tooltip,
          child: Semantics(
            button: true,
            label: tooltip,
            excludeSemantics: true,
            child: Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              child: InkWell(
                key: const Key('theme-toggle'),
                customBorder: const CircleBorder(),
                onTap: () =>
                    switchThemeMode(context, switcher, dark ? ThemeMode.light : ThemeMode.dark),
                child: SizedBox(
                  width: side,
                  height: side,
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: AppMotion.of(context, AppMotion.enter),
                      switchInCurve: AppMotion.out,
                      switchOutCurve: Curves.easeIn,
                      transitionBuilder: (child, animation) => RotationTransition(
                        turns: Tween<double>(begin: 0.25, end: 0).animate(animation),
                        child: ScaleTransition(
                          scale: animation,
                          child: FadeTransition(opacity: animation, child: child),
                        ),
                      ),
                      child: Icon(
                        dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                        key: ValueKey<bool>(dark),
                        size: AppSizes.icon,
                        color: context.palette.text,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
