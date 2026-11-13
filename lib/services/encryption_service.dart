import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../core/bytes.dart';
import '../core/clock.dart';
import '../crypto/aead.dart';
import '../crypto/fingerprint.dart';
import '../crypto/hpke.dart';
import '../crypto/key_store.dart';
import '../crypto/signatures.dart';
import '../protocol/envelope.dart';
import '../protocol/media_chunk.dart';
import '../protocol/mesh_packet.dart';
import '../protocol/packet_payloads.dart';
import '../protocol/protocol_constants.dart';
import '../protocol/room_record.dart';

export '../protocol/envelope.dart';
export '../protocol/media_chunk.dart';
export '../protocol/packet_payloads.dart' show AckContent, AnnounceContent;
export '../protocol/room_record.dart';

/// The public half of this phone's identity.
///
/// An identity is a pair of long-term keys:
///  * an Ed25519 key that signs everything this phone originates (and is the
///    identity's name on the network), and
///  * an X25519 key that others encrypt direct messages to.
/// They are generated from independent random seeds. The X25519 key is bound
/// to the Ed25519 key by the signed announcement that carries it.
class LocalIdentity {
  const LocalIdentity({
    required this.signingPublicKey,
    required this.agreementPublicKey,
  });

  final Uint8List signingPublicKey;
  final Uint8List agreementPublicKey;

  /// Lower-case hex of the signing key; used as the stable id everywhere.
  String get id => bytesToHex(signingPublicKey);

  Future<Uint8List> fingerprint() => Fingerprints.of(
        signingKey: signingPublicKey,
        agreementKey: agreementPublicKey,
      );
}

class DirectContent {
  const DirectContent(this.text);

  final String text;
}

/// The key of one group at one epoch, as needed to seal or open its packets.
class GroupSealKey {
  const GroupSealKey({required this.groupId, required this.epoch, required this.key});

  final Uint8List groupId;
  final int epoch;
  final Uint8List key;
}

enum DecryptionFailureReason {
  /// The packet is addressed to somebody else.
  notForUs,

  /// The packet has the wrong type for this operation.
  wrongType,

  /// The payload is structurally invalid.
  malformed,

  /// Authentication failed: wrong key, corrupted or tampered ciphertext.
  authenticationFailed,
}

class DecryptionFailure implements Exception {
  const DecryptionFailure(this.reason);

  final DecryptionFailureReason reason;

  @override
  String toString() => 'DecryptionFailure(${reason.name})';
}

/// Identity management and all cryptographic message operations.
///
/// Only established constructions are used - nothing here is a custom
/// algorithm:
///
///  * Direct messages (text, media manifests, group invitations): RFC 9180
///    HPKE (X25519 / HKDF-SHA256 / ChaCha20-Poly1305), then an Ed25519
///    signature over the whole packet.
///  * Group messages and media chunks: ChaCha20-Poly1305 under a random
///    per-group key (rotated when a member is removed), bound to the packet
///    header, plus the same Ed25519 packet signature.
///  * Public-room messages: signed but deliberately not encrypted - anyone in
///    range of the room can read them, and no relay can alter or forge them.
///  * Link authentication: Ed25519 signatures over fresh random challenges.
///
/// Neither the construction as a whole nor this implementation has been
/// independently audited. The primitives and HPKE are verified against the
/// published test vectors in the unit tests.
class EncryptionService {
  EncryptionService._({
    required this._signingKeyPair,
    required this._agreementKeyPair,
    required this.identity,
    required this._random,
    required this._clock,
    required this.createdNewIdentity,
  });

  static const String _signingSeedName = 'identity.signing.seed';
  static const String _agreementSeedName = 'identity.agreement.seed';
  static const int _seedLength = 32;
  static const int _padBlock = 64;

  final SimpleKeyPair _signingKeyPair;
  final SimpleKeyPair _agreementKeyPair;
  final Random _random;
  final Clock _clock;

  /// This phone's public identity.
  final LocalIdentity identity;

  /// True when no usable keys were found in the key store and fresh ones were
  /// generated (first launch, or secure storage was wiped/unreadable).
  final bool createdNewIdentity;

