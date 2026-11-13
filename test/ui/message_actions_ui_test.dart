import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_mesh_chat/models/conversation.dart';
import 'package:offline_mesh_chat/models/message.dart';
import 'package:offline_mesh_chat/protocol/room_record.dart';
import 'package:offline_mesh_chat/screens/chat_screen.dart';
import 'package:offline_mesh_chat/screens/room_screen.dart';
import 'package:offline_mesh_chat/theme/surfaces.dart';
import 'package:offline_mesh_chat/widgets/message_bubble.dart';

import '../support/app_harness.dart';
import '../support/ui_harness.dart';

const String _mesh = 'rm:${PublicRooms.meshIdHex}';

final Finder _field = find.byKey(const Key('composer-field'));

/// Two phones in range; Alice's screen shows her private chat with Bob.
class _Chat {
  _Chat(this.h, this.tester, this.alice, this.bob);

  final UiHarness h;
  final WidgetTester tester;
  final AppNode alice;
  final AppNode bob;

  String get conversation => Conversation.directId(bob.id);

  /// The same conversation as Bob sees it.
  String get bobsConversation => Conversation.directId(alice.id);

  bool _onRealLoop = false;

  Future<T> _real<T>(Future<T> Function() body) => _onRealLoop ? body() : h.real(body);

  /// Waits for a condition that reads the phones' databases. Inside it,
  /// [alicesMessages] and [bobsMessages] can be used directly.
  Future<void> untilAsync(Future<bool> Function() condition,
          {String? reason, int timeoutMs = 15000}) =>
      h.untilAsync(() async {
        _onRealLoop = true;
        try {
          return await condition();
        } finally {
          _onRealLoop = false;
        }
      }, reason: reason, timeoutMs: timeoutMs);

  Future<List<ChatMessage>> alicesMessages() =>
      _real(() => alice.controller.loadMessages(conversation));

  Future<List<ChatMessage>> bobsMessages() =>
      _real(() => bob.controller.loadMessages(bobsConversation));

  Future<void> bobHasCount(int n) => untilAsync(() async => (await bobsMessages()).length == n,
      reason: 'Bob should have $n message(s)');

  /// Waits until [text] is no longer on Alice's screen.
  Future<void> gone(String text) =>
      h.until(() => find.text(text).evaluate().isEmpty, reason: '"$text" should leave the screen');

  Future<void> type(String text) async {
    await tester.enterText(_field, text);
    await tester.pump();
  }

  /// Types [text] and presses send; waits until it shows in the chat.
  Future<void> say(String text) async {
    await type(text);
    await h.tap(find.byKey(const Key('composer-send')));
    await h.until(() => find.text(text).evaluate().isNotEmpty);
  }

  /// Bob writes to Alice; waits until it shows on her screen.
  Future<ChatMessage> bobSays(String text) async {
    final m = await h.real(() => bob.controller.sendDirect(alice.id, text));
    await h.until(() => find.text(text).evaluate().isNotEmpty, reason: 'Bob\'s "$text" should arrive');
    return m;
  }

  /// Press and hold [finder], then pick the action with this key suffix.
  Future<void> hold(Finder finder) async {
    await h.reveal(finder);
    await tester.longPress(finder);
    await h.settle();
  }

  Future<void> menu(String text, String action) async {
    await hold(find.text(text));
    await h.tap(find.byKey(Key('act-$action')));
  }
}

Future<_Chat> _openChat(WidgetTester tester) async {
  final h = UiHarness(tester)..screen();
  final alice = await h.node('Alice', onboarded: true, nickname: 'Alice');
  final bob = await h.node('Bob', onboarded: true, nickname: 'Bob');
  await h.show(alice);
  await h.until(
    () =>
        alice.directlyReaches(bob) &&
        bob.directlyReaches(alice) &&
        (alice.viewOf(bob)?.peer.canReceiveEncrypted ?? false),
    reason: 'Alice and Bob should find each other and swap keys',
  );
  await h.tap(find.byKey(Key('available-${bob.id}')));
  await h.until(() => find.byType(ChatScreen).evaluate().isNotEmpty);
  return _Chat(h, tester, alice, bob);
}

