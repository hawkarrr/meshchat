import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_mesh_chat/l10n/l10n.dart';
import 'package:offline_mesh_chat/models/conversation.dart';
import 'package:offline_mesh_chat/models/message.dart';
import 'package:offline_mesh_chat/protocol/room_record.dart';
import 'package:offline_mesh_chat/screens/chat_screen.dart';
import 'package:offline_mesh_chat/screens/room_screen.dart' show PublicLine, RoomChat, publicLineOpacity;
import 'package:offline_mesh_chat/theme/app_theme.dart';
import 'package:offline_mesh_chat/theme/motion.dart';
import 'package:offline_mesh_chat/widgets/empty_state.dart';
import 'package:offline_mesh_chat/widgets/ghost_mark.dart';
import 'package:offline_mesh_chat/widgets/message_bubble.dart' show SelectCheck;
import 'package:offline_mesh_chat/widgets/reveal.dart';

import '../support/ui_harness.dart';

Widget _app(Widget child, {bool reduceMotion = false}) => MaterialApp(
      // The colours come from the theme, so the app's own is what the pieces are drawn in.
      theme: buildAppTheme(),
      localizationsDelegates: AppLanguage.delegates,
      supportedLocales: AppLanguage.supportedLocales,
      locale: const Locale('en'),
      builder: (context, app) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: app!,
      ),
      home: Scaffold(body: Center(child: child)),
    );

