import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';

/// Describes this phone for the BLE test report ("Pixel 7, Android 14").
///
/// BLE behaviour differs a lot between phone models and OS versions, so a
/// report is only useful to compare runs if it says what produced it. This
/// reads local system properties only; nothing is sent anywhere.
abstract interface class DeviceInfoSource {
  Future<String> describe();

  /// Android API level, or null elsewhere.
  Future<int?> androidSdk();
}

class DeviceInfoService implements DeviceInfoSource {
  DeviceInfoService({DeviceInfoPlugin? plugin}) : _plugin = plugin ?? DeviceInfoPlugin();

  final DeviceInfoPlugin _plugin;
  String? _cached;
  int? _sdk;

  @override
  Future<int?> androidSdk() async {
    await describe();
    return _sdk;
  }

  @override
  Future<String> describe() async {
    final cached = _cached;
    if (cached != null) return cached;
    String text;
    try {
      if (Platform.isAndroid) {
        final i = await _plugin.androidInfo;
        _sdk = i.version.sdkInt;
        text = '${i.manufacturer} ${i.model} - Android ${i.version.release} (API ${i.version.sdkInt})';
      } else if (Platform.isIOS) {
        final i = await _plugin.iosInfo;
        text = '${i.utsname.machine} - ${i.systemName} ${i.systemVersion}';
      } else {
        text = '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
      }
    } catch (e) {
      text = '${Platform.operatingSystem} (device details unavailable)';
    }
    return _cached = text;
  }
}

/// A fixed description, for tests.
class StaticDeviceInfo implements DeviceInfoSource {
  const StaticDeviceInfo(this.text, {this.sdk});

  final String text;
  final int? sdk;

  @override
  Future<String> describe() async => text;

  @override
  Future<int?> androidSdk() async => sdk;
}
