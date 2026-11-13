import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:offline_mesh_chat/core/app_log.dart';
import 'package:offline_mesh_chat/core/bytes.dart';
import 'package:offline_mesh_chat/crypto/key_store.dart';
import 'package:offline_mesh_chat/protocol/fragmenter.dart';
import 'package:offline_mesh_chat/protocol/link_frame.dart';
import 'package:offline_mesh_chat/protocol/protocol_constants.dart';
import 'package:offline_mesh_chat/services/bluetooth_service.dart';
import 'package:offline_mesh_chat/services/encryption_service.dart';
import 'package:offline_mesh_chat/services/plugin_ble_radio.dart';
import 'package:offline_mesh_chat/transport/ble_radio.dart';
import 'package:offline_mesh_chat/transport/mesh_transport.dart';

import '../support/ble_stack.dart';
import '../support/fake_ble_world.dart';
import '../support/radio_harness.dart';

void main() {
  late FakeBleWorld world;
  final nodes = <BleNode>[];
  final rogues = <RogueDevice>[];

  setUp(() {
    world = FakeBleWorld();
    nodes.clear();
    rogues.clear();
  });

  tearDown(() async {
    for (final n in nodes) {
      await n.dispose();
    }
    for (final r in rogues) {
      await r.dispose();
    }
  });

  Future<BleNode> node(
    String name, {
    int seed = 1,
    BlePlatform platform = BlePlatform.android,
    int maxMtu = 247,
    BluetoothServiceConfig service = fastService,
    KeyStore? keys,
  }) async {
    final n = await BleNode.create(world, name,
        seed: seed, platform: platform, maxMtu: maxMtu, service: service, keys: keys);
    nodes.add(n);
    return n;
  }

  Future<RogueDevice> rogue(String name) async {
    final r = await RogueDevice.create(world, name);
    rogues.add(r);
    return r;
  }

  /// Connects [victim] (as central) to a rogue's device, without the policy.
  Future<String> connectTo(BleNode victim, RogueDevice r) async {
    await victim.radio.startScan();
    final target = r.phone.deviceUuid.toString();
    final heard = Completer<void>();
    final sub = victim.radio.discoveries.listen((d) {
      if (d.deviceId == target && !heard.isCompleted) heard.complete();
    });
    await heard.future.timeout(const Duration(seconds: 2));
    await sub.cancel();
    return victim.bluetooth.connectTo(target);
  }

  group('handshake', () {
    test('two phones find each other, prove their identities, and become neighbours', () async {
      final a = await node('A', seed: 1);
      final b = await node('B', seed: 2);
      await a.start();
      await b.start();
      // Both phones may connect to each other at the same instant; wait until
      // the redundant second link is gone so the roles below are settled.
      await waitStableLink(a, b);

      expect(a.ups.single.peerId, b.id);
      expect(b.ups.single.peerId, a.id);
      expect(a.ups.single.signingKey, b.crypto.identity.signingPublicKey);
      expect(a.ups.single.agreementKey, b.crypto.identity.agreementPublicKey);
      expect(a.ups.single.nickname, 'B');
      expect(b.ups.single.nickname, 'A');
      // On the surviving link one side is the central, the other the peripheral
      // (read from the live neighbour list: the first-up event may describe a
      // link that was replaced a moment later).
      expect({a.bluetooth.neighbors.single.role, b.bluetooth.neighbors.single.role},
          {LinkRole.central, LinkRole.peripheral});
      expect(world.violations, isEmpty, reason: world.violations.join('\n'));
      expect(a.securityEvents, isEmpty);
      expect(b.securityEvents, isEmpty);
    });

    test('works for every Android / iOS combination', () async {
      for (final (pa, pb) in [
        (BlePlatform.android, BlePlatform.android),
        (BlePlatform.android, BlePlatform.ios),
        (BlePlatform.ios, BlePlatform.android),
        (BlePlatform.ios, BlePlatform.ios),
      ]) {
        final w = FakeBleWorld();
        final a = await BleNode.create(w, 'A', seed: 1, platform: pa);
        final b = await BleNode.create(w, 'B', seed: 2, platform: pb);
        await a.start();
        await b.start();
        await waitLinked(a, b);
        await a.bluetooth.sendPacket(b.id, sampleBytes(300));
        await b.bluetooth.sendPacket(a.id, sampleBytes(300, 5));
        await eventually(() => a.packets.isNotEmpty && b.packets.isNotEmpty,
            reason: '$pa <-> $pb');
        expect(b.packets.single.$2, sampleBytes(300));
        expect(a.packets.single.$2, sampleBytes(300, 5));
        expect(w.violations, isEmpty, reason: '$pa <-> $pb: ${w.violations.join('\n')}');
        await a.dispose();
        await b.dispose();
      }
    });

    test('nicknames from the network are cleaned before use', () async {
      final a = await node('A', seed: 1);
      final b = await BleNode.create(world, 'B',
          seed: 2, nickname: 'Evil\u202Egnp.exe\u0000 ');
      nodes.add(b);
      await a.start();
      await b.start();
      await waitLinked(a, b);
      expect(a.ups.single.nickname, 'Evilgnp.exe');
    });

    test('a phone claiming another phone\'s key without owning it is rejected', () async {
      final victim = await node('Victim', seed: 1);
      await victim.start(discover: false);
      final alice = await EncryptionService.loadOrCreate(MemoryKeyStore(), random: Random(55));
      final r = await rogue('Rogue');

      final linkId = await connectTo(victim, r);
      await eventually(() => r.links.isNotEmpty, reason: 'rogue should see the link');
      // The rogue claims to be Alice but cannot sign as her.
      await r.send(
        r.links.first,
        HelloFrame(
          protocolVersion: Protocol.version,
          signingKey: alice.identity.signingPublicKey,
          agreementKey: alice.identity.agreementPublicKey,
          nonce: Uint8List(16)..fillRange(0, 16, 9),
          nickname: 'Alice',
        ),
      );
      await r.send(r.links.first, AuthFrame(Uint8List(64)..fillRange(0, 64, 7)));

      await eventually(() => victim.securityEvents.contains('link_auth_failed'));
      await eventually(() => !victim.bluetooth.hasLink(linkId));
      expect(victim.ups, isEmpty);
      expect(victim.bluetooth.isNeighbor(alice.identity.id), isFalse);
      // The victim told the rogue why.
      await eventually(() => r.received.whereType<ByeFrame>().isNotEmpty);
      expect(r.received.whereType<ByeFrame>().first.reason, ByeReason.authFailed);
    });

    test('a proof signed by some OTHER key than the claimed one is rejected', () async {
      final victim = await node('Victim', seed: 1);
      await victim.start(discover: false);
      final claimed = await EncryptionService.loadOrCreate(MemoryKeyStore(), random: Random(60));
      final attacker = await EncryptionService.loadOrCreate(MemoryKeyStore(), random: Random(61));
      final r = await rogue('Rogue');
      await connectTo(victim, r);
      await eventually(() => r.links.isNotEmpty);
      await eventually(() => r.received.whereType<HelloFrame>().isNotEmpty);
      final victimHello = r.received.whereType<HelloFrame>().first;

      final rogueNonce = Uint8List(16)..fillRange(0, 16, 3);
      await r.send(
        r.links.first,
        HelloFrame(
          protocolVersion: Protocol.version,
          signingKey: claimed.identity.signingPublicKey,
          agreementKey: claimed.identity.agreementPublicKey,
          nonce: rogueNonce,
          nickname: 'Claimed',
        ),
      );
      // A perfectly formed proof - but made with the attacker's key.
      final forged = await attacker.signLinkAuth(
        verifierNonce: victimHello.nonce,
        proverNonce: rogueNonce,
        verifierSigningKey: victimHello.signingKey,
        nickname: 'Claimed',
      );
      await r.send(r.links.first, AuthFrame(forged));
      await eventually(() => victim.securityEvents.contains('link_auth_failed'));
      expect(victim.ups, isEmpty);
    });

    test('a peer speaking another protocol version is turned away', () async {
      final victim = await node('Victim', seed: 1);
      await victim.start(discover: false);
      final other = await EncryptionService.loadOrCreate(MemoryKeyStore(), random: Random(70));
      final r = await rogue('Rogue');
      final linkId = await connectTo(victim, r);
      await eventually(() => r.links.isNotEmpty);
      await r.send(
        r.links.first,
        HelloFrame(
          protocolVersion: 99,
          signingKey: other.identity.signingPublicKey,
          agreementKey: other.identity.agreementPublicKey,
          nonce: Uint8List(16),
          nickname: 'Future',
        ),
      );
      await eventually(() => !victim.bluetooth.hasLink(linkId));
      expect(victim.securityEvents, contains('protocol_error'));
      expect(victim.ups, isEmpty);
      // It is remembered, so the person can be told one of the two needs an update.
      final seen = victim.bluetooth.versionMismatches.single;
      expect(seen.version, 99);
      expect(seen.peerIsNewer, isTrue);
      expect(seen.deviceId, r.phone.deviceUuid.toString());
      expect(victim.bluetooth.otherVersionSeenAt(seen.deviceId), seen.atMs);
      // The other phone is told why.
      await eventually(() => r.received.whereType<ByeFrame>().isNotEmpty);
      expect(r.received.whereType<ByeFrame>().first.reason, ByeReason.protocolError);
    });

    test('an older phone is remembered as older, and calling again is not logged again', () async {
      final victim = await node('Victim', seed: 1);
      await victim.start(discover: false);
      final r = await rogue('Old');
      for (var round = 0; round < 2; round++) {
        final before = r.links.length;
        final linkId = await connectTo(victim, r);
        await eventually(() => r.links.length > before);
        final rogueLink = r.links.last;
        // An old version's HELLO: only its first byte is ever read.
        await r.sendBytes(rogueLink, [LinkFrameType.hello.code, Protocol.version - 1, 0]);
        await eventually(() => !victim.bluetooth.hasLink(linkId));
        await eventually(() => r.closedLinks.contains(rogueLink));
      }
      expect(victim.bluetooth.versionMismatches, hasLength(2));
      expect(victim.bluetooth.versionMismatches.every((m) => !m.peerIsNewer), isTrue);
      expect(victim.securityEvents.where((e) => e == 'protocol_error'), hasLength(1));
    });

    test('packets before the handshake completes are never passed upwards', () async {
      final victim = await node('Victim', seed: 1);
      await victim.start(discover: false);
      final r = await rogue('Rogue');
      final linkId = await connectTo(victim, r);
      await eventually(() => r.links.isNotEmpty);
      for (var i = 0; i < 8; i++) {
        try {
          await r.send(r.links.first, PacketFrame(sampleBytes(200, i)));
        } on RadioException {
          break; // the victim already hung up
        }
      }
      await eventually(() => !victim.bluetooth.hasLink(linkId));
      expect(victim.packets, isEmpty);
    });

    test('a phone that never answers the handshake is dropped', () async {
      final victim = await node('Victim', seed: 1);
      await victim.start(discover: false);
      final r = await rogue('Silent');
      final linkId = await connectTo(victim, r);
      await eventually(() => victim.bluetooth.hasLink(linkId));
      await eventually(() => !victim.bluetooth.hasLink(linkId),
          timeout: const Duration(seconds: 4), reason: 'handshake timeout');
      expect(victim.ups, isEmpty);
    });

    test('connecting to a phone with the same identity is refused', () async {
      final shared = MemoryKeyStore();
      final a = await node('A', seed: 1, keys: shared);
      final b = await node('B', seed: 1, keys: shared); // same identity
      expect(a.id, b.id);
      await a.start();
      await b.start();
      await Future<void>.delayed(const Duration(milliseconds: 600));
      expect(a.ups, isEmpty);
      expect(b.ups, isEmpty);
    });

    test('too many half-open links are refused', () async {
      const config = BluetoothServiceConfig(
        maxUnauthenticated: 2,
        handshakeTimeout: Duration(seconds: 5),
        maintenanceInterval: Duration(milliseconds: 100),
      );
      final victim = await node('Victim', seed: 1, service: config);
      await victim.start(discover: false);
      final silent = [for (var i = 0; i < 4; i++) await rogue('S$i')];
      final results = <bool>[];
      for (final r in silent) {
        try {
          final linkId = await connectTo(victim, r);
          await Future<void>.delayed(const Duration(milliseconds: 30));
          results.add(victim.bluetooth.hasLink(linkId));
        } on Object {
          results.add(false);
        }
      }
      expect(victim.bluetooth.linkCount, lessThanOrEqualTo(2));
    });
  });

  group('data over a link', () {
    late BleNode a;
    late BleNode b;

    Future<void> linkUp({int maxMtu = 247}) async {
      a = await node('A', seed: 1, maxMtu: maxMtu);
      b = await node('B', seed: 2, maxMtu: maxMtu);
      await a.start();
      await b.start();
      await waitStableLink(a, b);
    }

    test('packets of many sizes arrive intact in both directions', () async {
      await linkUp();
      for (final size in [1, 20, 100, 500, 1500, Protocol.maxPacketBytes]) {
        final before = b.packets.length;
        expect(await a.bluetooth.sendPacket(b.id, sampleBytes(size, size)), isTrue);
        await eventually(() => b.packets.length == before + 1);
        expect(b.packets.last.$2, sampleBytes(size, size), reason: 'a -> b, $size bytes');
        expect(b.packets.last.$1, a.id);
      }
      for (final size in [1, 333, 2000]) {
        final before = a.packets.length;
        expect(await b.bluetooth.sendPacket(a.id, sampleBytes(size, 99)), isTrue);
        await eventually(() => a.packets.length == before + 1);
        expect(a.packets.last.$2, sampleBytes(size, 99), reason: 'b -> a, $size bytes');
      }
      expect(world.violations, isEmpty, reason: world.violations.join('\n'));
    });

    test('even with the minimum 20-byte writes (no MTU negotiated)', () async {
      a = await node('A', seed: 1);
      b = await node('B', seed: 2);
      a.phone.failMtuRequests = true;
      b.phone.failMtuRequests = true;
      await a.start();
      await b.start();
      await waitStableLink(a, b);
      expect(a.bluetooth.linkSnapshots.single.maxChunk, 20);
      expect(await a.bluetooth.sendPacket(b.id, sampleBytes(900)), isTrue);
      await eventually(() => b.packets.isNotEmpty, timeout: const Duration(seconds: 8));
      expect(b.packets.single.$2, sampleBytes(900));
      expect(world.violations, isEmpty, reason: world.violations.join('\n'));
    });

    test('simultaneous transfers in both directions do not corrupt each other', () async {
      await linkUp();
      final futures = <Future<bool>>[
        for (var i = 0; i < 10; i++) a.bluetooth.sendPacket(b.id, sampleBytes(700, i)),
        for (var i = 0; i < 10; i++) b.bluetooth.sendPacket(a.id, sampleBytes(700, 50 + i)),
      ];
      expect(await Future.wait(futures), everyElement(isTrue));
      await eventually(() => a.packets.length == 10 && b.packets.length == 10,
          timeout: const Duration(seconds: 8));
      for (var i = 0; i < 10; i++) {
        expect(b.packets[i].$2, sampleBytes(700, i), reason: 'a->b #$i (order preserved)');
        expect(a.packets[i].$2, sampleBytes(700, 50 + i), reason: 'b->a #$i');
      }
      expect(world.violations, isEmpty, reason: world.violations.join('\n'));
    });

    test('sending to someone who is not a neighbour fails cleanly', () async {
      await linkUp();
      expect(await a.bluetooth.sendPacket('ab' * 32, sampleBytes(10)), isFalse);
      expect(await a.bluetooth.sendPacket(b.id, Uint8List(Protocol.maxPacketBytes + 1)), isFalse);
    });

    test('a round-trip probe measures delivery and latency, including fragmented payloads',
        () async {
      await linkUp();
      final r = await a.bluetooth.probe(b.id, count: 4, payloadBytes: 700);
      expect(r.passed, isTrue, reason: r.error);
      expect(r.received, 4);
      expect(r.rttMs.length, 4);
      expect(r.minMs, isNotNull);
      expect(a.bluetooth.linkSnapshots.single.lastRttMs, isNotNull);
    });

    test('probing a phone without a link reports an error instead of hanging', () async {
      await linkUp();
      final r = await a.bluetooth.probe('cd' * 32);
      expect(r.passed, isFalse);
      expect(r.error, isNotNull);
    });

    test('link statistics are kept', () async {
      await linkUp();
      await a.bluetooth.sendPacket(b.id, sampleBytes(400));
      await eventually(() => b.packets.isNotEmpty);
      final s = a.bluetooth.linkSnapshots.single;
      expect(s.phase, LinkPhase.ready);
      expect(s.framesOut, greaterThanOrEqualTo(3)); // hello, auth, packet
      expect(s.bytesOut, greaterThan(400));
      expect(s.peerId, b.id);
    });
  });

  group('two links to one phone', () {
    test('mutual simultaneous connects leave exactly one link, and both phones agree on it',
        () async {
      final a = await node('A', seed: 1);
      final b = await node('B', seed: 2);
      await a.start(discover: false);
      await b.start(discover: false);
      // Each hears the other, then BOTH connect at the same instant.
      await Future.wait([a.radio.startScan(), b.radio.startScan()]);
      final aHeardB = Completer<void>();
      final bHeardA = Completer<void>();
      final s1 = a.radio.discoveries.listen((d) {
        if (d.deviceId == b.phone.deviceUuid.toString() && !aHeardB.isCompleted) aHeardB.complete();
      });
      final s2 = b.radio.discoveries.listen((d) {
        if (d.deviceId == a.phone.deviceUuid.toString() && !bHeardA.isCompleted) bHeardA.complete();
      });
      await Future.wait([aHeardB.future, bHeardA.future]).timeout(const Duration(seconds: 2));
      await s1.cancel();
      await s2.cancel();

      await Future.wait([
        a.bluetooth.connectTo(b.phone.deviceUuid.toString()),
        b.bluetooth.connectTo(a.phone.deviceUuid.toString()),
      ]);
      await waitLinked(a, b);
      await eventually(() => a.bluetooth.linkCount == 1 && b.bluetooth.linkCount == 1,
          reason: 'the redundant link must be closed on both sides');

      // No flapping: the neighbour went up exactly once and never down.
      expect(a.ups.length, 1);
      expect(b.ups.length, 1);
      expect(a.downs, isEmpty);
      expect(b.downs, isEmpty);

      // They kept the SAME link: the one where the phone with the smaller key is central.
      final aSmaller = compareBytes(a.crypto.identity.signingPublicKey, b.crypto.identity.signingPublicKey) < 0;
      final aRole = a.bluetooth.linkSnapshots.single.role;
      final bRole = b.bluetooth.linkSnapshots.single.role;
      expect(aRole == LinkRole.central, aSmaller);
      expect(bRole == LinkRole.central, !aSmaller);

      // And it works.
      expect(await a.bluetooth.sendPacket(b.id, sampleBytes(120)), isTrue);
      expect(await b.bluetooth.sendPacket(a.id, sampleBytes(130)), isTrue);
      await eventually(() => a.packets.isNotEmpty && b.packets.isNotEmpty);
      expect(world.violations, isEmpty, reason: world.violations.join('\n'));
    });

    test('the same holds when one phone is an iOS peripheral that cannot drop a central',
        () async {
      final a = await node('A', seed: 1);
      final b = await node('B', seed: 2, platform: BlePlatform.ios);
      await a.start(discover: false);
      await b.start(discover: false);
      await Future.wait([a.radio.startScan(), b.radio.startScan()]);
      await eventually(() => a.radio.isScanning && b.radio.isScanning);
      final heard = <String>{};
      final subs = [
        a.radio.discoveries.listen((d) => heard.add('a:${d.deviceId}')),
        b.radio.discoveries.listen((d) => heard.add('b:${d.deviceId}')),
      ];
      await eventually(() =>
          heard.contains('a:${b.phone.deviceUuid}') && heard.contains('b:${a.phone.deviceUuid}'));
      for (final s in subs) {
        await s.cancel();
      }
      await Future.wait([
        a.bluetooth.connectTo(b.phone.deviceUuid.toString()),
        b.bluetooth.connectTo(a.phone.deviceUuid.toString()),
      ]);
      await waitLinked(a, b);
      await eventually(() => a.bluetooth.linkCount == 1 && b.bluetooth.linkCount == 1,
          reason: 'BYE frames must close what the platform cannot');
      expect(a.downs, isEmpty);
      expect(b.downs, isEmpty);
    });

    test('automatic discovery never rebuilds the duplicate after it was closed', () async {
      final a = await node('A', seed: 1);
      final b = await node('B', seed: 2);
      await a.start();
      await b.start();
      await waitLinked(a, b);
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      final connects = world.calls.where((c) => c.contains('central.connect(')).length;
      expect(connects, lessThanOrEqualTo(2),
          reason: 'only the initial attempt(s); no reconnect loop. Calls: ${world.calls}');
      expect(a.bluetooth.linkCount, 1);
      expect(b.bluetooth.linkCount, 1);
    });
  });

  group('keepalive and loss', () {
    test('an idle but healthy link stays up, kept alive by pings', () async {
      final a = await node('A', seed: 1);
      final b = await node('B', seed: 2);
      await a.start();
      await b.start();
      await waitLinked(a, b);
      // More than twice the dead-link timeout (1.5 s), with no traffic.
      await Future<void>.delayed(const Duration(milliseconds: 3400));
      expect(a.linkedTo(b), isTrue);
      expect(b.linkedTo(a), isTrue);
      expect(a.downs, isEmpty);
      expect(a.bluetooth.linkSnapshots.single.lastRttMs, isNotNull,
          reason: 'keepalive pings should have produced a round-trip time');
    });

    test('a link whose far end froze is detected and closed on both sides', () async {
      final a = await node('A', seed: 1);
      final b = await node('B', seed: 2);
      await a.start();
      await b.start();
      await waitLinked(a, b);
      world.blackhole(a.phone, b.phone, true);
      await eventually(() => a.downs.isNotEmpty && b.downs.isNotEmpty,
          timeout: const Duration(seconds: 6));
      expect(a.bluetooth.isNeighbor(b.id), isFalse);
    });

    test('moving out of range ends the neighbourhood; coming back restores it', () async {
      final a = await node('A', seed: 1);
      final b = await node('B', seed: 2);
      await a.start();
      await b.start();
      await waitLinked(a, b);

      world.setInRange(a.phone, b.phone, false);
      await eventually(() => a.downs.isNotEmpty && b.downs.isNotEmpty,
          timeout: const Duration(seconds: 6));
      expect(a.linkedTo(b), isFalse, reason: 'out of range: no link can exist');

      world.setInRange(a.phone, b.phone, true);
      await waitLinked(a, b, timeout: const Duration(seconds: 10));
      expect(a.ups.length, greaterThanOrEqualTo(2), reason: 'up, down, and up again');
      expect(await a.bluetooth.sendPacket(b.id, sampleBytes(64)), isTrue);
      await eventually(() => b.packets.isNotEmpty);
    });

    test('switching Bluetooth off and on reconnects without any user action', () async {
      final a = await node('A', seed: 1);
      final b = await node('B', seed: 2);
      await a.start();
      await b.start();
      await waitLinked(a, b);

      b.phone.setBluetooth(false);
      await eventually(() => a.downs.isNotEmpty && b.downs.isNotEmpty);

      b.phone.setBluetooth(true);
      await eventually(() => b.phone.hasMeshService && b.phone.isAdvertising,
          reason: 'service and advertising must be rebuilt');
      await waitLinked(a, b, timeout: const Duration(seconds: 8));
      expect(await a.bluetooth.sendPacket(b.id, sampleBytes(64)), isTrue);
      await eventually(() => b.packets.isNotEmpty);
    });

    test('repeated disconnect / reconnect cycles stay healthy', () async {
      final a = await node('A', seed: 1);
      final b = await node('B', seed: 2);
      await a.start();
      await b.start();
      await waitLinked(a, b);
      for (var i = 0; i < 4; i++) {
        a.phone.dropConnectionsTo(b.phone);
        // Wait for the recorded NeighborDown events, not for the "not linked"
        // state: automatic discovery may reconnect so fast that the gap is
        // never seen between two polls on a busy machine.
        await eventually(() => a.downs.length > i && b.downs.length > i,
            timeout: const Duration(seconds: 6), reason: 'cycle $i: drop');
        await waitLinked(a, b, timeout: const Duration(seconds: 10));
        expect(await a.bluetooth.sendPacket(b.id, sampleBytes(80, i)), isTrue);
        await eventually(() => b.packets.length == i + 1, timeout: const Duration(seconds: 6));
      }
      expect(world.violations, isEmpty, reason: world.violations.join('\n'));
    });
  });

  group('capacity', () {
    test('a phone does not open more outgoing links than configured', () async {
      const small = BluetoothServiceConfig(
        maxLinks: 1,
        extraIncomingLinks: 0,
        handshakeTimeout: Duration(seconds: 2),
        maintenanceInterval: Duration(milliseconds: 40),
      );
      final a = await node('A', seed: 1, service: small);
      final b = await node('B', seed: 2);
      final c = await node('C', seed: 3);
      await a.start();
      await b.start();
      await c.start();
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      // A may have linked to one of them (as central), but never exceeds one link.
      expect(a.bluetooth.linkCount, lessThanOrEqualTo(1));
    });
  });

  group('robustness of the service itself', () {
    test('data that arrives before the link-opened event is not lost', () async {
      final radio = _StubRadio();
      final crypto = await EncryptionService.loadOrCreate(MemoryKeyStore(), random: Random(1));
      final remote = await EncryptionService.loadOrCreate(MemoryKeyStore(), random: Random(2));
      final service = BluetoothService(
        radio: radio,
        crypto: crypto,
        nickname: () => 'Local',
        config: fastService,
        log: AppLog(echo: false),
      );
      await service.start();

      final hello = HelloFrame(
        protocolVersion: Protocol.version,
        signingKey: remote.identity.signingPublicKey,
        agreementKey: remote.identity.agreementPublicKey,
        nonce: Uint8List(16)..fillRange(0, 16, 4),
        nickname: 'Remote',
      );
      // The remote's HELLO beats the link-opened event.
      for (final c in FrameChunker.split(hello.encode(), frameId: 1, maxChunk: 60)) {
        radio.emitChunk(RadioChunk('p:remote', c));
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
      radio.emitLink(const RadioLinkOpened(
          linkId: 'p:remote', role: LinkRole.peripheral, deviceId: 'remote', maxChunk: 60));

      // The service must have processed it: it answers with its own HELLO and AUTH.
      await eventually(() => radio.sentFrames.whereType<AuthFrame>().isNotEmpty);
      expect(radio.sentFrames.whereType<HelloFrame>(), isNotEmpty);
      await service.dispose();
      await radio.dispose();
    });
  });
}

/// A radio that records what the service sends and lets a test inject events,
/// for exercising the service without the simulated BLE world.
class _StubRadio implements BleRadio {
  final StreamController<RadioLinkEvent> _links = StreamController<RadioLinkEvent>.broadcast();
  final StreamController<RadioChunk> _chunks = StreamController<RadioChunk>.broadcast();
  final StreamController<RadioStatus> _status = StreamController<RadioStatus>.broadcast();
  final StreamController<RadioDiscovery> _disc = StreamController<RadioDiscovery>.broadcast();
  final Map<String, FrameReassembler> _re = <String, FrameReassembler>{};
  final List<LinkFrame> sentFrames = <LinkFrame>[];

  void emitChunk(RadioChunk c) => _chunks.add(c);

  void emitLink(RadioLinkEvent e) => _links.add(e);

  @override
  RadioStatus get status => const RadioStatus(
      central: RadioAvailability.poweredOn, peripheral: RadioAvailability.poweredOn);

  @override
  Stream<RadioStatus> get statusChanges => _status.stream;

  @override
  Stream<RadioDiscovery> get discoveries => _disc.stream;

  @override
  Stream<RadioLinkEvent> get linkEvents => _links.stream;

  @override
  Stream<RadioChunk> get chunks => _chunks.stream;

  @override
  bool get isAdvertising => false;

  @override
  bool get isScanning => false;

  @override
  String? get lastError => null;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> requestPermissions() async {}

  @override
  Future<void> openAppSettings() async {}

  @override
  Future<void> startAdvertising() async {}

  @override
  Future<void> stopAdvertising() async {}

  @override
  Future<void> startScan() async {}

  @override
  Future<void> stopScan() async {}

  @override
  Future<String> connect(String deviceId, {Duration timeout = const Duration(seconds: 20)}) =>
      throw UnimplementedError();

  @override
  Future<void> sendChunk(String linkId, Uint8List chunk) async {
    final frame = _re.putIfAbsent(linkId, FrameReassembler.new).add(chunk);
    if (frame != null) sentFrames.add(LinkFrame.decode(frame));
  }

  @override
  Future<void> disconnect(String linkId) async {}

  @override
  int maxChunkSize(String linkId) => 60;

  @override
  Future<int?> readRssi(String linkId) async => null;

  @override
  Future<void> dispose() async {
    await _links.close();
    await _chunks.close();
    await _status.close();
    await _disc.close();
  }
}
