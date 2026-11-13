import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:offline_mesh_chat/core/bytes.dart';
import 'package:offline_mesh_chat/database/message_repository.dart';
import 'package:offline_mesh_chat/models/conversation.dart';
import 'package:offline_mesh_chat/models/message.dart';
import 'package:offline_mesh_chat/protocol/mesh_packet.dart';
import 'package:offline_mesh_chat/protocol/protocol_constants.dart';
import 'package:offline_mesh_chat/services/message_service.dart';

import '../support/fake_clock.dart';
import '../support/memory_network.dart';
import '../support/message_node.dart';
import '../support/test_node.dart';
import 'package:offline_mesh_chat/l10n/l10n.dart';
import 'package:offline_mesh_chat/models/delivery_problem.dart';

void main() {
  late MemoryNetwork net;
  late FakeClock clock;
  final nodes = <MessageNode>[];

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

  Future<MessageNode> mk(String name, int seed) async {
    final n = await MessageNode.create(name, net, clock, seed: seed);
    nodes.add(n);
    return n;
  }

  Future<void> run() => settle(net, nodes.map((n) => n.node),
      extraBusy: () => nodes.any((n) => n.service.hasPendingWork));

  Future<void> connect(List<(MessageNode, MessageNode)> pairs) async {
    for (final (a, b) in pairs) {
      await net.connect(a.id, b.id);
    }
    await run();
  }

  /// Makes `from` aware of `to`'s keys, as an announcement would.
  Future<void> introduce(MessageNode to) async {
    await to.node.router.announceNow();
    await run();
  }

  Future<ChatMessage> only(MessageNode n, String conversationId) async {
    final all = await n.repo.getMessages(conversationId);
    expect(all, hasLength(1));
    return all.single;
  }

  group('sending and receiving', () {
    test('neighbours learn each other\'s keys during the link handshake and can chat', () async {
      final a = await mk('Alice', 1);
      final b = await mk('Bob', 2);
      await connect([(a, b)]);

      // Peers were recorded from the authenticated handshake.
      final bobAtAlice = await a.repo.getPeer(b.id);
      expect(bobAtAlice, isNotNull);
      expect(bobAtAlice!.nickname, 'Bob');
      expect(bobAtAlice.agreementKey, b.node.crypto.identity.agreementPublicKey);
      expect(bobAtAlice.verified, isFalse, reason: 'meeting someone never verifies them');

      final sent = await a.service.sendDirect(b.id, 'Hello Bob');
      expect(sent.status, MessageStatus.queued);
      await run();

      final atBob = await only(b, 'dm:${a.id}');
      expect(atBob.body, 'Hello Bob');
      expect(atBob.isOutgoing, isFalse);
      expect(atBob.status, MessageStatus.received);
      expect(atBob.hops, 0);
      expect((await b.repo.getConversation('dm:${a.id}'))!.unreadCount, 1);

      // The receipt came back.
      final atAlice = await only(a, 'dm:${b.id}');
      expect(atAlice.status, MessageStatus.delivered);
      expect(atAlice.hops, 0);
    });

    test('through a relay: delivered with the hop count, and the relay stores no message',
        () async {
      final a = await mk('Alice', 1);
      final b = await mk('Relay', 2);
      final c = await mk('Carol', 3);
      await connect([(a, b), (b, c)]);
      await introduce(c); // Alice learns Carol's encryption key from her announcement

      expect(await a.repo.getPeer(c.id), isNotNull);
      await a.service.sendDirect(c.id, 'Hi Carol, via the relay');
      await run();

      final atCarol = await only(c, 'dm:${a.id}');
      expect(atCarol.body, 'Hi Carol, via the relay');
      expect(atCarol.hops, 1);
      final atAlice = await only(a, 'dm:${c.id}');
      expect(atAlice.status, MessageStatus.delivered);
      expect(atAlice.hops, 1);

      // The relay carried it but kept no readable copy anywhere.
      expect(await b.repo.listConversations().then((l) => l.where((c) => c.id.startsWith('dm:${a.id}'))), isEmpty);
      final dump = StringBuffer();
      for (final e in await b.node.outbox.all()) {
        dump.write(utf8.decode(e.packet, allowMalformed: true));
      }
      expect(dump.toString(), isNot(contains('Hi Carol')));
    });

    test('the status moves queued -> sent -> delivered', () async {
      final a = await mk('Alice', 1);
      final b = await mk('Bob', 2);
      await connect([(a, b)]);
      // Take B out of range so the message stays pending.
      await net.disconnect(a.id, b.id);
      await run();
      final sent = await a.service.sendDirect(b.id, 'are you there?');
      await run();
      expect((await a.message(sent.id))!.status, MessageStatus.queued);

      await connect([(a, b)]);
      expect((await a.message(sent.id))!.status, MessageStatus.delivered);
    });

    test('a duplicated packet creates exactly one chat entry (acceptance criterion 5)', () async {
      final a = await mk('Alice', 1);
      final b = await mk('Bob', 2);
      await connect([(a, b)]);
      net.duplicateAll = true;
      await a.service.sendDirect(b.id, 'only once please');
      await run();
      expect(await b.chatWith(a), hasLength(1));
      expect((await b.repo.getConversation('dm:${a.id}'))!.unreadCount, 1);
    });

    test('replaying the very same packet bytes later adds nothing', () async {
      final a = await mk('Alice', 1);
      final b = await mk('Bob', 2);
      await connect([(a, b)]);
      await a.service.sendDirect(b.id, 'replay me');
      await run();
      final wire = net.log.firstWhere((d) =>
          d.toId == b.id && MeshPacket.decode(d.bytes).type == PacketType.direct);
      for (var i = 0; i < 5; i++) {
        b.node.transport.inject(a.id, wire.bytes);
      }
      await run();
      expect(await b.chatWith(a), hasLength(1));
    });

    test('a lost receipt is repaired: the sender retries and the recipient re-acknowledges',
        () async {
      final a = await mk('Alice', 1);
      final b = await mk('Bob', 2);
      await connect([(a, b)]);
      var dropped = false;
      net.onWire = (from, to, bytes) {
        if (from == b.id && !dropped && MeshPacket.decode(bytes).type == PacketType.ack) {
          dropped = true;
          return null;
        }
        return bytes;
      };
      final sent = await a.service.sendDirect(b.id, 'did my receipt get lost?');
      await run();
      expect((await a.message(sent.id))!.status, MessageStatus.sent);

      clock.advance(const Duration(seconds: 40));
      await a.node.router.flush();
      await run();
      expect((await a.message(sent.id))!.status, MessageStatus.delivered);
      expect(await b.chatWith(a), hasLength(1), reason: 'the retry must not create a second entry');
    });
  });

  group('refusals the user can understand', () {
    test('empty and oversized messages', () async {
      final a = await mk('Alice', 1);
      final b = await mk('Bob', 2);
      await connect([(a, b)]);
      await expectLater(
        a.service.sendDirect(b.id, '   '),
        throwsA(isA<MessageError>().having((e) => e.kind, 'kind', MessageErrorKind.empty)),
      );
      await expectLater(
        a.service.sendDirect(b.id, 'x' * (Protocol.maxTextBytes + 1)),
        throwsA(isA<MessageError>().having((e) => e.kind, 'kind', MessageErrorKind.tooLong)),
      );
      expect(await a.chatWith(b), isEmpty, reason: 'nothing may be stored for a refused message');
    });

    test('an unknown contact', () async {
      final a = await mk('Alice', 1);
      await expectLater(
        a.service.sendDirect('ab' * 32, 'hi'),
        throwsA(isA<MessageError>().having((e) => e.kind, 'kind', MessageErrorKind.unknownPeer)),
      );
    });

    test('a contact whose encryption key we have never seen', () async {
      final a = await mk('Alice', 1);
      final ghost = await mk('Ghost', 3);
      await a.repo.upsertPeer(signingKey: ghost.node.signingKey, seenAtMs: clock.nowMs); // no agreement key
      await expectLater(
        a.service.sendDirect(ghost.id, 'hello?'),
        throwsA(isA<MessageError>()
            .having((e) => e.kind, 'kind', MessageErrorKind.noEncryptionKey)
            .having((e) => e.message, 'message', contains("haven't received"))),
      );
    });

    test('a blocked contact', () async {
      final a = await mk('Alice', 1);
      final b = await mk('Bob', 2);
      await connect([(a, b)]);
      await a.repo.setBlocked(b.id, true);
      await expectLater(
        a.service.sendDirect(b.id, 'hi'),
        throwsA(isA<MessageError>().having((e) => e.kind, 'kind', MessageErrorKind.blocked)),
      );
    });
  });

  group('verification failures are visible, not hidden', () {
    test('a message encrypted to the wrong key is stored as "could not decrypt" and not acknowledged',
        () async {
      final a = await mk('Alice', 1);
      final b = await mk('Bob', 2);
      final mallory = await mk('Mallory', 9);
      await connect([(a, b)]);
      // Alice believes Bob's encryption key is Mallory's (a stale/substituted key).
      await a.repo.upsertPeer(
        signingKey: b.node.signingKey,
        agreementKey: mallory.node.agreementKey,
        seenAtMs: clock.nowMs,
      );
      final sent = await a.service.sendDirect(b.id, 'for bob, but sealed to the wrong key');
      await run();

      final atBob = await only(b, 'dm:${a.id}');
      expect(atBob.status, MessageStatus.undecryptable);
      expect(atBob.body, isEmpty);
      expect(atBob.error, isNotNull);
      final events = await b.repo.securityEvents();
      expect(events.map((e) => e.kind), contains(SecurityEventKind.decryptFailed));
      expect(events.first.peerId, a.id);
      // No receipt: the sender is not told "delivered" for something unreadable.
      expect((await a.message(sent.id))!.status, MessageStatus.sent);
      expect((await b.repo.getConversation('dm:${a.id}'))!.previewIn(englishStrings()),
          'Message could not be decrypted');
    });

    test('a tampered message never reaches the chat and is logged by the relay', () async {
      final a = await mk('Alice', 1);
      final b = await mk('Relay', 2);
      final c = await mk('Carol', 3);
      await connect([(a, b), (b, c)]);
      await introduce(c);
      var tampered = false;
      net.onWire = (from, to, bytes) {
        if (from == b.id &&
            to == c.id &&
            !tampered &&
            MeshPacket.decode(bytes).type == PacketType.direct) {
          tampered = true;
          return Uint8List.fromList(bytes)..[130] ^= 0x10;
        }
        return bytes;
      };
      await a.service.sendDirect(c.id, 'integrity please');
      await run();
      expect(await c.chatWith(a), isEmpty);
      expect((await c.repo.securityEvents()).map((e) => e.kind),
          contains(SecurityEventKind.badSignature));
    });

    test('a changed encryption key revokes verification and raises a warning', () async {
      final a = await mk('Alice', 1);
      final b = await mk('Bob', 2);
      await connect([(a, b)]);
      await a.repo.setVerified(b.id, true);
      final impostor = await mk('Impostor', 7);
      // The same signing identity suddenly presents a different encryption key.
      await a.repo.upsertPeer(
        signingKey: b.node.signingKey,
        agreementKey: impostor.node.agreementKey,
        seenAtMs: clock.nowMs,
      );
      // Bob's next genuine announcement restores the real key - and that is
      // itself a change from what Alice last held.
      await b.node.router.announceNow();
      await run();
      final peer = (await a.repo.getPeer(b.id))!;
      expect(peer.verified, isFalse);
      expect((await a.repo.securityEvents()).map((e) => e.kind),
          contains(SecurityEventKind.keyChanged));
    });

    test('messages from a blocked contact are dropped silently and not acknowledged', () async {
      final a = await mk('Alice', 1);
      final b = await mk('Bob', 2);
      await connect([(a, b)]);
      await b.repo.setBlocked(a.id, true);
      final sent = await a.service.sendDirect(b.id, 'you cannot hear me');
      await run();
      expect(await b.chatWith(a), isEmpty);
      expect((await a.message(sent.id))!.status, MessageStatus.sent);
    });
  });

  group('expiry and retry', () {
    test('an undeliverable message fails with an explanation, and can be sent again', () async {
      final a = await mk('Alice', 1);
      final b = await mk('Bob', 2);
      await connect([(a, b)]);
      await net.disconnect(a.id, b.id);
      await run();
      final sent = await a.service.sendDirect(b.id, 'will you ever get this?');
      await run();

      clock.advance(const Duration(hours: 13));
      await a.node.router.maintain();
      await run();
      final failed = (await a.message(sent.id))!;
      expect(failed.status, MessageStatus.failed);
      expect(failed.error, DeliveryProblem.expired.code);
      expect(DeliveryProblem.describe(englishStrings(), failed.error), contains('could not be reached'));

      // Bob comes back; the user taps "send again".
      await connect([(a, b)]);
      final fresh = await a.service.retry(sent.id);
      await run();
      expect(fresh.id, isNot(sent.id));
      expect(await a.message(sent.id), isNull, reason: 'the failed copy is replaced');
      expect((await a.message(fresh.id))!.status, MessageStatus.delivered);
      expect((await b.chatWith(a)).single.body, 'will you ever get this?');
    });

    test('only failed outgoing messages can be retried', () async {
      final a = await mk('Alice', 1);
      final b = await mk('Bob', 2);
      await connect([(a, b)]);
      final sent = await a.service.sendDirect(b.id, 'fine');
      await run();
      await expectLater(
        a.service.retry(sent.id),
        throwsA(isA<MessageError>().having((e) => e.kind, 'kind', MessageErrorKind.notRetryable)),
      );
    });
  });

  group('announcements and contacts', () {
    test('an announcement teaches a distant phone the key it needs to send', () async {
      final a = await mk('Alice', 1);
      final b = await mk('Relay', 2);
      final c = await mk('Carol', 3);
      await connect([(a, b), (b, c)]);
      expect(await a.repo.getPeer(c.id), isNull);
      await introduce(c);
      final carol = (await a.repo.getPeer(c.id))!;
      expect(carol.nickname, 'Carol');
      expect(carol.agreementKey, c.node.agreementKey);
      expect(carol.isContact, isFalse);
    });

    test('nicknames from the network are sanitised', () async {
      final a = await mk('Alice', 1);
      final b = await MessageNode.create('Bob', net, clock, seed: 2, nickname: 'Bo\u202Eb\u0007');
      nodes.add(b);
      await connect([(a, b)]);
      expect((await a.repo.getPeer(b.id))!.nickname, 'Bob');
    });

    test('sending marks the recipient as a contact', () async {
      final a = await mk('Alice', 1);
      final b = await mk('Bob', 2);
      await connect([(a, b)]);
      expect((await a.repo.getPeer(b.id))!.isContact, isFalse);
      await a.service.sendDirect(b.id, 'hi');
      expect((await a.repo.getPeer(b.id))!.isContact, isTrue);
    });
  });

  group('persistence', () {
    test('delivery state and history survive using a fresh repository on the same database',
        () async {
      final a = await mk('Alice', 1);
      final b = await mk('Bob', 2);
      await connect([(a, b)]);
      final sent = await a.service.sendDirect(b.id, 'remember me');
      await run();
      final again = MessageRepository(a.node.db.db);
      final stored = (await again.getMessage(sent.id))!;
      expect(stored.status, MessageStatus.delivered);
      expect(stored.body, 'remember me');
      expect((await again.listConversations()).map((c) => c.id), contains('dm:${b.id}'));
      expect(bytesToHex(Uint8List.fromList(utf8.encode(stored.body))), isNotEmpty);
      expect(Conversation.directId(b.id), 'dm:${b.id}');
    });
  });
}
