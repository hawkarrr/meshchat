import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_mesh_chat/models/conversation.dart';
import 'package:offline_mesh_chat/models/group.dart';
import 'package:offline_mesh_chat/screens/chat_screen.dart';
import 'package:offline_mesh_chat/screens/create_group_screen.dart';
import 'package:offline_mesh_chat/screens/group_detail_screen.dart';
import 'package:offline_mesh_chat/widgets/nav_bar.dart';

import '../support/app_harness.dart';
import '../support/ui_harness.dart';

Future<List<AppNode>> _phones(UiHarness h, List<String> names) async => [
      for (final n in names) await h.node(n, onboarded: true, nickname: n),
    ];

/// Waits until every phone is directly connected to, and has the keys of, all the others.
Future<void> _everyoneMeets(UiHarness h, List<AppNode> nodes) => h.until(
      () => nodes.every((a) => nodes.every((b) =>
          identical(a, b) ||
          (a.directlyReaches(b) && (a.viewOf(b)?.peer.canReceiveEncrypted ?? false)))),
      timeoutMs: 25000,
      reason: 'the phones should find each other and swap keys',
    );

/// The invitation reaches [member] and they accept it.
Future<void> _accepts(UiHarness h, AppNode member, GroupChat group) async {
  await h.untilAsync(() async {
    final g = await member.controller.group(group.id);
    return g != null && g.state == GroupState.invited;
  }, reason: '${member.name} should be invited');
  await h.real(() => member.controller.acceptGroup(group.id));
}

Future<void> _groupStateIs(UiHarness h, AppNode member, GroupChat group, GroupState state) =>
    h.untilAsync(() async => (await member.controller.group(group.id))?.state == state,
        reason: "${member.name}'s copy of the group should be $state");

String _chatOf(GroupChat g) => Conversation.groupConversationId(g.id);

