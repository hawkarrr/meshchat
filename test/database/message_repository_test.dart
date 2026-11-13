import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:offline_mesh_chat/database/database_helper.dart';
import 'package:offline_mesh_chat/database/message_repository.dart';
import 'package:offline_mesh_chat/models/conversation.dart';
import 'package:offline_mesh_chat/models/message.dart';
import 'package:offline_mesh_chat/models/peer.dart';

import '../support/test_database.dart';
import 'package:offline_mesh_chat/l10n/l10n.dart';

Uint8List _key(int v) => Uint8List(32)..fillRange(0, 32, v);

void main() {
  late DatabaseHelper helper;
  late MessageRepository repo;

  setUp(() async {
    helper = await openMemoryDatabase();
    repo = MessageRepository(helper.db);
  });

  tearDown(() async {
    await repo.dispose();
    await helper.close();
  });

  Future<Peer> addPeer(int v, {String nickname = 'Bob', int seen = 1000}) async =>
      (await repo.upsertPeer(
        signingKey: _key(v),
        agreementKey: _key(v + 100),
        nickname: nickname,
        seenAtMs: seen,
      ))
          .peer;

  ChatMessage msg(
    String id,
    String conv, {
    bool outgoing = false,
    String body = 'hi',
    int at = 1000,
    MessageStatus? status,
  }) =>
      ChatMessage(
        id: id,
        conversationId: conv,
        senderId: outgoing ? 'me' : 'them',
        isOutgoing: outgoing,
        body: body,
        sortTimeMs: at,
        claimedTimestampMs: at,
        status: status ?? (outgoing ? MessageStatus.queued : MessageStatus.received),
      );

  group('peers', () {
    test('first sighting inserts a non-contact, unverified peer', () async {
      final u = await repo.upsertPeer(
          signingKey: _key(1), agreementKey: _key(2), nickname: 'Bob', seenAtMs: 5);
      expect(u.isNew, isTrue);
      expect(u.keyChanged, isFalse);
      expect(u.peer.verified, isFalse);
      expect(u.peer.isContact, isFalse);
      expect(u.peer.nickname, 'Bob');
      expect(u.peer.agreementKey, _key(2));
    });

    test('repeat sightings update last-seen monotonically and keep first-seen', () async {
      await repo.upsertPeer(signingKey: _key(1), seenAtMs: 100);
      await repo.upsertPeer(signingKey: _key(1), seenAtMs: 500);
      final late = await repo.upsertPeer(signingKey: _key(1), seenAtMs: 300); // older sighting
      expect(late.isNew, isFalse);
      expect(late.peer.firstSeenMs, 100);
      expect(late.peer.lastSeenMs, 500);
    });

    test('a sighting without an agreement key does not erase a known one', () async {
      await repo.upsertPeer(signingKey: _key(1), agreementKey: _key(2), seenAtMs: 1);
      final u = await repo.upsertPeer(signingKey: _key(1), seenAtMs: 2);
      expect(u.peer.agreementKey, _key(2));
    });

    test('a changed agreement key revokes verification and is reported', () async {
      final p = await addPeer(1);
      await repo.setVerified(p.id, true);
      expect((await repo.getPeer(p.id))!.verified, isTrue);

      final same = await repo.upsertPeer(
          signingKey: _key(1), agreementKey: _key(101), seenAtMs: 2000);
      expect(same.keyChanged, isFalse);
      expect(same.peer.verified, isTrue);

      final changed = await repo.upsertPeer(
          signingKey: _key(1), agreementKey: _key(200), seenAtMs: 3000);
      expect(changed.keyChanged, isTrue);
      expect(changed.peer.verified, isFalse);
      expect(changed.peer.agreementKey, _key(200));
    });

    test('announcing never verifies a peer automatically', () async {
      for (var i = 0; i < 3; i++) {
        final u = await repo.upsertPeer(
            signingKey: _key(1), agreementKey: _key(2), nickname: 'Bob', seenAtMs: i);
        expect(u.peer.verified, isFalse);
      }
    });

    test('alias overrides the announced nickname; clearing restores it', () async {
      final p = await addPeer(1, nickname: 'Bob');
      expect(p.displayName, 'Bob');
      await repo.setAlias(p.id, 'Brother');
      expect((await repo.getPeer(p.id))!.displayName, 'Brother');
      await repo.setAlias(p.id, '  ');
      expect((await repo.getPeer(p.id))!.displayName, 'Bob');
    });

    test('a peer with no nickname gets a short-id display name', () async {
      final u = await repo.upsertPeer(signingKey: _key(0xab), seenAtMs: 1);
      expect(u.peer.displayName, 'Peer abababab');
    });

    test('contact, verified and blocked flags', () async {
      final p = await addPeer(1);
      await repo.setContact(p.id, true);
      await repo.setVerified(p.id, true);
      await repo.setBlocked(p.id, true);
      final r = (await repo.getPeer(p.id))!;
      expect([r.isContact, r.verified, r.blocked], [true, true, true]);
    });

    test('listPeers puts contacts first', () async {
      final a = await addPeer(1, nickname: 'A', seen: 10);
      await addPeer(2, nickname: 'B', seen: 20);
      await repo.setContact(a.id, true);
      expect((await repo.listPeers()).map((p) => p.nickname), ['A', 'B']);
      expect((await repo.listPeers(contactsOnly: true)).map((p) => p.nickname), ['A']);
    });

    test('nickname changes and aliases propagate to the conversation title', () async {
      final p = await addPeer(1, nickname: 'Bob');
      final conv = await repo.ensureDirectConversation(p, nowMs: 1);
      expect(conv.title, 'Bob');
      await repo.upsertPeer(signingKey: _key(1), nickname: 'Robert', seenAtMs: 5);
      expect((await repo.getConversation(conv.id))!.title, 'Robert');
      await repo.setAlias(p.id, 'Bro');
      expect((await repo.getConversation(conv.id))!.title, 'Bro');
    });

    test('deleting a peer removes its conversation and messages', () async {
      final p = await addPeer(1);
      final conv = await repo.ensureDirectConversation(p, nowMs: 1);
      await repo.insertMessage(msg('m1', conv.id));
      await repo.deletePeer(p.id);
      expect(await repo.getPeer(p.id), isNull);
      expect(await repo.getConversation(conv.id), isNull);
      expect(await repo.getMessage('m1'), isNull);
    });
  });

  group('messages', () {
    late Conversation conv;

    setUp(() async {
      conv = await repo.ensureDirectConversation(await addPeer(1), nowMs: 1);
    });

    test('a duplicate message id does not create a second chat entry', () async {
      expect(await repo.insertMessage(msg('same', conv.id, body: 'first')), isTrue);
      expect(await repo.insertMessage(msg('same', conv.id, body: 'second')), isFalse);
      expect(await repo.insertMessage(msg('same', conv.id, body: 'third')), isFalse);

      final all = await repo.getMessages(conv.id);
      expect(all.length, 1);
      expect(all.single.body, 'first');
      // Duplicates must not inflate the unread counter either.
      expect((await repo.getConversation(conv.id))!.unreadCount, 1);
    });

    test('messages come back oldest first, limited to the latest N', () async {
      for (var i = 0; i < 10; i++) {
        await repo.insertMessage(msg('m$i', conv.id, at: 1000 + i, body: 'b$i'));
      }
      final last3 = await repo.getMessages(conv.id, limit: 3);
      expect(last3.map((m) => m.body), ['b7', 'b8', 'b9']);
    });

    test('ordering uses local sort time, not the sender-claimed timestamp', () async {
      await repo.insertMessage(ChatMessage(
        id: 'liar',
        conversationId: conv.id,
        senderId: 'them',
        isOutgoing: false,
        body: 'from the future',
        sortTimeMs: 2000,
        claimedTimestampMs: 99999999999,
        status: MessageStatus.received,
      ));
      await repo.insertMessage(msg('normal', conv.id, at: 3000, body: 'later'));
      expect((await repo.getMessages(conv.id)).map((m) => m.body), ['from the future', 'later']);
    });

    test('only incoming messages raise the unread counter; marking read resets it', () async {
      await repo.insertMessage(msg('a', conv.id));
      await repo.insertMessage(msg('b', conv.id));
      await repo.insertMessage(msg('c', conv.id, outgoing: true));
      expect((await repo.getConversation(conv.id))!.unreadCount, 2);
      expect(await repo.totalUnread(), 2);
      await repo.markConversationRead(conv.id);
      expect((await repo.getConversation(conv.id))!.unreadCount, 0);
      expect(await repo.totalUnread(), 0);
    });

    test('the conversation preview is single-line and truncated', () async {
      await repo.insertMessage(msg('a', conv.id, body: 'line one\n\n  line   two'));
      expect((await repo.getConversation(conv.id))!.previewIn(englishStrings()), 'line one line two');
      await repo.insertMessage(msg('b', conv.id, body: 'x' * 200, at: 2000));
      final preview = (await repo.getConversation(conv.id))!.previewIn(englishStrings())!;
      expect(preview.length, 80);
      expect(preview.endsWith('…'), isTrue);
    });

    test('undecryptable messages never expose their (empty) body in the preview', () async {
      await repo.insertMessage(
          msg('bad', conv.id, body: '', status: MessageStatus.undecryptable));
      expect((await repo.getConversation(conv.id))!.previewIn(englishStrings()),
          'Message could not be decrypted');
    });

    test('conversations are ordered by latest activity', () async {
      final other = await repo.ensureDirectConversation(await addPeer(2, nickname: 'Carol'), nowMs: 2);
      await repo.insertMessage(msg('a', conv.id, at: 5000));
      await repo.insertMessage(msg('b', other.id, at: 9000));
      expect((await repo.listConversations()).map((c) => c.id), [other.id, conv.id]);
      await repo.insertMessage(msg('c', conv.id, at: 12000));
      expect((await repo.listConversations()).first.id, conv.id);
    });

    test('deleting a conversation cascades to its messages', () async {
      await repo.insertMessage(msg('a', conv.id));
      await repo.deleteConversation(conv.id);
      expect(await repo.getMessage('a'), isNull);
    });

    test('old messages can be pruned for retention', () async {
      await repo.insertMessage(msg('old', conv.id, at: 100));
      await repo.insertMessage(msg('new', conv.id, at: 900));
      expect(await repo.pruneMessagesBefore(500), 1);
      expect((await repo.getMessages(conv.id)).map((m) => m.id), ['new']);
    });
  });

  group('outgoing status transitions', () {
    late Conversation conv;

    setUp(() async {
      conv = await repo.ensureDirectConversation(await addPeer(1), nowMs: 1);
      await repo.insertMessage(msg('out', conv.id, outgoing: true));
    });

    Future<MessageStatus> status() async => (await repo.getMessage('out'))!.status;

    test('queued -> sent -> delivered with the receipt hop count', () async {
      expect(await repo.updateOutgoingStatus('out', MessageStatus.sent), isTrue);
      expect(await status(), MessageStatus.sent);
      expect(await repo.updateOutgoingStatus('out', MessageStatus.delivered, hops: 2), isTrue);
      final m = (await repo.getMessage('out'))!;
      expect(m.status, MessageStatus.delivered);
      expect(m.hops, 2);
    });

    test('a late "sent" can never overwrite "delivered"', () async {
      await repo.updateOutgoingStatus('out', MessageStatus.delivered);
      expect(await repo.updateOutgoingStatus('out', MessageStatus.sent), isFalse);
      expect(await repo.updateOutgoingStatus('out', MessageStatus.failed), isFalse);
      expect(await status(), MessageStatus.delivered);
    });

    test('failed messages can be retried or still be delivered by a late receipt', () async {
      await repo.updateOutgoingStatus('out', MessageStatus.failed, error: 'expired');
      expect((await repo.getMessage('out'))!.error, 'expired');
      expect(await repo.updateOutgoingStatus('out', MessageStatus.queued), isTrue);
      await repo.updateOutgoingStatus('out', MessageStatus.failed);
      expect(await repo.updateOutgoingStatus('out', MessageStatus.delivered), isTrue);
    });

    test('incoming messages are never touched by outgoing transitions', () async {
      await repo.insertMessage(msg('in', conv.id));
      expect(await repo.updateOutgoingStatus('in', MessageStatus.delivered), isFalse);
      expect((await repo.getMessage('in'))!.status, MessageStatus.received);
    });

    test('unfinishedOutgoing lists only queued and sent messages', () async {
      await repo.insertMessage(msg('s', conv.id, outgoing: true, at: 2000));
      await repo.updateOutgoingStatus('s', MessageStatus.sent);
      await repo.insertMessage(msg('d', conv.id, outgoing: true, at: 3000));
      await repo.updateOutgoingStatus('d', MessageStatus.delivered);
      expect((await repo.unfinishedOutgoing()).map((m) => m.id), ['out', 's']);
    });
  });

  group('group and room conversations', () {
    test('are created once, typed, and titled', () async {
      final g = await repo.ensureGroupConversation('abc', 'Family', nowMs: 3);
      expect(g.id, 'gr:abc');
      expect(g.type, ConversationType.group);
      expect(g.groupId, 'abc');
      expect(g.isGroup, isTrue);
      expect(g.showsSenderNames, isTrue);
      final again = await repo.ensureGroupConversation('abc', 'Ignored', nowMs: 9);
      expect(again.title, 'Family');
      expect(again.createdAtMs, 3);

      final r = await repo.ensureRoomConversation('def', '#mesh', nowMs: 4);
      expect(r.id, 'rm:def');
      expect(r.type, ConversationType.room);
      expect(r.roomId, 'def');
      expect(r.isRoom, isTrue);
      expect(r.showsSenderNames, isTrue);
      expect((await repo.listConversations()).length, 2);
    });

    test('a direct chat does not show sender names', () async {
      final conv = await repo.ensureDirectConversation(await addPeer(1), nowMs: 1);
      expect(conv.isDirect, isTrue);
      expect(conv.showsSenderNames, isFalse);
    });

    test('can be renamed and deleted with their messages', () async {
      final g = await repo.ensureGroupConversation('abc', 'Family', nowMs: 3);
      await repo.renameConversation(g.id, 'Family 2');
      expect((await repo.getConversation(g.id))!.title, 'Family 2');
      await repo.insertMessage(msg('m', g.id));
      await repo.deleteConversation(g.id);
      expect(await repo.getMessage('m'), isNull);
    });

    test('previews name the author in groups and rooms, and say "You" for our own', () async {
      final g = await repo.ensureGroupConversation('abc', 'Family', nowMs: 3);
      await repo.insertMessage(ChatMessage(
        id: 'in',
        conversationId: g.id,
        senderId: 'sara',
        senderNickname: 'Sara',
        isOutgoing: false,
        body: 'dinner at 8',
        sortTimeMs: 10,
        claimedTimestampMs: 10,
        status: MessageStatus.received,
      ));
      expect((await repo.getConversation(g.id))!.previewIn(englishStrings()), 'Sara: dinner at 8');
      await repo.insertMessage(msg('out', g.id, outgoing: true, body: 'ok', at: 20));
      expect((await repo.getConversation(g.id))!.previewIn(englishStrings()), 'You: ok');
    });
  });

  group('message kinds', () {
    late Conversation conv;

    setUp(() async {
      conv = await repo.ensureDirectConversation(await addPeer(1), nowMs: 1);
    });

    ChatMessage media(String id, MessageKind kind, {String body = '', int at = 1000}) =>
        ChatMessage(
          id: id,
          conversationId: conv.id,
          senderId: 'them',
          isOutgoing: false,
          kind: kind,
          body: body,
          mediaId: 'media-$id',
          sortTimeMs: at,
          claimedTimestampMs: at,
          status: MessageStatus.received,
        );

    test('image and voice messages round-trip with their media id', () async {
      await repo.insertMessage(media('i', MessageKind.image, body: 'sunset'));
      await repo.insertMessage(media('v', MessageKind.voice, at: 2000));
      final i = (await repo.getMessage('i'))!;
      expect(i.kind, MessageKind.image);
      expect(i.isMedia, isTrue);
      expect(i.mediaId, 'media-i');
      expect(i.body, 'sunset');
      expect((await repo.getMessage('v'))!.kind, MessageKind.voice);
    });

    test('previews describe media instead of showing empty text', () async {
      await repo.insertMessage(media('i', MessageKind.image));
      expect((await repo.getConversation(conv.id))!.previewIn(englishStrings()), '📷 Photo');
      await repo.insertMessage(media('j', MessageKind.image, body: 'sunset', at: 2000));
      expect((await repo.getConversation(conv.id))!.previewIn(englishStrings()), '📷 sunset');
      await repo.insertMessage(media('v', MessageKind.voice, at: 3000));
      expect((await repo.getConversation(conv.id))!.previewIn(englishStrings()), '🎤 Voice message');
    });

    test('unknown kinds fall back to text rather than crashing', () {
      expect(MessageKind.parse('hologram'), MessageKind.text);
      expect(MessageKind.parse('image'), MessageKind.image);
    });
  });

  group('group delivery receipts', () {
    late Conversation conv;

    setUp(() async {
      conv = await repo.ensureGroupConversation('g', 'G', nowMs: 1);
      await repo.insertMessage(ChatMessage(
        id: 'out',
        conversationId: conv.id,
        senderId: 'me',
        isOutgoing: true,
        body: 'hi all',
        sortTimeMs: 10,
        claimedTimestampMs: 10,
        status: MessageStatus.sent,
        recipientCount: 3,
      ));
    });

    test('each member counts once', () async {
      expect(await repo.addReceipt('out', 'sara', 100), isTrue);
      expect(await repo.addReceipt('out', 'sara', 200), isFalse);
      expect(await repo.addReceipt('out', 'tom', 300), isTrue);
      expect(await repo.receiptCount('out'), 2);
      expect(await repo.receiptMembers('out'), {'sara', 'tom'});
      final m = (await repo.getMessage('out'))!;
      expect(m.receiptCount, 2);
      expect(m.recipientCount, 3);
      expect((await repo.getMessages(conv.id)).single.receiptCount, 2);
    });

    test('a receipt for an unknown message is ignored', () async {
      expect(await repo.addReceipt('nope', 'sara', 1), isFalse);
    });

    test('receipts disappear with their message', () async {
      await repo.addReceipt('out', 'sara', 1);
      await repo.deleteMessage('out');
      expect(await repo.receiptCount('out'), 0);
    });
  });

  group('security log', () {
    test('records events newest first and counts recent ones', () async {
      await repo.recordSecurityEvent('bad_signature', peerId: 'abc', detail: 'x', atMs: 100);
      await repo.recordSecurityEvent('decrypt_failed', atMs: 200);
      final events = await repo.securityEvents();
      expect(events.map((e) => e.kind), ['decrypt_failed', 'bad_signature']);
      expect(events.last.peerId, 'abc');
      expect(await repo.securityEventCountSince(150), 1);
      await repo.clearSecurityEvents();
      expect(await repo.securityEvents(), isEmpty);
    });

    test('the log is capped so it cannot grow without bound', () async {
      for (var i = 0; i < 350; i++) {
        await repo.recordSecurityEvent('malformed', atMs: i);
      }
      final all = await repo.securityEvents(limit: 1000);
      expect(all.length, lessThanOrEqualTo(301));
      expect(all.first.atMs, 349); // newest kept
    });
  });

  group('settings', () {
    test('get / set / overwrite / remove', () async {
      expect(await repo.getSetting('nick'), isNull);
      await repo.setSetting('nick', 'A');
      await repo.setSetting('nick', 'B');
      expect(await repo.getSetting('nick'), 'B');
      await repo.removeSetting('nick');
      expect(await repo.getSetting('nick'), isNull);
    });

    test('all of them can be read in one go, with the latest value of each', () async {
      expect(await repo.allSettings(), isEmpty);
      await repo.setSetting('nick', 'A');
      await repo.setSetting('language', 'ckb');
      await repo.setSetting('nick', 'B');
      expect(await repo.allSettings(), {'nick': 'B', 'language': 'ckb'});
      await repo.removeSetting('nick');
      expect(await repo.allSettings(), {'language': 'ckb'});
    });
  });

  test('change notifications are emitted for the affected tables', () async {
    final seen = <DataChange>[];
    final sub = repo.changes.listen(seen.add);
    final p = await addPeer(1);
    final conv = await repo.ensureDirectConversation(p, nowMs: 1);
    await repo.insertMessage(msg('a', conv.id));
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();
    expect(seen, containsAll([DataChange.peers, DataChange.conversations, DataChange.messages]));
  });

  test('a repository sharing a change bus does not close it on dispose', () async {
    final bus = ChangeBus();
    final shared = MessageRepository(helper.db, bus: bus);
    final seen = <DataChange>[];
    final sub = bus.stream.listen(seen.add);
    await shared.dispose();
    bus.notify(DataChange.groups); // still open
    await Future<void>.delayed(Duration.zero);
    expect(seen, [DataChange.groups]);
    await sub.cancel();
    await bus.dispose();
  });
}
