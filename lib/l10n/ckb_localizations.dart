import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Flutter ships text for Arabic but not for Central Kurdish (Sorani, `ckb`), the
/// main language of this app. These three delegates give the framework's own
/// widgets what they need for it: the writing direction (right to left), and the
/// few words the framework itself shows - the Copy / Paste / Select all bar over
/// selected text, the tooltips of the back and close buttons, and the labels a
/// screen reader reads out. Everything else in the app comes from the app's own
/// translations (`lib/l10n/app_ckb.arb`).
///
/// The delegates answer for `ckb` only; every other language falls through to
/// Flutter's own `Global...Localizations`.
class CkbWidgetsLocalizations extends DefaultWidgetsLocalizations {
  const CkbWidgetsLocalizations();

  static const LocalizationsDelegate<WidgetsLocalizations> delegate = _CkbDelegate<WidgetsLocalizations>(
    CkbWidgetsLocalizations(),
  );

  @override
  TextDirection get textDirection => TextDirection.rtl;

  @override
  String get reorderItemUp => 'بەرزکردنەوە';
  @override
  String get reorderItemDown => 'دابەزاندن';
  @override
  String get reorderItemLeft => 'بۆ چەپ';
  @override
  String get reorderItemRight => 'بۆ ڕاست';
  @override
  String get reorderItemToEnd => 'بۆ کۆتایی';
  @override
  String get reorderItemToStart => 'بۆ سەرەتا';
  @override
  String get searchResultsFound => 'ئەنجامی گەڕان دۆزرایەوە';
  @override
  String get noResultsFound => 'هیچ ئەنجامێک نەدۆزرایەوە';
  @override
  String get copyButtonLabel => 'لەبەرگرتنەوە';
  @override
  String get cutButtonLabel => 'بڕین';
  @override
  String get pasteButtonLabel => 'لکاندن';
  @override
  String get selectAllButtonLabel => 'هەمووی هەڵبژێرە';
  @override
  String get lookUpButtonLabel => 'گەڕان';
  @override
  String get searchWebButtonLabel => 'گەڕان لە ئینتەرنێت';
  @override
  String get shareButtonLabel => 'هاوبەشکردن';
  @override
  String get radioButtonUnselectedLabel => 'هەڵنەبژێردراوە';
}

class CkbMaterialLocalizations extends DefaultMaterialLocalizations {
  const CkbMaterialLocalizations();

  static const LocalizationsDelegate<MaterialLocalizations> delegate =
      _CkbDelegate<MaterialLocalizations>(CkbMaterialLocalizations());

  /// Arabic-script text is taller than Latin text; the framework makes room for it.
  @override
  ScriptCategory get scriptCategory => ScriptCategory.tall;

  @override
  String get backButtonTooltip => 'گەڕانەوە';
  @override
  String get closeButtonTooltip => 'داخستن';
  @override
  String get closeButtonLabel => 'داخستن';
  @override
  String get moreButtonTooltip => 'زیاتر';
  @override
  String get deleteButtonTooltip => 'سڕینەوە';
  @override
  String get clearButtonTooltip => 'سڕینەوەی نووسین';
  @override
  String get showMenuTooltip => 'نیشاندانی لیست';
  @override
  String get openAppDrawerTooltip => 'کردنەوەی لیستی ڕێنیشاندەر';
  @override
  String get nextPageTooltip => 'پەڕەی دواتر';
  @override
  String get previousPageTooltip => 'پەڕەی پێشوو';
  @override
  String get firstPageTooltip => 'یەکەم پەڕە';
  @override
  String get lastPageTooltip => 'کۆتا پەڕە';
  @override
  String get drawerLabel => 'لیستی ڕێنیشاندەر';
  @override
  String get popupMenuLabel => 'لیستی هەڵقوڵاو';
  @override
  String get dialogLabel => 'پەنجەرە';
  @override
  String get alertDialogLabel => 'ئاگادارکردنەوە';
  @override
  String get searchFieldLabel => 'گەڕان';
  @override
  String get currentDateLabel => 'ئەمڕۆ';
  @override
  String get selectedDateLabel => 'هەڵبژێردراو';
  @override
  String get bottomSheetLabel => 'پەنجەرەی خوارەوە';
  @override
  String scrimOnTapHint(String modalRouteContentName) => 'داخستنی $modalRouteContentName';
  @override
  String tabLabel({required int tabIndex, required int tabCount}) {
    assert(tabIndex >= 1);
    assert(tabCount >= 1);
    return 'تاب $tabIndex لە $tabCount';
  }

