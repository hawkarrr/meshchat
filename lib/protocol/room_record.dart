import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../core/bytes.dart';
import 'protocol_constants.dart';

/// Thrown when a public-room record is malformed.
class RoomRecordException extends FormatException {
  const RoomRecordException(super.message);
}

/// The room every Damatqe phone belongs to. Its id is fixed (the SHA-256 of
/// the label below), so it needs no announcement.
abstract final class PublicRooms {
  /// SHA-256 of the UTF-8 text `damataqe/public-room/mesh`.
  static const String meshIdHex =
      'c73b99460eefd9125c89c9cbb4e75f103e8fa8ece7e7e4a50891489d8be9e18b';
  static const String meshName = 'mesh';
  static const String meshDescription = 'Everyone nearby';

  static Uint8List get meshId => hexToBytes(meshIdHex);

  /// A record may claim to be valid for at most this long from the moment it is
  /// received; a creator has to refresh a room to keep it listed.
  static const Duration maxLifetime = Duration(days: 7);
}

/// A public room, as announced to nearby phones.
///
/// The creator signs the record, so any phone can pass it on without being
/// able to alter it (a different name, a longer lifetime, a different
/// creator). Newer versions of the same room replace older ones.
///
/// The room id is derived from the creator's key, the creation time and the
/// name ([deriveId]), so nobody can announce a room under somebody else's id:
/// the id only matches records made by the key it was derived from.
/// `createdAtMs` never changes; a refresh only raises `version` and
/// `expiresAtMs`.
///
/// ```
/// u8 format(1) | roomId[32] | u8 nameLen name | u8 descLen description
/// | creatorKey[32] | u64 createdAtMs | u64 expiresAtMs | u32 version
/// | signature[64]
/// ```
class RoomRecord {
  const RoomRecord({
    required this.roomId,
    required this.name,
    required this.description,
    required this.creatorKey,
    required this.createdAtMs,
    required this.expiresAtMs,
    required this.version,
    required this.signature,
  });

  static const int formatVersion = 1;

  static final Uint8List _signingDomain =
      Uint8List.fromList(utf8.encode('damataqe/room-record\u0000'));

  final Uint8List roomId;
  final String name;
  final String description;

  /// The Ed25519 identity key that created (and may refresh) the room.
  final Uint8List creatorKey;
  final int createdAtMs;
  final int expiresAtMs;
  final int version;
  final Uint8List signature;

  String get roomIdHex => bytesToHex(roomId);
  String get creatorId => bytesToHex(creatorKey);

  bool isExpiredAt(int nowMs) => expiresAtMs <= nowMs;

  /// Whether the claimed expiry is believable at [nowMs]: still in the future,
  /// but not further than a room may ever be kept without a refresh.
  bool lifetimeAcceptableAt(int nowMs) =>
      expiresAtMs > nowMs &&
      expiresAtMs - nowMs <=
          PublicRooms.maxLifetime.inMilliseconds + Protocol.clockSkewTolerance.inMilliseconds;

  static final Uint8List _idDomain = Uint8List.fromList(utf8.encode('damataqe/room-id\u0000'));

  /// The only room id a record by [creatorKey] with this creation time and name
  /// may carry.
  static Future<Uint8List> deriveId({
    required Uint8List creatorKey,
    required int createdAtMs,
    required String name,
  }) async {
    final input = concatBytes([
      _idDomain,
      creatorKey,
      (ByteWriter()..u64(createdAtMs)).toBytes(),
      utf8.encode(name),
    ]);
    final hash = await Sha256().hash(input);
    return Uint8List.fromList(hash.bytes);
  }

  /// True when [roomId] is the id this record's creator, time and name derive.
  Future<bool> hasDerivedId() async {
    final expected = await deriveId(creatorKey: creatorKey, createdAtMs: createdAtMs, name: name);
    return constantTimeEquals(expected, roomId);
  }

  Uint8List encodeBody() {
    final nameBytes = utf8.encode(name);
    final descBytes = utf8.encode(description);
    if (nameBytes.isEmpty || nameBytes.length > Protocol.maxRoomNameBytes) {
      throw ArgumentError.value(name, 'name', 'must be 1..${Protocol.maxRoomNameBytes} bytes');
    }
    if (descBytes.length > Protocol.maxRoomDescriptionBytes) {
      throw ArgumentError.value(description, 'description', 'too long');
    }
    final w = ByteWriter()
      ..u8(formatVersion)
      ..bytes(roomId)
      ..u8(nameBytes.length)
      ..bytes(nameBytes)
      ..u8(descBytes.length)
      ..bytes(descBytes)
      ..bytes(creatorKey)
      ..u64(createdAtMs)
      ..u64(expiresAtMs)
      ..u32(version);
    return w.toBytes();
  }

  /// What the creator signs.
  Uint8List signingBytes() => concatBytes([_signingDomain, encodeBody()]);

  static Uint8List signingBytesFor(Uint8List body) => concatBytes([_signingDomain, body]);

  Uint8List encode() => concatBytes([encodeBody(), signature]);

  RoomRecord withSignature(Uint8List sig) => RoomRecord(
        roomId: roomId,
        name: name,
        description: description,
        creatorKey: creatorKey,
        createdAtMs: createdAtMs,
        expiresAtMs: expiresAtMs,
        version: version,
        signature: sig,
      );

  /// Structurally validates and parses a record. The signature is NOT checked
  /// here: callers verify it with the creator's key.
  static RoomRecord parse(Uint8List payload) {
    try {
      final r = ByteReader(payload);
      if (r.u8() != formatVersion) throw const RoomRecordException('Unknown record format');
      final roomId = r.bytes(Protocol.keyLength);
      final nameLength = r.u8();
      if (nameLength == 0 || nameLength > Protocol.maxRoomNameBytes) {
        throw const RoomRecordException('Bad room name');
      }
      final name = utf8.decode(r.bytes(nameLength));
      final descLength = r.u8();
      if (descLength > Protocol.maxRoomDescriptionBytes) {
        throw const RoomRecordException('Description too long');
      }
      final description = utf8.decode(r.bytes(descLength));
      final creator = r.bytes(Protocol.keyLength);
      final created = r.u64();
      final expires = r.u64();
      final version = r.u32();
      final signature = r.bytes(Protocol.signatureLength);
      if (r.remaining != 0) throw const RoomRecordException('Trailing bytes');
      if (isAllZero(roomId) || isAllZero(creator)) {
        throw const RoomRecordException('Degenerate key');
      }
      if (name.trim().isEmpty) throw const RoomRecordException('Empty room name');
      if (expires <= created) throw const RoomRecordException('Bad lifetime');
      if (version == 0) throw const RoomRecordException('Bad version');
      return RoomRecord(
        roomId: roomId,
        name: name,
        description: description,
        creatorKey: creator,
        createdAtMs: created,
        expiresAtMs: expires,
        version: version,
        signature: signature,
      );
    } on RoomRecordException {
      rethrow;
    } on FormatException catch (e) {
      throw RoomRecordException(e.message);
    }
  }
}
