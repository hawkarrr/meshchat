import 'dart:async';
import 'dart:typed_data';

import '../core/app_log.dart';
import '../core/bytes.dart';
import '../core/text.dart';
import '../crypto/hpke.dart';
import '../database/message_repository.dart';
import '../database/outbox_repository.dart';
import '../mesh/mesh_router.dart';
import '../models/conversation.dart';
import '../models/message.dart';
import '../models/peer.dart';
import '../protocol/mesh_packet.dart';
import '../protocol/protocol_constants.dart';
import '../transport/mesh_transport.dart';
import 'encryption_service.dart';
import 'group_keyring.dart';
import 'group_service.dart';
import 'media_service.dart';
import 'message_actions.dart';
import 'message_errors.dart';
import 'public_chat_cleanup.dart';
import 'room_service.dart';
import 'service_context.dart';

export 'media_service.dart' show MediaConfig, MediaDraft, MediaStore, MemoryMediaStore, FileMediaStore;
export 'message_actions.dart' show DeleteResult, MessageActions, MessagePolicy;
export 'message_errors.dart';
export 'public_chat_cleanup.dart' show CleanupResult, PublicChatCleanup;
import '../models/delivery_problem.dart';

/// The Message Manager: everything between "the user typed a message" and
/// "bytes handed to the router", and back again - for private chats, groups
/// and public rooms alike, for text, images and voice messages.
///
/// Outgoing: validates, encrypts (or signs) for the recipients, stores the
/// message as pending, and gives the sealed packets to the router.
/// Incoming (as the router's delegate): decrypts what is addressed to us,
/// stores it exactly once, acknowledges it, tracks delivery receipts, and
/// records - rather than hides - anything that fails verification.
class MessageService implements MeshDelegate {
  MessageService({
    required this.context,
    required GroupKeyring keyring,
    required MediaStore mediaStore,
    MediaConfig mediaConfig = const MediaConfig(),
    MessagePolicy policy = const MessagePolicy(),
  }) {
    media = MediaService(context, mediaStore, config: mediaConfig);
    groups = GroupService(context, keyring, media);
    rooms = RoomService(context, media);
    actions = MessageActions(context, groups, rooms, media, policy: policy);
    groups.controls = actions.onControl;
    rooms.controls = actions.onControl;
    publicCleanup = PublicChatCleanup(context, media);
  }

  final ServiceContext context;
  late final MediaService media;
  late final GroupService groups;
  late final RoomService rooms;

  /// Deleting and editing messages, and applying other phones' requests to.
  late final MessageActions actions;

  /// The six-hour clean-up of public rooms.
  late final PublicChatCleanup publicCleanup;

  static const String _tag = 'Messages';

  EncryptionService get crypto => context.crypto;
  MessageRepository get repo => context.repo;
  AppLog get _log => context.log;

  final Map<String, int> _lastReAckMs = <String, int>{};

  Stream<IncomingNotice> get incoming => context.notices;

  String get ownId => context.ownId;

  /// True while receipts are waiting to be sent.
  bool get hasPendingWork => context.acks.hasPending;

  /// Prepares what the app needs before the first message: the `#mesh` room.
  Future<void> start() async {
    await rooms.start();
    // Anything that ran out of time while the app was closed goes first.
    await publicCleanup.run();
  }

  /// Periodic housekeeping (incomplete media, expired rooms and public messages).
  Future<void> maintain() async {
    await media.maintain();
    await rooms.maintain();
    await publicCleanup.run();
  }

  Future<void> dispose() => context.dispose();

  // ---------------------------------------------------------------------------
  // Sending
  // ---------------------------------------------------------------------------

  /// A contact we can encrypt to.
  Future<Peer> _sendablePeer(String peerId) async {
    final peer = await repo.getPeer(peerId);
    if (peer == null) {
      throw MessageError(MessageErrorKind.unknownPeer, context.l10n.errUnknownContact);
    }
    if (peer.blocked) {
      throw MessageError(
          MessageErrorKind.blocked, context.l10n.errBlockedContact);
    }
    if (peer.agreementKey == null) {
      throw MessageError(
        MessageErrorKind.noEncryptionKey,
        context.l10n.errNoKey,
      );
    }
    return peer;
  }

