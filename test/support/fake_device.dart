import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:offline_mesh_chat/device/device_io.dart';

/// A permission service whose answers the test decides. Records what was asked.
class FakePermissionService implements PermissionService {
  FakePermissionService({
    Map<AppPermission, PermissionOutcome>? initial,
    this.answerWhenAsked = PermissionOutcome.granted,
  }) : _state = {
          for (final p in AppPermission.values) p: PermissionOutcome.denied,
          ...?initial,
        };

  final Map<AppPermission, PermissionOutcome> _state;

  /// What the system prompt returns when the person is asked.
  PermissionOutcome answerWhenAsked;

  final List<AppPermission> requested = <AppPermission>[];
  int settingsOpened = 0;

  void set(AppPermission p, PermissionOutcome outcome) => _state[p] = outcome;

  @override
  Future<PermissionOutcome> status(AppPermission permission) async => _state[permission]!;

  @override
  Future<PermissionOutcome> request(AppPermission permission) async {
    requested.add(permission);
    if (_state[permission] == PermissionOutcome.permanentlyDenied) {
      return PermissionOutcome.permanentlyDenied;
    }
    _state[permission] = answerWhenAsked;
    return answerWhenAsked;
  }

  @override
  Future<bool> openSettings() async {
    settingsOpened++;
    return true;
  }
}

class FakePhotoPicker implements PhotoPicker {
  /// What the next pick returns (null: the person backed out).
  Uint8List? next;
  final List<PhotoSource> picked = <PhotoSource>[];

  /// What the next video pick returns (null: the person backed out).
  PickedVideo? nextVideo;
  final List<PhotoSource> pickedVideos = <PhotoSource>[];
  int? lastVideoLimit;

  @override
  Future<Uint8List?> pick(PhotoSource source) async {
    picked.add(source);
    return next;
  }

  @override
  Future<PickedVideo?> pickVideo(PhotoSource source, {required int maxBytes}) async {
    pickedVideos.add(source);
    lastVideoLimit = maxBytes;
    final v = nextVideo;
    if (v == null) return null;
    // Like the real picker: nothing is read from something over the limit.
    return v.length > maxBytes ? PickedVideo(length: v.length) : v;
  }
}

/// Remembers what was handed to the "share sheet".
class FakeSharer implements Sharer {
  final List<String> texts = <String>[];
  final List<List<SharedFile>> files = <List<SharedFile>>[];
  final List<String?> fileTexts = <String?>[];

  @override
  Future<void> shareText(String text) async => texts.add(text);

  @override
  Future<void> shareFiles(List<SharedFile> shared, {String? text}) async {
    files.add(shared);
    fileTexts.add(text);
  }
}

/// Remembers what was saved to the "gallery".
class FakeGallery implements GallerySaver {
  final List<Uint8List> images = <Uint8List>[];
  final List<String> videos = <String>[];

  /// Set to make the next save fail the way the plugin would.
  GalleryException? failWith;

  @override
  Future<void> saveImage(Uint8List bytes) async {
    if (failWith != null) throw failWith!;
    images.add(bytes);
  }

  @override
  Future<void> saveVideo(String path) async {
    if (failWith != null) throw failWith!;
    videos.add(path);
  }
}

class FakeVoiceRecorder implements VoiceRecorder {
  bool _recording = false;
  final StreamController<double> _levels = StreamController<double>.broadcast();
  final StreamController<void> _limit = StreamController<void>.broadcast();
  Duration _elapsed = Duration.zero;

  /// What [stop] hands back.
  RecordedVoice? result = RecordedVoice(
    bytes: Uint8List.fromList(List<int>.generate(3000, (i) => i & 0xff)),
    duration: const Duration(seconds: 6),
    waveform: List<int>.generate(30, (i) => (i * 8) & 0xff),
  );
  Object? startError;
  int starts = 0;
  int cancels = 0;

  @override
  bool get isRecording => _recording;

  @override
  Stream<double> get levels => _levels.stream;

  @override
  Stream<void> get limitReached => _limit.stream;

  @override
  Duration get elapsed => _elapsed;

  /// Moves the clock and the level meter, as a real recording would.
  void tick(Duration by, {double level = 0.5}) {
    _elapsed += by;
    _levels.add(level);
  }

  void hitLimit() => _limit.add(null);

  @override
  Future<void> start() async {
    if (startError != null) throw startError!;
    starts++;
    _recording = true;
    _elapsed = Duration.zero;
  }

  @override
  Future<RecordedVoice?> stop() async {
    if (!_recording) return null;
    _recording = false;
    return result;
  }

  @override
  Future<void> cancel() async {
    if (_recording) cancels++;
    _recording = false;
  }

  @override
  Future<void> dispose() async {
    await _levels.close();
    await _limit.close();
  }
}

