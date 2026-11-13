import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:offline_mesh_chat/crypto/key_store.dart';
import 'package:offline_mesh_chat/models/conversation.dart';
import 'package:offline_mesh_chat/models/media.dart';
import 'package:offline_mesh_chat/models/message.dart';
import 'package:offline_mesh_chat/protocol/room_record.dart';
import 'package:offline_mesh_chat/services/discovery_service.dart';
import 'package:offline_mesh_chat/services/media_service.dart' show MediaDraft;
import 'package:offline_mesh_chat/services/media_store.dart';
import 'package:path/path.dart' as p;

import '../support/app_harness.dart';
import '../support/fake_ble_world.dart';
import '../support/message_node.dart' show fakeBytes;
import '../support/radio_harness.dart';
import '../support/test_database.dart';

MediaDraft _photo(Uint8List bytes, {String caption = ''}) =>
    MediaDraft(kind: MediaKind.image, bytes: bytes, width: 640, height: 480, caption: caption);

MediaDraft _voice(Uint8List bytes) => MediaDraft(
      kind: MediaKind.voice,
      bytes: bytes,
      durationMs: 8000,
      waveform: List<int>.generate(32, (i) => (i * 9) & 0xff),
    );

/// Local storage on a real disk: the SQLite database in a file, pictures and
/// voice messages as files in a private folder, keys in the key store. The
/// phone is simulated, the storage is not.
void main() {
  late FakeBleWorld world;
  late Directory root;
  final nodes = <AppNode>[];

  setUp(() {
    world = FakeBleWorld();
    root = makeTempDir('damataqe_storage_');
    nodes.clear();
  });

  tearDown(() async {
    for (final n in nodes) {
      await n.dispose();
    }
    try {
      root.deleteSync(recursive: true);
    } on FileSystemException {
      // Best effort: it is a temp directory (Windows may still hold a handle).
    }
  });

  Future<AppNode> phone(String name,
      {KeyStore? keys, String? dbPath, Directory? mediaFolder}) async {
    final n = await AppNode.create(
      world,
      name,
      keys: keys,
      db: dbPath == null ? null : await openFileDatabase(dbPath),
      media: mediaFolder == null ? null : FileMediaStore(mediaFolder),
    );
    nodes.add(n);
    return n;
  }

  List<String> filesIn(Directory d) {
    if (!d.existsSync()) return <String>[];
    return d.listSync().map((e) => p.basename(e.path)).toList()..sort();
  }

  test('chats, pictures, voice messages, settings and keys are kept on the phone and survive a restart',
      () async {
    final bobFolder = Directory(p.join(root.path, 'bob', 'media'));
    Directory(p.join(root.path, 'bob')).createSync(recursive: true);
    final bobDb = p.join(root.path, 'bob', 'app.db');
    final bobKeys = MemoryKeyStore();

    final alice = await phone('Alice');
    var bob = await phone('Bob', keys: bobKeys, dbPath: bobDb, mediaFolder: bobFolder);
    await alice.controller.setNickname('Alice');
    await bob.controller.setNickname('Bobby');
    await bob.controller.setRetentionDays(7);
    await bob.controller.setDiscoveryMode(DiscoveryMode.lowPower);
    await alice.startUp();
    await bob.startUp();
    await waitForDirect(alice, bob);

    final photo = fakeBytes(9000, 41);
    final audio = fakeBytes(4500, 42);
    final chat = Conversation.directId(bob.id);
    await alice.controller.sendText(chat, 'saved on the phone?');
    await alice.controller.sendMedia(chat, _photo(photo, caption: 'a picture'));
    await alice.controller.sendMedia(chat, _voice(audio));

    final fromAlice = Conversation.directId(alice.id);
    await eventually(() async {
      final all = await bob.controller.loadMessages(fromAlice);
      if (all.length < 3) return false;
      final items = await bob.controller.loadMedia([
        for (final m in all)
          if (m.mediaId != null) m.mediaId!
      ]);
      return items.length == 2 && items.values.every((i) => i.isReady);
    }, timeout: const Duration(seconds: 20), reason: 'Bob should hold the text, picture and voice');

    // The pictures and recordings are real files, named after their media id, and nothing else
    // (no half-written leftovers) is in the folder.
    final items = (await bob.controller.loadMedia([
      for (final m in await bob.controller.loadMessages(fromAlice))
        if (m.mediaId != null) m.mediaId!
    ]))
        .values
        .toList();
    expect(filesIn(bobFolder), [for (final i in items) i.fileName!]..sort());
    expect(filesIn(bobFolder).where((n) => n.endsWith('.jpg')), hasLength(1));
    expect(filesIn(bobFolder).where((n) => n.endsWith('.m4a')), hasLength(1));
    final image = items.firstWhere((i) => i.kind == MediaKind.image);
    expect(File(p.join(bobFolder.path, image.fileName!)).readAsBytesSync(), photo);

    // Bob closes the app. Nothing is held in memory any more.
    final bobId = bob.id;
    await bob.dispose();
    nodes.remove(bob);

    // Bob opens it again: same database file, same folder, same key store.
    bob = await phone('Bob', keys: bobKeys, dbPath: bobDb, mediaFolder: bobFolder);
    expect(bob.id, bobId, reason: 'the identity lives in the key store');
    expect(bob.controller.nickname, 'Bobby');
    expect(bob.controller.retentionDays, 7);
    expect(bob.controller.discoveryMode, DiscoveryMode.lowPower);

    final messages = await bob.controller.loadMessages(fromAlice);
    expect(messages.map((m) => m.kind), containsAll([MessageKind.text, MessageKind.image, MessageKind.voice]));
    expect(messages.firstWhere((m) => m.kind == MessageKind.text).body, 'saved on the phone?');
    expect(messages.firstWhere((m) => m.kind == MessageKind.image).body, 'a picture');
    final restored = await bob.controller.loadMedia([
      for (final m in messages)
        if (m.mediaId != null) m.mediaId!
    ]);
    expect(restored.values.every((i) => i.isReady), isTrue);
    final restoredImage = restored.values.firstWhere((i) => i.kind == MediaKind.image);
    final restoredVoice = restored.values.firstWhere((i) => i.kind == MediaKind.voice);
    expect(await bob.controller.mediaBytes(restoredImage), photo);
    expect(await bob.controller.mediaBytes(restoredVoice), audio);
    final voicePath = await bob.controller.mediaPath(restoredVoice);
    expect(voicePath, isNotNull, reason: 'the player needs a real file path');
    expect(File(voicePath!).readAsBytesSync(), audio);
    expect(bob.controller.conversations.any((c) => c.id == fromAlice), isTrue);

    // "Delete all local data" removes the files too, not only the database rows.
    await bob.controller.clearAllData();
    expect(filesIn(bobFolder), isEmpty, reason: 'every picture and recording is deleted');
    expect(await bob.controller.loadMessages(fromAlice), isEmpty);
    expect(bob.id, isNot(bobId), reason: 'a new identity after wiping the keys');
  });

  test('deleting a chat, a group or a room removes its pictures from the phone at once', () async {
    final folder = Directory(p.join(root.path, 'alice', 'media'));
    final alice = await phone('Alice', mediaFolder: folder);
    final bob = await phone('Bob');
    await alice.startUp();
    await bob.startUp();
    await waitForDirect(alice, bob);

    final dm = Conversation.directId(bob.id);
    await alice.controller.sendMedia(dm, _photo(fakeBytes(2100, 1)));

    final doomed = await alice.controller.createGroup('Doomed', [bob.id]);
    await alice.controller.sendMedia('gr:${doomed.id}', _photo(fakeBytes(2200, 2)));
    final forgotten = await alice.controller.createGroup('Forgotten', [bob.id]);
    await alice.controller.sendMedia('gr:${forgotten.id}', _voice(fakeBytes(2300, 3)));

    final room = await alice.controller.createRoom('Lounge');
    await alice.controller.sendMedia('rm:${room.id}', _photo(fakeBytes(2400, 4)));
    await alice.controller.sendMedia('rm:${PublicRooms.meshIdHex}', _voice(fakeBytes(2500, 5)));

    expect(filesIn(folder), hasLength(5), reason: 'one file for each of the five');

    await alice.controller.deleteConversation(dm);
    expect(filesIn(folder), hasLength(4), reason: 'the private chat\'s picture is gone');

    await alice.controller.deleteGroup(doomed.id);
    expect(filesIn(folder), hasLength(3), reason: 'the deleted group\'s picture is gone');

    await alice.controller.removeGroupFromPhone(forgotten.id);
    expect(filesIn(folder), hasLength(2), reason: 'the removed group\'s recording is gone');

    await alice.controller.leaveRoom(room.id);
    expect(filesIn(folder), hasLength(1), reason: 'the room\'s picture is gone');

    // What is left belongs to #mesh, which cannot be left, and is still readable.
    final left = await alice.controller.loadMessages('rm:${PublicRooms.meshIdHex}');
    final item = (await alice.controller.loadMedia([left.single.mediaId!])).values.single;
    expect(await alice.controller.mediaBytes(item), fakeBytes(2500, 5));
  });
}
