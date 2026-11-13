import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../core/bytes.dart';
import 'hkdf.dart';

/// Thrown when HPKE decryption fails (bad key, tampered data, wrong context).
/// Deliberately carries no detail about *why* so callers cannot build an
/// oracle from it.
class HpkeException implements Exception {
  const HpkeException(this.message);

  final String message;

  @override
  String toString() => 'HpkeException: $message';
}

/// Result of [Hpke.sealBase].
class HpkeSealed {
  const HpkeSealed({required this.enc, required this.ciphertext});

  /// The sender's ephemeral X25519 public key (the encapsulated key).
  final Uint8List enc;

  /// AEAD ciphertext with the 16-byte Poly1305 tag appended.
  final Uint8List ciphertext;
}

/// Intermediate values of the key schedule, exposed so unit tests can compare
/// them with the published RFC 9180 test vectors.
class HpkeKeySchedule {
  const HpkeKeySchedule({
    required this.sharedSecret,
    required this.keyScheduleContext,
    required this.secret,
    required this.key,
    required this.baseNonce,
  });

  final Uint8List sharedSecret;
  final Uint8List keyScheduleContext;
  final Uint8List secret;
  final Uint8List key;
  final Uint8List baseNonce;
}

/// Hybrid Public Key Encryption, RFC 9180, **Base mode (0x00)** only, with the
/// ciphersuite:
///
///  * KEM:  DHKEM(X25519, HKDF-SHA256)  (kem_id 0x0020)
///  * KDF:  HKDF-SHA256                 (kdf_id 0x0001)
///  * AEAD: ChaCha20-Poly1305           (aead_id 0x0003)
///
/// This is a single-shot API: each call creates a fresh encryption context
/// and uses sequence number 0, so a context key/nonce pair is never reused.
/// The implementation is checked against the RFC 9180 Appendix A.2.1 test
/// vector in `test/crypto/hpke_test.dart`.
///
/// HPKE Base mode authenticates nothing about the *sender* by itself; the
/// mesh protocol adds an Ed25519 signature over the packet for that.
abstract final class Hpke {
  static const int _kemId = 0x0020;
  static const int _kdfId = 0x0001;
  static const int _aeadId = 0x0003;

  static const int nSecret = 32;
  static const int nKey = 32;
  static const int nNonce = 12;
  static const int publicKeyLength = 32;
  static const int tagLength = 16;

  static final Uint8List _suiteIdKem =
      concatBytes([utf8.encode('KEM'), _i2osp2(_kemId)]);
  static final Uint8List _suiteId = concatBytes([
    utf8.encode('HPKE'),
    _i2osp2(_kemId),
    _i2osp2(_kdfId),
    _i2osp2(_aeadId),
  ]);
  static final Uint8List _version = Uint8List.fromList(utf8.encode('HPKE-v1'));

  static Uint8List _i2osp2(int v) => Uint8List.fromList([(v >> 8) & 0xff, v & 0xff]);

  static Future<Uint8List> _labeledExtract(
    Uint8List suiteId,
    List<int> salt,
    String label,
    List<int> ikm,
  ) {
    final labeledIkm = concatBytes([_version, suiteId, utf8.encode(label), ikm]);
    return hkdfExtract(salt: salt, ikm: labeledIkm);
  }

  static Future<Uint8List> _labeledExpand(
    Uint8List suiteId,
    List<int> prk,
    String label,
    List<int> info,
    int length,
  ) {
    final labeledInfo = concatBytes([
      _i2osp2(length),
      _version,
      suiteId,
      utf8.encode(label),
      info,
    ]);
    return hkdfExpand(prk: prk, info: labeledInfo, length: length);
  }

  /// DH() for X25519, rejecting the all-zero output produced by low-order
  /// public keys (RFC 9180 section 7.1.4).
  static Future<Uint8List> _dh(SimpleKeyPair privateKey, Uint8List publicKey) async {
    if (publicKey.length != publicKeyLength) {
      throw const HpkeException('Invalid public key length');
    }
    final secret = await X25519().sharedSecretKey(
      keyPair: privateKey,
      remotePublicKey: SimplePublicKey(publicKey, type: KeyPairType.x25519),
    );
    final bytes = Uint8List.fromList(await secret.extractBytes());
    if (isAllZero(bytes)) {
      throw const HpkeException('Degenerate Diffie-Hellman output');
    }
    return bytes;
  }

  static Future<Uint8List> _extractAndExpand(Uint8List dh, Uint8List kemContext) async {
    final eaePrk = await _labeledExtract(_suiteIdKem, const <int>[], 'eae_prk', dh);
    return _labeledExpand(_suiteIdKem, eaePrk, 'shared_secret', kemContext, nSecret);
  }