  /// Sends an end-to-end encrypted message to a contact.
  ///
  /// The returned message is already stored with status `queued`; it moves to
  /// `sent` when a neighbour has it and `delivered` when the recipient's
  /// signed receipt arrives.
  Future<ChatMessage> sendDirect(String peerId, String rawText,
      {String? replyToId, String? forwardedFrom}) async {
    final text = validateMessageText(rawText, context.l10n);
    final peer = await _sendablePeer(peerId);
    await validateReplyTarget(repo, Conversation.directId(peerId), replyToId, context.l10n);

    final MeshPacket packet;
    try {
      packet = await crypto.buildDirectEnvelope(
        recipientSigningKey: peer.signingKey,
        recipientAgreementKey: peer.agreementKey!,
        envelope: TextEnvelope(text,
            replyTo: replyToId == null ? null : hexToBytes(replyToId),
            forwardedFrom: forwardedFrom),
      );
    } on HpkeException {
      throw MessageError(
        MessageErrorKind.noEncryptionKey,
        context.l10n.errKeyUnusable,
      );
    } on ArgumentError catch (e) {
      throw MessageError(MessageErrorKind.noEncryptionKey, '${e.message}');
    }

    final now = context.clock.nowMs;
    final conversation = await repo.ensureDirectConversation(peer, nowMs: now);
    await repo.setContact(peer.id, true);
    final message = ChatMessage(
      id: packet.messageIdHex,
      conversationId: conversation.id,
      senderId: ownId,
      isOutgoing: true,
      body: text,
      sortTimeMs: now,
      claimedTimestampMs: packet.timestampMs,
      status: MessageStatus.queued,
      replyToId: replyToId,
      forwardedFrom: forwardedFrom,
    );
    await repo.insertMessage(message);
    await _submitOrFail(packet);
    return message;
  }

  Future<void> _submitOrFail(MeshPacket packet) async {
    final id = packet.messageIdHex;
    final outcome = await context.router.submit(packet);
    if (outcome != SubmitOutcome.queued) {
      await repo.updateOutgoingStatus(id, MessageStatus.failed,
          error: DeliveryProblem.queueFailed.code);
    }
  }

  static const String _directPrefix = 'dm:';

  Future<Conversation> _conversation(String conversationId) async {
    final existing = await repo.getConversation(conversationId);
    if (existing != null) return existing;
    // A private chat with someone we know exists as soon as we want to write
    // to them, even if nothing was ever said.
    if (conversationId.startsWith(_directPrefix)) {
      final peer = await repo.getPeer(conversationId.substring(_directPrefix.length));
      if (peer != null) {
        return repo.ensureDirectConversation(peer, nowMs: context.clock.nowMs);
      }
    }
    throw MessageError(
        MessageErrorKind.unknownConversation, context.l10n.errNoConversation);
  }

  /// Sends a text message to a private chat, group or public room. [replyToId]
  /// makes it an answer to a message of the same conversation; [forwardedFrom]
  /// marks it as passed on from somebody else.
  Future<ChatMessage> sendText(String conversationId, String text,
      {String? replyToId, String? forwardedFrom}) async {
    final c = await _conversation(conversationId);
    final from = _cleanForwardName(forwardedFrom);
    return switch (c.type) {
      ConversationType.direct =>
        sendDirect(c.peerId!, text, replyToId: replyToId, forwardedFrom: from),
      ConversationType.group =>
        groups.sendText(c.groupId!, text, replyToId: replyToId, forwardedFrom: from),
      ConversationType.room =>
        rooms.sendText(c.roomId!, text, replyToId: replyToId, forwardedFrom: from),
    };
  }

  String? _cleanForwardName(String? name) {
    if (name == null) return null;
    final clean = sanitizeDisplayName(name, maxBytes: Protocol.maxNicknameBytes);
    return clean.isEmpty ? context.l10n.unknownAuthor : clean;
  }

