import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:offline_mesh_chat/core/bytes.dart';
import 'package:offline_mesh_chat/crypto/hkdf.dart';

// Test vectors: RFC 5869 Appendix A (HKDF with SHA-256).
void main() {
  test('RFC 5869 test case 1 (basic)', () async {
    final ikm = hexToBytes('0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b');
    final salt = hexToBytes('000102030405060708090a0b0c');
    final info = hexToBytes('f0f1f2f3f4f5f6f7f8f9');

    final prk = await hkdfExtract(salt: salt, ikm: ikm);
    expect(
      bytesToHex(prk),
      '077709362c2e32df0ddc3f0dc47bba6390b6c73bb50f9c3122ec844ad7c2b3e5',
    );
    final okm = await hkdfExpand(prk: prk, info: info, length: 42);
    expect(
      bytesToHex(okm),
      '3cb25f25faacd57a90434f64d0362f2a2d2d0a90cf1a5a4c5db02d56ecc4c5bf'
      '34007208d5b887185865',
    );
  });

  test('RFC 5869 test case 3 (empty salt and info)', () async {
    final ikm = hexToBytes('0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b');
    final prk = await hkdfExtract(salt: const <int>[], ikm: ikm);
    expect(
      bytesToHex(prk),
      '19ef24a32c717b167f33a91d6f648bdf96596776afdb6377ac434c1c293ccb04',
    );
    final okm = await hkdfExpand(prk: prk, info: const <int>[], length: 42);
    expect(
      bytesToHex(okm),
      '8da4e775a563c18f715f802a063c5a31b8a11f5c5ee1879ec3454e5f3c738d2d'
      '9d201395faa4b61a96c8',
    );
  });

  test('expand rejects lengths above 255 blocks', () async {
    expect(
      () => hkdfExpand(prk: Uint8List(32), info: const <int>[], length: 255 * 32 + 1),
      throwsArgumentError,
    );
  });

  test('expand of zero length is empty', () async {
    final out = await hkdfExpand(prk: Uint8List(32), info: const <int>[], length: 0);
    expect(out, isEmpty);
  });
}