void main() {
  group('creating a group', () {
    testWidgets('name it, pick people, invitations go out, and the chat opens', (tester) async {
      final h = UiHarness(tester)..screen();
      final nodes = await _phones(h, ['Alice', 'Bob', 'Carol']);
      final [alice, bob, carol] = nodes;
      await h.show(alice);
      await _everyoneMeets(h, nodes);

      await h.goToTab('Groups');
      await h.tap(find.byKey(const Key('fab-groups')));
      expect(find.byType(CreateGroupScreen), findsOneWidget);
      expect(find.textContaining('only the people in the group'), findsNothing);
      expect(find.textContaining('nothing about the group is ever broadcast'), findsOneWidget);
      expect(find.text('Add people (0 of 11)'), findsOneWidget);

      FilledButton create() => tester.widget<FilledButton>(find.byKey(const Key('group-create')));
      expect(create().onPressed, isNull, reason: 'nothing can be created yet');
      await tester.enterText(find.byKey(const Key('group-name')), 'Weekend plans');
      await tester.pump();
      expect(create().onPressed, isNull, reason: 'a name alone is not enough');

      await h.tap(find.byKey(Key('pick-${bob.id}')));
      await h.tap(find.byKey(Key('pick-${carol.id}')));
      expect(find.text('Add people (2 of 11)'), findsOneWidget);
      expect(create().onPressed, isNotNull);
      await h.tap(find.byKey(const Key('group-create')));
      await h.until(() => find.byType(ChatScreen).evaluate().isNotEmpty);

      expect(find.text('Weekend plans'), findsWidgets);
      expect(find.textContaining('3 members'), findsOneWidget);
      await h.until(() => find.textContaining('encrypted with the group\'s key').evaluate().isNotEmpty,
          reason: 'an empty group explains itself once the chat has loaded');
      expect(find.textContaining('encrypted with the group\'s key'), findsOneWidget);
      final groupId = (await h.real(() async => alice.controller.groupsListenable.value.single)).id;

      // Both invited phones were sent a sealed invitation; they accept.
      final created = (await h.real(() => alice.controller.group(groupId)))!;
      expect({for (final m in created.members) m.id}, {alice.id, bob.id, carol.id});
      expect(created.adminId, alice.id);
      await _accepts(h, bob, created);
      await _accepts(h, carol, created);

      await tester.enterText(find.byKey(const Key('composer-field')), 'Saturday at ten?');
      await tester.pump();
      await h.tap(find.byKey(const Key('composer-send')));
      await h.until(() => find.text('Saturday at ten?').evaluate().isNotEmpty);
      await h.until(() => find.textContaining('Delivered').evaluate().isNotEmpty,
          timeoutMs: 20000, reason: 'both members confirm');
      for (final member in [bob, carol]) {
        await h.untilAsync(() async {
          final messages = await member.controller.loadMessages(_chatOf(created));
          return messages.any((m) => m.body == 'Saturday at ten?');
        }, reason: '${member.name} should have the message');
      }

      // A member's reply shows with their name.
      await h.real(() => carol.controller.sendText(_chatOf(created), 'Works for me'));
      await h.until(() => find.text('Works for me').evaluate().isNotEmpty);
      expect(find.text('Carol'), findsWidgets, reason: 'the author is named above the bubble');

      expect(tester.takeException(), isNull);
      await h.dispose();
    });

    testWidgets('a group needs a name and at least one person', (tester) async {
      final h = UiHarness(tester)..screen();
      final nodes = await _phones(h, ['Alice', 'Bob']);
      final [alice, bob] = nodes;
      await h.show(alice);
      await _everyoneMeets(h, nodes);

      await h.goToTab('Groups');
      expect(find.byKey(const Key('empty-create-group')), findsOneWidget,
          reason: 'the empty state offers to create one');
      await h.tap(find.byKey(const Key('empty-create-group')));
      await tester.enterText(find.byKey(const Key('group-name')), 'Just me');
      await tester.pump();
      expect(tester.widget<FilledButton>(find.byKey(const Key('group-create'))).onPressed, isNull);
      await h.tap(find.byKey(Key('pick-${bob.id}')));
      await h.tap(find.byKey(Key('pick-${bob.id}')));
      expect(find.text('Add people (0 of 11)'), findsOneWidget, reason: 'tapping again unpicks');
      expect(tester.widget<FilledButton>(find.byKey(const Key('group-create'))).onPressed, isNull);

      expect(tester.takeException(), isNull);
      await h.dispose();
    });

    testWidgets('with nobody met yet, the screen explains why the list is empty',
        (tester) async {
      final h = UiHarness(tester)..screen();
      final alice = await h.node('Alice', onboarded: true, nickname: 'Alice');
      await h.show(alice);
      await h.goToTab('Groups');
      await h.tap(find.byKey(const Key('fab-groups')));
      expect(find.text('Nobody to add yet'), findsOneWidget);
      expect(find.textContaining('only invite people your phone has met'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await h.dispose();
    });
  });

  group('invitations', () {
    testWidgets('can be declined or accepted, and the chat works afterwards', (tester) async {
      final h = UiHarness(tester)..screen();
      final nodes = await _phones(h, ['Alice', 'Bob']);
      final [alice, bob] = nodes;
      await h.show(bob);
      await _everyoneMeets(h, nodes);

      final lunch = await h.real(() => alice.controller.createGroup('Lunch', [bob.id]));
      final secret = await h.real(() => alice.controller.createGroup('Secret club', [bob.id]));
      await h.until(
          () =>
              bob.controller.groupsListenable.value.where((g) => g.state == GroupState.invited).length ==
              2,
          timeoutMs: 20000,
          reason: 'both invitations arrive');
      expect(find.textContaining('Alice invited you'), findsNothing,
          reason: 'not on the Private tab');

      await h.goToTab('Groups');
      expect(find.text('Invitations (2)'), findsOneWidget);
      expect(find.byKey(Key('invite-${lunch.id}')), findsOneWidget);
      expect(find.byKey(Key('invite-${secret.id}')), findsOneWidget);
      expect(find.textContaining('Alice invited you'), findsNWidgets(2));
      final tabBadge = find.descendant(of: find.byType(AppNavBar), matching: find.text('2'));
      expect(tabBadge, findsOneWidget, reason: 'the Groups tab counts the invitations');

      await h.tap(find.byKey(Key('decline-${secret.id}')));
      await h.until(() => find.byKey(Key('invite-${secret.id}')).evaluate().isEmpty);
      expect(find.text('Invitations (1)'), findsOneWidget);
      expect(await h.real(() => bob.controller.group(secret.id)), isNull,
          reason: 'a declined group is forgotten, with its key');

      await h.tap(find.byKey(Key('accept-${lunch.id}')));
      await h.until(() => find.byType(ChatScreen).evaluate().isNotEmpty);
      expect(find.text('Lunch'), findsWidgets);
      expect(find.textContaining('2 members'), findsOneWidget);

      await h.real(() => alice.controller.sendText(_chatOf(lunch), 'see you at noon'));
      await h.until(() => find.text('see you at noon').evaluate().isNotEmpty);
      expect(find.text('Alice'), findsWidgets, reason: 'the sender is named in a group');

      await tester.pageBack();
      await h.until(() =>
          find.byKey(Key('conversation-${_chatOf(lunch)}')).evaluate().isNotEmpty);
      expect(find.textContaining('Invitations'), findsNothing);
      expect(find.text('Alice: see you at noon'), findsOneWidget,
          reason: 'the preview of the last message names its author in a group');
      expect(find.text('Your groups'), findsNothing);

      expect(tester.takeException(), isNull);
      await h.dispose();
    });

    testWidgets('an unread group message shows a badge on the tile and on the tab',
        (tester) async {
      final h = UiHarness(tester)..screen();
      final nodes = await _phones(h, ['Alice', 'Bob']);
      final [alice, bob] = nodes;
      await h.show(alice);
      await _everyoneMeets(h, nodes);
      final g = await h.real(() => alice.controller.createGroup('Book club', [bob.id]));
      await _accepts(h, bob, g);
      await h.goToTab('Groups');

      await h.real(() => bob.controller.sendText(_chatOf(g), 'chapter four was great'));
      await h.until(() => alice.controller.totalUnread == 1, timeoutMs: 15000);
      await h.until(() => find.text('Bob: chapter four was great').evaluate().isNotEmpty);
      expect(find.descendant(of: find.byType(AppNavBar), matching: find.text('1')), findsWidgets);

      await h.tap(find.byKey(Key('conversation-${_chatOf(g)}')));
      await h.until(() => alice.controller.totalUnread == 0);
      expect(find.text('chapter four was great'), findsOneWidget, reason: 'the bubble in the chat');

      expect(tester.takeException(), isNull);
      await h.dispose();
    });
  });

  group('group details', () {
    testWidgets('a member sees who is in, cannot manage them, and can leave', (tester) async {
      final h = UiHarness(tester)..screen();
      final nodes = await _phones(h, ['Alice', 'Bob']);
      final [alice, bob] = nodes;
      await h.show(bob);
      await _everyoneMeets(h, nodes);
      final g = await h.real(() => alice.controller.createGroup('Hikers', [bob.id]));
      await h.goToTab('Groups');
      await h.until(() => find.byKey(Key('accept-${g.id}')).evaluate().isNotEmpty, timeoutMs: 20000);
      await h.tap(find.byKey(Key('accept-${g.id}')));
      await h.until(() => find.byType(ChatScreen).evaluate().isNotEmpty);

      await h.tap(find.byKey(const Key('group-info')));
      expect(find.byType(GroupDetailScreen), findsOneWidget);
      expect(find.text('Group details'), findsOneWidget);
      expect(find.text('Hikers'), findsWidgets);
      expect(find.text('Members'), findsOneWidget);
      expect(find.text('Admin'), findsOneWidget, reason: 'Alice is marked as the admin');
      expect(find.text('You'), findsOneWidget);
      expect(find.textContaining('new key'), findsOneWidget);
      expect(find.byKey(Key('remove-${alice.id}')), findsNothing, reason: 'only the admin manages');
      expect(find.byKey(const Key('group-add')), findsNothing);
      expect(find.byKey(const Key('group-delete')), findsNothing);

      // Cancelling the confirmation keeps everything as it is.
      await h.tap(find.byKey(const Key('group-leave')));
      expect(find.text('Leave this group?'), findsOneWidget);
      await h.tap(find.text('Cancel'));
      expect((await h.real(() => bob.controller.group(g.id)))!.state, GroupState.active);

      await h.tap(find.byKey(const Key('group-leave')));
      await h.tap(find.byKey(const Key('confirm-action')));
      await h.until(() => find.byType(GroupDetailScreen).evaluate().isEmpty);
      expect((await h.real(() => bob.controller.group(g.id)))!.state, GroupState.left);
      await _groupStateIs(h, alice, g, GroupState.active);

      // The chat stays, read-only, and says so.
      await h.goToTab('Groups');
      expect(find.text('You left this group'), findsOneWidget);
      await h.tap(find.byKey(Key('conversation-${_chatOf(g)}')));
      expect(find.text('You left this group'), findsWidgets);
      expect(tester.widget<TextField>(find.byKey(const Key('composer-field'))).enabled, isFalse);
      await h.tap(find.byKey(const Key('group-info')));
      await h.tap(find.byKey(const Key('group-forget')));
      expect(find.text('Remove from this phone?'), findsOneWidget);
      await h.tap(find.byKey(const Key('confirm-action')));
      await h.until(() => find.text('No groups yet').evaluate().isNotEmpty,
          reason: 'the chat is gone from this phone');
      expect(find.byKey(Key('conversation-${_chatOf(g)}')), findsNothing);

      expect(tester.takeException(), isNull);
      await h.dispose();
    });

    testWidgets('the admin adds and removes people, and ends the group', (tester) async {
      final h = UiHarness(tester)..screen();
      final nodes = await _phones(h, ['Alice', 'Bob', 'Carol']);
      final [alice, bob, carol] = nodes;
      await h.show(alice);
      await _everyoneMeets(h, nodes);
      final g = await h.real(() => alice.controller.createGroup('Hikers', [bob.id]));
      await _accepts(h, bob, g);

      await h.goToTab('Groups');
      await h.tap(find.byKey(Key('conversation-${_chatOf(g)}')));
      await h.tap(find.byKey(const Key('group-info')));
      expect(find.text('Admin'), findsOneWidget);
      expect(find.byKey(Key('member-${carol.id}')), findsNothing);
      expect(find.byKey(Key('remove-${bob.id}')), findsOneWidget);

      // Add Carol: only people who are not in yet are offered.
      await h.tap(find.byKey(const Key('group-add')));
      expect(find.text('Add people'), findsWidgets);
      expect(find.byKey(Key('pick-${bob.id}')), findsNothing);
      expect(tester.widget<FilledButton>(find.byKey(const Key('add-people-confirm'))).onPressed, isNull);
      await h.tap(find.byKey(Key('pick-${carol.id}')));
      await h.tap(find.byKey(const Key('add-people-confirm')));
      // The note is on screen for a few seconds only: look for it first.
      await h.until(() => find.text('Invitations sent. The group has a new key.').evaluate().isNotEmpty,
          reason: 'the admin is told invitations went out');
      await h.until(() => find.byKey(Key('member-${carol.id}')).evaluate().isNotEmpty);
      expect((await h.real(() => alice.controller.group(g.id)))!.epoch, 1,
          reason: 'every membership change gives the group a new key');
      await _accepts(h, carol, g);

      // Remove Bob, after being asked.
      await h.tap(find.byKey(Key('remove-${bob.id}')));
      expect(find.text('Remove Bob?'), findsOneWidget);
      await h.tap(find.text('Cancel'));
      expect(find.byKey(Key('member-${bob.id}')), findsOneWidget);
      await h.tap(find.byKey(Key('remove-${bob.id}')));
      await h.tap(find.byKey(const Key('confirm-action')));
      await h.until(() => find.byKey(Key('member-${bob.id}')).evaluate().isEmpty);
      expect((await h.real(() => alice.controller.group(g.id)))!.epoch, 2);
      await _groupStateIs(h, bob, g, GroupState.removed);

      // End the group for everybody.
      await h.tap(find.byKey(const Key('group-delete')));
      expect(find.text('Delete this group?'), findsOneWidget);
      await h.tap(find.byKey(const Key('confirm-action')));
      await h.until(() => find.byType(GroupDetailScreen).evaluate().isEmpty);
      await h.goToTab('Groups');
      await h.until(() => find.text('No groups yet').evaluate().isNotEmpty);
      expect(await h.real(() => alice.controller.group(g.id)), isNull);
      await _groupStateIs(h, carol, g, GroupState.removed);

      expect(tester.takeException(), isNull);
      await h.dispose();
    });

    testWidgets('someone who was removed sees it, and cannot write any more', (tester) async {
      final h = UiHarness(tester)..screen();
      final nodes = await _phones(h, ['Alice', 'Bob']);
      final [alice, bob] = nodes;
      await h.show(bob);
      await _everyoneMeets(h, nodes);
      final g = await h.real(() => alice.controller.createGroup('Hikers', [bob.id]));
      await h.goToTab('Groups');
      await h.until(() => find.byKey(Key('accept-${g.id}')).evaluate().isNotEmpty, timeoutMs: 20000);
      await h.tap(find.byKey(Key('accept-${g.id}')));
      await h.until(() => find.byType(ChatScreen).evaluate().isNotEmpty);
      expect(tester.widget<TextField>(find.byKey(const Key('composer-field'))).enabled, isTrue);

      await h.real(() => alice.controller.removeGroupMember(g.id, bob.id));
      await h.until(() => find.text('You were removed').evaluate().isNotEmpty,
          timeoutMs: 20000, reason: 'the header tells Bob');
      expect(tester.widget<TextField>(find.byKey(const Key('composer-field'))).enabled, isFalse);
      expect(find.text('You were removed from this group'), findsOneWidget,
          reason: 'the composer says why it is disabled');

      expect(tester.takeException(), isNull);
      await h.dispose();
    });
  });

  group('finding and fitting', () {
    testWidgets('search filters the groups', (tester) async {
      final h = UiHarness(tester)..screen();
      final nodes = await _phones(h, ['Alice', 'Bob']);
      final [alice, bob] = nodes;
      await h.show(alice);
      await _everyoneMeets(h, nodes);
      await h.real(() => alice.controller.createGroup('Lunch crew', [bob.id]));
      await h.real(() => alice.controller.createGroup('Hikers', [bob.id]));
      await h.goToTab('Groups');
      await h.until(() => find.text('Hikers').evaluate().isNotEmpty);

      await h.tap(find.byKey(const Key('search-toggle')));
      await tester.enterText(find.byKey(const Key('search-field')), 'hik');
      await h.settle();
      expect(find.text('Hikers'), findsOneWidget);
      expect(find.text('Lunch crew'), findsNothing);

      await tester.enterText(find.byKey(const Key('search-field')), 'zzz');
      await h.settle();
      expect(find.text('Nothing found'), findsOneWidget);
      expect(find.textContaining('No group matches "zzz"'), findsOneWidget);

      expect(tester.takeException(), isNull);
      await h.dispose();
    });

    testWidgets('every group screen fits the smallest phone with large text', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final h = UiHarness(tester)..screen(320, 568);
      final nodes = await _phones(h, ['Alice', 'Bobby Tables-Longname', 'Carol']);
      final [alice, bob, carol] = nodes;
      await h.show(alice);
      await _everyoneMeets(h, nodes);
      final g = await h.real(
          () => alice.controller.createGroup('A group with a very long name here', [bob.id, carol.id]));
      await h.real(() => alice.controller.sendText(_chatOf(g), 'a long message to wrap around'));
      await h.goToTab('Groups');
      expect(tester.takeException(), isNull, reason: 'the Groups tab');

      await h.tap(find.byKey(Key('conversation-${_chatOf(g)}')));
      expect(tester.takeException(), isNull, reason: 'the chat');
      await h.tap(find.byKey(const Key('group-info')));
      expect(tester.takeException(), isNull, reason: 'the details');
      await h.tap(find.byKey(const Key('group-add')));
      expect(tester.takeException(), isNull, reason: 'add people');
      await tester.pageBack();
      await h.settle();
      await tester.pageBack();
      await h.settle();
      await tester.pageBack();
      await h.settle();
      await h.tap(find.byKey(const Key('fab-groups')));
      expect(tester.takeException(), isNull, reason: 'the new group screen');

      await h.dispose();
    });
  });
}
