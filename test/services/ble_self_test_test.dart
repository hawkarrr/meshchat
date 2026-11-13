import 'package:flutter_test/flutter_test.dart';
import 'package:offline_mesh_chat/core/app_info.dart';
import 'package:offline_mesh_chat/mesh/peer_table.dart';
import 'package:offline_mesh_chat/services/ble_self_test.dart';
import 'package:offline_mesh_chat/services/device_info_service.dart';
import 'package:offline_mesh_chat/services/network_status_service.dart';

import '../support/ble_stack.dart';
import '../support/fake_ble_world.dart';
import '../support/full_stack_node.dart';
import '../support/radio_harness.dart';

BleSelfTest _testFor(
  BleNode n, {
  PeerTable? table,
  int? sdk,
  NetworkKind net = NetworkKind.none,
  Duration discoveryWindow = const Duration(milliseconds: 1500),
}) =>
    BleSelfTest(
      radio: n.radio,
      bluetooth: n.bluetooth,
      discovery: n.discovery,
      table: table ?? PeerTable(),
      device: StaticDeviceInfo('Test Phone 1 - Android 14', sdk: sdk),
      network: StaticNetworkStatus(net),
      discoveryWindow: discoveryWindow,
      connectWindow: const Duration(seconds: 3),
      advertiseWindow: const Duration(seconds: 1),
    );

CheckResult _check(BleSelfTest t, String id) => t.results.firstWhere((r) => r.id == id);

