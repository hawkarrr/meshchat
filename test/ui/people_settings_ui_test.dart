import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_mesh_chat/core/app_info.dart';
import 'package:offline_mesh_chat/database/message_repository.dart';
import 'package:offline_mesh_chat/device/device_io.dart';
import 'package:offline_mesh_chat/screens/diagnostics_screen.dart';
import 'package:offline_mesh_chat/screens/home_screen.dart';
import 'package:offline_mesh_chat/screens/peer_detail_screen.dart';
import 'package:offline_mesh_chat/screens/security_log_screen.dart';
import 'package:offline_mesh_chat/screens/help_screen.dart';
import 'package:offline_mesh_chat/services/discovery_service.dart';
import 'package:offline_mesh_chat/services/network_status_service.dart';
import 'package:offline_mesh_chat/widgets/connection_indicator.dart';

import '../support/ui_harness.dart';

Finder get _headerPill =>
    find.descendant(of: find.byType(HomeScreen), matching: find.byType(ConnectionIndicator));

/// A page of the settings: `profile`, `privacy`, `chat`, `help`...
Future<void> _openSettings(UiHarness h, String page) => h.openSettingsPage(page);

Future<void> _openPeople(UiHarness h) => h.tap(find.byKey(const Key('open-people')));

void main() {
  group('people and verification', () {
    testWidgets('both phones show the same safety number, and verifying is remembered',
        (tester) async {
      final h = UiHarness(tester)..screen();
      final alice = await h.node('Alice', onboarded: true, nickname: 'Alice');
      final bob = await h.node('Bob', onboarded: true, nickname: 'Bob');
      await h.show(alice);
      await h.until(() => alice.directlyReaches(bob) && bob.directlyReaches(alice));

      await _openPeople(h);
      expect(find.text('Bob'), findsOneWidget);
      expect(find.text('Direct'), findsWidgets);
      await h.tap(find.byTooltip('Contact details and verification'));
      await h.until(() => find.byType(PeerDetailScreen).evaluate().isNotEmpty);
      await h.loaded();
      expect(find.text('Not verified yet'), findsOneWidget);
      expect(find.textContaining('compare this safety number'), findsOneWidget);

      // The number Alice sees is the number Bob computes for Alice.
      final bobsNumber = await h.real(() async {
        final aliceAsSeenByBob = (await bob.controller.peer(alice.id))!;
        return bob.controller.safetyNumberFor(aliceAsSeenByBob);
      });
      expect(bobsNumber, isNotNull);
      expect(find.text(bobsNumber!), findsOneWidget);

      await h.reveal(find.text('The numbers match'));
      await h.tap(find.text('The numbers match'));
      await h.until(() => find.text('Verified').evaluate().isNotEmpty);
      expect((await h.real(() => alice.controller.peer(bob.id)))!.verified, isTrue);

      await tester.pageBack();
      await h.until(() =>
          find.byType(PeerDetailScreen).evaluate().isEmpty &&
          find.byIcon(Icons.verified_user_rounded).evaluate().isNotEmpty);
      expect(find.byIcon(Icons.verified_user_rounded), findsWidgets);

      expect(tester.takeException(), isNull);
      await h.dispose();
    });

    testWidgets('renaming a contact and blocking them', (tester) async {
      final h = UiHarness(tester)..screen();
      final alice = await h.node('Alice', onboarded: true, nickname: 'Alice');
      final bob = await h.node('Bob', onboarded: true, nickname: 'Bob');
      await h.show(alice);
      await h.until(() => alice.directlyReaches(bob));

      await _openPeople(h);
      await h.tap(find.byTooltip('Contact details and verification'));
      await h.loaded();
      await h.reveal(find.text('Rename'));
      await h.tap(find.text('Rename'));
      await tester.enterText(find.byType(TextField), 'Robert (work)');
      await h.tap(find.widgetWithText(FilledButton, 'Save'));
      await h.until(() => find.byType(Dialog).evaluate().isEmpty);
      // The header scrolled out of the (lazily built) list while revealing 'Rename'.
      await tester.drag(find.byType(ListView).first, const Offset(0, 2000));
      await h.until(() => find.textContaining('calls themselves').evaluate().isNotEmpty);
      expect(find.text('Robert (work)'), findsWidgets);
      expect(find.textContaining('calls themselves "Bob"'), findsOneWidget);

      await h.reveal(find.text('Block'));
      await h.tap(find.text('Block'));
      await h.until(() => alice.controller.peers.single.peer.blocked);

      await tester.pageBack();
      await h.until(() =>
          find.byType(PeerDetailScreen).evaluate().isEmpty &&
          find.byIcon(Icons.block_rounded).evaluate().isNotEmpty);
      expect(find.byIcon(Icons.block_rounded), findsWidgets);
      expect(find.text('Robert (work)'), findsOneWidget);

      expect(tester.takeException(), isNull);
      await h.dispose();
    });

    testWidgets('deleting a contact asks first', (tester) async {
      final h = UiHarness(tester)..screen();
      final alice = await h.node('Alice', onboarded: true, nickname: 'Alice');
      final bob = await h.node('Bob', onboarded: true, nickname: 'Bob');
      await h.show(alice);
      await h.until(() => alice.directlyReaches(bob));
      await _openPeople(h);
      await h.tap(find.byTooltip('Contact details and verification'));
      await h.loaded();

      await h.reveal(find.text('Delete contact'));
      await h.tap(find.text('Delete contact'));
      expect(find.text('Delete this contact?'), findsOneWidget);
      await h.tap(find.text('Cancel'));
      await h.until(() => find.byType(Dialog).evaluate().isEmpty);
      expect(find.byType(PeerDetailScreen), findsOneWidget, reason: 'cancelled: nothing happens');

      await h.tap(find.text('Delete contact'));
      await h.tap(find.byKey(const Key('confirm-action')));
      await h.until(() => find.byType(PeerDetailScreen).evaluate().isEmpty,
          reason: 'deleting closes the contact page');

      expect(tester.takeException(), isNull);
      await h.dispose();
    });
  });

  group('settings', () {
    testWidgets('shows who you are, and the name can be changed', (tester) async {
      final h = UiHarness(tester)..screen();
      final alice = await h.node('Alice', onboarded: true, nickname: 'Alice');
      await h.show(alice);
      await h.openTab('settings');
      expect(find.text('#${alice.id.substring(0, 8)}'), findsOneWidget, reason: 'on the menu too');
      await h.tap(find.byKey(const Key('settings-profile')));

      expect(find.text('Alice'), findsWidgets);
      expect(find.text('#${alice.id.substring(0, 8)}'), findsOneWidget);
      expect(find.text(alice.controller.fingerprintText), findsOneWidget);

      await h.tap(find.byKey(const Key('edit-nickname')));
      expect(find.text('Your name'), findsOneWidget);
      expect(find.textContaining('not unique and nobody checks it'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Alicia');
      await h.tap(find.widgetWithText(FilledButton, 'Save'));
      await h.until(() => alice.controller.nickname == 'Alicia');
      expect(find.text('Alicia'), findsWidgets);

      expect(tester.takeException(), isNull);
      await h.dispose();
    });

    testWidgets('discovery mode and message retention are saved', (tester) async {
      final h = UiHarness(tester)..screen();
      final alice = await h.node('Alice', onboarded: true);
      await h.show(alice);
      await _openSettings(h, 'chat');

      await h.reveal(find.byKey(const Key('discovery-mode')));
      await h.tap(find.byKey(const Key('discovery-mode')));
      await h.tap(find.text('Battery saver').last);
      await h.until(() => alice.controller.discoveryMode == DiscoveryMode.lowPower);
      expect(alice.controller.discovery.mode, DiscoveryMode.lowPower);

      await tester.binding.handlePopRoute();
      await h.settle();
      await h.tap(find.byKey(const Key('settings-privacy')));
      await h.reveal(find.byKey(const Key('retention')));
      await h.tap(find.byKey(const Key('retention')));
      await h.tap(find.text('7 days').last);
      await h.until(() => alice.controller.retentionDays == 7);

      expect(tester.takeException(), isNull);
      await h.dispose();
    });

    testWidgets('the internet row is purely informational, and says so', (tester) async {
      final h = UiHarness(tester)..screen();
      final alice = await h.node('Alice', onboarded: true, network: NetworkKind.wifi);
      await h.show(alice);
      await _openSettings(h, 'chat');
      await h.reveal(find.textContaining('Wi-Fi is on (not used by this app)'));
      expect(find.textContaining('${AppInfo.name} never uses the internet'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await h.dispose();
    });

    testWidgets('the limits are stated plainly, including that nothing was audited', (tester) async {
      final h = UiHarness(tester)..screen();
      final alice = await h.node('Alice', onboarded: true);
      await h.show(alice);
      await _openSettings(h, 'help');
      Finder heading(String text) =>
          find.descendant(of: find.byType(HelpScreen), matching: find.text(text));


      await h.reveal(heading('Not independently audited'));
      await h.tap(heading('Not independently audited'));
      expect(find.textContaining('has not been reviewed by an independent security expert'),
          findsOneWidget);

      await h.reveal(heading('The background is not guaranteed'));
      await h.tap(heading('The background is not guaranteed'));
      expect(find.textContaining('does not try to get around that'), findsOneWidget);

      await h.reveal(heading('Range, relaying and waiting'));
      await h.tap(heading('Range, relaying and waiting'));
      expect(find.textContaining('tested with simulated radios only'), findsOneWidget,
          reason: 'relaying must not be advertised as proven on real phones');
      expect(find.textContaining('not yet been proven on real phones'), findsOneWidget);

      await h.reveal(heading('Pictures, voice messages and videos'));
      await h.tap(heading('Pictures, voice messages and videos'));
      expect(find.textContaining('can stay incomplete if a piece of it is lost'), findsOneWidget);

      await h.reveal(heading('Public rooms'));
      await h.tap(heading('Public rooms'));
      expect(find.textContaining('is NOT private'), findsOneWidget);

      await h.reveal(heading('Groups'));
      await h.tap(heading('Groups'));
      expect(find.textContaining('every change gives the group a new key'), findsOneWidget);

      await h.reveal(heading('What is stored on this phone'));
      await h.tap(heading('What is stored on this phone'));
      expect(find.textContaining('without an extra layer of encryption'), findsOneWidget);

      expect(tester.takeException(), isNull);
      await h.dispose();
    });

    testWidgets('permissions are listed, each can be granted on request, none is asked for earlier',
        (tester) async {
      final h = UiHarness(tester)..screen();
      final alice = await h.node('Alice', onboarded: true);
      final perms = h.permissionsOf(alice);
      await h.show(alice);
      await _openSettings(h, 'privacy');
      await h.reveal(find.text('Permissions'));
      await h.until(() => find.byKey(const Key('allow-microphone')).evaluate().isNotEmpty);

      expect(find.text('Permissions'), findsOneWidget);
      expect(find.text('Bluetooth (nearby devices)'), findsOneWidget);
      for (final p in ['Microphone', 'Camera', 'Photos']) {
        expect(find.text(p), findsOneWidget);
      }
      expect(perms.requested, isEmpty, reason: 'looking at the list asks for nothing');

      // Allow the microphone: the app explains first, then asks the system.
      await h.reveal(find.byKey(const Key('allow-microphone')));
      await h.tap(find.byKey(const Key('allow-microphone')));
      expect(find.text('Allow the microphone?'), findsOneWidget);
      expect(find.textContaining('only while you are recording a voice message'), findsOneWidget);
      expect(perms.requested, isEmpty, reason: 'nothing is asked before the explanation is accepted');
      await h.tap(find.byKey(const Key('permission-continue')));
      await h.until(() => perms.requested.contains(AppPermission.microphone));
      await h.until(() => find.byKey(const Key('allow-microphone')).evaluate().isEmpty,
          reason: 'it now shows as allowed');

      // A permission switched off for good sends the person to the system settings.
      perms.set(AppPermission.camera, PermissionOutcome.permanentlyDenied);
      await h.until(() => find.byKey(const Key('allow-camera')).evaluate().isNotEmpty ||
          true);
      // Leaving the page and coming back shows what the phone says now.
      await tester.binding.handlePopRoute();
      await h.settle();
      await h.tap(find.byKey(const Key('settings-privacy')));
      await h.until(() => find.byKey(const Key('allow-camera')).evaluate().isNotEmpty);
      await h.reveal(find.byKey(const Key('allow-camera')));
      expect(find.text('Settings'), findsWidgets);
      await h.tap(find.byKey(const Key('allow-camera')));
      expect(find.text('The camera is switched off'), findsOneWidget);
      await h.tap(find.byKey(const Key('permission-open-settings')));
      await h.until(() => perms.settingsOpened == 1);

      expect(tester.takeException(), isNull);
      await h.dispose();
    });

    testWidgets('resetting the identity needs a confirmation and can be cancelled', (tester) async {
      final h = UiHarness(tester)..screen();
      final alice = await h.node('Alice', onboarded: true, nickname: 'Alice');
      await h.show(alice);
      await _openSettings(h, 'privacy');
      final before = alice.id;

      await h.reveal(find.byKey(const Key('reset-identity')));
      await h.tap(find.byKey(const Key('reset-identity')));
      expect(find.text('Reset your identity?'), findsOneWidget);
      expect(find.textContaining('must verify your new'), findsOneWidget);
      await h.tap(find.text('Cancel'));
      expect(alice.id, before, reason: 'cancelling changes nothing');

      await h.tap(find.byKey(const Key('reset-identity')));
      await h.tap(find.byKey(const Key('confirm-action')));
      await h.until(() => alice.id != before);
      await h.until(() => alice.controller.networkingStarted,
          reason: 'Bluetooth is restarted with the new identity');
      await h.until(() => find.text('You have a new identity').evaluate().isNotEmpty);

      expect(tester.takeException(), isNull);
      await h.dispose();
    });

    testWidgets('deleting everything needs the word "delete" typed, then wipes the phone',
        (tester) async {
      final h = UiHarness(tester)..screen();
      final alice = await h.node('Alice', onboarded: true, nickname: 'Alice');
      await h.real(() => alice.controller.createRoom('lobby'));
      await h.real(() => alice.controller.setRetentionDays(30));
      await h.show(alice);
      await _openSettings(h, 'privacy');
      final before = alice.id;

      await h.reveal(find.byKey(const Key('clear-all-data')));
      await h.tap(find.byKey(const Key('clear-all-data')));
      expect(find.text('Delete everything on this phone?'), findsOneWidget);
      FilledButton confirm() =>
          tester.widget<FilledButton>(find.byKey(const Key('confirm-action')));
      expect(confirm().onPressed, isNull, reason: 'disabled until the word is typed');

      await tester.enterText(find.byKey(const Key('confirm-text')), 'dele');
      await tester.pump();
      expect(confirm().onPressed, isNull);
      await tester.enterText(find.byKey(const Key('confirm-text')), 'DELETE');
      await tester.pump();
      expect(confirm().onPressed, isNotNull);

      // Dismiss the keyboard first, as a person would: the text field's
      // selection handle can otherwise sit on top of the button.
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      await h.tap(find.byKey(const Key('confirm-action')));
      // The confirmation appears once everything has been wiped and rebuilt.
      await h.until(() => find.text('All local data was deleted').evaluate().isNotEmpty,
          reason: 'the wipe should finish');
      expect(alice.id, isNot(before));
      expect(alice.controller.groups, isEmpty);
      expect(alice.controller.rooms.map((r) => r.label), ['#mesh']);
      expect(alice.controller.retentionDays, 0);
      expect(alice.controller.nickname, startsWith('Phone '));
      expect(alice.controller.networkingStarted, isTrue, reason: 'the phone keeps working');

      expect(tester.takeException(), isNull);
      await h.dispose();
    });
  });

  group('Bluetooth self-test screen', () {
    testWidgets('with another phone nearby it passes, and the report can be copied',
        (tester) async {
      final h = UiHarness(tester)..screen();
      final clipboard = h.recordClipboard();
      final alice = await h.node('Alice', onboarded: true, nickname: 'Alice');
      final bob = await h.node('Bob', onboarded: true, nickname: 'Bob');
      await h.show(alice);
      await h.until(() => alice.directlyReaches(bob));

      await h.tap(_headerPill);
      await h.tap(find.text('Run Bluetooth self-test'));
      expect(find.byType(DiagnosticsScreen), findsOneWidget);
      expect(find.text('Run self-test'), findsOneWidget);
      expect(tester.widget<OutlinedButton>(find.byKey(const Key('copy-report'))).onPressed, isNull,
          reason: 'nothing to copy before a run');

      // The fake clock must not outrun the real one while Bluetooth probes wait for replies.
      await h.tap(find.byKey(const Key('run-self-test')), pumpMs: 30);
      await h.until(() => find.byKey(const Key('self-test-verdict')).evaluate().isNotEmpty,
          timeoutMs: 25000, pumpMs: 30, reason: 'the run should finish with a verdict');
      expect(find.text('Everything that could be tested passed'), findsOneWidget);
      expect(find.text('Run again'), findsOneWidget);

      await h.reveal(find.byKey(const Key('check-exchange')));
      expect(find.textContaining('5/5 small'), findsOneWidget);
      expect(find.textContaining('3/3 large'), findsOneWidget);

      await h.scrollToTop();
      await h.tap(find.byKey(const Key('copy-report')));
      expect(clipboard.text, contains('${AppInfo.latinName} - BLE self-test'));
      expect(clipboard.text, contains('Connected and verified key ownership with: Bob'));
      expect(clipboard.text, contains('[PASS] Sending data both ways'));
      expect(clipboard.text, contains('Result: PASSED'));

      expect(tester.takeException(), isNull);
      await h.dispose();
    });

    testWidgets('with Bluetooth off it fails fast and says how to fix it', (tester) async {
      final h = UiHarness(tester)..screen();
      final alice = await h.node('Alice', onboarded: true, nickname: 'Alice');
      await h.show(alice);
      alice.phone.setBluetooth(false);
      await h.until(() => !alice.controller.radioStatus.canScan);

      await h.tap(_headerPill);
      await h.tap(find.text('Run Bluetooth self-test'));
      await h.tap(find.byKey(const Key('run-self-test')));
      await h.until(() => find.byKey(const Key('self-test-verdict')).evaluate().isNotEmpty);
      expect(find.text('A problem was found'), findsOneWidget);
      await h.reveal(find.textContaining('quick settings'));
      expect(find.textContaining('quick settings'), findsOneWidget);

      expect(tester.takeException(), isNull);
      await h.dispose();
    });

    testWidgets('a run can be stopped while it waits for another phone', (tester) async {
      final h = UiHarness(tester)..screen();
      final alice = await h.node('Alice', onboarded: true, nickname: 'Alice');
      await h.show(alice);
      await h.tap(_headerPill);
      await h.tap(find.text('Run Bluetooth self-test'));
      await h.tap(find.byKey(const Key('run-self-test')));
      await h.until(() => find.byKey(const Key('stop-self-test')).evaluate().isNotEmpty);

      await h.tap(find.byKey(const Key('stop-self-test')));
      await h.until(() => find.byKey(const Key('run-self-test')).evaluate().isNotEmpty,
          reason: 'after stopping, the run button comes back');
      expect(find.text('Run again'), findsOneWidget);
      expect(find.text('A problem was found'), findsNothing,
          reason: 'stopping must not be reported as a failure');

      expect(tester.takeException(), isNull);
      await h.dispose();
    });
  });

  group('security log', () {
    testWidgets('is empty at first, lists problems in plain words, and can be cleared',
        (tester) async {
      final h = UiHarness(tester)..screen();
      final alice = await h.node('Alice', onboarded: true, nickname: 'Alice');
      final bob = await h.node('Bob', onboarded: true, nickname: 'Bob');
      await h.show(alice);
      await h.until(() => alice.directlyReaches(bob));

      await _openSettings(h, 'privacy');
      await h.reveal(find.text('Security log'));
      await h.tap(find.text('Security log'));
      expect(find.byType(SecurityLogScreen), findsOneWidget);
      await h.loaded();
      expect(find.text('Nothing suspicious recorded'), findsOneWidget);

      await h.real(() async {
        final now = DateTime.now().millisecondsSinceEpoch;
        await alice.controller.repo.recordSecurityEvent(SecurityEventKind.badSignature,
            peerId: bob.id, detail: 'checked a relayed packet', atMs: now);
        await alice.controller.repo.recordSecurityEvent(SecurityEventKind.keyChanged,
            peerId: bob.id, atMs: now + 1);
        await alice.controller.repo.recordSecurityEvent(SecurityEventKind.notAMember,
            peerId: bob.id, atMs: now + 2);
        await alice.controller.repo.recordSecurityEvent(SecurityEventKind.badMedia,
            peerId: bob.id, atMs: now + 3);
      });
      await h.until(() => find.text('Nothing suspicious recorded').evaluate().isEmpty);
      // Newest first, and the list builds lazily: scroll to each entry in turn.
      for (final title in [
        'A picture or voice message was damaged',
        'Someone acted without being allowed to',
        'A contact\'s encryption key changed',
        'A message had an invalid signature',
      ]) {
        await h.reveal(find.text(title));
        expect(find.text(title), findsOneWidget, reason: title);
      }
      expect(find.textContaining('Bob'), findsWidgets, reason: 'the peer is named, not a hex id');
      expect(find.textContaining('checked a relayed packet'), findsOneWidget);

      await h.tap(find.byTooltip('Clear log'));
      expect(find.text('Clear the security log?'), findsOneWidget);
      await h.tap(find.widgetWithText(FilledButton, 'Clear'));
      await h.until(() => find.text('Nothing suspicious recorded').evaluate().isNotEmpty);

      expect(tester.takeException(), isNull);
      await h.dispose();
    });
  });

  testWidgets('large system text does not break the main screens', (tester) async {
    final h = UiHarness(tester)..screen();
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final alice = await h.node('Alice', onboarded: true, nickname: 'Alice');
    final bob = await h.node('Bob', onboarded: true, nickname: 'Bob');
    await h.show(alice);
    await h.until(() => alice.directlyReaches(bob));
    await h.real(() => alice.controller.sendDirect(bob.id, 'hello there'));
    await h.settle();

    for (final tab in ['Groups', 'Public', 'Settings', 'Private']) {
      await h.goToTab(tab);
      expect(tester.takeException(), isNull, reason: 'tab $tab at 160% text size');
    }
    for (final open in [
      () => _openPeople(h),
      () => h.tap(_headerPill),
    ]) {
      await open();
      expect(tester.takeException(), isNull, reason: 'screen at 160% text size');
      await tester.pageBack();
      await h.settle();
    }
    await h.tap(find.text('hello there'));
    expect(tester.takeException(), isNull, reason: 'chat at 160% text size');

    await h.dispose();
  });
}
