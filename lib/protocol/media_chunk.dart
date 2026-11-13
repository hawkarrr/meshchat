import 'dart:typed_data';

import '../core/bytes.dart';
import 'protocol_constants.dart';

/// Thrown when a media-chunk payload is malformed.
class ChunkFormatException extends FormatException {
  const ChunkFormatException(super.message);
}

/// One piece of an image or voice message.
///
/// Payload layout of a chunk packet (group packets put a `u32` key epoch in
/// front of it):
///
/// ```
/// mediaId[16] | index u16 | count u16 | body
/// ```
///
/// `body` is up to [Protocol.mediaChunkBytes] bytes of media: sealed
/// (`nonce | ciphertext | tag`) for private and group chats, plain for public
/// rooms.
class MediaChunk {
  const MediaChunk({
    required this.mediaId,
    required this.index,
    required this.count,
    required this.body,
  });

  static const int headerLength = Protocol.messageIdLength + 2 + 2;

  final Uint8List mediaId;
  final int index;
  final int count;
  final Uint8List body;

  String get mediaIdHex => bytesToHex(mediaId);

  /// The bytes that bind a sealed body to its place in the object.
  Uint8List get aadSuffix {
    final w = ByteWriter()
      ..bytes(mediaId)
      ..u16(index)
      ..u16(count);
    return w.toBytes();
  }

  Uint8List encode() => concatBytes([aadSuffix, body]);

  static MediaChunk parse(Uint8List payload) {
    try {
      final r = ByteReader(payload);
      final mediaId = r.bytes(Protocol.messageIdLength);
      final index = r.u16();
      final count = r.u16();
      if (count == 0 || count > Protocol.maxMediaChunks || index >= count) {
        throw const ChunkFormatException('Chunk position out of range');
      }
      final body = r.rest();
      if (body.isEmpty || body.length > maxBodyBytes) {
        throw const ChunkFormatException('Chunk body size out of range');
      }
      return MediaChunk(mediaId: mediaId, index: index, count: count, body: body);
    } on ChunkFormatException {
      rethrow;
    } on FormatException catch (e) {
      throw ChunkFormatException(e.message);
    }
  }

  /// Largest body a chunk may carry: the media bytes plus a sealing nonce and
  /// tag.
  static const int maxBodyBytes = Protocol.mediaChunkBytes + 12 + 16;
}
