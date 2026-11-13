import 'dart:convert';
import 'dart:typed_data';

import '../core/bytes.dart';
import 'protocol_constants.dart';

/// Thrown when bytes from the network cannot be a valid [MeshPacket].
class PacketFormatException extends FormatException {
  const PacketFormatException(super.message);
}

enum PacketType {
  /// Signed presence/key announcement, flooded with a small hop limit.
  announce(1),

  /// End-to-end encrypted message for one recipient.
  direct(2),

  /// Signed delivery acknowledgement routed back to the original sender.
  ack(4),

  /// Message for a group, encrypted with the group's key. Addressed to the
  /// group id and carried by every phone that can help, so members who were
  /// offline still get it later.
  group(5),

  /// Message for a public room: readable by anyone in the room, but signed, so
  /// its author and integrity can be checked. Addressed to the room id.
  room(6),

  /// Signed public-room record, so nearby phones can discover the room.
  roomAnnounce(7);

  const PacketType(this.code);

  final int code;

  /// Whether the payload may be a media chunk (see [MeshPacket.flagChunk])
  /// instead of a message.
  bool get canBeChunk => this == direct || this == group || this == room;

  /// Group and room packets have no single recipient: they are offered to
  /// every neighbour once and kept for a while (store, carry and forward).
  bool get isPersistentFlood => this == group || this == room;

  static PacketType? fromCode(int code) {
    for (final t in PacketType.values) {
      if (t.code == code) return t;
    }
    return null;
  }
}

/// A routable mesh packet.
///
/// Wire layout (big-endian):
///
/// ```
/// off  size  field
///   0     1  protocolVersion
///   1     1  type
///   2     1  flags            (bit 0 = media chunk; other bits must be 0)
///   3     1  hopLimit         (SIGNED: max relays the sender allows)
///   4     1  hops             (NOT signed: relays increment it)
///   5    16  messageId        (random; the duplicate-detection key)
///  21     8  timestampMs      (sender's clock; advisory only)
///  29     8  expiresAtMs      (sender's clock; clamped by every receiver)
///  37    32  senderPublicKey  (Ed25519 identity key)
///  69    32  recipientPublicKey for direct/ack; group id or room id for group
///            and room packets; all zeros for announcements
/// 101     2  payloadLength
/// 103     N  payload          (type specific; sealed for direct and group)
/// 103+N  64  signature       (Ed25519 over [signingBytes])
/// ```
///
/// Everything except `hops` and the signature itself is covered by the
/// signature, so a relay can increment `hops` but cannot alter the recipient,
/// expiry, hop limit or payload without invalidating the packet.
///
/// Neither the timestamp nor any other sender-supplied field is proof of
/// identity: identity is established only by a valid signature from the
/// sender's key, and trust in that key is a separate (verification) matter.
class MeshPacket {
  MeshPacket({
    required this.type,
    required this.hopLimit,
    this.hops = 0,
    required this.messageId,
    required this.timestampMs,
    required this.expiresAtMs,
    required this.senderKey,
    required this.recipientKey,
    required this.payload,
    required this.signature,
    this.protocolVersion = Protocol.version,
    this.flags = 0,
  });

  /// Flag bit: the payload is one chunk of an image or voice message, not a
  /// message. Covered by the signature and the AEAD associated data like every
  /// other header field.
  static const int flagChunk = 0x01;

  final int protocolVersion;
  final PacketType type;
  final int flags;
  final int hopLimit;
  final int hops;
  final Uint8List messageId;
  final int timestampMs;
  final int expiresAtMs;
  final Uint8List senderKey;
  final Uint8List recipientKey;
  final Uint8List payload;
  final Uint8List signature;

  static final Uint8List _signingDomain =
      Uint8List.fromList(utf8.encode('meshchat/v1/packet\u0000'));

  String get messageIdHex => bytesToHex(messageId);
  String get senderHex => bytesToHex(senderKey);
  String get recipientHex => bytesToHex(recipientKey);