  static final Ed25519 _ed25519 = Ed25519();
  static final X25519 _x25519 = X25519();

  /// Loads the identity from [store], creating and persisting one if absent.
  static Future<EncryptionService> loadOrCreate(
    KeyStore store, {
    Random? random,
    Clock clock = const SystemClock(),
  }) async {
    final rng = random ?? Random.secure();
    final signingSeed = await store.read(_signingSeedName);
    final agreementSeed = await store.read(_agreementSeedName);
    if (signingSeed != null &&
        agreementSeed != null &&
        signingSeed.length == _seedLength &&
        agreementSeed.length == _seedLength) {
      return _fromSeeds(signingSeed, agreementSeed, rng, clock, created: false);
    }
    return createFresh(store, random: rng, clock: clock);
  }

  /// Generates a brand new identity, replacing any stored one.
  static Future<EncryptionService> createFresh(
    KeyStore store, {
    Random? random,
    Clock clock = const SystemClock(),
  }) async {
    final rng = random ?? Random.secure();
    final signingSeed = _randomBytesFrom(rng, _seedLength);
    final agreementSeed = _randomBytesFrom(rng, _seedLength);
    await store.write(_signingSeedName, signingSeed);
    await store.write(_agreementSeedName, agreementSeed);
    return _fromSeeds(signingSeed, agreementSeed, rng, clock, created: true);
  }

  /// Removes the stored identity seeds.
  static Future<void> deleteStoredIdentity(KeyStore store) async {
    await store.delete(_signingSeedName);
    await store.delete(_agreementSeedName);
  }

  static Future<EncryptionService> _fromSeeds(
    Uint8List signingSeed,
    Uint8List agreementSeed,
    Random rng,
    Clock clock, {
    required bool created,
  }) async {
    final signing = await _ed25519.newKeyPairFromSeed(signingSeed);
    final agreement = await _x25519.newKeyPairFromSeed(agreementSeed);
    final identity = LocalIdentity(
      signingPublicKey:
          Uint8List.fromList((await signing.extractPublicKey()).bytes),
      agreementPublicKey:
          Uint8List.fromList((await agreement.extractPublicKey()).bytes),
    );
    return EncryptionService._(
      signingKeyPair: signing,
      agreementKeyPair: agreement,
      identity: identity,
      random: rng,
      clock: clock,
      createdNewIdentity: created,
    );
  }

  // ---------------------------------------------------------------------------
  // Randomness
  // ---------------------------------------------------------------------------

  static Uint8List _randomBytesFrom(Random rng, int length) =>
      Uint8List.fromList(List<int>.generate(length, (_) => rng.nextInt(256)));

  Uint8List randomBytes(int length) => _randomBytesFrom(_random, length);

  // ---------------------------------------------------------------------------
  // Signing
  // ---------------------------------------------------------------------------

  Future<Uint8List> sign(Uint8List message) async {
    final s = await _ed25519.sign(message, keyPair: _signingKeyPair);
    return Uint8List.fromList(s.bytes);
  }

  Future<MeshPacket> _buildSigned({
    required PacketType type,
    required int hopLimit,
    required Uint8List messageId,
    required int timestampMs,
    required int expiresAtMs,
    required Uint8List recipientKey,
    required Uint8List payload,
    int flags = 0,
  }) async {
    final signingBytes = MeshPacket.buildSigningBytes(
      type: type,
      hopLimit: hopLimit,
      messageId: messageId,
      timestampMs: timestampMs,
      expiresAtMs: expiresAtMs,
      senderKey: identity.signingPublicKey,
      recipientKey: recipientKey,
      payload: payload,
      flags: flags,
    );
    return MeshPacket(
      type: type,
      flags: flags,
      hopLimit: hopLimit,
      messageId: messageId,
      timestampMs: timestampMs,
      expiresAtMs: expiresAtMs,
      senderKey: identity.signingPublicKey,
      recipientKey: recipientKey,
      payload: payload,
      signature: await sign(signingBytes),
    );
  }

