import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:offline_mesh_chat/database/message_repository.dart';
import 'package:offline_mesh_chat/models/message.dart';
import 'package:offline_mesh_chat/protocol/mesh_packet.dart';
import 'package:offline_mesh_chat/protocol/protocol_constants.dart';
import 'package:offline_mesh_chat/services/encryption_service.dart';
import 'package:offline_mesh_chat/services/message_service.dart';

import '../support/fake_clock.dart';
import '../support/memory_network.dart';
import '../support/message_node.dart';
import '../support/test_node.dart';

Matcher _error(MessageErrorKind kind) =>
    throwsA(isA<MessageError>().having((e) => e.kind, 'kind', kind));

const _mesh = PublicRooms.meshIdHex;

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

  Future<void> announceRooms(MessageNode n) async {
    await n.node.router.announceRoomsNow();
    await run();
  }

  Future<List<ChatMessage>> inRoom(MessageNode n, String roomId) =>
      n.repo.getMessages('rm:$roomId');

  group('#mesh', () {
    test('every phone starts with it: joined, with a conversation', () async {
      final a = await mk('Alice', 1);
      final room = (await a.service.rooms.get(_mesh))!;
      expect(room.builtin, isTrue);
      expect(room.joined, isTrue);
      expect(room.label, '#mesh');
      final conversation = (await a.repo.getConversation('rm:$_mesh'))!;
      expect(conversation.title, '#mesh');
      expect(conversation.isRoom, isTrue);
    });

    test('everyone in range reads what others post, with the sender named', () async {
      final a = await mk('Alice', 1);
      final b = await mk('Bob', 2);
      final c = await mk('Carol', 3);
      await connect([(a, b), (b, c)]);

      final sent = await a.service.rooms.sendText(_mesh, 'hello mesh');
      await run();

      for (final n in [b, c]) {
        final got = (await inRoom(n, _mesh)).single;
        expect(got.body, 'hello mesh');
        expect(got.senderNickname, 'Alice');
        expect(got.senderId, a.id);
        expect(got.isOutgoing, isFalse);
      }
      expect((await inRoom(c, _mesh)).single.hops, 1);
      expect((await b.repo.getConversation('rm:$_mesh'))!.unreadCount, 1);
      expect((await a.message(sent.id))!.status, MessageStatus.sent,
          reason: 'a public room has no receipts, so "sent" is as far as it goes');
    });

    test('a phone that arrives later still gets recent messages from a carrier', () async {
      final a = await mk('Alice', 1);
      final b = await mk('Bob', 2);
      final c = await mk('Carol', 3);
      await connect([(a, b)]);
      await a.service.rooms.sendText(_mesh, 'earlier today');
      await run();
      clock.advance(const Duration(minutes: 45));
      await connect([(b, c)]);
      expect((await inRoom(c, _mesh)).single.body, 'earlier today');
    });

    test('a nickname can be faked, but the real author is always known', () async {
      final a = await mk('Alice', 1);
      final mallory = await MessageNode.create('Mallory', net, clock, seed: 9, nickname: 'Alice');
      nodes.add(mallory);
      await connect([(a, mallory)]);
      await mallory.service.rooms.sendText(_mesh, 'I am Alice, trust me');
      await run();
      final got = (await inRoom(a, _mesh)).single;
      expect(got.senderNickname, 'Alice');
      expect(got.senderId, mallory.id);
      expect(got.senderId, isNot(a.id));
    });

    test('it cannot be left, and empty or oversize posts are refused', () async {
      final a = await mk('Alice', 1);
      await expectLater(a.service.rooms.leave(_mesh), _error(MessageErrorKind.notJoined));
      await expectLater(a.service.rooms.sendText(_mesh, ' '), _error(MessageErrorKind.empty));
      await expectLater(a.service.rooms.sendText(_mesh, 'x' * (Protocol.maxTextBytes + 1)),
          _error(MessageErrorKind.tooLong));
    });

    test('a message from a blocked person is not shown', () async {
      final a = await mk('Alice', 1);
      final b = await mk('Bob', 2);
      await connect([(a, b)]);
      await b.repo.setBlocked(a.id, true);
      await a.service.rooms.sendText(_mesh, 'ignore me');
      await run();
      expect(await inRoom(b, _mesh), isEmpty);
    });

    test('sendText works through the conversation id for rooms too', () async {
      final a = await mk('Alice', 1);
      final b = await mk('Bob', 2);
      await connect([(a, b)]);
      await a.service.sendText('rm:$_mesh', 'via the facade');
      await run();
      expect((await inRoom(b, _mesh)).single.body, 'via the facade');
    });
  });

  group('creating a room', () {
    test('it is joined, signed by us, and gets a conversation', () async {
      final a = await mk('Alice', 1);
      final room = await a.service.rooms.create(name: '  #Cafe  ', description: 'Tables 1-9');
      expect(room.name, 'Cafe');
      expect(room.label, '#Cafe');
      expect(room.description, 'Tables 1-9');
      expect(room.joined, isTrue);
      expect(room.isMine(a.id), isTrue);
      expect(room.version, 1);
      expect(room.id, isNot(_mesh));
      final record = RoomRecord.parse(room.record!);
      expect(await EncryptionService.verifyRoomRecord(record), isTrue);
      expect((await a.repo.getConversation('rm:${room.id}'))!.title, '#Cafe');
    });

    test('names are cleaned, and empty ones refused', () async {
      final a = await mk('Alice', 1);
      await expectLater(a.service.rooms.create(name: ' ## '), _error(MessageErrorKind.invalidName));
      await expectLater(a.service.rooms.create(name: '   '), _error(MessageErrorKind.invalidName));
      final room = await a.service.rooms.create(name: 'Ca\u202Efe\u0007 ${'x' * 60}');
      expect(room.name, startsWith('Cafe x'));
      expect(room.name.length, lessThanOrEqualTo(Protocol.maxRoomNameBytes));
      expect(room.name.codeUnits.where((c) => c == 0x202E || c == 7), isEmpty);
    });
  });

  group('discovery', () {
    test('neighbours learn a room from its announcement, without joining it', () async {
      final a = await mk('Alice', 1);
      final b = await mk('Bob', 2);
      await connect([(a, b)]);
      final room = await a.service.rooms.create(name: 'Cafe');
      await announceRooms(a);

      final seen = (await b.service.rooms.get(room.id))!;
      expect(seen.name, 'Cafe');
      expect(seen.joined, isFalse);
      expect(seen.creatorId, a.id);
      expect(seen.record, room.record);
      expect(await b.repo.getConversation('rm:${room.id}'), isNull);
      expect((await b.service.rooms.list()).map((r) => r.label), ['#mesh', '#Cafe']);
    });

    test('a phone that did not join does not receive the room\'s messages', () async {
      final a = await mk('Alice', 1);
      final b = await mk('Bob', 2);
      await connect([(a, b)]);
      final room = await a.service.rooms.create(name: 'Cafe');
      await announceRooms(a);
      await a.service.rooms.sendText(room.id, 'espresso is ready');
      await run();
      expect(await inRoom(b, room.id), isEmpty);
    });

    test('joining lets you read and post; before that, posting is refused', () async {
      final a = await mk('Alice', 1);
      final b = await mk('Bob', 2);
      await connect([(a, b)]);
      final room = await a.service.rooms.create(name: 'Cafe');
      await announceRooms(a);

      await expectLater(b.service.rooms.sendText(room.id, 'hi'), _error(MessageErrorKind.notJoined));
      final joined = await b.service.rooms.join(room.id);
      expect(joined.joined, isTrue);
      expect((await b.repo.getConversation('rm:${room.id}'))!.title, '#Cafe');

      await a.service.rooms.sendText(room.id, 'welcome');
      await run();
      clock.advance(const Duration(seconds: 5));
      await b.service.rooms.sendText(room.id, 'thanks');
      await run();
      expect((await inRoom(b, room.id)).map((m) => m.body), ['welcome', 'thanks']);
      expect((await inRoom(a, room.id)).map((m) => m.body), ['welcome', 'thanks']);
    });

    test('a room is passed along: a phone arriving later learns it from a relay', () async {
      final a = await mk('Alice', 1);
      final r = await mk('Relay', 2);
      final c = await mk('Carol', 3);
      await connect([(a, r)]);
      final room = await a.service.rooms.create(name: 'Cafe');
      await announceRooms(a);
      expect(await r.service.rooms.get(room.id), isNotNull);

      // Alice walks away. Carol meets the relay, which tells her about the room.
      await net.disconnect(a.id, r.id);
      await run();
      await connect([(r, c)]);
      await announceRooms(r);
      final atCarol = (await c.service.rooms.get(room.id))!;
      expect(atCarol.name, 'Cafe');
      expect(atCarol.creatorId, a.id);
    });

    test('hearing a room again does not make it noisy: it is passed on only when news', () async {
      final a = await mk('Alice', 1);
      final b = await mk('Bob', 2);
      final c = await mk('Carol', 3);
      await connect([(a, b), (b, c)]);
      await a.service.rooms.create(name: 'Cafe');
      await announceRooms(a);
      final firstRound = net.log.length;
      await announceRooms(a); // the same, unchanged record again
      // b already knew it, so it adds nothing to forward: only Alice's own packet moves.
      final announcements = net.log
          .skip(firstRound)
          .where((d) => MeshPacket.decode(d.bytes).type == PacketType.roomAnnounce)
          .toList();
      expect(announcements.where((d) => d.fromId == b.id), isEmpty);
    });

    test('leaving removes the history and the conversation', () async {
      final a = await mk('Alice', 1);
      final b = await mk('Bob', 2);
      await connect([(a, b)]);
      final room = await a.service.rooms.create(name: 'Cafe');
      await announceRooms(a);
      await b.service.rooms.join(room.id);
      await a.service.rooms.sendText(room.id, 'hello');
      await run();
      expect(await inRoom(b, room.id), hasLength(1));

      await b.service.rooms.leave(room.id);
      expect(await b.repo.getConversation('rm:${room.id}'), isNull);
      expect(await inRoom(b, room.id), isEmpty);
      expect((await b.service.rooms.get(room.id))!.joined, isFalse);
      // Later messages are not kept either.
      await a.service.rooms.sendText(room.id, 'still here?');
      await run();
      expect(await inRoom(b, room.id), isEmpty);
    });

    test('joining a room nobody has heard of is refused', () async {
      final a = await mk('Alice', 1);
      await expectLater(a.service.rooms.join('ab' * 32), _error(MessageErrorKind.unknownRoom));
    });
  });

  group('hostile announcements', () {
    test('a copy of someone else\'s room id under another key is ignored', () async {
      final a = await mk('Alice', 1);
      final b = await mk('Bob', 2);
      final mallory = await mk('Mallory', 9);
      await connect([(a, b), (mallory, b)]);
      final room = await a.service.rooms.create(name: 'Cafe');
      await announceRooms(a);

      final real = RoomRecord.parse(room.record!);
      final fake = RoomRecord(
        roomId: real.roomId,
        name: 'Cafe (official)',
        description: 'send money here',
        creatorKey: mallory.node.signingKey,
        createdAtMs: real.createdAtMs,
        expiresAtMs: real.expiresAtMs,
        version: 99,
        signature: Uint8List(64),
      );
      final signed = fake.withSignature(await mallory.node.crypto.sign(fake.signingBytes()));
      b.node.transport.inject(
          mallory.id, (await mallory.node.crypto.buildRoomAnnounce(signed)).encode());
      await run();

      final atBob = (await b.service.rooms.get(room.id))!;
      expect(atBob.name, 'Cafe');
      expect(atBob.creatorId, a.id);
      expect(atBob.version, 1);
      expect((await b.repo.securityEvents()).map((e) => e.kind),
          contains(SecurityEventKind.badSignature));
    });

    test('a record altered after it was signed is rejected', () async {
      final a = await mk('Alice', 1);
      final b = await mk('Bob', 2);
      final mallory = await mk('Mallory', 9);
      await connect([(mallory, b)]);
      final room = await a.service.rooms.create(name: 'Cafe', description: 'Tables');
      final real = RoomRecord.parse(room.record!);
      final altered = RoomRecord(
        roomId: real.roomId,
        name: real.name,
        description: 'wire money to Mallory',
        creatorKey: real.creatorKey,
        createdAtMs: real.createdAtMs,
        expiresAtMs: real.expiresAtMs,
        version: real.version,
        signature: real.signature,
      );
      b.node.transport.inject(
          mallory.id, (await mallory.node.crypto.buildRoomAnnounce(altered)).encode());
      await run();
      expect(await b.service.rooms.get(room.id), isNull);
    });

    test('records with an absurd lifetime or hidden control characters are refused', () async {
      final a = await mk('Alice', 1);
      final b = await mk('Bob', 2);
      await connect([(a, b)]);
      final forever = await a.node.crypto.createRoomRecord(name: 'Forever', lifetime: const Duration(days: 60));
      final sneaky = await a.node.crypto.createRoomRecord(name: 'Ca\u202Efe');
      for (final r in [forever, sneaky]) {
        b.node.transport.inject(a.id, (await a.node.crypto.buildRoomAnnounce(r)).encode());
        await run();
        expect(await b.service.rooms.get(r.roomIdHex), isNull, reason: r.name);
      }
    });

    test('an expired record is refused', () async {
      final a = await mk('Alice', 1);
      final b = await mk('Bob', 2);
      await connect([(a, b)]);
      final short = await a.node.crypto.createRoomRecord(name: 'Brief', lifetime: const Duration(minutes: 10));
      final packet = await a.node.crypto.buildRoomAnnounce(short);
      clock.advance(const Duration(minutes: 11));
      b.node.transport.inject(a.id, packet.encode());
      await run();
      expect(await b.service.rooms.get(short.roomIdHex), isNull);
    });

    test('a creator cannot be impersonated into refreshing someone else\'s room', () async {
      final a = await mk('Alice', 1);
      final mallory = await mk('Mallory', 9);
      final room = await a.service.rooms.create(name: 'Cafe');
      await expectLater(
        mallory.node.crypto.refreshRoomRecord(RoomRecord.parse(room.record!)),
        throwsArgumentError,
      );
    });
  });

  group('expiry and renewal', () {
    test('a room nobody renews disappears for people who only heard of it', () async {
      final a = await mk('Alice', 1);
      final b = await mk('Bob', 2);
      await connect([(a, b)]);
      final room = await a.service.rooms.create(name: 'Cafe');
      await announceRooms(a);
      expect(await b.service.rooms.get(room.id), isNotNull);

      await net.disconnect(a.id, b.id);
      await run();
      clock.advance(const Duration(hours: 25));
      await b.service.maintain();
      expect(await b.service.rooms.get(room.id), isNull);
    });

    test('the creator renews it before it lapses, so it stays known', () async {
      final a = await mk('Alice', 1);
      final b = await mk('Bob', 2);
      await connect([(a, b)]);
      final room = await a.service.rooms.create(name: 'Cafe');
      await announceRooms(a);
      expect((await b.service.rooms.get(room.id))!.version, 1);

      clock.advance(const Duration(hours: 14)); // under 12 h left
      await announceRooms(a);
      final renewed = (await b.service.rooms.get(room.id))!;
      expect(renewed.version, 2);
      expect((await a.service.rooms.get(room.id))!.version, 2);

      clock.advance(const Duration(hours: 14));
      await b.service.maintain();
      expect(await b.service.rooms.get(room.id), isNotNull, reason: 'renewed, so still alive');
    });

    test('a joined room outlives its record: the room and its conversation stay', () async {
      final a = await mk('Alice', 1);
      final b = await mk('Bob', 2);
      await connect([(a, b)]);
      final room = await a.service.rooms.create(name: 'Cafe');
      await announceRooms(a);
      await b.service.rooms.join(room.id);
      await a.service.rooms.sendText(room.id, 'remember this');
      await run();

      await net.disconnect(a.id, b.id);
      await run();
      clock.advance(const Duration(hours: 5));
      await b.service.maintain();
      expect((await inRoom(b, room.id)).single.body, 'remember this',
          reason: 'public messages are kept for six hours');

      clock.advance(const Duration(days: 3));
      await b.service.maintain();
      expect(await b.service.rooms.get(room.id), isNotNull);
      expect(await b.repo.getConversation('rm:${room.id}'), isNotNull);
      expect(await inRoom(b, room.id), isEmpty, reason: 'but the history is gone after six hours');
    });
  });
}
