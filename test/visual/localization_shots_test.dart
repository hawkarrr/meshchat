import 'dart:io' show Directory;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_mesh_chat/l10n/l10n.dart';
import 'package:offline_mesh_chat/models/conversation.dart';
import 'package:offline_mesh_chat/protocol/room_record.dart';

import '../support/shots.dart';
import '../support/ui_harness.dart';

/// Visual check, not a regression test: the screens in Kurdish and in Arabic,
/// drawn with a font that has their letters, written to `build/shots/` as
/// `ckb_*.png` and `ar_*.png` for a person to look at. It always passes unless a
/// screen throws.
///
///     flutter test test/visual/localization_shots_test.dart
///
/// On a phone the system's own font draws these letters; here Windows' Arial is
/// used when it exists (it has the Kurdish letters), otherwise the Roboto of the
/// Flutter SDK, which has no Arabic script and shows empty boxes (see
/// `test/support/shots.dart`).
const String _mesh = 'rm:${PublicRooms.meshIdHex}';

/// The system's back: a button's tooltip is in the language of the phone, so
/// `tester.pageBack()` (which looks for "Back") would not find it.
Future<void> back(UiHarness h) async {
  await h.tester.binding.handlePopRoute();
  await h.settle();
}

/// What the people in the shots say, in the language of the phone being shown.
class _Script {
  const _Script({
    required this.me,
    required this.bob,
    required this.carol,
    required this.question,
    required this.answer,
    required this.group,
    required this.groupLine,
    required this.groupReply,
    required this.roomLine,
  });

  final String me;
  final String bob;
  final String carol;
  final String question;
  final String answer;
  final String group;
  final String groupLine;
  final String groupReply;
  final String roomLine;
}

const _scripts = <AppLanguage, _Script>{
  AppLanguage.ckb: _Script(
    me: 'ئارام',
    bob: 'شنۆ',
    carol: 'دانا',
    question: 'سڵاو! ئەمڕۆ دێیت بۆ پیکنیکەکە؟',
    answer: 'بەڵێ، ساندوێچ دەهێنم',
    group: 'پلانی کۆتایی هەفتە',
    groupLine: 'شەممە کاتژمێر 10؟',
    groupReply: 'بۆ من باشە',
    roomLine: 'کەسێک لە نزیک وێستگەکەیە؟',
  ),
  AppLanguage.ar: _Script(
    me: 'سارة',
    bob: 'أحمد',
    carol: 'ليلى',
    question: 'مرحبا! هل ستأتي إلى النزهة اليوم؟',
    answer: 'نعم، سأحضر الشطائر',
    group: 'خطة نهاية الأسبوع',
    groupLine: 'السبت الساعة 10؟',
    groupReply: 'يناسبني',
    roomLine: 'هل من أحد قرب المحطة؟',
  ),
};

/// Draws real shadows (the test renderer's default is a solid outline) and puts
/// the setting back before the test ends, as the framework insists.
void _testShots(String name, Future<void> Function(WidgetTester tester) body, {Timeout? timeout}) {
  testWidgets(name, (tester) async {
    debugDisableShadows = false;
    try {
      await body(tester);
    } finally {
      debugDisableShadows = true;
    }
  }, timeout: timeout);
}

