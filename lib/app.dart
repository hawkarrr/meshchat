import 'package:flutter/material.dart';

import 'app_controller.dart';
import 'app_scope.dart';
import 'core/app_info.dart';
import 'core/app_log.dart';
import 'l10n/l10n.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'theme/app_theme.dart';
import 'theme/surfaces.dart';
import 'theme/theme_controller.dart';
import 'theme/theme_host.dart';
import 'widgets/app_logo.dart';

/// Opens the database and identity (not Bluetooth), then shows the app. If that
/// fails, says so and offers a retry instead of a blank screen.
class BootstrapApp extends StatefulWidget {
  const BootstrapApp({super.key, this.bootstrap = AppController.bootstrap, this.theme});

  /// Builds the controller. Tests pass their own.
  final Future<AppController> Function() bootstrap;

  /// The appearance the person chose, read before anything else is opened, so that the
  /// splash and the message about a database that would not open are already in it. Dark
  /// when not given (the tests).
  final ThemeController? theme;

  @override
  State<BootstrapApp> createState() => _BootstrapAppState();
}

class _BootstrapAppState extends State<BootstrapApp> {
  late final ThemeController _theme = widget.theme ?? ThemeController(mode: ThemeMode.dark);
  AppController? _controller;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    try {
      final controller = await widget.bootstrap();
      if (!mounted) {
        controller.dispose();
        return;
      }
      setState(() => _controller = controller);
    } catch (e) {
      AppLog.instance.e('App', 'startup failed: $e');
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller != null) return DamataqeApp(controller: controller);
    // The stored choice of language cannot be read yet (the storage is what
    // failed, or has not opened), so the main language is used.
    return MaterialApp(
      title: AppInfo.name,
      debugShowCheckedModeBanner: false,
      // The standard way suffices here: no reveal is needed before the app is up.
      theme: lightTheme(),
      darkTheme: darkTheme(),
      themeMode: _theme.mode,
      locale: AppLanguage.main.locale,
      supportedLocales: AppLanguage.supportedLocales,
      localizationsDelegates: AppLanguage.delegates,
      home: _error == null
          ? const _Splash()
          : _StartupError(
              error: _error!,
              onRetry: () {
                setState(() => _error = null);
                _boot();
              },
            ),
    );
  }
}

/// The running app: theme, the controller scope, and the choice between the
/// first-run explanation and the main screens. It also tells the controller
/// whether the app is on screen, which decides whether a message becomes a
/// notification.
class DamataqeApp extends StatefulWidget {
  const DamataqeApp({super.key, required this.controller});

  final AppController controller;

  @override
  State<DamataqeApp> createState() => _DamataqeAppState();
}

class _DamataqeAppState extends State<DamataqeApp> with WidgetsBindingObserver {
  late AppLanguage _language = widget.controller.language;

  /// Starts the theme provider again, from the theme asked for now and with no reveal. It
  /// moves when the language does (its fonts are part of the theme), when the phone goes
  /// light or dark while "System default" is chosen, and when the appearance is changed
  /// with no reveal. A change made with the reveal does not move it: the reveal has already
  /// put the new theme on the screen, and rebuilding here first would show it before the
  /// picture of the old one is taken.
  int _themeSeed = 0;

  /// How many silent changes the theme controller had when this last looked. Set in
  /// [initState], not lazily: a lazy initializer would first run inside [_onTheme], after the
  /// change, and see nothing to do.
  int _silentChanges = 0;

  ThemeController get _themes => widget.controller.theme;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller.addListener(_onController);
    _silentChanges = _themes.silentChanges;
    _themes.addListener(_onTheme);
    final state = WidgetsBinding.instance.lifecycleState;
    widget.controller.setForeground(state == null || state == AppLifecycleState.resumed);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onController);
    _themes.removeListener(_onTheme);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Only a change of language rebuilds the whole app (new words, new writing
  /// direction); every other setting is read by the screens that show it.
  void _onController() {
    if (_language == widget.controller.language) return;
    setState(() {
      _language = widget.controller.language;
      _themeSeed++;
    });
  }

  void _onTheme() {
    if (_silentChanges == _themes.silentChanges) return;
    _silentChanges = _themes.silentChanges;
    setState(() => _themeSeed++);
  }

  /// "System default": the phone went light or dark, and the app follows at once.
  @override
  void didChangePlatformBrightness() {
    if (_themes.mode == ThemeMode.system) setState(() => _themeSeed++);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    widget.controller.setForeground(state == AppLifecycleState.resumed);
  }

  @override
  Widget build(BuildContext context) {
    // The fonts depend on the language (Kurdish and Arabic start with the bundled one), the
    // colours on the appearance.
    final platform = WidgetsBinding.instance.platformDispatcher.platformBrightness;
    final theme = buildAppTheme(language: _language, brightness: _themes.brightnessFor(platform));
    return AppScope(
      controller: widget.controller,
      child: MaterialApp(
        title: AppInfo.name,
        debugShowCheckedModeBanner: false,
        theme: theme,
        darkTheme: theme,
        themeMode: theme.brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
        // The reveal replaces the cross-fade of a theme change.
        themeAnimationDuration: Duration.zero,
        locale: _language.locale,
        supportedLocales: AppLanguage.supportedLocales,
        localizationsDelegates: AppLanguage.delegates,
        builder: (context, child) =>
            ThemeHost(initialTheme: theme, seed: _themeSeed, child: child ?? const SizedBox.shrink()),
        home: const AppGate(),
      ),
    );
  }
}

/// Nothing touches Bluetooth, and no permission is requested, until the person
/// has read the first-run page and chosen to start.
class AppGate extends StatelessWidget {
  const AppGate({super.key});

  @override
  Widget build(BuildContext context) {
    final onboarded = AppScope.of(context).onboardingDone;
    return onboarded ? const HomeScreen() : const OnboardingScreen();
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const AppScaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppLogo(size: 96),
            SizedBox(height: 18),
            Text(AppInfo.name, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            SizedBox(height: 20),
            SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)),
          ],
        ),
      ),
    );
  }
}

class _StartupError extends StatelessWidget {
  const _StartupError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    // The person's language is stored in the very storage that failed, so the
    // explanation is given in the main language and, below it, in English.
    final en = englishStrings();
    return AppScaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.error_outline_rounded, color: context.palette.danger, size: 40),
                  const SizedBox(height: 16),
                  Text(l.startupErrorTitle,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  Text(
                    l.startupErrorBody,
                    style: TextStyle(color: context.palette.textMuted, height: 1.4),
                  ),
                  const SizedBox(height: 14),
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(en.startupErrorTitle,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        Text(
                          en.startupErrorBody,
                          style: TextStyle(color: context.palette.textMuted, height: 1.4, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text('$error', style: monoStyle(fontSize: 12, color: context.palette.textMuted)),
                  ),
                  const SizedBox(height: 22),
                  FilledButton(onPressed: onRetry, child: Text('${l.commonTryAgain} / ${en.commonTryAgain}')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
