import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'app_controller.dart';
import 'core/app_log.dart';
import 'core/licences.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  registerBundledLicences();

  final previousHandler = FlutterError.onError;
  FlutterError.onError = (details) {
    AppLog.instance.e('Flutter', details.exceptionAsString());
    previousHandler?.call(details);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    AppLog.instance.e('Async', '$error');
    return true;
  };

  // How the app looks is the first thing read, and from storage that needs no database, so
  // that the very first frame is already in the right appearance (no flash of the wrong one
  // while the database opens). It never fails: unreadable storage means the default.
  final theme = await ThemeController.load();

  final shown = theme.brightnessFor(PlatformDispatcher.instance.platformBrightness);
  SystemChrome.setSystemUIOverlayStyle(systemOverlayFor(AppPalette.forBrightness(shown)));

  runApp(BootstrapApp(theme: theme, bootstrap: () => AppController.bootstrap(theme: theme)));
}
