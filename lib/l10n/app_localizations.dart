import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_ckb.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ckb'),
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @authorUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown {tag}'**
  String authorUnknown(String tag);

  /// No description provided for @actEditingGone.
  ///
  /// In en, this message translates to:
  /// **'The message you were editing is gone.'**
  String get actEditingGone;

  /// No description provided for @actReplyingGone.
  ///
  /// In en, this message translates to:
  /// **'The message you were replying to was deleted.'**
  String get actReplyingGone;

  /// No description provided for @actNoTextToCopy.
  ///
  /// In en, this message translates to:
  /// **'There is no text to copy.'**
  String get actNoTextToCopy;

  /// No description provided for @actCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get actCopied;

  /// No description provided for @actCopiedMany.
  ///
  /// In en, this message translates to:
  /// **'Copied {count} messages'**
  String actCopiedMany(int count);

  /// No description provided for @actSaveTitle.
  ///
  /// In en, this message translates to:
  /// **'Save to your gallery?'**
  String get actSaveTitle;

  /// No description provided for @actSaveBodyPicture.
  ///
  /// In en, this message translates to:
  /// **'دەمەتەقێ keeps this picture in its own private storage. Saving puts a copy in your phone\'s gallery, where other apps can see it and where it stays even if you delete the message here. Your phone may ask for permission to save files.'**
  String get actSaveBodyPicture;

  /// No description provided for @actSaveBodyVideo.
  ///
  /// In en, this message translates to:
  /// **'دەمەتەقێ keeps this video in its own private storage. Saving puts a copy in your phone\'s gallery, where other apps can see it and where it stays even if you delete the message here. Your phone may ask for permission to save files.'**
  String get actSaveBodyVideo;

  /// No description provided for @actSaveBodyFiles.
  ///
  /// In en, this message translates to:
  /// **'دەمەتەقێ keeps these {count} files in its own private storage. Saving puts a copy in your phone\'s gallery, where other apps can see it and where it stays even if you delete the message here. Your phone may ask for permission to save files.'**
  String actSaveBodyFiles(int count);

  /// No description provided for @actSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved to your gallery'**
  String get actSaved;

  /// No description provided for @actSavedMany.
  ///
  /// In en, this message translates to:
  /// **'Saved {count} files to your gallery'**
  String actSavedMany(int count);

  /// No description provided for @actSavedSome.
  ///
  /// In en, this message translates to:
  /// **'Saved {saved} of {total}. {reason}'**
  String actSavedSome(int saved, int total, String reason);

  /// No description provided for @actPinnedNote.
  ///
  /// In en, this message translates to:
  /// **'Pinned. Only you see this pin.'**
  String get actPinnedNote;

  /// No description provided for @actUnpinnedNote.
  ///
  /// In en, this message translates to:
  /// **'Unpinned'**
  String get actUnpinnedNote;

  /// No description provided for @actForwardPublicTitle.
  ///
  /// In en, this message translates to:
  /// **'Forward to a public room?'**
  String get actForwardPublicTitle;

  /// No description provided for @actForwardPublicBody.
  ///
  /// In en, this message translates to:
  /// **'Everyone nearby can read what you forward there, it is not private any more, and it shows the name of the person who wrote it. It disappears from phones after six hours.'**
  String get actForwardPublicBody;

  /// No description provided for @actForwardPublicAction.
  ///
  /// In en, this message translates to:
  /// **'Forward publicly'**
  String get actForwardPublicAction;

  /// No description provided for @actTheChat.
  ///
  /// In en, this message translates to:
  /// **'the chat'**
  String get actTheChat;

  /// No description provided for @actForwardedTo.
  ///
  /// In en, this message translates to:
  /// **'Forwarded to {title}'**
  String actForwardedTo(String title);

  /// No description provided for @actForwardedMany.
  ///
  /// In en, this message translates to:
  /// **'Forwarded {count} messages to {title}'**
  String actForwardedMany(int count, String title);

  /// No description provided for @actForwardedSome.
  ///
  /// In en, this message translates to:
  /// **'Forwarded {sent} of {total} to {title}. The others could not be read, or their file is not complete.'**
  String actForwardedSome(int sent, int total, String title);

  /// No description provided for @actNothingDeleted.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Nothing was deleted: that message is already gone.} other{Nothing was deleted: those messages are already gone.}}'**
  String actNothingDeleted(int count);

  /// No description provided for @actDeletedUnsent.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Deleted. It had not been sent yet, so nobody receives it.} other{Deleted. They had not been sent yet, so nobody receives them.}}'**
  String actDeletedUnsent(int count);

  /// No description provided for @actDeletedManyHere.
  ///
  /// In en, this message translates to:
  /// **'{count} messages deleted from this phone.'**
  String actDeletedManyHere(int count);

  /// No description provided for @actDeletedHere.
  ///
  /// In en, this message translates to:
  /// **'Deleted from this phone.'**
  String get actDeletedHere;

  /// No description provided for @actDeletedAskedOthers.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Deleted here. Other phones remove it when they receive the request.} other{Deleted here. Other phones remove them when they receive the request.}}'**
  String actDeletedAskedOthers(int count);

  /// No description provided for @actDeletedNeverSent.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Deleted. Nothing had been sent yet, so nobody else ever receives it.} other{Deleted. Nothing had been sent yet, so nobody else ever receives them.}}'**
  String actDeletedNeverSent(int count);

  /// No description provided for @actUnpinnedCount.
  ///
  /// In en, this message translates to:
  /// **'Unpinned {count}'**
  String actUnpinnedCount(int count);

  /// No description provided for @actPinnedCount.
  ///
  /// In en, this message translates to:
  /// **'Pinned {count}. Only you see these pins.'**
  String actPinnedCount(int count);

  /// No description provided for @actSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get actSelectAll;

  /// No description provided for @actFurtherBack.
  ///
  /// In en, this message translates to:
  /// **'That message is further back than this chat shows.'**
  String get actFurtherBack;

  /// No description provided for @pinnedListTitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 pinned message} other{{count} pinned messages}}'**
  String pinnedListTitle(int count);

  /// No description provided for @pinnedListNote.
  ///
  /// In en, this message translates to:
  /// **'Pins are yours alone: nobody else sees them.'**
  String get pinnedListNote;

  /// No description provided for @pinnedListEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing is pinned.'**
  String get pinnedListEmpty;

  /// No description provided for @startupErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'دەمەتەقێ could not start'**
  String get startupErrorTitle;

  /// No description provided for @startupErrorBody.
  ///
  /// In en, this message translates to:
  /// **'The app could not open its private storage or load your keys. Nothing has been deleted, and your identity is never replaced just because it could not be read. Try again; if it keeps failing, restart the phone. As a last resort, uninstalling and reinstalling the app clears the damaged storage, but it also deletes your chats and your identity.'**
  String get startupErrorBody;

  /// No description provided for @commonTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get commonTryAgain;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get commonOk;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @commonDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get commonDone;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @commonRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get commonRemove;

  /// No description provided for @commonBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get commonBack;

  /// No description provided for @commonSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get commonSearch;

  /// No description provided for @commonSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get commonSend;

  /// No description provided for @commonCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get commonCopy;

  /// No description provided for @commonShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get commonShare;

  /// No description provided for @commonMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get commonMore;

  /// No description provided for @commonYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get commonYes;

  /// No description provided for @commonNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get commonNo;

  /// No description provided for @commonOn.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get commonOn;

  /// No description provided for @commonOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get commonOff;

  /// No description provided for @commonYou.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get commonYou;

  /// No description provided for @commonLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get commonLoading;

  /// No description provided for @actReply.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get actReply;

  /// No description provided for @actCopyCaption.
  ///
  /// In en, this message translates to:
  /// **'Copy caption'**
  String get actCopyCaption;

  /// No description provided for @actCopyText.
  ///
  /// In en, this message translates to:
  /// **'Copy text'**
  String get actCopyText;

  /// No description provided for @actForward.
  ///
  /// In en, this message translates to:
  /// **'Forward'**
  String get actForward;

  /// No description provided for @actSaveToGallery.
  ///
  /// In en, this message translates to:
  /// **'Save to gallery'**
  String get actSaveToGallery;

  /// No description provided for @actSendAgain.
  ///
  /// In en, this message translates to:
  /// **'Send again'**
  String get actSendAgain;

  /// No description provided for @actUnpin.
  ///
  /// In en, this message translates to:
  /// **'Unpin'**
  String get actUnpin;

  /// No description provided for @actPin.
  ///
  /// In en, this message translates to:
  /// **'Pin'**
  String get actPin;

  /// No description provided for @actEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get actEdit;

  /// No description provided for @actSelect.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get actSelect;

  /// No description provided for @actDetails.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get actDetails;

  /// No description provided for @deleteTitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Delete message?} other{Delete {count} messages?}}'**
  String deleteTitle(int count);

  /// No description provided for @deleteForMeNote.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Delete for me removes it from this phone only. Everyone else keeps their copy.} other{Delete for me removes them from this phone only. Everyone else keeps their copy.}}'**
  String deleteForMeNote(int count);

  /// No description provided for @deleteEveryoneDirect.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Delete for everyone also asks {who}\'s phone to remove it. It is a request: it takes effect when their phone receives it (they must come into range within about 12 hours). A copy somebody saved or photographed cannot be reached.} other{Delete for everyone also asks {who}\'s phone to remove them. It is a request: it takes effect when their phone receives it (they must come into range within about 12 hours). A copy somebody saved or photographed cannot be reached.}}'**
  String deleteEveryoneDirect(int count, String who);

  /// No description provided for @deleteEveryoneGroup.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Delete for everyone also asks every member\'s phone to remove it. It is a request: it takes effect on each phone when it receives it, and a phone that is out of range gets it later, if it comes back in time. A copy somebody saved or photographed cannot be reached.} other{Delete for everyone also asks every member\'s phone to remove them. It is a request: it takes effect on each phone when it receives it, and a phone that is out of range gets it later, if it comes back in time. A copy somebody saved or photographed cannot be reached.}}'**
  String deleteEveryoneGroup(int count);

  /// No description provided for @deleteEveryoneRoom.
  ///
  /// In en, this message translates to:
  /// **'Delete for everyone also asks every phone nearby that has {count, plural, =1{it to remove it} other{them to remove them}}. It is a request: it takes effect on each phone when it receives it, and a phone that is out of range gets it later, if it comes back in time. A copy somebody saved or photographed cannot be reached.'**
  String deleteEveryoneRoom(int count);

  /// No description provided for @deleteEveryoneOwnOnly.
  ///
  /// In en, this message translates to:
  /// **'Delete for everyone is only possible for your own messages.'**
  String get deleteEveryoneOwnOnly;

  /// No description provided for @deleteEveryoneOwnOrAdmin.
  ///
  /// In en, this message translates to:
  /// **'Delete for everyone is only possible for your own messages (and for the group\'s admin).'**
  String get deleteEveryoneOwnOrAdmin;

  /// No description provided for @deleteForMe.
  ///
  /// In en, this message translates to:
  /// **'Delete for me'**
  String get deleteForMe;

  /// No description provided for @deleteForEveryone.
  ///
  /// In en, this message translates to:
  /// **'Delete for everyone'**
  String get deleteForEveryone;

  /// No description provided for @selCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel selection'**
  String get selCancel;

  /// No description provided for @selCount.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String selCount(int count);

  /// No description provided for @quoteOriginalDeleted.
  ///
  /// In en, this message translates to:
  /// **'Original message deleted'**
  String get quoteOriginalDeleted;

  /// No description provided for @forwardedFrom.
  ///
  /// In en, this message translates to:
  /// **'Forwarded from {name}'**
  String forwardedFrom(String name);

  /// No description provided for @pinnedOf.
  ///
  /// In en, this message translates to:
  /// **'Pinned message {index} of {count}'**
  String pinnedOf(int index, int count);

  /// No description provided for @pinnedMessage.
  ///
  /// In en, this message translates to:
  /// **'Pinned message'**
  String get pinnedMessage;

  /// No description provided for @pinnedAll.
  ///
  /// In en, this message translates to:
  /// **'All pinned messages'**
  String get pinnedAll;

  /// No description provided for @delWaiting.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Waiting for {name}\'s phone to confirm a deleted message. It happens as soon as you are in range.} other{Waiting for {name}\'s phone to confirm {count} deleted messages. It happens as soon as you are in range.}}'**
  String delWaiting(int count, String name);

  /// No description provided for @delExpired.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{name}\'s phone did not get a delete request in time, so that message may still be there.} other{{name}\'s phone did not get {count} delete requests in time, so those messages may still be there.}}'**
  String delExpired(int count, String name);

  /// No description provided for @snippetUnreadable.
  ///
  /// In en, this message translates to:
  /// **'Message could not be read'**
  String get snippetUnreadable;

  /// No description provided for @replyingTo.
  ///
  /// In en, this message translates to:
  /// **'Replying to {name}'**
  String replyingTo(String name);

  /// No description provided for @editMessageTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit message'**
  String get editMessageTitle;

  /// No description provided for @cancelEditing.
  ///
  /// In en, this message translates to:
  /// **'Cancel editing'**
  String get cancelEditing;

  /// No description provided for @cancelReply.
  ///
  /// In en, this message translates to:
  /// **'Cancel reply'**
  String get cancelReply;

  /// No description provided for @bubbleUndecryptable.
  ///
  /// In en, this message translates to:
  /// **'This message could not be decrypted or verified, so it was not shown. It may have been corrupted, tampered with, or encrypted for a different key.'**
  String get bubbleUndecryptable;

  /// No description provided for @bubblePicture.
  ///
  /// In en, this message translates to:
  /// **'Picture'**
  String get bubblePicture;

  /// No description provided for @bubbleVideo.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get bubbleVideo;

  /// No description provided for @bubbleVoice.
  ///
  /// In en, this message translates to:
  /// **'Voice message'**
  String get bubbleVoice;

  /// No description provided for @bubbleEdited.
  ///
  /// In en, this message translates to:
  /// **'edited'**
  String get bubbleEdited;

  /// No description provided for @bubbleViaRelays.
  ///
  /// In en, this message translates to:
  /// **'{hops, plural, =1{via 1 relay} other{via {hops} relays}}'**
  String bubbleViaRelays(int hops);

  /// No description provided for @bubbleNotDelivered.
  ///
  /// In en, this message translates to:
  /// **'This message could not be delivered.'**
  String get bubbleNotDelivered;

  /// No description provided for @composerCouldNotSend.
  ///
  /// In en, this message translates to:
  /// **'Could not send: {error}'**
  String composerCouldNotSend(String error);

  /// No description provided for @attachSendPicture.
  ///
  /// In en, this message translates to:
  /// **'Send a picture'**
  String get attachSendPicture;

  /// No description provided for @attachTakePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take a photo'**
  String get attachTakePhoto;

  /// No description provided for @attachChoosePhoto.
  ///
  /// In en, this message translates to:
  /// **'Choose from your photos'**
  String get attachChoosePhoto;

  /// No description provided for @attachPictureNote.
  ///
  /// In en, this message translates to:
  /// **'Pictures are shrunk to a few dozen kilobytes so they can cross Bluetooth, and are sent only to the people in this chat.'**
  String get attachPictureNote;

  /// No description provided for @attachSendVideo.
  ///
  /// In en, this message translates to:
  /// **'Send a video'**
  String get attachSendVideo;

  /// No description provided for @attachRecordVideo.
  ///
  /// In en, this message translates to:
  /// **'Record a short video'**
  String get attachRecordVideo;

  /// No description provided for @attachChooseVideo.
  ///
  /// In en, this message translates to:
  /// **'Choose a video'**
  String get attachChooseVideo;

  /// No description provided for @attachVideoNote.
  ///
  /// In en, this message translates to:
  /// **'Videos are not shrunk: only a very short, low-quality clip (up to {limit}) can cross Bluetooth, and it can take minutes. Bigger ones are refused. You can change the limit under Settings > Storage.'**
  String attachVideoNote(String limit);

  /// No description provided for @composerAllowPicture.
  ///
  /// In en, this message translates to:
  /// **'Allow access to send a picture.'**
  String get composerAllowPicture;

  /// No description provided for @composerOpenCameraFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the camera: {error}'**
  String composerOpenCameraFailed(String error);

  /// No description provided for @composerOpenPhotosFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the photos: {error}'**
  String composerOpenPhotosFailed(String error);

  /// No description provided for @composerOpenVideosFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the videos: {error}'**
  String composerOpenVideosFailed(String error);

  /// No description provided for @composerPictureNotPrepared.
  ///
  /// In en, this message translates to:
  /// **'That picture could not be prepared: {error}'**
  String composerPictureNotPrepared(String error);

  /// No description provided for @composerAllowVideo.
  ///
  /// In en, this message translates to:
  /// **'Allow access to send a video.'**
  String get composerAllowVideo;

  /// No description provided for @composerVideoTooBig.
  ///
  /// In en, this message translates to:
  /// **'That video is {size}. Over Bluetooth a video can be at most {limit} (you can raise this under Settings > Storage, up to {max}). Choose a shorter or smaller clip.'**
  String composerVideoTooBig(String size, String limit, String max);

  /// No description provided for @composerAllowMic.
  ///
  /// In en, this message translates to:
  /// **'Allow the microphone to record a voice message.'**
  String get composerAllowMic;

  /// No description provided for @composerRecordFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not start recording: {error}'**
  String composerRecordFailed(String error);

  /// No description provided for @composerVoiceTooShort.
  ///
  /// In en, this message translates to:
  /// **'That was too short for a voice message. Keep the microphone open a little longer.'**
  String get composerVoiceTooShort;

  /// No description provided for @composerBytesCounter.
  ///
  /// In en, this message translates to:
  /// **'{bytes} / {max} bytes'**
  String composerBytesCounter(int bytes, int max);

  /// No description provided for @composerTooLong.
  ///
  /// In en, this message translates to:
  /// **'Too long'**
  String get composerTooLong;

  /// No description provided for @composerSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get composerSaveChanges;

  /// No description provided for @composerRecord.
  ///
  /// In en, this message translates to:
  /// **'Record a voice message'**
  String get composerRecord;

  /// No description provided for @composerDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard the recording'**
  String get composerDiscard;

  /// No description provided for @composerSendVoice.
  ///
  /// In en, this message translates to:
  /// **'Send the voice message'**
  String get composerSendVoice;

  /// No description provided for @previewSendPicture.
  ///
  /// In en, this message translates to:
  /// **'Send this picture?'**
  String get previewSendPicture;

  /// No description provided for @previewSendVideo.
  ///
  /// In en, this message translates to:
  /// **'Send this video?'**
  String get previewSendVideo;

  /// No description provided for @previewCaptionHint.
  ///
  /// In en, this message translates to:
  /// **'Add a caption (optional)'**
  String get previewCaptionHint;

  /// No description provided for @previewVideoNote.
  ///
  /// In en, this message translates to:
  /// **'It goes over Bluetooth, only to the people in this chat, and it can take several minutes - longer when it has to pass through other phones. The person has to stay in range, with the app open, until it arrives.'**
  String get previewVideoNote;

  /// No description provided for @chatFallbackLower.
  ///
  /// In en, this message translates to:
  /// **'chat'**
  String get chatFallbackLower;

  /// No description provided for @chatSearchTooltip.
  ///
  /// In en, this message translates to:
  /// **'Search this chat'**
  String get chatSearchTooltip;

  /// No description provided for @chatFallbackGroup.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get chatFallbackGroup;

  /// No description provided for @chatFallbackChat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get chatFallbackChat;

  /// No description provided for @chatGroupMembers.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 member} other{{count} members}}'**
  String chatGroupMembers(int count);

  /// No description provided for @chatGroupMembersNearby.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 member · {nearby} nearby} other{{count} members · {nearby} nearby}}'**
  String chatGroupMembersNearby(int count, int nearby);

  /// No description provided for @chatInvitation.
  ///
  /// In en, this message translates to:
  /// **'Invitation'**
  String get chatInvitation;

  /// No description provided for @chatGroupDetails.
  ///
  /// In en, this message translates to:
  /// **'Group details'**
  String get chatGroupDetails;

  /// No description provided for @chatVerifiedContact.
  ///
  /// In en, this message translates to:
  /// **'Verified contact'**
  String get chatVerifiedContact;

  /// No description provided for @chatVerifyContact.
  ///
  /// In en, this message translates to:
  /// **'Verify this contact'**
  String get chatVerifyContact;

  /// No description provided for @chatTheOtherPerson.
  ///
  /// In en, this message translates to:
  /// **'the other person'**
  String get chatTheOtherPerson;

  /// No description provided for @composerHint.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get composerHint;

  /// No description provided for @chatRemovedFromGroup.
  ///
  /// In en, this message translates to:
  /// **'You were removed from this group'**
  String get chatRemovedFromGroup;

  /// No description provided for @chatYouBlocked.
  ///
  /// In en, this message translates to:
  /// **'You blocked this contact'**
  String get chatYouBlocked;

  /// No description provided for @chatEmptyGroup.
  ///
  /// In en, this message translates to:
  /// **'No messages yet. Everything here is encrypted with the group\'s key and reaches every member, now or when they are next in range.'**
  String get chatEmptyGroup;

  /// No description provided for @chatEmptyDirect.
  ///
  /// In en, this message translates to:
  /// **'No messages yet. They are end-to-end encrypted, and wait here if the other phone is out of range.'**
  String get chatEmptyDirect;

  /// No description provided for @chatToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get chatToday;

  /// No description provided for @stripWaitingForKey.
  ///
  /// In en, this message translates to:
  /// **'Waiting for this person\'s encryption key. It arrives automatically the first time you are in range of them.'**
  String get stripWaitingForKey;

  /// No description provided for @stripDirect.
  ///
  /// In en, this message translates to:
  /// **'Directly connected. Messages are delivered immediately.'**
  String get stripDirect;

  /// No description provided for @stripRelayed.
  ///
  /// In en, this message translates to:
  /// **'Reachable through other phones ({hops} hops). Messages are relayed, still end-to-end encrypted.'**
  String stripRelayed(int hops);

  /// No description provided for @stripOffline.
  ///
  /// In en, this message translates to:
  /// **'Not reachable right now. Messages wait on this phone and are sent as soon as this person (or a phone that can reach them) comes into range, for up to 12 hours.'**
  String get stripOffline;

  /// No description provided for @fwdTitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Forward to…} other{Forward {count} messages to…}}'**
  String fwdTitle(int count);

  /// No description provided for @fwdSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search chats'**
  String get fwdSearchHint;

  /// No description provided for @fwdNoTargets.
  ///
  /// In en, this message translates to:
  /// **'There is no chat to forward to yet. Start a chat with someone nearby first.'**
  String get fwdNoTargets;

  /// No description provided for @fwdNoMatch.
  ///
  /// In en, this message translates to:
  /// **'No chat matches \"{query}\".'**
  String fwdNoMatch(String query);

  /// No description provided for @fwdPrivateChat.
  ///
  /// In en, this message translates to:
  /// **'Private chat'**
  String get fwdPrivateChat;

  /// No description provided for @fwdPublicRoom.
  ///
  /// In en, this message translates to:
  /// **'Public room · everyone nearby can read it'**
  String get fwdPublicRoom;

  /// No description provided for @commonClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get commonClear;

  /// No description provided for @searchInTitle.
  ///
  /// In en, this message translates to:
  /// **'Search in {title}'**
  String searchInTitle(String title);

  /// No description provided for @searchPictures.
  ///
  /// In en, this message translates to:
  /// **'Pictures'**
  String get searchPictures;

  /// No description provided for @searchVideos.
  ///
  /// In en, this message translates to:
  /// **'Videos'**
  String get searchVideos;

  /// No description provided for @searchVoice.
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get searchVoice;

  /// No description provided for @searchFromMe.
  ///
  /// In en, this message translates to:
  /// **'From me'**
  String get searchFromMe;

  /// No description provided for @searchEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Type a word, or pick Pictures, Videos or Voice to see only those. Messages that were deleted are not searched: they are gone.'**
  String get searchEmptyBody;

  /// No description provided for @searchNoMatch.
  ///
  /// In en, this message translates to:
  /// **'No message in this chat matches.'**
  String get searchNoMatch;

  /// No description provided for @detailUnknownPhone.
  ///
  /// In en, this message translates to:
  /// **'Unknown phone'**
  String get detailUnknownPhone;

  /// No description provided for @detailAnyMoment.
  ///
  /// In en, this message translates to:
  /// **'any moment now'**
  String get detailAnyMoment;

  /// No description provided for @detailInMinutes.
  ///
  /// In en, this message translates to:
  /// **'in {minutes} min'**
  String detailInMinutes(int minutes);

  /// No description provided for @detailInHours.
  ///
  /// In en, this message translates to:
  /// **'in {hours} h'**
  String detailInHours(int hours);

  /// No description provided for @detailInHoursMinutes.
  ///
  /// In en, this message translates to:
  /// **'in {hours} h {minutes} min'**
  String detailInHoursMinutes(int hours, int minutes);

  /// No description provided for @detailTitle.
  ///
  /// In en, this message translates to:
  /// **'Message details'**
  String get detailTitle;

  /// No description provided for @detailFrom.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get detailFrom;

  /// No description provided for @detailDirection.
  ///
  /// In en, this message translates to:
  /// **'Direction'**
  String get detailDirection;

  /// No description provided for @detailSentByYou.
  ///
  /// In en, this message translates to:
  /// **'Sent by you'**
  String get detailSentByYou;

  /// No description provided for @detailReceived.
  ///
  /// In en, this message translates to:
  /// **'Received'**
  String get detailReceived;

  /// No description provided for @detailType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get detailType;

  /// No description provided for @detailSize.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get detailSize;

  /// No description provided for @detailStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get detailStatus;

  /// No description provided for @detailConfirmedBy.
  ///
  /// In en, this message translates to:
  /// **'Confirmed by'**
  String get detailConfirmedBy;

  /// No description provided for @detailConfirmedOf.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total} members'**
  String detailConfirmedOf(int done, int total);

  /// No description provided for @detailHasIt.
  ///
  /// In en, this message translates to:
  /// **'Has it'**
  String get detailHasIt;

  /// No description provided for @detailNotYet.
  ///
  /// In en, this message translates to:
  /// **'Not yet'**
  String get detailNotYet;

  /// No description provided for @detailSentTheirClock.
  ///
  /// In en, this message translates to:
  /// **'Sent (their clock)'**
  String get detailSentTheirClock;

  /// No description provided for @detailWrittenSaved.
  ///
  /// In en, this message translates to:
  /// **'Written and saved'**
  String get detailWrittenSaved;

  /// No description provided for @detailReceivedSaved.
  ///
  /// In en, this message translates to:
  /// **'Received and saved'**
  String get detailReceivedSaved;

  /// No description provided for @detailEdited.
  ///
  /// In en, this message translates to:
  /// **'Edited'**
  String get detailEdited;

  /// No description provided for @detailForwardedFrom.
  ///
  /// In en, this message translates to:
  /// **'Forwarded from'**
  String get detailForwardedFrom;

  /// No description provided for @detailReplyTo.
  ///
  /// In en, this message translates to:
  /// **'Reply to'**
  String get detailReplyTo;

  /// No description provided for @detailReplyDeleted.
  ///
  /// In en, this message translates to:
  /// **'a message that was deleted'**
  String get detailReplyDeleted;

  /// No description provided for @detailPinned.
  ///
  /// In en, this message translates to:
  /// **'Pinned'**
  String get detailPinned;

  /// No description provided for @detailPinnedValue.
  ///
  /// In en, this message translates to:
  /// **'Yes - only on this phone'**
  String get detailPinnedValue;

  /// No description provided for @detailDisappears.
  ///
  /// In en, this message translates to:
  /// **'Disappears'**
  String get detailDisappears;

  /// No description provided for @detailDisappearsValue.
  ///
  /// In en, this message translates to:
  /// **'{when} ({remaining}). Messages of public rooms are removed from this phone six hours after they arrive.'**
  String detailDisappearsValue(String when, String remaining);

  /// No description provided for @detailReceiptPath.
  ///
  /// In en, this message translates to:
  /// **'Receipt path'**
  String get detailReceiptPath;

  /// No description provided for @detailRoute.
  ///
  /// In en, this message translates to:
  /// **'Route'**
  String get detailRoute;

  /// No description provided for @detailRadioHops.
  ///
  /// In en, this message translates to:
  /// **'{count} radio hops'**
  String detailRadioHops(int count);

  /// No description provided for @detailPassedThrough.
  ///
  /// In en, this message translates to:
  /// **'{hops, plural, =1{passed through 1 relay} other{passed through {hops} relays}}'**
  String detailPassedThrough(int hops);

  /// No description provided for @detailNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get detailNote;

  /// No description provided for @detailClockSkew.
  ///
  /// In en, this message translates to:
  /// **'The sender\'s clock differs from yours by more than 10 minutes.'**
  String get detailClockSkew;

  /// No description provided for @detailProblem.
  ///
  /// In en, this message translates to:
  /// **'Problem'**
  String get detailProblem;

  /// No description provided for @detailMessageId.
  ///
  /// In en, this message translates to:
  /// **'Message id'**
  String get detailMessageId;

  /// No description provided for @galDenied.
  ///
  /// In en, this message translates to:
  /// **'دەمەتەقێ was not allowed to add to your gallery. You can allow it in your phone\'s settings.'**
  String get galDenied;

  /// No description provided for @galNoSpace.
  ///
  /// In en, this message translates to:
  /// **'There is not enough space on this phone to save it.'**
  String get galNoSpace;

  /// No description provided for @galUnsupported.
  ///
  /// In en, this message translates to:
  /// **'This phone cannot save that kind of file to the gallery.'**
  String get galUnsupported;

  /// No description provided for @galFailed.
  ///
  /// In en, this message translates to:
  /// **'It could not be saved to the gallery.'**
  String get galFailed;

  /// No description provided for @galPictureGone.
  ///
  /// In en, this message translates to:
  /// **'That picture is no longer on this phone.'**
  String get galPictureGone;

  /// No description provided for @galVideoGone.
  ///
  /// In en, this message translates to:
  /// **'That video cannot be saved from this phone.'**
  String get galVideoGone;

  /// No description provided for @galVoice.
  ///
  /// In en, this message translates to:
  /// **'Voice messages cannot be saved to the gallery.'**
  String get galVoice;

  /// No description provided for @imgUnreadable.
  ///
  /// In en, this message translates to:
  /// **'That file is not a picture this phone can read.'**
  String get imgUnreadable;

  /// No description provided for @imgTooDetailed.
  ///
  /// In en, this message translates to:
  /// **'That picture is too detailed to send over Bluetooth.'**
  String get imgTooDetailed;

  /// No description provided for @voiceMicOff.
  ///
  /// In en, this message translates to:
  /// **'The microphone is switched off for دەمەتەقێ.'**
  String get voiceMicOff;

  /// No description provided for @radarListening.
  ///
  /// In en, this message translates to:
  /// **'Listening for people nearby'**
  String get radarListening;

  /// No description provided for @commonStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get commonStop;

  /// No description provided for @diagRunAgain.
  ///
  /// In en, this message translates to:
  /// **'Run again'**
  String get diagRunAgain;

  /// No description provided for @diagRun.
  ///
  /// In en, this message translates to:
  /// **'Run self-test'**
  String get diagRun;

  /// No description provided for @diagReportCopied.
  ///
  /// In en, this message translates to:
  /// **'Report copied'**
  String get diagReportCopied;

  /// No description provided for @diagCopyReport.
  ///
  /// In en, this message translates to:
  /// **'Copy report'**
  String get diagCopyReport;

  /// No description provided for @diagLogTitle.
  ///
  /// In en, this message translates to:
  /// **'Activity log'**
  String get diagLogTitle;

  /// No description provided for @diagLogNote.
  ///
  /// In en, this message translates to:
  /// **'Kept in memory only; gone when the app closes'**
  String get diagLogNote;

  /// No description provided for @diagIntroTitle.
  ///
  /// In en, this message translates to:
  /// **'Check that Bluetooth really works'**
  String get diagIntroTitle;

  /// No description provided for @diagIntroBody.
  ///
  /// In en, this message translates to:
  /// **'Best done with two phones side by side, both running دەمەتەقێ with Bluetooth on. Turn Wi-Fi and mobile data off first to prove nothing needs the internet. The test takes about half a minute and tells you what to fix if a step fails.'**
  String get diagIntroBody;

  /// No description provided for @diagPass.
  ///
  /// In en, this message translates to:
  /// **'Everything that could be tested passed'**
  String get diagPass;

  /// No description provided for @diagPassBody.
  ///
  /// In en, this message translates to:
  /// **'These phones found each other, proved their identities and exchanged data over Bluetooth.'**
  String get diagPassBody;

  /// No description provided for @diagWarn.
  ///
  /// In en, this message translates to:
  /// **'Works, with something to look at'**
  String get diagWarn;

  /// No description provided for @diagWarnBody.
  ///
  /// In en, this message translates to:
  /// **'Nothing failed, but at least one step could not be fully tested or ran into trouble. See below.'**
  String get diagWarnBody;

  /// No description provided for @diagFail.
  ///
  /// In en, this message translates to:
  /// **'A problem was found'**
  String get diagFail;

  /// No description provided for @diagFailBody.
  ///
  /// In en, this message translates to:
  /// **'Follow the advice under the failed step, then run the test again.'**
  String get diagFailBody;

  /// No description provided for @diagNoResult.
  ///
  /// In en, this message translates to:
  /// **'No result'**
  String get diagNoResult;

  /// No description provided for @diagLimitsTitle.
  ///
  /// In en, this message translates to:
  /// **'What a pass does and does not mean'**
  String get diagLimitsTitle;

  /// No description provided for @diagLimitsBody.
  ///
  /// In en, this message translates to:
  /// **'A pass means these two phones, right now, found each other, connected, authenticated each other and moved data both ways, including messages too big for one Bluetooth packet. It does not measure range, battery use, or how other phone models behave, and relaying through a third phone needs three phones to test. Phones differ a lot in Bluetooth quality, so test with the models you will use.'**
  String get diagLimitsBody;

  /// No description provided for @diagLogCopied.
  ///
  /// In en, this message translates to:
  /// **'Log copied'**
  String get diagLogCopied;

  /// No description provided for @diagLogWarn.
  ///
  /// In en, this message translates to:
  /// **'The log can contain Bluetooth addresses of phones around you. Check it before sharing. It never contains keys or message text.'**
  String get diagLogWarn;

  /// No description provided for @diagLogEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing logged yet.'**
  String get diagLogEmpty;

  /// No description provided for @stNothingToClean.
  ///
  /// In en, this message translates to:
  /// **'Nothing to clean: every public message is less than six hours old.'**
  String get stNothingToClean;

  /// No description provided for @stRemovedPublic.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Removed 1 public message.} other{Removed {count} public messages.}}'**
  String stRemovedPublic(int count);

  /// No description provided for @stDeleteMediaTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete all pictures, voice messages and videos?'**
  String get stDeleteMediaTitle;

  /// No description provided for @stDeleteMediaBody.
  ///
  /// In en, this message translates to:
  /// **'They are removed from this phone together with their messages. Nobody else is told and other phones keep their copies. This cannot be undone.'**
  String get stDeleteMediaBody;

  /// No description provided for @stDeleteMediaAction.
  ///
  /// In en, this message translates to:
  /// **'Delete them'**
  String get stDeleteMediaAction;

  /// No description provided for @stNothingToDelete.
  ///
  /// In en, this message translates to:
  /// **'There was nothing to delete.'**
  String get stNothingToDelete;

  /// No description provided for @stDeletedMedia.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Deleted 1 message with files.} other{Deleted {count} messages with files.}}'**
  String stDeletedMedia(int count);

  /// No description provided for @stMessages.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get stMessages;

  /// No description provided for @stMedia.
  ///
  /// In en, this message translates to:
  /// **'Pictures, voice messages and videos'**
  String get stMedia;

  /// No description provided for @stFiles.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 file} other{{count} files}}'**
  String stFiles(int count);

  /// No description provided for @stDatabase.
  ///
  /// In en, this message translates to:
  /// **'Message database'**
  String get stDatabase;

  /// No description provided for @stPublic.
  ///
  /// In en, this message translates to:
  /// **'Public chats'**
  String get stPublic;

  /// No description provided for @stMessagesCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 message} other{{count} messages}}'**
  String stMessagesCount(int count);

  /// No description provided for @stPublicNoteNever.
  ///
  /// In en, this message translates to:
  /// **'Removed from this phone six hours after they arrive. Nothing has been removed yet.'**
  String get stPublicNoteNever;

  /// No description provided for @stPublicNote.
  ///
  /// In en, this message translates to:
  /// **'Removed from this phone six hours after they arrive. Last clean-up {ago}, {removed} removed.'**
  String stPublicNote(String ago, int removed);

  /// No description provided for @stVideoLimit.
  ///
  /// In en, this message translates to:
  /// **'Largest video you send'**
  String get stVideoLimit;

  /// No description provided for @stVideoLimitBody.
  ///
  /// In en, this message translates to:
  /// **'A video is not shrunk, so only a very short clip fits. Bigger ones are refused before anything is sent. Larger videos take much longer over Bluetooth, and videos are never sent to public rooms. Videos you receive are accepted up to {max}.'**
  String stVideoLimitBody(String max);

  /// No description provided for @stCleanNow.
  ///
  /// In en, this message translates to:
  /// **'Clean public chats now'**
  String get stCleanNow;

  /// No description provided for @stCleanNowBody.
  ///
  /// In en, this message translates to:
  /// **'They are also cleaned by themselves, about once a minute while the app runs, and when it starts. Private chats and groups are never touched.'**
  String get stCleanNowBody;

  /// No description provided for @stDeleteMediaTile.
  ///
  /// In en, this message translates to:
  /// **'Delete all pictures, voice messages and videos'**
  String get stDeleteMediaTile;

  /// No description provided for @stDeleteMediaTileBody.
  ///
  /// In en, this message translates to:
  /// **'Frees the most space. The messages that carried them go too.'**
  String get stDeleteMediaTileBody;

  /// No description provided for @stFooter.
  ///
  /// In en, this message translates to:
  /// **'To remove old messages automatically, use \"Keep messages\" under Privacy and security in the settings. Messages and files are stored without encryption of their own: they rely on your phone\'s screen lock and disk encryption.'**
  String get stFooter;

  /// No description provided for @nearbyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nearby'**
  String get nearbyTitle;

  /// No description provided for @nearbyVisible.
  ///
  /// In en, this message translates to:
  /// **'Visible to others'**
  String get nearbyVisible;

  /// No description provided for @nearbySearching.
  ///
  /// In en, this message translates to:
  /// **'Searching'**
  String get nearbySearching;

  /// No description provided for @nearbyScanningNow.
  ///
  /// In en, this message translates to:
  /// **'Scanning now'**
  String get nearbyScanningNow;

  /// No description provided for @nearbyBetweenScans.
  ///
  /// In en, this message translates to:
  /// **'Between scans'**
  String get nearbyBetweenScans;

  /// No description provided for @nearbyStopped.
  ///
  /// In en, this message translates to:
  /// **'Stopped'**
  String get nearbyStopped;

  /// No description provided for @nearbyHowHard.
  ///
  /// In en, this message translates to:
  /// **'How hard to look'**
  String get nearbyHowHard;

  /// No description provided for @nearbyRunSelfTest.
  ///
  /// In en, this message translates to:
  /// **'Run Bluetooth self-test'**
  String get nearbyRunSelfTest;

  /// No description provided for @nearbyConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected phones ({count})'**
  String nearbyConnected(int count);

  /// No description provided for @nearbyNoLinks.
  ///
  /// In en, this message translates to:
  /// **'No Bluetooth connections right now. Connections appear here as soon as a nearby phone is found, then show \"Verifying\" until it has proved its identity.'**
  String get nearbyNoLinks;

  /// No description provided for @nearbyHeard.
  ///
  /// In en, this message translates to:
  /// **'Devices heard ({count})'**
  String nearbyHeard(int count);

  /// No description provided for @nearbyNothingHeard.
  ///
  /// In en, this message translates to:
  /// **'Nothing heard yet. Other phones running دەمەتەقێ are found within about 10 metres. Both phones need Bluetooth on and the app open.'**
  String get nearbyNothingHeard;

  /// No description provided for @nearbyFootnote.
  ///
  /// In en, this message translates to:
  /// **'A device being \"heard\" means its Bluetooth advertisement was received. It is not trusted until it completes the identity handshake. Addresses shown here are temporary radio handles, not identities, and may change.'**
  String get nearbyFootnote;

  /// No description provided for @nearbyCannotAdvertise.
  ///
  /// In en, this message translates to:
  /// **'Cannot advertise'**
  String get nearbyCannotAdvertise;

  /// No description provided for @nearbyStartingPill.
  ///
  /// In en, this message translates to:
  /// **'Starting'**
  String get nearbyStartingPill;

  /// No description provided for @linkConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get linkConnected;

  /// No description provided for @linkVerifying.
  ///
  /// In en, this message translates to:
  /// **'Verifying…'**
  String get linkVerifying;

  /// No description provided for @linkClosing.
  ///
  /// In en, this message translates to:
  /// **'Closing'**
  String get linkClosing;

  /// No description provided for @linkUnnamed.
  ///
  /// In en, this message translates to:
  /// **'Unnamed phone'**
  String get linkUnnamed;

  /// No description provided for @linkUnverified.
  ///
  /// In en, this message translates to:
  /// **'Unverified phone'**
  String get linkUnverified;

  /// No description provided for @linkRole.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get linkRole;

  /// No description provided for @linkWeConnected.
  ///
  /// In en, this message translates to:
  /// **'we connected'**
  String get linkWeConnected;

  /// No description provided for @linkTheyConnected.
  ///
  /// In en, this message translates to:
  /// **'they connected'**
  String get linkTheyConnected;

  /// No description provided for @linkWriteSize.
  ///
  /// In en, this message translates to:
  /// **'Write size'**
  String get linkWriteSize;

  /// No description provided for @linkSignal.
  ///
  /// In en, this message translates to:
  /// **'Signal'**
  String get linkSignal;

  /// No description provided for @linkRoundTrip.
  ///
  /// In en, this message translates to:
  /// **'Round trip'**
  String get linkRoundTrip;

  /// No description provided for @linkTraffic.
  ///
  /// In en, this message translates to:
  /// **'Traffic'**
  String get linkTraffic;

  /// No description provided for @devHeard.
  ///
  /// In en, this message translates to:
  /// **'Heard'**
  String get devHeard;

  /// No description provided for @devConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get devConnecting;

  /// No description provided for @devLinked.
  ///
  /// In en, this message translates to:
  /// **'Linked'**
  String get devLinked;

  /// No description provided for @devRetrying.
  ///
  /// In en, this message translates to:
  /// **'Retrying later'**
  String get devRetrying;

  /// No description provided for @devAlreadyLinked.
  ///
  /// In en, this message translates to:
  /// **'Already linked'**
  String get devAlreadyLinked;

  /// No description provided for @devFailedAttempts.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 failed attempt} other{{count} failed attempts}}'**
  String devFailedAttempts(int count);

  /// No description provided for @errTypeFirst.
  ///
  /// In en, this message translates to:
  /// **'Type a message first.'**
  String get errTypeFirst;

  /// No description provided for @errMessageTooLong.
  ///
  /// In en, this message translates to:
  /// **'That message is too long ({bytes} of {max} bytes). Please shorten it.'**
  String errMessageTooLong(int bytes, int max);

  /// No description provided for @errReplyGone.
  ///
  /// In en, this message translates to:
  /// **'The message you are replying to is gone.'**
  String get errReplyGone;

  /// No description provided for @errUnknownContact.
  ///
  /// In en, this message translates to:
  /// **'That contact is not known yet.'**
  String get errUnknownContact;

  /// No description provided for @errBlockedContact.
  ///
  /// In en, this message translates to:
  /// **'You have blocked this contact. Unblock them to send messages.'**
  String get errBlockedContact;

  /// No description provided for @errBlockedNamed.
  ///
  /// In en, this message translates to:
  /// **'You have blocked {name}.'**
  String errBlockedNamed(String name);

  /// No description provided for @errNoKey.
  ///
  /// In en, this message translates to:
  /// **'We haven\'t received this person\'s encryption key yet. Come within range of them (or of a phone that can hear them) once, then try again.'**
  String get errNoKey;

  /// No description provided for @errNoKeyOnce.
  ///
  /// In en, this message translates to:
  /// **'We haven\'t received this person\'s encryption key yet. Come within range of them once, then try again.'**
  String get errNoKeyOnce;

  /// No description provided for @errNoKeyNamed.
  ///
  /// In en, this message translates to:
  /// **'We haven\'t received {name}\'s encryption key yet. Come within range of them once, then try again.'**
  String errNoKeyNamed(String name);

  /// No description provided for @errKeyUnusable.
  ///
  /// In en, this message translates to:
  /// **'This contact\'s encryption key is not usable. Ask them to open the app near you so it can be refreshed.'**
  String get errKeyUnusable;

  /// No description provided for @errKeyUnusableOne.
  ///
  /// In en, this message translates to:
  /// **'One person\'s encryption key is not usable. Ask them to open the app near you so it can be refreshed.'**
  String get errKeyUnusableOne;

  /// No description provided for @errNoKeyForControl.
  ///
  /// In en, this message translates to:
  /// **'We don\'t have this contact\'s encryption key, so nothing can be sent to them.'**
  String get errNoKeyForControl;

  /// No description provided for @errNoConversation.
  ///
  /// In en, this message translates to:
  /// **'That conversation no longer exists.'**
  String get errNoConversation;

  /// No description provided for @errCannotResend.
  ///
  /// In en, this message translates to:
  /// **'This message cannot be resent.'**
  String get errCannotResend;

  /// No description provided for @errFileGone.
  ///
  /// In en, this message translates to:
  /// **'The file is no longer on this phone.'**
  String get errFileGone;

  /// No description provided for @errNotQueued.
  ///
  /// In en, this message translates to:
  /// **'That could not be queued for sending. Try again.'**
  String get errNotQueued;

  /// No description provided for @unknownAuthor.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknownAuthor;

  /// No description provided for @errGroupName.
  ///
  /// In en, this message translates to:
  /// **'Give the group a name.'**
  String get errGroupName;

  /// No description provided for @errGroupGone.
  ///
  /// In en, this message translates to:
  /// **'That group no longer exists.'**
  String get errGroupGone;

  /// No description provided for @errNotInGroup.
  ///
  /// In en, this message translates to:
  /// **'You are not in this group any more.'**
  String get errNotInGroup;

  /// No description provided for @errAdminOnly.
  ///
  /// In en, this message translates to:
  /// **'Only the group\'s admin can do that.'**
  String get errAdminOnly;

  /// No description provided for @errPickPeople.
  ///
  /// In en, this message translates to:
  /// **'Pick at least one person to add.'**
  String get errPickPeople;

  /// No description provided for @errPickNewPeople.
  ///
  /// In en, this message translates to:
  /// **'Pick at least one new person to add.'**
  String get errPickNewPeople;

  /// No description provided for @errGroupFull.
  ///
  /// In en, this message translates to:
  /// **'A group can have at most {max} people, including you.'**
  String errGroupFull(int max);

  /// No description provided for @errGroupKeyMissing.
  ///
  /// In en, this message translates to:
  /// **'This group\'s key is missing.'**
  String get errGroupKeyMissing;

  /// No description provided for @errAdminCannotBeRemoved.
  ///
  /// In en, this message translates to:
  /// **'The admin cannot be removed.'**
  String get errAdminCannotBeRemoved;

  /// No description provided for @errNotInGroupPerson.
  ///
  /// In en, this message translates to:
  /// **'That person is not in the group.'**
  String get errNotInGroupPerson;

  /// No description provided for @errCreatorCannotLeave.
  ///
  /// In en, this message translates to:
  /// **'You created this group, so you cannot leave it - delete it instead.'**
  String get errCreatorCannotLeave;

  /// No description provided for @errRoomName.
  ///
  /// In en, this message translates to:
  /// **'Give the room a name.'**
  String get errRoomName;

  /// No description provided for @errRoomGone.
  ///
  /// In en, this message translates to:
  /// **'That room is no longer around.'**
  String get errRoomGone;

  /// No description provided for @errMeshCannotLeave.
  ///
  /// In en, this message translates to:
  /// **'#mesh is for everyone and cannot be left.'**
  String get errMeshCannotLeave;

  /// No description provided for @errJoinFirst.
  ///
  /// In en, this message translates to:
  /// **'Join the room to post in it.'**
  String get errJoinFirst;

  /// No description provided for @errFileEmpty.
  ///
  /// In en, this message translates to:
  /// **'That file is empty.'**
  String get errFileEmpty;

  /// No description provided for @errTooLargeForMesh.
  ///
  /// In en, this message translates to:
  /// **'That is too large for a Bluetooth mesh ({kb} KB; the limit is {limit} KB).'**
  String errTooLargeForMesh(int kb, int limit);

  /// No description provided for @errPictureUnreadable.
  ///
  /// In en, this message translates to:
  /// **'That picture could not be read.'**
  String get errPictureUnreadable;

  /// No description provided for @errVideoUnreadable.
  ///
  /// In en, this message translates to:
  /// **'That video could not be read.'**
  String get errVideoUnreadable;

  /// No description provided for @errRecordingUnreadable.
  ///
  /// In en, this message translates to:
  /// **'That recording could not be read.'**
  String get errRecordingUnreadable;

  /// No description provided for @errVoiceTooLong.
  ///
  /// In en, this message translates to:
  /// **'Voice messages can be at most {seconds} seconds long.'**
  String errVoiceTooLong(int seconds);

  /// No description provided for @errVideoNotInRooms.
  ///
  /// In en, this message translates to:
  /// **'Videos cannot be sent to public rooms: every phone in range would have to carry them. Send it in a private chat or a group.'**
  String get errVideoNotInRooms;

  /// No description provided for @errVideoTooLarge.
  ///
  /// In en, this message translates to:
  /// **'That video is too large to send.'**
  String get errVideoTooLarge;

  /// No description provided for @errNothingToShare.
  ///
  /// In en, this message translates to:
  /// **'There is nothing to share.'**
  String get errNothingToShare;

  /// No description provided for @errMessageGone.
  ///
  /// In en, this message translates to:
  /// **'That message is gone.'**
  String get errMessageGone;

  /// No description provided for @errDeleteGroupOnly.
  ///
  /// In en, this message translates to:
  /// **'Only the author, or the admin of the group, can delete a message for everyone.'**
  String get errDeleteGroupOnly;

  /// No description provided for @errDeleteOwnOnly.
  ///
  /// In en, this message translates to:
  /// **'You can only delete your own messages for everyone.'**
  String get errDeleteOwnOnly;

  /// No description provided for @errDeleteTooOld.
  ///
  /// In en, this message translates to:
  /// **'This message is older than {hours} hours, so it can no longer be deleted for everyone.'**
  String errDeleteTooOld(int hours);

  /// No description provided for @errEditOwnTextOnly.
  ///
  /// In en, this message translates to:
  /// **'Only your own text messages can be edited.'**
  String get errEditOwnTextOnly;

  /// No description provided for @errEditTooOld.
  ///
  /// In en, this message translates to:
  /// **'Messages can be edited for {hours} hours after they are sent.'**
  String errEditTooOld(int hours);

  /// No description provided for @timeYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get timeYesterday;

  /// No description provided for @weekdayMon.
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get weekdayMon;

  /// No description provided for @weekdayTue.
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get weekdayTue;

  /// No description provided for @weekdayWed.
  ///
  /// In en, this message translates to:
  /// **'Wed'**
  String get weekdayWed;

  /// No description provided for @weekdayThu.
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get weekdayThu;

  /// No description provided for @weekdayFri.
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get weekdayFri;

  /// No description provided for @weekdaySat.
  ///
  /// In en, this message translates to:
  /// **'Sat'**
  String get weekdaySat;

  /// No description provided for @weekdaySun.
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get weekdaySun;

  /// No description provided for @agoJustNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get agoJustNow;

  /// No description provided for @agoSeconds.
  ///
  /// In en, this message translates to:
  /// **'{n} s ago'**
  String agoSeconds(int n);

  /// No description provided for @agoMinutes.
  ///
  /// In en, this message translates to:
  /// **'{n} min ago'**
  String agoMinutes(int n);

  /// No description provided for @agoHours.
  ///
  /// In en, this message translates to:
  /// **'{n} h ago'**
  String agoHours(int n);

  /// No description provided for @agoDays.
  ///
  /// In en, this message translates to:
  /// **'{n} d ago'**
  String agoDays(int n);

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @homePeople.
  ///
  /// In en, this message translates to:
  /// **'People'**
  String get homePeople;

  /// No description provided for @homeSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search chats, groups and people'**
  String get homeSearchHint;

  /// No description provided for @navPrivate.
  ///
  /// In en, this message translates to:
  /// **'Private'**
  String get navPrivate;

  /// No description provided for @navGroups.
  ///
  /// In en, this message translates to:
  /// **'Groups'**
  String get navGroups;

  /// No description provided for @navPublic.
  ///
  /// In en, this message translates to:
  /// **'Public'**
  String get navPublic;

  /// No description provided for @fabNewMessage.
  ///
  /// In en, this message translates to:
  /// **'New message'**
  String get fabNewMessage;

  /// No description provided for @fabNewGroup.
  ///
  /// In en, this message translates to:
  /// **'New group'**
  String get fabNewGroup;

  /// No description provided for @homeNoMessagesYet.
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get homeNoMessagesYet;

  /// No description provided for @homePrivateEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No private chats yet'**
  String get homePrivateEmptyTitle;

  /// No description provided for @homeNothingFound.
  ///
  /// In en, this message translates to:
  /// **'Nothing found'**
  String get homeNothingFound;

  /// No description provided for @homePrivateEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'دەمەتەقێ works without internet, using Bluetooth. Ask someone nearby to open the app; when their phone is in range they will appear here.'**
  String get homePrivateEmptyBody;

  /// No description provided for @homeNoMatchChat.
  ///
  /// In en, this message translates to:
  /// **'No chat or person matches \"{query}\".'**
  String homeNoMatchChat(String query);

  /// No description provided for @homeSeePeople.
  ///
  /// In en, this message translates to:
  /// **'See people'**
  String get homeSeePeople;

  /// No description provided for @homeDeleteChatTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this conversation?'**
  String get homeDeleteChatTitle;

  /// No description provided for @homeDeleteChatBody.
  ///
  /// In en, this message translates to:
  /// **'Its messages and pictures are removed from this phone only.'**
  String get homeDeleteChatBody;

  /// No description provided for @homeAvailableNow.
  ///
  /// In en, this message translates to:
  /// **'Available now'**
  String get homeAvailableNow;

  /// No description provided for @homeGroupsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No groups yet'**
  String get homeGroupsEmptyTitle;

  /// No description provided for @homeGroupsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'A group is a private chat for several people at once, encrypted with a key only its members have. Create one with people you have met.'**
  String get homeGroupsEmptyBody;

  /// No description provided for @homeNoMatchGroup.
  ///
  /// In en, this message translates to:
  /// **'No group matches \"{query}\".'**
  String homeNoMatchGroup(String query);

  /// No description provided for @homeCreateGroup.
  ///
  /// In en, this message translates to:
  /// **'Create a group'**
  String get homeCreateGroup;

  /// No description provided for @homeInvitations.
  ///
  /// In en, this message translates to:
  /// **'Invitations ({count})'**
  String homeInvitations(int count);

  /// No description provided for @homeYourGroups.
  ///
  /// In en, this message translates to:
  /// **'Your groups'**
  String get homeYourGroups;

  /// No description provided for @homeYouLeft.
  ///
  /// In en, this message translates to:
  /// **'You left this group'**
  String get homeYouLeft;

  /// No description provided for @homeYouWereRemoved.
  ///
  /// In en, this message translates to:
  /// **'You were removed'**
  String get homeYouWereRemoved;

  /// No description provided for @homeDeleteGroupTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this group?'**
  String get homeDeleteGroupTitle;

  /// No description provided for @homeLeaveGroupTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave this group?'**
  String get homeLeaveGroupTitle;

  /// No description provided for @homeDeleteThisChatTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this chat?'**
  String get homeDeleteThisChatTitle;

  /// No description provided for @homeDeleteGroupBody.
  ///
  /// In en, this message translates to:
  /// **'The group ends for everybody. Each member keeps what they already have.'**
  String get homeDeleteGroupBody;

  /// No description provided for @homeLeaveGroupBody.
  ///
  /// In en, this message translates to:
  /// **'You will stop receiving its messages. Your copy of the chat is deleted from this phone.'**
  String get homeLeaveGroupBody;

  /// No description provided for @homeDeleteThisChatBody.
  ///
  /// In en, this message translates to:
  /// **'The chat is removed from this phone.'**
  String get homeDeleteThisChatBody;

  /// No description provided for @commonContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get commonContinue;

  /// No description provided for @homeSomeone.
  ///
  /// In en, this message translates to:
  /// **'Someone'**
  String get homeSomeone;

  /// No description provided for @homeInvitedYou.
  ///
  /// In en, this message translates to:
  /// **'{name} invited you · {count} people'**
  String homeInvitedYou(String name, int count);

  /// No description provided for @commonDecline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get commonDecline;

  /// No description provided for @commonAccept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get commonAccept;

  /// No description provided for @homeMeshSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Everyone nearby · public'**
  String get homeMeshSubtitle;

  /// No description provided for @homeLeaveRoomTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave {room}?'**
  String homeLeaveRoomTitle(String room);

  /// No description provided for @homeLeaveRoomBody.
  ///
  /// In en, this message translates to:
  /// **'Its messages and pictures are removed from this phone. You can join again while the room is still around.'**
  String get homeLeaveRoomBody;

  /// No description provided for @commonLeave.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get commonLeave;

  /// No description provided for @homeNearbyRooms.
  ///
  /// In en, this message translates to:
  /// **'Nearby rooms'**
  String get homeNearbyRooms;

  /// No description provided for @homeListeningForRooms.
  ///
  /// In en, this message translates to:
  /// **'Listening for rooms. Rooms created by people nearby, or passed on by their phones, appear here.'**
  String get homeListeningForRooms;

  /// No description provided for @homeHeardAgo.
  ///
  /// In en, this message translates to:
  /// **'heard {ago}'**
  String homeHeardAgo(String ago);

  /// No description provided for @commonJoin.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get commonJoin;

  /// No description provided for @promptTypeToConfirm.
  ///
  /// In en, this message translates to:
  /// **'Type \"{word}\" to confirm:'**
  String promptTypeToConfirm(String word);

  /// No description provided for @defaultNickname.
  ///
  /// In en, this message translates to:
  /// **'Phone {code}'**
  String defaultNickname(String code);

  /// No description provided for @previewYou.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get previewYou;

  /// No description provided for @previewPhoto.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get previewPhoto;

  /// No description provided for @previewVoice.
  ///
  /// In en, this message translates to:
  /// **'Voice message'**
  String get previewVoice;

  /// No description provided for @previewVideo.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get previewVideo;

  /// No description provided for @previewUndecryptable.
  ///
  /// In en, this message translates to:
  /// **'Message could not be decrypted'**
  String get previewUndecryptable;

  /// No description provided for @notifyHiddenInvite.
  ///
  /// In en, this message translates to:
  /// **'You have a new group invitation'**
  String get notifyHiddenInvite;

  /// No description provided for @notifyHiddenMany.
  ///
  /// In en, this message translates to:
  /// **'You have {count} new messages'**
  String notifyHiddenMany(int count);

  /// No description provided for @notifyHiddenOne.
  ///
  /// In en, this message translates to:
  /// **'You have a new message'**
  String get notifyHiddenOne;

  /// No description provided for @notifySenderInvite.
  ///
  /// In en, this message translates to:
  /// **'Invited you to a group'**
  String get notifySenderInvite;

  /// No description provided for @notifySenderMany.
  ///
  /// In en, this message translates to:
  /// **'{count} new messages'**
  String notifySenderMany(int count);

  /// No description provided for @notifySenderOne.
  ///
  /// In en, this message translates to:
  /// **'New message'**
  String get notifySenderOne;

  /// No description provided for @notifyFullInvite.
  ///
  /// In en, this message translates to:
  /// **'Invited you to a group'**
  String get notifyFullInvite;

  /// No description provided for @notifyFullInviteBy.
  ///
  /// In en, this message translates to:
  /// **'{name} invited you to a group'**
  String notifyFullInviteBy(String name);

  /// No description provided for @notifyFullMore.
  ///
  /// In en, this message translates to:
  /// **'{line}  (+{count} more)'**
  String notifyFullMore(String line, int count);

  /// No description provided for @notifyChannelName.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get notifyChannelName;

  /// No description provided for @notifyChannelDescription.
  ///
  /// In en, this message translates to:
  /// **'New messages and group invitations'**
  String get notifyChannelDescription;

  /// No description provided for @keepAliveChannelName.
  ///
  /// In en, this message translates to:
  /// **'Mesh running in the background'**
  String get keepAliveChannelName;

  /// No description provided for @keepAliveChannelDescription.
  ///
  /// In en, this message translates to:
  /// **'Shown while دەمەتەقێ keeps the Bluetooth mesh running with the screen off.'**
  String get keepAliveChannelDescription;

  /// No description provided for @keepAliveTitle.
  ///
  /// In en, this message translates to:
  /// **'دەمەتەقێ is keeping the mesh running'**
  String get keepAliveTitle;

  /// No description provided for @keepAliveText.
  ///
  /// In en, this message translates to:
  /// **'Relaying and receiving messages over Bluetooth. Tap to open.'**
  String get keepAliveText;

  /// No description provided for @obHeadline.
  ///
  /// In en, this message translates to:
  /// **'Chat with people nearby.\nNo internet needed.'**
  String get obHeadline;

  /// No description provided for @obPoint1Title.
  ///
  /// In en, this message translates to:
  /// **'Phone to phone, over Bluetooth'**
  String get obPoint1Title;

  /// No description provided for @obPoint1Body.
  ///
  /// In en, this message translates to:
  /// **'Messages, pictures and voice go straight from one phone to the next. No accounts, no servers, no internet.'**
  String get obPoint1Body;

  /// No description provided for @obPoint3Title.
  ///
  /// In en, this message translates to:
  /// **'Private chats, groups and public rooms'**
  String get obPoint3Title;

  /// No description provided for @obPoint3Body.
  ///
  /// In en, this message translates to:
  /// **'Chats and groups are encrypted. Public rooms are open: anyone nearby can read them.'**
  String get obPoint3Body;

  /// No description provided for @obPoint4Title.
  ///
  /// In en, this message translates to:
  /// **'Asks before it uses anything'**
  String get obPoint4Title;

  /// No description provided for @obPoint4Body.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth is requested next. The microphone, camera and photos only when you send a voice message or a picture. Never your location or contacts.'**
  String get obPoint4Body;

  /// No description provided for @obPoint5Title.
  ///
  /// In en, this message translates to:
  /// **'Good to know'**
  String get obPoint5Title;

  /// No description provided for @obPoint5Body.
  ///
  /// In en, this message translates to:
  /// **'Experimental: the encryption has not been independently audited, and passing messages through other phones has only been tested with simulated radios. More in Settings, under Help and instructions.'**
  String get obPoint5Body;

  /// No description provided for @obNameHint.
  ///
  /// In en, this message translates to:
  /// **'Shown to people nearby'**
  String get obNameHint;

  /// No description provided for @obNameNote.
  ///
  /// In en, this message translates to:
  /// **'You can change this any time in Settings. It does not have to be your real name.'**
  String get obNameNote;

  /// No description provided for @obStarting.
  ///
  /// In en, this message translates to:
  /// **'Starting…'**
  String get obStarting;

  /// No description provided for @obStart.
  ///
  /// In en, this message translates to:
  /// **'Allow Bluetooth & start'**
  String get obStart;

  /// No description provided for @gdGone.
  ///
  /// In en, this message translates to:
  /// **'This group is gone.'**
  String get gdGone;

  /// No description provided for @gdStateActive.
  ///
  /// In en, this message translates to:
  /// **'you are in'**
  String get gdStateActive;

  /// No description provided for @gdStateLeft.
  ///
  /// In en, this message translates to:
  /// **'you left'**
  String get gdStateLeft;

  /// No description provided for @gdStateRemoved.
  ///
  /// In en, this message translates to:
  /// **'you were removed'**
  String get gdStateRemoved;

  /// No description provided for @gdStateInvited.
  ///
  /// In en, this message translates to:
  /// **'invitation'**
  String get gdStateInvited;

  /// No description provided for @gdEncryptedNote.
  ///
  /// In en, this message translates to:
  /// **'Encrypted with a key only the members have. When someone is removed the group gets a new key, so they cannot read anything sent afterwards. They keep what they already received.'**
  String get gdEncryptedNote;

  /// No description provided for @gdMembers.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get gdMembers;

  /// No description provided for @gdAdmin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get gdAdmin;

  /// No description provided for @gdRemoveTooltip.
  ///
  /// In en, this message translates to:
  /// **'Remove from the group'**
  String get gdRemoveTooltip;

  /// No description provided for @gdRemoveTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}?'**
  String gdRemoveTitle(String name);

  /// No description provided for @gdRemoveBody.
  ///
  /// In en, this message translates to:
  /// **'They will no longer receive anything, and the group gets a new key they do not have.'**
  String get gdRemoveBody;

  /// No description provided for @gdFull.
  ///
  /// In en, this message translates to:
  /// **'The group is full'**
  String get gdFull;

  /// No description provided for @gdAddPeople.
  ///
  /// In en, this message translates to:
  /// **'Add people'**
  String get gdAddPeople;

  /// No description provided for @gdDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'The group ends for everybody. Each member keeps the messages they already have; nobody can send to it any more.'**
  String get gdDeleteBody;

  /// No description provided for @gdDeleteAction.
  ///
  /// In en, this message translates to:
  /// **'Delete group'**
  String get gdDeleteAction;

  /// No description provided for @gdDeleteButton.
  ///
  /// In en, this message translates to:
  /// **'Delete group for everyone'**
  String get gdDeleteButton;

  /// No description provided for @gdLeaveBody.
  ///
  /// In en, this message translates to:
  /// **'You will stop receiving its messages. The admin will give the group a new key. Your copy of the chat stays on this phone.'**
  String get gdLeaveBody;

  /// No description provided for @gdLeaveButton.
  ///
  /// In en, this message translates to:
  /// **'Leave group'**
  String get gdLeaveButton;

  /// No description provided for @gdForgetTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove from this phone?'**
  String get gdForgetTitle;

  /// No description provided for @gdForgetBody.
  ///
  /// In en, this message translates to:
  /// **'The chat and its messages are deleted from this phone.'**
  String get gdForgetBody;

  /// No description provided for @gdForgetButton.
  ///
  /// In en, this message translates to:
  /// **'Delete this chat'**
  String get gdForgetButton;

  /// No description provided for @gdInvitationsSent.
  ///
  /// In en, this message translates to:
  /// **'Invitations sent. The group has a new key.'**
  String get gdInvitationsSent;

  /// No description provided for @gdSelectedOf.
  ///
  /// In en, this message translates to:
  /// **'{count} of {room} possible'**
  String gdSelectedOf(int count, int room);

  /// No description provided for @gdInvite.
  ///
  /// In en, this message translates to:
  /// **'Invite'**
  String get gdInvite;

  /// No description provided for @pdNameTitle.
  ///
  /// In en, this message translates to:
  /// **'Name this contact'**
  String get pdNameTitle;

  /// No description provided for @pdNameHint.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get pdNameHint;

  /// No description provided for @pdDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this contact?'**
  String get pdDeleteTitle;

  /// No description provided for @pdDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'The contact and your conversation with them will be deleted from this phone. They are not notified. If they are nearby they will reappear as a new, unverified contact.'**
  String get pdDeleteBody;

  /// No description provided for @pdTitle.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get pdTitle;

  /// No description provided for @pdGone.
  ///
  /// In en, this message translates to:
  /// **'This contact no longer exists.'**
  String get pdGone;

  /// No description provided for @pdCallsThemselves.
  ///
  /// In en, this message translates to:
  /// **'calls themselves \"{name}\"'**
  String pdCallsThemselves(String name);

  /// No description provided for @pdSendMessage.
  ///
  /// In en, this message translates to:
  /// **'Send a message'**
  String get pdSendMessage;

  /// No description provided for @pdVerified.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get pdVerified;

  /// No description provided for @pdNotVerified.
  ///
  /// In en, this message translates to:
  /// **'Not verified yet'**
  String get pdNotVerified;

  /// No description provided for @pdVerifyBody.
  ///
  /// In en, this message translates to:
  /// **'Anyone can pick any nickname, and the first time two phones meet there is no way to know the keys are really theirs. To be sure, compare this safety number with the one on their phone - in person or on a call where you recognise their voice. If the numbers are identical, mark them verified. If they differ, do NOT trust this contact.'**
  String get pdVerifyBody;

  /// No description provided for @pdNoKey.
  ///
  /// In en, this message translates to:
  /// **'No encryption key received yet: come into range once.'**
  String get pdNoKey;

  /// No description provided for @pdSafetyNumber.
  ///
  /// In en, this message translates to:
  /// **'Safety number'**
  String get pdSafetyNumber;

  /// No description provided for @pdSafetyNote.
  ///
  /// In en, this message translates to:
  /// **'This is the same number on both phones. Long-press to copy.'**
  String get pdSafetyNote;

  /// No description provided for @pdNumbersMatch.
  ///
  /// In en, this message translates to:
  /// **'The numbers match'**
  String get pdNumbersMatch;

  /// No description provided for @pdMarkVerified.
  ///
  /// In en, this message translates to:
  /// **'Mark this contact as verified'**
  String get pdMarkVerified;

  /// No description provided for @pdShortId.
  ///
  /// In en, this message translates to:
  /// **'Short id'**
  String get pdShortId;

  /// No description provided for @pdFirstSeen.
  ///
  /// In en, this message translates to:
  /// **'First seen'**
  String get pdFirstSeen;

  /// No description provided for @pdLastSeen.
  ///
  /// In en, this message translates to:
  /// **'Last seen'**
  String get pdLastSeen;

  /// No description provided for @pdFullFingerprint.
  ///
  /// In en, this message translates to:
  /// **'Full fingerprint'**
  String get pdFullFingerprint;

  /// No description provided for @pdRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get pdRename;

  /// No description provided for @pdRenameBody.
  ///
  /// In en, this message translates to:
  /// **'Only you see this name'**
  String get pdRenameBody;

  /// No description provided for @pdBlock.
  ///
  /// In en, this message translates to:
  /// **'Block'**
  String get pdBlock;

  /// No description provided for @pdBlockBody.
  ///
  /// In en, this message translates to:
  /// **'Drop their messages and do not acknowledge them'**
  String get pdBlockBody;

  /// No description provided for @pdDeleteContact.
  ///
  /// In en, this message translates to:
  /// **'Delete contact'**
  String get pdDeleteContact;

  /// No description provided for @problemQueueFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not be queued for delivery'**
  String get problemQueueFailed;

  /// No description provided for @problemExpired.
  ///
  /// In en, this message translates to:
  /// **'Not delivered: the recipient could not be reached before the message expired.'**
  String get problemExpired;

  /// No description provided for @problemNobodyInRange.
  ///
  /// In en, this message translates to:
  /// **'Nobody was in range to receive this.'**
  String get problemNobodyInRange;

  /// No description provided for @problemFileDamaged.
  ///
  /// In en, this message translates to:
  /// **'The file arrived damaged and was discarded.'**
  String get problemFileDamaged;

  /// No description provided for @problemFileIncomplete.
  ///
  /// In en, this message translates to:
  /// **'The rest of this file never arrived.'**
  String get problemFileIncomplete;

  /// No description provided for @feedErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not load the messages'**
  String get feedErrorTitle;

  /// No description provided for @feedErrorBody.
  ///
  /// In en, this message translates to:
  /// **'Nothing was deleted. Try again, and if it keeps happening, restart the app.'**
  String get feedErrorBody;

  /// No description provided for @homePrivateTitle.
  ///
  /// In en, this message translates to:
  /// **'Private chats'**
  String get homePrivateTitle;

  /// No description provided for @setProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile and identity'**
  String get setProfileTitle;

  /// No description provided for @setDataHeading.
  ///
  /// In en, this message translates to:
  /// **'Data and history'**
  String get setDataHeading;

  /// No description provided for @setChatsBluetooth.
  ///
  /// In en, this message translates to:
  /// **'Chats and Bluetooth'**
  String get setChatsBluetooth;

  /// No description provided for @setHelp.
  ///
  /// In en, this message translates to:
  /// **'Help and instructions'**
  String get setHelp;

  /// No description provided for @setAboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About {name}'**
  String setAboutTitle(String name);

  /// No description provided for @setLicenses.
  ///
  /// In en, this message translates to:
  /// **'Open-source licences'**
  String get setLicenses;

  /// No description provided for @setLicensesBody.
  ///
  /// In en, this message translates to:
  /// **'The fonts and libraries this app is made with'**
  String get setLicensesBody;

  /// No description provided for @setLicensesLegalese.
  ///
  /// In en, this message translates to:
  /// **'Built with open-source software. Each part keeps its own licence.'**
  String get setLicensesLegalese;

  /// No description provided for @helpPermissionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Permissions: what is asked, and when'**
  String get helpPermissionsTitle;

  /// No description provided for @helpPermissionsBody.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth is requested when you start, so دەمەتەقێ can find nearby phones. The microphone, camera and photos are asked for only if you record a voice message or send a picture - each with an explanation first, and you can say no to any of them. دەمەتەقێ never reads your location or contacts. (Android 11 and older tie Bluetooth scanning to the Location permission; the app still never reads your location.)'**
  String get helpPermissionsBody;

  /// No description provided for @roomYourNameTitle.
  ///
  /// In en, this message translates to:
  /// **'Your name here'**
  String get roomYourNameTitle;

  /// No description provided for @roomYourNameBody.
  ///
  /// In en, this message translates to:
  /// **'Everyone in range sees this name next to what you write. It does not have to be your real name, and it is not unique: others can pick the same one.'**
  String get roomYourNameBody;

  /// No description provided for @roomExpiryNote.
  ///
  /// In en, this message translates to:
  /// **'Public · messages disappear after 6 hours'**
  String get roomExpiryNote;

  /// No description provided for @roomSearchTooltip.
  ///
  /// In en, this message translates to:
  /// **'Search this room'**
  String get roomSearchTooltip;

  /// No description provided for @roomComposerHint.
  ///
  /// In en, this message translates to:
  /// **'Message {room} · public'**
  String roomComposerHint(String room);

  /// No description provided for @roomJoinToPost.
  ///
  /// In en, this message translates to:
  /// **'Join this room to post'**
  String get roomJoinToPost;

  /// No description provided for @roomEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet. Whatever you write is public: every phone in range (and the phones they pass it to) can read it.'**
  String get roomEmpty;

  /// No description provided for @roomsCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'Create a public room'**
  String get roomsCreateTitle;

  /// No description provided for @roomsCreateBody.
  ///
  /// In en, this message translates to:
  /// **'Anyone nearby can find the room, join it and read everything said in it. It is not private. The room is listed for a day and renewed automatically while your app is running.'**
  String get roomsCreateBody;

  /// No description provided for @roomsNameHint.
  ///
  /// In en, this message translates to:
  /// **'room name'**
  String get roomsNameHint;

  /// No description provided for @roomsAboutHint.
  ///
  /// In en, this message translates to:
  /// **'What is it about? (optional)'**
  String get roomsAboutHint;

  /// No description provided for @commonCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get commonCreate;

  /// No description provided for @roomsTitle.
  ///
  /// In en, this message translates to:
  /// **'Public rooms'**
  String get roomsTitle;

  /// No description provided for @roomsCreateButton.
  ///
  /// In en, this message translates to:
  /// **'Create a room'**
  String get roomsCreateButton;

  /// No description provided for @peopleFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get peopleFilterAll;

  /// No description provided for @peopleFilterReachable.
  ///
  /// In en, this message translates to:
  /// **'Reachable now'**
  String get peopleFilterReachable;

  /// No description provided for @peopleFilterContacts.
  ///
  /// In en, this message translates to:
  /// **'Contacts'**
  String get peopleFilterContacts;

  /// No description provided for @peopleEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nobody yet'**
  String get peopleEmptyTitle;

  /// No description provided for @peopleEmptyFilterTitle.
  ///
  /// In en, this message translates to:
  /// **'No one matches this filter'**
  String get peopleEmptyFilterTitle;

  /// No description provided for @peopleEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Phones running دەمەتەقێ within Bluetooth range appear here automatically, along with anyone whose announcement reaches you through other phones. Nothing is sent over the internet.'**
  String get peopleEmptyBody;

  /// No description provided for @peopleEmptyFilterBody.
  ///
  /// In en, this message translates to:
  /// **'Try another filter.'**
  String get peopleEmptyFilterBody;

  /// No description provided for @peopleSeeNearby.
  ///
  /// In en, this message translates to:
  /// **'See what is nearby'**
  String get peopleSeeNearby;

  /// No description provided for @peopleDetailsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Contact details and verification'**
  String get peopleDetailsTooltip;

  /// No description provided for @peoplePickEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nobody to message yet. Phones appear here once they are in range.'**
  String get peoplePickEmpty;

  /// No description provided for @groupNoKeyYet.
  ///
  /// In en, this message translates to:
  /// **'no encryption key yet - meet them once first'**
  String get groupNoKeyYet;

  /// No description provided for @groupNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Group name'**
  String get groupNameLabel;

  /// No description provided for @groupCreateNote.
  ///
  /// In en, this message translates to:
  /// **'Messages in a group are encrypted with a key only its members have. People you choose get an invitation they can accept or decline; nothing about the group is ever broadcast.'**
  String get groupCreateNote;

  /// No description provided for @groupAddPeople.
  ///
  /// In en, this message translates to:
  /// **'Add people ({count} of {max})'**
  String groupAddPeople(int count, int max);

  /// No description provided for @groupNobodyToAdd.
  ///
  /// In en, this message translates to:
  /// **'Nobody to add yet'**
  String get groupNobodyToAdd;

  /// No description provided for @groupNobodyBody.
  ///
  /// In en, this message translates to:
  /// **'You can only invite people your phone has met. Open دەمەتەقێ near someone and they will appear here.'**
  String get groupNobodyBody;

  /// No description provided for @groupCreating.
  ///
  /// In en, this message translates to:
  /// **'Creating…'**
  String get groupCreating;

  /// No description provided for @groupCreate.
  ///
  /// In en, this message translates to:
  /// **'Create group'**
  String get groupCreate;

  /// No description provided for @videoCouldNotPlay.
  ///
  /// In en, this message translates to:
  /// **'This video could not be played on this phone.'**
  String get videoCouldNotPlay;

  /// No description provided for @commonPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get commonPause;

  /// No description provided for @commonPlay.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get commonPlay;

  /// No description provided for @secClearTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear the security log?'**
  String get secClearTitle;

  /// No description provided for @secClearBody.
  ///
  /// In en, this message translates to:
  /// **'The entries are removed from this phone. This cannot be undone.'**
  String get secClearBody;

  /// No description provided for @secClearTooltip.
  ///
  /// In en, this message translates to:
  /// **'Clear log'**
  String get secClearTooltip;

  /// No description provided for @secEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing suspicious recorded'**
  String get secEmptyTitle;

  /// No description provided for @secEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'If a message fails its signature or cannot be decrypted, a phone fails the identity check, or a contact\'s key changes, it is listed here. Occasional entries can be caused by a weak radio link and are not always an attack.'**
  String get secEmptyBody;

  /// No description provided for @secBadSignatureTitle.
  ///
  /// In en, this message translates to:
  /// **'A message had an invalid signature'**
  String get secBadSignatureTitle;

  /// No description provided for @secBadSignatureBody.
  ///
  /// In en, this message translates to:
  /// **'It was dropped. Someone may have forged or altered it, or it was corrupted in the air.'**
  String get secBadSignatureBody;

  /// No description provided for @secDecryptFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'A message could not be decrypted'**
  String get secDecryptFailedTitle;

  /// No description provided for @secDecryptFailedBody.
  ///
  /// In en, this message translates to:
  /// **'It was addressed to you but could not be opened. It was corrupted, tampered with, or encrypted for a different key.'**
  String get secDecryptFailedBody;

  /// No description provided for @secLinkAuthTitle.
  ///
  /// In en, this message translates to:
  /// **'A phone failed the identity check'**
  String get secLinkAuthTitle;

  /// No description provided for @secLinkAuthBody.
  ///
  /// In en, this message translates to:
  /// **'It connected over Bluetooth but could not prove it owns the key it claimed. The connection was closed.'**
  String get secLinkAuthBody;

  /// No description provided for @secKeyChangedTitle.
  ///
  /// In en, this message translates to:
  /// **'A contact\'s encryption key changed'**
  String get secKeyChangedTitle;

  /// No description provided for @secKeyChangedBody.
  ///
  /// In en, this message translates to:
  /// **'Their verification was removed. Compare safety numbers with them again before trusting this contact. A changed key is expected if they reinstalled the app.'**
  String get secKeyChangedBody;

  /// No description provided for @secRateLimitedTitle.
  ///
  /// In en, this message translates to:
  /// **'A phone sent too much'**
  String get secRateLimitedTitle;

  /// No description provided for @secRateLimitedBody.
  ///
  /// In en, this message translates to:
  /// **'Its traffic went over the limit and the excess was dropped.'**
  String get secRateLimitedBody;

  /// No description provided for @secMalformedTitle.
  ///
  /// In en, this message translates to:
  /// **'Unreadable data received'**
  String get secMalformedTitle;

  /// No description provided for @secMalformedBody.
  ///
  /// In en, this message translates to:
  /// **'Data that does not follow the protocol was ignored.'**
  String get secMalformedBody;

  /// No description provided for @secNotAMemberTitle.
  ///
  /// In en, this message translates to:
  /// **'Someone acted without being allowed to'**
  String get secNotAMemberTitle;

  /// No description provided for @secNotAMemberBody.
  ///
  /// In en, this message translates to:
  /// **'A group message, invitation or update came from someone who is not a member or not the admin. It was ignored.'**
  String get secNotAMemberBody;

  /// No description provided for @secUnauthorizedTitle.
  ///
  /// In en, this message translates to:
  /// **'Someone tried to change a message that is not theirs'**
  String get secUnauthorizedTitle;

  /// No description provided for @secUnauthorizedBody.
  ///
  /// In en, this message translates to:
  /// **'A request to delete or edit a message came from someone who did not write it (and is not the group\'s admin). It was ignored.'**
  String get secUnauthorizedBody;

  /// No description provided for @secBadMediaTitle.
  ///
  /// In en, this message translates to:
  /// **'A picture or voice message was damaged'**
  String get secBadMediaTitle;

  /// No description provided for @secBadMediaBody.
  ///
  /// In en, this message translates to:
  /// **'A file did not match its description (wrong size or checksum) or came with inconsistent parts, so it was discarded.'**
  String get secBadMediaBody;

  /// No description provided for @secProtocolTitle.
  ///
  /// In en, this message translates to:
  /// **'A phone broke the connection rules'**
  String get secProtocolTitle;

  /// No description provided for @secProtocolBody.
  ///
  /// In en, this message translates to:
  /// **'It sent data out of order or in an unexpected form, so the link was dropped.'**
  String get secProtocolBody;

  /// No description provided for @secUnknownBody.
  ///
  /// In en, this message translates to:
  /// **'No description is available for this entry.'**
  String get secUnknownBody;

  /// No description provided for @secUnknownPhone.
  ///
  /// In en, this message translates to:
  /// **'Unknown phone {tag}'**
  String secUnknownPhone(String tag);

  /// No description provided for @bstTitleDevice.
  ///
  /// In en, this message translates to:
  /// **'This phone'**
  String get bstTitleDevice;

  /// No description provided for @bstTitleSupport.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth Low Energy'**
  String get bstTitleSupport;

  /// No description provided for @bstTitlePermission.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth permission'**
  String get bstTitlePermission;

  /// No description provided for @bstTitlePower.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth switched on'**
  String get bstTitlePower;

  /// No description provided for @bstTitleAdvertising.
  ///
  /// In en, this message translates to:
  /// **'Visible to other phones (advertising)'**
  String get bstTitleAdvertising;

  /// No description provided for @bstTitleScanning.
  ///
  /// In en, this message translates to:
  /// **'Looking for other phones (scanning)'**
  String get bstTitleScanning;

  /// No description provided for @bstTitleDiscovery.
  ///
  /// In en, this message translates to:
  /// **'Finding another phone'**
  String get bstTitleDiscovery;

  /// No description provided for @bstTitleConnection.
  ///
  /// In en, this message translates to:
  /// **'Connecting and proving identity'**
  String get bstTitleConnection;

  /// No description provided for @bstTitleExchange.
  ///
  /// In en, this message translates to:
  /// **'Sending data both ways'**
  String get bstTitleExchange;

  /// No description provided for @bstTitleMultihop.
  ///
  /// In en, this message translates to:
  /// **'Reaching phones through a relay'**
  String get bstTitleMultihop;

  /// No description provided for @bstTitleNetwork.
  ///
  /// In en, this message translates to:
  /// **'Offline operation'**
  String get bstTitleNetwork;

  /// No description provided for @bstStopped.
  ///
  /// In en, this message translates to:
  /// **'Stopped.'**
  String get bstStopped;

  /// No description provided for @bstFixAbove.
  ///
  /// In en, this message translates to:
  /// **'Fix the problem above first.'**
  String get bstFixAbove;

  /// No description provided for @bstNoBle.
  ///
  /// In en, this message translates to:
  /// **'This phone does not offer Bluetooth Low Energy.'**
  String get bstNoBle;

  /// No description provided for @bstNoBleAdvice.
  ///
  /// In en, this message translates to:
  /// **'This phone cannot take part in the mesh.'**
  String get bstNoBleAdvice;

  /// No description provided for @bstBleAvailable.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth Low Energy is available.'**
  String get bstBleAvailable;

  /// No description provided for @bstWhereIos.
  ///
  /// In en, this message translates to:
  /// **'Settings > دەمەتەقێ > Bluetooth (turn it on).'**
  String get bstWhereIos;

  /// No description provided for @bstWhereAndroid12.
  ///
  /// In en, this message translates to:
  /// **'Settings > Apps > دەمەتەقێ > Permissions > Nearby devices > Allow.'**
  String get bstWhereAndroid12;

  /// No description provided for @bstWhereOlder.
  ///
  /// In en, this message translates to:
  /// **'Settings > Apps > دەمەتەقێ > Permissions > Location > Allow (older Android needs it for Bluetooth scanning).'**
  String get bstWhereOlder;

  /// No description provided for @bstPermDenied.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth permission has not been granted.'**
  String get bstPermDenied;

  /// No description provided for @bstPermAdvice.
  ///
  /// In en, this message translates to:
  /// **'Tap \"Allow Bluetooth\" on the Home screen, or open {where}'**
  String bstPermAdvice(String where);

  /// No description provided for @bstPermGranted.
  ///
  /// In en, this message translates to:
  /// **'Permission granted.'**
  String get bstPermGranted;

  /// No description provided for @bstOff.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth is switched off.'**
  String get bstOff;

  /// No description provided for @bstOffAdvice.
  ///
  /// In en, this message translates to:
  /// **'Switch Bluetooth on in your phone\'s quick settings, then run the test again.'**
  String get bstOffAdvice;

  /// No description provided for @bstPowerUnknown.
  ///
  /// In en, this message translates to:
  /// **'The phone has not reported its Bluetooth state yet.'**
  String get bstPowerUnknown;

  /// No description provided for @bstPowerUnknownAdvice.
  ///
  /// In en, this message translates to:
  /// **'Wait a moment and run the test again.'**
  String get bstPowerUnknownAdvice;

  /// No description provided for @bstOn.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth is on.'**
  String get bstOn;

  /// No description provided for @bstCannotAdvertise.
  ///
  /// In en, this message translates to:
  /// **'This phone cannot advertise (act as a Bluetooth peripheral).'**
  String get bstCannotAdvertise;

  /// No description provided for @bstCannotAdvertiseAdvice.
  ///
  /// In en, this message translates to:
  /// **'It can still find and connect to other phones, but others cannot find it. Two phones that both lack this ability cannot connect to each other.'**
  String get bstCannotAdvertiseAdvice;

  /// No description provided for @bstAdvertising.
  ///
  /// In en, this message translates to:
  /// **'Advertising the mesh service; other phones can see and connect to this one.'**
  String get bstAdvertising;

  /// No description provided for @bstNotAdvertising.
  ///
  /// In en, this message translates to:
  /// **'The phone is not advertising.'**
  String get bstNotAdvertising;

  /// No description provided for @bstNotAdvertisingAdvice.
  ///
  /// In en, this message translates to:
  /// **'Switch Bluetooth off and on, then run the test again. If it keeps failing this phone model may not support Bluetooth advertising.'**
  String get bstNotAdvertisingAdvice;

  /// No description provided for @bstDiscoveryStopped.
  ///
  /// In en, this message translates to:
  /// **'Discovery is stopped.'**
  String get bstDiscoveryStopped;

  /// No description provided for @bstDiscoveryStoppedAdvice.
  ///
  /// In en, this message translates to:
  /// **'Open the Nearby tab and make sure the app is started.'**
  String get bstDiscoveryStoppedAdvice;

  /// No description provided for @bstScanning.
  ///
  /// In en, this message translates to:
  /// **'Scanning in short windows ({mode} mode), {count} scan(s) started so far.'**
  String bstScanning(String mode, int count);

  /// No description provided for @bstNoScan.
  ///
  /// In en, this message translates to:
  /// **'No scan could be started.'**
  String get bstNoScan;

  /// No description provided for @bstNoScanAdvice.
  ///
  /// In en, this message translates to:
  /// **'Check the Bluetooth permission and that Bluetooth is on.'**
  String get bstNoScanAdvice;

  /// No description provided for @bstHeardCount.
  ///
  /// In en, this message translates to:
  /// **'Heard {count} دەمەتەقێ phone(s).'**
  String bstHeardCount(int count);

  /// No description provided for @bstHeardStrongest.
  ///
  /// In en, this message translates to:
  /// **'Heard {count} دەمەتەقێ phone(s), strongest signal {dbm} dBm.'**
  String bstHeardStrongest(int count, int dbm);

  /// No description provided for @bstNoneHeard.
  ///
  /// In en, this message translates to:
  /// **'No other دەمەتەقێ phone was heard in {seconds} seconds.'**
  String bstNoneHeard(int seconds);

  /// No description provided for @bstNoneHeardAdvice.
  ///
  /// In en, this message translates to:
  /// **'This is normal if nobody is nearby. Open the app on a second phone (Bluetooth on, within a few metres) and run the test again.'**
  String get bstNoneHeardAdvice;

  /// No description provided for @bstOlderAndroidLocation.
  ///
  /// In en, this message translates to:
  /// **' On Android 11 and older, scanning also needs the phone\'s Location switch (quick settings) to be on; دەمەتەقێ does not read your location, but those versions find nothing while it is off.'**
  String get bstOlderAndroidLocation;

  /// No description provided for @bstNeedsPhone.
  ///
  /// In en, this message translates to:
  /// **'Needs another phone in range.'**
  String get bstNeedsPhone;

  /// No description provided for @bstWeConnected.
  ///
  /// In en, this message translates to:
  /// **'we connected to them'**
  String get bstWeConnected;

  /// No description provided for @bstTheyConnected.
  ///
  /// In en, this message translates to:
  /// **'they connected to us'**
  String get bstTheyConnected;

  /// No description provided for @bstLinkLine.
  ///
  /// In en, this message translates to:
  /// **'{who} ({role}, {bytes} bytes per write)'**
  String bstLinkLine(String who, String role, String bytes);

  /// No description provided for @bstConnectedOk.
  ///
  /// In en, this message translates to:
  /// **'Connected and verified key ownership with: {lines}.'**
  String bstConnectedOk(String lines);

  /// No description provided for @bstNotConnected.
  ///
  /// In en, this message translates to:
  /// **'Heard other phones but could not finish connecting.'**
  String get bstNotConnected;

  /// No description provided for @bstNotConnectedWith.
  ///
  /// In en, this message translates to:
  /// **'Heard other phones but could not finish connecting: {errors}'**
  String bstNotConnectedWith(String errors);

  /// No description provided for @bstNotConnectedAdvice.
  ///
  /// In en, this message translates to:
  /// **'Move the phones closer (under 2 m), switch Bluetooth off and on on both, and close other apps that use Bluetooth heavily. Connection errors such as \"status 133\" are common on some Android phones and usually clear on retry.'**
  String get bstNotConnectedAdvice;

  /// No description provided for @bstNeedsConnected.
  ///
  /// In en, this message translates to:
  /// **'Needs a connected phone.'**
  String get bstNeedsConnected;

  /// No description provided for @bstSmall.
  ///
  /// In en, this message translates to:
  /// **'{received}/{sent} small'**
  String bstSmall(int received, int sent);

  /// No description provided for @bstLarge.
  ///
  /// In en, this message translates to:
  /// **'{received}/{sent} large (1200 B, fragmented)'**
  String bstLarge(int received, int sent);

  /// No description provided for @bstRtt.
  ///
  /// In en, this message translates to:
  /// **', round trip avg {avg} ms ({min}-{max})'**
  String bstRtt(int avg, int min, int max);

  /// No description provided for @bstExchangeLine.
  ///
  /// In en, this message translates to:
  /// **'{label}: {small}, {large}{rtt}'**
  String bstExchangeLine(String label, String small, String large, String rtt);

  /// No description provided for @bstNothingBack.
  ///
  /// In en, this message translates to:
  /// **'Nothing came back. The link was established but data does not flow; try again closer together, or toggle Bluetooth on both phones.'**
  String get bstNothingBack;

  /// No description provided for @bstSomeLost.
  ///
  /// In en, this message translates to:
  /// **'Some data was lost. Move closer together and test again.'**
  String get bstSomeLost;

  /// No description provided for @bstSlowChunk.
  ///
  /// In en, this message translates to:
  /// **'The link uses the Bluetooth minimum of 20 bytes per write, so messages will be slow. This happens when the phones fail to negotiate a larger size.'**
  String get bstSlowChunk;

  /// No description provided for @bstNoRelay.
  ///
  /// In en, this message translates to:
  /// **'No phone is currently reachable only through a relay. Testing this needs three phones: A and C each in range of B but not of each other.'**
  String get bstNoRelay;

  /// No description provided for @bstRelayLine.
  ///
  /// In en, this message translates to:
  /// **'{id} via {via} ({hops} links)'**
  String bstRelayLine(String id, String via, int hops);

  /// No description provided for @bstRelayOk.
  ///
  /// In en, this message translates to:
  /// **'Reachable through a relay, based on signed announcements: {lines}.'**
  String bstRelayOk(String lines);

  /// No description provided for @bstNetOffline.
  ///
  /// In en, this message translates to:
  /// **'{text}. Everything above ran without any internet connection.'**
  String bstNetOffline(String text);

  /// No description provided for @bstNetOnline.
  ///
  /// In en, this message translates to:
  /// **'{text}. The app does not use it; to prove offline operation, switch Wi-Fi and mobile data off (or use airplane mode with Bluetooth on) and run the test again.'**
  String bstNetOnline(String text);

  /// No description provided for @setLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get setLanguage;

  /// No description provided for @setLanguageBody.
  ///
  /// In en, this message translates to:
  /// **'The language of the whole app. Kurdish is the main one.'**
  String get setLanguageBody;

  /// No description provided for @setAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get setAppearance;

  /// No description provided for @appearanceHeading.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get appearanceHeading;

  /// No description provided for @appearanceSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get appearanceSystem;

  /// No description provided for @appearanceSystemHelp.
  ///
  /// In en, this message translates to:
  /// **'Follows your phone\'s light or dark setting.'**
  String get appearanceSystemHelp;

  /// No description provided for @appearanceLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get appearanceLight;

  /// No description provided for @appearanceLightHelp.
  ///
  /// In en, this message translates to:
  /// **'A pale page with white layers.'**
  String get appearanceLightHelp;

  /// No description provided for @appearanceDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get appearanceDark;

  /// No description provided for @appearanceDarkHelp.
  ///
  /// In en, this message translates to:
  /// **'A near-black page that is easy on the eyes at night.'**
  String get appearanceDarkHelp;

  /// No description provided for @themeSwitchToLight.
  ///
  /// In en, this message translates to:
  /// **'Switch to the light theme'**
  String get themeSwitchToLight;

  /// No description provided for @themeSwitchToDark.
  ///
  /// In en, this message translates to:
  /// **'Switch to the dark theme'**
  String get themeSwitchToDark;

  /// No description provided for @setName.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get setName;

  /// No description provided for @setNameBody.
  ///
  /// In en, this message translates to:
  /// **'Anyone nearby can see this name. It is not unique and nobody checks it: two people can pick the same one, which is why contacts show a short id too.'**
  String get setNameBody;

  /// No description provided for @setNicknameHint.
  ///
  /// In en, this message translates to:
  /// **'Nickname'**
  String get setNicknameHint;

  /// No description provided for @setChangeName.
  ///
  /// In en, this message translates to:
  /// **'Change name'**
  String get setChangeName;

  /// No description provided for @setFingerprint.
  ///
  /// In en, this message translates to:
  /// **'Your identity fingerprint'**
  String get setFingerprint;

  /// No description provided for @setFingerprintBody.
  ///
  /// In en, this message translates to:
  /// **'Your contacts compare a safety number with you to be sure it is really you.'**
  String get setFingerprintBody;

  /// No description provided for @setFingerprintCopied.
  ///
  /// In en, this message translates to:
  /// **'Fingerprint copied'**
  String get setFingerprintCopied;

  /// No description provided for @setPermissions.
  ///
  /// In en, this message translates to:
  /// **'Permissions'**
  String get setPermissions;

  /// No description provided for @setNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get setNotifications;

  /// No description provided for @setMeshBackground.
  ///
  /// In en, this message translates to:
  /// **'The mesh in the background'**
  String get setMeshBackground;

  /// No description provided for @setBluetooth.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth'**
  String get setBluetooth;

  /// No description provided for @setPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy and security'**
  String get setPrivacy;

  /// No description provided for @setHonesty.
  ///
  /// In en, this message translates to:
  /// **'How it works, and what it cannot do'**
  String get setHonesty;

  /// No description provided for @setDanger.
  ///
  /// In en, this message translates to:
  /// **'Danger zone'**
  String get setDanger;

  /// No description provided for @setSearchHow.
  ///
  /// In en, this message translates to:
  /// **'How hard to look for people'**
  String get setSearchHow;

  /// No description provided for @modeBalanced.
  ///
  /// In en, this message translates to:
  /// **'Balanced'**
  String get modeBalanced;

  /// No description provided for @modeLowPower.
  ///
  /// In en, this message translates to:
  /// **'Battery saver'**
  String get modeLowPower;

  /// No description provided for @modeAggressive.
  ///
  /// In en, this message translates to:
  /// **'Continuous'**
  String get modeAggressive;

  /// No description provided for @modeBalancedHelp.
  ///
  /// In en, this message translates to:
  /// **'Searches about half of the time'**
  String get modeBalancedHelp;

  /// No description provided for @modeLowPowerHelp.
  ///
  /// In en, this message translates to:
  /// **'Searches briefly and rarely: saves battery, finds people slowly'**
  String get modeLowPowerHelp;

  /// No description provided for @modeAggressiveHelp.
  ///
  /// In en, this message translates to:
  /// **'Searches non-stop: finds people fastest, uses the most battery'**
  String get modeAggressiveHelp;

  /// No description provided for @setSelfTest.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth self-test'**
  String get setSelfTest;

  /// No description provided for @setSelfTestBody.
  ///
  /// In en, this message translates to:
  /// **'Check that this phone can find, connect to and talk to another phone'**
  String get setSelfTestBody;

  /// No description provided for @setInternet.
  ///
  /// In en, this message translates to:
  /// **'Internet'**
  String get setInternet;

  /// No description provided for @setChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get setChecking;

  /// No description provided for @setInternetBody.
  ///
  /// In en, this message translates to:
  /// **'{state}. دەمەتەقێ never uses the internet; turn it off if you want to see it work without.'**
  String setInternetBody(String state);

  /// No description provided for @netNone.
  ///
  /// In en, this message translates to:
  /// **'No Wi-Fi or mobile data'**
  String get netNone;

  /// No description provided for @netWifi.
  ///
  /// In en, this message translates to:
  /// **'Wi-Fi is on (not used by this app)'**
  String get netWifi;

  /// No description provided for @netMobile.
  ///
  /// In en, this message translates to:
  /// **'Mobile data is on (not used by this app)'**
  String get netMobile;

  /// No description provided for @netWired.
  ///
  /// In en, this message translates to:
  /// **'Wired network (not used by this app)'**
  String get netWired;

  /// No description provided for @netOther.
  ///
  /// In en, this message translates to:
  /// **'Another network is on (not used by this app)'**
  String get netOther;

  /// No description provided for @netUnknown.
  ///
  /// In en, this message translates to:
  /// **'Network state unknown'**
  String get netUnknown;

  /// No description provided for @setStorage.
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get setStorage;

  /// No description provided for @setStorageBody.
  ///
  /// In en, this message translates to:
  /// **'What is kept on this phone, and how to free it'**
  String get setStorageBody;

  /// No description provided for @setKeepMessages.
  ///
  /// In en, this message translates to:
  /// **'Keep messages'**
  String get setKeepMessages;

  /// No description provided for @setKeepMessagesBody.
  ///
  /// In en, this message translates to:
  /// **'Older messages are deleted from this phone'**
  String get setKeepMessagesBody;

  /// No description provided for @setRetForever.
  ///
  /// In en, this message translates to:
  /// **'Forever'**
  String get setRetForever;

  /// No description provided for @setRetDay.
  ///
  /// In en, this message translates to:
  /// **'1 day'**
  String get setRetDay;

  /// No description provided for @setRetDays.
  ///
  /// In en, this message translates to:
  /// **'{days} days'**
  String setRetDays(int days);

  /// No description provided for @setSecurityLog.
  ///
  /// In en, this message translates to:
  /// **'Security log'**
  String get setSecurityLog;

  /// No description provided for @setSecurityLogBody.
  ///
  /// In en, this message translates to:
  /// **'Forged messages, failed identity checks, changed keys'**
  String get setSecurityLogBody;

  /// No description provided for @setResetAction.
  ///
  /// In en, this message translates to:
  /// **'Reset identity'**
  String get setResetAction;

  /// No description provided for @setResetTileBody.
  ///
  /// In en, this message translates to:
  /// **'Create new keys. Contacts must verify you again'**
  String get setResetTileBody;

  /// No description provided for @setResetTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset your identity?'**
  String get setResetTitle;

  /// No description provided for @setResetBody.
  ///
  /// In en, this message translates to:
  /// **'This creates a brand-new identity (new encryption and signing keys).\n\n• Your contacts will see you as a new, unverified person and must verify your new safety number.\n• Messages still travelling towards your old identity can no longer be read.\n• Messages waiting to be sent are discarded.\n• You can no longer take part in your groups (they know your old identity); your copies of those chats stay on this phone.\n• Your existing chats stay on this phone.\n\nThis cannot be undone.'**
  String get setResetBody;

  /// No description provided for @setResetDone.
  ///
  /// In en, this message translates to:
  /// **'You have a new identity'**
  String get setResetDone;

  /// No description provided for @setClearTile.
  ///
  /// In en, this message translates to:
  /// **'Delete all local data'**
  String get setClearTile;

  /// No description provided for @setClearTileBody.
  ///
  /// In en, this message translates to:
  /// **'Messages, pictures, contacts, groups and keys'**
  String get setClearTileBody;

  /// No description provided for @setClearTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete everything on this phone?'**
  String get setClearTitle;

  /// No description provided for @setClearBody.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes all messages, pictures, voice messages, contacts, groups, rooms and group keys, the security log and your settings, and creates a new identity.\n\nNobody else is told, and copies on other phones are not affected. This cannot be undone.'**
  String get setClearBody;

  /// No description provided for @setClearAction.
  ///
  /// In en, this message translates to:
  /// **'Delete everything'**
  String get setClearAction;

  /// No description provided for @confirmWordDelete.
  ///
  /// In en, this message translates to:
  /// **'delete'**
  String get confirmWordDelete;

  /// No description provided for @setClearDone.
  ///
  /// In en, this message translates to:
  /// **'All local data was deleted'**
  String get setClearDone;

  /// No description provided for @setVersionLine.
  ///
  /// In en, this message translates to:
  /// **'{name} {version} · protocol v{protocol}'**
  String setVersionLine(String name, String version, int protocol);

  /// No description provided for @setNotifyTitle.
  ///
  /// In en, this message translates to:
  /// **'Message notifications'**
  String get setNotifyTitle;

  /// No description provided for @setNotifyBody.
  ///
  /// In en, this message translates to:
  /// **'Tell me when a message arrives while the app is closed or in the background. Only for messages that are addressed to you.'**
  String get setNotifyBody;

  /// No description provided for @setNotifyShows.
  ///
  /// In en, this message translates to:
  /// **'What a notification shows'**
  String get setNotifyShows;

  /// No description provided for @setNotifyFull.
  ///
  /// In en, this message translates to:
  /// **'Name and message'**
  String get setNotifyFull;

  /// No description provided for @setNotifySender.
  ///
  /// In en, this message translates to:
  /// **'Name only'**
  String get setNotifySender;

  /// No description provided for @setNotifyHidden.
  ///
  /// In en, this message translates to:
  /// **'Nothing (just \"new message\")'**
  String get setNotifyHidden;

  /// No description provided for @setNotifyFullHelp.
  ///
  /// In en, this message translates to:
  /// **'Shows who wrote and what they wrote. Anyone who can see your lock screen can read it.'**
  String get setNotifyFullHelp;

  /// No description provided for @setNotifySenderHelp.
  ///
  /// In en, this message translates to:
  /// **'Shows who wrote, not what. \"New message\".'**
  String get setNotifySenderHelp;

  /// No description provided for @setNotifyHiddenHelp.
  ///
  /// In en, this message translates to:
  /// **'Shows only that something arrived. Neither who nor what.'**
  String get setNotifyHiddenHelp;

  /// No description provided for @setNotifyPublic.
  ///
  /// In en, this message translates to:
  /// **'Public rooms too'**
  String get setNotifyPublic;

  /// No description provided for @setNotifyPublicBody.
  ///
  /// In en, this message translates to:
  /// **'Off by default: a public room is everybody nearby talking and would never stop.'**
  String get setNotifyPublicBody;

  /// No description provided for @setRelayTitle.
  ///
  /// In en, this message translates to:
  /// **'Help relay messages for others'**
  String get setRelayTitle;

  /// No description provided for @setRelayOn.
  ///
  /// In en, this message translates to:
  /// **'Your phone passes sealed messages on between people who are out of each other\'s range. It cannot read them. This is what makes the mesh reach further.'**
  String get setRelayOn;

  /// No description provided for @setRelayOff.
  ///
  /// In en, this message translates to:
  /// **'Off: your phone receives what is for you and sends its own messages, but passes nothing on for anybody else. People who rely on you to reach each other will not get through.'**
  String get setRelayOff;

  /// No description provided for @relayActivity.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Since the app started: passed on 1 packet for others.} other{Since the app started: passed on {count} packets for others.}}'**
  String relayActivity(int count);

  /// No description provided for @relayActivityRefused.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Since the app started: passed on 1 packet for others, declined {refused} because relaying is off.} other{Since the app started: passed on {count} packets for others, declined {refused} because relaying is off.}}'**
  String relayActivityRefused(int count, int refused);

  /// No description provided for @setKeepAliveTitle.
  ///
  /// In en, this message translates to:
  /// **'Keep the mesh running in the background'**
  String get setKeepAliveTitle;

  /// No description provided for @setKeepAliveBody.
  ///
  /// In en, this message translates to:
  /// **'Shows a notification while it runs, and uses some battery. Without it Android may stop Bluetooth work soon after you lock the phone, and some phones do so even with it. This has not been tested on real phones yet.'**
  String get setKeepAliveBody;

  /// No description provided for @setKeepAliveRefused.
  ///
  /// In en, this message translates to:
  /// **'Android did not allow it right now. Try again with the app on screen.'**
  String get setKeepAliveRefused;

  /// No description provided for @setBackgroundUse.
  ///
  /// In en, this message translates to:
  /// **'Background use'**
  String get setBackgroundUse;

  /// No description provided for @setBackgroundUseBody.
  ///
  /// In en, this message translates to:
  /// **'This phone suspends the app soon after you lock it or leave it, and nothing the app can ask for changes that. Messages are exchanged while the app is open.'**
  String get setBackgroundUseBody;

  /// No description provided for @setBatteryTitle.
  ///
  /// In en, this message translates to:
  /// **'Battery restrictions'**
  String get setBatteryTitle;

  /// No description provided for @setBatteryRestricted.
  ///
  /// In en, this message translates to:
  /// **'On: to save battery, Android may stop دەمەتەقێ in the background, even with the setting above. To keep the mesh running with the screen off, open the battery settings and choose \"Unrestricted\" (the words differ from phone to phone).'**
  String get setBatteryRestricted;

  /// No description provided for @setBatteryUnrestricted.
  ///
  /// In en, this message translates to:
  /// **'Off: Android lets دەمەتەقێ run in the background without battery restrictions. Some phone makers add restrictions of their own.'**
  String get setBatteryUnrestricted;

  /// No description provided for @setBatteryOpen.
  ///
  /// In en, this message translates to:
  /// **'Open battery settings'**
  String get setBatteryOpen;

  /// No description provided for @setBatteryCouldNotOpen.
  ///
  /// In en, this message translates to:
  /// **'This phone did not open its battery settings. Look for دەمەتەقێ under Apps in the phone\'s settings.'**
  String get setBatteryCouldNotOpen;

  /// No description provided for @setPermBluetooth.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth (nearby devices)'**
  String get setPermBluetooth;

  /// No description provided for @setPermBluetoothWhy.
  ///
  /// In en, this message translates to:
  /// **'To find and talk to phones near you. Never your location.'**
  String get setPermBluetoothWhy;

  /// No description provided for @setAllowed.
  ///
  /// In en, this message translates to:
  /// **'Allowed'**
  String get setAllowed;

  /// No description provided for @commonAllow.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get commonAllow;

  /// No description provided for @setPermMic.
  ///
  /// In en, this message translates to:
  /// **'Microphone'**
  String get setPermMic;

  /// No description provided for @setPermMicShort.
  ///
  /// In en, this message translates to:
  /// **'Only while you record a voice message'**
  String get setPermMicShort;

  /// No description provided for @setPermCamera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get setPermCamera;

  /// No description provided for @setPermCameraShort.
  ///
  /// In en, this message translates to:
  /// **'Only to take a picture you want to send'**
  String get setPermCameraShort;

  /// No description provided for @setPermPhotos.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get setPermPhotos;

  /// No description provided for @setPermPhotosShort.
  ///
  /// In en, this message translates to:
  /// **'Only to pick a picture you want to send'**
  String get setPermPhotosShort;

  /// No description provided for @setPermNotifShort.
  ///
  /// In en, this message translates to:
  /// **'Only to tell you a message arrived while the app is not on screen'**
  String get setPermNotifShort;

  /// No description provided for @honestyNoInternetTitle.
  ///
  /// In en, this message translates to:
  /// **'No internet, no accounts, no servers'**
  String get honestyNoInternetTitle;

  /// No description provided for @honestyNoInternetBody.
  ///
  /// In en, this message translates to:
  /// **'Messages travel from phone to phone over Bluetooth Low Energy. Nothing is sent to the internet or to any company, and there is nothing to sign up for.'**
  String get honestyNoInternetBody;

  /// No description provided for @honestyRangeTitle.
  ///
  /// In en, this message translates to:
  /// **'Range, relaying and waiting'**
  String get honestyRangeTitle;

  /// No description provided for @honestyRangeBody.
  ///
  /// In en, this message translates to:
  /// **'One Bluetooth link reaches roughly 10 to 30 metres, less through walls. If phones with the app are in between, a message can hop through them: up to {direct} hops for private messages and {group} for groups and public rooms. If nobody is in reach, a private message or a group message is kept and retried for up to {directHours} hours (public rooms: {roomHours} hours), then it is marked as not delivered. Phones that pass group and public traffic along also keep it for people who arrive later. Relaying has been tested with simulated radios only; it has not yet been proven on real phones, so use the Bluetooth self-test and your own phones to see how it behaves in practice.'**
  String honestyRangeBody(
    int direct,
    int group,
    int directHours,
    int roomHours,
  );

  /// No description provided for @honestyMediaTitle.
  ///
  /// In en, this message translates to:
  /// **'Pictures, voice messages and videos'**
  String get honestyMediaTitle;

  /// No description provided for @honestyMediaBody.
  ///
  /// In en, this message translates to:
  /// **'Pictures are shrunk to a few dozen kilobytes (about 640 pixels wide), voice messages are limited to {seconds} seconds, and videos are not shrunk at all: only a very short clip fits (you choose the limit under Settings > Storage). Bluetooth is slow: each hop takes a few seconds, more with several hops or a weak signal. Every file is checked against its SHA-256 before it is shown. In a group a picture or a video can stay incomplete if a piece of it is lost on every path; it then shows as not received. Videos cannot be sent to public rooms. Pictures, recordings and videos are kept in the app\'s private storage, not in your gallery, unless you choose \"Save to gallery\".'**
  String honestyMediaBody(int seconds);

  /// No description provided for @honestyBackgroundTitle.
  ///
  /// In en, this message translates to:
  /// **'The background is not guaranteed'**
  String get honestyBackgroundTitle;

  /// No description provided for @honestyBackgroundBody.
  ///
  /// In en, this message translates to:
  /// **'دەمەتەقێ works best while it is open. Phones restrict what apps may do with Bluetooth in the background, and this app does not try to get around that. On Android you can switch on \"Keep the mesh running in the background\": it shows a notification while it runs and lets the app stay alive more often, but it is no guarantee, and it has not been tested on real phones yet. Phones that are locked or have the app closed may relay nothing.'**
  String get honestyBackgroundBody;

  /// No description provided for @honestyPrivateTitle.
  ///
  /// In en, this message translates to:
  /// **'Private chats'**
  String get honestyPrivateTitle;

  /// No description provided for @honestyPrivateBody.
  ///
  /// In en, this message translates to:
  /// **'Private messages, pictures and voice messages are end-to-end encrypted: only the person you send to can read them, even when other phones pass them along. Phones that pass something along can see who sent it and who it is for (their public keys), roughly when, and its approximate size, but not the content. Anyone nearby can see that a phone is advertising دەمەتەقێ, and the name you chose.'**
  String get honestyPrivateBody;

  /// No description provided for @honestyGroupsTitle.
  ///
  /// In en, this message translates to:
  /// **'Groups'**
  String get honestyGroupsTitle;

  /// No description provided for @honestyGroupsBody.
  ///
  /// In en, this message translates to:
  /// **'A group is private: its messages are encrypted with a key that only its members have, and nothing about it (its name, its members, that it exists) is ever broadcast. Only the person who created it can add or remove people, and every change gives the group a new key, so someone who was removed cannot read what is sent afterwards. They keep what they already received. If a key change reaches a member later than the messages sent right after it, those messages may be missed.'**
  String get honestyGroupsBody;

  /// No description provided for @honestyRoomsTitle.
  ///
  /// In en, this message translates to:
  /// **'Public rooms'**
  String get honestyRoomsTitle;

  /// No description provided for @honestyRoomsBody.
  ///
  /// In en, this message translates to:
  /// **'A public room is NOT private. Everything said in it - text, pictures and voice - can be read by every phone that carries it, and by anyone who joins. Messages are signed, so a relay cannot change a word or forge an author, but names can be chosen freely: the short id after a name is what tells two people with the same name apart. The built-in #mesh room is for everyone nearby; rooms people create are announced to nearby phones and disappear after a day unless their creator\'s phone keeps renewing them. Messages in public rooms are removed from this phone six hours after they arrive.'**
  String get honestyRoomsBody;

  /// No description provided for @honestyDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Deleting and editing'**
  String get honestyDeleteTitle;

  /// No description provided for @honestyDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'Delete for me removes a message from this phone only. Delete for everyone sends a request to the other phones: it works only if they receive it in time, and it cannot reach a copy somebody saved or photographed. Editing sends the new text in the same way. Both are possible for two days after a message is sent.'**
  String get honestyDeleteBody;

  /// No description provided for @honestyVerifyTitle.
  ///
  /// In en, this message translates to:
  /// **'Who are you really talking to?'**
  String get honestyVerifyTitle;

  /// No description provided for @honestyVerifyBody.
  ///
  /// In en, this message translates to:
  /// **'The first time two phones meet, there is no way to know a key is really that person\'s. Open their contact page, compare the safety number with them in person or on a call you trust, and only then mark them verified. Until then, treat names as unverified.'**
  String get honestyVerifyBody;

  /// No description provided for @honestyStoredTitle.
  ///
  /// In en, this message translates to:
  /// **'What is stored on this phone'**
  String get honestyStoredTitle;

  /// No description provided for @honestyStoredBody.
  ///
  /// In en, this message translates to:
  /// **'Your keys (and the keys of your groups) are kept in the phone\'s secure storage (Android Keystore / iOS Keychain). Chat history, pictures and recordings are stored in the app\'s private storage without an extra layer of encryption beyond your phone\'s own lock screen and disk encryption, and on an iPhone they may be included in device backups. Anyone who unlocks your phone can read your chats.'**
  String get honestyStoredBody;

  /// No description provided for @honestyAuditTitle.
  ///
  /// In en, this message translates to:
  /// **'Not independently audited'**
  String get honestyAuditTitle;

  /// No description provided for @honestyAuditBody.
  ///
  /// In en, this message translates to:
  /// **'The encryption uses standard algorithms (HPKE with X25519 and ChaCha20-Poly1305, Ed25519 signatures), and the core encryption is tested against the published test vectors. But this app\'s code has not been reviewed by an independent security expert. Do not rely on it where your safety or freedom depends on it.'**
  String get honestyAuditBody;

  /// No description provided for @reachDirectLong.
  ///
  /// In en, this message translates to:
  /// **'Directly connected'**
  String get reachDirectLong;

  /// No description provided for @reachRelayLong.
  ///
  /// In en, this message translates to:
  /// **'{hops, plural, =1{Via relay (1 hop)} other{Via relay ({hops} hops)}}'**
  String reachRelayLong(int hops);

  /// No description provided for @reachOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get reachOffline;

  /// No description provided for @reachDirectShort.
  ///
  /// In en, this message translates to:
  /// **'Direct'**
  String get reachDirectShort;

  /// No description provided for @reachRelayShort.
  ///
  /// In en, this message translates to:
  /// **'{hops, plural, =1{Relay · 1 hop} other{Relay · {hops} hops}}'**
  String reachRelayShort(int hops);

  /// No description provided for @deliveryPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get deliveryPending;

  /// No description provided for @deliverySentCount.
  ///
  /// In en, this message translates to:
  /// **'Sent · {done}/{total}'**
  String deliverySentCount(int done, int total);

  /// No description provided for @deliverySent.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get deliverySent;

  /// No description provided for @deliveryDelivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get deliveryDelivered;

  /// No description provided for @deliveryDeliveredVia.
  ///
  /// In en, this message translates to:
  /// **'{hops, plural, =1{Delivered · 1 hop} other{Delivered · {hops} hops}}'**
  String deliveryDeliveredVia(int hops);

  /// No description provided for @deliveryFailed.
  ///
  /// In en, this message translates to:
  /// **'Not delivered'**
  String get deliveryFailed;

  /// No description provided for @deliveryUndecryptable.
  ///
  /// In en, this message translates to:
  /// **'Could not decrypt or verify'**
  String get deliveryUndecryptable;

  /// No description provided for @connError.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth error'**
  String get connError;

  /// No description provided for @connStarting.
  ///
  /// In en, this message translates to:
  /// **'Starting…'**
  String get connStarting;

  /// No description provided for @connNotStarted.
  ///
  /// In en, this message translates to:
  /// **'Not started'**
  String get connNotStarted;

  /// No description provided for @connNotSupported.
  ///
  /// In en, this message translates to:
  /// **'Not supported'**
  String get connNotSupported;

  /// No description provided for @connPermissionNeeded.
  ///
  /// In en, this message translates to:
  /// **'Permission needed'**
  String get connPermissionNeeded;

  /// No description provided for @connBluetoothOff.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth off'**
  String get connBluetoothOff;

  /// No description provided for @connNearbyRelayed.
  ///
  /// In en, this message translates to:
  /// **'{direct} nearby · {relayed} via relay'**
  String connNearbyRelayed(int direct, int relayed);

  /// No description provided for @connNearby.
  ///
  /// In en, this message translates to:
  /// **'{direct} nearby'**
  String connNearby(int direct);

  /// No description provided for @connViaRelay.
  ///
  /// In en, this message translates to:
  /// **'{relayed} via relay'**
  String connViaRelay(int relayed);

  /// No description provided for @connSearching.
  ///
  /// In en, this message translates to:
  /// **'Searching…'**
  String get connSearching;

  /// No description provided for @offlineTipNone.
  ///
  /// In en, this message translates to:
  /// **'There is no internet connection. دەمەتەقێ does not need one: messages travel by Bluetooth.'**
  String get offlineTipNone;

  /// No description provided for @offlineTipOn.
  ///
  /// In en, this message translates to:
  /// **'The phone has internet, but دەمەتەقێ does not use it: messages travel by Bluetooth.'**
  String get offlineTipOn;

  /// No description provided for @offlineBadge.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get offlineBadge;

  /// No description provided for @internetOnBadge.
  ///
  /// In en, this message translates to:
  /// **'Internet on'**
  String get internetOnBadge;

  /// No description provided for @navUnreadLabel.
  ///
  /// In en, this message translates to:
  /// **'{label}, {count} unread'**
  String navUnreadLabel(String label, int count);

  /// No description provided for @peerSeenAgo.
  ///
  /// In en, this message translates to:
  /// **'seen {ago}'**
  String peerSeenAgo(String ago);

  /// No description provided for @peerNoKeyYet.
  ///
  /// In en, this message translates to:
  /// **'no encryption key yet'**
  String get peerNoKeyYet;

  /// No description provided for @commonStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get commonStart;

  /// No description provided for @commonOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get commonOpenSettings;

  /// No description provided for @commonDismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get commonDismiss;

  /// No description provided for @radioCouldNotStart.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth could not start'**
  String get radioCouldNotStart;

  /// No description provided for @radioNotStarted.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth is not started'**
  String get radioNotStarted;

  /// No description provided for @radioNotStartedBody.
  ///
  /// In en, this message translates to:
  /// **'دەمەتەقێ needs Bluetooth to find and talk to nearby phones.'**
  String get radioNotStartedBody;

  /// No description provided for @radioNotVisible.
  ///
  /// In en, this message translates to:
  /// **'This phone can\'t be found by others'**
  String get radioNotVisible;

  /// No description provided for @radioNotVisibleBody.
  ///
  /// In en, this message translates to:
  /// **'It can find and connect to other phones, but it cannot advertise itself over Bluetooth. Two phones that both lack this cannot connect to each other.'**
  String get radioNotVisibleBody;

  /// No description provided for @radioNoBle.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth Low Energy is not available'**
  String get radioNoBle;

  /// No description provided for @radioNoBleBody.
  ///
  /// In en, this message translates to:
  /// **'This device does not support the Bluetooth feature دەمەتەقێ is built on, so it cannot take part in the mesh.'**
  String get radioNoBleBody;

  /// No description provided for @radioPermission.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth permission needed'**
  String get radioPermission;

  /// No description provided for @radioPermissionBody.
  ///
  /// In en, this message translates to:
  /// **'دەمەتەقێ needs permission to use Bluetooth (the \"Nearby devices\" permission on recent Android, Bluetooth on iPhone) to find and talk to nearby phones. It never uses your location.'**
  String get radioPermissionBody;

  /// No description provided for @radioAllow.
  ///
  /// In en, this message translates to:
  /// **'Allow Bluetooth'**
  String get radioAllow;

  /// No description provided for @radioOff.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth is turned off'**
  String get radioOff;

  /// No description provided for @radioOffBody.
  ///
  /// In en, this message translates to:
  /// **'Switch Bluetooth on in your phone\'s quick settings. دەمەتەقێ will reconnect to nearby phones by itself.'**
  String get radioOffBody;

  /// No description provided for @radioProblem.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth problem'**
  String get radioProblem;

  /// No description provided for @identityResetTitle.
  ///
  /// In en, this message translates to:
  /// **'Your identity was reset'**
  String get identityResetTitle;

  /// No description provided for @identityResetBody.
  ///
  /// In en, this message translates to:
  /// **'Your encryption keys could not be read from this phone\'s secure storage, so a new identity was created. Your contacts will need to verify you again, and messages sent to your old identity can no longer be read.'**
  String get identityResetBody;

  /// No description provided for @versionNewerTitle.
  ///
  /// In en, this message translates to:
  /// **'A newer دەمەتەقێ is nearby'**
  String get versionNewerTitle;

  /// No description provided for @versionNewerBody.
  ///
  /// In en, this message translates to:
  /// **'A phone near you runs a newer version of دەمەتەقێ. The two phones cannot talk to each other until this one is updated too.'**
  String get versionNewerBody;

  /// No description provided for @versionOlderTitle.
  ///
  /// In en, this message translates to:
  /// **'A phone nearby needs an update'**
  String get versionOlderTitle;

  /// No description provided for @versionOlderBody.
  ///
  /// In en, this message translates to:
  /// **'A phone near you runs an older version of دەمەتەقێ. The two phones cannot talk to each other until that one is updated too.'**
  String get versionOlderBody;

  /// No description provided for @permMicTitle.
  ///
  /// In en, this message translates to:
  /// **'Allow the microphone?'**
  String get permMicTitle;

  /// No description provided for @permMicWhy.
  ///
  /// In en, this message translates to:
  /// **'دەمەتەقێ needs the microphone only while you are recording a voice message.'**
  String get permMicWhy;

  /// No description provided for @permMicPrivacy.
  ///
  /// In en, this message translates to:
  /// **'The recording goes over Bluetooth to the people in that chat and is never uploaded anywhere. Nothing is recorded when you are not holding a recording open.'**
  String get permMicPrivacy;

  /// No description provided for @permMicThing.
  ///
  /// In en, this message translates to:
  /// **'the microphone'**
  String get permMicThing;

  /// No description provided for @permMicOff.
  ///
  /// In en, this message translates to:
  /// **'The microphone is switched off'**
  String get permMicOff;

  /// No description provided for @permCameraTitle.
  ///
  /// In en, this message translates to:
  /// **'Allow the camera?'**
  String get permCameraTitle;

  /// No description provided for @permCameraWhy.
  ///
  /// In en, this message translates to:
  /// **'دەمەتەقێ needs the camera to take a picture you want to send.'**
  String get permCameraWhy;

  /// No description provided for @permCameraPrivacy.
  ///
  /// In en, this message translates to:
  /// **'The picture is shrunk and sent over Bluetooth to the people in that chat. It is not saved to your gallery and never uploaded anywhere.'**
  String get permCameraPrivacy;

  /// No description provided for @permCameraThing.
  ///
  /// In en, this message translates to:
  /// **'the camera'**
  String get permCameraThing;

  /// No description provided for @permCameraOff.
  ///
  /// In en, this message translates to:
  /// **'The camera is switched off'**
  String get permCameraOff;

  /// No description provided for @permPhotosTitle.
  ///
  /// In en, this message translates to:
  /// **'Allow access to your photos?'**
  String get permPhotosTitle;

  /// No description provided for @permPhotosWhy.
  ///
  /// In en, this message translates to:
  /// **'دەمەتەقێ needs to open your photo library so you can pick a picture to send.'**
  String get permPhotosWhy;

  /// No description provided for @permPhotosPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Only the picture you choose is used. It is shrunk and sent over Bluetooth to the people in that chat, and never uploaded anywhere.'**
  String get permPhotosPrivacy;

  /// No description provided for @permPhotosThing.
  ///
  /// In en, this message translates to:
  /// **'your photos'**
  String get permPhotosThing;

  /// No description provided for @permPhotosOff.
  ///
  /// In en, this message translates to:
  /// **'Access to your photos is switched off'**
  String get permPhotosOff;

  /// No description provided for @permNotifTitle.
  ///
  /// In en, this message translates to:
  /// **'Allow notifications?'**
  String get permNotifTitle;

  /// No description provided for @permNotifWhy.
  ///
  /// In en, this message translates to:
  /// **'دەمەتەقێ uses notifications to tell you when a message arrives while the app is closed or in the background.'**
  String get permNotifWhy;

  /// No description provided for @permNotifPrivacy.
  ///
  /// In en, this message translates to:
  /// **'You choose how much a notification shows: the name and the message, only the name, or nothing but \"new message\". Notifications are made on this phone from messages that reached it; nothing is sent to any server.'**
  String get permNotifPrivacy;

  /// No description provided for @permNotifThing.
  ///
  /// In en, this message translates to:
  /// **'notifications'**
  String get permNotifThing;

  /// No description provided for @permNotifOff.
  ///
  /// In en, this message translates to:
  /// **'Notifications are switched off'**
  String get permNotifOff;

  /// No description provided for @permNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Not available'**
  String get permNotAvailable;

  /// No description provided for @permUnavailableBody.
  ///
  /// In en, this message translates to:
  /// **'This phone does not allow دەمەتەقێ to use {thing} (it may be restricted by a parent or an administrator).'**
  String permUnavailableBody(String thing);

  /// No description provided for @permNotNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get permNotNow;

  /// No description provided for @permTurnOnInSettings.
  ///
  /// In en, this message translates to:
  /// **'To use it, turn it on for دەمەتەقێ in your phone\'s settings. Nothing else in the app needs it.'**
  String get permTurnOnInSettings;

  /// No description provided for @voicePause.
  ///
  /// In en, this message translates to:
  /// **'Pause voice message'**
  String get voicePause;

  /// No description provided for @voicePlay.
  ///
  /// In en, this message translates to:
  /// **'Play voice message'**
  String get voicePlay;

  /// No description provided for @mediaNotReceived.
  ///
  /// In en, this message translates to:
  /// **'Could not be received'**
  String get mediaNotReceived;

  /// No description provided for @mediaReceiving.
  ///
  /// In en, this message translates to:
  /// **'Receiving… {percent}%'**
  String mediaReceiving(int percent);

  /// No description provided for @pictureNotReceived.
  ///
  /// In en, this message translates to:
  /// **'Picture could not be received'**
  String get pictureNotReceived;

  /// No description provided for @videoCannotPlay.
  ///
  /// In en, this message translates to:
  /// **'This video cannot be played on this phone.'**
  String get videoCannotPlay;

  /// No description provided for @videoNotReceived.
  ///
  /// In en, this message translates to:
  /// **'Video could not be received'**
  String get videoNotReceived;

  /// No description provided for @videoReceiving.
  ///
  /// In en, this message translates to:
  /// **'Receiving video… {percent}%'**
  String videoReceiving(int percent);

  /// No description provided for @videoPlay.
  ///
  /// In en, this message translates to:
  /// **'Play video'**
  String get videoPlay;

  /// The heading of an empty private chat, under the little ghost.
  ///
  /// In en, this message translates to:
  /// **'Say hello to {name}'**
  String introDirectTitle(String name);

  /// The heading of a group that has no messages yet.
  ///
  /// In en, this message translates to:
  /// **'Welcome to {name}'**
  String introGroupTitle(String name);

  /// Under a public room in the forward list when a video is selected.
  ///
  /// In en, this message translates to:
  /// **'A video cannot go to a public room'**
  String get fwdNoVideoInRooms;

  /// No description provided for @setNotifyNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'Notifications are on here, but the phone has not allowed them yet, so none will appear.'**
  String get setNotifyNotAllowed;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'ckb', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'ckb':
      return AppLocalizationsCkb();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