  // ---------------------------------------------------------------------------
  // Announcements
  // ---------------------------------------------------------------------------

  /// Signed "here I am" broadcast binding this phone's X25519 key and
  /// nickname to its Ed25519 identity.
  Future<MeshPacket> buildAnnounce({required String nickname}) async {
    final payload = AnnounceContent(
      agreementKey: identity.agreementPublicKey,
      nickname: nickname,
    ).encode();
    final now = _clock.nowMs;
    return _buildSigned(
      type: PacketType.announce,
      hopLimit: Protocol.announceHopLimit,
      messageId: randomBytes(Protocol.messageIdLength),
      timestampMs: now,
      expiresAtMs: now + Protocol.announceTtl.inMilliseconds,
      recipientKey: Uint8List(Protocol.keyLength),
      payload: payload,
    );
  }

  static AnnounceContent parseAnnounce(MeshPacket packet) {
    if (packet.type != PacketType.announce) {
      throw const DecryptionFailure(DecryptionFailureReason.wrongType);
    }
    try {
      return AnnounceContent.parse(packet.payload);
    } on FormatException {
      throw const DecryptionFailure(DecryptionFailureReason.malformed);
    }
  }

  // ---------------------------------------------------------------------------
  // Direct messages (also used for media manifests and group control messages)
  // ---------------------------------------------------------------------------

  static Uint8List _directInfo(Uint8List sender, Uint8List recipient) =>
      concatBytes([utf8.encode('meshchat/v1/direct\u0000'), sender, recipient]);

  /// Pads [body] up to a multiple of 64 bytes with zeros so ciphertext
  /// length reveals only a coarse size bucket.
  static Uint8List _pad(Uint8List body) {
    final padded = ((body.length + _padBlock - 1) ~/ _padBlock) * _padBlock;
    final out = Uint8List(padded);
    out.setRange(0, body.length, body);
    return out;
  }

  static void _requireValidRecipient(Uint8List signingKey, Uint8List agreementKey, Uint8List own) {
    if (signingKey.length != Protocol.keyLength ||
        agreementKey.length != Protocol.keyLength ||
        isAllZero(signingKey)) {
      throw ArgumentError('Invalid recipient keys');
    }
    if (constantTimeEquals(signingKey, own)) {
      throw ArgumentError('Cannot send a direct message to yourself');
    }
  }

  /// Builds an end-to-end encrypted, signed direct text message.
  Future<MeshPacket> buildDirect({
    required Uint8List recipientSigningKey,
    required Uint8List recipientAgreementKey,
    required String text,
    int hopLimit = Protocol.directHopLimit,
    Duration ttl = Protocol.directMessageTtl,
  }) =>
      buildDirectEnvelope(
        recipientSigningKey: recipientSigningKey,
        recipientAgreementKey: recipientAgreementKey,
        envelope: TextEnvelope(text),
        hopLimit: hopLimit,
        ttl: ttl,
      );

  /// Builds an end-to-end encrypted, signed direct message carrying any
  /// [Envelope] (text, a media manifest, or a group invitation / update).
  Future<MeshPacket> buildDirectEnvelope({
    required Uint8List recipientSigningKey,
    required Uint8List recipientAgreementKey,
    required Envelope envelope,
    int hopLimit = Protocol.directHopLimit,
    Duration ttl = Protocol.directMessageTtl,
  }) async {
    _requireValidRecipient(recipientSigningKey, recipientAgreementKey, identity.signingPublicKey);
    final body = EnvelopeCodec.encode(envelope, withNickname: false);

    final messageId = randomBytes(Protocol.messageIdLength);
    final now = _clock.nowMs;
    final expires = now + ttl.inMilliseconds;
    final aad = MeshPacket.buildHeaderAad(
      type: PacketType.direct,
      hopLimit: hopLimit,
      messageId: messageId,
      timestampMs: now,
      expiresAtMs: expires,
      senderKey: identity.signingPublicKey,
      recipientKey: recipientSigningKey,
    );
    final sealed = await Hpke.sealBase(
      recipientPublicKey: recipientAgreementKey,
      info: _directInfo(identity.signingPublicKey, recipientSigningKey),
      aad: aad,
      plaintext: _pad(body),
    );
    return _buildSigned(
      type: PacketType.direct,
      hopLimit: hopLimit,
      messageId: messageId,
      timestampMs: now,
      expiresAtMs: expires,
      recipientKey: recipientSigningKey,
      payload: concatBytes([sealed.enc, sealed.ciphertext]),
    );
  }

