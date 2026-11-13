import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_mesh_chat/core/bytes.dart';
import 'package:offline_mesh_chat/protocol/protocol_constants.dart';
import 'package:offline_mesh_chat/protocol/room_record.dart';

Uint8List _key(int seed) =>
    Uint8List.fromList(List<int>.generate(32, (i) => (seed * 31 + i * 7) % 255 + 1));

RoomRecord _record({
  String name = 'Cafe',
  String description = 'Tables 1-9',
  int created = 1000000,
  int lifetimeMs = 3600000,
  int version = 1,
  Uint8List? roomId,
  Uint8List? creator,
}) =>
    RoomRecord(
      roomId: roomId ?? _key(1),
      name: name,
      description: description,
      creatorKey: creator ?? _key(2),
      createdAtMs: created,
      expiresAtMs: created + lifetimeMs,
      version: version,
      signature: Uint8List(Protocol.signatureLength),
    );

void main() {
  group('built-in #mesh room', () {
    test('its id is the SHA-256 of the documented label', () async {
      final hash = await Sha256().hash(utf8.encode('damataqe/public-room/mesh'));
      expect(bytesToHex(Uint8List.fromList(hash.bytes)), PublicRooms.meshIdHex);
      expect(PublicRooms.meshId.length, 32);
    });
  });

  group('room ids', () {
    test('are derived from creator, creation time and name', () async {
      final base = await RoomRecord.deriveId(creatorKey: _key(2), createdAtMs: 1000, name: 'Cafe');
      expect(base.length, 32);
      expect(await RoomRecord.deriveId(creatorKey: _key(2), createdAtMs: 1000, name: 'Cafe'), base);
      expect(await RoomRecord.deriveId(creatorKey: _key(3), createdAtMs: 1000, name: 'Cafe'),
          isNot(base));
      expect(await RoomRecord.deriveId(creatorKey: _key(2), createdAtMs: 1001, name: 'Cafe'),
          isNot(base));
      expect(await RoomRecord.deriveId(creatorKey: _key(2), createdAtMs: 1000, name: 'Cafe2'),
          isNot(base));
    });

    test('a record only has a derived id if it was built by the id\'s creator', () async {
      final id = await RoomRecord.deriveId(creatorKey: _key(2), createdAtMs: 1000, name: 'Cafe');
      final genuine = _record(roomId: id, creator: _key(2), created: 1000, name: 'Cafe');
      expect(await genuine.hasDerivedId(), isTrue);
      // A hijacker copies the room id but signs with their own key...
      final hijack = _record(roomId: id, creator: _key(9), created: 1000, name: 'Cafe');
      expect(await hijack.hasDerivedId(), isFalse);
      // ...or keeps the key and renames the room.
      final renamed = _record(roomId: id, creator: _key(2), created: 1000, name: 'Other');
      expect(await renamed.hasDerivedId(), isFalse);
    });

    test('the built-in room id cannot be produced by any creator key', () async {
      final record = RoomRecord(
        roomId: PublicRooms.meshId,
        name: PublicRooms.meshName,
        description: '',
        creatorKey: _key(2),
        createdAtMs: 1,
        expiresAtMs: 2,
        version: 1,
        signature: Uint8List(64),
      );
      expect(await record.hasDerivedId(), isFalse);
    });
  });

  group('RoomRecord', () {
    test('encodes and parses back to the same record', () {
      final original = _record();
      final parsed = RoomRecord.parse(original.encode());
      expect(parsed.roomId, original.roomId);
      expect(parsed.name, 'Cafe');
      expect(parsed.description, 'Tables 1-9');
      expect(parsed.creatorKey, original.creatorKey);
      expect(parsed.createdAtMs, original.createdAtMs);
      expect(parsed.expiresAtMs, original.expiresAtMs);
      expect(parsed.version, 1);
      expect(parsed.signature.length, 64);
    });

    test('unicode names survive', () {
      final parsed = RoomRecord.parse(_record(name: 'مقهى ☕', description: 'كوردی').encode());
      expect(parsed.name, 'مقهى ☕');
      expect(parsed.description, 'كوردی');
    });

    test('the signed bytes are domain-separated and cover every field', () {
      final base = _record();
      final signed = base.signingBytes();
      expect(utf8.decode(signed.sublist(0, 21)), 'damataqe/room-record\u0000');
      for (final other in [
        _record(name: 'Cafe2'),
        _record(description: 'x'),
        _record(created: 2000000),
        _record(lifetimeMs: 7200000),
        _record(version: 2),
        _record(roomId: _key(9)),
        _record(creator: _key(9)),
      ]) {
        expect(other.signingBytes(), isNot(signed));
      }
    });

    test('expiry', () {
      final r = _record(created: 1000, lifetimeMs: 500);
      expect(r.isExpiredAt(1499), isFalse);
      expect(r.isExpiredAt(1500), isTrue);
    });

    test('name and description limits apply on both encode and parse', () {
      expect(() => _record(name: '').encode(), throwsArgumentError);
      expect(() => _record(name: 'n' * 33).encode(), throwsArgumentError);
      expect(() => _record(description: 'd' * 97).encode(), throwsArgumentError);
      expect(_record(name: 'n' * 32, description: 'd' * 96).encode(), isNotEmpty);
    });

    test('rejects a blank name', () {
      final bytes = _record(name: '   ').encode();
      expect(() => RoomRecord.parse(bytes), throwsA(isA<RoomRecordException>()));
    });

    test('rejects a record that expires before (or when) it was created', () {
      expect(() => RoomRecord.parse(_record(lifetimeMs: 0).encode()),
          throwsA(isA<RoomRecordException>()));
      expect(() => RoomRecord.parse(_record(lifetimeMs: -5).encode()),
          throwsA(isA<RoomRecordException>()));
    });

    test('a believable lifetime is in the future but not beyond the maximum', () {
      const now = 5000000;
      final skew = Protocol.clockSkewTolerance.inMilliseconds;
      final max = PublicRooms.maxLifetime.inMilliseconds;
      RoomRecord expiring(int at) => RoomRecord(
            roomId: _key(1),
            name: 'x',
            description: '',
            creatorKey: _key(2),
            createdAtMs: 1,
            expiresAtMs: at,
            version: 1,
            signature: Uint8List(64),
          );
      expect(expiring(now + 1000).lifetimeAcceptableAt(now), isTrue);
      expect(expiring(now).lifetimeAcceptableAt(now), isFalse);
      expect(expiring(now - 1).lifetimeAcceptableAt(now), isFalse);
      expect(expiring(now + max + skew).lifetimeAcceptableAt(now), isTrue);
      expect(expiring(now + max + skew + 1).lifetimeAcceptableAt(now), isFalse);
    });

    test('a refreshed old room (created long ago) still parses', () {
      // createdAtMs never changes, so a room refreshed after weeks has a
      // creation time far older than its expiry.
      final old = _record(created: 1000000, lifetimeMs: 40 * 24 * 3600 * 1000);
      expect(RoomRecord.parse(old.encode()).createdAtMs, 1000000);
    });

    test('rejects version 0 and degenerate keys', () {
      expect(() => RoomRecord.parse(_record(version: 0).encode()),
          throwsA(isA<RoomRecordException>()));
      expect(() => RoomRecord.parse(_record(roomId: Uint8List(32)).encode()),
          throwsA(isA<RoomRecordException>()));
      expect(() => RoomRecord.parse(_record(creator: Uint8List(32)).encode()),
          throwsA(isA<RoomRecordException>()));
    });

    test('rejects trailing bytes, truncation and unknown formats', () {
      final good = _record().encode();
      expect(() => RoomRecord.parse(Uint8List.fromList([...good, 0])),
          throwsA(isA<RoomRecordException>()));
      for (var cut = 0; cut < good.length; cut++) {
        expect(() => RoomRecord.parse(Uint8List.sublistView(good, 0, cut)),
            throwsA(isA<RoomRecordException>()),
            reason: 'cut at $cut');
      }
      final unknown = Uint8List.fromList(good)..[0] = 9;
      expect(() => RoomRecord.parse(unknown), throwsA(isA<RoomRecordException>()));
    });

    test('invalid UTF-8 in the name is a clean format error', () {
      final good = _record(name: 'abc').encode();
      final bad = Uint8List.fromList(good)
        ..[1 + 32 + 1] = 0xff
        ..[1 + 32 + 2] = 0xfe;
      expect(() => RoomRecord.parse(bad), throwsA(isA<RoomRecordException>()));
    });
  });
}
