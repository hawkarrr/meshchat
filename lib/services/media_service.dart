import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../core/bytes.dart';
import '../core/text.dart';
import '../database/media_repository.dart';
import '../database/message_repository.dart';
import '../mesh/mesh_router.dart' show SubmitOutcome;
import '../models/conversation.dart';
import '../models/group.dart';
import '../models/media.dart';
import '../models/message.dart';
import '../models/peer.dart';
import '../models/room.dart';
import '../protocol/mesh_packet.dart';
import '../protocol/protocol_constants.dart';
import 'encryption_service.dart';
import 'media_store.dart';
import 'message_errors.dart';
import 'service_context.dart';

export 'media_store.dart';
import '../models/delivery_problem.dart';

/// An image or voice message the user wants to send. The bytes are already
/// compressed (a JPEG, or AAC audio in an .m4a container) and small enough to
/// travel by Bluetooth.
class MediaDraft {
  const MediaDraft({
    required this.kind,
    required this.bytes,
    this.width = 0,
    this.height = 0,
    this.durationMs = 0,
    this.waveform = const <int>[],
    this.caption = '',
    this.replyToId,
    this.forwardedFrom,
  });

  final MediaKind kind;
  final Uint8List bytes;
  final int width;
  final int height;
  final int durationMs;

  /// Amplitude samples (0..255) for drawing a voice waveform.
  final List<int> waveform;
  final String caption;

  /// The message this one answers (hex id), and the name of the original author
  /// when it is a forward.
  final String? replyToId;
  final String? forwardedFrom;

  int get mimeCode => switch (kind) {
        MediaKind.image => MediaMime.jpeg,
        MediaKind.voice => MediaMime.aacM4a,
        MediaKind.video => MediaMime.mp4,
      };

  /// The same picture or recording with a caption and/or a reply attached.
  MediaDraft copyWith({String? caption, String? replyToId, String? forwardedFrom}) => MediaDraft(
        kind: kind,
        bytes: bytes,
        width: width,
        height: height,
        durationMs: durationMs,
        waveform: waveform,
        caption: caption ?? this.caption,
        replyToId: replyToId ?? this.replyToId,
        forwardedFrom: forwardedFrom ?? this.forwardedFrom,
      );
}

/// Where a media message is going.
sealed class MediaRoute {
  const MediaRoute();
}

/// One person, end-to-end encrypted to them.
final class DirectMediaRoute extends MediaRoute {
  const DirectMediaRoute(this.peer);

  final Peer peer;
}

/// A private group, sealed under the group key.
final class GroupMediaRoute extends MediaRoute {
  const GroupMediaRoute(this.group, this.key);

  final GroupChat group;
  final GroupSealKey key;
}

/// A public room: readable by anyone who carries it, but signed.
final class RoomMediaRoute extends MediaRoute {
  const RoomMediaRoute(this.room);

  final PublicRoom room;
}

class MediaConfig {
  const MediaConfig({this.maxHeldChunks = 400});

  /// Chunks kept for media whose description (manifest) has not arrived. They
  /// are bounded so a stranger cannot fill the phone with orphans.
  final int maxHeldChunks;
}

/// Everything about images and voice messages: cutting them into chunks and
/// sending them, collecting chunks that arrive (in any order, from any path),
/// checking and storing the finished file, and cleaning up what never
/// completed.
///
/// An object travels as one *manifest* (a normal message that says what is
/// coming: size, chunk count, SHA-256, and for private chats the key) plus up
/// to 48 *chunk* packets of at most 1.5 KB each. The receiver assembles the
/// chunks, and only a file whose length and SHA-256 match the manifest is kept.
class MediaService {
  MediaService(this._ctx, this.store, {this.config = const MediaConfig()});

  final ServiceContext _ctx;
  final MediaStore store;
  final MediaConfig config;

  static const String _tag = 'Media';

  /// The largest video this phone will send, chosen by the person (never above
  /// [Protocol.maxVideoBytes]).
  int maxVideoSendBytes = Protocol.maxVideoBytes;

  /// Files that are on disk (or about to be) but whose row in the database is
  /// not written yet. A sweep must not take them for leftovers.
  final Set<String> _writing = <String>{};