  /// Decrypts a direct text message addressed to this phone.
  ///
  /// The caller must have verified the packet signature first; this method
  /// authenticates the *ciphertext* (via the AEAD) but not the sender.
  Future<DirectContent> openDirect(MeshPacket packet) async {
    final envelope = await openDirectEnvelope(packet);
    if (envelope is! TextEnvelope) {
      throw const DecryptionFailure(DecryptionFailureReason.wrongType);
    }
    return DirectContent(envelope.text);
  }

  /// Decrypts any direct message addressed to this phone.
  Future<Envelope> openDirectEnvelope(MeshPacket packet) async {
    if (packet.type != PacketType.direct || packet.isChunk) {
      throw const DecryptionFailure(DecryptionFailureReason.wrongType);
    }
    if (!constantTimeEquals(packet.recipientKey, identity.signingPublicKey)) {
      throw const DecryptionFailure(DecryptionFailureReason.notForUs);
    }
    const minPayload = Hpke.publicKeyLength + _padBlock + Hpke.tagLength;
    if (packet.payload.length < minPayload) {
      throw const DecryptionFailure(DecryptionFailureReason.malformed);
    }
    final enc = Uint8List.sublistView(packet.payload, 0, Hpke.publicKeyLength);
    final ct = Uint8List.sublistView(packet.payload, Hpke.publicKeyLength);
    final Uint8List plain;
    try {
      plain = await Hpke.openBase(
        recipientKeyPair: _agreementKeyPair,
        enc: Uint8List.fromList(enc),
        info: _directInfo(packet.senderKey, packet.recipientKey),
        aad: packet.headerAad(),
        ciphertext: Uint8List.fromList(ct),
      );
    } on HpkeException {
      throw const DecryptionFailure(DecryptionFailureReason.authenticationFailed);
    }
    try {
      return EnvelopeCodec.decode(plain, withNickname: false);
    } on EnvelopeFormatException {
      throw const DecryptionFailure(DecryptionFailureReason.malformed);
    }
  }

  // ---------------------------------------------------------------------------
  // Acknowledgements
  // ---------------------------------------------------------------------------

  /// Signed receipt for up to [AckContent.maxIds] messages, addressed to the
  /// phone that sent them.
  Future<MeshPacket> buildAck({
    required Uint8List recipientSigningKey,
    required List<Uint8List> ackedMessageIds,
  }) async {
    final now = _clock.nowMs;
    return _buildSigned(
      type: PacketType.ack,
      hopLimit: Protocol.ackHopLimit,
      messageId: randomBytes(Protocol.messageIdLength),
      timestampMs: now,
      expiresAtMs: now + Protocol.ackTtl.inMilliseconds,
      recipientKey: recipientSigningKey,
      payload: AckContent(
        status: AckContent.delivered,
        ackedMessageIds: ackedMessageIds,
      ).encode(),
    );
  }

  static AckContent parseAck(MeshPacket packet) {
    if (packet.type != PacketType.ack) {
      throw const DecryptionFailure(DecryptionFailureReason.wrongType);
    }
    try {
      return AckContent.parse(packet.payload);
    } on FormatException {
      throw const DecryptionFailure(DecryptionFailureReason.malformed);
    }
  }

  // ---------------------------------------------------------------------------
  // Groups
  // ---------------------------------------------------------------------------

  /// A brand-new group id and key (epoch 0), from the secure random source.
  GroupSealKey newGroupKey() => GroupSealKey(
        groupId: randomBytes(Protocol.keyLength),
        epoch: 0,
        key: randomBytes(Aead.keyLength),
      );

