import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_mesh_chat/screens/home_screen.dart';
import 'package:offline_mesh_chat/widgets/nav_bar.dart';
import 'package:offline_mesh_chat/transport/ble_radio.dart';
import 'package:offline_mesh_chat/widgets/connection_indicator.dart';

import '../support/ui_harness.dart';

Finder get _headerPill =>
    find.descendant(of: find.byType(HomeScreen), matching: find.byType(ConnectionIndicator));

void main() {
  group('home', () {
    testWidgets('every place explains itself when nothing is around', (tester) async {
      final h = UiHarness(tester)..screen();
      final alice = await h.node('Alice', onboarded: true, nickname: 'Alice');
      await h.show(alice, landing: true);

      // The four places of the product, in a bar at the bottom: Public, Private,
      // Groups and Settings.
      expect(find.byType(AppNavBar), findsOneWidget);
      for (final t in ['Public', 'Private', 'Groups', 'Settings']) {
        expect(h.navItem(t), findsOneWidget);
      }

      // The first place is the public room: the built-in one, with nobody in it yet.
      expect(find.text('#mesh'), findsOneWidget, reason: 'the built-in public room is always there');
      await h.until(() => find.byKey(const Key('room-empty')).evaluate().isNotEmpty);
      expect(find.text('No messages yet'), findsOneWidget);
      expect(find.textContaining('Whatever you write is public'), findsOneWidget);

      await h.goToTab('Private');
      expect(find.text('No private chats yet'), findsOneWidget);
      expect(find.textContaining('works without internet'), findsOneWidget);
      expect(find.byKey(const Key('fab-private')), findsOneWidget);

      await h.goToTab('Groups');
      expect(find.text('No groups yet'), findsOneWidget);
      expect(find.textContaining('encrypted with a key only its members have'), findsOneWidget);
      expect(find.byKey(const Key('fab-groups')), findsOneWidget);

      expect(tester.takeException(), isNull);
      await h.dispose();
    });

    testWidgets('the header opens People and Nearby, and the bar opens Settings', (tester) async {
      final h = UiHarness(tester)..screen();
      final alice = await h.node('Alice', onboarded: true, nickname: 'Alice');
      await h.show(alice);

      await h.tap(find.byKey(const Key('open-people')));
      expect(find.text('Nobody yet'), findsOneWidget);
      await tester.pageBack();
      await h.settle();

      await h.tap(_headerPill);
      expect(find.text('Visible to others'), findsOneWidget);
      expect(find.text('Connected phones (0)'), findsOneWidget);
      expect(find.text('Devices heard (0)'), findsOneWidget);
      expect(find.text('Run Bluetooth self-test'), findsOneWidget);
      await tester.pageBack();
      await h.settle();

      await h.goToTab('Settings');
      expect(find.text('Alice'), findsWidgets);
      await h.tap(find.byKey(const Key('settings-privacy')));
      await h.reveal(find.text('Danger zone'));
      expect(find.text('Danger zone'), findsOneWidget);

      expect(tester.takeException(), isNull);
      await h.dispose();
    });

    testWidgets('search filters chats and people', (tester) async {
      final h = UiHarness(tester)..screen();
      final alice = await h.node('Alice', onboarded: true, nickname: 'Alice');
      final bob = await h.node('Bob', onboarded: true, nickname: 'Bobby');
      await h.show(alice);
      await h.until(() => alice.directlyReaches(bob));
      await h.real(() => alice.controller.sendDirect(bob.id, 'about the picnic'));
      await h.until(() => find.text('about the picnic').evaluate().isNotEmpty);

      await h.tap(find.byKey(const Key('search-toggle')));
      await tester.enterText(find.byKey(const Key('search-field')), 'picnic');
      await h.settle();
      expect(find.text('about the picnic'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('search-field')), 'zzz-nothing');
      await h.settle();
      expect(find.text('Nothing found'), findsOneWidget);
      expect(find.text('about the picnic'), findsNothing);

      // People who have no chat yet are found too.
      await h.real(() => alice.controller.deleteConversation('dm:${bob.id}'));
      await tester.enterText(find.byKey(const Key('search-field')), 'bobb');
      await h.settle();
      expect(find.text('People'), findsOneWidget);
      expect(find.text('Bobby'), findsWidgets);

      expect(tester.takeException(), isNull);
      await h.dispose();
    });

    testWidgets('the layout stays centred and readable on a tablet', (tester) async {
      final h = UiHarness(tester)..screen(900, 640);
      final alice = await h.node('Alice', onboarded: true);
      await h.show(alice);
      expect(find.byType(HomeScreen), findsOneWidget);
      final width = tester.getSize(find.byKey(const Key('nav-bar-items'))).width;
      expect(width, lessThanOrEqualTo(520), reason: 'the bar does not stretch across a tablet');
      await h.goToTab('Public');
      expect(find.text('#mesh'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await h.dispose();
    });

    testWidgets('all tabs and screens lay out without overflow on the smallest phone, with data',
        (tester) async {
      final h = UiHarness(tester)..screen(320, 568);
      final alice = await h.node('Alice', onboarded: true, nickname: 'Alice');
      final bob = await h.node('Bob', onboarded: true, nickname: 'Bobby Tables-Longname');
      await h.show(alice);
      await h.until(() => alice.directlyReaches(bob));
      await h.real(() => alice.controller.sendDirect(bob.id, 'hello'));
      await h.real(() => alice.controller
          .createRoom('a-rather-long-public-room-name-indeed', description: 'with a long description too'));
      await h.real(() => alice.controller.createGroup('A group with a very long name here', [bob.id]));
      await h.settle();

      for (final tab in ['Groups', 'Public', 'Settings', 'Private']) {
        await h.goToTab(tab);
        expect(tester.takeException(), isNull, reason: 'tab $tab');
      }
      await h.tap(find.byKey(const Key('open-people')));
      expect(tester.takeException(), isNull, reason: 'people');
      await tester.pageBack();
      await h.settle();
      await h.tap(_headerPill);
      expect(tester.takeException(), isNull, reason: 'nearby');
      await h.dispose();
    });

    testWidgets('large system text does not break the home screen', (tester) async {
      final h = UiHarness(tester)..screen(360, 640);
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final alice = await h.node('Alice', onboarded: true, nickname: 'Alice');
      final bob = await h.node('Bob', onboarded: true, nickname: 'Bob');
      await h.show(alice);
      await h.until(() => alice.directlyReaches(bob));
      await h.real(() => alice.controller.sendDirect(bob.id, 'a message'));
      await h.settle();
      for (final tab in ['Groups', 'Public', 'Settings', 'Private']) {
        await h.goToTab(tab);
        expect(tester.takeException(), isNull, reason: tab);
      }
      await h.dispose();
    });
  });

  group('Bluetooth problems are explained, with the fix', () {
    testWidgets('permission missing: explains why and the button fixes it', (tester) async {
      final h = UiHarness(tester)..screen();
      final alice = await h.node('Alice');
      alice.phone
        ..permissionsGranted = false
        ..userGrantsPermissions = true;
      // Started, but the system has not been allowed to use Bluetooth yet.
      await h.real(() => alice.controller.completeOnboarding());
      await h.show(alice);

      expect(find.text('Bluetooth permission needed'), findsOneWidget);
      expect(find.textContaining('It never uses your location'), findsOneWidget);
      expect(find.text('Permission needed'), findsOneWidget, reason: 'status indicator');
      expect(find.text('Open settings'), findsOneWidget);

      await h.tap(find.text('Allow Bluetooth'));
      await h.until(() => find.text('Bluetooth permission needed').evaluate().isEmpty,
          reason: 'the banner should go away once permission is granted');
      expect(alice.controller.radioStatus.ready, isTrue);
      await h.until(() => alice.phone.isAdvertising);
      expect(find.text('Searching…'), findsOneWidget);

      expect(tester.takeException(), isNull);
      await h.dispose();
    });

    testWidgets('permission refused: the settings button opens the system settings', (tester) async {
      final h = UiHarness(tester)..screen();
      final alice = await h.node('Alice');
      alice.phone
        ..permissionsGranted = false
        ..userGrantsPermissions = false;
      await h.real(() => alice.controller.completeOnboarding());
      await h.show(alice);

      await h.tap(find.text('Allow Bluetooth'));
      expect(find.text('Bluetooth permission needed'), findsOneWidget,
          reason: 'still refused, so still explained');
      await h.tap(find.text('Open settings'));
      expect(alice.phone.settingsOpened, 1);

      // Later the person allows it in the system settings.
      alice.phone.setPermissions(true);
      await h.until(() => find.text('Bluetooth permission needed').evaluate().isEmpty);

      expect(tester.takeException(), isNull);
      await h.dispose();
    });

    testWidgets('Bluetooth switched off, and on again', (tester) async {
      final h = UiHarness(tester)..screen();
      final alice = await h.node('Alice', onboarded: true);
      await h.show(alice);
      expect(find.text('Bluetooth is turned off'), findsNothing);

      alice.phone.setBluetooth(false);
      await h.until(() => find.text('Bluetooth is turned off').evaluate().isNotEmpty);
      expect(find.text('Bluetooth off'), findsOneWidget, reason: 'status indicator');

      alice.phone.setBluetooth(true);
      await h.until(() => find.text('Bluetooth is turned off').evaluate().isEmpty);
      await h.until(() => alice.phone.isAdvertising);

      expect(tester.takeException(), isNull);
      await h.dispose();
    });

    testWidgets('a phone that cannot be found by others says so, but can still look',
        (tester) async {
      final h = UiHarness(tester)..screen();
      final alice = await h.node('Alice');
      alice.phone.advertisingSupported = false;
      await h.real(() => alice.controller.completeOnboarding());
      await h.show(alice);
      expect(alice.controller.radioStatus.blocker, RadioAvailability.unsupported);
      expect(find.text('This phone can\'t be found by others'), findsOneWidget);

      await h.tap(_headerPill);
      expect(find.text('Cannot advertise'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await h.dispose();
    });
  });

  group('connection indicators', () {
    testWidgets('show nearby phones, and phones that are only reachable through a relay',
        (tester) async {
      final h = UiHarness(tester)..screen();
      final alice = await h.node('Alice', onboarded: true, nickname: 'Alice');
      final bob = await h.node('Bob', onboarded: true, nickname: 'Bob');
      final carol = await h.node('Carol', onboarded: true, nickname: 'Carol');
      h.world.setInRange(alice.phone, carol.phone, false);
      await h.show(alice);
      await h.until(() => alice.directlyReaches(bob), timeoutMs: 15000);
      await h.until(() => find.textContaining('via relay').evaluate().isNotEmpty,
          timeoutMs: 20000, reason: 'Carol is reachable through Bob');
      expect(find.textContaining('1 nearby'), findsWidgets);
      expect(find.textContaining('1 via relay'), findsWidgets);
      expect(tester.takeException(), isNull);
      await h.dispose();
    });

    testWidgets('Nearby shows the live connection with the other phone, and what was heard',
        (tester) async {
      final h = UiHarness(tester)..screen();
      final alice = await h.node('Alice', onboarded: true, nickname: 'Alice');
      final bob = await h.node('Bob', onboarded: true, nickname: 'Bob');
      await h.show(alice);
      await h.until(() => alice.directlyReaches(bob));
      await h.tap(_headerPill);

      expect(find.text('Connected phones (1)'), findsOneWidget);
      expect(find.text('Connected'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
      expect(find.textContaining('Write size'), findsOneWidget);
      expect(find.text('Visible to others'), findsOneWidget);
      expect(find.text('Yes'), findsWidgets);
      expect(find.textContaining('Devices heard'), findsOneWidget);
      await h.reveal(find.textContaining('not trusted until it completes the identity handshake'));

      // The indicator agrees.
      expect(find.text('1 nearby'), findsWidgets);
      expect(tester.takeException(), isNull);
      await h.dispose();
    });

    testWidgets('losing the other phone updates every screen', (tester) async {
      final h = UiHarness(tester)..screen();
      final alice = await h.node('Alice', onboarded: true, nickname: 'Alice');
      final bob = await h.node('Bob', onboarded: true, nickname: 'Bob');
      await h.show(alice);
      await h.until(() => alice.directlyReaches(bob));
      expect(find.text('Available now'), findsOneWidget);

      h.world.setInRange(alice.phone, bob.phone, false);
      await h.until(() => find.text('Available now').evaluate().isEmpty,
          reason: 'out of range means no longer "available now"');
      await h.tap(find.byKey(const Key('open-people')));
      expect(find.text('Offline'), findsWidgets);
      await tester.pageBack();
      await h.settle();

      h.world.setInRange(alice.phone, bob.phone, true);
      await h.until(() => alice.directlyReaches(bob), timeoutMs: 15000);
      await h.until(() => find.text('Available now').evaluate().isNotEmpty);

      expect(tester.takeException(), isNull);
      await h.dispose();
    });

    testWidgets('the public place is the built-in room, with its header and its field',
        (tester) async {
      final h = UiHarness(tester)..screen();
      final alice = await h.node('Alice', onboarded: true, nickname: 'Alice');
      await h.show(alice);
      await h.goToTab('Public');
      expect(find.byKey(const Key('room-label')), findsOneWidget);
      expect(find.text('@Alice'), findsOneWidget);
      expect(find.byKey(const Key('composer-field')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await h.dispose();
    });
  });
}
