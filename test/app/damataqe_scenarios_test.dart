import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:offline_mesh_chat/models/conversation.dart';
import 'package:offline_mesh_chat/models/group.dart';
import 'package:offline_mesh_chat/models/media.dart';
import 'package:offline_mesh_chat/models/message.dart';
import 'package:offline_mesh_chat/models/peer.dart';
import 'package:offline_mesh_chat/protocol/room_record.dart';
import 'package:offline_mesh_chat/services/message_service.dart';
import 'package:offline_mesh_chat/services/network_status_service.dart';

import '../support/app_harness.dart';
import '../support/fake_ble_world.dart';
import '../support/message_node.dart' show fakeBytes;
import '../support/radio_harness.dart';

const _mesh = 'rm:${PublicRooms.meshIdHex}';

MediaDraft _photo(Uint8List bytes, {String caption = ''}) =>
    MediaDraft(kind: MediaKind.image, bytes: bytes, width: 640, height: 480, caption: caption);

MediaDraft _voice(Uint8List bytes) => MediaDraft(
      kind: MediaKind.voice,
      bytes: bytes,
      durationMs: 9000,
      waveform: List<int>.generate(36, (i) => (i * 7) & 0xff),
    );

bool _contains(Uint8List haystack, List<int> needle) {
  for (var i = 0; i + needle.length <= haystack.length; i++) {
    var ok = true;
    for (var j = 0; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) {
        ok = false;
        break;
      }
    }
    if (ok) return true;
  }
  return false;
}

