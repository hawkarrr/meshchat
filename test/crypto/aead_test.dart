import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:offline_mesh_chat/core/bytes.dart';
import 'package:offline_mesh_chat/crypto/aead.dart';

Uint8List _hex(String s) => hexToBytes(s.replaceAll(RegExp(r'\s'), ''));

void main() {
  group('ChaCha20-Poly1305 (RFC 8439 section 2.8.2 test vector)', () {
    final key = _hex('808182838485868788898a8b8c8d8e8f909192939495969798999a9b9c9d9e9f');
    final nonce = _hex('070000004041424344454647');
    final aad = _hex('50515253c0c1c2c3c4c5c6c7');
    final plaintext = Uint8List.fromList(
      ("Ladies and Gentlemen of the class of '99: If I could offer you only one tip for the future, sunscreen would be it.")
          .codeUnits,
    );
    const expectedCipher =
        'd31a8d34648e60db7b86afbc53ef7ec2a4aded51296e08fea9e2b5a736ee62d6'
        '3dbea45e8ca9671282fafb69da92728b1a71de0a9e060b2905d6a5b67ecd3b36'
        '92ddbd7f2d778b8c9803aee328091b58fab324e4fad675945585808b4831d7bc'
        '3ff4def08e4b7a9de576d26586cec64b6116';
    const expectedTag = '1ae10b594f09e26a7e902ecbd0600691';

    test('seal matches the published ciphertext and tag', () async {
      final sealed = await Aead.seal(key: key, nonce: nonce, aad: aad, plaintext: plaintext);
      expect(sealed.sublist(0, 12), nonce);
      expect(bytesToHex(Uint8List.sublistView(sealed, 12, sealed.length - 16)), expectedCipher);
      expect(bytesToHex(Uint8List.sublistView(sealed, sealed.length - 16)), expectedTag);
    });

    test('open recovers the plaintext', () async {
      final sealed = await Aead.seal(key: key, nonce: nonce, aad: aad, plaintext: plaintext);
      expect(await Aead.open(key: key, aad: aad, sealed: sealed), plaintext);
    });
  });

  group('Aead', () {
    final key = Uint8List.fromList(List<int>.generate(32, (i) => i));
    Uint8List nonce(int n) => Uint8List.fromList(List<int>.generate(12, (i) => n + i));
    final aad = Uint8List.fromList([1, 2, 3]);
    final plain = Uint8List.fromList(List<int>.generate(100, (i) => i * 3));

    test('adds exactly the documented overhead', () async {
      final sealed = await Aead.seal(key: key, nonce: nonce(0), aad: aad, plaintext: plain);
      expect(sealed.length, plain.length + Aead.overhead);
    });

    test('a different key, aad or any flipped bit fails with AeadFailure', () async {
      final sealed = await Aead.seal(key: key, nonce: nonce(0), aad: aad, plaintext: plain);
      final other = Uint8List.fromList(key)..[0] ^= 1;
      await expectLater(Aead.open(key: other, aad: aad, sealed: sealed), throwsA(isA<AeadFailure>()));
      await expectLater(
          Aead.open(key: key, aad: Uint8List.fromList([1, 2, 4]), sealed: sealed),
          throwsA(isA<AeadFailure>()));
      for (var i = 0; i < sealed.length; i += 7) {
        final tampered = Uint8List.fromList(sealed)..[i] ^= 0x10;
        await expectLater(Aead.open(key: key, aad: aad, sealed: tampered), throwsA(isA<AeadFailure>()),
            reason: 'byte $i');
      }
    });

    test('too-short input is a clean AeadFailure', () async {
      for (final n in [0, 1, 27]) {
        await expectLater(
            Aead.open(key: key, aad: aad, sealed: Uint8List(n)), throwsA(isA<AeadFailure>()));
      }
    });

    test('bad key and nonce sizes are argument errors', () async {
      await expectLater(
          Aead.seal(key: Uint8List(31), nonce: nonce(0), aad: aad, plaintext: plain), throwsArgumentError);
      await expectLater(
          Aead.seal(key: key, nonce: Uint8List(8), aad: aad, plaintext: plain), throwsArgumentError);
    });

    test('an empty plaintext works', () async {
      final sealed = await Aead.seal(key: key, nonce: nonce(0), aad: aad, plaintext: Uint8List(0));
      expect(sealed.length, Aead.overhead);
      expect(await Aead.open(key: key, aad: aad, sealed: sealed), isEmpty);
    });
  });

  group('Aead.deriveKey', () {
    final secret = Uint8List.fromList(List<int>.generate(32, (i) => 255 - i));

    test('is deterministic, 32 bytes, and depends on every input', () async {
      final a = await Aead.deriveKey(secret: secret, salt: [1, 2, 3], label: 'x');
      final b = await Aead.deriveKey(secret: secret, salt: [1, 2, 3], label: 'x');
      expect(a, b);
      expect(a.length, 32);
      expect(await Aead.deriveKey(secret: secret, salt: [1, 2, 4], label: 'x'), isNot(a));
      expect(await Aead.deriveKey(secret: secret, salt: [1, 2, 3], label: 'y'), isNot(a));
      final other = Uint8List.fromList(secret)..[0] ^= 1;
      expect(await Aead.deriveKey(secret: other, salt: [1, 2, 3], label: 'x'), isNot(a));
    });
  });
}