  static Future<HpkeKeySchedule> _keySchedule(
    Uint8List sharedSecret,
    Uint8List info,
  ) async {
    const mode = 0x00; // Base mode
    final pskIdHash =
        await _labeledExtract(_suiteId, const <int>[], 'psk_id_hash', const <int>[]);
    final infoHash = await _labeledExtract(_suiteId, const <int>[], 'info_hash', info);
    final context = concatBytes([
      [mode],
      pskIdHash,
      infoHash,
    ]);
    final secret = await _labeledExtract(_suiteId, sharedSecret, 'secret', const <int>[]);
    final key = await _labeledExpand(_suiteId, secret, 'key', context, nKey);
    final baseNonce =
        await _labeledExpand(_suiteId, secret, 'base_nonce', context, nNonce);
    return HpkeKeySchedule(
      sharedSecret: sharedSecret,
      keyScheduleContext: context,
      secret: secret,
      key: key,
      baseNonce: baseNonce,
    );
  }

  /// Encrypts [plaintext] to [recipientPublicKey] (a 32-byte X25519 key).
  ///
  /// [info] and [aad] are bound to the ciphertext: decryption fails unless
  /// the recipient supplies identical values.
  ///
  /// [ephemeralSeed] exists only so tests can reproduce the RFC vectors; in
  /// production leave it null so a fresh random key pair is generated.
  static Future<HpkeSealed> sealBase({
    required Uint8List recipientPublicKey,
    required Uint8List info,
    required Uint8List aad,
    required Uint8List plaintext,
    Uint8List? ephemeralSeed,
  }) async {
    final x25519 = X25519();
    final ephemeral = ephemeralSeed != null
        ? await x25519.newKeyPairFromSeed(ephemeralSeed)
        : await x25519.newKeyPair();
    final enc = Uint8List.fromList((await ephemeral.extractPublicKey()).bytes);
    final dh = await _dh(ephemeral, recipientPublicKey);
    final kemContext = concatBytes([enc, recipientPublicKey]);
    final sharedSecret = await _extractAndExpand(dh, kemContext);
    final schedule = await _keySchedule(sharedSecret, info);

    final box = await Chacha20.poly1305Aead().encrypt(
      plaintext,
      secretKey: SecretKey(schedule.key),
      nonce: schedule.baseNonce, // sequence number 0: nonce == base_nonce
      aad: aad,
    );
    return HpkeSealed(
      enc: enc,
      ciphertext: concatBytes([box.cipherText, box.mac.bytes]),
    );
  }

  /// Decrypts a message produced by [sealBase]. Throws [HpkeException] on any
  /// failure.
  static Future<Uint8List> openBase({
    required SimpleKeyPair recipientKeyPair,
    required Uint8List enc,
    required Uint8List info,
    required Uint8List aad,
    required Uint8List ciphertext,
  }) async {
    if (enc.length != publicKeyLength) {
      throw const HpkeException('Invalid encapsulated key length');
    }
    if (ciphertext.length < tagLength) {
      throw const HpkeException('Ciphertext too short');
    }
    final recipientPublic =
        Uint8List.fromList((await recipientKeyPair.extractPublicKey()).bytes);
    final dh = await _dh(recipientKeyPair, enc);
    final kemContext = concatBytes([enc, recipientPublic]);
    final sharedSecret = await _extractAndExpand(dh, kemContext);
    final schedule = await _keySchedule(sharedSecret, info);

    final split = ciphertext.length - tagLength;
    try {
      final clear = await Chacha20.poly1305Aead().decrypt(
        SecretBox(
          Uint8List.sublistView(ciphertext, 0, split),
          nonce: schedule.baseNonce,
          mac: Mac(Uint8List.sublistView(ciphertext, split)),
        ),
        secretKey: SecretKey(schedule.key),
        aad: aad,
      );
      return Uint8List.fromList(clear);
    } on SecretBoxAuthenticationError {
      throw const HpkeException('Authentication failed');
    }
  }

  /// Recomputes the key schedule for given inputs. Test hook for verifying
  /// the implementation against RFC 9180 Appendix A.
  static Future<HpkeKeySchedule> debugKeySchedule({
    required Uint8List ephemeralSeed,
    required Uint8List recipientPublicKey,
    required Uint8List info,
  }) async {
    final ephemeral = await X25519().newKeyPairFromSeed(ephemeralSeed);
    final enc = Uint8List.fromList((await ephemeral.extractPublicKey()).bytes);
    final dh = await _dh(ephemeral, recipientPublicKey);
    final sharedSecret =
        await _extractAndExpand(dh, concatBytes([enc, recipientPublicKey]));
    return _keySchedule(sharedSecret, info);
  }
}
