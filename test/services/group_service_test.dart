import 'package:flutter_test/flutter_test.dart';
import 'package:offline_mesh_chat/database/message_repository.dart';
import 'package:offline_mesh_chat/models/conversation.dart';
import 'package:offline_mesh_chat/models/group.dart';
import 'package:offline_mesh_chat/models/message.dart';
import 'package:offline_mesh_chat/protocol/mesh_packet.dart';
import 'package:offline_mesh_chat/protocol/protocol_constants.dart';
import 'package:offline_mesh_chat/services/encryption_service.dart';
import 'package:offline_mesh_chat/services/message_service.dart';

import '../support/fake_clock.dart';
import '../support/memory_network.dart';
import '../support/message_node.dart';
import '../support/test_node.dart';
import 'package:offline_mesh_chat/models/delivery_problem.dart';

Matcher _error(MessageErrorKind kind) =>
    throwsA(isA<MessageError>().having((e) => e.kind, 'kind', kind));

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

  Future<void> introduce(MessageNode who) async {
    await who.node.router.announceNow();
    await run();
  }

  Future<List<ChatMessage>> messagesOf(MessageNode n, String groupId) =>
      n.repo.getMessages(Conversation.groupConversationId(groupId));

  /// Creates a group and has every member accept it.
  Future<GroupChat> makeGroup(
    MessageNode admin,
    List<MessageNode> members, {
    String name = 'Family',
  }) async {
    final g = await admin.service.groups.create(name: name, memberIds: [for (final m in members) m.id]);
    await run();
    for (final m in members) {
      await m.service.groups.accept(g.id);
    }
    return g;
  }

  group('creating a group', () {
    test('the admin invites; members see a pending invitation and nothing else', () async {
      final a = await mk('Alice', 1);
      final b = await mk('Bob', 2);
      final c = await mk('Carol', 3);
      await connect([(a, b), (a, c)]);
      final notices = <IncomingNotice>[];
      final sub = b.service.incoming.listen(notices.add);

      final g = await a.service.groups.create(name: '  Family  ', memberIds: [b.id, c.id]);
      await run();
      await sub.cancel();

      expect(g.name, 'Family');
      expect(g.adminId, a.id);
      expect(g.epoch, 0);
      expect(g.members.map((m) => m.nickname), ['Alice', 'Bob', 'Carol']);
      expect((await a.groupRepo.getGroup(g.id))!.state, GroupState.active);
      expect(await a.repo.getConversation('gr:${g.id}'), isNotNull);

      final atBob = (await b.groupRepo.getGroup(g.id))!;
      expect(atBob.state, GroupState.invited);
      expect(atBob.invitedBy, a.id);
      expect(atBob.name, 'Family');
      expect(atBob.members.map((m) => m.id).toSet(), {a.id, b.id, c.id});
      expect(await b.repo.getConversation('gr:${g.id}'), isNull,
          reason: 'nothing shows in chats until the invitation is accepted');
      expect(await b.service.groups.keyring.has(g.id), isTrue);
      expect(notices.single.isInvite, isTrue);
      expect(notices.single.title, 'Family');
      expect(await b.service.groups.isActive(atBob.idBytes), isFalse);
    });

    test('nothing about the group appears on the air in the clear', () async {
      final a = await mk('Alice', 1);
      final b = await mk('Bob', 2);
      await connect([(a, b)]);
      await a.service.groups.create(name: 'SecretClubName', memberIds: [b.id]);
      await run();
      for (final d in net.log) {
        expect(String.fromCharCodes(d.bytes), isNot(contains('SecretClubName')));
      }
    });

    test('accepting makes it active and gives it a conversation; the key was never in the clear',
        () async {
      final a = await mk('Alice', 1);
      final b = await mk('Bob', 2);
      await connect([(a, b)]);
      final g = await a.service.groups.create(name: 'Trip', memberIds: [b.id]);
      await run();

      final joined = await b.service.groups.accept(g.id);
      expect(joined.state, GroupState.active);
      expect(joined.joinedAtMs, isNotNull);
      expect((await b.repo.getConversation('gr:${g.id}'))!.title, 'Trip');
      expect(await b.service.groups.isActive(joined.idBytes), isTrue);

      final key = (await a.service.groups.keyring.latest(g.id))!;
      for (final d in net.log) {
        expect(d.bytes.toList().join(','), isNot(contains(key.key.toList().join(','))));
      }
    });

    test('declining forgets the group and the admin makes a key the decliner does not have',
        () async {
      final a = await mk('Alice', 1);
      final b = await mk('Bob', 2);
      final c = await mk('Carol', 3);
      await connect([(a, b), (a, c)]);
      final g = await a.service.groups.create(name: 'Club', memberIds: [b.id, c.id]);
      await run();
      await c.service.groups.accept(g.id);

      await b.service.groups.decline(g.id);
      await run();

      expect(await b.groupRepo.getGroup(g.id), isNull);
      expect(await b.service.groups.keyring.has(g.id), isFalse);
      final atAdmin = (await a.groupRepo.getGroup(g.id))!;
      expect(atAdmin.members.map((m) => m.id).toSet(), {a.id, c.id});
      expect(atAdmin.epoch, 1, reason: 'the key was rotated');
      expect((await c.groupRepo.getGroup(g.id))!.epoch, 1);
    });

    test('invalid requests are refused with an explanation', () async {
      final a = await mk('Alice', 1);
      final b = await mk('Bob', 2);
      final stranger = await mk('Stranger', 3);
      final noKey = await mk('NoKey', 4);
      await connect([(a, b)]);
      await a.repo.upsertPeer(signingKey: noKey.node.signingKey, seenAtMs: clock.nowMs);

      await expectLater(a.service.groups.create(name: '   ', memberIds: [b.id]),
          _error(MessageErrorKind.invalidName));
      await expectLater(
          a.service.groups.create(name: 'x', memberIds: []), _error(MessageErrorKind.noMembers));
      await expectLater(a.service.groups.create(name: 'x', memberIds: [a.id]),
          _error(MessageErrorKind.noMembers),
          reason: 'you cannot invite yourself');
      await expectLater(a.service.groups.create(name: 'x', memberIds: [stranger.id]),
          _error(MessageErrorKind.unknownPeer));
      await expectLater(a.service.groups.create(name: 'x', memberIds: [noKey.id]),
          _error(MessageErrorKind.noEncryptionKey));
      await a.repo.setBlocked(b.id, true);
      await expectLater(
          a.service.groups.create(name: 'x', memberIds: [b.id]), _error(MessageErrorKind.blocked));
      expect(await a.groupRepo.listGroups(), isEmpty, reason: 'a refused group leaves nothing behind');
    });

    test('a group is limited to ${Protocol.maxGroupMembers} people including the admin', () async {
      final a = await mk('Alice', 1);
      final others = <MessageNode>[];
      for (var i = 0; i < Protocol.maxGroupMembers; i++) {
        others.add(await mk('P$i', 10 + i));
      }
      await connect([for (final o in others) (a, o)]);
      await expectLater(
        a.service.groups.create(name: 'Crowd', memberIds: [for (final o in others) o.id]),
        _error(MessageErrorKind.tooManyMembers),
      );
      final ok = await a.service.groups
          .create(name: 'Crowd', memberIds: [for (final o in others.take(Protocol.maxGroupMembers - 1)) o.id]);
      expect(ok.members.length, Protocol.maxGroupMembers);
    });
  });

  group('group messages', () {
    test('members read each other with the sender named; a non-member relay cannot', () async {
      final a = await mk('Alice', 1);
      final r = await mk('Relay', 2);
      final b = await mk('Bob', 3);
      await connect([(a, r), (r, b)]);
      await introduce(b);
      final g = await makeGroup(a, [b]);

      await a.service.groups.sendText(g.id, 'hello group');
      await run();
      await b.service.groups.sendText(g.id, 'hi Alice');
      await run();

      final atBob = await messagesOf(b, g.id);
      expect(atBob.map((m) => m.body), ['hello group', 'hi Alice']);
      expect(atBob.first.senderNickname, 'Alice');
      expect(atBob.first.senderId, a.id);
      expect(atBob.first.isOutgoing, isFalse);
      expect(atBob.last.isOutgoing, isTrue);
      expect((await messagesOf(a, g.id)).map((m) => m.body), ['hello group', 'hi Alice']);
      expect((await b.repo.getConversation('gr:${g.id}'))!.unreadCount, 1);

      // The relay carried the sealed packets but never joined or read anything.
      expect(await r.repo.getConversation('gr:${g.id}'), isNull);
      expect(await r.groupRepo.getGroup(g.id), isNull);
      for (final e in await r.node.outbox.all()) {
        expect(String.fromCharCodes(e.packet), isNot(contains('hello group')));
      }
    });

    test('"delivered" means every other member confirmed; until then it shows how many did',
        () async {
      final a = await mk('Alice', 1);
      final b = await mk('Bob', 2);
      final c = await mk('Carol', 3);
      await connect([(a, b)]); // Carol is away
      await introduce(c);
      await connect([(a, c)]);
      final g = await makeGroup(a, [b, c]);
      await net.disconnect(a.id, c.id);
      await run();

      final sent = await a.service.groups.sendText(g.id, 'is everyone here?');
      await run();
      var m = (await a.message(sent.id))!;
      expect(m.status, MessageStatus.sent);
      expect(m.recipientCount, 2);
      expect(m.receiptCount, 1, reason: 'only Bob has confirmed');

      clock.advance(const Duration(minutes: 30));
      await connect([(a, c)]);
      m = (await a.message(sent.id))!;
      expect(m.receiptCount, 2);
      expect(m.status, MessageStatus.delivered);
      expect((await messagesOf(c, g.id)).single.body, 'is everyone here?');
    });

    test('a member who was away catches up from a phone that carried the messages', () async {
      final a = await mk('Alice', 1);
      final b = await mk('Bob', 2);
      final c = await mk('Carol', 3);
      await connect([(a, b), (a, c)]);
      final g = await makeGroup(a, [b, c]);
      await net.disconnect(a.id, c.id);
      await run();

      await a.service.groups.sendText(g.id, 'first');
      await b.service.groups.sendText(g.id, 'second');
      await run();
      expect(await messagesOf(c, g.id), isEmpty);

      // Carol never meets Alice again - only Bob, who carried both messages.
      clock.advance(const Duration(hours: 2));
      await connect([(b, c)]);
      expect((await messagesOf(c, g.id)).map((m) => m.body).toSet(), {'first', 'second'});
    });

    test('a message from someone who is not in the member list is rejected', () async {
      final a = await mk('Alice', 1);
      final b = await mk('Bob', 2);
      final c = await mk('Carol', 3);
      await connect([(a, b), (a, c), (b, c)]);
      final g = await makeGroup(a, [b, c]);

      // Alice removes Carol; Carol still holds the old key (epoch 0)...
      final oldKey = (await c.service.groups.keyring.get(g.id, 0))!;
      await a.service.groups.removeMember(g.id, c.id);
      await run();
      // ...and uses it to post. The signature and the seal are both valid.
      final forged = await c.node.crypto.buildGroupMessage(
        group: oldKey,
        envelope: const TextEnvelope('I am still here', nickname: 'Carol'),
      );
      await c.node.router.submit(forged);
      await run();

      expect(await messagesOf(b, g.id), isEmpty);
      expect((await b.repo.securityEvents()).map((e) => e.kind),
          contains(SecurityEventKind.notAMember));
    });

    test('empty and oversized group messages are refused', () async {
      final a = await mk('Alice', 1);
      final b = await mk('Bob', 2);
      await connect([(a, b)]);
      final g = await makeGroup(a, [b]);
      await expectLater(a.service.groups.sendText(g.id, '  '), _error(MessageErrorKind.empty));
      await expectLater(a.service.groups.sendText(g.id, 'x' * (Protocol.maxTextBytes + 1)),
          _error(MessageErrorKind.tooLong));
    });

    test('a message nobody can receive fails honestly after it expires', () async {
      final a = await mk('Alice', 1);
      final b = await mk('Bob', 2);
      await connect([(a, b)]);
      final g = await makeGroup(a, [b]);
      await net.disconnect(a.id, b.id);
      await run();
      final sent = await a.service.groups.sendText(g.id, 'into the void');
      await run();
      expect((await a.message(sent.id))!.status, MessageStatus.queued);
      clock.advance(const Duration(hours: 13));
      await a.node.router.maintain();
      await run();
      final failed = (await a.message(sent.id))!;
      expect(failed.status, MessageStatus.failed);
      expect(failed.error, DeliveryProblem.nobodyInRange.code);
    });

    test('a failed group message can be sent again', () async {
      final a = await mk('Alice', 1);
      final b = await mk('Bob', 2);
      await connect([(a, b)]);
      final g = await makeGroup(a, [b]);
      await net.disconnect(a.id, b.id);
      await run();
      final sent = await a.service.sendText('gr:${g.id}', 'try again');
      clock.advance(const Duration(hours: 13));
      await a.node.router.maintain();
      await run();
      await connect([(a, b)]);
      final fresh = await a.service.retry(sent.id);
      await run();
      expect(await a.message(sent.id), isNull);
      expect((await messagesOf(b, g.id)).single.body, 'try again');
      expect((await a.message(fresh.id))!.status, MessageStatus.delivered);
    });

    test('messages from a blocked member are hidden', () async {
      final a = await mk('Alice', 1);
      final b = await mk('Bob', 2);
      await connect([(a, b)]);
      final g = await makeGroup(a, [b]);
      await b.repo.setBlocked(a.id, true);
      await a.service.groups.sendText(g.id, 'can you hear me');
      await run();
      expect(await messagesOf(b, g.id), isEmpty);
    });
  });

  group('changing a group', () {
    test('removing a member rotates the key: they can read nothing sent afterwards', () async {
      final a = await mk('Alice', 1);
      final b = await mk('Bob', 2);
      final c = await mk('Carol', 3);
      await connect([(a, b), (a, c)]);
      final g = await makeGroup(a, [b, c]);
      final oldKey = (await c.service.groups.keyring.get(g.id, 0))!;
      await a.service.groups.sendText(g.id, 'before');
      await run();

      final updated = await a.service.groups.removeMember(g.id, c.id);
      await run();
      await a.service.groups.sendText(g.id, 'after');
      await run();

      expect(updated.epoch, 1);
      expect(updated.members.map((m) => m.id).toSet(), {a.id, b.id});
      expect((await messagesOf(b, g.id)).map((m) => m.body), ['before', 'after']);
      expect((await b.groupRepo.getGroup(g.id))!.epoch, 1);

      final atCarol = (await c.groupRepo.getGroup(g.id))!;
      expect(atCarol.state, GroupState.removed);
      expect((await messagesOf(c, g.id)).map((m) => m.body), ['before'],
          reason: 'history stays, nothing new arrives');
      expect(await c.service.groups.keyring.has(g.id), isFalse);

      // Even a Carol who kept the old key could not read the new traffic: it is
      // sealed under epoch 1.
      final afterPacket = (await a.node.outbox.all())
          .map((e) => MeshPacket.decode(e.packet))
          .firstWhere((p) => p.type == PacketType.group && !p.isChunk &&
              EncryptionService.groupPacketEpoch(p) == 1);
      await expectLater(EncryptionService.openGroupMessage(afterPacket, oldKey),
          throwsA(isA<DecryptionFailure>()));
    });

    test('a member who leaves is removed and the key rotates', () async {
      final a = await mk('Alice', 1);
      final b = await mk('Bob', 2);
      final c = await mk('Carol', 3);
      await connect([(a, b), (a, c)]);
      final g = await makeGroup(a, [b, c]);

      await b.service.groups.leave(g.id);
      await run();

      expect((await b.groupRepo.getGroup(g.id))!.state, GroupState.left);
      expect(await b.service.groups.keyring.has(g.id), isFalse);
      final atAdmin = (await a.groupRepo.getGroup(g.id))!;
      expect(atAdmin.members.map((m) => m.id).toSet(), {a.id, c.id});
      expect(atAdmin.epoch, 1);
      expect((await c.groupRepo.getGroup(g.id))!.epoch, 1);

      await a.service.groups.sendText(g.id, 'just us now');
      await run();
      expect((await messagesOf(c, g.id)).map((m) => m.body), ['just us now']);
      expect(await messagesOf(b, g.id), isEmpty);
      await expectLater(
          b.service.groups.sendText(g.id, 'am I still in?'), _error(MessageErrorKind.groupNotActive));
    });

    test('the admin cannot leave, only delete; deleting tells the members', () async {
      final a = await mk('Alice', 1);
      final b = await mk('Bob', 2);
      await connect([(a, b)]);
      final g = await makeGroup(a, [b]);
      await expectLater(a.service.groups.leave(g.id), _error(MessageErrorKind.notAdmin));

      await a.service.groups.deleteAsAdmin(g.id);
      await run();
      expect(await a.groupRepo.getGroup(g.id), isNull);
      expect(await a.repo.getConversation('gr:${g.id}'), isNull);
      expect((await b.groupRepo.getGroup(g.id))!.state, GroupState.removed);
    });

    test('adding a member invites them with a fresh key; they cannot read earlier messages',
        () async {
      final a = await mk('Alice', 1);
      final b = await mk('Bob', 2);
      final d = await mk('Dave', 4);
      await connect([(a, b), (a, d)]);
      final g = await makeGroup(a, [b]);
      await a.service.groups.sendText(g.id, 'before Dave');
      await run();

      final updated = await a.service.groups.addMembers(g.id, [d.id]);
      await run();
      await d.service.groups.accept(g.id);
      await a.service.groups.sendText(g.id, 'welcome Dave');
      await run();

      expect(updated.epoch, 1);
      expect(updated.members.length, 3);
      expect((await messagesOf(d, g.id)).map((m) => m.body), ['welcome Dave']);
      expect((await messagesOf(b, g.id)).map((m) => m.body), ['before Dave', 'welcome Dave']);
      expect((await b.groupRepo.getGroup(g.id))!.members.length, 3);
    });

    test('only the admin may add or remove people', () async {
      final a = await mk('Alice', 1);
      final b = await mk('Bob', 2);
      final c = await mk('Carol', 3);
      await connect([(a, b), (a, c), (b, c)]);
      final g = await makeGroup(a, [b, c]);
      await expectLater(b.service.groups.addMembers(g.id, [c.id]), _error(MessageErrorKind.notAdmin));
      await expectLater(b.service.groups.removeMember(g.id, c.id), _error(MessageErrorKind.notAdmin));
      await expectLater(a.service.groups.removeMember(g.id, a.id), _error(MessageErrorKind.notAdmin));
      await expectLater(a.service.groups.removeMember(g.id, 'ab' * 32), _error(MessageErrorKind.noMembers));
      await expectLater(a.service.groups.addMembers(g.id, [b.id]), _error(MessageErrorKind.noMembers));
    });

    test('an update from a member who is not the admin is rejected', () async {
      final a = await mk('Alice', 1);
      final b = await mk('Bob', 2);
      final c = await mk('Carol', 3);
      await connect([(a, b), (a, c), (b, c)]);
      final g = await makeGroup(a, [b, c]);

      // Bob tries to take over: an "update" that names himself admin.
      final key = (await b.service.groups.keyring.latest(g.id))!;
      final fake = GroupSnapshot(
        isUpdate: true,
        groupId: key.groupId,
        epoch: 5,
        groupKey: b.node.crypto.randomBytes(32),
        name: 'Bob\'s group now',
        adminKey: b.node.signingKey,
        members: [
          GroupMemberInfo(key: b.node.signingKey, nickname: 'Bob'),
          GroupMemberInfo(key: c.node.signingKey, nickname: 'Carol'),
        ],
      );
      final packet = await b.node.crypto.buildDirectEnvelope(
        recipientSigningKey: c.node.signingKey,
        recipientAgreementKey: c.node.agreementKey,
        envelope: fake,
      );
      await b.node.router.submit(packet);
      await run();

      final atCarol = (await c.groupRepo.getGroup(g.id))!;
      expect(atCarol.adminId, a.id);
      expect(atCarol.epoch, 0);
      expect(atCarol.name, 'Family');
      expect((await c.repo.securityEvents()).map((e) => e.kind),
          contains(SecurityEventKind.notAMember));
    });

    test('an invitation from a stranger who is not its admin is rejected', () async {
      final a = await mk('Alice', 1);
      final mallory = await mk('Mallory', 9);
      await connect([(a, mallory)]);
      final forged = GroupSnapshot(
        isUpdate: false,
        groupId: mallory.node.crypto.randomBytes(32),
        epoch: 0,
        groupKey: mallory.node.crypto.randomBytes(32),
        name: 'Win a prize',
        adminKey: a.node.signingKey, // claims Alice is the admin
        members: [
          GroupMemberInfo(key: a.node.signingKey, nickname: 'Alice'),
          GroupMemberInfo(key: mallory.node.signingKey, nickname: 'Mallory'),
        ],
      );
      await mallory.node.router.submit(await mallory.node.crypto.buildDirectEnvelope(
        recipientSigningKey: a.node.signingKey,
        recipientAgreementKey: a.node.agreementKey,
        envelope: forged,
      ));
      await run();
      expect(await a.groupRepo.listGroups(), isEmpty);
      expect((await a.repo.securityEvents()).map((e) => e.kind),
          contains(SecurityEventKind.notAMember));
    });

    test('an update that leaves us out is not accepted', () async {
      final a = await mk('Alice', 1);
      final b = await mk('Bob', 2);
      await connect([(a, b)]);
      final g = await makeGroup(a, [b]);
      final key = (await a.service.groups.keyring.latest(g.id))!;
      final update = GroupSnapshot(
        isUpdate: true,
        groupId: key.groupId,
        epoch: 3,
        groupKey: a.node.crypto.randomBytes(32),
        name: 'x',
        adminKey: a.node.signingKey,
        members: [GroupMemberInfo(key: a.node.signingKey, nickname: 'Alice')],
      );
      await a.node.router.submit(await a.node.crypto.buildDirectEnvelope(
        recipientSigningKey: b.node.signingKey,
        recipientAgreementKey: b.node.agreementKey,
        envelope: update,
      ));
      await run();
      expect((await b.groupRepo.getGroup(g.id))!.epoch, 0);
    });

    test('a stale update (older key epoch) changes nothing', () async {
      final a = await mk('Alice', 1);
      final b = await mk('Bob', 2);
      final c = await mk('Carol', 3);
      await connect([(a, b), (a, c)]);
      final g = await makeGroup(a, [b, c]);
      await a.service.groups.removeMember(g.id, c.id); // epoch 1
      await run();
      final key0 = (await a.service.groups.keyring.get(g.id, 0))!;
      final stale = GroupSnapshot(
        isUpdate: true,
        groupId: key0.groupId,
        epoch: 0,
        groupKey: key0.key,
        name: 'Family',
        adminKey: a.node.signingKey,
        members: [
          GroupMemberInfo(key: a.node.signingKey, nickname: 'Alice'),
          GroupMemberInfo(key: b.node.signingKey, nickname: 'Bob'),
          GroupMemberInfo(key: c.node.signingKey, nickname: 'Carol'),
        ],
      );
      await a.node.router.submit(await a.node.crypto.buildDirectEnvelope(
        recipientSigningKey: b.node.signingKey,
        recipientAgreementKey: b.node.agreementKey,
        envelope: stale,
      ));
      await run();
      final atBob = (await b.groupRepo.getGroup(g.id))!;
      expect(atBob.epoch, 1);
      expect(atBob.members.length, 2, reason: 'Carol must not come back');
    });

    test('names from the network are cleaned before they are stored', () async {
      final a = await mk('Alice', 1);
      final b = await mk('Bob', 2);
      await connect([(a, b)]);
      final g = await a.service.groups.create(name: 'Fam\u202Eily\u0007', memberIds: [b.id]);
      await run();
      expect(g.name, 'Family');
      expect((await b.groupRepo.getGroup(g.id))!.name, 'Family');
    });
  });

  test('the admin sees the group in the list newest first, with pending ones separable', () async {
    final a = await mk('Alice', 1);
    final b = await mk('Bob', 2);
    await connect([(a, b)]);
    final g1 = await a.service.groups.create(name: 'One', memberIds: [b.id]);
    await run();
    clock.advance(const Duration(minutes: 1));
    await b.service.groups.accept(g1.id);
    final g2 = await a.service.groups.create(name: 'Two', memberIds: [b.id]);
    await run();
    final pending = await b.service.groups.list(states: [GroupState.invited]);
    expect(pending.map((g) => g.id), [g2.id]);
    expect((await b.service.groups.list()).length, 2);
  });
}
