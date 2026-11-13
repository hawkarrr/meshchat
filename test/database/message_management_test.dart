import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:offline_mesh_chat/database/database_helper.dart';
import 'package:offline_mesh_chat/database/message_repository.dart';
import 'package:offline_mesh_chat/models/message.dart';
import 'package:offline_mesh_chat/models/peer.dart';
import 'package:offline_mesh_chat/protocol/protocol_constants.dart';

import '../support/test_database.dart';
import 'package:offline_mesh_chat/l10n/l10n.dart';

const _hour = 60 * 60 * 1000;

/// Removing, editing, pinning, searching and expiring messages, at the data
/// layer: what is really gone, what must never come back, and what stays.
void main() {
  late DatabaseHelper helper;
  late MessageRepository repo;
  late Peer bobPeer;
  late String bob;
  late String direct;
  late String grp;
  late String room;

  setUp(() async {
    helper = await openMemoryDatabase();
    repo = MessageRepository(helper.db);
    bobPeer = (await repo.upsertPeer(
      signingKey: Uint8List(32)..fillRange(0, 32, 7),
      agreementKey: Uint8List(32)..fillRange(0, 32, 8),
      nickname: 'Bob',
      seenAtMs: 1,
    ))
        .peer;
    bob = bobPeer.id;
    direct = (await repo.ensureDirectConversation(bobPeer, nowMs: 0)).id;
    grp = (await repo.ensureGroupConversation('g1', 'Trip', nowMs: 0)).id;
    room = (await repo.ensureRoomConversation('r1', '#cafe', nowMs: 0)).id;
  });

  tearDown(() async {
    await repo.dispose();
    await helper.close();
  });

  ChatMessage msg(
    String id,
    String conv, {
    String? from,
    bool outgoing = false,
    String body = 'hi',
    int at = 1000,
    MessageKind kind = MessageKind.text,
    String? mediaId,
    String? replyTo,
    MessageStatus? status,
  }) =>
      ChatMessage(
        id: id,
        conversationId: conv,
        senderId: outgoing ? 'me' : (from ?? bob),
        isOutgoing: outgoing,
        kind: kind,
        body: body,
        mediaId: mediaId,
        sortTimeMs: at,
        claimedTimestampMs: at,
        status: status ?? (outgoing ? MessageStatus.queued : MessageStatus.received),
        replyToId: replyTo,
      );

  Future<int> count(String table) async =>
      (await helper.db.rawQuery('SELECT COUNT(*) AS n FROM $table')).first['n']! as int;

  group('removing messages', () {
    test('a removed message is really gone from the table, not merely hidden', () async {
      await repo.insertMessage(msg('a', direct));
      await repo.insertMessage(msg('b', direct, at: 2000));
      final removed = await repo.removeMessages(direct, ['a'],
          scope: 'me', requestedBy: 'me', atMs: 5000);
      expect(removed.map((m) => m.id), ['a']);
      expect(await repo.getMessage('a'), isNull);
      expect((await repo.getMessages(direct)).map((m) => m.id), ['b']);
      expect(await count('messages'), 1);
    });

    test('everything that hangs off it goes too: pins, receipts, picture and voice rows',
        () async {
      await repo.insertMessage(msg('a', grp, outgoing: true));
      await repo.setPinned(grp, 'a', true, 10);
      await repo.addReceipt('a', 'carol', 10);
      await helper.db.insert('media', {
        'id': 'm1',
        'message_id': 'a',
        'kind': 'image',
        'mime': 1,
        'byte_length': 10,
        'chunk_count': 1,
        'sha256': Uint8List.fromList([1, 2, 3]),
        'state': 'ready',
        'created_at': 1,
        'expires_at': 2,
      });
      await repo.removeMessages(grp, ['a'], scope: 'me', requestedBy: 'me', atMs: 5000);
      expect(await count('pinned_messages'), 0);
      expect(await count('message_receipts'), 0);
      expect(await count('media'), 0);
    });

    test('the preview and the unread count follow what is left', () async {
      await repo.insertMessage(msg('a', direct, body: 'first', at: 1000));
      await repo.insertMessage(msg('b', direct, body: 'second', at: 2000));
      await repo.insertMessage(msg('c', direct, body: 'third', at: 3000));
      var c = (await repo.getConversation(direct))!;
      expect([c.previewIn(englishStrings()), c.unreadCount], ['third', 3]);

      await repo.removeMessages(direct, ['c'], scope: 'me', requestedBy: 'me', atMs: 5000);
      c = (await repo.getConversation(direct))!;
      expect(c.previewIn(englishStrings()), 'second');
      expect(c.unreadCount, 2, reason: 'one fewer message to read');

      await repo.removeMessages(direct, ['a', 'b'], scope: 'me', requestedBy: 'me', atMs: 5000);
      c = (await repo.getConversation(direct))!;
      expect(c.previewIn(englishStrings()), isNull, reason: 'the empty chat shows no preview');
      expect(c.lastMessageAtMs, isNull);
      expect(c.unreadCount, 0);
      expect(await repo.getMessages(direct), isEmpty);
    });

    test('unread messages that stay are not lost when read ones are removed', () async {
      await repo.insertMessage(msg('a', direct, at: 1000));
      await repo.markConversationRead(direct);
      await repo.insertMessage(msg('b', direct, at: 2000));
      await repo.removeMessages(direct, ['a'], scope: 'me', requestedBy: 'me', atMs: 5000);
      expect((await repo.getConversation(direct))!.unreadCount, 1);
    });

    test('ids of another conversation are ignored: a chat cannot reach into another', () async {
      await repo.insertMessage(msg('x', grp));
      final removed = await repo.removeMessages(direct, ['x'],
          scope: 'remote', requestedBy: bob, atMs: 5000);
      expect(removed, isEmpty);
      expect(await repo.getMessage('x'), isNotNull);
    });

    test('removing is idempotent', () async {
      await repo.insertMessage(msg('a', direct));
      for (var i = 0; i < 3; i++) {
        await repo.removeMessages(direct, ['a'], scope: 'me', requestedBy: 'me', atMs: 5000);
      }
      expect(await repo.getMessages(direct), isEmpty);
    });
  });

  group('what is removed never comes back', () {
    test('a copy that arrives later is refused after "delete for me"', () async {
      await repo.insertMessage(msg('a', direct));
      await repo.removeMessages(direct, ['a'], scope: 'me', requestedBy: 'me', atMs: 5000);
      expect(await repo.insertMessage(msg('a', direct)), isFalse);
      expect(await repo.getMessages(direct), isEmpty);
      expect(await repo.wasRemoved('a'), isTrue);
    });

    test('a request to remove a message that has not arrived yet drops it on arrival, '
        'if the request came from the author', () async {
      await repo.rememberRemoteDeletion(direct, 'late', bob, 5000);
      expect(await repo.insertMessage(msg('late', direct, from: bob)), isFalse);
      expect(await repo.getMessages(direct), isEmpty);
    });

    test('a request from somebody who is not the author is not honoured', () async {
      await repo.rememberRemoteDeletion(grp, 'target', 'mallory', 5000);
      expect(await repo.insertMessage(msg('target', grp, from: 'carol')), isTrue,
          reason: 'mallory is neither the author nor the admin');
    });

    test("in a group, the admin's request counts for anyone's message", () async {
      await helper.db.insert('group_chats', {
        'id': 'g1',
        'name': 'Trip',
        'admin_key': 'admin',
        'epoch': 0,
        'state': 'active',
        'created_at': 0,
      });
      await repo.rememberRemoteDeletion(grp, 'target', 'admin', 5000);
      expect(await repo.insertMessage(msg('target', grp, from: 'carol')), isFalse);
    });

    test('records are kept only as long as a packet can live, then forgotten', () async {
      await repo.insertMessage(msg('a', direct));
      await repo.removeMessages(direct, ['a'], scope: 'me', requestedBy: 'me', atMs: 1000);
      await repo.purgeStaleRecords(1000 + Protocol.deletionRecordRetention.inMilliseconds - 1);
      expect(await repo.wasRemoved('a'), isTrue);
      await repo.purgeStaleRecords(1000 + Protocol.deletionRecordRetention.inMilliseconds);
      expect(await repo.wasRemoved('a'), isFalse);
    });

    test('a record holds no message content', () async {
      await repo.insertMessage(msg('a', direct, body: 'secret words'));
      await repo.removeMessages(direct, ['a'], scope: 'me', requestedBy: 'me', atMs: 1000);
      final rows = await helper.db.query('deletion_events');
      expect(rows.single.values.whereType<String>().join(' '), isNot(contains('secret')));
    });
  });

  group('delete requests of our own', () {
    test('their state only moves forward, and expiry is honest', () async {
      await repo.insertMessage(msg('a', direct, outgoing: true, status: MessageStatus.sent));
      await repo.removeMessages(direct, ['a'],
          scope: 'everyone',
          requestedBy: 'me',
          atMs: 1000,
          controlPacket: 'ctl',
          state: 'queued');
      expect(await repo.deletionRequestState('a'), 'queued');
      await repo.advanceDeletionRequest('ctl', 'sent');
      expect(await repo.deletionRequestState('a'), 'sent');
      await repo.advanceDeletionRequest('ctl', 'queued');
      expect(await repo.deletionRequestState('a'), 'sent', reason: 'never back');
      await repo.advanceDeletionRequest('ctl', 'delivered');
      expect(await repo.deletionRequestState('a'), 'delivered');
      await repo.expireDeletionRequest('ctl');
      expect(await repo.deletionRequestState('a'), 'delivered',
          reason: 'a confirmed request cannot later "expire"');
    });

    test('an unconfirmed request is marked expired when it runs out of time', () async {
      await repo.insertMessage(msg('a', direct, outgoing: true, status: MessageStatus.sent));
      await repo.removeMessages(direct, ['a'],
          scope: 'everyone', requestedBy: 'me', atMs: 1000, controlPacket: 'ctl', state: 'sent');
      await repo.expireDeletionRequest('ctl');
      expect(await repo.deletionRequestState('a'), 'expired');
      expect((await repo.deletionByControlPacket('ctl'))!.messageId, 'a');
    });

    test('a "delete for me" has no request state', () async {
      await repo.insertMessage(msg('a', direct));
      await repo.removeMessages(direct, ['a'], scope: 'me', requestedBy: 'me', atMs: 1000);
      expect(await repo.deletionRequestState('a'), isNull);
    });
  });

  group('editing', () {
    Future<EditOutcome> edit(String id, String from, int version, String text,
            {String? conv}) =>
        repo.applyEdit(
          conversationId: conv ?? direct,
          messageId: id,
          senderKey: from,
          version: version,
          text: text,
          atMs: 9000,
        );

    test("the author's newer text replaces the old one and shows as edited", () async {
      await repo.insertMessage(msg('a', direct, body: 'original'));
      expect(await edit('a', bob, 10, 'fixed'), EditOutcome.applied);
      final m = (await repo.getMessage('a'))!;
      expect([m.body, m.isEdited, m.editVersion], ['fixed', true, 10]);
      expect((await repo.getConversation(direct))!.previewIn(englishStrings()), 'fixed',
          reason: 'the preview is updated');
    });

    test('an older or repeated edit never puts an old text back', () async {
      await repo.insertMessage(msg('a', direct, body: 'original'));
      await edit('a', bob, 20, 'second');
      expect(await edit('a', bob, 10, 'first'), EditOutcome.older);
      expect(await edit('a', bob, 20, 'second'), EditOutcome.older);
      expect((await repo.getMessage('a'))!.body, 'second');
    });

    test('only the author can edit, only text, only inside the conversation', () async {
      await repo.insertMessage(msg('a', direct, body: 'original'));
      expect(await edit('a', 'mallory', 10, 'forged'), EditOutcome.rejected);
      expect(await edit('a', bob, 10, 'wrong chat', conv: grp), EditOutcome.rejected);
      await repo.insertMessage(msg('p', direct, kind: MessageKind.image, mediaId: 'm'));
      expect(await edit('p', bob, 10, 'not text'), EditOutcome.rejected);
      await repo.insertMessage(msg('mine', direct, outgoing: true));
      expect(await edit('mine', 'me', 10, 'loop'), EditOutcome.rejected,
          reason: 'an incoming event cannot rewrite our own message');
      expect((await repo.getMessage('a'))!.body, 'original');
    });

    test('an edit that arrives before its message is kept and applied on arrival', () async {
      expect(await edit('late', bob, 10, 'edited text'), EditOutcome.pending);
      expect(await repo.insertMessage(msg('late', direct, body: 'original text')), isTrue);
      final m = (await repo.getMessage('late'))!;
      expect([m.body, m.isEdited, m.editVersion], ['edited text', true, 10]);
      expect((await repo.getConversation(direct))!.previewIn(englishStrings()), 'edited text');
      expect(await count('edit_events'), 0, reason: 'nothing is left pending');
    });

    test('of several early edits the newest wins, and one from someone else is ignored',
        () async {
      await edit('late', bob, 10, 'one');
      await edit('late', bob, 30, 'three');
      await edit('late', bob, 20, 'two');
      await edit('late', 'mallory', 40, 'forged');
      await repo.insertMessage(msg('late', direct, body: 'zero'));
      expect((await repo.getMessage('late'))!.body, 'three');
    });

    test('an edit for a message that was removed is rejected, not parked', () async {
      await repo.insertMessage(msg('a', direct));
      await repo.removeMessages(direct, ['a'], scope: 'me', requestedBy: 'me', atMs: 1);
      expect(await edit('a', bob, 10, 'zombie'), EditOutcome.rejected);
      expect(await count('edit_events'), 0);
    });

    test('our own edit uses an increasing version', () async {
      await repo.insertMessage(msg('mine', direct, outgoing: true, body: 'v0'));
      expect(await repo.updateOwnText('mine', 'v1', 100, 5), isTrue);
      expect(await repo.updateOwnText('mine', 'older', 100, 6), isFalse);
      expect(await repo.updateOwnText('mine', 'v2', 101, 7), isTrue);
      expect((await repo.getMessage('mine'))!.body, 'v2');
    });
  });

  group('pins (personal)', () {
    test('pin, list newest first, unpin', () async {
      await repo.insertMessage(msg('a', direct, at: 1000));
      await repo.insertMessage(msg('b', direct, at: 2000));
      expect(await repo.setPinned(direct, 'a', true, 10), isTrue);
      expect(await repo.setPinned(direct, 'b', true, 20), isTrue);
      expect(await repo.setPinned(direct, 'b', true, 30), isFalse, reason: 'already pinned');
      expect((await repo.pinnedMessages(direct)).map((m) => m.id), ['b', 'a']);
      expect(await repo.pinnedIds(direct), {'a', 'b'});
      expect(await repo.setPinned(direct, 'b', false, 40), isTrue);
      expect((await repo.pinnedMessages(direct)).map((m) => m.id), ['a']);
    });

    test('only an existing message of that conversation can be pinned', () async {
      await repo.insertMessage(msg('a', grp));
      expect(await repo.setPinned(direct, 'a', true, 10), isFalse);
      expect(await repo.setPinned(direct, 'nope', true, 10), isFalse);
    });

    test('a pin disappears with its message, however the message goes', () async {
      await repo.insertMessage(msg('a', direct));
      await repo.insertMessage(msg('b', direct, at: 2000));
      await repo.setPinned(direct, 'a', true, 1);
      await repo.setPinned(direct, 'b', true, 2);
      await repo.removeMessages(direct, ['a'], scope: 'remote', requestedBy: bob, atMs: 5);
      expect((await repo.pinnedMessages(direct)).map((m) => m.id), ['b']);
      await repo.deleteMessage('b');
      expect(await repo.pinnedMessages(direct), isEmpty);
    });

    test('pinning is local: it changes nothing about the message', () async {
      await repo.insertMessage(msg('a', direct));
      final before = await repo.getMessage('a');
      await repo.setPinned(direct, 'a', true, 1);
      final after = await repo.getMessage('a');
      expect([after!.body, after.status, after.editVersion],
          [before!.body, before.status, before.editVersion]);
    });
  });

  group('search', () {
    setUp(() async {
      await repo.insertMessage(msg('1', direct, body: 'Lunch at noon?', at: 1000));
      await repo.insertMessage(msg('2', direct, body: 'sounds good', outgoing: true, at: 2000));
      await repo.insertMessage(
          msg('3', direct, body: 'the lake', kind: MessageKind.image, mediaId: 'm', at: 3000));
      await repo.insertMessage(msg('4', direct, body: '', kind: MessageKind.voice, mediaId: 'v', at: 4000));
      await repo.insertMessage(msg('5', direct, body: '100% sure_', at: 5000));
      await repo.insertMessage(msg('x', grp, body: 'lunch in the group'));
    });

    test('finds text and captions, ignoring case, newest first, inside one conversation', () async {
      expect((await repo.searchMessages(direct, query: 'LUNCH')).map((m) => m.id), ['1']);
      expect((await repo.searchMessages(direct, query: 'lake')).map((m) => m.id), ['3']);
      expect((await repo.searchMessages(direct, query: 'u')).map((m) => m.id), ['5', '2', '1']);
    });

    test('filters by kind and by sender', () async {
      expect((await repo.searchMessages(direct, kinds: {MessageKind.image, MessageKind.voice}))
          .map((m) => m.id), ['4', '3']);
      expect((await repo.searchMessages(direct, senderId: 'me')).map((m) => m.id), ['2']);
      expect((await repo.searchMessages(direct, query: 'u', kinds: {MessageKind.text}, senderId: bob))
          .map((m) => m.id), ['5', '1']);
    });

    test('wildcard characters in the search are plain characters', () async {
      expect((await repo.searchMessages(direct, query: '100%')).map((m) => m.id), ['5']);
      expect((await repo.searchMessages(direct, query: '_')).map((m) => m.id), ['5']);
      expect(await repo.searchMessages(direct, query: '%'), hasLength(1));
    });

    test('removed messages never show up', () async {
      await repo.removeMessages(direct, ['1'], scope: 'me', requestedBy: 'me', atMs: 9);
      expect(await repo.searchMessages(direct, query: 'lunch'), isEmpty);
    });
  });

  group('public chat expiry', () {
    test('only public messages get an expiry, six hours after the local time', () async {
      await repo.insertMessage(msg('pub', room, at: 1000));
      await repo.insertMessage(msg('prv', direct, at: 1000));
      await repo.insertMessage(msg('grp', grp, at: 1000));
      expect((await repo.getMessage('pub'))!.expiresAtMs, 1000 + 6 * _hour);
      expect((await repo.getMessage('prv'))!.expiresAtMs, isNull);
      expect((await repo.getMessage('grp'))!.expiresAtMs, isNull);
    });

    test('the clean-up removes exactly the overdue public messages and nothing else', () async {
      await repo.insertMessage(msg('old', room, at: 1000));
      await repo.insertMessage(msg('new', room, at: 1000 + 5 * _hour));
      await repo.insertMessage(msg('prv', direct, at: 1000));
      await repo.insertMessage(msg('grp', grp, at: 1000));

      final removed = await repo.removeExpiredPublic(1000 + 6 * _hour);
      expect(removed.map((m) => m.id), ['old']);
      expect(await repo.getMessage('new'), isNotNull);
      expect(await repo.getMessage('prv'), isNotNull, reason: 'private chats survive');
      expect(await repo.getMessage('grp'), isNotNull, reason: 'groups survive');
    });

    test('running it again, or much later, finds nothing more or only what is due', () async {
      await repo.insertMessage(msg('old', room, at: 1000));
      expect(await repo.removeExpiredPublic(1000 + 7 * _hour), hasLength(1));
      expect(await repo.removeExpiredPublic(1000 + 7 * _hour), isEmpty);
      expect(await repo.removeExpiredPublic(1000 + 7 * _hour), isEmpty);
    });

    test('expired messages leave the list, the preview and the pins', () async {
      await repo.insertMessage(msg('a', room, body: 'old news', at: 1000));
      await repo.insertMessage(msg('b', room, body: 'fresh', at: 1000 + 5 * _hour));
      await repo.setPinned(room, 'a', true, 1);
      await repo.removeExpiredPublic(1000 + 6 * _hour);
      expect((await repo.getMessages(room)).map((m) => m.id), ['b']);
      expect(await repo.pinnedMessages(room), isEmpty);
      expect((await repo.getConversation(room))!.previewIn(englishStrings()), contains('fresh'));
      expect(await repo.searchMessages(room, query: 'old'), isEmpty);
    });

    test('a late copy of an expired message cannot reappear during synchronisation', () async {
      await repo.insertMessage(msg('a', room, at: 1000));
      await repo.removeExpiredPublic(1000 + 7 * _hour);
      expect(await repo.insertMessage(msg('a', room, at: 1000 + 7 * _hour)), isFalse);
    });

    test('the clean-up is logged', () async {
      expect(await repo.lastPublicCleanup(), isNull);
      await repo.recordPublicCleanup(5000, removed: 3, files: 1);
      expect(await repo.lastPublicCleanup(), (at: 5000, removed: 3));
      await repo.recordPublicCleanup(9000, removed: 1);
      expect((await repo.lastPublicCleanup())!.removed, 1);
    });

    test('the retention is configurable for the repository', () async {
      final short = MessageRepository(helper.db, publicRetention: const Duration(minutes: 1));
      await short.insertMessage(msg('s', room, at: 1000));
      expect((await short.getMessage('s'))!.expiresAtMs, 1000 + 60000);
      await short.dispose();
    });
  });

  group('what other phones ask for is kept within bounds', () {
    test('edits that arrive before their message: the newest are kept, and still apply', () async {
      final small = MessageRepository(helper.db, maxPendingEdits: 5);
      addTearDown(small.dispose);
      for (var i = 0; i < 20; i++) {
        await small.applyEdit(
          conversationId: direct,
          messageId: 'm$i',
          senderKey: bob,
          version: 10,
          text: 'text $i',
          atMs: 1000 + i,
        );
      }
      final rows = await helper.db.query('edit_events', orderBy: 'at');
      expect([for (final r in rows) r['message_id']], ['m15', 'm16', 'm17', 'm18', 'm19']);

      await small.insertMessage(msg('m19', direct, body: 'original'));
      expect((await small.getMessage('m19'))!.body, 'text 19', reason: 'a kept edit is still applied');
      await small.insertMessage(msg('m0', direct, body: 'original'));
      expect((await small.getMessage('m0'))!.body, 'original', reason: 'the oldest was let go');
    });

    test('deletion requests for messages that never came: the newest are kept; ours never go', () async {
      final small = MessageRepository(helper.db, maxRemoteDeletionRecords: 5);
      addTearDown(small.dispose);
      await small.insertMessage(msg('mine', direct));
      await small.removeMessages(direct, ['mine'], scope: 'me', requestedBy: 'me', atMs: 500);
      for (var i = 0; i < 20; i++) {
        await small.rememberRemoteDeletion(direct, 'x$i', bob, 1000 + i);
      }
      final remote = await helper.db.query('deletion_events', where: "scope = 'remote'", orderBy: 'at');
      expect([for (final r in remote) r['message_id']], ['x15', 'x16', 'x17', 'x18', 'x19']);
      expect(await small.wasRemoved('mine'), isTrue, reason: 'a deletion made here is never dropped');
      expect(await small.insertMessage(msg('x19', direct)), isFalse, reason: 'the newest still blocks it');
      expect(await small.insertMessage(msg('x0', direct)), isTrue, reason: 'the oldest was let go');
    });

    test('the limits are generous for real use', () {
      expect(Protocol.maxPendingEdits, greaterThanOrEqualTo(100));
      expect(Protocol.maxRemoteDeletionRecords, greaterThanOrEqualTo(1000));
    });
  });
}
