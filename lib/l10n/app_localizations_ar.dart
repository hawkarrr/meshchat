// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String authorUnknown(String tag) {
    return 'مجهول $tag';
  }

  @override
  String get actEditingGone => 'الرسالة التي كنت تعدّلها لم تعد موجودة.';

  @override
  String get actReplyingGone => 'تم حذف الرسالة التي كنت ترد عليها.';

  @override
  String get actNoTextToCopy => 'لا يوجد نص لنسخه.';

  @override
  String get actCopied => 'تم النسخ';

  @override
  String actCopiedMany(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تم نسخ $count رسالة',
      few: 'تم نسخ $count رسائل',
      two: 'تم نسخ رسالتين',
    );
    return '$_temp0';
  }

  @override
  String get actSaveTitle => 'الحفظ في معرض الصور؟';

  @override
  String get actSaveBodyPicture =>
      'يحتفظ دەمەتەقێ بهذه الصورة في مساحته الخاصة. يضع الحفظ نسخة في معرض صور هاتفك، حيث تراها التطبيقات الأخرى وتبقى حتى لو حذفت الرسالة هنا. قد يطلب هاتفك إذنًا لحفظ الملفات.';

  @override
  String get actSaveBodyVideo =>
      'يحتفظ دەمەتەقێ بهذا الفيديو في مساحته الخاصة. يضع الحفظ نسخة في معرض صور هاتفك، حيث تراها التطبيقات الأخرى وتبقى حتى لو حذفت الرسالة هنا. قد يطلب هاتفك إذنًا لحفظ الملفات.';

  @override
  String actSaveBodyFiles(int count) {
    return 'يحتفظ دەمەتەقێ بهذه الملفات ($count) في مساحته الخاصة. يضع الحفظ نسخة في معرض صور هاتفك، حيث تراها التطبيقات الأخرى وتبقى حتى لو حذفت الرسالة هنا. قد يطلب هاتفك إذنًا لحفظ الملفات.';
  }

  @override
  String get actSaved => 'تم الحفظ في معرض الصور';

  @override
  String actSavedMany(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تم حفظ $count ملف في معرض الصور',
      many: 'تم حفظ $count ملفًا في معرض الصور',
      few: 'تم حفظ $count ملفات في معرض الصور',
      two: 'تم حفظ ملفين في معرض الصور',
    );
    return '$_temp0';
  }

  @override
  String actSavedSome(int saved, int total, String reason) {
    return 'تم حفظ $saved من $total. $reason';
  }

  @override
  String get actPinnedNote => 'تم التثبيت. أنت فقط ترى هذا التثبيت.';

  @override
  String get actUnpinnedNote => 'تم إلغاء التثبيت';

  @override
  String get actForwardPublicTitle => 'إعادة التوجيه إلى غرفة عامة؟';

  @override
  String get actForwardPublicBody =>
      'يمكن لكل من حولك قراءة ما تعيد توجيهه هناك، ولن يعود خاصًا، ويظهر اسم من كتبه. يختفي من الهواتف بعد ست ساعات.';

  @override
  String get actForwardPublicAction => 'إعادة توجيه علنية';

  @override
  String get actTheChat => 'المحادثة';

  @override
  String actForwardedTo(String title) {
    return 'تمت إعادة التوجيه إلى $title';
  }

  @override
  String actForwardedMany(int count, String title) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تمت إعادة توجيه $count رسالة إلى $title',
      few: 'تمت إعادة توجيه $count رسائل إلى $title',
      two: 'تمت إعادة توجيه رسالتين إلى $title',
    );
    return '$_temp0';
  }

  @override
  String actForwardedSome(int sent, int total, String title) {
    return 'تمت إعادة توجيه $sent من $total إلى $title. تعذّرت قراءة الباقي أو أن ملفه غير مكتمل.';
  }

  @override
  String actNothingDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'لم يُحذف شيء: الرسائل محذوفة بالفعل.',
      one: 'لم يُحذف شيء: الرسالة محذوفة بالفعل.',
    );
    return '$_temp0';
  }

  @override
  String actDeletedUnsent(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تم الحذف. لم تُرسل بعد، لذا لن يستلمها أحد.',
      one: 'تم الحذف. لم تُرسل بعد، لذا لن يستلمها أحد.',
    );
    return '$_temp0';
  }

  @override
  String actDeletedManyHere(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تم حذف $count رسالة من هذا الهاتف.',
      few: 'تم حذف $count رسائل من هذا الهاتف.',
      two: 'تم حذف رسالتين من هذا الهاتف.',
    );
    return '$_temp0';
  }

  @override
  String get actDeletedHere => 'تم الحذف من هذا الهاتف.';

  @override
  String actDeletedAskedOthers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تم الحذف هنا. ستزيلها الهواتف الأخرى عندما تستلم الطلب.',
      one: 'تم الحذف هنا. ستزيلها الهواتف الأخرى عندما تستلم الطلب.',
    );
    return '$_temp0';
  }

  @override
  String actDeletedNeverSent(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تم الحذف. لم يُرسل شيء بعد، لذا لن يستلمها أي شخص آخر أبدًا.',
      one: 'تم الحذف. لم يُرسل شيء بعد، لذا لن يستلمها أي شخص آخر أبدًا.',
    );
    return '$_temp0';
  }

  @override
  String actUnpinnedCount(int count) {
    return 'تم إلغاء تثبيت $count';
  }

  @override
  String actPinnedCount(int count) {
    return 'تم تثبيت $count. أنت فقط ترى هذه التثبيتات.';
  }

  @override
  String get actSelectAll => 'تحديد الكل';

  @override
  String get actFurtherBack => 'هذه الرسالة أقدم مما تعرضه هذه المحادثة.';

  @override
  String pinnedListTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count رسالة مثبتة',
      few: '$count رسائل مثبتة',
      two: 'رسالتان مثبتتان',
      one: 'رسالة مثبتة واحدة',
    );
    return '$_temp0';
  }

  @override
  String get pinnedListNote => 'التثبيتات لك وحدك: لا يراها أحد غيرك.';

  @override
  String get pinnedListEmpty => 'لا شيء مثبّت.';

  @override
  String get startupErrorTitle => 'تعذّر تشغيل دەمەتەقێ';

  @override
  String get startupErrorBody =>
      'تعذّر على التطبيق فتح مساحة التخزين الخاصة به أو تحميل مفاتيحك. لم يُحذف أي شيء، ولا يتم استبدال هويتك أبدًا لمجرد تعذّر قراءتها. حاول مرة أخرى؛ وإن استمر الفشل فأعد تشغيل الهاتف. وكحل أخير، فإن إلغاء تثبيت التطبيق وإعادة تثبيته يمسح التخزين التالف، لكنه يحذف أيضًا محادثاتك وهويتك.';

  @override
  String get commonTryAgain => 'حاول مرة أخرى';

  @override
  String get commonCancel => 'إلغاء';

  @override
  String get commonOk => 'حسنًا';

  @override
  String get commonClose => 'إغلاق';

  @override
  String get commonDone => 'تم';

  @override
  String get commonSave => 'حفظ';

  @override
  String get commonDelete => 'حذف';

  @override
  String get commonRemove => 'إزالة';

  @override
  String get commonBack => 'رجوع';

  @override
  String get commonSearch => 'بحث';

  @override
  String get commonSend => 'إرسال';

  @override
  String get commonCopy => 'نسخ';

  @override
  String get commonShare => 'مشاركة';

  @override
  String get commonMore => 'المزيد';

  @override
  String get commonYes => 'نعم';

  @override
  String get commonNo => 'لا';

  @override
  String get commonOn => 'يعمل';

  @override
  String get commonOff => 'متوقف';

  @override
  String get commonYou => 'أنت';

  @override
  String get commonLoading => 'جارٍ التحميل…';

  @override
  String get actReply => 'رد';

  @override
  String get actCopyCaption => 'نسخ التعليق';

  @override
  String get actCopyText => 'نسخ النص';

  @override
  String get actForward => 'إعادة توجيه';

  @override
  String get actSaveToGallery => 'حفظ في المعرض';

  @override
  String get actSendAgain => 'إعادة الإرسال';

  @override
  String get actUnpin => 'إلغاء التثبيت';

  @override
  String get actPin => 'تثبيت';

  @override
  String get actEdit => 'تعديل';

  @override
  String get actSelect => 'تحديد';

  @override
  String get actDetails => 'التفاصيل';

  @override
  String deleteTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'حذف $count رسالة؟',
      few: 'حذف $count رسائل؟',
      two: 'حذف الرسالتين؟',
      one: 'حذف الرسالة؟',
    );
    return '$_temp0';
  }

  @override
  String deleteForMeNote(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '«حذف عندي» يزيل الرسائل من هذا الهاتف فقط. ويحتفظ الجميع بنسختهم.',
      one: '«حذف عندي» يزيل الرسالة من هذا الهاتف فقط. ويحتفظ الجميع بنسختهم.',
    );
    return '$_temp0';
  }

  @override
  String deleteEveryoneDirect(int count, String who) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '«حذف للجميع» يطلب من هاتف $who إزالة الرسائل. إنه مجرد طلب: يسري عندما يستلمه هاتفه (يجب أن يدخل النطاق خلال نحو 12 ساعة). لا يمكن الوصول إلى نسخة حفظها أحد أو صوّرها.',
      one:
          '«حذف للجميع» يطلب من هاتف $who إزالة الرسالة. إنه مجرد طلب: يسري عندما يستلمه هاتفه (يجب أن يدخل النطاق خلال نحو 12 ساعة). لا يمكن الوصول إلى نسخة حفظها أحد أو صوّرها.',
    );
    return '$_temp0';
  }

  @override
  String deleteEveryoneGroup(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '«حذف للجميع» يطلب من هاتف كل عضو إزالة الرسائل. إنه مجرد طلب: يسري على كل هاتف عندما يستلمه، والهاتف الخارج عن النطاق يستلمه لاحقًا إن عاد في الوقت المناسب. لا يمكن الوصول إلى نسخة حفظها أحد أو صوّرها.',
      one: '«حذف للجميع» يطلب من هاتف كل عضو إزالة الرسالة. إنه مجرد طلب: يسري على كل هاتف عندما يستلمه، والهاتف الخارج عن النطاق يستلمه لاحقًا إن عاد في الوقت المناسب. لا يمكن الوصول إلى نسخة حفظها أحد أو صوّرها.',
    );
    return '$_temp0';
  }

  @override
  String deleteEveryoneRoom(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'الرسائل إزالتها',
      one: 'الرسالة إزالتها',
    );
    return '«حذف للجميع» يطلب من كل هاتف قريب لديه $_temp0. إنه مجرد طلب: يسري على كل هاتف عندما يستلمه، والهاتف الخارج عن النطاق يستلمه لاحقًا إن عاد في الوقت المناسب. لا يمكن الوصول إلى نسخة حفظها أحد أو صوّرها.';
  }

  @override
  String get deleteEveryoneOwnOnly => '«حذف للجميع» ممكن لرسائلك أنت فقط.';

  @override
  String get deleteEveryoneOwnOrAdmin =>
      '«حذف للجميع» ممكن لرسائلك أنت فقط (ولمشرف المجموعة).';

  @override
  String get deleteForMe => 'حذف عندي';

  @override
  String get deleteForEveryone => 'حذف للجميع';

  @override
  String get selCancel => 'إلغاء التحديد';

  @override
  String selCount(int count) {
    return '$count محدد';
  }

  @override
  String get quoteOriginalDeleted => 'تم حذف الرسالة الأصلية';

  @override
  String forwardedFrom(String name) {
    return 'معاد توجيهها من $name';
  }

  @override
  String pinnedOf(int index, int count) {
    return 'الرسالة المثبتة $index من $count';
  }

  @override
  String get pinnedMessage => 'رسالة مثبتة';

  @override
  String get pinnedAll => 'كل الرسائل المثبتة';

  @override
  String delWaiting(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'في انتظار تأكيد هاتف $name لحذف $count رسالة. سيحدث ذلك فور أن تصبح في النطاق.',
      few:
          'في انتظار تأكيد هاتف $name لحذف $count رسائل. سيحدث ذلك فور أن تصبح في النطاق.',
      two:
          'في انتظار تأكيد هاتف $name لحذف رسالتين. سيحدث ذلك فور أن تصبح في النطاق.',
      one:
          'في انتظار تأكيد هاتف $name لحذف رسالة. سيحدث ذلك فور أن تصبح في النطاق.',
    );
    return '$_temp0';
  }

  @override
  String delExpired(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'لم يصل هاتف $name $count طلب حذف في الوقت المناسب، لذا قد تكون تلك الرسائل ما تزال هناك.',
      few:
          'لم يصل هاتف $name $count طلبات حذف في الوقت المناسب، لذا قد تكون تلك الرسائل ما تزال هناك.',
      two:
          'لم يصل هاتف $name طلبا حذف في الوقت المناسب، لذا قد تكون تلك الرسالتان ما تزالان هناك.',
      one:
          'لم يصل هاتف $name طلب حذف في الوقت المناسب، لذا قد تكون تلك الرسالة ما تزال هناك.',
    );
    return '$_temp0';
  }

  @override
  String get snippetUnreadable => 'تعذّرت قراءة الرسالة';

  @override
  String replyingTo(String name) {
    return 'رد على $name';
  }

  @override
  String get editMessageTitle => 'تعديل الرسالة';

  @override
  String get cancelEditing => 'إلغاء التعديل';

  @override
  String get cancelReply => 'إلغاء الرد';

  @override
  String get bubbleUndecryptable =>
      'تعذّر فك تشفير هذه الرسالة أو التحقق منها، لذا لم تُعرض. ربما تعرضت للتلف أو العبث أو شُفّرت لمفتاح مختلف.';

  @override
  String get bubblePicture => 'صورة';

  @override
  String get bubbleVideo => 'فيديو';

  @override
  String get bubbleVoice => 'رسالة صوتية';

  @override
  String get bubbleEdited => 'معدّلة';

  @override
  String bubbleViaRelays(int hops) {
    String _temp0 = intl.Intl.pluralLogic(
      hops,
      locale: localeName,
      other: 'عبر $hops مُرحِّل',
      many: 'عبر $hops مُرحِّلًا',
      few: 'عبر $hops مُرحِّلات',
      two: 'عبر مُرحِّلين',
      one: 'عبر مُرحِّل واحد',
    );
    return '$_temp0';
  }

  @override
  String get bubbleNotDelivered => 'تعذّر تسليم هذه الرسالة.';

  @override
  String composerCouldNotSend(String error) {
    return 'تعذّر الإرسال: $error';
  }

  @override
  String get attachSendPicture => 'إرسال صورة';

  @override
  String get attachTakePhoto => 'التقاط صورة';

  @override
  String get attachChoosePhoto => 'اختيار من صورك';

  @override
  String get attachPictureNote =>
      'يتم تصغير الصور إلى بضع عشرات من الكيلوبايت لتعبر البلوتوث، وتُرسل فقط إلى الأشخاص في هذه المحادثة.';

  @override
  String get attachSendVideo => 'إرسال فيديو';

  @override
  String get attachRecordVideo => 'تسجيل فيديو قصير';

  @override
  String get attachChooseVideo => 'اختيار فيديو';

  @override
  String attachVideoNote(String limit) {
    return 'لا يتم تصغير الفيديو: فقط مقطع قصير جدًا ومنخفض الجودة (حتى $limit) يمكنه عبور البلوتوث، وقد يستغرق دقائق. أما الأكبر فيُرفض. يمكنك تغيير الحد من الإعدادات > التخزين.';
  }

  @override
  String get composerAllowPicture => 'اسمح بالوصول لإرسال صورة.';

  @override
  String composerOpenCameraFailed(String error) {
    return 'تعذّر فتح الكاميرا: $error';
  }

  @override
  String composerOpenPhotosFailed(String error) {
    return 'تعذّر فتح الصور: $error';
  }

  @override
  String composerOpenVideosFailed(String error) {
    return 'تعذّر فتح الفيديوهات: $error';
  }

  @override
  String composerPictureNotPrepared(String error) {
    return 'تعذّر تجهيز هذه الصورة: $error';
  }

  @override
  String get composerAllowVideo => 'اسمح بالوصول لإرسال فيديو.';

  @override
  String composerVideoTooBig(String size, String limit, String max) {
    return 'حجم هذا الفيديو $size. عبر البلوتوث يمكن أن يصل الفيديو إلى $limit كحد أقصى (يمكنك رفع ذلك من الإعدادات > التخزين، حتى $max). اختر مقطعًا أقصر أو أصغر.';
  }

  @override
  String get composerAllowMic => 'اسمح باستخدام الميكروفون لتسجيل رسالة صوتية.';

  @override
  String composerRecordFailed(String error) {
    return 'تعذّر بدء التسجيل: $error';
  }

  @override
  String get composerVoiceTooShort =>
      'كان ذلك أقصر من أن يكون رسالة صوتية. أبقِ الميكروفون مفتوحًا لوقت أطول قليلًا.';

  @override
  String composerBytesCounter(int bytes, int max) {
    return '$bytes / $max بايت';
  }

  @override
  String get composerTooLong => 'طويل جدًا';

  @override
  String get composerSaveChanges => 'حفظ التغييرات';

  @override
  String get composerRecord => 'تسجيل رسالة صوتية';

  @override
  String get composerDiscard => 'تجاهل التسجيل';

  @override
  String get composerSendVoice => 'إرسال الرسالة الصوتية';

  @override
  String get previewSendPicture => 'إرسال هذه الصورة؟';

  @override
  String get previewSendVideo => 'إرسال هذا الفيديو؟';

  @override
  String get previewCaptionHint => 'أضف تعليقًا (اختياري)';

  @override
  String get previewVideoNote =>
      'يُرسل عبر البلوتوث، فقط إلى الأشخاص في هذه المحادثة، وقد يستغرق عدة دقائق — وأكثر عندما يضطر للمرور عبر هواتف أخرى. يجب أن يبقى الشخص ضمن النطاق والتطبيق مفتوح حتى يصل.';

  @override
  String get chatFallbackLower => 'محادثة';

  @override
  String get chatSearchTooltip => 'بحث في هذه المحادثة';

  @override
  String get chatFallbackGroup => 'مجموعة';

  @override
  String get chatFallbackChat => 'محادثة';

  @override
  String chatGroupMembers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count عضو',
      many: '$count عضوًا',
      few: '$count أعضاء',
      two: 'عضوان',
      one: 'عضو واحد',
    );
    return '$_temp0';
  }

  @override
  String chatGroupMembersNearby(int count, int nearby) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count عضو · $nearby قريب',
      many: '$count عضوًا · $nearby قريب',
      few: '$count أعضاء · $nearby قريب',
      two: 'عضوان · $nearby قريب',
      one: 'عضو واحد · $nearby قريب',
    );
    return '$_temp0';
  }

  @override
  String get chatInvitation => 'دعوة';

  @override
  String get chatGroupDetails => 'تفاصيل المجموعة';

  @override
  String get chatVerifiedContact => 'جهة اتصال موثّقة';

  @override
  String get chatVerifyContact => 'تحقق من جهة الاتصال هذه';

  @override
  String get chatTheOtherPerson => 'الشخص الآخر';

  @override
  String get composerHint => 'رسالة';

  @override
  String get chatRemovedFromGroup => 'تمت إزالتك من هذه المجموعة';

  @override
  String get chatYouBlocked => 'لقد حظرت جهة الاتصال هذه';

  @override
  String get chatEmptyGroup =>
      'لا توجد رسائل بعد. كل شيء هنا مشفّر بمفتاح المجموعة ويصل إلى كل عضو، الآن أو عندما يصبح ضمن النطاق في المرة القادمة.';

  @override
  String get chatEmptyDirect =>
      'لا توجد رسائل بعد. الرسائل مشفّرة من طرف إلى طرف، وتنتظر هنا إن كان الهاتف الآخر خارج النطاق.';

  @override
  String get chatToday => 'اليوم';

  @override
  String get stripWaitingForKey =>
      'في انتظار مفتاح التشفير الخاص بهذا الشخص. يصل تلقائيًا أول مرة تكون فيها ضمن نطاقه.';

  @override
  String get stripDirect => 'متصل مباشرة. تُسلَّم الرسائل فورًا.';

  @override
  String stripRelayed(int hops) {
    return 'يمكن الوصول إليه عبر هواتف أخرى ($hops قفزات). تُنقل الرسائل وتبقى مشفّرة من طرف إلى طرف.';
  }

  @override
  String get stripOffline =>
      'لا يمكن الوصول إليه الآن. تنتظر الرسائل على هذا الهاتف وتُرسل فور أن يصبح هذا الشخص (أو هاتف يستطيع الوصول إليه) ضمن النطاق، لمدة تصل إلى 12 ساعة.';

  @override
  String fwdTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'إعادة توجيه $count رسالة إلى…',
      few: 'إعادة توجيه $count رسائل إلى…',
      two: 'إعادة توجيه رسالتين إلى…',
      one: 'إعادة التوجيه إلى…',
    );
    return '$_temp0';
  }

  @override
  String get fwdSearchHint => 'ابحث في المحادثات';

  @override
  String get fwdNoTargets =>
      'لا توجد محادثة لإعادة التوجيه إليها بعد. ابدأ محادثة مع شخص قريب أولًا.';

  @override
  String fwdNoMatch(String query) {
    return 'لا توجد محادثة تطابق \"$query\".';
  }

  @override
  String get fwdPrivateChat => 'محادثة خاصة';

  @override
  String get fwdPublicRoom => 'غرفة عامة · يمكن لكل من حولك قراءتها';

  @override
  String get commonClear => 'مسح';

  @override
  String searchInTitle(String title) {
    return 'بحث في $title';
  }

  @override
  String get searchPictures => 'الصور';

  @override
  String get searchVideos => 'الفيديوهات';

  @override
  String get searchVoice => 'صوت';

  @override
  String get searchFromMe => 'مني';

  @override
  String get searchEmptyBody =>
      'اكتب كلمة، أو اختر الصور أو الفيديوهات أو الصوت لعرضها فقط. لا يُبحث في الرسائل المحذوفة: فهي اختفت.';

  @override
  String get searchNoMatch => 'لا توجد رسالة في هذه المحادثة تطابق البحث.';

  @override
  String get detailUnknownPhone => 'هاتف غير معروف';

  @override
  String get detailAnyMoment => 'في أي لحظة';

  @override
  String detailInMinutes(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'بعد $minutes دقيقة',
      few: 'بعد $minutes دقائق',
      two: 'بعد دقيقتين',
      one: 'بعد دقيقة',
    );
    return '$_temp0';
  }

  @override
  String detailInHours(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: 'بعد $hours ساعة',
      few: 'بعد $hours ساعات',
      two: 'بعد ساعتين',
      one: 'بعد ساعة',
    );
    return '$_temp0';
  }

  @override
  String detailInHoursMinutes(int hours, int minutes) {
    return 'بعد $hours ساعة و$minutes دقيقة';
  }

  @override
  String get detailTitle => 'تفاصيل الرسالة';

  @override
  String get detailFrom => 'من';

  @override
  String get detailDirection => 'الاتجاه';

  @override
  String get detailSentByYou => 'أرسلتها أنت';

  @override
  String get detailReceived => 'مستلمة';

  @override
  String get detailType => 'النوع';

  @override
  String get detailSize => 'الحجم';

  @override
  String get detailStatus => 'الحالة';

  @override
  String get detailConfirmedBy => 'أكّدها';

  @override
  String detailConfirmedOf(int done, int total) {
    return '$done من $total أعضاء';
  }

  @override
  String get detailHasIt => 'استلمها';

  @override
  String get detailNotYet => 'لم يستلمها بعد';

  @override
  String get detailSentTheirClock => 'أُرسلت (ساعتهم)';

  @override
  String get detailWrittenSaved => 'كُتبت وحُفظت';

  @override
  String get detailReceivedSaved => 'استُلمت وحُفظت';

  @override
  String get detailEdited => 'عُدّلت';

  @override
  String get detailForwardedFrom => 'أُعيد توجيهها من';

  @override
  String get detailReplyTo => 'رد على';

  @override
  String get detailReplyDeleted => 'رسالة تم حذفها';

  @override
  String get detailPinned => 'مثبّتة';

  @override
  String get detailPinnedValue => 'نعم — على هذا الهاتف فقط';

  @override
  String get detailDisappears => 'تختفي';

  @override
  String detailDisappearsValue(String when, String remaining) {
    return '$when ($remaining). تُزال رسائل الغرف العامة من هذا الهاتف بعد ست ساعات من وصولها.';
  }

  @override
  String get detailReceiptPath => 'مسار الإيصال';

  @override
  String get detailRoute => 'المسار';

  @override
  String detailRadioHops(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count قفزة لاسلكية',
      few: '$count قفزات لاسلكية',
      two: 'قفزتان لاسلكيتان',
    );
    return '$_temp0';
  }

  @override
  String detailPassedThrough(int hops) {
    String _temp0 = intl.Intl.pluralLogic(
      hops,
      locale: localeName,
      other: 'مرّت عبر $hops مُرحِّل',
      many: 'مرّت عبر $hops مُرحِّلًا',
      few: 'مرّت عبر $hops مُرحِّلات',
      two: 'مرّت عبر مُرحِّلين',
      one: 'مرّت عبر مُرحِّل واحد',
    );
    return '$_temp0';
  }

  @override
  String get detailNote => 'ملاحظة';

  @override
  String get detailClockSkew => 'ساعة المرسل تختلف عن ساعتك بأكثر من 10 دقائق.';

  @override
  String get detailProblem => 'المشكلة';

  @override
  String get detailMessageId => 'معرّف الرسالة';

  @override
  String get galDenied =>
      'لم يُسمح لـ دەمەتەقێ بالإضافة إلى معرض صورك. يمكنك السماح بذلك من إعدادات هاتفك.';

  @override
  String get galNoSpace => 'لا توجد مساحة كافية على هذا الهاتف لحفظه.';

  @override
  String get galUnsupported =>
      'لا يستطيع هذا الهاتف حفظ هذا النوع من الملفات في المعرض.';

  @override
  String get galFailed => 'تعذّر الحفظ في المعرض.';

  @override
  String get galPictureGone => 'هذه الصورة لم تعد على هذا الهاتف.';

  @override
  String get galVideoGone => 'لا يمكن حفظ هذا الفيديو من هذا الهاتف.';

  @override
  String get galVoice => 'لا يمكن حفظ الرسائل الصوتية في المعرض.';

  @override
  String get imgUnreadable => 'هذا الملف ليس صورة يستطيع هذا الهاتف قراءتها.';

  @override
  String get imgTooDetailed => 'هذه الصورة مفصّلة جدًا للإرسال عبر البلوتوث.';

  @override
  String get voiceMicOff => 'الميكروفون متوقف لـ دەمەتەقێ.';

  @override
  String get radarListening => 'جارٍ الاستماع للأشخاص القريبين';

  @override
  String get commonStop => 'إيقاف';

  @override
  String get diagRunAgain => 'تشغيل مجددًا';

  @override
  String get diagRun => 'تشغيل الاختبار';

  @override
  String get diagReportCopied => 'تم نسخ التقرير';

  @override
  String get diagCopyReport => 'نسخ التقرير';

  @override
  String get diagLogTitle => 'سجل النشاط';

  @override
  String get diagLogNote => 'محفوظ في الذاكرة فقط؛ يختفي عند إغلاق التطبيق';

  @override
  String get diagIntroTitle => 'تحقق من أن البلوتوث يعمل فعلًا';

  @override
  String get diagIntroBody =>
      'الأفضل إجراؤه بهاتفين جنبًا إلى جنب، يشغّل كلاهما دەمەتەقێ مع تفعيل البلوتوث. أوقف Wi-Fi وبيانات الجوّال أولًا لإثبات أن لا شيء يحتاج الإنترنت. يستغرق الاختبار نحو نصف دقيقة ويخبرك بما يجب إصلاحه إذا فشلت خطوة.';

  @override
  String get diagPass => 'نجح كل ما أمكن اختباره';

  @override
  String get diagPassBody =>
      'عثرت هذه الهواتف على بعضها وأثبتت هوياتها وتبادلت البيانات عبر البلوتوث.';

  @override
  String get diagWarn => 'يعمل، مع ما يستحق النظر';

  @override
  String get diagWarnBody =>
      'لم يفشل شيء، لكن خطوة واحدة على الأقل لم يمكن اختبارها كاملةً أو واجهت مشكلة. انظر أدناه.';

  @override
  String get diagFail => 'تم العثور على مشكلة';

  @override
  String get diagFailBody => 'اتبع النصيحة تحت الخطوة الفاشلة ثم أعد الاختبار.';

  @override
  String get diagNoResult => 'لا نتيجة';

  @override
  String get diagLimitsTitle => 'ما يعنيه النجاح وما لا يعنيه';

  @override
  String get diagLimitsBody =>
      'النجاح يعني أن هذين الهاتفين، الآن، عثرا على بعضهما واتصلا وأثبتا هويتيهما ونقلا البيانات في الاتجاهين، بما فيها رسائل أكبر من حزمة بلوتوث واحدة. لا يقيس المدى ولا استهلاك البطارية ولا سلوك الطُّرز الأخرى، ويحتاج الترحيل عبر هاتف ثالث إلى ثلاثة هواتف للاختبار. تتفاوت الهواتف كثيرًا في جودة البلوتوث، فاختبر بالطُّرز التي ستستخدمها.';

  @override
  String get diagLogCopied => 'تم نسخ السجل';

  @override
  String get diagLogWarn =>
      'قد يحتوي السجل على عناوين بلوتوث للهواتف من حولك. تحقق منه قبل مشاركته. ولا يحتوي أبدًا على مفاتيح أو نص رسائل.';

  @override
  String get diagLogEmpty => 'لم يُسجَّل شيء بعد.';

  @override
  String get stNothingToClean =>
      'لا شيء لتنظيفه: كل رسالة عامة عمرها أقل من ست ساعات.';

  @override
  String stRemovedPublic(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تمت إزالة $count رسالة عامة.',
      few: 'تمت إزالة $count رسائل عامة.',
      two: 'تمت إزالة رسالتين عامتين.',
      one: 'تمت إزالة رسالة عامة واحدة.',
    );
    return '$_temp0';
  }

  @override
  String get stDeleteMediaTitle => 'حذف كل الصور والرسائل الصوتية والفيديوهات؟';

  @override
  String get stDeleteMediaBody =>
      'تُزال من هذا الهاتف مع رسائلها. لا يُبلَّغ أحد آخر وتحتفظ الهواتف الأخرى بنسخها. لا يمكن التراجع عن ذلك.';

  @override
  String get stDeleteMediaAction => 'احذفها';

  @override
  String get stNothingToDelete => 'لم يكن هناك ما يُحذف.';

  @override
  String stDeletedMedia(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تم حذف $count رسالة مع ملفاتها.',
      few: 'تم حذف $count رسائل مع ملفاتها.',
      two: 'تم حذف رسالتين مع ملفاتهما.',
      one: 'تم حذف رسالة واحدة مع ملفاتها.',
    );
    return '$_temp0';
  }

  @override
  String get stMessages => 'الرسائل';

  @override
  String get stMedia => 'الصور والرسائل الصوتية والفيديوهات';

  @override
  String stFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ملف',
      many: '$count ملفًا',
      few: '$count ملفات',
      two: 'ملفان',
      one: 'ملف واحد',
    );
    return '$_temp0';
  }

  @override
  String get stDatabase => 'قاعدة بيانات الرسائل';

  @override
  String get stPublic => 'المحادثات العامة';

  @override
  String stMessagesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count رسالة',
      few: '$count رسائل',
      two: 'رسالتان',
      one: 'رسالة واحدة',
    );
    return '$_temp0';
  }

  @override
  String get stPublicNoteNever =>
      'تُزال من هذا الهاتف بعد ست ساعات من وصولها. لم يُزَل شيء بعد.';

  @override
  String stPublicNote(String ago, int removed) {
    return 'تُزال من هذا الهاتف بعد ست ساعات من وصولها. آخر تنظيف $ago، أُزيل $removed.';
  }

  @override
  String get stVideoLimit => 'أكبر فيديو ترسله';

  @override
  String stVideoLimitBody(String max) {
    return 'لا يُصغَّر الفيديو، لذا لا يتسع إلا مقطع قصير جدًا. يُرفض الأكبر قبل إرسال أي شيء. الفيديوهات الأكبر تستغرق وقتًا أطول بكثير عبر البلوتوث، ولا تُرسل الفيديوهات إلى الغرف العامة أبدًا. تُقبل الفيديوهات التي تستلمها حتى $max.';
  }

  @override
  String get stCleanNow => 'نظّف المحادثات العامة الآن';

  @override
  String get stCleanNowBody =>
      'تُنظَّف أيضًا من تلقاء نفسها، نحو مرة كل دقيقة أثناء عمل التطبيق، وعند بدئه. لا تُمَسّ المحادثات الخاصة والمجموعات أبدًا.';

  @override
  String get stDeleteMediaTile => 'حذف كل الصور والرسائل الصوتية والفيديوهات';

  @override
  String get stDeleteMediaTileBody =>
      'يُخلي أكبر مساحة. وتذهب معها الرسائل التي حملتها.';

  @override
  String get stFooter =>
      'لإزالة الرسائل القديمة تلقائيًا، استخدم «الاحتفاظ بالرسائل» ضمن الخصوصية والأمان في الإعدادات. تُخزَّن الرسائل والملفات دون تشفير خاص بها: فهي تعتمد على قفل شاشة هاتفك وتشفير قرصه.';

  @override
  String get nearbyTitle => 'القريب';

  @override
  String get nearbyVisible => 'ظاهر للآخرين';

  @override
  String get nearbySearching => 'البحث';

  @override
  String get nearbyScanningNow => 'يبحث الآن';

  @override
  String get nearbyBetweenScans => 'بين عمليات البحث';

  @override
  String get nearbyStopped => 'متوقف';

  @override
  String get nearbyHowHard => 'مدى كثافة البحث';

  @override
  String get nearbyRunSelfTest => 'تشغيل اختبار البلوتوث';

  @override
  String nearbyConnected(int count) {
    return 'الهواتف المتصلة ($count)';
  }

  @override
  String get nearbyNoLinks =>
      'لا توجد اتصالات بلوتوث الآن. تظهر الاتصالات هنا فور العثور على هاتف قريب، ثم تعرض «جارٍ التحقق» إلى أن يثبت هويته.';

  @override
  String nearbyHeard(int count) {
    return 'الأجهزة المسموعة ($count)';
  }

  @override
  String get nearbyNothingHeard =>
      'لم يُسمع شيء بعد. تُكتشف الهواتف الأخرى التي تشغّل دەمەتەقێ ضمن نحو 10 أمتار. يحتاج كلا الهاتفين إلى بلوتوث مفعّل والتطبيق مفتوحًا.';

  @override
  String get nearbyFootnote =>
      'أن يكون الجهاز «مسموعًا» يعني أن إعلانه عبر البلوتوث قد استُلم. لا يُوثق به حتى يكمل مصافحة الهوية. العناوين المعروضة هنا مقابض راديو مؤقتة لا هويات، وقد تتغير.';

  @override
  String get nearbyCannotAdvertise => 'لا يستطيع الإعلان عن نفسه';

  @override
  String get nearbyStartingPill => 'يبدأ';

  @override
  String get linkConnected => 'متصل';

  @override
  String get linkVerifying => 'جارٍ التحقق…';

  @override
  String get linkClosing => 'يُغلق';

  @override
  String get linkUnnamed => 'هاتف بلا اسم';

  @override
  String get linkUnverified => 'هاتف غير موثّق';

  @override
  String get linkRole => 'الدور';

  @override
  String get linkWeConnected => 'نحن اتصلنا';

  @override
  String get linkTheyConnected => 'هم اتصلوا';

  @override
  String get linkWriteSize => 'حجم الكتابة';

  @override
  String get linkSignal => 'الإشارة';

  @override
  String get linkRoundTrip => 'زمن الذهاب والإياب';

  @override
  String get linkTraffic => 'حركة البيانات';

  @override
  String get devHeard => 'مسموع';

  @override
  String get devConnecting => 'جارٍ الاتصال…';

  @override
  String get devLinked => 'مرتبط';

  @override
  String get devRetrying => 'ستُعاد المحاولة لاحقًا';

  @override
  String get devAlreadyLinked => 'مرتبط مسبقًا';

  @override
  String devFailedAttempts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count محاولة فاشلة',
      few: '$count محاولات فاشلة',
      two: 'محاولتان فاشلتان',
      one: 'محاولة فاشلة واحدة',
    );
    return '$_temp0';
  }

  @override
  String get errTypeFirst => 'اكتب رسالة أولاً.';

  @override
  String errMessageTooLong(int bytes, int max) {
    return 'الرسالة طويلة جدًا ($bytes من $max بايت). يرجى اختصارها.';
  }

  @override
  String get errReplyGone => 'الرسالة التي ترد عليها لم تعد موجودة.';

  @override
  String get errUnknownContact => 'جهة الاتصال هذه غير معروفة بعد.';

  @override
  String get errBlockedContact =>
      'لقد حظرت جهة الاتصال هذه. ألغِ الحظر لتتمكن من إرسال الرسائل.';

  @override
  String errBlockedNamed(String name) {
    return 'لقد حظرت $name.';
  }

  @override
  String get errNoKey =>
      'لم يصلنا مفتاح التشفير الخاص بهذا الشخص بعد. اقترب منه مرة واحدة (أو من هاتف يسمعه) ثم حاول مجددًا.';

  @override
  String get errNoKeyOnce =>
      'لم يصلنا مفتاح التشفير الخاص بهذا الشخص بعد. اقترب منه مرة واحدة ثم حاول مجددًا.';

  @override
  String errNoKeyNamed(String name) {
    return 'لم يصلنا مفتاح التشفير الخاص بـ $name بعد. اقترب منه مرة واحدة ثم حاول مجددًا.';
  }

  @override
  String get errKeyUnusable =>
      'مفتاح التشفير الخاص بجهة الاتصال هذه غير صالح للاستخدام. اطلب منه فتح التطبيق بالقرب منك ليتم تحديثه.';

  @override
  String get errKeyUnusableOne =>
      'مفتاح التشفير لأحد الأشخاص غير صالح للاستخدام. اطلب منه فتح التطبيق بالقرب منك ليتم تحديثه.';

  @override
  String get errNoKeyForControl =>
      'ليس لدينا مفتاح التشفير الخاص بجهة الاتصال هذه، لذا لا يمكن إرسال أي شيء إليها.';

  @override
  String get errNoConversation => 'هذه المحادثة لم تعد موجودة.';

  @override
  String get errCannotResend => 'لا يمكن إعادة إرسال هذه الرسالة.';

  @override
  String get errFileGone => 'الملف لم يعد موجودًا على هذا الهاتف.';

  @override
  String get errNotQueued => 'تعذّرت إضافته إلى قائمة الإرسال. حاول مرة أخرى.';

  @override
  String get unknownAuthor => 'غير معروف';

  @override
  String get errGroupName => 'أعطِ المجموعة اسمًا.';

  @override
  String get errGroupGone => 'هذه المجموعة لم تعد موجودة.';

  @override
  String get errNotInGroup => 'لم تعد عضوًا في هذه المجموعة.';

  @override
  String get errAdminOnly => 'مشرف المجموعة وحده يمكنه القيام بذلك.';

  @override
  String get errPickPeople => 'اختر شخصًا واحدًا على الأقل لإضافته.';

  @override
  String get errPickNewPeople => 'اختر شخصًا جديدًا واحدًا على الأقل لإضافته.';

  @override
  String errGroupFull(int max) {
    return 'يمكن أن تضم المجموعة $max أشخاص كحد أقصى، بمن فيهم أنت.';
  }

  @override
  String get errGroupKeyMissing => 'مفتاح هذه المجموعة مفقود.';

  @override
  String get errAdminCannotBeRemoved => 'لا يمكن إزالة المشرف.';

  @override
  String get errNotInGroupPerson => 'هذا الشخص ليس في المجموعة.';

  @override
  String get errCreatorCannotLeave =>
      'لقد أنشأت هذه المجموعة، لذا لا يمكنك مغادرتها — احذفها بدلًا من ذلك.';

  @override
  String get errRoomName => 'أعطِ الغرفة اسمًا.';

  @override
  String get errRoomGone => 'هذه الغرفة لم تعد متاحة.';

  @override
  String get errMeshCannotLeave => 'الغرفة mesh للجميع ولا يمكن مغادرتها.';

  @override
  String get errJoinFirst => 'انضم إلى الغرفة لتتمكن من النشر فيها.';

  @override
  String get errFileEmpty => 'هذا الملف فارغ.';

  @override
  String errTooLargeForMesh(int kb, int limit) {
    return 'هذا الحجم كبير جدًا على شبكة البلوتوث ($kb KB؛ الحد الأقصى $limit KB).';
  }

  @override
  String get errPictureUnreadable => 'تعذّرت قراءة هذه الصورة.';

  @override
  String get errVideoUnreadable => 'تعذّرت قراءة هذا الفيديو.';

  @override
  String get errRecordingUnreadable => 'تعذّرت قراءة هذا التسجيل.';

  @override
  String errVoiceTooLong(int seconds) {
    return 'يمكن أن تصل مدة الرسالة الصوتية إلى $seconds ثانية كحد أقصى.';
  }

  @override
  String get errVideoNotInRooms =>
      'لا يمكن إرسال الفيديو إلى الغرف العامة: فكل هاتف في النطاق سيضطر إلى حمله. أرسله في محادثة خاصة أو في مجموعة.';

  @override
  String get errVideoTooLarge => 'هذا الفيديو كبير جدًا للإرسال.';

  @override
  String get errNothingToShare => 'لا يوجد ما يمكن مشاركته.';

  @override
  String get errMessageGone => 'هذه الرسالة لم تعد موجودة.';

  @override
  String get errDeleteGroupOnly =>
      'يمكن لكاتب الرسالة أو لمشرف المجموعة فقط حذف الرسالة للجميع.';

  @override
  String get errDeleteOwnOnly => 'يمكنك حذف رسائلك أنت فقط للجميع.';

  @override
  String errDeleteTooOld(int hours) {
    return 'مضى على هذه الرسالة أكثر من $hours ساعة، لذا لم يعد بالإمكان حذفها للجميع.';
  }

  @override
  String get errEditOwnTextOnly => 'يمكن تعديل رسائلك النصية فقط.';

  @override
  String errEditTooOld(int hours) {
    return 'يمكن تعديل الرسائل خلال $hours ساعة من إرسالها.';
  }

  @override
  String get timeYesterday => 'أمس';

  @override
  String get weekdayMon => 'الإثنين';

  @override
  String get weekdayTue => 'الثلاثاء';

  @override
  String get weekdayWed => 'الأربعاء';

  @override
  String get weekdayThu => 'الخميس';

  @override
  String get weekdayFri => 'الجمعة';

  @override
  String get weekdaySat => 'السبت';

  @override
  String get weekdaySun => 'الأحد';

  @override
  String get agoJustNow => 'الآن';

  @override
  String agoSeconds(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'قبل $n ثانية',
      few: 'قبل $n ثوانٍ',
      two: 'قبل ثانيتين',
      one: 'قبل ثانية',
    );
    return '$_temp0';
  }

  @override
  String agoMinutes(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'قبل $n دقيقة',
      few: 'قبل $n دقائق',
      two: 'قبل دقيقتين',
      one: 'قبل دقيقة',
    );
    return '$_temp0';
  }

  @override
  String agoHours(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'قبل $n ساعة',
      few: 'قبل $n ساعات',
      two: 'قبل ساعتين',
      one: 'قبل ساعة',
    );
    return '$_temp0';
  }

  @override
  String agoDays(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'قبل $n يوم',
      many: 'قبل $n يومًا',
      few: 'قبل $n أيام',
      two: 'قبل يومين',
      one: 'قبل يوم',
    );
    return '$_temp0';
  }

  @override
  String get settingsTitle => 'الإعدادات';

  @override
  String get homePeople => 'الأشخاص';

  @override
  String get homeSearchHint => 'ابحث في المحادثات والمجموعات والأشخاص';

  @override
  String get navPrivate => 'خاصة';

  @override
  String get navGroups => 'المجموعات';

  @override
  String get navPublic => 'عامة';

  @override
  String get fabNewMessage => 'رسالة جديدة';

  @override
  String get fabNewGroup => 'مجموعة جديدة';

  @override
  String get homeNoMessagesYet => 'لا توجد رسائل بعد';

  @override
  String get homePrivateEmptyTitle => 'لا توجد محادثات خاصة بعد';

  @override
  String get homeNothingFound => 'لم يتم العثور على شيء';

  @override
  String get homePrivateEmptyBody =>
      'يعمل دەمەتەقێ دون إنترنت عبر البلوتوث. اطلب من شخص قريب فتح التطبيق؛ وعندما يصبح هاتفه في النطاق سيظهر هنا.';

  @override
  String homeNoMatchChat(String query) {
    return 'لا توجد محادثة أو شخص يطابق \"$query\".';
  }

  @override
  String get homeSeePeople => 'عرض الأشخاص';

  @override
  String get homeDeleteChatTitle => 'حذف هذه المحادثة؟';

  @override
  String get homeDeleteChatBody => 'تُحذف رسائلها وصورها من هذا الهاتف فقط.';

  @override
  String get homeAvailableNow => 'متاحون الآن';

  @override
  String get homeGroupsEmptyTitle => 'لا توجد مجموعات بعد';

  @override
  String get homeGroupsEmptyBody =>
      'المجموعة محادثة خاصة لعدة أشخاص معًا، مشفّرة بمفتاح لا يملكه سوى أعضائها. أنشئ واحدة مع أشخاص التقيت بهم.';

  @override
  String homeNoMatchGroup(String query) {
    return 'لا توجد مجموعة تطابق \"$query\".';
  }

  @override
  String get homeCreateGroup => 'إنشاء مجموعة';

  @override
  String homeInvitations(int count) {
    return 'الدعوات ($count)';
  }

  @override
  String get homeYourGroups => 'مجموعاتك';

  @override
  String get homeYouLeft => 'غادرت هذه المجموعة';

  @override
  String get homeYouWereRemoved => 'تمت إزالتك';

  @override
  String get homeDeleteGroupTitle => 'حذف هذه المجموعة؟';

  @override
  String get homeLeaveGroupTitle => 'مغادرة هذه المجموعة؟';

  @override
  String get homeDeleteThisChatTitle => 'حذف هذه المحادثة؟';

  @override
  String get homeDeleteGroupBody =>
      'تنتهي المجموعة للجميع. يحتفظ كل عضو بما لديه بالفعل.';

  @override
  String get homeLeaveGroupBody =>
      'ستتوقف عن استلام رسائلها. تُحذف نسختك من المحادثة من هذا الهاتف.';

  @override
  String get homeDeleteThisChatBody => 'تتم إزالة المحادثة من هذا الهاتف.';

  @override
  String get commonContinue => 'متابعة';

  @override
  String get homeSomeone => 'شخص ما';

  @override
  String homeInvitedYou(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count شخصًا',
      few: '$count أشخاص',
      two: 'شخصان',
    );
    return 'دعاك $name · $_temp0';
  }

  @override
  String get commonDecline => 'رفض';

  @override
  String get commonAccept => 'قبول';

  @override
  String get homeMeshSubtitle => 'كل من حولك · عام';

  @override
  String homeLeaveRoomTitle(String room) {
    return 'مغادرة $room؟';
  }

  @override
  String get homeLeaveRoomBody =>
      'تُحذف رسائلها وصورها من هذا الهاتف. يمكنك الانضمام مجددًا ما دامت الغرفة متاحة.';

  @override
  String get commonLeave => 'مغادرة';

  @override
  String get homeNearbyRooms => 'الغرف القريبة';

  @override
  String get homeListeningForRooms =>
      'جارٍ الاستماع للغرف. الغرف التي ينشئها من حولك أو تنقلها هواتفهم تظهر هنا.';

  @override
  String homeHeardAgo(String ago) {
    return 'سُمعت $ago';
  }

  @override
  String get commonJoin => 'انضمام';

  @override
  String promptTypeToConfirm(String word) {
    return 'اكتب \"$word\" للتأكيد:';
  }

  @override
  String defaultNickname(String code) {
    return 'هاتف $code';
  }

  @override
  String get previewYou => 'أنت';

  @override
  String get previewPhoto => 'صورة';

  @override
  String get previewVoice => 'رسالة صوتية';

  @override
  String get previewVideo => 'فيديو';

  @override
  String get previewUndecryptable => 'تعذّر فك تشفير الرسالة';

  @override
  String get notifyHiddenInvite => 'لديك دعوة جديدة إلى مجموعة';

  @override
  String notifyHiddenMany(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'لديك $count رسالة جديدة',
      few: 'لديك $count رسائل جديدة',
      two: 'لديك رسالتان جديدتان',
    );
    return '$_temp0';
  }

  @override
  String get notifyHiddenOne => 'لديك رسالة جديدة';

  @override
  String get notifySenderInvite => 'دعاك إلى مجموعة';

  @override
  String notifySenderMany(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count رسالة جديدة',
      few: '$count رسائل جديدة',
      two: 'رسالتان جديدتان',
    );
    return '$_temp0';
  }

  @override
  String get notifySenderOne => 'رسالة جديدة';

  @override
  String get notifyFullInvite => 'دعاك إلى مجموعة';

  @override
  String notifyFullInviteBy(String name) {
    return 'دعاك $name إلى مجموعة';
  }

  @override
  String notifyFullMore(String line, int count) {
    return '$line  (+$count أخرى)';
  }

  @override
  String get notifyChannelName => 'الرسائل';

  @override
  String get notifyChannelDescription => 'الرسائل الجديدة ودعوات المجموعات';

  @override
  String get keepAliveChannelName => 'الشبكة تعمل في الخلفية';

  @override
  String get keepAliveChannelDescription =>
      'يظهر أثناء إبقاء دەمەتەقێ لشبكة البلوتوث تعمل والشاشة مطفأة.';

  @override
  String get keepAliveTitle => 'يُبقي دەمەتەقێ الشبكة تعمل';

  @override
  String get keepAliveText =>
      'يتم نقل الرسائل واستقبالها عبر البلوتوث. اضغط للفتح.';

  @override
  String get obHeadline => 'تحدّث مع من حولك.\nلا حاجة للإنترنت.';

  @override
  String get obPoint1Title => 'من هاتف إلى هاتف، عبر البلوتوث';

  @override
  String get obPoint1Body =>
      'تنتقل الرسائل والصور والصوت مباشرة من هاتف إلى آخر. بلا حسابات ولا خوادم ولا إنترنت.';

  @override
  String get obPoint3Title => 'محادثات خاصة ومجموعات وغرف عامة';

  @override
  String get obPoint3Body =>
      'المحادثات والمجموعات مشفّرة. الغرف العامة مفتوحة: يمكن لأي شخص قريب قراءتها.';

  @override
  String get obPoint4Title => 'يسأل قبل أن يستخدم أي شيء';

  @override
  String get obPoint4Body =>
      'يُطلب البلوتوث بعد ذلك. أما الميكروفون والكاميرا والصور فلا تُطلب إلا عند إرسال رسالة صوتية أو صورة. ولا يقرأ موقعك أو جهات اتصالك أبدًا.';

  @override
  String get obPoint5Title => 'من الجيد أن تعرف';

  @override
  String get obPoint5Body =>
      'تجريبي: لم يُدقَّق التشفير بشكل مستقل، ولم يُختبر تمرير الرسائل عبر الهواتف الأخرى إلا بأجهزة راديو محاكاة. المزيد في الإعدادات، ضمن المساعدة والإرشادات.';

  @override
  String get obNameHint => 'يظهر للأشخاص القريبين';

  @override
  String get obNameNote =>
      'يمكنك تغيير هذا في أي وقت من الإعدادات. لا يلزم أن يكون اسمك الحقيقي.';

  @override
  String get obStarting => 'جارٍ البدء…';

  @override
  String get obStart => 'اسمح بالبلوتوث وابدأ';

  @override
  String get gdGone => 'هذه المجموعة لم تعد موجودة.';

  @override
  String get gdStateActive => 'أنت فيها';

  @override
  String get gdStateLeft => 'غادرتها';

  @override
  String get gdStateRemoved => 'أُزلت منها';

  @override
  String get gdStateInvited => 'دعوة';

  @override
  String get gdEncryptedNote =>
      'مشفّرة بمفتاح لا يملكه سوى الأعضاء. عند إزالة أحدهم تحصل المجموعة على مفتاح جديد، فلا يستطيع قراءة أي شيء يُرسل بعد ذلك. ويحتفظ بما استلمه سابقًا.';

  @override
  String get gdMembers => 'الأعضاء';

  @override
  String get gdAdmin => 'مشرف';

  @override
  String get gdRemoveTooltip => 'إزالة من المجموعة';

  @override
  String gdRemoveTitle(String name) {
    return 'إزالة $name؟';
  }

  @override
  String get gdRemoveBody =>
      'لن يستلموا أي شيء بعد الآن، وتحصل المجموعة على مفتاح جديد لا يملكونه.';

  @override
  String get gdFull => 'المجموعة ممتلئة';

  @override
  String get gdAddPeople => 'إضافة أشخاص';

  @override
  String get gdDeleteBody =>
      'تنتهي المجموعة للجميع. يحتفظ كل عضو بالرسائل التي لديه بالفعل؛ ولا يستطيع أحد الإرسال إليها بعد الآن.';

  @override
  String get gdDeleteAction => 'حذف المجموعة';

  @override
  String get gdDeleteButton => 'حذف المجموعة للجميع';

  @override
  String get gdLeaveBody =>
      'ستتوقف عن استلام رسائلها. سيمنح المشرف المجموعة مفتاحًا جديدًا. تبقى نسختك من المحادثة على هذا الهاتف.';

  @override
  String get gdLeaveButton => 'مغادرة المجموعة';

  @override
  String get gdForgetTitle => 'إزالة من هذا الهاتف؟';

  @override
  String get gdForgetBody => 'تُحذف المحادثة ورسائلها من هذا الهاتف.';

  @override
  String get gdForgetButton => 'حذف هذه المحادثة';

  @override
  String get gdInvitationsSent => 'أُرسلت الدعوات. للمجموعة مفتاح جديد.';

  @override
  String gdSelectedOf(int count, int room) {
    return '$count من $room مسموح';
  }

  @override
  String get gdInvite => 'دعوة';

  @override
  String get pdNameTitle => 'سمِّ جهة الاتصال هذه';

  @override
  String get pdNameHint => 'الاسم';

  @override
  String get pdDeleteTitle => 'حذف جهة الاتصال هذه؟';

  @override
  String get pdDeleteBody =>
      'ستُحذف جهة الاتصال ومحادثتك معها من هذا الهاتف. لن يُبلَّغ بذلك. وإن كان قريبًا فسيظهر مجددًا كجهة اتصال جديدة غير موثّقة.';

  @override
  String get pdTitle => 'جهة الاتصال';

  @override
  String get pdGone => 'جهة الاتصال هذه لم تعد موجودة.';

  @override
  String pdCallsThemselves(String name) {
    return 'يسمّي نفسه \"$name\"';
  }

  @override
  String get pdSendMessage => 'إرسال رسالة';

  @override
  String get pdVerified => 'موثّق';

  @override
  String get pdNotVerified => 'لم يُوثَّق بعد';

  @override
  String get pdVerifyBody =>
      'يمكن لأي شخص اختيار أي اسم مستعار، وعندما يلتقي هاتفان لأول مرة لا توجد طريقة لمعرفة أن المفاتيح له فعلًا. للتأكد، قارن رقم الأمان هذا بالرقم على هاتفه — وجهًا لوجه أو في مكالمة تتعرف فيها على صوته. إن كان الرقمان متطابقين فضع علامة موثّق. وإن اختلفا فلا تثق بجهة الاتصال هذه.';

  @override
  String get pdNoKey => 'لم يُستلم مفتاح تشفير بعد: ادخل نطاقه مرة واحدة.';

  @override
  String get pdSafetyNumber => 'رقم الأمان';

  @override
  String get pdSafetyNote =>
      'هذا هو الرقم نفسه على الهاتفين. اضغط مطولًا للنسخ.';

  @override
  String get pdNumbersMatch => 'الرقمان متطابقان';

  @override
  String get pdMarkVerified => 'ضع علامة موثّق على جهة الاتصال هذه';

  @override
  String get pdShortId => 'المعرّف القصير';

  @override
  String get pdFirstSeen => 'أول ظهور';

  @override
  String get pdLastSeen => 'آخر ظهور';

  @override
  String get pdFullFingerprint => 'البصمة الكاملة';

  @override
  String get pdRename => 'إعادة تسمية';

  @override
  String get pdRenameBody => 'أنت فقط ترى هذا الاسم';

  @override
  String get pdBlock => 'حظر';

  @override
  String get pdBlockBody => 'تجاهل رسائله ولا تؤكّد استلامها';

  @override
  String get pdDeleteContact => 'حذف جهة الاتصال';

  @override
  String get problemQueueFailed => 'تعذّرت إضافته إلى قائمة التسليم';

  @override
  String get problemExpired =>
      'لم تُسلَّم: تعذّر الوصول إلى المستلم قبل انتهاء صلاحية الرسالة.';

  @override
  String get problemNobodyInRange =>
      'لم يكن هناك أحد في النطاق لاستلام هذه الرسالة.';

  @override
  String get problemFileDamaged => 'وصل الملف تالفًا وتم تجاهله.';

  @override
  String get problemFileIncomplete => 'لم يصل باقي هذا الملف أبدًا.';

  @override
  String get feedErrorTitle => 'تعذّر تحميل الرسائل';

  @override
  String get feedErrorBody =>
      'لم يُحذف أي شيء. حاول مرة أخرى، وإن استمرت المشكلة فأعد تشغيل التطبيق.';

  @override
  String get homePrivateTitle => 'المحادثات الخاصة';

  @override
  String get setProfileTitle => 'الملف الشخصي والهوية';

  @override
  String get setDataHeading => 'البيانات والسجل';

  @override
  String get setChatsBluetooth => 'المحادثات والبلوتوث';

  @override
  String get setHelp => 'المساعدة والإرشادات';

  @override
  String setAboutTitle(String name) {
    return 'حول $name';
  }

  @override
  String get setLicenses => 'تراخيص المصادر المفتوحة';

  @override
  String get setLicensesBody => 'الخطوط والمكتبات التي بُني بها التطبيق';

  @override
  String get setLicensesLegalese =>
      'مبني ببرمجيات مفتوحة المصدر. لكل جزء ترخيصه الخاص.';

  @override
  String get helpPermissionsTitle => 'الأذونات: ما الذي يُطلب ومتى';

  @override
  String get helpPermissionsBody =>
      'يُطلب البلوتوث عند البدء، ليتمكن دەمەتەقێ من العثور على الهواتف القريبة. ولا يُطلب الميكروفون والكاميرا والصور إلا إذا سجّلت رسالة صوتية أو أرسلت صورة — كلٌّ منها مع شرح مسبق، ويمكنك رفض أي منها. لا يقرأ دەمەتەقێ موقعك أو جهات اتصالك أبدًا. (يربط أندرويد 11 والأقدم مسح البلوتوث بإذن الموقع؛ ومع ذلك لا يقرأ التطبيق موقعك أبدًا.)';

  @override
  String get roomYourNameTitle => 'اسمك هنا';

  @override
  String get roomYourNameBody =>
      'يرى كل من في النطاق هذا الاسم بجانب ما تكتبه. لا يلزم أن يكون اسمك الحقيقي، وهو غير فريد: يمكن للآخرين اختيار الاسم نفسه.';

  @override
  String get roomExpiryNote => 'عامة · تختفي الرسائل بعد 6 ساعات';

  @override
  String get roomSearchTooltip => 'بحث في هذه الغرفة';

  @override
  String roomComposerHint(String room) {
    return 'رسالة إلى $room · عامة';
  }

  @override
  String get roomJoinToPost => 'انضم إلى هذه الغرفة للنشر';

  @override
  String get roomEmpty =>
      'لا شيء هنا بعد. كل ما تكتبه علني: يمكن لكل هاتف في النطاق (والهواتف التي تنقله إليها) قراءته.';

  @override
  String get roomsCreateTitle => 'إنشاء غرفة عامة';

  @override
  String get roomsCreateBody =>
      'يمكن لأي شخص قريب العثور على الغرفة والانضمام إليها وقراءة كل ما يُقال فيها. هي ليست خاصة. تُدرج الغرفة ليوم واحد وتتجدد تلقائيًا ما دام تطبيقك يعمل.';

  @override
  String get roomsNameHint => 'اسم الغرفة';

  @override
  String get roomsAboutHint => 'ما موضوعها؟ (اختياري)';

  @override
  String get commonCreate => 'إنشاء';

  @override
  String get roomsTitle => 'الغرف العامة';

  @override
  String get roomsCreateButton => 'إنشاء غرفة';

  @override
  String get peopleFilterAll => 'الكل';

  @override
  String get peopleFilterReachable => 'متاحون الآن';

  @override
  String get peopleFilterContacts => 'جهات الاتصال';

  @override
  String get peopleEmptyTitle => 'لا أحد بعد';

  @override
  String get peopleEmptyFilterTitle => 'لا أحد يطابق هذا المرشّح';

  @override
  String get peopleEmptyBody =>
      'تظهر هنا تلقائيًا الهواتف التي تشغّل دەمەتەقێ ضمن نطاق البلوتوث، مع كل من يصلك إعلانه عبر هواتف أخرى. لا يُرسل شيء عبر الإنترنت.';

  @override
  String get peopleEmptyFilterBody => 'جرّب مرشّحًا آخر.';

  @override
  String get peopleSeeNearby => 'اعرض ما حولك';

  @override
  String get peopleDetailsTooltip => 'تفاصيل جهة الاتصال والتحقق';

  @override
  String get peoplePickEmpty =>
      'لا أحد لمراسلته بعد. تظهر الهواتف هنا فور دخولها النطاق.';

  @override
  String get groupNoKeyYet => 'لا يوجد مفتاح تشفير بعد — التقِ به مرة أولًا';

  @override
  String get groupNameLabel => 'اسم المجموعة';

  @override
  String get groupCreateNote =>
      'تُشفَّر رسائل المجموعة بمفتاح لا يملكه سوى أعضائها. يتلقى من تختارهم دعوة يمكنهم قبولها أو رفضها؛ ولا يُبثّ أي شيء عن المجموعة أبدًا.';

  @override
  String groupAddPeople(int count, int max) {
    return 'إضافة أشخاص ($count من $max)';
  }

  @override
  String get groupNobodyToAdd => 'لا أحد لإضافته بعد';

  @override
  String get groupNobodyBody =>
      'يمكنك دعوة الأشخاص الذين التقاهم هاتفك فقط. افتح دەمەتەقێ قرب أحدهم وسيظهر هنا.';

  @override
  String get groupCreating => 'جارٍ الإنشاء…';

  @override
  String get groupCreate => 'إنشاء المجموعة';

  @override
  String get videoCouldNotPlay => 'تعذّر تشغيل هذا الفيديو على هذا الهاتف.';

  @override
  String get commonPause => 'إيقاف مؤقت';

  @override
  String get commonPlay => 'تشغيل';

  @override
  String get secClearTitle => 'مسح سجل الأمان؟';

  @override
  String get secClearBody =>
      'تُزال المدخلات من هذا الهاتف. لا يمكن التراجع عن ذلك.';

  @override
  String get secClearTooltip => 'مسح السجل';

  @override
  String get secEmptyTitle => 'لم يُسجَّل أي شيء مريب';

  @override
  String get secEmptyBody =>
      'إذا فشل توقيع رسالة أو تعذّر فك تشفيرها، أو فشل هاتف في فحص الهوية، أو تغيّر مفتاح جهة اتصال، فإنه يُدرج هنا. قد تنتج المدخلات العرضية عن ارتباط راديو ضعيف وليست دائمًا هجومًا.';

  @override
  String get secBadSignatureTitle => 'كان لرسالة توقيع غير صالح';

  @override
  String get secBadSignatureBody =>
      'تم تجاهلها. ربما زوّرها أحد أو غيّرها، أو تلفت في الهواء.';

  @override
  String get secDecryptFailedTitle => 'تعذّر فك تشفير رسالة';

  @override
  String get secDecryptFailedBody =>
      'كانت موجّهة إليك لكن تعذّر فتحها. تلفت أو جرى العبث بها أو شُفّرت لمفتاح مختلف.';

  @override
  String get secLinkAuthTitle => 'فشل هاتف في فحص الهوية';

  @override
  String get secLinkAuthBody =>
      'اتصل عبر البلوتوث لكنه لم يستطع إثبات أنه يملك المفتاح الذي ادّعاه. أُغلق الاتصال.';

  @override
  String get secKeyChangedTitle => 'تغيّر مفتاح التشفير لجهة اتصال';

  @override
  String get secKeyChangedBody =>
      'أُزيل توثيقه. قارن أرقام الأمان معه مجددًا قبل الوثوق بجهة الاتصال هذه. تغيّر المفتاح متوقع إذا أعاد تثبيت التطبيق.';

  @override
  String get secRateLimitedTitle => 'أرسل هاتف أكثر من اللازم';

  @override
  String get secRateLimitedBody => 'تجاوزت حركته الحد وأُسقط الفائض.';

  @override
  String get secMalformedTitle => 'استُلمت بيانات غير مقروءة';

  @override
  String get secMalformedBody => 'تم تجاهل بيانات لا تتبع البروتوكول.';

  @override
  String get secNotAMemberTitle => 'تصرّف شخص دون أن يكون مسموحًا له';

  @override
  String get secNotAMemberBody =>
      'وصلت رسالة أو دعوة أو تحديث لمجموعة من شخص ليس عضوًا أو ليس المشرف. تم تجاهلها.';

  @override
  String get secUnauthorizedTitle => 'حاول شخص تغيير رسالة ليست له';

  @override
  String get secUnauthorizedBody =>
      'وصل طلب حذف أو تعديل رسالة من شخص لم يكتبها (وليس مشرف المجموعة). تم تجاهله.';

  @override
  String get secBadMediaTitle => 'تلفت صورة أو رسالة صوتية';

  @override
  String get secBadMediaBody =>
      'لم يطابق ملف وصفه (حجم أو مجموع تحقق خاطئ) أو وصل بأجزاء غير متسقة، فتم تجاهله.';

  @override
  String get secProtocolTitle => 'خالف هاتف قواعد الاتصال';

  @override
  String get secProtocolBody =>
      'أرسل بيانات بترتيب خاطئ أو بصيغة غير متوقعة، فأُسقط الاتصال.';

  @override
  String get secUnknownBody => 'لا يتوفر وصف لهذا المدخل.';

  @override
  String secUnknownPhone(String tag) {
    return 'هاتف غير معروف $tag';
  }

  @override
  String get bstTitleDevice => 'هذا الهاتف';

  @override
  String get bstTitleSupport => 'البلوتوث منخفض الطاقة';

  @override
  String get bstTitlePermission => 'إذن البلوتوث';

  @override
  String get bstTitlePower => 'البلوتوث مفعّل';

  @override
  String get bstTitleAdvertising => 'ظاهر للهواتف الأخرى (الإعلان)';

  @override
  String get bstTitleScanning => 'البحث عن هواتف أخرى (المسح)';

  @override
  String get bstTitleDiscovery => 'العثور على هاتف آخر';

  @override
  String get bstTitleConnection => 'الاتصال وإثبات الهوية';

  @override
  String get bstTitleExchange => 'إرسال البيانات في الاتجاهين';

  @override
  String get bstTitleMultihop => 'الوصول إلى الهواتف عبر مُرحِّل';

  @override
  String get bstTitleNetwork => 'العمل دون إنترنت';

  @override
  String get bstStopped => 'تم الإيقاف.';

  @override
  String get bstFixAbove => 'أصلح المشكلة أعلاه أولًا.';

  @override
  String get bstNoBle => 'لا يوفّر هذا الهاتف البلوتوث منخفض الطاقة.';

  @override
  String get bstNoBleAdvice => 'لا يمكن لهذا الهاتف المشاركة في الشبكة.';

  @override
  String get bstBleAvailable => 'البلوتوث منخفض الطاقة متاح.';

  @override
  String get bstWhereIos => 'الإعدادات > دەمەتەقێ > البلوتوث (فعّله).';

  @override
  String get bstWhereAndroid12 =>
      'الإعدادات > التطبيقات > دەمەتەقێ > الأذونات > الأجهزة القريبة > السماح.';

  @override
  String get bstWhereOlder =>
      'الإعدادات > التطبيقات > دەمەتەقێ > الأذونات > الموقع > السماح (يحتاجه أندرويد الأقدم لمسح البلوتوث).';

  @override
  String get bstPermDenied => 'لم يتم منح إذن البلوتوث.';

  @override
  String bstPermAdvice(String where) {
    return 'اضغط «السماح بالبلوتوث» في الشاشة الرئيسية، أو افتح: $where';
  }

  @override
  String get bstPermGranted => 'تم منح الإذن.';

  @override
  String get bstOff => 'البلوتوث متوقف.';

  @override
  String get bstOffAdvice =>
      'شغّل البلوتوث من الإعدادات السريعة في هاتفك، ثم أعد الاختبار.';

  @override
  String get bstPowerUnknown => 'لم يبلّغ الهاتف عن حالة البلوتوث بعد.';

  @override
  String get bstPowerUnknownAdvice => 'انتظر لحظة وأعد الاختبار.';

  @override
  String get bstOn => 'البلوتوث يعمل.';

  @override
  String get bstCannotAdvertise =>
      'لا يستطيع هذا الهاتف الإعلان عن نفسه (العمل كطرفية بلوتوث).';

  @override
  String get bstCannotAdvertiseAdvice =>
      'ما زال يستطيع العثور على هواتف أخرى والاتصال بها، لكن الآخرين لا يستطيعون العثور عليه. لا يمكن لهاتفين يفتقران كلاهما إلى هذه القدرة أن يتصلا ببعضهما.';

  @override
  String get bstAdvertising =>
      'يعلن عن خدمة الشبكة؛ يمكن للهواتف الأخرى رؤية هذا الهاتف والاتصال به.';

  @override
  String get bstNotAdvertising => 'الهاتف لا يعلن عن نفسه.';

  @override
  String get bstNotAdvertisingAdvice =>
      'أوقف البلوتوث ثم شغّله، ثم أعد الاختبار. إذا استمر الفشل فقد لا يدعم هذا الطراز الإعلان عبر البلوتوث.';

  @override
  String get bstDiscoveryStopped => 'الاكتشاف متوقف.';

  @override
  String get bstDiscoveryStoppedAdvice =>
      'افتح تبويب القريب وتأكد من أن التطبيق قد بدأ.';

  @override
  String bstScanning(String mode, int count) {
    return 'يمسح في نوافذ قصيرة (وضع $mode)، بدأ $count مسح حتى الآن.';
  }

  @override
  String get bstNoScan => 'تعذّر بدء أي مسح.';

  @override
  String get bstNoScanAdvice => 'تحقق من إذن البلوتوث ومن أن البلوتوث يعمل.';

  @override
  String bstHeardCount(int count) {
    return 'تم سماع $count هاتف يشغّل دەمەتەقێ.';
  }

  @override
  String bstHeardStrongest(int count, int dbm) {
    return 'تم سماع $count هاتف يشغّل دەمەتەقێ، أقوى إشارة $dbm dBm.';
  }

  @override
  String bstNoneHeard(int seconds) {
    return 'لم يُسمع أي هاتف آخر يشغّل دەمەتەقێ خلال $seconds ثانية.';
  }

  @override
  String get bstNoneHeardAdvice =>
      'هذا طبيعي إن لم يكن أحد قريبًا. افتح التطبيق على هاتف ثانٍ (البلوتوث يعمل، ضمن بضعة أمتار) وأعد الاختبار.';

  @override
  String get bstOlderAndroidLocation =>
      ' في أندرويد 11 والأقدم، يحتاج المسح أيضًا إلى تشغيل مفتاح الموقع في الهاتف (الإعدادات السريعة)؛ لا يقرأ دەمەتەقێ موقعك، لكن تلك الإصدارات لا تجد شيئًا ما دام مطفأً.';

  @override
  String get bstNeedsPhone => 'يحتاج إلى هاتف آخر ضمن النطاق.';

  @override
  String get bstWeConnected => 'نحن اتصلنا بهم';

  @override
  String get bstTheyConnected => 'هم اتصلوا بنا';

  @override
  String bstLinkLine(String who, String role, String bytes) {
    return '$who ($role، $bytes بايت لكل كتابة)';
  }

  @override
  String bstConnectedOk(String lines) {
    return 'تم الاتصال والتحقق من ملكية المفتاح مع: $lines.';
  }

  @override
  String get bstNotConnected => 'سُمعت هواتف أخرى لكن تعذّر إكمال الاتصال.';

  @override
  String bstNotConnectedWith(String errors) {
    return 'سُمعت هواتف أخرى لكن تعذّر إكمال الاتصال: $errors';
  }

  @override
  String get bstNotConnectedAdvice =>
      'قرّب الهاتفين (أقل من مترين)، وأوقف البلوتوث ثم شغّله على كليهما، وأغلق التطبيقات الأخرى التي تستخدم البلوتوث بكثافة. أخطاء الاتصال مثل «status 133» شائعة على بعض هواتف أندرويد وتزول عادة بإعادة المحاولة.';

  @override
  String get bstNeedsConnected => 'يحتاج إلى هاتف متصل.';

  @override
  String bstSmall(int received, int sent) {
    return '$received/$sent صغيرة';
  }

  @override
  String bstLarge(int received, int sent) {
    return '$received/$sent كبيرة (1200 B، مجزّأة)';
  }

  @override
  String bstRtt(int avg, int min, int max) {
    return '، متوسط الذهاب والإياب $avg ms ($min-$max)';
  }

  @override
  String bstExchangeLine(String label, String small, String large, String rtt) {
    return '$label: $small، $large$rtt';
  }

  @override
  String get bstNothingBack =>
      'لم يرجع شيء. أُنشئ الرابط لكن البيانات لا تتدفق؛ جرّب مجددًا وهما أقرب، أو أوقف البلوتوث وشغّله على الهاتفين.';

  @override
  String get bstSomeLost => 'فُقدت بعض البيانات. قرّب الهاتفين وأعد الاختبار.';

  @override
  String get bstSlowChunk =>
      'يستخدم الرابط الحد الأدنى للبلوتوث وهو 20 بايت لكل كتابة، لذا ستكون الرسائل بطيئة. يحدث هذا حين يفشل الهاتفان في التفاوض على حجم أكبر.';

  @override
  String get bstNoRelay =>
      'لا يوجد هاتف يمكن الوصول إليه حاليًا عبر مُرحِّل فقط. اختبار ذلك يحتاج إلى ثلاثة هواتف: A وC كلٌّ منهما ضمن نطاق B لكن ليس ضمن نطاق الآخر.';

  @override
  String bstRelayLine(String id, String via, int hops) {
    return '$id عبر $via ($hops روابط)';
  }

  @override
  String bstRelayOk(String lines) {
    return 'يمكن الوصول إليه عبر مُرحِّل، استنادًا إلى إعلانات موقّعة: $lines.';
  }

  @override
  String bstNetOffline(String text) {
    return '$text. كل ما سبق عمل دون أي اتصال بالإنترنت.';
  }

  @override
  String bstNetOnline(String text) {
    return '$text. التطبيق لا يستخدمه؛ ولإثبات العمل دون إنترنت، أوقف Wi-Fi وبيانات الجوّال (أو استخدم وضع الطيران مع تشغيل البلوتوث) وأعد الاختبار.';
  }

  @override
  String get setLanguage => 'اللغة';

  @override
  String get setLanguageBody => 'لغة التطبيق كله. الكردية هي الأساسية.';

  @override
  String get setAppearance => 'المظهر';

  @override
  String get appearanceHeading => 'السمة';

  @override
  String get appearanceSystem => 'حسب إعداد الهاتف';

  @override
  String get appearanceSystemHelp => 'يتبع إعداد هاتفك الفاتح أو الداكن.';

  @override
  String get appearanceLight => 'فاتح';

  @override
  String get appearanceLightHelp => 'صفحة فاتحة بطبقات بيضاء.';

  @override
  String get appearanceDark => 'داكن';

  @override
  String get appearanceDarkHelp => 'صفحة قريبة من السواد، مريحة للعين ليلًا.';

  @override
  String get themeSwitchToLight => 'التبديل إلى المظهر الفاتح';

  @override
  String get themeSwitchToDark => 'التبديل إلى المظهر الداكن';

  @override
  String get setName => 'اسمك';

  @override
  String get setNameBody =>
      'يمكن لأي شخص قريب رؤية هذا الاسم. إنه غير فريد ولا يتحقق منه أحد: يمكن لشخصين اختيار الاسم نفسه، ولهذا تعرض جهات الاتصال معرّفًا قصيرًا أيضًا.';

  @override
  String get setNicknameHint => 'اسم مستعار';

  @override
  String get setChangeName => 'تغيير الاسم';

  @override
  String get setFingerprint => 'بصمة هويتك';

  @override
  String get setFingerprintBody =>
      'تقارن جهات اتصالك رقم أمان معك للتأكد من أنك أنت فعلًا.';

  @override
  String get setFingerprintCopied => 'تم نسخ البصمة';

  @override
  String get setPermissions => 'الأذونات';

  @override
  String get setNotifications => 'الإشعارات';

  @override
  String get setMeshBackground => 'الشبكة في الخلفية';

  @override
  String get setBluetooth => 'البلوتوث';

  @override
  String get setPrivacy => 'الخصوصية والأمان';

  @override
  String get setHonesty => 'كيف يعمل، وما لا يستطيع فعله';

  @override
  String get setDanger => 'منطقة الخطر';

  @override
  String get setSearchHow => 'مدى كثافة البحث عن الأشخاص';

  @override
  String get modeBalanced => 'متوازن';

  @override
  String get modeLowPower => 'توفير البطارية';

  @override
  String get modeAggressive => 'مستمر';

  @override
  String get modeBalancedHelp => 'يبحث نحو نصف الوقت';

  @override
  String get modeLowPowerHelp =>
      'يبحث لفترات قصيرة ونادرًا: يوفر البطارية، ويجد الأشخاص ببطء';

  @override
  String get modeAggressiveHelp =>
      'يبحث دون توقف: يجد الأشخاص بأسرع ما يمكن، ويستهلك أكبر قدر من البطارية';

  @override
  String get setSelfTest => 'اختبار البلوتوث';

  @override
  String get setSelfTestBody =>
      'تحقق من أن هذا الهاتف يستطيع العثور على هاتف آخر والاتصال به والتحدث معه';

  @override
  String get setInternet => 'الإنترنت';

  @override
  String get setChecking => 'جارٍ التحقق…';

  @override
  String setInternetBody(String state) {
    return '$state. لا يستخدم دەمەتەقێ الإنترنت أبدًا؛ أطفئه إن أردت رؤيته يعمل بدونه.';
  }

  @override
  String get netNone => 'لا Wi-Fi ولا بيانات جوّال';

  @override
  String get netWifi => 'Wi-Fi يعمل (لا يستخدمه هذا التطبيق)';

  @override
  String get netMobile => 'بيانات الجوّال تعمل (لا يستخدمها هذا التطبيق)';

  @override
  String get netWired => 'شبكة سلكية (لا يستخدمها هذا التطبيق)';

  @override
  String get netOther => 'شبكة أخرى تعمل (لا يستخدمها هذا التطبيق)';

  @override
  String get netUnknown => 'حالة الشبكة غير معروفة';

  @override
  String get setStorage => 'التخزين';

  @override
  String get setStorageBody => 'ما المحفوظ على هذا الهاتف، وكيف تُخلي مساحته';

  @override
  String get setKeepMessages => 'الاحتفاظ بالرسائل';

  @override
  String get setKeepMessagesBody => 'تُحذف الرسائل الأقدم من هذا الهاتف';

  @override
  String get setRetForever => 'للأبد';

  @override
  String get setRetDay => 'يوم واحد';

  @override
  String setRetDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days يوم',
      many: '$days يومًا',
      few: '$days أيام',
      two: 'يومان',
    );
    return '$_temp0';
  }

  @override
  String get setSecurityLog => 'سجل الأمان';

  @override
  String get setSecurityLogBody =>
      'رسائل مزوّرة، فحوص هوية فاشلة، مفاتيح متغيّرة';

  @override
  String get setResetAction => 'إعادة تعيين الهوية';

  @override
  String get setResetTileBody =>
      'تُنشئ مفاتيح جديدة. على جهات الاتصال التحقق منك مجددًا';

  @override
  String get setResetTitle => 'إعادة تعيين هويتك؟';

  @override
  String get setResetBody =>
      'يُنشئ هذا هوية جديدة تمامًا (مفاتيح تشفير وتوقيع جديدة).\n\n• سترى جهات اتصالك شخصًا جديدًا غير موثّق وعليها التحقق من رقم أمانك الجديد.\n• الرسائل التي ما زالت في طريقها إلى هويتك القديمة لن يمكن قراءتها.\n• تُهمَل الرسائل التي تنتظر الإرسال.\n• لن تستطيع المشاركة في مجموعاتك (فهي تعرف هويتك القديمة)؛ وتبقى نسخك من تلك المحادثات على هذا الهاتف.\n• تبقى محادثاتك الحالية على هذا الهاتف.\n\nلا يمكن التراجع عن ذلك.';

  @override
  String get setResetDone => 'لديك هوية جديدة';

  @override
  String get setClearTile => 'حذف كل البيانات المحلية';

  @override
  String get setClearTileBody =>
      'الرسائل والصور وجهات الاتصال والمجموعات والمفاتيح';

  @override
  String get setClearTitle => 'حذف كل شيء على هذا الهاتف؟';

  @override
  String get setClearBody =>
      'يحذف هذا نهائيًا كل الرسائل والصور والرسائل الصوتية وجهات الاتصال والمجموعات والغرف ومفاتيح المجموعات وسجل الأمان وإعداداتك، ويُنشئ هوية جديدة.\n\nلا يُبلَّغ أي شخص آخر، ولا تتأثر النسخ الموجودة على الهواتف الأخرى. لا يمكن التراجع عن ذلك.';

  @override
  String get setClearAction => 'حذف كل شيء';

  @override
  String get confirmWordDelete => 'حذف';

  @override
  String get setClearDone => 'تم حذف كل البيانات المحلية';

  @override
  String setVersionLine(String name, String version, int protocol) {
    return '$name $version · البروتوكول v$protocol';
  }

  @override
  String get setNotifyTitle => 'إشعارات الرسائل';

  @override
  String get setNotifyBody =>
      'أخبرني عند وصول رسالة بينما التطبيق مغلق أو في الخلفية. فقط للرسائل الموجّهة إليك.';

  @override
  String get setNotifyShows => 'ما يعرضه الإشعار';

  @override
  String get setNotifyFull => 'الاسم والرسالة';

  @override
  String get setNotifySender => 'الاسم فقط';

  @override
  String get setNotifyHidden => 'لا شيء («رسالة جديدة» فقط)';

  @override
  String get setNotifyFullHelp =>
      'يعرض من كتب وماذا كتب. يمكن لأي شخص يرى شاشة القفل قراءته.';

  @override
  String get setNotifySenderHelp => 'يعرض من كتب، لا ماذا كتب. «رسالة جديدة».';

  @override
  String get setNotifyHiddenHelp => 'يعرض فقط أن شيئًا وصل. لا من ولا ماذا.';

  @override
  String get setNotifyPublic => 'الغرف العامة أيضًا';

  @override
  String get setNotifyPublicBody =>
      'متوقف افتراضيًا: الغرفة العامة هي كل من حولك يتحدثون ولن تتوقف أبدًا.';

  @override
  String get setRelayTitle => 'ساعد في ترحيل الرسائل للآخرين';

  @override
  String get setRelayOn =>
      'ينقل هاتفك الرسائل المختومة بين أشخاص خارج نطاق بعضهم. ولا يستطيع قراءتها. وهذا ما يجعل الشبكة تصل أبعد.';

  @override
  String get setRelayOff =>
      'متوقف: يستقبل هاتفك ما هو لك ويرسل رسائله، لكنه لا ينقل شيئًا لأي شخص آخر. الأشخاص الذين يعتمدون عليك للوصول إلى بعضهم لن يصلوا.';

  @override
  String relayActivity(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'منذ بدء التطبيق: نُقلت $count حزمة للآخرين.',
      few: 'منذ بدء التطبيق: نُقلت $count حزم للآخرين.',
      two: 'منذ بدء التطبيق: نُقلت حزمتان للآخرين.',
      one: 'منذ بدء التطبيق: نُقلت حزمة واحدة للآخرين.',
      zero: 'منذ بدء التطبيق: لم يُنقل أي حزمة للآخرين.',
    );
    return '$_temp0';
  }

  @override
  String relayActivityRefused(int count, int refused) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'منذ بدء التطبيق: نُقلت $count حزمة للآخرين، ورُفض $refused لأن الترحيل متوقف.',
      few:
          'منذ بدء التطبيق: نُقلت $count حزم للآخرين، ورُفض $refused لأن الترحيل متوقف.',
      two:
          'منذ بدء التطبيق: نُقلت حزمتان للآخرين، ورُفض $refused لأن الترحيل متوقف.',
      one:
          'منذ بدء التطبيق: نُقلت حزمة واحدة للآخرين، ورُفض $refused لأن الترحيل متوقف.',
      zero:
          'منذ بدء التطبيق: لم يُنقل شيء للآخرين، ورُفض $refused لأن الترحيل متوقف.',
    );
    return '$_temp0';
  }

  @override
  String get setKeepAliveTitle => 'أبقِ الشبكة تعمل في الخلفية';

  @override
  String get setKeepAliveBody =>
      'يعرض إشعارًا أثناء عمله، ويستهلك بعض البطارية. وبدونه قد يوقف أندرويد عمل البلوتوث بعد قفل الهاتف بقليل، وبعض الهواتف تفعل ذلك حتى معه. لم يُختبر هذا على هواتف حقيقية بعد.';

  @override
  String get setKeepAliveRefused =>
      'لم يسمح أندرويد بذلك الآن. حاول مجددًا والتطبيق على الشاشة.';

  @override
  String get setBackgroundUse => 'الاستخدام في الخلفية';

  @override
  String get setBackgroundUseBody =>
      'يوقف هذا الهاتف التطبيق بعد قفله أو تركه بقليل، ولا شيء يمكن للتطبيق طلبه يغيّر ذلك. تُتبادل الرسائل أثناء فتح التطبيق.';

  @override
  String get setBatteryTitle => 'قيود البطارية';

  @override
  String get setBatteryRestricted =>
      'مفعّلة: قد يوقف أندرويد دەمەتەقێ في الخلفية لتوفير البطارية، حتى مع الإعداد أعلاه. لتبقى الشبكة تعمل والشاشة مطفأة، افتح إعدادات البطارية واختر «غير مقيّد» (تختلف التسميات من هاتف لآخر).';

  @override
  String get setBatteryUnrestricted =>
      'متوقفة: يسمح أندرويد بعمل دەمەتەقێ في الخلفية دون قيود على البطارية. وتضيف بعض الشركات المصنّعة للهواتف قيودًا خاصة بها.';

  @override
  String get setBatteryOpen => 'فتح إعدادات البطارية';

  @override
  String get setBatteryCouldNotOpen =>
      'لم يفتح هذا الهاتف إعدادات البطارية. ابحث عن دەمەتەقێ ضمن التطبيقات في إعدادات الهاتف.';

  @override
  String get setPermBluetooth => 'البلوتوث (الأجهزة القريبة)';

  @override
  String get setPermBluetoothWhy =>
      'للعثور على الهواتف القريبة منك والتحدث معها. وليس موقعك أبدًا.';

  @override
  String get setAllowed => 'مسموح';

  @override
  String get commonAllow => 'السماح';

  @override
  String get setPermMic => 'الميكروفون';

  @override
  String get setPermMicShort => 'فقط أثناء تسجيل رسالة صوتية';

  @override
  String get setPermCamera => 'الكاميرا';

  @override
  String get setPermCameraShort => 'فقط لالتقاط صورة تريد إرسالها';

  @override
  String get setPermPhotos => 'الصور';

  @override
  String get setPermPhotosShort => 'فقط لاختيار صورة تريد إرسالها';

  @override
  String get setPermNotifShort =>
      'فقط لإخبارك بوصول رسالة بينما التطبيق ليس على الشاشة';

  @override
  String get honestyNoInternetTitle => 'لا إنترنت، لا حسابات، لا خوادم';

  @override
  String get honestyNoInternetBody =>
      'تنتقل الرسائل من هاتف إلى هاتف عبر بلوتوث منخفض الطاقة. لا يُرسل شيء إلى الإنترنت ولا إلى أي شركة، ولا شيء تحتاج إلى التسجيل فيه.';

  @override
  String get honestyRangeTitle => 'النطاق والترحيل والانتظار';

  @override
  String honestyRangeBody(
    int direct,
    int group,
    int directHours,
    int roomHours,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      directHours,
      locale: localeName,
      other: '$directHours ساعة',
      few: '$directHours ساعات',
      two: 'ساعتين',
      one: 'ساعة واحدة',
    );
    String _temp1 = intl.Intl.pluralLogic(
      roomHours,
      locale: localeName,
      other: '$roomHours ساعة',
      few: '$roomHours ساعات',
      two: 'ساعتان',
      one: 'ساعة واحدة',
    );
    return 'يصل رابط البلوتوث الواحد إلى نحو 10 إلى 30 مترًا، وأقل عبر الجدران. إذا وُجدت هواتف تحمل التطبيق بينهما، يمكن للرسالة أن تقفز عبرها: حتى $direct قفزات للرسائل الخاصة و$group للمجموعات والغرف العامة. وإذا لم يكن أحد في المتناول تُحفظ الرسالة الخاصة أو رسالة المجموعة وتُعاد المحاولة لمدة تصل إلى $_temp0 (الغرف العامة: $_temp1)، ثم تُعلَّم بأنها لم تُسلَّم. والهواتف التي تمرّر حركة المجموعات والغرف العامة تحتفظ بها أيضًا لمن يصل لاحقًا. جرى اختبار الترحيل بأجهزة راديو محاكاة فقط؛ ولم يثبت بعد على هواتف حقيقية، فاستخدم اختبار البلوتوث وهواتفك لترى كيف يتصرف عمليًا.';
  }

  @override
  String get honestyMediaTitle => 'الصور والرسائل الصوتية والفيديوهات';

  @override
  String honestyMediaBody(int seconds) {
    return 'تُصغَّر الصور إلى بضع عشرات من الكيلوبايت (بعرض نحو 640 بكسل)، وتُحدَّد الرسائل الصوتية بـ $seconds ثانية، ولا يُصغَّر الفيديو إطلاقًا: لا يتسع إلا مقطع قصير جدًا (تختار الحد من الإعدادات > التخزين). البلوتوث بطيء: تستغرق كل قفزة بضع ثوانٍ، وأكثر مع عدة قفزات أو إشارة ضعيفة. يُفحص كل ملف بـ SHA-256 قبل عرضه. في المجموعة قد تبقى الصورة أو الفيديو غير مكتمل إذا ضاعت قطعة منه على كل المسارات؛ فيظهر حينها كغير مستلم. لا يمكن إرسال الفيديو إلى الغرف العامة. تُحفظ الصور والتسجيلات والفيديوهات في التخزين الخاص بالتطبيق لا في معرض الصور، ما لم تختر «حفظ في المعرض».';
  }

  @override
  String get honestyBackgroundTitle => 'العمل في الخلفية غير مضمون';

  @override
  String get honestyBackgroundBody =>
      'يعمل دەمەتەقێ بأفضل شكل وهو مفتوح. تقيّد الهواتف ما يمكن للتطبيقات فعله بالبلوتوث في الخلفية، ولا يحاول هذا التطبيق الالتفاف على ذلك. في أندرويد يمكنك تشغيل «أبقِ الشبكة تعمل في الخلفية»: يعرض إشعارًا أثناء عمله ويُبقي التطبيق حيًا في أحيان أكثر، لكنه ليس ضمانًا، ولم يُختبر على هواتف حقيقية بعد. قد لا ترحّل الهواتف المقفلة أو التي أُغلق عليها التطبيق شيئًا.';

  @override
  String get honestyPrivateTitle => 'المحادثات الخاصة';

  @override
  String get honestyPrivateBody =>
      'الرسائل والصور والرسائل الصوتية الخاصة مشفّرة من طرف إلى طرف: لا يستطيع قراءتها إلا من ترسل إليه، حتى عندما تمرّرها هواتف أخرى. والهواتف التي تمرّر شيئًا يمكنها رؤية من أرسله ولمن هو (مفاتيحهما العامة)، وتقريبًا متى، وحجمه التقريبي، لكن ليس المحتوى. ويمكن لأي شخص قريب أن يرى أن هاتفًا يعلن عن دەمەتەقێ، والاسم الذي اخترته.';

  @override
  String get honestyGroupsTitle => 'المجموعات';

  @override
  String get honestyGroupsBody =>
      'المجموعة خاصة: تُشفَّر رسائلها بمفتاح لا يملكه سوى أعضائها، ولا يُبثّ أي شيء عنها (اسمها أو أعضاؤها أو وجودها). وحده من أنشأها يستطيع إضافة الأشخاص أو إزالتهم، وكل تغيير يمنح المجموعة مفتاحًا جديدًا، فلا يستطيع من أُزيل قراءة ما يُرسل بعد ذلك. ويحتفظ بما استلمه سابقًا. وإذا وصل تغيير المفتاح إلى عضو بعد الرسائل المرسلة بعده مباشرة، فقد تفوته تلك الرسائل.';

  @override
  String get honestyRoomsTitle => 'الغرف العامة';

  @override
  String get honestyRoomsBody =>
      'الغرفة العامة ليست خاصة. كل ما يُقال فيها — نصًا وصورًا وصوتًا — يمكن لكل هاتف ينقلها ولكل من ينضم قراءته. الرسائل موقّعة، فلا يستطيع المرحِّل تغيير كلمة أو تزوير كاتب، لكن الأسماء تُختار بحرية: المعرّف القصير بعد الاسم هو ما يميّز شخصين يحملان الاسم نفسه. الغرفة المدمجة mesh لكل من حولك؛ أما الغرف التي ينشئها الناس فيُعلَن عنها للهواتف القريبة وتختفي بعد يوم ما لم يواصل هاتف منشئها تجديدها. وتُزال رسائل الغرف العامة من هذا الهاتف بعد ست ساعات من وصولها.';

  @override
  String get honestyDeleteTitle => 'الحذف والتعديل';

  @override
  String get honestyDeleteBody =>
      '«حذف عندي» يزيل الرسالة من هذا الهاتف فقط. و«حذف للجميع» يرسل طلبًا إلى الهواتف الأخرى: ينجح فقط إذا استلمته في الوقت المناسب، ولا يصل إلى نسخة حفظها أحد أو صوّرها. ويرسل التعديل النص الجديد بالطريقة نفسها. وكلاهما ممكن خلال يومين من إرسال الرسالة.';

  @override
  String get honestyVerifyTitle => 'مع من تتحدث فعلًا؟';

  @override
  String get honestyVerifyBody =>
      'عندما يلتقي هاتفان لأول مرة، لا توجد طريقة لمعرفة أن المفتاح لذلك الشخص فعلًا. افتح صفحة جهة الاتصال وقارن رقم الأمان معه وجهًا لوجه أو في مكالمة تثق بها، ثم فقط ضع علامة موثّق. وإلى ذلك الحين، تعامل مع الأسماء على أنها غير موثّقة.';

  @override
  String get honestyStoredTitle => 'ما المخزَّن على هذا الهاتف';

  @override
  String get honestyStoredBody =>
      'تُحفظ مفاتيحك (ومفاتيح مجموعاتك) في التخزين الآمن للهاتف (Android Keystore / iOS Keychain). ويُخزَّن سجل المحادثات والصور والتسجيلات في التخزين الخاص بالتطبيق دون طبقة تشفير إضافية فوق قفل شاشة هاتفك وتشفير قرصه، وقد تُدرج في النسخ الاحتياطية للجهاز على آيفون. يمكن لأي شخص يفتح هاتفك قراءة محادثاتك.';

  @override
  String get honestyAuditTitle => 'لم يُدقَّق باستقلالية';

  @override
  String get honestyAuditBody =>
      'يستخدم التشفير خوارزميات قياسية (HPKE مع X25519 وChaCha20-Poly1305، وتوقيعات Ed25519)، واختُبر التشفير الأساسي مقابل متجهات الاختبار المنشورة. لكن شيفرة هذا التطبيق لم يراجعها خبير أمني مستقل. لا تعتمد عليه حيث تتوقف سلامتك أو حريتك على ذلك.';

  @override
  String get reachDirectLong => 'متصل مباشرة';

  @override
  String reachRelayLong(int hops) {
    String _temp0 = intl.Intl.pluralLogic(
      hops,
      locale: localeName,
      other: 'عبر مُرحِّل ($hops قفزة)',
      few: 'عبر مُرحِّل ($hops قفزات)',
      two: 'عبر مُرحِّل (قفزتان)',
      one: 'عبر مُرحِّل (قفزة واحدة)',
    );
    return '$_temp0';
  }

  @override
  String get reachOffline => 'غير متصل';

  @override
  String get reachDirectShort => 'مباشر';

  @override
  String reachRelayShort(int hops) {
    String _temp0 = intl.Intl.pluralLogic(
      hops,
      locale: localeName,
      other: 'مُرحِّل · $hops قفزة',
      few: 'مُرحِّل · $hops قفزات',
      two: 'مُرحِّل · قفزتان',
      one: 'مُرحِّل · قفزة',
    );
    return '$_temp0';
  }

  @override
  String get deliveryPending => 'قيد الانتظار';

  @override
  String deliverySentCount(int done, int total) {
    return 'أُرسلت · $done/$total';
  }

  @override
  String get deliverySent => 'أُرسلت';

  @override
  String get deliveryDelivered => 'تم التسليم';

  @override
  String deliveryDeliveredVia(int hops) {
    String _temp0 = intl.Intl.pluralLogic(
      hops,
      locale: localeName,
      other: 'تم التسليم · $hops قفزة',
      few: 'تم التسليم · $hops قفزات',
      two: 'تم التسليم · قفزتان',
      one: 'تم التسليم · قفزة',
    );
    return '$_temp0';
  }

  @override
  String get deliveryFailed => 'لم تُسلَّم';

  @override
  String get deliveryUndecryptable => 'تعذّر فك التشفير أو التحقق';

  @override
  String get connError => 'خطأ في البلوتوث';

  @override
  String get connStarting => 'جارٍ البدء…';

  @override
  String get connNotStarted => 'لم يبدأ';

  @override
  String get connNotSupported => 'غير مدعوم';

  @override
  String get connPermissionNeeded => 'الإذن مطلوب';

  @override
  String get connBluetoothOff => 'البلوتوث متوقف';

  @override
  String connNearbyRelayed(int direct, int relayed) {
    return '$direct قريب · $relayed عبر مُرحِّل';
  }

  @override
  String connNearby(int direct) {
    return '$direct قريب';
  }

  @override
  String connViaRelay(int relayed) {
    return '$relayed عبر مُرحِّل';
  }

  @override
  String get connSearching => 'جارٍ البحث…';

  @override
  String get offlineTipNone =>
      'لا يوجد اتصال بالإنترنت. لا يحتاج دەمەتەقێ إليه: تنتقل الرسائل عبر البلوتوث.';

  @override
  String get offlineTipOn =>
      'الهاتف متصل بالإنترنت، لكن دەمەتەقێ لا يستخدمه: تنتقل الرسائل عبر البلوتوث.';

  @override
  String get offlineBadge => 'غير متصل';

  @override
  String get internetOnBadge => 'الإنترنت يعمل';

  @override
  String navUnreadLabel(String label, int count) {
    return '$label، $count غير مقروءة';
  }

  @override
  String peerSeenAgo(String ago) {
    return 'شوهد $ago';
  }

  @override
  String get peerNoKeyYet => 'لا يوجد مفتاح تشفير بعد';

  @override
  String get commonStart => 'ابدأ';

  @override
  String get commonOpenSettings => 'فتح الإعدادات';

  @override
  String get commonDismiss => 'إخفاء';

  @override
  String get radioCouldNotStart => 'تعذّر تشغيل البلوتوث';

  @override
  String get radioNotStarted => 'البلوتوث غير مشغّل';

  @override
  String get radioNotStartedBody =>
      'يحتاج دەمەتەقێ إلى البلوتوث للعثور على الهواتف القريبة والتحدث معها.';

  @override
  String get radioNotVisible => 'لا يمكن للآخرين العثور على هذا الهاتف';

  @override
  String get radioNotVisibleBody =>
      'يمكنه العثور على الهواتف الأخرى والاتصال بها، لكنه لا يستطيع الإعلان عن نفسه عبر البلوتوث. لا يمكن لهاتفين يفتقران إلى ذلك أن يتصلا ببعضهما.';

  @override
  String get radioNoBle => 'البلوتوث منخفض الطاقة غير متاح';

  @override
  String get radioNoBleBody =>
      'لا يدعم هذا الجهاز ميزة البلوتوث التي يقوم عليها دەمەتەقێ، لذا لا يمكنه المشاركة في الشبكة.';

  @override
  String get radioPermission => 'إذن البلوتوث مطلوب';

  @override
  String get radioPermissionBody =>
      'يحتاج دەمەتەقێ إلى إذن لاستخدام البلوتوث (إذن «الأجهزة القريبة» في أندرويد الحديث، والبلوتوث في آيفون) للعثور على الهواتف القريبة والتحدث معها. ولا يستخدم موقعك أبدًا.';

  @override
  String get radioAllow => 'السماح بالبلوتوث';

  @override
  String get radioOff => 'البلوتوث متوقف';

  @override
  String get radioOffBody =>
      'شغّل البلوتوث من الإعدادات السريعة في هاتفك. سيعيد دەمەتەقێ الاتصال بالهواتف القريبة من تلقاء نفسه.';

  @override
  String get radioProblem => 'مشكلة في البلوتوث';

  @override
  String get identityResetTitle => 'تمت إعادة تعيين هويتك';

  @override
  String get identityResetBody =>
      'تعذّرت قراءة مفاتيح التشفير الخاصة بك من التخزين الآمن لهذا الهاتف، لذا أُنشئت هوية جديدة. سيحتاج الأشخاص في جهات اتصالك إلى التحقق منك مجددًا، ولم يعد بالإمكان قراءة الرسائل المرسلة إلى هويتك القديمة.';

  @override
  String get versionNewerTitle => 'إصدار أحدث من دەمەتەقێ قريب منك';

  @override
  String get versionNewerBody =>
      'هاتف قريب منك يعمل بإصدار أحدث من دەمەتەقێ. لا يستطيع الهاتفان التحدث معًا حتى يُحدَّث هذا الهاتف أيضًا.';

  @override
  String get versionOlderTitle => 'هاتف قريب يحتاج إلى تحديث';

  @override
  String get versionOlderBody =>
      'هاتف قريب منك يعمل بإصدار أقدم من دەمەتەقێ. لا يستطيع الهاتفان التحدث معًا حتى يُحدَّث ذلك الهاتف.';

  @override
  String get permMicTitle => 'السماح باستخدام الميكروفون؟';

  @override
  String get permMicWhy =>
      'يحتاج دەمەتەقێ إلى الميكروفون فقط أثناء تسجيلك رسالة صوتية.';

  @override
  String get permMicPrivacy =>
      'ينتقل التسجيل عبر البلوتوث إلى الأشخاص في تلك المحادثة ولا يُرفع إلى أي مكان أبدًا. لا يُسجَّل أي شيء حين لا يكون هناك تسجيل مفتوح.';

  @override
  String get permMicThing => 'الميكروفون';

  @override
  String get permMicOff => 'الميكروفون متوقف';

  @override
  String get permCameraTitle => 'السماح باستخدام الكاميرا؟';

  @override
  String get permCameraWhy =>
      'يحتاج دەمەتەقێ إلى الكاميرا لالتقاط صورة تريد إرسالها.';

  @override
  String get permCameraPrivacy =>
      'يتم تصغير الصورة وإرسالها عبر البلوتوث إلى الأشخاص في تلك المحادثة. لا تُحفظ في معرض الصور ولا تُرفع إلى أي مكان أبدًا.';

  @override
  String get permCameraThing => 'الكاميرا';

  @override
  String get permCameraOff => 'الكاميرا متوقفة';

  @override
  String get permPhotosTitle => 'السماح بالوصول إلى صورك؟';

  @override
  String get permPhotosWhy =>
      'يحتاج دەمەتەقێ إلى فتح مكتبة صورك لتتمكن من اختيار صورة لإرسالها.';

  @override
  String get permPhotosPrivacy =>
      'تُستخدم الصورة التي تختارها فقط. يتم تصغيرها وإرسالها عبر البلوتوث إلى الأشخاص في تلك المحادثة، ولا تُرفع إلى أي مكان أبدًا.';

  @override
  String get permPhotosThing => 'صورك';

  @override
  String get permPhotosOff => 'الوصول إلى صورك متوقف';

  @override
  String get permNotifTitle => 'السماح بالإشعارات؟';

  @override
  String get permNotifWhy =>
      'يستخدم دەمەتەقێ الإشعارات ليخبرك عند وصول رسالة بينما التطبيق مغلق أو في الخلفية.';

  @override
  String get permNotifPrivacy =>
      'أنت تختار مقدار ما يعرضه الإشعار: الاسم والرسالة، أو الاسم فقط، أو «رسالة جديدة» فقط. تُنشأ الإشعارات على هذا الهاتف من الرسائل التي وصلت إليه؛ ولا يُرسل شيء إلى أي خادم.';

  @override
  String get permNotifThing => 'الإشعارات';

  @override
  String get permNotifOff => 'الإشعارات متوقفة';

  @override
  String get permNotAvailable => 'غير متاح';

  @override
  String permUnavailableBody(String thing) {
    return 'لا يسمح هذا الهاتف لـ دەمەتەقێ باستخدام $thing (قد يكون مقيّدًا من قبل أحد الوالدين أو مسؤول).';
  }

  @override
  String get permNotNow => 'ليس الآن';

  @override
  String get permTurnOnInSettings =>
      'لاستخدامه، فعّله لـ دەمەتەقێ من إعدادات هاتفك. لا يحتاج إليه أي شيء آخر في التطبيق.';

  @override
  String get voicePause => 'إيقاف الرسالة الصوتية مؤقتًا';

  @override
  String get voicePlay => 'تشغيل الرسالة الصوتية';

  @override
  String get mediaNotReceived => 'تعذّر استلامه';

  @override
  String mediaReceiving(int percent) {
    return 'جارٍ الاستلام… $percent%';
  }

  @override
  String get pictureNotReceived => 'تعذّر استلام الصورة';

  @override
  String get videoCannotPlay => 'لا يمكن تشغيل هذا الفيديو على هذا الهاتف.';

  @override
  String get videoNotReceived => 'تعذّر استلام الفيديو';

  @override
  String videoReceiving(int percent) {
    return 'جارٍ استلام الفيديو… $percent%';
  }

  @override
  String get videoPlay => 'تشغيل الفيديو';

  @override
  String introDirectTitle(String name) {
    return 'ألقِ التحية على $name';
  }

  @override
  String introGroupTitle(String name) {
    return 'مرحبًا بك في $name';
  }

  @override
  String get fwdNoVideoInRooms => 'لا يمكن إرسال الفيديو إلى غرفة عامة';

  @override
  String get setNotifyNotAllowed =>
      'الإشعارات مفعّلة هنا، لكن الهاتف لم يسمح بها بعد، لذلك لن يظهر أي إشعار.';
}
