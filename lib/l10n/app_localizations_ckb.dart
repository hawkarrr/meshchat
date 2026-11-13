// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Central Kurdish (`ckb`).
class AppLocalizationsCkb extends AppLocalizations {
  AppLocalizationsCkb([String locale = 'ckb']) : super(locale);

  @override
  String authorUnknown(String tag) {
    return 'نەناسراو $tag';
  }

  @override
  String get actEditingGone => 'ئەو نامەیەی دەستکاریت دەکرد نەماوە.';

  @override
  String get actReplyingGone => 'ئەو نامەیەی وەڵامت دەدایەوە سڕایەوە.';

  @override
  String get actNoTextToCopy => 'هیچ نووسینێک نییە بۆ لەبەرگرتنەوە.';

  @override
  String get actCopied => 'لەبەرگیرایەوە';

  @override
  String actCopiedMany(int count) {
    return '$count نامە لەبەرگیرانەوە';
  }

  @override
  String get actSaveTitle => 'لە گەلەریەکەت پاشەکەوت بکرێت؟';

  @override
  String get actSaveBodyPicture =>
      'دەمەتەقێ ئەم وێنەیە لە هەڵگری تایبەتی خۆیدا دەپارێزێت. پاشەکەوتکردن لەبەرگیراوەیەک دەخاتە گەلەری مۆبایلەکەتەوە، کە ئەپەکانی تر دەیبینن و تەنانەت ئەگەر نامەکەش لێرە بسڕیتەوە دەمێنێتەوە. ڕەنگە مۆبایلەکەت داوای ڕێگەپێدان بکات بۆ پاشەکەوتکردنی فایل.';

  @override
  String get actSaveBodyVideo =>
      'دەمەتەقێ ئەم ڤیدیۆیە لە هەڵگری تایبەتی خۆیدا دەپارێزێت. پاشەکەوتکردن لەبەرگیراوەیەک دەخاتە گەلەری مۆبایلەکەتەوە، کە ئەپەکانی تر دەیبینن و تەنانەت ئەگەر نامەکەش لێرە بسڕیتەوە دەمێنێتەوە. ڕەنگە مۆبایلەکەت داوای ڕێگەپێدان بکات بۆ پاشەکەوتکردنی فایل.';

  @override
  String actSaveBodyFiles(int count) {
    return 'دەمەتەقێ ئەم $count فایلە لە هەڵگری تایبەتی خۆیدا دەپارێزێت. پاشەکەوتکردن لەبەرگیراوەیەک دەخاتە گەلەری مۆبایلەکەتەوە، کە ئەپەکانی تر دەیبینن و تەنانەت ئەگەر نامەکەش لێرە بسڕیتەوە دەمێنێتەوە. ڕەنگە مۆبایلەکەت داوای ڕێگەپێدان بکات بۆ پاشەکەوتکردنی فایل.';
  }

  @override
  String get actSaved => 'لە گەلەریەکەت پاشەکەوت کرا';

  @override
  String actSavedMany(int count) {
    return '$count فایل لە گەلەریەکەت پاشەکەوت کران';
  }

  @override
  String actSavedSome(int saved, int total, String reason) {
    return '$saved لە $total پاشەکەوت کران. $reason';
  }

  @override
  String get actPinnedNote => 'جێگیرکرا. تەنها تۆ ئەم جێگیرکردنە دەبینیت.';

  @override
  String get actUnpinnedNote => 'جێگیرکردنەکە لابرا';

  @override
  String get actForwardPublicTitle => 'بنێردرێتەوە بۆ ژووری گشتی؟';

  @override
  String get actForwardPublicBody =>
      'هەموو کەسێکی نزیک دەتوانێت ئەوەی لەوێ دەینێریتەوە بیخوێنێتەوە، چیتر تایبەت نامێنێت، و ناوی ئەو کەسە پیشان دەدات کە نووسیویەتی. دوای شەش کاتژمێر لە مۆبایلەکان دەسڕێتەوە.';

  @override
  String get actForwardPublicAction => 'بە گشتی بینێرەوە';

  @override
  String get actTheChat => 'گفتوگۆکە';

  @override
  String actForwardedTo(String title) {
    return 'ناردرایەوە بۆ $title';
  }

  @override
  String actForwardedMany(int count, String title) {
    return '$count نامە ناردرانەوە بۆ $title';
  }

  @override
  String actForwardedSome(int sent, int total, String title) {
    return '$sent لە $total ناردرانەوە بۆ $title. ئەوانی تر نەتوانران بخوێنرێنەوە، یان فایلەکەیان تەواو نییە.';
  }

