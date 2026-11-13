import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_mesh_chat/core/app_info.dart';
import 'package:offline_mesh_chat/l10n/l10n.dart';
import 'package:offline_mesh_chat/theme/app_theme.dart';

import '../support/font_cmap.dart';

/// Kurdish and Arabic are drawn with a font that ships inside the app, not with
/// whatever the phone happens to have. These tests check that the font is declared, that
/// it really has every letter the app writes, and that the theme puts it where it belongs.
void main() {
  final pubspec = File('pubspec.yaml').readAsStringSync();
  const files = {
    400: 'assets/fonts/NotoSansArabic-Regular.ttf',
    500: 'assets/fonts/NotoSansArabic-Medium.ttf',
    600: 'assets/fonts/NotoSansArabic-SemiBold.ttf',
    700: 'assets/fonts/NotoSansArabic-Bold.ttf',
  };

  group('the bundled font', () {
    test('is declared in pubspec.yaml, with four weights, and its licence', () {
      expect(pubspec, contains('family: $kArabicFont'));
      for (final path in files.values) {
        expect(pubspec, contains('asset: $path'), reason: path);
        expect(File(path).existsSync(), isTrue, reason: '$path is in the project');
      }
      expect(pubspec, contains('- assets/fonts/OFL.txt'));
      expect(File('assets/fonts/OFL.txt').readAsStringSync(), contains('SIL OPEN FONT LICENSE'));
    });

    test('has every letter of the app\'s Kurdish and Arabic text', () {
      // A few marks of punctuation are not in it; the phone's own font draws them.
      const drawnByTheFallback = {0x00B7, 0x2014, 0x2022, 0x2026};
      for (final weight in files.entries) {
        final have = fontCharacters(File(weight.value).readAsBytesSync());
        final missing = <String>{};
        for (final code in ['ckb', 'ar']) {
          final arb = jsonDecode(File('lib/l10n/app_$code.arb').readAsStringSync()) as Map<String, dynamic>;
          for (final entry in arb.entries) {
            if (entry.key.startsWith('@')) continue;
            for (final rune in (entry.value as String).runes) {
              if (rune < 0x80 || String.fromCharCode(rune).trim().isEmpty) continue;
              if (!have.contains(rune) && !drawnByTheFallback.contains(rune)) {
                missing.add('U+${rune.toRadixString(16).toUpperCase()} ${String.fromCharCode(rune)}');
              }
            }
          }
        }
        expect(missing, isEmpty, reason: '${weight.value} lacks letters the app writes');
      }
    });

    test('has every letter of Central Kurdish, and of the app\'s name', () {
      final have = fontCharacters(File(files[400]!).readAsBytesSync());
      for (final rune in 'ڕڵۆێەڤپچژگکیو'.runes) {
        expect(have, contains(rune), reason: String.fromCharCode(rune));
      }
      for (final rune in AppInfo.name.runes) {
        expect(have, contains(rune), reason: String.fromCharCode(rune));
      }
    });
  });

  group('the theme', () {
    test('Kurdish and Arabic start with the bundled font, and fall back to the phone for Latin', () {
      for (final language in [AppLanguage.ckb, AppLanguage.ar]) {
        final theme = buildAppTheme(language: language);
        expect(theme.textTheme.bodyMedium!.fontFamily, kArabicFont, reason: language.code);
        expect(theme.textTheme.titleLarge!.fontFamily, kArabicFont);
        expect(theme.textTheme.labelLarge!.fontFamily, kArabicFont, reason: 'buttons too');
        expect(theme.textTheme.bodyMedium!.fontFamilyFallback, contains('Roboto'));
      }
    });

    test('English keeps the phone\'s own font, with the bundled one behind it for Arabic script', () {
      final theme = buildAppTheme(language: AppLanguage.en);
      expect(theme.textTheme.bodyMedium!.fontFamily, isNot(kArabicFont));
      expect(theme.textTheme.bodyMedium!.fontFamilyFallback, contains(kArabicFont));
    });

    test('one theme per language, built once', () {
      expect(identical(buildAppTheme(language: AppLanguage.ckb), buildAppTheme(language: AppLanguage.ckb)),
          isTrue);
      expect(identical(buildAppTheme(language: AppLanguage.ckb), buildAppTheme(language: AppLanguage.en)),
          isFalse);
    });

    test('the right-to-left languages are exactly the ones with the bundled font first', () {
      for (final language in AppLanguage.values) {
        expect(fontsFor(language).family == kArabicFont, language.isRtl, reason: language.code);
      }
    });

    test('is dark and Telegram-blue unless the light one is asked for', () {
      final theme = buildAppTheme();
      expect(theme.brightness, Brightness.dark);
      expect(theme.colorScheme.primary, AppPalette.dark.accent);
      expect(AppPalette.dark.accent, const Color(0xFF3390EC));
      expect(AppPalette.dark.background.computeLuminance(), lessThan(0.01), reason: 'near-black');

      final light = buildAppTheme(brightness: Brightness.light);
      expect(light.brightness, Brightness.light);
      expect(light.colorScheme.primary, AppPalette.light.accent);
      expect(AppPalette.light.background.computeLuminance(), greaterThan(0.85), reason: 'a pale page');
    });

    test('one theme per language and appearance, built once', () {
      for (final brightness in Brightness.values) {
        expect(
          identical(buildAppTheme(language: AppLanguage.en, brightness: brightness),
              buildAppTheme(language: AppLanguage.en, brightness: brightness)),
          isTrue,
          reason: brightness.name,
        );
      }
      expect(
        identical(buildAppTheme(language: AppLanguage.en, brightness: Brightness.dark),
            buildAppTheme(language: AppLanguage.en, brightness: Brightness.light)),
        isFalse,
      );
      expect(identical(lightTheme(), buildAppTheme(brightness: Brightness.light)), isTrue);
      expect(identical(darkTheme(), buildAppTheme()), isTrue);
    });

    test('both appearances put the right fonts in place', () {
      for (final brightness in Brightness.values) {
        final theme = buildAppTheme(language: AppLanguage.ckb, brightness: brightness);
        expect(theme.textTheme.bodyMedium!.fontFamily, kArabicFont, reason: brightness.name);
        expect(theme.textTheme.labelLarge!.fontFamily, kArabicFont, reason: '${brightness.name}: buttons');
      }
    });
  });
}
