import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_mesh_chat/core/bidi.dart';
import 'package:offline_mesh_chat/l10n/l10n.dart';
import 'package:offline_mesh_chat/models/conversation.dart';
import 'package:offline_mesh_chat/protocol/room_record.dart';
import 'package:offline_mesh_chat/screens/home_screen.dart';
import 'package:offline_mesh_chat/screens/onboarding_screen.dart';
import 'package:offline_mesh_chat/screens/settings_pages.dart' show LanguagePage;
import 'package:offline_mesh_chat/theme/app_icons.dart';

import '../support/app_harness.dart';
import '../support/ui_harness.dart';

TextDirection _directionOf(WidgetTester tester, Type screen) =>
    Directionality.of(tester.element(find.byType(screen).first));

Future<(AppNode, AppNode)> _pair(UiHarness h, {AppLanguage language = AppLanguage.ckb}) async {
  final alice = await h.node('Alice', onboarded: true, nickname: 'Alice', language: language);
  final bob = await h.node('Bob', onboarded: true, nickname: 'Bob');
  await h.show(alice);
  await h.until(
      () =>
          alice.directlyReaches(bob) &&
          bob.directlyReaches(alice) &&
          (alice.viewOf(bob)?.peer.canReceiveEncrypted ?? false),
      timeoutMs: 30000);
  return (alice, bob);
}

