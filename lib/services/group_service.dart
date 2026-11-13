import 'dart:async';
import 'dart:typed_data';

import '../core/bytes.dart';
import '../core/text.dart';
import '../crypto/hpke.dart';
import '../database/group_repository.dart';
import '../database/message_repository.dart';
import '../mesh/mesh_router.dart' show SubmitOutcome;
import '../models/conversation.dart';
import '../models/group.dart';
import '../models/message.dart';
import '../models/peer.dart';
import '../protocol/mesh_packet.dart';
import '../protocol/protocol_constants.dart';
import 'encryption_service.dart';
import 'group_keyring.dart';
import 'media_service.dart';
import 'message_errors.dart';
import 'service_context.dart';
import '../models/delivery_problem.dart';

/// Private groups: a fixed set of members sharing a random key.
///
///  * Only the *admin* (the creator) changes a group - adds or removes people.
///    Everyone checks that a change really comes from the admin they know.
///  * Whenever the membership changes the admin makes a new key and sends it,
///    sealed, to each remaining member, so a removed member cannot read
///    anything sent afterwards.
///  * Invitations carry the key. They are ordinary end-to-end encrypted direct
///    messages, so nobody on the way can read them, and nothing about a group
///    (its name, its members, that it exists) is ever broadcast.
///  * A group message is accepted only if its author is on the member list the
///    admin sent, however valid its signature is.
class GroupService {
  GroupService(this._ctx, this.keyring, this._media);

  final ServiceContext _ctx;
  final GroupKeyring keyring;
  final MediaService _media;

  static const String _tag = 'Groups';

  GroupRepository get _groups => _ctx.groupRepo;
  MessageRepository get _repo => _ctx.repo;
  EncryptionService get _crypto => _ctx.crypto;

  final Map<String, int> _lastUndecryptableMs = <String, int>{};

  // ---------------------------------------------------------------------------
  // Queries
  // ---------------------------------------------------------------------------

  Future<GroupChat?> get(String groupId) => _groups.getGroup(groupId);

  Future<List<GroupChat>> list({Iterable<GroupState>? states}) => _groups.listGroups(states: states);

  /// Whether packets of this group should be opened by us.
  Future<bool> isActive(Uint8List groupId) async =>
      (await _groups.stateOf(bytesToHex(groupId))) == GroupState.active;

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String _cleanName(String raw) {
    final name = sanitizeDisplayName(raw, maxBytes: Protocol.maxGroupNameBytes);
    if (name.isEmpty) {
      throw MessageError(MessageErrorKind.invalidName, _ctx.l10n.errGroupName);
    }
    return name;
  }

  static String _announcedName(Peer p) => p.nickname.isNotEmpty ? p.nickname : 'Peer ${p.shortId}';

  /// A person we can invite: known, not blocked, with a usable encryption key.
  Future<Peer> _invitable(String id) async {
    final peer = await _repo.getPeer(id);
    if (peer == null) {
      throw MessageError(MessageErrorKind.unknownPeer, _ctx.l10n.errUnknownContact);
    }
    if (peer.blocked) {
      throw MessageError(MessageErrorKind.blocked, _ctx.l10n.errBlockedNamed(peer.displayName));
    }
    if (peer.agreementKey == null) {
      throw MessageError(
        MessageErrorKind.noEncryptionKey,
        _ctx.l10n.errNoKeyNamed(peer.displayName),
      );
    }
    return peer;
  }

  Future<GroupChat> _requireGroup(String groupId, {bool admin = false, bool active = true}) async {
    final g = await _groups.getGroup(groupId);
    if (g == null) {
      throw MessageError(MessageErrorKind.unknownGroup, _ctx.l10n.errGroupGone);
    }
    if (active && !g.isActive) {
      throw MessageError(MessageErrorKind.groupNotActive, _ctx.l10n.errNotInGroup);
    }
    if (admin && g.adminId != _ctx.ownId) {
      throw MessageError(MessageErrorKind.notAdmin, _ctx.l10n.errAdminOnly);
    }
    return g;
  }

