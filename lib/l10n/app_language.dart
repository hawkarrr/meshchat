import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_localizations.dart';
import 'ckb_localizations.dart';

/// The languages of the app. Kurdish (Central Kurdish, also called Sorani, in
/// the Arabic script) is the main one: it is what the app opens in until a
/// person picks another. Arabic is the second; English is kept for people who
/// read it best.
enum AppLanguage {
  ckb(code: 'ckb', nativeName: 'کوردی', englishName: 'Kurdish (Sorani)', direction: TextDirection.rtl),
  ar(code: 'ar', nativeName: 'العربية', englishName: 'Arabic', direction: TextDirection.rtl),
  en(code: 'en', nativeName: 'English', englishName: 'English', direction: TextDirection.ltr);

  const AppLanguage({
    required this.code,
    required this.nativeName,
    required this.englishName,
    required this.direction,
  });

  /// The language code (`ckb`, `ar`, `en`); this is what is stored.
  final String code;

  /// The language's name in itself, as the picker shows it.
  final String nativeName;
  final String englishName;
  final TextDirection direction;

  /// What the app opens in when nothing was chosen yet.
  static const AppLanguage main = AppLanguage.ckb;

  Locale get locale => Locale(code);

  bool get isRtl => direction == TextDirection.rtl;

  /// The app's own text in this language, for code that has no [BuildContext]
  /// (messages from the services, notifications).
  AppLocalizations get strings => lookupAppLocalizations(locale);

  /// The language stored as [code], or null when it is missing or unknown.
  static AppLanguage? parse(String? code) {
    for (final l in values) {
      if (l.code == code) return l;
    }
    return null;
  }

  static const List<Locale> supportedLocales = <Locale>[Locale('ckb'), Locale('ar'), Locale('en')];

  /// The app's own text first, then Flutter's words for Central Kurdish, then
  /// Flutter's own Arabic and English.
  static const List<LocalizationsDelegate<dynamic>> delegates = <LocalizationsDelegate<dynamic>>[
    AppLocalizations.delegate,
    CkbWidgetsLocalizations.delegate,
    CkbMaterialLocalizations.delegate,
    CkbCupertinoLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];
}