class FakeVoicePlayer implements VoicePlayer {
  final ValueNotifier<PlaybackState> _state = ValueNotifier<PlaybackState>(PlaybackState.idle);
  final List<String> played = <String>[];

  @override
  ValueListenable<PlaybackState> get state => _state;

  @override
  Future<void> toggle(String id, String filePath) async {
    final s = _state.value;
    if (s.playingId == id) {
      _state.value = PlaybackState(
          playingId: id,
          playing: !s.playing,
          position: s.position,
          duration: s.duration,
          speed: s.speed);
      return;
    }
    played.add(filePath);
    _state.value = PlaybackState(
        playingId: id, playing: true, duration: const Duration(seconds: 8), speed: s.speed);
  }

  @override
  Future<void> pause() async {
    final s = _state.value;
    _state.value = PlaybackState(
        playingId: s.playingId,
        playing: false,
        position: s.position,
        duration: s.duration,
        speed: s.speed);
  }

  @override
  Future<void> seek(Duration position) async {
    final s = _state.value;
    _state.value = PlaybackState(
        playingId: s.playingId,
        playing: s.playing,
        position: position,
        duration: s.duration,
        speed: s.speed);
  }

  @override
  Future<void> cycleSpeed() async {
    final s = _state.value;
    final next = s.speed == 1.0 ? 1.5 : (s.speed == 1.5 ? 2.0 : 1.0);
    _state.value = PlaybackState(
        playingId: s.playingId,
        playing: s.playing,
        position: s.position,
        duration: s.duration,
        speed: next);
  }

  @override
  Future<void> stop() async => _state.value = PlaybackState(speed: _state.value.speed);

  @override
  Future<void> dispose() async => _state.dispose();
}

/// Records the notifications the app would show.
class FakeNotificationSink implements NotificationSink {
  final List<MessageNotification> shown = <MessageNotification>[];
  final List<String> cancelled = <String>[];
  int cancelledAll = 0;
  bool initialized = false;

  /// The conversation whose notification "started" the app.
  String? launch;

  void Function(String conversationId)? _onTap;

  /// The person taps the notification of [conversationId].
  void tap(String conversationId) => _onTap?.call(conversationId);

  @override
  Future<void> initialize({required void Function(String conversationId) onTap}) async {
    initialized = true;
    _onTap = onTap;
  }

  @override
  Future<void> show(MessageNotification notification) async => shown.add(notification);

  @override
  Future<void> cancelConversation(String conversationId) async => cancelled.add(conversationId);

  @override
  Future<void> cancelAll() async => cancelledAll++;

  @override
  Future<String?> launchConversation() async => launch;
}

/// A background service that only remembers whether it was asked to run.
class FakeKeepAlive implements KeepAlive {
  FakeKeepAlive({this.supported = true, this.allow = true});

  @override
  final bool supported;

  /// What the system answers when asked to start (it can refuse).
  bool allow;

  bool running = false;
  int starts = 0;
  int stops = 0;

  /// The words the last start came with.
  KeepAliveTexts? lastTexts;

  @override
  Future<bool> start({KeepAliveTexts? texts}) async {
    starts++;
    lastTexts = texts;
    running = supported && allow;
    return running;
  }

  @override
  Future<void> stop() async {
    stops++;
    running = false;
  }

  @override
  Future<bool> isRunning() async => running;

  /// What the phone says about its battery optimisation (null: it cannot tell).
  bool? batteryRestrictedAnswer = true;

  /// Whether this "phone" has a battery settings page to open.
  bool canOpenBatterySettings = true;
  int batterySettingsOpened = 0;

  @override
  Future<bool?> batteryRestricted() async => supported ? batteryRestrictedAnswer : null;

  @override
  Future<bool> openBatterySettings() async {
    if (!supported || !canOpenBatterySettings) return false;
    batterySettingsOpened++;
    return true;
  }
}

/// A complete fake phone: nothing touches a real plugin.
DeviceIo fakeDeviceIo({
  FakePermissionService? permissions,
  FakePhotoPicker? photos,
  FakeVoiceRecorder? recorder,
  FakeVoicePlayer? player,
  FakeNotificationSink? notifications,
  FakeKeepAlive? keepAlive,
  FakeGallery? gallery,
  FakeSharer? sharer,
  ImageCompressor compressor = const ImageCompressor(),
}) =>
    DeviceIo(
      permissions: permissions ?? FakePermissionService(),
      photos: photos ?? FakePhotoPicker(),
      compressor: compressor,
      recorder: () => recorder ?? FakeVoiceRecorder(),
      player: () => player ?? FakeVoicePlayer(),
      notifications: notifications ?? FakeNotificationSink(),
      keepAlive: keepAlive ?? FakeKeepAlive(),
      gallery: gallery ?? FakeGallery(),
      sharer: sharer ?? FakeSharer(),
    );