  GroupSnapshot _snapshot(GroupChat g, GroupSealKey key, {required bool isUpdate}) => GroupSnapshot(
        isUpdate: isUpdate,
        groupId: g.idBytes,
        epoch: key.epoch,
        groupKey: key.key,
        name: g.name,
        adminKey: hexToBytes(g.adminId),
        members: [
          for (final m in g.members) GroupMemberInfo(key: m.key, nickname: m.nickname),
        ],
      );

  /// Seals [envelope] to each of [peers] as an ordinary direct message.
  Future<List<MeshPacket>> _sealTo(List<Peer> peers, Envelope envelope) async {
    try {
      return [
        for (final p in peers)
          await _crypto.buildDirectEnvelope(
            recipientSigningKey: p.signingKey,
            recipientAgreementKey: p.agreementKey!,
            envelope: envelope,
          ),
      ];
    } on HpkeException {
      throw MessageError(
        MessageErrorKind.noEncryptionKey,
        _ctx.l10n.errKeyUnusableOne,
      );
    }
  }

  Future<void> _submitAll(Iterable<MeshPacket> packets) async {
    for (final p in packets) {
      await _ctx.router.submit(p);
    }
  }

  /// Peers we can still reach for a group message, ignoring ones we no longer
  /// know (they will be told whenever they next meet the admin).
  Future<List<Peer>> _knownPeers(Iterable<String> ids) async {
    final out = <Peer>[];
    for (final id in ids) {
      final p = await _repo.getPeer(id);
      if (p != null && p.agreementKey != null && !p.blocked) out.add(p);
    }
    return out;
  }

  // ---------------------------------------------------------------------------
  // Creating and changing a group (admin)
  // ---------------------------------------------------------------------------

  Future<GroupChat> create({required String name, required List<String> memberIds}) async {
    final cleanName = _cleanName(name);
    final ids = <String>{...memberIds}..remove(_ctx.ownId);
    if (ids.isEmpty) {
      throw MessageError(MessageErrorKind.noMembers, _ctx.l10n.errPickPeople);
    }
    if (ids.length + 1 > Protocol.maxGroupMembers) {
      throw MessageError(
        MessageErrorKind.tooManyMembers,
        _ctx.l10n.errGroupFull(Protocol.maxGroupMembers),
      );
    }
    final peers = [for (final id in ids) await _invitable(id)];
    final key = _crypto.newGroupKey();
    final now = _ctx.clock.nowMs;
    final group = GroupChat(
      id: bytesToHex(key.groupId),
      name: cleanName,
      adminId: _ctx.ownId,
      epoch: 0,
      state: GroupState.active,
      createdAtMs: now,
      joinedAtMs: now,
      members: [
        GroupMember(id: _ctx.ownId, nickname: _ctx.ownNickname),
        for (final p in peers) GroupMember(id: p.id, nickname: _announcedName(p)),
      ],
    );
    // Build every invitation first, so an unusable key aborts before anything
    // is stored or sent.
    final invitations = await _sealTo(peers, _snapshot(group, key, isUpdate: false));
    await keyring.put(group.id, 0, key.key);
    await _groups.save(group);
    await _repo.ensureGroupConversation(group.id, group.name, nowMs: now);
    await _submitAll(invitations);
    return group;
  }

  /// Changes the membership: makes a fresh key, tells everyone who stays (and
  /// invites anyone new), and tells people who were removed.
  Future<GroupChat> _changeMembership(
    GroupChat g, {
    List<Peer> add = const <Peer>[],
    List<String> remove = const <String>[],
    bool tellRemoved = true,
  }) async {
    final current = await keyring.get(g.id, g.epoch);
    if (current == null) {
      throw MessageError(MessageErrorKind.groupNotActive, _ctx.l10n.errGroupKeyMissing);
    }
    final next = _crypto.rotatedGroupKey(current);
    final removed = g.members.where((m) => remove.contains(m.id)).toList();
    final kept = g.members.where((m) => !remove.contains(m.id)).toList();
    final updated = GroupChat(
      id: g.id,
      name: g.name,
      adminId: g.adminId,
      epoch: next.epoch,
      state: GroupState.active,
      createdAtMs: g.createdAtMs,
      joinedAtMs: g.joinedAtMs,
      members: [
        ...kept,
        for (final p in add) GroupMember(id: p.id, nickname: _announcedName(p)),
      ],
    );
    final addedIds = add.map((p) => p.id).toSet();
    final stayers = await _knownPeers(
      updated.members.map((m) => m.id).where((id) => id != _ctx.ownId && !addedIds.contains(id)),
    );
    final packets = <MeshPacket>[
      ...await _sealTo(add, _snapshot(updated, next, isUpdate: false)),
      ...await _sealTo(stayers, _snapshot(updated, next, isUpdate: true)),
      if (tellRemoved)
        ...await _sealTo(
          await _knownPeers(removed.map((m) => m.id)),
          GroupRemovedEnvelope(g.idBytes),
        ),
    ];
    await keyring.put(g.id, next.epoch, next.key);
    await _groups.save(updated);
    await _submitAll(packets);
    return updated;
  }

