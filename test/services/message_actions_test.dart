import 'package:flutter_test/flutter_test.dart';
import 'package:offline_mesh_chat/core/bytes.dart';
import 'package:offline_mesh_chat/database/message_repository.dart';
import 'package:offline_mesh_chat/models/conversation.dart';
import 'package:offline_mesh_chat/models/message.dart';
import 'package:offline_mesh_chat/protocol/mesh_packet.dart';
import 'package:offline_mesh_chat/protocol/protocol_constants.dart';
import 'package:offline_mesh_chat/services/encryption_service.dart';
import 'package:offline_mesh_chat/services/message_service.dart';

import '../support/fake_clock.dart';
import '../support/memory_network.dart';
import '../support/message_node.dart';
import '../support/test_node.dart';
import 'package:offline_mesh_chat/l10n/l10n.dart';

Matcher _error(MessageErrorKind kind) =>
    throwsA(isA<MessageError>().having((e) => e.kind, 'kind', kind));

const _mesh = PublicRooms.meshIdHex;

/// Deleting, editing, replying, forwarding and pinning, between real phones on
/// the in-memory mesh: what the other side sees, what it is told, and what it
/// must refuse.
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

  Future<void> cut(MessageNode a, MessageNode b) async {
    await net.disconnect(a.id, b.id);
    await run();
  }

  /// Two phones that have met and can chat.
  Future<(MessageNode, MessageNode)> pair() async {
    final a = await mk('Alice', 1);
    final b = await mk('Bob', 2);
    await connect([(a, b)]);
    return (a, b);
  }

  /// A group of three phones that all know each other, everybody a member.
  Future<(MessageNode, MessageNode, MessageNode, String, String)> trio() async {
    final a = await mk('Alice', 1);
    final b = await mk('Bob', 2);
    final c = await mk('Carol', 3);
    await connect([(a, b), (a, c), (b, c)]);
    final g = await a.service.groups.create(name: 'Family', memberIds: [b.id, c.id]);
    await run();
    await b.service.groups.accept(g.id);
    await c.service.groups.accept(g.id);
    await run();
    return (a, b, c, g.id, Conversation.groupConversationId(g.id));
  }

  Future<List<SecurityEvent>> refusals(MessageNode n) async =>
      (await n.repo.securityEvents()).where((e) => e.kind == SecurityEventKind.unauthorizedChange).toList();

  /// A request someone wrote by hand to a private chat, as a hostile phone would.
  Future<void> forgeDirect(MessageNode from, MessageNode to, Envelope e) async {
    final peer = (await from.repo.getPeer(to.id))!;
    final packet = await from.node.crypto.buildDirectEnvelope(
      recipientSigningKey: peer.signingKey,
      recipientAgreementKey: peer.agreementKey!,
      envelope: e,
    );
    await from.node.router.submit(packet);
    await run();
  }

  Future<void> forgeGroup(MessageNode from, String groupId, Envelope e) async {
    final MeshPacket packet = await from.service.groups.buildEnvelopePacket(groupId, e);
    await from.node.router.submit(packet);
    await run();
  }

  Future<void> forgeRoom(MessageNode from, Envelope e) async {
    final MeshPacket packet = await from.service.rooms.buildEnvelopePacket(_mesh, e);
    await from.node.router.submit(packet);
    await run();
  }

  DeleteEnvelope deleteOf(String id) => DeleteEnvelope([hexToBytes(id)]);

  group('delete for me', () {
    test('removes it here and leaves the other phone alone, with no placeholder', () async {
      final (a, b) = await pair();
      final sent = await a.service.sendDirect(b.id, 'keep me at Alice');
      await run();

      final r = await b.service.actions.deleteForMe('dm:${a.id}', [sent.id]);
      await run();

      expect(r.removed, 1);
      expect(r.askedOthers, isFalse);
      expect(await b.message(sent.id), isNull);
      expect(await b.repo.getMessages('dm:${a.id}'), isEmpty);
      expect((await a.message(sent.id))!.body, 'keep me at Alice');
      expect(await a.repo.deletionRequestState(sent.id), isNull, reason: 'nobody was asked');
    });

    test('a message that has not left the phone yet is never sent', () async {
      final (a, b) = await pair();
      await cut(a, b);
      final sent = await a.service.sendDirect(b.id, 'oops, wrong chat');
      await run();
      expect((await a.message(sent.id))!.status, MessageStatus.queued);

      final r = await a.service.actions.deleteForMe('dm:${b.id}', [sent.id]);
      expect([r.removed, r.cancelled], [1, 1]);

      await connect([(a, b)]);
      expect(await b.repo.getMessages('dm:${a.id}'), isEmpty, reason: 'it was cancelled');
      expect(await a.repo.getMessages('dm:${b.id}'), isEmpty);
    });

    test('its pin goes with it, and the chat list falls back to the previous message', () async {
      final (a, b) = await pair();
      final first = await a.service.sendDirect(b.id, 'first');
      await run();
      final second = await a.service.sendDirect(b.id, 'second');
      await run();
      await b.service.setPinned('dm:${a.id}', second.id, true);
      expect((await b.repo.pinnedMessages('dm:${a.id}')).single.id, second.id);

      await b.service.actions.deleteForMe('dm:${a.id}', [second.id]);
      expect(await b.repo.pinnedMessages('dm:${a.id}'), isEmpty);
      expect((await b.repo.getConversation('dm:${a.id}'))!.previewIn(englishStrings()), 'first');
      expect((await b.message(first.id)), isNotNull);
    });

    test('a photo is removed from the phone together with the message', () async {
      final (a, b) = await pair();
      final sent = await a.service.sendMedia(
        'dm:${b.id}',
        MediaDraft(kind: MediaKind.image, bytes: fakeBytes(5000), width: 320, height: 240),
      );
      await run();
      expect(b.mediaStore.files, isNotEmpty);

      await b.service.actions.deleteForMe('dm:${a.id}', [sent.id]);
      expect(b.mediaStore.files, isEmpty, reason: 'the picture file is deleted, not just hidden');
      expect(await b.mediaOf(sent.id), isNull);
      expect(a.mediaStore.files, isNotEmpty, reason: "Alice's copy is hers");
    });
  });

  group('delete for everyone: private chat', () {
    test('both phones lose it, nothing is left behind, and the request is confirmed', () async {
      final (a, b) = await pair();
      final sent = await a.service.sendDirect(b.id, 'regret');
      await run();

      final r = await a.service.actions.deleteForEveryone('dm:${b.id}', [sent.id]);
      expect([r.removed, r.askedOthers], [1, true]);
      await run();

      expect(await a.message(sent.id), isNull);
      expect(await b.message(sent.id), isNull);
      expect(await b.repo.getMessages('dm:${a.id}'), isEmpty);
      expect((await b.repo.getConversation('dm:${a.id}'))!.previewIn(englishStrings()), isNull);
      expect(await a.repo.deletionRequestState(sent.id), 'delivered',
          reason: 'Bob confirmed it, so this is no longer just a hope');
    });

    test('forty messages at once go out in batches, and every one is gone on both phones', () async {
      final (a, b) = await pair();
      final ids = <String>[];
      for (var i = 0; i < 40; i++) {
        ids.add((await a.service.sendDirect(b.id, 'message $i')).id);
      }
      await run();
      expect((await b.repo.getMessages('dm:${a.id}')).length, 40);

      final r = await a.service.actions.deleteForEveryone('dm:${b.id}', ids);
      expect([r.removed, r.askedOthers], [40, true]);
      await run();

      expect(await a.repo.getMessages('dm:${b.id}'), isEmpty);
      expect(await b.repo.getMessages('dm:${a.id}'), isEmpty);
      for (final id in ids) {
        expect(await a.repo.deletionRequestState(id), 'delivered', reason: 'message $id');
      }
      expect((Protocol.maxDeleteBatch * 2) < ids.length, isTrue, reason: 'this really took three requests');
    });

    test('a phone that is out of reach keeps it until the request arrives', () async {
      final (a, b) = await pair();
      final sent = await a.service.sendDirect(b.id, 'regret');
      await run();
      await cut(a, b);

      final r = await a.service.actions.deleteForEveryone('dm:${b.id}', [sent.id]);
      await run();

      expect(r.askedOthers, isTrue);
      expect(await a.message(sent.id), isNull, reason: 'gone here at once');
      expect(await b.message(sent.id), isNotNull, reason: 'Bob has not heard yet');
      expect(await a.repo.deletionRequestState(sent.id), 'queued',
          reason: 'the screen can say it is still waiting');

      await connect([(a, b)]);
      expect(await b.message(sent.id), isNull);
      expect(await a.repo.deletionRequestState(sent.id), 'delivered');
    });

    test('a request nobody confirms in time is reported as expired, not as done', () async {
      final (a, b) = await pair();
      final sent = await a.service.sendDirect(b.id, 'regret');
      await run();
      await cut(a, b);
      await a.service.actions.deleteForEveryone('dm:${b.id}', [sent.id]);
      await run();

      clock.advance(const Duration(hours: 13));
      await a.node.router.maintain();
      await run();

      expect(await a.repo.deletionRequestState(sent.id), 'expired');
      expect(await b.message(sent.id), isNotNull, reason: 'it never reached Bob');
      expect(await a.message(sent.id), isNull, reason: 'still gone from this phone');
    });

    test('a message that never left the phone has nobody to be told', () async {
      final (a, b) = await pair();
      await cut(a, b);
      final sent = await a.service.sendDirect(b.id, 'draft that slipped out');
      await run();

      final r = await a.service.actions.deleteForEveryone('dm:${b.id}', [sent.id]);
      expect([r.removed, r.askedOthers, r.cancelled], [1, false, 1]);

      await connect([(a, b)]);
      expect(await b.repo.getMessages('dm:${a.id}'), isEmpty);
    });

    test("only one's own messages can be deleted for everyone", () async {
      final (a, b) = await pair();
      final sent = await a.service.sendDirect(b.id, 'mine');
      await run();

      await expectLater(b.service.actions.deleteForEveryone('dm:${a.id}', [sent.id]),
          _error(MessageErrorKind.notAllowed));
      expect(await b.message(sent.id), isNotNull);
      expect(await a.message(sent.id), isNotNull);
    });

    test('after two days it is too late, and nothing happens', () async {
      final (a, b) = await pair();
      final sent = await a.service.sendDirect(b.id, 'old news');
      await run();
      clock.advance(const Duration(hours: 49));

      await expectLater(a.service.actions.deleteForEveryone('dm:${b.id}', [sent.id]),
          _error(MessageErrorKind.tooOld));
      expect(await a.message(sent.id), isNotNull);
    });

    test('a request for a message the sender did not write is refused and logged', () async {
      final (a, b) = await pair();
      final sent = await a.service.sendDirect(b.id, 'Alice wrote this');
      await run();

      await forgeDirect(b, a, deleteOf(sent.id));

      expect(await a.message(sent.id), isNotNull, reason: "Bob cannot delete Alice's message");
      expect(await b.message(sent.id), isNotNull);
      final logged = await refusals(a);
      expect(logged, hasLength(1));
      expect(logged.single.peerId, b.id);
    });

    test('a request for something that is not in the chat is ignored quietly', () async {
      final (a, b) = await pair();
      final sent = await a.service.sendDirect(b.id, 'hello');
      await run();
      final other = await a.service.groups.create(name: 'Elsewhere', memberIds: [b.id]);
      await run();
      await b.service.groups.accept(other.id);
      await run();
      final inGroup = await b.service.sendText(Conversation.groupConversationId(other.id), 'in the group');
      await run();

      // Bob's private-chat request names a message that lives in the group.
      await forgeDirect(b, a, deleteOf(inGroup.id));
      expect(await a.message(inGroup.id), isNotNull);
      expect(await a.message(sent.id), isNotNull);
    });

    test('a photo is gone from both phones', () async {
      final (a, b) = await pair();
      final sent = await a.service.sendMedia(
        'dm:${b.id}',
        MediaDraft(kind: MediaKind.image, bytes: fakeBytes(5000), width: 320, height: 240),
      );
      await run();
      expect(a.mediaStore.files, isNotEmpty);
      expect(b.mediaStore.files, isNotEmpty);

      await a.service.actions.deleteForEveryone('dm:${b.id}', [sent.id]);
      await run();

      for (final n in [a, b]) {
        expect(n.mediaStore.files, isEmpty);
        expect(await n.mediaOf(sent.id), isNull);
        expect(await n.message(sent.id), isNull);
      }
    });

    test('several messages go in one request', () async {
      final (a, b) = await pair();
      final ids = <String>[];
      for (var i = 0; i < 5; i++) {
        ids.add((await a.service.sendDirect(b.id, 'message $i')).id);
        await run();
      }
      final r = await a.service.actions.deleteForEveryone('dm:${b.id}', ids.take(4).toList());
      await run();
      expect(r.removed, 4);
      expect((await b.repo.getMessages('dm:${a.id}')).map((m) => m.body), ['message 4']);
      expect((await a.repo.getMessages('dm:${b.id}')).map((m) => m.body), ['message 4']);
    });
  });

  group('delete for everyone: group', () {
    test('the author removes it from every member', () async {
      final (a, b, c, _, gc) = await trio();
      final sent = await b.service.sendText(gc, 'plans');
      await run();
      expect((await c.repo.getMessages(gc)).single.body, 'plans');

      final r = await b.service.actions.deleteForEveryone(gc, [sent.id]);
      await run();

      expect(r.askedOthers, isTrue);
      for (final n in [a, b, c]) {
        expect(await n.repo.getMessages(gc), isEmpty, reason: n.name);
      }
    });

    test("the admin can remove anyone's message, a member cannot", () async {
      final (a, b, c, _, gc) = await trio();
      final sent = await b.service.sendText(gc, 'something unwelcome');
      await run();

      await expectLater(
          c.service.actions.deleteForEveryone(gc, [sent.id]), _error(MessageErrorKind.notAllowed));
      expect(await c.message(sent.id), isNotNull);

      await a.service.actions.deleteForEveryone(gc, [sent.id]);
      await run();
      for (final n in [a, b, c]) {
        expect(await n.message(sent.id), isNull, reason: n.name);
      }
    });

    test('a member who forges a request for somebody else\'s message is refused by everyone',
        () async {
      final (a, b, c, g, gc) = await trio();
      final sent = await b.service.sendText(gc, 'Bob wrote this');
      await run();

      await forgeGroup(c, g, deleteOf(sent.id));

      for (final n in [a, b, c]) {
        expect(await n.message(sent.id), isNotNull, reason: n.name);
      }
      expect(await refusals(a), hasLength(1));
      expect(await refusals(b), hasLength(1));
      expect((await refusals(a)).single.peerId, c.id);
    });

    test('a member who was away ends up without it, whichever of the two reaches them first',
        () async {
      final (a, b, c, _, gc) = await trio();
      await cut(a, c);
      await cut(b, c);
      final sent = await b.service.sendText(gc, 'plans');
      await run();
      await b.service.actions.deleteForEveryone(gc, [sent.id]);
      await run();
      expect(await a.message(sent.id), isNull);

      await connect([(a, c), (b, c)]);
      expect(await c.repo.getMessages(gc), isEmpty);
      expect(await c.message(sent.id), isNull);
    });
  });

  group('delete for everyone: public room', () {
    test('the author removes it from everyone in range', () async {
      final a = await mk('Alice', 1);
      final b = await mk('Bob', 2);
      final c = await mk('Carol', 3);
      await connect([(a, b), (b, c)]);
      final sent = await a.service.rooms.sendText(_mesh, 'oops');
      await run();
      expect(await c.message(sent.id), isNotNull);

      await a.service.actions.deleteForEveryone('rm:$_mesh', [sent.id]);
      await run();

      for (final n in [a, b, c]) {
        expect(await n.repo.getMessages('rm:$_mesh'), isEmpty, reason: n.name);
      }
    });

    test('nobody else in the room can remove it', () async {
      final a = await mk('Alice', 1);
      final b = await mk('Bob', 2);
      final c = await mk('Carol', 3);
      await connect([(a, b), (b, c)]);
      final sent = await a.service.rooms.sendText(_mesh, 'Alice speaking');
      await run();

      await expectLater(b.service.actions.deleteForEveryone('rm:$_mesh', [sent.id]),
          _error(MessageErrorKind.notAllowed));
      await forgeRoom(c, deleteOf(sent.id));

      for (final n in [a, b, c]) {
        expect(await n.message(sent.id), isNotNull, reason: n.name);
      }
      expect(await refusals(a), hasLength(1));
    });
  });

  group('editing', () {
    test('the new text replaces the old one on both phones and shows as edited', () async {
      final (a, b) = await pair();
      final sent = await a.service.sendDirect(b.id, 'helo wrld');
      await run();

      final mine = await a.service.actions.edit(sent.id, 'hello world');
      await run();

      expect(mine.body, 'hello world');
      expect(mine.isEdited, isTrue);
      final theirs = (await b.message(sent.id))!;
      expect([theirs.body, theirs.isEdited, theirs.editVersion], ['hello world', true, mine.editVersion]);
      expect((await b.repo.getConversation('dm:${a.id}'))!.previewIn(englishStrings()), 'hello world');
      expect((await a.message(sent.id))!.status, MessageStatus.delivered,
          reason: 'editing does not change the delivery state of the message');
    });

    test('a later edit wins, and two quick edits arrive in order', () async {
      final (a, b) = await pair();
      final sent = await a.service.sendDirect(b.id, 'v1');
      await run();
      await a.service.actions.edit(sent.id, 'v2');
      await a.service.actions.edit(sent.id, 'v3');
      await run();
      expect((await b.message(sent.id))!.body, 'v3');
      expect((await a.message(sent.id))!.body, 'v3');
    });

    test('an edit made while the other phone is away is delivered later', () async {
      final (a, b) = await pair();
      final sent = await a.service.sendDirect(b.id, 'before');
      await run();
      await cut(a, b);
      await a.service.actions.edit(sent.id, 'after');
      await run();
      expect((await b.message(sent.id))!.body, 'before');

      await connect([(a, b)]);
      expect((await b.message(sent.id))!.body, 'after');
    });

    test('works in a group and in a public room', () async {
      final (a, b, c, _, gc) = await trio();
      final inGroup = await a.service.sendText(gc, 'grup');
      final inRoom = await a.service.rooms.sendText(_mesh, 'rom');
      await run();
      await a.service.actions.edit(inGroup.id, 'group');
      await a.service.actions.edit(inRoom.id, 'room');
      await run();
      for (final n in [b, c]) {
        expect((await n.message(inGroup.id))!.body, 'group', reason: n.name);
        expect((await n.message(inRoom.id))!.body, 'room', reason: n.name);
      }
    });

    test('editing to the same text changes and sends nothing', () async {
      final (a, b) = await pair();
      final sent = await a.service.sendDirect(b.id, 'same');
      await run();
      final before = (await a.node.outbox.all()).length;
      final again = await a.service.actions.edit(sent.id, '  same ');
      expect(again.isEdited, isFalse);
      expect((await a.node.outbox.all()).length, before);
    });

    test('only your own text messages, within two days, and never empty', () async {
      final (a, b) = await pair();
      final text = await a.service.sendDirect(b.id, 'text');
      final photo = await a.service.sendMedia(
        'dm:${b.id}',
        MediaDraft(kind: MediaKind.image, bytes: fakeBytes(3000), width: 10, height: 10),
      );
      await run();

      await expectLater(b.service.actions.edit(text.id, 'not mine'), _error(MessageErrorKind.notAllowed));
      await expectLater(a.service.actions.edit(photo.id, 'caption?'), _error(MessageErrorKind.notAllowed));
      await expectLater(a.service.actions.edit(text.id, '   '), _error(MessageErrorKind.empty));
      await expectLater(a.service.actions.edit('00' * Protocol.messageIdLength, 'x'),
          _error(MessageErrorKind.unknownMessage));
      expect((await b.message(text.id))!.body, 'text');

      clock.advance(const Duration(hours: 49));
      await expectLater(a.service.actions.edit(text.id, 'too late'), _error(MessageErrorKind.tooOld));
    });

    test('an edit written by somebody else is ignored', () async {
      final (a, b) = await pair();
      final sent = await a.service.sendDirect(b.id, 'Alice wrote this');
      await run();
      await forgeDirect(b, a, EditEnvelope(targetId: hexToBytes(sent.id), version: 1 << 50, text: 'forged'));
      expect((await a.message(sent.id))!.body, 'Alice wrote this');
      expect((await b.message(sent.id))!.body, 'Alice wrote this');
    });

    test('a member cannot rewrite what another member said', () async {
      final (a, b, c, g, gc) = await trio();
      final sent = await b.service.sendText(gc, 'Bob wrote this');
      await run();
      await forgeGroup(c, g, EditEnvelope(targetId: hexToBytes(sent.id), version: 1 << 50, text: 'forged'));
      for (final n in [a, b, c]) {
        expect((await n.message(sent.id))!.body, 'Bob wrote this', reason: n.name);
      }
    });
  });

  group('reply', () {
    test('the answer points at the question on both phones', () async {
      final (a, b) = await pair();
      final q = await a.service.sendDirect(b.id, 'Lunch?');
      await run();
      final r = await b.service.sendText('dm:${a.id}', 'Yes!', replyToId: q.id);
      await run();

      expect(r.replyToId, q.id);
      final atAlice = (await a.repo.getMessages('dm:${b.id}')).firstWhere((m) => m.body == 'Yes!');
      expect(atAlice.replyToId, q.id);
    });

    test('works in groups and rooms too', () async {
      final (a, b, c, _, gc) = await trio();
      final q = await a.service.sendText(gc, 'Who is coming?');
      final p = await a.service.rooms.sendText(_mesh, 'Anyone around?');
      await run();
      await b.service.sendText(gc, 'Me', replyToId: q.id);
      await c.service.sendText('rm:$_mesh', 'Here', replyToId: p.id);
      await run();
      expect((await a.repo.getMessages(gc)).last.replyToId, q.id);
      expect((await a.repo.getMessages('rm:$_mesh')).last.replyToId, p.id);
    });

    test('only to a message of the same conversation', () async {
      final (a, b) = await pair();
      final sent = await a.service.sendDirect(b.id, 'hi');
      await run();
      await expectLater(
          b.service.sendText('rm:$_mesh', 'wrong place', replyToId: sent.id),
          _error(MessageErrorKind.unknownMessage));
      await expectLater(
          b.service.sendText('dm:${a.id}', 'no such thing', replyToId: 'ab' * Protocol.messageIdLength),
          _error(MessageErrorKind.unknownMessage));
    });

    test('the answer stays when the question is deleted, and nothing of the question is kept',
        () async {
      final (a, b) = await pair();
      final q = await a.service.sendDirect(b.id, 'secret question');
      await run();
      final r = await b.service.sendText('dm:${a.id}', 'my answer', replyToId: q.id);
      await run();

      await a.service.actions.deleteForEveryone('dm:${b.id}', [q.id]);
      await run();

      final answer = (await b.message(r.id))!;
      expect(answer.body, 'my answer');
      expect(answer.replyToId, q.id, reason: 'only the id is kept');
      expect(await b.message(q.id), isNull, reason: 'so there is nothing to quote any more');
      final dump = StringBuffer();
      for (final row in await b.node.db.db.query('messages')) {
        dump.write(row.values.join(' '));
      }
      expect(dump.toString(), isNot(contains('secret question')));
    });
  });

  group('forward', () {
    test('goes to another conversation as a new message that says who wrote it', () async {
      final (a, b, c, _, gc) = await trio();
      final said = await b.service.sendDirect(a.id, 'a fine idea');
      await run();

      final sent = await a.service.forward([said.id], gc);
      await run();

      expect(sent.single.forwardedFrom, 'Bob');
      expect(sent.single.id, isNot(said.id));
      expect(sent.single.replyToId, isNull);
      final atCarol = (await c.repo.getMessages(gc)).single;
      expect([atCarol.body, atCarol.forwardedFrom, atCarol.senderId], ['a fine idea', 'Bob', a.id]);
    });

    test('your own message is forwarded under your name, a forward keeps its first author',
        () async {
      final (a, b, c, _, gc) = await trio();
      final mine = await a.service.sendDirect(b.id, 'from me');
      await run();
      final first = await a.service.forward([mine.id], gc);
      expect(first.single.forwardedFrom, 'Alice');
      await run();
      final second = await b.service.forward([(await b.repo.getMessages(gc)).single.id], 'dm:${c.id}');
      await run();
      expect(second.single.forwardedFrom, 'Alice', reason: 'not "Bob"');
    });

    test('a photo is sent again, byte for byte', () async {
      final (a, b, c, _, gc) = await trio();
      final bytes = fakeBytes(4000, 5);
      final photo = await b.service.sendMedia(
        'dm:${a.id}',
        MediaDraft(kind: MediaKind.image, bytes: bytes, width: 40, height: 30, caption: 'the lake'),
      );
      await run();

      final sent = await a.service.forward([photo.id], gc);
      await run();

      expect(sent.single.forwardedFrom, 'Bob');
      final got = (await c.repo.getMessages(gc)).single;
      expect([got.kind, got.body], [MessageKind.image, 'the lake']);
      final item = (await c.mediaOf(got.id))!;
      expect(await c.service.media.read(item), bytes);
    });

    test('the copy is independent: deleting the original leaves it', () async {
      final (a, b, c, _, gc) = await trio();
      final said = await b.service.sendDirect(a.id, 'worth keeping');
      await run();
      await a.service.forward([said.id], gc);
      await run();

      await b.service.actions.deleteForEveryone('dm:${a.id}', [said.id]);
      await run();

      expect(await a.message(said.id), isNull);
      expect((await c.repo.getMessages(gc)).single.body, 'worth keeping');
      expect((await a.repo.getMessages(gc)).single.body, 'worth keeping');
    });

    test('can go to a public room', () async {
      final (a, b) = await pair();
      final said = await b.service.sendDirect(a.id, 'for everybody');
      await run();
      final sent = await a.service.forward([said.id], 'rm:$_mesh');
      await run();
      expect(sent.single.forwardedFrom, 'Bob');
      expect((await b.repo.getMessages('rm:$_mesh')).single.forwardedFrom, 'Bob');
    });

    test('messages go in the order they were written', () async {
      final (a, b, c, _, gc) = await trio();
      final one = await b.service.sendDirect(a.id, 'one');
      await run();
      clock.advance(const Duration(seconds: 5));
      final two = await b.service.sendDirect(a.id, 'two');
      await run();
      await a.service.forward([two.id, one.id], gc);
      await run();
      expect((await c.repo.getMessages(gc)).map((m) => m.body), ['one', 'two']);
    });
  });

  group('pins are personal', () {
    test('pinning tells nobody and changes nothing for anybody else', () async {
      final (a, b) = await pair();
      final sent = await a.service.sendDirect(b.id, 'important');
      await run();
      expect(await a.service.setPinned('dm:${b.id}', sent.id, true), isTrue);
      await run();
      expect((await a.repo.pinnedMessages('dm:${b.id}')).single.id, sent.id);
      expect(await b.repo.pinnedMessages('dm:${a.id}'), isEmpty);
      expect(await a.service.setPinned('dm:${b.id}', sent.id, true), isFalse, reason: 'already pinned');
      expect(await a.service.setPinned('dm:${b.id}', sent.id, false), isTrue);
      expect(await a.repo.pinnedMessages('dm:${b.id}'), isEmpty);
    });

    test('a pinned message that is deleted for everyone leaves the pinned list', () async {
      final (a, b) = await pair();
      final sent = await a.service.sendDirect(b.id, 'important');
      await run();
      await b.service.setPinned('dm:${a.id}', sent.id, true);

      await a.service.actions.deleteForEveryone('dm:${b.id}', [sent.id]);
      await run();
      expect(await b.repo.pinnedMessages('dm:${a.id}'), isEmpty);
    });
  });
}
