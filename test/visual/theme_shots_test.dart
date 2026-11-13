import 'dart:io' show Directory;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_mesh_chat/models/conversation.dart';
import 'package:offline_mesh_chat/models/media.dart' show MediaKind;
import 'package:offline_mesh_chat/protocol/room_record.dart';
import 'package:offline_mesh_chat/services/media_service.dart' show MediaDraft;
import 'package:offline_mesh_chat/theme/theme_controller.dart';

import '../support/message_node.dart' show fakeBytes;
import '../support/shots.dart';
import '../support/ui_harness.dart';

/// Visual check, not a regression test: the same screens in the light and in the dark
/// appearance, written to `build/shots/theme_<light|dark>_*.png` for a person to look at.
///
///     flutter test test/visual/theme_shots_test.dart
const String _mesh = 'rm:${PublicRooms.meshIdHex}';

void _testShots(String name, Future<void> Function(WidgetTester tester) body) {
  testWidgets(name, (tester) async {
    debugDisableShadows = false;
    try {
      await body(tester);
    } finally {
      debugDisableShadows = true;
    }
  }, timeout: const Timeout(Duration(minutes: 4)));
}

void main() {
  setUpAll(() async {
    await loadShotFonts();
    goldenFileComparator = ShotWriter(Directory('build/shots'));
  });

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    final tag = mode.name;

    _testShots('$tag: the room, a private chat with voice, the menu', (tester) async {
      final h = UiHarness(tester)..screen(390, 844);
      final alice = await h.node('Alice', onboarded: true, nickname: 'Alice', theme: ThemeController(mode: mode));
      final bob = await h.node('Bob', onboarded: true, nickname: 'Bob');
      final carol = await h.node('Carol', onboarded: true, nickname: 'Carol');
      await h.show(alice, landing: true);
      await h.settle(300);
      await shot(tester, 'theme_${tag}_01_room_empty');

      await h.until(() => alice.directlyReaches(bob) && alice.directlyReaches(carol), timeoutMs: 30000);
      await h.real(() => bob.controller.sendText(_mesh, 'hello everyone'));
      await h.real(() => carol.controller.sendText(_mesh, 'anyone near the market?'));
      await h.until(() => find.text('anyone near the market?').evaluate().isNotEmpty, timeoutMs: 30000);
      await tester.enterText(find.byKey(const Key('composer-field')), 'I am here, next to the cafe');
      await tester.pump();
      await h.tap(find.byKey(const Key('composer-send')));
      await h.until(() => find.text('I am here, next to the cafe').evaluate().isNotEmpty);
      await h.settle(300);
      await shot(tester, 'theme_${tag}_02_room');

      // A private chat, with words and a voice message each way.
      await h.goToTab('Private');
      await h.until(
          () => alice.directlyReaches(bob) && (alice.viewOf(bob)?.peer.canReceiveEncrypted ?? false),
          timeoutMs: 30000);
      final withBob = Conversation.directId(bob.id);
      final withAlice = Conversation.directId(alice.id);
      MediaDraft voice(int ms) => MediaDraft(
            kind: MediaKind.voice,
            bytes: fakeBytes(3000),
            durationMs: ms,
            waveform: List<int>.generate(40, (i) => 40 + (i * 37) % 200),
          );
      await h.real(() async {
        await alice.controller.openChat(bob.id);
        await bob.controller.openChat(alice.id);
        await bob.controller.sendText(withAlice, 'Did the picture come through?');
        await alice.controller.sendText(withBob, 'Yes, it did. Thank you!');
        await bob.controller.sendMedia(withAlice, voice(7000));
        await alice.controller.sendMedia(withBob, voice(12000));
      });
      await h.until(() => find.byKey(Key('conversation-$withBob')).evaluate().isNotEmpty);
      await h.settle(300);
      await shot(tester, 'theme_${tag}_03_private_list');
      await h.tap(find.byKey(Key('conversation-$withBob')));
      await h.until(() => find.text('Yes, it did. Thank you!').evaluate().isNotEmpty);
      await h.until(() => find.byKey(const Key('voice-play')).evaluate().length >= 2, timeoutMs: 30000);
      await h.settle(400);
      await shot(tester, 'theme_${tag}_04_chat');

      await tester.longPress(find.text('Did the picture come through?').first);
      await h.settle(300);
      await shot(tester, 'theme_${tag}_05_menu');
      expect(tester.takeException(), isNull);
      await h.dispose();
    });

    _testShots('$tag: lists, settings and the pages', (tester) async {
      final h = UiHarness(tester)..screen(390, 844);
      final alice = await h.node('Alice', onboarded: true, nickname: 'Alice', theme: ThemeController(mode: mode));
      final bob = await h.node('Bob', onboarded: true, nickname: 'Bob');
      await h.show(alice, landing: true);
      await h.until(
          () => alice.directlyReaches(bob) && (alice.viewOf(bob)?.peer.canReceiveEncrypted ?? false),
          timeoutMs: 30000);
      await h.real(() => alice.controller.createGroup('Hikers', [bob.id]));
      await h.goToTab('Groups');
      await h.settle(400);
      await shot(tester, 'theme_${tag}_06_groups');
      await h.goToTab('Settings');
      await h.settle(300);
      await shot(tester, 'theme_${tag}_07_settings');
      var n = 8;
      for (final key in ['settings-appearance', 'settings-notifications', 'settings-chat', 'settings-privacy']) {
        await h.tap(find.byKey(Key(key)));
        await h.settle(300);
        await shot(tester, 'theme_${tag}_${(n++).toString().padLeft(2, '0')}_$key');
        await h.tester.binding.handlePopRoute();
        await h.settle();
      }
      expect(tester.takeException(), isNull);
      await h.dispose();
    });

    _testShots('$tag: the other screens', (tester) async {
      final h = UiHarness(tester)..screen(390, 844);
      final alice = await h.node('Alice', onboarded: true, nickname: 'Alice', theme: ThemeController(mode: mode));
      final bob = await h.node('Bob', onboarded: true, nickname: 'Bob');
      await h.show(alice, landing: true);
      await h.until(
          () => alice.directlyReaches(bob) && (alice.viewOf(bob)?.peer.canReceiveEncrypted ?? false),
          timeoutMs: 30000);
      await h.real(() => alice.controller.openChat(bob.id));

      Future<void> back() async {
        await h.tester.binding.handlePopRoute();
        await h.settle();
      }

      // The room's list of rooms.
      await h.tap(find.byKey(const Key('room-label')));
      await h.settle(300);
      await shot(tester, 'theme_${tag}_20_rooms');
      await back();

      // Who is nearby (the number of people in the room's header).
      await h.tap(find.byKey(const Key('room-people')));
      await h.settle(300);
      await shot(tester, 'theme_${tag}_21_nearby');
      await back();

      // A private chat's details (the shield).
      await h.goToTab('Private');
      await h.tap(find.byKey(Key('conversation-${Conversation.directId(bob.id)}')));
      await h.tap(find.byKey(const Key('verify-contact')));
      await h.settle(300);
      await shot(tester, 'theme_${tag}_22_contact');
      await back();
      await back();

      // The people list.
      await h.tap(find.byKey(const Key('open-people')));
      await h.settle(300);
      await shot(tester, 'theme_${tag}_23_people');
      await back();

      // Settings pages that are long or odd.
      await h.goToTab('Settings');
      await h.tap(find.byKey(const Key('settings-privacy')));
      await h.tap(find.byKey(const Key('open-storage')));
      await h.settle(300);
      await shot(tester, 'theme_${tag}_24_storage');
      await back();
      await h.settle(300);
      await shot(tester, 'theme_${tag}_25_privacy');
      await back();
      await h.tap(find.byKey(const Key('settings-chat')));
      await h.tap(find.text('Bluetooth self-test'));
      await h.settle(300);
      await shot(tester, 'theme_${tag}_26_self_test');
      await back();
      await back();
      await h.tap(find.byKey(const Key('settings-help')));
      await h.settle(300);
      await shot(tester, 'theme_${tag}_27_help');
      await back();
      await h.tap(find.byKey(const Key('settings-about')));
      await h.settle(300);
      await shot(tester, 'theme_${tag}_28_about');
      expect(tester.takeException(), isNull);
      await h.dispose();
    });

    _testShots('$tag: the first-run page', (tester) async {
      final h = UiHarness(tester)..screen(390, 844);
      final alice = await h.node('Alice', theme: ThemeController(mode: mode));
      await h.show(alice, landing: true);
      await h.settle(300);
      await shot(tester, 'theme_${tag}_12_first_run');
      expect(tester.takeException(), isNull);
      await h.dispose();
    });
  }
}
