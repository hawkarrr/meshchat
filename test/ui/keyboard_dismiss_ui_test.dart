import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_mesh_chat/models/conversation.dart';
import 'package:offline_mesh_chat/protocol/room_record.dart';

import '../support/ui_harness.dart';

/// Dragging a conversation puts the keyboard away, as in every messenger, so the person
/// can read what is above without reaching for the system's own button.
const String _mesh = 'rm:${PublicRooms.meshIdHex}';

bool _keyboardUp(WidgetTester tester) => tester
    .widget<EditableText>(find.descendant(
        of: find.byKey(const Key('composer-field')), matching: find.byType(EditableText)))
    .focusNode
    .hasFocus;

void main() {
  testWidgets('in the public room', (tester) async {
    // A short screen, so that a few lines are more than it holds and the list can be dragged.
    final h = UiHarness(tester)..screen(360, 420);
    final alice = await h.node('Alice', onboarded: true, nickname: 'Alice');
    await h.show(alice, landing: true);
    for (var i = 1; i <= 8; i++) {
      await h.real(() => alice.controller.sendText(_mesh, 'line number $i'));
    }
    await h.until(() => find.text('line number 8').evaluate().isNotEmpty);

    await tester.tap(find.byKey(const Key('composer-field')));
    await tester.pump();
    expect(_keyboardUp(tester), isTrue, reason: 'the person is writing');

    await tester.drag(find.byKey(const Key('message-list')), const Offset(0, 120));
    await tester.pump();
    expect(_keyboardUp(tester), isFalse, reason: 'dragging the room puts the keyboard away');
    expect(tester.takeException(), isNull);
    await h.dispose();
  });

  testWidgets('in a private chat', (tester) async {
    final h = UiHarness(tester)..screen(360, 420);
    final alice = await h.node('Alice', onboarded: true, nickname: 'Alice');
    final bob = await h.node('Bob', onboarded: true, nickname: 'Bob');
    await h.show(alice);
    await h.until(
        () => alice.directlyReaches(bob) && (alice.viewOf(bob)?.peer.canReceiveEncrypted ?? false));
    final withBob = Conversation.directId(bob.id);
    await h.real(() async {
      await alice.controller.openChat(bob.id);
      for (var i = 1; i <= 8; i++) {
        await alice.controller.sendText(withBob, 'note number $i');
      }
    });
    await h.until(() => find.byKey(Key('conversation-$withBob')).evaluate().isNotEmpty);
    await h.tap(find.byKey(Key('conversation-$withBob')));
    await h.until(() => find.text('note number 8').evaluate().isNotEmpty);

    await tester.tap(find.byKey(const Key('composer-field')));
    await tester.pump();
    expect(_keyboardUp(tester), isTrue);
    await tester.drag(find.byKey(const Key('message-list')), const Offset(0, 120));
    await tester.pump();
    expect(_keyboardUp(tester), isFalse, reason: 'dragging the chat puts the keyboard away');
    expect(tester.takeException(), isNull);
    await h.dispose();
  });
}
