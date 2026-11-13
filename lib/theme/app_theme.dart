import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_language.dart';
import 'app_palette.dart';
import 'page_transitions.dart';

// Every file that takes its colours from the theme imports this one, so the palette comes
// with it: `context.palette.text`.
export 'app_palette.dart';

/// The family name of the bundled font, Noto Sans Arabic (see `pubspec.yaml` and
/// `assets/fonts/`). It draws Arabic and Central Kurdish; it has no Latin letters.
const String kArabicFont = 'NotoSansArabic';

/// The colours that are the same in the dark and the light appearance. Everything else is in
/// [AppPalette] and is read from the theme (`context.palette`), because it changes with it.
abstract final class AppColors {
  // ---- avatars of groups and rooms: a soft blue gradient, from top-left to bottom-right -------------
  static const List<Color> groupAvatar = <Color>[Color(0xFF2AA9E8), Color(0xFF16638F)];
  static const List<Color> roomAvatar = <Color>[Color(0xFF3F7FD6), Color(0xFF244B8C)];

  // ---- over a picture or a video: always white on black, whatever the theme ---------------------
  static const Color viewerBackground = Color(0xFF000000);
  static const Color onMedia = Color(0xFFFFFFFF);
  static const Color onMediaMuted = Color(0xB3FFFFFF); // 70%
  static const Color onMediaFaint = Color(0x66FFFFFF); // 40%
  static const Color mediaTrack = Color(0x3DFFFFFF); // 24%
  static const Color mediaTrackFaint = Color(0x1FFFFFFF); // 12%
  static const Color mediaBar = Color(0x8A000000); // black at 54%: a bar over a picture
}

/// Corner radii. Small things 12, controls 16, cards 20, sheets and bars 28.
abstract final class AppRadii {
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 28;
  static const double pill = 999;
}

/// Space, in steps of four points.
abstract final class AppSpace {
  static const double xs = 4;
  static const double s = 8;
  static const double m = 12;
  static const double l = 16;
  static const double xl = 24;

  /// The page's side margin.
  static const double gutter = 16;
}

/// Sizes of things that are touched or recognised: the smallest target is 44.
abstract final class AppSizes {
  static const double tap = 44;
  static const double button = 48;
  static const double icon = 24;
  static const double iconSmall = 20;
  static const double avatarList = 52;
  static const double avatarHeader = 40;
  static const double listRow = 72;
}

/// A monospace style for fingerprints, ids and logs. The family "monospace"
/// exists on Android only; Menlo and Courier are what iOS and desktop have.
TextStyle monoStyle({
  double fontSize = 13,
  Color? color,
  FontWeight? fontWeight,
  double? height,
  double? letterSpacing,
}) =>
    TextStyle(
      fontFamily: 'monospace',
      fontFamilyFallback: const <String>['Menlo', 'Courier New', 'Courier'],
      fontSize: fontSize,
      color: color,
      fontWeight: fontWeight,
      height: height,
      letterSpacing: letterSpacing,
    );

/// The contrast between two colours, from 1 (the same) to 21 (black on white).
/// Text should have 4.5 against what it is on.
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

/// What the status bar and the phone's own navigation bar look like over [palette]'s page:
/// transparent bar with light icons on the dark appearance, dark icons on the light one.
/// [navigationBar] false leaves the bottom bar out (what an app bar may set for itself).
SystemUiOverlayStyle systemOverlayFor(AppPalette palette, {bool navigationBar = true}) {
  final dark = palette.isDark;
  final icons = dark ? Brightness.light : Brightness.dark;
  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: icons,
    // iOS: the brightness of what is behind the bar, the opposite of its icons.
    statusBarBrightness: dark ? Brightness.dark : Brightness.light,
    systemNavigationBarColor: navigationBar ? palette.surface : null,
    systemNavigationBarIconBrightness: navigationBar ? icons : null,
  );
}

/// The fonts of a language.
///
/// Kurdish and Arabic start with the bundled Noto Sans Arabic - the same letters on
/// every phone - and fall back to the phone's own font for what it lacks (Latin
/// letters, a few punctuation marks). Every other language keeps the phone's font
/// and has the bundled one as its fallback, so a Kurdish name in an English chat is
/// drawn with it too instead of with whatever the phone happens to choose.
({String? family, List<String> fallback}) fontsFor(AppLanguage language) => language.isRtl
    ? (family: kArabicFont, fallback: const <String>['Roboto'])
    : (family: null, fallback: const <String>[kArabicFont]);

final Map<(AppLanguage, Brightness), ThemeData> _themes = <(AppLanguage, Brightness), ThemeData>{};

/// The theme of the app in [language] and [brightness]: the dark appearance unless asked
/// for the light one. It is built once per pair, so the same call gives the same object.
ThemeData buildAppTheme({
  AppLanguage language = AppLanguage.main,
  Brightness brightness = Brightness.dark,
}) =>
    _themes.putIfAbsent((language, brightness), () => _build(language, brightness));

/// The light appearance of the app in [language].
ThemeData lightTheme({AppLanguage language = AppLanguage.main}) =>
    buildAppTheme(language: language, brightness: Brightness.light);

/// The dark appearance of the app in [language].
ThemeData darkTheme({AppLanguage language = AppLanguage.main}) =>
    buildAppTheme(language: language, brightness: Brightness.dark);

