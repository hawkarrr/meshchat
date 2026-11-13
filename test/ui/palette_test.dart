import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_mesh_chat/theme/app_theme.dart';

/// The colours of the interface in its two appearances. Every pair of text and ground the
/// screens draw is checked here, in both, so a value can never be changed into something
/// that cannot be read.
void main() {
  // Small text needs 4.5 : 1 against what it is written on; icons and large marks 3 : 1.
  void readable(String what, Color text, Color on, [double need = 4.5]) {
    expect(contrastRatio(text, on), greaterThanOrEqualTo(need), reason: what);
  }

  for (final p in [AppPalette.dark, AppPalette.light]) {
    group('the ${p.brightness.name} palette', () {
      test('text on the page and on every layer', () {
        for (final layer in [p.background, p.surface, p.surfaceHigh, p.incomingBubble]) {
          readable('text on $layer', p.text, layer);
          readable('secondary on $layer', p.textSecondary, layer);
          readable('muted on $layer', p.textMuted, layer);
          readable('blue text on $layer', p.accentSoft, layer);
        }
        // The blue of icons and of the focus of a field: 4.5 on the dark page; on the pale one
        // it is not used for small text (that is the deeper blue above), so 3 : 1 is what an
        // icon needs.
        readable('blue on the page', p.accent, p.background, p.isDark ? 4.5 : 3);
        readable('blue on a layer', p.accent, p.surface, 3);
      });

      test('white on the blue of a button and of the bubble you sent', () {
        readable('button', p.onAccent, p.accentFill);
        readable('outgoing bubble', p.onAccent, p.outgoingBubble);
        expect(p.outgoingBubble, p.accentFill);
      });

      test('the text on a status colour, and the items of the bottom bar', () {
        for (final fill in [p.danger, p.pending, p.accentSoft]) {
          readable('on $fill', p.onStatus, fill);
        }
        final pill = Color.alphaBlend(p.accent.withValues(alpha: 0.16), p.surface);
        readable('the word of the chosen item', p.accentSoft, pill);
        readable('its icon', p.accent, pill, 3);
        readable('an item that is not chosen', p.textMuted, p.surface);
      });

      test('the status colours can be read on the layers', () {
        for (final layer in [p.surface, p.background]) {
          for (final color in [p.direct, p.pending, p.danger, p.delivered]) {
            readable('status $color on $layer', color, layer);
          }
        }
      });

      test('the names of people can be read on the page and on a bubble', () {
        for (final name in p.nameColors) {
          for (final ground in [p.background, p.incomingBubble]) {
            readable('name $name on $ground', name, ground);
          }
        }
        expect(p.nameColors, hasLength(8));
      });

      test('a person has one colour, the same every time, and people differ', () {
        expect(p.nameColorFor('abc'), p.nameColorFor('abc'));
        final colours = {for (var i = 0; i < 64; i++) p.nameColorFor('person-$i')};
        expect(colours.length, greaterThan(4), reason: 'the colours are spread out');
      });

      test('what lies over a picture is the same everywhere, and white on black', () {
        expect(AppColors.onMedia, const Color(0xFFFFFFFF));
        expect(AppColors.viewerBackground, const Color(0xFF000000));
        readable('over a picture', AppColors.onMedia, AppColors.viewerBackground);
      });
    });
  }

  group('the two appearances together', () {
    test('every colour differs where it must, and the brand blue does not move', () {
      expect(AppPalette.dark.background, isNot(AppPalette.light.background));
      expect(AppPalette.dark.text, isNot(AppPalette.light.text));
      expect(AppPalette.dark.surface, isNot(AppPalette.light.surface));
      expect(AppPalette.dark.accentFill, AppPalette.light.accentFill, reason: 'the bubble you sent');
      expect(AppPalette.dark.onAccent, AppPalette.light.onAccent);
    });

    test('they know which one they are, and are found by brightness', () {
      expect(AppPalette.dark.isDark, isTrue);
      expect(AppPalette.light.isDark, isFalse);
      expect(AppPalette.forBrightness(Brightness.dark), same(AppPalette.dark));
      expect(AppPalette.forBrightness(Brightness.light), same(AppPalette.light));
    });

    test('the middle of a change is a blend, and the ends are the two palettes', () {
      final half = AppPalette.dark.lerp(AppPalette.light, 0.5);
      expect(half.background, Color.lerp(AppPalette.dark.background, AppPalette.light.background, 0.5));
      expect(AppPalette.dark.lerp(AppPalette.light, 0).text, AppPalette.dark.text);
      expect(AppPalette.dark.lerp(AppPalette.light, 1).text, AppPalette.light.text);
      expect(AppPalette.dark.lerp(null, 0.5), same(AppPalette.dark), reason: 'nothing to blend with');
    });

    test('copyWith changes only what it is given', () {
      const mark = Color(0xFF123456);
      final changed = AppPalette.light.copyWith(accent: mark);
      expect(changed.accent, mark);
      expect(changed.background, AppPalette.light.background);
      expect(changed.nameColors, AppPalette.light.nameColors);
    });

    testWidgets('a widget finds the palette of the theme it is under', (tester) async {
      late AppPalette seen;
      Future<void> under(ThemeData theme) async {
        await tester.pumpWidget(MaterialApp(
          theme: theme,
          home: Builder(builder: (context) {
            seen = context.palette;
            return const SizedBox();
          }),
        ));
        // A new theme is cross-faded in by MaterialApp (and the palette blended on the way);
        // at the end of it the palette is the real one.
        await tester.pumpAndSettle();
      }

      await under(buildAppTheme());
      expect(seen, same(AppPalette.dark));
      await under(buildAppTheme(brightness: Brightness.light));
      expect(seen, same(AppPalette.light));
      // A tree built without the app's theme still gets a palette that matches its brightness.
      await under(ThemeData.light());
      expect(seen, same(AppPalette.light));
      await under(ThemeData.dark());
      expect(seen, same(AppPalette.dark));
    });

    testWidgets('the theme of each appearance is built from its palette', (tester) async {
      for (final brightness in Brightness.values) {
        final p = AppPalette.forBrightness(brightness);
        final theme = buildAppTheme(brightness: brightness);
        expect(theme.extension<AppPalette>(), same(p));
        expect(theme.brightness, brightness);
        expect(theme.scaffoldBackgroundColor, p.background);
        expect(theme.colorScheme.surface, p.surface);
        expect(theme.colorScheme.onSurface, p.text);
        expect(theme.appBarTheme.backgroundColor, p.surface);
        expect(theme.cardTheme.color, p.surface);
        expect(theme.dialogTheme.backgroundColor, p.surface);
        expect(theme.bottomSheetTheme.backgroundColor, p.surface);
        expect(theme.inputDecorationTheme.fillColor, p.surfaceHigh);
        expect(theme.dividerTheme.color, p.divider);
      }
    });

    test('the status bar follows the appearance', () {
      final dark = systemOverlayFor(AppPalette.dark);
      expect(dark.statusBarIconBrightness, Brightness.light, reason: 'light icons on the dark page');
      expect(dark.statusBarBrightness, Brightness.dark);
      final light = systemOverlayFor(AppPalette.light);
      expect(light.statusBarIconBrightness, Brightness.dark, reason: 'dark icons on the pale page');
      expect(light.statusBarBrightness, Brightness.light);
      expect(light.systemNavigationBarColor, AppPalette.light.surface);
      expect(systemOverlayFor(AppPalette.light, navigationBar: false).systemNavigationBarColor, isNull);
    });
  });
}