  /// Passes the given messages on to another conversation, oldest first, as new
  /// messages marked with who wrote them. Pictures and voice messages are sent
  /// again from the stored file. Nothing but the message itself is sent: no keys,
  /// and nothing else from the conversation it came from. A message that cannot
  /// be forwarded (not readable, or its file is not complete) is skipped.
  Future<List<ChatMessage>> forward(List<String> ids, String targetConversationId) async {
    final messages = await repo.getMessagesByIds(ids);
    // Said before anything is sent: a selection must not go half way, with the text
    // in front of a video delivered and the rest refused.
    final target = await _conversation(targetConversationId);
    if (target.type == ConversationType.room && messages.any((m) => m.kind == MessageKind.video)) {
      throw MessageError(MessageErrorKind.notAllowed, context.l10n.errVideoNotInRooms);
    }
    final sent = <ChatMessage>[];
    for (final m in messages) {
      if (m.status == MessageStatus.undecryptable) continue;
      var from = m.forwardedFrom;
      if (from == null) {
        if (m.isOutgoing) {
          from = context.ownNickname;
        } else {
          from = m.senderNickname ?? (await repo.getPeer(m.senderId))?.displayName;
        }
      }
      if (m.kind == MessageKind.text) {
        sent.add(await sendText(targetConversationId, m.body, forwardedFrom: from ?? context.l10n.unknownAuthor));
        continue;
      }
      final item = m.mediaId == null ? null : await context.mediaRepo.get(m.mediaId!);
      final bytes = item == null || !item.isReady ? null : await media.read(item);
      if (item == null || bytes == null) continue;
      sent.add(await sendMedia(
        targetConversationId,
        MediaDraft(
          kind: item.kind,
          bytes: bytes,
          width: item.width,
          height: item.height,
          durationMs: item.durationMs,
          waveform: item.waveform,
          caption: m.body,
          forwardedFrom: _cleanForwardName(from ?? context.l10n.unknownAuthor),
        ),
      ));
    }
    return sent;
  }

  /// Pins or unpins a message for this person only. Nobody else is told.
  Future<bool> setPinned(String conversationId, String messageId, bool pinned) =>
      repo.setPinned(conversationId, messageId, pinned, context.clock.nowMs);

  /// Sends an image or a voice message to a private chat, group or room.
  Future<ChatMessage> sendMedia(String conversationId, MediaDraft draft) async {
    final c = await _conversation(conversationId);
    await validateReplyTarget(repo, c.id, draft.replyToId, context.l10n);
    final MediaRoute route;
    switch (c.type) {
      case ConversationType.direct:
        route = DirectMediaRoute(await _sendablePeer(c.peerId!));
        await repo.setContact(c.peerId!, true);
      case ConversationType.group:
        route = await groups.mediaRoute(c.groupId!);
      case ConversationType.room:
        route = await rooms.mediaRoute(c.roomId!);
    }
    return media.send(conversation: c, route: route, draft: draft);
  }

  /// Sends a failed message again as a fresh message.
  Future<ChatMessage> retry(String messageId) async {
    final old = await repo.getMessage(messageId);
    if (old == null || !old.isOutgoing || old.status != MessageStatus.failed) {
      throw MessageError(MessageErrorKind.notRetryable, context.l10n.errCannotResend);
    }
    final conversation = await repo.getConversation(old.conversationId);
    if (conversation == null) {
      throw MessageError(MessageErrorKind.notRetryable, context.l10n.errNoConversation);
    }
    final ChatMessage fresh;
    if (old.kind == MessageKind.text) {
      fresh = await sendText(conversation.id, old.body);
    } else {
      final item = old.mediaId == null ? null : await context.mediaRepo.get(old.mediaId!);
      final bytes = item == null ? null : await media.read(item);
      if (item == null || bytes == null) {
        throw MessageError(MessageErrorKind.notRetryable, context.l10n.errFileGone);
      }
      fresh = await sendMedia(
        conversation.id,
        MediaDraft(
          kind: item.kind,
          bytes: bytes,
          width: item.width,
          height: item.height,
          durationMs: item.durationMs,
          waveform: item.waveform,
          caption: old.body,
        ),
      );
    }
    await repo.deleteMessage(old.id);
    return fresh;
  }

  // ---------------------------------------------------------------------------
  // MeshDelegate: what the router asks
  // ---------------------------------------------------------------------------

  @override
  Future<bool> wantsGroup(Uint8List groupId) => groups.isActive(groupId);

  @override
  Future<bool> wantsRoom(Uint8List roomId) => rooms.isJoined(roomId);

