import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:offline_mesh_chat/protocol/link_frame.dart';
import 'package:offline_mesh_chat/protocol/protocol_constants.dart';

Uint8List _fill(int length, int value) => Uint8List(length)..fillRange(0, length, value);

HelloFrame _hello({String nickname = 'Alice'}) => HelloFrame(
      protocolVersion: Protocol.version,
      signingKey: _fill(32, 1),
      agreementKey: _fill(32, 2),
      nonce: _fill(16, 3),
      nickname: nickname,
    );

void main() {
  test('a HELLO in another protocol version is recognised by its first byte alone', () {
    // A future version may lay out the rest differently: here it is garbage.
    final bytes = Uint8List.fromList([LinkFrameType.hello.code, Protocol.version + 1, 1, 2, 3]);
    expect(
      () => LinkFrame.decode(bytes),
      throwsA(isA<UnsupportedVersionException>()
          .having((e) => e.version, 'version', Protocol.version + 1)),
    );
    // An older one too; a broken HELLO in our own version stays a broken frame.
    expect(() => LinkFrame.decode(Uint8List.fromList([LinkFrameType.hello.code, 2])),
        throwsA(isA<UnsupportedVersionException>()));
    final broken = LinkFrame.decode;
    expect(() => broken(Uint8List.fromList([LinkFrameType.hello.code, Protocol.version, 1])),
        throwsA(isA<LinkFrameException>().having((e) => e is UnsupportedVersionException, 'other version', isFalse)));
  });

  test('HELLO round-trips, including a non-ASCII nickname', () {
    final h = _hello(nickname: 'Zoë 🙂');
    final d = LinkFrame.decode(h.encode()) as HelloFrame;
    expect(d.protocolVersion, Protocol.version);
    expect(d.signingKey, h.signingKey);
    expect(d.agreementKey, h.agreementKey);
    expect(d.nonce, h.nonce);
    expect(d.nickname, 'Zoë 🙂');
  });

  test('HELLO rejects a nickname over the limit when encoding', () {
    expect(() => _hello(nickname: 'x' * 33).encode(), throwsStateError);
  });

  test('HELLO decode rejects bad nickname length, UTF-8, truncation, trailing bytes', () {
    final good = _hello().encode();
    // nickLen field is at offset 1+1+1+32+32+16 = 83
    final tooLong = Uint8List.fromList(good)..[83] = 200;
    expect(() => LinkFrame.decode(tooLong), throwsA(isA<LinkFrameException>()));

    final badUtf8 = Uint8List.fromList(good)..[84] = 0xff;
    expect(() => LinkFrame.decode(badUtf8), throwsA(isA<LinkFrameException>()));

    for (var n = 1; n < good.length; n++) {
      expect(() => LinkFrame.decode(Uint8List.sublistView(good, 0, n)),
          throwsA(isA<LinkFrameException>()),
          reason: 'truncated to $n');
    }
    expect(() => LinkFrame.decode(Uint8List.fromList([...good, 0])),
        throwsA(isA<LinkFrameException>()));
  });

  test('AUTH round-trips and enforces its length', () {
    final a = AuthFrame(_fill(64, 9));
    expect((LinkFrame.decode(a.encode()) as AuthFrame).signature, a.signature);
    expect(() => LinkFrame.decode(Uint8List.fromList([LinkFrameType.auth.code, 1, 2])),
        throwsA(isA<LinkFrameException>()));
  });

  test('PING/PONG echo arbitrary data', () {
    final data = Uint8List.fromList(List.generate(300, (i) => i % 256));
    expect((LinkFrame.decode(PingFrame(data).encode()) as PingFrame).data, data);
    expect((LinkFrame.decode(PongFrame(data).encode()) as PongFrame).data, data);
    expect((LinkFrame.decode(PingFrame(Uint8List(0)).encode()) as PingFrame).data,
        isEmpty);
  });

  test('BYE carries a reason and rejects a wrong length', () {
    final b = LinkFrame.decode(ByeFrame.reason(ByeReason.duplicateLink).encode()) as ByeFrame;
    expect(b.reason, ByeReason.duplicateLink);
    expect(ByeFrame(250).reason, ByeReason.normal);
    expect(() => LinkFrame.decode(Uint8List.fromList([LinkFrameType.bye.code])),
        throwsA(isA<LinkFrameException>()));
    expect(() => LinkFrame.decode(Uint8List.fromList([LinkFrameType.bye.code, 1, 2])),
        throwsA(isA<LinkFrameException>()));
  });

  test('PACKET frames wrap raw packet bytes', () {
    final bytes = Uint8List.fromList([1, 2, 3, 4]);
    final f = LinkFrame.decode(PacketFrame(bytes).encode()) as PacketFrame;
    expect(f.packetBytes, bytes);
  });

  test('empty, unknown and oversized frames are rejected', () {
    expect(() => LinkFrame.decode(Uint8List(0)), throwsA(isA<LinkFrameException>()));
    expect(() => LinkFrame.decode(Uint8List.fromList([0x77])),
        throwsA(isA<LinkFrameException>()));
    expect(() => LinkFrame.decode(Uint8List(Protocol.maxFrameBytes + 1)..[0] = 0x20),
        throwsA(isA<LinkFrameException>()));
  });

  test('random garbage only ever raises LinkFrameException', () {
    final rng = Random(7);
    for (var i = 0; i < 3000; i++) {
      final len = rng.nextInt(200);
      final bytes = Uint8List.fromList(List.generate(len, (_) => rng.nextInt(256)));
      try {
        LinkFrame.decode(bytes);
      } on LinkFrameException {
        // expected
      }
    }
  });
}
