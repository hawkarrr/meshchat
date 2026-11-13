import 'dart:typed_data';

import 'package:bluetooth_low_energy/bluetooth_low_energy.dart' hide ConnectionState;
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_mesh_chat/services/plugin_ble_radio.dart';
import 'package:offline_mesh_chat/transport/ble_radio.dart';
import 'package:offline_mesh_chat/transport/mesh_transport.dart';

import '../support/fake_ble_world.dart';
import '../support/radio_harness.dart';

void main() {
  late FakeBleWorld world;
  final harnesses = <RadioHarness>[];

  setUp(() {
    world = FakeBleWorld();
    harnesses.clear();
  });

  tearDown(() async {
    for (final h in harnesses) {
      await h.dispose();
    }
  });

  RadioHarness phone(String name, {BlePlatform platform = BlePlatform.android, int maxMtu = 247}) {
    final h = RadioHarness.create(world, name, platform: platform, maxMtu: maxMtu);
    harnesses.add(h);
    return h;
  }

  /// B advertises, A scans, A connects to B specifically. Returns A's link id.
  Future<String> connectAtoB(RadioHarness a, RadioHarness b) async {
    await b.radio.initialize();
    await b.radio.startAdvertising();
    await a.radio.initialize();
    await a.radio.startScan();
    final target = b.phone.deviceUuid.toString();
    await eventually(() => a.discoveries.any((d) => d.deviceId == target),
        reason: 'A should discover B');
    return a.radio.connect(target);
  }

  group('initialisation and advertising', () {
    test('publishes exactly one write+notify characteristic and advertises only the service UUID',
        () async {
      final b = phone('B');
      await b.radio.initialize();
      await b.radio.startAdvertising();
      expect(b.phone.hasMeshService, isTrue);
      expect(b.phone.isAdvertising, isTrue);
      expect(b.radio.isAdvertising, isTrue);
      expect(world.violations, isEmpty); // in particular: no advertisement name
    });

    test('advertising requested before initialisation starts once the service is up', () async {
      final b = phone('B');
      await b.radio.startAdvertising(); // too early: just remembered
      expect(b.phone.isAdvertising, isFalse);
      await b.radio.initialize();
      await eventually(() => b.phone.isAdvertising);
    });

    test('reports a ready radio when Bluetooth is on and permitted', () async {
      final a = phone('A');
      await a.radio.initialize();
      expect(a.radio.status.ready, isTrue);
      expect(a.radio.status.blocker, isNull);
    });

    test('initialising twice does nothing the second time', () async {
      final a = phone('A');
      await a.radio.initialize();
      final callsBefore = world.calls.length;
      await a.radio.initialize();
      expect(world.calls.length, callsBefore);
    });
  });

  group('platform differences are respected', () {
    test('iOS: Android-only plugin members are never touched', () async {
      // The fake throws UnsupportedError for them exactly like the iOS plugin.
      final b = phone('B', platform: BlePlatform.ios);
      final a = phone('A', platform: BlePlatform.ios);
      await connectAtoB(a, b);
      expect(world.violations, isEmpty);
      expect(world.calls.where((c) => c.contains('requestMTU')), isEmpty);
    });

    test('Android: requests a large MTU, discovers, subscribes - in that order', () async {
      final a = phone('A');
      final b = phone('B');
      await connectAtoB(a, b);
      final aCalls = world.calls.where((c) => c.startsWith('A: central.')).toList();
      final order = ['connect', 'requestMTU(517)', 'discoverGATT', 'setCharacteristicNotifyState(true)'];
      var cursor = 0;
      for (final call in aCalls) {
        if (cursor < order.length && call.contains(order[cursor])) cursor++;
      }
      expect(cursor, order.length, reason: 'calls were: $aCalls');
    });

    test('Android <-> Android uses the negotiated MTU on both sides', () async {
      final a = phone('A');
      final b = phone('B');
      final linkId = await connectAtoB(a, b);
      expect(a.radio.maxChunkSize(linkId), 244); // 247 - 3
      await eventually(() => b.opened.isNotEmpty);
      expect(b.opened.single.maxChunk, 244);
    });

    test('a small remote MTU limits both directions', () async {
      final a = phone('A');
      final b = phone('B', maxMtu: 100);
      final linkId = await connectAtoB(a, b);
      expect(a.radio.maxChunkSize(linkId), 97);
      await eventually(() => b.opened.isNotEmpty);
      expect(b.opened.single.maxChunk, 97);
    });

    test('iOS central uses the system-negotiated size (no MTU request)', () async {
      final a = phone('A', platform: BlePlatform.ios);
      final b = phone('B');
      final linkId = await connectAtoB(a, b);
      expect(a.radio.maxChunkSize(linkId), 182); // iOS: 185 - 3
      await eventually(() => b.opened.isNotEmpty);
      expect(b.opened.single.maxChunk, 182);
    });

    test('an iPhone central sends full-size chunks without ever relying on long writes', () async {
      // CoreBluetooth reports 512 as the with-response write limit (it splits
      // bigger values into long writes). Chunks must still fit one ATT packet.
      final a = phone('A', platform: BlePlatform.ios);
      final b = phone('B');
      final linkId = await connectAtoB(a, b);
      await eventually(() => b.opened.isNotEmpty);
      final size = a.radio.maxChunkSize(linkId);
      expect(size, 182);
      final payload = Uint8List.fromList(List<int>.generate(size, (i) => (i * 3) & 0xff));
      await a.radio.sendChunk(linkId, payload);
      await eventually(() => b.chunks.isNotEmpty);
      expect(b.chunks.single.data, payload);
      expect(world.violations, isEmpty, reason: world.violations.join('\n'));
    });

    test('iOS peripheral reports the real notify length', () async {
      final a = phone('A');
      final b = phone('B', platform: BlePlatform.ios);
      await connectAtoB(a, b);
      await eventually(() => b.opened.isNotEmpty);
      expect(b.opened.single.maxChunk, greaterThanOrEqualTo(20));
      expect(world.violations, isEmpty);
    });

    test('if the MTU request fails, the 20-byte minimum is used and data still flows', () async {
      final a = phone('A');
      final b = phone('B');
      a.phone.failMtuRequests = true;
      final linkId = await connectAtoB(a, b);
      expect(a.radio.maxChunkSize(linkId), 20);
      await eventually(() => b.opened.isNotEmpty);
      expect(b.opened.single.maxChunk, 20);
      await a.radio.sendChunk(linkId, Uint8List.fromList(List<int>.generate(20, (i) => i)));
      await b.radio.sendChunk(b.opened.single.linkId, Uint8List.fromList(List<int>.generate(20, (i) => 100 + i)));
      await eventually(() => b.chunks.isNotEmpty && a.chunks.isNotEmpty);
      expect(world.violations, isEmpty);
    });
  });

  group('discovery', () {
    test('a scanning phone sees an advertising phone in range, not one out of range', () async {
      final a = phone('A');
      final b = phone('B');
      final c = phone('C');
      world.setInRange(a.phone, c.phone, false);
      for (final h in [b, c]) {
        await h.radio.initialize();
        await h.radio.startAdvertising();
      }
      await a.radio.initialize();
      await a.radio.startScan();
      await eventually(() => a.discoveries.isNotEmpty);
      await Future<void>.delayed(const Duration(milliseconds: 120));
      final seen = a.discoveries.map((d) => d.deviceId).toSet();
      expect(seen, {b.phone.deviceUuid.toString()});
    });

    test('scanning always uses the service filter', () async {
      final a = phone('A');
      await a.radio.initialize();
      await a.radio.startScan();
      expect(a.phone.isScanning, isTrue);
      expect(world.violations, isEmpty);
      await a.radio.stopScan();
      expect(a.phone.isScanning, isFalse);
    });
  });

  group('connecting', () {
    test('both sides get a usable link with matching roles and ids', () async {
      final a = phone('A');
      final b = phone('B');
      final linkId = await connectAtoB(a, b);
      expect(linkId, 'c:${b.phone.deviceUuid}');
      expect(a.opened.single.role, LinkRole.central);
      await eventually(() => b.opened.isNotEmpty);
      expect(b.opened.single.role, LinkRole.peripheral);
      expect(b.opened.single.linkId, 'p:${a.phone.deviceUuid}');
      expect(world.violations, isEmpty);
    });

    test('connecting twice to the same device returns the same link', () async {
      final a = phone('A');
      final b = phone('B');
      final first = await connectAtoB(a, b);
      final second = await a.radio.connect(a.discoveries.first.deviceId);
      expect(second, first);
      expect(a.opened.length, 1);
    });

    test('a device without the mesh service is rejected and disconnected', () async {
      final a = phone('A');
      final other = world.addPhone('Other'); // advertises the UUID but publishes nothing
      await other.peripheral.startAdvertising(
        Advertisement(serviceUUIDs: [UUID.fromString('7f0c1a2e-5d3b-4c8a-9e61-2b4d8f3a6c10')]),
      );
      await a.radio.initialize();
      await a.radio.startScan();
      await eventually(() => a.discoveries.isNotEmpty);
      await expectLater(
        a.radio.connect(a.discoveries.first.deviceId),
        throwsA(isA<RadioException>().having((e) => e.kind, 'kind', RadioErrorKind.serviceMissing)),
      );
      await eventually(() => a.phone.connectionCount == 0);
      expect(a.opened, isEmpty);
    });

    test('a connection that never completes (iOS style) times out and is abandoned', () async {
      final a = phone('A', platform: BlePlatform.ios);
      final b = phone('B');
      b.phone.connectBehavior = ConnectBehavior.hang;
      await b.radio.initialize();
      await b.radio.startAdvertising();
      await a.radio.initialize();
      await a.radio.startScan();
      await eventually(() => a.discoveries.isNotEmpty);
      await expectLater(
        a.radio.connect(a.discoveries.first.deviceId),
        throwsA(isA<RadioException>().having((e) => e.kind, 'kind', RadioErrorKind.timeout)),
      );
      expect(world.calls.where((c) => c.startsWith('A: central.disconnect')), isNotEmpty);
    });

    test('a fast connection failure (Android status 133) is reported, not hidden', () async {
      final a = phone('A');
      final b = phone('B');
      b.phone.connectBehavior = ConnectBehavior.failFast;
      await b.radio.initialize();
      await b.radio.startAdvertising();
      await a.radio.initialize();
      await a.radio.startScan();
      await eventually(() => a.discoveries.isNotEmpty);
      await expectLater(
        a.radio.connect(a.discoveries.first.deviceId),
        throwsA(isA<RadioException>().having((e) => e.kind, 'kind', RadioErrorKind.connectFailed)),
      );
    });

    test('a device that moved out of range after discovery cannot be connected', () async {
      final a = phone('A');
      final b = phone('B');
      await b.radio.initialize();
      await b.radio.startAdvertising();
      await a.radio.initialize();
      await a.radio.startScan();
      await eventually(() => a.discoveries.isNotEmpty);
      world.setInRange(a.phone, b.phone, false);
      await expectLater(a.radio.connect(a.discoveries.first.deviceId), throwsA(isA<RadioException>()));
    });

    test('an unknown device id is refused immediately', () async {
      final a = phone('A');
      await a.radio.initialize();
      await expectLater(
        a.radio.connect('no-such-device'),
        throwsA(isA<RadioException>().having((e) => e.kind, 'kind', RadioErrorKind.notFound)),
      );
    });

    test('connect attempts are serialised', () async {
      final a = phone('A');
      final b = phone('B');
      final c = phone('C');
      for (final h in [b, c]) {
        await h.radio.initialize();
        await h.radio.startAdvertising();
      }
      await a.radio.initialize();
      await a.radio.startScan();
      await eventually(() => a.discoveries.map((d) => d.deviceId).toSet().length == 2);
      final ids = a.discoveries.map((d) => d.deviceId).toSet().toList();
      final results = await Future.wait(ids.map(a.radio.connect));
      expect(results.toSet().length, 2);
      expect(world.violations, isEmpty);
    });
  });

  group('data transfer', () {
    Uint8List chunk(int n, [int len = 100]) =>
        Uint8List.fromList(List<int>.generate(len, (i) => (n + i) & 0xff));

    test('central -> peripheral: chunks arrive intact and in order', () async {
      final a = phone('A');
      final b = phone('B');
      final linkId = await connectAtoB(a, b);
      await eventually(() => b.opened.isNotEmpty);
      for (var i = 0; i < 50; i++) {
        await a.radio.sendChunk(linkId, chunk(i));
      }
      await eventually(() => b.chunks.length == 50);
      for (var i = 0; i < 50; i++) {
        expect(b.chunks[i].data, chunk(i));
        expect(b.chunks[i].linkId, 'p:${a.phone.deviceUuid}');
      }
      expect(world.violations, isEmpty);
    });

    test('peripheral -> central: notifications arrive intact and in order', () async {
      final a = phone('A');
      final b = phone('B');
      await connectAtoB(a, b);
      await eventually(() => b.opened.isNotEmpty);
      final back = b.opened.single.linkId;
      for (var i = 0; i < 50; i++) {
        await b.radio.sendChunk(back, chunk(i, 60));
      }
      await eventually(() => a.chunks.length == 50);
      for (var i = 0; i < 50; i++) {
        expect(a.chunks[i].data, chunk(i, 60));
        expect(a.chunks[i].linkId, 'c:${b.phone.deviceUuid}');
      }
      expect(world.violations, isEmpty);
    });

    test('many concurrent sends never overlap GATT operations and keep their order', () async {
      final a = phone('A');
      final b = phone('B');
      final linkId = await connectAtoB(a, b);
      await eventually(() => b.opened.isNotEmpty);
      final backLink = b.opened.single.linkId;

      final futures = <Future<void>>[
        for (var i = 0; i < 25; i++) a.radio.sendChunk(linkId, chunk(i, 50)),
        for (var i = 0; i < 25; i++) b.radio.sendChunk(backLink, chunk(i, 50)),
      ];
      await Future.wait(futures);
      await eventually(() => a.chunks.length == 25 && b.chunks.length == 25);
      for (var i = 0; i < 25; i++) {
        expect(b.chunks[i].data, chunk(i, 50));
        expect(a.chunks[i].data, chunk(i, 50));
      }
      expect(world.violations, isEmpty, reason: world.violations.join('\n'));
    });

    test('the peripheral never notifies before the central has subscribed', () async {
      final a = phone('A');
      final b = phone('B');
      await connectAtoB(a, b);
      // The peripheral link only appears once the subscription arrived.
      await eventually(() => b.opened.isNotEmpty);
      expect(world.violations.where((v) => v.contains('not subscribed')), isEmpty);
    });

    test('a chunk larger than the link allows is rejected up front', () async {
      final a = phone('A');
      final b = phone('B');
      final linkId = await connectAtoB(a, b);
      await expectLater(
        a.radio.sendChunk(linkId, Uint8List(a.radio.maxChunkSize(linkId) + 1)),
        throwsArgumentError,
      );
    });

    test('sending on a closed or unknown link fails with RadioException.closed', () async {
      final a = phone('A');
      await a.radio.initialize();
      await expectLater(
        a.radio.sendChunk('c:nowhere', Uint8List(5)),
        throwsA(isA<RadioException>().having((e) => e.kind, 'kind', RadioErrorKind.closed)),
      );
    });

    test('a transient write failure is retried transparently', () async {
      final a = phone('A');
      final b = phone('B');
      final linkId = await connectAtoB(a, b);
      a.phone.failNextWrites = 2;
      await a.radio.sendChunk(linkId, chunk(1));
      await eventually(() => b.chunks.isNotEmpty);
      expect(b.chunks.single.data, chunk(1));
    });

    test('a persistent write failure closes the link and reports it', () async {
      final a = phone('A');
      final b = phone('B');
      final linkId = await connectAtoB(a, b);
      a.phone.failNextWrites = 10;
      await expectLater(
        a.radio.sendChunk(linkId, chunk(1)),
        throwsA(isA<RadioException>().having((e) => e.kind, 'kind', RadioErrorKind.sendFailed)),
      );
      expect(a.closed.map((e) => e.linkId), contains(linkId));
    });

    test('a write the far end never answers times out and closes the link', () async {
      final a = phone('A');
      final b = phone('B');
      final linkId = await connectAtoB(a, b);
      await eventually(() => b.opened.isNotEmpty);
      world.blackhole(a.phone, b.phone, true);
      await expectLater(
        a.radio.sendChunk(linkId, chunk(1)),
        throwsA(isA<RadioException>().having((e) => e.kind, 'kind', RadioErrorKind.timeout)),
      );
      expect(a.closed.map((e) => e.linkId), contains(linkId));
    });
  });

  group('early data (the handshake race)', () {
    test('a write sent the instant a central subscribes is delivered, after the open event',
        () async {
      final b = phone('B');
      b.phone.notifyLengthDelay = const Duration(milliseconds: 60); // slow bookkeeping
      await b.radio.initialize();
      await b.radio.startAdvertising();

      // A bare central (no radio) that talks immediately after subscribing.
      final raw = world.addPhone('Raw');
      final target = FakePeripheral(b.phone);
      await raw.central.connect(target);
      final services = await raw.central.discoverGATT(target);
      final characteristic = services.single.characteristics.single;
      await raw.central.setCharacteristicNotifyState(target, characteristic, state: true);
      await raw.central.writeCharacteristic(
        target,
        characteristic,
        value: Uint8List.fromList([7, 8, 9]),
        type: GATTCharacteristicWriteType.withResponse,
      );
      await raw.central.writeCharacteristic(
        target,
        characteristic,
        value: Uint8List.fromList([10, 11]),
        type: GATTCharacteristicWriteType.withResponse,
      );

      await eventually(() => b.chunks.length == 2);
      expect(b.chunks.map((c) => c.data.toList()), [
        [7, 8, 9],
        [10, 11],
      ]);
      // The link was announced before any of its data was reported.
      expect(b.timeline.first, startsWith('open:'));
      expect(b.timeline.where((e) => e.startsWith('chunk:')).length, 2);
    });

    test('a notification sent the instant a subscription lands is delivered (central side)',
        () async {
      final a = phone('A');
      a.phone.subscribeAckDelay = const Duration(milliseconds: 60); // slow subscribe ack
      await a.radio.initialize();
      await a.radio.startScan();

      // A bare peripheral (no radio) that notifies as soon as it is subscribed.
      final raw = world.addPhone('Raw');
      final gattChar = GATTCharacteristic.mutable(
        uuid: UUID.fromString('7f0c1a2e-5d3b-4c8a-9e61-2b4d8f3a6c11'),
        properties: [GATTCharacteristicProperty.write, GATTCharacteristicProperty.notify],
        permissions: [GATTCharacteristicPermission.write],
        descriptors: const [],
      );
      await raw.peripheral.addService(GATTService(
        uuid: UUID.fromString('7f0c1a2e-5d3b-4c8a-9e61-2b4d8f3a6c10'),
        isPrimary: true,
        includedServices: const [],
        characteristics: [gattChar],
      ));
      await raw.peripheral.startAdvertising(
        Advertisement(serviceUUIDs: [UUID.fromString('7f0c1a2e-5d3b-4c8a-9e61-2b4d8f3a6c10')]),
      );
      raw.peripheral.characteristicNotifyStateChanged.listen((e) async {
        if (!e.state) return;
        await raw.peripheral.notifyCharacteristic(e.central, gattChar,
            value: Uint8List.fromList([42, 43]));
        await raw.peripheral.notifyCharacteristic(e.central, gattChar,
            value: Uint8List.fromList([44]));
      });

      final target = raw.deviceUuid.toString();
      await eventually(() => a.discoveries.any((d) => d.deviceId == target));
      await a.radio.connect(target);

      await eventually(() => a.chunks.length == 2);
      expect(a.chunks.map((c) => c.data.toList()), [
        [42, 43],
        [44],
      ]);
      expect(a.timeline.first, startsWith('open:'));
    });

    test('a link that fails during setup is never reported as opened or closed', () async {
      final a = phone('A');
      final b = phone('B');
      b.phone.connectBehavior = ConnectBehavior.succeed;
      await b.radio.initialize(); // no advertising: B has the service but we connect by id below
      await b.radio.startAdvertising();
      await a.radio.initialize();
      await a.radio.startScan();
      final target = b.phone.deviceUuid.toString();
      await eventually(() => a.discoveries.any((d) => d.deviceId == target));
      // Remove B's service so discovery in the middle of setup finds nothing.
      await b.phone.peripheral.removeAllServices();
      await expectLater(a.radio.connect(target), throwsA(isA<RadioException>()));
      expect(a.linkEvents, isEmpty);
    });
  });

  group('disconnection', () {
    test('a remote disconnect closes the link on both sides (Android peripheral)', () async {
      final a = phone('A');
      final b = phone('B');
      final linkId = await connectAtoB(a, b);
      await eventually(() => b.opened.isNotEmpty);
      a.phone.dropConnectionsTo(b.phone);
      await eventually(() => a.closed.isNotEmpty && b.closed.isNotEmpty);
      expect(a.closed.single.linkId, linkId);
      expect(b.closed.single.linkId, 'p:${a.phone.deviceUuid}');
    });

    test('an iOS peripheral learns of the loss through the unsubscribe event', () async {
      final a = phone('A');
      final b = phone('B', platform: BlePlatform.ios);
      await connectAtoB(a, b);
      await eventually(() => b.opened.isNotEmpty);
      a.phone.dropConnectionsTo(b.phone);
      await eventually(() => b.closed.isNotEmpty);
    });

    test('moving out of range drops the link', () async {
      final a = phone('A');
      final b = phone('B');
      await connectAtoB(a, b);
      await eventually(() => b.opened.isNotEmpty);
      world.setInRange(a.phone, b.phone, false);
      await eventually(() => a.closed.isNotEmpty && b.closed.isNotEmpty);
    });

    test('disconnect() tears the link down and tells the far end', () async {
      final a = phone('A');
      final b = phone('B');
      final linkId = await connectAtoB(a, b);
      await eventually(() => b.opened.isNotEmpty);
      await a.radio.disconnect(linkId);
      expect(a.closed.single.linkId, linkId);
      await eventually(() => b.closed.isNotEmpty);
      expect(a.phone.connectionCount, 0);
    });

    test('an Android peripheral can drop a central; an iOS one cannot', () async {
      final a = phone('A');
      final b = phone('B');
      await connectAtoB(a, b);
      await eventually(() => b.opened.isNotEmpty);
      await b.radio.disconnect(b.opened.single.linkId);
      await eventually(() => a.closed.isNotEmpty);
      expect(world.violations, isEmpty);

      // iOS peripheral: disconnect only closes our side's bookkeeping; it must
      // not call the unsupported API (the fake would throw).
      final c = phone('C');
      final d = phone('D', platform: BlePlatform.ios);
      await connectAtoB(c, d);
      await eventually(() => d.opened.isNotEmpty);
      await d.radio.disconnect(d.opened.single.linkId);
      expect(d.closed, isNotEmpty);
    });
  });

  group('Bluetooth and permission states', () {
    test('turning Bluetooth off closes links; turning it on restores service and advertising',
        () async {
      final a = phone('A');
      final b = phone('B');
      await connectAtoB(a, b);
      await eventually(() => b.opened.isNotEmpty);

      b.phone.setBluetooth(false);
      await eventually(() => b.closed.isNotEmpty && a.closed.isNotEmpty);
      expect(b.radio.status.canAdvertise, isFalse);
      expect(b.radio.isAdvertising, isFalse);
      expect(b.phone.hasMeshService, isFalse);

      b.phone.setBluetooth(true);
      await eventually(() => b.phone.hasMeshService && b.phone.isAdvertising,
          reason: 'service and advertising must be rebuilt after the toggle');
      expect(b.radio.status.ready, isTrue);
    });

    test('scanning resumes by itself after Bluetooth returns', () async {
      final a = phone('A');
      final b = phone('B');
      await b.radio.initialize();
      await b.radio.startAdvertising();
      await a.radio.initialize();
      await a.radio.startScan();
      await eventually(() => a.discoveries.isNotEmpty);
      a.phone.setBluetooth(false);
      expect(a.phone.isScanning, isFalse);
      a.discoveries.clear();
      a.phone.setBluetooth(true);
      await eventually(() => a.phone.isScanning);
      await eventually(() => a.discoveries.isNotEmpty);
    });

    test('status changes are published for the UI', () async {
      final a = phone('A');
      await a.radio.initialize();
      a.phone.setBluetooth(false);
      await eventually(() => a.statuses.any((s) => s.blocker == RadioAvailability.poweredOff));
      a.phone.setBluetooth(true);
      await eventually(() => a.statuses.last.ready);
    });

    test('missing permission is reported as such, and requesting it fixes Android', () async {
      final a = phone('A');
      a.phone.permissionsGranted = false;
      a.phone.userGrantsPermissions = true;
      await a.radio.initialize();
      expect(a.radio.status.blocker, RadioAvailability.unauthorized);
      await a.radio.startAdvertising();
      expect(a.phone.isAdvertising, isFalse);

      await a.radio.requestPermissions();
      await eventually(() => a.radio.status.ready);
      await eventually(() => a.phone.isAdvertising, reason: 'advertising was requested earlier');
    });

    test('asking again when Bluetooth is already allowed shows no dialog and does not wait',
        () async {
      final a = phone('A');
      await a.radio.initialize();
      expect(a.radio.status.ready, isTrue);
      final callsBefore = world.calls.length;

      final watch = Stopwatch()..start();
      await a.radio.requestPermissions();
      watch.stop();

      expect(world.calls.skip(callsBefore).where((c) => c.contains('authorize')), isEmpty,
          reason: 'there is nothing to ask for');
      expect(watch.elapsedMilliseconds, lessThan(500),
          reason: 'it must not sit waiting for a state change that will never come');
    });

    test('a refused permission stays unauthorized and can open the settings', () async {
      final a = phone('A');
      a.phone.permissionsGranted = false;
      a.phone.userGrantsPermissions = false;
      await a.radio.initialize();
      await a.radio.requestPermissions();
      expect(a.radio.status.blocker, RadioAvailability.unauthorized);
      await a.radio.openAppSettings();
      expect(a.phone.settingsOpened, 1);
    });

    test('iOS never asks through authorize() (it would throw) but can open settings', () async {
      final a = phone('A', platform: BlePlatform.ios);
      a.phone.permissionsGranted = false;
      await a.radio.initialize();
      await a.radio.requestPermissions(); // must not throw
      expect(a.radio.status.blocker, RadioAvailability.unauthorized);
      await a.radio.openAppSettings();
      expect(a.phone.settingsOpened, 1);
      // Granting in system settings is picked up through the state stream.
      a.phone.setPermissions(true);
      await eventually(() => a.radio.status.ready);
    });

    test('a phone that cannot advertise can still scan, and says so', () async {
      final a = phone('A');
      a.phone.advertisingSupported = false;
      await a.radio.initialize();
      expect(a.radio.status.canScan, isTrue);
      expect(a.radio.status.canAdvertise, isFalse);
      expect(a.radio.status.blocker, RadioAvailability.unsupported);
      await a.radio.startAdvertising(); // must not throw or loop
      expect(a.radio.isAdvertising, isFalse);
    });

    test('a phone without BLE is unsupported', () async {
      final a = phone('A');
      a.phone.bleSupported = false;
      await a.radio.initialize();
      expect(a.radio.status.blocker, RadioAvailability.unsupported);
    });
  });
}
