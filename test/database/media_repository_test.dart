import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:offline_mesh_chat/database/database_helper.dart';
import 'package:offline_mesh_chat/database/media_repository.dart';
import 'package:offline_mesh_chat/database/message_repository.dart';
import 'package:offline_mesh_chat/models/media.dart';
import 'package:offline_mesh_chat/models/message.dart';

import '../support/test_database.dart';

MediaItem _item(
  String id, {
  String messageId = 'msg',
  MediaKind kind = MediaKind.image,
  MediaState state = MediaState.receiving,
  int chunkCount = 3,
  int expires = 100000,
  List<int> waveform = const [],
}) =>
    MediaItem(
      id: id,
      messageId: messageId,
      kind: kind,
      mimeCode: kind == MediaKind.image ? 1 : 2,
      byteLength: 4000,
      chunkCount: chunkCount,
      sha256: Uint8List.fromList(List.filled(32, 7)),
      width: 320,
      height: 240,
      durationMs: kind == MediaKind.voice ? 9000 : 0,
      waveform: waveform,
      state: state,
      createdAtMs: 1000,
      expiresAtMs: expires,
    );

void main() {
  late DatabaseHelper helper;
  late ChangeBus bus;
  late MessageRepository messages;
  late MediaRepository media;

  setUp(() async {
    helper = await openMemoryDatabase();
    bus = ChangeBus();
    messages = MessageRepository(helper.db, bus: bus);
    media = MediaRepository(helper.db, bus: bus);
    final conv = await messages.ensureGroupConversation('g', 'G', nowMs: 1);
    for (final id in ['msg', 'msg2']) {
      await messages.insertMessage(ChatMessage(
        id: id,
        conversationId: conv.id,
        senderId: 'them',
        isOutgoing: false,
        kind: MessageKind.image,
        body: '',
        mediaId: 'm-$id',
        sortTimeMs: 10,
        claimedTimestampMs: 10,
        status: MessageStatus.received,
      ));
    }
  });

  tearDown(() async {
    await bus.dispose();
    await helper.close();
  });

  Uint8List bytes(int n, [int v = 1]) => Uint8List.fromList(List.filled(n, v));

  group('media rows', () {
    test('store everything the UI needs', () async {
      await media.insert(_item('a', kind: MediaKind.voice, waveform: const [1, 50, 255]),
          key: bytes(32, 9));
      final m = (await media.get('a'))!;
      expect(m.kind, MediaKind.voice);
      expect(m.isVoice, isTrue);
      expect(m.waveform, [1, 50, 255]);
      expect(m.durationMs, 9000);
      expect(m.duration, const Duration(seconds: 9));
      expect(m.state, MediaState.receiving);
      expect(m.sha256, List.filled(32, 7));
      expect(await media.keyOf('a'), bytes(32, 9));
      expect((await media.forMessage('msg'))!.id, 'a');
    });

    test('an image has no waveform and no key unless given one', () async {
      await media.insert(_item('a'));
      final m = (await media.get('a'))!;
      expect(m.isImage, isTrue);
      expect(m.waveform, isEmpty);
      expect(m.width, 320);
      expect(await media.keyOf('a'), isNull);
      expect(await media.keyOf('missing'), isNull);
    });

    test('getMany returns only what exists, keyed by media id', () async {
      await media.insert(_item('a'));
      await media.insert(_item('b', messageId: 'msg2'));
      final many = await media.getMany(['a', 'b', 'zzz']);
      expect(many.keys.toSet(), {'a', 'b'});
      expect(await media.getMany(const []), isEmpty);
    });

    test('getMany copes with more ids than one SQL statement allows', () async {
      await media.insert(_item('a'));
      final ids = ['a', for (var i = 0; i < 1200; i++) 'x$i'];
      expect((await media.getMany(ids)).keys, ['a']);
    });

    test('state changes: ready sets the file and drops the key', () async {
      await media.insert(_item('a'), key: bytes(32));
      await media.setState('a', MediaState.ready, fileName: 'a.jpg', dropKey: true);
      final m = (await media.get('a'))!;
      expect(m.isReady, isTrue);
      expect(m.progress, 1);
      expect(m.fileName, 'a.jpg');
      expect(await media.keyOf('a'), isNull);
      await media.setState('a', MediaState.failed, error: 'damaged');
      final f = (await media.get('a'))!;
      expect(f.state, MediaState.failed);
      expect(f.error, 'damaged');
      expect(f.fileName, 'a.jpg', reason: 'an existing file name is kept');
    });

    test('progress follows the chunks received', () async {
      await media.insert(_item('a', chunkCount: 4));
      await media.setReceivedChunks('a', 1);
      expect((await media.get('a'))!.progress, 0.25);
      await media.setReceivedChunks('a', 4);
      expect((await media.get('a'))!.progress, 1);
    });

    test('deleting the message deletes its media row', () async {
      await media.insert(_item('a'));
      await messages.deleteMessage('msg');
      expect(await media.get('a'), isNull);
    });

    test('a media row needs its message (foreign key)', () async {
      await expectLater(media.insert(_item('a', messageId: 'nope')), throwsA(anything));
    });

    test('referenced file names are listed for cleanup', () async {
      await media.insert(_item('a'));
      await media.insert(_item('b', messageId: 'msg2'));
      await media.setState('a', MediaState.ready, fileName: 'a.jpg');
      expect(await media.referencedFileNames(), {'a.jpg'});
    });

    test('unknown state names fail closed', () {
      expect(MediaState.parse('???'), MediaState.failed);
    });
  });

  group('chunks', () {
    Future<bool> store(String id, int i, {bool sealed = false, int at = 1000, int size = 10}) =>
        media.storeChunk(
          mediaId: id,
          index: i,
          data: bytes(size, i + 1),
          sealed: sealed,
          senderId: 'them',
          nowMs: at,
        );

    test('a chunk position is stored once', () async {
      expect(await store('a', 0), isTrue);
      expect(await store('a', 0), isFalse);
      expect(await store('a', 1), isTrue);
      expect(await media.plainChunkCount('a'), 2);
    });

    test('chunks come back in order whatever order they arrived in', () async {
      for (final i in [2, 0, 1]) {
        await store('a', i);
      }
      final chunks = await media.chunks('a');
      expect(chunks.map((c) => c.index), [0, 1, 2]);
      expect(chunks[1].data, bytes(10, 2));
      expect(chunks.first.senderId, 'them');
    });

    test('sealed chunks wait for their manifest and are opened in place', () async {
      await store('a', 0, sealed: true);
      await store('a', 1);
      expect(await media.plainChunkCount('a'), 1);
      expect((await media.chunks('a', sealed: true)).single.index, 0);
      await media.replaceChunk('a', 0, bytes(5, 99));
      expect(await media.plainChunkCount('a'), 2);
      expect((await media.chunks('a', sealed: true)), isEmpty);
      expect((await media.chunks('a')).first.data, bytes(5, 99));
    });

    test('a single chunk can be dropped, or all of them', () async {
      await store('a', 0);
      await store('a', 1);
      await media.deleteChunk('a', 0);
      expect((await media.chunks('a')).map((c) => c.index), [1]);
      await media.deleteChunks('a');
      expect(await media.chunks('a'), isEmpty);
    });

    test('orphans (no manifest yet) are counted and pruned by age', () async {
      await media.insert(_item('known'));
      await store('known', 0, at: 100);
      await store('orphan1', 0, at: 100);
      await store('orphan2', 0, at: 900);
      expect(await media.orphanChunkCount(), 2);
      expect(await media.pruneOrphanChunks(500), 1);
      expect(await media.orphanChunkCount(), 1);
      expect(await media.plainChunkCount('known'), 1, reason: 'chunks of known media are kept');
    });
  });

  group('partial media', () {
    test('lists receiving media past its deadline, and what was left unfinished', () async {
      await media.insert(_item('late', expires: 5000));
      await media.insert(_item('fresh', messageId: 'msg2', expires: 90000));
      expect((await media.expiredPartial(6000)).map((m) => m.id), ['late']);
      expect((await media.receiving()).map((m) => m.id).toSet(), {'late', 'fresh'});
      await media.setState('late', MediaState.ready, fileName: 'x');
      expect(await media.expiredPartial(6000), isEmpty);
    });
  });

  group('our own uploads', () {
    test('a message is complete when every part was acknowledged', () async {
      await media.addOutgoingParts('msg', ['p0', 'p1', 'p2']);
      expect(await media.unackedPartCount('msg'), 3);

      var progress = (await media.ackPart('p1'))!;
      expect(progress.messageId, 'msg');
      expect(progress.remaining, 2);
      progress = (await media.ackPart('p0'))!;
      expect(progress.remaining, 1);
      progress = (await media.ackPart('p2'))!;
      expect(progress.remaining, 0);
    });

    test('an unknown or repeated acknowledgement changes nothing', () async {
      await media.addOutgoingParts('msg', ['p0', 'p1']);
      expect(await media.ackPart('nope'), isNull);
      expect(await media.ackPart('p0'), isNotNull);
      expect(await media.ackPart('p0'), isNull);
      expect(await media.unackedPartCount('msg'), 1);
    });

    test('two messages are tracked independently', () async {
      await media.addOutgoingParts('msg', ['a0']);
      await media.addOutgoingParts('msg2', ['b0', 'b1']);
      expect((await media.ackPart('b0'))!.remaining, 1);
      expect((await media.ackPart('a0'))!.remaining, 0);
      expect(await media.unackedPartCount('msg2'), 1);
    });

    test('parts disappear with their message', () async {
      await media.addOutgoingParts('msg', ['a0']);
      await messages.deleteMessage('msg');
      expect(await media.ackPart('a0'), isNull);
    });
  });
}
