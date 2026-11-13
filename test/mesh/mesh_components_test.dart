import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:offline_mesh_chat/database/database_helper.dart';
import 'package:offline_mesh_chat/database/outbox_repository.dart';
import 'package:offline_mesh_chat/mesh/duplicate_filter.dart';
import 'package:offline_mesh_chat/mesh/message_queue.dart';
import 'package:offline_mesh_chat/mesh/peer_table.dart';
import 'package:offline_mesh_chat/mesh/rate_limiter.dart';
import 'package:offline_mesh_chat/mesh/relay_manager.dart';
import 'package:offline_mesh_chat/models/peer.dart';
import 'package:offline_mesh_chat/protocol/mesh_packet.dart';
import 'package:offline_mesh_chat/transport/mesh_transport.dart';

import '../support/fake_clock.dart';
import '../support/test_database.dart';

Uint8List _k(int v) => Uint8List(32)..fillRange(0, 32, v);

NeighborInfo _neighbor(int v, {String nick = 'n'}) => NeighborInfo(
      signingKey: _k(v),
      agreementKey: _k(v + 100),
      nickname: nick,
      sinceMs: 0,
    );

String _id(int v) => _neighbor(v).peerId;

MeshPacket _packet({
  PacketType type = PacketType.direct,
  int sender = 1,
  int recipient = 9,
  int idByte = 7,
  int hopLimit = 5,
  int hops = 0,
  int expires = 2000000000000,
}) =>
    MeshPacket(
      type: type,
      hopLimit: hopLimit,
      hops: hops,
      messageId: _k(idByte).sublist(0, 16),
      timestampMs: 1700000000000,
      expiresAtMs: expires,
      senderKey: _k(sender),
      recipientKey: type == PacketType.announce ? Uint8List(32) : _k(recipient),
      payload: Uint8List(70),
      signature: Uint8List(64),
    );

