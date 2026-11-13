import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:offline_mesh_chat/database/database_helper.dart';
import 'package:offline_mesh_chat/database/group_repository.dart';
import 'package:offline_mesh_chat/database/media_repository.dart';
import 'package:offline_mesh_chat/database/message_repository.dart';
import 'package:offline_mesh_chat/database/outbox_repository.dart';
import 'package:offline_mesh_chat/database/room_repository.dart';
import 'package:offline_mesh_chat/models/conversation.dart';
import 'package:offline_mesh_chat/models/group.dart';
import 'package:offline_mesh_chat/models/media.dart';
import 'package:offline_mesh_chat/models/message.dart';
import 'package:offline_mesh_chat/models/peer.dart';
import 'package:offline_mesh_chat/protocol/room_record.dart';

import '../support/legacy_schema.dart';
import '../support/test_database.dart';
import 'package:offline_mesh_chat/l10n/l10n.dart';

Uint8List _key(int v) => Uint8List(32)..fillRange(0, 32, v);

const _allTables = <String>[
  'peers',
  'conversations',
  'messages',
  'outbox',
  'outbox_sent',
  'seen_messages',
  'security_events',
  'settings',
  'message_receipts',
  'group_chats',
  'group_members',
  'rooms',
  'media',
  'media_chunks',
  'outgoing_parts',
  'pinned_messages',
  'deletion_events',
  'edit_events',
  'public_chat_cleanups',
];

