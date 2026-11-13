import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_mesh_chat/device/device_io.dart';
import 'package:offline_mesh_chat/models/conversation.dart';
import 'package:offline_mesh_chat/models/media.dart' show MediaKind;
import 'package:offline_mesh_chat/protocol/link_frame.dart' show LinkFrameType;
import 'package:offline_mesh_chat/protocol/protocol_constants.dart';
import 'package:offline_mesh_chat/screens/chat_screen.dart';
import 'package:offline_mesh_chat/screens/storage_screen.dart';
import 'package:offline_mesh_chat/services/media_service.dart' show MediaDraft;
import 'package:offline_mesh_chat/services/notification_coordinator.dart';
import 'package:offline_mesh_chat/widgets/setting_switch.dart';

import '../support/app_harness.dart';
import '../support/ble_stack.dart' show RogueDevice;
import '../support/fake_device.dart';
import '../support/message_node.dart' show fakeBytes;
import '../support/ui_harness.dart';

/// A page of the settings: `notifications`, `privacy`, `chat`...
Future<void> _openSettings(UiHarness h, String page) => h.openSettingsPage(page);

bool _on(WidgetTester tester, String key) =>
    tester.widget<SettingSwitch>(find.byKey(Key(key))).value;

void main() {
  group('notifications', () {
    testWidgets('on by default; choose what they show; off hides the options; on again asks first',
        (tester) async {
      final h = UiHarness(tester)..screen();
      final alice = await h.node('Alice', onboarded: true, nickname: 'Alice');
      await h.show(alice);
      await _openSettings(h, 'notifications');

      await h.reveal(find.byKey(const Key('notify-switch')));
      expect(_on(tester, 'notify-switch'), isTrue);
      expect(find.text('Name only'), findsOneWidget, reason: 'the default shows the name, not the text');
      expect(find.textContaining('Shows who wrote, not what'), findsOneWidget);

      await h.tap(find.byKey(const Key('notify-privacy')));
      await h.tap(find.text('Name and message').last);
      await h.until(() => alice.controller.notificationPrivacy == NotificationPrivacy.full);
      expect(find.textContaining('lock screen can read it'), findsOneWidget,
          reason: 'the cost of this choice is said out loud');

      await h.reveal(find.byKey(const Key('notify-public')));
      expect(_on(tester, 'notify-public'), isFalse);
      await h.tap(find.byKey(const Key('notify-public')));
      await h.until(() => alice.controller.notifyPublicRooms);

      await h.reveal(find.byKey(const Key('notify-switch')));
      await h.tap(find.byKey(const Key('notify-switch')));
      await h.until(() => !alice.controller.notificationsEnabled);
      expect(find.byKey(const Key('notify-privacy')), findsNothing, reason: 'nothing to choose when off');

      // Turning them on again explains first, then asks the system.
      final perms = h.permissionsOf(alice);
      expect(perms.requested, isEmpty);
      await h.tap(find.byKey(const Key('notify-switch')));
      await h.until(() => find.text('Allow notifications?').evaluate().isNotEmpty);
      expect(find.textContaining('nothing is sent to any server'), findsOneWidget);
      await h.tap(find.byKey(const Key('permission-continue')));
      expect(perms.requested, [AppPermission.notifications]);
      await h.until(() => alice.controller.notificationsEnabled);

      expect(tester.takeException(), isNull);
      await h.dispose();
    });

    testWidgets('on here but not allowed by the phone: the page says so, and the button fixes it',
        (tester) async {
      final h = UiHarness(tester)..screen();
      final alice = await h.node('Alice', onboarded: true, nickname: 'Alice');
      await h.show(alice);
      await _openSettings(h, 'notifications');
      await h.reveal(find.byKey(const Key('notify-switch')));

      expect(find.byKey(const Key('notify-not-allowed')), findsOneWidget,
          reason: 'the phone has not allowed notifications, so none would ever appear');
      expect(find.textContaining('has not allowed them yet'), findsOneWidget);

      await h.tap(find.byKey(const Key('notify-allow')));
      await h.until(() => find.text('Allow notifications?').evaluate().isNotEmpty,
          reason: 'it explains first, like every other permission');
      await h.tap(find.byKey(const Key('permission-continue')));
      await h.until(() => find.byKey(const Key('notify-not-allowed')).evaluate().isEmpty,
          reason: 'allowed: nothing left to say');
      expect(h.permissionsOf(alice).requested, [AppPermission.notifications]);
      await h.dispose();
    });

    testWidgets('it is not there when notifications are off, or when the phone has allowed them',
        (tester) async {
      final h = UiHarness(tester)..screen();
      final alice = await h.node('Alice', onboarded: true, nickname: 'Alice');
      h.permissionsOf(alice).set(AppPermission.notifications, PermissionOutcome.granted);
      await h.show(alice);
      await _openSettings(h, 'notifications');
      await h.reveal(find.byKey(const Key('notify-switch')));
      expect(find.byKey(const Key('notify-not-allowed')), findsNothing, reason: 'allowed');

      h.permissionsOf(alice).set(AppPermission.notifications, PermissionOutcome.denied);
      await h.tap(find.byKey(const Key('notify-switch')));
      await h.until(() => !alice.controller.notificationsEnabled);
      expect(find.byKey(const Key('notify-not-allowed')), findsNothing, reason: 'switched off here');
      await h.dispose();
    });

    testWidgets('the permission list shows the notification permission with its state',
        (tester) async {
      final h = UiHarness(tester)..screen();
      final alice = await h.node('Alice', onboarded: true, nickname: 'Alice');
      await h.show(alice);
      await _openSettings(h, 'privacy');
      await h.reveal(find.byKey(const Key('permission-notifications')));
      expect(find.byKey(const Key('allow-notifications')), findsOneWidget, reason: 'not allowed yet');
      h.permissionsOf(alice).set(AppPermission.notifications, PermissionOutcome.granted);
      await h.tap(find.byKey(const Key('allow-notifications')));
      await h.until(() => find.byKey(const Key('allow-notifications')).evaluate().isEmpty);
      await h.dispose();
    });

    testWidgets('tapping a notification opens that chat', (tester) async {
      final h = UiHarness(tester)..screen();
      final alice = await h.node('Alice', onboarded: true, nickname: 'Alice');
      final bob = await h.node('Bob', onboarded: true, nickname: 'Bob');
      await h.show(alice);
      await h.until(
          () => alice.directlyReaches(bob) && (alice.viewOf(bob)?.peer.canReceiveEncrypted ?? false));
      await h.real(() => alice.controller.openChat(bob.id));
      expect(find.byType(ChatScreen), findsNothing);

      h.notificationsOf(alice).tap(Conversation.directId(bob.id));
      await h.until(() => find.byType(ChatScreen).evaluate().isNotEmpty,
          reason: 'the home screen opens the conversation');
      expect(alice.controller.openRequest.value, isNull, reason: 'the request was consumed');
      await h.dispose();
    });
  });

  group('the mesh in the background', () {
    testWidgets('relaying can be switched off, and the page says what that costs', (tester) async {
      final h = UiHarness(tester)..screen();
      final alice = await h.node('Alice', onboarded: true, nickname: 'Alice');
      await h.show(alice);
      await _openSettings(h, 'chat');
      await h.reveal(find.byKey(const Key('relay-switch')));
      expect(_on(tester, 'relay-switch'), isTrue);
      expect(find.textContaining('makes the mesh reach further'), findsOneWidget);
      expect(find.byKey(const Key('relay-activity')), findsOneWidget);
      expect(find.textContaining('Since the app started: passed on 0 packets for others'), findsOneWidget,
          reason: 'relaying is never hidden: the page says what it has done');

      await h.tap(find.byKey(const Key('relay-switch')));
      await h.until(() => !alice.controller.relayEnabled);
      expect(alice.controller.router.relayForOthers, isFalse);
      expect(find.textContaining('passes nothing on for anybody else'), findsOneWidget);
      expect(find.textContaining('will not get through'), findsOneWidget);
      await h.dispose();
    });

    testWidgets('the background service starts and stops, and an Android refusal is reported',
        (tester) async {
      final h = UiHarness(tester)..screen();
      final alice = await h.node('Alice', onboarded: true, nickname: 'Alice');
      await h.show(alice);
      await _openSettings(h, 'chat');
      final keep = h.keepAliveOf(alice);

      await h.reveal(find.byKey(const Key('keepalive-switch')));
      expect(_on(tester, 'keepalive-switch'), isFalse);
      expect(find.textContaining('has not been tested on real phones yet'), findsOneWidget);
      await h.tap(find.byKey(const Key('keepalive-switch')));
      await h.until(() => alice.controller.keepAliveEnabled);
      expect(keep.running, isTrue);
      await h.tap(find.byKey(const Key('keepalive-switch')));
      await h.until(() => !alice.controller.keepAliveEnabled);
      expect(keep.running, isFalse);

      keep.allow = false;
      await h.tap(find.byKey(const Key('keepalive-switch')));
      await h.until(() => find.textContaining('did not allow it right now').evaluate().isNotEmpty);
      expect(_on(tester, 'keepalive-switch'), isFalse, reason: 'the switch does not claim it is on');
      await h.dispose();
    });

    testWidgets('battery restrictions: the page says they are on, opens the phone\'s page, and '
        'shows the new state on coming back', (tester) async {
      final h = UiHarness(tester)..screen();
      final alice = await h.node('Alice', onboarded: true, nickname: 'Alice');
      final keep = h.keepAliveOf(alice);
      await h.show(alice);
      await _openSettings(h, 'chat');

      await h.reveal(find.byKey(const Key('battery-hint')));
      expect(find.text('Battery restrictions'), findsOneWidget);
      expect(find.textContaining('may stop دەمەتەقێ in the background'), findsOneWidget);

      await h.tap(find.byKey(const Key('battery-open')));
      expect(keep.batterySettingsOpened, 1);

      keep.canOpenBatterySettings = false;
      await h.tap(find.byKey(const Key('battery-open')));
      await h.until(() => find.textContaining('did not open its battery settings').evaluate().isNotEmpty);
      expect(keep.batterySettingsOpened, 1);

      // The person chose "Unrestricted" there and comes back.
      keep.batteryRestrictedAnswer = false;
      for (final s in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(s);
      }
      await h.until(() => find.textContaining('without battery restrictions').evaluate().isNotEmpty);
      expect(find.byKey(const Key('battery-open')), findsNothing, reason: 'nothing left to fix');
      await h.dispose();
    });

    testWidgets('a phone that would not say anything about its battery gets no row', (tester) async {
      final h = UiHarness(tester)..screen();
      final alice = await h.node('Alice', onboarded: true, nickname: 'Alice');
      h.keepAliveOf(alice).batteryRestrictedAnswer = null;
      await h.show(alice);
      await _openSettings(h, 'chat');
      await h.reveal(find.byKey(const Key('keepalive-switch')));
      expect(find.byKey(const Key('battery-hint')), findsNothing);
      await h.dispose();
    });

    testWidgets('a phone that cannot keep running in the background says so plainly',
        (tester) async {
      final h = UiHarness(tester)..screen();
      final io = fakeDeviceIo(keepAlive: FakeKeepAlive(supported: false));
      final made = await tester.runAsync(() async {
        final n = await AppNode.create(h.world, 'Alice', io: io);
        await n.controller.setNickname('Alice');
        await n.startUp();
        return n;
      });
      final alice = made!;
      h.nodes.add(alice);
      await h.show(alice);
      await _openSettings(h, 'chat');
      await h.reveal(find.byKey(const Key('keepalive-unsupported')));
      expect(find.byKey(const Key('keepalive-switch')), findsNothing);
      expect(find.textContaining('suspends the app soon after you lock it'), findsOneWidget);
      await h.dispose();
    });
  });

  group('another version of the app nearby', () {
    testWidgets('an older phone that is turned away is mentioned until dismissed', (tester) async {
      final h = UiHarness(tester)..screen();
      final alice = await h.node('Alice', onboarded: true, nickname: 'Alice');
      await h.show(alice);
      expect(find.byKey(const Key('version-older')), findsNothing);

      // A phone with an older app: it advertises like any other, and once Alice
      // connects, its HELLO carries an older protocol version.
      final old = (await tester.runAsync(() => RogueDevice.create(h.world, 'Old')))!;
      addTearDown(() => tester.runAsync(old.dispose));
      await h.until(() => old.links.isNotEmpty, reason: 'Alice finds the phone and connects');
      await h.real(() => old.sendBytes(old.links.first, [LinkFrameType.hello.code, Protocol.version - 1, 0]));

      await h.until(() => find.byKey(const Key('version-older')).evaluate().isNotEmpty);
      expect(find.text('A phone nearby needs an update'), findsOneWidget);
      expect(find.byKey(const Key('version-newer')), findsNothing);
      expect(alice.controller.networkListenable.value.olderVersionNearby, isTrue);

      await h.tap(find.descendant(
          of: find.byKey(const Key('version-older')), matching: find.text('Dismiss')));
      await h.until(() => find.byKey(const Key('version-older')).evaluate().isEmpty);
      await h.dispose();
    });
  });

  group('storage', () {
    testWidgets('shows what is kept, cleans public chats and deletes all media', (tester) async {
      final h = UiHarness(tester)..screen();
      final alice = await h.node('Alice', onboarded: true, nickname: 'Alice');
      final bob = await h.node('Bob', onboarded: true, nickname: 'Bob');
      await h.show(alice);
      await h.until(
          () => alice.directlyReaches(bob) && (alice.viewOf(bob)?.peer.canReceiveEncrypted ?? false));
      final chat = Conversation.directId(bob.id);
      await h.real(() async {
        await alice.controller.sendText(chat, 'a text message');
        await alice.controller.sendMedia(
          chat,
          MediaDraft(
              kind: MediaKind.voice,
              bytes: fakeBytes(3000),
              durationMs: 2000,
              waveform: List<int>.filled(40, 80)),
        );
      });

      await _openSettings(h, 'privacy');
      await h.tap(find.byKey(const Key('open-storage')));
      await h.until(() => find.byType(StorageScreen).evaluate().isNotEmpty);
      await h.loaded();

      expect(find.descendant(of: find.byKey(const Key('storage-messages')), matching: find.text('2')),
          findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('storage-media')), matching: find.text('1 file')),
          findsOneWidget);
      expect(find.textContaining('six hours after they arrive'), findsOneWidget);
      expect(find.textContaining('Nothing has been removed yet'), findsOneWidget);

      await h.tap(find.byKey(const Key('storage-clean-public')));
      await h.until(() => find.textContaining('Nothing to clean').evaluate().isNotEmpty);

      await h.tap(find.byKey(const Key('storage-delete-media')));
      expect(find.text('Delete all pictures, voice messages and videos?'), findsOneWidget);
      await h.tap(find.byKey(const Key('confirm-action')));
      await h.until(() => find.textContaining('Deleted 1 message with files').evaluate().isNotEmpty);
      // The list scrolled down to the button; the numbers are at the top.
      await h.scrollToTop();
      await h.until(() =>
          find.descendant(of: find.byKey(const Key('storage-messages')), matching: find.text('1')).evaluate().isNotEmpty);
      expect(find.descendant(of: find.byKey(const Key('storage-media')), matching: find.text('0 files')),
          findsOneWidget);
      expect((await h.real(() => alice.controller.loadMessages(chat))).map((m) => m.body), ['a text message'],
          reason: 'only the voice message went');

      expect(tester.takeException(), isNull);
      await h.dispose();
    });
  });
}
