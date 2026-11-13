import 'package:animated_theme_switcher/animated_theme_switcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_mesh_chat/l10n/l10n.dart';
import 'package:offline_mesh_chat/screens/appearance_page.dart';
import 'package:offline_mesh_chat/theme/app_theme.dart';
import 'package:offline_mesh_chat/theme/theme_controller.dart';
import 'package:offline_mesh_chat/theme/theme_host.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/ui_harness.dart';

/// The light / dark switch, from the button to the screen: the circular reveal, the choice
/// kept, the phone's own setting followed - and that none of it costs the person anything
/// they had on screen.
///
/// The reveal takes a picture of the screen, which is real asynchronous work (the engine
/// draws it); a test gives it real time with `runAsync` and then moves the fake clock.
const Key _firstChild = ValueKey<String>('ThemeSwitchingAreaFirstChild');

Brightness _shown(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(Scaffold).first)).brightness;

bool _revealing(WidgetTester tester) =>
    ThemeModelInheritedNotifier.of(tester.element(find.byType(Scaffold).first))
        .controller
        .isAnimating;

/// The status bar's icons, as the whole app asks for them.
Brightness? _statusBarIcons(WidgetTester tester) => tester
    .widget<AnnotatedRegion<SystemUiOverlayStyle>>(find.byWidgetPredicate(
        (w) => w is AnnotatedRegion<SystemUiOverlayStyle> && w.value.systemNavigationBarColor != null))
    .value
    .statusBarIconBrightness;

Future<void> _letThePictureBeTaken(WidgetTester tester) =>
    tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));

/// Waits for a reveal that was started to finish.
Future<void> _untilRevealed(UiHarness h, WidgetTester tester) async {
  await h.until(() => _shown(tester) == Brightness.light || _shown(tester) == Brightness.dark);
  await h.until(() => !_revealing(tester) && find.byKey(_firstChild).evaluate().isEmpty,
      reason: 'the reveal should finish');
}

Future<ThemeController> _themes(WidgetTester tester, ThemeMode mode) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = (await tester.runAsync(SharedPreferences.getInstance))!;
  return ThemeController(mode: mode, preferences: prefs);
}

