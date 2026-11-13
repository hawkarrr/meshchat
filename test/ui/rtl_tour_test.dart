import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_mesh_chat/l10n/l10n.dart';
import 'package:offline_mesh_chat/models/conversation.dart';
import 'package:offline_mesh_chat/protocol/room_record.dart';
import 'package:offline_mesh_chat/screens/onboarding_screen.dart';

import '../support/ui_harness.dart';

/// A walk through nearly every screen of the app in Kurdish and in Arabic, on a
/// narrow phone with large system text, looking for text that runs out of its
/// box or a layout that breaks. The words themselves are checked elsewhere.
void main() {
  for (final language in [AppLanguage.ckb, AppLanguage.ar]) {
    testWidgets('${language.englishName}: first run, lists, chats, groups, rooms and settings',
        (tester) async {
      final h = UiHarness(tester)..screen(320, 640);
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final l = language.strings;
      // Layout errors are collected with their details, so a failure names the widget.
      final problems = <String>[];
      final previous = FlutterError.onError;
      FlutterError.onError = (details) {
        problems.add(details.toString());
        previous?.call(details);
      };
      addTearDown(() => FlutterError.onError = previous);
      void clean(String where) {
        final thrown = tester.takeException();
        if (thrown == null && problems.isEmpty) return;
        fail('$where: ${problems.map((d) => d.toString()).join('\n')} $thrown');
      }
      // The system's back: closes a sheet or a dialog, or leaves a screen.
      Future<void> back() async {
        await tester.binding.handlePopRoute();
        await h.settle();
      }

      // The first-run page.
      final fresh = await h.node('Fresh', language: language);
      await h.show(fresh);
      expect(find.byType(OnboardingScreen), findsOneWidget);
      for (final key in ['language-picker', 'onboarding-name', 'onboarding-start']) {
        await h.reveal(find.byKey(Key(key)));
        clean('first run: $key');
      }
      await h.scrollToTop();

      // Two phones that know each other.
      final alice = await h.node('Alice', onboarded: true, nickname: 'Alice', language: language);
      final bob = await h.node('Bob', onboarded: true, nickname: 'Bob');
      await h.show(alice);
      await h.until(
          () =>
              alice.directlyReaches(bob) &&
              bob.directlyReaches(alice) &&
              (alice.viewOf(bob)?.peer.canReceiveEncrypted ?? false),
          timeoutMs: 30000);
      final withBob = Conversation.directId(bob.id);
      final mesh = 'rm:${PublicRooms.meshIdHex}';
      late String groupId;
      await h.real(() async {
        await bob.controller.sendDirect(alice.id, 'hello from Bob');
        await alice.controller.sendDirect(bob.id, 'hello Bob');
        final group = await alice.controller.createGroup('Hikers', [bob.id]);
        groupId = Conversation.groupConversationId(group.id);
        await alice.controller.sendText(groupId, 'meet at the lake');
        await bob.controller.sendText(mesh, 'anyone near the station?');
      });
      await h.untilAsync(() async => (await alice.controller.loadMessages(withBob)).length == 2);
      await h.until(() => find.byKey(Key('conversation-$withBob')).evaluate().isNotEmpty);
      clean('private list');

      // The people, and what is around.
      await h.tap(find.byKey(const Key('open-people')));
      clean('people');
      await back();
      await h.tap(find.byKey(const Key('search-toggle')));
      await tester.enterText(find.byKey(const Key('search-field')), 'zzz');
      await h.settle();
      clean('search with nothing found');
      await h.tap(find.byKey(const Key('search-toggle')));

      // A chat: its menu, selection and the sheets.
      await h.tap(find.byKey(Key('conversation-$withBob')));
      await h.until(() => find.text('hello Bob').evaluate().isNotEmpty);
      clean('chat');
      await tester.longPress(find.text('hello Bob').first);
      await h.settle();
      clean('message menu');
      await h.tap(find.byKey(const Key('act-select')));
      clean('selection');
      await h.tap(find.byKey(const Key('selection-more')));
      clean('selection menu');
      await back();
      await h.tap(find.byKey(const Key('selection-delete')));
      clean('delete dialog');
      await h.tap(find.byKey(const Key('delete-cancel')));
      await h.tap(find.byKey(const Key('selection-close')));
      await h.tap(find.byKey(const Key('composer-attach')));
      clean('attach sheet');
      await back();
      await h.tap(find.byKey(const Key('chat-search')));
      clean('search in the chat');
      await back();
      await h.tap(find.byKey(const Key('verify-contact')));
      clean('contact details');
      await back();
      await back();

      // Groups.
      await h.goToTab(l.navGroups);
      await h.until(() => find.byKey(Key('conversation-$groupId')).evaluate().isNotEmpty);
      clean('groups list');
      await h.tap(find.byKey(Key('conversation-$groupId')));
      await h.until(() => find.text('meet at the lake').evaluate().isNotEmpty);
      clean('group chat');
      await h.tap(find.byKey(const Key('group-info')));
      clean('group details');
      await back();
      await back();
      await h.tap(find.byKey(const Key('fab-groups')));
      clean('new group');
      await back();

      // The public room, the first place of the bar.
      await h.goToTab(l.navPublic);
      await h.until(() => find.byKey(const Key('room-expiry-note')).evaluate().isNotEmpty);
      await h.until(() => find.text('anyone near the station?').evaluate().isNotEmpty);
      clean('room');
      await h.tap(find.byKey(const Key('room-label')));
      clean('rooms sheet');
      await h.tap(find.byKey(const Key('rooms-create')));
      clean('new room');
      await back();
      await back();
      await h.tap(find.byKey(const Key('room-nickname')));
      clean('room name');
      await back();
      await h.tap(find.byKey(const Key('room-people')));
      clean('nearby');
      await back();

      // Settings: the menu, each page, and what hangs off it.
      await h.goToTab(l.settingsTitle);
      clean('settings menu');
      Future<void> page(String id, Future<void> Function() inside) async {
        await h.tap(find.byKey(Key('settings-$id')));
        clean('settings: $id');
        await inside();
        await back();
      }

      await page('profile', () async {
        await h.tap(find.byKey(const Key('edit-nickname')));
        clean('edit name');
        await back();
      });
      await page('language', () async {});
      await page('notifications', () async {});
      await page('privacy', () async {
        await h.reveal(find.byKey(const Key('open-storage')));
        await h.tap(find.byKey(const Key('open-storage')));
        clean('storage');
        await back();
        await h.reveal(find.text(l.setSecurityLog));
        await h.tap(find.text(l.setSecurityLog));
        clean('security log');
        await back();
        await h.reveal(find.byKey(const Key('reset-identity')));
        await h.tap(find.byKey(const Key('reset-identity')));
        clean('reset identity');
        await back();
      });
      await page('chat', () async {
        await h.tap(find.text(l.setSelfTest));
        clean('self-test');
        await back();
        await h.reveal(find.byKey(const Key('relay-switch')));
      });
      await page('help', () async {
        await h.tap(find.text(l.honestyNoInternetTitle));
        clean('how it works');
      });
      await page('about', () async {});
      FlutterError.onError = previous;
      await h.dispose();
    }, timeout: const Timeout(Duration(minutes: 4)));
  }
}
