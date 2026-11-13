# Fonts

**Noto Sans Arabic** (Regular, Medium, SemiBold, Bold), from the official Noto repository
<https://github.com/notofonts/arabic> (files: `fonts/NotoSansArabic/hinted/ttf/`).
Copyright 2022 The Noto Project Authors. Licensed under the SIL Open Font License 1.1 (`OFL.txt`).

Why it is bundled: it draws every letter of Arabic and of Central Kurdish (Sorani: ڕ ڵ ۆ ێ ە ڤ پ چ ژ گ ک ...)
the same way on every phone, instead of whatever the phone's own fallback font happens to be.
It has no Latin letters; the phone's own font draws those (see `buildAppTheme` in `lib/theme/app_theme.dart`).

`test/ui/typography_test.dart` checks that the files are declared in `pubspec.yaml` and that they contain every
character of the app's Kurdish and Arabic text.