void main() {
  setUpAll(() async {
    await loadShotFonts();
    goldenFileComparator = ShotWriter(Directory('build/shots'));
  });

  for (final language in [AppLanguage.ckb, AppLanguage.ar]) {
    final code = language.code;
    final l = language.strings;
    final say = _scripts[language]!;

    _testShots('$code: the first page', (tester) async {
      final h = UiHarness(tester)..screen(390, 844);
      final fresh = await h.node('Fresh', language: language);
      await h.show(fresh);
      await shot(tester, '${code}_01_onboarding');
      await h.reveal(find.byKey(const Key('onboarding-start')));
      await shot(tester, '${code}_02_onboarding_end');
      await h.dispose();
    });

    _testShots('$code: the main screens', (tester) async {
      final h = UiHarness(tester)..screen(390, 844);
      final alice = await h.node('Alice', onboarded: true, nickname: say.me, language: language);
      final bob = await h.node('Bob', onboarded: true, nickname: say.bob);
      final carol = await h.node('Carol', onboarded: true, nickname: say.carol);
      await h.show(alice);
      await h.until(
          () =>
              alice.directlyReaches(bob) &&
              alice.directlyReaches(carol) &&
              bob.directlyReaches(alice) &&
              (alice.viewOf(bob)?.peer.canReceiveEncrypted ?? false) &&
              (alice.viewOf(carol)?.peer.canReceiveEncrypted ?? false),
          timeoutMs: 30000);

      final withBob = Conversation.directId(bob.id);
      await h.real(() async {
        await bob.controller.sendDirect(alice.id, say.question);
        await alice.controller.sendDirect(bob.id, say.answer);
        await bob.controller.sendDirect(alice.id, 'Meet at ten, by the lake');
      });
      final plans = await h.real(() => alice.controller.createGroup(say.group, [bob.id, carol.id]));
      await h.untilAsync(() async {
        final gb = await bob.controller.group(plans.id);
        final gc = await carol.controller.group(plans.id);
        return gb != null && gc != null;
      }, timeoutMs: 30000);
      final groupChat = Conversation.groupConversationId(plans.id);
      await h.real(() async {
        await bob.controller.acceptGroup(plans.id);
        await carol.controller.acceptGroup(plans.id);
        await alice.controller.sendText(groupChat, say.groupLine);
        await bob.controller.sendText(groupChat, say.groupReply);
      });
      await h.real(() async {
        await bob.controller.sendText(_mesh, say.roomLine);
        await alice.controller.sendText(_mesh, say.answer);
      });
      await h.untilAsync(() async => (await alice.controller.loadMessages(withBob)).length >= 3);
      await h.until(() => find.byKey(Key('conversation-$withBob')).evaluate().isNotEmpty);
      await h.settle(200);

      await shot(tester, '${code}_10_private_list');
      await h.goToTab(l.navGroups);
      await shot(tester, '${code}_11_groups');
      await h.goToTab(l.navPublic);
      await shot(tester, '${code}_12_public');
      await h.goToTab(l.navPrivate);

      await h.tap(find.byKey(Key('conversation-$withBob')));
      await h.until(() => find.text(say.question).evaluate().isNotEmpty);
      await h.settle(300);
      await shot(tester, '${code}_20_chat');
      await tester.longPress(find.text(say.answer).first);
      await h.settle();
      await shot(tester, '${code}_21_message_menu');
      await h.tap(find.byKey(const Key('act-select')));
      await h.tap(find.byKey(const Key('selection-delete')));
      await shot(tester, '${code}_22_delete_dialog');
      await h.tap(find.byKey(const Key('delete-cancel')));
      await h.tap(find.byKey(const Key('selection-close')));
      await back(h);

      await h.goToTab(l.navGroups);
      await h.tap(find.byKey(Key('conversation-$groupChat')));
      await h.until(() => find.text(say.groupReply).evaluate().isNotEmpty);
      await shot(tester, '${code}_30_group_chat');
      await h.tap(find.byKey(const Key('group-info')));
      await shot(tester, '${code}_31_group_details');
      await back(h);
      await back(h);

      await h.openTab('public');
      await h.until(() => find.byKey(const Key('room-expiry-note')).evaluate().isNotEmpty);
      await h.settle(300);
      await shot(tester, '${code}_40_room');
      await h.tap(find.byKey(const Key('room-label')));
      await shot(tester, '${code}_41_rooms_sheet');
      await tester.tapAt(const Offset(195, 60));
      await h.settle();

      // The settings: the menu, then each page.
      await h.goToTab(l.settingsTitle);
      await shot(tester, '${code}_50_settings');
      final pages = <String, Finder>{
        'profile': find.byKey(const Key('edit-nickname')),
        'language': find.byKey(const Key('language-picker')),
        'notifications': find.byKey(const Key('notify-switch')),
        'privacy': find.byKey(const Key('reset-identity')),
        'chat': find.byKey(const Key('relay-switch')),
        'help': find.text(l.honestyNoInternetTitle),
        'about': find.byKey(const Key('open-licences')),
      };
      var n = 51;
      for (final page in pages.entries) {
        await h.tap(find.byKey(Key('settings-${page.key}')));
        await h.reveal(page.value);
        if (page.key == 'help') await h.tap(page.value);
        await shot(tester, '${code}_${n++}_settings_${page.key}');
        await back(h);
      }

      expect(tester.takeException(), isNull);
      await h.dispose();
    }, timeout: const Timeout(Duration(minutes: 6)));
  }

  _testShots('ckb: a narrow phone with large text', (tester) async {
    final h = UiHarness(tester)..screen(320, 640);
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final language = AppLanguage.ckb;
    final l = language.strings;
    final fresh = await h.node('Fresh', language: language);
    await h.show(fresh);
    await shot(tester, 'ckb_90_narrow_onboarding');

    final alice =
        await h.node('Alice', onboarded: true, nickname: _scripts[language]!.me, language: language);
    await h.show(alice);
    await h.goToTab(l.settingsTitle);
    await shot(tester, 'ckb_91_narrow_settings');
    await h.tap(find.byKey(const Key('settings-notifications')));
    await shot(tester, 'ckb_92_narrow_notifications');
    await back(h);
    await h.tap(find.byKey(const Key('settings-chat')));
    await h.reveal(find.byKey(const Key('relay-switch')));
    await shot(tester, 'ckb_93_narrow_mesh');
    expect(tester.takeException(), isNull);
    await h.dispose();
  }, timeout: const Timeout(Duration(minutes: 3)));
}
