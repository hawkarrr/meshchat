import 'dart:convert';

import '../database/message_repository.dart';
import '../l10n/l10n.dart';
import '../models/conversation.dart';
import '../protocol/protocol_constants.dart';
import '../protocol/envelope.dart';

enum MessageErrorKind {
  empty,
  tooLong,
  unknownPeer,
  noEncryptionKey,
  blocked,
  notRetryable,
  unknownConversation,
  invalidName,
  noMembers,
  tooManyMembers,
  unknownGroup,
  groupNotActive,
  notAdmin,
  unknownRoom,
  notJoined,
  mediaTooLarge,
  invalidMedia,

  /// The message is gone (deleted, expired) or never existed here.
  unknownMessage,

  /// Not allowed for this person or this kind of message.
  notAllowed,

  /// Past the time limit for editing or deleting for everyone.
  tooOld,
}

/// A problem with a request that the UI can explain to the user.
class MessageError implements Exception {
  const MessageError(this.kind, this.message);

  final MessageErrorKind kind;
  final String message;

  @override
  String toString() => message;
}

/// Trims [raw] and checks it is a sendable text message: not empty and within
/// the size limit. Throws a [MessageError] the UI can show.
String validateMessageText(String raw, AppLocalizations l) {
  final text = raw.trim();
  if (text.isEmpty) {
    throw MessageError(MessageErrorKind.empty, l.errTypeFirst);
  }
  final bytes = utf8.encode(text).length;
  if (bytes > Protocol.maxTextBytes) {
    throw MessageError(
      MessageErrorKind.tooLong,
      l.errMessageTooLong(bytes, Protocol.maxTextBytes),
    );
  }
  return text;
}

/// Checks that [replyToId] names a message of [conversationId] (so a reply can
/// only ever point inside its own conversation). Null is fine: not a reply.
Future<void> validateReplyTarget(
    MessageRepository repo, String conversationId, String? replyToId, AppLocalizations l) async {
  if (replyToId == null) return;
  final target = await repo.getMessage(replyToId);
  if (target == null || target.conversationId != conversationId) {
    throw MessageError(MessageErrorKind.unknownMessage, l.errReplyGone);
  }
}

/// What an [IncomingNotice] is about.
enum NoticeKind {
  /// A new message in a conversation.
  message,

  /// Somebody invited us to a group.
  groupInvite,

  /// A message arrived that could not be decrypted or verified.
  failure,
}

/// A new incoming message (or invitation), for notifications and unread badges.
class IncomingNotice {
  const IncomingNotice({
    required this.conversationId,
    required this.title,
    required this.type,
    this.kind = NoticeKind.message,
    this.messageId,
    this.preview,
    this.mediaKind,
    this.sender,
  });

  final String conversationId;
  final String title;
  final ConversationType type;
  final NoticeKind kind;

  /// The message that arrived, what to show of it (its text, or - for a picture,
  /// voice message or video - which kind it was, to be worded in the language of
  /// the notification) and who wrote it, for a notification. Null for notices
  /// that are not about one message.
  final String? messageId;
  final String? preview;
  final MediaKind? mediaKind;
  final String? sender;

  bool get isInvite => kind == NoticeKind.groupInvite;

  /// The message could not be decrypted / verified.
  bool get verifiedFailure => kind == NoticeKind.failure;
}
