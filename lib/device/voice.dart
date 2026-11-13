import '../core/app_info.dart';
import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../protocol/protocol_constants.dart';
import '../l10n/l10n.dart';

/// A finished voice recording, ready to send.
class RecordedVoice {
  const RecordedVoice({required this.bytes, required this.duration, required this.waveform});

  /// AAC-LC audio in an .m4a container.
  final Uint8List bytes;
  final Duration duration;

  /// Amplitude samples (0..255) for drawing the waveform.
  final List<int> waveform;
}

enum VoiceProblem { micOff }

class VoiceException implements Exception {
  const VoiceException(this.message, {this.problem});

  /// The words in English, for logs.
  final String message;
  final VoiceProblem? problem;

  /// What to tell the person, in the language of [l].
  String text(AppLocalizations l) => switch (problem) {
        VoiceProblem.micOff => l.voiceMicOff,
        null => message,
      };

  @override
  String toString() => message;
}

/// Records a voice message. The permission has already been granted by the
/// time [start] is called (see the permission prompt in the UI).
abstract interface class VoiceRecorder {
  bool get isRecording;

  /// Live loudness while recording, 0..1, about ten times a second.
  Stream<double> get levels;

  /// Time recorded so far.
  Duration get elapsed;

  Future<void> start();

  /// Ends the recording and returns it, or null if it was too short to be a
  /// message. Recording also ends by itself at [Protocol.maxVoiceDuration]; the
  /// caller then gets the result from [stop] as usual.
  Future<RecordedVoice?> stop();

  /// Throws the recording away.
  Future<void> cancel();

  /// Fires when the time limit (or, on a phone whose encoder writes more than
  /// planned, the size limit) ends the recording on its own.
  Stream<void> get limitReached;

  Future<void> dispose();
}

/// Turns a series of loudness samples (0..1) into at most
/// [Protocol.maxWaveformSamples] bars of 0..255.
List<int> waveformFromLevels(List<double> levels) {
  if (levels.isEmpty) return const <int>[];
  final bars = min(levels.length, Protocol.maxWaveformSamples);
  final out = <int>[];
  for (var i = 0; i < bars; i++) {
    final from = (i * levels.length / bars).floor();
    final to = max(from + 1, ((i + 1) * levels.length / bars).floor());
    var peak = 0.0;
    for (var j = from; j < to && j < levels.length; j++) {
      peak = max(peak, levels[j]);
    }
    out.add((peak.clamp(0.0, 1.0) * 255).round());
  }
  return out;
}

/// Maps the recorder's dBFS reading (about -45 quiet .. 0 loud) to 0..1.
double levelFromDecibels(double db) => ((db + 45) / 45).clamp(0.0, 1.0);

/// Ends a recording before its file outgrows what one voice message may carry.
///
/// The recorder aims at 16 kbit/s, so thirty seconds are about 60 KB: close to
/// the 64 KB limit, with the file's index still to be written when the recording
/// stops. A phone whose encoder runs a little over its bitrate would make a file
/// that cannot be sent, and the person would only learn that after recording.
/// This watches the growing file and ends the recording early instead, the same
/// way the time limit does ([onLimit] fires once).
class VoiceSizeGuard {
  VoiceSizeGuard({
    required this.currentBytes,
    required this.onLimit,
    this.maxBytes = Protocol.maxMediaBytes - reserveBytes,
    this.every = const Duration(milliseconds: 250),
  });

  /// Room kept for what the encoder writes when the recording stops (the index
  /// of an .m4a file, about 3 KB for thirty seconds) and for data it has not
  /// written out yet. Small enough that thirty seconds at the planned bitrate
  /// (60,000 bytes) never reach the limit: a normal phone stops at the time
  /// limit, as before.
  static const int reserveBytes = 4 * 1024;

  /// The size of the file being recorded, in bytes.
  final Future<int> Function() currentBytes;
  final void Function() onLimit;
  final int maxBytes;
  final Duration every;

  Timer? _timer;
  bool _checking = false;
  bool _fired = false;

