import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_mesh_chat/theme/theme_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The choice between light, dark and "follow the phone", and its memory.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  group('what is stored', () {
    test('a new install follows the phone', () async {
      final themes = await ThemeController.load();
      expect(themes.mode, ThemeMode.system);
      expect(ThemeController.defaultMode, ThemeMode.system);
    });

    test('the stored choice is the one that comes back', () async {
      for (final mode in ThemeMode.values) {
        SharedPreferences.setMockInitialValues(<String, Object>{
          ThemeController.preferenceKey: mode.name,
        });
        expect((await ThemeController.load()).mode, mode, reason: mode.name);
      }
    });

    test('something that is not a choice is ignored', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        ThemeController.preferenceKey: 'sepia',
      });
      expect((await ThemeController.load()).mode, ThemeController.defaultMode);
      expect(ThemeController.parse('sepia'), isNull);
      expect(ThemeController.parse(null), isNull);
      expect(ThemeController.parse('dark'), ThemeMode.dark);
    });

    test('a choice is kept after the app is closed and opened again', () async {
      final first = await ThemeController.load();
      await first.setMode(ThemeMode.light);

      // "Closing the app": a new controller reads what the first one wrote.
      final second = await ThemeController.load();
      expect(second.mode, ThemeMode.light);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(ThemeController.preferenceKey), 'light');

      await second.setMode(ThemeMode.dark);
      expect((await ThemeController.load()).mode, ThemeMode.dark);
      await second.setMode(ThemeMode.system);
      expect((await ThemeController.load()).mode, ThemeMode.system);
    });

    test('a controller without storage still works, and does not store', () async {
      final themes = ThemeController(mode: ThemeMode.dark);
      expect(themes.mode, ThemeMode.dark);
      await themes.setMode(ThemeMode.light);
      expect(themes.mode, ThemeMode.light);
    });
  });

  group('what it shows', () {
    test('light and dark are what they say, and system is whatever the phone is', () {
      final themes = ThemeController();
      for (final platform in Brightness.values) {
        expect(themes.brightnessFor(platform, ThemeMode.light), Brightness.light);
        expect(themes.brightnessFor(platform, ThemeMode.dark), Brightness.dark);
        expect(themes.brightnessFor(platform, ThemeMode.system), platform);
      }
    });

    test('with no mode given, the current choice decides', () async {
      final themes = ThemeController(mode: ThemeMode.light);
      expect(themes.brightnessFor(Brightness.dark), Brightness.light);
      await themes.setMode(ThemeMode.system);
      expect(themes.brightnessFor(Brightness.dark), Brightness.dark);
    });
  });

  group('who is told', () {
    test('listeners hear a change, and only a change', () async {
      final themes = ThemeController(mode: ThemeMode.dark);
      var heard = 0;
      themes.addListener(() => heard++);
      await themes.setMode(ThemeMode.dark);
      expect(heard, 0, reason: 'the same choice again says nothing');
      await themes.setMode(ThemeMode.light);
      expect(heard, 1);
    });

    test('a change with no reveal is counted, so the app swaps at once', () async {
      final themes = ThemeController(mode: ThemeMode.dark);
      expect(themes.silentChanges, 0);
      await themes.setMode(ThemeMode.light);
      expect(themes.silentChanges, 0, reason: 'the reveal does the drawing for this one');
      await themes.setMode(ThemeMode.dark, silent: true);
      expect(themes.silentChanges, 1);
      var heard = 0;
      themes.addListener(() => heard++);
      await themes.setMode(ThemeMode.dark, silent: true);
      expect(themes.silentChanges, 2, reason: 'also when the choice is the same but the screen is not');
      expect(heard, 1);
    });
  });
}
