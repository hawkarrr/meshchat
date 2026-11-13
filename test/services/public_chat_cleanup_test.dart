import 'package:flutter_test/flutter_test.dart';
import 'package:offline_mesh_chat/models/conversation.dart';
import 'package:offline_mesh_chat/models/message.dart';
import 'package:offline_mesh_chat/protocol/mesh_packet.dart';
import 'package:offline_mesh_chat/services/encryption_service.dart';
import 'package:offline_mesh_chat/services/message_service.dart';

import '../support/fake_clock.dart';
import '../support/memory_network.dart';
import '../support/message_node.dart';
import '../support/test_node.dart';
import 'package:offline_mesh_chat/l10n/l10n.dart';

const _mesh = PublicRooms.meshIdHex;
const _room = 'rm:$_mesh';

/// The six-hour rule of public chats: what it removes, what it must never
/// touch, and that nothing it removed can come back.
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

  Future<void> everyone(Future<void> Function(MessageNode n) f) async {
    for (final n in nodes) {
      await f(n);
    }
    await run();
  }

  Future<List<String>> bodies(MessageNode n, String conversation) async =>
      [for (final m in await n.repo.getMessages(conversation)) m.body];

  group('six hours', () {
    test('a public message stays for six hours on every phone, then goes', () async {
      final a = await mk('Alice', 1);
      final b = await mk('Bob', 2);
      final c = await mk('Carol', 3);
      await connect([(a, b), (b, c)]);
      await a.service.rooms.sendText(_mesh, 'lunch at the square');
      await run();
      expect(await bodies(c, _room), ['lunch at the square']);

      clock.advance(const Duration(hours: 5, minutes: 59));
      await everyone((n) => n.service.maintain());
      for (final n in nodes) {
        expect(await bodies(n, _room), ['lunch at the square'], reason: '${n.name} at 5h59');
      }

      clock.advance(const Duration(minutes: 1));
      await everyone((n) => n.service.maintain());
      for (final n in nodes) {
        expect(await bodies(n, _room), isEmpty, reason: '${n.name} at 6h');
        expect((await n.repo.getConversation(_room))!.previewIn(englishStrings()), isNull);
      }
    });

    test('the six hours count from when this phone got the message', () async {
      final a = await mk('Alice', 1);
      final b = await mk('Bob', 2);
      await connect([(a, b)]);
      await a.service.rooms.sendText(_mesh, 'early');
      await run();
      clock.advance(const Duration(hours: 4));
      await b.service.rooms.sendText(_mesh, 'later');
      await run();

      clock.advance(const Duration(hours: 2, minutes: 1));
      await everyone((n) => n.service.maintain());
      for (final n in [a, b]) {
        expect(await bodies(n, _room), ['later'], reason: n.name);
      }
    });

    test('a phone that was switched off for a day cleans up as soon as it starts', () async {
      final a = await mk('Alice', 1);
      await a.service.rooms.sendText(_mesh, 'one');
      await a.service.rooms.sendText(_mesh, 'two');
      expect(await bodies(a, _room), hasLength(2));

      clock.advance(const Duration(days: 1));
      await a.service.start();

      expect(await bodies(a, _room), isEmpty, reason: 'nothing expired is ever shown');
    });

    test('running it again finds nothing more, and only a real clean-up is logged', () async {
      final a = await mk('Alice', 1);
      expect(await a.repo.lastPublicCleanup(), isNull);
      final empty = await a.service.publicCleanup.run();
      expect([empty.messages, empty.files], [0, 0]);
      expect(await a.repo.lastPublicCleanup(), isNull, reason: 'nothing happened, nothing to log');

      await a.service.rooms.sendText(_mesh, 'one');
      await a.service.rooms.sendText(_mesh, 'two');
      clock.advance(const Duration(hours: 6, minutes: 1));
      final first = await a.service.publicCleanup.run();
      final second = await a.service.publicCleanup.run();
      expect([first.messages, second.messages], [2, 0]);
      final logged = (await a.repo.lastPublicCleanup())!;
      expect([logged.at, logged.removed], [clock.nowMs, 2]);
    });
  });

  group('only public chats', () {
    test('private chats, groups, contacts and keys are never touched', () async {
      final a = await mk('Alice', 1);
      final b = await mk('Bob', 2);
      final c = await mk('Carol', 3);
      await connect([(a, b), (a, c), (b, c)]);
      final g = await a.service.groups.create(name: 'Family', memberIds: [b.id, c.id]);
      await run();
      await b.service.groups.accept(g.id);
      await c.service.groups.accept(g.id);
      await run();
      final gc = Conversation.groupConversationId(g.id);

      await a.service.sendDirect(b.id, 'private words');
      await a.service.sendText(gc, 'family words');
      await a.service.rooms.sendText(_mesh, 'public words');
      await run();

      clock.advance(const Duration(days: 7));
      await everyone((n) => n.service.maintain());

      expect(await bodies(a, 'dm:${b.id}'), ['private words']);
      expect(await bodies(b, 'dm:${a.id}'), ['private words']);
      for (final n in [a, b, c]) {
        expect(await bodies(n, gc), ['family words'], reason: n.name);
        expect(await bodies(n, _room), isEmpty, reason: n.name);
      }
      expect((await a.repo.getPeer(b.id)), isNotNull);
      expect((await b.repo.getConversation('dm:${a.id}')), isNotNull);
      expect((await a.service.groups.isActive(g.idBytes)), isTrue);
      expect(await a.repo.pinnedMessages(gc), isEmpty);
    });

    test('a private photo stays with its file, a public photo goes with its file', () async {
      final a = await mk('Alice', 1);
      final b = await mk('Bob', 2);
      await connect([(a, b)]);
      final bytes = fakeBytes(4000, 3);
      final privatePhoto = await a.service.sendMedia(
          'dm:${b.id}', MediaDraft(kind: MediaKind.image, bytes: bytes, width: 40, height: 30));
      await run();
      await a.service.sendMedia(
          _room, MediaDraft(kind: MediaKind.image, bytes: fakeBytes(4000, 4), width: 40, height: 30));
      await run();
      expect(a.mediaStore.files, hasLength(2));
      expect(b.mediaStore.files, hasLength(2));

      clock.advance(const Duration(hours: 6, minutes: 1));
      final result = await a.service.publicCleanup.run();
      await b.service.publicCleanup.run();

      expect(result.messages, 1);
      expect(result.files, 1);
      for (final n in [a, b]) {
        expect(n.mediaStore.files, hasLength(1), reason: '${n.name}: only the private photo is left');
        expect(await n.repo.getMessages(_room), isEmpty);
      }
      final kept = (await a.mediaOf(privatePhoto.id))!;
      expect(await a.service.media.read(kept), bytes);
    });

    test('pins and replies of expired messages follow them out; later replies stay a while',
        () async {
      final a = await mk('Alice', 1);
      final b = await mk('Bob', 2);
      await connect([(a, b)]);
      final question = await a.service.rooms.sendText(_mesh, 'who has a charger?');
      await run();
      await b.service.setPinned(_room, question.id, true);
      clock.advance(const Duration(hours: 3));
      final answer = await b.service.rooms.sendText(_mesh, 'me', replyToId: question.id);
      await run();

      clock.advance(const Duration(hours: 3, minutes: 1));
      await everyone((n) => n.service.maintain());

      expect(await b.message(question.id), isNull);
      expect(await b.repo.pinnedMessages(_room), isEmpty);
      final kept = (await b.message(answer.id))!;
      expect(kept.replyToId, question.id, reason: 'only an id; the quote is looked up and finds nothing');
      expect(await a.message(answer.id), isNotNull);

      clock.advance(const Duration(hours: 3));
      await everyone((n) => n.service.maintain());
      expect(await bodies(b, _room), isEmpty);
    });
  });

  group('what was removed does not come back', () {
    test('a late copy of an expired message is refused', () async {
      final a = await mk('Alice', 1);
      final b = await mk('Bob', 2);
      await a.service.rooms.sendText(_mesh, 'old news');
      final held = (await a.node.outbox.all()).where((e) {
        final p = MeshPacket.decode(e.packet);
        return p.type == PacketType.room && !p.isChunk;
      }).toList();
      expect(held, hasLength(1));
      final packet = MeshPacket.decode(held.single.packet);

      // The copy is acceptable while it is fresh ...
      await b.service.onRoomPacket(packet, relayHops: 1);
      expect(await bodies(b, _room), ['old news']);

      clock.advance(const Duration(hours: 6, minutes: 1));
      await b.service.maintain();
      expect(await bodies(b, _room), isEmpty);
      expect(await b.repo.wasRemoved(packet.messageIdHex), isTrue);

      // ... and refused once it has expired, however it reaches the phone.
      await b.service.onRoomPacket(packet, relayHops: 2);
      expect(await bodies(b, _room), isEmpty);
    });

    test('a message that could never be sent is given up on, then removed with the rest',
        () async {
      final a = await mk('Alice', 1);
      final sent = await a.service.rooms.sendText(_mesh, 'is anybody there?');
      await run();
      expect((await a.message(sent.id))!.status, MessageStatus.queued);

      clock.advance(const Duration(hours: 2, minutes: 1));
      await a.node.router.maintain();
      await run();
      expect((await a.message(sent.id))!.status, MessageStatus.failed);

      clock.advance(const Duration(hours: 4));
      await a.service.maintain();
      expect(await a.message(sent.id), isNull);
    });
  });
}