String _fieldText(WidgetTester tester) => (tester.widget(_field) as TextField).controller!.text;

void main() {
  group('the long-press menu', () {
    testWidgets('offers what fits the message: edit only for your own text', (tester) async {
      final c = await _openChat(tester);
      await c.say('my words');
      await c.bobSays('his words');

      await c.hold(find.text('my words'));
      for (final action in ['reply', 'copy', 'forward', 'pin', 'edit', 'select', 'details', 'delete']) {
        expect(find.byKey(Key('act-$action')), findsOneWidget, reason: action);
      }
      expect(find.byKey(const Key('message-menu')), findsOneWidget);
      await tester.tapAt(const Offset(180, 30)); // the dimmed area closes it
      await c.h.settle();
      expect(find.byKey(const Key('message-menu')), findsNothing);

      await c.hold(find.text('his words'));
      expect(find.byKey(const Key('act-reply')), findsOneWidget);
      expect(find.byKey(const Key('act-edit')), findsNothing, reason: 'only your own text');
      expect(find.byKey(const Key('act-delete')), findsOneWidget);

      expect(tester.takeException(), isNull);
      await c.h.dispose();
    });

    testWidgets('copy puts the text on the clipboard', (tester) async {
      final c = await _openChat(tester);
      final clipboard = c.h.recordClipboard();
      await c.bobSays('copy this please');
      await c.menu('copy this please', 'copy');
      expect(clipboard.text, 'copy this please');
      expect(find.text('Copied'), findsOneWidget);
      await c.h.dispose();
    });
  });

  group('reply', () {
    testWidgets('the answer quotes the question, and Bob receives it as an answer', (tester) async {
      final c = await _openChat(tester);
      final question = await c.bobSays('Lunch at noon?');

      await c.menu('Lunch at noon?', 'reply');
      expect(find.byKey(const Key('composer-reply-banner')), findsOneWidget);
      expect(find.text('Replying to Bob'), findsOneWidget);

      await c.say('Sounds good');
      expect(find.byKey(const Key('composer-reply-banner')), findsNothing, reason: 'sent: the banner goes');
      expect(find.byKey(const Key('quote-view')), findsOneWidget);
      expect(find.text('Lunch at noon?'), findsNWidgets(2), reason: 'the message and the quote of it');

      await c.bobHasCount(2);
      expect((await c.bobsMessages()).last.replyToId, question.id);
      await c.h.dispose();
    });

    testWidgets('cancelling leaves nothing behind', (tester) async {
      final c = await _openChat(tester);
      await c.bobSays('anything');
      await c.menu('anything', 'reply');
      await c.h.tap(find.byKey(const Key('composer-target-cancel')));
      expect(find.byKey(const Key('composer-reply-banner')), findsNothing);
      await c.say('plain message');
      expect(find.byKey(const Key('quote-view')), findsNothing);
      expect((await c.alicesMessages()).last.replyToId, isNull);
      await c.h.dispose();
    });

    testWidgets('a quote of a message that was deleted shows no content', (tester) async {
      final c = await _openChat(tester);
      final question = await c.bobSays('a secret question');
      await c.menu('a secret question', 'reply');
      await c.say('my answer');
      await c.bobHasCount(2);

      await c.h.real(() => c.bob.controller.deleteForEveryone(c.bobsConversation, [question.id]));
      await c.h.until(() => find.text('a secret question').evaluate().isEmpty,
          reason: 'Bob deleted it for everyone');

      expect(find.text('my answer'), findsOneWidget, reason: 'the answer stays');
      expect(find.text('Original message deleted'), findsOneWidget);
      expect(find.textContaining('secret'), findsNothing);
      await c.h.dispose();
    });
  });

  group('edit', () {
    testWidgets('the old text goes into the field, the new one replaces it on both phones',
        (tester) async {
      final c = await _openChat(tester);
      await c.say('helo wrld');

      await c.menu('helo wrld', 'edit');
      expect(find.byKey(const Key('composer-edit-banner')), findsOneWidget);
      expect(find.text('Edit message'), findsOneWidget);
      expect(_fieldText(tester), 'helo wrld');
      expect(tester.widget<RoundButton>(find.byKey(const Key('composer-attach'))).onPressed,
          isNull,
          reason: 'a picture cannot be added to an edit');

      await c.type('hello world');
      await c.h.tap(find.byKey(const Key('composer-send')));
      await c.h.until(() => find.text('hello world').evaluate().isNotEmpty);

      expect(find.text('helo wrld'), findsNothing);
      expect(find.byKey(const Key('edited-label')), findsOneWidget);
      expect(find.byKey(const Key('composer-edit-banner')), findsNothing);
      expect(_fieldText(tester), isEmpty);

      await c.untilAsync(() async => (await c.bobsMessages()).single.body == 'hello world',
          reason: 'Bob gets the edit');
      expect((await c.bobsMessages()).single.isEdited, isTrue);
      await c.h.dispose();
    });

    testWidgets('cancelling an edit puts nothing in the field and changes nothing', (tester) async {
      final c = await _openChat(tester);
      await c.say('keep me');
      await c.menu('keep me', 'edit');
      await c.h.tap(find.byKey(const Key('composer-target-cancel')));
      expect(_fieldText(tester), isEmpty);
      expect(find.byKey(const Key('composer-edit-banner')), findsNothing);
      expect(find.byKey(const Key('edited-label')), findsNothing);
      await c.h.dispose();
    });
  });

  group('delete', () {
    testWidgets('for me: gone here, still there on the other phone, and no placeholder',
        (tester) async {
      final c = await _openChat(tester);
      await c.say('delete me here');
      await c.bobHasCount(1);

      await c.menu('delete me here', 'delete');
      expect(find.text('Delete message?'), findsOneWidget);
      expect(find.byKey(const Key('delete-for-everyone')), findsOneWidget);
      await c.h.tap(find.byKey(const Key('delete-for-me')));
      await c.gone('delete me here');

      expect(find.byType(MessageBubble), findsNothing, reason: 'no placeholder bubble is left');
      expect(find.text('Deleted from this phone.'), findsOneWidget);
      expect(await c.alicesMessages(), isEmpty);
      expect((await c.bobsMessages()).single.body, 'delete me here');
      await c.h.dispose();
    });

    testWidgets('for everyone: the other phone removes it too, and the note is honest',
        (tester) async {
      final c = await _openChat(tester);
      await c.say('regret this');
      await c.bobHasCount(1);

      await c.menu('regret this', 'delete');
      await c.h.tap(find.byKey(const Key('delete-for-everyone')));
      await c.gone('regret this');

      expect(find.text('Deleted here. Other phones remove it when they receive the request.'),
          findsOneWidget);
      await c.untilAsync(() async => (await c.bobsMessages()).isEmpty,
          reason: 'the request reaches Bob');
      expect(await c.alicesMessages(), isEmpty);
      await c.h.dispose();
    });

    testWidgets("somebody else's message can only be deleted for me, and the dialog says why",
        (tester) async {
      final c = await _openChat(tester);
      await c.bobSays('his message');

      await c.menu('his message', 'delete');
      expect(find.byKey(const Key('delete-for-everyone')), findsNothing);
      expect(find.textContaining('only possible for your own messages'), findsOneWidget);
      await c.h.tap(find.byKey(const Key('delete-cancel')));
      expect(find.text('his message'), findsOneWidget, reason: 'cancelling deletes nothing');
      await c.h.dispose();
    });

    testWidgets('a delete request still waiting for the other phone is shown, not hidden',
        (tester) async {
      final c = await _openChat(tester);
      await c.say('will not be heard');
      await c.bobHasCount(1);
      c.h.world.setInRange(c.alice.phone, c.bob.phone, false);
      await c.h.until(() => !c.alice.directlyReaches(c.bob));

      await c.menu('will not be heard', 'delete');
      await c.h.tap(find.byKey(const Key('delete-for-everyone')));
      await c.gone('will not be heard');
      await c.h.until(() => find.byKey(const Key('deletion-status')).evaluate().isNotEmpty,
          reason: 'the strip says it is still waiting');
      expect(find.textContaining('Waiting for Bob\'s phone to confirm a deleted message'),
          findsOneWidget);
      expect((await c.bobsMessages()), hasLength(1), reason: 'Bob has not heard yet');

      c.h.world.setInRange(c.alice.phone, c.bob.phone, true);
      await c.untilAsync(() async => (await c.bobsMessages()).isEmpty, timeoutMs: 30000,
          reason: 'back in range, the request arrives');
      await c.h.until(() => find.byKey(const Key('deletion-status')).evaluate().isEmpty,
          timeoutMs: 30000, reason: 'and the strip goes away once Bob confirmed');
      await c.h.dispose();
    });
  });

  group('selecting several messages', () {
    testWidgets('select, count, deselect, bulk delete, and back leaves the selection first',
        (tester) async {
      final c = await _openChat(tester);
      await c.say('one');
      await c.bobSays('two');
      await c.say('three');

      await c.menu('one', 'select');
      expect(find.byKey(const Key('selection-count')), findsOneWidget);
      expect(find.text('1 selected'), findsOneWidget);
      expect(find.byKey(const Key('select-check-on')), findsOneWidget);
      expect(find.byKey(const Key('select-check-off')), findsNWidgets(2));

      await c.h.tap(find.text('two'));
      expect(find.text('2 selected'), findsOneWidget, reason: 'a tap now picks instead of opening details');
      await c.h.tap(find.text('two'));
      expect(find.text('1 selected'), findsOneWidget);
      await c.h.tap(find.text('three'));
      expect(find.text('2 selected'), findsOneWidget);

      // Back leaves the selection, not the chat.
      await tester.binding.handlePopRoute();
      await c.h.settle();
      expect(find.byType(ChatScreen), findsOneWidget);
      expect(find.byKey(const Key('selection-count')), findsNothing);
      expect(find.byKey(const Key('select-check-off')), findsNothing);

      await c.menu('one', 'select');
      await c.h.tap(find.text('three'));
      await c.h.tap(find.byKey(const Key('selection-delete')));
      expect(find.text('Delete 2 messages?'), findsOneWidget);
      await c.h.tap(find.byKey(const Key('delete-for-me')));
      await c.gone('one');
      await c.gone('three');
      expect(find.text('two'), findsOneWidget);
      expect(find.byKey(const Key('selection-count')), findsNothing);
      expect((await c.alicesMessages()).map((m) => m.body), ['two']);
      await c.h.dispose();
    });

    testWidgets('bulk copy joins the texts, with who said what', (tester) async {
      final c = await _openChat(tester);
      final clipboard = c.h.recordClipboard();
      await c.say('first');
      await c.bobSays('second');
      await c.menu('first', 'select');
      await c.h.tap(find.text('second'));
      await c.h.tap(find.byKey(const Key('selection-more')));
      await c.h.tap(find.byKey(const Key('sel-copy')));
      expect(clipboard.text, 'You: first\nBob: second');
      expect(find.byKey(const Key('selection-count')), findsNothing);
      await c.h.dispose();
    });
  });

  group('pins', () {
    testWidgets('pin shows a banner, the list unpins, and the other phone never knows',
        (tester) async {
      final c = await _openChat(tester);
      await c.say('remember this');
      await c.say('and this one');

      await c.menu('remember this', 'pin');
      await c.h.until(() => find.byKey(const Key('pinned-banner')).evaluate().isNotEmpty,
          reason: 'the banner appears');
      expect(find.descendant(of: find.byKey(const Key('pinned-banner')), matching: find.textContaining('remember this')),
          findsOneWidget);
      expect(find.text('Pinned message'), findsOneWidget);

      await c.menu('and this one', 'pin');
      await c.h.until(() => find.textContaining('Pinned message 1 of 2').evaluate().isNotEmpty);

      await c.h.tap(find.byKey(const Key('pinned-list-open')));
      expect(find.text('2 pinned messages'), findsOneWidget);
      final first = (await c.alicesMessages()).first;
      await c.h.tap(find.byKey(Key('pinned-unpin-${first.id}')));
      await c.h.until(() => find.text('1 pinned message').evaluate().isNotEmpty);
      expect(await c.h.real(() => c.bob.controller.pinnedMessages(c.bobsConversation)), isEmpty);
      await c.h.dispose();
    });

    testWidgets('a pinned message that is deleted leaves the banner', (tester) async {
      final c = await _openChat(tester);
      await c.say('pin and delete');
      await c.menu('pin and delete', 'pin');
      await c.h.until(() => find.byKey(const Key('pinned-banner')).evaluate().isNotEmpty,
          reason: 'the banner appears');
      await c.menu('pin and delete', 'delete');
      await c.h.tap(find.byKey(const Key('delete-for-me')));
      await c.h.until(() => find.byKey(const Key('pinned-banner')).evaluate().isEmpty);
      await c.h.dispose();
    });
  });

  group('forward', () {
    testWidgets('to a public room: asks first, then sends it under the first author\'s name',
        (tester) async {
      final c = await _openChat(tester);
      await c.bobSays('worth sharing');

      await c.menu('worth sharing', 'forward');
      expect(find.text('Forward to…'), findsOneWidget);
      expect(find.byKey(Key('forward-target-${c.conversation}')), findsOneWidget);
      await c.h.tap(find.byKey(const Key('forward-target-$_mesh')));
      expect(find.text('Forward to a public room?'), findsOneWidget);
      await c.h.tap(find.byKey(const Key('confirm-action')));

      await c.untilAsync(
          () async => (await c.alice.controller.loadMessages(_mesh)).isNotEmpty,
          reason: 'the forward is sent to the room');
      final sent = (await c.h.real(() => c.alice.controller.loadMessages(_mesh))).single;
      expect([sent.body, sent.forwardedFrom, sent.replyToId], ['worth sharing', 'Bob', null]);
      await c.h.until(() => find.textContaining('Forwarded to #mesh').evaluate().isNotEmpty,
          reason: 'the person is told');
      await c.h.dispose();
    });

    testWidgets('a forwarded message says where it came from', (tester) async {
      final c = await _openChat(tester);
      await c.bobSays('original words');
      await c.menu('original words', 'forward');
      await c.h.tap(find.byKey(Key('forward-target-${c.conversation}')));
      await c.h.until(() => find.byKey(const Key('forwarded-label')).evaluate().isNotEmpty,
          reason: 'forwarded into the same chat');
      expect(find.text('Forwarded from Bob'), findsOneWidget);
      expect(find.text('original words'), findsNWidgets(2));
      await c.h.dispose();
    });

    testWidgets('the search narrows the list of chats', (tester) async {
      final c = await _openChat(tester);
      await c.bobSays('anything');
      await c.menu('anything', 'forward');
      await tester.enterText(find.byKey(const Key('forward-search')), 'zzz');
      await tester.pump();
      expect(find.byKey(Key('forward-target-${c.conversation}')), findsNothing);
      expect(find.textContaining('No chat matches'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('forward-search')), 'bob');
      await tester.pump();
      expect(find.byKey(Key('forward-target-${c.conversation}')), findsOneWidget);
      await c.h.dispose();
    });
  });

  group('details', () {
    testWidgets('tell about edits, replies and forwards', (tester) async {
      final c = await _openChat(tester);
      await c.bobSays('the question');
      await c.menu('the question', 'reply');
      await c.say('the answer');
      await c.menu('the answer', 'edit');
      await c.type('the better answer');
      await c.h.tap(find.byKey(const Key('composer-send')));
      await c.h.until(() => find.text('the better answer').evaluate().isNotEmpty);

      await c.menu('the better answer', 'details');
      expect(find.byKey(const Key('message-details')), findsOneWidget);
      expect(find.byKey(const Key('detail-edited')), findsOneWidget);
      expect(find.byKey(const Key('detail-reply')), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('detail-reply'))).data, contains('the question'));
      expect(find.byKey(const Key('detail-expires')), findsNothing, reason: 'private chats do not expire');
      await c.h.dispose();
    });
  });

  group('search', () {
    testWidgets('finds a message, filters by kind, and jumps back to it', (tester) async {
      final c = await _openChat(tester);
      await c.say('weekend plans');
      await c.bobSays('lunch on saturday?');
      await c.say('sounds good');

      await c.h.tap(find.byKey(const Key('chat-search')));
      expect(find.text('Search this chat'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('search-field')), 'LUNCH');
      await c.h.settle();
      final results = await c.alicesMessages();
      final hit = results.firstWhere((m) => m.body.contains('lunch'));
      expect(find.byKey(Key('search-result-${hit.id}')), findsOneWidget);
      expect(find.byKey(Key('search-result-${results.first.id}')), findsNothing);

      await tester.enterText(find.byKey(const Key('search-field')), 'zzzz');
      await c.h.settle();
      expect(find.text('Nothing found'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('search-field')), '');
      await c.h.tap(find.byKey(const Key('search-filter-mine')));
      expect(find.byKey(Key('search-result-${results.first.id}')), findsOneWidget);
      expect(find.byKey(Key('search-result-${hit.id}')), findsNothing, reason: 'that one is Bob\'s');

      await c.h.tap(find.byKey(Key('search-result-${results.first.id}')));
      expect(find.byType(ChatScreen), findsOneWidget);
      expect(find.byKey(const Key('search-field')), findsNothing);
      await c.h.dispose();
    });
  });

  group('the public room', () {
    Future<(UiHarness, AppNode, AppNode)> openRoom(WidgetTester tester) async {
      final h = UiHarness(tester)..screen();
      final alice = await h.node('Alice', onboarded: true, nickname: 'Alice');
      final bob = await h.node('Bob', onboarded: true, nickname: 'Bob');
      await h.show(alice, landing: true);
      await h.until(() => find.byType(RoomChat).evaluate().isNotEmpty);
      await h.until(() => alice.directlyReaches(bob) && bob.directlyReaches(alice), timeoutMs: 20000);
      return (h, alice, bob);
    }

    Finder line(String text) => find.text(text);

    testWidgets('says that messages disappear after six hours', (tester) async {
      final (h, _, _) = await openRoom(tester);
      expect(find.byKey(const Key('room-expiry-note')), findsOneWidget);
      expect(find.textContaining('disappear after 6 hours'), findsOneWidget);
      await h.dispose();
    });

    testWidgets('long press, reply and pin work on a line, and delete for everyone reaches the others',
        (tester) async {
      final (h, alice, bob) = await openRoom(tester);
      await h.real(() => bob.controller.sendText(_mesh, 'anyone for coffee?'));
      await h.until(() => line('anyone for coffee?').evaluate().isNotEmpty);

      await tester.longPress(line('anyone for coffee?'));
      await h.settle();
      expect(find.byKey(const Key('message-menu')), findsOneWidget);
      expect(find.byKey(const Key('act-edit')), findsNothing, reason: 'it is Bob\'s');
      await h.tap(find.byKey(const Key('act-reply')));
      expect(find.text('Replying to Bob'), findsOneWidget);
      await tester.enterText(_field, 'yes please');
      await tester.pump();
      await h.tap(find.byKey(const Key('composer-send')));
      await h.until(() => line('yes please').evaluate().isNotEmpty);
      expect(find.byKey(const Key('quote-view')), findsOneWidget);

      // Pin Alice's own line, then delete it for everyone.
      await tester.longPress(line('yes please'));
      await h.settle();
      await h.tap(find.byKey(const Key('act-pin')));
      await h.until(() => find.byKey(const Key('pinned-banner')).evaluate().isNotEmpty,
          reason: 'the banner appears');
      await h.untilAsync(
          () async => (await bob.controller.loadMessages(_mesh)).any((m) => m.body == 'yes please'),
          reason: 'Bob has Alice\'s answer');

      // The pinned banner quotes the line too: the line itself is the last match.
      await tester.longPress(line('yes please').last);
      await h.settle();
      await h.tap(find.byKey(const Key('act-delete')));
      expect(find.textContaining('every phone nearby'), findsOneWidget);
      await h.tap(find.byKey(const Key('delete-for-everyone')));
      await h.until(() => line('yes please').evaluate().isEmpty, reason: 'gone from this phone');
      await h.untilAsync(
          () async => !(await bob.controller.loadMessages(_mesh)).any((m) => m.body == 'yes please'),
          reason: 'the request reaches Bob');
      expect(find.byKey(const Key('pinned-banner')), findsNothing);
      expect((await h.real(() => alice.controller.loadMessages(_mesh))).map((m) => m.body),
          ['anyone for coffee?']);
      await h.dispose();
    });
  });
}
