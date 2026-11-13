// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String authorUnknown(String tag) {
    return 'Unknown $tag';
  }

  @override
  String get actEditingGone => 'The message you were editing is gone.';

  @override
  String get actReplyingGone => 'The message you were replying to was deleted.';

  @override
  String get actNoTextToCopy => 'There is no text to copy.';

  @override
  String get actCopied => 'Copied';

  @override
  String actCopiedMany(int count) {
    return 'Copied $count messages';
  }

  @override
  String get actSaveTitle => 'Save to your gallery?';

  @override
  String get actSaveBodyPicture =>
      'دەمەتەقێ keeps this picture in its own private storage. Saving puts a copy in your phone\'s gallery, where other apps can see it and where it stays even if you delete the message here. Your phone may ask for permission to save files.';

  @override
  String get actSaveBodyVideo =>
      'دەمەتەقێ keeps this video in its own private storage. Saving puts a copy in your phone\'s gallery, where other apps can see it and where it stays even if you delete the message here. Your phone may ask for permission to save files.';

  @override
  String actSaveBodyFiles(int count) {
    return 'دەمەتەقێ keeps these $count files in its own private storage. Saving puts a copy in your phone\'s gallery, where other apps can see it and where it stays even if you delete the message here. Your phone may ask for permission to save files.';
  }

  @override
  String get actSaved => 'Saved to your gallery';

  @override
  String actSavedMany(int count) {
    return 'Saved $count files to your gallery';
  }

  @override
  String actSavedSome(int saved, int total, String reason) {
    return 'Saved $saved of $total. $reason';
  }

  @override
  String get actPinnedNote => 'Pinned. Only you see this pin.';

  @override
  String get actUnpinnedNote => 'Unpinned';

  @override
  String get actForwardPublicTitle => 'Forward to a public room?';

  @override
  String get actForwardPublicBody =>
      'Everyone nearby can read what you forward there, it is not private any more, and it shows the name of the person who wrote it. It disappears from phones after six hours.';

  @override
  String get actForwardPublicAction => 'Forward publicly';

  @override
  String get actTheChat => 'the chat';

  @override
  String actForwardedTo(String title) {
    return 'Forwarded to $title';
  }

  @override
  String actForwardedMany(int count, String title) {
    return 'Forwarded $count messages to $title';
  }

  @override
  String actForwardedSome(int sent, int total, String title) {
    return 'Forwarded $sent of $total to $title. The others could not be read, or their file is not complete.';
  }

  @override
  String actNothingDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Nothing was deleted: those messages are already gone.',
      one: 'Nothing was deleted: that message is already gone.',
    );
    return '$_temp0';
  }

  @override
  String actDeletedUnsent(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Deleted. They had not been sent yet, so nobody receives them.',
      one: 'Deleted. It had not been sent yet, so nobody receives it.',
    );
    return '$_temp0';
  }

  @override
  String actDeletedManyHere(int count) {
    return '$count messages deleted from this phone.';
  }

  @override
  String get actDeletedHere => 'Deleted from this phone.';

  @override
  String actDeletedAskedOthers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Deleted here. Other phones remove them when they receive the request.',
      one:
          'Deleted here. Other phones remove it when they receive the request.',
    );
    return '$_temp0';
  }

  @override
  String actDeletedNeverSent(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Deleted. Nothing had been sent yet, so nobody else ever receives them.',
      one: 'Deleted. Nothing had been sent yet, so nobody else ever receives it.',
    );
    return '$_temp0';
  }

  @override
  String actUnpinnedCount(int count) {
    return 'Unpinned $count';
  }

  @override
  String actPinnedCount(int count) {
    return 'Pinned $count. Only you see these pins.';
  }

  @override
  String get actSelectAll => 'Select all';

  @override
  String get actFurtherBack =>
      'That message is further back than this chat shows.';

  @override
  String pinnedListTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pinned messages',
      one: '1 pinned message',
    );
    return '$_temp0';
  }

  @override
  String get pinnedListNote => 'Pins are yours alone: nobody else sees them.';

  @override
  String get pinnedListEmpty => 'Nothing is pinned.';

  @override
  String get startupErrorTitle => 'دەمەتەقێ could not start';

  @override
  String get startupErrorBody =>
      'The app could not open its private storage or load your keys. Nothing has been deleted, and your identity is never replaced just because it could not be read. Try again; if it keeps failing, restart the phone. As a last resort, uninstalling and reinstalling the app clears the damaged storage, but it also deletes your chats and your identity.';

  @override
  String get commonTryAgain => 'Try again';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonOk => 'OK';

  @override
  String get commonClose => 'Close';

  @override
  String get commonDone => 'Done';

  @override
  String get commonSave => 'Save';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonRemove => 'Remove';

  @override
  String get commonBack => 'Back';

  @override
  String get commonSearch => 'Search';

  @override
  String get commonSend => 'Send';

  @override
  String get commonCopy => 'Copy';

  @override
  String get commonShare => 'Share';

  @override
  String get commonMore => 'More';

  @override
  String get commonYes => 'Yes';

  @override
  String get commonNo => 'No';

  @override
  String get commonOn => 'On';

  @override
  String get commonOff => 'Off';

  @override
  String get commonYou => 'You';

  @override
  String get commonLoading => 'Loading…';

  @override
  String get actReply => 'Reply';

  @override
  String get actCopyCaption => 'Copy caption';

  @override
  String get actCopyText => 'Copy text';

  @override
  String get actForward => 'Forward';

  @override
  String get actSaveToGallery => 'Save to gallery';

  @override
  String get actSendAgain => 'Send again';

  @override
  String get actUnpin => 'Unpin';

  @override
  String get actPin => 'Pin';

  @override
  String get actEdit => 'Edit';

  @override
  String get actSelect => 'Select';

  @override
  String get actDetails => 'Details';

  @override
  String deleteTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Delete $count messages?',
      one: 'Delete message?',
    );
    return '$_temp0';
  }

  @override
  String deleteForMeNote(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Delete for me removes them from this phone only. Everyone else keeps their copy.',
      one: 'Delete for me removes it from this phone only. Everyone else keeps their copy.',
    );
    return '$_temp0';
  }

  @override
  String deleteEveryoneDirect(int count, String who) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Delete for everyone also asks $who\'s phone to remove them. It is a request: it takes effect when their phone receives it (they must come into range within about 12 hours). A copy somebody saved or photographed cannot be reached.',
      one:
          'Delete for everyone also asks $who\'s phone to remove it. It is a request: it takes effect when their phone receives it (they must come into range within about 12 hours). A copy somebody saved or photographed cannot be reached.',
    );
    return '$_temp0';
  }

  @override
  String deleteEveryoneGroup(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Delete for everyone also asks every member\'s phone to remove them. It is a request: it takes effect on each phone when it receives it, and a phone that is out of range gets it later, if it comes back in time. A copy somebody saved or photographed cannot be reached.',
      one: 'Delete for everyone also asks every member\'s phone to remove it. It is a request: it takes effect on each phone when it receives it, and a phone that is out of range gets it later, if it comes back in time. A copy somebody saved or photographed cannot be reached.',
    );
    return '$_temp0';
  }

  @override
  String deleteEveryoneRoom(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'them to remove them',
      one: 'it to remove it',
    );
    return 'Delete for everyone also asks every phone nearby that has $_temp0. It is a request: it takes effect on each phone when it receives it, and a phone that is out of range gets it later, if it comes back in time. A copy somebody saved or photographed cannot be reached.';
  }

  @override
  String get deleteEveryoneOwnOnly =>
      'Delete for everyone is only possible for your own messages.';

  @override
  String get deleteEveryoneOwnOrAdmin =>
      'Delete for everyone is only possible for your own messages (and for the group\'s admin).';

  @override
  String get deleteForMe => 'Delete for me';

  @override
  String get deleteForEveryone => 'Delete for everyone';

  @override
  String get selCancel => 'Cancel selection';

  @override
  String selCount(int count) {
    return '$count selected';
  }

  @override
  String get quoteOriginalDeleted => 'Original message deleted';

  @override
  String forwardedFrom(String name) {
    return 'Forwarded from $name';
  }

  @override
  String pinnedOf(int index, int count) {
    return 'Pinned message $index of $count';
  }

  @override
  String get pinnedMessage => 'Pinned message';

  @override
  String get pinnedAll => 'All pinned messages';

  @override
  String delWaiting(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Waiting for $name\'s phone to confirm $count deleted messages. It happens as soon as you are in range.',
      one:
          'Waiting for $name\'s phone to confirm a deleted message. It happens as soon as you are in range.',
    );
    return '$_temp0';
  }

  @override
  String delExpired(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$name\'s phone did not get $count delete requests in time, so those messages may still be there.',
      one:
          '$name\'s phone did not get a delete request in time, so that message may still be there.',
    );
    return '$_temp0';
  }

  @override
  String get snippetUnreadable => 'Message could not be read';

  @override
  String replyingTo(String name) {
    return 'Replying to $name';
  }

  @override
  String get editMessageTitle => 'Edit message';

  @override
  String get cancelEditing => 'Cancel editing';

  @override
  String get cancelReply => 'Cancel reply';

  @override
  String get bubbleUndecryptable =>
      'This message could not be decrypted or verified, so it was not shown. It may have been corrupted, tampered with, or encrypted for a different key.';

  @override
  String get bubblePicture => 'Picture';

  @override
  String get bubbleVideo => 'Video';

  @override
  String get bubbleVoice => 'Voice message';

  @override
  String get bubbleEdited => 'edited';

  @override
  String bubbleViaRelays(int hops) {
    String _temp0 = intl.Intl.pluralLogic(
      hops,
      locale: localeName,
      other: 'via $hops relays',
      one: 'via 1 relay',
    );
    return '$_temp0';
  }

  @override
  String get bubbleNotDelivered => 'This message could not be delivered.';

  @override
  String composerCouldNotSend(String error) {
    return 'Could not send: $error';
  }

  @override
  String get attachSendPicture => 'Send a picture';

  @override
  String get attachTakePhoto => 'Take a photo';

  @override
  String get attachChoosePhoto => 'Choose from your photos';

  @override
  String get attachPictureNote =>
      'Pictures are shrunk to a few dozen kilobytes so they can cross Bluetooth, and are sent only to the people in this chat.';

  @override
  String get attachSendVideo => 'Send a video';

  @override
  String get attachRecordVideo => 'Record a short video';

  @override
  String get attachChooseVideo => 'Choose a video';

  @override
  String attachVideoNote(String limit) {
    return 'Videos are not shrunk: only a very short, low-quality clip (up to $limit) can cross Bluetooth, and it can take minutes. Bigger ones are refused. You can change the limit under Settings > Storage.';
  }

  @override
  String get composerAllowPicture => 'Allow access to send a picture.';

  @override
  String composerOpenCameraFailed(String error) {
    return 'Could not open the camera: $error';
  }

  @override
  String composerOpenPhotosFailed(String error) {
    return 'Could not open the photos: $error';
  }

  @override
  String composerOpenVideosFailed(String error) {
    return 'Could not open the videos: $error';
  }

  @override
  String composerPictureNotPrepared(String error) {
    return 'That picture could not be prepared: $error';
  }

  @override
  String get composerAllowVideo => 'Allow access to send a video.';

  @override
  String composerVideoTooBig(String size, String limit, String max) {
    return 'That video is $size. Over Bluetooth a video can be at most $limit (you can raise this under Settings > Storage, up to $max). Choose a shorter or smaller clip.';
  }

  @override
  String get composerAllowMic =>
      'Allow the microphone to record a voice message.';

  @override
  String composerRecordFailed(String error) {
    return 'Could not start recording: $error';
  }

  @override
  String get composerVoiceTooShort =>
      'That was too short for a voice message. Keep the microphone open a little longer.';

  @override
  String composerBytesCounter(int bytes, int max) {
    return '$bytes / $max bytes';
  }

  @override
  String get composerTooLong => 'Too long';

  @override
  String get composerSaveChanges => 'Save changes';

  @override
  String get composerRecord => 'Record a voice message';

  @override
  String get composerDiscard => 'Discard the recording';

  @override
  String get composerSendVoice => 'Send the voice message';

  @override
  String get previewSendPicture => 'Send this picture?';

  @override
  String get previewSendVideo => 'Send this video?';

  @override
  String get previewCaptionHint => 'Add a caption (optional)';

  @override
  String get previewVideoNote =>
      'It goes over Bluetooth, only to the people in this chat, and it can take several minutes - longer when it has to pass through other phones. The person has to stay in range, with the app open, until it arrives.';

  @override
  String get chatFallbackLower => 'chat';

  @override
  String get chatSearchTooltip => 'Search this chat';

  @override
  String get chatFallbackGroup => 'Group';

  @override
  String get chatFallbackChat => 'Chat';

  @override
  String chatGroupMembers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members',
      one: '1 member',
    );
    return '$_temp0';
  }

  @override
  String chatGroupMembersNearby(int count, int nearby) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members · $nearby nearby',
      one: '1 member · $nearby nearby',
    );
    return '$_temp0';
  }

  @override
  String get chatInvitation => 'Invitation';

  @override
  String get chatGroupDetails => 'Group details';

  @override
  String get chatVerifiedContact => 'Verified contact';

  @override
  String get chatVerifyContact => 'Verify this contact';

  @override
  String get chatTheOtherPerson => 'the other person';

  @override
  String get composerHint => 'Message';

  @override
  String get chatRemovedFromGroup => 'You were removed from this group';

  @override
  String get chatYouBlocked => 'You blocked this contact';

  @override
  String get chatEmptyGroup =>
      'No messages yet. Everything here is encrypted with the group\'s key and reaches every member, now or when they are next in range.';

  @override
  String get chatEmptyDirect =>
      'No messages yet. They are end-to-end encrypted, and wait here if the other phone is out of range.';

  @override
  String get chatToday => 'Today';

  @override
  String get stripWaitingForKey =>
      'Waiting for this person\'s encryption key. It arrives automatically the first time you are in range of them.';

  @override
  String get stripDirect =>
      'Directly connected. Messages are delivered immediately.';

  @override
  String stripRelayed(int hops) {
    return 'Reachable through other phones ($hops hops). Messages are relayed, still end-to-end encrypted.';
  }

  @override
  String get stripOffline =>
      'Not reachable right now. Messages wait on this phone and are sent as soon as this person (or a phone that can reach them) comes into range, for up to 12 hours.';

  @override
  String fwdTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Forward $count messages to…',
      one: 'Forward to…',
    );
    return '$_temp0';
  }

  @override
  String get fwdSearchHint => 'Search chats';

  @override
  String get fwdNoTargets =>
      'There is no chat to forward to yet. Start a chat with someone nearby first.';

  @override
  String fwdNoMatch(String query) {
    return 'No chat matches \"$query\".';
  }

  @override
  String get fwdPrivateChat => 'Private chat';

  @override
  String get fwdPublicRoom => 'Public room · everyone nearby can read it';

  @override
  String get commonClear => 'Clear';

  @override
  String searchInTitle(String title) {
    return 'Search in $title';
  }

  @override
  String get searchPictures => 'Pictures';

  @override
  String get searchVideos => 'Videos';

  @override
  String get searchVoice => 'Voice';

  @override
  String get searchFromMe => 'From me';

  @override
  String get searchEmptyBody =>
      'Type a word, or pick Pictures, Videos or Voice to see only those. Messages that were deleted are not searched: they are gone.';

  @override
  String get searchNoMatch => 'No message in this chat matches.';

  @override
  String get detailUnknownPhone => 'Unknown phone';

  @override
  String get detailAnyMoment => 'any moment now';

  @override
  String detailInMinutes(int minutes) {
    return 'in $minutes min';
  }

  @override
  String detailInHours(int hours) {
    return 'in $hours h';
  }

  @override
  String detailInHoursMinutes(int hours, int minutes) {
    return 'in $hours h $minutes min';
  }

  @override
  String get detailTitle => 'Message details';

  @override
  String get detailFrom => 'From';

  @override
  String get detailDirection => 'Direction';

  @override
  String get detailSentByYou => 'Sent by you';

  @override
  String get detailReceived => 'Received';

  @override
  String get detailType => 'Type';

  @override
  String get detailSize => 'Size';

  @override
  String get detailStatus => 'Status';

  @override
  String get detailConfirmedBy => 'Confirmed by';

  @override
  String detailConfirmedOf(int done, int total) {
    return '$done of $total members';
  }

  @override
  String get detailHasIt => 'Has it';

  @override
  String get detailNotYet => 'Not yet';

  @override
  String get detailSentTheirClock => 'Sent (their clock)';

  @override
  String get detailWrittenSaved => 'Written and saved';

  @override
  String get detailReceivedSaved => 'Received and saved';

  @override
  String get detailEdited => 'Edited';

  @override
  String get detailForwardedFrom => 'Forwarded from';

  @override
  String get detailReplyTo => 'Reply to';

  @override
  String get detailReplyDeleted => 'a message that was deleted';

  @override
  String get detailPinned => 'Pinned';

  @override
  String get detailPinnedValue => 'Yes - only on this phone';

  @override
  String get detailDisappears => 'Disappears';

  @override
  String detailDisappearsValue(String when, String remaining) {
    return '$when ($remaining). Messages of public rooms are removed from this phone six hours after they arrive.';
  }

  @override
  String get detailReceiptPath => 'Receipt path';

  @override
  String get detailRoute => 'Route';

  @override
  String detailRadioHops(int count) {
    return '$count radio hops';
  }

  @override
  String detailPassedThrough(int hops) {
    String _temp0 = intl.Intl.pluralLogic(
      hops,
      locale: localeName,
      other: 'passed through $hops relays',
      one: 'passed through 1 relay',
    );
    return '$_temp0';
  }

  @override
  String get detailNote => 'Note';

  @override
  String get detailClockSkew =>
      'The sender\'s clock differs from yours by more than 10 minutes.';

  @override
  String get detailProblem => 'Problem';

  @override
  String get detailMessageId => 'Message id';

  @override
  String get galDenied =>
      'دەمەتەقێ was not allowed to add to your gallery. You can allow it in your phone\'s settings.';

  @override
  String get galNoSpace =>
      'There is not enough space on this phone to save it.';

  @override
  String get galUnsupported =>
      'This phone cannot save that kind of file to the gallery.';

  @override
  String get galFailed => 'It could not be saved to the gallery.';

  @override
  String get galPictureGone => 'That picture is no longer on this phone.';

  @override
  String get galVideoGone => 'That video cannot be saved from this phone.';

  @override
  String get galVoice => 'Voice messages cannot be saved to the gallery.';

  @override
  String get imgUnreadable => 'That file is not a picture this phone can read.';

  @override
  String get imgTooDetailed =>
      'That picture is too detailed to send over Bluetooth.';

  @override
  String get voiceMicOff => 'The microphone is switched off for دەمەتەقێ.';

  @override
  String get radarListening => 'Listening for people nearby';

  @override
  String get commonStop => 'Stop';

  @override
  String get diagRunAgain => 'Run again';

  @override
  String get diagRun => 'Run self-test';

  @override
  String get diagReportCopied => 'Report copied';

  @override
  String get diagCopyReport => 'Copy report';

  @override
  String get diagLogTitle => 'Activity log';

  @override
  String get diagLogNote => 'Kept in memory only; gone when the app closes';

  @override
  String get diagIntroTitle => 'Check that Bluetooth really works';

  @override
  String get diagIntroBody =>
      'Best done with two phones side by side, both running دەمەتەقێ with Bluetooth on. Turn Wi-Fi and mobile data off first to prove nothing needs the internet. The test takes about half a minute and tells you what to fix if a step fails.';

  @override
  String get diagPass => 'Everything that could be tested passed';

  @override
  String get diagPassBody =>
      'These phones found each other, proved their identities and exchanged data over Bluetooth.';

  @override
  String get diagWarn => 'Works, with something to look at';

  @override
  String get diagWarnBody =>
      'Nothing failed, but at least one step could not be fully tested or ran into trouble. See below.';

  @override
  String get diagFail => 'A problem was found';

  @override
  String get diagFailBody =>
      'Follow the advice under the failed step, then run the test again.';

  @override
  String get diagNoResult => 'No result';

  @override
  String get diagLimitsTitle => 'What a pass does and does not mean';

  @override
  String get diagLimitsBody =>
      'A pass means these two phones, right now, found each other, connected, authenticated each other and moved data both ways, including messages too big for one Bluetooth packet. It does not measure range, battery use, or how other phone models behave, and relaying through a third phone needs three phones to test. Phones differ a lot in Bluetooth quality, so test with the models you will use.';

  @override
  String get diagLogCopied => 'Log copied';

  @override
  String get diagLogWarn =>
      'The log can contain Bluetooth addresses of phones around you. Check it before sharing. It never contains keys or message text.';

  @override
  String get diagLogEmpty => 'Nothing logged yet.';

  @override
  String get stNothingToClean =>
      'Nothing to clean: every public message is less than six hours old.';

  @override
  String stRemovedPublic(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Removed $count public messages.',
      one: 'Removed 1 public message.',
    );
    return '$_temp0';
  }

  @override
  String get stDeleteMediaTitle =>
      'Delete all pictures, voice messages and videos?';

  @override
  String get stDeleteMediaBody =>
      'They are removed from this phone together with their messages. Nobody else is told and other phones keep their copies. This cannot be undone.';

  @override
  String get stDeleteMediaAction => 'Delete them';

  @override
  String get stNothingToDelete => 'There was nothing to delete.';

  @override
  String stDeletedMedia(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Deleted $count messages with files.',
      one: 'Deleted 1 message with files.',
    );
    return '$_temp0';
  }

  @override
  String get stMessages => 'Messages';

  @override
  String get stMedia => 'Pictures, voice messages and videos';

  @override
  String stFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files',
      one: '1 file',
    );
    return '$_temp0';
  }

  @override
  String get stDatabase => 'Message database';

  @override
  String get stPublic => 'Public chats';

  @override
  String stMessagesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count messages',
      one: '1 message',
    );
    return '$_temp0';
  }

  @override
  String get stPublicNoteNever =>
      'Removed from this phone six hours after they arrive. Nothing has been removed yet.';

  @override
  String stPublicNote(String ago, int removed) {
    return 'Removed from this phone six hours after they arrive. Last clean-up $ago, $removed removed.';
  }

  @override
  String get stVideoLimit => 'Largest video you send';

  @override
  String stVideoLimitBody(String max) {
    return 'A video is not shrunk, so only a very short clip fits. Bigger ones are refused before anything is sent. Larger videos take much longer over Bluetooth, and videos are never sent to public rooms. Videos you receive are accepted up to $max.';
  }

  @override
  String get stCleanNow => 'Clean public chats now';

  @override
  String get stCleanNowBody =>
      'They are also cleaned by themselves, about once a minute while the app runs, and when it starts. Private chats and groups are never touched.';

  @override
  String get stDeleteMediaTile =>
      'Delete all pictures, voice messages and videos';

  @override
  String get stDeleteMediaTileBody =>
      'Frees the most space. The messages that carried them go too.';

  @override
  String get stFooter =>
      'To remove old messages automatically, use \"Keep messages\" under Privacy and security in the settings. Messages and files are stored without encryption of their own: they rely on your phone\'s screen lock and disk encryption.';

  @override
  String get nearbyTitle => 'Nearby';

  @override
  String get nearbyVisible => 'Visible to others';

  @override
  String get nearbySearching => 'Searching';

  @override
  String get nearbyScanningNow => 'Scanning now';

  @override
  String get nearbyBetweenScans => 'Between scans';

  @override
  String get nearbyStopped => 'Stopped';

  @override
  String get nearbyHowHard => 'How hard to look';

  @override
  String get nearbyRunSelfTest => 'Run Bluetooth self-test';

  @override
  String nearbyConnected(int count) {
    return 'Connected phones ($count)';
  }

  @override
  String get nearbyNoLinks =>
      'No Bluetooth connections right now. Connections appear here as soon as a nearby phone is found, then show \"Verifying\" until it has proved its identity.';

  @override
  String nearbyHeard(int count) {
    return 'Devices heard ($count)';
  }

  @override
  String get nearbyNothingHeard =>
      'Nothing heard yet. Other phones running دەمەتەقێ are found within about 10 metres. Both phones need Bluetooth on and the app open.';

  @override
  String get nearbyFootnote =>
      'A device being \"heard\" means its Bluetooth advertisement was received. It is not trusted until it completes the identity handshake. Addresses shown here are temporary radio handles, not identities, and may change.';

  @override
  String get nearbyCannotAdvertise => 'Cannot advertise';

  @override
  String get nearbyStartingPill => 'Starting';

  @override
  String get linkConnected => 'Connected';

  @override
  String get linkVerifying => 'Verifying…';

  @override
  String get linkClosing => 'Closing';

  @override
  String get linkUnnamed => 'Unnamed phone';

  @override
  String get linkUnverified => 'Unverified phone';

  @override
  String get linkRole => 'Role';

  @override
  String get linkWeConnected => 'we connected';

  @override
  String get linkTheyConnected => 'they connected';

  @override
  String get linkWriteSize => 'Write size';

  @override
  String get linkSignal => 'Signal';

  @override
  String get linkRoundTrip => 'Round trip';

  @override
  String get linkTraffic => 'Traffic';

  @override
  String get devHeard => 'Heard';

  @override
  String get devConnecting => 'Connecting…';

  @override
  String get devLinked => 'Linked';

  @override
  String get devRetrying => 'Retrying later';

  @override
  String get devAlreadyLinked => 'Already linked';

  @override
  String devFailedAttempts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count failed attempts',
      one: '1 failed attempt',
    );
    return '$_temp0';
  }

  @override
  String get errTypeFirst => 'Type a message first.';

  @override
  String errMessageTooLong(int bytes, int max) {
    return 'That message is too long ($bytes of $max bytes). Please shorten it.';
  }

  @override
  String get errReplyGone => 'The message you are replying to is gone.';

  @override
  String get errUnknownContact => 'That contact is not known yet.';

  @override
  String get errBlockedContact =>
      'You have blocked this contact. Unblock them to send messages.';

  @override
  String errBlockedNamed(String name) {
    return 'You have blocked $name.';
  }

  @override
  String get errNoKey =>
      'We haven\'t received this person\'s encryption key yet. Come within range of them (or of a phone that can hear them) once, then try again.';

  @override
  String get errNoKeyOnce =>
      'We haven\'t received this person\'s encryption key yet. Come within range of them once, then try again.';

  @override
  String errNoKeyNamed(String name) {
    return 'We haven\'t received $name\'s encryption key yet. Come within range of them once, then try again.';
  }

  @override
  String get errKeyUnusable =>
      'This contact\'s encryption key is not usable. Ask them to open the app near you so it can be refreshed.';

  @override
  String get errKeyUnusableOne =>
      'One person\'s encryption key is not usable. Ask them to open the app near you so it can be refreshed.';

  @override
  String get errNoKeyForControl =>
      'We don\'t have this contact\'s encryption key, so nothing can be sent to them.';

  @override
  String get errNoConversation => 'That conversation no longer exists.';

  @override
  String get errCannotResend => 'This message cannot be resent.';

  @override
  String get errFileGone => 'The file is no longer on this phone.';

  @override
  String get errNotQueued => 'That could not be queued for sending. Try again.';

  @override
  String get unknownAuthor => 'Unknown';

  @override
  String get errGroupName => 'Give the group a name.';

  @override
  String get errGroupGone => 'That group no longer exists.';

  @override
  String get errNotInGroup => 'You are not in this group any more.';

  @override
  String get errAdminOnly => 'Only the group\'s admin can do that.';

  @override
  String get errPickPeople => 'Pick at least one person to add.';

  @override
  String get errPickNewPeople => 'Pick at least one new person to add.';

  @override
  String errGroupFull(int max) {
    return 'A group can have at most $max people, including you.';
  }

  @override
  String get errGroupKeyMissing => 'This group\'s key is missing.';

  @override
  String get errAdminCannotBeRemoved => 'The admin cannot be removed.';

  @override
  String get errNotInGroupPerson => 'That person is not in the group.';

  @override
  String get errCreatorCannotLeave =>
      'You created this group, so you cannot leave it - delete it instead.';

  @override
  String get errRoomName => 'Give the room a name.';

  @override
  String get errRoomGone => 'That room is no longer around.';

  @override
  String get errMeshCannotLeave => '#mesh is for everyone and cannot be left.';

  @override
  String get errJoinFirst => 'Join the room to post in it.';

  @override
  String get errFileEmpty => 'That file is empty.';

  @override
  String errTooLargeForMesh(int kb, int limit) {
    return 'That is too large for a Bluetooth mesh ($kb KB; the limit is $limit KB).';
  }

  @override
  String get errPictureUnreadable => 'That picture could not be read.';

  @override
  String get errVideoUnreadable => 'That video could not be read.';

  @override
  String get errRecordingUnreadable => 'That recording could not be read.';

  @override
  String errVoiceTooLong(int seconds) {
    return 'Voice messages can be at most $seconds seconds long.';
  }

  @override
  String get errVideoNotInRooms =>
      'Videos cannot be sent to public rooms: every phone in range would have to carry them. Send it in a private chat or a group.';

  @override
  String get errVideoTooLarge => 'That video is too large to send.';

  @override
  String get errNothingToShare => 'There is nothing to share.';

  @override
  String get errMessageGone => 'That message is gone.';

  @override
  String get errDeleteGroupOnly =>
      'Only the author, or the admin of the group, can delete a message for everyone.';

  @override
  String get errDeleteOwnOnly =>
      'You can only delete your own messages for everyone.';

  @override
  String errDeleteTooOld(int hours) {
    return 'This message is older than $hours hours, so it can no longer be deleted for everyone.';
  }

  @override
  String get errEditOwnTextOnly => 'Only your own text messages can be edited.';

  @override
  String errEditTooOld(int hours) {
    return 'Messages can be edited for $hours hours after they are sent.';
  }

  @override
  String get timeYesterday => 'Yesterday';

  @override
  String get weekdayMon => 'Mon';

  @override
  String get weekdayTue => 'Tue';

  @override
  String get weekdayWed => 'Wed';

  @override
  String get weekdayThu => 'Thu';

  @override
  String get weekdayFri => 'Fri';

  @override
  String get weekdaySat => 'Sat';

  @override
  String get weekdaySun => 'Sun';

  @override
  String get agoJustNow => 'just now';

  @override
  String agoSeconds(int n) {
    return '$n s ago';
  }

  @override
  String agoMinutes(int n) {
    return '$n min ago';
  }

  @override
  String agoHours(int n) {
    return '$n h ago';
  }

  @override
  String agoDays(int n) {
    return '$n d ago';
  }

  @override
  String get settingsTitle => 'Settings';

  @override
  String get homePeople => 'People';

  @override
  String get homeSearchHint => 'Search chats, groups and people';

  @override
  String get navPrivate => 'Private';

  @override
  String get navGroups => 'Groups';

  @override
  String get navPublic => 'Public';

  @override
  String get fabNewMessage => 'New message';

  @override
  String get fabNewGroup => 'New group';

  @override
  String get homeNoMessagesYet => 'No messages yet';

  @override
  String get homePrivateEmptyTitle => 'No private chats yet';

  @override
  String get homeNothingFound => 'Nothing found';

  @override
  String get homePrivateEmptyBody =>
      'دەمەتەقێ works without internet, using Bluetooth. Ask someone nearby to open the app; when their phone is in range they will appear here.';

  @override
  String homeNoMatchChat(String query) {
    return 'No chat or person matches \"$query\".';
  }

  @override
  String get homeSeePeople => 'See people';

  @override
  String get homeDeleteChatTitle => 'Delete this conversation?';

  @override
  String get homeDeleteChatBody =>
      'Its messages and pictures are removed from this phone only.';

  @override
  String get homeAvailableNow => 'Available now';

  @override
  String get homeGroupsEmptyTitle => 'No groups yet';

  @override
  String get homeGroupsEmptyBody =>
      'A group is a private chat for several people at once, encrypted with a key only its members have. Create one with people you have met.';

  @override
  String homeNoMatchGroup(String query) {
    return 'No group matches \"$query\".';
  }

  @override
  String get homeCreateGroup => 'Create a group';

  @override
  String homeInvitations(int count) {
    return 'Invitations ($count)';
  }

  @override
  String get homeYourGroups => 'Your groups';

  @override
  String get homeYouLeft => 'You left this group';

  @override
  String get homeYouWereRemoved => 'You were removed';

  @override
  String get homeDeleteGroupTitle => 'Delete this group?';

  @override
  String get homeLeaveGroupTitle => 'Leave this group?';

  @override
  String get homeDeleteThisChatTitle => 'Delete this chat?';

  @override
  String get homeDeleteGroupBody =>
      'The group ends for everybody. Each member keeps what they already have.';

  @override
  String get homeLeaveGroupBody =>
      'You will stop receiving its messages. Your copy of the chat is deleted from this phone.';

  @override
  String get homeDeleteThisChatBody => 'The chat is removed from this phone.';

  @override
  String get commonContinue => 'Continue';

  @override
  String get homeSomeone => 'Someone';

  @override
  String homeInvitedYou(String name, int count) {
    return '$name invited you · $count people';
  }

  @override
  String get commonDecline => 'Decline';

  @override
  String get commonAccept => 'Accept';

  @override
  String get homeMeshSubtitle => 'Everyone nearby · public';

  @override
  String homeLeaveRoomTitle(String room) {
    return 'Leave $room?';
  }

  @override
  String get homeLeaveRoomBody =>
      'Its messages and pictures are removed from this phone. You can join again while the room is still around.';

  @override
  String get commonLeave => 'Leave';

  @override
  String get homeNearbyRooms => 'Nearby rooms';

  @override
  String get homeListeningForRooms =>
      'Listening for rooms. Rooms created by people nearby, or passed on by their phones, appear here.';

  @override
  String homeHeardAgo(String ago) {
    return 'heard $ago';
  }

  @override
  String get commonJoin => 'Join';

  @override
  String promptTypeToConfirm(String word) {
    return 'Type \"$word\" to confirm:';
  }

  @override
  String defaultNickname(String code) {
    return 'Phone $code';
  }

  @override
  String get previewYou => 'You';

  @override
  String get previewPhoto => 'Photo';

  @override
  String get previewVoice => 'Voice message';

  @override
  String get previewVideo => 'Video';

  @override
  String get previewUndecryptable => 'Message could not be decrypted';

  @override
  String get notifyHiddenInvite => 'You have a new group invitation';

  @override
  String notifyHiddenMany(int count) {
    return 'You have $count new messages';
  }

  @override
  String get notifyHiddenOne => 'You have a new message';

  @override
  String get notifySenderInvite => 'Invited you to a group';

  @override
  String notifySenderMany(int count) {
    return '$count new messages';
  }

  @override
  String get notifySenderOne => 'New message';

  @override
  String get notifyFullInvite => 'Invited you to a group';

  @override
  String notifyFullInviteBy(String name) {
    return '$name invited you to a group';
  }

  @override
  String notifyFullMore(String line, int count) {
    return '$line  (+$count more)';
  }

  @override
  String get notifyChannelName => 'Messages';

  @override
  String get notifyChannelDescription => 'New messages and group invitations';

  @override
  String get keepAliveChannelName => 'Mesh running in the background';

  @override
  String get keepAliveChannelDescription =>
      'Shown while دەمەتەقێ keeps the Bluetooth mesh running with the screen off.';

  @override
  String get keepAliveTitle => 'دەمەتەقێ is keeping the mesh running';

  @override
  String get keepAliveText =>
      'Relaying and receiving messages over Bluetooth. Tap to open.';

  @override
  String get obHeadline => 'Chat with people nearby.\nNo internet needed.';

  @override
  String get obPoint1Title => 'Phone to phone, over Bluetooth';

  @override
  String get obPoint1Body =>
      'Messages, pictures and voice go straight from one phone to the next. No accounts, no servers, no internet.';

  @override
  String get obPoint3Title => 'Private chats, groups and public rooms';

  @override
  String get obPoint3Body =>
      'Chats and groups are encrypted. Public rooms are open: anyone nearby can read them.';

  @override
  String get obPoint4Title => 'Asks before it uses anything';

  @override
  String get obPoint4Body =>
      'Bluetooth is requested next. The microphone, camera and photos only when you send a voice message or a picture. Never your location or contacts.';

  @override
  String get obPoint5Title => 'Good to know';

  @override
  String get obPoint5Body =>
      'Experimental: the encryption has not been independently audited, and passing messages through other phones has only been tested with simulated radios. More in Settings, under Help and instructions.';

  @override
  String get obNameHint => 'Shown to people nearby';

  @override
  String get obNameNote =>
      'You can change this any time in Settings. It does not have to be your real name.';

  @override
  String get obStarting => 'Starting…';

  @override
  String get obStart => 'Allow Bluetooth & start';

  @override
  String get gdGone => 'This group is gone.';

  @override
  String get gdStateActive => 'you are in';

  @override
  String get gdStateLeft => 'you left';

  @override
  String get gdStateRemoved => 'you were removed';

  @override
  String get gdStateInvited => 'invitation';

  @override
  String get gdEncryptedNote =>
      'Encrypted with a key only the members have. When someone is removed the group gets a new key, so they cannot read anything sent afterwards. They keep what they already received.';

  @override
  String get gdMembers => 'Members';

  @override
  String get gdAdmin => 'Admin';

  @override
  String get gdRemoveTooltip => 'Remove from the group';

  @override
  String gdRemoveTitle(String name) {
    return 'Remove $name?';
  }

  @override
  String get gdRemoveBody =>
      'They will no longer receive anything, and the group gets a new key they do not have.';

  @override
  String get gdFull => 'The group is full';

  @override
  String get gdAddPeople => 'Add people';

  @override
  String get gdDeleteBody =>
      'The group ends for everybody. Each member keeps the messages they already have; nobody can send to it any more.';

  @override
  String get gdDeleteAction => 'Delete group';

  @override
  String get gdDeleteButton => 'Delete group for everyone';

  @override
  String get gdLeaveBody =>
      'You will stop receiving its messages. The admin will give the group a new key. Your copy of the chat stays on this phone.';

  @override
  String get gdLeaveButton => 'Leave group';

  @override
  String get gdForgetTitle => 'Remove from this phone?';

  @override
  String get gdForgetBody =>
      'The chat and its messages are deleted from this phone.';

  @override
  String get gdForgetButton => 'Delete this chat';

  @override
  String get gdInvitationsSent => 'Invitations sent. The group has a new key.';

  @override
  String gdSelectedOf(int count, int room) {
    return '$count of $room possible';
  }

  @override
  String get gdInvite => 'Invite';

  @override
  String get pdNameTitle => 'Name this contact';

  @override
  String get pdNameHint => 'Name';

  @override
  String get pdDeleteTitle => 'Delete this contact?';

  @override
  String get pdDeleteBody =>
      'The contact and your conversation with them will be deleted from this phone. They are not notified. If they are nearby they will reappear as a new, unverified contact.';

  @override
  String get pdTitle => 'Contact';

  @override
  String get pdGone => 'This contact no longer exists.';

  @override
  String pdCallsThemselves(String name) {
    return 'calls themselves \"$name\"';
  }

  @override
  String get pdSendMessage => 'Send a message';

  @override
  String get pdVerified => 'Verified';

  @override
  String get pdNotVerified => 'Not verified yet';

  @override
  String get pdVerifyBody =>
      'Anyone can pick any nickname, and the first time two phones meet there is no way to know the keys are really theirs. To be sure, compare this safety number with the one on their phone - in person or on a call where you recognise their voice. If the numbers are identical, mark them verified. If they differ, do NOT trust this contact.';

  @override
  String get pdNoKey => 'No encryption key received yet: come into range once.';

  @override
  String get pdSafetyNumber => 'Safety number';

  @override
  String get pdSafetyNote =>
      'This is the same number on both phones. Long-press to copy.';

  @override
  String get pdNumbersMatch => 'The numbers match';

  @override
  String get pdMarkVerified => 'Mark this contact as verified';

  @override
  String get pdShortId => 'Short id';

  @override
  String get pdFirstSeen => 'First seen';

  @override
  String get pdLastSeen => 'Last seen';

  @override
  String get pdFullFingerprint => 'Full fingerprint';

  @override
  String get pdRename => 'Rename';

  @override
  String get pdRenameBody => 'Only you see this name';

  @override
  String get pdBlock => 'Block';

  @override
  String get pdBlockBody => 'Drop their messages and do not acknowledge them';

  @override
  String get pdDeleteContact => 'Delete contact';

  @override
  String get problemQueueFailed => 'Could not be queued for delivery';

  @override
  String get problemExpired =>
      'Not delivered: the recipient could not be reached before the message expired.';

  @override
  String get problemNobodyInRange => 'Nobody was in range to receive this.';

  @override
  String get problemFileDamaged =>
      'The file arrived damaged and was discarded.';

  @override
  String get problemFileIncomplete => 'The rest of this file never arrived.';

  @override
  String get feedErrorTitle => 'Could not load the messages';

  @override
  String get feedErrorBody =>
      'Nothing was deleted. Try again, and if it keeps happening, restart the app.';

  @override
  String get homePrivateTitle => 'Private chats';

  @override
  String get setProfileTitle => 'Profile and identity';

  @override
  String get setDataHeading => 'Data and history';

  @override
  String get setChatsBluetooth => 'Chats and Bluetooth';

  @override
  String get setHelp => 'Help and instructions';

  @override
  String setAboutTitle(String name) {
    return 'About $name';
  }

  @override
  String get setLicenses => 'Open-source licences';

  @override
  String get setLicensesBody => 'The fonts and libraries this app is made with';

  @override
  String get setLicensesLegalese =>
      'Built with open-source software. Each part keeps its own licence.';

  @override
  String get helpPermissionsTitle => 'Permissions: what is asked, and when';

  @override
  String get helpPermissionsBody =>
      'Bluetooth is requested when you start, so دەمەتەقێ can find nearby phones. The microphone, camera and photos are asked for only if you record a voice message or send a picture - each with an explanation first, and you can say no to any of them. دەمەتەقێ never reads your location or contacts. (Android 11 and older tie Bluetooth scanning to the Location permission; the app still never reads your location.)';

  @override
  String get roomYourNameTitle => 'Your name here';

  @override
  String get roomYourNameBody =>
      'Everyone in range sees this name next to what you write. It does not have to be your real name, and it is not unique: others can pick the same one.';

  @override
  String get roomExpiryNote => 'Public · messages disappear after 6 hours';

  @override
  String get roomSearchTooltip => 'Search this room';

  @override
  String roomComposerHint(String room) {
    return 'Message $room · public';
  }

  @override
  String get roomJoinToPost => 'Join this room to post';

  @override
  String get roomEmpty =>
      'Nothing here yet. Whatever you write is public: every phone in range (and the phones they pass it to) can read it.';

  @override
  String get roomsCreateTitle => 'Create a public room';

  @override
  String get roomsCreateBody =>
      'Anyone nearby can find the room, join it and read everything said in it. It is not private. The room is listed for a day and renewed automatically while your app is running.';

  @override
  String get roomsNameHint => 'room name';

  @override
  String get roomsAboutHint => 'What is it about? (optional)';

  @override
  String get commonCreate => 'Create';

  @override
  String get roomsTitle => 'Public rooms';

  @override
  String get roomsCreateButton => 'Create a room';

  @override
  String get peopleFilterAll => 'All';

  @override
  String get peopleFilterReachable => 'Reachable now';

  @override
  String get peopleFilterContacts => 'Contacts';

  @override
  String get peopleEmptyTitle => 'Nobody yet';

  @override
  String get peopleEmptyFilterTitle => 'No one matches this filter';

  @override
  String get peopleEmptyBody =>
      'Phones running دەمەتەقێ within Bluetooth range appear here automatically, along with anyone whose announcement reaches you through other phones. Nothing is sent over the internet.';

  @override
  String get peopleEmptyFilterBody => 'Try another filter.';

  @override
  String get peopleSeeNearby => 'See what is nearby';

  @override
  String get peopleDetailsTooltip => 'Contact details and verification';

  @override
  String get peoplePickEmpty =>
      'Nobody to message yet. Phones appear here once they are in range.';

  @override
  String get groupNoKeyYet => 'no encryption key yet - meet them once first';

  @override
  String get groupNameLabel => 'Group name';

  @override
  String get groupCreateNote =>
      'Messages in a group are encrypted with a key only its members have. People you choose get an invitation they can accept or decline; nothing about the group is ever broadcast.';

  @override
  String groupAddPeople(int count, int max) {
    return 'Add people ($count of $max)';
  }

  @override
  String get groupNobodyToAdd => 'Nobody to add yet';

  @override
  String get groupNobodyBody =>
      'You can only invite people your phone has met. Open دەمەتەقێ near someone and they will appear here.';

  @override
  String get groupCreating => 'Creating…';

  @override
  String get groupCreate => 'Create group';

  @override
  String get videoCouldNotPlay =>
      'This video could not be played on this phone.';

  @override
  String get commonPause => 'Pause';

  @override
  String get commonPlay => 'Play';

  @override
  String get secClearTitle => 'Clear the security log?';

  @override
  String get secClearBody =>
      'The entries are removed from this phone. This cannot be undone.';

  @override
  String get secClearTooltip => 'Clear log';

  @override
  String get secEmptyTitle => 'Nothing suspicious recorded';

  @override
  String get secEmptyBody =>
      'If a message fails its signature or cannot be decrypted, a phone fails the identity check, or a contact\'s key changes, it is listed here. Occasional entries can be caused by a weak radio link and are not always an attack.';

  @override
  String get secBadSignatureTitle => 'A message had an invalid signature';

  @override
  String get secBadSignatureBody =>
      'It was dropped. Someone may have forged or altered it, or it was corrupted in the air.';

  @override
  String get secDecryptFailedTitle => 'A message could not be decrypted';

  @override
  String get secDecryptFailedBody =>
      'It was addressed to you but could not be opened. It was corrupted, tampered with, or encrypted for a different key.';

  @override
  String get secLinkAuthTitle => 'A phone failed the identity check';

  @override
  String get secLinkAuthBody =>
      'It connected over Bluetooth but could not prove it owns the key it claimed. The connection was closed.';

  @override
  String get secKeyChangedTitle => 'A contact\'s encryption key changed';

  @override
  String get secKeyChangedBody =>
      'Their verification was removed. Compare safety numbers with them again before trusting this contact. A changed key is expected if they reinstalled the app.';

  @override
  String get secRateLimitedTitle => 'A phone sent too much';

  @override
  String get secRateLimitedBody =>
      'Its traffic went over the limit and the excess was dropped.';

  @override
  String get secMalformedTitle => 'Unreadable data received';

  @override
  String get secMalformedBody =>
      'Data that does not follow the protocol was ignored.';

  @override
  String get secNotAMemberTitle => 'Someone acted without being allowed to';

  @override
  String get secNotAMemberBody =>
      'A group message, invitation or update came from someone who is not a member or not the admin. It was ignored.';

  @override
  String get secUnauthorizedTitle =>
      'Someone tried to change a message that is not theirs';

  @override
  String get secUnauthorizedBody =>
      'A request to delete or edit a message came from someone who did not write it (and is not the group\'s admin). It was ignored.';

  @override
  String get secBadMediaTitle => 'A picture or voice message was damaged';

  @override
  String get secBadMediaBody =>
      'A file did not match its description (wrong size or checksum) or came with inconsistent parts, so it was discarded.';

  @override
  String get secProtocolTitle => 'A phone broke the connection rules';

  @override
  String get secProtocolBody =>
      'It sent data out of order or in an unexpected form, so the link was dropped.';

  @override
  String get secUnknownBody => 'No description is available for this entry.';

  @override
  String secUnknownPhone(String tag) {
    return 'Unknown phone $tag';
  }

  @override
  String get bstTitleDevice => 'This phone';

  @override
  String get bstTitleSupport => 'Bluetooth Low Energy';

  @override
  String get bstTitlePermission => 'Bluetooth permission';

  @override
  String get bstTitlePower => 'Bluetooth switched on';

  @override
  String get bstTitleAdvertising => 'Visible to other phones (advertising)';

  @override
  String get bstTitleScanning => 'Looking for other phones (scanning)';

  @override
  String get bstTitleDiscovery => 'Finding another phone';

  @override
  String get bstTitleConnection => 'Connecting and proving identity';

  @override
  String get bstTitleExchange => 'Sending data both ways';

  @override
  String get bstTitleMultihop => 'Reaching phones through a relay';

  @override
  String get bstTitleNetwork => 'Offline operation';

  @override
  String get bstStopped => 'Stopped.';

  @override
  String get bstFixAbove => 'Fix the problem above first.';

  @override
  String get bstNoBle => 'This phone does not offer Bluetooth Low Energy.';

  @override
  String get bstNoBleAdvice => 'This phone cannot take part in the mesh.';

  @override
  String get bstBleAvailable => 'Bluetooth Low Energy is available.';

  @override
  String get bstWhereIos => 'Settings > دەمەتەقێ > Bluetooth (turn it on).';

  @override
  String get bstWhereAndroid12 =>
      'Settings > Apps > دەمەتەقێ > Permissions > Nearby devices > Allow.';

  @override
  String get bstWhereOlder =>
      'Settings > Apps > دەمەتەقێ > Permissions > Location > Allow (older Android needs it for Bluetooth scanning).';

  @override
  String get bstPermDenied => 'Bluetooth permission has not been granted.';

  @override
  String bstPermAdvice(String where) {
    return 'Tap \"Allow Bluetooth\" on the Home screen, or open $where';
  }

  @override
  String get bstPermGranted => 'Permission granted.';

  @override
  String get bstOff => 'Bluetooth is switched off.';

  @override
  String get bstOffAdvice =>
      'Switch Bluetooth on in your phone\'s quick settings, then run the test again.';

  @override
  String get bstPowerUnknown =>
      'The phone has not reported its Bluetooth state yet.';

  @override
  String get bstPowerUnknownAdvice => 'Wait a moment and run the test again.';

  @override
  String get bstOn => 'Bluetooth is on.';

  @override
  String get bstCannotAdvertise =>
      'This phone cannot advertise (act as a Bluetooth peripheral).';

  @override
  String get bstCannotAdvertiseAdvice =>
      'It can still find and connect to other phones, but others cannot find it. Two phones that both lack this ability cannot connect to each other.';

  @override
  String get bstAdvertising =>
      'Advertising the mesh service; other phones can see and connect to this one.';

  @override
  String get bstNotAdvertising => 'The phone is not advertising.';

  @override
  String get bstNotAdvertisingAdvice =>
      'Switch Bluetooth off and on, then run the test again. If it keeps failing this phone model may not support Bluetooth advertising.';

  @override
  String get bstDiscoveryStopped => 'Discovery is stopped.';

  @override
  String get bstDiscoveryStoppedAdvice =>
      'Open the Nearby tab and make sure the app is started.';

  @override
  String bstScanning(String mode, int count) {
    return 'Scanning in short windows ($mode mode), $count scan(s) started so far.';
  }

  @override
  String get bstNoScan => 'No scan could be started.';

  @override
  String get bstNoScanAdvice =>
      'Check the Bluetooth permission and that Bluetooth is on.';

  @override
  String bstHeardCount(int count) {
    return 'Heard $count دەمەتەقێ phone(s).';
  }

  @override
  String bstHeardStrongest(int count, int dbm) {
    return 'Heard $count دەمەتەقێ phone(s), strongest signal $dbm dBm.';
  }

  @override
  String bstNoneHeard(int seconds) {
    return 'No other دەمەتەقێ phone was heard in $seconds seconds.';
  }

  @override
  String get bstNoneHeardAdvice =>
      'This is normal if nobody is nearby. Open the app on a second phone (Bluetooth on, within a few metres) and run the test again.';

  @override
  String get bstOlderAndroidLocation =>
      ' On Android 11 and older, scanning also needs the phone\'s Location switch (quick settings) to be on; دەمەتەقێ does not read your location, but those versions find nothing while it is off.';

  @override
  String get bstNeedsPhone => 'Needs another phone in range.';

  @override
  String get bstWeConnected => 'we connected to them';

  @override
  String get bstTheyConnected => 'they connected to us';

  @override
  String bstLinkLine(String who, String role, String bytes) {
    return '$who ($role, $bytes bytes per write)';
  }

  @override
  String bstConnectedOk(String lines) {
    return 'Connected and verified key ownership with: $lines.';
  }

  @override
  String get bstNotConnected =>
      'Heard other phones but could not finish connecting.';

  @override
  String bstNotConnectedWith(String errors) {
    return 'Heard other phones but could not finish connecting: $errors';
  }

  @override
  String get bstNotConnectedAdvice =>
      'Move the phones closer (under 2 m), switch Bluetooth off and on on both, and close other apps that use Bluetooth heavily. Connection errors such as \"status 133\" are common on some Android phones and usually clear on retry.';

  @override
  String get bstNeedsConnected => 'Needs a connected phone.';

  @override
  String bstSmall(int received, int sent) {
    return '$received/$sent small';
  }

  @override
  String bstLarge(int received, int sent) {
    return '$received/$sent large (1200 B, fragmented)';
  }

  @override
  String bstRtt(int avg, int min, int max) {
    return ', round trip avg $avg ms ($min-$max)';
  }

  @override
  String bstExchangeLine(String label, String small, String large, String rtt) {
    return '$label: $small, $large$rtt';
  }

  @override
  String get bstNothingBack =>
      'Nothing came back. The link was established but data does not flow; try again closer together, or toggle Bluetooth on both phones.';

  @override
  String get bstSomeLost =>
      'Some data was lost. Move closer together and test again.';

  @override
  String get bstSlowChunk =>
      'The link uses the Bluetooth minimum of 20 bytes per write, so messages will be slow. This happens when the phones fail to negotiate a larger size.';

  @override
  String get bstNoRelay =>
      'No phone is currently reachable only through a relay. Testing this needs three phones: A and C each in range of B but not of each other.';

  @override
  String bstRelayLine(String id, String via, int hops) {
    return '$id via $via ($hops links)';
  }

  @override
  String bstRelayOk(String lines) {
    return 'Reachable through a relay, based on signed announcements: $lines.';
  }

  @override
  String bstNetOffline(String text) {
    return '$text. Everything above ran without any internet connection.';
  }

  @override
  String bstNetOnline(String text) {
    return '$text. The app does not use it; to prove offline operation, switch Wi-Fi and mobile data off (or use airplane mode with Bluetooth on) and run the test again.';
  }

  @override
  String get setLanguage => 'Language';

  @override
  String get setLanguageBody =>
      'The language of the whole app. Kurdish is the main one.';

  @override
  String get setAppearance => 'Appearance';

  @override
  String get appearanceHeading => 'Theme';

  @override
  String get appearanceSystem => 'System default';

  @override
  String get appearanceSystemHelp =>
      'Follows your phone\'s light or dark setting.';

  @override
  String get appearanceLight => 'Light';

  @override
  String get appearanceLightHelp => 'A pale page with white layers.';

  @override
  String get appearanceDark => 'Dark';

  @override
  String get appearanceDarkHelp =>
      'A near-black page that is easy on the eyes at night.';

  @override
  String get themeSwitchToLight => 'Switch to the light theme';

  @override
  String get themeSwitchToDark => 'Switch to the dark theme';

  @override
  String get setName => 'Your name';

  @override
  String get setNameBody =>
      'Anyone nearby can see this name. It is not unique and nobody checks it: two people can pick the same one, which is why contacts show a short id too.';

  @override
  String get setNicknameHint => 'Nickname';

  @override
  String get setChangeName => 'Change name';

  @override
  String get setFingerprint => 'Your identity fingerprint';

  @override
  String get setFingerprintBody =>
      'Your contacts compare a safety number with you to be sure it is really you.';

  @override
  String get setFingerprintCopied => 'Fingerprint copied';

  @override
  String get setPermissions => 'Permissions';

  @override
  String get setNotifications => 'Notifications';

  @override
  String get setMeshBackground => 'The mesh in the background';

  @override
  String get setBluetooth => 'Bluetooth';

  @override
  String get setPrivacy => 'Privacy and security';

  @override
  String get setHonesty => 'How it works, and what it cannot do';

  @override
  String get setDanger => 'Danger zone';

  @override
  String get setSearchHow => 'How hard to look for people';

  @override
  String get modeBalanced => 'Balanced';

  @override
  String get modeLowPower => 'Battery saver';

  @override
  String get modeAggressive => 'Continuous';

  @override
  String get modeBalancedHelp => 'Searches about half of the time';

  @override
  String get modeLowPowerHelp =>
      'Searches briefly and rarely: saves battery, finds people slowly';

  @override
  String get modeAggressiveHelp =>
      'Searches non-stop: finds people fastest, uses the most battery';

  @override
  String get setSelfTest => 'Bluetooth self-test';

  @override
  String get setSelfTestBody =>
      'Check that this phone can find, connect to and talk to another phone';

  @override
  String get setInternet => 'Internet';

  @override
  String get setChecking => 'Checking…';

  @override
  String setInternetBody(String state) {
    return '$state. دەمەتەقێ never uses the internet; turn it off if you want to see it work without.';
  }

  @override
  String get netNone => 'No Wi-Fi or mobile data';

  @override
  String get netWifi => 'Wi-Fi is on (not used by this app)';

  @override
  String get netMobile => 'Mobile data is on (not used by this app)';

  @override
  String get netWired => 'Wired network (not used by this app)';

  @override
  String get netOther => 'Another network is on (not used by this app)';

  @override
  String get netUnknown => 'Network state unknown';

  @override
  String get setStorage => 'Storage';

  @override
  String get setStorageBody => 'What is kept on this phone, and how to free it';

  @override
  String get setKeepMessages => 'Keep messages';

  @override
  String get setKeepMessagesBody =>
      'Older messages are deleted from this phone';

  @override
  String get setRetForever => 'Forever';

  @override
  String get setRetDay => '1 day';

  @override
  String setRetDays(int days) {
    return '$days days';
  }

  @override
  String get setSecurityLog => 'Security log';

  @override
  String get setSecurityLogBody =>
      'Forged messages, failed identity checks, changed keys';

  @override
  String get setResetAction => 'Reset identity';

  @override
  String get setResetTileBody =>
      'Create new keys. Contacts must verify you again';

  @override
  String get setResetTitle => 'Reset your identity?';

  @override
  String get setResetBody =>
      'This creates a brand-new identity (new encryption and signing keys).\n\n• Your contacts will see you as a new, unverified person and must verify your new safety number.\n• Messages still travelling towards your old identity can no longer be read.\n• Messages waiting to be sent are discarded.\n• You can no longer take part in your groups (they know your old identity); your copies of those chats stay on this phone.\n• Your existing chats stay on this phone.\n\nThis cannot be undone.';

  @override
  String get setResetDone => 'You have a new identity';

  @override
  String get setClearTile => 'Delete all local data';

  @override
  String get setClearTileBody =>
      'Messages, pictures, contacts, groups and keys';

  @override
  String get setClearTitle => 'Delete everything on this phone?';

  @override
  String get setClearBody =>
      'This permanently deletes all messages, pictures, voice messages, contacts, groups, rooms and group keys, the security log and your settings, and creates a new identity.\n\nNobody else is told, and copies on other phones are not affected. This cannot be undone.';

  @override
  String get setClearAction => 'Delete everything';

  @override
  String get confirmWordDelete => 'delete';

  @override
  String get setClearDone => 'All local data was deleted';

  @override
  String setVersionLine(String name, String version, int protocol) {
    return '$name $version · protocol v$protocol';
  }

  @override
  String get setNotifyTitle => 'Message notifications';

  @override
  String get setNotifyBody =>
      'Tell me when a message arrives while the app is closed or in the background. Only for messages that are addressed to you.';

  @override
  String get setNotifyShows => 'What a notification shows';

  @override
  String get setNotifyFull => 'Name and message';

  @override
  String get setNotifySender => 'Name only';

  @override
  String get setNotifyHidden => 'Nothing (just \"new message\")';

  @override
  String get setNotifyFullHelp =>
      'Shows who wrote and what they wrote. Anyone who can see your lock screen can read it.';

  @override
  String get setNotifySenderHelp =>
      'Shows who wrote, not what. \"New message\".';

  @override
  String get setNotifyHiddenHelp =>
      'Shows only that something arrived. Neither who nor what.';

  @override
  String get setNotifyPublic => 'Public rooms too';

  @override
  String get setNotifyPublicBody =>
      'Off by default: a public room is everybody nearby talking and would never stop.';

  @override
  String get setRelayTitle => 'Help relay messages for others';

  @override
  String get setRelayOn =>
      'Your phone passes sealed messages on between people who are out of each other\'s range. It cannot read them. This is what makes the mesh reach further.';

  @override
  String get setRelayOff =>
      'Off: your phone receives what is for you and sends its own messages, but passes nothing on for anybody else. People who rely on you to reach each other will not get through.';

  @override
  String relayActivity(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Since the app started: passed on $count packets for others.',
      one: 'Since the app started: passed on 1 packet for others.',
    );
    return '$_temp0';
  }

  @override
  String relayActivityRefused(int count, int refused) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Since the app started: passed on $count packets for others, declined $refused because relaying is off.',
      one:
          'Since the app started: passed on 1 packet for others, declined $refused because relaying is off.',
    );
    return '$_temp0';
  }

  @override
  String get setKeepAliveTitle => 'Keep the mesh running in the background';

  @override
  String get setKeepAliveBody =>
      'Shows a notification while it runs, and uses some battery. Without it Android may stop Bluetooth work soon after you lock the phone, and some phones do so even with it. This has not been tested on real phones yet.';

  @override
  String get setKeepAliveRefused =>
      'Android did not allow it right now. Try again with the app on screen.';

  @override
  String get setBackgroundUse => 'Background use';

  @override
  String get setBackgroundUseBody =>
      'This phone suspends the app soon after you lock it or leave it, and nothing the app can ask for changes that. Messages are exchanged while the app is open.';

  @override
  String get setBatteryTitle => 'Battery restrictions';

  @override
  String get setBatteryRestricted =>
      'On: to save battery, Android may stop دەمەتەقێ in the background, even with the setting above. To keep the mesh running with the screen off, open the battery settings and choose \"Unrestricted\" (the words differ from phone to phone).';

  @override
  String get setBatteryUnrestricted =>
      'Off: Android lets دەمەتەقێ run in the background without battery restrictions. Some phone makers add restrictions of their own.';

  @override
  String get setBatteryOpen => 'Open battery settings';

  @override
  String get setBatteryCouldNotOpen =>
      'This phone did not open its battery settings. Look for دەمەتەقێ under Apps in the phone\'s settings.';

  @override
  String get setPermBluetooth => 'Bluetooth (nearby devices)';

  @override
  String get setPermBluetoothWhy =>
      'To find and talk to phones near you. Never your location.';

  @override
  String get setAllowed => 'Allowed';

  @override
  String get commonAllow => 'Allow';

  @override
  String get setPermMic => 'Microphone';

  @override
  String get setPermMicShort => 'Only while you record a voice message';

  @override
  String get setPermCamera => 'Camera';

  @override
  String get setPermCameraShort => 'Only to take a picture you want to send';

  @override
  String get setPermPhotos => 'Photos';

  @override
  String get setPermPhotosShort => 'Only to pick a picture you want to send';

  @override
  String get setPermNotifShort =>
      'Only to tell you a message arrived while the app is not on screen';

  @override
  String get honestyNoInternetTitle => 'No internet, no accounts, no servers';

  @override
  String get honestyNoInternetBody =>
      'Messages travel from phone to phone over Bluetooth Low Energy. Nothing is sent to the internet or to any company, and there is nothing to sign up for.';

  @override
  String get honestyRangeTitle => 'Range, relaying and waiting';

  @override
  String honestyRangeBody(
    int direct,
    int group,
    int directHours,
    int roomHours,
  ) {
    return 'One Bluetooth link reaches roughly 10 to 30 metres, less through walls. If phones with the app are in between, a message can hop through them: up to $direct hops for private messages and $group for groups and public rooms. If nobody is in reach, a private message or a group message is kept and retried for up to $directHours hours (public rooms: $roomHours hours), then it is marked as not delivered. Phones that pass group and public traffic along also keep it for people who arrive later. Relaying has been tested with simulated radios only; it has not yet been proven on real phones, so use the Bluetooth self-test and your own phones to see how it behaves in practice.';
  }

  @override
  String get honestyMediaTitle => 'Pictures, voice messages and videos';

  @override
  String honestyMediaBody(int seconds) {
    return 'Pictures are shrunk to a few dozen kilobytes (about 640 pixels wide), voice messages are limited to $seconds seconds, and videos are not shrunk at all: only a very short clip fits (you choose the limit under Settings > Storage). Bluetooth is slow: each hop takes a few seconds, more with several hops or a weak signal. Every file is checked against its SHA-256 before it is shown. In a group a picture or a video can stay incomplete if a piece of it is lost on every path; it then shows as not received. Videos cannot be sent to public rooms. Pictures, recordings and videos are kept in the app\'s private storage, not in your gallery, unless you choose \"Save to gallery\".';
  }

  @override
  String get honestyBackgroundTitle => 'The background is not guaranteed';

  @override
  String get honestyBackgroundBody =>
      'دەمەتەقێ works best while it is open. Phones restrict what apps may do with Bluetooth in the background, and this app does not try to get around that. On Android you can switch on \"Keep the mesh running in the background\": it shows a notification while it runs and lets the app stay alive more often, but it is no guarantee, and it has not been tested on real phones yet. Phones that are locked or have the app closed may relay nothing.';

  @override
  String get honestyPrivateTitle => 'Private chats';

  @override
  String get honestyPrivateBody =>
      'Private messages, pictures and voice messages are end-to-end encrypted: only the person you send to can read them, even when other phones pass them along. Phones that pass something along can see who sent it and who it is for (their public keys), roughly when, and its approximate size, but not the content. Anyone nearby can see that a phone is advertising دەمەتەقێ, and the name you chose.';

  @override
  String get honestyGroupsTitle => 'Groups';

  @override
  String get honestyGroupsBody =>
      'A group is private: its messages are encrypted with a key that only its members have, and nothing about it (its name, its members, that it exists) is ever broadcast. Only the person who created it can add or remove people, and every change gives the group a new key, so someone who was removed cannot read what is sent afterwards. They keep what they already received. If a key change reaches a member later than the messages sent right after it, those messages may be missed.';

  @override
  String get honestyRoomsTitle => 'Public rooms';

  @override
  String get honestyRoomsBody =>
      'A public room is NOT private. Everything said in it - text, pictures and voice - can be read by every phone that carries it, and by anyone who joins. Messages are signed, so a relay cannot change a word or forge an author, but names can be chosen freely: the short id after a name is what tells two people with the same name apart. The built-in #mesh room is for everyone nearby; rooms people create are announced to nearby phones and disappear after a day unless their creator\'s phone keeps renewing them. Messages in public rooms are removed from this phone six hours after they arrive.';

  @override
  String get honestyDeleteTitle => 'Deleting and editing';

  @override
  String get honestyDeleteBody =>
      'Delete for me removes a message from this phone only. Delete for everyone sends a request to the other phones: it works only if they receive it in time, and it cannot reach a copy somebody saved or photographed. Editing sends the new text in the same way. Both are possible for two days after a message is sent.';

  @override
  String get honestyVerifyTitle => 'Who are you really talking to?';

  @override
  String get honestyVerifyBody =>
      'The first time two phones meet, there is no way to know a key is really that person\'s. Open their contact page, compare the safety number with them in person or on a call you trust, and only then mark them verified. Until then, treat names as unverified.';

  @override
  String get honestyStoredTitle => 'What is stored on this phone';

  @override
  String get honestyStoredBody =>
      'Your keys (and the keys of your groups) are kept in the phone\'s secure storage (Android Keystore / iOS Keychain). Chat history, pictures and recordings are stored in the app\'s private storage without an extra layer of encryption beyond your phone\'s own lock screen and disk encryption, and on an iPhone they may be included in device backups. Anyone who unlocks your phone can read your chats.';

  @override
  String get honestyAuditTitle => 'Not independently audited';

  @override
  String get honestyAuditBody =>
      'The encryption uses standard algorithms (HPKE with X25519 and ChaCha20-Poly1305, Ed25519 signatures), and the core encryption is tested against the published test vectors. But this app\'s code has not been reviewed by an independent security expert. Do not rely on it where your safety or freedom depends on it.';

  @override
  String get reachDirectLong => 'Directly connected';

  @override
  String reachRelayLong(int hops) {
    String _temp0 = intl.Intl.pluralLogic(
      hops,
      locale: localeName,
      other: 'Via relay ($hops hops)',
      one: 'Via relay (1 hop)',
    );
    return '$_temp0';
  }

  @override
  String get reachOffline => 'Offline';

  @override
  String get reachDirectShort => 'Direct';

  @override
  String reachRelayShort(int hops) {
    String _temp0 = intl.Intl.pluralLogic(
      hops,
      locale: localeName,
      other: 'Relay · $hops hops',
      one: 'Relay · 1 hop',
    );
    return '$_temp0';
  }

  @override
  String get deliveryPending => 'Pending';

  @override
  String deliverySentCount(int done, int total) {
    return 'Sent · $done/$total';
  }

  @override
  String get deliverySent => 'Sent';

  @override
  String get deliveryDelivered => 'Delivered';

  @override
  String deliveryDeliveredVia(int hops) {
    String _temp0 = intl.Intl.pluralLogic(
      hops,
      locale: localeName,
      other: 'Delivered · $hops hops',
      one: 'Delivered · 1 hop',
    );
    return '$_temp0';
  }

  @override
  String get deliveryFailed => 'Not delivered';

  @override
  String get deliveryUndecryptable => 'Could not decrypt or verify';

  @override
  String get connError => 'Bluetooth error';

  @override
  String get connStarting => 'Starting…';

  @override
  String get connNotStarted => 'Not started';

  @override
  String get connNotSupported => 'Not supported';

  @override
  String get connPermissionNeeded => 'Permission needed';

  @override
  String get connBluetoothOff => 'Bluetooth off';

  @override
  String connNearbyRelayed(int direct, int relayed) {
    return '$direct nearby · $relayed via relay';
  }

  @override
  String connNearby(int direct) {
    return '$direct nearby';
  }

  @override
  String connViaRelay(int relayed) {
    return '$relayed via relay';
  }

  @override
  String get connSearching => 'Searching…';

  @override
  String get offlineTipNone =>
      'There is no internet connection. دەمەتەقێ does not need one: messages travel by Bluetooth.';

  @override
  String get offlineTipOn =>
      'The phone has internet, but دەمەتەقێ does not use it: messages travel by Bluetooth.';

  @override
  String get offlineBadge => 'Offline';

  @override
  String get internetOnBadge => 'Internet on';

  @override
  String navUnreadLabel(String label, int count) {
    return '$label, $count unread';
  }

  @override
  String peerSeenAgo(String ago) {
    return 'seen $ago';
  }

  @override
  String get peerNoKeyYet => 'no encryption key yet';

  @override
  String get commonStart => 'Start';

  @override
  String get commonOpenSettings => 'Open settings';

  @override
  String get commonDismiss => 'Dismiss';

  @override
  String get radioCouldNotStart => 'Bluetooth could not start';

  @override
  String get radioNotStarted => 'Bluetooth is not started';

  @override
  String get radioNotStartedBody =>
      'دەمەتەقێ needs Bluetooth to find and talk to nearby phones.';

  @override
  String get radioNotVisible => 'This phone can\'t be found by others';

  @override
  String get radioNotVisibleBody =>
      'It can find and connect to other phones, but it cannot advertise itself over Bluetooth. Two phones that both lack this cannot connect to each other.';

  @override
  String get radioNoBle => 'Bluetooth Low Energy is not available';

  @override
  String get radioNoBleBody =>
      'This device does not support the Bluetooth feature دەمەتەقێ is built on, so it cannot take part in the mesh.';

  @override
  String get radioPermission => 'Bluetooth permission needed';

  @override
  String get radioPermissionBody =>
      'دەمەتەقێ needs permission to use Bluetooth (the \"Nearby devices\" permission on recent Android, Bluetooth on iPhone) to find and talk to nearby phones. It never uses your location.';

  @override
  String get radioAllow => 'Allow Bluetooth';

  @override
  String get radioOff => 'Bluetooth is turned off';

  @override
  String get radioOffBody =>
      'Switch Bluetooth on in your phone\'s quick settings. دەمەتەقێ will reconnect to nearby phones by itself.';

  @override
  String get radioProblem => 'Bluetooth problem';

  @override
  String get identityResetTitle => 'Your identity was reset';

  @override
  String get identityResetBody =>
      'Your encryption keys could not be read from this phone\'s secure storage, so a new identity was created. Your contacts will need to verify you again, and messages sent to your old identity can no longer be read.';

  @override
  String get versionNewerTitle => 'A newer دەمەتەقێ is nearby';

  @override
  String get versionNewerBody =>
      'A phone near you runs a newer version of دەمەتەقێ. The two phones cannot talk to each other until this one is updated too.';

  @override
  String get versionOlderTitle => 'A phone nearby needs an update';

  @override
  String get versionOlderBody =>
      'A phone near you runs an older version of دەمەتەقێ. The two phones cannot talk to each other until that one is updated too.';

  @override
  String get permMicTitle => 'Allow the microphone?';

  @override
  String get permMicWhy =>
      'دەمەتەقێ needs the microphone only while you are recording a voice message.';

  @override
  String get permMicPrivacy =>
      'The recording goes over Bluetooth to the people in that chat and is never uploaded anywhere. Nothing is recorded when you are not holding a recording open.';

  @override
  String get permMicThing => 'the microphone';

  @override
  String get permMicOff => 'The microphone is switched off';

  @override
  String get permCameraTitle => 'Allow the camera?';

  @override
  String get permCameraWhy =>
      'دەمەتەقێ needs the camera to take a picture you want to send.';

  @override
  String get permCameraPrivacy =>
      'The picture is shrunk and sent over Bluetooth to the people in that chat. It is not saved to your gallery and never uploaded anywhere.';

  @override
  String get permCameraThing => 'the camera';

  @override
  String get permCameraOff => 'The camera is switched off';

  @override
  String get permPhotosTitle => 'Allow access to your photos?';

  @override
  String get permPhotosWhy =>
      'دەمەتەقێ needs to open your photo library so you can pick a picture to send.';

  @override
  String get permPhotosPrivacy =>
      'Only the picture you choose is used. It is shrunk and sent over Bluetooth to the people in that chat, and never uploaded anywhere.';

  @override
  String get permPhotosThing => 'your photos';

  @override
  String get permPhotosOff => 'Access to your photos is switched off';

  @override
  String get permNotifTitle => 'Allow notifications?';

  @override
  String get permNotifWhy =>
      'دەمەتەقێ uses notifications to tell you when a message arrives while the app is closed or in the background.';

  @override
  String get permNotifPrivacy =>
      'You choose how much a notification shows: the name and the message, only the name, or nothing but \"new message\". Notifications are made on this phone from messages that reached it; nothing is sent to any server.';

  @override
  String get permNotifThing => 'notifications';

  @override
  String get permNotifOff => 'Notifications are switched off';

  @override
  String get permNotAvailable => 'Not available';

  @override
  String permUnavailableBody(String thing) {
    return 'This phone does not allow دەمەتەقێ to use $thing (it may be restricted by a parent or an administrator).';
  }

  @override
  String get permNotNow => 'Not now';

  @override
  String get permTurnOnInSettings =>
      'To use it, turn it on for دەمەتەقێ in your phone\'s settings. Nothing else in the app needs it.';

  @override
  String get voicePause => 'Pause voice message';

  @override
  String get voicePlay => 'Play voice message';

  @override
  String get mediaNotReceived => 'Could not be received';

  @override
  String mediaReceiving(int percent) {
    return 'Receiving… $percent%';
  }

  @override
  String get pictureNotReceived => 'Picture could not be received';

  @override
  String get videoCannotPlay => 'This video cannot be played on this phone.';

  @override
  String get videoNotReceived => 'Video could not be received';

  @override
  String videoReceiving(int percent) {
    return 'Receiving video… $percent%';
  }

  @override
  String get videoPlay => 'Play video';

  @override
  String introDirectTitle(String name) {
    return 'Say hello to $name';
  }

  @override
  String introGroupTitle(String name) {
    return 'Welcome to $name';
  }

  @override
  String get fwdNoVideoInRooms => 'A video cannot go to a public room';

  @override
  String get setNotifyNotAllowed =>
      'Notifications are on here, but the phone has not allowed them yet, so none will appear.';
}
