import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:offline_mesh_chat/models/peer.dart';
import 'package:offline_mesh_chat/protocol/mesh_packet.dart';
import 'package:offline_mesh_chat/protocol/protocol_constants.dart';
import 'package:offline_mesh_chat/services/encryption_service.dart';
import 'package:offline_mesh_chat/services/plugin_ble_radio.dart';

import '../support/fake_ble_world.dart';
import '../support/full_stack_node.dart';
import '../support/radio_harness.dart';

/// End-to-end tests of the whole stack except the UI, over the simulated BLE
/// world: discovery -> connection -> authenticated handshake -> routing ->
/// encrypted multi-hop delivery -> acknowledgement.
///
/// These prove the software logic; they cannot prove the behaviour of real
/// radios. See the README's "What is and is not verified".
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

  Future<FullStackNode> phone(
    String name,
    int seed, {
    BlePlatform platform = BlePlatform.android,
    int maxMtu = 247,
  }) async {
    final n = await FullStackNode.create(world, name,
        seed: seed, platform: platform, maxMtu: maxMtu);
    nodes.add(n);
    return n;
  }

  Future<void> startAll() async {
    for (final n in nodes) {
      await n.start();
    }
  }

  /// A - B - C in a line: A and C cannot hear each other.
  Future<(FullStackNode, FullStackNode, FullStackNode)> line({
    BlePlatform a = BlePlatform.android,
    BlePlatform b = BlePlatform.android,
    BlePlatform c = BlePlatform.android,
  }) async {
    final na = await phone('A', 1, platform: a);
    final nb = await phone('B', 2, platform: b);
    final nc = await phone('C', 3, platform: c);
    world.setInRange(na.phone, nc.phone, false);
    return (na, nb, nc);
  }

  bool linked(FullStackNode x, FullStackNode y) => x.ble.bluetooth.isNeighbor(y.id);

  Future<void> waitForLine(FullStackNode a, FullStackNode b, FullStackNode c) =>
      eventually(() => linked(a, b) && linked(b, a) && linked(b, c) && linked(c, b),
          timeout: const Duration(seconds: 8), reason: 'A-B and B-C should be linked');

  test('three phones: A reaches C through B, and the receipt comes back', () async {
    final (a, b, c) = await line();
    await startAll();
    await waitForLine(a, b, c);
    expect(linked(a, c), isFalse, reason: 'A and C are out of range of each other');

    const secret = 'the-package-is-under-the-old-oak';
    final packet = await a.sendDirect(c, secret);

    await eventually(() => c.delegate.directs.isNotEmpty, timeout: const Duration(seconds: 8));
    expect(c.delegate.directs.single.text, secret);
    expect(c.delegate.directs.single.relayHops, 1, reason: 'exactly one relay: B');
    await eventually(() => a.delegate.acks.isNotEmpty, timeout: const Duration(seconds: 8));
    expect(a.delegate.acks.single.ackedMessageIdsHex.single, packet.messageIdHex);

    // Acceptance: the relay cannot read the message...
    await expectLater(b.crypto.openDirect(packet), throwsA(isA<DecryptionFailure>()));
    expect(b.delegate.directs, isEmpty);
    // ...and the plaintext never appears in anything B handled.
    final seenByB = (await b.outbox.all()).map((e) => e.packet);
    for (final bytes in seenByB) {
      expect(utf8.decode(bytes, allowMalformed: true), isNot(contains(secret)));
    }
    expect(world.violations, isEmpty, reason: world.violations.join('\n'));
  });

  test('once routes are announced, A knows C is reachable through B (and only then)', () async {
    final (a, b, c) = await line();
    await startAll();
    await waitForLine(a, b, c);
    await eventually(() => a.table.statusOf(c.id).reachability == Reachability.relayed,
        timeout: const Duration(seconds: 6), reason: 'an announcement from C must reach A');
    final s = a.table.statusOf(c.id);
    expect(s.hops, 2);
    expect(s.viaPeerId, b.id);

    // Losing the relay removes the claim at once.
    world.setInRange(a.phone, b.phone, false);
    await eventually(() => a.table.statusOf(c.id) == PeerStatus.offline,
        timeout: const Duration(seconds: 4));
  });

  test('delayed delivery: B carries the message until C comes into range', () async {
    final (a, b, c) = await line();
    world.setInRange(b.phone, c.phone, false); // C is nowhere near anybody yet
    await startAll();
    await eventually(() => linked(a, b) && linked(b, a), timeout: const Duration(seconds: 6));

    await a.sendDirect(c, 'catch up when you can');
    await eventually(() => b.outbox.count().then((n) => n == 1),
        reason: 'B should be holding the message');
    expect(c.delegate.directs, isEmpty);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    expect(c.delegate.directs, isEmpty);

    world.setInRange(b.phone, c.phone, true); // C walks into range of B
    await eventually(() => c.delegate.directs.isNotEmpty, timeout: const Duration(seconds: 10));
    expect(c.delegate.directs.single.text, 'catch up when you can');
    await eventually(() => a.delegate.acks.isNotEmpty, timeout: const Duration(seconds: 8));
  });

  test('a message composed with nobody around is sent as soon as somebody appears', () async {
    final a = await phone('A', 1);
    final b = await phone('B', 2);
    world.setInRange(a.phone, b.phone, false);
    await startAll();
    await a.sendDirect(b, 'pending message');
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(a.delegate.ownSent, isEmpty, reason: 'nothing could be sent yet: it is pending');
    expect(await a.queue.size(), 1);

    world.setInRange(a.phone, b.phone, true);
    await eventually(() => b.delegate.directs.isNotEmpty, timeout: const Duration(seconds: 10));
    expect(b.delegate.directs.single.text, 'pending message');
    await eventually(() => a.delegate.acks.isNotEmpty, timeout: const Duration(seconds: 8));
    await eventually(() => a.queue.size().then((n) => n == 0));
  });

  test('Bluetooth switched off on the relay mid-conversation: no message is lost', () async {
    final (a, b, c) = await line();
    await startAll();
    await waitForLine(a, b, c);

    b.phone.setBluetooth(false);
    await eventually(() => !linked(a, b) && !linked(c, b));
    await a.sendDirect(c, 'sent while the relay was down');
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(c.delegate.directs, isEmpty);

    b.phone.setBluetooth(true);
    await eventually(() => c.delegate.directs.isNotEmpty, timeout: const Duration(seconds: 15));
    expect(c.delegate.directs.single.text, 'sent while the relay was down');
  });

  test('many messages all arrive exactly once', () async {
    final (a, b, c) = await line();
    await startAll();
    await waitForLine(a, b, c);
    for (var i = 0; i < 12; i++) {
      await a.sendDirect(c, 'message number $i');
    }
    await eventually(() => c.delegate.directs.length >= 12, timeout: const Duration(seconds: 20));
    await Future<void>.delayed(const Duration(milliseconds: 600)); // let any stray duplicates show
    final texts = c.delegate.directs.map((d) => d.text).toList();
    expect(texts.toSet().length, 12, reason: 'no duplicates: $texts');
    expect(texts.length, 12);
    await eventually(() => a.delegate.acks.length == 12, timeout: const Duration(seconds: 20));
    expect(world.violations, isEmpty, reason: world.violations.join('\n'));
  });

  test('works across mixed Android / iOS phones', () async {
    final (a, b, c) = await line(a: BlePlatform.ios, b: BlePlatform.android, c: BlePlatform.ios);
    await startAll();
    await waitForLine(a, b, c);
    await a.sendDirect(c, 'iPhone to iPhone through an Android relay');
    await eventually(() => c.delegate.directs.isNotEmpty, timeout: const Duration(seconds: 10));
    expect(c.delegate.directs.single.text, 'iPhone to iPhone through an Android relay');
    expect(world.violations, isEmpty, reason: world.violations.join('\n'));
  });

  test('a full-size message crosses two hops with tiny 20-byte writes', () async {
    final (a, b, c) = await line();
    for (final n in [a, b, c]) {
      n.phone.failMtuRequests = true; // the BLE minimum: 20 bytes per write
    }
    await startAll();
    await waitForLine(a, b, c);
    final text = 'x' * Protocol.maxTextBytes;
    await a.sendDirect(c, text);
    await eventually(() => c.delegate.directs.isNotEmpty, timeout: const Duration(seconds: 25));
    expect(c.delegate.directs.single.text, text);
  });

  test('a four-phone ring still delivers each message once', () async {
    final a = await phone('A', 1);
    final b = await phone('B', 2);
    final c = await phone('C', 3);
    final d = await phone('D', 4);
    // A-B-C-D-A ring; the diagonals are out of range.
    world.setInRange(a.phone, c.phone, false);
    world.setInRange(b.phone, d.phone, false);
    await startAll();
    await eventually(
        () => linked(a, b) && linked(b, c) && linked(c, d) && linked(d, a),
        timeout: const Duration(seconds: 10));
    await a.sendDirect(c, 'around the ring');
    await eventually(() => c.delegate.directs.isNotEmpty, timeout: const Duration(seconds: 10));
    await Future<void>.delayed(const Duration(milliseconds: 800));
    expect(c.delegate.directs.length, 1);
    expect(MeshPacket.decode(c.delegate.directs.single.packet.encode()).hops, lessThanOrEqualTo(2));
  });

  test('every control path used by the radio respects the plugin contract', () async {
    final (a, b, c) = await line();
    await startAll();
    await waitForLine(a, b, c);
    await a.sendDirect(c, 'contract check');
    await eventually(() => a.delegate.acks.isNotEmpty, timeout: const Duration(seconds: 10));
    b.phone.dropConnectionsTo(c.phone);
    await eventually(() => !linked(b, c));
    await eventually(() => linked(b, c), timeout: const Duration(seconds: 10));
    expect(world.violations, isEmpty, reason: world.violations.join('\n'));
    final unused = Uint8List(0);
    expect(unused, isEmpty);
  });
}
