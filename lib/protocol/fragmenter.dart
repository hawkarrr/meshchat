import 'dart:typed_data';

import '../core/bytes.dart';
import '../core/clock.dart';
import 'protocol_constants.dart';

/// Splits link frames into BLE-sized chunks and reassembles them.
///
/// BLE characteristic writes and notifications are limited to (ATT MTU - 3)
/// bytes, which is only 20 bytes until an MTU exchange succeeds. Every chunk
/// therefore carries a 6-byte header:
///
/// ```
/// u16 frameId   identifies the frame (wraps around)
/// u16 index     0-based position of this chunk
/// u16 count     total number of chunks in the frame
/// ```
///
/// Carrying `index`/`count` in every chunk (rather than start/end flags)
/// lets the reassembler tolerate duplicated chunks, which can occur when a
/// write times out on the sender but was in fact delivered.
class FrameChunker {
  const FrameChunker._();

  static const int headerLength = 6;

  /// Smallest usable chunk size: header plus one payload byte.
  static const int minChunkSize = headerLength + 1;

  static List<Uint8List> split(
    Uint8List frame, {
    required int frameId,
    required int maxChunk,
  }) {
    if (maxChunk < minChunkSize) {
      throw ArgumentError.value(maxChunk, 'maxChunk', 'too small');
    }
    final payloadPer = maxChunk - headerLength;
    final count = frame.isEmpty ? 1 : (frame.length + payloadPer - 1) ~/ payloadPer;
    if (count > 0xffff) {
      throw ArgumentError('Frame needs more than 65535 chunks');
    }
    final chunks = <Uint8List>[];
    for (var i = 0; i < count; i++) {
      final start = i * payloadPer;
      final end = start + payloadPer > frame.length ? frame.length : start + payloadPer;
      final w = ByteWriter()
        ..u16(frameId & 0xffff)
        ..u16(i)
        ..u16(count)
        ..bytes(Uint8List.sublistView(frame, start, end));
      chunks.add(w.toBytes());
    }
    return chunks;
  }
}

class _Partial {
  _Partial(this.frameId, this.count, this.startedAtMs)
      : parts = List<Uint8List?>.filled(count, null);

  final int frameId;
  final int count;
  final int startedAtMs;
  final List<Uint8List?> parts;
  int received = 0;
  int bytes = 0;
}

/// Reassembles chunks produced by [FrameChunker.split].
///
/// Memory is bounded: at most one partially received frame is kept, it can
/// never exceed [maxFrameBytes], and it is discarded after [partialTimeoutMs].
class FrameReassembler {
  FrameReassembler({
    this.maxFrameBytes = Protocol.maxFrameBytes,
    this.partialTimeoutMs = 15000,
    this._clock = const SystemClock(),
  });

  final int maxFrameBytes;
  final int partialTimeoutMs;
  final Clock _clock;

  _Partial? _current;
  int? _lastCompletedId;

  int completedFrames = 0;
  int droppedPartialFrames = 0;
  int duplicateChunks = 0;

  /// Whether a frame is currently half-received (for diagnostics).
  bool get hasPartial => _current != null;

  /// Feeds one chunk. Returns the complete frame when this chunk finishes
  /// it, otherwise null. Throws [FormatException] for a malformed chunk (the
  /// caller should treat repeated violations as a misbehaving peer).
  Uint8List? add(Uint8List chunk) {
    if (chunk.length < FrameChunker.headerLength) {
      throw const FormatException('Chunk shorter than header');
    }
    final r = ByteReader(chunk);
    final frameId = r.u16();
    final index = r.u16();
    final count = r.u16();
    final body = r.rest();

    if (count == 0 || index >= count) {
      throw const FormatException('Chunk index out of range');
    }
    if (count > maxFrameBytes) {
      throw const FormatException('Chunk count implausibly large');
    }

    final now = _clock.nowMs;
    final current = _current;
    if (current != null &&
        (current.frameId != frameId ||
            now - current.startedAtMs > partialTimeoutMs)) {
      droppedPartialFrames++;
      _current = null;
    }

    if (_current == null && _lastCompletedId == frameId) {
      // Retransmission of a frame we already delivered.
      duplicateChunks++;
      return null;
    }

    final partial = _current ??= _Partial(frameId, count, now);
    if (partial.count != count) {
      _current = null;
      droppedPartialFrames++;
      throw const FormatException('Chunk count changed mid-frame');
    }
    if (partial.parts[index] != null) {
      duplicateChunks++;
      return null;
    }
    if (partial.bytes + body.length > maxFrameBytes) {
      _current = null;
      droppedPartialFrames++;
      throw const FormatException('Frame exceeds maximum size');
    }

    partial.parts[index] = body;
    partial.received++;
    partial.bytes += body.length;

    if (partial.received < partial.count) return null;

    final out = Uint8List(partial.bytes);
    var offset = 0;
    for (final p in partial.parts) {
      out.setRange(offset, offset + p!.length, p);
      offset += p.length;
    }
    _current = null;
    _lastCompletedId = frameId;
    completedFrames++;
    return out;
  }

  /// Forget any partially received frame (e.g. when the link is closed).
  void reset() {
    _current = null;
    _lastCompletedId = null;
  }
}
