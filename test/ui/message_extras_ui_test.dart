import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_mesh_chat/core/app_info.dart';
import 'package:image/image.dart' as img;
import 'package:offline_mesh_chat/models/conversation.dart';
import 'package:offline_mesh_chat/models/media.dart';
import 'package:offline_mesh_chat/models/message.dart';
import 'package:offline_mesh_chat/screens/chat_screen.dart';
import 'package:offline_mesh_chat/services/message_service.dart' show MessageError, MessageErrorKind;
import 'package:offline_mesh_chat/services/network_status_service.dart';

import '../support/app_harness.dart';
import '../support/ui_harness.dart';

Uint8List _photo() {
  final rng = Random(5);
  final image = img.Image(width: 120, height: 90, numChannels: 3);
  for (final p in image) {
    p
      ..r = p.x * 255 ~/ 120
      ..g = p.y * 255 ~/ 90
      ..b = 50 + rng.nextInt(50);
  }
  return Uint8List.fromList(img.encodeJpg(image, quality: 85));
}

class _Chat {
  _Chat(this.h, this.tester, this.alice, this.bob);

  final UiHarness h;
  final WidgetTester tester;
  final AppNode alice;
  final AppNode bob;

  String get conversation => Conversation.directId(bob.id);

  String get bobsConversation => Conversation.directId(alice.id);

  Future<void> say(String text) async {
    await tester.enterText(find.byKey(const Key('composer-field')), text);
    await tester.pump();
    await h.tap(find.byKey(const Key('composer-send')));
    await h.until(() => find.text(text).evaluate().isNotEmpty);
  }

  Future<void> bobSays(String text) async {
    await h.real(() => bob.controller.sendDirect(alice.id, text));
    await h.until(() => find.text(text).evaluate().isNotEmpty);
  }

  Future<void> menu(Finder f, String action) async {
    await h.reveal(f);
    await tester.longPress(f);
    await h.settle();
    await h.tap(find.byKey(Key('act-$action')));
  }