/// Kurdish is the main language, Arabic the second, English the third; the first
/// two read right to left. These tests look at the screens themselves: the
/// words, the direction, the picker, and that nothing runs out of its box.
void main() {
  group('Kurdish, the main language', () {
    testWidgets('a new install opens in Kurdish, right to left', (tester) async {
      final h = UiHarness(tester)..screen();
      final alice = await h.node('Alice', onboarded: true, nickname: 'Alice', language: AppLanguage.main);
      await h.show(alice);

      expect(_directionOf(tester, HomeScreen), TextDirection.rtl);
      for (final word in ['تایبەت', 'گرووپەکان', 'گشتی', 'ڕێکخستنەکان']) {
        expect(h.navItem(word), findsOneWidget, reason: word);
      }
      expect(find.text('Private'), findsNothing);
      expect(tester.takeException(), isNull);
      await h.dispose();
    });

    testWidgets('the bottom bar starts at the right, and the highlight follows', (tester) async {
      final h = UiHarness(tester)..screen();
      final alice = await h.node('Alice', onboarded: true, language: AppLanguage.main);
      await h.show(alice);

      double x(String id) => tester.getCenter(find.byKey(Key('nav-$id'))).dx;
      expect(x('public'), greaterThan(x('private')), reason: 'the first place is the rightmost');
      expect(x('private'), greaterThan(x('groups')));
      expect(x('groups'), greaterThan(x('settings')));

      Finder pill() => find.byWidgetPredicate(
            (w) => w is Container && w.constraints == BoxConstraints.tightFor(width: 74, height: 56),
          );
      expect(tester.getCenter(pill()).dx, closeTo(x('private'), 1.5),
          reason: 'show() goes to Private, so the highlight is under it');
      await h.tap(find.byKey(const Key('nav-groups')));
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.getCenter(pill()).dx, closeTo(x('groups'), 1.5));
      await h.tap(find.byKey(const Key('nav-settings')));
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.getCenter(pill()).dx, closeTo(x('settings'), 1.5));
      await h.dispose();
    });

    testWidgets('the same bar in English starts at the left', (tester) async {
      final h = UiHarness(tester)..screen();
      final alice = await h.node('Alice', onboarded: true);
      await h.show(alice);
      expect(_directionOf(tester, HomeScreen), TextDirection.ltr);
      double x(String id) => tester.getCenter(find.byKey(Key('nav-$id'))).dx;
      expect(x('public'), lessThan(x('private')));
      expect(x('private'), lessThan(x('settings')));
      await h.dispose();
    });
  });

  group('changing the language', () {
    testWidgets('in Settings, at once, for every word and the direction', (tester) async {
      final h = UiHarness(tester)..screen();
      final alice = await h.node('Alice', onboarded: true, language: AppLanguage.main);
      await h.show(alice);
      await h.openSettingsPage('language');

      expect(find.byKey(const Key('language-picker')), findsOneWidget);
      expect(find.text('کوردی'), findsOneWidget);
      expect(find.text('العربية'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);

      await h.tap(find.byKey(const Key('language-en')));
      expect(alice.controller.language, AppLanguage.en);
      expect(_directionOf(tester, LanguagePage), TextDirection.ltr);
      // The page is still open, now in English, and the picker did not move away.
      expect(find.byKey(const Key('language-picker')), findsOneWidget);
      expect(find.descendant(of: find.byType(AppBar), matching: find.text('Language')), findsOneWidget);

      await h.tap(find.byKey(const Key('language-ar')));
      expect(alice.controller.language, AppLanguage.ar);
      expect(_directionOf(tester, LanguagePage), TextDirection.rtl);
      expect(find.byKey(const Key('language-picker')), findsOneWidget);
      expect(find.descendant(of: find.byType(AppBar), matching: find.text('اللغة')), findsOneWidget);

      await h.tap(find.byKey(const Key('language-ckb')));
      expect(alice.controller.language, AppLanguage.ckb);

      // Back on the home screen the bar speaks Kurdish too, and the menu shows the language
      // by its own name.
      await tester.binding.handlePopRoute();
      await h.settle();
      expect(h.navItem('تایبەت'), findsOneWidget);
      expect(h.navItem('Private'), findsNothing);
      expect(_directionOf(tester, HomeScreen), TextDirection.rtl);
      expect(tester.takeException(), isNull);
      await h.dispose();
    });

    testWidgets('the first page offers the choice before anything else', (tester) async {
      final h = UiHarness(tester)..screen();
      final alice = await h.node('Alice', language: AppLanguage.main);
      await h.show(alice);

      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.byKey(const Key('language-picker')), findsOneWidget);
      expect(find.textContaining('لەگەڵ خەڵکی نزیک گفتوگۆ بکە'), findsOneWidget);
      expect(_directionOf(tester, OnboardingScreen), TextDirection.rtl);

      await h.tap(find.byKey(const Key('language-en')));
      expect(find.textContaining('Chat with people nearby.'), findsOneWidget);
      expect(_directionOf(tester, OnboardingScreen), TextDirection.ltr);
      expect(find.byKey(const Key('onboarding-start')), findsOneWidget);

      await h.tap(find.byKey(const Key('language-ar')));
      expect(find.textContaining('تحدّث مع من حولك'), findsOneWidget);
      expect(find.text('اسمح بالبلوتوث وابدأ'), findsOneWidget);
      await h.dispose();
    });

    testWidgets('the name field stops at 32 bytes: sixteen Kurdish letters', (tester) async {
      final h = UiHarness(tester)..screen();
      final alice = await h.node('Alice', language: AppLanguage.main);
      await h.show(alice);
      await h.reveal(find.byKey(const Key('onboarding-name')));
      await tester.enterText(find.byKey(const Key('onboarding-name')), 'ک' * 30);
      await tester.pump();
      final text = (tester.widget(find.byKey(const Key('onboarding-name'))) as TextField).controller!.text;
      expect(text.runes.length, 16);
      await h.dispose();
    });
  });

  group('messages keep their own direction', () {
    testWidgets('English text in a Kurdish chat reads left to right, Kurdish text right to left',
        (tester) async {
      final h = UiHarness(tester)..screen();
      final (alice, bob) = await _pair(h);
      final withBob = Conversation.directId(bob.id);
      await h.real(() async {
        await bob.controller.sendDirect(alice.id, 'see you at ten!');
        await bob.controller.sendDirect(alice.id, 'دەبینمەوە لە دەیدا!');
      });
      await h.untilAsync(() async => (await alice.controller.loadMessages(withBob)).length == 2);
      await h.until(() => find.byKey(Key('conversation-$withBob')).evaluate().isNotEmpty);
      await h.tap(find.byKey(Key('conversation-$withBob')));
      await h.until(() => find.text('see you at ten!').evaluate().isNotEmpty);

      TextDirection? directionOf(String body) =>
          tester.widget<Text>(find.text(body).first).textDirection;
      expect(directionOf('see you at ten!'), TextDirection.ltr);
      expect(directionOf('دەبینمەوە لە دەیدا!'), TextDirection.rtl);
      expect(tester.takeException(), isNull);
      await h.dispose();
    });

    testWidgets('bubbles stay where they always were: mine on the right, theirs on the left',
        (tester) async {
      final h = UiHarness(tester)..screen();
      final (alice, bob) = await _pair(h);
      final withBob = Conversation.directId(bob.id);
      await h.real(() async {
        await bob.controller.sendDirect(alice.id, 'theirs');
        await alice.controller.sendDirect(bob.id, 'mine');
      });
      await h.untilAsync(() async => (await alice.controller.loadMessages(withBob)).length == 2);
      await h.until(() => find.byKey(Key('conversation-$withBob')).evaluate().isNotEmpty);
      await h.tap(find.byKey(Key('conversation-$withBob')));
      await h.until(() => find.text('mine').evaluate().isNotEmpty);
      final mine = tester.getCenter(find.text('mine').first).dx;
      final theirs = tester.getCenter(find.text('theirs').first).dx;
      expect(mine, greaterThan(180), reason: 'the sent bubble is on the right half of a 360 wide screen');
      expect(theirs, lessThan(mine));
      await h.dispose();
    });

    testWidgets('the tag after a name in the public room always reads left to right', (tester) async {
      final h = UiHarness(tester)..screen();
      final (alice, bob) = await _pair(h);
      await h.real(() => bob.controller.sendText('rm:${PublicRooms.meshIdHex}', 'hi everyone'));
      await h.openTab('public');
      await h.until(() => find.text('hi everyone').evaluate().isNotEmpty);
      final shortId = bob.id.substring(0, 4);
      final name = find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText() == 'Bob $leftToRightIsolate#$shortId$isolateEnd',
          description: 'the name, with its tag as one left-to-right block');
      expect(name, findsOneWidget);
      expect(tester.widget<Text>(find.text('hi everyone')).textDirection, TextDirection.ltr,
          reason: 'an English message keeps its layout');
      expect(alice.controller.language, AppLanguage.ckb);
      await h.dispose();
    });
  });

  group('what the app writes itself keeps its shape in a right-to-left sentence', () {
    final mesh = 'rm:${PublicRooms.meshIdHex}';
    final tag = '$firstStrongIsolate#mesh$isolateEnd';

    testWidgets('in Kurdish a room is one piece: the header, the hint and the list', (tester) async {
      final h = UiHarness(tester)..screen();
      final (alice, bob) = await _pair(h);
      final l = alice.controller.l10n;
      await h.real(() => bob.controller.sendText(mesh, 'hi everyone'));
      await h.openTab('public');
      await h.until(() => find.byKey(const Key('room-label')).evaluate().isNotEmpty);
      expect(find.descendant(of: find.byKey(const Key('room-label')), matching: find.text(tag)),
          findsOneWidget,
          reason: 'the header: #mesh, not mesh#');
      expect(find.text('#mesh'), findsNothing);
      expect(find.text(l.roomComposerHint(tag)), findsOneWidget, reason: 'the hint of the field');
      expect(find.textContaining('damataqe/'), findsNothing, reason: 'no prompt any more');

      await h.tap(find.byKey(const Key('room-label')));
      expect(find.text(tag), findsWidgets);
      expect(find.text(l.homeMeshSubtitle), findsOneWidget,
          reason: 'the built-in room is described in Kurdish, not with its stored English');
      expect(find.text('Everyone nearby'), findsNothing);
      expect(tester.takeException(), isNull);
      await h.dispose();
    });

    testWidgets('in English nothing is added', (tester) async {
      final h = UiHarness(tester)..screen();
      final (alice, bob) = await _pair(h, language: AppLanguage.en);
      await h.real(() => bob.controller.sendText(mesh, 'hi everyone'));
      await h.openTab('public');
      await h.until(() => find.text('hi everyone').evaluate().isNotEmpty);
      expect(find.descendant(of: find.byKey(const Key('room-label')), matching: find.text('#mesh')),
          findsOneWidget);
      expect(find.textContaining(leftToRightIsolate), findsNothing);
      expect(find.textContaining(firstStrongIsolate), findsNothing);
      expect(alice.controller.language, AppLanguage.en);
      await h.dispose();
    });

    test('the forward arrow turns around with the language, like reply and back', () {
      expect(AppIcons.forward.matchTextDirection, isTrue);
      expect(AppIcons.forward.codePoint, Icons.shortcut_rounded.codePoint);
      expect(AppIcons.forward.fontFamily, Icons.shortcut_rounded.fontFamily);
      expect(Icons.reply_rounded.matchTextDirection, isTrue);
    });

    testWidgets('and the message menu uses it', (tester) async {
      final h = UiHarness(tester)..screen();
      final (alice, bob) = await _pair(h);
      final withBob = Conversation.directId(bob.id);
      await h.real(() => bob.controller.sendDirect(alice.id, 'hello'));
      await h.until(() => find.byKey(Key('conversation-$withBob')).evaluate().isNotEmpty);
      await h.tap(find.byKey(Key('conversation-$withBob')));
      await h.until(() => find.text('hello').evaluate().isNotEmpty);
      await tester.longPress(find.text('hello').first);
      await h.settle();
      expect(find.descendant(of: find.byKey(const Key('act-forward')), matching: find.byIcon(AppIcons.forward)),
          findsOneWidget);
      await h.dispose();
    });
  });

  group('nothing runs out of its box', () {
    for (final language in [AppLanguage.ckb, AppLanguage.ar]) {
      testWidgets('${language.englishName}: the main screens at 320 wide with large text', (tester) async {
        final h = UiHarness(tester)..screen(320, 640);
        tester.platformDispatcher.textScaleFactorTestValue = 1.5;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final (alice, bob) = await _pair(h, language: language);
        final l = language.strings;
        final withBob = Conversation.directId(bob.id);
        await h.real(() => bob.controller.sendDirect(alice.id, 'hello'));
        await h.untilAsync(() async => (await alice.controller.loadMessages(withBob)).isNotEmpty);
        await h.until(() => find.byKey(Key('conversation-$withBob')).evaluate().isNotEmpty);

        // The three lists and the settings.
        for (final label in [l.navGroups, l.navPublic, l.settingsTitle, l.navPrivate]) {
          await h.goToTab(label);
          expect(tester.takeException(), isNull, reason: label);
        }

        // Every page of the settings, from top to bottom.
        for (final (page, keys) in [
          ('profile', <String>['edit-nickname']),
          ('language', ['language-picker']),
          ('notifications', ['notify-switch']),
          ('privacy', ['open-storage', 'reset-identity']),
          ('chat', ['relay-switch']),
          ('help', <String>[]),
          ('about', ['open-licences']),
        ]) {
          await h.openSettingsPage(page);
          for (final key in keys) {
            await h.reveal(find.byKey(Key(key)));
          }
          expect(tester.takeException(), isNull, reason: page);
          await tester.binding.handlePopRoute();
          await h.settle();
        }
        await h.goToTab(l.navPrivate);

        // A chat, its details and the people.
        await h.tap(find.byKey(Key('conversation-$withBob')));
        await h.until(() => find.text('hello').evaluate().isNotEmpty);
        expect(tester.takeException(), isNull, reason: 'the chat');
        await tester.longPress(find.text('hello').first);
        await h.settle();
        expect(tester.takeException(), isNull, reason: 'the message menu');
        await h.tap(find.byKey(const Key('act-details')));
        expect(tester.takeException(), isNull, reason: 'the details');
        await h.dispose();
      });
    }
  });
}
