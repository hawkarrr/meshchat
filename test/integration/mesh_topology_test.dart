import 'package:flutter_test/flutter_test.dart';
import 'package:offline_mesh_chat/protocol/protocol_constants.dart';
import 'package:offline_mesh_chat/services/plugin_ble_radio.dart';

import '../support/fake_ble_world.dart';
import '../support/full_stack_node.dart';
import '../support/radio_harness.dart';

/// The shape of the mesh, end to end: discovery, connection, the authenticated handshake,
/// announcements, routing and encrypted delivery over the simulated Bluetooth world, in
/// a line, a star and a mixed Android / iPhone line - and where the hop limit stops it.
///
/// Like every test here it proves the software; it says nothing about real radios.
void main() {
  late FakeBleWorld world;
  final nodes = <FullStackNode>[];

  setUp(() {
    world = FakeBleWorld();
    nodes.clear();
  });

  tearDown(() async {
    for (final n in nodes) {
      await n.dispose();
    }
  });

  Future<FullStackNode> phone(String name, int seed,
      {BlePlatform platform = BlePlatform.android}) async {
    final n = await FullStackNode.create(world, name, seed: seed, platform: platform);
    nodes.add(n);
    return n;
  }

  bool linked(FullStackNode x, FullStackNode y) => x.ble.bluetooth.isNeighbor(y.id);

  /// [count] phones in a line: each hears only the ones next to it.
  Future<List<FullStackNode>> line(int count,
      {List<BlePlatform>? platforms, bool tinyWrites = false}) async {
    final n = [
      for (var i = 0; i < count; i++)
        await phone('P$i', i + 1,
            platform: platforms == null ? BlePlatform.android : platforms[i % platforms.length]),
    ];
    // The BLE minimum: 20 bytes per write, because no phone agrees to a larger one.
    if (tinyWrites) {
      for (final p in n) {
        p.phone.failMtuRequests = true;
      }
    }
    for (var i = 0; i < count; i++) {
      for (var j = i + 2; j < count; j++) {
        world.setInRange(n[i].phone, n[j].phone, false);
      }
    }
    for (final p in n) {
      await p.start();
    }
    await eventually(
      () => [for (var i = 0; i < count - 1; i++) linked(n[i], n[i + 1]) && linked(n[i + 1], n[i])]
          .every((x) => x),
      timeout: const Duration(seconds: 40),
      reason: 'every phone should be linked to the ones next to it',
    );
    return n;
  }

  test('a line of seven phones: the first reaches the last across six links, and the receipt returns',
      () async {
    final n = await line(7);
    expect(linked(n.first, n.last), isFalse);

    final packet = await n.first.sendDirect(n.last, 'across the whole line');
    await eventually(() => n.last.delegate.directs.isNotEmpty, timeout: const Duration(seconds: 40));
    expect(n.last.delegate.directs.single.text, 'across the whole line');
    expect(n.last.delegate.directs.single.relayHops, 5, reason: 'the five phones in between');
    await eventually(() => n.first.delegate.acks.isNotEmpty, timeout: const Duration(seconds: 40));
    expect(n.first.delegate.acks.single.ackedMessageIdsHex.single, packet.messageIdHex);

    // Nobody in between could read it, and each of them got one copy to carry on.
    for (final middle in n.sublist(1, n.length - 1)) {
      expect(middle.delegate.directs, isEmpty);
    }
    expect(world.violations, isEmpty, reason: world.violations.join('\n'));
  });

  test('a line of eight phones: the hop limit stops it at the seventh, and the sender keeps waiting',
      () async {
    final n = await line(8);
    await n.first.sendDirect(n.last, 'one link too far');

    // It travels as far as the limit lets it...
    await eventually(() => n[6].router.stats.hopLimitDrops > 0, timeout: const Duration(seconds: 40),
        reason: 'the seventh phone receives it and may not pass it on');
    await Future<void>.delayed(const Duration(seconds: 2));
    // ...and no further: the last phone has nothing, and so the sender has no receipt.
    expect(n.last.delegate.directs, isEmpty);
    expect(n.first.delegate.acks, isEmpty);
    expect(await n.first.outbox.count(), greaterThan(0), reason: 'the message is still waiting to be delivered');
    expect(world.violations, isEmpty, reason: world.violations.join('\n'));
  });

  test('a star: four phones that cannot hear each other talk through the one in the middle',
      () async {
    final hub = await phone('Hub', 1);
    final spokes = [for (var i = 0; i < 4; i++) await phone('S$i', i + 2)];
    for (var i = 0; i < spokes.length; i++) {
      for (var j = i + 1; j < spokes.length; j++) {
        world.setInRange(spokes[i].phone, spokes[j].phone, false);
      }
    }
    for (final p in [hub, ...spokes]) {
      await p.start();
    }
    await eventually(() => spokes.every((s) => linked(hub, s) && linked(s, hub)),
        timeout: const Duration(seconds: 30), reason: 'every spoke is linked to the hub');

    // Each spoke writes to the next one around: four conversations at once.
    for (var i = 0; i < spokes.length; i++) {
      await spokes[i].sendDirect(spokes[(i + 1) % spokes.length], 'from S$i');
    }
    for (var i = 0; i < spokes.length; i++) {
      final to = spokes[(i + 1) % spokes.length];
      await eventually(() => to.delegate.directs.isNotEmpty, timeout: const Duration(seconds: 30),
          reason: 'S${(i + 1) % spokes.length} should get what S$i wrote');
    }
    await Future<void>.delayed(const Duration(seconds: 1));
    for (var i = 0; i < spokes.length; i++) {
      final to = spokes[(i + 1) % spokes.length];
      expect(to.delegate.directs.length, 1, reason: 'exactly once');
      expect(to.delegate.directs.single.text, 'from S$i');
      expect(to.delegate.directs.single.relayHops, 1, reason: 'one relay: the hub');
    }
    expect(hub.delegate.directs, isEmpty, reason: 'the hub carries four conversations and reads none');
    expect(world.violations, isEmpty, reason: world.violations.join('\n'));
  });

  test('a line of five with iPhones and Android phones alternating, writing 20 bytes at a time',
      () async {
    final n = await line(5, platforms: [BlePlatform.android, BlePlatform.ios], tinyWrites: true);
    final text = 'x' * 600;
    await n.first.sendDirect(n.last, text);
    await eventually(() => n.last.delegate.directs.isNotEmpty, timeout: const Duration(seconds: 90));
    expect(n.last.delegate.directs.single.text, text);
    expect(n.last.delegate.directs.single.relayHops, 3);
    expect(world.violations, isEmpty, reason: world.violations.join('\n'));
  });

  test('the limits the line tests rely on', () {
    // A packet may be relayed while hops < hopLimit: a limit of 5 means five relays at most.
    expect(Protocol.directHopLimit, 5);
    expect(Protocol.maxHopLimit, 7);
    expect(Protocol.announceHopLimit, lessThan(Protocol.directHopLimit),
        reason: 'routes are known a few links away; farther phones are found by flooding');
  });
}