  /// True when the payload is a media chunk rather than a message.
  bool get isChunk => flags & flagChunk != 0;

  bool get isBroadcast => isAllZero(recipientKey);

  /// Total encoded size in bytes.
  int get encodedLength =>
      Protocol.headerLength + payload.length + Protocol.signatureLength;

  bool isExpiredAt(int nowMs) =>
      expiresAtMs < nowMs - Protocol.clockSkewTolerance.inMilliseconds;

  /// Copy as forwarded by a relay: `hops` incremented, nothing else changed.
  MeshPacket relayed() => MeshPacket(
        protocolVersion: protocolVersion,
        type: type,
        flags: flags,
        hopLimit: hopLimit,
        hops: hops + 1,
        messageId: messageId,
        timestampMs: timestampMs,
        expiresAtMs: expiresAtMs,
        senderKey: senderKey,
        recipientKey: recipientKey,
        payload: payload,
        signature: signature,
      );

  /// True when a relay may still forward this packet.
  bool get canBeRelayed => hops < hopLimit;

  /// The bytes the sender signs (and receivers verify): a domain separation
  /// prefix, then the whole packet minus `hops` and the signature.
  Uint8List signingBytes() => _signingBytes(
        protocolVersion: protocolVersion,
        type: type,
        flags: flags,
        hopLimit: hopLimit,
        messageId: messageId,
        timestampMs: timestampMs,
        expiresAtMs: expiresAtMs,
        senderKey: senderKey,
        recipientKey: recipientKey,
        payload: payload,
      );

  /// Additional authenticated data for the payload AEAD. Identical to the
  /// signed header but computed without the payload (which does not exist
  /// yet while encrypting), so it binds the ciphertext to its envelope.
  Uint8List headerAad() => buildHeaderAad(
        protocolVersion: protocolVersion,
        type: type,
        flags: flags,
        hopLimit: hopLimit,
        messageId: messageId,
        timestampMs: timestampMs,
        expiresAtMs: expiresAtMs,
        senderKey: senderKey,
        recipientKey: recipientKey,
      );

  /// Builds the AAD that binds an AEAD ciphertext to its packet header.
  static Uint8List buildHeaderAad({
    required PacketType type,
    required int hopLimit,
    required Uint8List messageId,
    required int timestampMs,
    required int expiresAtMs,
    required Uint8List senderKey,
    required Uint8List recipientKey,
    int protocolVersion = Protocol.version,
    int flags = 0,
  }) {
    final w = ByteWriter()
      ..bytes(utf8.encode('meshchat/v1/aad\u0000'))
      ..u8(protocolVersion)
      ..u8(type.code)
      ..u8(flags)
      ..u8(hopLimit)
      ..bytes(messageId)
      ..u64(timestampMs)
      ..u64(expiresAtMs)
      ..bytes(senderKey)
      ..bytes(recipientKey);
    return w.toBytes();
  }

  /// Canonical bytes to sign for a packet that has no signature yet.
  static Uint8List buildSigningBytes({
    required PacketType type,
    required int hopLimit,
    required Uint8List messageId,
    required int timestampMs,
    required int expiresAtMs,
    required Uint8List senderKey,
    required Uint8List recipientKey,
    required Uint8List payload,
    int protocolVersion = Protocol.version,
    int flags = 0,
  }) =>
      _signingBytes(
        protocolVersion: protocolVersion,
        type: type,
        flags: flags,
        hopLimit: hopLimit,
        messageId: messageId,
        timestampMs: timestampMs,
        expiresAtMs: expiresAtMs,
        senderKey: senderKey,
        recipientKey: recipientKey,
        payload: payload,
      );

