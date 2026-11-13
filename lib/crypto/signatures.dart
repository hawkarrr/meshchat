import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../protocol/mesh_packet.dart';
import '../protocol/protocol_constants.dart';
import 'weak_keys.dart';

final Ed25519 _ed25519 = Ed25519();

/// Verifies an Ed25519 [signature] over [message]. Any malformed input
/// (wrong lengths, invalid curve point, small-order key) yields `false`
/// rather than throwing, because the inputs come from untrusted neighbours.
Future<bool> verifySignature({
  required Uint8List publicKey,
  required Uint8List message,
  required Uint8List signature,
}) async {
  if (publicKey.length != Protocol.keyLength ||
      signature.length != Protocol.signatureLength) {
    return false;
  }
  if (isWeakEd25519PublicKey(publicKey)) {
    return false;
  }
  try {
    return await _ed25519.verify(
      message,
      signature: Signature(
        signature,
        publicKey: SimplePublicKey(publicKey, type: KeyPairType.ed25519),
      ),
    );
  } catch (_) {
    return false;
  }
}

/// True when [packet] carries a valid signature by its claimed sender key.
///
/// This proves *who sent it* (holder of that key), not that the key belongs
/// to any particular person - that is what key verification is for.
Future<bool> verifyPacketSignature(MeshPacket packet) => verifySignature(
      publicKey: packet.senderKey,
      message: packet.signingBytes(),
      signature: packet.signature,
    );
