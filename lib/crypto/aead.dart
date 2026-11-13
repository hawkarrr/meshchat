import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../core/bytes.dart';
import 'hkdf.dart';

/// Thrown when an AEAD ciphertext fails authentication (wrong key, corrupted
/// or tampered data). Deliberately carries no detail.
class AeadFailure implements Exception {
  const AeadFailure();

  @override
  String toString() => 'AeadFailure';
}

/// ChaCha20-Poly1305 (RFC 8439) with the nonce stored in front of the
/// ciphertext: `nonce[12] | ciphertext | tag[16]`.
///
/// Used for group messages and for media chunks. Callers supply the nonce
/// (fresh random bytes) and the associated data that binds the ciphertext to
/// its packet header and position.
abstract final class Aead {
  static const int nonceLength = 12;
  static const int tagLength = 16;
  static const int keyLength = 32;

  /// Bytes added to a plaintext by [seal].
  static const int overhead = nonceLength + tagLength;

  static final Chacha20 _cipher = Chacha20.poly1305Aead();

  static Future<Uint8List> seal({
    required Uint8List key,
    required Uint8List nonce,
    required Uint8List aad,
    required Uint8List plaintext,
  }) async {
    if (key.length != keyLength) throw ArgumentError.value(key.length, 'key', 'must be 32 bytes');
    if (nonce.length != nonceLength) {
      throw ArgumentError.value(nonce.length, 'nonce', 'must be 12 bytes');
    }
    final box = await _cipher.encrypt(
      plaintext,
      secretKey: SecretKey(key),
      nonce: nonce,
      aad: aad,
    );
    return concatBytes([nonce, box.cipherText, box.mac.bytes]);
  }

  static Future<Uint8List> open({
    required Uint8List key,
    required Uint8List aad,
    required Uint8List sealed,
  }) async {
    if (key.length != keyLength || sealed.length < overhead) throw const AeadFailure();
    final nonce = sealed.sublist(0, nonceLength);
    final tagStart = sealed.length - tagLength;
    try {
      final plain = await _cipher.decrypt(
        SecretBox(
          sealed.sublist(nonceLength, tagStart),
          nonce: nonce,
          mac: Mac(sealed.sublist(tagStart)),
        ),
        secretKey: SecretKey(key),
        aad: aad,
      );
      return Uint8List.fromList(plain);
    } on SecretBoxAuthenticationError {
      throw const AeadFailure();
    }
  }

  /// HKDF-SHA256 sub-key: `HKDF(secret, salt, label)`. Used to give every
  /// media object its own key, derived from the group key.
  static Future<Uint8List> deriveKey({
    required Uint8List secret,
    required List<int> salt,
    required String label,
    int length = keyLength,
  }) async {
    final prk = await hkdfExtract(salt: salt, ikm: secret);
    return hkdfExpand(prk: prk, info: utf8.encode(label), length: length);
  }
}
