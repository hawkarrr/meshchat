import '../core/bytes.dart';
import '../database/message_repository.dart';
import '../models/conversation.dart';
import '../models/message.dart';
import '../protocol/envelope.dart';
import '../protocol/mesh_packet.dart';
import '../protocol/protocol_constants.dart';
import '../mesh/mesh_router.dart';
import 'group_service.dart';
import 'media_service.dart';
import 'message_errors.dart';
import 'room_service.dart';
import 'service_context.dart';

/// Who may change what, and for how long. Both windows are counted from when
/// the message was sent or received on this phone.
class MessagePolicy {
  const MessagePolicy({
    this.editWindow = const Duration(hours: 48),
    this.deleteForEveryoneWindow = const Duration(hours: 48),
  });

  /// How long after sending the author can still edit a text message.
  final Duration editWindow;

  /// How long after sending (or receiving, for a group admin) a message can
  /// still be deleted for everyone. A request can only reach phones while the
  /// message itself is still travelling, so a longer window is mostly a promise
  /// the mesh cannot keep.
  final Duration deleteForEveryoneWindow;
}

/// What a delete request did, in words the screen can use without overclaiming.
class DeleteResult {
  const DeleteResult({
    required this.removed,
    this.askedOthers = false,
    this.cancelled = 0,
  });

  /// Messages removed from this phone.
  final int removed;

  /// Whether a request to remove them was sent to the other phones. It reaches
  /// them only when they are in reach; nothing here says it has.
  final bool askedOthers;

  /// Messages that had not left this phone yet, so nobody ever got them.
  final int cancelled;

  static const DeleteResult none = DeleteResult(removed: 0);
}

/// Deleting and editing messages, and applying other people's requests to do
/// the same.
///
/// A request travels as an ordinary message of the conversation (sealed for a
/// private chat or a group, signed for a public room), so it is checked like
/// any other: a request is honoured only if it comes from the message's author
/// - or, in a group, from its admin.
class MessageActions {
  MessageActions(
    this._ctx,
    this._groups,
    this._rooms,
    this._media, {
    this.policy = const MessagePolicy(),
  });

  final ServiceContext _ctx;
  final GroupService _groups;
  final RoomService _rooms;
  final MediaService _media;
  final MessagePolicy policy;

  static const String _tag = 'Actions';

  /// Told whenever messages leave this phone (deleted here, deleted at someone's
  /// request), so a notification that quotes one can be taken back.
  void Function(List<ChatMessage> removed)? onRemoved;

  MessageRepository get _repo => _ctx.repo;

  Future<Conversation> _conversation(String id) async {
    final c = await _repo.getConversation(id);
    if (c == null) {
      throw MessageError(
          MessageErrorKind.unknownConversation, _ctx.l10n.errNoConversation);
    }
    return c;
  }

  /// Seals (or signs) [envelope] for everyone in [conversation].
  Future<MeshPacket> _buildControl(Conversation conversation, Envelope envelope) async {
    switch (conversation.type) {
      case ConversationType.direct:
        final peer = await _repo.getPeer(conversation.peerId!);
        if (peer == null || peer.agreementKey == null) {
          throw MessageError(
            MessageErrorKind.noEncryptionKey,
            _ctx.l10n.errNoKeyForControl,
          );
        }
        return _ctx.crypto.buildDirectEnvelope(
          recipientSigningKey: peer.signingKey,
          recipientAgreementKey: peer.agreementKey!,
          envelope: envelope,
        );
      case ConversationType.group:
        return _groups.buildEnvelopePacket(conversation.groupId!, envelope);
      case ConversationType.room:
        return _rooms.buildEnvelopePacket(conversation.roomId!, envelope);
    }
  }

  Future<void> _submit(MeshPacket packet) async {
    final outcome = await _ctx.router.submit(packet);
    if (outcome != SubmitOutcome.queued) {
      throw MessageError(
          MessageErrorKind.invalidMedia, _ctx.l10n.errNotQueued);
    }
  }

  /// Stops messages that never left this phone from being sent.
  Future<void> _cancelUnsent(List<ChatMessage> messages) async {
    for (final m in messages) {
      if (!m.isOutgoing || m.status != MessageStatus.queued) continue;
      for (final part in await _ctx.mediaRepo.partIds(m.id)) {
        await _ctx.router.queue.remove(part);
      }
      await _ctx.router.queue.remove(m.id);
    }
  }

  /// What goes with a removed message: its half-received or finished file.
  Future<void> _tidy(List<ChatMessage> removed) async {
    if (removed.isNotEmpty) onRemoved?.call(removed);
    await _media.forget(removed);
    await _media.sweepFiles();
  }

