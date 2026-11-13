import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../core/bytes.dart';

/// Human-comparable identifiers for key verification.
///
/// Verification means two people compare these values over a channel an
/// attacker cannot tamper with (in person, or a phone call they recognise)
/// and confirm they match. It is the only defence against a man-in-the-middle
/// who substitutes keys the first time two phones meet.
abstract final class Fingerprints {
  /// SHA-256 over both public keys of one identity.
  static Future<Uint8List> of({
    required Uint8List signingKey,
    required Uint8List agreementKey,
  }) async {
    final h = await Sha256().hash(concatBytes([
      utf8.encode('meshchat/v1/fingerprint\u0000'),
      signingKey,
      agreementKey,
    ]));
    return Uint8List.fromList(h.bytes);
  }

  /// 64 hex characters in 16 groups of four, upper case. (Fingerprints are
  /// SHA-256, so exactly 32 bytes.)
  static String formatHex(Uint8List fingerprint) {
    final hex = bytesToHex(fingerprint).toUpperCase();
    final groups = <String>[];
    for (var i = 0; i < hex.length; i += 4) {
      groups.add(hex.substring(i, i + 4));
    }
    return groups.join(' ');
  }

  /// A 30-digit number, identical on both phones, that is easier to read out
  /// than a hex fingerprint. Derived from both fingerprints in a canonical
  /// order so each side computes the same value.
  static Future<String> safetyNumber({
    required Uint8List localFingerprint,
    required Uint8List remoteFingerprint,
  }) async {
    final ordered = compareBytes(localFingerprint, remoteFingerprint) <= 0
        ? [localFingerprint, remoteFingerprint]
        : [remoteFingerprint, localFingerprint];
    final h = await Sha256().hash(concatBytes([
      utf8.encode('meshchat/v1/safety-number\u0000'),
      ordered[0],
      ordered[1],
    ]));
    final digest = Uint8List.fromList(h.bytes);
    final groups = <String>[];
    for (var i = 0; i < 6; i++) {
      var v = 0;
      for (var j = 0; j < 5; j++) {
        v = (v << 8) | digest[i * 5 + j];
      }
      groups.add((v % 100000).toString().padLeft(5, '0'));
    }
    return groups.join(' ');
  }
}
