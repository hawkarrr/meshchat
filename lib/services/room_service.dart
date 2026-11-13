import 'dart:async';
import 'dart:typed_data';

import '../core/bytes.dart';
import '../core/text.dart';
import '../database/message_repository.dart';
import '../database/room_repository.dart';
import '../mesh/mesh_router.dart' show SubmitOutcome;
import '../models/conversation.dart';
import '../models/message.dart';
import '../models/room.dart';
import '../protocol/mesh_packet.dart';
import '../protocol/protocol_constants.dart';
import 'encryption_service.dart';
import 'media_service.dart';
import 'message_errors.dart';
import 'service_context.dart';
import '../models/delivery_problem.dart';

/// Public rooms: named places anybody in range can read and post in.
///
///  * Everything said in a room is visible to every phone that carries it.
///    There is no secrecy here - only authorship (every message is signed) and
///    integrity (a relay cannot change a word).
///  * The built-in `#mesh` room is open to everyone with the app.
///  * Anyone can create a room. Its creator signs a *record* (name, description,
///    expiry, version); phones pass records on without being able to alter
///    them, so rooms are discovered by walking past people who know them.
///  * A record is only kept for a limited time unless its creator refreshes it,
///    so abandoned rooms disappear on their own.
class RoomService {
  RoomService(
    this._ctx,
    this._media, {
    this.refreshWhenLessThan = const Duration(hours: 12),
    this.announcePerCycle = 8,
  });

  final ServiceContext _ctx;
  final MediaService _media;

  /// A room we created is renewed when it would expire within this long.
  final Duration refreshWhenLessThan;

  /// How many rooms are announced each time the neighbours are told (the list
  /// rotates, so every known room gets its turn).
  final int announcePerCycle;

  static const String _tag = 'Rooms';

  RoomRepository get _rooms => _ctx.roomRepo;
  MessageRepository get _repo => _ctx.repo;
  EncryptionService get _crypto => _ctx.crypto;

  int _announceCursor = 0;
  final Map<String, int> _lastMalformedMs = <String, int>{};

  // ---------------------------------------------------------------------------
  // Queries and setup
  // ---------------------------------------------------------------------------

  /// Makes sure `#mesh` exists, is joined, and has its conversation.
  Future<void> start() async {
    final now = _ctx.clock.nowMs;
    await _rooms.ensureBuiltin(now);
    await _repo.ensureRoomConversation(PublicRooms.meshIdHex, '#${PublicRooms.meshName}', nowMs: now);
    // Joined rooms always have a conversation.
    for (final r in await _rooms.joinedRooms()) {
      await _repo.ensureRoomConversation(r.id, r.label, nowMs: now);
    }
  }

  Future<PublicRoom?> get(String roomId) => _rooms.getRoom(roomId);

  Future<List<PublicRoom>> list() => _rooms.listRooms();

  Future<bool> isJoined(Uint8List roomId) => _rooms.isJoined(bytesToHex(roomId));

  // ---------------------------------------------------------------------------
  // Creating, joining, leaving
  // ---------------------------------------------------------------------------

  String _cleanRoomName(String raw) {
    var name = raw.trim();
    while (name.startsWith('#')) {
      name = name.substring(1).trimLeft();
    }
    name = sanitizeDisplayName(name, maxBytes: Protocol.maxRoomNameBytes);
    if (name.isEmpty) {
      throw MessageError(MessageErrorKind.invalidName, _ctx.l10n.errRoomName);
    }
    return name;
  }

  Future<PublicRoom> create({required String name, String description = ''}) async {
    final cleanName = _cleanRoomName(name);
    final cleanDescription =
        sanitizeDisplayName(description, maxBytes: Protocol.maxRoomDescriptionBytes);
    final record = await _crypto.createRoomRecord(name: cleanName, description: cleanDescription);
    final now = _ctx.clock.nowMs;
    await _rooms.upsertRecord(record, nowMs: now, join: true);
    final room = (await _rooms.getRoom(record.roomIdHex))!;
    await _repo.ensureRoomConversation(room.id, room.label, nowMs: now);
    // Tell whoever is around straight away.
    unawaited(_ctx.router.announceRoomsNow());
    return room;
  }

