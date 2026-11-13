import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

/// How long opening and closing a page takes on Android.
///
/// Flutter's default there is Material 3's "fade forwards", which takes 450 ms - the
/// slowest thing in everyday use, since every screen opens and closes through it. The app
/// moves things quickly elsewhere (a banner comes in in 220 ms, see `AppMotion`), so pages
/// take 300 ms: still a clear slide and fade, but the next screen is there sooner.
const Duration kPageTransitionDuration = Duration(milliseconds: 300);

/// Android's page transition, the platform's own (Material 3's fade-forwards, with the
/// predictive-back peek where the phone and the app opt in), only quicker. The motion itself
/// is Flutter's: every curve is a share of the transition's length, so it simply plays faster.
class AppPageTransitionsBuilder extends PredictiveBackPageTransitionsBuilder {
  const AppPageTransitionsBuilder();

  @override
  Duration get transitionDuration => kPageTransitionDuration;

  @override
  Duration get reverseTransitionDuration => kPageTransitionDuration;
}

/// The transitions of the app: its own on Android, the native slide (with the swipe back
/// gesture) on iPhone, which is left as it is.
const PageTransitionsTheme appPageTransitions = PageTransitionsTheme(
  builders: <TargetPlatform, PageTransitionsBuilder>{
    TargetPlatform.android: AppPageTransitionsBuilder(),
    TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
    TargetPlatform.windows: ZoomPageTransitionsBuilder(),
    TargetPlatform.linux: ZoomPageTransitionsBuilder(),
  },
);
