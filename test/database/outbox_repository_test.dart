import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:offline_mesh_chat/database/database_helper.dart';
import 'package:offline_mesh_chat/database/outbox_repository.dart';

import '../support/test_database.dart';

OutboxEntry _entry(
  String id, {
  OutboxKind kind = OutboxKind.own,
  String sender = 'sender',
  String? recipient = 'recipient',
  int created = 1000,
  int expires = 100000,
  int next = 1000,
}) =>
    OutboxEntry(
      messageId: id,
      kind: kind,
      senderId: sender,
      recipientId: recipient,
      packet: Uint8List.fromList([1, 2, 3, 4]),
      createdAtMs: created,
      expiresAtMs: expires,
      nextAttemptAtMs: next,
    );

void main() {
  late DatabaseHelper helper;
  late OutboxRepository outbox;

  setUp(() async {
    helper = await openMemoryDatabase();
    outbox = OutboxRepository(helper.db);
  });

  tearDown(() => helper.close());

  group('queue', () {
    test('enqueue stores the packet bytes and refuses duplicates', () async {
      expect(await outbox.enqueue(_entry('a')), isTrue);
      expect(await outbox.enqueue(_entry('a')), isFalse);
      final e = (await outbox.get('a'))!;
      expect(e.packet, [1, 2, 3, 4]);
      expect(e.kind, OutboxKind.own);
      expect(await outbox.count(), 1);
    });

    test('due() returns only entries whose time has come and that have not expired', () async {
      await outbox.enqueue(_entry('now', next: 1000));
      await outbox.enqueue(_entry('later', next: 5000));
      await outbox.enqueue(_entry('dead', next: 1000, expires: 1500));
      expect((await outbox.due(1000)).map((e) => e.messageId), ['now', 'dead']);
      expect((await outbox.due(2000)).map((e) => e.messageId), ['now']);
      expect((await outbox.due(5000)).map((e) => e.messageId), ['now', 'later']);
    });

    test('recordAttempt counts attempts and schedules the next one', () async {
      await outbox.enqueue(_entry('a', next: 1000));
      await outbox.recordAttempt('a', nextAttemptAtMs: 9000);
      await outbox.recordAttempt('a', nextAttemptAtMs: 19000);
      final e = (await outbox.get('a'))!;
      expect(e.attempts, 2);
      expect(e.nextAttemptAtMs, 19000);
      expect(await outbox.due(5000), isEmpty);
    });

    test('makeDueNow pulls every future retry forward (topology changed)', () async {
      await outbox.enqueue(_entry('a', next: 50000));
      await outbox.enqueue(_entry('b', next: 90000));
      await outbox.makeDueNow(2000);
      expect((await outbox.due(2000)).length, 2);
    });

    test('expired entries are reported before removal so callers can fail them', () async {
      await outbox.enqueue(_entry('old', expires: 1500));
      await outbox.enqueue(_entry('live', expires: 9000));
      expect((await outbox.expired(2000)).map((e) => e.messageId), ['old']);
      expect(await outbox.removeExpired(2000), 1);
      expect((await outbox.all()).map((e) => e.messageId), ['live']);
    });

    test('relay entries are counted per sender and can be capped, own entries never evicted', () async {
      await outbox.enqueue(_entry('own1', kind: OutboxKind.own, created: 1));
      for (var i = 0; i < 6; i++) {
        await outbox.enqueue(_entry('r$i',
            kind: OutboxKind.relay, sender: i < 4 ? 'spammer' : 'other', created: 10 + i));
      }
      expect(await outbox.countRelayBySender('spammer'), 4);
      expect(await outbox.countRelayBySender('other'), 2);
      expect(await outbox.evictOldestRelay(keep: 3), 3);
      expect((await outbox.all()).map((e) => e.messageId), ['own1', 'r3', 'r4', 'r5']);
      expect(await outbox.evictOldestRelay(keep: 10), 0);
    });

    test('due() serves the most urgent class first, then the oldest', () async {
      Future<void> add(String id, int priority, int created) => outbox.enqueue(OutboxEntry(
            messageId: id,
            kind: OutboxKind.own,
            senderId: 's',
            packet: Uint8List(1),
            createdAtMs: created,
            expiresAtMs: 100000,
            nextAttemptAtMs: 0,
            priority: priority,
          ));
      await add('chunk-old', OutboxPriority.chunk, 1);
      await add('message', OutboxPriority.message, 2);
      await add('direct', OutboxPriority.direct, 3);
      await add('ack', OutboxPriority.ack, 4);
      await add('chunk-new', OutboxPriority.chunk, 5);
      expect((await outbox.due(10)).map((e) => e.messageId),
          ['ack', 'direct', 'message', 'chunk-old', 'chunk-new']);
    });

    test('priority and the flood flag are stored and default to a plain direct packet', () async {
      await outbox.enqueue(_entry('plain'));
      final plain = (await outbox.get('plain'))!;
      expect(plain.priority, OutboxPriority.direct);
      expect(plain.flood, isFalse);
      await outbox.enqueue(OutboxEntry(
        messageId: 'fl',
        kind: OutboxKind.relay,
        senderId: 's',
        packet: Uint8List(1),
        createdAtMs: 1,
        expiresAtMs: 100000,
        nextAttemptAtMs: 0,
        priority: OutboxPriority.chunk,
        flood: true,
      ));
      final fl = (await outbox.get('fl'))!;
      expect(fl.priority, OutboxPriority.chunk);
      expect(fl.flood, isTrue);
    });

    test('directed and flood relay entries have separate quotas and eviction', () async {
      Future<void> relay(String id, {required bool flood, required int created, String sender = 's'}) =>
          outbox.enqueue(OutboxEntry(
            messageId: id,
            kind: OutboxKind.relay,
            senderId: sender,
            packet: Uint8List(1),
            createdAtMs: created,
            expiresAtMs: 100000,
            nextAttemptAtMs: 0,
            flood: flood,
          ));
      for (var i = 0; i < 3; i++) {
        await relay('d$i', flood: false, created: i);
      }
      for (var i = 0; i < 5; i++) {
        await relay('f$i', flood: true, created: 10 + i);
      }
      expect(await outbox.countRelayBySender('s'), 3);
      expect(await outbox.countRelayBySender('s', flood: true), 5);

      // Trimming the flood class never touches directed packets...
      expect(await outbox.evictOldestRelay(keep: 2, flood: true), 3);
      expect((await outbox.all()).map((e) => e.messageId),
          ['d0', 'd1', 'd2', 'f3', 'f4']);
      // ...and trimming directed packets never touches the flood class.
      expect(await outbox.evictOldestRelay(keep: 1), 2);
      expect((await outbox.all()).map((e) => e.messageId), ['d2', 'f3', 'f4']);
    });
  });

  group('per-neighbour send tracking', () {
    setUp(() => outbox.enqueue(_entry('m')));

    test('recordSent counts repeated sends to the same neighbour', () async {
      await outbox.recordSent('m', 'n1', 100);
      await outbox.recordSent('m', 'n1', 200);
      await outbox.recordSent('m', 'n2', 300);
      final sent = await outbox.sentTo('m');
      expect(sent['n1']!.sendCount, 2);
      expect(sent['n1']!.sentAtMs, 200);
      expect(sent['n2']!.sendCount, 1);
    });

    test('removing the packet removes its send history', () async {
      await outbox.recordSent('m', 'n1', 100);
      await outbox.remove('m');
      expect(await outbox.sentTo('m'), isEmpty);
    });

    test('recording a send for a packet that is no longer queued is harmless', () async {
      await outbox.remove('m');
      await outbox.recordSent('m', 'n1', 100);
      expect(await outbox.sentTo('m'), isEmpty);
    });
  });

  group('seen ids', () {
    test('only unexpired ids are loaded, and pruning removes the rest', () async {
      await outbox.addSeen('live', 5000);
      await outbox.addSeen('dead', 500);
      expect((await outbox.loadSeen(1000)).keys, ['live']);
      expect(await outbox.pruneSeen(1000), 1);
      expect((await outbox.loadSeen(0)).keys, ['live']);
    });

    test('re-adding extends the expiry instead of failing', () async {
      await outbox.addSeen('x', 1000);
      await outbox.addSeen('x', 9000);
      expect((await outbox.loadSeen(2000))['x'], 9000);
    });
  });
}