  @override
  Future<MeshPacket?> buildAnnouncement() =>
      crypto.buildAnnounce(nickname: context.ownNickname);

  @override
  Future<List<MeshPacket>> buildRoomAnnouncements() => rooms.buildAnnouncements();

  // ---------------------------------------------------------------------------
  // MeshDelegate: events from the router
  // ---------------------------------------------------------------------------

  @override
  Future<void> onAnnounce(
    MeshPacket packet,
    AnnounceContent content, {
    required int relayHops,
  }) async {
    await _recordPeer(
      packet.senderKey,
      content.agreementKey,
      sanitizeDisplayName(content.nickname),
    );
  }

  @override
  Future<void> onNeighborUp(NeighborInfo neighbor) async {
    // The link handshake already proved this phone owns its signing key, and
    // its agreement key was covered by that proof.
    await _recordPeer(neighbor.signingKey, neighbor.agreementKey, neighbor.nickname);
  }

  @override
  Future<void> onNeighborDown(String peerId) async {}

  Future<void> _recordPeer(Uint8List signingKey, Uint8List agreementKey, String nick) async {
    final now = context.clock.nowMs;
    final update = await repo.upsertPeer(
      signingKey: signingKey,
      agreementKey: agreementKey,
      nickname: nick,
      seenAtMs: now,
    );
    if (update.keyChanged) {
      _log.w(_tag, 'encryption key of ${update.peer.shortId} changed');
      await repo.recordSecurityEvent(
        SecurityEventKind.keyChanged,
        peerId: update.peer.id,
        detail: 'Encryption key changed; verification was reset',
        atMs: now,
      );
    }
  }

  // ---- direct packets -------------------------------------------------------

  @override
  Future<void> onDirectMessage(MeshPacket packet, {required int relayHops}) async {
    final now = context.clock.nowMs;
    final senderId = packet.senderHex;
    final known = await repo.getPeer(senderId);
    if (known?.blocked ?? false) {
      _log.d(_tag, 'dropped a message from blocked ${senderId.substring(0, 8)}');
      return;
    }
    final peer = (await repo.upsertPeer(signingKey: packet.senderKey, seenAtMs: now)).peer;

    if (packet.isChunk) {
      if (await media.onDirectChunk(packet)) {
        context.acks.add(packet.senderKey, packet.messageId);
      }
      return;
    }

    final Envelope envelope;
    try {
      envelope = await crypto.openDirectEnvelope(packet);
    } on DecryptionFailure catch (e) {
      await _storeUndecryptable(packet, peer, e, relayHops);
      return;
    }

    switch (envelope) {
      case TextEnvelope():
        await _storeDirectText(packet, peer, envelope, relayHops);
      case MediaEnvelope():
        await _storeDirectMedia(packet, peer, envelope, relayHops);
      case EditEnvelope():
      case DeleteEnvelope():
        // Only inside a chat that already exists: a request must not create one.
        final chat = await repo.getConversation(Conversation.directId(peer.id));
        if (chat != null && await actions.onControl(chat, peer.id, envelope)) {
          context.acks.add(packet.senderKey, packet.messageId);
        }
      case GroupSnapshot():
        if (await groups.onSnapshot(packet, envelope)) {
          context.acks.add(packet.senderKey, packet.messageId);
        }
      case GroupRemovedEnvelope():
        if (await groups.onRemoved(packet, envelope)) {
          context.acks.add(packet.senderKey, packet.messageId);
        }
      case GroupLeaveEnvelope():
        if (await groups.onLeft(packet, envelope)) {
          context.acks.add(packet.senderKey, packet.messageId);
        }
    }
  }

