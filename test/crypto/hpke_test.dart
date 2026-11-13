import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_mesh_chat/core/bytes.dart';
import 'package:offline_mesh_chat/crypto/hpke.dart';

// Test vector: RFC 9180 Appendix A.2.1
// DHKEM(X25519, HKDF-SHA256), HKDF-SHA256, ChaCha20Poly1305 - Base mode.
final _info = hexToBytes('4f6465206f6e2061204772656369616e2055726e');
final _skEm = hexToBytes('f4ec9b33b792c372c1d2c2063507b684ef925b8c75a42dbcbf57d63ccd381600');
final _pkEm = hexToBytes('1afa08d3dec047a643885163f1180476fa7ddb54c6a8029ea33f95796bf2ac4a');
final _skRm = hexToBytes('8057991eef8f1f1af18f4a9491d16a1ce333f695d4db8e38da75975c4478e0fb');
final _pkRm = hexToBytes('4310ee97d88cc1f088a5576c77ab0cf5c3ac797f3d95139c6c84b5429c59662a');
const _sharedSecret = '0bbe78490412b4bbea4812666f7916932b828bba79942424abb65244930d69a7';
const _keyScheduleContext =
    '00431df6cd95e11ff49d7013563baf7f11588c75a6611ee2a4404a49306ae4cf'
    'c5b69c5718a60cc5876c358d3f7fc31ddb598503f67be58ea1e798c0bb19eb9796';
const _secret = '5b9cd775e64b437a2335cf499361b2e0d5e444d5cb41a8a53336d8fe402282c6';
const _key = 'ad2744de8e17f4ebba575b3f5f5a8fa1f69c2a07f6e7500bc60ca6e3e3ec1c91';
const _baseNonce = '5c4d98150661b848853b547f';
final _pt = hexToBytes('4265617574792069732074727574682c20747275746820626561757479');
final _aad = hexToBytes('436f756e742d30');
const _ct =
    '1c5250d8034ec2b784ba2cfd69dbdb8af406cfe3ff938e131f0def8c8b60b4db'
    '21993c62ce81883d2dd1b51a28';

Future<SimpleKeyPair> _recipient() => X25519().newKeyPairFromSeed(_skRm);

void main() {
  test('the RFC key pairs are consistent with the cryptography package', () async {
    final eph = await X25519().newKeyPairFromSeed(_skEm);
    expect((await eph.extractPublicKey()).bytes, _pkEm);
    final rcpt = await _recipient();
    expect((await rcpt.extractPublicKey()).bytes, _pkRm);
  });

  test('key schedule matches RFC 9180 A.2.1', () async {
    final ks = await Hpke.debugKeySchedule(
      ephemeralSeed: _skEm,
      recipientPublicKey: _pkRm,
      info: _info,
    );
    expect(bytesToHex(ks.sharedSecret), _sharedSecret);
    expect(bytesToHex(ks.keyScheduleContext), _keyScheduleContext);
    expect(bytesToHex(ks.secret), _secret);
    expect(bytesToHex(ks.key), _key);
    expect(bytesToHex(ks.baseNonce), _baseNonce);
  });

  test('sealBase reproduces the RFC 9180 A.2.1 ciphertext', () async {
    final sealed = await Hpke.sealBase(
      recipientPublicKey: _pkRm,
      info: _info,
      aad: _aad,
      plaintext: _pt,
      ephemeralSeed: _skEm,
    );
    expect(bytesToHex(sealed.enc), bytesToHex(_pkEm));
    expect(bytesToHex(sealed.ciphertext), _ct);
  });

  test('openBase decrypts the RFC 9180 A.2.1 ciphertext', () async {
    final clear = await Hpke.openBase(
      recipientKeyPair: await _recipient(),
      enc: _pkEm,
      info: _info,
      aad: _aad,
      ciphertext: hexToBytes(_ct),
    );
    expect(clear, _pt);
  });

  group('rejects', () {
    late SimpleKeyPair recipient;
    late HpkeSealed sealed;

    setUp(() async {
      recipient = await _recipient();
      sealed = await Hpke.sealBase(
        recipientPublicKey: _pkRm,
        info: _info,
        aad: _aad,
        plaintext: _pt,
        ephemeralSeed: _skEm,
      );
    });

    Future<Uint8List> open({
      SimpleKeyPair? key,
      Uint8List? enc,
      Uint8List? info,
      Uint8List? aad,
      Uint8List? ct,
    }) =>
        Hpke.openBase(
          recipientKeyPair: key ?? recipient,
          enc: enc ?? sealed.enc,
          info: info ?? _info,
          aad: aad ?? _aad,
          ciphertext: ct ?? sealed.ciphertext,
        );

    test('a flipped ciphertext bit', () async {
      final bad = Uint8List.fromList(sealed.ciphertext)..[3] ^= 0x01;
      expect(open(ct: bad), throwsA(isA<HpkeException>()));
    });

    test('a flipped tag bit', () async {
      final bad = Uint8List.fromList(sealed.ciphertext)
        ..[sealed.ciphertext.length - 1] ^= 0x80;
      expect(open(ct: bad), throwsA(isA<HpkeException>()));
    });

    test('different AAD', () async {
      expect(open(aad: hexToBytes('436f756e742d31')), throwsA(isA<HpkeException>()));
    });

    test('different info', () async {
      expect(open(info: hexToBytes('00')), throwsA(isA<HpkeException>()));
    });

    test('the wrong recipient key', () async {
      final other = await X25519().newKeyPairFromSeed(Uint8List(32)..[0] = 7);
      expect(open(key: other), throwsA(isA<HpkeException>()));
    });

    test('a modified encapsulated key', () async {
      final badEnc = Uint8List.fromList(sealed.enc)..[0] ^= 0x01;
      expect(open(enc: badEnc), throwsA(isA<HpkeException>()));
    });

    test('a truncated ciphertext', () async {
      expect(open(ct: Uint8List(8)), throwsA(isA<HpkeException>()));
    });

    test('an all-zero (low order) encapsulated key', () async {
      expect(open(enc: Uint8List(32)), throwsA(isA<HpkeException>()));
    });

    test('an encapsulated key of the wrong length', () async {
      expect(open(enc: Uint8List(31)), throwsA(isA<HpkeException>()));
    });
  });

  test('fresh ephemeral keys: two seals of the same data differ', () async {
    final a = await Hpke.sealBase(
        recipientPublicKey: _pkRm, info: _info, aad: _aad, plaintext: _pt);
    final b = await Hpke.sealBase(
        recipientPublicKey: _pkRm, info: _info, aad: _aad, plaintext: _pt);
    expect(a.enc, isNot(b.enc));
    expect(a.ciphertext, isNot(b.ciphertext));
    final recipient = await _recipient();
    for (final s in [a, b]) {
      expect(
        await Hpke.openBase(
          recipientKeyPair: recipient,
          enc: s.enc,
          info: _info,
          aad: _aad,
          ciphertext: s.ciphertext,
        ),
        _pt,
      );
    }
  });

  test('seal refuses a degenerate recipient key', () async {
    expect(
      Hpke.sealBase(
        recipientPublicKey: Uint8List(32),
        info: _info,
        aad: _aad,
        plaintext: _pt,
      ),
      throwsA(isA<HpkeException>()),
    );
  });
}