  Future<GroupChat> addMembers(String groupId, List<String> memberIds) async {
    final g = await _requireGroup(groupId, admin: true);
    final fresh = <String>{...memberIds}..removeWhere((id) => id == _ctx.ownId || g.hasMember(id));
    if (fresh.isEmpty) {
      throw MessageError(MessageErrorKind.noMembers, _ctx.l10n.errPickNewPeople);
    }
    if (g.members.length + fresh.length > Protocol.maxGroupMembers) {
      throw MessageError(
        MessageErrorKind.tooManyMembers,
        _ctx.l10n.errGroupFull(Protocol.maxGroupMembers),
      );
    }
    final peers = [for (final id in fresh) await _invitable(id)];
    return _changeMembership(g, add: peers);
  }

  Future<GroupChat> removeMember(String groupId, String memberId) async {
    final g = await _requireGroup(groupId, admin: true);
    if (memberId == g.adminId) {
      throw MessageError(MessageErrorKind.notAdmin, _ctx.l10n.errAdminCannotBeRemoved);
    }
    if (!g.hasMember(memberId)) {
      throw MessageError(MessageErrorKind.noMembers, _ctx.l10n.errNotInGroupPerson);
    }
    return _changeMembership(g, remove: [memberId]);
  }

  /// The admin ends the group for everybody and forgets it.
  Future<void> deleteAsAdmin(String groupId) async {
    final g = await _requireGroup(groupId, admin: true, active: false);
    final others = g.members.map((m) => m.id).where((id) => id != _ctx.ownId);
    final packets = await _sealTo(await _knownPeers(others), GroupRemovedEnvelope(g.idBytes));
    await _submitAll(packets);
    await keyring.remove(g.id);
    await _groups.delete(g.id);
    await _repo.deleteConversation(Conversation.groupConversationId(g.id));
  }

  // ---------------------------------------------------------------------------
  // Invitations and leaving (member)
  // ---------------------------------------------------------------------------

  Future<GroupChat> accept(String groupId) async {
    final g = await _requireGroup(groupId, active: false);
    if (g.state != GroupState.invited) return g;
    final now = _ctx.clock.nowMs;
    await _groups.setState(g.id, GroupState.active, joinedAtMs: now);
    await _repo.ensureGroupConversation(g.id, g.name, nowMs: now);
    return (await _groups.getGroup(g.id))!;
  }

  Future<void> decline(String groupId) async {
    final g = await _requireGroup(groupId, active: false);
    if (g.state != GroupState.invited) return;
    await _tellAdminWeLeft(g);
    await keyring.remove(g.id);
    await _groups.delete(g.id);
  }

  Future<void> leave(String groupId) async {
    final g = await _requireGroup(groupId);
    if (g.adminId == _ctx.ownId) {
      throw MessageError(
        MessageErrorKind.notAdmin,
        _ctx.l10n.errCreatorCannotLeave,
      );
    }
    await _tellAdminWeLeft(g);
    await keyring.remove(g.id);
    await _groups.setState(g.id, GroupState.left);
  }

  /// Lets the admin know, so they can make a key we do not have.
  Future<void> _tellAdminWeLeft(GroupChat g) async {
    final admin = await _repo.getPeer(g.adminId);
    if (admin == null || admin.agreementKey == null) return;
    try {
      await _submitAll(await _sealTo([admin], GroupLeaveEnvelope(g.idBytes)));
    } on MessageError catch (e) {
      _ctx.log.w(_tag, 'could not tell the admin we left: ${e.message}');
    }
  }

