import 'dart:convert';
import 'dart:typed_data';

import '../core/bytes.dart';
import 'protocol_constants.dart';

/// Thrown when a packet payload is structurally invalid.
class PayloadFormatException extends FormatException {
  const PayloadFormatException(super.message);
}

/// Payload of an `announce` packet: the sender's X25519 key and nickname.
/// The packet's signature binds both to the sender's Ed25519 identity.
class AnnounceContent {
  const AnnounceContent({required this.agreementKey, required this.nickname});

  final Uint8List agreementKey;
  final String nickname;

  Uint8List encode() {
    final nick = utf8.encode(nickname);
    if (nick.length > Protocol.maxNicknameBytes) {
      throw ArgumentError.value(nickname, 'nickname', 'too long');
    }
    return concatBytes([
      agreementKey,
      [nick.length],
      nick,
    ]);
  }

  static AnnounceContent parse(Uint8List payload) {
    try {
      final r = ByteReader(payload);
      final agreement = r.bytes(Protocol.keyLength);
      if (isAllZero(agreement)) {
        // Degenerate X25519 key: every shared secret with it would be zero.
        throw const PayloadFormatException('Degenerate agreement key');
      }
      final nickLen = r.u8();
      if (nickLen > Protocol.maxNicknameBytes) {
        throw const PayloadFormatException('Nickname too long');
      }
      final nickname = utf8.decode(r.bytes(nickLen));
      if (r.remaining != 0) {
        throw const PayloadFormatException('Trailing bytes');
      }
      return AnnounceContent(agreementKey: agreement, nickname: nickname);
    } on PayloadFormatException {
      rethrow;
    } on FormatException catch (e) {
      throw PayloadFormatException(e.message);
    }
  }
}

/// Payload of an `ack` packet: which messages were received.
///
/// One receipt confirms up to [maxIds] messages, so an image that arrives as
/// dozens of packets is confirmed with a handful of receipts, not dozens.
///
/// ```
/// u8 status | u8 count | messageId[16] * count
/// ```
class AckContent {
  AckContent({required this.status, required List<Uint8List> ackedMessageIds})
      : ackedMessageIds = List<Uint8List>.unmodifiable(ackedMessageIds);

  static const int delivered = 0;

  /// Most message ids one receipt may carry.
  static const int maxIds = 16;

  final int status;
  final List<Uint8List> ackedMessageIds;

  List<String> get ackedMessageIdsHex => [for (final id in ackedMessageIds) bytesToHex(id)];

  Uint8List encode() {
    if (ackedMessageIds.isEmpty || ackedMessageIds.length > maxIds) {
      throw ArgumentError.value(ackedMessageIds.length, 'ackedMessageIds', 'must be 1..$maxIds');
    }
    for (final id in ackedMessageIds) {
      if (id.length != Protocol.messageIdLength) {
        throw ArgumentError.value(id.length, 'ackedMessageId', 'must be 16 bytes');
      }
    }
    return concatBytes([
      [status, ackedMessageIds.length],
      ...ackedMessageIds,
    ]);
  }

  static AckContent parse(Uint8List payload) {
    if (payload.length < 2) throw const PayloadFormatException('Ack too short');
    final count = payload[1];
    if (count == 0 || count > maxIds) throw const PayloadFormatException('Bad ack count');
    if (payload.length != 2 + count * Protocol.messageIdLength) {
      throw const PayloadFormatException('Bad ack length');
    }
    return AckContent(
      status: payload[0],
      ackedMessageIds: [
        for (var i = 0; i < count; i++)
          Uint8List.fromList(payload.sublist(
            2 + i * Protocol.messageIdLength,
            2 + (i + 1) * Protocol.messageIdLength,
          )),
      ],
    );
  }
}
