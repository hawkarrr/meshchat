import 'dart:io' show Platform;

import 'package:flutter/services.dart';

/// Keeps the app's process alive while the screen is off, so the Bluetooth mesh
/// keeps relaying and receiving ("Keep the mesh running in the background").
///
/// On Android this is a foreground service with a visible notification (see
/// `KeepAliveService.kt`). There is nothing equivalent to start on iOS: the
/// system suspends the app after a while whatever it asks for, and the app
/// declares no Bluetooth background mode. The person is told so in the settings.
abstract interface class KeepAlive {
  /// Whether this phone can do it at all.
  bool get supported;

  /// Starts it, with the words of its ongoing notification in the language of the
  /// app (Android's own translations follow the phone's language, not the app's).
  /// Starting it again updates the words. Returns whether it is running afterwards:
  /// a request Android accepted but the service then could not carry out counts as
  /// refused.
  Future<bool> start({KeepAliveTexts? texts});

  Future<void> stop();

  Future<bool> isRunning();

  /// Whether the phone's battery optimisation still applies to this app. Many
  /// phones stop an optimised app's Bluetooth work in the background, with or
  /// without the service. Null when it cannot be told (not Android, or the phone
  /// would not say).
  Future<bool?> batteryRestricted();

  /// Opens the phone's page where the app can be allowed to run without battery
  /// restrictions. Returns whether a page opened.
  Future<bool> openBatterySettings();
}

/// What the service's notification says, and the name of its channel in the
/// system's notification settings.
class KeepAliveTexts {
  const KeepAliveTexts({
    required this.title,
    required this.text,
    required this.channelName,
    required this.channelDescription,
  });

  final String title;
  final String text;
  final String channelName;
  final String channelDescription;

  Map<String, String> toMap() => <String, String>{
        'title': title,
        'text': text,
        'channelName': channelName,
        'channelDescription': channelDescription,
      };
}

/// The real thing, through a small method channel to the Android service.
class PluginKeepAlive implements KeepAlive {
  /// [android] overrides the platform check (tests run on a computer).
  const PluginKeepAlive({
    bool? android,
    this.confirmWithin = const Duration(seconds: 3),
    this.confirmEvery = const Duration(milliseconds: 100),
  }) : _android = android; // ignore: prefer_initializing_formals

  static const MethodChannel _channel = MethodChannel('damataqe/keep_alive');

  final bool? _android;

  /// How long a started service has to report that it became a foreground
  /// service, and how often it is asked meanwhile.
  final Duration confirmWithin;
  final Duration confirmEvery;

  @override
  bool get supported => _android ?? Platform.isAndroid;

  @override
  Future<bool> start({KeepAliveTexts? texts}) async {
    if (!supported) return false;
    final bool accepted;
    try {
      accepted = (await _channel.invokeMethod<bool>('start', texts?.toMap())) ?? false;
    } on PlatformException {
      // Android would not allow it right now (for example the app is not on screen).
      return false;
    } on MissingPluginException {
      return false;
    }
    if (!accepted) return false;
    // So far Android has only accepted the request. The service becomes a
    // foreground service a moment later - or is refused then (on Android 14 and
    // newer, for example, without the Bluetooth permission) and ends itself. Only
    // a service that says it runs counts.
    var waited = Duration.zero;
    while (true) {
      if (await isRunning()) return true;
      if (waited >= confirmWithin) return false;
      await Future<void>.delayed(confirmEvery);
      waited += confirmEvery;
    }
  }

  @override
  Future<void> stop() async {
    if (!supported) return;
    try {
      await _channel.invokeMethod<bool>('stop');
    } on PlatformException {
      // Already stopped.
    } on MissingPluginException {
      // Nothing to stop.
    }
  }

  @override
  Future<bool> isRunning() async {
    if (!supported) return false;
    try {
      return (await _channel.invokeMethod<bool>('isRunning')) ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<bool?> batteryRestricted() async {
    if (!supported) return null;
    try {
      return await _channel.invokeMethod<bool>('batteryRestricted');
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Future<bool> openBatterySettings() async {
    if (!supported) return false;
    try {
      return (await _channel.invokeMethod<bool>('openBatterySettings')) ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