void main() {
  late FakeBleWorld world;
  final nodes = <BleNode>[];
  final stacks = <FullStackNode>[];

  setUp(() {
    world = FakeBleWorld();
    nodes.clear();
    stacks.clear();
  });

  tearDown(() async {
    for (final n in nodes) {
      await n.dispose();
    }
    for (final s in stacks) {
      await s.dispose();
    }
  });

  Future<BleNode> node(String name, int seed, {int maxMtu = 247}) async {
    final n = await BleNode.create(world, name, seed: seed, maxMtu: maxMtu);
    nodes.add(n);
    return n;
  }

  test('with a second phone every check passes and the data really round-trips', () async {
    final a = await node('Alice', 1);
    final b = await node('Bob', 2);
    await a.start();
    await b.start();

    final t = _testFor(a);
    await t.run();

    for (final id in ['device', 'support', 'permission', 'power', 'advertising', 'scanning',
        'discovery', 'connection', 'exchange', 'network']) {
      expect(_check(t, id).state, CheckState.passed, reason: '$id: ${_check(t, id).detail}');
    }
    expect(_check(t, 'multihop').state, CheckState.skipped);
    expect(_check(t, 'connection').detail, contains('Bob'));
    expect(_check(t, 'exchange').detail, contains('5/5 small'));
    expect(_check(t, 'exchange').detail, contains('3/3 large'));
    expect(t.overall, CheckState.passed);
    expect(t.running, isFalse);
    expect(world.violations, isEmpty, reason: world.violations.join('\n'));

    final report = t.report();
    expect(report, contains('${AppInfo.latinName} - BLE self-test'));
    expect(report, contains('Test Phone 1 - Android 14'));
    expect(report, contains('[PASS] Sending data both ways'));
    expect(report, contains('Links:'));
  });

  test('alone in the room: the radio checks pass and the rest honestly say there is nobody',
      () async {
    final a = await node('Alice', 1);
    await a.start();
    final t = _testFor(a, discoveryWindow: const Duration(milliseconds: 700));
    await t.run();

    expect(_check(t, 'advertising').state, CheckState.passed);
    expect(_check(t, 'scanning').state, CheckState.passed);
    expect(_check(t, 'discovery').state, CheckState.warning);
    expect(_check(t, 'discovery').advice, contains('second phone'));
    expect(_check(t, 'connection').state, CheckState.skipped);
    expect(_check(t, 'exchange').state, CheckState.skipped);
    expect(t.overall, CheckState.warning, reason: 'not a failure: an empty room proves nothing');
  });

  test('on Android 11 and older, an empty scan also points at the Location switch', () async {
    final a = await node('Alice', 1);
    await a.start();
    final old = _testFor(a, sdk: 30, discoveryWindow: const Duration(milliseconds: 500));
    await old.run();
    expect(_check(old, 'discovery').state, CheckState.warning);
    expect(_check(old, 'discovery').advice, contains('Location switch'));

    final modern = _testFor(a, sdk: 34, discoveryWindow: const Duration(milliseconds: 500));
    await modern.run();
    expect(_check(modern, 'discovery').advice, isNot(contains('Location')),
        reason: 'Android 12+ scanning does not depend on location');
  });

  test('Bluetooth switched off is reported with the fix, and the rest is skipped', () async {
    final a = await node('Alice', 1);
    await a.start();
    a.phone.setBluetooth(false);
    await eventually(() => !a.radio.status.canScan);
    final t = _testFor(a);
    await t.run();
    expect(_check(t, 'power').state, CheckState.failed);
    expect(_check(t, 'power').advice, contains('quick settings'));
    expect(_check(t, 'advertising').state, CheckState.skipped);
    expect(_check(t, 'exchange').state, CheckState.skipped);
    expect(t.overall, CheckState.failed);
  });

  test('a missing permission explains where to grant it, per Android version', () async {
    final a = await node('Alice', 1);
    await a.radio.initialize();
    a.phone.setPermissions(false);
    await eventually(() => !a.radio.status.ready);

    final modern = _testFor(a, sdk: 34);
    await modern.run();
    expect(_check(modern, 'permission').state, CheckState.failed);
    expect(_check(modern, 'permission').advice, contains('Nearby devices'));

    final legacy = _testFor(a, sdk: 29);
    await legacy.run();
    expect(_check(legacy, 'permission').advice, contains('Location'));

    final ios = _testFor(a);
    await ios.run();
    expect(_check(ios, 'permission').advice, contains('Settings > ${AppInfo.name} > Bluetooth'));
  });

  test('a phone that cannot advertise gets a warning, not a failure', () async {
    final a = await node('Alice', 1);
    a.phone.advertisingSupported = false;
    await a.start();
    final t = _testFor(a, discoveryWindow: const Duration(milliseconds: 500));
    await t.run();
    expect(_check(t, 'advertising').state, CheckState.warning);
    expect(_check(t, 'advertising').detail, contains('cannot advertise'));
    expect(_check(t, 'scanning').state, CheckState.passed);
  });

  test('a connection that keeps failing is reported with the underlying error', () async {
    final a = await node('Alice', 1);
    final b = await node('Bob', 2);
    await b.start(discover: false);
    b.phone.connectBehavior = ConnectBehavior.failFast;
    await a.start();
    final t = _testFor(a);
    await t.run();
    expect(_check(t, 'discovery').state, CheckState.passed);
    expect(_check(t, 'connection').state, CheckState.failed);
    expect(_check(t, 'connection').detail, contains('133'));
    expect(_check(t, 'connection').advice, contains('closer'));
    expect(_check(t, 'exchange').state, CheckState.skipped);
  });

  test('the 20-byte minimum write size is flagged as slow', () async {
    final a = await node('Alice', 1);
    final b = await node('Bob', 2);
    a.phone.failMtuRequests = true;
    b.phone.failMtuRequests = true;
    await a.start();
    await b.start();
    final t = _testFor(a);
    await t.run();
    expect(_check(t, 'exchange').state, CheckState.warning);
    expect(_check(t, 'exchange').advice, contains('20 bytes'));
    // It still worked, just slowly.
    expect(_check(t, 'exchange').detail, contains('5/5 small'));
  });

  test('three phones in a line: the end phone is reported as reachable through the relay',
      () async {
    final a = await FullStackNode.create(world, 'A', seed: 1);
    final b = await FullStackNode.create(world, 'B', seed: 2);
    final c = await FullStackNode.create(world, 'C', seed: 3);
    stacks.addAll([a, b, c]);
    world.setInRange(a.phone, c.phone, false);
    for (final n in stacks) {
      await n.start();
    }
    await eventually(
        () => a.ble.bluetooth.isNeighbor(b.id) && b.ble.bluetooth.isNeighbor(c.id),
        timeout: const Duration(seconds: 8));
    await eventually(() => a.table.statusOf(c.id).isReachable, timeout: const Duration(seconds: 8));

    final t = BleSelfTest(
      radio: a.ble.radio,
      bluetooth: a.ble.bluetooth,
      discovery: a.ble.discovery,
      table: a.table,
      device: const StaticDeviceInfo('Test'),
      network: StaticNetworkStatus(NetworkKind.none),
      discoveryWindow: const Duration(seconds: 2),
      connectWindow: const Duration(seconds: 3),
      advertiseWindow: const Duration(seconds: 1),
    );
    await t.run();
    expect(_check(t, 'multihop').state, CheckState.passed);
    expect(_check(t, 'multihop').detail, contains('2 links'));
  });

  test('the network line states plainly that the internet is not used', () async {
    final a = await node('Alice', 1);
    await a.start();
    final online = _testFor(a, net: NetworkKind.wifi, discoveryWindow: const Duration(milliseconds: 300));
    await online.run();
    expect(_check(online, 'network').detail, contains('not used by this app'));
    expect(_check(online, 'network').detail, contains('airplane mode'));
  });

  test('stopping a run marks unfinished steps as stopped instead of inventing failures', () async {
    final a = await node('Alice', 1);
    await a.start();
    final t = _testFor(a, discoveryWindow: const Duration(seconds: 6));
    final future = t.run();
    await eventually(() => _check(t, 'discovery').state == CheckState.running);
    t.cancel();
    await future.timeout(const Duration(seconds: 8));

    expect(_check(t, 'advertising').state, CheckState.passed, reason: 'finished before the stop');
    for (final id in ['discovery', 'connection', 'exchange', 'multihop', 'network']) {
      expect(_check(t, id).state, CheckState.skipped, reason: id);
      expect(_check(t, id).detail, 'Stopped.', reason: id);
    }
    expect(t.overall, isNot(CheckState.failed));
    expect(t.running, isFalse);
  });

  test('closing the screen while a run is in progress is harmless', () async {
    final a = await node('Alice', 1);
    await a.start();
    final t = _testFor(a, discoveryWindow: const Duration(seconds: 6));
    final future = t.run();
    await eventually(() => _check(t, 'discovery').state == CheckState.running);
    t.dispose();
    // The run winds down in the background; late updates must not throw.
    await future.timeout(const Duration(seconds: 8));
  });

  test('a run can be repeated and cancelled', () async {
    final a = await node('Alice', 1);
    await a.start();
    final t = _testFor(a, discoveryWindow: const Duration(milliseconds: 300));
    await t.run();
    final first = t.finishedAt;
    expect(first, isNotNull);
    await t.run();
    expect(t.finishedAt!.isAfter(first!) || t.finishedAt == first, isTrue);
    final cancelled = _testFor(a, discoveryWindow: const Duration(seconds: 5));
    final future = cancelled.run();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    cancelled.cancel();
    await future.timeout(const Duration(seconds: 8));
    expect(cancelled.running, isFalse);
  });
}
