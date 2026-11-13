import 'dart:io' show Directory;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_mesh_chat/l10n/l10n.dart';
import 'package:offline_mesh_chat/models/conversation.dart';
import 'package:offline_mesh_chat/models/message.dart';
import 'package:offline_mesh_chat/protocol/room_record.dart';
import 'package:offline_mesh_chat/screens/room_screen.dart' show PublicLine;
import 'package:offline_mesh_chat/theme/app_theme.dart';
import 'package:offline_mesh_chat/theme/surfaces.dart';

import '../support/shots.dart';
import '../support/ui_harness.dart';

/// Visual check, not a regression test: the little ghost where nothing is yet - empty
/// lists, an empty search, a new chat, the public room - in English and in Kurdish,
/// written to `build/shots/ghost_*.png` for a person to look at.
///
///     flutter test test/visual/ghost_shots_test.dart
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

void main() {
  setUpAll(() async {
    await loadShotFonts();
    goldenFileComparator = ShotWriter(Directory('build/shots'));
  });

  for (final language in [AppLanguage.en, AppLanguage.ckb]) {
    final code = language.code;
    final l = language.strings;
    final me = language == AppLanguage.en ? 'Alice' : 'ئارام';

    _testShots('$code: empty lists, a search with nothing, an empty log', (tester) async {
      final h = UiHarness(tester)..screen(390, 844);
      final alice = await h.node('Alice', onboarded: true, nickname: me, language: language);
      await h.show(alice);
      await h.settle(200);
      await shot(tester, 'ghost_${code}_01_empty_private');
      await h.goToTab(l.navGroups);
      await shot(tester, 'ghost_${code}_02_empty_groups');
      await h.goToTab(l.navPrivate);
      await h.tap(find.byKey(const Key('search-toggle')));
      await tester.enterText(find.byKey(const Key('search-field')), 'zzz');
      await h.settle();
      await shot(tester, 'ghost_${code}_03_nothing_found');
      await h.tap(find.byKey(const Key('search-toggle')));
      await h.openSettingsPage('privacy');
      await h.reveal(find.text(l.setSecurityLog));
      await h.tap(find.text(l.setSecurityLog));
      await h.settle(300);
      await shot(tester, 'ghost_${code}_04_empty_log');
      expect(tester.takeException(), isNull);
      await h.dispose();
    });

    _testShots('$code: a new chat, a new group, the public room', (tester) async {
      final h = UiHarness(tester)..screen(390, 844);
      final alice = await h.node('Alice', onboarded: true, nickname: me, language: language);
      final bob = await h.node('Bob', onboarded: true, nickname: 'Bob');
      await h.show(alice);
      await h.until(
          () => alice.directlyReaches(bob) && (alice.viewOf(bob)?.peer.canReceiveEncrypted ?? false),
          timeoutMs: 30000);

      await h.tap(find.byKey(Key('available-${bob.id}')));
      await h.until(() => find.byKey(const Key('chat-intro')).evaluate().isNotEmpty);
      await h.settle(500);
      await shot(tester, 'ghost_${code}_05_new_chat');
      await h.tester.binding.handlePopRoute();
      await h.settle();

      final group = await h.real(() => alice.controller.createGroup('Hikers', [bob.id]));
      await h.goToTab(l.navGroups);
      await h.tap(find.byKey(Key('conversation-${Conversation.groupConversationId(group.id)}')));
      await h.until(() => find.byKey(const Key('chat-intro')).evaluate().isNotEmpty);
      await h.settle(500);
      await shot(tester, 'ghost_${code}_06_new_group');
      await h.tester.binding.handlePopRoute();
      await h.settle();

      await h.openTab('public');
      await h.until(() => find.byKey(const Key('room-expiry-note')).evaluate().isNotEmpty);
      await h.settle(300);
      await shot(tester, 'ghost_${code}_07_room');
      expect(tester.takeException(), isNull);
      await h.dispose();
    });
  }

  _testShots('lines of the public room in their last hour', (tester) async {
    final h = UiHarness(tester)..screen(390, 520);
    final alice = await h.node('Alice', onboarded: true, nickname: 'Alice');
    await h.show(alice);
    const minute = 60 * 1000;
    const now = 100 * 60 * minute;
    ChatMessage line(int i, int minutesLeft, String body) => ChatMessage(
          id: '${i.toString().padLeft(2, '0')}${'a' * 30}',
          conversationId: _mesh,
          senderId: '${'bc' * 16}${i.toString().padLeft(2, '0')}${'d' * 30}',
          senderNickname: ['Mira', 'Omar', 'Lena', 'Sami', 'Noor', 'Jad', 'Rana'][i],
          isOutgoing: false,
          kind: MessageKind.text,
          body: body,
          sortTimeMs: now - (360 - minutesLeft) * minute,
          claimedTimestampMs: now - (360 - minutesLeft) * minute,
          status: MessageStatus.received,
          expiresAtMs: now + minutesLeft * minute,
        );
    final lines = [
      line(0, 200, 'anyone near the station?'),
      line(1, 75, 'yes, by the cafe'),
      line(2, 60, 'the bus is late again'),
      line(3, 45, 'bring a jacket, it is windy'),
      line(4, 30, 'see you at six'),
      line(5, 12, 'who has the key?'),
      line(6, 2, 'this one is about to go'),
    ];
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      localizationsDelegates: AppLanguage.delegates,
      supportedLocales: AppLanguage.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(
        body: AppBackground(
          child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(14),
              children: [
                for (final m in lines)
                  PublicLine(message: m, media: null, controller: alice.controller, nowMs: now),
              ],
            ),
          ),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 200));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('ghost_08_fading_lines.png'));
    expect(tester.takeException(), isNull);
    await h.dispose();
  });
}
