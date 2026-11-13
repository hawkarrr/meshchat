import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_mesh_chat/core/app_info.dart';
import 'package:offline_mesh_chat/core/licences.dart' show registerBundledLicences;
import 'package:offline_mesh_chat/l10n/l10n.dart';

import '../support/ui_harness.dart';

/// Settings is a short menu: the profile, then one row for each subject, each opening a
/// page of its own. Everything the app can be set to, and everything it explains about
/// itself, is on one of those pages.
void main() {
  Future<UiHarness> open(WidgetTester tester, {AppLanguage language = AppLanguage.en}) async {
    final h = UiHarness(tester)..screen();
    final alice = await h.node('Alice', onboarded: true, nickname: 'Alice', language: language);
    await h.show(alice);
    await h.openTab('settings');
    return h;
  }

  group('the menu', () {
    testWidgets('has the profile and one row for each subject, in order, and nothing else',
        (tester) async {
      final h = await open(tester);

      expect(find.text('Settings'), findsWidgets);
      expect(find.byKey(const Key('settings-profile')), findsOneWidget);
      expect(find.text('Alice'), findsOneWidget);
      final rows = [
        ('settings-language', 'Language'),
        ('settings-appearance', 'Appearance'),
        ('settings-notifications', 'Notifications'),
        ('settings-privacy', 'Privacy and security'),
        ('settings-chat', 'Chats and Bluetooth'),
        ('settings-help', 'Help and instructions'),
        ('settings-about', 'About ${AppInfo.name}'),
      ];
      var top = 0.0;
      for (final (key, label) in rows) {
        expect(find.descendant(of: find.byKey(Key(key)), matching: find.text(label)), findsOneWidget,
            reason: key);
        final y = tester.getTopLeft(find.byKey(Key(key))).dy;
        expect(y, greaterThan(top), reason: '$key comes after the one above it');
        top = y;
      }
      // The language shows its current value, in its own words.
      expect(find.descendant(of: find.byKey(const Key('settings-language')), matching: find.text('English')),
          findsOneWidget);
      // No explanation sits on the menu itself: those are on the pages.
      expect(find.textContaining('encrypted'), findsNothing);
      expect(find.text('Permissions'), findsNothing);
      expect(find.text('Danger zone'), findsNothing);
      expect(tester.takeException(), isNull);
      await h.dispose();
    });

    testWidgets('every row opens its page, and Back returns to the menu', (tester) async {
      final h = await open(tester);
      for (final (key, title) in [
        ('settings-profile', 'Profile and identity'),
        ('settings-language', 'Language'),
        ('settings-appearance', 'Appearance'),
        ('settings-notifications', 'Notifications'),
        ('settings-privacy', 'Privacy and security'),
        ('settings-chat', 'Chats and Bluetooth'),
        ('settings-help', 'Help and instructions'),
        ('settings-about', 'About ${AppInfo.name}'),
      ]) {
        await h.tap(find.byKey(Key(key)));
        expect(find.descendant(of: find.byType(AppBar), matching: find.text(title)), findsOneWidget,
            reason: key);
        await tester.pageBack();
        await h.settle();
        expect(find.byKey(const Key('settings-profile')), findsOneWidget, reason: 'back at the menu');
      }
      expect(tester.takeException(), isNull);
      await h.dispose();
    });
  });

  group('the pages', () {
    testWidgets('profile: who you are, the fingerprint, and the name can be changed', (tester) async {
      final h = await open(tester);
      await h.tap(find.byKey(const Key('settings-profile')));
      final alice = h.nodes.first;

      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('#${alice.id.substring(0, 8)}'), findsOneWidget);
      expect(find.text(alice.controller.fingerprintText), findsOneWidget);
      await h.tap(find.byKey(const Key('edit-nickname')));
      expect(find.text('Your name'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Alicia');
      await h.tap(find.widgetWithText(FilledButton, 'Save'));
      await h.until(() => alice.controller.nickname == 'Alicia');
      expect(find.text('Alicia'), findsWidgets);
      expect(tester.takeException(), isNull);
      await h.dispose();
    });

    testWidgets('notifications: the switch and what a notification shows', (tester) async {
      final h = await open(tester);
      await h.tap(find.byKey(const Key('settings-notifications')));
      expect(find.byKey(const Key('notify-switch')), findsOneWidget);
      expect(find.byKey(const Key('notify-privacy')), findsOneWidget);
      expect(find.byKey(const Key('notify-public')), findsOneWidget);
      await h.dispose();
    });

    testWidgets('privacy and security: permissions, data, the log, and the two things that cannot be undone',
        (tester) async {
      final h = await open(tester);
      await h.tap(find.byKey(const Key('settings-privacy')));

      expect(find.text('Permissions'), findsOneWidget);
      expect(find.byKey(const Key('permission-bluetooth')), findsOneWidget);
      await h.reveal(find.byKey(const Key('retention')));
      expect(find.byKey(const Key('open-storage')), findsOneWidget);
      await h.reveal(find.text('Security log'));
      await h.reveal(find.text('Danger zone'));
      expect(find.byKey(const Key('reset-identity')), findsOneWidget);
      expect(find.byKey(const Key('clear-all-data')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await h.dispose();
    });

    testWidgets('chats and Bluetooth: how hard to look, the self-test, relaying, the background',
        (tester) async {
      final h = await open(tester);
      await h.tap(find.byKey(const Key('settings-chat')));

      expect(find.byKey(const Key('discovery-mode')), findsOneWidget);
      expect(find.text('Bluetooth self-test'), findsOneWidget);
      await h.reveal(find.byKey(const Key('relay-switch')));
      expect(find.byKey(const Key('relay-switch')), findsOneWidget);
      await h.reveal(find.byKey(const Key('keepalive-switch')));
      expect(tester.takeException(), isNull);
      await h.dispose();
    });

    testWidgets('help: what the app does and cannot do, each one a line that opens', (tester) async {
      final h = await open(tester);
      await h.tap(find.byKey(const Key('settings-help')));

      expect(find.text('How it works, and what it cannot do'), findsOneWidget);
      expect(find.text('Further, through other phones'), findsNothing);
      expect(find.text('Range, relaying and waiting'), findsOneWidget);
      // The permission explanation that used to fill the first page.
      await h.reveal(find.text('Permissions: what is asked, and when'));
      await h.tap(find.text('Permissions: what is asked, and when'));
      expect(find.textContaining('Android 11 and older'), findsOneWidget);
      await h.reveal(find.text('Not independently audited'));
      await h.tap(find.text('Not independently audited'));
      expect(find.textContaining('has not been reviewed by an independent security expert'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await h.dispose();
    });

    testWidgets('about: the name, the version, and the licences, the font\'s among them', (tester) async {
      registerBundledLicences();
      final h = await open(tester);
      await h.tap(find.byKey(const Key('settings-about')));

      expect(find.text(AppInfo.name), findsWidgets);
      expect(find.textContaining(AppInfo.version), findsOneWidget);
      await h.tap(find.byKey(const Key('open-licences')));
      expect(find.byType(LicensePage), findsOneWidget);
      await h.until(() => find.text('Noto Sans Arabic').evaluate().isNotEmpty,
          reason: 'the bundled font is in the list');
      expect(tester.takeException(), isNull);
      await h.dispose();
    });
  });

  group('in Kurdish', () {
    testWidgets('the menu turns around: titles at the right, arrows at the left, no overflow',
        (tester) async {
      final h = await open(tester, language: AppLanguage.ckb);
      final l = AppLanguage.ckb.strings;
      expect(find.text(l.setLanguage), findsOneWidget);
      final title = tester.getTopRight(find.text(l.setPrivacy)).dx;
      final arrow = tester.getTopLeft(find.descendant(
              of: find.byKey(const Key('settings-privacy')), matching: find.byIcon(Icons.chevron_right_rounded)))
          .dx;
      expect(title, greaterThan(180), reason: 'the title is at the right');
      expect(arrow, lessThan(100), reason: 'the arrow is at the left');
      for (final key in [
        'settings-profile',
        'settings-language',
        'settings-notifications',
        'settings-privacy',
        'settings-chat',
        'settings-help',
        'settings-about',
      ]) {
        await h.tap(find.byKey(Key(key)));
        expect(tester.takeException(), isNull, reason: key);
        // The back button's tooltip is in Kurdish here: go back the way the system does.
        await tester.binding.handlePopRoute();
        await h.settle();
      }
      await h.dispose();
    });
  });
}
