/// Delivery state of a chat message.
enum MessageStatus {
  /// Outgoing: stored, waiting for a usable route (the "pending" state).
  queued,

  /// Outgoing: handed to at least one neighbour; no receipt yet.
  sent,

  /// Outgoing: the recipient's signed acknowledgement arrived (for a group:
  /// every other member's).
  delivered,

  /// Outgoing: expired or retries exhausted without a receipt.
  failed,

  /// Incoming: decrypted and verified.
  received,

  /// Incoming: addressed to us and correctly signed, but could not be
  /// decrypted/authenticated (corrupted, tampered, wrong key or password).
  undecryptable;

  static MessageStatus parse(String name) => MessageStatus.values.firstWhere(
        (s) => s.name == name,
        orElse: () => MessageStatus.failed,
      );

  bool get isOutgoingState =>
      this == queued || this == sent || this == delivered || this == failed;

  /// Monotonic ordering for outgoing messages, so a late "sent" event can
  /// never overwrite "delivered".
  int get rank => switch (this) {
        queued => 0,
        sent => 1,
        delivered => 2,
        failed => 0,
        received => 0,
        undecryptable => 0,
      };
}

/// What a message contains.
enum MessageKind {
  text,
  image,
  voice,
  video;

  static MessageKind parse(String name) => MessageKind.values.firstWhere(
        (k) => k.name == name,
        orElse: () => MessageKind.text,
      );

  bool get isMedia => this != text;
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    this.senderNickname,
    required this.isOutgoing,
    this.kind = MessageKind.text,
    required this.body,
    this.mediaId,
    required this.sortTimeMs,
    required this.claimedTimestampMs,
    required this.status,
    this.hops = 0,
    this.error,
    this.recipientCount = 0,
    this.receiptCount = 0,
    this.replyToId,
    this.forwardedFrom,
    this.editedAtMs,
    this.editVersion = 0,
    this.expiresAtMs,
  });

  /// Message id (hex). Unique across the app: inserting a duplicate is a no-op,
  /// which is what stops relayed or retransmitted copies from creating
  /// duplicate chat entries.
  final String id;
  final String conversationId;

  /// Hex signing key of the author (our own id for outgoing messages).
  final String senderId;
  final String? senderNickname;
  final bool isOutgoing;
  final MessageKind kind;

  /// The text of a text message, or the caption of an image / voice message.
  final String body;

  /// Hex id of the attached [MediaItem], for image and voice messages.
  final String? mediaId;

  /// LOCAL time the message was created or received. Used for ordering so a
  /// sender with a wrong clock cannot reorder history.
  final int sortTimeMs;

  /// The sender's own clock (advisory only; shown if it disagrees a lot).
  final int claimedTimestampMs;
  final MessageStatus status;

  /// Incoming: relays traversed. Outgoing: relays on the receipt's path.
  final int hops;
  final String? error;

  /// Outgoing group messages: how many other members should receive it, and
  /// how many have confirmed so far.
  final int recipientCount;
  final int receiptCount;

  /// The message this one answers (hex id). Only the id is stored: what is
  /// quoted is looked up when shown, so nothing of a deleted message lingers.
  final String? replyToId;

  /// The name of the person who wrote this originally, if it was forwarded.
  final String? forwardedFrom;

  /// When the text was last edited (local time), and which edit that was.
  final int? editedAtMs;
  final int editVersion;

  /// Public rooms only: when this phone removes the message. Null = never.
  final int? expiresAtMs;

  bool get isMedia => kind.isMedia;

  bool get isEdited => editedAtMs != null;

  bool get isForwarded => forwardedFrom != null;

  ChatMessage copyWith({MessageStatus? status, int? hops, String? error, String? body}) =>
      ChatMessage(
        id: id,
        conversationId: conversationId,
        senderId: senderId,
        senderNickname: senderNickname,
        isOutgoing: isOutgoing,
        kind: kind,
        body: body ?? this.body,
        mediaId: mediaId,
        sortTimeMs: sortTimeMs,
        claimedTimestampMs: claimedTimestampMs,
        status: status ?? this.status,
        hops: hops ?? this.hops,
        error: error ?? this.error,
        recipientCount: recipientCount,
        receiptCount: receiptCount,
        replyToId: replyToId,
        forwardedFrom: forwardedFrom,
        editedAtMs: editedAtMs,
        editVersion: editVersion,
        expiresAtMs: expiresAtMs,
      );
}