  // ---------------------------------------------------------------------------
  // Control messages arriving (they come in sealed, one to one)
  // ---------------------------------------------------------------------------

  Future<void> _reject(MeshPacket packet, String detail) => _repo.recordSecurityEvent(
        SecurityEventKind.notAMember,
        peerId: packet.senderHex,
        detail: detail,
        atMs: _ctx.clock.nowMs,
      );

  /// An invitation or an update. Returns whether it was accepted (and so
  /// should be acknowledged).
  Future<bool> onSnapshot(MeshPacket packet, GroupSnapshot s) async {
    final sender = packet.senderHex;
    if (sender != s.adminId) {
      await _reject(packet, 'group invitation or update from someone who is not its admin');
      return false;
    }
    if (!s.members.any((m) => m.id == _ctx.ownId)) {
      await _reject(packet, 'group update that does not include us');
      return false;
    }
    final groupId = s.groupIdHex;
    final existing = await _groups.getGroup(groupId);
    if (existing != null && existing.adminId != s.adminId) {
      await _reject(packet, 'group update that changes the admin');
      return false;
    }
    // Stale or repeated: harmless, and the sender can stop retrying.
    if (existing != null && s.epoch <= existing.epoch) return true;

    final now = _ctx.clock.nowMs;
    final members = [
      for (final m in s.members)
        GroupMember(id: m.id, nickname: sanitizeDisplayName(m.nickname)),
    ];
    final name = sanitizeDisplayName(s.name, maxBytes: Protocol.maxGroupNameBytes);
    if (name.isEmpty) return false;

    await keyring.put(groupId, s.epoch, s.groupKey);
    final isNew = existing == null ||
        existing.state == GroupState.left ||
        existing.state == GroupState.removed;
    final state = isNew ? GroupState.invited : existing.state;
    await _groups.save(GroupChat(
      id: groupId,
      name: name,
      adminId: s.adminId,
      epoch: s.epoch,
      state: state,
      invitedBy: isNew ? sender : existing.invitedBy,
      createdAtMs: isNew ? now : existing.createdAtMs,
      joinedAtMs: isNew ? null : existing.joinedAtMs,
      members: members,
    ));
    if (!isNew && existing.state == GroupState.active) {
      await _repo.renameConversation(Conversation.groupConversationId(groupId), name);
    }
    if (isNew) {
      _ctx.notify(IncomingNotice(
        conversationId: Conversation.groupConversationId(groupId),
        title: name,
        type: ConversationType.group,
        kind: NoticeKind.groupInvite,
      ));
    }
    return true;
  }

  /// The admin removed us (or deleted the group).
  Future<bool> onRemoved(MeshPacket packet, GroupRemovedEnvelope e) async {
    final id = bytesToHex(e.groupId);
    final g = await _groups.getGroup(id);
    if (g == null) return true;
    if (g.adminId != packet.senderHex) {
      await _reject(packet, 'removal notice from someone who is not the admin');
      return false;
    }
    await keyring.remove(id);
    if (g.state == GroupState.invited) {
      await _groups.delete(id);
    } else {
      await _groups.setState(id, GroupState.removed);
    }
    return true;
  }

  /// A member left; as the admin we make a key they do not have.
  Future<bool> onLeft(MeshPacket packet, GroupLeaveEnvelope e) async {
    final id = bytesToHex(e.groupId);
    final g = await _groups.getGroup(id);
    if (g == null || g.adminId != _ctx.ownId || !g.isActive) return true;
    if (!g.hasMember(packet.senderHex)) return true;
    try {
      await _changeMembership(g, remove: [packet.senderHex], tellRemoved: false);
    } on MessageError catch (err) {
      _ctx.log.w(_tag, 'could not re-key after a member left: ${err.message}');
      return false;
    }
    return true;
  }

  // ---------------------------------------------------------------------------
  // Messages
  // ---------------------------------------------------------------------------

  /// Handles edit and delete requests that arrive in a group's traffic (set by
  /// the message service). Returns whether the request was acceptable.
  Future<bool> Function(Conversation conversation, String senderId, Envelope envelope)?
      controls;