  Future<PublicRoom> join(String roomId) async {
    final room = await _rooms.getRoom(roomId);
    if (room == null) {
      throw MessageError(MessageErrorKind.unknownRoom, _ctx.l10n.errRoomGone);
    }
    await _rooms.setJoined(roomId, true);
    await _repo.ensureRoomConversation(room.id, room.label, nowMs: _ctx.clock.nowMs);
    return (await _rooms.getRoom(roomId))!;
  }

  /// Leaves a room and removes its history from this phone.
  Future<void> leave(String roomId) async {
    final room = await _rooms.getRoom(roomId);
    if (room == null) return;
    if (room.builtin) {
      throw MessageError(MessageErrorKind.notJoined, _ctx.l10n.errMeshCannotLeave);
    }
    await _rooms.setJoined(roomId, false);
    await _repo.deleteConversation(Conversation.roomConversationId(roomId));
    await _media.sweepFiles();
  }

  // ---------------------------------------------------------------------------
  // Messages
  // ---------------------------------------------------------------------------

  Future<PublicRoom> _requireJoined(String roomId) async {
    final room = await _rooms.getRoom(roomId);
    if (room == null) {
      throw MessageError(MessageErrorKind.unknownRoom, _ctx.l10n.errRoomGone);
    }
    if (!room.joined) {
      throw MessageError(MessageErrorKind.notJoined, _ctx.l10n.errJoinFirst);
    }
    return room;
  }

  /// Handles edit and delete requests that arrive in a room's traffic (set by
  /// the message service). Returns whether the request was acceptable.
  Future<bool> Function(Conversation conversation, String senderId, Envelope envelope)?
      controls;

  /// Signs [envelope] (an edit or delete request) for the room.
  Future<MeshPacket> buildEnvelopePacket(String roomId, Envelope envelope) async {
    final room = await _requireJoined(roomId);
    return _crypto.buildRoomMessage(roomId: room.idBytes, envelope: envelope);
  }

  Future<ChatMessage> sendText(String roomId, String rawText,
      {String? replyToId, String? forwardedFrom}) async {
    final text = validateMessageText(rawText, _ctx.l10n);
    final room = await _requireJoined(roomId);
    await validateReplyTarget(_repo, Conversation.roomConversationId(room.id), replyToId, _ctx.l10n);
    final nickname = _ctx.ownNickname;
    final packet = await _crypto.buildRoomMessage(
      roomId: room.idBytes,
      envelope: TextEnvelope(text,
          nickname: nickname,
          replyTo: replyToId == null ? null : hexToBytes(replyToId),
          forwardedFrom: forwardedFrom),
    );
    final now = _ctx.clock.nowMs;
    final conversation = await _repo.ensureRoomConversation(room.id, room.label, nowMs: now);
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

  Future<RoomMediaRoute> mediaRoute(String roomId) async => RoomMediaRoute(await _requireJoined(roomId));

  /// A packet of a room we joined: a message, or a chunk of an image / voice
  /// message. Room messages are never acknowledged - there is no single
  /// recipient to confirm them.
  Future<void> onRoomPacket(MeshPacket packet, {required int relayHops}) async {
    final roomId = bytesToHex(packet.recipientKey);
    final room = await _rooms.getRoom(roomId);
    if (room == null || !room.joined) return;
    final sender = packet.senderHex;
    if ((await _repo.getPeer(sender))?.blocked ?? false) return;
    await _rooms.touch(roomId, _ctx.clock.nowMs);

    if (packet.isChunk) {
      final ({int? epoch, MediaChunk chunk}) parsed;
      try {
        parsed = EncryptionService.parseChunkPacket(packet);
      } on DecryptionFailure {
        return;
      }
      await _media.onOpenedChunk(chunk: parsed.chunk, plain: parsed.chunk.body, senderId: sender);
      return;
    }

    final Envelope envelope;
    try {
      envelope = EncryptionService.openRoomMessage(packet);
    } on DecryptionFailure catch (e) {
      final now = _ctx.clock.nowMs;
      if (now - (_lastMalformedMs[roomId] ?? 0) >= 30000) {
        _lastMalformedMs[roomId] = now;
        await _repo.recordSecurityEvent(
          SecurityEventKind.malformed,
          peerId: sender,
          detail: 'room ${room.label}: ${e.reason.name}',
          atMs: now,
        );
      }
      return;
    }

    final now = _ctx.clock.nowMs;
    final conversation = await _repo.ensureRoomConversation(room.id, room.label, nowMs: now);
    final announced = switch (envelope) {
      TextEnvelope(:final nickname) => nickname,
      MediaEnvelope(:final nickname) => nickname,
      _ => null,
    };
    final cleaned = sanitizeDisplayName(announced ?? '');
    final nickname = cleaned.isNotEmpty ? cleaned : 'Peer ${sender.substring(0, 4)}';

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
      case MediaEnvelope():
        if (envelope.mediaKind == MediaKind.video) {
          // This app never sends one: a video would have to be carried by every
          // phone in range. Whoever did, it is not shown.
          await _repo.recordSecurityEvent(
            SecurityEventKind.malformed,
            peerId: sender,
            detail: 'a video in a public room',
            atMs: now,
          );
          return;
        }
        previewKind = envelope.mediaKind;
        stored = await _media.onManifest(
          packet: packet,
          manifest: envelope,
          conversation: conversation,
          senderNickname: nickname,
          relayHops: relayHops,
        );
      case EditEnvelope():
      case DeleteEnvelope():
        await controls?.call(conversation, sender, envelope);
        return;
      default:
        return;
    }
    if (stored) {
      _ctx.notify(IncomingNotice(
        conversationId: conversation.id,
        title: room.label,
        type: ConversationType.room,
        messageId: packet.messageIdHex,
        preview: preview,
        mediaKind: previewKind,
        sender: nickname,
      ));
    }
  }

