import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:offline_mesh_chat/crypto/key_store.dart';
import 'package:offline_mesh_chat/crypto/signatures.dart';
import 'package:offline_mesh_chat/crypto/weak_keys.dart';
import 'package:offline_mesh_chat/services/encryption_service.dart';

// ---------------------------------------------------------------------------
// Independent Edwards25519 arithmetic (affine, BigInt) used ONLY to check that
// the constants in weak_keys.dart really are the curve's small-order points.
// ---------------------------------------------------------------------------
final BigInt _p = curveFieldPrime;
final BigInt _d = (BigInt.from(-121665) * BigInt.from(121666).modInverse(_p)) % _p;

BigInt _mod(BigInt a) => a % _p;

class _Pt {
  _Pt(this.x, this.y);

  final BigInt x;
  final BigInt y;

  bool get isIdentity => x == BigInt.zero && y == BigInt.one;
}

_Pt _add(_Pt a, _Pt b) {
  final dxy = _mod(_d * a.x * b.x * a.y * b.y);
  final x3 = _mod((a.x * b.y + a.y * b.x) * _mod(BigInt.one + dxy).modInverse(_p));
  final y3 = _mod((a.y * b.y + a.x * b.x) * _mod(BigInt.one - dxy).modInverse(_p));
  return _Pt(x3, y3);
}

_Pt _mul(_Pt a, int k) {
  var result = _Pt(BigInt.zero, BigInt.one);
  var addend = a;
  while (k > 0) {
    if (k & 1 == 1) result = _add(result, addend);
    addend = _add(addend, addend);
    k >>= 1;
  }
  return result;
}

BigInt _sqrt(BigInt a) {
  // p = 5 (mod 8)
  var r = a.modPow((_p + BigInt.from(3)) ~/ BigInt.from(8), _p);
  if (_mod(r * r) == _mod(a)) return r;
  r = _mod(r * BigInt.two.modPow((_p - BigInt.one) ~/ BigInt.from(4), _p));
  if (_mod(r * r) != _mod(a)) {
    throw StateError('not a square');
  }
  return r;
}

_Pt _pointWithY(BigInt y) {
  final y2 = _mod(y * y);
  final x2 = _mod((y2 - BigInt.one) * _mod(_d * y2 + BigInt.one).modInverse(_p));
  return _Pt(_sqrt(x2), y);
}

Uint8List _encode(BigInt y, {bool signBit = false}) {
  final out = Uint8List(32);
  var v = y;
  for (var i = 0; i < 32; i++) {
    out[i] = (v & BigInt.from(0xff)).toInt();
    v >>= 8;
  }
  if (signBit) out[31] |= 0x80;
  return out;
}

void main() {
  group('the blocklist matches the curve\'s torsion subgroup', () {
    test('every listed y coordinate is a point of order dividing 8', () {
      for (final y in smallOrderYCoordinates) {
        final pt = _pointWithY(y);
        // Make sure our arithmetic put the point on the curve.
        expect(
          _mod(-pt.x * pt.x + pt.y * pt.y),
          _mod(BigInt.one + _d * pt.x * pt.x * pt.y * pt.y),
        );
        expect(_mul(pt, 8).isIdentity, isTrue, reason: 'y=$y');
      }
    });

    test('the two large constants have exact order 8', () {
      final big = smallOrderYCoordinates.where((y) => y > BigInt.from(1000000));
      // p-1 is also "large"; filter it out.
      final order8 = big.where((y) => y != _p - BigInt.one).toList();
      expect(order8.length, 2);
      for (final y in order8) {
        final pt = _pointWithY(y);
        expect(_mul(pt, 4).isIdentity, isFalse);
        expect(_mul(pt, 8).isIdentity, isTrue);
      }
    });

    test('they are negatives of each other (y and p-y), as the theory predicts', () {
      final order8 = smallOrderYCoordinates
          .where((y) => y > BigInt.from(1000000) && y != _p - BigInt.one)
          .toList();
      expect(order8[0] + order8[1], _p);
    });

    test('a point outside the list is not small order', () async {
      final store = MemoryKeyStore();
      final svc = await EncryptionService.loadOrCreate(store);
      final pub = svc.identity.signingPublicKey;
      expect(isWeakEd25519PublicKey(pub), isFalse);
      // A real public key, decompressed, must not be 8-torsion.
      var y = BigInt.zero;
      for (var i = 31; i >= 0; i--) {
        y = (y << 8) | BigInt.from(i == 31 ? pub[i] & 0x7f : pub[i]);
      }
      expect(_mul(_pointWithY(y), 8).isIdentity, isFalse);
    });
  });

  group('isWeakEd25519PublicKey', () {
    test('rejects the all-zero key and the identity', () {
      expect(isWeakEd25519PublicKey(Uint8List(32)), isTrue);
      expect(isWeakEd25519PublicKey(_encode(BigInt.one)), isTrue);
    });

    test('ignores the sign bit', () {
      expect(isWeakEd25519PublicKey(_encode(BigInt.zero, signBit: true)), isTrue);
      expect(isWeakEd25519PublicKey(_encode(BigInt.one, signBit: true)), isTrue);
    });

    test('rejects all five small-order y values with either sign', () {
      for (final y in smallOrderYCoordinates) {
        expect(isWeakEd25519PublicKey(_encode(y)), isTrue);
        expect(isWeakEd25519PublicKey(_encode(y, signBit: true)), isTrue);
      }
    });

    test('rejects non-canonical encodings (y >= p)', () {
      expect(isWeakEd25519PublicKey(_encode(_p)), isTrue); // aliases y=0
      expect(isWeakEd25519PublicKey(_encode(_p + BigInt.one)), isTrue); // aliases y=1
      expect(isWeakEd25519PublicKey(_encode(_p + BigInt.from(5))), isTrue);
    });

    test('rejects keys of the wrong length', () {
      expect(isWeakEd25519PublicKey(Uint8List(31)), isTrue);
      expect(isWeakEd25519PublicKey(Uint8List(33)), isTrue);
    });

    test('accepts a freshly generated identity key', () async {
      final svc = await EncryptionService.loadOrCreate(MemoryKeyStore());
      expect(isUsableEd25519PublicKey(svc.identity.signingPublicKey), isTrue);
    });
  });

  group('verifySignature refuses weak keys', () {
    test('the all-zero key with an all-zero signature never verifies', () async {
      // Before the guard, the pure-Dart verifier accepted this for ~1 message in 4.
      var accepted = 0;
      for (var i = 0; i < 64; i++) {
        final ok = await verifySignature(
          publicKey: Uint8List(32),
          message: Uint8List.fromList([i, i + 1, i + 2]),
          signature: Uint8List(64),
        );
        if (ok) accepted++;
      }
      expect(accepted, 0);
    });

    test('crafted (R = A, S = 0) forgeries for every small-order key are rejected', () async {
      for (final y in smallOrderYCoordinates) {
        final key = _encode(y);
        final sig = Uint8List(64)..setRange(0, 32, key);
        for (var i = 0; i < 24; i++) {
          expect(
            await verifySignature(
              publicKey: key,
              message: Uint8List.fromList([i]),
              signature: sig,
            ),
            isFalse,
          );
        }
      }
    });
  });
}