  /// The next epoch of [old] with a completely fresh key: used when a member
  /// is removed, so they cannot read anything sent afterwards.
  GroupSealKey rotatedGroupKey(GroupSealKey old) => GroupSealKey(
        groupId: old.groupId,
        epoch: old.epoch + 1,
        key: randomBytes(Aead.keyLength),
      );

  /// Text, media and the edit and delete events about them are conversation
  /// content. Group invitations and updates carry keys, so they travel
  /// one-to-one inside direct messages and are never accepted from (or put
  /// into) group and room traffic.
  static bool isConversationContent(Envelope e) =>
      e is TextEnvelope || e is MediaEnvelope || e is EditEnvelope || e is DeleteEnvelope;

  /// Seals [envelope] under the group key and signs the packet. Relays carry
  /// it without being able to read it; members check [openGroupMessage].
  Future<MeshPacket> buildGroupMessage({
    required GroupSealKey group,
    required Envelope envelope,
    int hopLimit = Protocol.groupHopLimit,
    Duration ttl = Protocol.groupMessageTtl,
  }) async {
    if (!isConversationContent(envelope)) {
      throw ArgumentError.value(envelope.kind, 'envelope', 'is not conversation content');
    }
    final body = EnvelopeCodec.encode(envelope, withNickname: true);
    final messageId = randomBytes(Protocol.messageIdLength);
    final now = _clock.nowMs;
    final expires = now + ttl.inMilliseconds;
    final aad = MeshPacket.buildHeaderAad(
      type: PacketType.group,
      hopLimit: hopLimit,
      messageId: messageId,
      timestampMs: now,
      expiresAtMs: expires,
      senderKey: identity.signingPublicKey,
      recipientKey: group.groupId,
    );
    final sealed = await Aead.seal(
      key: group.key,
      nonce: randomBytes(Aead.nonceLength),
      aad: aad,
      plaintext: _pad(body),
    );
    return _buildSigned(
      type: PacketType.group,
      hopLimit: hopLimit,
      messageId: messageId,
      timestampMs: now,
      expiresAtMs: expires,
      recipientKey: group.groupId,
      payload: concatBytes([(ByteWriter()..u32(group.epoch)).toBytes(), sealed]),
    );
  }

  /// The key epoch a group message (or chunk) was sealed under, so the caller
  /// can look up the right key before opening it.
  static int groupPacketEpoch(MeshPacket packet) {
    if (packet.type != PacketType.group || packet.payload.length < 4) {
      throw const DecryptionFailure(DecryptionFailureReason.malformed);
    }
    return ByteReader(packet.payload).u32();
  }

  static Future<Envelope> openGroupMessage(MeshPacket packet, GroupSealKey group) async {
    if (packet.type != PacketType.group || packet.isChunk) {
      throw const DecryptionFailure(DecryptionFailureReason.wrongType);
    }
    if (!constantTimeEquals(packet.recipientKey, group.groupId)) {
      throw const DecryptionFailure(DecryptionFailureReason.notForUs);
    }
    if (packet.payload.length < 4 + _padBlock + Aead.overhead ||
        groupPacketEpoch(packet) != group.epoch) {
      throw const DecryptionFailure(DecryptionFailureReason.malformed);
    }
    final Uint8List plain;
    try {
      plain = await Aead.open(
        key: group.key,
        aad: packet.headerAad(),
        sealed: Uint8List.sublistView(packet.payload, 4),
      );
    } on AeadFailure {
      throw const DecryptionFailure(DecryptionFailureReason.authenticationFailed);
    }
    return _decodeConversation(plain);
  }

  static Envelope _decodeConversation(Uint8List plain) {
    final Envelope envelope;
    try {
      envelope = EnvelopeCodec.decode(plain, withNickname: true);
    } on EnvelopeFormatException {
      throw const DecryptionFailure(DecryptionFailureReason.malformed);
    }
    if (!isConversationContent(envelope)) {
      throw const DecryptionFailure(DecryptionFailureReason.wrongType);
    }
    return envelope;
  }