  // ---------------------------------------------------------------------------
  // Delete for me
  // ---------------------------------------------------------------------------

  /// Removes the messages from this phone only. Nobody else's copy changes. A
  /// message that has not been sent yet is not sent any more.
  Future<DeleteResult> deleteForMe(String conversationId, List<String> ids) async {
    await _conversation(conversationId);
    final messages =
        (await _repo.getMessagesByIds(ids)).where((m) => m.conversationId == conversationId);
    if (messages.isEmpty) return DeleteResult.none;
    final list = messages.toList();
    await _cancelUnsent(list);
    final removed = await _repo.removeMessages(
      conversationId,
      [for (final m in list) m.id],
      scope: 'me',
      requestedBy: _ctx.ownId,
      atMs: _ctx.clock.nowMs,
    );
    await _tidy(removed);
    return DeleteResult(
      removed: removed.length,
      cancelled: list.where((m) => m.isOutgoing && m.status == MessageStatus.queued).length,
    );
  }

  // ---------------------------------------------------------------------------
  // Delete for everyone
  // ---------------------------------------------------------------------------

  /// Whether [m] may be deleted for everyone by this phone; throws the reason.
  Future<void> _checkMayDeleteForEveryone(Conversation conversation, ChatMessage m) async {
    var allowed = m.isOutgoing;
    if (!allowed && conversation.isGroup) {
      final group = await _ctx.groupRepo.getGroup(conversation.groupId!);
      allowed = group != null && group.adminId == _ctx.ownId;
    }
    if (!allowed || m.status == MessageStatus.undecryptable) {
      throw MessageError(
        MessageErrorKind.notAllowed,
        conversation.isGroup
            ? _ctx.l10n.errDeleteGroupOnly
            : _ctx.l10n.errDeleteOwnOnly,
      );
    }
    final age = _ctx.clock.nowMs - m.sortTimeMs;
    if (age > policy.deleteForEveryoneWindow.inMilliseconds) {
      throw MessageError(
        MessageErrorKind.tooOld,
        _ctx.l10n.errDeleteTooOld(policy.deleteForEveryoneWindow.inHours),
      );
    }
  }

  /// Asks everyone in the conversation to remove the messages, and removes them
  /// here. The request is queued and sent whenever the other phones are in
  /// reach; until a phone receives it, it still has the message, and nothing
  /// here pretends otherwise. A copy somebody saved or photographed cannot be
  /// reached at all.
  ///
  /// Nothing is removed here unless the request could be queued.
  Future<DeleteResult> deleteForEveryone(String conversationId, List<String> ids) async {
    final conversation = await _conversation(conversationId);
    final messages = (await _repo.getMessagesByIds(ids))
        .where((m) => m.conversationId == conversationId)
        .toList();
    if (messages.isEmpty) return DeleteResult.none;
    for (final m in messages) {
      await _checkMayDeleteForEveryone(conversation, m);
    }

    // A message that never left this phone has nobody to be told.
    final unsent =
        messages.where((m) => m.isOutgoing && m.status == MessageStatus.queued).toList();
    final told = messages.where((m) => !unsent.contains(m)).toList();

    final batches = <List<ChatMessage>>[];
    for (var i = 0; i < told.length; i += Protocol.maxDeleteBatch) {
      batches.add(told.sublist(i, (i + Protocol.maxDeleteBatch).clamp(0, told.length)));
    }
    final now = _ctx.clock.nowMs;
    final removed = <ChatMessage>[];
    var asked = 0;
    try {
      // One batch at a time: its request is queued first and its messages are removed
      // here right after. If a later batch cannot be queued, the earlier ones are both
      // gone here and asked for, and the rest are still on the screen - what is shown
      // is always what is not being asked for.
      for (final batch in batches) {
        final packet = await _buildControl(
            conversation, DeleteEnvelope([for (final m in batch) hexToBytes(m.id)]));
        await _submit(packet);
        asked++;
        removed.addAll(await _repo.removeMessages(
          conversationId,
          [for (final m in batch) m.id],
          scope: 'everyone',
          requestedBy: _ctx.ownId,
          atMs: now,
          controlPacket: packet.messageIdHex,
          state: 'queued',
        ));
      }
      await _cancelUnsent(unsent);
      removed.addAll(await _repo.removeMessages(
        conversationId,
        [for (final m in unsent) m.id],
        scope: 'everyone',
        requestedBy: _ctx.ownId,
        atMs: now,
      ));
    } finally {
      // Whatever did go (even if a later batch failed) leaves its files and
      // notifications behind it.
      await _tidy(removed);
    }
    return DeleteResult(
      removed: removed.length,
      askedOthers: asked > 0,
      cancelled: unsent.length,
    );
  }

