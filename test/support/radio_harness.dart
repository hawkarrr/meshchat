import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:offline_mesh_chat/core/app_log.dart';
import 'package:offline_mesh_chat/services/plugin_ble_radio.dart';
import 'package:offline_mesh_chat/transport/ble_radio.dart';

import 'fake_ble_world.dart';

/// Short time budgets so failure paths run in milliseconds.
const RadioTimings fastTimings = RadioTimings(
  connectGuard: Duration(milliseconds: 400),
  postConnectDelay: Duration.zero,
  mtuTimeout: Duration(milliseconds: 300),
  discoverTimeout: Duration(milliseconds: 300),
  subscribeTimeout: Duration(milliseconds: 300),
  operationTimeout: Duration(milliseconds: 400),
  stateWait: Duration(milliseconds: 300),
  advertiseRetry: Duration(milliseconds: 80),
  sendRetryBase: Duration(milliseconds: 2),
);

/// A phone's radio plus a recording of everything it reports.
class RadioHarness {
  RadioHarness._(this.phone, this.radio) {
    _subs.add(radio.linkEvents.listen((e) {
      linkEvents.add(e);
      timeline.add(e is RadioLinkOpened ? 'open:${e.linkId}' : 'close:${e.linkId}');
    }));
    _subs.add(radio.chunks.listen((c) {
      chunks.add(c);
      timeline.add('chunk:${c.linkId}');
    }));
    _subs.add(radio.discoveries.listen(discoveries.add));
    _subs.add(radio.statusChanges.listen(statuses.add));
  }

  final FakePhone phone;
  final PluginBleRadio radio;

  /// Link and chunk events in the exact order the radio reported them.
  final List<String> timeline = <String>[];
  final List<RadioLinkEvent> linkEvents = <RadioLinkEvent>[];
  final List<RadioChunk> chunks = <RadioChunk>[];
  final List<RadioDiscovery> discoveries = <RadioDiscovery>[];
  final List<RadioStatus> statuses = <RadioStatus>[];
  final List<StreamSubscription<Object?>> _subs = <StreamSubscription<Object?>>[];

  static RadioHarness create(
    FakeBleWorld world,
    String name, {
    BlePlatform platform = BlePlatform.android,
    int maxMtu = 247,
    RadioTimings timings = fastTimings,
  }) {
    final phone = world.addPhone(name, platform: platform, maxMtu: maxMtu);
    final radio = PluginBleRadio(
      central: phone.central,
      peripheral: phone.peripheral,
      platform: platform,
      log: AppLog(echo: false),
      timings: timings,
    );
    return RadioHarness._(phone, radio);
  }

  List<RadioLinkOpened> get opened => linkEvents.whereType<RadioLinkOpened>().toList();

  List<RadioLinkClosed> get closed => linkEvents.whereType<RadioLinkClosed>().toList();

  Future<void> dispose() async {
    for (final s in _subs) {
      await s.cancel();
    }
    await radio.dispose();
  }
}

/// Polls [condition] until it holds, or fails the test after [timeout].
Future<void> eventually(
  FutureOr<bool> Function() condition, {
  Duration timeout = const Duration(seconds: 3),
  String? reason,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (await condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 4));
  }
  fail('Condition not met within $timeout${reason == null ? '' : ': $reason'}');
}