  bool get fired => _fired;

  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(every, (_) => unawaited(_check()));
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _check() async {
    if (_fired || _checking) return;
    _checking = true;
    try {
      final size = await currentBytes();
      if (size >= maxBytes && !_fired && _timer != null) {
        _fired = true;
        stop();
        onLimit();
      }
    } catch (_) {
      // The file may not be there yet; the next check sees it.
    } finally {
      _checking = false;
    }
  }
}

class PluginVoiceRecorder implements VoiceRecorder {
  PluginVoiceRecorder({
    this.minDuration = const Duration(milliseconds: 600),
    AudioRecorder? recorder,
  }) : _recorder = recorder ?? AudioRecorder();

  /// Shorter recordings are treated as an accidental tap and discarded.
  final Duration minDuration;
  final AudioRecorder _recorder;

  final StreamController<double> _levels = StreamController<double>.broadcast();
  final StreamController<void> _limit = StreamController<void>.broadcast();
  final List<double> _samples = <double>[];
  final Stopwatch _watch = Stopwatch();
  StreamSubscription<Amplitude>? _amplitudeSub;
  Timer? _limitTimer;
  VoiceSizeGuard? _sizeGuard;
  String? _path;
  bool _recording = false;

  @override
  bool get isRecording => _recording;

  @override
  Stream<double> get levels => _levels.stream;

  @override
  Stream<void> get limitReached => _limit.stream;

  @override
  Duration get elapsed => _watch.elapsed;

  @override
  Future<void> start() async {
    if (_recording) return;
    if (!await _recorder.hasPermission()) {
      throw const VoiceException('The microphone is switched off for ${AppInfo.name}.',
          problem: VoiceProblem.micOff);
    }
    final dir = await getTemporaryDirectory();
    final path = p.join(dir.path, 'voice_${DateTime.now().microsecondsSinceEpoch}.m4a');
    // Speech at 16 kHz mono and 16 kbit/s: about 2 KB per second, so thirty
    // seconds fit in a Bluetooth mesh message.
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        sampleRate: 16000,
        numChannels: 1,
        bitRate: 16000,
        noiseSuppress: true,
        echoCancel: true,
      ),
      path: path,
    );
    _path = path;
    _samples.clear();
    _watch
      ..reset()
      ..start();
    _recording = true;
    _amplitudeSub = _recorder.onAmplitudeChanged(const Duration(milliseconds: 100)).listen((a) {
      final level = levelFromDecibels(a.current);
      _samples.add(level);
      if (!_levels.isClosed) _levels.add(level);
    });
    _limitTimer = Timer(Protocol.maxVoiceDuration, () {
      if (_recording && !_limit.isClosed) _limit.add(null);
    });
    // The time limit assumes the encoder keeps to its bitrate; this ends the
    // recording early if the file grows faster.
    _sizeGuard = VoiceSizeGuard(
      currentBytes: () => File(path).length(),
      onLimit: () {
        if (_recording && !_limit.isClosed) _limit.add(null);
      },
    )..start();
  }

  Future<String?> _finish() async {
    _limitTimer?.cancel();
    _sizeGuard?.stop();
    _sizeGuard = null;
    await _amplitudeSub?.cancel();
    _amplitudeSub = null;
    _watch.stop();
    _recording = false;
    return _recorder.stop();
  }

  @override
  Future<RecordedVoice?> stop() async {
    if (!_recording) return null;
    final duration = _watch.elapsed;
    final path = await _finish() ?? _path;
    _path = null;
    if (path == null) return null;
    final file = File(path);
    try {
      if (duration < minDuration || !await file.exists()) return null;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return null;
      return RecordedVoice(
        bytes: bytes,
        duration: duration,
        waveform: waveformFromLevels(List<double>.of(_samples)),
      );
    } finally {
      if (await file.exists()) await file.delete();
    }
  }

  @override
  Future<void> cancel() async {
    if (!_recording) return;
    await _finish();
    final path = _path;
    _path = null;
    if (path != null) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
  }

  @override
  Future<void> dispose() async {
    await cancel();
    await _levels.close();
    await _limit.close();
    await _recorder.dispose();
  }
}

