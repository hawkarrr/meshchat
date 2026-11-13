import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:offline_mesh_chat/app.dart';
import 'package:offline_mesh_chat/core/bidi.dart';
import 'package:offline_mesh_chat/device/device_io.dart';
import 'package:offline_mesh_chat/l10n/l10n.dart';
import 'package:offline_mesh_chat/models/message.dart';
import 'package:offline_mesh_chat/protocol/room_record.dart';
import 'package:offline_mesh_chat/screens/room_screen.dart';
import 'package:offline_mesh_chat/widgets/empty_state.dart';
import 'package:offline_mesh_chat/widgets/skeleton.dart';

import '../support/app_harness.dart';
import '../support/ui_harness.dart';

const String _mesh = 'rm:${PublicRooms.meshIdHex}';

Uint8List _photo() {
  final image = img.Image(width: 320, height: 240, numChannels: 3);
  for (final p in image) {
    p
      ..r = (p.x * 255 ~/ 320)
      ..g = (p.y * 255 ~/ 240)
      ..b = ((p.x + p.y) * 90 ~/ 560 + (p.x * 7 + p.y * 13) % 40);
  }
  return Uint8List.fromList(img.encodeJpg(image, quality: 90));
}

/// A message of the room, found by its text: the words of one bubble.
Finder _line(String text) => find.text(text);

/// The name above a message, with the first characters of the writer's id: "Bob #79e2".
Finder _author(String name, String shortId) => find.byWidgetPredicate(
      (w) =>
          w is RichText &&
          w.text.toPlainText().replaceAll(RegExp('[$leftToRightIsolate$isolateEnd]'), '') ==
              '$name #$shortId',
      description: 'the name "$name #$shortId"',
    );

final Finder _field = find.byKey(const Key('composer-field'));

/// The public room is the first place of the bar: the app opens on it.
Future<void> _openMesh(UiHarness h) async {
  await h.openTab('public');
  await h.until(() => find.byKey(const Key('room-label')).evaluate().isNotEmpty);
}

Future<void> _say(WidgetTester tester, UiHarness h, String text) async {
  await tester.enterText(_field, text);
  await tester.pump();
  await h.tap(find.byKey(const Key('composer-send')));
}

Future<void> _meet(UiHarness h, AppNode a, AppNode b) => h.until(
      () => a.directlyReaches(b) && b.directlyReaches(a),
      timeoutMs: 20000,
      reason: '${a.name} and ${b.name} should find each other',
    );