  // ---------------------------------------------------------------------------
  // Edit
  // ---------------------------------------------------------------------------

  /// Replaces the text of one of our own text messages, here and - through an
  /// authenticated edit event - on every phone that has it. A phone that is out
  /// of reach gets the edit later; a phone that has seen a newer edit ignores an
  /// older one.
  Future<ChatMessage> edit(String messageId, String rawText) async {
    final text = validateMessageText(rawText, _ctx.l10n);
    final m = await _repo.getMessage(messageId);
    if (m == null) {
      throw MessageError(MessageErrorKind.unknownMessage, _ctx.l10n.errMessageGone);
    }
    if (!m.isOutgoing || m.kind != MessageKind.text || m.status == MessageStatus.failed) {
      throw MessageError(
          MessageErrorKind.notAllowed, _ctx.l10n.errEditOwnTextOnly);
    }
    final now = _ctx.clock.nowMs;
    if (now - m.sortTimeMs > policy.editWindow.inMilliseconds) {
      throw MessageError(
        MessageErrorKind.tooOld,
        _ctx.l10n.errEditTooOld(policy.editWindow.inHours),
      );
    }
    if (text == m.body) return m;
    final conversation = await _conversation(m.conversationId);
    final version = now > m.editVersion ? now : m.editVersion + 1;
    final packet = await _buildControl(
      conversation,
      EditEnvelope(targetId: hexToBytes(m.id), version: version, text: text),
    );
    await _submit(packet);
    await _repo.updateOwnText(m.id, text, version, now);
    return (await _repo.getMessage(m.id))!;
  }

  // ---------------------------------------------------------------------------
  // Requests from other phones
  // ---------------------------------------------------------------------------

  /// Applies an edit or delete request that arrived in [conversation] from
  /// [senderId] (already verified as the signer, and as a member where that
  /// matters). Returns whether it was acceptable, so it can be acknowledged.
  Future<bool> onControl(Conversation conversation, String senderId, Envelope envelope) async {
    final now = _ctx.clock.nowMs;
    switch (envelope) {
      case EditEnvelope():
        final outcome = await _repo.applyEdit(
          conversationId: conversation.id,
          messageId: envelope.targetHex,
          senderKey: senderId,
          version: envelope.version,
          text: envelope.text,
          atMs: now,
        );
        if (outcome == EditOutcome.rejected) {
          _ctx.log.w(_tag, 'ignored an edit that is not allowed');
        }
        return outcome != EditOutcome.rejected;
      case DeleteEnvelope():
        String? adminId;
        if (conversation.isGroup) {
          adminId = (await _ctx.groupRepo.getGroup(conversation.groupId!))?.adminId;
        }
        final allowed = <String>[];
        var refused = 0;
        for (final id in envelope.targetsHex) {
          final m = await _repo.getMessage(id);
          if (m == null) {
            await _repo.rememberRemoteDeletion(conversation.id, id, senderId, now);
          } else if (m.conversationId != conversation.id) {
            refused++;
          } else if (m.senderId == senderId || (adminId != null && adminId == senderId)) {
            allowed.add(id);
          } else {
            refused++;
          }
        }
        if (refused > 0) {
          await _repo.recordSecurityEvent(
            SecurityEventKind.unauthorizedChange,
            peerId: senderId,
            detail: 'asked to delete $refused message(s) they did not write',
            atMs: now,
          );
        }
        if (allowed.isNotEmpty) {
          final removed = await _repo.removeMessages(
            conversation.id,
            allowed,
            scope: 'remote',
            requestedBy: senderId,
            atMs: now,
          );
          await _tidy(removed);
        }
        return refused == 0;
      default:
        return false;
    }
  }

  // ---------------------------------------------------------------------------
  // How far our own delete request got
  // ---------------------------------------------------------------------------

  /// A delete request of ours was handed to a neighbour.
  Future<void> onControlSent(String packetId) => _repo.advanceDeletionRequest(packetId, 'sent');

  /// A private chat's recipient confirmed our delete request.
  Future<void> onControlAcked(String packetId, String from) async {
    final deletion = await _repo.deletionByControlPacket(packetId);
    if (deletion == null) return;
    final conversation = await _repo.getConversation(deletion.conversationId);
    // Only the other person of a private chat can confirm; a group or a room has
    // no single recipient, so those requests stay at "sent".
    if (conversation == null || !conversation.isDirect || conversation.peerId != from) return;
    await _repo.advanceDeletionRequest(packetId, 'delivered');
  }

  /// A delete request of ours ran out of time before anyone confirmed it.
  Future<void> onControlExpired(String packetId) => _repo.expireDeletionRequest(packetId);
}
