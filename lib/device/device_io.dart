import 'gallery.dart';
import 'image_tools.dart';
import 'keep_alive.dart';
import 'notifications.dart';
import 'permission_service.dart';
import 'share.dart';
import 'voice.dart';

export 'gallery.dart';
export 'image_tools.dart';
export 'keep_alive.dart';
export 'notifications.dart';
export 'permission_service.dart';
export 'share.dart';
export 'voice.dart';

/// Everything the app uses from the phone besides Bluetooth: permissions, the
/// photo picker, the image shrinker, the microphone and the speaker. One
/// bundle, so tests can swap in fakes and the real recorder and player are
/// only created when somebody actually uses them.
class DeviceIo {
  DeviceIo({
    required this.permissions,
    required this.photos,
    required this.compressor,
    required VoiceRecorder Function() recorder,
    required VoicePlayer Function() player,
    required this.notifications,
    required this.keepAlive,
    required this.gallery,
    required this.sharer,
  })  : _recorderFactory = recorder,
        _playerFactory = player;

  /// The real phone.
  factory DeviceIo.real() => DeviceIo(
        permissions: const PluginPermissionService(),
        photos: PluginPhotoPicker(),
        compressor: const ImageCompressor(),
        recorder: PluginVoiceRecorder.new,
        player: PluginVoicePlayer.new,
        notifications: PluginNotificationSink(),
        keepAlive: const PluginKeepAlive(),
        gallery: const PluginGallerySaver(),
        sharer: const PluginSharer(),
      );

  final PermissionService permissions;
  final PhotoPicker photos;
  final ImageCompressor compressor;

  /// System notifications, and the Android service that keeps the mesh running
  /// with the screen off.
  final NotificationSink notifications;
  final KeepAlive keepAlive;

  /// Copies a received picture or video into the phone's gallery.
  final GallerySaver gallery;

  /// Hands text and files to another app through the system share sheet.
  final Sharer sharer;
  final VoiceRecorder Function() _recorderFactory;
  final VoicePlayer Function() _playerFactory;

  bool _recorderMade = false;
  bool _playerMade = false;

  late final VoiceRecorder recorder = _make(_recorderFactory, () => _recorderMade = true);
  late final VoicePlayer player = _make(_playerFactory, () => _playerMade = true);

  static T _make<T>(T Function() factory, void Function() mark) {
    mark();
    return factory();
  }

  Future<void> dispose() async {
    if (_recorderMade) await recorder.dispose();
    if (_playerMade) await player.dispose();
  }
}
