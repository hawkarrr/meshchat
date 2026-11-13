import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_mesh_chat/models/conversation.dart';
import 'package:offline_mesh_chat/screens/chat_screen.dart';
import 'package:offline_mesh_chat/screens/room_screen.dart';

import '../support/ui_harness.dart';

/// The smallest thing a thumb is asked to hit is 44 x 44 points: the size Apple
/// and Google both ask for. A button that is drawn smaller (a round icon on a
/// header, a close cross) still has to take up that much room.
const double _minimum = 44;

void _big(WidgetTester tester, String key, {String? where}) {
  final finder = find.byKey(Key(key));
  expect(finder, findsOneWidget, reason: '$key${where == null ? '' : ' ($where)'}');
  final size = tester.getSize(finder);
  expect(size.width, greaterThanOrEqualTo(_minimum), reason: '$key is ${size.width} wide');
  expect(size.height, greaterThanOrEqualTo(_minimum), reason: '$key is ${size.height} high');
}

void main() {
  testWidgets('the home screen: its buttons and the bottom bar', (tester) async {
    final h = UiHarness(tester)..screen(360, 760);
    final alice = await h.node('Alice', onboarded: true, nickname: 'Alice');
    await h.show(alice);
    for (final key in ['search-toggle', 'open-people', 'nav-private', 'nav-groups', 'nav-public', 'nav-settings']) {
      _big(tester, key, where: 'home');
    }
    await h.dispose();
  });

  testWidgets('a private chat: header, composer, reply bar and selection', (tester) async {
    final h = UiHarness(tester)..screen(360, 760);
    final alice = await h.node('Alice', onboarded: true, nickname: 'Alice');
    final bob = await h.node('Bob', onboarded: true, nickname: 'Bob');
    await h.show(alice);
    await h.until(() => alice.directlyReaches(bob) && (alice.viewOf(bob)?.peer.canReceiveEncrypted ?? false));
    await h.real(() => bob.controller.sendDirect(alice.id, 'hello'));
    final withBob = Conversation.directId(bob.id);
    await h.until(() => find.byKey(Key('conversation-$withBob')).evaluate().isNotEmpty);
    await h.tap(find.byKey(Key('conversation-$withBob')));
    await h.until(() => find.text('hello').evaluate().isNotEmpty);
    expect(find.byType(ChatScreen), findsOneWidget);

    for (final key in ['header-back', 'chat-search', 'verify-contact', 'composer-attach', 'composer-mic']) {
      _big(tester, key, where: 'chat');
    }

    // The reply bar and its cross.
    await tester.longPress(find.text('hello').first);
    await h.settle();
    await h.tap(find.byKey(const Key('act-reply')));
    _big(tester, 'composer-target-cancel', where: 'reply bar');
    await h.tap(find.byKey(const Key('composer-target-cancel')));

    // Selecting.
    await tester.longPress(find.text('hello').first);
    await h.settle();
    await h.tap(find.byKey(const Key('act-select')));
    for (final key in ['selection-close', 'selection-forward', 'selection-delete', 'selection-more']) {
      _big(tester, key, where: 'selection bar');
    }
    await h.dispose();
  });

  testWidgets('the public room: header, note row, composer', (tester) async {
    final h = UiHarness(tester)..screen(360, 760);
    final alice = await h.node('Alice', onboarded: true, nickname: 'Alice');
    await h.show(alice, landing: true);
    await h.until(() => find.byType(RoomChat).evaluate().isNotEmpty);
    for (final key in [
      'room-label',
      'room-people',
      'room-nickname',
      'room-search',
      'composer-attach',
      'composer-mic',
    ]) {
      _big(tester, key, where: 'room');
    }
    await h.dispose();
  });
}
