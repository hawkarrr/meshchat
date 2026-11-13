import 'dart:io' show Directory;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_mesh_chat/l10n/l10n.dart';
import 'package:offline_mesh_chat/models/conversation.dart';
import 'package:offline_mesh_chat/protocol/room_record.dart';

import '../support/shots.dart';
import '../support/ui_harness.dart';

/// Visual check, not a regression test: the home screen as a person meets it - the
/// public room first, then the private chats, the groups and the settings - in Kurdish,
/// Arabic and English, written to `build/shots/home_*.png` for a person to look at.
///
///     flutter test test/visual/redesign_shots_test.dart
const String _mesh = 'rm:${PublicRooms.meshIdHex}';

/// Draws real shadows (the test renderer's default is a solid outline) and puts the
/// setting back before the test ends, as the framework insists.
void _testShots(String name, Future<void> Function(WidgetTester tester) body) {
  testWidgets(name, (tester) async {
    debugDisableShadows = false;
    try {
      await body(tester);
    } finally {
      debugDisableShadows = true;
    }
  }, timeout: const Timeout(Duration(minutes: 4)));
}

class _Cast {
  const _Cast(this.me, this.bob, this.carol, this.lines);

  final String me;
  final String bob;
  final String carol;

  /// bob, carol, me, bob
  final List<String> lines;
}

const Map<AppLanguage, _Cast> _casts = {
  AppLanguage.ckb: _Cast('ئارام', 'ڕێبوار', 'شادی', [
    'سڵاو بۆ هەمووان',
    'کێ لە نزیک بازاڕە؟',
    'من لێرەم، لە تەنیشت چایخانەکە',
    'باشە، دێم',
  ]),
  AppLanguage.ar: _Cast('سامي', 'ليلى', 'عمر', [
    'مرحباً بالجميع',
    'من قريب من السوق؟',
    'أنا هنا، بجانب المقهى',
    'حسناً، قادم',
  ]),
  AppLanguage.en: _Cast('Alice', 'Bob', 'Carol', [
    'hello everyone',
    'anyone near the market?',
    'I am here, next to the cafe',
    'ok, coming',
  ]),
};

void main() {
  setUpAll(() async {
    await loadShotFonts();
    goldenFileComparator = ShotWriter(Directory('build/shots'));
  });

  for (final language in AppLanguage.values) {
    final code = language.code;
    final l = language.strings;
    final cast = _casts[language]!;

    _testShots('$code: the public room is the first thing, empty and then alive', (tester) async {
      final h = UiHarness(tester)..screen(390, 844);
      final alice = await h.node('Alice', onboarded: true, nickname: cast.me, language: language);
      final bob = await h.node('Bob', onboarded: true, nickname: cast.bob);
      final carol = await h.node('Carol', onboarded: true, nickname: cast.carol);
      await h.show(alice, landing: true);
      await h.settle(300);
      await shot(tester, 'home_${code}_01_landing');

      await h.until(() => alice.directlyReaches(bob) && alice.directlyReaches(carol),
          timeoutMs: 30000);
      await h.real(() => bob.controller.sendText(_mesh, cast.lines[0]));
      await h.real(() => carol.controller.sendText(_mesh, cast.lines[1]));
      await h.until(() => find.text(cast.lines[1]).evaluate().isNotEmpty, timeoutMs: 30000);
      await tester.enterText(find.byKey(const Key('composer-field')), cast.lines[2]);
      await tester.pump();
      await h.tap(find.byKey(const Key('composer-send')));
      await h.until(() => find.text(cast.lines[2]).evaluate().isNotEmpty);
      await h.real(() => bob.controller.sendText(_mesh, cast.lines[3]));
      await h.until(() => find.text(cast.lines[3]).evaluate().isNotEmpty, timeoutMs: 30000);
      await h.settle(300);
      await shot(tester, 'home_${code}_02_public_room');

      // The rooms list (the room's name opens it).
      await h.tap(find.byKey(const Key('room-label')));
      await h.settle(300);
      await shot(tester, 'home_${code}_03_rooms');
      expect(tester.takeException(), isNull);
      await h.dispose();
    });

    _testShots('$code: private chats, groups and settings', (tester) async {
      final h = UiHarness(tester)..screen(390, 844);
      final alice = await h.node('Alice', onboarded: true, nickname: cast.me, language: language);
      final bob = await h.node('Bob', onboarded: true, nickname: cast.bob);
      await h.show(alice);
      await h.until(
          () => alice.directlyReaches(bob) && (alice.viewOf(bob)?.peer.canReceiveEncrypted ?? false),
          timeoutMs: 30000);
      await h.real(() => alice.controller.openChat(bob.id));
      await h.real(() => alice.controller.createGroup('Hikers', [bob.id]));
      await h.real(() => bob.controller.openChat(alice.id));
      await h.real(() => bob.controller.sendText(Conversation.directId(alice.id), cast.lines[0]));
      await h.goToTab(l.navPrivate);
      await h.settle(600);
      await shot(tester, 'home_${code}_04_private');
      await h.goToTab(l.navGroups);
      await h.settle(300);
      await shot(tester, 'home_${code}_05_groups');
      expect(tester.takeException(), isNull);
      await h.dispose();
    });

    _testShots('$code: the settings menu and each of its pages', (tester) async {
      final h = UiHarness(tester)..screen(390, 844);
      final alice = await h.node('Alice', onboarded: true, nickname: cast.me, language: language);
      await h.show(alice, landing: true);
      await h.goToTab(l.settingsTitle);
      await h.settle(300);
      await shot(tester, 'home_${code}_06_settings');
      var n = 7;
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
        await h.settle(300);
        await shot(tester, 'home_${code}_0${n++}_$key');
        await h.tester.binding.handlePopRoute();
        await h.settle();
      }
      expect(tester.takeException(), isNull);
      await h.dispose();
    });
  }
}
