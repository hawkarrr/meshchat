import 'package:flutter_test/flutter_test.dart';
import 'package:offline_mesh_chat/services/bluetooth_service.dart';
import 'package:offline_mesh_chat/services/discovery_service.dart';

import '../support/ble_stack.dart';
import '../support/fake_ble_world.dart';
import '../support/radio_harness.dart';

DiscoveryConfig _config({
  Duration scanOn = const Duration(milliseconds: 250),
  Duration scanOff = const Duration(milliseconds: 100),
  Duration minScanStartGap = Duration.zero,
  Duration forgetAfter = const Duration(minutes: 2),
}) =>
    DiscoveryConfig(
      scanOn: scanOn,
      scanOff: scanOff,
      minScanStartGap: minScanStartGap,
      connectTick: const Duration(milliseconds: 20),
      candidateFreshness: const Duration(seconds: 3),
      connectJitterMax: const Duration(milliseconds: 25),
      baseBackoff: const Duration(milliseconds: 60),
      maxBackoff: const Duration(milliseconds: 500),
      reconnectDelay: const Duration(milliseconds: 60),
      notifyGap: Duration.zero,
      forgetAfter: forgetAfter,
    );

void main() {
  late FakeBleWorld world;
  final nodes = <BleNode>[];

  setUp(() {
    world = FakeBleWorld();
    nodes.clear();
  });

  tearDown(() async {
    for (final n in nodes) {
      await n.dispose();
    }
  });

  Future<BleNode> node(
    String name, {
    int seed = 1,
    DiscoveryConfig? discovery,
    BluetoothServiceConfig service = fastService,
  }) async {
    final n = await BleNode.create(world, name,
        seed: seed, discoveryConfig: discovery ?? fastDiscovery, service: service);
    nodes.add(n);
    return n;
  }

  int count(String what) => world.calls.where((c) => c.contains(what)).length;

  group('scan cadence', () {
    test('keeps the phone advertising and scans in on/off windows', () async {
      final a = await node('A', discovery: _config());
      await a.start();
      expect(a.phone.isAdvertising, isTrue);
      final seenOn = <bool>[];
      for (var i = 0; i < 40; i++) {
        seenOn.add(a.discovery.isScanning);
        await Future<void>.delayed(const Duration(milliseconds: 25));
      }
      expect(seenOn, contains(true));
      expect(seenOn, contains(false), reason: 'there must be pauses between windows');
      expect(a.discovery.scanStarts, greaterThanOrEqualTo(2));
      expect(count('startDiscovery'), greaterThanOrEqualTo(2));
      expect(count('stopDiscovery'), greaterThanOrEqualTo(1));
      expect(world.violations, isEmpty);
    });

    test('never starts scans closer together than the configured minimum gap', () async {
      final a = await node('A',
          discovery: _config(
            scanOn: const Duration(milliseconds: 40),
            scanOff: const Duration(milliseconds: 20),
            minScanStartGap: const Duration(milliseconds: 300),
          ));
      await a.start();
      await Future<void>.delayed(const Duration(milliseconds: 1300));
      // 1.3 s / 0.3 s gap = at most 5 starts (including the first).
      expect(a.discovery.scanStarts, lessThanOrEqualTo(5));
      expect(a.discovery.scanStarts, greaterThanOrEqualTo(2));
    });

    test('the default cadences stay within Android\'s limit of 5 scan starts per 30 s', () {
      for (final mode in DiscoveryMode.values) {
        final c = DiscoveryConfig.forMode(mode);
        final periodMs = (c.scanOn + c.scanOff).inMilliseconds;
        final effective = periodMs < c.minScanStartGap.inMilliseconds
            ? c.minScanStartGap.inMilliseconds
            : periodMs;
        final startsPer30s = 30000 / effective;
        expect(startsPer30s, lessThanOrEqualTo(5), reason: '${mode.name}: $startsPer30s starts / 30 s');
      }
    });

    test('continuous mode starts one scan and never stops it', () async {
      final a = await node('A', discovery: DiscoveryConfig.forMode(DiscoveryMode.aggressive));
      await a.start();
      await Future<void>.delayed(const Duration(milliseconds: 600));
      expect(a.discovery.scanStarts, 1);
      expect(a.phone.isScanning, isTrue);
      expect(count('stopDiscovery'), 0);
    });

    test('changing the mode takes effect immediately', () async {
      final a = await node('A', discovery: _config(scanOn: const Duration(seconds: 30)));
      await a.start();
      await eventually(() => a.discovery.isScanning);
      a.discovery.setMode(DiscoveryMode.lowPower);
      expect(a.discovery.mode, DiscoveryMode.lowPower);
      expect(a.discovery.config.scanOff, const Duration(seconds: 25));
    });

    test('stopping stops advertising, scanning and connecting', () async {
      final a = await node('A', discovery: _config());
      await a.start();
      await eventually(() => a.phone.isScanning);
      await a.discovery.stop();
      expect(a.phone.isAdvertising, isFalse);
      expect(a.phone.isScanning, isFalse);
      final startsAfterStop = a.discovery.scanStarts;
      await Future<void>.delayed(const Duration(milliseconds: 500));
      expect(a.discovery.scanStarts, startsAfterStop);
    });

    test('waits while Bluetooth is off and resumes by itself', () async {
      final a = await node('A', discovery: _config());
      final b = await node('B', seed: 2, discovery: _config());
      await a.start();
      await b.start();
      await waitStableLink(a, b);

      a.phone.setBluetooth(false);
      await eventually(() => !a.discovery.isScanning);
      final before = a.discovery.scanStarts;
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(a.discovery.scanStarts, before, reason: 'must not try to scan while Bluetooth is off');

      a.phone.setBluetooth(true);
      await waitLinked(a, b, timeout: const Duration(seconds: 8));
    });
  });

  group('connection policy', () {
    test('finds a phone, connects, and learns who it is', () async {
      final a = await node('A', seed: 1);
      final b = await node('B', seed: 2);
      await a.start();
      await b.start();
      await waitStableLink(a, b);
      await eventually(() => a.discovery.devices.any((d) => d.peerId == b.id));
      final d = a.discovery.devices.firstWhere((d) => d.peerId == b.id);
      expect(d.deviceId, b.phone.deviceUuid.toString());
      expect(d.state, anyOf(DeviceState.connected, DeviceState.alreadyLinked));
    });

    test('backs off exponentially after failures, then connects once the fault clears', () async {
      final a = await node('A', seed: 1);
      final b = await node('B', seed: 2);
      // B only advertises; it does not run the policy, so A is the only one connecting.
      await b.start(discover: false);
      b.phone.connectBehavior = ConnectBehavior.failFast;
      await a.start();
      await eventually(() => a.discovery.devices.isNotEmpty);

      await Future<void>.delayed(const Duration(milliseconds: 1500));
      final attempts = count('A: central.connect(');
      final device = a.discovery.devices.single;
      expect(device.failures, greaterThanOrEqualTo(3));
      expect(device.lastError, isNotNull);
      // Backing off: 1.5 s of failures with 60 ms .. 500 ms delays means a handful of
      // attempts, not one per tick (which would be ~75).
      expect(attempts, lessThan(20), reason: 'attempts: $attempts');
      expect(attempts, greaterThanOrEqualTo(3));

      b.phone.connectBehavior = ConnectBehavior.succeed;
      await eventually(() => a.bluetooth.isNeighbor(b.id), timeout: const Duration(seconds: 5));
      expect(a.discovery.devices.single.failures, 0);
    });

    test('does not connect when the phone has no free link slot', () async {
      const none = BluetoothServiceConfig(maxLinks: 0, extraIncomingLinks: 0);
      final a = await node('A', seed: 1, service: none);
      final b = await node('B', seed: 2);
      await b.start(discover: false);
      await a.start();
      await eventually(() => a.discovery.devices.isNotEmpty);
      await Future<void>.delayed(const Duration(milliseconds: 600));
      expect(count('A: central.connect('), 0);
    });

    test('stale devices are forgotten', () async {
      final a = await node('A',
          seed: 1, discovery: _config(forgetAfter: const Duration(milliseconds: 400)));
      final b = await node('B', seed: 2);
      await b.start(discover: false);
      b.phone.connectBehavior = ConnectBehavior.hang; // never becomes a link
      await a.start();
      await eventually(() => a.discovery.devices.isNotEmpty);
      world.setInRange(a.phone, b.phone, false);
      await eventually(() => a.discovery.devices.isEmpty, timeout: const Duration(seconds: 3));
    });

    test('devices are listed strongest signal first, and the strongest is tried first', () async {
      final a = await node('A', seed: 1);
      final weak = await node('Weak', seed: 2);
      final strong = await node('Strong', seed: 3);
      weak.phone.advertisedRssi = -90;
      strong.phone.advertisedRssi = -40;
      for (final other in [weak, strong]) {
        await other.start(discover: false);
        other.phone.connectBehavior = ConnectBehavior.hang; // keep them unlinked
      }
      await a.start();
      await eventually(() => a.discovery.devices.length == 2);
      final list = a.discovery.devices;
      expect(list.map((d) => d.rssi), [-40, -90]);
      expect(list.first.deviceId, strong.phone.deviceUuid.toString());
      await eventually(() => world.calls.any((c) => c.startsWith('A: central.connect(')));
      final firstAttempt = world.calls.firstWhere((c) => c.startsWith('A: central.connect('));
      expect(firstAttempt, contains('Strong'));
    });

    test('the UI is told about changes', () async {
      final a = await node('A', seed: 1);
      final b = await node('B', seed: 2);
      var changes = 0;
      final sub = a.discovery.changes.listen((_) => changes++);
      await a.start();
      await b.start();
      await waitLinked(a, b);
      await sub.cancel();
      expect(changes, greaterThan(2));
    });
  });
}
