import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_mesh_chat/models/conversation.dart';
import 'package:offline_mesh_chat/models/message.dart';
import 'package:offline_mesh_chat/protocol/room_record.dart';

import '../support/shots.dart';
import '../support/ui_harness.dart';

/// Visual check, not a regression test: draws the message-action screens (menu,
/// selection, reply and edit bars, pinned banner, forward list, search, details,
/// delete dialog) with the real font and icons and writes PNG files to
/// `build/shots/` for a person to look at.
///
///     flutter test test/visual/message_actions_shots_test.dart

const String _mesh = 'rm:${PublicRooms.meshIdHex}';

void main() {
  setUpAll(() async {
    await loadShotFonts();
    goldenFileComparator = ShotWriter(Directory('build/shots'));
  });

  testWidgets('a chat with replies, a forward, an edit and pins', (tester) async {
    debugDisableShadows = false;
    try {
      final h = UiHarness(tester)..screen(390, 844);
      final alice = await h.node('Alice', onboarded: true, nickname: 'Alice');
      final bob = await h.node('Bob', onboarded: true, nickname: 'Bob');
      await h.show(alice);
      await h.until(
          () =>
              alice.directlyReaches(bob) &&
              bob.directlyReaches(alice) &&
              (alice.viewOf(bob)?.peer.canReceiveEncrypted ?? false),
          timeoutMs: 30000);
      final withBob = Conversation.directId(bob.id);

      final question = await h.real(
          () => bob.controller.sendDirect(alice.id, 'Are you coming to the picnic tomorrow?'));
      await h.untilAsync(() async => (await alice.controller.loadMessages(withBob)).length == 1);
      late ChatMessage answer;
      await h.real(() async {
        answer = await alice.controller
            .sendText(withBob, 'Yes! I will bring sandwiches', replyToId: question.id);
      });
      await h.real(() async {
        await bob.controller.sendDirect(alice.id, 'Meet at ten, by the lake');
        await alice.controller.sendText(withBob, 'Perfect, see you there');
      });
      await h.untilAsync(() async => (await alice.controller.loadMessages(withBob)).length == 4);
      await h.real(() async {
        final lake = (await alice.controller.loadMessages(withBob))[2];
        await alice.controller.forwardMessages([lake.id], withBob);
        await alice.controller.editMessage(answer.id, 'Yes! I will bring sandwiches and juice');
        await alice.controller.setPinned(withBob, lake.id, true);
      });
      await h.settle(200);

      await h.tap(find.byKey(Key('conversation-$withBob')));
      await h.until(() => find.byKey(const Key('pinned-banner')).evaluate().isNotEmpty);
      await h.until(() => find.byKey(const Key('forwarded-label')).evaluate().isNotEmpty);
      await h.settle(300);
      await shot(tester, '60_chat_actions');

      // The long-press menu on one of Bob's messages.
      await tester.longPress(find.text('Are you coming to the picnic tomorrow?').first);
      await h.settle();
      await shot(tester, '61_message_menu');
      await h.tap(find.byKey(const Key('act-reply')));
      await shot(tester, '62_reply_bar');
      await h.tap(find.byKey(const Key('composer-target-cancel')));

      // Edit one of ours.
      await tester.longPress(find.text('Perfect, see you there').first);
      await h.settle();
      await shot(tester, '63_menu_own_message');
      await h.tap(find.byKey(const Key('act-edit')));
      await shot(tester, '64_edit_bar');
      await h.tap(find.byKey(const Key('composer-target-cancel')));

      // Selection mode, with the delete dialog.
      await tester.longPress(find.text('Perfect, see you there').first);
      await h.settle();
      await h.tap(find.byKey(const Key('act-select')));
      await h.tap(find.text('Meet at ten, by the lake').first);
      await shot(tester, '65_selection');
      await h.tap(find.byKey(const Key('selection-more')));
      await shot(tester, '65b_selection_more');
      await tester.tapAt(const Offset(30, 400)); // the dimmed area closes the menu
      await h.settle();
      await h.tap(find.byKey(const Key('selection-delete')));
      await shot(tester, '66_delete_dialog');
      await h.tap(find.byKey(const Key('delete-cancel')));
      await h.tap(find.byKey(const Key('selection-close')));

      // Forward list, details, pinned list and search.
      await tester.longPress(find.text('Meet at ten, by the lake').first);
      await h.settle();
      await h.tap(find.byKey(const Key('act-forward')));
      await shot(tester, '67_forward_list');
      await tester.tapAt(const Offset(195, 60));
      await h.settle();

      await tester.longPress(find.text('Yes! I will bring sandwiches and juice').first);
      await h.settle();
      await h.tap(find.byKey(const Key('act-details')));
      await shot(tester, '68_details');
      await tester.tapAt(const Offset(195, 60));
      await h.settle();

      await h.tap(find.byKey(const Key('pinned-list-open')));
      await shot(tester, '69_pinned_list');
      await tester.tapAt(const Offset(195, 60));
      await h.settle();

      await h.tap(find.byKey(const Key('chat-search')));
      await tester.enterText(find.byKey(const Key('search-field')), 'lake');
      await h.settle();
      await shot(tester, '70_search');

      await h.dispose();
    } finally {
      debugDisableShadows = true;
    }
  }, timeout: const Timeout(Duration(minutes: 3)));

  testWidgets('home header, settings and storage', (tester) async {
    debugDisableShadows = false;
    try {
      final h = UiHarness(tester)..screen(390, 844);
      final alice = await h.node('Alice', onboarded: true, nickname: 'Alice');
      final bob = await h.node('Bob', onboarded: true, nickname: 'Bob');
      await h.show(alice);
      await h.until(() => alice.directlyReaches(bob) && bob.directlyReaches(alice), timeoutMs: 30000);
      await h.settle(300);
      await shot(tester, '80_home_offline_badge');

      await h.openSettingsPage('notifications');
      await shot(tester, '81_settings_notifications');
      await tester.pageBack();
      await h.settle();
      await h.tap(find.byKey(const Key('settings-chat')));
      await h.reveal(find.byKey(const Key('keepalive-switch')));
      await shot(tester, '82_settings_mesh');
      await tester.pageBack();
      await h.settle();

      await h.tap(find.byKey(const Key('settings-privacy')));
      await h.reveal(find.byKey(const Key('open-storage')));
      await h.tap(find.byKey(const Key('open-storage')));
      await h.until(() => find.byKey(const Key('video-limit')).evaluate().isNotEmpty);
      await h.loaded();
      await h.settle(300);
      await shot(tester, '83_storage');
      await h.dispose();
    } finally {
      debugDisableShadows = true;
    }
  }, timeout: const Timeout(Duration(minutes: 3)));

  testWidgets('the public room with a quote, a pin and its six-hour note', (tester) async {
    debugDisableShadows = false;
    try {
      final h = UiHarness(tester)..screen(390, 844);
      final alice = await h.node('Alice', onboarded: true, nickname: 'Alice');
      final bob = await h.node('Bob', onboarded: true, nickname: 'Bob');
      await h.show(alice);
      await h.until(() => alice.directlyReaches(bob) && bob.directlyReaches(alice), timeoutMs: 30000);
      final first = await h.real(() => bob.controller.sendText(_mesh, 'anyone near the station?'));
      await h.untilAsync(() async => (await alice.controller.loadMessages(_mesh)).isNotEmpty);
      await h.real(() async {
        await alice.controller.sendText(_mesh, 'yes, by the cafe', replyToId: first.id);
        await alice.controller.setPinned(_mesh, first.id, true);
      });
      await h.openTab('public');
      await h.until(() => find.byKey(const Key('pinned-banner')).evaluate().isNotEmpty);
      await h.settle(300);
      await shot(tester, '71_room_actions');
      await tester.longPress(find.text('yes, by the cafe'));
      await h.settle();
      await shot(tester, '72_room_menu');
      await h.dispose();
    } finally {
      debugDisableShadows = true;
    }
  }, timeout: const Timeout(Duration(minutes: 3)));
}
