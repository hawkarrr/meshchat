import 'dart:typed_data';

import '../protocol/envelope.dart' show MediaKind;
import 'message.dart';

export '../protocol/envelope.dart' show MediaKind;

extension MediaKindMessage on MediaKind {
  /// The kind of chat message that carries this kind of media.
  MessageKind get messageKind => switch (this) {
        MediaKind.image => MessageKind.image,
        MediaKind.voice => MessageKind.voice,
        MediaKind.video => MessageKind.video,
      };
}

enum MediaState {
  /// Ours, being handed to the network.
  sending,

  /// Someone else's, still arriving.
  receiving,

  /// Complete, verified and stored; can be shown or played.
  ready,

  /// Could not be completed (expired, damaged, or too big).
  failed;

  static MediaState parse(String name) => MediaState.values.firstWhere(
        (s) => s.name == name,
        orElse: () => MediaState.failed,
      );
}

/// An image or voice message's media, as stored on this phone.
class MediaItem {
  const MediaItem({
    required this.id,
    required this.messageId,
    required this.kind,
    required this.mimeCode,
    required this.byteLength,
    required this.chunkCount,
    required this.sha256,
    this.width = 0,
    this.height = 0,
    this.durationMs = 0,
    this.waveform = const <int>[],
    required this.state,
    this.receivedChunks = 0,
    this.fileName,
    this.error,
    required this.createdAtMs,
    required this.expiresAtMs,
  });

  /// Hex media id.
  final String id;

  /// The message this media belongs to.
  final String messageId;
  final MediaKind kind;
  final int mimeCode;
  final int byteLength;
  final int chunkCount;
  final Uint8List sha256;
  final int width;
  final int height;
  final int durationMs;

  /// Amplitude samples (0..255) for drawing a voice waveform.
  final List<int> waveform;
  final MediaState state;

  /// How many chunks have arrived (receiving), or were sent (sending).
  final int receivedChunks;

  /// File inside the app's private media folder, once the bytes are stored.
  final String? fileName;
  final String? error;
  final int createdAtMs;

  /// Deadline for a partly received object; after it the media is abandoned.
  final int expiresAtMs;

  bool get isReady => state == MediaState.ready;

  bool get isImage => kind == MediaKind.image;

  bool get isVoice => kind == MediaKind.voice;

  bool get isVideo => kind == MediaKind.video;

  /// 0..1 while receiving.
  double get progress {
    if (state == MediaState.ready) return 1;
    if (chunkCount <= 0) return 0;
    return (receivedChunks / chunkCount).clamp(0.0, 1.0);
  }

  Duration get duration => Duration(milliseconds: durationMs);
}