  MediaRepository get _media => _ctx.mediaRepo;
  MessageRepository get _repo => _ctx.repo;
  EncryptionService get _crypto => _ctx.crypto;

  // ---------------------------------------------------------------------------
  // Sending
  // ---------------------------------------------------------------------------

  static String _cleanCaption(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return '';
    final out = StringBuffer();
    var bytes = 0;
    for (final rune in text.runes) {
      final ch = String.fromCharCode(rune);
      final n = _utf8Length(rune);
      if (bytes + n > Protocol.maxCaptionBytes) break;
      out.write(ch);
      bytes += n;
    }
    return out.toString();
  }

  static int _utf8Length(int rune) {
    if (rune < 0x80) return 1;
    if (rune < 0x800) return 2;
    if (rune < 0x10000) return 3;
    return 4;
  }

  void _validate(MediaDraft d) {
    if (d.bytes.isEmpty) {
      throw MessageError(MessageErrorKind.invalidMedia, _ctx.l10n.errFileEmpty);
    }
    final limit = d.kind == MediaKind.video
        ? (maxVideoSendBytes < Protocol.maxVideoBytes ? maxVideoSendBytes : Protocol.maxVideoBytes)
        : Protocol.maxMediaBytes;
    if (d.bytes.length > limit) {
      throw MessageError(
        MessageErrorKind.mediaTooLarge,
        _ctx.l10n.errTooLargeForMesh((d.bytes.length / 1024).ceil(), limit ~/ 1024),
      );
    }
    if (d.kind == MediaKind.image && (d.width <= 0 || d.height <= 0 || d.width > 8192 || d.height > 8192)) {
      throw MessageError(MessageErrorKind.invalidMedia, _ctx.l10n.errPictureUnreadable);
    }
    if (d.kind == MediaKind.video && (d.width > 8192 || d.height > 8192)) {
      throw MessageError(MessageErrorKind.invalidMedia, _ctx.l10n.errVideoUnreadable);
    }
    if (d.kind == MediaKind.voice &&
        (d.durationMs <= 0 || d.durationMs > Protocol.maxVoiceDuration.inMilliseconds + 5000)) {
      throw MessageError(
        MessageErrorKind.invalidMedia,
        _ctx.l10n.errVoiceTooLong(Protocol.maxVoiceDuration.inSeconds),
      );
    }
    if (d.waveform.length > Protocol.maxWaveformSamples) {
      throw MessageError(MessageErrorKind.invalidMedia, _ctx.l10n.errRecordingUnreadable);
    }
  }

