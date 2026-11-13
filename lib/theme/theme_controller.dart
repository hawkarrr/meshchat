import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_log.dart';

/// Which appearance the person chose - light, dark, or whatever the phone is set to - and
/// the memory of it.
///
/// The choice is kept in `SharedPreferences`, not in the database with the other settings, on
/// purpose: it is read before the database is open, so the first frame (the splash, or the
/// message that the database could not be opened) is already in the right appearance and
/// nothing flashes. It also survives "Delete all local data", like the language: how the app
/// looks is not the person's data.
///
/// This class only knows the choice. Showing it - the circular reveal, the theme of the whole
/// app - is `ThemeHost` (`theme_host.dart`), and the buttons that change it are in
/// `widgets/theme_toggle.dart`.
class ThemeController extends ChangeNotifier {
  /// `mode` is the choice to start from; with `preferences` every change is also stored.
  ThemeController({this._mode = defaultMode, this._preferences});

  /// The key under which the choice is stored.
  static const String preferenceKey = 'theme_mode';

  /// What a new install does: follow the phone.
  static const ThemeMode defaultMode = ThemeMode.system;

  /// Reads the stored choice. Never fails and never holds the app up: if the storage cannot
  /// be read, the app starts with [defaultMode] (and tries again when the person chooses).
  static Future<ThemeController> load({SharedPreferences? preferences}) async {
    try {
      final stored = preferences ?? await SharedPreferences.getInstance();
      return ThemeController(
        mode: parse(stored.getString(preferenceKey)) ?? defaultMode,
        preferences: stored,
      );
    } catch (e) {
      AppLog.instance.w('Theme', 'the stored appearance could not be read: $e');
      return ThemeController();
    }
  }

  /// `light`, `dark` and `system` are understood; anything else is not.
  static ThemeMode? parse(String? stored) {
    for (final mode in ThemeMode.values) {
      if (mode.name == stored) return mode;
    }
    return null;
  }

  ThemeMode _mode;
  SharedPreferences? _preferences;
  int _silentChanges = 0;

  /// The person's choice.
  ThemeMode get mode => _mode;

  /// How many times the appearance was changed with no reveal (the person asked the phone
  /// for less motion, or no button was there to reveal from). The app watches this number:
  /// when it moves, the appearance is swapped at once.
  int get silentChanges => _silentChanges;

  /// The appearance that is shown when the phone itself is [platform] bright, for the
  /// choice [mode] (the current one unless given).
  Brightness brightnessFor(Brightness platform, [ThemeMode? mode]) => switch (mode ?? _mode) {
        ThemeMode.light => Brightness.light,
        ThemeMode.dark => Brightness.dark,
        ThemeMode.system => platform,
      };

  /// Records the choice: it is stored, and whoever listens is told.
  ///
  /// This does not draw anything. The caller either has already started the circular
  /// reveal (`switchThemeMode`), or passes [silent] to have the app swap the appearance at
  /// once.
  Future<void> setMode(ThemeMode mode, {bool silent = false}) async {
    if (mode == _mode && !silent) return;
    _mode = mode;
    if (silent) _silentChanges++;
    notifyListeners();
    try {
      final stored = _preferences ??= await SharedPreferences.getInstance();
      await stored.setString(preferenceKey, mode.name);
    } catch (e) {
      // The choice still holds for this run; it is just not remembered.
      AppLog.instance.w('Theme', 'the appearance could not be stored: $e');
    }
  }
}