void main() {
  group('DuplicateFilter', () {
    late DatabaseHelper helper;
    late OutboxRepository store;
    late FakeClock clock;

    setUp(() async {
      helper = await openMemoryDatabase();
      store = OutboxRepository(helper.db);
      clock = FakeClock(1000);
    });

    tearDown(() => helper.close());

    test('marks once and reports duplicates', () async {
      final f = DuplicateFilter(store: store, clock: clock);
      expect(f.contains('a'), isFalse);
      expect(await f.mark('a', 5000), isTrue);
      expect(f.contains('a'), isTrue);
      expect(await f.mark('a', 5000), isFalse);
    });

    test('entries expire with the packet', () async {
      final f = DuplicateFilter(store: store, clock: clock);
      await f.mark('a', 3000);
      clock.set(2999);
      expect(f.contains('a'), isTrue);
      clock.set(3000);
      expect(f.contains('a'), isFalse);
      // An expired id can be accepted again (the packet itself is expired too).
      expect(await f.mark('a', 9000), isTrue);
    });

    test('is bounded: the oldest ids are evicted first', () async {
      final f = DuplicateFilter(store: store, clock: clock, capacity: 3);
      for (final id in ['a', 'b', 'c', 'd']) {
        await f.mark(id, 99999);
      }
      expect(f.size, 3);
      expect(f.contains('a'), isFalse);
      expect([f.contains('b'), f.contains('c'), f.contains('d')], [true, true, true]);
    });

    test('survives a restart (persisted), ignoring expired entries', () async {
      final first = DuplicateFilter(store: store, clock: clock);
      await first.mark('keep', 9000);
      await first.mark('gone', 1500);
      clock.set(2000);

      final second = DuplicateFilter(store: store, clock: clock);
      expect(second.contains('keep'), isFalse); // nothing loaded yet
      await second.load();
      expect(second.contains('keep'), isTrue);
      expect(second.contains('gone'), isFalse);
    });

    test('prune removes expired ids from memory and storage', () async {
      final f = DuplicateFilter(store: store, clock: clock);
      await f.mark('old', 1500);
      await f.mark('new', 9000);
      clock.set(2000);
      await f.prune();
      expect(f.size, 1);
      expect((await store.loadSeen(0)).keys, ['new']);
    });
  });

  group('TokenBucketRateLimiter', () {
    test('allows a burst, then throttles to the refill rate', () {
      final clock = FakeClock();
      final l = TokenBucketRateLimiter(capacity: 5, refillPerSecond: 2, clock: clock);
      for (var i = 0; i < 5; i++) {
        expect(l.tryAcquire('k'), isTrue, reason: 'burst $i');
      }
      expect(l.tryAcquire('k'), isFalse);
      clock.advance(const Duration(milliseconds: 500)); // +1 token
      expect(l.tryAcquire('k'), isTrue);
      expect(l.tryAcquire('k'), isFalse);
      clock.advance(const Duration(seconds: 10)); // refills, capped at capacity
      var granted = 0;
      while (l.tryAcquire('k')) {
        granted++;
        if (granted > 100) break;
      }
      expect(granted, 5);
    });

    test('keys are independent and can be forgotten', () {
      final clock = FakeClock();
      final l = TokenBucketRateLimiter(capacity: 1, refillPerSecond: 0.001, clock: clock);
      expect(l.tryAcquire('a'), isTrue);
      expect(l.tryAcquire('a'), isFalse);
      expect(l.tryAcquire('b'), isTrue);
      l.forget('a');
      expect(l.tryAcquire('a'), isTrue);
    });

    test('costly operations consume more tokens', () {
      final l = TokenBucketRateLimiter(capacity: 10, refillPerSecond: 1, clock: FakeClock());
      expect(l.tryAcquire('k', cost: 8), isTrue);
      expect(l.tryAcquire('k', cost: 8), isFalse);
      expect(l.tryAcquire('k', cost: 2), isTrue);
    });

    test('idle buckets are pruned', () {
      final clock = FakeClock();
      final l = TokenBucketRateLimiter(capacity: 5, refillPerSecond: 1, clock: clock);
      l.tryAcquire('a');
      clock.advance(const Duration(minutes: 10));
      l.tryAcquire('b');
      l.prune(idleMs: 300000);
      expect(l.trackedKeys, 1);
    });
  });

  group('PeerTable reachability evidence', () {
    late FakeClock clock;
    late PeerTable table;

    setUp(() {
      clock = FakeClock();
      table = PeerTable(clock: clock);
    });

    test('a connected neighbour is reachable directly with one hop', () {
      table.neighborUp(_neighbor(1));
      expect(table.statusOf(_id(1)), const PeerStatus(Reachability.direct, hops: 1));
    });

    test('an unknown peer is offline', () {
      expect(table.statusOf(_id(5)), PeerStatus.offline);
      expect(table.statusOf(_id(5)).isReachable, isFalse);
    });

    test('a route needs a verified announcement through a CONNECTED neighbour', () {
      // Nothing is learned through a neighbour that is not connected.
      expect(table.learnRoute(destId: _id(5), viaId: _id(1), relayHops: 1), isFalse);
      expect(table.statusOf(_id(5)), PeerStatus.offline);

      table.neighborUp(_neighbor(1));
      expect(table.learnRoute(destId: _id(5), viaId: _id(1), relayHops: 1), isTrue);
      final s = table.statusOf(_id(5));
      expect(s.reachability, Reachability.relayed);
      expect(s.hops, 2);
      expect(s.viaPeerId, _id(1));
    });

    test('more relays mean more hops', () {
      table.neighborUp(_neighbor(1));
      table.learnRoute(destId: _id(5), viaId: _id(1), relayHops: 3);
      expect(table.statusOf(_id(5)).hops, 4);
    });

    test('routes disappear the moment their next hop disconnects', () {
      table.neighborUp(_neighbor(1));
      table.learnRoute(destId: _id(5), viaId: _id(1), relayHops: 1);
      expect(table.statusOf(_id(5)).isReachable, isTrue);
      table.neighborDown(_id(1));
      expect(table.statusOf(_id(5)), PeerStatus.offline);
      expect(table.routesTo(_id(5)), isEmpty);
    });

    test('routes expire when not refreshed by new announcements', () {
      table.neighborUp(_neighbor(1));
      table.learnRoute(destId: _id(5), viaId: _id(1), relayHops: 1);
      clock.advance(const Duration(seconds: 99));
      expect(table.statusOf(_id(5)).isReachable, isTrue);
      clock.advance(const Duration(seconds: 2));
      expect(table.statusOf(_id(5)), PeerStatus.offline);
      expect(table.expireRoutes(), isTrue);
    });

    test('a refreshing announcement keeps the route alive', () {
      table.neighborUp(_neighbor(1));
      table.learnRoute(destId: _id(5), viaId: _id(1), relayHops: 1);
      clock.advance(const Duration(seconds: 90));
      table.learnRoute(destId: _id(5), viaId: _id(1), relayHops: 1);
      clock.advance(const Duration(seconds: 90));
      expect(table.statusOf(_id(5)).isReachable, isTrue);
    });

    test('the shortest route is preferred and the list is capped', () {
      for (final v in [1, 2, 3, 4]) {
        table.neighborUp(_neighbor(v));
      }
      table.learnRoute(destId: _id(5), viaId: _id(1), relayHops: 4);
      table.learnRoute(destId: _id(5), viaId: _id(2), relayHops: 1);
      table.learnRoute(destId: _id(5), viaId: _id(3), relayHops: 2);
      table.learnRoute(destId: _id(5), viaId: _id(4), relayHops: 3);
      final routes = table.routesTo(_id(5));
      expect(routes.length, 3);
      expect(routes.first.nextHopId, _id(2));
      expect(routes.map((r) => r.linkHops), [2, 3, 4]);
    });

    test('becoming a direct neighbour replaces any route', () {
      table.neighborUp(_neighbor(1));
      table.learnRoute(destId: _id(5), viaId: _id(1), relayHops: 1);
      table.neighborUp(_neighbor(5));
      expect(table.statusOf(_id(5)).reachability, Reachability.direct);
      expect(table.routesTo(_id(5)), isEmpty);
    });

    test('a packet that arrived with zero relays is not a route', () {
      table.neighborUp(_neighbor(1));
      expect(table.learnRoute(destId: _id(1), viaId: _id(1), relayHops: 0), isFalse);
    });

    test('changes are announced to listeners', () async {
      var events = 0;
      final sub = table.changes.listen((_) => events++);
      table.neighborUp(_neighbor(1));
      table.learnRoute(destId: _id(5), viaId: _id(1), relayHops: 1);
      table.neighborDown(_id(1));
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      expect(events, greaterThanOrEqualTo(3));
    });

    test('reachablePeerIds lists neighbours and routed peers', () {
      table.neighborUp(_neighbor(1));
      table.learnRoute(destId: _id(5), viaId: _id(1), relayHops: 1);
      expect(table.reachablePeerIds, {_id(1), _id(5)});
    });
  });

  group('MessageQueue', () {
    late DatabaseHelper helper;
    late OutboxRepository store;
    late FakeClock clock;
    late MessageQueue queue;

    setUp(() async {
      helper = await openMemoryDatabase();
      store = OutboxRepository(helper.db);
      clock = FakeClock(1700000000000);
      queue = MessageQueue(
        store: store,
        clock: clock,
        random: Random(1),
        config: const QueueConfig(maxRelayEntries: 3, maxRelayPerSender: 2),
      );
    });

    tearDown(() => helper.close());

    test('retention is clamped to our own maximum, whatever the sender claims', () async {
      final greedy = _packet(expires: clock.nowMs + const Duration(days: 365).inMilliseconds);
      await queue.enqueueOwn(greedy, recipientId: _id(9));
      final e = (await store.get(greedy.messageIdHex))!;
      expect(e.expiresAtMs - clock.nowMs, const Duration(hours: 24).inMilliseconds);
    });

    test('relayed packets are held for a shorter time than our own', () async {
      final p = _packet(expires: clock.nowMs + const Duration(hours: 12).inMilliseconds);
      await queue.enqueueRelay(p);
      final e = (await store.get(p.messageIdHex))!;
      expect(e.expiresAtMs - clock.nowMs, const Duration(hours: 4).inMilliseconds);
    });

    test('already expired packets are refused', () async {
      expect(await queue.enqueueOwn(_packet(expires: clock.nowMs - 1), recipientId: 'x'),
          EnqueueOutcome.rejectedExpired);
      expect(await queue.enqueueRelay(_packet(expires: clock.nowMs - 1)),
          EnqueueOutcome.rejectedExpired);
    });

    test('duplicates are reported', () async {
      final p = _packet();
      expect(await queue.enqueueOwn(p, recipientId: _id(9)), EnqueueOutcome.stored);
      expect(await queue.enqueueOwn(p, recipientId: _id(9)), EnqueueOutcome.duplicate);
    });

    test('one sender cannot monopolise the relay queue', () async {
      expect(await queue.enqueueRelay(_packet(idByte: 1, sender: 4)), EnqueueOutcome.stored);
      expect(await queue.enqueueRelay(_packet(idByte: 2, sender: 4)), EnqueueOutcome.stored);
      expect(await queue.enqueueRelay(_packet(idByte: 3, sender: 4)),
          EnqueueOutcome.rejectedSenderQuota);
      expect(await queue.enqueueRelay(_packet(idByte: 4, sender: 5)), EnqueueOutcome.stored);
    });

    test('the relay queue is capped; the oldest relayed packets go first, own packets stay',
        () async {
      await queue.enqueueOwn(_packet(idByte: 50, sender: 1), recipientId: _id(9));
      for (var i = 1; i <= 5; i++) {
        clock.advance(const Duration(seconds: 1));
        await queue.enqueueRelay(_packet(idByte: i, sender: 10 + i));
      }
      final ids = (await store.all()).map((e) => e.kind).toList();
      expect(ids.where((k) => k == OutboxKind.relay).length, 3);
      expect(ids.where((k) => k == OutboxKind.own).length, 1);
    });

    test('retries back off exponentially (with jitter) up to a ceiling', () async {
      final p = _packet();
      await queue.enqueueOwn(p, recipientId: _id(9));
      final delays = <int>[];
      for (var i = 0; i < 12; i++) {
        final e = (await store.get(p.messageIdHex))!;
        final before = clock.nowMs;
        await queue.scheduleRetry(e);
        final after = (await store.get(p.messageIdHex))!;
        delays.add(after.nextAttemptAtMs - before);
        expect(after.attempts, i + 1);
      }
      // 10s, 20s, 40s ... within +-20 % jitter.
      expect(delays[0], inInclusiveRange(8000, 12000));
      expect(delays[1], inInclusiveRange(16000, 24000));
      expect(delays[2], inInclusiveRange(32000, 48000));
      // Never beyond the 15 minute ceiling (plus jitter).
      for (final d in delays) {
        expect(d, lessThanOrEqualTo((15 * 60 * 1000 * 1.2).round()));
      }
      expect(delays.last, greaterThan(15 * 60 * 1000 * 0.8 - 1));
    });

    test('an idle deferral does not consume an attempt', () async {
      final p = _packet();
      await queue.enqueueOwn(p, recipientId: _id(9));
      await queue.deferIdle((await store.get(p.messageIdHex))!);
      final e = (await store.get(p.messageIdHex))!;
      expect(e.attempts, 0);
      expect(e.nextAttemptAtMs, clock.nowMs + 15000);
    });

    test('nudge makes everything due immediately', () async {
      final p = _packet();
      await queue.enqueueOwn(p, recipientId: _id(9));
      await queue.scheduleRetry((await store.get(p.messageIdHex))!);
      expect(await queue.due(), isEmpty);
      await queue.nudge();
      expect((await queue.due()).length, 1);
    });

    test('expireOld returns and removes expired entries', () async {
      final p = _packet(expires: clock.nowMs + 60000);
      await queue.enqueueOwn(p, recipientId: _id(9));
      clock.advance(const Duration(minutes: 2));
      final expired = await queue.expireOld();
      expect(expired.single.messageId, p.messageIdHex);
      expect(await queue.size(), 0);
    });

    test('an ack cancels the queued message only if it comes from the recipient', () async {
      final p = _packet(recipient: 9);
      await queue.enqueueOwn(p, recipientId: _id(9));
      expect(await queue.cancelIfAckedBy(p.messageIdHex, _id(3)), isFalse); // an impostor
      expect(await queue.size(), 1);
      expect(await queue.cancelIfAckedBy(p.messageIdHex, _id(9)), isTrue);
      expect(await queue.size(), 0);
    });

    group('group and room packets', () {
      test('are stored as flood entries without a recipient', () async {
        for (final type in [PacketType.group, PacketType.room]) {
          final p = _packet(type: type, idByte: type.code);
          await queue.enqueueOwn(p, recipientId: null);
          final e = (await store.get(p.messageIdHex))!;
          expect(e.flood, isTrue, reason: type.name);
          expect(e.recipientId, isNull);
          expect(e.priority, OutboxPriority.message);
        }
      });

      test('a receipt from a member never cancels them', () async {
        final p = _packet(type: PacketType.group, recipient: 9);
        await queue.enqueueOwn(p, recipientId: null);
        expect(await queue.cancelIfAckedBy(p.messageIdHex, _id(9)), isFalse);
        expect(await queue.size(), 1);
      });

      test('carried copies live longer than directed ones, but never past our maximum', () async {
        final group = _packet(type: PacketType.group, expires: clock.nowMs + const Duration(hours: 12).inMilliseconds);
        await queue.enqueueRelay(group);
        expect((await store.get(group.messageIdHex))!.expiresAtMs - clock.nowMs,
            const Duration(hours: 12).inMilliseconds);
        final greedy = _packet(
            type: PacketType.room,
            idByte: 8,
            expires: clock.nowMs + const Duration(days: 30).inMilliseconds);
        await queue.enqueueRelay(greedy);
        expect((await store.get(greedy.messageIdHex))!.expiresAtMs - clock.nowMs,
            const Duration(hours: 12).inMilliseconds,
            reason: 'bounded by the flood relay retention');
      });

      test('have their own quotas and eviction', () async {
        final q = MessageQueue(
          store: store,
          clock: clock,
          config: const QueueConfig(maxFloodEntries: 2, maxFloodPerSender: 2, maxRelayEntries: 10),
        );
        expect(await q.enqueueRelay(_packet(type: PacketType.group, idByte: 1, sender: 4)),
            EnqueueOutcome.stored);
        expect(await q.enqueueRelay(_packet(type: PacketType.group, idByte: 2, sender: 4)),
            EnqueueOutcome.stored);
        expect(await q.enqueueRelay(_packet(type: PacketType.group, idByte: 3, sender: 4)),
            EnqueueOutcome.rejectedSenderQuota);
        // A directed packet from the same sender is unaffected.
        expect(await q.enqueueRelay(_packet(idByte: 4, sender: 4)), EnqueueOutcome.stored);
        // Overall flood cap: oldest flood packet is evicted.
        clock.advance(const Duration(seconds: 1));
        expect(await q.enqueueRelay(_packet(type: PacketType.room, idByte: 5, sender: 5)),
            EnqueueOutcome.stored);
        final floods = (await store.all()).where((e) => e.flood).length;
        expect(floods, 2);
        expect((await store.all()).where((e) => !e.flood).length, 1);
      });

      test('wait a long time when nobody new is around, but not forever', () async {
        final p = _packet(type: PacketType.group);
        await queue.enqueueOwn(p, recipientId: null);
        await queue.deferIdle((await store.get(p.messageIdHex))!);
        final e = (await store.get(p.messageIdHex))!;
        expect(e.nextAttemptAtMs, clock.nowMs + const Duration(minutes: 5).inMilliseconds);
        expect(e.attempts, 0);
      });
    });

    group('priorities', () {
      test('are derived from the packet', () {
        expect(MessageQueue.priorityFor(_packet(type: PacketType.ack)), OutboxPriority.ack);
        expect(MessageQueue.priorityFor(_packet()), OutboxPriority.direct);
        expect(MessageQueue.priorityFor(_packet(type: PacketType.group)), OutboxPriority.message);
        expect(MessageQueue.priorityFor(_packet(type: PacketType.room)), OutboxPriority.message);
        final chunk = MeshPacket(
          type: PacketType.direct,
          flags: MeshPacket.flagChunk,
          hopLimit: 5,
          messageId: _k(7).sublist(0, 16),
          timestampMs: 1,
          expiresAtMs: 2,
          senderKey: _k(1),
          recipientKey: _k(9),
          payload: Uint8List(70),
          signature: Uint8List(64),
        );
        expect(MessageQueue.priorityFor(chunk), OutboxPriority.chunk);
        expect(MessageQueue.priorityFor(MeshPacket.decode(chunk.encode())), OutboxPriority.chunk);
      });

      test('due() hands out receipts first and chunks last', () async {
        await queue.enqueueOwn(
            _packet(type: PacketType.group, idByte: 1), recipientId: null);
        await queue.enqueueOwn(_packet(type: PacketType.ack, idByte: 2), recipientId: _id(9));
        await queue.enqueueOwn(_packet(idByte: 3), recipientId: _id(9));
        expect((await queue.due()).map((e) => e.priority), [
          OutboxPriority.ack,
          OutboxPriority.direct,
          OutboxPriority.message,
        ]);
      });
    });

    group('mayResend', () {
      SentRecord rec(int count, int ago) =>
          SentRecord(neighborId: 'n', sentAtMs: clock.nowMs - ago, sendCount: count);

      test('a neighbour that has never been sent the packet is eligible', () {
        expect(queue.mayResend(previous: null, neighborIsFinalRecipient: false), isTrue);
        expect(queue.mayResend(previous: null, neighborIsFinalRecipient: true), isTrue);
      });

      test('the final recipient gets growing cool-downs and a hard cap', () {
        expect(queue.mayResend(previous: rec(1, 10000), neighborIsFinalRecipient: true), isFalse);
        expect(queue.mayResend(previous: rec(1, 31000), neighborIsFinalRecipient: true), isTrue);
        expect(queue.mayResend(previous: rec(2, 31000), neighborIsFinalRecipient: true), isFalse);
        expect(queue.mayResend(previous: rec(2, 61000), neighborIsFinalRecipient: true), isTrue);
        expect(queue.mayResend(previous: rec(3, 9999999), neighborIsFinalRecipient: true), isFalse);
      });

      test('a relay that already has it gets at most one late second chance', () {
        expect(queue.mayResend(previous: rec(1, 60000), neighborIsFinalRecipient: false), isFalse);
        expect(queue.mayResend(previous: rec(1, 301000), neighborIsFinalRecipient: false), isTrue);
        expect(queue.mayResend(previous: rec(2, 9999999), neighborIsFinalRecipient: false), isFalse);
      });

      test('a neighbour known to hold the packet is never offered it again', () {
        final has = SentRecord(
            neighborId: 'n',
            sentAtMs: 0,
            sendCount: OutboxRepository.neighborHasItCount);
        expect(queue.mayResend(previous: has, neighborIsFinalRecipient: false), isFalse);
        expect(queue.mayResend(previous: has, neighborIsFinalRecipient: true), isFalse);
      });
    });
  });

  group('RelayManager decisions', () {
    late DatabaseHelper helper;
    late FakeClock clock;
    late PeerTable table;
    late MessageQueue queue;
    late RelayManager relay;

    setUp(() async {
      helper = await openMemoryDatabase();
      clock = FakeClock(1700000000000);
      table = PeerTable(clock: clock);
      queue = MessageQueue(store: OutboxRepository(helper.db), clock: clock);
      relay = RelayManager(table: table, queue: queue, floodFanout: 2);
    });

    tearDown(() => helper.close());

    RelayDecision decide(MeshPacket p,
            {Map<String, SentRecord> sent = const {}, String? from}) =>
        relay.decide(packet: p, sentTo: sent, receivedFromId: from);

    test('sends only to the recipient when it is a neighbour', () {
      for (final v in [1, 2, 9]) {
        table.neighborUp(_neighbor(v));
      }
      final d = decide(_packet(recipient: 9));
      expect(d.strategy, RelayStrategy.direct);
      expect(d.targets, [_id(9)]);
    });

    test('follows a fresh route to its next hop only', () {
      for (final v in [1, 2]) {
        table.neighborUp(_neighbor(v));
      }
      table.learnRoute(destId: _id(9), viaId: _id(2), relayHops: 1);
      final d = decide(_packet(recipient: 9));
      expect(d.strategy, RelayStrategy.route);
      expect(d.targets, [_id(2)]);
    });

    test('floods when nothing is known, limited by the fan-out', () {
      for (final v in [1, 2, 3, 4]) {
        table.neighborUp(_neighbor(v));
      }
      final d = decide(_packet(recipient: 9, sender: 8));
      expect(d.strategy, RelayStrategy.flood);
      expect(d.targets.length, 2);
    });

    test('never returns a packet to the neighbour it came from or to its author', () {
      for (final v in [1, 2, 3]) {
        table.neighborUp(_neighbor(v));
      }
      final d = decide(_packet(recipient: 9, sender: 3), from: _id(1));
      expect(d.targets, [_id(2)]);
    });

    test('does not resend to a neighbour that already has the packet', () {
      for (final v in [1, 2]) {
        table.neighborUp(_neighbor(v));
      }
      final sent = {
        _id(1): SentRecord(neighborId: _id(1), sentAtMs: clock.nowMs, sendCount: 1),
      };
      final d = decide(_packet(recipient: 9, sender: 8), sent: sent);
      expect(d.targets, [_id(2)]);
    });

    test('holds (sends nothing) when the only route\'s next hop already has it', () {
      table.neighborUp(_neighbor(2));
      table.learnRoute(destId: _id(9), viaId: _id(2), relayHops: 1);
      final sent = {
        _id(2): SentRecord(neighborId: _id(2), sentAtMs: clock.nowMs, sendCount: 1),
      };
      final d = decide(_packet(recipient: 9), sent: sent);
      expect(d.strategy, RelayStrategy.hold);
      expect(d.targets, isEmpty);
    });

    test('holds rather than flooding when the recipient neighbour was just sent a copy', () {
      table.neighborUp(_neighbor(9));
      table.neighborUp(_neighbor(2));
      final sent = {
        _id(9): SentRecord(neighborId: _id(9), sentAtMs: clock.nowMs, sendCount: 1),
      };
      final d = decide(_packet(recipient: 9), sent: sent);
      expect(d.strategy, RelayStrategy.hold);
      expect(d.targets, isEmpty);
    });

    test('with no neighbours at all there is nothing to do', () {
      final d = decide(_packet(recipient: 9));
      expect(d.targets, isEmpty);
    });

    test('announcements flood to a limited number of neighbours', () {
      for (final v in [1, 2, 3, 4]) {
        table.neighborUp(_neighbor(v));
      }
      for (final type in [PacketType.announce, PacketType.roomAnnounce]) {
        final d = decide(_packet(type: type, sender: 8));
        expect(d.strategy, RelayStrategy.flood, reason: type.name);
        expect(d.targets.length, 2, reason: '${type.name} respects the fan-out');
      }
    });

    group('group and room packets', () {
      for (final type in [PacketType.group, PacketType.room]) {
        test('${type.name}: go to every neighbour that lacks them, ignoring the fan-out', () {
          for (final v in [1, 2, 3, 4, 5]) {
            table.neighborUp(_neighbor(v));
          }
          final d = decide(_packet(type: type, sender: 8));
          expect(d.strategy, RelayStrategy.flood);
          expect(d.targets.toSet(), {for (final v in [1, 2, 3, 4, 5]) _id(v)});
        });

        test('${type.name}: never offered twice to the same neighbour', () {
          for (final v in [1, 2, 3]) {
            table.neighborUp(_neighbor(v));
          }
          final sent = {
            _id(1): SentRecord(neighborId: _id(1), sentAtMs: 0, sendCount: 1),
            _id(3): SentRecord(
                neighborId: _id(3),
                sentAtMs: 0,
                sendCount: OutboxRepository.neighborHasItCount),
          };
          final d = decide(_packet(type: type, sender: 8), sent: sent);
          expect(d.targets, [_id(2)]);
          // Even a very long time later: no second copy.
          clock.advance(const Duration(days: 1));
          expect(decide(_packet(type: type, sender: 8), sent: sent).targets, [_id(2)]);
        });

        test('${type.name}: skip the neighbour it came from and its author', () {
          for (final v in [1, 2, 3]) {
            table.neighborUp(_neighbor(v));
          }
          final d = decide(_packet(type: type, sender: 3), from: _id(1));
          expect(d.targets, [_id(2)]);
        });

        test('${type.name}: hold when everybody has it, and when nobody is around', () {
          expect(decide(_packet(type: type, sender: 8)).strategy, RelayStrategy.hold);
          table.neighborUp(_neighbor(1));
          final sent = {_id(1): SentRecord(neighborId: _id(1), sentAtMs: 0, sendCount: 1)};
          final d = decide(_packet(type: type, sender: 8), sent: sent);
          expect(d.strategy, RelayStrategy.hold);
          expect(d.targets, isEmpty);
        });
      }
    });
  });
}