  /// Seals, signs, stores and queues an image or voice message. The returned
  /// message is already stored as `queued`; it becomes `sent` once a neighbour
  /// has it and `delivered` when the recipient(s) confirmed.
  Future<ChatMessage> send({
    required Conversation conversation,
    required MediaRoute route,
    required MediaDraft draft,
  }) async {
    _validate(draft);
    if (draft.kind == MediaKind.video && route is RoomMediaRoute) {
      throw MessageError(
        MessageErrorKind.notAllowed,
        _ctx.l10n.errVideoNotInRooms,
      );
    }
    final caption = _cleanCaption(draft.caption);
    final now = _ctx.clock.nowMs;
    final mediaId = _crypto.randomBytes(Protocol.messageIdLength);
    final mediaIdHex = bytesToHex(mediaId);
    final sha = Uint8List.fromList((await Sha256().hash(draft.bytes)).bytes);
    final chunkCount = EnvelopeCodec.chunkCountFor(draft.bytes.length);
    final nickname = _ctx.ownNickname;

    final directKey = route is DirectMediaRoute ? _crypto.randomBytes(Protocol.keyLength) : null;
    MediaEnvelope manifest({String? nick}) => MediaEnvelope(
          mediaKind: draft.kind,
          mediaId: mediaId,
          mimeCode: draft.mimeCode,
          byteLength: draft.bytes.length,
          chunkCount: chunkCount,
          sha256: sha,
          key: directKey,
          width: draft.width,
          height: draft.height,
          durationMs: draft.durationMs,
          waveform: draft.waveform,
          caption: caption,
          nickname: nick,
          replyTo: draft.replyToId == null ? null : hexToBytes(draft.replyToId!),
          forwardedFrom: draft.forwardedFrom,
        );

    final MeshPacket manifestPacket;
    final List<MeshPacket> chunkPackets = <MeshPacket>[];
    try {
      Uint8List chunkBytes(int i) => Uint8List.sublistView(
            draft.bytes,
            i * Protocol.mediaChunkBytes,
            min((i + 1) * Protocol.mediaChunkBytes, draft.bytes.length),
          );
      switch (route) {
        case DirectMediaRoute(:final peer):
          final agreement = peer.agreementKey;
          if (agreement == null) {
            throw MessageError(
              MessageErrorKind.noEncryptionKey,
              _ctx.l10n.errNoKeyOnce,
            );
          }
          manifestPacket = await _crypto.buildDirectEnvelope(
            recipientSigningKey: peer.signingKey,
            recipientAgreementKey: agreement,
            envelope: manifest(),
          );
          for (var i = 0; i < chunkCount; i++) {
            chunkPackets.add(await _crypto.buildChunk(
              type: PacketType.direct,
              recipientKey: peer.signingKey,
              mediaId: mediaId,
              index: i,
              count: chunkCount,
              data: chunkBytes(i),
              key: directKey,
            ));
          }
        case GroupMediaRoute(:final key):
          manifestPacket = await _crypto.buildGroupMessage(
            group: key,
            envelope: manifest(nick: nickname),
          );
          final mediaKey = await EncryptionService.groupMediaKey(key.key, mediaId);
          for (var i = 0; i < chunkCount; i++) {
            chunkPackets.add(await _crypto.buildChunk(
              type: PacketType.group,
              recipientKey: key.groupId,
              mediaId: mediaId,
              index: i,
              count: chunkCount,
              data: chunkBytes(i),
              key: mediaKey,
              epoch: key.epoch,
            ));
          }
        case RoomMediaRoute(:final room):
          manifestPacket = await _crypto.buildRoomMessage(
            roomId: room.idBytes,
            envelope: manifest(nick: nickname),
          );
          for (var i = 0; i < chunkCount; i++) {
            chunkPackets.add(await _crypto.buildChunk(
              type: PacketType.room,
              recipientKey: room.idBytes,
              mediaId: mediaId,
              index: i,
              count: chunkCount,
              data: chunkBytes(i),
            ));
          }
      }
    } on ArgumentError catch (e) {
      throw MessageError(MessageErrorKind.invalidMedia, '${e.message}');
    } on EnvelopeFormatException catch (e) {
      throw MessageError(MessageErrorKind.invalidMedia, e.message);
    }

    final fileName = '$mediaIdHex.${MediaMime.extension(draft.mimeCode)}';
    final messageId = manifestPacket.messageIdHex;
    final message = ChatMessage(
      id: messageId,
      conversationId: conversation.id,
      senderId: _ctx.ownId,
      senderNickname: route is DirectMediaRoute ? null : nickname,
      isOutgoing: true,
      kind: draft.kind.messageKind,
      body: caption,
      mediaId: mediaIdHex,
      sortTimeMs: now,
      claimedTimestampMs: manifestPacket.timestampMs,
      status: MessageStatus.queued,
      recipientCount: route is GroupMediaRoute ? route.group.members.length - 1 : 0,
      replyToId: draft.replyToId,
      forwardedFrom: draft.forwardedFrom,
    );
    _writing.add(fileName);
    try {
      await store.save(fileName, draft.bytes);
      await _repo.insertMessage(message);
      await _media.insert(MediaItem(
        id: mediaIdHex,
        messageId: messageId,
        kind: draft.kind,
        mimeCode: draft.mimeCode,
        byteLength: draft.bytes.length,
        chunkCount: chunkCount,
        sha256: sha,
        width: draft.width,
        height: draft.height,
        durationMs: draft.durationMs,
        waveform: draft.waveform,
        state: MediaState.ready,
        receivedChunks: chunkCount,
        fileName: fileName,
        createdAtMs: now,
        expiresAtMs: now + Protocol.partialMediaTtl.inMilliseconds,
      ));
    } finally {
      _writing.remove(fileName);
    }
    if (route is DirectMediaRoute) {
      // A private upload is delivered once the manifest AND every chunk were
      // confirmed by the recipient.
      await _media.addOutgoingParts(
          messageId, [messageId, for (final c in chunkPackets) c.messageIdHex]);
    }

    // Description first, then the chunks.
    var ok = await _ctx.router.submit(manifestPacket) == SubmitOutcome.queued;
    for (final c in chunkPackets) {
      if (!ok) break;
      ok = await _ctx.router.submit(c) == SubmitOutcome.queued;
    }
    if (!ok) {
      await _repo.updateOutgoingStatus(messageId, MessageStatus.failed,
          error: DeliveryProblem.queueFailed.code);
    }
    return message;
  }