void main() {
  test('creates the full schema', () async {
    final helper = await openMemoryDatabase();
    final tables = (await helper.db
            .rawQuery("SELECT name FROM sqlite_master WHERE type = 'table'"))
        .map((r) => r['name'])
        .toSet();
    expect(tables, containsAll(_allTables));
    expect(tables, isNot(contains('channels')), reason: 'channels were retired in v2');
    final version = (await helper.db.rawQuery('PRAGMA user_version')).first.values.first;
    expect(version, DatabaseHelper.schemaVersion);
    expect(DatabaseHelper.schemaVersion, 3);
    await helper.close();
  });

  test('foreign keys are enforced', () async {
    final helper = await openMemoryDatabase();
    final fk = await helper.db.rawQuery('PRAGMA foreign_keys');
    expect(fk.first.values.first, 1);
    await expectLater(
      helper.db.insert('messages', {
        'id': 'orphan',
        'conversation_id': 'does-not-exist',
        'sender_key': 'x',
        'is_outgoing': 0,
        'body': 'b',
        'sort_time': 1,
        'claimed_time': 1,
        'status': 'received',
      }),
      throwsA(anything),
    );
    await helper.close();
  });

  group('persistence across an application restart', () {
    late Directory dir;
    late String path;

    setUp(() {
      dir = makeTempDir('mesh_db_test_');
      path = '${dir.path}${Platform.pathSeparator}test.db';
    });

    tearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    test('chats, groups, rooms, media and the outbox are still there after re-opening', () async {
      var helper = await openFileDatabase(path);
      var bus = ChangeBus();
      var repo = MessageRepository(helper.db, bus: bus);
      var groups = GroupRepository(helper.db, bus: bus);
      var rooms = RoomRepository(helper.db, bus: bus);
      var media = MediaRepository(helper.db, bus: bus);
      var outbox = OutboxRepository(helper.db);

      final peer = (await repo.upsertPeer(
        signingKey: _key(7),
        agreementKey: _key(8),
        nickname: 'Bob',
        seenAtMs: 1000,
      ))
          .peer;
      final conv = await repo.ensureDirectConversation(peer, nowMs: 1000);
      await repo.insertMessage(ChatMessage(
        id: 'm1',
        conversationId: conv.id,
        senderId: 'me',
        isOutgoing: true,
        body: 'saved text',
        sortTimeMs: 2000,
        claimedTimestampMs: 2000,
        status: MessageStatus.queued,
      ));
      await repo.insertMessage(ChatMessage(
        id: 'img1',
        conversationId: conv.id,
        senderId: 'me',
        isOutgoing: true,
        kind: MessageKind.image,
        body: 'caption',
        mediaId: 'media1',
        sortTimeMs: 2100,
        claimedTimestampMs: 2100,
        status: MessageStatus.queued,
      ));
      await media.insert(MediaItem(
        id: 'media1',
        messageId: 'img1',
        kind: MediaKind.image,
        mimeCode: 1,
        byteLength: 3000,
        chunkCount: 2,
        sha256: Uint8List(32),
        width: 10,
        height: 20,
        state: MediaState.ready,
        fileName: 'media1.jpg',
        createdAtMs: 2100,
        expiresAtMs: 99999,
      ));
      await outbox.enqueue(OutboxEntry(
        messageId: 'm1',
        kind: OutboxKind.own,
        senderId: 'me',
        recipientId: peer.id,
        packet: Uint8List.fromList([1, 2, 3]),
        createdAtMs: 2000,
        expiresAtMs: 999999,
        nextAttemptAtMs: 2000,
        priority: OutboxPriority.message,
        flood: true,
      ));
      await outbox.recordSent('m1', 'neighbor-a', 2500);
      await outbox.addSeen('m1', 999999);
      await groups.save(GroupChat(
        id: 'g1',
        name: 'Family',
        adminId: 'me',
        epoch: 2,
        state: GroupState.active,
        createdAtMs: 5,
        joinedAtMs: 6,
        members: const [
          GroupMember(id: 'me', nickname: 'Me'),
          GroupMember(id: 'sara', nickname: 'Sara'),
        ],
      ));
      await rooms.ensureBuiltin(5);
      await repo.setSetting('nickname', 'Alice');
      await helper.close();

      // "Restart": a brand-new connection to the same file.
      helper = await openFileDatabase(path);
      bus = ChangeBus();
      repo = MessageRepository(helper.db, bus: bus);
      groups = GroupRepository(helper.db, bus: bus);
      rooms = RoomRepository(helper.db, bus: bus);
      media = MediaRepository(helper.db, bus: bus);
      outbox = OutboxRepository(helper.db);

      expect((await repo.getPeer(peer.id))!.nickname, 'Bob');
      expect((await repo.getMessages(conv.id)).map((m) => m.body), ['saved text', 'caption']);
      expect((await repo.getMessage('img1'))!.kind, MessageKind.image);
      expect((await repo.listConversations()).single.previewIn(englishStrings()), '📷 caption');
      expect((await media.get('media1'))!.fileName, 'media1.jpg');
      final queued = (await outbox.get('m1'))!;
      expect(queued.packet, [1, 2, 3]);
      expect(queued.priority, OutboxPriority.message);
      expect(queued.flood, isTrue);
      expect((await outbox.sentTo('m1')).keys, ['neighbor-a']);
      expect((await outbox.loadSeen(0)).keys, ['m1']);
      final group = (await groups.getGroup('g1'))!;
      expect(group.name, 'Family');
      expect(group.epoch, 2);
      expect(group.members.map((m) => m.nickname), ['Me', 'Sara']);
      expect((await rooms.getRoom(PublicRooms.meshIdHex))!.builtin, isTrue);
      expect(await repo.getSetting('nickname'), 'Alice');
      await helper.close();
    });
  });

  group('upgrading from the first release', () {
    late Directory dir;
    late String path;

    setUp(() {
      dir = makeTempDir('mesh_db_migrate_');
      path = '${dir.path}${Platform.pathSeparator}old.db';
    });

    tearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    Future<void> seedV1() async {
      final old = await createLegacyV1Database(path);
      await old.insert('peers', {
        'public_key': 'aa' * 32,
        'nickname': 'Bob',
        'verified': 1,
        'is_contact': 1,
        'blocked': 0,
        'first_seen': 1,
        'last_seen': 2,
      });
      await old.insert('conversations', {
        'id': 'dm:${'aa' * 32}',
        'type': 'direct',
        'title': 'Bob',
        'peer_key': 'aa' * 32,
        'created_at': 1,
        'unread_count': 1,
      });
      await old.insert('conversations', {
        'id': 'ch:general',
        'type': 'channel',
        'title': '#general',
        'channel_name': 'general',
        'created_at': 1,
        'unread_count': 0,
      });
      Future<void> message(String id, String conv, String status, {bool out = false}) =>
          old.insert('messages', {
            'id': id,
            'conversation_id': conv,
            'sender_key': 'x',
            'is_outgoing': out ? 1 : 0,
            'body': 'body $id',
            'sort_time': 10,
            'claimed_time': 10,
            'status': status,
          });
      await message('received', 'dm:${'aa' * 32}', 'received');
      await message('delivered', 'dm:${'aa' * 32}', 'delivered', out: true);
      await message('queued', 'dm:${'aa' * 32}', 'queued', out: true);
      await message('sent', 'dm:${'aa' * 32}', 'sent', out: true);
      await message('channelmsg', 'ch:general', 'received');
      await old.insert('channels', {'name': 'general', 'has_password': 0, 'joined_at': 1});
      await old.insert('outbox', {
        'message_id': 'queued',
        'kind': 'own',
        'sender_key': 'x',
        'packet': Uint8List.fromList([9]),
        'created_at': 1,
        'expires_at': 99999999999999,
        'next_attempt_at': 1,
      });
      await old.insert('outbox_sent', {'message_id': 'queued', 'neighbor_key': 'n', 'sent_at': 1});
      await old.insert('seen_messages', {'message_id': 's', 'expires_at': 99999999999999});
      await old.insert('settings', {'key': 'nickname', 'value': 'Alice'});
      await old.close();
    }

    test('chats and settings survive; channels and v1 packets are removed', () async {
      await seedV1();
      final helper = await openFileDatabase(path);
      final db = helper.db;

      expect((await db.rawQuery('PRAGMA user_version')).first.values.first, 3);

      final tables = (await db.rawQuery("SELECT name FROM sqlite_master WHERE type = 'table'"))
          .map((r) => r['name'])
          .toSet();
      expect(tables, containsAll(_allTables));
      expect(tables, isNot(contains('channels')));

      final convs = await db.query('conversations');
      expect(convs.map((c) => c['id']), ['dm:${'aa' * 32}']);

      final repo = MessageRepository(db);
      final ids = (await repo.getMessages('dm:${'aa' * 32}')).map((m) => m.id).toSet();
      expect(ids, {'received', 'delivered', 'queued', 'sent'});
      expect(await repo.getMessage('channelmsg'), isNull);

      // Messages that were still waiting on a v1 packet can no longer be sent.
      expect((await repo.getMessage('queued'))!.status, MessageStatus.failed);
      expect((await repo.getMessage('queued'))!.error, contains('updated'));
      expect((await repo.getMessage('sent'))!.status, MessageStatus.failed);
      expect((await repo.getMessage('delivered'))!.status, MessageStatus.delivered);
      expect((await repo.getMessage('received'))!.status, MessageStatus.received);
      expect((await repo.getMessage('received'))!.kind, MessageKind.text);

      expect(await OutboxRepository(db).count(), 0);
      expect(await OutboxRepository(db).loadSeen(0), isEmpty);
      expect(await repo.getSetting('nickname'), 'Alice');
      expect((await repo.getPeer('aa' * 32))!.verified, isTrue);

      await repo.dispose();
      await helper.close();
    });

    test('an upgraded database accepts every new kind of data', () async {
      await seedV1();
      final helper = await openFileDatabase(path);
      final bus = ChangeBus();
      final repo = MessageRepository(helper.db, bus: bus);
      final groups = GroupRepository(helper.db, bus: bus);
      final rooms = RoomRepository(helper.db, bus: bus);
      final media = MediaRepository(helper.db, bus: bus);
      final outbox = OutboxRepository(helper.db);

      final group = await repo.ensureGroupConversation('g', 'Trip', nowMs: 5);
      final room = await repo.ensureRoomConversation('r', '#cafe', nowMs: 5);
      expect([group.type, room.type], [ConversationType.group, ConversationType.room]);
      await repo.insertMessage(ChatMessage(
        id: 'v',
        conversationId: group.id,
        senderId: 'me',
        isOutgoing: true,
        kind: MessageKind.voice,
        body: '',
        mediaId: 'mv',
        sortTimeMs: 6,
        claimedTimestampMs: 6,
        status: MessageStatus.queued,
        recipientCount: 3,
      ));
      expect((await repo.getMessage('v'))!.recipientCount, 3);
      await media.insert(MediaItem(
        id: 'mv',
        messageId: 'v',
        kind: MediaKind.voice,
        mimeCode: 2,
        byteLength: 100,
        chunkCount: 1,
        sha256: Uint8List(32),
        durationMs: 1000,
        waveform: const [1, 2, 3],
        state: MediaState.sending,
        createdAtMs: 6,
        expiresAtMs: 99,
      ));
      expect((await media.get('mv'))!.waveform, [1, 2, 3]);
      await groups.save(const GroupChat(
        id: 'g',
        name: 'Trip',
        adminId: 'me',
        epoch: 0,
        state: GroupState.active,
        createdAtMs: 1,
      ));
      await rooms.ensureBuiltin(1);
      await outbox.enqueue(OutboxEntry(
        messageId: 'p',
        kind: OutboxKind.relay,
        senderId: 's',
        packet: Uint8List(1),
        createdAtMs: 1,
        expiresAtMs: 100,
        nextAttemptAtMs: 1,
        flood: true,
        priority: OutboxPriority.chunk,
      ));
      expect((await outbox.get('p'))!.flood, isTrue);
      await repo.dispose();
      await bus.dispose();
      await helper.close();
    });
  });

  test('deleteAllData empties every table but keeps the schema usable', () async {
    final helper = await openMemoryDatabase();
    final bus = ChangeBus();
    final repo = MessageRepository(helper.db, bus: bus);
    final outbox = OutboxRepository(helper.db);
    final groups = GroupRepository(helper.db, bus: bus);
    final rooms = RoomRepository(helper.db, bus: bus);
    final peer = (await repo.upsertPeer(
            signingKey: _key(1), agreementKey: _key(2), nickname: 'Bob', seenAtMs: 1))
        .peer;
    final conv = await repo.ensureDirectConversation(peer, nowMs: 1);
    await repo.insertMessage(ChatMessage(
      id: 'a',
      conversationId: conv.id,
      senderId: peer.id,
      isOutgoing: false,
      body: 'x',
      sortTimeMs: 1,
      claimedTimestampMs: 1,
      status: MessageStatus.received,
    ));
    await repo.addReceipt('a', 'someone', 1);
    await outbox.enqueue(OutboxEntry(
      messageId: 'a',
      kind: OutboxKind.relay,
      senderId: 's',
      packet: Uint8List(1),
      createdAtMs: 1,
      expiresAtMs: 100,
      nextAttemptAtMs: 1,
    ));
    await outbox.addSeen('a', 100);
    await groups.save(const GroupChat(
      id: 'g',
      name: 'G',
      adminId: 'me',
      epoch: 0,
      state: GroupState.active,
      createdAtMs: 1,
      members: [GroupMember(id: 'me', nickname: 'Me')],
    ));
    await rooms.ensureBuiltin(1);
    await repo.recordSecurityEvent('bad_signature', atMs: 1);
    await repo.setSetting('k', 'v');

    await helper.deleteAllData();

    for (final table in _allTables) {
      final n = (await helper.db.rawQuery('SELECT COUNT(*) AS n FROM $table')).first['n'];
      expect(n, 0, reason: table);
    }
    // Still usable afterwards.
    final again = await repo.upsertPeer(signingKey: _key(9), seenAtMs: 2);
    expect(again.isNew, isTrue);
    await helper.close();
  });

  group('upgrading from the second release (v2 to v3)', () {
    late Directory dir;
    late String path;

    setUp(() {
      dir = makeTempDir('mesh_db_migrate2_');
      path = '${dir.path}${Platform.pathSeparator}v2.db';
    });

    tearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    const dayMs = 24 * 60 * 60 * 1000;

    Future<void> seedV2() async {
      final old = await createLegacyV2Database(path);
      await old.insert('conversations', {
        'id': 'dm:${'aa' * 32}',
        'type': 'direct',
        'title': 'Bob',
        'peer_key': 'aa' * 32,
        'created_at': 1,
        'unread_count': 1,
      });
      await old.insert('conversations',
          {'id': 'rm:cafe', 'type': 'room', 'title': '#cafe', 'room_id': 'cafe', 'created_at': 1});
      Future<void> message(String id, String conv, int sortTime) => old.insert('messages', {
            'id': id,
            'conversation_id': conv,
            'sender_key': 'aa' * 32,
            'is_outgoing': 0,
            'body': 'body $id',
            'sort_time': sortTime,
            'claimed_time': sortTime,
            'status': 'received',
          });
      await message('private', 'dm:${'aa' * 32}', 1000);
      await message('public', 'rm:cafe', 2000);
      await old.insert('settings', {'key': 'nickname', 'value': 'Alice'});
      await old.close();
    }

    test('every message and setting survives, and nothing is rewritten', () async {
      await seedV2();
      final helper = await openFileDatabase(path);
      final db = helper.db;
      expect((await db.rawQuery('PRAGMA user_version')).first.values.first, 3);
      final tables = (await db.rawQuery("SELECT name FROM sqlite_master WHERE type = 'table'"))
          .map((r) => r['name'])
          .toSet();
      expect(tables, containsAll(_allTables));

      final repo = MessageRepository(db);
      final private = (await repo.getMessage('private'))!;
      expect(private.body, 'body private');
      expect(private.status, MessageStatus.received);
      expect(private.replyToId, isNull);
      expect(private.forwardedFrom, isNull);
      expect(private.isEdited, isFalse);
      expect(private.editVersion, 0);
      expect(private.expiresAtMs, isNull, reason: 'private chats never expire');
      expect(await repo.getSetting('nickname'), 'Alice');
      await repo.dispose();
      await helper.close();
    });

    test('public history gets its six-hour expiry from its own time; private chats get none',
        () async {
      await seedV2();
      final helper = await openFileDatabase(path);
      final repo = MessageRepository(helper.db);
      expect((await repo.getMessage('public'))!.expiresAtMs, 2000 + 6 * 60 * 60 * 1000);
      expect((await repo.getMessage('private'))!.expiresAtMs, isNull);

      // The first clean-up removes the overdue public message and only that one.
      final removed = await repo.removeExpiredPublic(2000 + dayMs);
      expect(removed.map((m) => m.id), ['public']);
      expect(await repo.getMessage('private'), isNotNull);
      await repo.dispose();
      await helper.close();
    });

    test('an upgraded database accepts replies, edits, pins and deletion records', () async {
      await seedV2();
      final helper = await openFileDatabase(path);
      final repo = MessageRepository(helper.db);
      await repo.setPinned('dm:${'aa' * 32}', 'private', true, 5);
      expect((await repo.pinnedMessages('dm:${'aa' * 32}')).single.id, 'private');
      expect(await repo.insertMessage(ChatMessage(
        id: 'answer',
        conversationId: 'dm:${'aa' * 32}',
        senderId: 'me',
        isOutgoing: true,
        body: 'a reply',
        sortTimeMs: 10,
        claimedTimestampMs: 10,
        status: MessageStatus.queued,
        replyToId: 'private',
        forwardedFrom: 'Carol',
      )), isTrue);
      final answer = (await repo.getMessage('answer'))!;
      expect(answer.replyToId, 'private');
      expect(answer.forwardedFrom, 'Carol');
      await repo.dispose();
      await helper.close();
    });
  });

  test('Conversation id helpers', () {
    expect(Conversation.directId('ab'), 'dm:ab');
    expect(Conversation.groupConversationId('cd'), 'gr:cd');
    expect(Conversation.roomConversationId('ef'), 'rm:ef');
    expect(Peer(signingKey: _key(1), firstSeenMs: 0, lastSeenMs: 0).shortId.length, 8);
  });
}
