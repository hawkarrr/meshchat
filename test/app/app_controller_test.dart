import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:offline_mesh_chat/crypto/key_store.dart';
import 'package:offline_mesh_chat/models/conversation.dart';
import 'package:offline_mesh_chat/models/group.dart';
import 'package:offline_mesh_chat/models/message.dart';
import 'package:offline_mesh_chat/models/peer.dart';
import 'package:offline_mesh_chat/protocol/room_record.dart';
import 'package:offline_mesh_chat/services/discovery_service.dart';
import 'package:offline_mesh_chat/services/message_service.dart';
import 'package:offline_mesh_chat/transport/ble_radio.dart';

import '../support/app_harness.dart';
import '../support/fake_ble_world.dart';
import '../support/radio_harness.dart';
import '../support/test_database.dart';
import 'package:offline_mesh_chat/l10n/l10n.dart';

/// The whole application controller - what the UI talks to - on the simulated
/// BLE world: first run, finding people, messaging, being offline, relaying,
/// Bluetooth being switched off and on, identity reset, restart.
void main() {
  late FakeBleWorld world;
  final nodes = <AppNode>[];
  final tempDirs = <Directory>[];

  setUp(() {
    world = FakeBleWorld();
    nodes.clear();
    tempDirs.clear();
  });

  tearDown(() async {
    for (final n in nodes) {
      await n.dispose();
    }
    // Only once the databases are closed (Windows cannot delete open files).
    for (final d in tempDirs) {
      try {
        d.deleteSync(recursive: true);
      } on FileSystemException {
        // Best effort: it is a temp directory.
      }
    }
  });

  Future<AppNode> phone(String name, {KeyStore? keys}) async {
    final n = await AppNode.create(world, name, keys: keys);
    nodes.add(n);
    return n;
  }

  Future<ChatMessage?> messageWhere(
      AppNode n, String conversationId, bool Function(ChatMessage) test) async {
    final all = await n.controller.loadMessages(conversationId);
    return all.where(test).firstOrNull;
  }

  Future<bool> hasMessage(AppNode n, String conversationId, String body,
          {MessageStatus? status}) async =>
      (await messageWhere(
              n, conversationId, (m) => m.body == body && (status == null || m.status == status))) !=
      null;

  group('first run', () {
    test('nothing touches Bluetooth until the person chooses to start', () async {
      final a = await phone('Alice');
      expect(a.controller.onboardingDone, isFalse);
      expect(a.controller.networkingStarted, isFalse);
      expect(world.calls.where((c) => c.startsWith('Alice:')), isEmpty,
          reason: 'no plugin call may happen before onboarding');
      expect(a.phone.isAdvertising, isFalse);
      expect(a.phone.isScanning, isFalse);

      // Sensible private defaults.
      expect(a.controller.nickname, matches(RegExp(r'^Phone [0-9A-F]{4}$')));
      expect(a.controller.discoveryMode, DiscoveryMode.balanced);
      expect(a.controller.retentionDays, 0);
      expect(a.controller.fingerprintText.replaceAll(' ', ''), hasLength(64));
    });

    test('starting makes the phone visible and starts searching', () async {
      final a = await phone('Alice');
      await a.startUp();
      expect(a.controller.onboardingDone, isTrue);
      expect(a.controller.networkingStarted, isTrue);
      expect(a.controller.radioStatus.ready, isTrue);
      await eventually(() => a.phone.isAdvertising && a.controller.isAdvertising);
      await eventually(() => a.controller.discovery.scanStarts > 0);
      expect(world.violations, isEmpty, reason: world.violations.join('\n'));
    });

    test('a denied permission is explained, and granting it later starts everything', () async {
      final a = await phone('Alice');
      a.phone
        ..permissionsGranted = false
        ..userGrantsPermissions = false;
      await a.startUp();
      expect(a.controller.networkingStarted, isTrue);
      expect(a.controller.radioStatus.blocker, RadioAvailability.unauthorized);
      expect(a.phone.isAdvertising, isFalse);
      expect(a.phone.isScanning, isFalse);

      // The person fixes it in the system settings.
      a.phone.setPermissions(true);
      await eventually(() => a.controller.radioStatus.ready);
      await eventually(() => a.phone.isAdvertising);
      await eventually(() => a.controller.discovery.scanStarts > 0);
    });

    test('the permission button asks the system, and works when the answer is yes', () async {
      final a = await phone('Alice');
      a.phone
        ..permissionsGranted = false
        ..userGrantsPermissions = false;
      await a.startUp();
      expect(a.controller.radioStatus.blocker, RadioAvailability.unauthorized);

      a.phone.userGrantsPermissions = true;
      await a.controller.requestPermissions();
      await eventually(() => a.controller.radioStatus.ready);
      await eventually(() => a.phone.isAdvertising);

      a.phone.userGrantsPermissions = false;
      a.phone.setPermissions(false);
      await eventually(() => !a.controller.radioStatus.ready);
      await a.controller.openSystemSettings();
      expect(a.phone.settingsOpened, 1);
    });
  });

  group('two phones', () {
    late AppNode alice;
    late AppNode bob;

    setUp(() async {
      alice = await phone('Alice');
      bob = await phone('Bob');
      await alice.controller.setNickname('Alice');
      await bob.controller.setNickname('Bob');
      await alice.startUp();
      await bob.startUp();
      await waitForDirect(alice, bob);
    });

    test('find each other, with names, a verified link and the right encryption keys', () async {
      final seenByAlice = alice.viewOf(bob)!;
      expect(seenByAlice.peer.displayName, 'Bob');
      expect(seenByAlice.peer.canReceiveEncrypted, isTrue);
      expect(seenByAlice.status.reachability, Reachability.direct);
      expect(alice.controller.neighborCount, 1);
      expect(bob.controller.neighborCount, 1);
      expect(alice.controller.reachablePeers.map((p) => p.peer.id), [bob.id]);

      final link = alice.controller.links.single;
      expect(link.peerId, bob.id);
      expect(link.maxChunk, greaterThan(100), reason: 'MTU negotiation should have worked');
      expect(world.violations, isEmpty, reason: world.violations.join('\n'));
    });

    test('a message arrives, is acknowledged and shown as delivered', () async {
      final sent = await alice.controller.sendDirect(bob.id, 'hello Bob');
      expect(sent.status, MessageStatus.queued);

      final dm = Conversation.directId(alice.id);
      await eventually(() async => hasMessage(bob, dm, 'hello Bob', status: MessageStatus.received));
      await eventually(() async =>
          hasMessage(alice, Conversation.directId(bob.id), 'hello Bob',
              status: MessageStatus.delivered));

      // Unread bookkeeping on the receiving side.
      await eventually(() => bob.controller.totalUnread == 1);
      await eventually(() =>
          bob.controller.conversations.firstWhere((c) => c.id == dm).previewIn(englishStrings()) == 'hello Bob');
      await bob.controller.markRead(dm);
      await eventually(() => bob.controller.totalUnread == 0);

      // And back again.
      await bob.controller.sendDirect(alice.id, 'hi Alice');
      await eventually(() async =>
          hasMessage(alice, Conversation.directId(bob.id), 'hi Alice', status: MessageStatus.received));
      await eventually(() async =>
          hasMessage(bob, dm, 'hi Alice', status: MessageStatus.delivered));
    });

    test('healthy phones raise no security alarms', () async {
      // Regression: throttled announcements (an honest phone announces on every
      // new neighbour) used to be logged as "rate limited" security events.
      await alice.controller.sendDirect(bob.id, 'ping');
      await bob.controller.sendDirect(alice.id, 'pong');
      await eventually(() async =>
          hasMessage(alice, Conversation.directId(bob.id), 'ping', status: MessageStatus.delivered));
      await eventually(() async =>
          hasMessage(bob, Conversation.directId(alice.id), 'pong', status: MessageStatus.delivered));
      await Future<void>.delayed(const Duration(seconds: 1));
      expect(await alice.controller.securityEvents(), isEmpty);
      expect(await bob.controller.securityEvents(), isEmpty);
    });

    test('both people compute the same safety number; verifying is remembered', () async {
      final bobAsSeenByAlice = (await alice.controller.peer(bob.id))!;
      final aliceAsSeenByBob = (await bob.controller.peer(alice.id))!;
      final n1 = await alice.controller.safetyNumberFor(bobAsSeenByAlice);
      final n2 = await bob.controller.safetyNumberFor(aliceAsSeenByBob);
      expect(n1, isNotNull);
      expect(n1, n2, reason: 'the point of a safety number is that both phones show the same one');

      expect(bobAsSeenByAlice.verified, isFalse);
      await alice.controller.setVerified(bob.id, true);
      expect((await alice.controller.peer(bob.id))!.verified, isTrue);
    });

    test('a blocked contact cannot be messaged', () async {
      await alice.controller.setBlocked(bob.id, true);
      await expectLater(
        alice.controller.sendDirect(bob.id, 'hello?'),
        throwsA(isA<MessageError>().having((e) => e.kind, 'kind', MessageErrorKind.blocked)),
      );
      await alice.controller.setBlocked(bob.id, false);
      await alice.controller.sendDirect(bob.id, 'hello!');
    });

    test('out of range: the message waits as pending, then is delivered when they meet again',
        () async {
      world.setInRange(alice.phone, bob.phone, false);
      await eventually(() => !alice.directlyReaches(bob) && !bob.directlyReaches(alice));
      expect(alice.viewOf(bob)!.status.reachability, Reachability.offline);

      final sent = await alice.controller.sendDirect(bob.id, 'are you there?');
      final aliceChat = Conversation.directId(bob.id);
      await Future<void>.delayed(const Duration(milliseconds: 600));
      final waiting = await messageWhere(alice, aliceChat, (m) => m.id == sent.id);
      expect(waiting!.status, MessageStatus.queued, reason: 'nobody to hand it to yet');
      expect(await hasMessage(bob, Conversation.directId(alice.id), 'are you there?'), isFalse);

      world.setInRange(alice.phone, bob.phone, true);
      await waitForDirect(alice, bob, timeout: const Duration(seconds: 12));
      await eventually(
          () async => hasMessage(bob, Conversation.directId(alice.id), 'are you there?'),
          timeout: const Duration(seconds: 10));
      await eventually(
          () async => hasMessage(alice, aliceChat, 'are you there?',
              status: MessageStatus.delivered),
          timeout: const Duration(seconds: 10));
      expect(
          (await alice.controller.loadMessages(aliceChat)).where((m) => m.body == 'are you there?'),
          hasLength(1),
          reason: 'retries must not create duplicates');
      expect(
          (await bob.controller.loadMessages(Conversation.directId(alice.id)))
              .where((m) => m.body == 'are you there?'),
          hasLength(1));
    });

    test('switching Bluetooth off drops the link and switching it on reconnects by itself',
        () async {
      alice.phone.setBluetooth(false);
      await eventually(() => alice.controller.radioStatus.blocker == RadioAvailability.poweredOff);
      await eventually(() => !alice.directlyReaches(bob) && !bob.directlyReaches(alice));
      expect(alice.controller.neighborCount, 0);
      expect(alice.viewOf(bob)!.status.reachability, Reachability.offline,
          reason: 'stored history must not be shown as live reachability');

      alice.phone.setBluetooth(true);
      await eventually(() => alice.controller.radioStatus.ready);
      await waitForDirect(alice, bob, timeout: const Duration(seconds: 12));

      // And the restored link is genuinely usable.
      await alice.controller.sendDirect(bob.id, 'back again');
      await eventually(
          () async => hasMessage(bob, Conversation.directId(alice.id), 'back again'),
          timeout: const Duration(seconds: 10));
      expect(world.violations, isEmpty, reason: world.violations.join('\n'));
    });

    test('everyone shares #mesh: a post reaches the other phone with its author', () async {
      const mesh = 'rm:${PublicRooms.meshIdHex}';
      await alice.controller.sendText(mesh, 'anyone here?');
      await eventually(() async => hasMessage(bob, mesh, 'anyone here?'));
      final got = (await bob.controller.loadMessages(mesh)).single;
      expect(got.senderNickname, 'Alice');
      expect(got.senderId, alice.id);
      expect(bob.controller.rooms.first.label, '#mesh');
    });

    test('a group: invite, accept, chat, and the member list is kept on both phones', () async {
      final g = await alice.controller.createGroup('Pals', [bob.id]);
      await eventually(() => bob.controller.groups.any((x) => x.id == g.id));
      expect(bob.controller.groups.single.state, GroupState.invited);

      await bob.controller.acceptGroup(g.id);
      await alice.controller.sendText('gr:${g.id}', 'welcome');
      await eventually(() async => hasMessage(bob, 'gr:${g.id}', 'welcome'));
      await bob.controller.sendText('gr:${g.id}', 'thanks');
      await eventually(() async => hasMessage(alice, 'gr:${g.id}', 'thanks'));
      await eventually(() async =>
          hasMessage(alice, 'gr:${g.id}', 'welcome', status: MessageStatus.delivered));
      expect(alice.controller.groups.single.members.length, 2);
    });

    test('a created room is found by the other phone, which can join it', () async {
      final room = await alice.controller.createRoom('Lounge', description: 'Chill');
      await eventually(() => bob.controller.rooms.any((r) => r.id == room.id),
          timeout: const Duration(seconds: 15));
      expect(bob.controller.rooms.firstWhere((r) => r.id == room.id).joined, isFalse);
      await bob.controller.joinRoom(room.id);
      await alice.controller.sendText('rm:${room.id}', 'hi lounge');
      await eventually(() async => hasMessage(bob, 'rm:${room.id}', 'hi lounge'));
    });

    test('invalid group and room names are refused without side effects', () async {
      await expectLater(
          alice.controller.createGroup('   ', [bob.id]),
          throwsA(isA<MessageError>().having((e) => e.kind, 'kind', MessageErrorKind.invalidName)));
      await expectLater(
          alice.controller.createRoom(' # '),
          throwsA(isA<MessageError>().having((e) => e.kind, 'kind', MessageErrorKind.invalidName)));
      expect(alice.controller.groups, isEmpty);
      expect(alice.controller.rooms.map((r) => r.label), ['#mesh']);
    });

    test('resetting the identity gives new keys: the old contact sees a new person', () async {
      final oldId = alice.id;
      await alice.controller.resetIdentity();
      expect(alice.id, isNot(oldId));
      expect(alice.controller.networkingStarted, isTrue, reason: 'Bluetooth is restarted');

      // Bob meets the new identity as a separate, unverified peer.
      await eventually(
          () => bob.controller.peers.any((p) =>
              p.peer.id == alice.id && p.status.reachability == Reachability.direct),
          timeout: const Duration(seconds: 12));
      final fresh = bob.controller.peers.firstWhere((p) => p.peer.id == alice.id);
      expect(fresh.peer.verified, isFalse);
      expect(bob.controller.peers.where((p) => p.peer.id == oldId).single.status.reachability,
          Reachability.offline);
    });

    test('deleting all data wipes chats, contacts, groups and rooms but leaves a working phone',
        () async {
      await alice.controller.createRoom('Lobby');
      await alice.controller.createGroup('Pals', [bob.id]);
      await alice.controller.sendDirect(bob.id, 'something private');
      await eventually(
          () async => hasMessage(bob, Conversation.directId(alice.id), 'something private'));
      await alice.controller.setNickname('Alicia');

      final oldId = alice.id;
      await alice.controller.clearAllData();
      expect(alice.id, isNot(oldId));
      expect(alice.controller.conversations.map((c) => c.id), ['rm:${PublicRooms.meshIdHex}'],
          reason: 'only the built-in #mesh room is left');
      expect(alice.controller.groups, isEmpty);
      expect(alice.controller.rooms.map((r) => r.label), ['#mesh']);
      expect(alice.controller.nickname, startsWith('Phone '));
      expect(alice.controller.onboardingDone, isTrue,
          reason: 'the person should not have to click through the intro again');
      expect(await alice.controller.securityEvents(), isEmpty);

      // The phone still works: it meets Bob again, as a new identity.
      await eventually(
          () => bob.controller.peers.any((p) =>
              p.peer.id == alice.id && p.status.reachability == Reachability.direct),
          timeout: const Duration(seconds: 12));
    });
  });

  test('three phones in a line: a message is relayed through the middle one and acknowledged',
      () async {
    final alice = await phone('Alice');
    final bob = await phone('Bob');
    final carol = await phone('Carol');
    for (final (n, name) in [(alice, 'Alice'), (bob, 'Bob'), (carol, 'Carol')]) {
      await n.controller.setNickname(name);
    }
    world.setInRange(alice.phone, carol.phone, false);
    for (final n in nodes) {
      await n.startUp();
    }
    await eventually(() => alice.directlyReaches(bob) && bob.directlyReaches(carol),
        timeout: const Duration(seconds: 10));

    // Alice learns about Carol only through Bob's relaying of Carol's signed announcement.
    await eventually(() {
      final c = alice.viewOf(carol);
      return c != null &&
          c.status.reachability == Reachability.relayed &&
          c.peer.canReceiveEncrypted;
    }, timeout: const Duration(seconds: 12));
    expect(alice.viewOf(carol)!.status.hops, 2);
    expect(alice.viewOf(carol)!.status.viaPeerId, bob.id);
    expect(alice.controller.neighborCount, 1, reason: 'Alice is only connected to Bob');

    final sent = await alice.controller.sendDirect(carol.id, 'via Bob');
    await eventually(
        () async => hasMessage(carol, Conversation.directId(alice.id), 'via Bob',
            status: MessageStatus.received),
        timeout: const Duration(seconds: 12));
    await eventually(
        () async => (await messageWhere(
                    alice, Conversation.directId(carol.id), (m) => m.id == sent.id))
                ?.status ==
            MessageStatus.delivered,
        timeout: const Duration(seconds: 12));

    // The relay carried it but cannot read it and does not store it as a chat.
    expect(await bob.controller.loadMessages(Conversation.directId(alice.id)), isEmpty);
    expect(await bob.controller.loadMessages(Conversation.directId(carol.id)), isEmpty);
    expect(world.violations, isEmpty, reason: world.violations.join('\n'));
  });

  test('the relay phone loses Bluetooth while messages are in flight: both still arrive, no alarms',
      () async {
    final alice = await phone('Alice');
    final bob = await phone('Bob');
    final carol = await phone('Carol');
    world.setInRange(alice.phone, carol.phone, false);
    for (final n in nodes) {
      await n.startUp();
    }
    await eventually(() => alice.directlyReaches(bob) && bob.directlyReaches(carol),
        timeout: const Duration(seconds: 10));
    await eventually(() {
      final v = alice.viewOf(carol);
      return v != null && v.peer.canReceiveEncrypted && v.status.isReachable;
    }, timeout: const Duration(seconds: 12));

    final first = await alice.controller.sendDirect(carol.id, 'one');
    await Future<void>.delayed(const Duration(milliseconds: 150));
    bob.phone.setBluetooth(false);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    bob.phone.setBluetooth(true);
    final second = await alice.controller.sendDirect(carol.id, 'two');

    final chat = Conversation.directId(carol.id);
    await eventually(() async {
      final delivered = (await alice.controller.loadMessages(chat))
          .where((m) => (m.id == first.id || m.id == second.id) && m.status == MessageStatus.delivered);
      return delivered.length == 2;
    }, timeout: const Duration(seconds: 30), reason: 'both messages should be delivered');
    final received = (await carol.controller.loadMessages(Conversation.directId(alice.id)))
        .map((m) => m.body)
        .toList()
      ..sort();
    expect(received, ['one', 'two'], reason: 'each exactly once');

    await Future<void>.delayed(const Duration(milliseconds: 800));
    for (final n in nodes) {
      expect(await n.controller.securityEvents(), isEmpty, reason: '${n.name} should have no alarms');
    }
    expect(world.violations, isEmpty, reason: world.violations.join('\n'));
  });

  test('settings, identity and history survive restarting the app', () async {
    final dir = makeTempDir('mesh_restart_');
    tempDirs.add(dir);
    final dbPath = '${dir.path}${Platform.pathSeparator}app.db';
    final keys = MemoryKeyStore();

    final db1 = await openFileDatabase(dbPath);
    final first = await AppNode.create(world, 'Alice', keys: keys, db: db1);
    final firstId = first.id;
    await first.controller.setNickname('Alice ✓');
    await first.controller.setDiscoveryMode(DiscoveryMode.lowPower);
    await first.controller.setRetentionDays(7);
    await first.controller.createRoom('Lounge');
    await first.controller.completeOnboarding();
    await first.dispose();

    final db2 = await openFileDatabase(dbPath);
    final second = await AppNode.create(world, 'Alice', keys: keys, db: db2);
    nodes.add(second);
    expect(second.id, firstId, reason: 'the identity lives in the secure key store');
    expect(second.controller.nickname, 'Alice ✓');
    expect(second.controller.discoveryMode, DiscoveryMode.lowPower);
    expect(second.controller.retentionDays, 7);
    expect(second.controller.onboardingDone, isTrue);
    expect(second.controller.rooms.map((r) => r.label), containsAll(['#mesh', '#Lounge']));
    expect(second.controller.identityWasReset, isFalse);
  });

  test('an identity that vanished from secure storage is reported, not hidden', () async {
    final dir = makeTempDir('mesh_lost_identity_');
    tempDirs.add(dir);
    final dbPath = '${dir.path}${Platform.pathSeparator}app.db';

    final first = await AppNode.create(world, 'Alice',
        keys: MemoryKeyStore(), db: await openFileDatabase(dbPath));
    final oldId = first.id;
    await first.dispose();

    // Same database, but the keystore came back empty (wiped, or restored from
    // a backup that does not carry keychain items).
    final second = await AppNode.create(world, 'Alice',
        keys: MemoryKeyStore(), db: await openFileDatabase(dbPath));
    nodes.add(second);
    expect(second.id, isNot(oldId));
    expect(second.controller.identityWasReset, isTrue);
    second.controller.dismissIdentityNotice();
    expect(second.controller.identityWasReset, isFalse);
  });
}