/// What the voice player is doing right now.
@immutable
class PlaybackState {
  const PlaybackState({
    this.playingId,
    this.playing = false,
    this.position = Duration.zero,
    this.duration,
    this.speed = 1.0,
  });

  static const PlaybackState idle = PlaybackState();

  /// The id of the message being played (or paused), or null.
  final String? playingId;
  final bool playing;
  final Duration position;
  final Duration? duration;
  final double speed;

  bool isPlaying(String id) => playing && playingId == id;

  bool isCurrent(String id) => playingId == id;

  @override
  bool operator ==(Object other) =>
      other is PlaybackState &&
      other.playingId == playingId &&
      other.playing == playing &&
      other.position == position &&
      other.duration == duration &&
      other.speed == speed;

  @override
  int get hashCode => Object.hash(playingId, playing, position, duration, speed);
}

/// Plays voice messages, one at a time.
abstract interface class VoicePlayer {
  ValueListenable<PlaybackState> get state;

  /// Starts playing [filePath] as message [id]; pressing it again on the same
  /// message resumes after a pause.
  Future<void> toggle(String id, String filePath);

  Future<void> pause();

  Future<void> seek(Duration position);

  /// Steps through 1x, 1.5x and 2x.
  Future<void> cycleSpeed();

  Future<void> stop();

  Future<void> dispose();
}

class PluginVoicePlayer implements VoicePlayer {
  PluginVoicePlayer({AudioPlayer? player}) : _player = player ?? AudioPlayer() {
    _subs.addAll([
      _player.onPositionChanged.listen((d) => _update(position: d)),
      _player.onDurationChanged.listen((d) => _update(duration: d)),
      _player.onPlayerComplete.listen((_) {
        _state.value = PlaybackState(
          playingId: _state.value.playingId,
          duration: _state.value.duration,
          speed: _state.value.speed,
        );
      }),
    ]);
  }

  final AudioPlayer _player;
  final List<StreamSubscription<Object?>> _subs = <StreamSubscription<Object?>>[];
  final ValueNotifier<PlaybackState> _state = ValueNotifier<PlaybackState>(PlaybackState.idle);
  static const List<double> _speeds = <double>[1.0, 1.5, 2.0];

  @override
  ValueListenable<PlaybackState> get state => _state;

  void _update({Duration? position, Duration? duration, bool? playing}) {
    final s = _state.value;
    if (s.playingId == null) return;
    _state.value = PlaybackState(
      playingId: s.playingId,
      playing: playing ?? s.playing,
      position: position ?? s.position,
      duration: duration ?? s.duration,
      speed: s.speed,
    );
  }

  @override
  Future<void> toggle(String id, String filePath) async {
    final s = _state.value;
    if (s.playingId == id) {
      if (s.playing) {
        await pause();
      } else {
        await _player.resume();
        _update(playing: true);
      }
      return;
    }
    await _player.stop();
    _state.value = PlaybackState(playingId: id, playing: true, speed: s.speed);
    await _player.setPlaybackRate(s.speed);
    await _player.play(DeviceFileSource(filePath));
  }

  @override
  Future<void> pause() async {
    await _player.pause();
    _update(playing: false);
  }

  @override
  Future<void> seek(Duration position) async {
    await _player.seek(position);
    _update(position: position);
  }

  @override
  Future<void> cycleSpeed() async {
    final s = _state.value;
    final next = _speeds[(_speeds.indexOf(s.speed) + 1) % _speeds.length];
    await _player.setPlaybackRate(next);
    _state.value = PlaybackState(
      playingId: s.playingId,
      playing: s.playing,
      position: s.position,
      duration: s.duration,
      speed: next,
    );
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    _state.value = PlaybackState(speed: _state.value.speed);
  }

  @override
  Future<void> dispose() async {
    for (final s in _subs) {
      await s.cancel();
    }
    await _player.dispose();
    _state.dispose();
  }
}
