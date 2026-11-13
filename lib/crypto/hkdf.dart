import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../core/bytes.dart';

/// HMAC-SHA256 / HKDF-SHA256 (RFC 2104 / RFC 5869) built on the audited
/// primitives of package:cryptography. Split into Extract and Expand because
/// HPKE (RFC 9180) uses the two steps separately with its own labelling.
final Hmac _hmac = Hmac.sha256();

const int sha256Length = 32;

Future<Uint8List> hmacSha256(List<int> key, List<int> data) async {
  final mac = await _hmac.calculateMac(data, secretKey: SecretKey(key));
  return Uint8List.fromList(mac.bytes);
}

/// HKDF-Extract. An empty [salt] means "a string of HashLen zeros" (RFC 5869).
Future<Uint8List> hkdfExtract({
  required List<int> salt,
  required List<int> ikm,
}) {
  final effectiveSalt = salt.isEmpty ? Uint8List(sha256Length) : salt;
  return hmacSha256(effectiveSalt, ikm);
}

/// HKDF-Expand to [length] bytes (at most 255 * 32).
Future<Uint8List> hkdfExpand({
  required List<int> prk,
  required List<int> info,
  required int length,
}) async {
  if (length < 0 || length > 255 * sha256Length) {
    throw ArgumentError.value(length, 'length', 'out of range for HKDF-SHA256');
  }
  final blocks = (length + sha256Length - 1) ~/ sha256Length;
  final out = BytesBuilder(copy: false);
  var previous = Uint8List(0);
  for (var i = 1; i <= blocks; i++) {
    previous = await hmacSha256(prk, concatBytes([previous, info, [i]]));
    out.add(previous);
  }
  return Uint8List.sublistView(out.toBytes(), 0, length);
}