void main() {
  group('the button', () {
    testWidgets('spreads the new look out from the button, and keeps the choice', (tester) async {
      final themes = await _themes(tester, ThemeMode.dark);
      final h = UiHarness(tester)..screen();
      final alice = await h.node('Alice', onboarded: true, nickname: 'Alice', theme: themes);
      await h.show(alice, landing: true);
      await h.openTab('settings');

      expect(_shown(tester), Brightness.dark);
      expect(_statusBarIcons(tester), Brightness.light, reason: 'light icons on the dark page');
      expect(find.byIcon(Icons.light_mode_rounded), findsOneWidget, reason: 'a tap gives the light one');
      expect(find.byKey(_firstChild), findsNothing, reason: 'nothing is being revealed yet');
      expect(tester.getSize(find.byKey(const Key('theme-toggle'))).shortestSide, greaterThanOrEqualTo(44));

      await tester.tap(find.byKey(const Key('theme-toggle')));
      await _letThePictureBeTaken(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      // Half way: the picture of the old screen, and the live page in the new theme inside the circle.
      expect(find.byKey(_firstChild), findsOneWidget, reason: 'the old picture lies under the circle');
      expect(_shown(tester), Brightness.light, reason: 'the page that grows is already the new one');
      expect(_revealing(tester), isTrue);

      await tester.pump(kThemeRevealDuration);
      await tester.pump();
      expect(find.byKey(_firstChild), findsNothing, reason: 'the picture is gone at the end');
      expect(_revealing(tester), isFalse);
      expect(_shown(tester), Brightness.light);
      expect(_statusBarIcons(tester), Brightness.dark, reason: 'dark icons on the pale page');
      expect(find.byIcon(Icons.dark_mode_rounded), findsOneWidget, reason: 'now a tap gives the dark one');
      // What lies under the pages (the area's own Material) is in the theme on show too, not in
      // the one the app started with.
      expect(Theme.of(tester.element(find.byType(ThemeSwitchingArea))).brightness, Brightness.light);

      expect(themes.mode, ThemeMode.light);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(ThemeController.preferenceKey), 'light');
      expect(tester.takeException(), isNull);
      await h.dispose();
    });

    testWidgets('works in both directions, as often as it is pressed', (tester) async {
      final themes = await _themes(tester, ThemeMode.dark);
      final h = UiHarness(tester)..screen();
      final alice = await h.node('Alice', onboarded: true, nickname: 'Alice', theme: themes);
      await h.show(alice, landing: true);
      await h.openTab('settings');

      for (final expected in [Brightness.light, Brightness.dark, Brightness.light]) {
        await h.tap(find.byKey(const Key('theme-toggle')));
        await _untilRevealed(h, tester);
        expect(_shown(tester), expected);
        expect(themes.mode, expected == Brightness.light ? ThemeMode.light : ThemeMode.dark);
      }
      expect(tester.takeException(), isNull);
      await h.dispose();
    });

    testWidgets('a second press while the circle is still growing is ignored', (tester) async {
      final themes = await _themes(tester, ThemeMode.dark);
      final h = UiHarness(tester)..screen();
      final alice = await h.node('Alice', onboarded: true, nickname: 'Alice', theme: themes);
      await h.show(alice, landing: true);
      await h.openTab('settings');

      await tester.tap(find.byKey(const Key('theme-toggle')));
      await _letThePictureBeTaken(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(_revealing(tester), isTrue);
      await tester.tap(find.byKey(const Key('theme-toggle')), warnIfMissed: false);
      await tester.pump(kThemeRevealDuration);
      await _untilRevealed(h, tester);
      expect(_shown(tester), Brightness.light, reason: 'the second press did not turn it back');
      expect(themes.mode, ThemeMode.light, reason: 'and the choice agrees with the screen');
      await h.dispose();
    });

    testWidgets('is on the first-run page too', (tester) async {
      final h = UiHarness(tester)..screen();
      final alice = await h.node('Alice');
      await h.show(alice, landing: true);
      expect(find.byKey(const Key('onboarding-start')), findsOneWidget);
      expect(find.byKey(const Key('theme-toggle')), findsOneWidget);
      await h.dispose();
    });

    testWidgets('with "remove animations" the new look is simply there', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      final themes = await _themes(tester, ThemeMode.dark);
      final h = UiHarness(tester)..screen();
      final alice = await h.node('Alice', onboarded: true, nickname: 'Alice', theme: themes);
      await h.show(alice, landing: true);
      await h.openTab('settings');

      await tester.tap(find.byKey(const Key('theme-toggle')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(_shown(tester), Brightness.light);
      expect(find.byKey(_firstChild), findsNothing, reason: 'no circle, no picture');
      expect(themes.mode, ThemeMode.light);
      expect(themes.silentChanges, 1);
      await h.dispose();
    });
  });

  group('what the person had on screen is still there', () {
    testWidgets('the place of the bar, a draft in the room and a page that was opened', (tester) async {
      final themes = await _themes(tester, ThemeMode.dark);
      final h = UiHarness(tester)..screen();
      final alice = await h.node('Alice', onboarded: true, nickname: 'Alice', theme: themes);
      await h.show(alice, landing: true);

      // A draft, typed in the public room.
      await tester.enterText(find.byKey(const Key('composer-field')), 'a draft I am still writing');
      await tester.pump();
      // A page opened over the menu.
      await h.openSettingsPage('appearance');
      expect(find.byType(AppearancePage), findsOneWidget);

      await h.tap(find.byKey(const Key('appearance-light')));
      await _untilRevealed(h, tester);
      expect(_shown(tester), Brightness.light);

      // The page is still the one on top: the Navigator was not thrown away.
      expect(find.byType(AppearancePage), findsOneWidget);
      await tester.pageBack();
      await h.settle();
      expect(find.byKey(const Key('settings-profile')), findsOneWidget, reason: 'back on the menu, not at the start');
      // And the draft is where it was left.
      await h.openTab('public');
      expect(find.text('a draft I am still writing'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await h.dispose();
    });

    testWidgets('a page keeps its own state through a reveal and through a silent restart of the provider',
        (tester) async {
      Widget app(int seed) => MaterialApp(
            theme: buildAppTheme(),
            builder: (context, child) =>
                ThemeHost(initialTheme: buildAppTheme(), seed: seed, child: child!),
            home: Scaffold(
              body: Column(children: [
                const _Witness(),
                ThemeSwitcher.switcher(
                  builder: (context, switcher) => TextButton(
                    key: const Key('go'),
                    onPressed: () => switcher.changeTheme(
                        theme: buildAppTheme(brightness: Brightness.light)),
                    child: const Text('go'),
                  ),
                ),
              ]),
            ),
          );

      _Witness.created = 0;
      await tester.pumpWidget(app(0));
      await tester.tap(find.byKey(const Key('witness')));
      await tester.pump();
      expect(find.text('taps 1'), findsOneWidget);

      // A new seed starts the provider again (a language, the phone going dark): no reveal.
      await tester.pumpWidget(app(1));
      await tester.pump();
      expect(find.text('taps 1'), findsOneWidget, reason: 'the page was moved, not built again');

      // And the reveal.
      await tester.tap(find.byKey(const Key('go')));
      await _letThePictureBeTaken(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.byKey(_firstChild), findsOneWidget, reason: 'the circle is growing');
      expect(find.text('taps 1'), findsOneWidget, reason: 'the page is the live one, not a picture');
      await tester.pump(kThemeRevealDuration);
      await tester.pump();
      expect(find.byKey(_firstChild), findsNothing);
      expect(find.text('taps 1'), findsOneWidget);
      expect(_Witness.created, 1, reason: 'one state, made once');
      expect(Theme.of(tester.element(find.byType(Scaffold).first)).brightness, Brightness.light);
    });
  });

  group('the Appearance page', () {
    testWidgets('has the three choices, ticks the chosen one, and each choice works', (tester) async {
      final themes = await _themes(tester, ThemeMode.dark);
      final h = UiHarness(tester)..screen();
      final alice = await h.node('Alice', onboarded: true, nickname: 'Alice', theme: themes);
      await h.show(alice);
      await h.openTab('settings');
      expect(
          find.descendant(of: find.byKey(const Key('settings-appearance')), matching: find.text('Dark')),
          findsOneWidget,
          reason: 'the menu says what is chosen');
      await h.tap(find.byKey(const Key('settings-appearance')));

      bool ticked(String mode) => find
          .descendant(of: find.byKey(Key('appearance-$mode')), matching: find.byKey(const Key('appearance-selected')))
          .evaluate()
          .isNotEmpty;
      for (final mode in ['system', 'light', 'dark']) {
        expect(find.byKey(Key('appearance-$mode')), findsOneWidget, reason: mode);
      }
      expect(find.text('System default'), findsOneWidget);
      expect(ticked('dark'), isTrue);
      expect(ticked('light'), isFalse);

      await h.tap(find.byKey(const Key('appearance-light')));
      await _untilRevealed(h, tester);
      expect(_shown(tester), Brightness.light);
      expect(ticked('light'), isTrue);
      expect(ticked('dark'), isFalse);

      // "System default" on a phone that is light: the look does not change, the choice does.
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await h.tap(find.byKey(const Key('appearance-system')));
      await h.settle();
      expect(themes.mode, ThemeMode.system);
      expect(ticked('system'), isTrue);
      expect(_shown(tester), Brightness.light);
      expect(find.byKey(_firstChild), findsNothing, reason: 'nothing to reveal');

      await tester.pageBack();
      await h.settle();
      expect(
          find.descendant(
              of: find.byKey(const Key('settings-appearance')), matching: find.text('System default')),
          findsOneWidget);
      expect(tester.takeException(), isNull);
      await h.dispose();
    });

    testWidgets('is in Kurdish and Arabic too, and reads right to left', (tester) async {
      for (final (language, title, light, dark) in [
        (AppLanguage.ckb, 'ڕووکار', 'ڕووناک', 'تاریک'),
        (AppLanguage.ar, 'المظهر', 'فاتح', 'داكن'),
      ]) {
        final themes = await _themes(tester, ThemeMode.dark);
        final h = UiHarness(tester)..screen();
        final alice =
            await h.node('Alice', onboarded: true, nickname: 'Alice', language: language, theme: themes);
        await h.show(alice);
        await h.openSettingsPage('appearance');
        expect(find.text(title), findsWidgets, reason: language.code);
        expect(find.text(light), findsOneWidget, reason: language.code);
        expect(find.text(dark), findsOneWidget, reason: language.code);
        expect(Directionality.of(tester.element(find.byType(AppearancePage))), TextDirection.rtl);
        // The choice works in this language too.
        await h.tap(find.byKey(const Key('appearance-light')));
        await _untilRevealed(h, tester);
        expect(_shown(tester), Brightness.light, reason: language.code);
        expect(tester.takeException(), isNull);
        await h.dispose();
      }
    });
  });
  group('System default', () {
    testWidgets('follows the phone while the app is open, and keeps the page that was open',
        (tester) async {
      final themes = await _themes(tester, ThemeMode.system);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      final h = UiHarness(tester)..screen();
      final alice = await h.node('Alice', onboarded: true, nickname: 'Alice', theme: themes);
      await h.show(alice);
      await h.openSettingsPage('appearance');
      expect(_shown(tester), Brightness.dark, reason: 'the phone is dark');

      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      await tester.pump();
      await tester.pump();
      expect(_shown(tester), Brightness.light, reason: 'the phone went light, and the app with it');
      expect(find.byType(AppearancePage), findsOneWidget, reason: 'with no reveal and nothing lost');
      expect(find.byKey(_firstChild), findsNothing);

      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await tester.pump();
      await tester.pump();
      expect(_shown(tester), Brightness.dark);
      expect(themes.mode, ThemeMode.system, reason: 'the choice itself did not change');
      await h.dispose();
    });

    testWidgets('a phone going light does not touch a person who chose dark', (tester) async {
      final themes = await _themes(tester, ThemeMode.dark);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      final h = UiHarness(tester)..screen();
      final alice = await h.node('Alice', onboarded: true, nickname: 'Alice', theme: themes);
      await h.show(alice);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      await tester.pump();
      await tester.pump();
      expect(_shown(tester), Brightness.dark);
      await h.dispose();
    });
  });
}

/// Something with a state of its own, to see whether it survives.
class _Witness extends StatefulWidget {
  const _Witness();

  /// How many times a state of this kind was made.
  static int created = 0;

  @override
  State<_Witness> createState() => _WitnessState();
}

class _WitnessState extends State<_Witness> {
  int _taps = 0;

  @override
  void initState() {
    super.initState();
    _Witness.created++;
  }

  @override
  Widget build(BuildContext context) => TextButton(
        key: const Key('witness'),
        onPressed: () => setState(() => _taps++),
        child: Text('taps $_taps'),
      );
}