ThemeData _build(AppLanguage language, Brightness brightness) {
  final p = AppPalette.forBrightness(brightness);

  // The dark scheme is exactly what it was before the light one existed. The light one
  // names more of the scheme's colours, because the ones Material would fill in for it are
  // the lilac of its baseline, which would show up in chips, selected segments and the like.
  final scheme = p.isDark
      ? ColorScheme.dark(
          primary: p.accent,
          onPrimary: p.onAccent,
          secondary: p.accentSoft,
          onSecondary: const Color(0xFF00182B),
          surface: p.surface,
          onSurface: p.text,
          surfaceContainerHighest: p.surfaceHigh,
          outline: p.outline,
          error: p.danger,
          onError: p.onStatus,
        )
      : ColorScheme.light(
          primary: p.accent,
          onPrimary: p.onAccent,
          primaryContainer: Color.alphaBlend(p.accent.withValues(alpha: 0.16), p.surface),
          onPrimaryContainer: p.accentSoft,
          secondary: p.accentSoft,
          onSecondary: p.onAccent,
          secondaryContainer: Color.alphaBlend(p.accent.withValues(alpha: 0.16), p.surface),
          onSecondaryContainer: p.accentSoft,
          surface: p.surface,
          onSurface: p.text,
          onSurfaceVariant: p.textMuted,
          surfaceContainerLowest: p.surface,
          surfaceContainerLow: p.surface,
          surfaceContainer: p.surfaceHigh,
          surfaceContainerHigh: p.surfaceHigh,
          surfaceContainerHighest: p.surfaceHighest,
          surfaceTint: Colors.transparent,
          outline: p.outline,
          outlineVariant: p.divider,
          error: p.danger,
          onError: p.onStatus,
          inverseSurface: const Color(0xFF2B2F36),
          onInverseSurface: p.onAccent,
        );

  final fonts = fontsFor(language);
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.background,
    canvasColor: p.background,
    fontFamily: fonts.family,
    fontFamilyFallback: fonts.fallback,
    splashFactory: InkSparkle.splashFactory,
    visualDensity: VisualDensity.standard,
    // The palette travels with the theme: `context.palette` finds it here.
    extensions: <ThemeExtension<dynamic>>[p],
    iconTheme: IconThemeData(color: p.text),
  );

  final text = base.textTheme.apply(
    bodyColor: p.text,
    displayColor: p.text,
  );

  // Styles given to a component replace its default style instead of adding to
  // it, so every one of them starts from the text theme: that keeps the font
  // (and the sizes) the same in buttons, bars and chips as everywhere else.
  return base.copyWith(
    textTheme: text,
    // Pages open and close in 300 ms on Android (Flutter's default is 450).
    pageTransitionsTheme: appPageTransitions,
    // The bar of a page is the same flat strip as the header of a conversation.
    appBarTheme: AppBarTheme(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      toolbarHeight: 60,
      systemOverlayStyle: systemOverlayFor(p, navigationBar: false),
      titleTextStyle: text.titleLarge!.copyWith(
        color: p.text,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
    ),
    // Cards are flat: a layer, no border.
    cardTheme: CardThemeData(
      color: p.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.lg)),
    ),
    dividerTheme: DividerThemeData(color: p.divider, space: 1, thickness: 1),
    listTileTheme: ListTileThemeData(
      iconColor: p.textMuted,
      textColor: p.text,
      minVerticalPadding: 8,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.surfaceHigh,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.xl),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.xl),
        borderSide: BorderSide.none,
      ),
      // The one place a line shows: where the typing goes.
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.xl),
        borderSide: BorderSide(color: p.accent, width: 1.2),
      ),
      hintStyle: TextStyle(color: p.textMuted),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: p.accentFill,
        foregroundColor: p.onAccent,
        minimumSize: const Size(AppSizes.button, AppSizes.button),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.md)),
        textStyle: text.labelLarge!.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    // The quieter button is a layer, not an outline.
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: p.text,
        backgroundColor: p.surfaceHigh,
        minimumSize: const Size(AppSizes.button, AppSizes.button),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.md)),
        textStyle: text.labelLarge!.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: p.accentSoft,
        minimumSize: const Size(AppSizes.tap, AppSizes.tap),
        textStyle: text.labelLarge!.copyWith(fontSize: 14.5, fontWeight: FontWeight.w600),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size(AppSizes.tap, AppSizes.tap),
        foregroundColor: p.text,
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: p.accentFill,
      foregroundColor: p.onAccent,
      elevation: 3,
      focusElevation: 3,
      hoverElevation: 4,
      highlightElevation: 3,
      shape: const CircleBorder(),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: p.surfaceHighest,
      contentTextStyle: text.bodyMedium!.copyWith(color: p.text),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.md)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.xl)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: p.surfaceHighest,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.md)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: p.surfaceHigh,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.lg)),
      labelStyle: text.labelLarge!.copyWith(color: p.text),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Colors.white : p.textMuted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? p.accent : p.surfaceHighest,
      ),
      trackOutlineColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: p.accent),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: p.surfaceHighest,
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      textStyle: text.bodySmall!.copyWith(color: p.text),
    ),
  );
}