  /// Correctly signed by a known key, but unreadable: tampered with,
  /// corrupted, or encrypted to a key that is not ours. Say so.
  Future<void> _storeUndecryptable(
    MeshPacket packet,
    Peer peer,
    DecryptionFailure e,
    int relayHops,
  ) async {
    final now = context.clock.nowMs;
    _log.w(_tag, 'could not decrypt a message from ${peer.shortId}: ${e.reason.name}');
    await repo.recordSecurityEvent(
      SecurityEventKind.decryptFailed,
      peerId: peer.id,
      detail: e.reason.name,
      atMs: now,
    );
    final conversation = await repo.ensureDirectConversation(peer, nowMs: now);
    final inserted = await repo.insertMessage(ChatMessage(
      id: packet.messageIdHex,
      conversationId: conversation.id,
      senderId: peer.id,
      isOutgoing: false,
      body: '',
      sortTimeMs: now,
      claimedTimestampMs: packet.timestampMs,
      status: MessageStatus.undecryptable,
      hops: relayHops,
      error: e.reason.name,
    ));
    if (inserted) {
      context.notify(IncomingNotice(
        conversationId: conversation.id,
        title: peer.displayName,
        type: ConversationType.direct,
        kind: NoticeKind.failure,
      ));
    }
  }

  Future<void> _storeDirectText(
      MeshPacket packet, Peer peer, TextEnvelope envelope, int relayHops) async {
    final text = envelope.text;
    final now = context.clock.nowMs;
    final conversation = await repo.ensureDirectConversation(peer, nowMs: now);
    final inserted = await repo.insertMessage(ChatMessage(
      id: packet.messageIdHex,
      conversationId: conversation.id,
      senderId: peer.id,
      isOutgoing: false,
      body: text,
      sortTimeMs: now,
      claimedTimestampMs: packet.timestampMs,
      status: MessageStatus.received,
      hops: relayHops,
      replyToId: envelope.replyTo == null ? null : bytesToHex(envelope.replyTo!),
      forwardedFrom: envelope.forwardedFrom == null
          ? null
          : sanitizeDisplayName(envelope.forwardedFrom!, maxBytes: Protocol.maxNicknameBytes),
    ));
    // Acknowledge even a message we already had: our earlier receipt may have
    // been lost.
    context.acks.add(packet.senderKey, packet.messageId);
    if (inserted) {
      context.notify(IncomingNotice(
        conversationId: conversation.id,
        title: peer.displayName,
        type: ConversationType.direct,
        messageId: packet.messageIdHex,
        preview: text,
        sender: peer.displayName,
      ));
    }
  }

  Future<void> _storeDirectMedia(
    MeshPacket packet,
    Peer peer,
    MediaEnvelope manifest,
    int relayHops,
  ) async {
    if (manifest.key == null) {
      // Without the key the chunks could never be opened: not a valid private
      // media message.
      await repo.recordSecurityEvent(
        SecurityEventKind.malformed,
        peerId: peer.id,
        detail: 'private media message without a key',
        atMs: context.clock.nowMs,
      );
      return;
    }
    final now = context.clock.nowMs;
    final conversation = await repo.ensureDirectConversation(peer, nowMs: now);
    final stored = await media.onManifest(
      packet: packet,
      manifest: manifest,
      conversation: conversation,
      relayHops: relayHops,
    );
    context.acks.add(packet.senderKey, packet.messageId);
    if (stored) {
      context.notify(IncomingNotice(
        conversationId: conversation.id,
        title: peer.displayName,
        type: ConversationType.direct,
        messageId: packet.messageIdHex,
        mediaKind: manifest.mediaKind,
        sender: peer.displayName,
      ));
    }
  }

  @override
  Future<void> onDuplicateDirect(MeshPacket packet) async {
    final id = packet.messageIdHex;
    final now = context.clock.nowMs;
    final last = _lastReAckMs[id];
    if (last != null && now - last < 10000) return;

    // Only confirm what we really have: a repeat of something we had to drop
    // must not make the sender believe it arrived.
    final bool have;
    if (packet.isChunk) {
      have = await media.holdsChunk(packet);
    } else {
      final stored = await repo.getMessage(id);
      have = stored != null && stored.status == MessageStatus.received;
    }
    if (!have) return;
    _lastReAckMs[id] = now;
    if (_lastReAckMs.length > 500) _lastReAckMs.remove(_lastReAckMs.keys.first);
    context.acks.add(packet.senderKey, packet.messageId);
  }

  // ---- group and room packets -----------------------------------------------

  @override
  Future<void> onGroupPacket(MeshPacket packet, {required int relayHops}) =>
      groups.onGroupPacket(packet, relayHops: relayHops);

