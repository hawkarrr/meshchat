import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:offline_mesh_chat/core/app_info.dart';
import 'package:offline_mesh_chat/device/device_io.dart';
import 'package:offline_mesh_chat/models/conversation.dart';
import 'package:offline_mesh_chat/models/media.dart';
import 'package:offline_mesh_chat/models/message.dart';
import 'package:offline_mesh_chat/screens/chat_screen.dart';
import 'package:offline_mesh_chat/screens/room_screen.dart';
import 'package:offline_mesh_chat/services/media_service.dart' show FileMediaStore, MediaDraft;

import '../support/app_harness.dart';
import '../support/message_node.dart' show fakeBytes;
import '../support/test_database.dart';
import '../support/ui_harness.dart';

final Finder _field = find.byKey(const Key('composer-field'));

Uint8List _photo() {
  final rng = Random(3);
  final image = img.Image(width: 160, height: 120, numChannels: 3);
  for (final p in image) {
    p
      ..r = p.x * 255 ~/ 160
      ..g = p.y * 255 ~/ 120
      ..b = 60 + rng.nextInt(60);
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

  Future<void> bobHas(bool Function(ChatMessage) test) => h.untilAsync(() async {
        final all = await bob.controller.loadMessages(bobsConversation);
        return all.any(test);
      }, timeoutMs: 30000);
}

Future<_Chat> _openChat(WidgetTester tester, {MediaStoreMaker? aliceStore}) async {
  final h = UiHarness(tester)..screen();
  final AppNode alice;
  if (aliceStore != null) {
    final made = await tester.runAsync(() async {
      final n = await AppNode.create(h.world, 'Alice', media: aliceStore());
      await n.controller.setNickname('Alice');
      await n.startUp();
      return n;
    });
    alice = made!;
    h.nodes.add(alice);
  } else {
    alice = await h.node('Alice', onboarded: true, nickname: 'Alice');
  }
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

typedef MediaStoreMaker = FileMediaStore Function();

void main() {
  group('sending a video', () {
    testWidgets('the attach sheet offers videos in chats and says how small they must be, '
        'but not in a public room', (tester) async {
      final c = await _openChat(tester);
      await c.h.tap(find.byKey(const Key('composer-attach')));
      expect(find.byKey(const Key('attach-camera')), findsOneWidget);
      expect(find.byKey(const Key('attach-video-camera')), findsOneWidget);
      expect(find.byKey(const Key('attach-video-gallery')), findsOneWidget);
      expect(find.textContaining('256.0 KB'), findsOneWidget, reason: 'the default limit is stated');
      expect(find.textContaining('can take minutes'), findsOneWidget);
      await tester.tapAt(const Offset(180, 30));
      await c.h.settle();

      await tester.pageBack();
      await c.h.settle();
      await c.h.openTab('public');
      await c.h.until(() => find.byType(RoomChat).evaluate().isNotEmpty);
      await c.h.tap(find.byKey(const Key('composer-attach')));
      expect(find.byKey(const Key('attach-camera')), findsOneWidget);
      expect(find.byKey(const Key('attach-video-gallery')), findsNothing,
          reason: 'a video would have to be carried by every phone in range');
      await c.h.dispose();
    });

    testWidgets('a video over the limit is refused before anything is sent, with the numbers',
        (tester) async {
      final c = await _openChat(tester);
      c.h.permissionsOf(c.alice).set(AppPermission.photos, PermissionOutcome.granted);
      final picker = c.h.pickerOf(c.alice);
      picker.nextVideo = PickedVideo(length: 3 * 1024 * 1024, bytes: fakeBytes(8));

      await c.h.tap(find.byKey(const Key('composer-attach')));
      await c.h.tap(find.byKey(const Key('attach-video-gallery')));
      await c.h.until(() => find.textContaining('That video is 3.0 MB').evaluate().isNotEmpty);
      expect(find.textContaining('at most 256.0 KB'), findsOneWidget);
      expect(find.textContaining('up to 512.0 KB'), findsOneWidget);
      expect(picker.lastVideoLimit, 256 * 1024, reason: 'the picker was told the limit');
      expect(find.text('Send this video?'), findsNothing);
      expect(await c.h.real(() => c.alice.controller.loadMessages(c.conversation)), isEmpty);
      await c.h.dispose();
    });

    testWidgets('a small video is previewed with its size, sent, and Bob receives it',
        (tester) async {
      final c = await _openChat(tester);
      c.h.permissionsOf(c.alice).set(AppPermission.photos, PermissionOutcome.granted);
      final bytes = fakeBytes(30 * 1024, 5);
      c.h.pickerOf(c.alice).nextVideo = PickedVideo(length: bytes.length, bytes: bytes);

      await c.h.tap(find.byKey(const Key('composer-attach')));
      await c.h.tap(find.byKey(const Key('attach-video-gallery')));
      await c.h.until(() => find.text('Send this video?').evaluate().isNotEmpty);
      expect(find.text('30.0 KB'), findsOneWidget);
      expect(find.textContaining('several minutes'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('caption-field')), 'the lake');
      await c.h.tap(find.byKey(const Key('video-send')));

      await c.h.until(() => find.byKey(const Key('video-open')).evaluate().isNotEmpty,
          reason: 'the video shows as a card in the chat');
      expect(find.text('the lake'), findsOneWidget);
      expect(find.textContaining('30.0 KB'), findsWidgets);
      await c.bobHas((m) => m.kind == MessageKind.video && m.body == 'the lake');
      final message = (await c.h.real(() => c.bob.controller.loadMessages(c.bobsConversation)))
          .firstWhere((m) => m.kind == MessageKind.video);
      await c.h.untilAsync(() async =>
          (await c.bob.controller.loadMedia([message.mediaId!]))[message.mediaId]!.isReady,
          timeoutMs: 30000);
      final item = (await c.h.real(() => c.bob.controller.loadMedia([message.mediaId!])))[message.mediaId]!;
      expect(item.kind, MediaKind.video);
      expect(await c.h.real(() => c.bob.controller.mediaBytes(item)), bytes);
      await c.h.dispose();
    });

    testWidgets('the limit can be lowered in Settings > Storage and the sheet follows',
        (tester) async {
      final c = await _openChat(tester);
      await tester.pageBack();
      await c.h.settle();
      await c.h.openSettingsPage('privacy');
      await c.h.tap(find.byKey(const Key('open-storage')));
      await c.h.until(() => find.byKey(const Key('video-limit')).evaluate().isNotEmpty);
      await c.h.loaded();
      await c.h.tap(find.byKey(const Key('video-limit')));
      await c.h.tap(find.text('128.0 KB').last);
      await c.h.until(() => c.alice.controller.videoSendLimit == 128 * 1024);
      expect(c.alice.controller.router, isNotNull);
      await tester.pageBack();
      await c.h.settle();
      expect(find.byKey(const Key('video-limit')), findsNothing);
      await c.h.dispose();
    });

    testWidgets('the video card shows how far a video that is still arriving has got',
        (tester) async {
      final c = await _openChat(tester);
      // Bob sends one; Alice sees the card (ready once complete).
      await c.h.real(() => c.bob.controller.sendMedia(
            c.bobsConversation,
            MediaDraft(kind: MediaKind.video, bytes: fakeBytes(40 * 1024, 2), width: 320, height: 240, durationMs: 7000),
          ));
      await c.h.until(() => find.byKey(const Key('video-open')).evaluate().isNotEmpty, timeoutMs: 30000);
      expect(find.textContaining('0:07 · 40.0 KB'), findsOneWidget);
      await c.h.dispose();
    });
  });

  group('saving to the gallery', () {
    testWidgets('a picture: asks first, says what it means, then saves', (tester) async {
      final c = await _openChat(tester);
      final jpeg = _photo();
      await c.h.real(() async {
        final draft = await c.bob.controller.prepareImage(jpeg);
        await c.bob.controller.sendMedia(c.bobsConversation, draft);
      });
      await c.h.until(() => find.byKey(const Key('image-open')).evaluate().isNotEmpty, timeoutMs: 30000);
      final gallery = c.h.galleryOf(c.alice);

      await c.tester.longPress(find.byKey(const Key('image-open')));
      await c.h.settle();
      expect(find.byKey(const Key('act-save')), findsOneWidget);
      await c.h.tap(find.byKey(const Key('act-save')));
      expect(find.text('Save to your gallery?'), findsOneWidget);
      expect(find.textContaining('where other apps can see it'), findsOneWidget);
      expect(find.textContaining('stays even if you delete the message here'), findsOneWidget);
      expect(gallery.images, isEmpty, reason: 'nothing is saved before the person agrees');

      await c.h.tap(find.byKey(const Key('save-confirm')));
      await c.h.until(() => gallery.images.isNotEmpty);
      expect(gallery.images.single.length, greaterThan(1000));
      expect(find.text('Saved to your gallery'), findsOneWidget);
      await c.h.dispose();
    });

    testWidgets('cancelling saves nothing', (tester) async {
      final c = await _openChat(tester);
      await c.h.real(() async {
        final draft = await c.bob.controller.prepareImage(_photo());
        await c.bob.controller.sendMedia(c.bobsConversation, draft);
      });
      await c.h.until(() => find.byKey(const Key('image-open')).evaluate().isNotEmpty, timeoutMs: 30000);
      await c.tester.longPress(find.byKey(const Key('image-open')));
      await c.h.settle();
      await c.h.tap(find.byKey(const Key('act-save')));
      await c.h.tap(find.byKey(const Key('save-cancel')));
      expect(c.h.galleryOf(c.alice).images, isEmpty);
      await c.h.dispose();
    });

    testWidgets('a refusal from the phone is shown in words', (tester) async {
      final c = await _openChat(tester);
      await c.h.real(() async {
        final draft = await c.bob.controller.prepareImage(_photo());
        await c.bob.controller.sendMedia(c.bobsConversation, draft);
      });
      await c.h.until(() => find.byKey(const Key('image-open')).evaluate().isNotEmpty, timeoutMs: 30000);
      c.h.galleryOf(c.alice).failWith = const GalleryException('${AppInfo.name} was not allowed to add to your gallery.');
      await c.tester.longPress(find.byKey(const Key('image-open')));
      await c.h.settle();
      await c.h.tap(find.byKey(const Key('act-save')));
      await c.h.tap(find.byKey(const Key('save-confirm')));
      await c.h.until(() => find.textContaining('was not allowed to add to your gallery').evaluate().isNotEmpty);
      await c.h.dispose();
    });

    testWidgets('a video is saved from its file; voice messages and text have no such action',
        (tester) async {
      final dir = makeTempDir('mesh_video_ui_');
      addTearDown(() {
        try {
          dir.deleteSync(recursive: true);
        } on FileSystemException {
          // best effort
        }
      });
      final c = await _openChat(tester, aliceStore: () => FileMediaStore(Directory('${dir.path}${Platform.pathSeparator}media')..createSync()));
      final bytes = fakeBytes(25 * 1024, 4);
      await c.h.real(() => c.bob.controller.sendMedia(
            c.bobsConversation,
            MediaDraft(kind: MediaKind.video, bytes: bytes, width: 320, height: 240, durationMs: 5000),
          ));
      await c.h.real(() => c.bob.controller.sendMedia(
            c.bobsConversation,
            MediaDraft(kind: MediaKind.voice, bytes: fakeBytes(2000), durationMs: 2000, waveform: List<int>.filled(30, 90)),
          ));
      await c.h.real(() => c.bob.controller.sendText(c.bobsConversation, 'just words'));
      await c.h.until(() => find.byKey(const Key('video-open')).evaluate().isNotEmpty &&
          find.text('just words').evaluate().isNotEmpty, timeoutMs: 30000);
      await c.h.until(() => find.byKey(const Key('voice-play')).evaluate().isNotEmpty, timeoutMs: 30000);

      await c.tester.longPress(find.byKey(const Key('voice-play')));
      await c.h.settle();
      expect(find.byKey(const Key('act-save')), findsNothing, reason: 'voice messages stay in the app');
      await c.tester.tapAt(const Offset(180, 30));
      await c.h.settle();
      await c.tester.longPress(find.text('just words'));
      await c.h.settle();
      expect(find.byKey(const Key('act-save')), findsNothing);
      await c.tester.tapAt(const Offset(180, 30));
      await c.h.settle();

      await c.tester.longPress(find.byKey(const Key('video-open')));
      await c.h.settle();
      await c.h.tap(find.byKey(const Key('act-save')));
      expect(find.textContaining('keeps this video'), findsOneWidget);
      await c.h.tap(find.byKey(const Key('save-confirm')));
      final gallery = c.h.galleryOf(c.alice);
      await c.h.until(() => gallery.videos.isNotEmpty);
      expect(gallery.videos.single, endsWith('.mp4'));
      expect(File(gallery.videos.single).lengthSync(), bytes.length, reason: 'the file that was saved is the video');
      await c.h.dispose();
    });
  });

  group('search', () {
    testWidgets('can be narrowed to videos', (tester) async {
      final c = await _openChat(tester);
      await c.h.real(() async {
        await c.bob.controller.sendText(c.bobsConversation, 'a text about the lake');
        await c.bob.controller.sendMedia(
          c.bobsConversation,
          MediaDraft(kind: MediaKind.video, bytes: fakeBytes(10 * 1024), width: 100, height: 100, caption: 'the lake video'),
        );
      });
      await c.h.until(() => find.text('a text about the lake').evaluate().isNotEmpty);
      await c.h.until(() => find.byKey(const Key('video-open')).evaluate().isNotEmpty, timeoutMs: 30000);

      await c.h.tap(find.byKey(const Key('chat-search')));
      await c.h.tap(find.byKey(const Key('search-filter-videos')));
      expect(find.textContaining('the lake video'), findsOneWidget);
      expect(find.textContaining('a text about the lake'), findsNothing);
      await tester.enterText(_field.evaluate().isEmpty ? find.byKey(const Key('search-field')) : _field, 'lake');
      await c.h.settle();
      expect(find.textContaining('the lake video'), findsOneWidget);
      await c.h.dispose();
    });
  });
}