/// The room as the first place of the home screen, with its header, its messages as
/// bubbles and the field below.
void main() {
  group('the public room is a chat', () {
    testWidgets('header, the line about six hours, the empty room, and the field with its buttons',
        (tester) async {
      final h = UiHarness(tester)..screen();
      final alice = await h.node('Alice', onboarded: true, nickname: 'Alice');
      await h.show(alice, landing: true);

      // The room's name (it opens the list of rooms), how we are connected, how many
      // phones are around, and search.
      expect(find.descendant(of: find.byKey(const Key('room-label')), matching: find.text('#mesh')),
          findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('room-connection')), matching: find.text('Searching…')),
          findsOneWidget, reason: 'nobody is around yet');
      expect(find.byTooltip('Searching…'), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('room-people')), matching: find.text('0')),
          findsOneWidget);
      expect(find.byKey(const Key('room-search')), findsOneWidget);
      expect(find.byKey(const Key('header-back')), findsNothing, reason: 'it is a place, not a page');

      // What makes this room different: what is said fades away; and the name it is said under.
      expect(find.byKey(const Key('room-expiry-note')), findsOneWidget);
      expect(find.text('@Alice'), findsOneWidget);

      // No message yet: the empty room says so, and says plainly that this is public.
      await h.until(() => find.byKey(const Key('room-empty')).evaluate().isNotEmpty);
      expect(find.text('No messages yet'), findsOneWidget);
      expect(find.textContaining('Whatever you write is public'), findsOneWidget);
      expect(find.byKey(const Key('chat-skeleton')), findsNothing);

      // The field: the hint, a paperclip and a microphone. No globe: the name is the list.
      expect(find.text('Message #mesh · public'), findsOneWidget);
      expect(find.byKey(const Key('composer-attach')), findsOneWidget);
      expect(find.byKey(const Key('composer-mic')), findsOneWidget);
      expect(find.byKey(const Key('composer-globe')), findsNothing);

      expect(tester.takeException(), isNull);
      await h.dispose();
    });

    testWidgets('a grey skeleton stands in for the messages until they are read', (tester) async {
      final h = UiHarness(tester)..screen();
      final alice = await h.node('Alice', onboarded: true, nickname: 'Alice');
      await tester.pumpWidget(DamataqeApp(controller: alice.controller));
      await tester.pump();
      expect(find.byKey(const Key('chat-skeleton')), findsOneWidget, reason: 'the first frame');
      expect(find.byType(EmptyState), findsNothing);

      await h.until(() => find.byKey(const Key('room-empty')).evaluate().isNotEmpty);
      expect(find.byKey(const Key('chat-skeleton')), findsNothing, reason: 'replaced by the room');
      expect(find.byType(SkeletonPulse), findsNothing);
      await h.dispose();
    });

    testWidgets('the header shows how many phones are around, live', (tester) async {
      final h = UiHarness(tester)..screen();
      final alice = await h.node('Alice', onboarded: true, nickname: 'Alice');
      final bob = await h.node('Bob', onboarded: true, nickname: 'Bob');
      await h.show(alice);
      await _openMesh(h);

      await _meet(h, alice, bob);
      expect(find.byTooltip('1 nearby'), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('room-people')), matching: find.text('1')),
          findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('room-connection')), matching: find.text('1 nearby')),
          findsOneWidget);

      h.world.setInRange(alice.phone, bob.phone, false);
      await h.until(() => find.byTooltip('1 nearby').evaluate().isEmpty,
          reason: 'out of range: the indicator follows');
      expect(find.descendant(of: find.byKey(const Key('room-people')), matching: find.text('0')),
          findsOneWidget);

      // Tapping the count opens the Nearby screen.
      await h.tap(find.byKey(const Key('room-people')));
      expect(find.text('Visible to others'), findsOneWidget);

      expect(tester.takeException(), isNull);
      await h.dispose();
    });

    testWidgets('messages are bubbles: yours on the right in blue, theirs on the left with a name',
        (tester) async {
      final h = UiHarness(tester)..screen();
      final alice = await h.node('Alice', onboarded: true, nickname: 'Alice');
      final bob = await h.node('Bob', onboarded: true, nickname: 'Bob');
      await h.show(alice);
      await _meet(h, alice, bob);
      await _openMesh(h);

      await _say(tester, h, 'hello everyone');
      await h.until(() => _line('hello everyone').evaluate().isNotEmpty);
      expect(find.byKey(const Key('room-empty')), findsNothing, reason: 'the first message ends it');
      expect((tester.widget(_field) as TextField).controller!.text, isEmpty);
      expect(tester.getCenter(_line('hello everyone')).dx, greaterThan(180), reason: 'on the right');

      // Bob (also in #mesh) receives it, and answers.
      await h.untilAsync(() async {
        final theirs = await bob.controller.loadMessages(_mesh);
        return theirs.any((m) => m.body == 'hello everyone' && m.senderNickname == 'Alice');
      }, reason: 'Bob should see Alice\'s message');
      await h.real(() => bob.controller.sendText(_mesh, 'hi from Bob'));
      final shortId = bob.id.substring(0, 4);
      await h.until(() => _line('hi from Bob').evaluate().isNotEmpty);
      expect(_author('Bob', shortId), findsOneWidget,
          reason: 'other people\'s messages carry the start of their id, as names are not unique');
      expect(tester.getCenter(_line('hi from Bob')).dx, lessThan(180), reason: 'on the left');
      expect(find.text('Today'), findsOneWidget, reason: 'the day, once');

      expect(tester.takeException(), isNull);
      await h.dispose();
    });

    testWidgets('tapping the name changes it for everything written afterwards', (tester) async {
      final h = UiHarness(tester)..screen();
      final alice = await h.node('Alice', onboarded: true, nickname: 'Alice');
      await h.show(alice);
      await _openMesh(h);

      await h.tap(find.byKey(const Key('room-nickname')));
      expect(find.text('Your name here'), findsOneWidget);
      expect(find.textContaining('not unique'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('nickname-field')), 'Zed');
      await tester.pump();
      await h.tap(find.byKey(const Key('nickname-save')));
      await h.until(() => find.text('@Zed').evaluate().isNotEmpty);
      expect(alice.controller.nickname, 'Zed');

      await _say(tester, h, 'new name, same me');
      await h.until(() => _line('new name, same me').evaluate().isNotEmpty);
      final mine = await h.real(() => alice.controller.loadMessages(_mesh));
      expect(mine.single.isOutgoing, isTrue);

      // Backing out changes nothing.
      await h.tap(find.byKey(const Key('room-nickname')));
      await h.tap(find.text('Cancel'));
      expect(alice.controller.nickname, 'Zed');

      expect(tester.takeException(), isNull);
      await h.dispose();
    });
  });

  group('rooms', () {
    testWidgets('the name lists the rooms; a new room can be created and opens at once',
        (tester) async {
      final h = UiHarness(tester)..screen();
      final alice = await h.node('Alice', onboarded: true, nickname: 'Alice');
      await h.show(alice);
      await _openMesh(h);

      await h.tap(find.byKey(const Key('room-label')));
      expect(find.text('Public rooms'), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget, reason: 'the current room is ticked');
      expect(find.byKey(const Key('rooms-listening')), findsOneWidget,
          reason: 'no other room around yet: the sheet says it is listening');
      await h.tap(find.byKey(const Key('rooms-create')));
      expect(find.text('Create a public room'), findsOneWidget);
      expect(find.textContaining('not private'), findsOneWidget);

      // A name is needed.
      await h.tap(find.byKey(const Key('room-create')));
      expect(find.text('Give the room a name.'), findsOneWidget);
      expect(find.text('Create a public room'), findsOneWidget, reason: 'still open');

      await tester.enterText(find.byKey(const Key('room-name')), 'hikers');
      await tester.enterText(find.byKey(const Key('room-description')), 'weekend trails');
      await tester.pump();
      await h.tap(find.byKey(const Key('room-create')));
      await h.until(() => find.text('Message #hikers · public').evaluate().isNotEmpty);

      // The same place now shows the new room.
      expect(find.byType(RoomChat), findsOneWidget);
      expect(find.byType(RoomScreen), findsNothing, reason: 'it did not open a page of its own');
      expect(find.descendant(of: find.byKey(const Key('room-label')), matching: find.text('#hikers')),
          findsOneWidget);
      final room = alice.controller.roomsListenable.value.firstWhere((r) => r.name == 'hikers');
      expect(room.joined, isTrue);
      expect(room.description, 'weekend trails');

      await _say(tester, h, 'first!');
      await h.until(() => _line('first!').evaluate().isNotEmpty);

      // Back to #mesh through the list: both rooms are in it; the new one can be left.
      await h.tap(find.byKey(const Key('room-label')));
      expect(find.byKey(Key('leave-${room.id}')), findsNothing, reason: 'the open room is not left');
      await h.tap(find.text('#mesh').last);
      await h.until(() => find.text('Message #mesh · public').evaluate().isNotEmpty);
      await h.tap(find.byKey(const Key('room-label')));
      expect(find.byKey(Key('leave-${room.id}')), findsOneWidget);
      expect(find.byKey(Key('leave-$_mesh')), findsNothing, reason: '#mesh is for everyone and cannot be left');
      await tester.tapAt(const Offset(180, 40)); // the dimmed page behind the sheet
      await h.settle();

      expect(tester.takeException(), isNull);
      await h.dispose();
    });

    testWidgets('a room created by someone nearby is under "Nearby rooms" and can be joined and left',
        (tester) async {
      final h = UiHarness(tester)..screen();
      final alice = await h.node('Alice', onboarded: true, nickname: 'Alice');
      final bob = await h.node('Bob', onboarded: true, nickname: 'Bob');
      await h.show(alice);
      await _meet(h, alice, bob);
      await _openMesh(h);
      await h.tap(find.byKey(const Key('room-label')));
      expect(find.textContaining('Listening for rooms'), findsOneWidget);

      final chess = await h.real(() => bob.controller.createRoom('chess', description: 'blitz and bullet'));
      await h.until(() => find.byKey(Key('join-${chess.id}')).evaluate().isNotEmpty,
          timeoutMs: 20000, reason: 'the room announcement reaches Alice');
      expect(find.text('#chess'), findsOneWidget);
      expect(find.textContaining('blitz and bullet'), findsOneWidget);
      expect(find.textContaining('Listening for rooms'), findsNothing);

      await h.tap(find.byKey(Key('join-${chess.id}')));
      await h.until(() => find.text('Message #chess · public').evaluate().isNotEmpty);
      await _say(tester, h, 'anyone for a game?');
      await h.untilAsync(() async {
        final theirs = await bob.controller.loadMessages('rm:${chess.id}');
        return theirs.any((m) => m.body == 'anyone for a game?');
      }, reason: 'Bob receives it in the room he created');
      await h.real(() => bob.controller.sendText('rm:${chess.id}', 'always'));
      await h.until(() => _line('always').evaluate().isNotEmpty);

      // Joined rooms are in the list, and can be left (the built-in one cannot).
      await h.tap(find.byKey(const Key('room-label')));
      expect(find.byKey(Key('join-${chess.id}')), findsNothing);
      await h.tap(find.text('#mesh').last);
      await h.until(() => find.text('Message #mesh · public').evaluate().isNotEmpty);
      await h.tap(find.byKey(const Key('room-label')));
      await h.tap(find.byKey(Key('leave-${chess.id}')));
      expect(find.text('Leave #chess?'), findsOneWidget);
      await h.tap(find.byKey(const Key('confirm-action')));
      await h.until(() => find.byKey(Key('leave-${chess.id}')).evaluate().isEmpty);
      expect(find.byKey(Key('join-${chess.id}')), findsOneWidget,
          reason: 'still around, so it can be joined again');

      expect(tester.takeException(), isNull);
      await h.dispose();
    });

    testWidgets('a room that this phone has left is no longer shown: back to #mesh', (tester) async {
      final h = UiHarness(tester)..screen();
      final alice = await h.node('Alice', onboarded: true, nickname: 'Alice');
      await h.show(alice);
      final room = await h.real(() => alice.controller.createRoom('temp'));
      await _openMesh(h);
      await h.tap(find.byKey(const Key('room-label')));
      await h.tap(find.text('#temp').last);
      await h.until(() => find.text('Message #temp · public').evaluate().isNotEmpty);

      await h.real(() => alice.controller.leaveRoom(room.id));
      await h.until(() => find.text('Message #mesh · public').evaluate().isNotEmpty,
          reason: 'the open room is gone: the first one comes back');
      expect(tester.takeException(), isNull);
      await h.dispose();
    });

    testWidgets('a notification for a room opens it on a page of its own, with a way back',
        (tester) async {
      final h = UiHarness(tester)..screen();
      final alice = await h.node('Alice', onboarded: true, nickname: 'Alice');
      await h.show(alice);

      h.notificationsOf(alice).tap(_mesh);
      await h.until(() => find.byType(RoomScreen).evaluate().isNotEmpty);
      expect(find.byKey(const Key('header-back')), findsOneWidget);
      expect(find.byKey(const Key('composer-field')), findsWidgets);

      await tester.binding.handlePopRoute();
      await h.settle();
      expect(find.byType(RoomScreen), findsNothing);
      expect(tester.takeException(), isNull);
      await h.dispose();
    });
  });

  group('pictures and voice in a public room', () {
    testWidgets('are explained first, sent as part of the room, and reach everyone nearby',
        (tester) async {
      final h = UiHarness(tester)..screen();
      final alice = await h.node('Alice', onboarded: true, nickname: 'Alice');
      final bob = await h.node('Bob', onboarded: true, nickname: 'Bob');
      await h.show(alice);
      await _meet(h, alice, bob);
      await _openMesh(h);
      final permissions = h.permissionsOf(alice);

      // A voice message.
      await h.tap(find.byKey(const Key('composer-mic')));
      expect(find.text('Allow the microphone?'), findsOneWidget);
      expect(permissions.requested, isEmpty);
      await h.tap(find.byKey(const Key('permission-continue')));
      expect(permissions.requested, [AppPermission.microphone]);
      expect(find.byKey(const Key('voice-send')), findsOneWidget);
      await h.tap(find.byKey(const Key('voice-send')));
      await h.until(() => find.byKey(const Key('voice-play')).evaluate().isNotEmpty);

      // A picture from the camera.
      h.pickerOf(alice).next = _photo();
      await h.tap(find.byKey(const Key('composer-attach')));
      await h.tap(find.byKey(const Key('attach-camera')));
      expect(find.text('Allow the camera?'), findsOneWidget);
      await h.tap(find.byKey(const Key('permission-continue')));
      await h.until(() => find.text('Send this picture?').evaluate().isNotEmpty);
      await tester.enterText(find.byKey(const Key('caption-field')), 'the view from here');
      await tester.pump();
      await h.tap(find.byKey(const Key('picture-send')));
      await h.until(() => find.byKey(const Key('image-open')).evaluate().isNotEmpty);
      expect(permissions.requested, [AppPermission.microphone, AppPermission.camera]);
      await h.until(() => _line('the view from here').evaluate().isNotEmpty);

      // Bob has both, complete and verified. Nobody confirms receipt in a public room.
      await h.untilAsync(() async {
        final theirs = await bob.controller.loadMessages(_mesh);
        final ids = [for (final m in theirs) if (m.mediaId != null) m.mediaId!];
        if (ids.length < 2) return false;
        final media = await bob.controller.loadMedia(ids);
        return media.length == 2 && media.values.every((m) => m.isReady);
      }, timeoutMs: 30000, reason: 'Bob should have the voice message and the picture');
      final mine = await h.real(() => alice.controller.loadMessages(_mesh));
      expect(mine.every((m) => m.status != MessageStatus.delivered), isTrue,
          reason: 'a public room has no delivery receipts');

      expect(tester.takeException(), isNull);
      await h.dispose();
    });

    testWidgets('a picture and a voice message from someone else show in the room',
        (tester) async {
      final h = UiHarness(tester)..screen();
      final alice = await h.node('Alice', onboarded: true, nickname: 'Alice');
      final bob = await h.node('Bob', onboarded: true, nickname: 'Bob');
      await h.show(alice);
      await _meet(h, alice, bob);
      await _openMesh(h);

      final draft = await h.real(() => bob.controller.prepareImage(_photo(), caption: 'hello from Bob'));
      await h.real(() => bob.controller.sendMedia(_mesh, draft));
      await h.until(() => find.byKey(const Key('image-open')).evaluate().isNotEmpty,
          timeoutMs: 20000, reason: 'the picture arrives chunk by chunk, then shows');
      expect(_line('hello from Bob'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await h.dispose();
    });
  });

  group('what has not been seen yet is not marked as read', () {
    testWidgets('a message that arrives while another place is open counts, and clears on return',
        (tester) async {
      final h = UiHarness(tester)..screen();
      final alice = await h.node('Alice', onboarded: true, nickname: 'Alice');
      final bob = await h.node('Bob', onboarded: true, nickname: 'Bob');
      await h.show(alice, landing: true);
      await _meet(h, alice, bob);

      // Public is open: a message that arrives is read at once.
      await h.real(() => bob.controller.sendText(_mesh, 'while you watch'));
      await h.until(() => _line('while you watch').evaluate().isNotEmpty);
      expect(alice.controller.totalUnread, 0);

      // Another place is open: the room is kept ready behind it, and its messages wait.
      await h.openTab('settings');
      await h.real(() => bob.controller.sendText(_mesh, 'while you were away'));
      await h.until(() => alice.controller.totalUnread == 1, reason: 'counted, not marked read');
      expect(find.descendant(of: find.byKey(const Key('nav-public')), matching: find.text('1')),
          findsOneWidget, reason: 'the badge of the Public place');

      await h.openTab('public');
      await h.until(() => alice.controller.totalUnread == 0, reason: 'coming back reads them');
      expect(find.descendant(of: find.byKey(const Key('nav-public')), matching: find.text('1')),
          findsNothing);
      expect(tester.takeException(), isNull);
      await h.dispose();
    });
  });

  group('responsiveness', () {
    testWidgets('opening the keyboard and typing never rebuild the room', (tester) async {
      final h = UiHarness(tester)..screen();
      final alice = await h.node('Alice', onboarded: true, nickname: 'Alice');
      await h.show(alice);
      await _openMesh(h);
      await h.real(() async {
        for (var i = 0; i < 24; i++) {
          await alice.controller.sendText(_mesh, 'line number $i');
        }
      });
      await h.until(() => _line('line number 23').evaluate().isNotEmpty);
      await h.settle();
      final before = PublicLine.debugBuilds;
      expect(before, greaterThan(0));

      addTearDown(tester.view.resetViewInsets);
      // 900 device pixels, three to a point: 300 points of keyboard.
      for (var i = 1; i <= 15; i++) {
        tester.view.viewInsets = FakeViewPadding(bottom: i * 60.0);
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(PublicLine.debugBuilds, before, reason: 'moving the keyboard must not rebuild the messages');
      expect(tester.getBottomLeft(_field).dy, lessThanOrEqualTo(760 - 300 + 1),
          reason: 'the field sits right above the keyboard');
      expect(_line('line number 23'), findsOneWidget, reason: 'the newest message stays visible');

      const text = 'typing quickly while the keyboard is open';
      for (var i = 1; i <= text.length; i++) {
        await tester.enterText(_field, text.substring(0, i));
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(PublicLine.debugBuilds, before, reason: 'typing must not rebuild the messages');

      expect(tester.takeException(), isNull);
      await h.dispose();
    });

    testWidgets('a long room name and nickname fit the smallest phone with large text',
        (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final h = UiHarness(tester)..screen(320, 568);
      final alice = await h.node('Alice', onboarded: true, nickname: 'A nickname that is rather long');
      final bob = await h.node('Bob', onboarded: true, nickname: 'Bobby Tables-Longname');
      await h.show(alice, landing: true);
      await _meet(h, alice, bob);
      final room = await h.real(() => alice.controller
          .createRoom('a-rather-long-room-name-here-ok', description: 'with a description'));
      expect(tester.takeException(), isNull, reason: 'the first place');

      await h.tap(find.byKey(const Key('room-label')));
      await h.tap(find.text('#${room.name}').last);
      await h.until(() => find.byKey(const Key('composer-field')).evaluate().isNotEmpty);
      await h.real(() => alice.controller.sendText('rm:${room.id}',
          'a rather long message that has to wrap around the narrow screen twice'));
      await h.until(() => _line('a rather long message that has to wrap around the narrow screen twice')
          .evaluate()
          .isNotEmpty);
      expect(tester.takeException(), isNull, reason: 'the room, with a long name and nickname');

      await h.tap(find.byKey(const Key('composer-mic')));
      expect(tester.takeException(), isNull, reason: 'the permission explanation');
      await h.tap(find.text('Not now'));
      await h.tap(find.byKey(const Key('room-label')));
      expect(tester.takeException(), isNull, reason: 'the rooms sheet');

      await h.dispose();
    });

    testWidgets('on a tablet the room is a readable column', (tester) async {
      final h = UiHarness(tester)..screen(900, 640);
      final alice = await h.node('Alice', onboarded: true, nickname: 'Alice');
      await h.show(alice);
      await _openMesh(h);
      await _say(tester, h, 'hello from a tablet');
      await h.until(() => _line('hello from a tablet').evaluate().isNotEmpty);
      expect(tester.getSize(find.byType(RoomChat)).width, lessThanOrEqualTo(680));
      expect(tester.takeException(), isNull);
      await h.dispose();
    });
  });

  group('the field follows what is typed', () {
    testWidgets('English typed in a Kurdish app reads left to right, Kurdish right to left',
        (tester) async {
      final h = UiHarness(tester)..screen();
      final alice = await h.node('Alice', onboarded: true, nickname: 'Alice', language: AppLanguage.ckb);
      await h.show(alice);
      await _openMesh(h);

      TextDirection? direction() => (tester.widget(_field) as TextField).textDirection;
      expect(direction(), isNull, reason: 'empty: the direction of the app');

      await tester.enterText(_field, 'hello!');
      await tester.pump();
      expect(direction(), TextDirection.ltr);

      await tester.enterText(_field, 'سڵاو!');
      await tester.pump();
      expect(direction(), TextDirection.rtl);

      await tester.enterText(_field, '');
      await tester.pump();
      expect(direction(), isNull);
      expect(tester.takeException(), isNull);
      await h.dispose();
    });
  });
}