  /// Seals [envelope] (an edit or delete request) for the group.
  Future<MeshPacket> buildEnvelopePacket(String groupId, Envelope envelope) async {
    final g = await _requireGroup(groupId);
    final key = await keyring.get(g.id, g.epoch);
    if (key == null) {
      throw MessageError(MessageErrorKind.groupNotActive, _ctx.l10n.errGroupKeyMissing);
    }
    return _crypto.buildGroupMessage(group: key, envelope: envelope);
  }

  Future<ChatMessage> sendText(String groupId, String rawText,
      {String? replyToId, String? forwardedFrom}) async {
    final text = validateMessageText(rawText, _ctx.l10n);
    final g = await _requireGroup(groupId);
    await validateReplyTarget(_repo, Conversation.groupConversationId(g.id), replyToId, _ctx.l10n);
    final key = await keyring.get(g.id, g.epoch);
    if (key == null) {
      throw MessageError(MessageErrorKind.groupNotActive, _ctx.l10n.errGroupKeyMissing);
    }
    final nickname = _ctx.ownNickname;
    final packet = await _crypto.buildGroupMessage(
      group: key,
      envelope: TextEnvelope(text,
          nickname: nickname,
          replyTo: replyToId == null ? null : hexToBytes(replyToId),
          forwardedFrom: forwardedFrom),
    );
    final now = _ctx.clock.nowMs;
    final conversation = await _repo.ensureGroupConversation(g.id, g.name, nowMs: now);
    final message = ChatMessage(
      id: packet.messageIdHex,
      conversationId: conversation.id,
      senderId: _ctx.ownId,
      senderNickname: nickname,
      isOutgoing: true,
      body: text,
      sortTimeMs: now,
      claimedTimestampMs: packet.timestampMs,
      status: MessageStatus.queued,
      recipientCount: g.members.length - 1,
      replyToId: replyToId,
      forwardedFrom: forwardedFrom,
    );
    await _repo.insertMessage(message);
    final outcome = await _ctx.router.submit(packet);
    if (outcome != SubmitOutcome.queued) {
      await _repo.updateOutgoingStatus(message.id, MessageStatus.failed,
          error: DeliveryProblem.queueFailed.code);
    }
    return message;
  }

  /// Where an image or voice message for this group goes.
  Future<GroupMediaRoute> mediaRoute(String groupId) async {
    final g = await _requireGroup(groupId);
    final key = await keyring.get(g.id, g.epoch);
    if (key == null) {
      throw MessageError(MessageErrorKind.groupNotActive, _ctx.l10n.errGroupKeyMissing);
    }
    return GroupMediaRoute(g, key);
  }

