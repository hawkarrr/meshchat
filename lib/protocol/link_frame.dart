import 'dart:convert';
import 'dart:typed_data';

import '../core/bytes.dart';
import 'protocol_constants.dart';

/// Thrown when a link frame received from a neighbour is malformed.
class LinkFrameException extends FormatException {
  const LinkFrameException(super.message);
}

/// A HELLO in a protocol version this app does not speak.
///
/// Only its first byte, the version, is read: the rest of another version's
/// HELLO may be laid out differently. That first byte stays the version in every
/// version of the protocol, so a phone can always tell "another version" from
/// "a broken frame".
class UnsupportedVersionException extends LinkFrameException {
  UnsupportedVersionException(this.version)
      : super('Protocol version $version is not supported (this app speaks ${Protocol.version})');

  final int version;
}

enum LinkFrameType {
  /// Identity announcement exchanged by both ends right after connecting.
  hello(0x01),

  /// Proof that the sender holds the private key it claimed in its HELLO.
  auth(0x02),

  /// Keepalive / diagnostics probe. The peer echoes the same bytes in a PONG.
  ping(0x10),
  pong(0x11),

  /// Polite close with a reason code.
  bye(0x1f),

  /// Carries one serialized `MeshPacket`.
  packet(0x20);

  const LinkFrameType(this.code);

  final int code;

  static LinkFrameType? fromCode(int code) {
    for (final t in LinkFrameType.values) {
      if (t.code == code) return t;
    }
    return null;
  }
}

/// A frame exchanged between two directly connected phones. These never leave
/// the link: only `PacketFrame` contents are routed through the mesh.
sealed class LinkFrame {
  const LinkFrame();

  LinkFrameType get type;

  Uint8List encode();

  static LinkFrame decode(Uint8List bytes) {
    if (bytes.isEmpty) {
      throw const LinkFrameException('Empty frame');
    }
    if (bytes.length > Protocol.maxFrameBytes) {
      throw const LinkFrameException('Frame too large');
    }
    final type = LinkFrameType.fromCode(bytes[0]);
    if (type == null) {
      throw LinkFrameException('Unknown frame type 0x${bytes[0].toRadixString(16)}');
    }
    final body = Uint8List.sublistView(bytes, 1);
    try {
      switch (type) {
        case LinkFrameType.hello:
          return HelloFrame._decode(body);
        case LinkFrameType.auth:
          return AuthFrame._decode(body);
        case LinkFrameType.ping:
          return PingFrame(Uint8List.fromList(body));
        case LinkFrameType.pong:
          return PongFrame(Uint8List.fromList(body));
        case LinkFrameType.bye:
          if (body.length != 1) {
            throw const LinkFrameException('Bad BYE frame');
          }
          return ByeFrame(body[0]);
        case LinkFrameType.packet:
          return PacketFrame(Uint8List.fromList(body));
      }
    } on LinkFrameException {
      rethrow;
    } on FormatException catch (e) {
      throw LinkFrameException(e.message);
    }
  }
}

class HelloFrame extends LinkFrame {
  HelloFrame({
    required this.protocolVersion,
    required this.signingKey,
    required this.agreementKey,
    required this.nonce,
    required this.nickname,
    this.capabilities = 0,
  });

  static const int nonceLength = 16;

  final int protocolVersion;
  final Uint8List signingKey;
  final Uint8List agreementKey;

  /// Fresh random challenge. The peer signs it (together with other values)
  /// to prove possession of the private key; see `AuthFrame`.
  final Uint8List nonce;
  final String nickname;
  final int capabilities;

  @override
  LinkFrameType get type => LinkFrameType.hello;

  @override
  Uint8List encode() {
    final nick = utf8.encode(nickname);
    if (nick.length > Protocol.maxNicknameBytes) {
      throw StateError('Nickname too long');
    }
    final w = ByteWriter()
      ..u8(type.code)
      ..u8(protocolVersion)
      ..u8(capabilities)
      ..bytes(signingKey)
      ..bytes(agreementKey)
      ..bytes(nonce)
      ..u8(nick.length)
      ..bytes(nick);
    return w.toBytes();
  }

  static HelloFrame _decode(Uint8List body) {
    final r = ByteReader(body);
    final version = r.u8();
    if (version != Protocol.version) throw UnsupportedVersionException(version);
    final caps = r.u8();
    final signing = r.bytes(Protocol.keyLength);
    final agreement = r.bytes(Protocol.keyLength);
    final nonce = r.bytes(nonceLength);
    final nickLen = r.u8();
    if (nickLen > Protocol.maxNicknameBytes) {
      throw const LinkFrameException('Nickname too long');
    }
    final nickBytes = r.bytes(nickLen);
    if (r.remaining != 0) {
      throw const LinkFrameException('Trailing bytes in HELLO');
    }
    String nickname;
    try {
      nickname = utf8.decode(nickBytes);
    } on FormatException {
      throw const LinkFrameException('Nickname is not valid UTF-8');
    }
    return HelloFrame(
      protocolVersion: version,
      signingKey: signing,
      agreementKey: agreement,
      nonce: nonce,
      nickname: nickname,
      capabilities: caps,
    );
  }
}

class AuthFrame extends LinkFrame {
  const AuthFrame(this.signature);

  final Uint8List signature;

  @override
  LinkFrameType get type => LinkFrameType.auth;

  @override
  Uint8List encode() => concatBytes([
        [type.code],
        signature,
      ]);

  static AuthFrame _decode(Uint8List body) {
    if (body.length != Protocol.signatureLength) {
      throw const LinkFrameException('Bad AUTH length');
    }
    return AuthFrame(Uint8List.fromList(body));
  }
}

class PingFrame extends LinkFrame {
  const PingFrame(this.data);

  /// Opaque bytes echoed back unchanged. The first 4 bytes are conventionally
  /// a sequence number; any extra bytes are padding used by the diagnostics
  /// screen to exercise fragmentation.
  final Uint8List data;

  @override
  LinkFrameType get type => LinkFrameType.ping;

  @override
  Uint8List encode() => concatBytes([
        [type.code],
        data,
      ]);
}

class PongFrame extends LinkFrame {
  const PongFrame(this.data);

  final Uint8List data;

  @override
  LinkFrameType get type => LinkFrameType.pong;

  @override
  Uint8List encode() => concatBytes([
        [type.code],
        data,
      ]);
}

enum ByeReason {
  normal(0),
  duplicateLink(1),
  authFailed(2),
  protocolError(3),
  rateLimited(4),
  shuttingDown(5);

  const ByeReason(this.code);

  final int code;

  static ByeReason fromCode(int code) {
    for (final r in ByeReason.values) {
      if (r.code == code) return r;
    }
    return ByeReason.normal;
  }
}

class ByeFrame extends LinkFrame {
  const ByeFrame(this.reasonCode);

  ByeFrame.reason(ByeReason reason) : reasonCode = reason.code;

  final int reasonCode;

  ByeReason get reason => ByeReason.fromCode(reasonCode);

  @override
  LinkFrameType get type => LinkFrameType.bye;

  @override
  Uint8List encode() => Uint8List.fromList([type.code, reasonCode]);
}

class PacketFrame extends LinkFrame {
  const PacketFrame(this.packetBytes);

  final Uint8List packetBytes;

  @override
  LinkFrameType get type => LinkFrameType.packet;

  @override
  Uint8List encode() => concatBytes([
        [type.code],
        packetBytes,
      ]);
}