  /// The bytes of a finished media file.
  Future<Uint8List?> read(MediaItem item) async {
    final name = item.fileName;
    if (name == null || !item.isReady) return null;
    return store.read(name);
  }

  Future<String?> pathOf(MediaItem item) async {
    final name = item.fileName;
    return name == null ? null : store.pathOf(name);
  }

  // ---------------------------------------------------------------------------
  // Receiving: manifests
  // ---------------------------------------------------------------------------

  /// A media message arrived (private, group or room). Stores the message and
  /// starts collecting its chunks, including any that arrived before it.
  /// Returns false when it was a repeat of something we already had.
  Future<bool> onManifest({
    required MeshPacket packet,
    required MediaEnvelope manifest,
    required Conversation conversation,
    String? senderNickname,
    required int relayHops,
  }) async {
    final now = _ctx.clock.nowMs;
    final mediaIdHex = manifest.mediaIdHex;
    if (await _media.get(mediaIdHex) != null) return false;

    final inserted = await _repo.insertMessage(ChatMessage(
      id: packet.messageIdHex,
      conversationId: conversation.id,
      senderId: packet.senderHex,
      senderNickname: senderNickname,
      isOutgoing: false,
      kind: manifest.mediaKind.messageKind,
      body: manifest.caption,
      mediaId: mediaIdHex,
      sortTimeMs: now,
      claimedTimestampMs: packet.timestampMs,
      status: MessageStatus.received,
      hops: relayHops,
      replyToId: manifest.replyTo == null ? null : bytesToHex(manifest.replyTo!),
      forwardedFrom: manifest.forwardedFrom == null
          ? null
          : sanitizeDisplayName(manifest.forwardedFrom!, maxBytes: Protocol.maxNicknameBytes),
    ));
    if (!inserted) return false;

    final item = MediaItem(
      id: mediaIdHex,
      messageId: packet.messageIdHex,
      kind: manifest.mediaKind,
      mimeCode: manifest.mimeCode,
      byteLength: manifest.byteLength,
      chunkCount: manifest.chunkCount,
      sha256: manifest.sha256,
      width: manifest.width,
      height: manifest.height,
      durationMs: manifest.durationMs,
      waveform: manifest.waveform,
      state: MediaState.receiving,
      createdAtMs: now,
      expiresAtMs: now + Protocol.partialMediaTtl.inMilliseconds,
    );
    await _media.insert(item, key: manifest.key);
    await _adoptHeldChunks(item, manifest.key, packet.senderHex);
    await _tryAssemble(item);
    return true;
  }