  /// A packet of a group we are in: a message, or a chunk of an image / voice
  /// message.
  Future<void> onGroupPacket(MeshPacket packet, {required int relayHops}) async {
    final groupId = bytesToHex(packet.recipientKey);
    final g = await _groups.getGroup(groupId);
    if (g == null || !g.isActive) return;
    final sender = packet.senderHex;
    if (!g.hasMember(sender)) {
      await _reject(packet, 'group message from someone who is not a member');
      return;
    }
    if ((await _repo.getPeer(sender))?.blocked ?? false) return;

    if (packet.isChunk) {
      await _onChunk(g, packet);
      return;
    }

    final int epoch;
    try {
      epoch = EncryptionService.groupPacketEpoch(packet);
    } on DecryptionFailure {
      return;
    }
    final key = await keyring.get(groupId, epoch);
    if (key == null) {
      _ctx.log.w(_tag, 'group message sealed under an unknown key epoch $epoch');
      return;
    }
    final Envelope envelope;
    try {
      envelope = await EncryptionService.openGroupMessage(packet, key);
    } on DecryptionFailure catch (e) {
      final now = _ctx.clock.nowMs;
      if (now - (_lastUndecryptableMs[groupId] ?? 0) >= 30000) {
        _lastUndecryptableMs[groupId] = now;
        await _repo.recordSecurityEvent(
          SecurityEventKind.decryptFailed,
          peerId: sender,
          detail: 'group "${g.name}": ${e.reason.name}',
          atMs: now,
        );
      }
      return;
    }

    final now = _ctx.clock.nowMs;
    final conversation = await _repo.ensureGroupConversation(g.id, g.name, nowMs: now);
    final announced = switch (envelope) {
      TextEnvelope(:final nickname) => nickname,
      MediaEnvelope(:final nickname) => nickname,
      _ => null,
    };
    final cleaned = sanitizeDisplayName(announced ?? '');
    final nickname = cleaned.isNotEmpty ? cleaned : g.nicknameOf(sender);

    var stored = false;
    String preview = '';
    MediaKind? previewKind;
    switch (envelope) {
      case TextEnvelope():
        preview = envelope.text;
        stored = await _repo.insertMessage(ChatMessage(
          id: packet.messageIdHex,
          conversationId: conversation.id,
          senderId: sender,
          senderNickname: nickname,
          isOutgoing: false,
          body: envelope.text,
          sortTimeMs: now,
          claimedTimestampMs: packet.timestampMs,
          status: MessageStatus.received,
          hops: relayHops,
          replyToId: envelope.replyTo == null ? null : bytesToHex(envelope.replyTo!),
          forwardedFrom: envelope.forwardedFrom == null
              ? null
              : sanitizeDisplayName(envelope.forwardedFrom!, maxBytes: Protocol.maxNicknameBytes),
        ));
        _ctx.acks.add(packet.senderKey, packet.messageId);
      case MediaEnvelope():
        previewKind = envelope.mediaKind;
        // A media message is confirmed once the whole file has arrived.
        stored = await _media.onManifest(
          packet: packet,
          manifest: envelope,
          conversation: conversation,
          senderNickname: nickname,
          relayHops: relayHops,
        );
      case EditEnvelope():
      case DeleteEnvelope():
        if (await controls?.call(conversation, sender, envelope) ?? false) {
          _ctx.acks.add(packet.senderKey, packet.messageId);
        }
        return;
      default:
        return;
    }
    if (stored) {
      _ctx.notify(IncomingNotice(
        conversationId: conversation.id,
        title: g.name,
        type: ConversationType.group,
        messageId: packet.messageIdHex,
        preview: preview,
        mediaKind: previewKind,
        sender: nickname,
      ));
    }
  }

  Future<void> _onChunk(GroupChat g, MeshPacket packet) async {
    final ({int? epoch, MediaChunk chunk}) parsed;
    try {
      parsed = EncryptionService.parseChunkPacket(packet);
    } on DecryptionFailure {
      return;
    }
    final epoch = parsed.epoch;
    if (epoch == null) return;
    final key = await keyring.get(g.id, epoch);
    if (key == null) return;
    final mediaKey = await EncryptionService.groupMediaKey(key.key, parsed.chunk.mediaId);
    final Uint8List plain;
    try {
      plain = await EncryptionService.openChunkBody(
        packet: packet,
        chunk: parsed.chunk,
        key: mediaKey,
        epoch: epoch,
      );
    } on DecryptionFailure {
      await _repo.recordSecurityEvent(
        SecurityEventKind.decryptFailed,
        peerId: packet.senderHex,
        detail: 'group media chunk',
        atMs: _ctx.clock.nowMs,
      );
      return;
    }
    await _media.onOpenedChunk(chunk: parsed.chunk, plain: plain, senderId: packet.senderHex);
  }

  // ---------------------------------------------------------------------------
  // Delivery receipts
  // ---------------------------------------------------------------------------

  /// A member confirmed receiving [message]. Once every other member has, it is
  /// "delivered".
  Future<void> onReceipt(
    ChatMessage message,
    Conversation conversation,
    String memberId, {
    required int relayHops,
  }) async {
    final groupId = conversation.groupId;
    if (groupId == null || memberId == _ctx.ownId) return;
    final g = await _groups.getGroup(groupId);
    if (g == null || !g.hasMember(memberId)) return;
    final added = await _repo.addReceipt(message.id, memberId, _ctx.clock.nowMs);
    if (!added) return;
    final confirmed = await _repo.receiptCount(message.id);
    if (message.recipientCount > 0 && confirmed >= message.recipientCount) {
      await _repo.updateOutgoingStatus(message.id, MessageStatus.delivered, hops: relayHops);
    }
  }
}
