import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_mesh_chat/app.dart';
import 'package:offline_mesh_chat/l10n/l10n.dart';
import 'package:offline_mesh_chat/screens/home_screen.dart';
import 'package:offline_mesh_chat/screens/onboarding_screen.dart';
import 'package:offline_mesh_chat/screens/room_screen.dart';
import 'package:offline_mesh_chat/widgets/nav_bar.dart';

import '../support/ui_harness.dart';

/// Where the app opens, for a person who has just finished the first page, for one who
/// comes back, and in each language.
void main() {
  group('the public room is where the app opens', () {
    testWidgets('right after the first page, and the first page itself is short', (tester) async {
      final h = UiHarness(tester)..screen();
      final alice = await h.node('Alice');
      await h.show(alice, landing: true);

      // The first page: the language, the promise, three points and one honest note,
      // the name, and the one button. The long explanations are in Settings.
      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.byType(AppNavBar), findsNothing, reason: 'no bar before the page is done');
      expect(find.text('Phone to phone, over Bluetooth'), findsOneWidget);
      await h.reveal(find.text('Private chats, groups and public rooms'));
      expect(find.text('Private chats, groups and public rooms'), findsOneWidget);
      await h.reveal(find.text('Asks before it uses anything'));
      expect(find.text('Asks before it uses anything'), findsOneWidget);
      await h.reveal(find.text('Good to know'));
      expect(find.text('Good to know'), findsOneWidget);
      expect(find.text('Further, through other phones'), findsNothing, reason: 'moved to Help');
      expect(find.textContaining('Android 11 and older'), findsNothing, reason: 'moved to Help');

      await h.tap(find.byKey(const Key('onboarding-start')));
      await h.until(() => find.byType(HomeScreen).evaluate().isNotEmpty);

      // The home screen opens on the public room: its header, its field, the first
      // item of the bar current.
      expect(find.byType(RoomChat), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('room-label')), matching: find.text('#mesh')),
          findsOneWidget);
      expect(find.byKey(const Key('composer-field')), findsOneWidget);
      expect(
          tester.getSemantics(find.byKey(const Key('nav-public'))),
          matchesSemantics(
            label: 'Public',
            isButton: true,
            isSelected: true,
            hasTapAction: true,
            hasSelectedState: true,
          ));
      expect(tester.takeException(), isNull);
      await h.dispose();
    });

    testWidgets('a returning person lands there too, without a loading page in between',
        (tester) async {
      final h = UiHarness(tester)..screen();
      final alice = await h.node('Alice', onboarded: true, nickname: 'Alice');
      await tester.pumpWidget(DamataqeApp(controller: alice.controller));
      await tester.pump();

      expect(find.byType(OnboardingScreen), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget, reason: 'the very first frame');
      expect(find.byType(RoomChat), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing, reason: 'no spinner page');
      await h.dispose();
    });

    for (final language in AppLanguage.values) {
      testWidgets('${language.code}: the first place of the bar is the room, and the bar names it',
          (tester) async {
        final h = UiHarness(tester)..screen();
        final alice = await h.node('Alice', onboarded: true, nickname: 'Alice', language: language);
        await h.show(alice, landing: true);

        expect(find.byType(RoomChat), findsOneWidget);
        final first = find.descendant(
            of: find.byKey(const Key('nav-public')), matching: find.text(language.strings.navPublic));
        expect(first, findsOneWidget);
        expect(Directionality.of(tester.element(find.byType(HomeScreen))), language.direction);
        final others = [
          for (final id in ['private', 'groups', 'settings']) tester.getCenter(find.byKey(Key('nav-$id'))).dx
        ];
        final publicX = tester.getCenter(find.byKey(const Key('nav-public'))).dx;
        if (language.isRtl) {
          expect(others.every((x) => x < publicX), isTrue, reason: 'the first place is the rightmost');
        } else {
          expect(others.every((x) => x > publicX), isTrue, reason: 'the first place is the leftmost');
        }
        expect(tester.takeException(), isNull);
        await h.dispose();
      });
    }

    testWidgets('changing the language turns the whole page around, and back', (tester) async {
      final h = UiHarness(tester)..screen();
      final alice = await h.node('Alice', onboarded: true, nickname: 'Alice');
      await h.show(alice, landing: true);
      double publicX() => tester.getCenter(find.byKey(const Key('nav-public'))).dx;
      expect(publicX(), lessThan(100), reason: 'English: at the left');

      await h.openSettingsPage('language');
      await h.tap(find.byKey(const Key('language-ckb')));
      await h.tester.binding.handlePopRoute();
      await h.settle();
      await h.openTab('public');
      expect(publicX(), greaterThan(260), reason: 'Kurdish: at the right');
      expect(find.text(AppLanguage.ckb.strings.navPublic), findsOneWidget);

      await h.openSettingsPage('language');
      await h.tap(find.byKey(const Key('language-en')));
      await h.tester.binding.handlePopRoute();
      await h.settle();
      await h.openTab('public');
      expect(publicX(), lessThan(100), reason: 'English again: at the left');
      expect(tester.takeException(), isNull);
      await h.dispose();
    });
  });
}