/// The little ghost and the movement that goes with it: where it appears, what its
/// face says, and that every bit of motion gives way to "remove animations".
void main() {
  group('the ghost itself', () {
    testWidgets('every mood is drawn at every size without a problem', (tester) async {
      await tester.pumpWidget(_app(Wrap(
        children: [
          for (final mood in GhostMood.values)
            for (final size in [16.0, 24.0, 40.0, 96.0, 160.0]) GhostMark(size: size, mood: mood),
        ],
      )));
      expect(find.byType(GhostMark), findsNWidgets(GhostMood.values.length * 5));
      expect(tester.takeException(), isNull);
    });

    testWidgets('is decoration unless it is given something to say', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_app(const GhostMark()));
      expect(find.bySemanticsLabel('A ghost'), findsNothing);
      await tester.pumpWidget(_app(const GhostMark(semanticLabel: 'A ghost')));
      expect(find.bySemanticsLabel('A ghost'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('floats only when asked, and not at all when the system asks for less motion',
        (tester) async {
      await tester.pumpWidget(_app(const GhostMark()));
      expect(tester.binding.transientCallbackCount, 0, reason: 'a small ghost stands still');

      await tester.pumpWidget(_app(const GhostMark(float: true)));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.binding.transientCallbackCount, greaterThan(0), reason: 'a large one bobs');

      await tester.pumpWidget(_app(const GhostMark(float: true), reduceMotion: true));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.binding.transientCallbackCount, 0, reason: 'remove animations: no movement');
    });
  });

  group('empty places', () {
    testWidgets('a new phone: the lists have a sleeping ghost, a search that finds nothing a sheepish one',
        (tester) async {
      final h = UiHarness(tester)..screen();
      final alice = await h.node('Alice', onboarded: true, nickname: 'Alice');
      await h.show(alice);

      // The home screen keeps every tab; the one on screen is the one that can be hit.
      EmptyState shown() => tester.widget<EmptyState>(find.byType(EmptyState).hitTestable());
      expect(shown().mood, GhostMood.sleepy);
      expect(find.descendant(of: find.byType(EmptyState).hitTestable(), matching: find.byType(GhostMark)),
          findsOneWidget);

      await h.tap(find.byKey(const Key('search-toggle')));
      await tester.enterText(find.byKey(const Key('search-field')), 'zzz');
      await h.settle();
      expect(shown().mood, GhostMood.oops);
      expect(tester.takeException(), isNull);
      await h.dispose();
    });

    testWidgets('an empty security log has a pleased one', (tester) async {
      final h = UiHarness(tester)..screen();
      final alice = await h.node('Alice', onboarded: true, nickname: 'Alice');
      await h.show(alice);
      await h.openSettingsPage('privacy');
      await h.reveal(find.text('Security log'));
      await h.tap(find.text('Security log'));
      await h.until(() => find.byType(EmptyState).hitTestable().evaluate().isNotEmpty);
      expect(tester.widget<EmptyState>(find.byType(EmptyState).hitTestable()).mood, GhostMood.happy);
      await h.dispose();
    });
  });

  group('the first page of a chat', () {
    testWidgets('greets the other person, then gives way to the first message', (tester) async {
      final h = UiHarness(tester)..screen();
      final alice = await h.node('Alice', onboarded: true, nickname: 'Alice');
      final bob = await h.node('Bob', onboarded: true, nickname: 'Bob');
      await h.show(alice);
      await h.until(
          () => alice.directlyReaches(bob) && (alice.viewOf(bob)?.peer.canReceiveEncrypted ?? false));
      await h.tap(find.byKey(Key('available-${bob.id}')));
      await h.until(() => find.byType(ChatScreen).evaluate().isNotEmpty);
      await h.until(() => find.byKey(const Key('chat-intro')).evaluate().isNotEmpty);

      expect(find.text('Say hello to Bob'), findsOneWidget);
      expect(find.textContaining('No messages yet'), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('chat-intro')), matching: find.byType(GhostMark)),
          findsOneWidget);

      await h.real(() => alice.controller.sendDirect(bob.id, 'hi Bob'));
      await h.until(() => find.text('hi Bob').evaluate().isNotEmpty);
      expect(find.byKey(const Key('chat-intro')), findsNothing, reason: 'the first message ends it');
      await h.dispose();
    });

    testWidgets('a group has its own greeting', (tester) async {
      final h = UiHarness(tester)..screen();
      final alice = await h.node('Alice', onboarded: true, nickname: 'Alice');
      final bob = await h.node('Bob', onboarded: true, nickname: 'Bob');
      await h.show(alice);
      await h.until(
          () => alice.directlyReaches(bob) && (alice.viewOf(bob)?.peer.canReceiveEncrypted ?? false));
      final group = await h.real(() => alice.controller.createGroup('Hikers', [bob.id]));
      await h.goToTab('Groups');
      await h.tap(find.byKey(Key('conversation-${Conversation.groupConversationId(group.id)}')));
      await h.until(() => find.byKey(const Key('chat-intro')).evaluate().isNotEmpty);
      expect(find.text('Welcome to Hikers'), findsOneWidget);
      await h.dispose();
    });
  });

  group('the public room', () {
    testWidgets('has a ghost beside its note about the six hours', (tester) async {
      final h = UiHarness(tester)..screen();
      final alice = await h.node('Alice', onboarded: true, nickname: 'Alice');
      await h.show(alice, landing: true);
      await h.until(() => find.byKey(const Key('room-expiry-note')).evaluate().isNotEmpty);
      final note = tester.getRect(find.byKey(const Key('room-expiry-note')));
      final ghost = tester.getRect(
          find.descendant(of: find.byType(RoomChat), matching: find.byType(GhostMark)).first);
      expect(ghost.center.dy, closeTo(note.center.dy, 12), reason: 'on the same line');
      expect(ghost.right, lessThanOrEqualTo(note.left), reason: 'in front of the words');
      await h.dispose();
    });

    test('a line is whole until its last hour, then fades towards one half', () {
      const hour = 60 * 60 * 1000;
      const now = 1000 * hour;
      expect(publicLineOpacity(now, null), 1);
      expect(publicLineOpacity(now, now + 5 * hour), 1);
      expect(publicLineOpacity(now, now + hour), 1);
      expect(publicLineOpacity(now, now + hour ~/ 2), closeTo(0.75, 0.001));
      expect(publicLineOpacity(now, now), closeTo(0.5, 0.001));
      expect(publicLineOpacity(now, now - hour), 0.5, reason: 'overdue lines are about to go');
    });

    testWidgets('a line in its last hour is drawn fainter, a selected one whole', (tester) async {
      final h = UiHarness(tester)..screen();
      final alice = await h.node('Alice', onboarded: true, nickname: 'Alice');
      await h.show(alice);
      const hour = 60 * 60 * 1000;
      final message = ChatMessage(
        id: 'aa' * 16,
        conversationId: 'rm:${PublicRooms.meshIdHex}',
        senderId: 'bb' * 32,
        senderNickname: 'Bob',
        isOutgoing: false,
        kind: MessageKind.text,
        body: 'is anyone there?',
        sortTimeMs: 10 * hour,
        claimedTimestampMs: 10 * hour,
        status: MessageStatus.received,
        expiresAtMs: 16 * hour,
      );

      Widget line({required int now, bool selected = false}) => _app(PublicLine(
            message: message,
            media: null,
            controller: alice.controller,
            nowMs: now,
            selecting: selected,
            selected: selected,
          ));
      Finder fade() => find.descendant(of: find.byType(PublicLine), matching: find.byType(Opacity));

      await tester.pumpWidget(line(now: 12 * hour));
      expect(fade(), findsNothing);

      await tester.pumpWidget(line(now: 15 * hour + hour ~/ 2));
      expect(tester.widget<Opacity>(fade()).opacity, closeTo(0.75, 0.001));

      await tester.pumpWidget(line(now: 15 * hour + hour ~/ 2, selected: true));
      expect(fade(), findsNothing, reason: 'what is chosen must be readable');
      await h.dispose();
    });
  });

  group('movement', () {
    // Pinned to the top, so what is under the bar moves by exactly the bar's height.
    Widget bar({required bool show, bool reduceMotion = false}) => _app(
          Align(
            alignment: Alignment.topCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Reveal(show: show, child: const SizedBox(key: Key('bar'), height: 60, width: 200)),
                const SizedBox(key: Key('below'), height: 10, width: 200),
              ],
            ),
          ),
          reduceMotion: reduceMotion,
        );
    double below(WidgetTester tester) => tester.getTopLeft(find.byKey(const Key('below'))).dy;

    testWidgets('a bar opens and closes: the space goes through the sizes in between', (tester) async {
      await tester.pumpWidget(bar(show: false));
      final top = below(tester);

      await tester.pumpWidget(bar(show: true));
      await tester.pump(const Duration(milliseconds: 60));
      expect(below(tester), greaterThan(top));
      expect(below(tester), lessThan(top + 60), reason: 'still opening');
      await tester.pump(AppMotion.enter);
      expect(below(tester), top + 60);

      await tester.pumpWidget(bar(show: false));
      await tester.pump(const Duration(milliseconds: 40));
      expect(find.byKey(const Key('bar')), findsOneWidget, reason: 'still on its way out');
      await tester.pump(AppMotion.exit + const Duration(milliseconds: 50));
      expect(find.byKey(const Key('bar')), findsNothing);
      expect(below(tester), top);
    });

    testWidgets('going out is quicker than coming in', (tester) async {
      expect(AppMotion.exit, lessThan(AppMotion.enter));
      expect(AppMotion.press, lessThan(AppMotion.exit));
    });

    testWidgets('with "remove animations" it is there and gone at once', (tester) async {
      await tester.pumpWidget(bar(show: false, reduceMotion: true));
      final top = below(tester);
      await tester.pumpWidget(bar(show: true, reduceMotion: true));
      expect(below(tester), top + 60);
      await tester.pumpWidget(bar(show: false, reduceMotion: true));
      expect(find.byKey(const Key('bar')), findsNothing);
      expect(below(tester), top);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the tick of a selected message fills in within a tenth of a second', (tester) async {
      Widget tick({required bool on, bool reduceMotion = false}) =>
          _app(SelectCheck(selected: on), reduceMotion: reduceMotion);
      Color fill() => (tester
              .widget<DecoratedBox>(
                  find.descendant(of: find.byType(SelectCheck), matching: find.byType(DecoratedBox)).first)
              .decoration as BoxDecoration)
          .color!;

      await tester.pumpWidget(tick(on: false));
      expect(find.byKey(const Key('select-check-off')), findsOneWidget);
      expect(fill().a, 0, reason: 'empty circle');

      await tester.pumpWidget(tick(on: true));
      expect(find.byKey(const Key('select-check-on')), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 30));
      expect(fill().a, inExclusiveRange(0, 1), reason: 'on its way');
      await tester.pump(AppMotion.press);
      expect(fill(), AppPalette.dark.accent, reason: 'full');

      await tester.pumpWidget(tick(on: false, reduceMotion: true));
      await tester.pump();
      expect(fill().a, 0, reason: 'remove animations: no in-between');
    });
  });
}
