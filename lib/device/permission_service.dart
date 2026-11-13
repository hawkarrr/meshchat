import 'dart:io' show Platform;

import 'package:permission_handler/permission_handler.dart';

/// The permissions Damatqe asks for besides Bluetooth (which has its own flow
/// because the Bluetooth plugin knows exactly which set each Android version
/// needs).
enum AppPermission {
  /// Recording voice messages.
  microphone,

  /// Taking a photo to send.
  camera,

  /// Choosing a photo from the library to send.
  photos,

  /// Showing a notification when a message arrives (Android 13 and newer, iOS).
  notifications,
}

enum PermissionOutcome {
  granted,

  /// Not granted; the system will show its prompt if asked again.
  denied,

  /// Switched off for good: only the system settings can turn it on.
  permanentlyDenied,

  /// This phone does not allow it (parental controls, no hardware).
  unavailable,
}

/// Asks the system about, and for, permissions. Behind an interface so the UI
/// can be tested without a phone.
abstract interface class PermissionService {
  Future<PermissionOutcome> status(AppPermission permission);

  /// Shows the system prompt (if the system still allows one).
  Future<PermissionOutcome> request(AppPermission permission);

  /// Opens this app's page in the system settings.
  Future<bool> openSettings();
}

class PluginPermissionService implements PermissionService {
  const PluginPermissionService();

  Permission _map(AppPermission p) => switch (p) {
        AppPermission.microphone => Permission.microphone,
        AppPermission.camera => Permission.camera,
        AppPermission.photos => Permission.photos,
        AppPermission.notifications => Permission.notification,
      };

  /// Android's system photo picker lets the person choose pictures without the
  /// app holding any storage permission at all, so there is nothing to ask for.
  bool _needsNoPrompt(AppPermission p) => p == AppPermission.photos && Platform.isAndroid;

  PermissionOutcome _outcome(PermissionStatus s) => switch (s) {
        PermissionStatus.granted || PermissionStatus.limited || PermissionStatus.provisional =>
          PermissionOutcome.granted,
        PermissionStatus.denied => PermissionOutcome.denied,
        PermissionStatus.permanentlyDenied => PermissionOutcome.permanentlyDenied,
        PermissionStatus.restricted => PermissionOutcome.unavailable,
      };

  @override
  Future<PermissionOutcome> status(AppPermission permission) async {
    if (_needsNoPrompt(permission)) return PermissionOutcome.granted;
    return _outcome(await _map(permission).status);
  }

  @override
  Future<PermissionOutcome> request(AppPermission permission) async {
    if (_needsNoPrompt(permission)) return PermissionOutcome.granted;
    return _outcome(await _map(permission).request());
  }

  @override
  Future<bool> openSettings() => openAppSettings();
}
