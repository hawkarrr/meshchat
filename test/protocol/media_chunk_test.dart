import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:offline_mesh_chat/protocol/media_chunk.dart';
import 'package:offline_mesh_chat/protocol/protocol_constants.dart';

Uint8List _id() => Uint8List.fromList(List<int>.generate(16, (i) => i + 1));

void main() {
  group('MediaChunk', () {
    test('encodes and parses', () {
      final chunk = MediaChunk(
        mediaId: _id(),
        index: 2,
        count: 5,
        body: Uint8List.fromList(List<int>.generate(100, (i) => i)),
      );
      final parsed = MediaChunk.parse(chunk.encode());
      expect(parsed.mediaId, chunk.mediaId);
      expect(parsed.index, 2);
      expect(parsed.count, 5);
      expect(parsed.body, chunk.body);
    });

    test('the header is 20 bytes and aadSuffix is exactly that header', () {
      final chunk = MediaChunk(mediaId: _id(), index: 0, count: 1, body: Uint8List(1));
      expect(MediaChunk.headerLength, 20);
      expect(chunk.aadSuffix.length, 20);
      expect(chunk.encode().sublist(0, 20), chunk.aadSuffix);
    });

    test('a full-size sealed chunk fits in a packet with room to spare', () {
      final chunk = MediaChunk(
        mediaId: _id(),
        index: 0,
        count: 1,
        body: Uint8List(MediaChunk.maxBodyBytes),
      );
      // header + (u32 epoch for groups) + payload must stay under the packet payload limit.
      expect(4 + chunk.encode().length, lessThanOrEqualTo(Protocol.maxPayloadBytes));
      expect(MediaChunk.parse(chunk.encode()).body.length, MediaChunk.maxBodyBytes);
    });

    test('rejects a position outside the object', () {
      for (final (index, count) in [(5, 5), (0, 0), (9, 3), (0, Protocol.maxMediaChunks + 1)]) {
        final bytes = MediaChunk(mediaId: _id(), index: index, count: count, body: Uint8List(4)).encode();
        expect(() => MediaChunk.parse(bytes), throwsA(isA<ChunkFormatException>()),
            reason: 'index $index of $count');
      }
    });

    test('rejects empty, oversize and truncated bodies', () {
      final empty = MediaChunk(mediaId: _id(), index: 0, count: 1, body: Uint8List(0)).encode();
      expect(() => MediaChunk.parse(empty), throwsA(isA<ChunkFormatException>()));
      final huge = MediaChunk(
        mediaId: _id(),
        index: 0,
        count: 1,
        body: Uint8List(MediaChunk.maxBodyBytes + 1),
      ).encode();
      expect(() => MediaChunk.parse(huge), throwsA(isA<ChunkFormatException>()));
      expect(() => MediaChunk.parse(Uint8List(7)), throwsA(isA<ChunkFormatException>()));
    });
  });
}