  /// The key a group uses for one media object: derived from the group key, so
  /// the manifest need not carry a key and every object has its own.
  static Future<Uint8List> groupMediaKey(Uint8List groupKey, Uint8List mediaId) =>
      Aead.deriveKey(secret: groupKey, salt: mediaId, label: 'damataqe/v2/group-media');

  // ---------------------------------------------------------------------------
  // Media chunks (private, group and public-room images and voice messages)
  // ---------------------------------------------------------------------------

  /// Builds one chunk packet of an image or voice message.
  ///
  ///  * direct: [key] is the media key from the (sealed) manifest;
  ///  * group:  [key] is [groupMediaKey] and [epoch] the group key epoch;
  ///  * room:   [key] is null - the chunk is public but signed.
  Future<MeshPacket> buildChunk({
    required PacketType type,
    required Uint8List recipientKey,
    required Uint8List mediaId,
    required int index,
    required int count,
    required Uint8List data,
    Uint8List? key,
    int? epoch,
    int? hopLimit,
    Duration? ttl,
  }) async {
    if (!type.canBeChunk) throw ArgumentError.value(type, 'type', 'cannot carry chunks');
    if (type == PacketType.room ? key != null : key == null) {
      throw ArgumentError('Room chunks are plain; direct and group chunks must be sealed');
    }
    if ((type == PacketType.group) != (epoch != null)) {
      throw ArgumentError('Only group chunks carry a key epoch');
    }
    if (data.isEmpty || data.length > Protocol.mediaChunkBytes) {
      throw ArgumentError.value(data.length, 'data', 'chunk size out of range');
    }
    if (count < 1 || count > Protocol.maxMediaChunks || index < 0 || index >= count) {
      throw ArgumentError('Chunk position out of range');
    }
    final limit = hopLimit ??
        switch (type) {
          PacketType.group => Protocol.groupHopLimit,
          PacketType.room => Protocol.roomHopLimit,
          _ => Protocol.directHopLimit,
        };
    final life = ttl ??
        switch (type) {
          PacketType.group => Protocol.groupMessageTtl,
          PacketType.room => Protocol.roomMessageTtl,
          _ => Protocol.directMessageTtl,
        };
    final messageId = randomBytes(Protocol.messageIdLength);
    final now = _clock.nowMs;
    final expires = now + life.inMilliseconds;
    final position = MediaChunk(
      mediaId: mediaId,
      index: index,
      count: count,
      body: Uint8List(0),
    ).aadSuffix;
    final epochBytes = epoch == null ? const <int>[] : (ByteWriter()..u32(epoch)).toBytes();

    Uint8List body = data;
    if (key != null) {
      final aad = concatBytes([
        MeshPacket.buildHeaderAad(
          type: type,
          hopLimit: limit,
          messageId: messageId,
          timestampMs: now,
          expiresAtMs: expires,
          senderKey: identity.signingPublicKey,
          recipientKey: recipientKey,
          flags: MeshPacket.flagChunk,
        ),
        epochBytes,
        position,
      ]);
      body = await Aead.seal(
        key: key,
        nonce: randomBytes(Aead.nonceLength),
        aad: aad,
        plaintext: data,
      );
    }
    return _buildSigned(
      type: type,
      flags: MeshPacket.flagChunk,
      hopLimit: limit,
      messageId: messageId,
      timestampMs: now,
      expiresAtMs: expires,
      recipientKey: recipientKey,
      payload: concatBytes([epochBytes, position, body]),
    );
  }

  /// Splits a chunk packet's payload into its (group) key epoch and chunk.
  static ({int? epoch, MediaChunk chunk}) parseChunkPacket(MeshPacket packet) {
    if (!packet.isChunk) throw const DecryptionFailure(DecryptionFailureReason.wrongType);
    try {
      if (packet.type == PacketType.group) {
        if (packet.payload.length < 4) {
          throw const DecryptionFailure(DecryptionFailureReason.malformed);
        }
        final epoch = ByteReader(packet.payload).u32();
        final chunk = MediaChunk.parse(Uint8List.sublistView(packet.payload, 4));
        return (epoch: epoch, chunk: chunk);
      }
      return (epoch: null, chunk: MediaChunk.parse(packet.payload));
    } on ChunkFormatException {
      throw const DecryptionFailure(DecryptionFailureReason.malformed);
    }
  }

