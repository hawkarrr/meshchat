import 'dart:typed_data';

/// Rejection of degenerate Ed25519 public keys.
///
/// Curve25519 has a cofactor of 8, so eight points have small order. If an
/// attacker chooses one of them as an "identity", signature verification
/// accepts crafted signatures for a sizeable fraction of messages (for the
/// all-zero key, roughly one message in four) without knowing any secret.
/// libsodium refuses such keys outright; so do we. Non-canonical encodings
/// (y >= p) are refused for the same reason: they alias other keys.
///
/// A small-order point is fully described by its y coordinate: 0, 1, p-1 and
/// the two order-8 values below. The sign bit of the encoding only selects
/// x, so it is ignored here (as libsodium does).
final BigInt _p = (BigInt.one << 255) - BigInt.from(19);

final Set<BigInt> _smallOrderY = <BigInt>{
  BigInt.zero, // order 4
  BigInt.one, // order 1 (the identity)
  _p - BigInt.one, // order 2
  BigInt.parse(
      '2707385501144840649318225287225658788936804267575313519463743609750303402022'), // order 8
  BigInt.parse(
      '55188659117513257062467267217118295137698188065244968500265048394206261417927'), // order 8
};

/// Exposed for tests.
final Set<BigInt> smallOrderYCoordinates = Set.unmodifiable(_smallOrderY);

/// Exposed for tests.
BigInt get curveFieldPrime => _p;

/// True when [key] must not be accepted as an Ed25519 identity.
bool isWeakEd25519PublicKey(List<int> key) {
  if (key.length != 32) return true;
  var y = BigInt.zero;
  for (var i = 31; i >= 0; i--) {
    final byte = i == 31 ? key[i] & 0x7f : key[i];
    y = (y << 8) | BigInt.from(byte);
  }
  if (y >= _p) return true; // non-canonical encoding
  return _smallOrderY.contains(y);
}

/// Convenience for call sites holding a [Uint8List].
bool isUsableEd25519PublicKey(Uint8List key) => !isWeakEd25519PublicKey(key);