/// The ten scenarios of the product specification, played on the simulated
/// Bluetooth world with the complete application stack on every phone (only the
/// Bluetooth plugin itself is simulated). They prove the logic; they do not
/// prove how real radios behave - that needs real phones.
void main() {
  late FakeBleWorld world;
  final nodes = <AppNode>[];

  setUp(() {
    world = FakeBleWorld();
    nodes.clear();
  });

  tearDown(() async {
    for (final n in nodes) {
      await n.dispose();
    }
  });

  Future<AppNode> phone(String name, {NetworkKind network = NetworkKind.none}) async {
    final n = await AppNode.create(world, name, network: network);
    nodes.add(n);
    await n.controller.setNickname(name);
    return n;
  }

  Future<void> startAll() async {
    for (final n in nodes) {
      await n.startUp();
    }
  }

  Future<ChatMessage?> find(AppNode n, String conversationId, bool Function(ChatMessage) test) async =>
      (await n.controller.loadMessages(conversationId)).where(test).firstOrNull;

  Future<bool> has(AppNode n, String conversationId, String body, {MessageStatus? status}) async =>
      (await find(n, conversationId, (m) => m.body == body && (status == null || m.status == status))) !=
      null;

  Future<Uint8List?> bytesOf(AppNode n, ChatMessage m) async {
    final item = (await n.controller.loadMedia([m.mediaId!]))[m.mediaId!];
    return item == null ? null : n.controller.mediaBytes(item);
  }

  /// Waits until [n] holds a completed picture/voice message in [conversationId].
  Future<ChatMessage> waitForMedia(
    AppNode n,
    String conversationId, {
    MessageKind kind = MessageKind.image,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    ChatMessage? found;
    await eventually(() async {
      for (final m in await n.controller.loadMessages(conversationId)) {
        if (m.kind != kind || m.mediaId == null) continue;
        final item = (await n.controller.loadMedia([m.mediaId!]))[m.mediaId!];
        if (item != null && item.isReady) {
          found = m;
          return true;
        }
      }
      return false;
    }, timeout: timeout, reason: '${n.name} should receive a finished $kind');
    return found!;
  }

  group('1. private chat: text, image and voice between two phones', () {
    test('everything arrives intact and is shown as delivered', () async {
      final alice = await phone('Alice');
      final bob = await phone('Bob');
      await startAll();
      await waitForDirect(alice, bob);
      final chat = Conversation.directId(bob.id);
      final photo = fakeBytes(9000, 3);
      final audio = fakeBytes(6000, 4);

      await alice.controller.sendText(chat, 'hello Bob');
      final image = await alice.controller.sendMedia(chat, _photo(photo, caption: 'my dog'));
      final voice = await alice.controller.sendMedia(chat, _voice(audio));

      await eventually(() async => has(bob, Conversation.directId(alice.id), 'hello Bob'));
      final gotImage = await waitForMedia(bob, Conversation.directId(alice.id));
      final gotVoice =
          await waitForMedia(bob, Conversation.directId(alice.id), kind: MessageKind.voice);
      expect(gotImage.body, 'my dog');
      expect(await bytesOf(bob, gotImage), photo);
      expect(await bytesOf(bob, gotVoice), audio);
      final voiceItem = (await bob.controller.loadMedia([gotVoice.mediaId!]))[gotVoice.mediaId!]!;
      expect(voiceItem.durationMs, 9000);
      expect(voiceItem.waveform.length, 36);

      await eventually(() async =>
          (await alice.controller.loadMessages(chat))
              .where((m) => [image.id, voice.id].contains(m.id))
              .every((m) => m.status == MessageStatus.delivered),
          timeout: const Duration(seconds: 20));
      expect(await alice.controller.securityEvents(), isEmpty);
      expect(await bob.controller.securityEvents(), isEmpty);
      expect(world.violations, isEmpty, reason: world.violations.join('\n'));
    });
  });

  group('2. relay: a private message and picture cross a phone that cannot read them', () {
    test('Alice -> Bob (relay) -> Carol', () async {
      final alice = await phone('Alice');
      final bob = await phone('Bob');
      final carol = await phone('Carol');
      world.setInRange(alice.phone, carol.phone, false);
      await startAll();
      await eventually(() {
        final c = alice.viewOf(carol);
        return alice.directlyReaches(bob) &&
            bob.directlyReaches(carol) &&
            c != null &&
            c.status.isReachable &&
            c.peer.canReceiveEncrypted;
      }, timeout: const Duration(seconds: 15));

      final photo = fakeBytes(8000, 6);
      await alice.controller.sendMedia(Conversation.directId(carol.id), _photo(photo));
      final got = await waitForMedia(carol, Conversation.directId(alice.id));
      expect(await bytesOf(carol, got), photo);
      expect(got.hops, 1);

      // The relay kept no chat, no file, no key.
      expect(await bob.controller.loadMessages(Conversation.directId(alice.id)), isEmpty);
      expect(await bob.controller.loadMessages(Conversation.directId(carol.id)), isEmpty);
      expect(await bob.media.list(), isEmpty);
      expect(world.violations, isEmpty, reason: world.violations.join('\n'));
    });
  });

  group('3. a group of three: text, picture and voice for everybody', () {
    test('create, invite, accept, chat, share media, see who received it', () async {
      final alice = await phone('Alice');
      final bob = await phone('Bob');
      final carol = await phone('Carol');
      await startAll();
      await eventually(() => alice.directlyReaches(bob) && alice.directlyReaches(carol) &&
          bob.directlyReaches(carol), timeout: const Duration(seconds: 15));

      final g = await alice.controller.createGroup('Friends', [bob.id, carol.id]);
      await eventually(() =>
          bob.controller.groups.any((x) => x.id == g.id) &&
          carol.controller.groups.any((x) => x.id == g.id));
      await bob.controller.acceptGroup(g.id);
      await carol.controller.acceptGroup(g.id);
      final chat = 'gr:${g.id}';

      await alice.controller.sendText(chat, 'welcome everyone');
      for (final n in [bob, carol]) {
        await eventually(() async => has(n, chat, 'welcome everyone'));
      }
      final photo = fakeBytes(7000, 8);
      final sentPhoto = await bob.controller.sendMedia(chat, _photo(photo, caption: 'view'));
      for (final n in [alice, carol]) {
        final got = await waitForMedia(n, chat);
        expect(got.senderNickname, 'Bob');
        expect(await bytesOf(n, got), photo);
      }
      final audio = fakeBytes(5000, 9);
      await carol.controller.sendMedia(chat, _voice(audio));
      for (final n in [alice, bob]) {
        final got = await waitForMedia(n, chat, kind: MessageKind.voice);
        expect(await bytesOf(n, got), audio);
      }

      // Bob's picture counts as delivered once both others have all of it.
      await eventually(() async =>
          (await find(bob, chat, (m) => m.id == sentPhoto.id))?.status == MessageStatus.delivered,
          timeout: const Duration(seconds: 20));
      final mine = (await find(bob, chat, (m) => m.id == sentPhoto.id))!;
      expect(mine.receiptCount, 2);
      expect(mine.recipientCount, 2);
      expect(world.violations, isEmpty, reason: world.violations.join('\n'));
    });
  });

  group('4. a member who was away catches up', () {
    test('missed group messages and a picture arrive when they are back in range of anyone', () async {
      final alice = await phone('Alice');
      final bob = await phone('Bob');
      final carol = await phone('Carol');
      await startAll();
      await eventually(() => alice.directlyReaches(bob) && alice.directlyReaches(carol) &&
          bob.directlyReaches(carol), timeout: const Duration(seconds: 15));
      final g = await alice.controller.createGroup('Crew', [bob.id, carol.id]);
      await eventually(() =>
          bob.controller.groups.any((x) => x.id == g.id) &&
          carol.controller.groups.any((x) => x.id == g.id));
      await bob.controller.acceptGroup(g.id);
      await carol.controller.acceptGroup(g.id);
      final chat = 'gr:${g.id}';

      // Carol wanders off.
      world.setInRange(carol.phone, alice.phone, false);
      world.setInRange(carol.phone, bob.phone, false);
      await eventually(() => !carol.directlyReaches(alice) && !carol.directlyReaches(bob));
      await alice.controller.sendText(chat, 'while you were gone');
      final photo = fakeBytes(6000, 5);
      await alice.controller.sendMedia(chat, _photo(photo));
      await eventually(() async => has(bob, chat, 'while you were gone'));
      await waitForMedia(bob, chat);
      expect(await has(carol, chat, 'while you were gone'), isFalse);

      // She comes back near Bob only.
      world.setInRange(carol.phone, bob.phone, true);
      await eventually(() async => has(carol, chat, 'while you were gone'),
          timeout: const Duration(seconds: 30));
      final got = await waitForMedia(carol, chat, timeout: const Duration(seconds: 30));
      expect(await bytesOf(carol, got), photo);
    });
  });

  group('5. a public room is discovered through a relay', () {
    test('the creator, a relay and a newcomer who only meets the relay', () async {
      final alice = await phone('Alice');
      final bob = await phone('Bob');
      final carol = await phone('Carol');
      world.setInRange(alice.phone, carol.phone, false);
      await startAll();
      await eventually(() => alice.directlyReaches(bob) && bob.directlyReaches(carol),
          timeout: const Duration(seconds: 15));

      final room = await alice.controller.createRoom('Cafe', description: 'Tables 1-9');
      await eventually(() => carol.controller.rooms.any((r) => r.id == room.id),
          timeout: const Duration(seconds: 40), reason: 'Carol never met Alice but should learn of the room');
      final seen = carol.controller.rooms.firstWhere((r) => r.id == room.id);
      expect(seen.name, 'Cafe');
      expect(seen.joined, isFalse);
      expect(seen.creatorId, alice.id);

      await carol.controller.joinRoom(room.id);
      await bob.controller.joinRoom(room.id);
      final chat = 'rm:${room.id}';
      await carol.controller.sendText(chat, 'is anyone here?');
      await eventually(() async => has(alice, chat, 'is anyone here?'),
          timeout: const Duration(seconds: 20));
      await alice.controller.sendMedia(chat, _photo(fakeBytes(4000, 2), caption: 'the menu'));
      await waitForMedia(carol, chat);
    });
  });

  group('6. public messages are shown once, whatever path they take', () {
    test('a ring of phones produces exactly one entry per phone', () async {
      final a = await phone('A');
      final b = await phone('B');
      final c = await phone('C');
      await startAll();
      await eventually(() => a.directlyReaches(b) && b.directlyReaches(c) && a.directlyReaches(c),
          timeout: const Duration(seconds: 15));
      await a.controller.sendText(_mesh, 'once only please');
      for (final n in [b, c]) {
        await eventually(() async => has(n, _mesh, 'once only please'));
      }
      await Future<void>.delayed(const Duration(seconds: 2));
      for (final n in [b, c]) {
        expect((await n.controller.loadMessages(_mesh)).where((m) => m.body == 'once only please'),
            hasLength(1));
        expect(n.controller.conversations.firstWhere((x) => x.id == _mesh).unreadCount, 1);
      }
      expect((await a.controller.loadMessages(_mesh)).where((m) => m.body == 'once only please'),
          hasLength(1));
    });
  });

  group('7. pictures and voice messages work in every mode', () {
    test('private chat, group and public room, each with both kinds, byte for byte', () async {
      final alice = await phone('Alice');
      final bob = await phone('Bob');
      final carol = await phone('Carol');
      await startAll();
      await eventually(
          () => alice.directlyReaches(bob) && alice.directlyReaches(carol) && bob.directlyReaches(carol),
          timeout: const Duration(seconds: 15));
      final photo = fakeBytes(7500, 21);
      final audio = fakeBytes(5200, 22);

      // Private: only Bob gets it.
      final privateChat = Conversation.directId(bob.id);
      await alice.controller.sendMedia(privateChat, _photo(photo, caption: 'for Bob'));
      await alice.controller.sendMedia(privateChat, _voice(audio));
      final seenByBob = Conversation.directId(alice.id);
      expect(await bytesOf(bob, await waitForMedia(bob, seenByBob)), photo);
      expect(await bytesOf(bob, await waitForMedia(bob, seenByBob, kind: MessageKind.voice)), audio);

      // Group: both members.
      final g = await alice.controller.createGroup('Trio', [bob.id, carol.id]);
      await eventually(() =>
          bob.controller.groups.any((x) => x.id == g.id) &&
          carol.controller.groups.any((x) => x.id == g.id));
      await bob.controller.acceptGroup(g.id);
      await carol.controller.acceptGroup(g.id);
      final groupChat = 'gr:${g.id}';
      await alice.controller.sendMedia(groupChat, _photo(photo, caption: 'for the trio'));
      await alice.controller.sendMedia(groupChat, _voice(audio));
      for (final n in [bob, carol]) {
        expect(await bytesOf(n, await waitForMedia(n, groupChat)), photo, reason: n.name);
        expect(await bytesOf(n, await waitForMedia(n, groupChat, kind: MessageKind.voice)), audio,
            reason: n.name);
      }

      // Public room (#mesh): everyone nearby.
      await alice.controller.sendMedia(_mesh, _photo(photo, caption: 'for everyone'));
      await alice.controller.sendMedia(_mesh, _voice(audio));
      for (final n in [bob, carol]) {
        expect(await bytesOf(n, await waitForMedia(n, _mesh)), photo, reason: n.name);
        expect(await bytesOf(n, await waitForMedia(n, _mesh, kind: MessageKind.voice)), audio,
            reason: n.name);
      }

      // Carol was never part of the private chat.
      expect(await carol.controller.loadMessages(Conversation.directId(alice.id)).then(
          (m) => m.where((x) => x.isMedia)), isEmpty);
      for (final n in [alice, bob, carol]) {
        expect(await n.controller.securityEvents(), isEmpty, reason: n.name);
      }
      expect(world.violations, isEmpty, reason: world.violations.join('\n'));
    });
  });

  group('8. a phone that is not part of a conversation cannot read it', () {
    test('a bystander in range carries traffic but ends up with nothing readable', () async {
      final alice = await phone('Alice');
      final bob = await phone('Bob');
      final eve = await phone('Eve');
      await startAll();
      await eventually(() => alice.directlyReaches(bob) && alice.directlyReaches(eve) &&
          bob.directlyReaches(eve), timeout: const Duration(seconds: 15));

      final secret = 'the-meeting-is-at-the-old-bridge';
      final g = await alice.controller.createGroup('Secret', [bob.id]);
      await eventually(() => bob.controller.groups.any((x) => x.id == g.id));
      await bob.controller.acceptGroup(g.id);
      await alice.controller.sendText('gr:${g.id}', secret);
      await alice.controller.sendText(Conversation.directId(bob.id), '$secret (private)');
      final photo = fakeBytes(5000, 7);
      await alice.controller.sendMedia('gr:${g.id}', _photo(photo));
      await alice.controller.sendMedia(Conversation.directId(bob.id), _photo(fakeBytes(3000, 1)));
      await eventually(() async => has(bob, 'gr:${g.id}', secret));
      await waitForMedia(bob, 'gr:${g.id}');
      await waitForMedia(bob, Conversation.directId(alice.id));
      await Future<void>.delayed(const Duration(seconds: 1));

      // Eve has no chat, group, file or key for any of it...
      expect(eve.controller.groups, isEmpty);
      expect(eve.controller.conversations.map((c) => c.id), [_mesh]);
      expect(await eve.controller.loadMessages(_mesh), isEmpty);
      expect(await eve.media.list(), isEmpty);
      // ...and nothing she was handed to carry contains the words or the picture.
      final probe = photo.sublist(1000, 1032);
      for (final e in await eve.controller.outbox.all()) {
        expect(_contains(e.packet, probe), isFalse);
        expect(String.fromCharCodes(e.packet), isNot(contains(secret)));
      }
      expect(await eve.controller.securityEvents(), isEmpty);
    });

    test('a member removed from a group reads nothing sent afterwards', () async {
      final alice = await phone('Alice');
      final bob = await phone('Bob');
      final carol = await phone('Carol');
      await startAll();
      await eventually(() => alice.directlyReaches(bob) && alice.directlyReaches(carol) &&
          bob.directlyReaches(carol), timeout: const Duration(seconds: 15));
      final g = await alice.controller.createGroup('Club', [bob.id, carol.id]);
      await eventually(() =>
          bob.controller.groups.any((x) => x.id == g.id) &&
          carol.controller.groups.any((x) => x.id == g.id));
      await bob.controller.acceptGroup(g.id);
      await carol.controller.acceptGroup(g.id);
      final chat = 'gr:${g.id}';

      await alice.controller.removeGroupMember(g.id, carol.id);
      await eventually(() => carol.controller.groups.single.state == GroupState.removed);
      await eventually(() => bob.controller.groups.single.epoch == 1);
      await alice.controller.sendText(chat, 'only for the two of us');
      await eventually(() async => has(bob, chat, 'only for the two of us'));
      await Future<void>.delayed(const Duration(seconds: 1));
      expect(await has(carol, chat, 'only for the two of us'), isFalse);
    });
  });

  group('9. the relay drops out during a picture transfer', () {
    test('Bluetooth off and on at the middle phone: the picture still arrives complete', () async {
      final alice = await phone('Alice');
      final bob = await phone('Bob');
      final carol = await phone('Carol');
      world.setInRange(alice.phone, carol.phone, false);
      await startAll();
      await eventually(() {
        final c = alice.viewOf(carol);
        return alice.directlyReaches(bob) &&
            bob.directlyReaches(carol) &&
            c != null &&
            c.status.isReachable &&
            c.peer.canReceiveEncrypted;
      }, timeout: const Duration(seconds: 15));

      final photo = fakeBytes(12000, 11);
      final sent = await alice.controller.sendMedia(Conversation.directId(carol.id), _photo(photo));
      await Future<void>.delayed(const Duration(milliseconds: 120));
      bob.phone.setBluetooth(false);
      await Future<void>.delayed(const Duration(milliseconds: 600));
      bob.phone.setBluetooth(true);

      final got = await waitForMedia(carol, Conversation.directId(alice.id),
          timeout: const Duration(seconds: 60));
      expect(await bytesOf(carol, got), photo);
      await eventually(() async =>
          (await find(alice, Conversation.directId(carol.id), (m) => m.id == sent.id))?.status ==
          MessageStatus.delivered,
          timeout: const Duration(seconds: 60));
      expect(world.violations, isEmpty, reason: world.violations.join('\n'));
    });
  });

  group('10. fully offline', () {
    test('with no internet at all, everything above still works', () async {
      final alice = await phone('Alice', network: NetworkKind.none);
      final bob = await phone('Bob', network: NetworkKind.none);
      await startAll();
      await waitForDirect(alice, bob);
      expect(await alice.controller.networkKind(), NetworkKind.none);
      expect(await bob.controller.networkKind(), NetworkKind.none);

      await alice.controller.sendText(Conversation.directId(bob.id), 'no signal, no problem');
      await eventually(() async => has(bob, Conversation.directId(alice.id), 'no signal, no problem'));
      await alice.controller.sendText(_mesh, 'offline in public too');
      await eventually(() async => has(bob, _mesh, 'offline in public too'));
      final g = await alice.controller.createGroup('Offline', [bob.id]);
      await eventually(() => bob.controller.groups.any((x) => x.id == g.id));
    });
  });

  group('peers keep their roles', () {
    test('a person in a group is not automatically a contact', () async {
      final alice = await phone('Alice');
      final bob = await phone('Bob');
      await startAll();
      await waitForDirect(alice, bob);
      final g = await alice.controller.createGroup('Pair', [bob.id]);
      await eventually(() => bob.controller.groups.any((x) => x.id == g.id));
      expect((await bob.controller.peer(alice.id))!.isContact, isFalse);
      expect(bob.viewOf(alice)!.status.reachability, Reachability.direct);
    });
  });
}