  /// Chunks that arrived before their manifest are picked up now.
  Future<void> _adoptHeldChunks(MediaItem item, Uint8List? key, String authorId) async {
    for (final held in await _media.chunks(item.id)) {
      if (held.index >= item.chunkCount || held.senderId != authorId) {
        // Not part of this object, or injected by somebody else.
        await _media.deleteChunk(item.id, held.index);
        continue;
      }
      if (!held.sealed) continue;
      try {
        final packet = MeshPacket.decode(held.data);
        final chunk = EncryptionService.parseChunkPacket(packet).chunk;
        if (key == null || chunk.count != item.chunkCount) {
          await _media.deleteChunk(item.id, held.index);
          continue;
        }
        final plain = await EncryptionService.openChunkBody(packet: packet, chunk: chunk, key: key);
        if (plain.isEmpty || plain.length > Protocol.mediaChunkBytes) {
          await _media.deleteChunk(item.id, held.index);
          continue;
        }
        await _media.replaceChunk(item.id, held.index, plain);
      } on Object catch (e) {
        _ctx.log.w(_tag, 'dropped a held chunk that could not be opened: $e');
        await _media.deleteChunk(item.id, held.index);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Receiving: chunks
  // ---------------------------------------------------------------------------

  Future<({int? epoch, MediaChunk chunk})?> _parse(MeshPacket packet) async {
    try {
      return EncryptionService.parseChunkPacket(packet);
    } on DecryptionFailure {
      await _ctx.repo.recordSecurityEvent(
        SecurityEventKind.malformed,
        peerId: packet.senderHex,
        detail: 'media chunk',
        atMs: _ctx.clock.nowMs,
      );
      return null;
    }
  }

  /// A chunk of a private image / voice message. Returns whether it should be
  /// acknowledged (false: it was malformed or could not be kept).
  Future<bool> onDirectChunk(MeshPacket packet) async {
    final parsed = await _parse(packet);
    if (parsed == null) return false;
    final chunk = parsed.chunk;
    final item = await _media.get(chunk.mediaIdHex);
    if (item == null) {
      // The manifest has not arrived: keep the sealed packet until it does.
      if (await _media.orphanChunkCount() >= config.maxHeldChunks) return false;
      await _media.storeChunk(
        mediaId: chunk.mediaIdHex,
        index: chunk.index,
        data: packet.encode(),
        sealed: true,
        senderId: packet.senderHex,
        nowMs: _ctx.clock.nowMs,
      );
      return true;
    }
    if (!await _belongsTo(item, packet.senderHex)) return false;
    if (item.state != MediaState.receiving) return true; // already complete: confirm again
    if (chunk.count != item.chunkCount) return _badMedia(packet.senderHex, 'chunk count mismatch');
    final key = await _media.keyOf(item.id);
    if (key == null) return true;
    final Uint8List plain;
    try {
      plain = await EncryptionService.openChunkBody(packet: packet, chunk: chunk, key: key);
    } on DecryptionFailure {
      return _badMedia(packet.senderHex, 'chunk could not be decrypted', decrypt: true);
    }
    return _accept(item, chunk.index, plain, packet.senderHex);
  }

  /// A chunk whose body the caller has already opened (group chunks, whose key
  /// comes from the group; room chunks, which are not sealed).
  Future<void> onOpenedChunk({
    required MediaChunk chunk,
    required Uint8List plain,
    required String senderId,
  }) async {
    final item = await _media.get(chunk.mediaIdHex);
    if (item == null) {
      if (plain.isEmpty || plain.length > Protocol.mediaChunkBytes) return;
      if (await _media.orphanChunkCount() >= config.maxHeldChunks) return;
      await _media.storeChunk(
        mediaId: chunk.mediaIdHex,
        index: chunk.index,
        data: plain,
        sealed: false,
        senderId: senderId,
        nowMs: _ctx.clock.nowMs,
      );
      return;
    }
    if (!await _belongsTo(item, senderId)) return;
    if (item.state != MediaState.receiving) return;
    if (chunk.count != item.chunkCount) {
      await _badMedia(senderId, 'chunk count mismatch');
      return;
    }
    await _accept(item, chunk.index, plain, senderId);
  }

  /// Chunks belong to the author of the manifest and nobody else.
  Future<bool> _belongsTo(MediaItem item, String senderId) async {
    final message = await _repo.getMessage(item.messageId);
    if (message == null || message.isOutgoing || message.senderId != senderId) {
      await _badMedia(senderId, 'chunk for media from another sender');
      return false;
    }
    return true;
  }

  Future<bool> _badMedia(String peerId, String detail, {bool decrypt = false}) async {
    await _ctx.repo.recordSecurityEvent(
      decrypt ? SecurityEventKind.decryptFailed : SecurityEventKind.badMedia,
      peerId: peerId,
      detail: detail,
      atMs: _ctx.clock.nowMs,
    );
    return false;
  }

  Future<bool> _accept(MediaItem item, int index, Uint8List plain, String senderId) async {
    if (index >= item.chunkCount || plain.isEmpty || plain.length > Protocol.mediaChunkBytes) {
      return _badMedia(senderId, 'chunk out of range');
    }
    await _media.storeChunk(
      mediaId: item.id,
      index: index,
      data: plain,
      sealed: false,
      senderId: senderId,
      nowMs: _ctx.clock.nowMs,
    );
    await _tryAssemble(item);
    return true;
  }

  /// Whether we already hold (or finished) this chunk, so a repeat of it can be
  /// confirmed again without pretending to have something we dropped.
  Future<bool> holdsChunk(MeshPacket packet) async {
    final ({int? epoch, MediaChunk chunk}) parsed;
    try {
      parsed = EncryptionService.parseChunkPacket(packet);
    } on DecryptionFailure {
      return false;
    }
    final item = await _media.get(parsed.chunk.mediaIdHex);
    if (item != null && item.state != MediaState.receiving) return true;
    final held = await _media.chunks(parsed.chunk.mediaIdHex);
    return held.any((c) => c.index == parsed.chunk.index);
  }

  Future<void> _tryAssemble(MediaItem item) async {
    final have = await _media.plainChunkCount(item.id);
    await _media.setReceivedChunks(item.id, have);
    if (have < item.chunkCount) return;

    final chunks = await _media.chunks(item.id, sealed: false);
    final complete = chunks.length == item.chunkCount &&
        [for (var i = 0; i < chunks.length; i++) chunks[i].index == i].every((x) => x);
    if (!complete) return;

    final bytes = concatBytes(chunks.map((c) => c.data));
    final digest = Uint8List.fromList((await Sha256().hash(bytes)).bytes);
    if (bytes.length != item.byteLength || !constantTimeEquals(digest, item.sha256)) {
      await _media.deleteChunks(item.id);
      await _media.setState(item.id, MediaState.failed,
          error: DeliveryProblem.fileDamaged.code, dropKey: true);
      final message = await _repo.getMessage(item.messageId);
      await _badMedia(message?.senderId ?? '', 'checksum mismatch');
      return;
    }

    final fileName = '${item.id}.${MediaMime.extension(item.mimeCode)}';
    _writing.add(fileName);
    try {
      await store.save(fileName, bytes);
      await _media.setState(item.id, MediaState.ready, fileName: fileName, dropKey: true);
    } finally {
      _writing.remove(fileName);
    }
    await _media.deleteChunks(item.id);

    // In a group the author learns that this member has the whole file only
    // now (not when the description arrived).
    final message = await _repo.getMessage(item.messageId);
    if (message != null && !message.isOutgoing) {
      final conversation = await _repo.getConversation(message.conversationId);
      if (conversation != null && conversation.isGroup) {
        _ctx.acks.add(hexToBytes(message.senderId), hexToBytes(message.id));
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Housekeeping
  // ---------------------------------------------------------------------------

  /// Gives up on files that never completed, drops orphan chunks, and deletes
  /// files nothing refers to any more.
  Future<void> maintain() async {
    final now = _ctx.clock.nowMs;
    for (final item in await _media.expiredPartial(now)) {
      await _media.deleteChunks(item.id);
      await _media.setState(item.id, MediaState.failed,
          error: DeliveryProblem.fileIncomplete.code, dropKey: true);
    }
    await _media.pruneOrphanChunks(now - Protocol.partialMediaTtl.inMilliseconds);
    await sweepFiles();
  }

  /// Deletes every file that no database row refers to, at once - a deleted
  /// chat's pictures are gone when the chat is.
  ///
  /// The order matters. A file that is in the list below was written before
  /// the list was read, so its name went into [_writing] before; if it is no
  /// longer in [_writing] when that set is copied, its row was already written
  /// (or its write failed), and the database read after that shows it. So a
  /// file being saved right now is never mistaken for a leftover.
  /// Drops the half-received pieces of messages that were removed. (The finished
  /// files go with the next [sweepFiles].)
  Future<void> forget(Iterable<ChatMessage> removed) async {
    for (final m in removed) {
      final id = m.mediaId;
      if (id != null) await _media.deleteChunks(id);
    }
  }

  Future<void> sweepFiles() async {
    final onDisk = await store.list();
    final writing = Set<String>.of(_writing);
    final referenced = await _media.referencedFileNames();
    for (final file in onDisk) {
      if (referenced.contains(file.name) || writing.contains(file.name)) continue;
      await store.delete(file.name);
    }
  }
}