  @override
  String actNothingDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'هیچ شتێک نەسڕایەوە: ئەو نامانە پێشتر نەماون.',
      one: 'هیچ شتێک نەسڕایەوە: نامەکە پێشتر نەماوە.',
    );
    return '$_temp0';
  }

  @override
  String actDeletedUnsent(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'سڕانەوە. هێشتا نەنێردرابوون، بۆیە کەس وەریان ناگرێت.',
      one: 'سڕایەوە. هێشتا نەنێردرابوو، بۆیە کەس وەریناگرێت.',
    );
    return '$_temp0';
  }

  @override
  String actDeletedManyHere(int count) {
    return '$count نامە لەسەر ئەم مۆبایلە سڕانەوە.';
  }

  @override
  String get actDeletedHere => 'لەسەر ئەم مۆبایلە سڕایەوە.';

  @override
  String actDeletedAskedOthers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'لێرە سڕانەوە. مۆبایلەکانی تر کاتێک داواکارییەکە وەردەگرن لایاندەبەن.',
      one: 'لێرە سڕایەوە. مۆبایلەکانی تر کاتێک داواکارییەکە وەردەگرن لایدەبەن.',
    );
    return '$_temp0';
  }

  @override
  String actDeletedNeverSent(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'سڕانەوە. هیچ شتێک نەنێردرابوو، بۆیە کەسی تر هەرگیز وەریان ناگرێت.',
      one: 'سڕایەوە. هیچ شتێک نەنێردرابوو، بۆیە کەسی تر هەرگیز وەریناگرێت.',
    );
    return '$_temp0';
  }

  @override
  String actUnpinnedCount(int count) {
    return 'جێگیرکردنی $count لابرا';
  }

  @override
  String actPinnedCount(int count) {
    return '$count جێگیرکرا. تەنها تۆ ئەم جێگیرکردنانە دەبینیت.';
  }

  @override
  String get actSelectAll => 'هەمووی هەڵبژێرە';

  @override
  String get actFurtherBack =>
      'ئەو نامەیە لە پێشتر دایە لەوەی ئەم گفتوگۆیە پیشانی دەدات.';

  @override
  String pinnedListTitle(int count) {
    return '$count نامەی جێگیرکراو';
  }

  @override
  String get pinnedListNote =>
      'جێگیرکردنەکان تەنها هی تۆن: کەسی تر نایانبینێت.';

  @override
  String get pinnedListEmpty => 'هیچ شتێک جێگیر نەکراوە.';

  @override
  String get startupErrorTitle => 'دەمەتەقێ نەیتوانی دەست پێبکات';

  @override
  String get startupErrorBody =>
      'ئەپەکە نەیتوانی شوێنی هەڵگرتنی تایبەتی خۆی بکاتەوە یان کلیلەکانت باربکات. هیچ شتێک نەسڕاوەتەوە، و ناسنامەکەت هەرگیز تەنها لەبەر ئەوەی نەخوێندرایەوە ناگۆڕدرێت. دووبارە هەوڵ بدەرەوە؛ ئەگەر هەر سەرنەکەوت، مۆبایلەکە ڕیستارت بکە. وەک دوا چارە، سڕینەوە و دووبارە دامەزراندنی ئەپەکە شوێنە زیانلێکەوتووەکە پاک دەکاتەوە، بەڵام گفتوگۆکان و ناسنامەکەشت دەسڕێتەوە.';

  @override
  String get commonTryAgain => 'دووبارە هەوڵ بدەرەوە';

  @override
  String get commonCancel => 'هەڵوەشاندنەوە';

  @override
  String get commonOk => 'باشە';

  @override
  String get commonClose => 'داخستن';

  @override
  String get commonDone => 'تەواو';

  @override
  String get commonSave => 'پاشەکەوتکردن';

  @override
  String get commonDelete => 'سڕینەوە';

  @override
  String get commonRemove => 'لابردن';

  @override
  String get commonBack => 'گەڕانەوە';

  @override
  String get commonSearch => 'گەڕان';

  @override
  String get commonSend => 'ناردن';

  @override
  String get commonCopy => 'لەبەرگرتنەوە';

  @override
  String get commonShare => 'هاوبەشکردن';

  @override
  String get commonMore => 'زیاتر';

  @override
  String get commonYes => 'بەڵێ';

  @override
  String get commonNo => 'نەخێر';

  @override
  String get commonOn => 'کراوە';

  @override
  String get commonOff => 'کوژاوە';

  @override
  String get commonYou => 'تۆ';

  @override
  String get commonLoading => 'بار دەبێت…';

  @override
  String get actReply => 'وەڵامدانەوە';

  @override
  String get actCopyCaption => 'لەبەرگرتنەوەی ژێرنووس';

  @override
  String get actCopyText => 'لەبەرگرتنەوەی نووسین';

  @override
  String get actForward => 'ناردنەوە';

  @override
  String get actSaveToGallery => 'پاشەکەوتکردن لە گەلەری';

  @override
  String get actSendAgain => 'دووبارە بنێرە';

  @override
  String get actUnpin => 'لابردنی جێگیرکردن';

  @override
  String get actPin => 'جێگیرکردن';

  @override
  String get actEdit => 'دەستکاری';

  @override
  String get actSelect => 'هەڵبژاردن';

  @override
  String get actDetails => 'وردەکاری';

  @override
  String deleteTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count نامە بسڕدرێنەوە؟',
      one: 'نامەکە بسڕدرێتەوە؟',
    );
    return '$_temp0';
  }

  @override
  String deleteForMeNote(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '«سڕینەوە بۆ من» نامەکان تەنها لەسەر ئەم مۆبایلە لادەبات. هەموو کەسێکی تر لەبەرگیراوەکەی خۆی دەهێڵێتەوە.',
      one: '«سڕینەوە بۆ من» نامەکە تەنها لەسەر ئەم مۆبایلە لادەبات. هەموو کەسێکی تر لەبەرگیراوەکەی خۆی دەهێڵێتەوە.',
    );
    return '$_temp0';
  }

  @override
  String deleteEveryoneDirect(int count, String who) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '«سڕینەوە بۆ هەمووان» داوا لە مۆبایلی $who دەکات نامەکان لابەرێت. ئەمە تەنها داواکارییە: کاتێک دەگاتە مۆبایلەکەی کاردەکات (دەبێت لە ماوەی نزیکەی 12 کاتژمێردا بێتە ناو ڕادە). ئەو لەبەرگیراوەی کەسێک پاشەکەوتی کردووە یان وێنەی گرتووە ناگەیەنرێتێ.',
      one:
          '«سڕینەوە بۆ هەمووان» داوا لە مۆبایلی $who دەکات نامەکە لابەرێت. ئەمە تەنها داواکارییە: کاتێک دەگاتە مۆبایلەکەی کاردەکات (دەبێت لە ماوەی نزیکەی 12 کاتژمێردا بێتە ناو ڕادە). ئەو لەبەرگیراوەی کەسێک پاشەکەوتی کردووە یان وێنەی گرتووە ناگەیەنرێتێ.',
    );
    return '$_temp0';
  }

  @override
  String deleteEveryoneGroup(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '«سڕینەوە بۆ هەمووان» داوا لە مۆبایلی هەموو ئەندامێک دەکات نامەکان لابەرێت. ئەمە تەنها داواکارییە: کاتێک دەگاتە هەر مۆبایلێک کاردەکات، و ئەو مۆبایلەی لە ڕادە دەرەوەیە دواتر وەریدەگرێت، ئەگەر لە کاتی خۆیدا گەڕایەوە. ئەو لەبەرگیراوەی کەسێک پاشەکەوتی کردووە یان وێنەی گرتووە ناگەیەنرێتێ.',
      one: '«سڕینەوە بۆ هەمووان» داوا لە مۆبایلی هەموو ئەندامێک دەکات نامەکە لابەرێت. ئەمە تەنها داواکارییە: کاتێک دەگاتە هەر مۆبایلێک کاردەکات، و ئەو مۆبایلەی لە ڕادە دەرەوەیە دواتر وەریدەگرێت، ئەگەر لە کاتی خۆیدا گەڕایەوە. ئەو لەبەرگیراوەی کەسێک پاشەکەوتی کردووە یان وێنەی گرتووە ناگەیەنرێتێ.',
    );
    return '$_temp0';
  }

  @override
  String deleteEveryoneRoom(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '«سڕینەوە بۆ هەمووان» داوا لە هەر مۆبایلێکی نزیک دەکات کە ئەم نامانەی هەیە لایانببات. ئەمە تەنها داواکارییە: کاتێک دەگاتە هەر مۆبایلێک کاردەکات، و ئەو مۆبایلەی لە ڕادە دەرەوەیە دواتر وەریدەگرێت، ئەگەر لە کاتی خۆیدا گەڕایەوە. ئەو لەبەرگیراوەی کەسێک پاشەکەوتی کردووە یان وێنەی گرتووە ناگەیەنرێتێ.',
      one: '«سڕینەوە بۆ هەمووان» داوا لە هەر مۆبایلێکی نزیک دەکات کە ئەم نامەیەی هەیە لایببات. ئەمە تەنها داواکارییە: کاتێک دەگاتە هەر مۆبایلێک کاردەکات، و ئەو مۆبایلەی لە ڕادە دەرەوەیە دواتر وەریدەگرێت، ئەگەر لە کاتی خۆیدا گەڕایەوە. ئەو لەبەرگیراوەی کەسێک پاشەکەوتی کردووە یان وێنەی گرتووە ناگەیەنرێتێ.',
    );
    return '$_temp0';
  }

  @override
  String get deleteEveryoneOwnOnly =>
      '«سڕینەوە بۆ هەمووان» تەنها بۆ نامەکانی خۆت دەکرێت.';

  @override
  String get deleteEveryoneOwnOrAdmin =>
      '«سڕینەوە بۆ هەمووان» تەنها بۆ نامەکانی خۆت دەکرێت (و بۆ بەڕێوەبەری گرووپەکە).';

  @override
  String get deleteForMe => 'سڕینەوە بۆ من';

  @override
  String get deleteForEveryone => 'سڕینەوە بۆ هەمووان';

  @override
  String get selCancel => 'هەڵوەشاندنەوەی هەڵبژاردن';

  @override
  String selCount(int count) {
    return '$count هەڵبژێردراوە';
  }

  @override
  String get quoteOriginalDeleted => 'نامە ڕەسەنەکە سڕاوەتەوە';

  @override
  String forwardedFrom(String name) {
    return 'ناردراوەتەوە لە $name';
  }

  @override
  String pinnedOf(int index, int count) {
    return 'نامەی جێگیرکراو $index لە $count';
  }

  @override
  String get pinnedMessage => 'نامەی جێگیرکراو';

  @override
  String get pinnedAll => 'هەموو نامە جێگیرکراوەکان';

  @override
  String delWaiting(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'چاوەڕێی مۆبایلی $name دەکرێت بۆ دووپاتکردنەوەی $count نامەی سڕاوە. هەر کە لە ڕادەدا بوویت ئەنجام دەدرێت.',
      one:
          'چاوەڕێی مۆبایلی $name دەکرێت بۆ دووپاتکردنەوەی نامەیەکی سڕاوە. هەر کە لە ڕادەدا بوویت ئەنجام دەدرێت.',
    );
    return '$_temp0';
  }

  @override
  String delExpired(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'مۆبایلی $name $count داواکاری سڕینەوەی لە کاتی خۆیدا پێنەگەیشت، بۆیە ڕەنگە ئەو نامانە هێشتا لەوێ بن.',
      one:
          'مۆبایلی $name داواکاری سڕینەوەی لە کاتی خۆیدا پێنەگەیشت، بۆیە ڕەنگە ئەو نامەیە هێشتا لەوێ بێت.',
    );
    return '$_temp0';
  }

  @override
  String get snippetUnreadable => 'نەتوانرا نامەکە بخوێنرێتەوە';

  @override
  String replyingTo(String name) {
    return 'وەڵامدانەوەی $name';
  }

  @override
  String get editMessageTitle => 'دەستکاریکردنی نامە';

  @override
  String get cancelEditing => 'هەڵوەشاندنەوەی دەستکاری';

  @override
  String get cancelReply => 'هەڵوەشاندنەوەی وەڵام';

  @override
  String get bubbleUndecryptable =>
      'نەتوانرا شفرەی ئەم نامەیە لابدرێت یان پشتڕاست بکرێتەوە، بۆیە پیشان نەدرا. ڕەنگە تێکچووبێت، دەستکاری کرابێت، یان بۆ کلیلێکی تر شفرە کرابێت.';

  @override
  String get bubblePicture => 'وێنە';

  @override
  String get bubbleVideo => 'ڤیدیۆ';

  @override
  String get bubbleVoice => 'نامەی دەنگی';

  @override
  String get bubbleEdited => 'دەستکاریکراوە';

  @override
  String bubbleViaRelays(int hops) {
    String _temp0 = intl.Intl.pluralLogic(
      hops,
      locale: localeName,
      other: 'بە $hops گواستنەوە',
      one: 'بە یەک گواستنەوە',
    );
    return '$_temp0';
  }

  @override
  String get bubbleNotDelivered => 'نەتوانرا ئەم نامەیە بگەیەنرێت.';

  @override
  String composerCouldNotSend(String error) {
    return 'نەتوانرا بنێردرێت: $error';
  }

  @override
  String get attachSendPicture => 'وێنەیەک بنێرە';

  @override
  String get attachTakePhoto => 'وێنەیەک بگرە';

  @override
  String get attachChoosePhoto => 'لە وێنەکانتەوە هەڵبژێرە';

  @override
  String get attachPictureNote =>
      'وێنەکان دەبچووککرێنەوە بۆ چەند دەیەک کیلۆبایت تا بتوانن بە بلوتوس بپەڕنەوە، و تەنها بۆ ئەو کەسانە دەنێردرێن کە لەم گفتوگۆیەدان.';

  @override
  String get attachSendVideo => 'ڤیدیۆیەک بنێرە';

  @override
  String get attachRecordVideo => 'ڤیدیۆیەکی کورت تۆمار بکە';

  @override
  String get attachChooseVideo => 'ڤیدیۆیەک هەڵبژێرە';

  @override
  String attachVideoNote(String limit) {
    return 'ڤیدیۆ ناچووککرێتەوە: تەنها کلیپێکی زۆر کورت و کوالیتی نزم (تا $limit) دەتوانێت بە بلوتوس بپەڕێتەوە، و دەکرێت چەند خولەکێک بخایەنێت. گەورەترەکان ڕەت دەکرێنەوە. دەتوانیت سنوورەکە لە ڕێکخستنەکان > شوێنی هەڵگرتن بگۆڕیت.';
  }

  @override
  String get composerAllowPicture => 'ڕێگە بدە بۆ ناردنی وێنە.';

  @override
  String composerOpenCameraFailed(String error) {
    return 'نەتوانرا کامێرا بکرێتەوە: $error';
  }

  @override
  String composerOpenPhotosFailed(String error) {
    return 'نەتوانرا وێنەکان بکرێنەوە: $error';
  }

  @override
  String composerOpenVideosFailed(String error) {
    return 'نەتوانرا ڤیدیۆکان بکرێنەوە: $error';
  }

  @override
  String composerPictureNotPrepared(String error) {
    return 'نەتوانرا ئەم وێنەیە ئامادە بکرێت: $error';
  }

  @override
  String get composerAllowVideo => 'ڕێگە بدە بۆ ناردنی ڤیدیۆ.';

  @override
  String composerVideoTooBig(String size, String limit, String max) {
    return 'قەبارەی ئەم ڤیدیۆیە: $size. بە بلوتوس ڤیدیۆ زۆرترین $limit دەتوانێت بێت (دەتوانیت لە ڕێکخستنەکان > شوێنی هەڵگرتن بیبەرزی بکەیتەوە، تا $max). کلیپێکی کورتتر یان بچووکتر هەڵبژێرە.';
  }

  @override
  String get composerAllowMic =>
      'ڕێگە بە مایکرۆفۆن بدە بۆ تۆمارکردنی نامەی دەنگی.';

  @override
  String composerRecordFailed(String error) {
    return 'نەتوانرا تۆمارکردن دەستپێبکات: $error';
  }

  @override
  String get composerVoiceTooShort =>
      'ئەمە زۆر کورت بوو بۆ نامەیەکی دەنگی. مایکرۆفۆنەکە کەمێک زیاتر بکراوە بهێڵەرەوە.';

  @override
  String composerBytesCounter(int bytes, int max) {
    return '$bytes / $max بایت';
  }

  @override
  String get composerTooLong => 'زۆر درێژە';

  @override
  String get composerSaveChanges => 'پاشەکەوتکردنی گۆڕانکارییەکان';

  @override
  String get composerRecord => 'نامەیەکی دەنگی تۆمار بکە';

  @override
  String get composerDiscard => 'تۆمارەکە فڕێبدە';

  @override
  String get composerSendVoice => 'نامە دەنگییەکە بنێرە';

  @override
  String get previewSendPicture => 'ئەم وێنەیە بنێردرێت؟';

  @override
  String get previewSendVideo => 'ئەم ڤیدیۆیە بنێردرێت؟';

  @override
  String get previewCaptionHint => 'ژێرنووسێک زیاد بکە (ئیختیاری)';

  @override
  String get previewVideoNote =>
      'بە بلوتوس دەنێردرێت، تەنها بۆ ئەو کەسانەی لەم گفتوگۆیەدان، و دەکرێت چەند خولەکێک بخایەنێت — زیاتریش کاتێک پێویستە بە مۆبایلەکانی تردا تێپەڕێت. دەبێت کەسەکە لە ڕادەدا بمێنێتەوە، لەگەڵ ئەپەکەی کراوە، تا دەگات.';

  @override
  String get chatFallbackLower => 'گفتوگۆ';

  @override
  String get chatSearchTooltip => 'گەڕان لەم گفتوگۆیەدا';

  @override
  String get chatFallbackGroup => 'گرووپ';

  @override
  String get chatFallbackChat => 'گفتوگۆ';

  @override
  String chatGroupMembers(int count) {
    return '$count ئەندام';
  }

  @override
  String chatGroupMembersNearby(int count, int nearby) {
    return '$count ئەندام · $nearby نزیک';
  }

  @override
  String get chatInvitation => 'بانگهێشتنامە';

  @override
  String get chatGroupDetails => 'وردەکاری گرووپ';

  @override
  String get chatVerifiedContact => 'پەیوەندی پشتڕاستکراو';

  @override
  String get chatVerifyContact => 'ئەم پەیوەندییە پشتڕاست بکەرەوە';

  @override
  String get chatTheOtherPerson => 'کەسەکەی تر';

  @override
  String get composerHint => 'نامە';

  @override
  String get chatRemovedFromGroup => 'تۆ لەم گرووپە لابرایت';

  @override
  String get chatYouBlocked => 'تۆ ئەم کەسەت بلۆک کردووە';

  @override
  String get chatEmptyGroup =>
      'هێشتا نامە نییە. هەموو شتێک لێرە بە کلیلی گرووپەکە شفرە کراوە و دەگاتە هەموو ئەندامێک، ئێستا یان کاتێک جاری داهاتوو دەکەوێتە ڕادەوە.';

  @override
  String get chatEmptyDirect =>
      'هێشتا نامە نییە. نامەکان بە شفرەکردنی کۆتایی-بۆ-کۆتایی پارێزراون، و ئەگەر مۆبایلی ئەوی تر لە ڕادە دەرەوە بوو لێرە چاوەڕێ دەکەن.';

  @override
  String get chatToday => 'ئەمڕۆ';

  @override
  String get stripWaitingForKey =>
      'چاوەڕێی کلیلی شفرەکردنی ئەم کەسەین. یەکەم جار کە لە ڕادەی ئەودا بیت خۆکارانە دەگات.';

  @override
  String get stripDirect => 'ڕاستەوخۆ پەیوەندیدارە. نامەکان یەکسەر دەگەیەنرێن.';

  @override
  String stripRelayed(int hops) {
    return 'دەگەیت پێی لە ڕێگەی مۆبایلەکانی ترەوە ($hops هەنگاو). نامەکان دەگوازرێنەوە، هێشتا بە شفرەکردنی کۆتایی-بۆ-کۆتایی.';
  }

  @override
  String get stripOffline =>
      'ئێستا ناگەیت پێی. نامەکان لەسەر ئەم مۆبایلە چاوەڕێ دەکەن و هەر کە ئەم کەسە (یان مۆبایلێک بتوانێت بگات پێی) بکەوێتە ڕادەوە دەنێردرێن، تا 12 کاتژمێر.';

  @override
  String fwdTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ناردنەوەی $count نامە بۆ…',
      one: 'ناردنەوە بۆ…',
    );
    return '$_temp0';
  }

  @override
  String get fwdSearchHint => 'بگەڕێ لە گفتوگۆکان';

  @override
  String get fwdNoTargets =>
      'هێشتا هیچ گفتوگۆیەک نییە بۆ ناردنەوە. سەرەتا گفتوگۆیەک لەگەڵ کەسێکی نزیک دەستپێبکە.';

  @override
  String fwdNoMatch(String query) {
    return 'هیچ گفتوگۆیەک لەگەڵ \"$query\" ناگونجێت.';
  }

  @override
  String get fwdPrivateChat => 'گفتوگۆی تایبەت';

  @override
  String get fwdPublicRoom =>
      'ژووری گشتی · هەموو کەسێکی نزیک دەتوانێت بیخوێنێتەوە';

  @override
  String get commonClear => 'پاککردنەوە';

  @override
  String searchInTitle(String title) {
    return 'گەڕان لە $title';
  }

  @override
  String get searchPictures => 'وێنەکان';

  @override
  String get searchVideos => 'ڤیدیۆکان';

  @override
  String get searchVoice => 'دەنگ';

  @override
  String get searchFromMe => 'لە منەوە';

  @override
  String get searchEmptyBody =>
      'وشەیەک بنووسە، یان وێنەکان، ڤیدیۆکان یان دەنگ هەڵبژێرە بۆ بینینی ئەوانە تەنها. لە نامە سڕاوەکان ناگەڕێت: نەماون.';

  @override
  String get searchNoMatch => 'هیچ نامەیەک لەم گفتوگۆیەدا ناگونجێت.';

  @override
  String get detailUnknownPhone => 'مۆبایلی نەناسراو';

  @override
  String get detailAnyMoment => 'هەر ئێستا';

  @override
  String detailInMinutes(int minutes) {
    return 'دوای $minutes خولەک';
  }

  @override
  String detailInHours(int hours) {
    return 'دوای $hours کاتژمێر';
  }

  @override
  String detailInHoursMinutes(int hours, int minutes) {
    return 'دوای $hours کاتژمێر و $minutes خولەک';
  }

  @override
  String get detailTitle => 'وردەکاری نامە';

  @override
  String get detailFrom => 'لەلایەن';

  @override
  String get detailDirection => 'ئاراستە';

  @override
  String get detailSentByYou => 'لەلایەن تۆوە نێردراوە';

  @override
  String get detailReceived => 'وەرگیراوە';

  @override
  String get detailType => 'جۆر';

  @override
  String get detailSize => 'قەبارە';

  @override
  String get detailStatus => 'دۆخ';

  @override
  String get detailConfirmedBy => 'دووپاتکراوەتەوە لەلایەن';

  @override
  String detailConfirmedOf(int done, int total) {
    return '$done لە $total ئەندام';
  }

  @override
  String get detailHasIt => 'هەیەتی';

  @override
  String get detailNotYet => 'هێشتا نا';

  @override
  String get detailSentTheirClock => 'نێردراوە (کاتژمێری ئەوان)';

  @override
  String get detailWrittenSaved => 'نووسراوە و پاشەکەوتکراوە';

  @override
  String get detailReceivedSaved => 'وەرگیراوە و پاشەکەوتکراوە';

  @override
  String get detailEdited => 'دەستکاریکراوە';

  @override
  String get detailForwardedFrom => 'ناردراوەتەوە لە';

  @override
  String get detailReplyTo => 'وەڵام بۆ';

  @override
  String get detailReplyDeleted => 'نامەیەک کە سڕاوەتەوە';

  @override
  String get detailPinned => 'جێگیرکراو';

  @override
  String get detailPinnedValue => 'بەڵێ — تەنها لەسەر ئەم مۆبایلە';

  @override
  String get detailDisappears => 'دەسڕێتەوە';

  @override
  String detailDisappearsValue(String when, String remaining) {
    return '$when ($remaining). نامەکانی ژووری گشتی شەش کاتژمێر دوای گەیشتنیان لەسەر ئەم مۆبایلە دەسڕدرێنەوە.';
  }

  @override
  String get detailReceiptPath => 'ڕێگای ڕەزامەندی وەرگرتن';

  @override
  String get detailRoute => 'ڕێگا';

  @override
  String detailRadioHops(int count) {
    return '$count هەنگاوی ڕادیۆیی';
  }

  @override
  String detailPassedThrough(int hops) {
    String _temp0 = intl.Intl.pluralLogic(
      hops,
      locale: localeName,
      other: 'بە $hops گواستنەوەدا تێپەڕیوە',
      one: 'بە یەک گواستنەوەدا تێپەڕیوە',
    );
    return '$_temp0';
  }

  @override
  String get detailNote => 'تێبینی';

  @override
  String get detailClockSkew =>
      'کاتژمێری نێرەر زیاتر لە 10 خولەک لە کاتژمێری تۆ جیاوازە.';

  @override
  String get detailProblem => 'کێشە';

  @override
  String get detailMessageId => 'ناسنامەی نامە';

  @override
  String get galDenied =>
      'ڕێگە بە دەمەتەقێ نەدرا بۆ زیادکردن بۆ گەلەریەکەت. دەتوانیت لە ڕێکخستنەکانی مۆبایلەکەت ڕێگەی پێبدەیت.';

  @override
  String get galNoSpace =>
      'شوێنی پێویست لەسەر ئەم مۆبایلە نییە بۆ پاشەکەوتکردنی.';

  @override
  String get galUnsupported =>
      'ئەم مۆبایلە ناتوانێت ئەم جۆرە فایلە لە گەلەریدا پاشەکەوت بکات.';

  @override
  String get galFailed => 'نەتوانرا لە گەلەریدا پاشەکەوت بکرێت.';

  @override
  String get galPictureGone => 'ئەم وێنەیە چیتر لەسەر ئەم مۆبایلە نەماوە.';

  @override
  String get galVideoGone =>
      'ئەم ڤیدیۆیە ناتوانرێت لەم مۆبایلەوە پاشەکەوت بکرێت.';

  @override
  String get galVoice =>
      'نامە دەنگییەکان ناتوانرێن لە گەلەریدا پاشەکەوت بکرێن.';

  @override
  String get imgUnreadable =>
      'ئەو فایلە وێنەیەک نییە کە ئەم مۆبایلە بتوانێت بیخوێنێتەوە.';

  @override
  String get imgTooDetailed => 'ئەم وێنەیە زۆر وردە بۆ ناردن بە بلوتوس.';

  @override
  String get voiceMicOff => 'مایکرۆفۆن بۆ دەمەتەقێ کوژێنراوەتەوە.';

  @override
  String get radarListening => 'گوێ لە کەسانی نزیک دەگرێت';

  @override
  String get commonStop => 'وەستاندن';

  @override
  String get diagRunAgain => 'دووبارە بیکە';

  @override
  String get diagRun => 'تاقیکردنەوە بکە';

  @override
  String get diagReportCopied => 'ڕاپۆرت لەبەرگیرایەوە';

  @override
  String get diagCopyReport => 'لەبەرگرتنەوەی ڕاپۆرت';

  @override
  String get diagLogTitle => 'تۆماری چالاکی';

  @override
  String get diagLogNote =>
      'تەنها لە بیرگەدا دەمێنێتەوە؛ بە داخستنی ئەپەکە دەسڕێتەوە';

  @override
  String get diagIntroTitle => 'بپشکنە بلوتوس بەڕاستی کار دەکات';

  @override
  String get diagIntroBody =>
      'باشترین شێوە ئەوەیە بە دوو مۆبایلی تەنیشت یەک، هەردووکیان دەمەتەقێ کاردەکەن و بلوتوسیان کراوەیە. سەرەتا وای-فای و داتای مۆبایل بکوژێنەرەوە بۆ سەلماندنی هیچ شتێک پێویستی بە ئینتەرنێت نییە. تاقیکردنەوەکە نزیکەی نیو خولەک دەخایەنێت و پێت دەڵێت چی چاک بکەیتەوە ئەگەر هەنگاوێک شکستی هێنا.';

  @override
  String get diagPass => 'هەموو ئەوەی دەکرا تاقی بکرێتەوە سەرکەوتوو بوو';

  @override
  String get diagPassBody =>
      'ئەم مۆبایلانە یەکتریان دۆزییەوە، ناسنامەکانیان سەلماند و داتایان بە بلوتوس ئاڵوگۆڕ کرد.';

  @override
  String get diagWarn => 'کار دەکات، بەڵام شتێک هەیە سەیر بکرێت';

  @override
  String get diagWarnBody =>
      'هیچ شتێک شکستی نەهێنا، بەڵام لانیکەم یەک هەنگاو نەتوانرا بە تەواوی تاقی بکرێتەوە یان کێشەی بۆ دروست بوو. خوارەوە ببینە.';

  @override
  String get diagFail => 'کێشەیەک دۆزرایەوە';

  @override
  String get diagFailBody =>
      'ئامۆژگارییەکەی ژێر هەنگاوە شکستخواردووەکە جێبەجێ بکە، پاشان تاقیکردنەوەکە دووبارە بکە.';

  @override
  String get diagNoResult => 'ئەنجام نییە';

  @override
  String get diagLimitsTitle => 'سەرکەوتن چی دەگەیەنێت و چی ناگەیەنێت';

  @override
  String get diagLimitsBody =>
      'سەرکەوتن واتە ئەم دوو مۆبایلە، لە ئێستادا، یەکتریان دۆزییەوە، پەیوەندییان کرد، یەکتریان سەلماند و داتایان بە هەردوو ئاراستەدا گواستەوە، لەوانە نامەی زۆر گەورە بۆ یەک پاکێتی بلوتوس. ڕادە، بەکارهێنانی باتری، یان ڕەفتاری مۆدێلەکانی تر ناپێوێت، و گواستنەوە لە ڕێگەی مۆبایلی سێیەمەوە سێ مۆبایل پێویستە بۆ تاقیکردنەوە. مۆبایلەکان لە کوالیتی بلوتوسدا زۆر جیاوازن، بۆیە لەگەڵ ئەو مۆدێلانە تاقی بکەرەوە کە بەکاریان دەهێنیت.';

  @override
  String get diagLogCopied => 'تۆمار لەبەرگیرایەوە';

  @override
  String get diagLogWarn =>
      'تۆمارەکە لەوانەیە ناونیشانی بلوتوسی مۆبایلە دەوروبەرەکانت لەخۆ بگرێت. پێش هاوبەشکردن بیپشکنە. هەرگیز کلیل یان دەقی نامە لەخۆ ناگرێت.';

  @override
  String get diagLogEmpty => 'هێشتا هیچ تۆمار نەکراوە.';

  @override
  String get stNothingToClean =>
      'هیچ نییە بۆ پاککردنەوە: هەموو نامە گشتییەکان کەمتر لە شەش کاتژمێر تەمەنیانە.';

  @override
  String stRemovedPublic(int count) {
    return '$count نامەی گشتی لابران.';
  }

  @override
  String get stDeleteMediaTitle =>
      'هەموو وێنە، نامەی دەنگی و ڤیدیۆکان بسڕدرێنەوە؟';

  @override
  String get stDeleteMediaBody =>
      'لەگەڵ نامەکانیان لەسەر ئەم مۆبایلە لادەبرێن. کەسی تر ئاگادار ناکرێتەوە و مۆبایلەکانی تر لەبەرگیراوەکانیان دەهێڵنەوە. ئەمە ناگەڕێتەوە.';

  @override
  String get stDeleteMediaAction => 'بیانسڕەوە';

  @override
  String get stNothingToDelete => 'هیچ نەبوو بۆ سڕینەوە.';

  @override
  String stDeletedMedia(int count) {
    return '$count نامە لەگەڵ فایلەکانیان سڕانەوە.';
  }

  @override
  String get stMessages => 'نامەکان';

  @override
  String get stMedia => 'وێنە، نامەی دەنگی و ڤیدیۆ';

  @override
  String stFiles(int count) {
    return '$count فایل';
  }

  @override
  String get stDatabase => 'بنکەی داتای نامەکان';

  @override
  String get stPublic => 'گفتوگۆ گشتییەکان';

  @override
  String stMessagesCount(int count) {
    return '$count نامە';
  }

  @override
  String get stPublicNoteNever =>
      'شەش کاتژمێر دوای گەیشتنیان لەسەر ئەم مۆبایلە لادەبرێن. هێشتا هیچ لانەبراوە.';

  @override
  String stPublicNote(String ago, int removed) {
    return 'شەش کاتژمێر دوای گەیشتنیان لەسەر ئەم مۆبایلە لادەبرێن. دوایین پاککردنەوە $ago، $removed لابرا.';
  }

  @override
  String get stVideoLimit => 'گەورەترین ڤیدیۆ کە دەینێریت';

  @override
  String stVideoLimitBody(String max) {
    return 'ڤیدیۆ ناچووککرێتەوە، بۆیە تەنها کلیپێکی زۆر کورت دەگونجێت. گەورەترەکان ڕەت دەکرێنەوە پێش ئەوەی هیچ بنێردرێت. ڤیدیۆی گەورەتر زۆر زیاتر لە بلوتوسدا دەخایەنێت، و ڤیدیۆ هەرگیز بۆ ژووری گشتی نانێردرێت. ئەو ڤیدیۆیانەی وەریدەگریت تا $max قبوڵ دەکرێن.';
  }

  @override
  String get stCleanNow => 'ئێستا گفتوگۆ گشتییەکان پاک بکەرەوە';

  @override
  String get stCleanNowBody =>
      'خۆیان بە خۆیان پاک دەبنەوە، نزیکەی هەر خولەکێک جارێک لە کاتی کارکردنی ئەپەکە، و کاتێک دەست پێدەکات. گفتوگۆ تایبەتەکان و گرووپەکان هەرگیز دەست لێ نادرێن.';

  @override
  String get stDeleteMediaTile => 'سڕینەوەی هەموو وێنە، نامەی دەنگی و ڤیدیۆکان';

  @override
  String get stDeleteMediaTileBody =>
      'زۆرترین شوێن بەتاڵ دەکاتەوە. ئەو نامانەی هەڵیانگرتبوو ئەوانیش دەڕۆن.';

  @override
  String get stFooter =>
      'بۆ لابردنی نامە کۆنەکان بە شێوەی خۆکار، «هێشتنەوەی نامەکان» لە ڕێکخستنەکان > تایبەتمەندی و پاراستن بەکاربهێنە. نامە و فایلەکان بەبێ شفرەکردنی خۆیان هەڵدەگیرێن: پشت دەبەستن بە قفڵی شاشە و شفرەکردنی دیسکی مۆبایلەکەت.';

  @override
  String get nearbyTitle => 'نزیک';

  @override
  String get nearbyVisible => 'بۆ ئەوانی تر دیارە';

  @override
  String get nearbySearching => 'گەڕان';

  @override
  String get nearbyScanningNow => 'ئێستا دەگەڕێت';

  @override
  String get nearbyBetweenScans => 'لە نێوان گەڕانەکان';

  @override
  String get nearbyStopped => 'وەستاوە';

  @override
  String get nearbyHowHard => 'چەند بە توندی بگەڕێیت';

  @override
  String get nearbyRunSelfTest => 'تاقیکردنەوەی بلوتوس بکە';

  @override
  String nearbyConnected(int count) {
    return 'مۆبایلە پەیوەندیدارەکان ($count)';
  }

  @override
  String get nearbyNoLinks =>
      'ئێستا هیچ پەیوەندییەکی بلوتوس نییە. پەیوەندییەکان لێرە دەردەکەون هەر کە مۆبایلێکی نزیک دەدۆزرێتەوە، پاشان «پشتڕاست دەکرێتەوە» پیشان دەدەن تا ناسنامەکەی دەسەلمێنێت.';

  @override
  String nearbyHeard(int count) {
    return 'ئامێرە بیستراوەکان ($count)';
  }

  @override
  String get nearbyNothingHeard =>
      'هێشتا هیچ نەبیستراوە. مۆبایلەکانی تر کە دەمەتەقێ کاردەکەن لە نزیکەی 10 مەتردا دەدۆزرێنەوە. هەردوو مۆبایلەکە پێویستیان بە بلوتوسی کراوە و ئەپی کراوەیە.';

  @override
  String get nearbyFootnote =>
      'کاتێک ئامێرێک «دەبیسترێت» واتە ڕاگەیاندنی بلوتوسەکەی وەرگیراوە. متمانەی پێ ناکرێت تا دەستپێکی ناسنامە تەواو دەکات. ئەو ناونیشانانەی لێرە پیشان دەدرێن دەستگرەی ڕادیۆیی کاتین، نەک ناسنامە، و لەوانەیە بگۆڕدرێن.';

  @override
  String get nearbyCannotAdvertise => 'ناتوانێت خۆی ڕابگەیەنێت';

  @override
  String get nearbyStartingPill => 'دەست پێدەکات';

  @override
  String get linkConnected => 'پەیوەندیدار';

  @override
  String get linkVerifying => 'پشتڕاست دەکرێتەوە…';

  @override
  String get linkClosing => 'دادەخرێت';

  @override
  String get linkUnnamed => 'مۆبایلی بێناو';

  @override
  String get linkUnverified => 'مۆبایلی پشتڕاستنەکراو';

  @override
  String get linkRole => 'ڕۆڵ';

  @override
  String get linkWeConnected => 'ئێمە پەیوەندیمان کرد';

  @override
  String get linkTheyConnected => 'ئەوان پەیوەندییان کرد';

  @override
  String get linkWriteSize => 'قەبارەی نووسین';

  @override
  String get linkSignal => 'نیشانە';

  @override
  String get linkRoundTrip => 'چوون و گەڕانەوە';

  @override
  String get linkTraffic => 'هاتوچۆ';

  @override
  String get devHeard => 'بیستراوە';

  @override
  String get devConnecting => 'پەیوەندی دەکرێت…';

  @override
  String get devLinked => 'بەستراوە';

  @override
  String get devRetrying => 'دواتر دووبارە هەوڵ دەدرێتەوە';

  @override
  String get devAlreadyLinked => 'پێشتر بەستراوە';

  @override
  String devFailedAttempts(int count) {
    return '$count هەوڵی شکستخواردوو';
  }

  @override
  String get errTypeFirst => 'سەرەتا نامەیەک بنووسە.';

  @override
  String errMessageTooLong(int bytes, int max) {
    return 'ئەم نامەیە زۆر درێژە ($bytes لە $max بایت). تکایە کورتی بکەرەوە.';
  }

  @override
  String get errReplyGone => 'ئەو نامەیەی وەڵامی دەدەیتەوە نەماوە.';

  @override
  String get errUnknownContact => 'ئەم کەسە هێشتا نەناسراوە.';

  @override
  String get errBlockedContact =>
      'ئەم کەسەت بلۆک کردووە. بلۆکەکەی لابە بۆ ناردنی نامە.';

  @override
  String errBlockedNamed(String name) {
    return 'تۆ بلۆکت کردووە: $name.';
  }

  @override
  String get errNoKey =>
      'هێشتا کلیلی شفرەکردنی ئەم کەسەمان پێ نەگەیشتووە. جارێک لێی نزیک ببەرەوە (یان لە مۆبایلێک کە دەیبیستێت)، پاشان دووبارە هەوڵ بدەرەوە.';

  @override
  String get errNoKeyOnce =>
      'هێشتا کلیلی شفرەکردنی ئەم کەسەمان پێ نەگەیشتووە. جارێک لێی نزیک ببەرەوە، پاشان دووبارە هەوڵ بدەرەوە.';

  @override
  String errNoKeyNamed(String name) {
    return 'هێشتا کلیلی شفرەکردنی ئەم کەسەمان پێ نەگەیشتووە ($name). جارێک لێی نزیک ببەرەوە، پاشان دووبارە هەوڵ بدەرەوە.';
  }

  @override
  String get errKeyUnusable =>
      'کلیلی شفرەکردنی ئەم کەسە بەکارنایەت. داوایان لێ بکە ئەپەکە لە نزیک تۆ بکەنەوە تا نوێ بکرێتەوە.';

  @override
  String get errKeyUnusableOne =>
      'کلیلی شفرەکردنی یەکێک لە کەسەکان بەکارنایەت. داوایان لێ بکە ئەپەکە لە نزیک تۆ بکەنەوە تا نوێ بکرێتەوە.';

  @override
  String get errNoKeyForControl =>
      'کلیلی شفرەکردنی ئەم کەسەمان نییە، بۆیە هیچ شتێک ناتوانرێت بۆیان بنێردرێت.';

  @override
  String get errNoConversation => 'ئەم گفتوگۆیە چیتر نەماوە.';

  @override
  String get errCannotResend => 'ناتوانرێت ئەم نامەیە دووبارە بنێردرێتەوە.';

  @override
  String get errFileGone => 'فایلەکە چیتر لەسەر ئەم مۆبایلە نەماوە.';

  @override
  String get errNotQueued =>
      'نەتوانرا بخرێتە ڕیزی ناردن. دووبارە هەوڵ بدەرەوە.';

  @override
  String get unknownAuthor => 'نەزانراو';

  @override
  String get errGroupName => 'ناوێک بۆ گرووپەکە دابنێ.';

  @override
  String get errGroupGone => 'ئەم گرووپە چیتر نەماوە.';

  @override
  String get errNotInGroup => 'تۆ چیتر لەم گرووپەدا نیت.';

  @override
  String get errAdminOnly => 'تەنها بەڕێوەبەری گرووپەکە دەتوانێت ئەمە بکات.';

  @override
  String get errPickPeople => 'لانیکەم یەک کەس هەڵبژێرە بۆ زیادکردن.';

  @override
  String get errPickNewPeople => 'لانیکەم یەک کەسی نوێ هەڵبژێرە بۆ زیادکردن.';

  @override
  String errGroupFull(int max) {
    return 'گرووپێک دەتوانێت زۆرترین $max کەسی تێدا بێت، لەگەڵ تۆدا.';
  }

  @override
  String get errGroupKeyMissing => 'کلیلی ئەم گرووپە نەماوە.';

  @override
  String get errAdminCannotBeRemoved => 'ناتوانرێت بەڕێوەبەر لاببرێت.';

  @override
  String get errNotInGroupPerson => 'ئەو کەسە لە گرووپەکەدا نییە.';

  @override
  String get errCreatorCannotLeave =>
      'تۆ ئەم گرووپەت دروستکردووە، بۆیە ناتوانیت جێی بهێڵیت — لەبری ئەوە بیسڕەوە.';

  @override
  String get errRoomName => 'ناوێک بۆ ژوورەکە دابنێ.';

  @override
  String get errRoomGone => 'ئەم ژوورە چیتر لە نزیکدا نەماوە.';

  @override
  String get errMeshCannotLeave =>
      'ژووری mesh بۆ هەمووانە و ناتوانرێت جێبهێڵرێت.';

  @override
  String get errJoinFirst => 'بۆ ناردنی نامە لەم ژوورەدا، سەرەتا بچۆ ناوی.';

  @override
  String get errFileEmpty => 'ئەم فایلە بەتاڵە.';

  @override
  String errTooLargeForMesh(int kb, int limit) {
    return 'ئەمە زۆر گەورەیە بۆ تۆڕی بلوتوس ($kb KB؛ زۆرترین ڕێگەپێدراو $limit KB یە).';
  }

  @override
  String get errPictureUnreadable => 'نەتوانرا ئەم وێنەیە بخوێنرێتەوە.';

  @override
  String get errVideoUnreadable => 'نەتوانرا ئەم ڤیدیۆیە بخوێنرێتەوە.';

  @override
  String get errRecordingUnreadable => 'نەتوانرا ئەم تۆمارە بخوێنرێتەوە.';

  @override
  String errVoiceTooLong(int seconds) {
    return 'نامەی دەنگی دەتوانێت زۆرترین $seconds چرکە بێت.';
  }

  @override
  String get errVideoNotInRooms =>
      'ڤیدیۆ ناتوانرێت بنێردرێت بۆ ژووری گشتی: هەموو مۆبایلێکی نزیک دەبێت هەڵیبگرێت. لە گفتوگۆیەکی تایبەت یان گرووپێکدا بینێرە.';

  @override
  String get errVideoTooLarge => 'ئەم ڤیدیۆیە زۆر گەورەیە بۆ ناردن.';

  @override
  String get errNothingToShare => 'هیچ شتێک نییە بۆ هاوبەشکردن.';

  @override
  String get errMessageGone => 'ئەو نامەیە نەماوە.';

  @override
  String get errDeleteGroupOnly =>
      'تەنها نووسەری نامەکە، یان بەڕێوەبەری گرووپەکە، دەتوانێت نامەیەک بۆ هەمووان بسڕێتەوە.';

  @override
  String get errDeleteOwnOnly =>
      'تەنها دەتوانیت نامەکانی خۆت بۆ هەمووان بسڕیتەوە.';

  @override
  String errDeleteTooOld(int hours) {
    return 'تەمەنی ئەم نامەیە لە $hours کاتژمێر زیاترە، بۆیە چیتر ناتوانرێت بۆ هەمووان بسڕدرێتەوە.';
  }

  @override
  String get errEditOwnTextOnly =>
      'تەنها نامە نووسراوەکانی خۆت دەتوانرێت دەستکاری بکرێن.';

  @override
  String errEditTooOld(int hours) {
    return 'نامە تا $hours کاتژمێر دوای ناردن دەتوانرێت دەستکاری بکرێت.';
  }

  @override
  String get timeYesterday => 'دوێنێ';

  @override
  String get weekdayMon => 'دووشەممە';

  @override
  String get weekdayTue => 'سێشەممە';

  @override
  String get weekdayWed => 'چوارشەممە';

  @override
  String get weekdayThu => 'پێنجشەممە';

  @override
  String get weekdayFri => 'هەینی';

  @override
  String get weekdaySat => 'شەممە';

  @override
  String get weekdaySun => 'یەکشەممە';

  @override
  String get agoJustNow => 'هەر ئێستا';

  @override
  String agoSeconds(int n) {
    return 'پێش $n چرکە';
  }

  @override
  String agoMinutes(int n) {
    return 'پێش $n خولەک';
  }

  @override
  String agoHours(int n) {
    return 'پێش $n کاتژمێر';
  }

  @override
  String agoDays(int n) {
    return 'پێش $n ڕۆژ';
  }

  @override
  String get settingsTitle => 'ڕێکخستنەکان';

  @override
  String get homePeople => 'کەسەکان';

  @override
  String get homeSearchHint => 'بگەڕێ لە گفتوگۆ، گرووپ و کەسەکان';

  @override
  String get navPrivate => 'تایبەت';

  @override
  String get navGroups => 'گرووپەکان';

  @override
  String get navPublic => 'گشتی';

  @override
  String get fabNewMessage => 'نامەی نوێ';

  @override
  String get fabNewGroup => 'گرووپی نوێ';

  @override
  String get homeNoMessagesYet => 'هێشتا هیچ نامەیەک نییە';

  @override
  String get homePrivateEmptyTitle => 'هێشتا گفتوگۆی تایبەت نییە';

  @override
  String get homeNothingFound => 'هیچ نەدۆزرایەوە';

  @override
  String get homePrivateEmptyBody =>
      'دەمەتەقێ بێ ئینتەرنێت کار دەکات، بە بلوتوس. لە کەسێکی نزیک بپرسە ئەپەکە بکاتەوە؛ کاتێک مۆبایلەکەی لە ڕادەی تۆدا بوو، لێرە دەردەکەوێت.';

  @override
  String homeNoMatchChat(String query) {
    return 'هیچ گفتوگۆ یان کەسێک لەگەڵ \"$query\" ناگونجێت.';
  }

  @override
  String get homeSeePeople => 'کەسەکان ببینە';

  @override
  String get homeDeleteChatTitle => 'ئەم گفتوگۆیە بسڕدرێتەوە؟';

  @override
  String get homeDeleteChatBody =>
      'نامە و وێنەکانی تەنها لەسەر ئەم مۆبایلە دەسڕدرێنەوە.';

  @override
  String get homeAvailableNow => 'ئێستا بەردەستن';

  @override
  String get homeGroupsEmptyTitle => 'هێشتا گرووپ نییە';

  @override
  String get homeGroupsEmptyBody =>
      'گرووپ گفتوگۆیەکی تایبەتە بۆ چەند کەسێک پێکەوە، بە کلیلێک شفرە کراوە کە تەنها ئەندامەکانی هەیانە. لەگەڵ ئەو کەسانەی ناسیووتن گرووپێک دروست بکە.';

  @override
  String homeNoMatchGroup(String query) {
    return 'هیچ گرووپێک لەگەڵ \"$query\" ناگونجێت.';
  }

  @override
  String get homeCreateGroup => 'گرووپێک دروست بکە';

  @override
  String homeInvitations(int count) {
    return 'بانگهێشتنامەکان ($count)';
  }

  @override
  String get homeYourGroups => 'گرووپەکانت';

  @override
  String get homeYouLeft => 'تۆ ئەم گرووپەت بەجێهێشت';

  @override
  String get homeYouWereRemoved => 'تۆ لابرایت';

  @override
  String get homeDeleteGroupTitle => 'ئەم گرووپە بسڕدرێتەوە؟';

  @override
  String get homeLeaveGroupTitle => 'ئەم گرووپە بەجێبهێڵیت؟';

  @override
  String get homeDeleteThisChatTitle => 'ئەم گفتوگۆیە بسڕدرێتەوە؟';

  @override
  String get homeDeleteGroupBody =>
      'گرووپەکە بۆ هەمووان کۆتایی دێت. هەر ئەندامێک ئەوەی پێشتر هەیەتی هەڵیدەگرێت.';

  @override
  String get homeLeaveGroupBody =>
      'چیتر نامەکانی وەرناگریت. لەبەرگیراوەکەی گفتوگۆکە لەسەر ئەم مۆبایلە دەسڕدرێتەوە.';

  @override
  String get homeDeleteThisChatBody =>
      'گفتوگۆکە لەسەر ئەم مۆبایلە دەسڕدرێتەوە.';

  @override
  String get commonContinue => 'بەردەوام بە';

  @override
  String get homeSomeone => 'کەسێک';

  @override
  String homeInvitedYou(String name, int count) {
    return '$name بانگهێشتی کردوویت · $count کەس';
  }

  @override
  String get commonDecline => 'ڕەتکردنەوە';

  @override
  String get commonAccept => 'قبوڵکردن';

  @override
  String get homeMeshSubtitle => 'هەموو کەسانی نزیک · گشتی';

  @override
  String homeLeaveRoomTitle(String room) {
    return 'جێهێشتنی $room؟';
  }

  @override
  String get homeLeaveRoomBody =>
      'نامە و وێنەکانی لەسەر ئەم مۆبایلە دەسڕدرێنەوە. دەتوانیت دووبارە بچیتەوە ناوی ئەگەر ژوورەکە هێشتا لە نزیکدا بوو.';

  @override
  String get commonLeave => 'جێهێشتن';

  @override
  String get homeNearbyRooms => 'ژوورە نزیکەکان';

  @override
  String get homeListeningForRooms =>
      'گوێ لە ژوورەکان دەگرێت. ئەو ژوورانەی کەسانی نزیک دروستیان کردوون، یان مۆبایلەکانیان گواستوونەتەوە، لێرە دەردەکەون.';

  @override
  String homeHeardAgo(String ago) {
    return 'بیستراوە $ago';
  }

  @override
  String get commonJoin => 'بچۆ ناو';

  @override
  String promptTypeToConfirm(String word) {
    return 'بۆ دووپاتکردنەوە بنووسە \"$word\":';
  }

  @override
  String defaultNickname(String code) {
    return 'مۆبایل $code';
  }

  @override
  String get previewYou => 'تۆ';

  @override
  String get previewPhoto => 'وێنە';

  @override
  String get previewVoice => 'نامەی دەنگی';

  @override
  String get previewVideo => 'ڤیدیۆ';

  @override
  String get previewUndecryptable => 'نەتوانرا شفرەی نامەکە لابدرێت';

  @override
  String get notifyHiddenInvite => 'بانگهێشتنامەیەکی نوێی گرووپت هەیە';

  @override
  String notifyHiddenMany(int count) {
    return '$count نامەی نوێت هەیە';
  }

  @override
  String get notifyHiddenOne => 'نامەیەکی نوێت هەیە';

  @override
  String get notifySenderInvite => 'بانگهێشتی کردوویت بۆ گرووپێک';

  @override
  String notifySenderMany(int count) {
    return '$count نامەی نوێ';
  }

  @override
  String get notifySenderOne => 'نامەی نوێ';

  @override
  String get notifyFullInvite => 'بانگهێشتی کردوویت بۆ گرووپێک';

  @override
  String notifyFullInviteBy(String name) {
    return '$name بانگهێشتی کردوویت بۆ گرووپێک';
  }

  @override
  String notifyFullMore(String line, int count) {
    return '$line  (+$count زیاتر)';
  }

  @override
  String get notifyChannelName => 'نامەکان';

  @override
  String get notifyChannelDescription =>
      'نامە نوێیەکان و بانگهێشتنامەی گرووپەکان';

  @override
  String get keepAliveChannelName => 'تۆڕەکە لە پاشبنەمادا کار دەکات';

  @override
  String get keepAliveChannelDescription =>
      'کاتێک پیشان دەدرێت کە دەمەتەقێ تۆڕی بلوتوس بە شاشەی کوژاوەوە بەردەوام دەهێڵێتەوە.';

  @override
  String get keepAliveTitle => 'دەمەتەقێ تۆڕەکە بەردەوام دەهێڵێتەوە';

  @override
  String get keepAliveText =>
      'نامەکان بە بلوتوس دەگوازێتەوە و وەردەگیرێن. بۆ کردنەوە دەستی پێدابنێ.';

  @override
  String get obHeadline =>
      'لەگەڵ خەڵکی نزیک گفتوگۆ بکە.\nپێویستت بە ئینتەرنێت نییە.';

  @override
  String get obPoint1Title => 'مۆبایل بۆ مۆبایل، بە بلوتوس';

  @override
  String get obPoint1Body =>
      'نامە، وێنە و دەنگ ڕاستەوخۆ لە مۆبایلێکەوە بۆ مۆبایلەکەی تر دەچن. هیچ هەژمار، سێرڤەر یان ئینتەرنێتێک نییە.';

  @override
  String get obPoint3Title => 'گفتوگۆی تایبەت، گرووپ و ژووری گشتی';

  @override
  String get obPoint3Body =>
      'گفتوگۆ و گرووپەکان شفرە کراون. ژووری گشتی کراوەن: هەر کەسێکی نزیک دەتوانێت بیانخوێنێتەوە.';

  @override
  String get obPoint4Title => 'پێش بەکارهێنانی هەر شتێک دەپرسێت';

  @override
  String get obPoint4Body =>
      'دواتر بلوتوس داوا دەکرێت. مایکرۆفۆن، کامێرا و وێنەکان تەنها کاتێک نامەی دەنگی یان وێنە دەنێریت. هەرگیز شوێن یان پەیوەندییەکانت.';

  @override
  String get obPoint5Title => 'باشە بزانیت';

  @override
  String get obPoint5Body =>
      'تاقیکارییە: شفرەکردنەکە بە سەربەخۆیی پشکنین نەکراوە، و گواستنەوەی نامە بە مۆبایلەکانی تر تەنها بە ڕادیۆی نموونەکراو تاقیکراوەتەوە. زیاتر لە ڕێکخستنەکان، لە بەشی یارمەتی و ڕێنمایی.';

  @override
  String get obNameHint => 'بۆ خەڵکی نزیک پیشان دەدرێت';

  @override
  String get obNameNote =>
      'هەر کاتێک دەتوانیت لە ڕێکخستنەکان بیگۆڕیت. پێویست ناکات ناوی ڕاستەقینەت بێت.';

  @override
  String get obStarting => 'دەست پێدەکات…';

  @override
  String get obStart => 'ڕێگە بە بلوتوس بدە و دەست پێبکە';

  @override
  String get gdGone => 'ئەم گرووپە نەماوە.';

  @override
  String get gdStateActive => 'تۆ تێیدایت';

  @override
  String get gdStateLeft => 'تۆ جێتهێشت';

  @override
  String get gdStateRemoved => 'تۆ لابرایت';

  @override
  String get gdStateInvited => 'بانگهێشتنامە';

  @override
  String get gdEncryptedNote =>
      'بە کلیلێک شفرە کراوە کە تەنها ئەندامەکان هەیانە. کاتێک کەسێک لادەبرێت گرووپەکە کلیلێکی نوێ وەردەگرێت، بۆیە ناتوانێت هیچ شتێک بخوێنێتەوە کە دواتر دەنێردرێت. ئەوەی پێشتر وەریگرتووە دەمێنێتەوە لای.';

  @override
  String get gdMembers => 'ئەندامەکان';

  @override
  String get gdAdmin => 'بەڕێوەبەر';

  @override
  String get gdRemoveTooltip => 'لابردن لە گرووپ';

  @override
  String gdRemoveTitle(String name) {
    return '$name لابدرێت؟';
  }

  @override
  String get gdRemoveBody =>
      'چیتر هیچ شتێک وەرناگرن، و گرووپەکە کلیلێکی نوێ وەردەگرێت کە ئەوان نایانبێت.';

  @override
  String get gdFull => 'گرووپەکە پڕە';

  @override
  String get gdAddPeople => 'زیادکردنی کەس';

  @override
  String get gdDeleteBody =>
      'گرووپەکە بۆ هەمووان کۆتایی دێت. هەر ئەندامێک ئەو نامانە دەهێڵێتەوە کە پێشتر هەیەتی؛ کەس چیتر ناتوانێت بۆی بنێرێت.';

  @override
  String get gdDeleteAction => 'سڕینەوەی گرووپ';

  @override
  String get gdDeleteButton => 'سڕینەوەی گرووپ بۆ هەمووان';

  @override
  String get gdLeaveBody =>
      'چیتر نامەکانی وەرناگریت. بەڕێوەبەر کلیلێکی نوێ دەدات بە گرووپەکە. لەبەرگیراوەکەی گفتوگۆکە لەسەر ئەم مۆبایلە دەمێنێتەوە.';

  @override
  String get gdLeaveButton => 'جێهێشتنی گرووپ';

  @override
  String get gdForgetTitle => 'لەسەر ئەم مۆبایلە لابدرێت؟';

  @override
  String get gdForgetBody =>
      'گفتوگۆکە و نامەکانی لەسەر ئەم مۆبایلە دەسڕدرێنەوە.';

  @override
  String get gdForgetButton => 'سڕینەوەی ئەم گفتوگۆیە';

  @override
  String get gdInvitationsSent =>
      'بانگهێشتنامەکان نێردران. گرووپەکە کلیلێکی نوێی هەیە.';

  @override
  String gdSelectedOf(int count, int room) {
    return '$count لە $room کەس';
  }

  @override
  String get gdInvite => 'بانگهێشت بکە';

  @override
  String get pdNameTitle => 'ناوێک بۆ ئەم پەیوەندییە دابنێ';

  @override
  String get pdNameHint => 'ناو';

  @override
  String get pdDeleteTitle => 'ئەم پەیوەندییە بسڕدرێتەوە؟';

  @override
  String get pdDeleteBody =>
      'پەیوەندییەکە و گفتوگۆکەت لەگەڵیدا لەسەر ئەم مۆبایلە دەسڕدرێنەوە. ئاگادار ناکرێتەوە. ئەگەر لە نزیکدا بێت وەک پەیوەندییەکی نوێی پشتڕاستنەکراو دووبارە دەردەکەوێتەوە.';

  @override
  String get pdTitle => 'پەیوەندی';

  @override
  String get pdGone => 'ئەم پەیوەندییە چیتر نەماوە.';

  @override
  String pdCallsThemselves(String name) {
    return 'خۆی بە \"$name\" بانگ دەکات';
  }

  @override
  String get pdSendMessage => 'نامەیەک بنێرە';

  @override
  String get pdVerified => 'پشتڕاستکراوە';

  @override
  String get pdNotVerified => 'هێشتا پشتڕاست نەکراوەتەوە';

  @override
  String get pdVerifyBody =>
      'هەر کەسێک دەتوانێت هەر نازناوێک هەڵبژێرێت، و یەکەم جار کە دوو مۆبایل یەکتر دەبینن هیچ ڕێگایەک نییە بزانیت کلیلەکان بەڕاستی هی ئەوانن. بۆ دڵنیابوون، ئەم ژمارەی پاراستنە لەگەڵ ئەوەی لەسەر مۆبایلەکەی ئەو بەراورد بکە — بە ڕووبەڕوو یان لە پەیوەندییەکدا کە دەنگی ئەو دەناسیتەوە. ئەگەر ژمارەکان وەک یەک بوون، وەک پشتڕاستکراو نیشانەی بکە. ئەگەر جیاواز بوون، متمانە بەم پەیوەندییە مەکە.';

  @override
  String get pdNoKey =>
      'هێشتا هیچ کلیلێکی شفرەکردن وەرنەگیراوە: جارێک بکەوە ڕادەوە.';

  @override
  String get pdSafetyNumber => 'ژمارەی پاراستن';

  @override
  String get pdSafetyNote =>
      'ئەمە هەمان ژمارەیە لەسەر هەردوو مۆبایلەکە. بۆ لەبەرگرتنەوە درێژ دابگرە.';

  @override
  String get pdNumbersMatch => 'ژمارەکان وەک یەکن';

  @override
  String get pdMarkVerified => 'ئەم پەیوەندییە وەک پشتڕاستکراو نیشانە بکە';

  @override
  String get pdShortId => 'ناسنامەی کورت';

  @override
  String get pdFirstSeen => 'یەکەم جار بینراوە';

  @override
  String get pdLastSeen => 'دوایین جار بینراوە';

  @override
  String get pdFullFingerprint => 'پەنجەمۆری تەواو';

  @override
  String get pdRename => 'گۆڕینی ناو';

  @override
  String get pdRenameBody => 'تەنها تۆ ئەم ناوە دەبینیت';

  @override
  String get pdBlock => 'بلۆککردن';

  @override
  String get pdBlockBody => 'نامەکانیان فڕێبدە و دووپاتیان مەکەرەوە';

  @override
  String get pdDeleteContact => 'سڕینەوەی پەیوەندی';

  @override
  String get problemQueueFailed => 'نەتوانرا بخرێتە ڕیزی گەیاندن';

  @override
  String get problemExpired =>
      'نەگەیشت: پێش بەسەرچوونی نامەکە نەتوانرا بە وەرگر بگەیەنرێت.';

  @override
  String get problemNobodyInRange => 'کەس لە نزیکدا نەبوو بۆ وەرگرتنی ئەمە.';

  @override
  String get problemFileDamaged => 'فایلەکە زیانلێکەوتوو گەیشت و فڕێدرا.';

  @override
  String get problemFileIncomplete => 'بەشەکانی تری ئەم فایلە هەرگیز نەگەیشتن.';

  @override
  String get feedErrorTitle => 'نەتوانرا نامەکان بار بکرێن';

  @override
  String get feedErrorBody =>
      'هیچ شتێک نەسڕایەوە. دووبارە هەوڵبدەرەوە، و ئەگەر بەردەوام بوو، ئەپەکە دووبارە بکەرەوە.';

  @override
  String get homePrivateTitle => 'گفتوگۆ تایبەتەکان';

  @override
  String get setProfileTitle => 'پرۆفایل و ناسنامە';

  @override
  String get setDataHeading => 'داتا و مێژوو';

  @override
  String get setChatsBluetooth => 'گفتوگۆ و بلوتوس';

  @override
  String get setHelp => 'یارمەتی و ڕێنمایی';

  @override
  String setAboutTitle(String name) {
    return 'دەربارەی $name';
  }

  @override
  String get setLicenses => 'مۆڵەتنامەکانی سەرچاوە کراوە';

  @override
  String get setLicensesBody =>
      'ئەو فۆنت و کتێبخانانەی ئەم ئەپە پێیان دروست کراوە';

  @override
  String get setLicensesLegalese =>
      'بە نەرمامێری سەرچاوە کراوە دروست کراوە. هەر بەشێک مۆڵەتنامەی خۆی هەیە.';

  @override
  String get helpPermissionsTitle => 'ڕێگەپێدانەکان: چی داوا دەکرێت، و کەی';

  @override
  String get helpPermissionsBody =>
      'بلوتوس لە کاتی دەستپێکردندا داوا دەکرێت، تا دەمەتەقێ بتوانێت مۆبایلە نزیکەکان بدۆزێتەوە. مایکرۆفۆن، کامێرا و وێنەکان تەنها ئەگەر نامەی دەنگی تۆمار بکەیت یان وێنە بنێریت داوا دەکرێن — هەریەکەیان بە ڕوونکردنەوەیەکەوە پێشتر، و دەتوانیت بە هەریەکێکیان بڵێیت نا. دەمەتەقێ هەرگیز شوێن یان پەیوەندییەکانت ناخوێنێتەوە. (ئەندرۆید 11 و کۆنتر سکانی بلوتوس دەبەستنەوە بە ڕێگەپێدانی شوێن؛ ئەپەکە هێشتا هەرگیز شوێنەکەت ناخوێنێتەوە.)';

  @override
  String get roomYourNameTitle => 'ناوی تۆ لێرە';

  @override
  String get roomYourNameBody =>
      'هەموو کەسێکی لە ڕادەدا ئەم ناوە دەبینێت لە تەنیشت ئەوەی دەینووسیت. پێویست ناکات ناوی ڕاستەقینەت بێت، و تاکانە نییە: ئەوانی تر دەتوانن هەمان ناو هەڵبژێرن.';

  @override
  String get roomExpiryNote => 'گشتی · نامەکان دوای 6 کاتژمێر دەسڕێنەوە';

  @override
  String get roomSearchTooltip => 'گەڕان لەم ژوورەدا';

  @override
  String roomComposerHint(String room) {
    return 'نامە بۆ $room · گشتی';
  }

  @override
  String get roomJoinToPost => 'بۆ ناردنی نامە بچۆ ناو ئەم ژوورە';

  @override
  String get roomEmpty =>
      'هێشتا هیچ شتێک لێرە نییە. هەرچی بینووسیت گشتییە: هەموو مۆبایلێکی لە ڕادەدا (و ئەو مۆبایلانەی بۆیان دەگوازنەوە) دەتوانێت بیخوێنێتەوە.';

  @override
  String get roomsCreateTitle => 'ژوورێکی گشتی دروست بکە';

  @override
  String get roomsCreateBody =>
      'هەر کەسێکی نزیک دەتوانێت ژوورەکە بدۆزێتەوە، بچێتە ناوی و هەرچی تێیدا دەوترێت بیخوێنێتەوە. تایبەت نییە. ژوورەکە بۆ ماوەی ڕۆژێک لیست دەکرێت و تا ئەپەکەت کاردەکات خۆکارانە نوێ دەکرێتەوە.';

  @override
  String get roomsNameHint => 'ناوی ژوور';

  @override
  String get roomsAboutHint => 'دەربارەی چییە؟ (ئیختیاری)';

  @override
  String get commonCreate => 'دروستکردن';

  @override
  String get roomsTitle => 'ژووری گشتی';

  @override
  String get roomsCreateButton => 'ژوورێک دروست بکە';

  @override
  String get peopleFilterAll => 'هەموو';

  @override
  String get peopleFilterReachable => 'ئێستا بەردەست';

  @override
  String get peopleFilterContacts => 'پەیوەندییەکان';

  @override
  String get peopleEmptyTitle => 'هێشتا کەس نییە';

  @override
  String get peopleEmptyFilterTitle => 'هیچ کەسێک لەگەڵ ئەم فلتەرە ناگونجێت';

  @override
  String get peopleEmptyBody =>
      'ئەو مۆبایلانەی دەمەتەقێ کاردەکەن لە ڕادەی بلوتوسدا خۆکارانە لێرە دەردەکەون، لەگەڵ هەر کەسێک ئاگادارکردنەوەکەی لە ڕێگەی مۆبایلەکانی ترەوە دەگاتە تۆ. هیچ شتێک بە ئینتەرنێت نانێردرێت.';

  @override
  String get peopleEmptyFilterBody => 'فلتەرێکی تر تاقی بکەرەوە.';

  @override
  String get peopleSeeNearby => 'ببینە چی لە نزیکە';

  @override
  String get peopleDetailsTooltip => 'وردەکاری پەیوەندی و پشتڕاستکردنەوە';

  @override
  String get peoplePickEmpty =>
      'هێشتا کەس نییە بۆ ناردنی نامە. مۆبایلەکان لێرە دەردەکەون هەر کە دەکەونە ڕادەوە.';

  @override
  String get groupNoKeyYet =>
      'هێشتا کلیلی شفرەکردنی نییە — سەرەتا جارێک بیانبینە';

  @override
  String get groupNameLabel => 'ناوی گرووپ';

  @override
  String get groupCreateNote =>
      'نامەکانی گرووپ بە کلیلێک شفرە دەکرێن کە تەنها ئەندامەکانی هەیانە. ئەو کەسانەی هەڵیدەبژێریت بانگهێشتنامەیەک وەردەگرن کە دەتوانن قبوڵی بکەن یان ڕەتی بکەنەوە؛ هیچ شتێک دەربارەی گرووپەکە هەرگیز بڵاو ناکرێتەوە.';

  @override
  String groupAddPeople(int count, int max) {
    return 'زیادکردنی کەس ($count لە $max)';
  }

  @override
  String get groupNobodyToAdd => 'هێشتا کەس نییە بۆ زیادکردن';

  @override
  String get groupNobodyBody =>
      'تەنها دەتوانیت ئەو کەسانە بانگهێشت بکەیت کە مۆبایلەکەت بینیوونی. دەمەتەقێ لە نزیک کەسێک بکەرەوە و لێرە دەردەکەوێت.';

  @override
  String get groupCreating => 'دروست دەکرێت…';

  @override
  String get groupCreate => 'دروستکردنی گرووپ';

  @override
  String get videoCouldNotPlay =>
      'ئەم ڤیدیۆیە نەتوانرا لەسەر ئەم مۆبایلە لێبدرێت.';

  @override
  String get commonPause => 'وەستاندن';

  @override
  String get commonPlay => 'لێدان';

  @override
  String get secClearTitle => 'تۆماری پاراستن پاک بکرێتەوە؟';

  @override
  String get secClearBody =>
      'تۆمارەکان لەسەر ئەم مۆبایلە لادەبرێن. ئەمە ناگەڕێتەوە.';

  @override
  String get secClearTooltip => 'پاککردنەوەی تۆمار';

  @override
  String get secEmptyTitle => 'هیچ شتێکی گوماناوی تۆمار نەکراوە';

  @override
  String get secEmptyBody =>
      'ئەگەر نامەیەک واژۆکەی هەڵە بوو یان نەتوانرا شفرەکەی لابدرێت، مۆبایلێک پشکنینی ناسنامەی شکستی هێنا، یان کلیلی پەیوەندییەک گۆڕا، لێرە لیست دەکرێت. هەندێک تۆمار لەوانەیە بەهۆی بەستنێکی ڕادیۆیی لاوازەوە بن و هەمیشە هێرش نین.';

  @override
  String get secBadSignatureTitle => 'نامەیەک واژۆیەکی نادروستی هەبوو';

  @override
  String get secBadSignatureBody =>
      'فڕێدرا. لەوانەیە کەسێک ساختەی کردبێت یان گۆڕیبێتی، یان لە هەوادا تێکچووبێت.';

  @override
  String get secDecryptFailedTitle => 'نەتوانرا شفرەی نامەیەک لابدرێت';

  @override
  String get secDecryptFailedBody =>
      'ئاڕاستەی تۆ کرابوو بەڵام نەتوانرا بکرێتەوە. تێکچووە، دەستکاری کراوە، یان بۆ کلیلێکی تر شفرە کراوە.';

  @override
  String get secLinkAuthTitle => 'مۆبایلێک پشکنینی ناسنامەی شکستی هێنا';

  @override
  String get secLinkAuthBody =>
      'بە بلوتوس پەیوەندی کرد بەڵام نەیتوانی بسەلمێنێت کلیلەکەی کە داوای کرد هی ئەوە. پەیوەندییەکە داخرا.';

  @override
  String get secKeyChangedTitle => 'کلیلی شفرەکردنی پەیوەندییەک گۆڕا';

  @override
  String get secKeyChangedBody =>
      'پشتڕاستکردنەوەکەی لابرا. پێش متمانەکردن بەم پەیوەندییە دووبارە ژمارەی پاراستن لەگەڵی بەراورد بکە. گۆڕانی کلیل چاوەڕوانکراوە ئەگەر ئەپەکەی دووبارە دامەزراندبێتەوە.';

  @override
  String get secRateLimitedTitle => 'مۆبایلێک زۆری نارد';

  @override
  String get secRateLimitedBody =>
      'هاتوچۆکەی لە سنوور تێپەڕی و زیادەکە فڕێدرا.';

  @override
  String get secMalformedTitle => 'داتایەکی نەخوێنراو وەرگیرا';

  @override
  String get secMalformedBody =>
      'ئەو داتایەی پەیڕەوی پرۆتۆکۆڵ ناکات پشتگوێ خرا.';

  @override
  String get secNotAMemberTitle => 'کەسێک بەبێ ڕێگەپێدان کاری کرد';

  @override
  String get secNotAMemberBody =>
      'نامە، بانگهێشتنامە یان نوێکردنەوەیەکی گرووپ لە کەسێکەوە هات کە ئەندام نییە یان بەڕێوەبەر نییە. پشتگوێ خرا.';

  @override
  String get secUnauthorizedTitle =>
      'کەسێک هەوڵیدا نامەیەک بگۆڕێت کە هی ئەو نییە';

  @override
  String get secUnauthorizedBody =>
      'داواکارییەک بۆ سڕینەوە یان دەستکاریکردنی نامەیەک لە کەسێکەوە هات کە نەینووسیوە (و بەڕێوەبەری گرووپ نییە). پشتگوێ خرا.';

  @override
  String get secBadMediaTitle => 'وێنەیەک یان نامەیەکی دەنگی زیانی بەرکەوت';

  @override
  String get secBadMediaBody =>
      'فایلێک لەگەڵ وەسفەکەی نەدەگونجا (قەبارە یان کۆدی پشکنین هەڵە) یان بە پارچەی نەگونجاو هات، بۆیە فڕێدرا.';

  @override
  String get secProtocolTitle => 'مۆبایلێک ڕێساکانی پەیوەندی شکاند';

  @override
  String get secProtocolBody =>
      'داتای بە ڕیزی هەڵە یان بە شێوەیەکی چاوەڕواننەکراو نارد، بۆیە بەستنەکە پچڕا.';

  @override
  String get secUnknownBody => 'هیچ وەسفێک بۆ ئەم تۆمارە بەردەست نییە.';

  @override
  String secUnknownPhone(String tag) {
    return 'مۆبایلی نەناسراو $tag';
  }

  @override
  String get bstTitleDevice => 'ئەم مۆبایلە';

  @override
  String get bstTitleSupport => 'بلوتوسی کەم-وزە';

  @override
  String get bstTitlePermission => 'ڕێگەپێدانی بلوتوس';

  @override
  String get bstTitlePower => 'بلوتوس کراوەتەوە';

  @override
  String get bstTitleAdvertising => 'بۆ مۆبایلەکانی تر دیارە (ڕاگەیاندن)';

  @override
  String get bstTitleScanning => 'گەڕان بۆ مۆبایلەکانی تر (سکان)';

  @override
  String get bstTitleDiscovery => 'دۆزینەوەی مۆبایلێکی تر';

  @override
  String get bstTitleConnection => 'پەیوەندیکردن و سەلماندنی ناسنامە';

  @override
  String get bstTitleExchange => 'ناردنی داتا بە هەردوو ئاراستە';

  @override
  String get bstTitleMultihop => 'گەیشتن بە مۆبایلەکان لە ڕێگەی گواستنەوەوە';

  @override
  String get bstTitleNetwork => 'کارکردنی بێ ئینتەرنێت';

  @override
  String get bstStopped => 'وەستێنرا.';

  @override
  String get bstFixAbove => 'سەرەتا کێشەی سەرەوە چارەسەر بکە.';

  @override
  String get bstNoBle => 'ئەم مۆبایلە پشتگیری بلوتوسی کەم-وزە ناکات.';

  @override
  String get bstNoBleAdvice => 'ئەم مۆبایلە ناتوانێت بەشداری لە تۆڕەکەدا بکات.';

  @override
  String get bstBleAvailable => 'بلوتوسی کەم-وزە بەردەستە.';

  @override
  String get bstWhereIos => 'ڕێکخستنەکان > دەمەتەقێ > بلوتوس (بیکەرەوە).';

  @override
  String get bstWhereAndroid12 =>
      'ڕێکخستنەکان > ئەپەکان > دەمەتەقێ > ڕێگەپێدانەکان > ئامێرە نزیکەکان > ڕێگەپێبدە.';

  @override
  String get bstWhereOlder =>
      'ڕێکخستنەکان > ئەپەکان > دەمەتەقێ > ڕێگەپێدانەکان > شوێن > ڕێگەپێبدە (ئەندرۆیدی کۆنتر پێویستی پێیەتی بۆ سکانی بلوتوس).';

  @override
  String get bstPermDenied => 'ڕێگەپێدانی بلوتوس نەدراوە.';

  @override
  String bstPermAdvice(String where) {
    return 'لەسەر شاشەی سەرەکی «ڕێگە بە بلوتوس بدە» دابگرە، یان بکەرەوە: $where';
  }

  @override
  String get bstPermGranted => 'ڕێگەپێدان دراوە.';

  @override
  String get bstOff => 'بلوتوس کوژاوەتەوە.';

  @override
  String get bstOffAdvice =>
      'بلوتوس لە ڕێکخستنە خێراکانی مۆبایلەکەتدا بکەرەوە، پاشان تاقیکردنەوەکە دووبارە بکە.';

  @override
  String get bstPowerUnknown => 'مۆبایلەکە هێشتا دۆخی بلوتوسی ڕانەگەیاندووە.';

  @override
  String get bstPowerUnknownAdvice =>
      'کەمێک چاوەڕێ بکە و تاقیکردنەوەکە دووبارە بکە.';

  @override
  String get bstOn => 'بلوتوس کراوەیە.';

  @override
  String get bstCannotAdvertise =>
      'ئەم مۆبایلە ناتوانێت خۆی ڕابگەیەنێت (وەک ئامرازی دەرەکی بلوتوس کار بکات).';

  @override
  String get bstCannotAdvertiseAdvice =>
      'هێشتا دەتوانێت مۆبایلەکانی تر بدۆزێتەوە و پەیوەندییان پێوە بکات، بەڵام ئەوانی تر ناتوانن بیدۆزنەوە. دوو مۆبایل کە هەردووکیان ئەم توانایەیان نییە ناتوانن پەیوەندی بە یەکتر بکەن.';

  @override
  String get bstAdvertising =>
      'خزمەتگوزاری تۆڕەکە ڕادەگەیەنێت؛ مۆبایلەکانی تر دەتوانن ئەمە ببینن و پەیوەندی پێوە بکەن.';

  @override
  String get bstNotAdvertising => 'مۆبایلەکە خۆی ڕانەگەیاندووە.';

  @override
  String get bstNotAdvertisingAdvice =>
      'بلوتوس بکوژێنەرەوە و دووبارە بیکەرەوە، پاشان تاقیکردنەوەکە دووبارە بکە. ئەگەر هەر سەرنەکەوت لەوانەیە ئەم مۆدێلە پشتگیری ڕاگەیاندنی بلوتوس نەکات.';

  @override
  String get bstDiscoveryStopped => 'دۆزینەوە وەستاوە.';

  @override
  String get bstDiscoveryStoppedAdvice =>
      'تابی «نزیک» بکەرەوە و دڵنیابە ئەپەکە دەستی پێکردووە.';

  @override
  String bstScanning(String mode, int count) {
    return 'بە ماوەی کورت دەگەڕێت (دۆخی $mode)، تا ئێستا $count سکان دەستی پێکردووە.';
  }

  @override
  String get bstNoScan => 'هیچ سکانێک نەتوانرا دەستپێبکات.';

  @override
  String get bstNoScanAdvice =>
      'ڕێگەپێدانی بلوتوس بپشکنە و دڵنیابە بلوتوس کراوەیە.';

  @override
  String bstHeardCount(int count) {
    return '$count مۆبایلی دەمەتەقێ بیستران.';
  }

  @override
  String bstHeardStrongest(int count, int dbm) {
    return '$count مۆبایلی دەمەتەقێ بیستران، بەهێزترین نیشانە $dbm dBm.';
  }

  @override
  String bstNoneHeard(int seconds) {
    return 'هیچ مۆبایلێکی تری دەمەتەقێ لە $seconds چرکەدا نەبیسترا.';
  }

  @override
  String get bstNoneHeardAdvice =>
      'ئەمە ئاساییە ئەگەر کەس لە نزیکدا نەبێت. ئەپەکە لەسەر مۆبایلێکی دووەم بکەرەوە (بلوتوس کراوە، لە چەند مەتری نزیکدا) و تاقیکردنەوەکە دووبارە بکە.';

  @override
  String get bstOlderAndroidLocation =>
      ' لە ئەندرۆید 11 و کۆنتر، سکانکردن پێویستی بەوەشە شوێنی مۆبایلەکە (لە ڕێکخستنە خێراکان) کرابێتەوە؛ دەمەتەقێ شوێنی تۆ ناخوێنێتەوە، بەڵام ئەو وەشانانە هیچ نادۆزنەوە کاتێک کوژاوەیە.';

  @override
  String get bstNeedsPhone => 'مۆبایلێکی تری لە ڕادەدا پێویستە.';

  @override
  String get bstWeConnected => 'ئێمە پەیوەندیمان پێیانەوە کرد';

  @override
  String get bstTheyConnected => 'ئەوان پەیوەندییان پێمانەوە کرد';

  @override
  String bstLinkLine(String who, String role, String bytes) {
    return '$who ($role، $bytes بایت بۆ هەر نووسینێک)';
  }

  @override
  String bstConnectedOk(String lines) {
    return 'پەیوەندی کرا و خاوەندارێتی کلیل پشتڕاست کرایەوە لەگەڵ: $lines.';
  }

  @override
  String get bstNotConnected =>
      'مۆبایلەکانی تر بیستران بەڵام نەتوانرا پەیوەندییەکە تەواو بکرێت.';

  @override
  String bstNotConnectedWith(String errors) {
    return 'مۆبایلەکانی تر بیستران بەڵام نەتوانرا پەیوەندییەکە تەواو بکرێت: $errors';
  }

  @override
  String get bstNotConnectedAdvice =>
      'مۆبایلەکان نزیکتر بکەرەوە (لە خوار 2 مەتر)، بلوتوس لەسەر هەردووکیان بکوژێنەرەوە و بیکەرەوە، و ئەپەکانی تر دابخە کە بلوتوس زۆر بەکاردەهێنن. هەڵەی پەیوەندی وەک «status 133» لەسەر هەندێک مۆبایلی ئەندرۆید باوە و زۆرجار بە هەوڵدانەوە نامێنێت.';

  @override
  String get bstNeedsConnected => 'مۆبایلێکی پەیوەندیدار پێویستە.';

  @override
  String bstSmall(int received, int sent) {
    return '$received/$sent بچووک';
  }

  @override
  String bstLarge(int received, int sent) {
    return '$received/$sent گەورە (1200 B، پارچەپارچە)';
  }

  @override
  String bstRtt(int avg, int min, int max) {
    return '، تێکڕای چوون و گەڕانەوە $avg ms ($min-$max)';
  }

  @override
  String bstExchangeLine(String label, String small, String large, String rtt) {
    return '$label: $small، $large$rtt';
  }

  @override
  String get bstNothingBack =>
      'هیچ نەگەڕایەوە. بەستنەکە دروست بوو بەڵام داتا ناڕوات؛ نزیکتر دووبارە هەوڵ بدەرەوە، یان بلوتوس لەسەر هەردوو مۆبایلەکە بکوژێنەرەوە و بیکەرەوە.';

  @override
  String get bstSomeLost =>
      'هەندێک داتا لەدەست چوو. نزیکتر ببەرەوە و دووبارە تاقی بکەرەوە.';

  @override
  String get bstSlowChunk =>
      'بەستنەکە کەمترین قەبارەی بلوتوس بەکاردەهێنێت، 20 بایت بۆ هەر نووسینێک، بۆیە نامەکان هێواش دەبن. ئەمە ڕوودەدات کاتێک مۆبایلەکان نەتوانن قەبارەیەکی گەورەتر ڕێککەون لەسەری.';

  @override
  String get bstNoRelay =>
      'ئێستا هیچ مۆبایلێک تەنها لە ڕێگەی گواستنەوەوە بەردەست نییە. تاقیکردنەوەی ئەمە سێ مۆبایل پێویستە: A و C هەریەکەیان لە ڕادەی B دان بەڵام لە ڕادەی یەکتر نین.';

  @override
  String bstRelayLine(String id, String via, int hops) {
    return '$id لە ڕێگەی $via ($hops بەست)';
  }

  @override
  String bstRelayOk(String lines) {
    return 'لە ڕێگەی گواستنەوەوە دەگەیت پێی، لەسەر بنەمای ڕاگەیاندنە واژۆکراوەکان: $lines.';
  }

  @override
  String bstNetOffline(String text) {
    return '$text. هەموو ئەوەی سەرەوە بەبێ هیچ پەیوەندییەکی ئینتەرنێت کارا بوو.';
  }

  @override
  String bstNetOnline(String text) {
    return '$text. ئەپەکە بەکاری ناهێنێت؛ بۆ سەلماندنی کارکردنی بێ ئینتەرنێت، وای-فای و داتای مۆبایل بکوژێنەرەوە (یان دۆخی فڕۆکە بەکاربهێنە لەگەڵ بلوتوسی کراوە) و تاقیکردنەوەکە دووبارە بکە.';
  }

  @override
  String get setLanguage => 'زمان';

  @override
  String get setLanguageBody => 'زمانی هەموو ئەپەکە. کوردی زمانی سەرەکییە.';

  @override
  String get setAppearance => 'ڕووکار';

  @override
  String get appearanceHeading => 'ڕووکار';

  @override
  String get appearanceSystem => 'وەک ڕێکخستنی مۆبایل';

  @override
  String get appearanceSystemHelp =>
      'بەپێی ڕێکخستنی ڕووناک یان تاریکی مۆبایلەکەت دەگۆڕێت.';

  @override
  String get appearanceLight => 'ڕووناک';

  @override
  String get appearanceLightHelp => 'پەڕەیەکی کاڵ لەگەڵ چینی سپی.';

  @override
  String get appearanceDark => 'تاریک';

  @override
  String get appearanceDarkHelp =>
      'پەڕەیەکی نزیک لە ڕەش، لە شەودا کەمتر چاو ماندوو دەکات.';

  @override
  String get themeSwitchToLight => 'بگۆڕە بۆ ڕووکاری ڕووناک';

  @override
  String get themeSwitchToDark => 'بگۆڕە بۆ ڕووکاری تاریک';

  @override
  String get setName => 'ناوەکەت';

  @override
  String get setNameBody =>
      'هەر کەسێکی نزیک دەتوانێت ئەم ناوە ببینێت. تاکانە نییە و کەس نایپشکنێت: دوو کەس دەتوانن هەمان ناو هەڵبژێرن، بۆیە پەیوەندییەکان ناسنامەیەکی کورتیش پیشان دەدەن.';

  @override
  String get setNicknameHint => 'نازناو';

  @override
  String get setChangeName => 'گۆڕینی ناو';

  @override
  String get setFingerprint => 'پەنجەمۆری ناسنامەکەت';

  @override
  String get setFingerprintBody =>
      'پەیوەندییەکانت ژمارەیەکی پاراستن لەگەڵ تۆ بەراورد دەکەن بۆ دڵنیابوون کە ڕاستەقینە تۆیت.';

  @override
  String get setFingerprintCopied => 'پەنجەمۆر لەبەرگیرایەوە';

  @override
  String get setPermissions => 'ڕێگەپێدانەکان';

  @override
  String get setNotifications => 'ئاگادارکردنەوەکان';

  @override
  String get setMeshBackground => 'تۆڕەکە لە پاشبنەمادا';

  @override
  String get setBluetooth => 'بلوتوس';

  @override
  String get setPrivacy => 'تایبەتمەندی و پاراستن';

  @override
  String get setHonesty => 'چۆن کار دەکات، و چی ناتوانێت بیکات';

  @override
  String get setDanger => 'ناوچەی مەترسی';

  @override
  String get setSearchHow => 'چەند بە توندی بگەڕێیت بۆ کەسەکان';

  @override
  String get modeBalanced => 'هاوسەنگ';

  @override
  String get modeLowPower => 'پاشەکەوتکردنی باتری';

  @override
  String get modeAggressive => 'بەردەوام';

  @override
  String get modeBalancedHelp => 'نزیکەی نیوەی کات دەگەڕێت';

  @override
  String get modeLowPowerHelp =>
      'کورت و بە کەمی دەگەڕێت: باتری پاشەکەوت دەکات، کەسەکان بە هێواشی دەدۆزێتەوە';

  @override
  String get modeAggressiveHelp =>
      'بەبێ وەستان دەگەڕێت: کەسەکان بە خێراترین شێوە دەدۆزێتەوە، زۆرترین باتری بەکاردەهێنێت';

  @override
  String get setSelfTest => 'تاقیکردنەوەی بلوتوس';

  @override
  String get setSelfTestBody =>
      'بپشکنە کە ئەم مۆبایلە دەتوانێت مۆبایلێکی تر بدۆزێتەوە، پەیوەندی پێوە بکات و قسەی لەگەڵ بکات';

  @override
  String get setInternet => 'ئینتەرنێت';

  @override
  String get setChecking => 'دەپشکنرێت…';

  @override
  String setInternetBody(String state) {
    return '$state. دەمەتەقێ هەرگیز ئینتەرنێت بەکارناهێنێت؛ ئەگەر دەتەوێت ببینیت بەبێ ئینتەرنێت کار دەکات، بیکوژێنەوە.';
  }

  @override
  String get netNone => 'نە وای-فای نە داتای مۆبایل';

  @override
  String get netWifi => 'وای-فای کارایە (ئەم ئەپە بەکاری ناهێنێت)';

  @override
  String get netMobile => 'داتای مۆبایل کارایە (ئەم ئەپە بەکاری ناهێنێت)';

  @override
  String get netWired => 'تۆڕی تەل (ئەم ئەپە بەکاری ناهێنێت)';

  @override
  String get netOther => 'تۆڕێکی تر کارایە (ئەم ئەپە بەکاری ناهێنێت)';

  @override
  String get netUnknown => 'دۆخی تۆڕ نەزانراوە';

  @override
  String get setStorage => 'شوێنی هەڵگرتن';

  @override
  String get setStorageBody =>
      'چی لەسەر ئەم مۆبایلە دەپارێزرێت، و چۆن شوێنەکەی بەتاڵ بکەیتەوە';

  @override
  String get setKeepMessages => 'هێشتنەوەی نامەکان';

  @override
  String get setKeepMessagesBody =>
      'نامە کۆنەکان لەسەر ئەم مۆبایلە دەسڕدرێنەوە';

  @override
  String get setRetForever => 'بۆ هەمیشە';

  @override
  String get setRetDay => 'ڕۆژێک';

  @override
  String setRetDays(int days) {
    return '$days ڕۆژ';
  }

  @override
  String get setSecurityLog => 'تۆماری پاراستن';

  @override
  String get setSecurityLogBody =>
      'نامەی ساختە، پشکنینی ناسنامەی شکستخواردوو، کلیلی گۆڕدراو';

  @override
  String get setResetAction => 'ڕیسێتکردنی ناسنامە';

  @override
  String get setResetTileBody =>
      'کلیلی نوێ دروست دەکات. پەیوەندییەکان دەبێت دووبارە پشتڕاستت بکەنەوە';

  @override
  String get setResetTitle => 'ناسنامەکەت ڕیسێت بکرێت؟';

  @override
  String get setResetBody =>
      'ئەمە ناسنامەیەکی تەواو نوێ دروست دەکات (کلیلی نوێی شفرەکردن و واژۆکردن).\n\n• پەیوەندییەکانت وەک کەسێکی نوێی پشتڕاستنەکراو دەتبینن و دەبێت ژمارەی پاراستنی نوێت پشتڕاست بکەنەوە.\n• ئەو نامانەی هێشتا بەرەو ناسنامە کۆنەکەت دەڕۆن چیتر ناخوێنرێنەوە.\n• ئەو نامانەی چاوەڕێی ناردنن فڕێدەدرێن.\n• چیتر ناتوانیت بەشداری گرووپەکانت بکەیت (ناسنامە کۆنەکەت دەناسن)؛ لەبەرگیراوەی ئەو گفتوگۆیانە لەسەر ئەم مۆبایلە دەمێنێتەوە.\n• گفتوگۆ هەبووەکانت لەسەر ئەم مۆبایلە دەمێنێتەوە.\n\nئەمە ناگەڕێتەوە.';

  @override
  String get setResetDone => 'ناسنامەیەکی نوێت هەیە';

  @override
  String get setClearTile => 'سڕینەوەی هەموو داتای ناوخۆیی';

  @override
  String get setClearTileBody => 'نامە، وێنە، پەیوەندی، گرووپ و کلیلەکان';

  @override
  String get setClearTitle => 'هەموو شتێک لەسەر ئەم مۆبایلە بسڕدرێتەوە؟';

  @override
  String get setClearBody =>
      'ئەمە بۆ هەمیشە هەموو نامە، وێنە، نامەی دەنگی، پەیوەندی، گرووپ، ژوور و کلیلەکانی گرووپ، تۆماری پاراستن و ڕێکخستنەکانت دەسڕێتەوە، و ناسنامەیەکی نوێ دروست دەکات.\n\nکەسی تر ئاگادار ناکرێتەوە، و لەبەرگیراوەکانی سەر مۆبایلەکانی تر کاریگەرییان لەسەر نابێت. ئەمە ناگەڕێتەوە.';

  @override
  String get setClearAction => 'هەموو شتێک بسڕەوە';

  @override
  String get confirmWordDelete => 'سڕینەوە';

  @override
  String get setClearDone => 'هەموو داتای ناوخۆیی سڕایەوە';

  @override
  String setVersionLine(String name, String version, int protocol) {
    return '$name $version · پرۆتۆکۆڵ v$protocol';
  }

  @override
  String get setNotifyTitle => 'ئاگادارکردنەوەی نامە';

  @override
  String get setNotifyBody =>
      'پێم بڵێ کاتێک نامەیەک دێت لە کاتێکدا ئەپەکە داخراوە یان لە پاشبنەمایە. تەنها بۆ ئەو نامانەی ئاڕاستەی تۆ کراون.';

  @override
  String get setNotifyShows => 'ئاگادارکردنەوەکە چی پیشان دەدات';

  @override
  String get setNotifyFull => 'ناو و نامە';

  @override
  String get setNotifySender => 'تەنها ناو';

  @override
  String get setNotifyHidden => 'هیچ (تەنها «نامەی نوێ»)';

  @override
  String get setNotifyFullHelp =>
      'پیشان دەدات کێ نووسیویەتی و چی نووسیوە. هەر کەسێک شاشەی قفڵکراوەکەت ببینێت دەتوانێت بیخوێنێتەوە.';

  @override
  String get setNotifySenderHelp =>
      'پیشان دەدات کێ نووسیویەتی، نەک چی. «نامەی نوێ».';

  @override
  String get setNotifyHiddenHelp =>
      'تەنها پیشان دەدات شتێک گەیشتووە. نە کێ نە چی.';

  @override
  String get setNotifyPublic => 'ژووری گشتیش';

  @override
  String get setNotifyPublicBody =>
      'بە شێوەی بنەڕەتی کوژاوەیە: ژووری گشتی واتە هەموو کەسانی نزیک قسە دەکەن، و هەرگیز ناوەستێت.';

  @override
  String get setRelayTitle => 'یارمەتی گواستنەوەی نامە بدە بۆ ئەوانی تر';

  @override
  String get setRelayOn =>
      'مۆبایلەکەت نامە داخراوەکان دەگوازێتەوە لە نێوان ئەو کەسانەی لە ڕادەی یەکتر دەرەوەن. ناتوانێت بیانخوێنێتەوە. ئەمەیە وا دەکات تۆڕەکە زیاتر بگات.';

  @override
  String get setRelayOff =>
      'کوژاوەیە: مۆبایلەکەت ئەوەی بۆ تۆیە وەریدەگرێت و نامەکانی خۆت دەنێرێت، بەڵام هیچ شتێک بۆ کەسی تر ناگوازێتەوە. ئەو کەسانەی پشت بە تۆ دەبەستن بۆ گەیشتن بە یەکتر ناگەن.';

  @override
  String relayActivity(int count) {
    return 'لە دەستپێکردنی ئەپەکەوە: $count پاکێت بۆ ئەوانی تر گوازرایەوە.';
  }

  @override
  String relayActivityRefused(int count, int refused) {
    return 'لە دەستپێکردنی ئەپەکەوە: $count پاکێت بۆ ئەوانی تر گوازرایەوە، $refused ڕەتکرانەوە چونکە گواستنەوە کوژاوەیە.';
  }

  @override
  String get setKeepAliveTitle => 'تۆڕەکە لە پاشبنەمادا بەردەوام بهێڵەرەوە';

  @override
  String get setKeepAliveBody =>
      'کاتێک کاردەکات ئاگادارکردنەوەیەک پیشان دەدات، و کەمێک باتری بەکاردەهێنێت. بەبێ ئەمە ئەندرۆید لەوانەیە کارەکانی بلوتوس بوەستێنێت کەمێک دوای قفڵکردنی مۆبایل، و هەندێک مۆبایل ئەمە دەکەن تەنانەت لەگەڵیشیدا. ئەمە هێشتا لەسەر مۆبایلی ڕاستەقینە تاقی نەکراوەتەوە.';

  @override
  String get setKeepAliveRefused =>
      'ئەندرۆید ئێستا ڕێگەی نەدا. دووبارە هەوڵ بدەرەوە لەکاتێکدا ئەپەکە لەسەر شاشەیە.';

  @override
  String get setBackgroundUse => 'بەکارهێنان لە پاشبنەما';

  @override
  String get setBackgroundUseBody =>
      'ئەم مۆبایلە ئەپەکە دەوەستێنێت کەمێک دوای قفڵکردنی یان بەجێهێشتنی، و هیچ شتێک ئەپەکە بتوانێت داوای بکات ئەمە ناگۆڕێت. نامەکان کاتێک ئەپەکە کراوەیە ئاڵوگۆڕ دەکرێن.';

  @override
  String get setBatteryTitle => 'سنووردارکردنی باتری';

  @override
  String get setBatteryRestricted =>
      'هەڵکراوە: بۆ پاشەکەوتکردنی باتری، ئەندرۆید لەوانەیە دەمەتەقێ لە پاشبنەمادا بوەستێنێت، تەنانەت لەگەڵ ڕێکخستنەکەی سەرەوەش. بۆ ئەوەی تۆڕەکە بە شاشەی کوژاوەوە کار بکات، ڕێکخستنەکانی باتری بکەرەوە و «بێ سنوور» هەڵبژێرە (ناوەکان لە مۆبایلێکەوە بۆ مۆبایلێکی تر جیاوازن).';

  @override
  String get setBatteryUnrestricted =>
      'کوژاوەیە: ئەندرۆید ڕێگە بە دەمەتەقێ دەدات لە پاشبنەمادا بەبێ سنووردارکردنی باتری کار بکات. هەندێک کۆمپانیای مۆبایل سنووری خۆیان زیاد دەکەن.';

  @override
  String get setBatteryOpen => 'ڕێکخستنەکانی باتری بکەرەوە';

  @override
  String get setBatteryCouldNotOpen =>
      'ئەم مۆبایلە ڕێکخستنەکانی باتری نەکردەوە. لە ڕێکخستنەکانی مۆبایلەکەتدا، لە بەشی ئەپەکان بەدوای دەمەتەقێدا بگەڕێ.';

  @override
  String get setPermBluetooth => 'بلوتوس (ئامێرە نزیکەکان)';

  @override
  String get setPermBluetoothWhy =>
      'بۆ دۆزینەوە و قسەکردن لەگەڵ مۆبایلە نزیکەکانت. هەرگیز شوێنی تۆ نا.';

  @override
  String get setAllowed => 'ڕێگەپێدراوە';

  @override
  String get commonAllow => 'ڕێگەپێبدە';

  @override
  String get setPermMic => 'مایکرۆفۆن';

  @override
  String get setPermMicShort => 'تەنها کاتێک نامەی دەنگی تۆمار دەکەیت';

  @override
  String get setPermCamera => 'کامێرا';

  @override
  String get setPermCameraShort => 'تەنها بۆ گرتنی وێنەیەک کە دەتەوێت بینێریت';

  @override
  String get setPermPhotos => 'وێنەکان';

  @override
  String get setPermPhotosShort =>
      'تەنها بۆ هەڵبژاردنی وێنەیەک کە دەتەوێت بینێریت';

  @override
  String get setPermNotifShort =>
      'تەنها بۆ ئەوەی پێت بڵێت نامەیەک گەیشتووە لە کاتێکدا ئەپەکە لەسەر شاشە نییە';

  @override
  String get honestyNoInternetTitle => 'بێ ئینتەرنێت، بێ هەژمار، بێ سێرڤەر';

  @override
  String get honestyNoInternetBody =>
      'نامەکان لە مۆبایلەوە بۆ مۆبایل بە بلوتوسی کەم-وزە (BLE) دەگوازرێنەوە. هیچ شتێک بۆ ئینتەرنێت یان هیچ کۆمپانیایەک نانێردرێت، و هیچ شتێک نییە بۆ خۆتۆمارکردن.';

  @override
  String get honestyRangeTitle => 'ڕادە، گواستنەوە و چاوەڕوانی';

  @override
  String honestyRangeBody(
    int direct,
    int group,
    int directHours,
    int roomHours,
  ) {
    return 'یەک بەستنی بلوتوس نزیکەی 10 بۆ 30 مەتر دەگات، لە پشت دیواردا کەمتر. ئەگەر مۆبایلی خاوەن ئەپەکە لە نێواندا بن، نامەیەک دەتوانێت بەناویاندا بپەڕێتەوە: تا $direct هەنگاو بۆ نامە تایبەتەکان و $group بۆ گرووپ و ژووری گشتی. ئەگەر کەس لە ڕادەدا نەبێت، نامەی تایبەت یان نامەی گرووپ دەپارێزرێت و تا $directHours کاتژمێر دووبارە هەوڵی بۆ دەدرێت (ژووری گشتی: $roomHours کاتژمێر)، پاشان وەک «نەگەیشتوو» نیشان دەکرێت. ئەو مۆبایلانەی هاتوچۆی گرووپ و گشتی دەگوازنەوە، بۆ ئەو کەسانەش دەیپارێزن کە دواتر دێن. گواستنەوە تەنها بە ڕادیۆی نموونەکراو تاقیکراوەتەوە؛ هێشتا لەسەر مۆبایلی ڕاستەقینە نەسەلمێنراوە، بۆیە تاقیکردنەوەی بلوتوس و مۆبایلەکانی خۆت بەکاربهێنە بۆ ئەوەی بزانیت لە پراکتیکدا چۆن ڕەفتار دەکات.';
  }

  @override
  String get honestyMediaTitle => 'وێنە، نامەی دەنگی و ڤیدیۆ';

  @override
  String honestyMediaBody(int seconds) {
    return 'وێنەکان دەبچووککرێنەوە بۆ چەند دەیەک کیلۆبایت (نزیکەی 640 پیکسڵ پانی)، نامەی دەنگی بۆ $seconds چرکە سنووردار دەکرێت، و ڤیدیۆ هیچ نابچووککرێتەوە: تەنها کلیپێکی زۆر کورت دەگونجێت (سنوورەکە لە ڕێکخستنەکان > شوێنی هەڵگرتن دیاری دەکەیت). بلوتوس هێواشە: هەر هەنگاوێک چەند چرکەیەک دەخایەنێت، زیاتر ئەگەر چەند هەنگاو یان نیشانەیەکی لاواز هەبێت. هەر فایلێک پێش پیشاندان بە SHA-256 دەپشکنرێت. لە گرووپدا وێنە یان ڤیدیۆ دەتوانێت ناتەواو بمێنێتەوە ئەگەر پارچەیەکی لە هەموو ڕێگاکاندا ون بێت؛ ئەوکات وەک «وەرنەگیراو» پیشان دەدرێت. ڤیدیۆ ناتوانرێت بنێردرێت بۆ ژووری گشتی. وێنە، تۆمار و ڤیدیۆ لە هەڵگری تایبەتی ئەپەکەدا دەپارێزرێن، نەک لە گەلەری، مەگەر «پاشەکەوتکردن لە گەلەری» هەڵبژێریت.';
  }

  @override
  String get honestyBackgroundTitle => 'پاشبنەما دڵنیاکراو نییە';

  @override
  String get honestyBackgroundBody =>
      'دەمەتەقێ باشترین کار دەکات کاتێک کراوەیە. مۆبایلەکان سنوور دادەنێن بۆ ئەوەی ئەپەکان لە پاشبنەمادا چی بکەن بە بلوتوس، و ئەم ئەپە هەوڵ نادات ئەو سنوورە بشکێنێت. لە ئەندرۆیدا دەتوانیت «تۆڕەکە لە پاشبنەمادا بەردەوام بهێڵەرەوە» بکەیتەوە: کاتێک کاردەکات ئاگادارکردنەوەیەک پیشان دەدات و ئەپەکە زیاتر زیندوو دەهێڵێتەوە، بەڵام دڵنیایی نییە، و هێشتا لەسەر مۆبایلی ڕاستەقینە تاقی نەکراوەتەوە. ئەو مۆبایلانەی قفڵکراون یان ئەپەکەیان داخراوە لەوانەیە هیچ نەگوازنەوە.';

  @override
  String get honestyPrivateTitle => 'گفتوگۆی تایبەت';

  @override
  String get honestyPrivateBody =>
      'نامە، وێنە و نامە دەنگییە تایبەتەکان بە شفرەکردنی کۆتایی-بۆ-کۆتایی پارێزراون: تەنها ئەو کەسەی دەینێریت بۆی دەتوانێت بیانخوێنێتەوە، تەنانەت کاتێک مۆبایلەکانی تر دەیانگوازنەوە. ئەو مۆبایلانەی شتێک دەگوازنەوە دەتوانن ببینن کێ ناردوویەتی و بۆ کێیە (کلیلە گشتییەکانیان)، نزیکەی کەی، و قەبارەی نزیکەیی، بەڵام نەک ناوەڕۆک. هەر کەسێکی نزیک دەتوانێت ببینێت مۆبایلێک دەمەتەقێ ڕادەگەیەنێت، و ئەو ناوەی تۆ هەڵتبژاردووە.';

  @override
  String get honestyGroupsTitle => 'گرووپەکان';

  @override
  String get honestyGroupsBody =>
      'گرووپ تایبەتە: نامەکانی بە کلیلێک شفرە دەکرێن کە تەنها ئەندامەکانی هەیانە، و هیچ شتێک دەربارەی (ناوەکەی، ئەندامەکانی، بوونی) هەرگیز بڵاو ناکرێتەوە. تەنها ئەو کەسەی دروستی کردووە دەتوانێت کەس زیاد بکات یان لایببات، و هەموو گۆڕانکارییەک کلیلێکی نوێ دەداتە گرووپەکە، بۆیە ئەوەی لابراوە ناتوانێت ئەوەی دواتر دەنێردرێت بخوێنێتەوە. ئەوەی پێشتر وەریگرتووە دەمێنێتەوە لای. ئەگەر گۆڕینی کلیل دواتر لە نامەکانی دوای خۆی بگات بە ئەندامێک، لەوانەیە ئەو نامانە لەدەست بچن.';

  @override
  String get honestyRoomsTitle => 'ژووری گشتی';

  @override
  String get honestyRoomsBody =>
      'ژووری گشتی تایبەت نییە. هەرچی تێیدا دەوترێت — نووسین، وێنە و دەنگ — هەر مۆبایلێک دەیگوازێتەوە و هەر کەسێک بچێتە ناوی دەتوانێت بیخوێنێتەوە. نامەکان واژۆکراون، بۆیە گواستنەوەکار ناتوانێت وشەیەک بگۆڕێت یان نووسەرێک بسازێنێت، بەڵام ناوەکان بە ئازادی هەڵدەبژێردرێن: ناسنامە کورتەکەی دوای ناو ئەوەیە جیاوازی دەکات لە نێوان دوو کەسی هاوناو. ژووری ناوخۆیی mesh بۆ هەموو کەسانی نزیکە؛ ئەو ژوورانەی خەڵک دروستیان دەکەن بۆ مۆبایلە نزیکەکان ڕادەگەیەندرێن و دوای ڕۆژێک نامێنن مەگەر مۆبایلی دروستکەرەکەیان نوێیان بکاتەوە. نامەکانی ژووری گشتی شەش کاتژمێر دوای گەیشتنیان لەسەر ئەم مۆبایلە دەسڕدرێنەوە.';

  @override
  String get honestyDeleteTitle => 'سڕینەوە و دەستکاریکردن';

  @override
  String get honestyDeleteBody =>
      '«سڕینەوە بۆ من» نامەیەک تەنها لەسەر ئەم مۆبایلە لادەبات. «سڕینەوە بۆ هەمووان» داواکارییەک بۆ مۆبایلەکانی تر دەنێرێت: تەنها ئەگەر لە کاتی خۆیدا وەریبگرن کار دەکات، و ناگات بە لەبەرگیراوەیەک کە کەسێک پاشەکەوتی کردووە یان وێنەی گرتووە. دەستکاریکردن دەقە نوێیەکە بە هەمان شێوە دەنێرێت. هەردووکیان بۆ ماوەی دوو ڕۆژ دوای ناردنی نامەکە ئەنجامدەدرێن.';

  @override
  String get honestyVerifyTitle => 'لەگەڵ کێ قسە دەکەیت لە ڕاستیدا؟';

  @override
  String get honestyVerifyBody =>
      'یەکەم جار دوو مۆبایل یەکتر دەبینن، هیچ ڕێگایەک نییە بزانیت کلیلێک بەڕاستی هی ئەو کەسە بێت. لاپەڕەی پەیوەندییەکەی بکەرەوە، ژمارەی پاراستن لەگەڵی بەراورد بکە بە ڕووبەڕوو یان لە پەیوەندییەکی متمانەپێکراودا، و تەنها ئەوکات وەک پشتڕاستکراو نیشانەی بکە. تا ئەوکات، ناوەکان وەک پشتڕاستنەکراو لەبەرچاو بگرە.';

  @override
  String get honestyStoredTitle => 'چی لەسەر ئەم مۆبایلە هەڵدەگیرێت';

  @override
  String get honestyStoredBody =>
      'کلیلەکانت (و کلیلی گرووپەکانت) لە هەڵگری پارێزراوی مۆبایلەکەدا دەپارێزرێن (Android Keystore / iOS Keychain). مێژووی گفتوگۆ، وێنە و تۆمارەکان لە هەڵگری تایبەتی ئەپەکەدا هەڵدەگیرێن بەبێ چینێکی زیادەی شفرەکردن لە دەرەوەی قفڵی شاشە و شفرەکردنی دیسکی خودی مۆبایلەکەت، و لە ئایفۆندا لەوانەیە لەناو پاشەکەوتی ئامێرەکەدا بن. هەر کەسێک مۆبایلەکەت بکاتەوە دەتوانێت گفتوگۆکانت بخوێنێتەوە.';

  @override
  String get honestyAuditTitle => 'بە سەربەخۆیی پشکنین نەکراوە';

  @override
  String get honestyAuditBody =>
      'شفرەکردنەکە ئەلگۆریتمی ستانداردی بەکاردەهێنێت (HPKE لەگەڵ X25519 و ChaCha20-Poly1305، واژۆی Ed25519)، و شفرەکردنی بنەڕەتی لە بەرامبەر نموونە تاقیکارییە بڵاوکراوەکاندا تاقیکراوەتەوە. بەڵام کۆدی ئەم ئەپە لەلایەن شارەزایەکی پاراستنی سەربەخۆوە پێداچوونەوەی بۆ نەکراوە. پشتی پێ مەبەستە لەو شوێنانەی ئاسایش یان ئازادیت پێوە بەندە.';

  @override
  String get reachDirectLong => 'ڕاستەوخۆ پەیوەندیدارە';

  @override
  String reachRelayLong(int hops) {
    return 'بە گواستنەوە ($hops هەنگاو)';
  }

  @override
  String get reachOffline => 'ئۆفلاین';

  @override
  String get reachDirectShort => 'ڕاستەوخۆ';

  @override
  String reachRelayShort(int hops) {
    return 'گواستنەوە · $hops هەنگاو';
  }

  @override
  String get deliveryPending => 'چاوەڕوان';

  @override
  String deliverySentCount(int done, int total) {
    return 'نێردرا · $done/$total';
  }

  @override
  String get deliverySent => 'نێردرا';

  @override
  String get deliveryDelivered => 'گەیشت';

  @override
  String deliveryDeliveredVia(int hops) {
    return 'گەیشت · $hops هەنگاو';
  }

  @override
  String get deliveryFailed => 'نەگەیشت';

  @override
  String get deliveryUndecryptable =>
      'نەتوانرا شفرەکەی لابدرێت یان پشتڕاست بکرێتەوە';

  @override
  String get connError => 'هەڵەی بلوتوس';

  @override
  String get connStarting => 'دەست پێدەکات…';

  @override
  String get connNotStarted => 'دەستی پێنەکردووە';

  @override
  String get connNotSupported => 'پشتگیری ناکرێت';

  @override
  String get connPermissionNeeded => 'ڕێگەپێدان پێویستە';

  @override
  String get connBluetoothOff => 'بلوتوس کوژاوەتەوە';

  @override
  String connNearbyRelayed(int direct, int relayed) {
    return '$direct نزیک · $relayed بە گواستنەوە';
  }

  @override
  String connNearby(int direct) {
    return '$direct نزیک';
  }

  @override
  String connViaRelay(int relayed) {
    return '$relayed بە گواستنەوە';
  }

  @override
  String get connSearching => 'دەگەڕێت…';

  @override
  String get offlineTipNone =>
      'ئینتەرنێت نییە. دەمەتەقێ پێویستی پێی نییە: نامەکان بە بلوتوس دەگوازرێنەوە.';

  @override
  String get offlineTipOn =>
      'مۆبایلەکە ئینتەرنێتی هەیە، بەڵام دەمەتەقێ بەکاری ناهێنێت: نامەکان بە بلوتوس دەگوازرێنەوە.';

  @override
  String get offlineBadge => 'ئۆفلاین';

  @override
  String get internetOnBadge => 'ئینتەرنێت کارایە';

  @override
  String navUnreadLabel(String label, int count) {
    return '$label، $count نەخوێندراوە';
  }

  @override
  String peerSeenAgo(String ago) {
    return 'بینراو $ago';
  }

  @override
  String get peerNoKeyYet => 'هێشتا کلیلی شفرەکردنی نییە';

  @override
  String get commonStart => 'دەستپێکردن';

  @override
  String get commonOpenSettings => 'کردنەوەی ڕێکخستنەکان';

  @override
  String get commonDismiss => 'داخستن';

  @override
  String get radioCouldNotStart => 'بلوتوس دەستی پێنەکرد';

  @override
  String get radioNotStarted => 'بلوتوس دەستی پێنەکردووە';

  @override
  String get radioNotStartedBody =>
      'دەمەتەقێ پێویستی بە بلوتوس هەیە بۆ دۆزینەوە و قسەکردن لەگەڵ مۆبایلە نزیکەکان.';

  @override
  String get radioNotVisible =>
      'ئەم مۆبایلە ناتوانرێت لەلایەن ئەوانی ترەوە بدۆزرێتەوە';

  @override
  String get radioNotVisibleBody =>
      'دەتوانێت مۆبایلەکانی تر بدۆزێتەوە و پەیوەندییان پێوە بکات، بەڵام ناتوانێت خۆی بە بلوتوس بناسێنێت. دوو مۆبایل کە هەردووکیان ئەمەیان نییە ناتوانن پەیوەندی بە یەکتر بکەن.';

  @override
  String get radioNoBle => 'بلوتوسی کەم-وزە بەردەست نییە';

  @override
  String get radioNoBleBody =>
      'ئەم ئامێرە پشتگیری تایبەتمەندییەکی بلوتوس ناکات کە دەمەتەقێ لەسەری دروستکراوە، بۆیە ناتوانێت بەشداری لە تۆڕەکەدا بکات.';

  @override
  String get radioPermission => 'ڕێگەپێدانی بلوتوس پێویستە';

  @override
  String get radioPermissionBody =>
      'دەمەتەقێ پێویستی بە ڕێگەپێدان هەیە بۆ بەکارهێنانی بلوتوس (ڕێگەپێدانی «ئامێرە نزیکەکان» لە ئەندرۆیدی نوێ، بلوتوس لە ئایفۆن) بۆ دۆزینەوە و قسەکردن لەگەڵ مۆبایلە نزیکەکان. هەرگیز شوێنی تۆ بەکارناهێنێت.';

  @override
  String get radioAllow => 'ڕێگە بە بلوتوس بدە';

  @override
  String get radioOff => 'بلوتوس کوژاوەتەوە';

  @override
  String get radioOffBody =>
      'بلوتوس لە ڕێکخستنە خێراکانی مۆبایلەکەتدا بکەرەوە. دەمەتەقێ خۆی دووبارە بە مۆبایلە نزیکەکانەوە دەبەستێتەوە.';

  @override
  String get radioProblem => 'کێشەی بلوتوس';

  @override
  String get identityResetTitle => 'ناسنامەکەت ڕیسێت کرایەوە';

  @override
  String get identityResetBody =>
      'نەتوانرا کلیلەکانی شفرەکردنت لە هەڵگری پارێزراوی ئەم مۆبایلە بخوێنرێنەوە، بۆیە ناسنامەیەکی نوێ دروست کرا. پەیوەندییەکانت پێویستە دووبارە پشتڕاستت بکەنەوە، و ئەو نامانەی بۆ ناسنامە کۆنەکەت نێردراون چیتر ناخوێنرێنەوە.';

  @override
  String get versionNewerTitle => 'وەشانێکی نوێتری دەمەتەقێ لە نزیکە';

  @override
  String get versionNewerBody =>
      'مۆبایلێک لە نزیکت وەشانێکی نوێتری دەمەتەقێ بەکاردەهێنێت. ئەو دوو مۆبایلە ناتوانن قسە لەگەڵ یەکتر بکەن تا ئەم مۆبایلەش نوێ نەکرێتەوە.';

  @override
  String get versionOlderTitle => 'مۆبایلێکی نزیک پێویستی بە نوێکردنەوە هەیە';

  @override
  String get versionOlderBody =>
      'مۆبایلێک لە نزیکت وەشانێکی کۆنتری دەمەتەقێ بەکاردەهێنێت. ئەو دوو مۆبایلە ناتوانن قسە لەگەڵ یەکتر بکەن تا ئەو مۆبایلەش نوێ نەکرێتەوە.';

  @override
  String get permMicTitle => 'ڕێگە بە مایکرۆفۆن دەدەیت؟';

  @override
  String get permMicWhy =>
      'دەمەتەقێ تەنها کاتێک مایکرۆفۆنی پێویستە کە نامەی دەنگی تۆمار دەکەیت.';

  @override
  String get permMicPrivacy =>
      'تۆمارەکە بە بلوتوس دەچێت بۆ ئەو کەسانەی لەو گفتوگۆیەدان و هەرگیز بۆ هیچ شوێنێک بارناکرێت. کاتێک تۆمارێکت کراوە نییە هیچ شتێک تۆمار ناکرێت.';

  @override
  String get permMicThing => 'مایکرۆفۆن';

  @override
  String get permMicOff => 'مایکرۆفۆن کوژێنراوەتەوە';

  @override
  String get permCameraTitle => 'ڕێگە بە کامێرا دەدەیت؟';

  @override
  String get permCameraWhy =>
      'دەمەتەقێ کامێرای پێویستە بۆ گرتنی ئەو وێنەیەی دەتەوێت بینێریت.';

  @override
  String get permCameraPrivacy =>
      'وێنەکە دەبچووککرێتەوە و بە بلوتوس دەنێردرێت بۆ ئەو کەسانەی لەو گفتوگۆیەدان. لە گەلەریەکەت پاشەکەوت ناکرێت و هەرگیز بۆ هیچ شوێنێک بارناکرێت.';

  @override
  String get permCameraThing => 'کامێرا';

  @override
  String get permCameraOff => 'کامێرا کوژێنراوەتەوە';

  @override
  String get permPhotosTitle => 'ڕێگە بە دەستگەیشتن بە وێنەکانت دەدەیت؟';

  @override
  String get permPhotosWhy =>
      'دەمەتەقێ پێویستە کتێبخانەی وێنەکانت بکاتەوە تا بتوانیت وێنەیەک هەڵبژێریت بۆ ناردن.';

  @override
  String get permPhotosPrivacy =>
      'تەنها ئەو وێنەیەی هەڵیدەبژێریت بەکاردێت. دەبچووککرێتەوە و بە بلوتوس دەنێردرێت بۆ ئەو کەسانەی لەو گفتوگۆیەدان، و هەرگیز بۆ هیچ شوێنێک بارناکرێت.';

  @override
  String get permPhotosThing => 'وێنەکانت';

  @override
  String get permPhotosOff => 'دەستگەیشتن بە وێنەکانت کوژێنراوەتەوە';

  @override
  String get permNotifTitle => 'ڕێگە بە ئاگادارکردنەوەکان دەدەیت؟';

  @override
  String get permNotifWhy =>
      'دەمەتەقێ ئاگادارکردنەوە بەکاردەهێنێت بۆ ئەوەی پێت بڵێت کاتێک نامەیەک دێت لە کاتێکدا ئەپەکە داخراوە یان لە پاشبنەمایە.';

  @override
  String get permNotifPrivacy =>
      'تۆ هەڵدەبژێریت ئاگادارکردنەوەکە چەندی پیشان بدات: ناو و نامە، تەنها ناو، یان تەنها «نامەی نوێ». ئاگادارکردنەوەکان لەسەر ئەم مۆبایلە لە نامەکانی گەیشتوون دروست دەکرێن؛ هیچ شتێک بۆ هیچ سێرڤەرێک نانێردرێت.';

  @override
  String get permNotifThing => 'ئاگادارکردنەوەکان';

  @override
  String get permNotifOff => 'ئاگادارکردنەوەکان کوژێنراونەتەوە';

  @override
  String get permNotAvailable => 'بەردەست نییە';

  @override
  String permUnavailableBody(String thing) {
    return 'ئەم مۆبایلە ڕێگە بە دەمەتەقێ نادات $thing بەکاربهێنێت (لەوانەیە لەلایەن دایک و باوک یان بەڕێوەبەرەوە سنووردار کرابێت).';
  }

  @override
  String get permNotNow => 'ئێستا نا';

  @override
  String get permTurnOnInSettings =>
      'بۆ بەکارهێنانی، لە ڕێکخستنەکانی مۆبایلەکەتدا بۆ دەمەتەقێ بیکەرەوە. هیچ شتێکی تری ئەپەکە پێویستی پێی نییە.';

  @override
  String get voicePause => 'وەستاندنی نامە دەنگییەکە';

  @override
  String get voicePlay => 'لێدانی نامە دەنگییەکە';

  @override
  String get mediaNotReceived => 'نەتوانرا وەربگیرێت';

  @override
  String mediaReceiving(int percent) {
    return 'وەرگرتن… $percent%';
  }

  @override
  String get pictureNotReceived => 'نەتوانرا وێنەکە وەربگیرێت';

  @override
  String get videoCannotPlay =>
      'ئەم ڤیدیۆیە ناتوانرێت لەسەر ئەم مۆبایلە لێبدرێت.';

  @override
  String get videoNotReceived => 'نەتوانرا ڤیدیۆکە وەربگیرێت';

  @override
  String videoReceiving(int percent) {
    return 'وەرگرتنی ڤیدیۆ… $percent%';
  }

  @override
  String get videoPlay => 'لێدانی ڤیدیۆ';

  @override
  String introDirectTitle(String name) {
    return 'سڵاو لە $name بکە';
  }

  @override
  String introGroupTitle(String name) {
    return 'بەخێربێیت بۆ $name';
  }

  @override
  String get fwdNoVideoInRooms => 'ڤیدیۆ ناتوانرێت بنێردرێت بۆ ژووری گشتی';

  @override
  String get setNotifyNotAllowed =>
      'ئاگادارکردنەوەکان لێرە چالاکن، بەڵام مۆبایلەکە هێشتا ڕێگەی پێنەداون، بۆیە هیچ ئاگادارکردنەوەیەک پیشان نادرێت.';
}