  /// Opens the sealed body of a direct or group chunk with [key].
  static Future<Uint8List> openChunkBody({
    required MeshPacket packet,
    required MediaChunk chunk,
    required Uint8List key,
    int? epoch,
  }) async {
    final aad = concatBytes([
      packet.headerAad(),
      epoch == null ? const <int>[] : (ByteWriter()..u32(epoch)).toBytes(),
      chunk.aadSuffix,
    ]);
    try {
      return await Aead.open(key: key, aad: aad, sealed: chunk.body);
    } on AeadFailure {
      throw const DecryptionFailure(DecryptionFailureReason.authenticationFailed);
    }
  }

  // ---------------------------------------------------------------------------
  // Public rooms
  // ---------------------------------------------------------------------------

  /// A public-room message: readable by everyone in the room, signed so its
  /// author and integrity can be checked and no relay can alter or forge it.
  Future<MeshPacket> buildRoomMessage({
    required Uint8List roomId,
    required Envelope envelope,
    int hopLimit = Protocol.roomHopLimit,
    Duration ttl = Protocol.roomMessageTtl,
  }) async {
    if (!isConversationContent(envelope)) {
      throw ArgumentError.value(envelope.kind, 'envelope', 'is not conversation content');
    }
    final body = EnvelopeCodec.encode(envelope, withNickname: true);
    final now = _clock.nowMs;
    return _buildSigned(
      type: PacketType.room,
      hopLimit: hopLimit,
      messageId: randomBytes(Protocol.messageIdLength),
      timestampMs: now,
      expiresAtMs: now + ttl.inMilliseconds,
      recipientKey: roomId,
      payload: body,
    );
  }

  static Envelope openRoomMessage(MeshPacket packet) {
    if (packet.type != PacketType.room || packet.isChunk) {
      throw const DecryptionFailure(DecryptionFailureReason.wrongType);
    }
    return _decodeConversation(packet.payload);
  }

  /// Creates and signs the record of a new public room owned by this phone.
  Future<RoomRecord> createRoomRecord({
    required String name,
    String description = '',
    Duration lifetime = Protocol.roomRecordLifetime,
  }) async {
    final now = _clock.nowMs;
    return _signRoomRecord(RoomRecord(
      roomId: await RoomRecord.deriveId(
        creatorKey: identity.signingPublicKey,
        createdAtMs: now,
        name: name,
      ),
      name: name,
      description: description,
      creatorKey: identity.signingPublicKey,
      createdAtMs: now,
      expiresAtMs: now + lifetime.inMilliseconds,
      version: 1,
      signature: Uint8List(Protocol.signatureLength),
    ));
  }

  /// A newer version of one of our own rooms with a fresh lifetime. Only the
  /// version and expiry change; the id, name and creation time are fixed.
  Future<RoomRecord> refreshRoomRecord(
    RoomRecord old, {
    Duration lifetime = Protocol.roomRecordLifetime,
  }) async {
    if (!constantTimeEquals(old.creatorKey, identity.signingPublicKey)) {
      throw ArgumentError('Only the creator can refresh a room');
    }
    final now = _clock.nowMs;
    return _signRoomRecord(RoomRecord(
      roomId: old.roomId,
      name: old.name,
      description: old.description,
      creatorKey: old.creatorKey,
      createdAtMs: old.createdAtMs,
      expiresAtMs: now + lifetime.inMilliseconds,
      version: old.version + 1,
      signature: Uint8List(Protocol.signatureLength),
    ));
  }

  Future<RoomRecord> _signRoomRecord(RoomRecord unsigned) async =>
      unsigned.withSignature(await sign(unsigned.signingBytes()));