  Future<void> more(String item) async {
    await h.tap(find.byKey(const Key('selection-more')));
    await h.tap(find.byKey(Key(item)));
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

void main() {
  group('the selection bar\'s more menu', () {
    testWidgets('Select all counts every message, and the same menu pins them all',
        (tester) async {
      final c = await _openChat(tester);
      await c.say('one');
      await c.bobSays('two');
      await c.say('three');

      await c.menu(find.text('one'), 'select');
      expect(find.text('1 selected'), findsOneWidget);
      await c.more('sel-all');
      expect(find.text('3 selected'), findsOneWidget);
      expect(find.byKey(const Key('select-check-on')), findsNWidgets(3));

      await c.more('sel-pin');
      await c.h.until(() => find.byKey(const Key('pinned-banner')).evaluate().isNotEmpty);
      expect(find.textContaining('Pinned message 1 of 3'), findsOneWidget);
      expect(find.byKey(const Key('selection-count')), findsNothing, reason: 'the selection ends');

      // All pinned: the same item now unpins.
      await c.menu(find.text('one'), 'select');
      await c.more('sel-all');
      await c.h.tap(find.byKey(const Key('selection-more')));
      expect(find.text('Unpin'), findsOneWidget);
      await c.h.tap(find.byKey(const Key('sel-pin')));
      await c.h.until(() => find.byKey(const Key('pinned-banner')).evaluate().isEmpty);
      expect(await c.h.real(() => c.alice.controller.pinnedMessages(c.conversation)), isEmpty);
      await c.h.dispose();
    });

    testWidgets('Share hands the selected texts, in order, to the share sheet', (tester) async {
      final c = await _openChat(tester);
      await c.say('first words');
      await c.bobSays('second words');
      await c.menu(find.text('first words'), 'select');
      await c.h.tap(find.text('second words'));
      await c.more('sel-share');
      await c.h.until(() => c.h.sharerOf(c.alice).texts.isNotEmpty);
      expect(c.h.sharerOf(c.alice).texts.single, 'first words\nsecond words');
      expect(find.byKey(const Key('selection-count')), findsNothing);
      await c.h.dispose();
    });

    testWidgets('Save to gallery appears only when a picture is selected, and saves it',
        (tester) async {
      final c = await _openChat(tester);
      await c.bobSays('just a text');
      await c.h.real(() async {
        final draft = await c.bob.controller.prepareImage(_photo());
        await c.bob.controller.sendMedia(c.bobsConversation, draft);
      });
      await c.h.until(() => find.byKey(const Key('image-open')).evaluate().isNotEmpty, timeoutMs: 30000);

      await c.menu(find.text('just a text'), 'select');
      await c.h.tap(find.byKey(const Key('selection-more')));
      expect(find.byKey(const Key('sel-save')), findsNothing, reason: 'text cannot be saved to the gallery');
      await c.tester.tapAt(const Offset(10, 10));
      await c.h.settle();
      // Tap where the picture is. While selecting, a layer over each message takes
      // every tap (a picture must not open then), so this selects the message.
      await c.h.reveal(find.byKey(const Key('image-open')));
      await c.tester.tapAt(c.tester.getCenter(find.byKey(const Key('image-open'))));
      await c.h.settle();
      await c.more('sel-save');
      expect(find.text('Save to your gallery?'), findsOneWidget);
      expect(find.textContaining('keeps this picture'), findsOneWidget);
      await c.h.tap(find.byKey(const Key('save-confirm')));
      final gallery = c.h.galleryOf(c.alice);
      await c.h.until(() => gallery.images.isNotEmpty);
      expect(gallery.images, hasLength(1));
      await c.h.dispose();
    });
  });

  group('the message menu', () {
    testWidgets('Share on one message, text and picture', (tester) async {
      final c = await _openChat(tester);
      await c.bobSays('share these words');
      final jpeg = _photo();
      await c.h.real(() async {
        final draft = await c.bob.controller.prepareImage(jpeg, caption: 'look');
        await c.bob.controller.sendMedia(c.bobsConversation, draft);
      });
      await c.h.until(() => find.byKey(const Key('image-open')).evaluate().isNotEmpty, timeoutMs: 30000);
      final sharer = c.h.sharerOf(c.alice);

      await c.menu(find.text('share these words'), 'share');
      await c.h.until(() => sharer.texts.isNotEmpty);
      expect(sharer.texts.single, 'share these words');

      await c.tester.longPress(find.byKey(const Key('image-open')));
      await c.h.settle();
      await c.h.tap(find.byKey(const Key('act-share')));
      await c.h.until(() => sharer.files.isNotEmpty);
      final shared = sharer.files.single.single;
      expect(shared.mimeType, 'image/jpeg');
      expect(shared.name, endsWith('.jpg'));
      expect(shared.bytes ?? Uint8List(0), isNotEmpty, reason: 'the memory store has no path, so the bytes go');
      expect(sharer.fileTexts.single, 'look', reason: 'the caption goes along');
      await c.h.dispose();
    });

    testWidgets('a failed message offers "Send again" in the menu', (tester) async {
      final c = await _openChat(tester);
      c.h.world.setInRange(c.alice.phone, c.bob.phone, false);
      await c.h.until(() => !c.alice.directlyReaches(c.bob));
      await c.say('will not get through');
      final failed = (await c.h.real(() => c.alice.controller.loadMessages(c.conversation))).single;
      await c.h.real(() => c.alice.controller.repo
          .updateOutgoingStatus(failed.id, MessageStatus.failed, error: 'Not delivered'));
      await c.h.until(() => find.text('Send again').evaluate().isNotEmpty);

      await c.h.reveal(find.text('will not get through'));
      await c.tester.longPress(find.text('will not get through'));
      await c.h.settle();
      expect(find.byKey(const Key('act-retry')), findsOneWidget);
      await c.h.tap(find.byKey(const Key('act-retry')));
      await c.h.until(() => find.text('Send again').evaluate().isEmpty, reason: 'the failed copy is replaced');
      final now = await c.h.real(() => c.alice.controller.loadMessages(c.conversation));
      expect(now.single.id, isNot(failed.id));
      expect(now.single.status, isNot(MessageStatus.failed));
      await c.h.dispose();
    });

    testWidgets('a message that did not fail has no "Send again", and Cancel closes the menu',
        (tester) async {
      final c = await _openChat(tester);
      await c.say('fine');
      await c.h.reveal(find.text('fine'));
      await c.tester.longPress(find.text('fine'));
      await c.h.settle();
      expect(find.byKey(const Key('act-retry')), findsNothing);
      expect(find.byKey(const Key('act-share')), findsOneWidget);
      await c.h.tap(find.byKey(const Key('act-cancel')));
      expect(find.byKey(const Key('message-menu')), findsNothing);
      await c.h.dispose();
    });
  });

  group('details', () {
    testWidgets('keep what the sender\'s clock said apart from when this phone saved it',
        (tester) async {
      final c = await _openChat(tester);
      await c.bobSays('from Bob');
      await c.say('from Alice');

      await c.menu(find.text('from Bob'), 'details');
      expect(find.byKey(const Key('detail-sent')), findsOneWidget);
      expect(find.text('Sent (their clock)'), findsOneWidget);
      expect(find.text('Received and saved'), findsOneWidget);
      await c.tester.tapAt(const Offset(180, 30));
      await c.h.settle();

      await c.menu(find.text('from Alice'), 'details');
      expect(find.byKey(const Key('detail-sent')), findsNothing, reason: 'it was our own clock');
      expect(find.text('Written and saved'), findsOneWidget);
      await c.h.dispose();
    });
  });

  group('the offline indicator', () {
    testWidgets('says "Offline" with no internet, and that the internet is not used when there is some',
        (tester) async {
      final h = UiHarness(tester)..screen();
      final off = await h.node('Alice', onboarded: true, nickname: 'Alice');
      await h.show(off);
      await h.until(() => find.byKey(const Key('offline-badge')).evaluate().isNotEmpty);
      expect(find.text('Offline'), findsOneWidget, reason: 'the badge is one word; the tooltip explains');
      expect(find.byTooltip('There is no internet connection. ${AppInfo.name} does not need one: '
          'messages travel by Bluetooth.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await h.dispose();

      final h2 = UiHarness(tester)..screen();
      final on = await h2.node('Bob', onboarded: true, nickname: 'Bob', network: NetworkKind.wifi);
      await h2.show(on);
      await h2.until(() => find.byKey(const Key('offline-badge')).evaluate().isNotEmpty);
      expect(find.text('Internet on'), findsOneWidget);
      expect(find.byTooltip('The phone has internet, but ${AppInfo.name} does not use it: messages travel by Bluetooth.'),
          findsOneWidget);
      await h2.dispose();
    });

    testWidgets('fits the smallest phone with large text', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final h = UiHarness(tester)..screen(320, 568);
      final a = await h.node('Alice', onboarded: true, nickname: 'Alice');
      await h.show(a);
      await h.until(() => find.byKey(const Key('offline-badge')).evaluate().isNotEmpty);
      expect(tester.takeException(), isNull);
      await h.dispose();
    });
  });

  group('the share action in the controller', () {
    testWidgets('refuses to share nothing, and a file that is still arriving', (tester) async {
      final h = UiHarness(tester)..screen();
      final a = await h.node('Alice', onboarded: true, nickname: 'Alice');
      final error = await h.real<MessageError?>(() async {
        try {
          await a.controller.shareMessages(const [], const <String, MediaItem>{});
          return null;
        } on MessageError catch (e) {
          return e;
        }
      });
      expect(error?.kind, MessageErrorKind.notAllowed);
      expect(h.sharerOf(a).texts, isEmpty);
      expect(h.sharerOf(a).files, isEmpty);
      await h.dispose();
    });
  });
}
