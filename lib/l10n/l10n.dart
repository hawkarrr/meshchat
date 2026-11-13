import 'package:flutter/widgets.dart';

import 'app_localizations.dart';

export 'app_language.dart';
export 'app_localizations.dart';

/// `context.l10n.settingsTitle`: the app's text in the language being shown.
extension AppLocalizationsContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// English text, for code that is not given a language (tests, a service built
/// on its own).
AppLocalizations englishStrings() => lookupAppLocalizations(const Locale('en'));