  /// Checks that [record] was signed by its stated creator and carries the
  /// room id that creator's key derives - so nobody can announce a room under
  /// an id that belongs to somebody else.
  static Future<bool> verifyRoomRecord(RoomRecord record) async {
    if (!await verifySignature(
      publicKey: record.creatorKey,
      message: record.signingBytes(),
      signature: record.signature,
    )) {
      return false;
    }
    return record.hasDerivedId();
  }

  /// Wraps a (creator-signed) record in a packet signed by this phone, so any
  /// phone can pass a room on, not only its creator.
  Future<MeshPacket> buildRoomAnnounce(RoomRecord record) async {
    final now = _clock.nowMs;
    return _buildSigned(
      type: PacketType.roomAnnounce,
      hopLimit: Protocol.roomAnnounceHopLimit,
      messageId: randomBytes(Protocol.messageIdLength),
      timestampMs: now,
      expiresAtMs: now + Protocol.roomAnnounceTtl.inMilliseconds,
      recipientKey: Uint8List(Protocol.keyLength),
      payload: record.encode(),
    );
  }

  static RoomRecord parseRoomAnnounce(MeshPacket packet) {
    if (packet.type != PacketType.roomAnnounce) {
      throw const DecryptionFailure(DecryptionFailureReason.wrongType);
    }
    try {
      return RoomRecord.parse(packet.payload);
    } on FormatException {
      throw const DecryptionFailure(DecryptionFailureReason.malformed);
    }
  }

  // ---------------------------------------------------------------------------
  // Link authentication (proof of key possession)
  // ---------------------------------------------------------------------------

  static Uint8List _linkAuthMessage({
    required Uint8List verifierNonce,
    required Uint8List proverNonce,
    required Uint8List proverSigningKey,
    required Uint8List proverAgreementKey,
    required String proverNickname,
    required Uint8List verifierSigningKey,
  }) =>
      concatBytes([
        utf8.encode('meshchat/v1/link-auth\u0000'),
        verifierNonce,
        proverNonce,
        proverSigningKey,
        proverAgreementKey,
        verifierSigningKey,
        utf8.encode(proverNickname),
      ]);

  /// Signs the challenge the remote ("verifier") sent us, binding both
  /// identities, both nonces and our announced nickname so the proof cannot
  /// be replayed on another link or to another peer, and the nickname cannot
  /// be altered in transit.
  Future<Uint8List> signLinkAuth({
    required Uint8List verifierNonce,
    required Uint8List proverNonce,
    required Uint8List verifierSigningKey,
    required String nickname,
  }) =>
      sign(_linkAuthMessage(
        verifierNonce: verifierNonce,
        proverNonce: proverNonce,
        proverSigningKey: identity.signingPublicKey,
        proverAgreementKey: identity.agreementPublicKey,
        proverNickname: nickname,
        verifierSigningKey: verifierSigningKey,
      ));

  /// Checks a remote's proof that it owns [proverSigningKey].
  static Future<bool> verifyLinkAuth({
    required Uint8List signature,
    required Uint8List verifierNonce,
    required Uint8List proverNonce,
    required Uint8List proverSigningKey,
    required Uint8List proverAgreementKey,
    required String proverNickname,
    required Uint8List verifierSigningKey,
  }) =>
      verifySignature(
        publicKey: proverSigningKey,
        message: _linkAuthMessage(
          verifierNonce: verifierNonce,
          proverNonce: proverNonce,
          proverSigningKey: proverSigningKey,
          proverAgreementKey: proverAgreementKey,
          proverNickname: proverNickname,
          verifierSigningKey: verifierSigningKey,
        ),
        signature: signature,
      );

  // ---------------------------------------------------------------------------
  // Verification helpers
  // ---------------------------------------------------------------------------

  /// Safety number shared with [remote]; equal on both phones.
  Future<String> safetyNumberWith({
    required Uint8List remoteSigningKey,
    required Uint8List remoteAgreementKey,
  }) async {
    return Fingerprints.safetyNumber(
      localFingerprint: await identity.fingerprint(),
      remoteFingerprint: await Fingerprints.of(
        signingKey: remoteSigningKey,
        agreementKey: remoteAgreementKey,
      ),
    );
  }
}
