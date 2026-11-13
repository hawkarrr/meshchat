import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:offline_mesh_chat/core/bytes.dart';
import 'package:offline_mesh_chat/crypto/key_store.dart';
import 'package:offline_mesh_chat/mesh/mesh_router.dart';
import 'package:offline_mesh_chat/mesh/message_queue.dart';
import 'package:offline_mesh_chat/models/peer.dart';
import 'package:offline_mesh_chat/protocol/mesh_packet.dart';
import 'package:offline_mesh_chat/services/encryption_service.dart';

import '../support/fake_clock.dart';
import '../support/memory_network.dart';
import '../support/test_database.dart';
import '../support/test_node.dart';

bool _contains(Uint8List haystack, List<int> needle) {
  for (var i = 0; i + needle.length <= haystack.length; i++) {
    var ok = true;
    for (var j = 0; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) {
        ok = false;
        break;
      }
    }
    if (ok) return true;
  }
  return false;
}

void main() {
  late MemoryNetwork net;
  late FakeClock clock;
  final nodes = <TestNode>[];

  setUp(() {
    net = MemoryNetwork();
    clock = FakeClock(1700000000000);
    nodes.clear();
  });

  tearDown(() async {
    for (final n in nodes) {
      await n.close();
    }
  });

  Future<TestNode> mk(
    String name,
    int seed, {
    QueueConfig queue = const QueueConfig(),
    MeshRouterConfig config = const MeshRouterConfig(autoTimers: false),
    int floodFanout = 4,
  }) async {
    final n = await TestNode.create(name, net, clock,
        seed: seed, queueConfig: queue, routerConfig: config, floodFanout: floodFanout);
    nodes.add(n);
    return n;
  }

  Future<void> run() => settle(net, nodes);

  Future<void> connect(List<(TestNode, TestNode)> pairs) => link(net, nodes, pairs);

  List<Delivery> ofType(PacketType t) =>
      net.log.where((d) => MeshPacket.decode(d.bytes).type == t).toList();

  group('direct neighbours', () {
    test('a message crosses one link, is decrypted, and the receipt comes back', () async {
      final a = await mk('a', 1);
      final b = await mk('b', 2);
      await connect([(a, b)]);

      final sent = await a.sendDirect(b, 'hello b');
      await run();

      expect(b.delegate.directs.single.text, 'hello b');
      expect(b.delegate.directs.single.relayHops, 0);
      expect(a.delegate.ownSent.single.messageIdHex, sent.messageIdHex);
      expect(a.delegate.acks.single.ackedMessageIdsHex.single, sent.messageIdHex);
      expect(a.delegate.ackHops.single, 0);
      // Everything is cleaned up once acknowledged.
      expect(await a.queue.size(), 0);
      expect(await b.queue.size(), 0);
    });

    test('a message sent while the recipient is out of range stays pending', () async {
      final a = await mk('a', 1);
      final b = await mk('b', 2);
      await a.sendDirect(b, 'anyone there?');
      await run();
      expect(await a.queue.size(), 1);
      expect(a.delegate.ownSent, isEmpty); // handed to nobody: "pending"
      expect(net.log, isEmpty);
    });

    test('it is delivered as soon as the recipient comes into range', () async {
      final a = await mk('a', 1);
      final b = await mk('b', 2);
      await a.sendDirect(b, 'waiting for you');
      await run();
      await connect([(a, b)]);
      expect(b.delegate.directs.single.text, 'waiting for you');
      expect(a.delegate.acks, hasLength(1));
      expect(await a.queue.size(), 0);
    });
  });

  group('multi-hop relaying', () {
    test('A -> B -> C: the middle phone relays a message it cannot read', () async {
      final a = await mk('a', 1);
      final b = await mk('b', 2);
      final c = await mk('c', 3);
      await connect([(a, b), (b, c)]);
      expect(a.table.isNeighbor(c.id), isFalse); // A can't reach C directly

      const secret = 'meet-at-the-old-bridge-at-nine';
      final packet = await a.sendDirect(c, secret);
      await run();

      // C got it, one relay deep.
      expect(c.delegate.directs.single.text, secret);
      expect(c.delegate.directs.single.relayHops, 1);
      // The receipt travelled back through B.
      expect(a.delegate.acks.single.ackedMessageIdsHex.single, packet.messageIdHex);
      expect(a.delegate.ackHops.single, 1);

      // B relayed but is cryptographically unable to read the message...
      await expectLater(b.crypto.openDirect(packet), throwsA(isA<DecryptionFailure>()));
      expect(b.delegate.directs, isEmpty);
      // ...and nothing B ever received on the air contained the plaintext.
      for (final d in net.log.where((d) => d.toId == b.id)) {
        expect(_contains(d.bytes, utf8.encode(secret)), isFalse);
      }
      // After the receipt, nobody keeps carrying the message.
      expect(await a.queue.size(), 0);
      expect(await b.queue.size(), 0);
      expect(await c.queue.size(), 0);
    });

    test('a longer chain delivers within the hop limit', () async {
      final n = [for (var i = 0; i < 5; i++) await mk('n$i', i + 1)];
      await connect([for (var i = 0; i < 4; i++) (n[i], n[i + 1])]);
      await n[0].sendDirect(n[4], 'across the chain');
      await run();
      expect(n[4].delegate.directs.single.text, 'across the chain');
      expect(n[4].delegate.directs.single.relayHops, 3);
      expect(n[0].delegate.acks, hasLength(1));
    });

    test('the hop limit stops a packet from travelling further', () async {
      final n = [for (var i = 0; i < 4; i++) await mk('n$i', i + 1)];
      await connect([for (var i = 0; i < 3; i++) (n[i], n[i + 1])]);
      // hopLimit 1 = at most one relay: n0 -> n1 -> n2, but never n3.
      await n[0].sendDirect(n[3], 'too far', hopLimit: 1);
      await run();
      expect(n[3].delegate.directs, isEmpty);
      expect(n[2].router.stats.hopLimitDrops, 1);
      expect(n[2].delegate.directs, isEmpty);
    });

    test('with a sufficient hop limit the same chain delivers', () async {
      final n = [for (var i = 0; i < 4; i++) await mk('n$i', i + 1)];
      await connect([for (var i = 0; i < 3; i++) (n[i], n[i + 1])]);
      await n[0].sendDirect(n[3], 'just enough', hopLimit: 2);
      await run();
      expect(n[3].delegate.directs.single.text, 'just enough');
    });

    test('a packet is never sent back to the neighbour it came from', () async {
      final a = await mk('a', 1);
      final b = await mk('b', 2);
      final c = await mk('c', 3);
      await connect([(a, b), (b, c)]);
      await a.sendDirect(c, 'no echo');
      await run();
      final directs = ofType(PacketType.direct);
      expect(directs.where((d) => d.fromId == b.id && d.toId == a.id), isEmpty);
      expect(directs.where((d) => d.fromId == c.id), isEmpty);
    });
  });

  group('duplicate handling', () {
    test('a packet that arrives by two paths creates exactly one delivery', () async {
      final a = await mk('a', 1);
      final b = await mk('b', 2);
      final d = await mk('d', 3);
      final c = await mk('c', 4);
      // Diamond: a -> {b, d} -> c
      await connect([(a, b), (a, d), (b, c), (d, c)]);
      await a.sendDirect(c, 'once only');
      await run();
      expect(c.delegate.directs, hasLength(1));
      expect(c.router.stats.duplicates, greaterThanOrEqualTo(1));
      expect(c.delegate.duplicateDirects, isNotEmpty); // told the sender-side to re-ack
    });

    test('radio-level duplication of every packet changes nothing', () async {
      final a = await mk('a', 1);
      final b = await mk('b', 2);
      final c = await mk('c', 3);
      await connect([(a, b), (b, c)]);
      net.duplicateAll = true;
      await a.sendDirect(c, 'doubled');
      await run();
      expect(c.delegate.directs, hasLength(1));
      expect(a.delegate.acks, hasLength(1));
    });

    test('a loop topology does not cause a broadcast storm', () async {
      final a = await mk('a', 1);
      final b = await mk('b', 2);
      final c = await mk('c', 3);
      final ghost = await mk('ghost', 4); // exists, but is out of range of everyone
      await connect([(a, b), (b, c), (c, a)]);
      await a.sendDirect(ghost, 'into the void');
      await run();
      expect(ofType(PacketType.direct).length, lessThanOrEqualTo(4));

      // Time passes, queues flush repeatedly: no further copies appear.
      final before = net.log.length;
      for (var i = 0; i < 20; i++) {
        clock.advance(const Duration(seconds: 20));
        for (final n in nodes) {
          await n.router.flush();
        }
        await run();
      }
      expect(net.log.length - before, lessThanOrEqualTo(3));
    });

    test('our own packet coming back around a loop is ignored', () async {
      final a = await mk('a', 1);
      final b = await mk('b', 2);
      final c = await mk('c', 3);
      await connect([(a, b)]);
      final packet = await a.sendDirect(c, 'boomerang');
      await run();
      b.transport.inject(b.id, packet.encode());
      a.transport.inject(b.id, packet.encode());
      await run();
      expect(a.router.stats.duplicates, 1);
      expect(a.delegate.directs, isEmpty);
    });
  });

  group('store and forward', () {
    test('a relay holds the message until the next hop appears, then delivers it', () async {
      final a = await mk('a', 1);
      final b = await mk('b', 2);
      final c = await mk('c', 3);
      await connect([(a, b)]); // C is nowhere near yet
      await a.sendDirect(c, 'delayed delivery');
      await run();
      expect(c.delegate.directs, isEmpty);
      expect(await b.queue.size(), 1); // B is carrying it
      expect(a.delegate.acks, isEmpty);

      // Later, B walks into range of C.
      clock.advance(const Duration(minutes: 10));
      await connect([(b, c)]);

      expect(c.delegate.directs.single.text, 'delayed delivery');
      expect(c.delegate.directs.single.relayHops, 1);
      expect(a.delegate.acks, hasLength(1)); // receipt made it home too
      expect(await b.queue.size(), 0);
    });

    test('an interrupted connection is retried and the message still arrives', () async {
      final a = await mk('a', 1);
      final b = await mk('b', 2);
      final c = await mk('c', 3);
      await connect([(a, b), (b, c)]);
      b.transport.failSendsTo.add(c.id); // the B-C radio link is flaky

      await a.sendDirect(c, 'persevere');
      await run();
      expect(c.delegate.directs, isEmpty);
      expect(b.transport.sendAttempts[c.id], 1);

      // Link recovers; B's back-off timer fires.
      b.transport.failSendsTo.clear();
      clock.advance(const Duration(seconds: 40));
      await b.router.flush();
      await run();
      expect(c.delegate.directs.single.text, 'persevere');
      expect(a.delegate.acks, hasLength(1));
    });

    test('a link that drops mid-conversation and returns resumes delivery', () async {
      final a = await mk('a', 1);
      final b = await mk('b', 2);
      final c = await mk('c', 3);
      await connect([(a, b), (b, c)]);
      await net.disconnect(b.id, c.id);
      await run();
      await a.sendDirect(c, 'while you were gone');
      await run();
      expect(c.delegate.directs, isEmpty);
      await net.connect(b.id, c.id);
      await run();
      expect(c.delegate.directs.single.text, 'while you were gone');
    });

    test('messages nobody can deliver expire and the sender is told', () async {
      final a = await mk('a', 1);
      final b = await mk('b', 2);
      final ghost = await mk('ghost', 3);
      await connect([(a, b)]);
      final packet = await a.sendDirect(ghost, 'never arrives');
      await run();
      expect(await a.queue.size(), 1);

      clock.advance(const Duration(hours: 13));
      await a.router.maintain();
      await b.router.maintain();
      await run();

      expect(a.delegate.ownExpired.single.messageId, packet.messageIdHex);
      expect(await a.queue.size(), 0);
      expect(await b.queue.size(), 0); // the relay let go too
    });

    test('a relay stops carrying a packet after its shorter relay retention', () async {
      final a = await mk('a', 1);
      final b = await mk('b', 2);
      final ghost = await mk('ghost', 3);
      await connect([(a, b)]);
      await a.sendDirect(ghost, 'carry me');
      await run();
      expect(await b.queue.size(), 1);
      clock.advance(const Duration(hours: 5)); // > 4 h relay retention, < 12 h message life
      await b.router.maintain();
      expect(await b.queue.size(), 0);
      expect(await a.queue.size(), 1); // the sender keeps trying
    });

    test('the sender stops pushing once the recipient acknowledges, even via relays', () async {
      final a = await mk('a', 1);
      final b = await mk('b', 2);
      final c = await mk('c', 3);
      await connect([(a, b), (b, c)]);
      await a.sendDirect(c, 'ack me');
      await run();
      final before = net.log.length;
      for (var i = 0; i < 10; i++) {
        clock.advance(const Duration(minutes: 5));
        for (final n in nodes) {
          await n.router.flush();
        }
        await run();
      }
      expect(net.log.length, before);
    });

    test('sending to the final recipient is retried a bounded number of times', () async {
      final a = await mk('a', 1);
      final b = await mk('b', 2);
      await connect([(a, b)]);
      b.delegate.autoAck = false; // B never acknowledges
      await a.sendDirect(b, 'are you there?');
      await run();
      for (var i = 0; i < 120; i++) {
        clock.advance(const Duration(seconds: 10));
        await a.router.flush();
        await run();
      }
      // Exactly the policy maximum, not one more.
      expect(a.transport.sendAttempts[b.id], 3);
      expect(ofType(PacketType.direct).length, 3);
      expect(b.delegate.directs, hasLength(1)); // retransmissions create no duplicates
    });

    test('an unacknowledged duplicate prompts the recipient to re-acknowledge', () async {
      final a = await mk('a', 1);
      final b = await mk('b', 2);
      await connect([(a, b)]);
      // Drop B's first receipt on the wire.
      var dropped = false;
      net.onWire = (from, to, bytes) {
        if (from == b.id && !dropped && MeshPacket.decode(bytes).type == PacketType.ack) {
          dropped = true;
          return null;
        }
        return bytes;
      };
      await a.sendDirect(b, 'did you get that?');
      await run();
      expect(a.delegate.acks, isEmpty);
      expect(b.delegate.directs, hasLength(1));

      clock.advance(const Duration(seconds: 40));
      await a.router.flush(); // A retries; B sees a duplicate
      await run();
      expect(b.delegate.duplicateDirects, hasLength(1));
      expect(b.delegate.directs, hasLength(1));
    });
  });

  group('routing decisions use evidence', () {
    test('announcements teach distant phones a route; messages then follow it', () async {
      final a = await mk('a', 1);
      final x = await mk('x', 2); // a bystander that is also A's neighbour
      final b = await mk('b', 3);
      final c = await mk('c', 4);
      await connect([(a, b), (a, x), (b, c)]);

      expect(a.table.statusOf(c.id), PeerStatus.offline); // no evidence yet
      await c.router.announceNow();
      await run();
      final status = a.table.statusOf(c.id);
      expect(status.reachability, Reachability.relayed);
      expect(status.hops, 2);
      expect(status.viaPeerId, b.id);

      await a.sendDirect(c, 'routed, not flooded');
      await run();
      expect(c.delegate.directs.single.text, 'routed, not flooded');
      // The bystander never saw the message.
      expect(
        ofType(PacketType.direct).where((d) => d.toId == x.id),
        isEmpty,
      );
    });

    test('without a route a message is flooded to every neighbour', () async {
      final a = await mk('a', 1);
      final x = await mk('x', 2);
      final b = await mk('b', 3);
      final c = await mk('c', 4);
      await connect([(a, b), (a, x), (b, c)]);
      await a.sendDirect(c, 'flooded');
      await run();
      expect(c.delegate.directs.single.text, 'flooded');
      expect(ofType(PacketType.direct).where((d) => d.fromId == a.id && d.toId == x.id),
          hasLength(1));
    });

    test('a route is forgotten when the relay disconnects', () async {
      final a = await mk('a', 1);
      final b = await mk('b', 2);
      final c = await mk('c', 3);
      await connect([(a, b), (b, c)]);
      await c.router.announceNow();
      await run();
      expect(a.table.statusOf(c.id).reachability, Reachability.relayed);
      await net.disconnect(a.id, b.id);
      await run();
      expect(a.table.statusOf(c.id), PeerStatus.offline);
    });

    test('a route is forgotten when it stops being refreshed', () async {
      final a = await mk('a', 1);
      final b = await mk('b', 2);
      final c = await mk('c', 3);
      await connect([(a, b), (b, c)]);
      await c.router.announceNow();
      await run();
      expect(a.table.statusOf(c.id).isReachable, isTrue);
      clock.advance(const Duration(seconds: 101));
      expect(a.table.statusOf(c.id), PeerStatus.offline);
    });

    test('announcements are rate limited per author, without raising a security alarm', () async {
      final a = await mk('a', 1);
      final b = await mk('b', 2);
      await connect([(a, b)]);
      for (var i = 0; i < 5; i++) {
        await b.router.announceNow();
        await run();
      }
      expect(a.delegate.announces.length, 2); // burst of 2, then throttled
      expect(a.router.stats.rateLimited, 3, reason: 'the excess is counted...');
      expect(a.delegate.securityEvents, isNot(contains('rate_limited')),
          reason: '...but an honest phone that announces on every new neighbour is not an attack');
    });

    test('announcements stop after their small hop limit', () async {
      final n = [for (var i = 0; i < 6; i++) await mk('n$i', i + 1)];
      await connect([for (var i = 0; i < 5; i++) (n[i], n[i + 1])]);
      await n[5].router.announceNow();
      await run();
      // hopLimit 3 = three relays, so the announcement is heard up to four
      // links away (n1) but is not forwarded a fourth time, so n0 never hears it.
      expect(n[1].table.statusOf(n[5].id).isReachable, isTrue);
      expect(n[1].table.statusOf(n[5].id).hops, 4);
      expect(n[0].table.statusOf(n[5].id).isReachable, isFalse);
    });

    test('a neighbour is "direct", an unknown phone is "offline"', () async {
      final a = await mk('a', 1);
      final b = await mk('b', 2);
      final c = await mk('c', 3);
      await connect([(a, b)]);
      expect(a.table.statusOf(b.id).reachability, Reachability.direct);
      expect(a.table.statusOf(c.id).reachability, Reachability.offline);
    });
  });

  group('hostile and faulty input', () {
    test('a relay that tampers with a message is caught; the genuine copy still works', () async {
      final a = await mk('a', 1);
      final b = await mk('b', 2);
      final c = await mk('c', 3);
      await connect([(a, b), (b, c)]);
      var tampered = false;
      net.onWire = (from, to, bytes) {
        if (from == b.id &&
            to == c.id &&
            !tampered &&
            MeshPacket.decode(bytes).type == PacketType.direct) {
          tampered = true;
          return Uint8List.fromList(bytes)..[120] ^= 0x04;
        }
        return bytes;
      };
      await a.sendDirect(c, 'untouched please');
      await run();
      expect(c.delegate.directs, isEmpty);
      expect(c.delegate.securityEvents, contains('bad_signature'));

      // B retries later; the forged copy must not have poisoned C's duplicate memory.
      clock.advance(const Duration(seconds: 45));
      await b.router.flush();
      await run();
      expect(c.delegate.directs.single.text, 'untouched please');
    });

    test('a forged sender is rejected', () async {
      final a = await mk('a', 1);
      final mallory = await mk('mallory', 9);
      final c = await mk('c', 3);
      await connect([(a, c), (mallory, c)]);
      final real = await mallory.crypto.buildDirect(
        recipientSigningKey: c.signingKey,
        recipientAgreementKey: c.agreementKey,
        text: 'pay mallory',
      );
      // Mallory claims to be A but can only sign with her own key.
      final forged = MeshPacket(
        type: real.type,
        hopLimit: real.hopLimit,
        messageId: real.messageId,
        timestampMs: real.timestampMs,
        expiresAtMs: real.expiresAtMs,
        senderKey: a.signingKey,
        recipientKey: real.recipientKey,
        payload: real.payload,
        signature: real.signature,
      );
      c.transport.inject(mallory.id, forged.encode());
      await run();
      expect(c.delegate.directs, isEmpty);
      expect(c.delegate.securityEvents, contains('bad_signature'));
    });

    test('an expired packet replayed later is rejected', () async {
      final a = await mk('a', 1);
      final c = await mk('c', 3);
      await connect([(a, c)]);
      c.delegate.autoAck = false;
      final packet = await a.sendDirect(c, 'old news');
      await run();
      expect(c.delegate.directs, hasLength(1));

      clock.advance(const Duration(hours: 13));
      final fresh = await mk('c2', 3); // same identity seed, empty memory
      await fresh.router.settled();
      fresh.transport.inject(a.id, packet.encode());
      await run();
      expect(fresh.delegate.directs, isEmpty);
      expect(fresh.router.stats.expired, 1);
    });

    test('malformed bytes are reported but do not break the router', () async {
      final a = await mk('a', 1);
      final b = await mk('b', 2);
      await connect([(a, b)]);
      b.transport.inject(a.id, Uint8List.fromList([1, 2, 3]));
      b.transport.inject(a.id, Uint8List(400));
      await run();
      expect(b.delegate.securityEvents, contains('malformed'));
      // Still fully functional.
      await a.sendDirect(b, 'still working');
      await run();
      expect(b.delegate.directs.single.text, 'still working');
    });

    test('a flooding neighbour is rate limited and then disconnected', () async {
      final a = await mk('a', 1);
      final b = await mk('b', 2,
          config: const MeshRouterConfig(
            autoTimers: false,
            inboundBurst: 5,
            inboundPerSecond: 1,
            maxStrikes: 4,
          ));
      await connect([(a, b)]);
      for (var i = 0; i < 30; i++) {
        b.transport.inject(a.id, Uint8List.fromList([i, 1, 2]));
      }
      await run();
      expect(b.transport.dropped.keys, contains(a.id));
      expect(b.delegate.securityEvents.where((e) => e == 'rate_limited'), hasLength(1));
      expect(b.table.isNeighbor(a.id), isFalse);
    });

    test('repeated bad signatures also get a neighbour disconnected', () async {
      final a = await mk('a', 1);
      final mallory = await mk('mallory', 9);
      final b = await mk('b', 2,
          config: const MeshRouterConfig(
            autoTimers: false,
            maxStrikes: 3,
            inboundBurst: 100,
            senderBurst: 100,
          ));
      await connect([(mallory, b)]);
      for (var i = 0; i < 6; i++) {
        final p = await mallory.crypto.buildDirect(
          recipientSigningKey: b.signingKey,
          recipientAgreementKey: b.agreementKey,
          text: 'spam $i',
        );
        final bad = Uint8List.fromList(p.encode())..[105] ^= 1;
        b.transport.inject(mallory.id, bad);
      }
      await run();
      expect(b.transport.dropped.keys, contains(mallory.id));
      expect(a.id, isNot(b.transport.dropped.keys)); // unrelated neighbours untouched
    });

    test('one author cannot fill a relay\'s storage', () async {
      final spammer = await mk('spammer', 7);
      final relay = await mk('relay', 2,
          queue: const QueueConfig(maxRelayPerSender: 3, maxRelayEntries: 100));
      final ghost = await mk('ghost', 9);
      await connect([(spammer, relay)]);
      for (var i = 0; i < 8; i++) {
        await spammer.sendDirect(ghost, 'flood $i');
        await run();
      }
      expect(await relay.outbox.countRelayBySender(spammer.id), 3);
      expect(relay.delegate.securityEvents, contains('rate_limited'));
    });
  });

  group('group packets (store, carry and forward)', () {
    Future<(GroupSealKey, String)> newGroup(TestNode owner, List<TestNode> members) async {
      final key = owner.crypto.newGroupKey();
      final hex = bytesToHex(key.groupId);
      for (final m in [owner, ...members]) {
        m.delegate.memberOfGroups.add(hex);
      }
      return (key, hex);
    }

    test('members get it through a non-member relay that cannot read it', () async {
      final a = await mk('a', 1);
      final b = await mk('b', 2); // carries, is not a member
      final c = await mk('c', 3);
      await connect([(a, b), (b, c)]);
      final (key, _) = await newGroup(a, [c]);

      final packet = await a.sendGroup(key, 'hello group');
      await run();

      expect(c.delegate.groupPackets.single.messageIdHex, packet.messageIdHex);
      expect(c.delegate.groupPackets.single.hops, 1);
      expect(b.delegate.groupPackets, isEmpty, reason: 'a non-member is never handed the packet');
      final opened =
          await EncryptionService.openGroupMessage(c.delegate.groupPackets.single, key) as TextEnvelope;
      expect(opened.text, 'hello group');
      final stranger = GroupSealKey(
          groupId: key.groupId, epoch: 0, key: b.crypto.randomBytes(32));
      await expectLater(EncryptionService.openGroupMessage(packet, stranger),
          throwsA(isA<DecryptionFailure>()));
      for (final d in net.log.where((d) => d.toId == b.id)) {
        expect(_contains(d.bytes, utf8.encode('hello group')), isFalse);
      }
    });

    test('everyone keeps a copy to hand on - it is not cancelled when it is delivered', () async {
      final a = await mk('a', 1);
      final b = await mk('b', 2);
      final c = await mk('c', 3);
      await connect([(a, b), (b, c)]);
      final (key, _) = await newGroup(a, [c]);
      await a.sendGroup(key, 'keep carrying');
      await run();
      expect(await a.queue.size(), 1);
      expect(await b.queue.size(), 1);
      expect(await c.queue.size(), 1);
    });

    test('a member who was out of range gets it from a carrier when they arrive', () async {
      final a = await mk('a', 1);
      final b = await mk('b', 2);
      final c = await mk('c', 3);
      await connect([(a, b)]); // c is nowhere near
      final (key, _) = await newGroup(a, [c]);
      await a.sendGroup(key, 'you missed this');
      await run();
      expect(c.delegate.groupPackets, isEmpty);
      expect(await b.queue.size(), 1);

      clock.advance(const Duration(hours: 3));
      await connect([(b, c)]);

      final got = c.delegate.groupPackets.single;
      expect(got.hops, 1);
      final opened = await EncryptionService.openGroupMessage(got, key) as TextEnvelope;
      expect(opened.text, 'you missed this');
    });

    test('a neighbour is offered a packet only once, however often the queue is flushed', () async {
      final a = await mk('a', 1);
      final b = await mk('b', 2);
      await connect([(a, b)]);
      final (key, _) = await newGroup(a, [b]);
      await a.sendGroup(key, 'just once');
      await run();
      for (var i = 0; i < 30; i++) {
        clock.advance(const Duration(minutes: 20));
        for (final n in nodes) {
          await n.router.flush();
        }
        await run();
      }
      expect(ofType(PacketType.group).where((d) => d.fromId == a.id && d.toId == b.id),
          hasLength(1));
      expect(b.delegate.groupPackets, hasLength(1));
    });

    test('it is never sent back to the neighbour it came from, nor to its author', () async {
      final a = await mk('a', 1);
      final b = await mk('b', 2);
      final c = await mk('c', 3);
      await connect([(a, b), (b, c), (c, a)]);
      final (key, _) = await newGroup(a, [b, c]);
      await a.sendGroup(key, 'ring');
      await run();
      expect(ofType(PacketType.group).where((d) => d.toId == a.id), isEmpty);
      // Every directed link carries it at most once.
      final links = ofType(PacketType.group).map((d) => '${d.fromId}>${d.toId}').toList();
      expect(links.toSet().length, links.length);
      expect(b.delegate.groupPackets, hasLength(1));
      expect(c.delegate.groupPackets, hasLength(1));
    });

    test('a receipt from a member does not stop the packet being carried to the others', () async {
      final a = await mk('a', 1);
      final b = await mk('b', 2);
      await connect([(a, b)]);
      final (key, _) = await newGroup(a, [b]);
      final packet = await a.sendGroup(key, 'ack me, but keep going');
      await run();
      final ack = await b.crypto.buildAck(
        recipientSigningKey: a.signingKey,
        ackedMessageIds: [packet.messageId],
      );
      await b.router.submit(ack);
      await run();
      expect(a.delegate.acks.single.ackedMessageIdsHex, [packet.messageIdHex]);
      expect(await a.queue.size(), 1, reason: 'other members may still need it');
    });

    test('packets expire: carriers let go after their retention, the author at the packet expiry',
        () async {
      final a = await mk('a', 1);
      final b = await mk('b', 2);
      await connect([(a, b)]);
      final (key, _) = await newGroup(a, []);
      final packet = await a.sendGroup(key, 'ephemeral');
      await run();
      clock.advance(const Duration(hours: 13)); // beyond the 12 h life
      await a.router.maintain();
      await b.router.maintain();
      await run();
      expect(await a.queue.size(), 0);
      expect(await b.queue.size(), 0);
      expect(a.delegate.ownExpired.single.messageId, packet.messageIdHex);
    });

    test('an author\'s group traffic has its own quota and cannot crowd out directed relaying',
        () async {
      final spammer = await mk('spammer', 7);
      final relay = await mk('relay', 2,
          queue: const QueueConfig(maxFloodPerSender: 3, maxRelayPerSender: 3));
      final ghost = await mk('ghost', 9);
      await connect([(spammer, relay)]);
      final (key, _) = await newGroup(spammer, []);
      for (var i = 0; i < 8; i++) {
        await spammer.sendGroup(key, 'flood $i');
        await run();
      }
      expect(await relay.outbox.countRelayBySender(spammer.id, flood: true), 3);
      expect(await relay.outbox.countRelayBySender(spammer.id), 0);
      expect(relay.delegate.securityEvents, contains('rate_limited'));
      // A directed message from the same sender is still carried.
      await spammer.sendDirect(ghost, 'still welcome');
      await run();
      expect(await relay.outbox.countRelayBySender(spammer.id), 1);
    });

    test('flood storage is bounded and evicts only flood packets, oldest first', () async {
      final sender = await mk('sender', 7);
      final relay = await mk('relay', 2, queue: const QueueConfig(maxFloodEntries: 4));
      final ghost = await mk('ghost', 9);
      await connect([(sender, relay)]);
      final (key, _) = await newGroup(sender, []);
      await sender.sendDirect(ghost, 'directed, must survive');
      await run();
      final ids = <String>[];
      for (var i = 0; i < 7; i++) {
        ids.add((await sender.sendGroup(key, 'g$i')).messageIdHex);
        await run();
        clock.advance(const Duration(seconds: 1));
      }
      final held = (await relay.outbox.all()).where((e) => e.flood).map((e) => e.messageId);
      expect(held.toSet(), ids.sublist(3).toSet());
      expect((await relay.outbox.all()).where((e) => !e.flood), hasLength(1));
    });

    test('a long chain of carriers delivers within the hop limit', () async {
      final n = [for (var i = 0; i < 6; i++) await mk('n$i', i + 1)];
      await connect([for (var i = 0; i < 5; i++) (n[i], n[i + 1])]);
      final (key, hex) = await newGroup(n[0], []);
      n[5].delegate.memberOfGroups.add(hex);
      await n[0].sendGroup(key, 'across the chain');
      await run();
      // Five relays is the group hop limit: n5 is exactly at the edge.
      expect(n[5].delegate.groupPackets.single.hops, 4);
      expect(n[4].delegate.groupPackets, isEmpty);
    });

    test('the group hop limit stops a packet from going further', () async {
      final n = [for (var i = 0; i < 8; i++) await mk('n$i', i + 1)];
      await connect([for (var i = 0; i < 7; i++) (n[i], n[i + 1])]);
      final (key, hex) = await newGroup(n[0], []);
      n[7].delegate.memberOfGroups.add(hex);
      await n[0].sendGroup(key, 'too far');
      await run();
      expect(n[7].delegate.groupPackets, isEmpty);
      expect(n.any((x) => x.router.stats.hopLimitDrops > 0), isTrue);
    });

    test('a forged group packet is rejected, and does not stop the genuine one', () async {
      final a = await mk('a', 1);
      final mallory = await mk('mallory', 9);
      final c = await mk('c', 3);
      await connect([(a, c), (mallory, c)]);
      final (key, _) = await newGroup(a, [c]);
      final real = await a.crypto.buildGroupMessage(
        group: key,
        envelope: const TextEnvelope('genuine', nickname: 'a'),
      );
      final forged = Uint8List.fromList(real.encode())..[130] ^= 1;
      c.transport.inject(mallory.id, forged);
      await run();
      expect(c.delegate.groupPackets, isEmpty);
      expect(c.delegate.securityEvents, contains('bad_signature'));
      c.transport.inject(a.id, real.encode());
      await run();
      expect(c.delegate.groupPackets, hasLength(1));
    });

    test('pending until someone is in range, then delivered', () async {
      final a = await mk('a', 1);
      final b = await mk('b', 2);
      final (key, _) = await newGroup(a, [b]);
      await a.sendGroup(key, 'anyone?');
      await run();
      expect(a.delegate.ownSent, isEmpty);
      expect(await a.queue.size(), 1);
      await connect([(a, b)]);
      expect(b.delegate.groupPackets, hasLength(1));
      expect(a.delegate.ownSent, hasLength(1));
    });

    test('our own group packet coming back around a loop is not delivered to us', () async {
      final a = await mk('a', 1);
      final b = await mk('b', 2);
      await connect([(a, b)]);
      final (key, _) = await newGroup(a, [b]);
      final packet = await a.sendGroup(key, 'boomerang');
      await run();
      a.transport.inject(b.id, packet.encode());
      await run();
      expect(a.delegate.groupPackets, isEmpty);
    });
  });

  group('public rooms', () {
    final room = PublicRooms.meshId;
    final roomHex = PublicRooms.meshIdHex;

    test('joined phones receive it; relays that did not join still carry it', () async {
      final a = await mk('a', 1);
      final b = await mk('b', 2);
      final c = await mk('c', 3);
      await connect([(a, b), (b, c)]);
      a.delegate.joinedRooms.add(roomHex);
      c.delegate.joinedRooms.add(roomHex);

      final packet = await a.sendRoom(room, 'hello everyone');
      await run();

      expect(c.delegate.roomPackets.single.messageIdHex, packet.messageIdHex);
      expect(b.delegate.roomPackets, isEmpty);
      expect((EncryptionService.openRoomMessage(c.delegate.roomPackets.single) as TextEnvelope).text,
          'hello everyone');
      expect(await b.queue.size(), 1, reason: 'b carries it for later arrivals');
    });

    test('a room message is stored for phones that arrive later', () async {
      final a = await mk('a', 1);
      final b = await mk('b', 2);
      final c = await mk('c', 3);
      await connect([(a, b)]);
      c.delegate.joinedRooms.add(roomHex);
      await a.sendRoom(room, 'earlier');
      await run();
      clock.advance(const Duration(minutes: 30));
      await connect([(b, c)]);
      expect(c.delegate.roomPackets, hasLength(1));
    });

    test('a message for a room we did not join is not delivered', () async {
      final a = await mk('a', 1);
      final b = await mk('b', 2);
      await connect([(a, b)]);
      await a.sendRoom(room, 'not for b');
      await run();
      expect(b.delegate.roomPackets, isEmpty);
    });

    test('room traffic has a shorter life than group traffic', () async {
      final a = await mk('a', 1);
      await a.sendRoom(room, 'short lived');
      await run();
      clock.advance(const Duration(hours: 3)); // beyond the 2 h room TTL
      await a.router.maintain();
      expect(await a.queue.size(), 0);
    });

    group('announcements', () {
      Future<RoomRecord> record(TestNode creator, String name) =>
          creator.crypto.createRoomRecord(name: name);

      test('are heard by neighbours and passed on while they are news', () async {
        final a = await mk('a', 1);
        final b = await mk('b', 2);
        final c = await mk('c', 3);
        await connect([(a, b), (b, c)]);
        final r = await record(a, 'Cafe');
        a.delegate.roomsToAnnounce.add(r);

        await a.router.announceRoomsNow();
        await run();

        expect(b.delegate.roomAnnounces.single.roomId, r.roomId);
        expect(c.delegate.roomAnnounces.single.roomId, r.roomId);
        // Announcements are never stored.
        expect(await a.queue.size(), 0);
        expect(await b.queue.size(), 0);
      });

      test('a phone that already knows the room does not pass it on again', () async {
        final a = await mk('a', 1);
        final b = await mk('b', 2);
        final c = await mk('c', 3);
        await connect([(a, b), (b, c)]);
        b.delegate.roomAnnounceIsNews = false;
        a.delegate.roomsToAnnounce.add(await record(a, 'Cafe'));
        await a.router.announceRoomsNow();
        await run();
        expect(b.delegate.roomAnnounces, hasLength(1));
        expect(c.delegate.roomAnnounces, isEmpty);
      });

      test('stop after their hop limit', () async {
        final n = [for (var i = 0; i < 8; i++) await mk('n$i', i + 1)];
        await connect([for (var i = 0; i < 7; i++) (n[i], n[i + 1])]);
        n[0].delegate.roomsToAnnounce.add(await record(n[0], 'Far'));
        await n[0].router.announceRoomsNow();
        await run();
        expect(n[5].delegate.roomAnnounces, hasLength(1)); // 4 relays away
        expect(n[6].delegate.roomAnnounces, isEmpty);
      });

      test('a garbled record is reported, not forwarded', () async {
        final a = await mk('a', 1);
        final b = await mk('b', 2);
        final c = await mk('c', 3);
        await connect([(a, b), (b, c)]);
        final r = await record(a, 'Cafe');
        final bad = RoomRecord(
          roomId: r.roomId,
          name: r.name,
          description: r.description,
          creatorKey: r.creatorKey,
          createdAtMs: r.createdAtMs,
          expiresAtMs: r.createdAtMs, // expires immediately: structurally invalid
          version: r.version,
          signature: r.signature,
        );
        final packet = await a.crypto.buildRoomAnnounce(bad);
        b.transport.inject(a.id, packet.encode());
        await run();
        expect(b.delegate.roomAnnounces, isEmpty);
        expect(b.delegate.securityEvents, contains('malformed'));
        expect(c.delegate.roomAnnounces, isEmpty);
      });

      test('are announced to a neighbour as soon as it connects', () async {
        final a = await mk('a', 1,
            config: const MeshRouterConfig(autoTimers: true, announceInterval: Duration(days: 1)));
        final b = await mk('b', 2);
        a.delegate.roomsToAnnounce.add(await record(a, 'Greeting'));
        await connect([(a, b)]);
        expect(b.delegate.roomAnnounces.map((r) => r.name), ['Greeting']);
      });

      test('flooding them is throttled per author without a security alarm', () async {
        final a = await mk('a', 1);
        final b = await mk('b', 2);
        await connect([(a, b)]);
        a.delegate.roomsToAnnounce.addAll([for (var i = 0; i < 20; i++) await record(a, 'room $i')]);
        await a.router.announceRoomsNow();
        await run();
        expect(b.delegate.roomAnnounces.length, 12); // the burst allowance
        expect(b.delegate.securityEvents, isNot(contains('rate_limited')));
      });
    });
  });

  group('image and voice chunks', () {
    Future<List<MeshPacket>> chunks(TestNode from, TestNode to, int count) async {
      final key = from.crypto.randomBytes(32);
      final mediaId = from.crypto.randomBytes(16);
      return [
        for (var i = 0; i < count; i++)
          await from.crypto.buildChunk(
            type: PacketType.direct,
            recipientKey: to.signingKey,
            mediaId: mediaId,
            index: i,
            count: count,
            data: Uint8List.fromList(List.filled(1500, i)),
            key: key,
          ),
      ];
    }

    test('direct chunks cross a relay, are acknowledged, and nobody keeps carrying them', () async {
      final a = await mk('a', 1);
      final b = await mk('b', 2);
      final c = await mk('c', 3);
      await connect([(a, b), (b, c)]);
      final parts = await chunks(a, c, 6);
      for (final p in parts) {
        await a.router.submit(p);
      }
      await run();
      expect(c.delegate.directChunks, hasLength(6));
      expect(a.delegate.acks, hasLength(6));
      expect(await a.queue.size(), 0);
      expect(await b.queue.size(), 0);
      expect(c.delegate.directs, isEmpty, reason: 'chunks are not messages');
    });

    test('a lost chunk is retried until acknowledged', () async {
      final a = await mk('a', 1);
      final b = await mk('b', 2);
      await connect([(a, b)]);
      final parts = await chunks(a, b, 3);
      var dropped = false;
      net.onWire = (from, to, bytes) {
        final p = MeshPacket.decode(bytes);
        if (!dropped && p.type == PacketType.direct && p.messageIdHex == parts[1].messageIdHex) {
          dropped = true;
          return null;
        }
        return bytes;
      };
      for (final p in parts) {
        await a.router.submit(p);
      }
      await run();
      expect(b.delegate.directChunks, hasLength(2));
      clock.advance(const Duration(seconds: 60));
      await a.router.flush();
      await run();
      expect(b.delegate.directChunks, hasLength(3));
      expect(await a.queue.size(), 0);
    });

    test('group chunks are carried like group messages', () async {
      final a = await mk('a', 1);
      final b = await mk('b', 2);
      final c = await mk('c', 3);
      await connect([(a, b), (b, c)]);
      final group = a.crypto.newGroupKey();
      c.delegate.memberOfGroups.add(bytesToHex(group.groupId));
      final mediaId = a.crypto.randomBytes(16);
      final key = await EncryptionService.groupMediaKey(group.key, mediaId);
      for (var i = 0; i < 4; i++) {
        await a.router.submit(await a.crypto.buildChunk(
          type: PacketType.group,
          recipientKey: group.groupId,
          mediaId: mediaId,
          index: i,
          count: 4,
          data: Uint8List.fromList(List.filled(1200, i)),
          key: key,
          epoch: group.epoch,
        ));
      }
      await run();
      expect(c.delegate.groupPackets, hasLength(4));
      expect(c.delegate.groupPackets.every((p) => p.isChunk), isTrue);
      expect(b.delegate.groupPackets, isEmpty);
    });

    test('a whole 48-chunk image from one author is not mistaken for an attack', () async {
      final a = await mk('a', 1);
      final b = await mk('b', 2);
      await connect([(a, b)]);
      for (final p in await chunks(a, b, 48)) {
        await a.router.submit(p);
      }
      await run();
      expect(b.delegate.directChunks, hasLength(48));
      expect(b.delegate.securityEvents, isEmpty);
    });

    test('urgent traffic is sent before bulk: receipts, then messages, then chunks', () async {
      final a = await mk('a', 1);
      final b = await mk('b', 2);
      // Everything is queued while nobody is in range...
      final bulk = await chunks(a, b, 3);
      for (final p in bulk) {
        await a.router.submit(p);
      }
      final key = a.crypto.newGroupKey();
      b.delegate.memberOfGroups.add(bytesToHex(key.groupId));
      await a.sendGroup(key, 'a group message');
      final direct = await a.sendDirect(b, 'a direct message');
      final ack = await a.crypto.buildAck(
        recipientSigningKey: b.signingKey,
        ackedMessageIds: [a.crypto.randomBytes(16)],
      );
      await a.router.submit(ack);
      await run();
      // ...then they all become due at once when b arrives.
      await connect([(a, b)]);
      b.delegate.autoAck = false;
      final order = net.log
          .where((d) => d.fromId == a.id && d.toId == b.id)
          .map((d) => MeshPacket.decode(d.bytes))
          .where((p) => p.type != PacketType.announce)
          .map((p) => p.isChunk ? 'chunk' : p.type.name)
          .toList();
      expect(order.indexOf('ack'), lessThan(order.indexOf('direct')));
      expect(order.indexOf('direct'), lessThan(order.indexOf('group')));
      expect(order.indexOf('group'), lessThan(order.indexOf('chunk')));
      expect(direct.messageIdHex, isNotEmpty);
    });
  });

  group('restarts', () {
    late Directory dir;

    setUp(() => dir = makeTempDir('mesh_router_test_'));

    // Registered after the outer tearDown, so it runs BEFORE it: databases
    // must be closed before their files can be deleted on Windows.
    tearDown(() async {
      for (final n in nodes) {
        await n.close();
      }
      nodes.clear();
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    test('a relay that restarts still delivers what it was carrying, and remembers duplicates',
        () async {
      final path = '${dir.path}${Platform.pathSeparator}relay.db';
      final relayKeys = MemoryKeyStore();

      final a = await mk('a', 1);
      final c = await mk('c', 3);
      var relay = await TestNode.create('relay', net, clock,
          seed: 2, identityStore: relayKeys, db: await openFileDatabase(path));
      nodes.add(relay);
      await connect([(a, relay)]);

      final packet = await a.sendDirect(c, 'survives a reboot');
      await run();
      expect(await relay.queue.size(), 1);

      // The relay phone restarts.
      await net.disconnect(a.id, relay.id);
      await run();
      await relay.stop();
      await relay.db.close();
      nodes.remove(relay);

      relay = await TestNode.create('relay', net, clock,
          seed: 2, identityStore: relayKeys, db: await openFileDatabase(path));
      nodes.add(relay);
      expect(await relay.queue.size(), 1); // still there
      expect(relay.seen.contains(packet.messageIdHex), isTrue); // still remembered

      // The same bytes arriving again are a duplicate, not new work.
      relay.transport.inject(a.id, packet.encode());
      await run();
      expect(relay.router.stats.duplicates, 1);
      expect(await relay.queue.size(), 1);

      await connect([(relay, c)]);
      expect(c.delegate.directs.single.text, 'survives a reboot');
    });

    test('a sender that restarts keeps retrying its unacknowledged message', () async {
      final path = '${dir.path}${Platform.pathSeparator}sender.db';
      final keys = MemoryKeyStore();
      final b = await mk('b', 2);
      var a = await TestNode.create('a', net, clock,
          seed: 1, identityStore: keys, db: await openFileDatabase(path));
      nodes.add(a);

      await a.sendDirect(b, 'composed before the crash');
      await run();
      await a.stop();
      await a.db.close();
      nodes.remove(a);

      a = await TestNode.create('a', net, clock,
          seed: 1, identityStore: keys, db: await openFileDatabase(path));
      nodes.add(a);
      expect(await a.queue.size(), 1);
      await connect([(a, b)]);
      expect(b.delegate.directs.single.text, 'composed before the crash');
      expect(a.delegate.acks, hasLength(1));
    });
  });

  group('flooding limits', () {
    test('a flood goes to at most the configured fan-out', () async {
      final hub = await mk('hub', 1, floodFanout: 3);
      final leaves = [for (var i = 0; i < 6; i++) await mk('leaf$i', 10 + i)];
      final ghost = await mk('ghost', 99);
      await connect([for (final l in leaves) (hub, l)]);
      await hub.sendDirect(ghost, 'who wants this');
      await run();
      final recipients = ofType(PacketType.direct).where((d) => d.fromId == hub.id).length;
      expect(recipients, 3);
    });
  });
}
