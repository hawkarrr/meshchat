import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:offline_mesh_chat/protocol/mesh_packet.dart';
import 'package:offline_mesh_chat/protocol/protocol_constants.dart';

Uint8List _fill(int length, int value) => Uint8List(length)..fillRange(0, length, value);

MeshPacket _packet({
  PacketType type = PacketType.direct,
  int hopLimit = 5,
  int hops = 0,
  int payloadLength = 100,
  int timestampMs = 1700000000000,
  int expiresAtMs = 1700000600000,
  int flags = 0,
}) =>
    MeshPacket(
      type: type,
      flags: flags,
      hopLimit: hopLimit,
      hops: hops,
      messageId: _fill(16, 1),
      timestampMs: timestampMs,
      expiresAtMs: expiresAtMs,
      senderKey: _fill(32, 2),
      recipientKey: _fill(32, 3),
      payload: _fill(payloadLength, 4),
      signature: _fill(64, 5),
    );

void main() {
  group('encode/decode', () {
    test('round-trips every field', () {
      final p = _packet(hops: 2);
      final d = MeshPacket.decode(p.encode());
      expect(d.protocolVersion, Protocol.version);
      expect(d.type, PacketType.direct);
      expect(d.hopLimit, 5);
      expect(d.hops, 2);
      expect(d.messageId, p.messageId);
      expect(d.timestampMs, p.timestampMs);
      expect(d.expiresAtMs, p.expiresAtMs);
      expect(d.senderKey, p.senderKey);
      expect(d.recipientKey, p.recipientKey);
      expect(d.payload, p.payload);
      expect(d.signature, p.signature);
    });

    test('encoded length matches the documented layout', () {
      final p = _packet(payloadLength: 37);
      expect(p.encode().length, Protocol.headerLength + 37 + 64);
      expect(p.encodedLength, p.encode().length);
    });

    test('every packet type round-trips', () {
      for (final t in PacketType.values) {
        expect(MeshPacket.decode(_packet(type: t).encode()).type, t);
      }
    });

    test('empty and maximum payloads are accepted', () {
      expect(MeshPacket.decode(_packet(payloadLength: 0).encode()).payload, isEmpty);
      final big = _packet(payloadLength: Protocol.maxPayloadBytes);
      expect(MeshPacket.decode(big.encode()).payload.length, Protocol.maxPayloadBytes);
    });
  });

  group('decode rejects malformed input', () {
    final good = _packet().encode();

    void expectRejected(Uint8List bytes, [String? why]) {
      expect(() => MeshPacket.decode(bytes), throwsA(isA<PacketFormatException>()),
          reason: why);
    }

    test('truncated packets', () {
      for (var n = 0; n < good.length; n++) {
        expectRejected(Uint8List.sublistView(good, 0, n), 'length $n');
      }
    });

    test('trailing bytes', () {
      expectRejected(Uint8List.fromList([...good, 0]));
    });

    test('unknown protocol version, including the old v1 phones', () {
      expectRejected(Uint8List.fromList(good)..[0] = Protocol.version + 1);
      expectRejected(Uint8List.fromList(good)..[0] = 1);
      expectRejected(Uint8List.fromList(good)..[0] = 0);
    });

    test('unknown packet type (the retired channel type 3 included)', () {
      expectRejected(Uint8List.fromList(good)..[1] = 99);
      expectRejected(Uint8List.fromList(good)..[1] = 3);
      expectRejected(Uint8List.fromList(good)..[1] = 0);
    });

    test('reserved flag bits are rejected', () {
      expectRejected(Uint8List.fromList(good)..[2] = 0x02);
      expectRejected(Uint8List.fromList(good)..[2] = 0x80);
      expectRejected(Uint8List.fromList(good)..[2] = 0x03);
    });

    test('the chunk flag is only valid on direct, group and room packets', () {
      for (final t in PacketType.values) {
        final bytes = _packet(type: t, flags: MeshPacket.flagChunk).encode();
        if (t.canBeChunk) {
          final d = MeshPacket.decode(bytes);
          expect(d.isChunk, isTrue, reason: t.name);
          expect(d.flags, MeshPacket.flagChunk);
        } else {
          expectRejected(bytes, '${t.name} must not be a chunk');
        }
      }
    });

    test('hopLimit above the protocol maximum', () {
      final b = Uint8List.fromList(good)..[3] = Protocol.maxHopLimit + 1;
      expectRejected(b);
    });

    test('hops greater than hopLimit', () {
      final b = Uint8List.fromList(good)..[4] = 6; // hopLimit is 5
      expectRejected(b);
    });

    test('a payload length that disagrees with the data', () {
      final b = Uint8List.fromList(good);
      b[101] = 0xff;
      b[102] = 0xff;
      expectRejected(b);
    });

    test('oversized input', () {
      expectRejected(Uint8List(Protocol.maxPacketBytes + 1));
    });

    test('random garbage never throws anything but PacketFormatException', () {
      final rng = Random(1234);
      for (var i = 0; i < 2000; i++) {
        final len = rng.nextInt(400);
        final bytes = Uint8List.fromList(List.generate(len, (_) => rng.nextInt(256)));
        try {
          MeshPacket.decode(bytes);
        } on PacketFormatException {
          // expected
        }
      }
    });

    test('bit-flipped valid packets either decode or throw PacketFormatException', () {
      final rng = Random(99);
      for (var i = 0; i < 2000; i++) {
        final b = Uint8List.fromList(good);
        b[rng.nextInt(b.length)] ^= 1 << rng.nextInt(8);
        try {
          MeshPacket.decode(b);
        } on PacketFormatException {
          // expected
        }
      }
    });
  });

  group('signing bytes', () {
    test('do not change when a relay increments hops', () {
      final p = _packet();
      expect(p.relayed().signingBytes(), p.signingBytes());
      expect(p.relayed().hops, 1);
    });

    test('change when any signed field changes', () {
      final base = _packet().signingBytes();
      expect(_packet(hopLimit: 4).signingBytes(), isNot(base));
      expect(_packet(timestampMs: 1).signingBytes(), isNot(base));
      expect(_packet(expiresAtMs: 1).signingBytes(), isNot(base));
      expect(_packet(payloadLength: 101).signingBytes(), isNot(base));
      expect(_packet(type: PacketType.group).signingBytes(), isNot(base));
      expect(_packet(flags: MeshPacket.flagChunk).signingBytes(), isNot(base));
    });

    test('are domain separated from the AEAD header', () {
      final p = _packet();
      expect(p.signingBytes(), isNot(p.headerAad()));
    });

    test('header AAD ignores hops and payload', () {
      final p = _packet();
      expect(p.relayed().headerAad(), p.headerAad());
      expect(_packet(payloadLength: 7).headerAad(), p.headerAad());
    });

    test('header AAD covers the type, version and the chunk flag', () {
      final p = _packet();
      expect(_packet(flags: MeshPacket.flagChunk).headerAad(), isNot(p.headerAad()));
      expect(_packet(type: PacketType.group).headerAad(), isNot(p.headerAad()));
    });

    test('headerAad() equals buildHeaderAad() with the same fields (sender and receiver agree)', () {
      final p = _packet(flags: MeshPacket.flagChunk);
      expect(
        p.headerAad(),
        MeshPacket.buildHeaderAad(
          type: p.type,
          flags: MeshPacket.flagChunk,
          hopLimit: p.hopLimit,
          messageId: p.messageId,
          timestampMs: p.timestampMs,
          expiresAtMs: p.expiresAtMs,
          senderKey: p.senderKey,
          recipientKey: p.recipientKey,
        ),
      );
    });

    test('relaying keeps the chunk flag', () {
      expect(_packet(flags: MeshPacket.flagChunk).relayed().isChunk, isTrue);
    });
  });

  group('packet classes', () {
    test('only group and room packets are persistent floods', () {
      expect(
        PacketType.values.where((t) => t.isPersistentFlood),
        [PacketType.group, PacketType.room],
      );
    });

    test('codes are stable on the wire', () {
      expect({for (final t in PacketType.values) t.name: t.code}, {
        'announce': 1,
        'direct': 2,
        'ack': 4,
        'group': 5,
        'room': 6,
        'roomAnnounce': 7,
      });
    });
  });

  group('relay and expiry rules', () {
    test('canBeRelayed is true until hops reaches hopLimit', () {
      var p = _packet(hopLimit: 2);
      expect(p.canBeRelayed, isTrue);
      p = p.relayed();
      expect(p.canBeRelayed, isTrue);
      p = p.relayed();
      expect(p.hops, 2);
      expect(p.canBeRelayed, isFalse);
    });

    test('isExpiredAt honours the clock-skew tolerance', () {
      final p = _packet(expiresAtMs: 1000000);
      final skew = Protocol.clockSkewTolerance.inMilliseconds;
      expect(p.isExpiredAt(1000000), isFalse);
      expect(p.isExpiredAt(1000000 + skew), isFalse);
      expect(p.isExpiredAt(1000000 + skew + 1), isTrue);
    });

    test('broadcast is recognised by an all-zero recipient', () {
      final p = MeshPacket(
        type: PacketType.announce,
        hopLimit: 3,
        messageId: _fill(16, 1),
        timestampMs: 1,
        expiresAtMs: 2,
        senderKey: _fill(32, 2),
        recipientKey: Uint8List(32),
        payload: Uint8List(0),
        signature: _fill(64, 5),
      );
      expect(p.isBroadcast, isTrue);
      expect(_packet().isBroadcast, isFalse);
    });
  });
}