  // ---------------------------------------------------------------------------
  // Discovery
  // ---------------------------------------------------------------------------

  /// A room announcement arrived. Returns whether it was valid and taught us
  /// something, i.e. whether neighbours should hear about it too.
  Future<bool> onAnnounce(MeshPacket packet, RoomRecord record) async {
    final now = _ctx.clock.nowMs;
    if (record.creatorId == _ctx.ownId) return false;
    // Names come from strangers: anything with hidden or bidi-control
    // characters is refused rather than cleaned (the record is signed, so it
    // cannot be altered without breaking it).
    if (sanitizeDisplayName(record.name, maxBytes: Protocol.maxRoomNameBytes) != record.name ||
        sanitizeDisplayName(record.description, maxBytes: Protocol.maxRoomDescriptionBytes) !=
            record.description) {
      return false;
    }
    if (!record.lifetimeAcceptableAt(now)) return false;
    if (!await EncryptionService.verifyRoomRecord(record)) {
      await _repo.recordSecurityEvent(
        SecurityEventKind.badSignature,
        peerId: packet.senderHex,
        detail: 'room record',
        atMs: now,
      );
      return false;
    }
    final outcome = await _rooms.upsertRecord(record, nowMs: now);
    return outcome != RoomUpsertOutcome.unchanged;
  }

  /// Signed announcements of the rooms worth telling neighbours about. Rooms we
  /// created are renewed here when they are about to lapse.
  Future<List<MeshPacket>> buildAnnouncements() async {
    final now = _ctx.clock.nowMs;
    final known = await _rooms.announceable(now);
    if (known.isEmpty) return const <MeshPacket>[];
    final count = known.length < announcePerCycle ? known.length : announcePerCycle;
    final out = <MeshPacket>[];
    for (var i = 0; i < count; i++) {
      final room = known[(_announceCursor + i) % known.length];
      try {
        var record = RoomRecord.parse(room.record!);
        if (room.creatorId == _ctx.ownId &&
            record.expiresAtMs - now < refreshWhenLessThan.inMilliseconds) {
          record = await _crypto.refreshRoomRecord(record);
          await _rooms.upsertRecord(record, nowMs: now);
        }
        out.add(await _crypto.buildRoomAnnounce(record));
      } on Object catch (e) {
        _ctx.log.w(_tag, 'skipped announcing ${room.label}: $e');
      }
    }
    _announceCursor = (_announceCursor + count) % known.length;
    return out;
  }

  Future<void> maintain() async {
    await _rooms.purgeExpired(_ctx.clock.nowMs);
  }
}
