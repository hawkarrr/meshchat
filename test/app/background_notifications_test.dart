import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:offline_mesh_chat/crypto/key_store.dart';
import 'package:offline_mesh_chat/device/device_io.dart';
import 'package:offline_mesh_chat/models/conversation.dart';
import 'package:offline_mesh_chat/models/message.dart';
import 'package:offline_mesh_chat/protocol/room_record.dart';
import 'package:offline_mesh_chat/services/notification_coordinator.dart';

import '../support/app_harness.dart';
import '../support/fake_ble_world.dart';
import '../support/fake_device.dart';
import '../support/radio_harness.dart';
import '../support/test_database.dart';

/// The controller's notification, relay and background behaviour, on two
/// simulated phones: when a message becomes a notification, what the settings
/// remember, what a tapped notification does.
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
    for (final d in tempDirs) {
      try {
        d.deleteSync(recursive: true);
      } on FileSystemException {
        // A temp directory: best effort.
      }
    }
  });

  Future<AppNode> phone(
    String name, {
    FakeNotificationSink? sink,
    FakeKeepAlive? keepAlive,
    FakePermissionService? permissions,
  }) async {
    final io = fakeDeviceIo(
      notifications: sink,
      keepAlive: keepAlive,
      permissions: permissions ??
          FakePermissionService(initial: {AppPermission.notifications: PermissionOutcome.granted}),
    );
    final n = await AppNode.create(world, name, io: io);
    await n.controller.setNickname(name);
    nodes.add(n);
    return n;
  }

  /// Alice (who is being notified) and Bob, in range of each other and knowing
  /// each other's keys.
  Future<(AppNode, AppNode, FakeNotificationSink)> pair() async {
    final sink = FakeNotificationSink();
    final alice = await phone('Alice', sink: sink);
    final bob = await phone('Bob');
    await alice.startUp();
    await bob.startUp();
    await waitForDirect(alice, bob, timeout: const Duration(seconds: 15));
    await eventually(() => alice.viewOf(bob)?.peer.canReceiveEncrypted ?? false,
        timeout: const Duration(seconds: 15));
    await eventually(() => bob.viewOf(alice)?.peer.canReceiveEncrypted ?? false,
        timeout: const Duration(seconds: 15));
    return (alice, bob, sink);
  }

  group('defaults and memory', () {
    test('notifications are on, show only the name, and stay quiet about public rooms; the mesh '
        'relays; nothing runs in the background', () async {
      final a = await phone('Alice');
      final c = a.controller;
      expect(c.notificationsEnabled, isTrue);
      expect(c.notificationPrivacy, NotificationPrivacy.sender);
      expect(c.notifyPublicRooms, isFalse);
      expect(c.relayEnabled, isTrue);
      expect(c.keepAliveEnabled, isFalse);
      expect((a.io.notifications as FakeNotificationSink).initialized, isTrue);
    });

    test('every choice survives restarting the app', () async {
      final dir = makeTempDir('mesh_settings_');
      tempDirs.add(dir);
      final dbPath = '${dir.path}${Platform.pathSeparator}app.db';
      final keys = MemoryKeyStore();

      final first = await AppNode.create(world, 'Alice', keys: keys, db: await openFileDatabase(dbPath));
      await first.controller.setNotificationsEnabled(false);
      await first.controller.setNotificationPrivacy(NotificationPrivacy.hidden);
      await first.controller.setNotifyPublicRooms(true);
      await first.controller.setRelayEnabled(false);
      await first.controller.setKeepAlive(true);
      await first.dispose();

      final second = await AppNode.create(world, 'Alice', keys: keys, db: await openFileDatabase(dbPath));
      nodes.add(second);
      final c = second.controller;
      expect(c.notificationsEnabled, isFalse);
      expect(c.notificationPrivacy, NotificationPrivacy.hidden);
      expect(c.notifyPublicRooms, isTrue);
      expect(c.relayEnabled, isFalse);
      expect(c.keepAliveEnabled, isTrue);
      expect(c.router.relayForOthers, isFalse, reason: 'the router follows the setting from the start');
    });

    test('"delete all data" puts every choice back to its default', () async {
      final a = await phone('Alice');
      await a.controller.setNotifyPublicRooms(true);
      await a.controller.setRelayEnabled(false);
      await a.controller.setNotificationPrivacy(NotificationPrivacy.full);
      await a.controller.clearAllData();
      expect(a.controller.notifyPublicRooms, isFalse);
      expect(a.controller.relayEnabled, isTrue);
      expect(a.controller.router.relayForOthers, isTrue);
      expect(a.controller.notificationPrivacy, NotificationPrivacy.sender);
    });
  });

  group('relaying', () {
    test('the switch reaches the router', () async {
      final a = await phone('Alice');
      await a.controller.setRelayEnabled(false);
      expect(a.controller.router.relayForOthers, isFalse);
      await a.controller.setRelayEnabled(true);
      expect(a.controller.router.relayForOthers, isTrue);
    });
  });

  group('the background service', () {
    test('turning it on starts it, off stops it, and the choice is kept', () async {
      final keep = FakeKeepAlive();
      final a = await phone('Alice', keepAlive: keep);
      expect(a.controller.keepAliveSupported, isTrue);
      expect(await a.controller.setKeepAlive(true), isTrue);
      expect(keep.running, isTrue);
      expect(a.controller.keepAliveEnabled, isTrue);
      expect(await a.controller.setKeepAlive(false), isTrue);
      expect(keep.running, isFalse);
      expect(a.controller.keepAliveEnabled, isFalse);
    });

    test('if the system refuses, the switch does not pretend', () async {
      final keep = FakeKeepAlive(allow: false);
      final a = await phone('Alice', keepAlive: keep);
      expect(await a.controller.setKeepAlive(true), isFalse);
      expect(a.controller.keepAliveEnabled, isFalse);
    });

    test('if it cannot be started again later (back on screen), the switch goes off and nothing '
        'is left running', () async {
      final keep = FakeKeepAlive();
      final a = await phone('Alice', keepAlive: keep);
      await a.controller.setKeepAlive(true);
      await a.startUp();
      await eventually(() => keep.running);

      keep.allow = false; // e.g. the Bluetooth permission was taken away meanwhile
      a.controller.setForeground(false);
      a.controller.setForeground(true);
      await eventually(() => !a.controller.keepAliveEnabled);
      expect(keep.running, isFalse);
      expect(await a.controller.repo.getSetting('keep_alive'), '0',
          reason: 'the next start does not claim it either');
    });

    test('a phone that cannot do it says so', () async {
      final a = await phone('Alice', keepAlive: FakeKeepAlive(supported: false));
      expect(a.controller.keepAliveSupported, isFalse);
    });

    test('it runs while Bluetooth runs and stops when Bluetooth stops', () async {
      final keep = FakeKeepAlive();
      final a = await phone('Alice', keepAlive: keep);
      await a.controller.setKeepAlive(true);
      keep.stops = 0;
      await a.startUp();
      await eventually(() => keep.running);
      await a.controller.stopNetworking();
      await eventually(() => !keep.running);
    });
  });

  group('notifications from real messages', () {
    test('a message that arrives while the app is away becomes a notification with the name only',
        () async {
      final (alice, bob, sink) = await pair();
      alice.controller.setForeground(false);

      await bob.controller.sendDirect(alice.id, 'see you at ten');
      await eventually(() => sink.shown.isNotEmpty, reason: 'Alice is notified');

      final n = sink.shown.single;
      expect(n.conversationId, Conversation.directId(bob.id));
      expect(n.title, 'Bob');
      expect(n.body, 'New message');
      expect('${n.title} ${n.body}', isNot(contains('ten')), reason: 'the text stays off the lock screen');
    });

    test('with the app on screen there is no notification, only the unread count', () async {
      final (alice, bob, sink) = await pair();
      await bob.controller.sendDirect(alice.id, 'hello');
      await eventually(() => alice.controller.totalUnread == 1);
      expect(sink.shown, isEmpty);
    });

    test('the choice of what to show is honoured', () async {
      final (alice, bob, sink) = await pair();
      alice.controller.setForeground(false);
      await alice.controller.setNotificationPrivacy(NotificationPrivacy.full);
      await bob.controller.sendDirect(alice.id, 'the full words');
      await eventually(() => sink.shown.isNotEmpty);
      expect(sink.shown.single.body, 'the full words');

      sink.shown.clear();
      await alice.controller.setNotificationPrivacy(NotificationPrivacy.hidden);
      await bob.controller.sendDirect(alice.id, 'secret words');
      await eventually(() => sink.shown.isNotEmpty);
      expect('${sink.shown.single.title} ${sink.shown.single.body}', isNot(contains('Bob')));
      expect('${sink.shown.single.title} ${sink.shown.single.body}', isNot(contains('secret')));
    });

    test('switched off: nothing, even while the app is away', () async {
      final (alice, bob, sink) = await pair();
      alice.controller.setForeground(false);
      await alice.controller.setNotificationsEnabled(false);
      await bob.controller.sendDirect(alice.id, 'quiet please');
      await eventually(() => alice.controller.totalUnread == 1);
      expect(sink.shown, isEmpty);
    });

    test('a public room is silent unless asked for', () async {
      final (alice, bob, sink) = await pair();
      alice.controller.setForeground(false);
      final mesh = 'rm:${PublicRooms.meshIdHex}';

      await bob.controller.sendText(mesh, 'anyone near?');
      await eventually(() => alice.controller.totalUnread == 1, reason: 'it arrived');
      expect(sink.shown, isEmpty);

      await alice.controller.setNotifyPublicRooms(true);
      await bob.controller.sendText(mesh, 'hello again');
      await eventually(() => sink.shown.isNotEmpty);
      expect(sink.shown.single.title, '#mesh');
    });

    test('reading the chat takes its notification away', () async {
      final (alice, bob, sink) = await pair();
      alice.controller.setForeground(false);
      await bob.controller.sendDirect(alice.id, 'one');
      await eventually(() => sink.shown.isNotEmpty);

      await alice.controller.markRead(Conversation.directId(bob.id));
      expect(sink.cancelled, contains(Conversation.directId(bob.id)));
    });

    test('coming back to the app clears the notifications', () async {
      final (alice, bob, sink) = await pair();
      alice.controller.setForeground(false);
      await bob.controller.sendDirect(alice.id, 'one');
      await eventually(() => sink.shown.isNotEmpty);
      alice.controller.setForeground(true);
      await eventually(() => sink.cancelledAll > 0);
    });

    test('a notification goes when its message is deleted for everyone', () async {
      final (alice, bob, sink) = await pair();
      alice.controller.setForeground(false);
      final sent = await bob.controller.sendDirect(alice.id, 'to be deleted');
      await eventually(() => sink.shown.isNotEmpty);

      await bob.controller.deleteForEveryone(Conversation.directId(alice.id), [sent.id]);
      await eventually(() => sink.cancelled.contains(Conversation.directId(bob.id)),
          reason: 'the notification may have quoted what is now deleted');
    });

    test('a public message that expires takes its notification with it, and coming back to '
        'the app removes what ran out of time while it was away', () async {
      final (alice, _, sink) = await pair();
      await alice.controller.setNotifyPublicRooms(true);
      final mesh = 'rm:${PublicRooms.meshIdHex}';
      final old = DateTime.now().millisecondsSinceEpoch - const Duration(hours: 7).inMilliseconds;
      await alice.controller.repo.insertMessage(ChatMessage(
        id: 'ab' * 16,
        conversationId: mesh,
        senderId: 'cd' * 32,
        senderNickname: 'Zed',
        isOutgoing: false,
        body: 'old news',
        sortTimeMs: old,
        claimedTimestampMs: old,
        status: MessageStatus.received,
      ));
      expect(await alice.controller.loadMessages(mesh), hasLength(1));

      alice.controller.setForeground(false);
      alice.controller.setForeground(true);
      await eventually(() async => (await alice.controller.loadMessages(mesh)).isEmpty,
          reason: 'the overdue public message is gone as soon as the app is back');
      expect(sink.shown, isEmpty);
    });

    test('without the system permission nothing is shown and nothing is asked', () async {
      final sink = FakeNotificationSink();
      final perms = FakePermissionService(); // everything denied
      final alice = await phone('Alice', sink: sink, permissions: perms);
      final bob = await phone('Bob');
      await alice.startUp();
      await bob.startUp();
      await waitForDirect(alice, bob, timeout: const Duration(seconds: 15));
      await eventually(() => alice.viewOf(bob)?.peer.canReceiveEncrypted ?? false,
          timeout: const Duration(seconds: 15));
      await eventually(() => bob.viewOf(alice)?.peer.canReceiveEncrypted ?? false,
          timeout: const Duration(seconds: 15));
      alice.controller.setForeground(false);

      await bob.controller.sendDirect(alice.id, 'hello?');
      await eventually(() => alice.controller.totalUnread == 1);
      expect(sink.shown, isEmpty);
      expect(perms.requested, isEmpty);
    });

    test('a phone that only relays a message never notifies about it', () async {
      final sinkRelay = FakeNotificationSink();
      final alice = await phone('Alice');
      final relay = await phone('Relay', sink: sinkRelay);
      final carol = await phone('Carol');
      for (final n in [alice, relay, carol]) {
        await n.startUp();
      }
      world.setInRange(alice.phone, carol.phone, false);
      await waitForDirect(alice, relay, timeout: const Duration(seconds: 15));
      await waitForDirect(relay, carol, timeout: const Duration(seconds: 15));
      await eventually(() => alice.viewOf(carol)?.peer.canReceiveEncrypted ?? false,
          timeout: const Duration(seconds: 20), reason: 'Alice learns Carol through the relay');
      relay.controller.setForeground(false);

      await alice.controller.sendDirect(carol.id, 'for Carol only');
      await eventually(() => carol.controller.totalUnread == 1, timeout: const Duration(seconds: 15));
      expect(sinkRelay.shown, isEmpty);
      expect(relay.controller.totalUnread, 0);
    });
  });

  group('coming back to the app', () {
    test('cleaning up the public rooms in the background never throws, even if it fails', () async {
      final alice = await phone('Alice');
      await alice.startUp();
      alice.controller.setForeground(false);
      // Every database call fails from here on, as it would in a phone that is shutting down.
      await alice.db.close();
      alice.controller.setForeground(true);
      // If the failure escaped, the test framework reports it as an uncaught error.
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
  });

  group('tapping a notification', () {
    test('asks for that conversation to be opened', () async {
      final sink = FakeNotificationSink();
      final alice = await phone('Alice', sink: sink);
      expect(alice.controller.openRequest.value, isNull);
      sink.tap('dm:abcd');
      expect(alice.controller.openRequest.value, 'dm:abcd');
    });

    test('so does a notification that started the app', () async {
      final sink = FakeNotificationSink()..launch = 'gr:trip';
      final alice = await phone('Alice', sink: sink);
      expect(alice.controller.openRequest.value, 'gr:trip');
    });
  });
}
