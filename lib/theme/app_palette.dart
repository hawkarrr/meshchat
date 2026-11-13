import 'package:flutter/material.dart';

/// The colours of the interface in one appearance: dark (near-black, charcoal layers) or
/// light (a pale page with white layers), with the same Telegram-inspired blue in both.
///
/// Every screen takes its colours from here, through the theme: `context.palette.text`.
/// Nothing writes a colour of its own, so changing a value in [dark] or [light] changes it
/// everywhere (`test/ui/theme_tokens_test.dart` reads the sources and checks this).
///
/// The palette is a [ThemeExtension] of the app's [ThemeData] (see `buildAppTheme`), which is
/// why switching the theme repaints exactly the widgets that read a colour from it, also the
/// ones that are `const`.
///
/// Status colours mean the same thing everywhere in the app, in both appearances:
///
///  * green  - directly connected
///  * blue   - reachable through a relay (the brand blue)
///  * grey   - offline / unreachable
///  * amber  - pending / needs attention
///  * blue ticks - delivered
///  * red    - encryption or verification failure, errors
///
/// What is the same in both appearances (the colours over a picture or a video, the
/// gradients of the avatars) is in `AppColors`, in `app_theme.dart`.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.brightness,
    required this.background,
    required this.backgroundDeep,
    required this.backgroundTop,
    required this.surface,
    required this.surfaceHigh,
    required this.surfaceHighest,
    required this.outline,
    required this.divider,
    required this.text,
    required this.textSecondary,
    required this.textMuted,
    required this.accent,
    required this.accentSoft,
    required this.accentFill,
    required this.onAccent,
    required this.direct,
    required this.offline,
    required this.pending,
    required this.danger,
    required this.onStatus,
    required this.incomingBubble,
    required this.veil,
    required this.veilStrong,
    required this.scrim,
    required this.shadow,
    required this.inset,
    required this.track,
    required this.mediaPlaceholder,
    required this.videoCard,
    required this.nameColors,
  });

  /// Which appearance this is.
  final Brightness brightness;

  // ---- surfaces: the page, and the layers on it ---------------------------------------------
  /// The page.
  final Color background;

  /// The bottom of the page's gradient.
  final Color backgroundDeep;

  /// The very top of the page, where the faintest blue begins.
  final Color backgroundTop;

  /// Navigation bar, sheets, cards.
  final Color surface;

  /// Inputs, chips, the incoming bubble in the dark appearance: one step up.
  final Color surfaceHigh;

  /// Pressed rows, menus, snack bars: two steps up.
  final Color surfaceHighest;

  /// A hairline, used rarely: the edge of a focused field.
  final Color outline;

  /// A divider between rows.
  final Color divider;

  // ---- text ----------------------------------------------------------------------------------
  final Color text;
  final Color textSecondary;
  final Color textMuted;

  // ---- the brand blue ------------------------------------------------------------------------
  /// Telegram-inspired blue: active states, links, icons, the focus of a field.
  final Color accent;

  /// The blue for small text and for icons next to it: lighter than [accent] on the dark
  /// layers, deeper on the light ones, so it keeps 4.5 : 1 on every layer.
  final Color accentSoft;

  /// The blue of a surface that carries white text (a button, the bubble you sent): a
  /// little deeper than [accent], so the text keeps 4.5 : 1.
  final Color accentFill;

  /// Text and icons on [accentFill]: white in both appearances.
  final Color onAccent;

  // ---- status --------------------------------------------------------------------------------
  final Color direct;
  final Color offline;
  final Color pending;
  final Color danger;

  /// Text on a status colour (the red, amber and blue of a banner or a delete button):
  /// near-black on the bright colours of the dark appearance, white on the deeper ones of
  /// the light appearance.
  final Color onStatus;

  /// Reachable through a relay: the brand blue.
  Color get relay => accent;

  /// Blue ticks: delivered.
  Color get delivered => accentSoft;

  // ---- bubbles -------------------------------------------------------------------------------
  /// The bubble you sent. White text sits on it ([onAccent]), whatever the appearance.
  Color get outgoingBubble => accentFill;

  /// The bubble of what you received.
  final Color incomingBubble;

  // ---- veils over the page (a selected row, a hover) ----------------------------------------
  final Color veil;
  final Color veilStrong;

  // ---- depth ---------------------------------------------------------------------------------
  /// Over the page behind a sheet or a dialog.
  final Color scrim;

  /// Under what floats (the bottom bar). The only shadow of the app.
  final Color shadow;

  /// A darker panel inside a bubble or a sheet (the quoted message).
  final Color inset;

  // ---- media inside a bubble ------------------------------------------------------------------
  /// The empty track of a progress bar or ring that sits on a bubble or on the page.
  final Color track;

  /// The box a picture occupies while it arrives, or when it cannot be shown.
  final Color mediaPlaceholder;

  /// The card a video is shown as. It is dark in both appearances (white text and a play
  /// button sit on it), so on the light page it is a slate, not a wash of black.
  final Color videoCard;

  // ---- the names of people in a shared chat ---------------------------------------------------
  /// Distinct, readable colours for the names of people, readable on the page and on a bubble.
  final List<Color> nameColors;

  /// The colour a person's name is shown in, derived from their id so it is the same on every
  /// screen and every phone (and, in the other appearance, the same hue).
  Color nameColorFor(String seed) {
    var h = 0;
    for (final c in seed.codeUnits) {
      h = (h * 31 + c) & 0xffff;
    }
    return nameColors[h % nameColors.length];
  }

  bool get isDark => brightness == Brightness.dark;

  // ---------------------------------------------------------------------------------------------
  // The two appearances
  // ---------------------------------------------------------------------------------------------

  /// A near-black base, charcoal layers and one blue, in the manner of Telegram's night mode.
  static const AppPalette dark = AppPalette(
    brightness: Brightness.dark,
    background: Color(0xFF0E0E0E),
    backgroundDeep: Color(0xFF0A0A0A),
    backgroundTop: Color(0xFF12161B),
    surface: Color(0xFF1A1A1C),
    surfaceHigh: Color(0xFF242427),
    surfaceHighest: Color(0xFF2E2E32),
    outline: Color(0x1FFFFFFF), // white at 12%
    divider: Color(0x14FFFFFF), // white at 8%
    text: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFD0D0D6),
    textMuted: Color(0xFF8F8F98),
    accent: Color(0xFF3390EC),
    accentSoft: Color(0xFF6CB2F5),
    accentFill: Color(0xFF2874C8),
    onAccent: Color(0xFFFFFFFF),
    direct: Color(0xFF4FD08A),
    offline: Color(0xFF6E6E78),
    pending: Color(0xFFF5B74A),
    danger: Color(0xFFFF5C5C),
    onStatus: Color(0xFF2B0000),
    incomingBubble: Color(0xFF242427),
    veil: Color(0x0FFFFFFF), // white at 6%
    veilStrong: Color(0x1AFFFFFF), // white at 10%
    scrim: Color(0x99000000), // black at 60%
    shadow: Color(0x73000000), // black at 45%
    inset: Color(0x2E000000), // black at 18%
    track: Color(0x3DFFFFFF), // white at 24%
    mediaPlaceholder: Color(0x42000000), // black at 26%
    videoCard: Color(0x61000000), // black at 38%
    nameColors: <Color>[
      Color(0xFF6CB2F5),
      Color(0xFFFFA45C),
      Color(0xFF8BE08B),
      Color(0xFFFF7FA8),
      Color(0xFFC49BFF),
      Color(0xFFF2D14F),
      Color(0xFF5FE0CE),
      Color(0xFFFF8E72),
    ],
  );

  /// A pale page, white layers and the same blue, in the manner of Telegram's day mode. Every
  /// pair of text and ground keeps 4.5 : 1 (3 : 1 for icons), checked in
  /// `test/ui/typography_test.dart`; the status colours are deeper than in the dark
  /// appearance, so that they are readable on white and carry white text.
  static const AppPalette light = AppPalette(
    brightness: Brightness.light,
    background: Color(0xFFF1F3F6),
    backgroundDeep: Color(0xFFE9ECF1),
    backgroundTop: Color(0xFFEAF3FC),
    surface: Color(0xFFFFFFFF),
    surfaceHigh: Color(0xFFE9ECF1),
    surfaceHighest: Color(0xFFDDE2E9),
    outline: Color(0x1F000000), // black at 12%
    divider: Color(0x14000000), // black at 8%
    text: Color(0xFF0F1419),
    textSecondary: Color(0xFF3C4650),
    textMuted: Color(0xFF5B6672),
    accent: Color(0xFF2481CC),
    accentSoft: Color(0xFF1A63AB),
    accentFill: Color(0xFF2874C8),
    onAccent: Color(0xFFFFFFFF),
    direct: Color(0xFF157A48),
    offline: Color(0xFF7A8490),
    pending: Color(0xFFA85200),
    danger: Color(0xFFC62828),
    onStatus: Color(0xFFFFFFFF),
    incomingBubble: Color(0xFFFFFFFF),
    veil: Color(0x0D000000), // black at 5%
    veilStrong: Color(0x17000000), // black at 9%
    scrim: Color(0x73000000), // black at 45%
    shadow: Color(0x29000000), // black at 16%
    inset: Color(0x1A000000), // black at 10%
    track: Color(0x1F000000), // black at 12%
    mediaPlaceholder: Color(0x14000000), // black at 8%
    videoCard: Color(0xFF3A4350),
    nameColors: <Color>[
      Color(0xFF1F6FBF),
      Color(0xFFA84F00),
      Color(0xFF2A7D34),
      Color(0xFFB82D63),
      Color(0xFF7B3FC4),
      Color(0xFF7D6200),
      Color(0xFF0E7C72),
      Color(0xFFBD3F25),
    ],
  );

  /// The palette of [brightness].
  static AppPalette forBrightness(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  /// The palette of the theme [context] is under. A tree built without the app's theme (a
  /// widget test with a bare [MaterialApp]) gets the one that matches its brightness.
  static AppPalette of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<AppPalette>() ?? forBrightness(theme.brightness);
  }

  // ---------------------------------------------------------------------------------------------
  // ThemeExtension
  // ---------------------------------------------------------------------------------------------

  @override
  AppPalette copyWith({
    Brightness? brightness,
    Color? background,
    Color? backgroundDeep,
    Color? backgroundTop,
    Color? surface,
    Color? surfaceHigh,
    Color? surfaceHighest,
    Color? outline,
    Color? divider,
    Color? text,
    Color? textSecondary,
    Color? textMuted,
    Color? accent,
    Color? accentSoft,
    Color? accentFill,
    Color? onAccent,
    Color? direct,
    Color? offline,
    Color? pending,
    Color? danger,
    Color? onStatus,
    Color? incomingBubble,
    Color? veil,
    Color? veilStrong,
    Color? scrim,
    Color? shadow,
    Color? inset,
    Color? track,
    Color? mediaPlaceholder,
    Color? videoCard,
    List<Color>? nameColors,
  }) =>
      AppPalette(
        brightness: brightness ?? this.brightness,
        background: background ?? this.background,
        backgroundDeep: backgroundDeep ?? this.backgroundDeep,
        backgroundTop: backgroundTop ?? this.backgroundTop,
        surface: surface ?? this.surface,
        surfaceHigh: surfaceHigh ?? this.surfaceHigh,
        surfaceHighest: surfaceHighest ?? this.surfaceHighest,
        outline: outline ?? this.outline,
        divider: divider ?? this.divider,
        text: text ?? this.text,
        textSecondary: textSecondary ?? this.textSecondary,
        textMuted: textMuted ?? this.textMuted,
        accent: accent ?? this.accent,
        accentSoft: accentSoft ?? this.accentSoft,
        accentFill: accentFill ?? this.accentFill,
        onAccent: onAccent ?? this.onAccent,
        direct: direct ?? this.direct,
        offline: offline ?? this.offline,
        pending: pending ?? this.pending,
        danger: danger ?? this.danger,
        onStatus: onStatus ?? this.onStatus,
        incomingBubble: incomingBubble ?? this.incomingBubble,
        veil: veil ?? this.veil,
        veilStrong: veilStrong ?? this.veilStrong,
        scrim: scrim ?? this.scrim,
        shadow: shadow ?? this.shadow,
        inset: inset ?? this.inset,
        track: track ?? this.track,
        mediaPlaceholder: mediaPlaceholder ?? this.mediaPlaceholder,
        videoCard: videoCard ?? this.videoCard,
        nameColors: nameColors ?? this.nameColors,
      );

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(
      brightness: t < 0.5 ? brightness : other.brightness,
      background: mix(background, other.background),
      backgroundDeep: mix(backgroundDeep, other.backgroundDeep),
      backgroundTop: mix(backgroundTop, other.backgroundTop),
      surface: mix(surface, other.surface),
      surfaceHigh: mix(surfaceHigh, other.surfaceHigh),
      surfaceHighest: mix(surfaceHighest, other.surfaceHighest),
      outline: mix(outline, other.outline),
      divider: mix(divider, other.divider),
      text: mix(text, other.text),
      textSecondary: mix(textSecondary, other.textSecondary),
      textMuted: mix(textMuted, other.textMuted),
      accent: mix(accent, other.accent),
      accentSoft: mix(accentSoft, other.accentSoft),
      accentFill: mix(accentFill, other.accentFill),
      onAccent: mix(onAccent, other.onAccent),
      direct: mix(direct, other.direct),
      offline: mix(offline, other.offline),
      pending: mix(pending, other.pending),
      danger: mix(danger, other.danger),
      onStatus: mix(onStatus, other.onStatus),
      incomingBubble: mix(incomingBubble, other.incomingBubble),
      veil: mix(veil, other.veil),
      veilStrong: mix(veilStrong, other.veilStrong),
      scrim: mix(scrim, other.scrim),
      shadow: mix(shadow, other.shadow),
      inset: mix(inset, other.inset),
      track: mix(track, other.track),
      mediaPlaceholder: mix(mediaPlaceholder, other.mediaPlaceholder),
      videoCard: mix(videoCard, other.videoCard),
      nameColors: t < 0.5 ? nameColors : other.nameColors,
    );
  }
}

/// `context.palette`: the colours of the theme this widget is under.
extension AppPaletteOnContext on BuildContext {
  AppPalette get palette => AppPalette.of(this);
}