  @override
  Future<void> onRoomPacket(MeshPacket packet, {required int relayHops}) =>
      rooms.onRoomPacket(packet, relayHops: relayHops);

  @override
  Future<bool> onRoomAnnounce(MeshPacket packet, RoomRecord record, {required int relayHops}) =>
      rooms.onAnnounce(packet, record);

  // ---- receipts ----------------------------------------------------------------

  @override
  Future<void> onAck(MeshPacket packet, AckContent ack, {required int relayHops}) async {
    final from = packet.senderHex;
    for (final id in ack.ackedMessageIdsHex) {
      // A delete request of ours, confirmed by the other person of a private chat.
      await actions.onControlAcked(id, from);
      // A part (manifest or chunk) of a private image / voice message.
      final owner = await context.mediaRepo.messageOfPart(id);
      if (owner != null) {
        await _onMediaPartAck(owner, id, from, relayHops);
        continue;
      }
      final message = await repo.getMessage(id);
      if (message == null || !message.isOutgoing) continue;
      final conversation = await repo.getConversation(message.conversationId);
      if (conversation == null) continue;
      switch (conversation.type) {
        case ConversationType.direct:
          // Only the intended recipient's receipt counts.
          if (conversation.peerId != from) {
            _log.w(_tag, 'ignored a receipt from the wrong sender');
            continue;
          }
          await repo.updateOutgoingStatus(message.id, MessageStatus.delivered, hops: relayHops);
        case ConversationType.group:
          await groups.onReceipt(message, conversation, from, relayHops: relayHops);
        case ConversationType.room:
          break; // public rooms have no receipts
      }
    }
  }

  Future<void> _onMediaPartAck(String messageId, String partId, String from, int relayHops) async {
    final message = await repo.getMessage(messageId);
    if (message == null) return;
    final conversation = await repo.getConversation(message.conversationId);
    if (conversation == null || conversation.peerId != from) {
      _log.w(_tag, 'ignored a receipt from the wrong sender');
      return;
    }
    final progress = await context.mediaRepo.ackPart(partId);
    if (progress != null && progress.remaining == 0) {
      await repo.updateOutgoingStatus(messageId, MessageStatus.delivered, hops: relayHops);
    }
  }

  // ---- our own packets ---------------------------------------------------------

  @override
  Future<void> onOwnPacketSent(MeshPacket packet) async {
    if (packet.isChunk) return;
    switch (packet.type) {
      case PacketType.direct:
      case PacketType.group:
      case PacketType.room:
        await repo.updateOutgoingStatus(packet.messageIdHex, MessageStatus.sent);
        await actions.onControlSent(packet.messageIdHex);
      case PacketType.announce:
      case PacketType.roomAnnounce:
      case PacketType.ack:
        break;
    }
  }

  @override
  Future<void> onOwnPacketExpired(OutboxEntry entry) async {
    final MeshPacket packet;
    try {
      packet = MeshPacket.decode(entry.packet);
    } on PacketFormatException {
      return;
    }
    switch (packet.type) {
      case PacketType.direct:
        await actions.onControlExpired(packet.messageIdHex);
        // The message itself, or a piece of an image / voice message.
        final owner = packet.isChunk
            ? await context.mediaRepo.messageOfPart(packet.messageIdHex)
            : packet.messageIdHex;
        if (owner != null) {
          await repo.updateOutgoingStatus(
            owner,
            MessageStatus.failed,
            error: DeliveryProblem.expired.code,
          );
        }
      case PacketType.group:
      case PacketType.room:
        // Reaching nobody is a failure; reaching somebody is as good as it
        // gets for traffic that has no single recipient.
        if (!packet.isChunk) {
          final message = await repo.getMessage(packet.messageIdHex);
          if (message != null && message.status == MessageStatus.queued) {
            await repo.updateOutgoingStatus(
              message.id,
              MessageStatus.failed,
              error: DeliveryProblem.nobodyInRange.code,
            );
          }
        }
      case PacketType.announce:
      case PacketType.roomAnnounce:
      case PacketType.ack:
        break;
    }
  }

  @override
  Future<void> onSecurityEvent(String kind, {String? peerId, String? detail}) =>
      repo.recordSecurityEvent(kind, peerId: peerId, detail: detail, atMs: context.clock.nowMs);
}
