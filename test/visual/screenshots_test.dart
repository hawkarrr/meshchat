import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:offline_mesh_chat/device/device_io.dart';
import 'package:offline_mesh_chat/models/conversation.dart';
import 'package:offline_mesh_chat/models/media.dart' show MediaKind;
import 'package:offline_mesh_chat/protocol/room_record.dart';
import 'package:offline_mesh_chat/services/media_service.dart' show MediaDraft;

import '../support/shots.dart';
import '../support/ui_harness.dart';

/// Visual check, not a regression test: it draws the real screens, with the real
/// font and icons, on a phone-sized surface and writes PNG files to
/// `build/shots/` so a person (or a reviewer) can look at them. It always
/// passes unless a screen throws.
///
///     flutter test test/visual/screenshots_test.dart
/// A little landscape, so the pictures in the shots are not grey boxes.
Uint8List _landscape({int w = 480, int h = 320, int seed = 1}) {
  final rng = Random(seed);
  final image = img.Image(width: w, height: h, numChannels: 3);
  for (final p in image) {
    final t = p.y / h;
    p
      ..r = (255 * (1 - t * 0.55)).round()
      ..g = (140 + 60 * (1 - t) - 70 * t).round().clamp(0, 255)
      ..b = (90 + 150 * t).round().clamp(0, 255);
  }
  img.fillCircle(image,
      x: (w * 0.68).round(), y: (h * 0.38).round(), radius: (h * 0.14).round(), color: img.ColorRgb8(255, 236, 170));
  // Hills.
  for (var x = 0; x < w; x++) {
    final top = (h * 0.68 + 26 * sin(x / 41 + seed) + 14 * sin(x / 17)).round();
    for (var y = top; y < h; y++) {
      final n = rng.nextInt(10);
      image.setPixelRgb(x, y, 28 + n, 70 + n + (y - top) ~/ 8, 56 + n);
    }
  }
  return Uint8List.fromList(img.encodeJpg(image, quality: 88));
}

const String _mesh = 'rm:${PublicRooms.meshIdHex}';