  @override
  String get cancelButtonLabel => 'هەڵوەشاندنەوە';
  @override
  String get continueButtonLabel => 'بەردەوامبوون';
  @override
  String get saveButtonLabel => 'پاشەکەوتکردن';
  @override
  String get okButtonLabel => 'باشە';
  @override
  String get copyButtonLabel => 'لەبەرگرتنەوە';
  @override
  String get cutButtonLabel => 'بڕین';
  @override
  String get pasteButtonLabel => 'لکاندن';
  @override
  String get selectAllButtonLabel => 'هەمووی هەڵبژێرە';
  @override
  String get lookUpButtonLabel => 'گەڕان';
  @override
  String get searchWebButtonLabel => 'گەڕان لە ئینتەرنێت';
  @override
  String get shareButtonLabel => 'هاوبەشکردن';
  @override
  String get anteMeridiemAbbreviation => 'پ.ن';
  @override
  String get postMeridiemAbbreviation => 'د.ن';
  @override
  String get modalBarrierDismissLabel => 'داخستن';
  @override
  String get menuDismissLabel => 'داخستنی لیست';
  @override
  String get refreshIndicatorSemanticLabel => 'نوێکردنەوە';
  @override
  String get expandedIconTapHint => 'کۆکردنەوە';
  @override
  String get collapsedIconTapHint => 'فراوانکردن';
  @override
  String get scrimLabel => 'پشتەوە';
}

class CkbCupertinoLocalizations extends DefaultCupertinoLocalizations {
  const CkbCupertinoLocalizations();

  static const LocalizationsDelegate<CupertinoLocalizations> delegate =
      _CkbDelegate<CupertinoLocalizations>(CkbCupertinoLocalizations());

  @override
  String get anteMeridiemAbbreviation => 'پ.ن';
  @override
  String get postMeridiemAbbreviation => 'د.ن';
  @override
  String get todayLabel => 'ئەمڕۆ';
  @override
  String get alertDialogLabel => 'ئاگادارکردنەوە';
  @override
  String get cutButtonLabel => 'بڕین';
  @override
  String get copyButtonLabel => 'لەبەرگرتنەوە';
  @override
  String get pasteButtonLabel => 'لکاندن';
  @override
  String get clearButtonLabel => 'سڕینەوە';
  @override
  String get selectAllButtonLabel => 'هەمووی هەڵبژێرە';
  @override
  String get lookUpButtonLabel => 'گەڕان';
  @override
  String get searchWebButtonLabel => 'گەڕان لە ئینتەرنێت';
  @override
  String get shareButtonLabel => 'هاوبەشکردن';
  @override
  String get searchTextFieldPlaceholderLabel => 'گەڕان';
  @override
  String get modalBarrierDismissLabel => 'داخستن';
  @override
  String get menuDismissLabel => 'داخستنی لیست';
  @override
  String get cancelButtonLabel => 'هەڵوەشاندنەوە';
  @override
  String get backButtonLabel => 'گەڕانەوە';
  @override
  String get noSpellCheckReplacementsLabel => 'هیچ جێگرەوەیەک نەدۆزرایەوە';
}

/// Answers for Central Kurdish only, with one ready-made object.
class _CkbDelegate<T> extends LocalizationsDelegate<T> {
  const _CkbDelegate(this._value);

  final T _value;

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'ckb';

  @override
  Future<T> load(Locale locale) => SynchronousFuture<T>(_value);

  @override
  bool shouldReload(_CkbDelegate<T> old) => false;
}