  static Uint8List _signingBytes({
    required int protocolVersion,
    required PacketType type,
    required int flags,
    required int hopLimit,
    required Uint8List messageId,
    required int timestampMs,
    required int expiresAtMs,
    required Uint8List senderKey,
    required Uint8List recipientKey,
    required Uint8List payload,
  }) {
    final w = ByteWriter()
      ..bytes(_signingDomain)
      ..u8(protocolVersion)
      ..u8(type.code)
      ..u8(flags)
      ..u8(hopLimit)
      ..bytes(messageId)
      ..u64(timestampMs)
      ..u64(expiresAtMs)
      ..bytes(senderKey)
      ..bytes(recipientKey)
      ..u16(payload.length)
      ..bytes(payload);
    return w.toBytes();
  }

  Uint8List encode() {
    if (messageId.length != Protocol.messageIdLength ||
        senderKey.length != Protocol.keyLength ||
        recipientKey.length != Protocol.keyLength ||
        signature.length != Protocol.signatureLength) {
      throw StateError('MeshPacket has a field of the wrong length');
    }
    if (payload.length > Protocol.maxPayloadBytes) {
      throw StateError('MeshPacket payload exceeds ${Protocol.maxPayloadBytes}');
    }
    final w = ByteWriter()
      ..u8(protocolVersion)
      ..u8(type.code)
      ..u8(flags)
      ..u8(hopLimit)
      ..u8(hops)
      ..bytes(messageId)
      ..u64(timestampMs)
      ..u64(expiresAtMs)
      ..bytes(senderKey)
      ..bytes(recipientKey)
      ..u16(payload.length)
      ..bytes(payload)
      ..bytes(signature);
    return w.toBytes();
  }

  /// Parses and structurally validates a packet. Does NOT verify the
  /// signature; callers must do that before trusting any field.
  static MeshPacket decode(Uint8List bytes) {
    if (bytes.length < Protocol.headerLength + Protocol.signatureLength) {
      throw const PacketFormatException('Packet too short');
    }
    if (bytes.length > Protocol.maxPacketBytes) {
      throw const PacketFormatException('Packet too large');
    }
    try {
      final r = ByteReader(bytes);
      final version = r.u8();
      if (version != Protocol.version) {
        throw PacketFormatException('Unsupported protocol version $version');
      }
      final typeCode = r.u8();
      final type = PacketType.fromCode(typeCode);
      if (type == null) {
        throw PacketFormatException('Unknown packet type $typeCode');
      }
      final flags = r.u8();
      final allowedFlags = type.canBeChunk ? flagChunk : 0;
      if (flags & ~allowedFlags != 0) {
        throw PacketFormatException('Unsupported flags 0x${flags.toRadixString(16)}');
      }
      final hopLimit = r.u8();
      final hops = r.u8();
      if (hopLimit > Protocol.maxHopLimit) {
        throw const PacketFormatException('hopLimit above protocol maximum');
      }
      if (hops > hopLimit) {
        throw const PacketFormatException('hops exceed hopLimit');
      }
      final messageId = r.bytes(Protocol.messageIdLength);
      final timestampMs = r.u64();
      final expiresAtMs = r.u64();
      final sender = r.bytes(Protocol.keyLength);
      final recipient = r.bytes(Protocol.keyLength);
      final payloadLength = r.u16();
      if (payloadLength > Protocol.maxPayloadBytes) {
        throw const PacketFormatException('Payload too large');
      }
      final payload = r.bytes(payloadLength);
      final signature = r.bytes(Protocol.signatureLength);
      if (r.remaining != 0) {
        throw const PacketFormatException('Trailing bytes after packet');
      }
      return MeshPacket(
        protocolVersion: version,
        type: type,
        flags: flags,
        hopLimit: hopLimit,
        hops: hops,
        messageId: messageId,
        timestampMs: timestampMs,
        expiresAtMs: expiresAtMs,
        senderKey: sender,
        recipientKey: recipient,
        payload: payload,
        signature: signature,
      );
    } on PacketFormatException {
      rethrow;
    } on FormatException catch (e) {
      throw PacketFormatException(e.message);
    }
  }

  @override
  String toString() =>
      'MeshPacket(${type.name}${isChunk ? ' chunk' : ''} id=${messageIdHex.substring(0, 8)} '
      'hops=$hops/$hopLimit payload=${payload.length}B)';
}