/// A widget test that draws real shadows (the test renderer's default is a
/// solid outline) and puts the setting back before the test ends, as the
/// framework insists.
void _testShots(String name, Future<void> Function(WidgetTester tester) body,
    {Timeout? timeout}) {
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

  _testShots('first run page', (tester) async {
    final h = UiHarness(tester)..screen(390, 844);
    final alice = await h.node('Alice');
    await h.show(alice);
    await shot(tester, '01_onboarding');
    await h.reveal(find.textContaining('Asks before it uses anything'));
    await shot(tester, '02_onboarding_permissions');
    await h.dispose();
  });

  _testShots('the main screens, with a lively mesh around', (tester) async {
    final h = UiHarness(tester)..screen(390, 844);
    final alice = await h.node('Alice', onboarded: true, nickname: 'Alice');
    final bob = await h.node('Bob', onboarded: true, nickname: 'Bob');
    final carol = await h.node('Carol', onboarded: true, nickname: 'Carol');
    final dana = await h.node('Dana', onboarded: true, nickname: 'Dana');
    // Dana can only be reached through Bob.
    h.world.setInRange(alice.phone, dana.phone, false);
    h.world.setInRange(carol.phone, dana.phone, false);
    await h.show(alice);
    await h.until(
        () =>
            alice.directlyReaches(bob) &&
            alice.directlyReaches(carol) &&
            bob.directlyReaches(carol) &&
            bob.directlyReaches(alice) &&
            carol.directlyReaches(alice) &&
            (alice.viewOf(bob)?.peer.canReceiveEncrypted ?? false) &&
            (alice.viewOf(carol)?.peer.canReceiveEncrypted ?? false),
        timeoutMs: 30000);
    await h.until(() => find.textContaining('via relay').evaluate().isNotEmpty,
        timeoutMs: 30000, reason: 'Dana is reachable through Bob');

    // ---- private chats -------------------------------------------------------
    final withBob = Conversation.directId(bob.id);
    final bobsSide = Conversation.directId(alice.id);
    final withCarol = Conversation.directId(carol.id);
    final carolsSide = Conversation.directId(alice.id);
    final photo = await h.real(() =>
        bob.controller.prepareImage(_landscape(), caption: 'Look at this spot'));
    await h.real(() async {
      await bob.controller.sendDirect(alice.id, 'Are you coming to the picnic tomorrow?');
      await alice.controller.sendDirect(bob.id, 'Yes! I will bring sandwiches');
      await bob.controller.sendMedia(bobsSide, photo);
      await bob.controller.sendDirect(alice.id, 'Meet at ten, by the lake');
      await carol.controller.sendMedia(
        carolsSide,
        MediaDraft(
          kind: MediaKind.voice,
          bytes: Uint8List.fromList(List<int>.generate(2200, (i) => (i * 7) & 0xff)),
          durationMs: 12000,
          waveform: List<int>.generate(40, (i) => 40 + ((sin(i / 2.2) + 1) * 90).round()),
        ),
      );
      await carol.controller.sendDirect(alice.id, 'Sent you a voice note');
    });

    // ---- a group, and an invitation -------------------------------------------
    final plans = await h.real(() => alice.controller.createGroup('Weekend plans', [bob.id, carol.id]));
    await h.untilAsync(() async {
      final gb = await bob.controller.group(plans.id);
      final gc = await carol.controller.group(plans.id);
      return gb != null && gc != null;
    }, timeoutMs: 30000);
    await h.real(() async {
      await bob.controller.acceptGroup(plans.id);
      await carol.controller.acceptGroup(plans.id);
      final chat = Conversation.groupConversationId(plans.id);
      await alice.controller.sendText(chat, 'Saturday at ten?');
      await bob.controller.sendText(chat, 'Works for me');
      await carol.controller.sendText(chat, 'I can bring the speaker');
    });
    await h.real(() => bob.controller.createGroup('Lunch crew', [alice.id, carol.id]));

    // ---- public rooms ---------------------------------------------------------
    await h.real(() async {
      await bob.controller.sendText(_mesh, 'anyone near the station?');
      await carol.controller.sendText(_mesh, 'yes, by the cafe');
      await dana.controller.sendText(_mesh, 'hello from the other side');
      await alice.controller.sendText(_mesh, 'hi all, testing the mesh');
    });
    final hikers = await h.real(
        () => alice.controller.createRoom('hikers', description: 'weekend trails'));
    final chess = await h.real(
        () => bob.controller.createRoom('chess', description: 'blitz and bullet'));
    await h.until(() => alice.controller.roomsListenable.value.any((r) => r.id == chess.id),
        timeoutMs: 30000, reason: 'Alice hears about #chess');
    await h.untilAsync(() async {
      final lines = await alice.controller.loadMessages(_mesh);
      return lines.length >= 4;
    }, timeoutMs: 30000);
    await h.settle(200);

    // ---- the shots --------------------------------------------------------------
    await shot(tester, '10_home_private');
    await h.goToTab('Groups');
    await shot(tester, '11_home_groups');
    await h.goToTab('Public');
    await shot(tester, '12_home_public');
    await h.goToTab('Private');

    await h.tap(find.byKey(Key('conversation-$withBob')));
    await h.until(() => find.byKey(const Key('image-open')).evaluate().isNotEmpty);
    await h.settle(300);
    await shot(tester, '20_chat_private');
    await h.tap(find.byKey(const Key('composer-attach')));
    await shot(tester, '21_attach_sheet');
    await tester.tapAt(const Offset(195, 60)); // the dimmed area closes the sheet
    await h.settle();
    await h.tap(find.byKey(const Key('composer-mic')));
    await shot(tester, '22_permission_microphone');
    h.permissionsOf(alice).set(AppPermission.microphone, PermissionOutcome.granted);
    await h.tap(find.byKey(const Key('permission-continue')));
    h.recorderOf(alice).tick(const Duration(seconds: 7), level: 0.7);
    await h.settle();
    await shot(tester, '23_recording');
    await h.tap(find.byKey(const Key('voice-cancel')));
    await tester.pageBack();
    await h.settle();

    await h.tap(find.byKey(Key('conversation-$withCarol')));
    await h.until(() => find.byKey(const Key('voice-play')).evaluate().isNotEmpty &&
        find.textContaining('Receiving').evaluate().isEmpty);
    await h.tap(find.byKey(const Key('voice-play')));
    await shot(tester, '24_chat_voice');
    await tester.pageBack();
    await h.settle();

    await h.goToTab('Groups');
    await h.tap(find.byKey(Key('conversation-${Conversation.groupConversationId(plans.id)}')));
    await h.until(() => find.text('I can bring the speaker').evaluate().isNotEmpty);
    await shot(tester, '30_group_chat');
    await h.tap(find.byKey(const Key('group-info')));
    await shot(tester, '31_group_details');
    await tester.pageBack();
    await h.settle();
    await tester.pageBack();
    await h.settle();
    await h.tap(find.byKey(const Key('fab-groups')));
    await shot(tester, '32_new_group');
    await tester.pageBack();
    await h.settle();

    await h.openTab('public');
    await h.until(() => find.textContaining('hi all, testing the mesh').evaluate().isNotEmpty);
    await shot(tester, '40_room_mesh');
    await h.tap(find.byKey(const Key('room-label')));
    await shot(tester, '41_rooms_sheet');
    await h.tap(find.byKey(const Key('rooms-create')));
    await shot(tester, '42_create_room');
    await h.tap(find.text('Cancel'));
    await h.tap(find.text('#${hikers.name}').last);
    await h.until(() => find.byKey(const Key('room-empty')).evaluate().isNotEmpty);
    await shot(tester, '43_room_empty');

    await h.goToTab('Private');
    await h.tap(find.byKey(const Key('open-people')));
    await shot(tester, '50_people');
    await tester.pageBack();
    await h.settle();
    await h.goToTab('Settings');
    await shot(tester, '51_settings');
    await h.tap(find.byKey(const Key('settings-privacy')));
    await shot(tester, '52_settings_privacy');
    await h.reveal(find.text('Danger zone'));
    await shot(tester, '53_settings_privacy_bottom');
    await tester.pageBack();
    await h.settle();
    await h.goToTab('Private');
    await h.tap(find.textContaining('nearby').first);
    await shot(tester, '54_nearby');

    expect(tester.takeException(), isNull);
    await h.dispose();
  }, timeout: const Timeout(Duration(minutes: 5)));
}
