import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:offline_mesh_chat/protocol/fragmenter.dart';
import 'package:offline_mesh_chat/protocol/protocol_constants.dart';

import '../support/fake_clock.dart';

Uint8List _frame(int n, [int seed = 1]) {
  final rng = Random(seed);
  return Uint8List.fromList(List.generate(n, (_) => rng.nextInt(256)));
}

Uint8List? _feedAll(FrameReassembler r, Iterable<Uint8List> chunks) {
  Uint8List? out;
  for (final c in chunks) {
    out = r.add(c) ?? out;
  }
  return out;
}

void main() {
  group('FrameChunker', () {
    test('respects the maximum chunk size and numbers chunks consecutively', () {
      final chunks = FrameChunker.split(_frame(1000), frameId: 7, maxChunk: 20);
      expect(chunks.every((c) => c.length <= 20), isTrue);
      expect(chunks.length, (1000 / 14).ceil());
      for (var i = 0; i < chunks.length; i++) {
        expect((chunks[i][2] << 8) | chunks[i][3], i);
        expect((chunks[i][4] << 8) | chunks[i][5], chunks.length);
      }
    });

    test('an empty frame becomes exactly one chunk', () {
      final chunks = FrameChunker.split(Uint8List(0), frameId: 1, maxChunk: 20);
      expect(chunks.length, 1);
      expect(chunks.single.length, FrameChunker.headerLength);
    });

    test('rejects a chunk size too small to carry data', () {
      expect(() => FrameChunker.split(_frame(10), frameId: 1, maxChunk: 6),
          throwsArgumentError);
    });
  });

  group('round trip', () {
    for (final maxChunk in [20, 23, 100, 185, 247, 512]) {
      for (final size in [0, 1, 14, 15, 100, 1000, Protocol.maxFrameBytes]) {
        test('frame of $size bytes in $maxChunk-byte chunks', () {
          final frame = _frame(size, size + maxChunk);
          final chunks = FrameChunker.split(frame, frameId: 3, maxChunk: maxChunk);
          final r = FrameReassembler();
          expect(_feedAll(r, chunks), frame);
          expect(r.hasPartial, isFalse);
        });
      }
    }

    test('frame ids may wrap around', () {
      final r = FrameReassembler();
      for (final id in [0xfffe, 0xffff, 0x10000, 0x10001]) {
        final frame = _frame(50, id);
        expect(_feedAll(r, FrameChunker.split(frame, frameId: id, maxChunk: 20)), frame);
      }
    });
  });

  group('tolerates network misbehaviour', () {
    test('out-of-order chunks within one frame', () {
      final frame = _frame(300);
      final chunks = FrameChunker.split(frame, frameId: 9, maxChunk: 40).reversed.toList();
      expect(_feedAll(FrameReassembler(), chunks), frame);
    });

    test('duplicate chunks are ignored and counted', () {
      final frame = _frame(300);
      final chunks = FrameChunker.split(frame, frameId: 9, maxChunk: 40);
      final r = FrameReassembler();
      r.add(chunks[0]);
      r.add(chunks[0]);
      r.add(chunks[1]);
      r.add(chunks[1]);
      expect(_feedAll(r, chunks.skip(2)), frame);
      expect(r.duplicateChunks, 2);
    });

    test('a retransmitted, already-delivered frame is not delivered twice', () {
      final frame = _frame(100);
      final chunks = FrameChunker.split(frame, frameId: 5, maxChunk: 40);
      final r = FrameReassembler();
      expect(_feedAll(r, chunks), frame);
      expect(_feedAll(r, chunks), isNull);
      expect(r.completedFrames, 1);
      // A later frame with a different id still works.
      final next = _frame(100, 2);
      expect(_feedAll(r, FrameChunker.split(next, frameId: 6, maxChunk: 40)), next);
    });

    test('a lost chunk: the next frame is delivered, the broken one dropped', () {
      final broken = FrameChunker.split(_frame(200), frameId: 1, maxChunk: 40);
      final next = _frame(30, 5);
      final r = FrameReassembler();
      for (var i = 0; i < broken.length; i++) {
        if (i == 2) continue; // lost
        expect(r.add(broken[i]), isNull);
      }
      final out = _feedAll(r, FrameChunker.split(next, frameId: 2, maxChunk: 40));
      expect(out, next);
      expect(r.droppedPartialFrames, 1);
    });

    test('a partial frame is discarded after the timeout', () {
      final clock = FakeClock();
      final r = FrameReassembler(partialTimeoutMs: 1000, clock: clock);
      final chunks = FrameChunker.split(_frame(200), frameId: 1, maxChunk: 40);
      r.add(chunks[0]);
      clock.advance(const Duration(seconds: 2));
      // Same frame id, but the first part expired: it restarts, so it can't complete.
      for (final c in chunks.skip(1)) {
        expect(r.add(c), isNull);
      }
      expect(r.droppedPartialFrames, greaterThanOrEqualTo(1));
    });
  });

  group('rejects hostile input', () {
    test('a chunk shorter than its header', () {
      expect(() => FrameReassembler().add(Uint8List(5)), throwsFormatException);
    });

    test('index out of range and zero count', () {
      expect(() => FrameReassembler().add(Uint8List.fromList([0, 1, 0, 5, 0, 5, 9])),
          throwsFormatException);
      expect(() => FrameReassembler().add(Uint8List.fromList([0, 1, 0, 0, 0, 0, 9])),
          throwsFormatException);
    });

    test('a count that changes mid-frame', () {
      final r = FrameReassembler();
      r.add(Uint8List.fromList([0, 1, 0, 0, 0, 3, 9]));
      expect(() => r.add(Uint8List.fromList([0, 1, 0, 1, 0, 4, 9])), throwsFormatException);
    });

    test('a frame that grows beyond the maximum', () {
      final r = FrameReassembler(maxFrameBytes: 50);
      final chunks = FrameChunker.split(_frame(500), frameId: 1, maxChunk: 20);
      expect(() => _feedAll(r, chunks), throwsFormatException);
    });

    test('an absurd chunk count', () {
      expect(() => FrameReassembler(maxFrameBytes: 100).add(
              Uint8List.fromList([0, 1, 0, 0, 0xff, 0xff, 9])),
          throwsFormatException);
    });

    test('random garbage only throws FormatException', () {
      final rng = Random(3);
      final r = FrameReassembler();
      for (var i = 0; i < 3000; i++) {
        final bytes = Uint8List.fromList(List.generate(rng.nextInt(60), (_) => rng.nextInt(256)));
        try {
          r.add(bytes);
        } on FormatException {
          // expected
        }
      }
    });
  });
}
