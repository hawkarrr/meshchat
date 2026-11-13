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
import 'package:offline_mesh_chat/screens/image_viewer_screen.dart';
import 'package:offline_mesh_chat/protocol/protocol_constants.dart';
import 'package:offline_mesh_chat/services/media_service.dart' show MediaDraft;
import 'package:offline_mesh_chat/theme/surfaces.dart';
import 'package:offline_mesh_chat/widgets/message_bubble.dart';

import '../support/app_harness.dart';
import '../support/ui_harness.dart';

/// A photograph-like picture: smooth gradients plus noise.
Uint8List _photo(int w, int h, {int seed = 1}) {
  final rng = Random(seed);
  final image = img.Image(width: w, height: h, numChannels: 3);
  for (final p in image) {
    final x = p.x / w, y = p.y / h;
    p
      ..r = (x * 255).round().clamp(0, 255)
      ..g = (y * 255).round().clamp(0, 255)
      ..b = ((x + y) * 120 + rng.nextInt(40)).round().clamp(0, 255);
  }
  return Uint8List.fromList(img.encodeJpg(image, quality: 92));
}

final Finder _field = find.byKey(const Key('composer-field'));

/// Two phones in range; Alice's screen shows her private chat with Bob.
class _Chat {
  _Chat(this.h, this.alice, this.bob);

  final UiHarness h;
  final AppNode alice;
  final AppNode bob;

  String get conversation => Conversation.directId(bob.id);

  /// The same conversation as Bob sees it.
  String get bobsConversation => Conversation.directId(alice.id);
}

Future<_Chat> _openChat(
  WidgetTester tester, {
  double width = 360,
  double height = 760,
  String bobName = 'Bob',
}) async {
  final h = UiHarness(tester)..screen(width, height);
  final alice = await h.node('Alice', onboarded: true, nickname: 'Alice');
  final bob = await h.node(bobName, onboarded: true, nickname: bobName);
  await h.show(alice);
  await h.until(
    () =>
        alice.directlyReaches(bob) &&
        bob.directlyReaches(alice) &&
        (alice.viewOf(bob)?.peer.canReceiveEncrypted ?? false),
    reason: 'Alice and Bob should find each other and swap keys',
  );
  await h.tap(find.byKey(Key('available-${bob.id}')));
  await h.until(() => find.byType(ChatScreen).evaluate().isNotEmpty,
      reason: 'opening a chat reads the database first');
  return _Chat(h, alice, bob);
}

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(_field, text);
  await tester.pump();
}

/// Types [text] and presses the send button.
Future<void> _say(_Chat c, WidgetTester tester, String text) async {
  await _type(tester, text);
  await c.h.tap(find.byKey(const Key('composer-send')));
}

/// Waits until Bob's copy of the conversation has [count] messages.
Future<List<ChatMessage>> _bobHas(_Chat c, int count) async {
  var messages = <ChatMessage>[];
  await c.h.untilAsync(() async {
    messages = await c.bob.controller.loadMessages(c.bobsConversation);
    return messages.length >= count;
  }, reason: 'Bob should have $count message(s)');
  return messages;
}

void main() {
  group('a private chat', () {
    testWidgets('a nearby phone appears, a message is sent and shows as delivered',
        (tester) async {
      final h = UiHarness(tester)..screen();
      final alice = await h.node('Alice', onboarded: true, nickname: 'Alice');
      final bob = await h.node('Bob', onboarded: true, nickname: 'Bob');
      await h.show(alice);

      await h.until(() => alice.directlyReaches(bob), reason: 'Alice should find Bob');
      await h.until(() => bob.directlyReaches(alice));
      await h.until(() => alice.viewOf(bob)?.peer.canReceiveEncrypted ?? false);
      await h.settle();

      // The Private tab lists who can be reached right now.
      expect(find.text('Available now'), findsOneWidget);
      expect(find.text('Bob'), findsWidgets);
      expect(find.text('Direct'), findsWidgets);
      expect(find.textContaining('1 nearby'), findsWidgets, reason: 'the connection indicator');

      await h.tap(find.byKey(Key('available-${bob.id}')));
      await h.until(() => find.byType(ChatScreen).evaluate().isNotEmpty);
      expect(find.text('Directly connected'), findsWidgets);
      expect(find.textContaining('delivered immediately'), findsNothing,
          reason: 'the header already says it in green: the strip is for what is not obvious');
      await h.until(() => find.textContaining('No messages yet').evaluate().isNotEmpty,
          reason: 'an empty chat explains itself once it has loaded');
      expect(find.byKey(const Key('composer-mic')), findsOneWidget,
          reason: 'with nothing typed, the action button is the microphone');

      await _type(tester, 'hello Bob');
      expect(find.byKey(const Key('composer-send')), findsOneWidget,
          reason: 'as soon as there is text, the button sends it');
      expect(find.byKey(const Key('composer-mic')), findsNothing);
      await h.tap(find.byKey(const Key('composer-send')));
      await h.until(() => find.text('hello Bob').evaluate().isNotEmpty);
      expect(find.text('hello Bob'), findsOneWidget);
      expect((tester.widget(_field) as TextField).controller!.text, isEmpty,
          reason: 'the field is cleared after sending');
      await h.until(() => find.textContaining('Delivered').evaluate().isNotEmpty,
          reason: 'the recipient\'s signed receipt should turn the bubble to Delivered');

      // Bob really received it, decrypted.
      final bobsView = await h.real(() => bob.controller.loadMessages(Conversation.directId(alice.id)));
      expect(bobsView.single.body, 'hello Bob');
      expect(bobsView.single.status, MessageStatus.received);

      // A reply from Bob shows up live, while the chat is open.
      await h.real(() => bob.controller.sendDirect(alice.id, 'hi Alice'));
      await h.until(() => find.text('hi Alice').evaluate().isNotEmpty);

      // Back on the list: the conversation is there with its preview, nothing
      // unread because it was open.
      await tester.pageBack();
      await h.until(() =>
          find.byType(ChatScreen).evaluate().isEmpty && find.text('hi Alice').evaluate().length == 1);
      await h.until(() => alice.controller.totalUnread == 0);

      expect(tester.takeException(), isNull);
      await h.dispose();
    });

    testWidgets('a message that arrives while elsewhere shows an unread badge until opened',
        (tester) async {
      final h = UiHarness(tester)..screen();
      final alice = await h.node('Alice', onboarded: true, nickname: 'Alice');
      final bob = await h.node('Bob', onboarded: true, nickname: 'Bob');
      await h.show(alice);
      await h.until(() => alice.directlyReaches(bob) && bob.directlyReaches(alice));

      await h.real(() => bob.controller.sendDirect(alice.id, 'are you there?'));
      await h.until(() =>
          alice.controller.totalUnread == 1 && find.text('are you there?').evaluate().isNotEmpty);
      expect(find.byType(UnreadBadge), findsWidgets, reason: 'a badge on the row and on the tab');
      expect(find.text('1'), findsWidgets);

      await h.tap(find.byKey(Key('conversation-${Conversation.directId(bob.id)}')));
      expect(find.byType(ChatScreen), findsOneWidget);
      await h.until(() => alice.controller.totalUnread == 0);
      expect(find.byType(UnreadBadge), findsNothing, reason: 'reading the chat clears the badge');

      expect(tester.takeException(), isNull);
      await h.dispose();
    });

    testWidgets('tapping a message shows its details, and the text can be copied',
        (tester) async {
      final c = await _openChat(tester);
      final clipboard = c.h.recordClipboard();
      await _say(c, tester, 'details please');
      await c.h.until(() => find.textContaining('Delivered').evaluate().isNotEmpty);

      await c.h.tap(find.text('details please'));
      expect(find.text('Message details'), findsOneWidget);
      expect(find.text('Sent by you'), findsOneWidget);
      expect(find.text('Status'), findsOneWidget);
      expect(find.text('Message id'), findsOneWidget);
      await c.h.tap(find.text('Copy text'));
      expect(clipboard.text, 'details please');

      expect(tester.takeException(), isNull);
      await c.h.dispose();
    });

    testWidgets('the same conversation works on the smallest supported phone screen',
        (tester) async {
      final c = await _openChat(tester,
          width: 320, height: 568, bobName: 'Bob with a rather long display name');
      await _say(
          c,
          tester,
          'a fairly long message that has to wrap over several lines on a very small '
          'screen without anything overflowing');
      await c.h.until(() => find.textContaining('Delivered').evaluate().isNotEmpty);

      expect(tester.takeException(), isNull);
      await c.h.dispose();
    });

    testWidgets('a text that is too long cannot be sent', (tester) async {
      final c = await _openChat(tester);
      await _type(tester, 'x' * 1200);
      expect(find.text('Too long'), findsOneWidget);
      final send = tester.widget<RoundButton>(find.byKey(const Key('composer-send')));
      expect(send.onPressed, isNull, reason: 'the send button is disabled');

      expect(tester.takeException(), isNull);
      await c.h.dispose();
    });
  });

  group('pictures', () {
    testWidgets('are explained first, previewed with a caption, sent, and arrive intact',
        (tester) async {
      final c = await _openChat(tester);
      final h = c.h;
      final picker = h.pickerOf(c.alice)..next = _photo(480, 360);
      final permissions = h.permissionsOf(c.alice);

      await h.tap(find.byKey(const Key('composer-attach')));
      expect(find.text('Send a picture'), findsOneWidget);
      expect(find.byKey(const Key('attach-camera')), findsOneWidget);
      expect(find.byKey(const Key('attach-gallery')), findsOneWidget);
      await h.tap(find.byKey(const Key('attach-gallery')));

      // Damatqe explains what it will do before the system is asked anything.
      expect(find.text('Allow access to your photos?'), findsOneWidget);
      expect(find.textContaining('never uploaded anywhere'), findsOneWidget);
      expect(permissions.requested, isEmpty);
      expect(picker.picked, isEmpty);

      await h.tap(find.byKey(const Key('permission-continue')));
      expect(permissions.requested, [AppPermission.photos]);
      await h.until(() => find.text('Send this picture?').evaluate().isNotEmpty,
          reason: 'the picture is shrunk, then previewed');
      expect(picker.picked, [PhotoSource.gallery]);
      expect(find.byKey(const Key('caption-field')), findsOneWidget);

      await tester.enterText(find.byKey(const Key('caption-field')), 'sunset at the lake');
      await tester.pump();
      await h.tap(find.byKey(const Key('picture-send')));
      await h.until(() => find.byKey(const Key('image-open')).evaluate().isNotEmpty,
          reason: 'the sent picture shows in the chat');
      expect(find.text('sunset at the lake'), findsOneWidget);
      await h.until(() => find.textContaining('Delivered').evaluate().isNotEmpty,
          timeoutMs: 20000, reason: 'Bob confirms once the whole picture arrived');

      // What Bob holds is byte for byte what Alice sent, and within the limit.
      final received = (await _bobHas(c, 1)).single;
      expect(received.kind, MessageKind.image);
      expect(received.body, 'sunset at the lake');
      final theirs = await h.real(() async {
        final m = (await c.bob.controller.loadMedia([received.mediaId!]))[received.mediaId]!;
        expect(m.isReady, isTrue);
        return (m, await c.bob.controller.mediaBytes(m));
      });
      final mine = await h.real(() async {
        final sent = (await c.alice.controller.loadMessages(c.conversation)).single;
        final m = (await c.alice.controller.loadMedia([sent.mediaId!]))[sent.mediaId]!;
        return c.alice.controller.mediaBytes(m);
      });
      expect(theirs.$2, isNotNull);
      expect(theirs.$2, mine);
      expect(theirs.$2!.length, lessThanOrEqualTo(Protocol.maxMediaBytes));
      expect(theirs.$1.kind, MediaKind.image);

      // Tapping the picture opens it full screen.
      await h.tap(find.byKey(const Key('image-open')));
      expect(find.byType(ImageViewerScreen), findsOneWidget);
      await tester.pageBack();
      await h.settle();

      expect(tester.takeException(), isNull);
      await h.dispose();
    });

    testWidgets('the camera and the photos are each asked for once, and only when needed',
        (tester) async {
      final c = await _openChat(tester);
      final h = c.h;
      final picker = h.pickerOf(c.alice);
      final permissions = h.permissionsOf(c.alice);

      Future<void> sendPicture(String source, {bool rationale = true, String? title}) async {
        picker.next = _photo(320, 240, seed: source.length);
        await h.tap(find.byKey(const Key('composer-attach')));
        await h.tap(find.byKey(Key('attach-$source')));
        if (rationale) {
          expect(find.text(title!), findsOneWidget);
          await h.tap(find.byKey(const Key('permission-continue')));
        } else {
          expect(find.textContaining('Allow'), findsNothing, reason: 'already allowed: no prompt');
        }
        await h.until(() => find.text('Send this picture?').evaluate().isNotEmpty);
        await h.tap(find.byKey(const Key('picture-send')));
        await h.until(() => find.byKey(const Key('image-open')).evaluate().isNotEmpty);
      }

      await sendPicture('camera', title: 'Allow the camera?');
      expect(permissions.requested, [AppPermission.camera]);
      expect(picker.picked, [PhotoSource.camera]);

      await sendPicture('camera', rationale: false);
      expect(permissions.requested, [AppPermission.camera], reason: 'the camera is not asked twice');

      await sendPicture('gallery', title: 'Allow access to your photos?');
      expect(permissions.requested, [AppPermission.camera, AppPermission.photos]);
      expect(picker.picked, [PhotoSource.camera, PhotoSource.camera, PhotoSource.gallery]);

      // Timers started by taps live in the test's fake clock: keep pumping it until
      // all three pictures are confirmed, then look at Bob's phone.
      await h.until(() => find.textContaining('Delivered').evaluate().length >= 3,
          timeoutMs: 30000, reason: 'Bob confirms all three pictures');
      expect((await _bobHas(c, 3)).every((m) => m.kind == MessageKind.image), isTrue);
      expect(tester.takeException(), isNull);
      await h.dispose();
    });

    testWidgets('saying "not now" to the explanation asks the system nothing',
        (tester) async {
      final c = await _openChat(tester);
      final h = c.h;
      final picker = h.pickerOf(c.alice)..next = _photo(320, 240);
      final permissions = h.permissionsOf(c.alice);

      await h.tap(find.byKey(const Key('composer-attach')));
      await h.tap(find.byKey(const Key('attach-gallery')));
      expect(find.text('Allow access to your photos?'), findsOneWidget);
      await h.tap(find.text('Not now'));

      expect(permissions.requested, isEmpty);
      expect(picker.picked, isEmpty);
      expect(find.text('Allow access to send a picture.'), findsOneWidget,
          reason: 'the chat says why nothing was sent');
      expect(find.byKey(const Key('image-open')), findsNothing);

      // The message can be dismissed.
      await h.tap(find.byIcon(Icons.close_rounded));
      expect(find.text('Allow access to send a picture.'), findsNothing);

      expect(tester.takeException(), isNull);
      await h.dispose();
    });

    testWidgets('refusing in the system dialog, and a permission that is off for good',
        (tester) async {
      final c = await _openChat(tester);
      final h = c.h;
      final picker = h.pickerOf(c.alice)..next = _photo(320, 240);
      final permissions = h.permissionsOf(c.alice)..answerWhenAsked = PermissionOutcome.denied;

      await h.tap(find.byKey(const Key('composer-attach')));
      await h.tap(find.byKey(const Key('attach-camera')));
      await h.tap(find.byKey(const Key('permission-continue')));
      expect(permissions.requested, [AppPermission.camera]);
      expect(picker.picked, isEmpty, reason: 'no permission, no camera');
      expect(find.text('Allow access to send a picture.'), findsOneWidget);

      // Later the system remembers "never ask again": only the settings can help.
      permissions.set(AppPermission.camera, PermissionOutcome.permanentlyDenied);
      await h.tap(find.byKey(const Key('composer-attach')));
      await h.tap(find.byKey(const Key('attach-camera')));
      expect(find.text('The camera is switched off'), findsOneWidget);
      expect(find.textContaining('turn it on for ${AppInfo.name} in your phone'), findsOneWidget);
      await h.tap(find.byKey(const Key('permission-open-settings')));
      expect(permissions.settingsOpened, 1);
      expect(permissions.requested, [AppPermission.camera],
          reason: 'a permanently refused permission is not asked for again');

      // A phone that forbids it altogether says so.
      permissions.set(AppPermission.photos, PermissionOutcome.unavailable);
      await h.tap(find.byKey(const Key('composer-attach')));
      await h.tap(find.byKey(const Key('attach-gallery')));
      expect(find.text('Not available'), findsOneWidget);
      expect(find.textContaining('does not allow ${AppInfo.name} to use your photos'), findsOneWidget);
      await h.tap(find.text('OK'));

      expect(tester.takeException(), isNull);
      await h.dispose();
    });

    testWidgets('a file that is not a picture is reported, and nothing is sent', (tester) async {
      final c = await _openChat(tester);
      final h = c.h;
      h.pickerOf(c.alice).next = Uint8List.fromList(List<int>.filled(400, 7));
      h.permissionsOf(c.alice).set(AppPermission.photos, PermissionOutcome.granted);

      await h.tap(find.byKey(const Key('composer-attach')));
      await h.tap(find.byKey(const Key('attach-gallery')));
      await h.until(() =>
          find.text('That file is not a picture this phone can read.').evaluate().isNotEmpty);
      expect(find.text('Send this picture?'), findsNothing);
      expect(find.byKey(const Key('image-open')), findsNothing);
      expect(await h.real(() => c.alice.controller.loadMessages(c.conversation)), isEmpty);

      expect(tester.takeException(), isNull);
      await h.dispose();
    });

    testWidgets('backing out of the preview sends nothing', (tester) async {
      final c = await _openChat(tester);
      final h = c.h;
      h.pickerOf(c.alice).next = _photo(320, 240);
      h.permissionsOf(c.alice).set(AppPermission.photos, PermissionOutcome.granted);

      await h.tap(find.byKey(const Key('composer-attach')));
      await h.tap(find.byKey(const Key('attach-gallery')));
      await h.until(() => find.text('Send this picture?').evaluate().isNotEmpty);
      await h.tap(find.text('Cancel'));

      expect(find.text('Send this picture?'), findsNothing);
      expect(await h.real(() => c.alice.controller.loadMessages(c.conversation)), isEmpty);
      expect(tester.takeException(), isNull);
      await h.dispose();
    });

    testWidgets('a picture sent by the other phone shows progress, then the picture',
        (tester) async {
      final c = await _openChat(tester);
      final h = c.h;
      final draft = await h.real(() => c.bob.controller.prepareImage(_photo(640, 480, seed: 5)));
      await h.real(() => c.bob.controller.sendMedia(c.bobsConversation, draft));

      await h.until(() => find.byKey(const Key('image-open')).evaluate().isNotEmpty,
          timeoutMs: 20000, reason: 'the picture arrives chunk by chunk, then shows');
      expect(find.textContaining('Receiving'), findsNothing);
      await h.until(() => c.alice.controller.totalUnread == 0);

      expect(tester.takeException(), isNull);
      await h.dispose();
    });
  });

  group('voice messages', () {
    testWidgets('are explained first, recorded with a timer, sent, and played back',
        (tester) async {
      final c = await _openChat(tester);
      final h = c.h;
      final recorder = h.recorderOf(c.alice);
      final permissions = h.permissionsOf(c.alice);

      await h.tap(find.byKey(const Key('composer-mic')));
      expect(find.text('Allow the microphone?'), findsOneWidget);
      expect(find.textContaining('only while you are recording'), findsOneWidget);
      expect(permissions.requested, isEmpty, reason: 'the system is asked only after "Continue"');
      expect(recorder.starts, 0);

      await h.tap(find.byKey(const Key('permission-continue')));
      expect(permissions.requested, [AppPermission.microphone]);
      expect(recorder.starts, 1);
      expect(recorder.isRecording, isTrue);

      // The bar swaps to the recording view: delete, timer, bars, send.
      expect(find.byKey(const Key('voice-cancel')), findsOneWidget);
      expect(find.byKey(const Key('voice-send')), findsOneWidget);
      expect(_field, findsNothing, reason: 'the text field gives way to the recording bar');
      expect(find.byKey(const Key('voice-timer')), findsOneWidget);
      expect(find.text('0:00'), findsOneWidget);
      recorder.tick(const Duration(seconds: 3), level: 0.8);
      await h.settle();
      expect(find.text('0:03'), findsOneWidget, reason: 'the timer follows the recording');

      await h.tap(find.byKey(const Key('voice-send')));
      await h.until(() => find.byKey(const Key('voice-play')).evaluate().isNotEmpty,
          reason: 'the voice message appears in the chat');
      expect(recorder.isRecording, isFalse);
      expect(find.byKey(const Key('composer-mic')), findsOneWidget, reason: 'the composer is back');
      expect(find.text('0:06'), findsOneWidget, reason: 'the clip is 6 seconds long');
      await h.until(() => find.textContaining('Delivered').evaluate().isNotEmpty,
          timeoutMs: 20000, reason: 'Bob confirms once the whole clip arrived');

      // Bob holds exactly the recording.
      final received = (await _bobHas(c, 1)).single;
      expect(received.kind, MessageKind.voice);
      final bytes = await h.real(() async {
        final m = (await c.bob.controller.loadMedia([received.mediaId!]))[received.mediaId]!;
        expect(m.isReady, isTrue);
        expect(m.durationMs, 6000);
        return c.bob.controller.mediaBytes(m);
      });
      expect(bytes, recorder.result!.bytes);

      // Play, change the speed, pause.
      final player = h.playerOf(c.alice);
      await h.tap(find.byKey(const Key('voice-play')));
      expect(player.played, hasLength(1));
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
      expect(find.text('1x'), findsOneWidget, reason: 'the speed button shows while it plays');
      await h.tap(find.text('1x'));
      expect(find.text('1.5x'), findsOneWidget);
      await h.tap(find.byKey(const Key('voice-play')));
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);

      expect(tester.takeException(), isNull);
      await h.dispose();
    });

    testWidgets('a recording can be thrown away before it is sent', (tester) async {
      final c = await _openChat(tester);
      final h = c.h;
      final recorder = h.recorderOf(c.alice);
      h.permissionsOf(c.alice).set(AppPermission.microphone, PermissionOutcome.granted);

      await h.tap(find.byKey(const Key('composer-mic')));
      expect(recorder.starts, 1, reason: 'already allowed, so no explanation is shown');
      expect(find.text('Allow the microphone?'), findsNothing);
      await h.tap(find.byKey(const Key('voice-cancel')));

      expect(recorder.isRecording, isFalse);
      expect(recorder.cancels, 1);
      expect(find.byKey(const Key('composer-mic')), findsOneWidget);
      expect(find.byKey(const Key('voice-play')), findsNothing);
      expect(await h.real(() => c.alice.controller.loadMessages(c.conversation)), isEmpty);

      expect(tester.takeException(), isNull);
      await h.dispose();
    });

    testWidgets('a recording that is too short is not sent, and says why', (tester) async {
      final c = await _openChat(tester);
      final h = c.h;
      final recorder = h.recorderOf(c.alice)..result = null;
      h.permissionsOf(c.alice).set(AppPermission.microphone, PermissionOutcome.granted);

      await h.tap(find.byKey(const Key('composer-mic')));
      await h.tap(find.byKey(const Key('voice-send')));

      expect(recorder.isRecording, isFalse);
      expect(find.textContaining('too short for a voice message'), findsOneWidget);
      expect(find.byKey(const Key('composer-mic')), findsOneWidget);
      expect(await h.real(() => c.alice.controller.loadMessages(c.conversation)), isEmpty);

      expect(tester.takeException(), isNull);
      await h.dispose();
    });

    testWidgets('when the limit is reached the recording ends by itself, ready to send',
        (tester) async {
      final c = await _openChat(tester);
      final h = c.h;
      final recorder = h.recorderOf(c.alice);
      h.permissionsOf(c.alice).set(AppPermission.microphone, PermissionOutcome.granted);

      await h.tap(find.byKey(const Key('composer-mic')));
      recorder.hitLimit();
      await h.settle();
      expect(recorder.isRecording, isFalse, reason: 'the recorder was stopped');
      expect(find.byKey(const Key('voice-send')), findsOneWidget, reason: 'still waiting to be sent');
      expect(find.text('0:06'), findsOneWidget);

      await h.tap(find.byKey(const Key('voice-send')));
      await h.until(() => find.byKey(const Key('voice-play')).evaluate().isNotEmpty);

      expect(tester.takeException(), isNull);
      await h.dispose();
    });

    testWidgets('a refused microphone starts nothing; one switched off for good opens the settings',
        (tester) async {
      final c = await _openChat(tester);
      final h = c.h;
      final recorder = h.recorderOf(c.alice);
      final permissions = h.permissionsOf(c.alice)..answerWhenAsked = PermissionOutcome.denied;

      await h.tap(find.byKey(const Key('composer-mic')));
      await h.tap(find.byKey(const Key('permission-continue')));
      expect(permissions.requested, [AppPermission.microphone]);
      expect(recorder.starts, 0, reason: 'nothing is recorded without permission');
      expect(find.text('Allow the microphone to record a voice message.'), findsOneWidget);

      permissions.set(AppPermission.microphone, PermissionOutcome.permanentlyDenied);
      await h.tap(find.byKey(const Key('composer-mic')));
      expect(find.text('The microphone is switched off'), findsOneWidget);
      await h.tap(find.byKey(const Key('permission-open-settings')));
      expect(permissions.settingsOpened, 1);
      expect(recorder.starts, 0);

      // The person turns it on in the settings; the next try just works.
      permissions.set(AppPermission.microphone, PermissionOutcome.granted);
      await h.tap(find.byKey(const Key('composer-mic')));
      expect(recorder.starts, 1);
      await h.tap(find.byKey(const Key('voice-cancel')));

      expect(tester.takeException(), isNull);
      await h.dispose();
    });

    testWidgets('a recorder that fails to start reports it', (tester) async {
      final c = await _openChat(tester);
      final h = c.h;
      final recorder = h.recorderOf(c.alice)
        ..startError = const VoiceException('The microphone is being used by another app.');
      h.permissionsOf(c.alice).set(AppPermission.microphone, PermissionOutcome.granted);

      await h.tap(find.byKey(const Key('composer-mic')));
      expect(find.text('The microphone is being used by another app.'), findsOneWidget);
      expect(find.byKey(const Key('voice-send')), findsNothing);
      expect(recorder.isRecording, isFalse);

      expect(tester.takeException(), isNull);
      await h.dispose();
    });

    testWidgets('leaving the chat while recording throws the recording away', (tester) async {
      final c = await _openChat(tester);
      final h = c.h;
      final recorder = h.recorderOf(c.alice);
      h.permissionsOf(c.alice).set(AppPermission.microphone, PermissionOutcome.granted);

      await h.tap(find.byKey(const Key('composer-mic')));
      expect(recorder.isRecording, isTrue);
      await tester.pageBack();
      await h.settle();

      expect(find.byType(ChatScreen), findsNothing);
      expect(recorder.isRecording, isFalse, reason: 'the microphone is released');
      expect(await h.real(() => c.alice.controller.loadMessages(c.conversation)), isEmpty);

      expect(tester.takeException(), isNull);
      await h.dispose();
    });

    testWidgets('a voice message from the other phone arrives and can be played',
        (tester) async {
      final c = await _openChat(tester);
      final h = c.h;
      final clip = Uint8List.fromList(List<int>.generate(2500, (i) => (i * 13) & 0xff));
      await h.real(() => c.bob.controller.sendMedia(
            c.bobsConversation,
            MediaDraft(
              kind: MediaKind.voice,
              bytes: clip,
              durationMs: 9000,
              waveform: List<int>.generate(32, (i) => (i * 9) & 0xff),
            ),
          ));

      await h.until(
          () =>
              find.byKey(const Key('voice-play')).evaluate().isNotEmpty &&
              find.textContaining('Receiving').evaluate().isEmpty,
          timeoutMs: 20000,
          reason: 'the clip arrives, then it can be played');
      await h.until(() => c.alice.controller.totalUnread == 0);
      expect(find.text('0:09'), findsOneWidget);
      await h.tap(find.byKey(const Key('voice-play')));
      expect(h.playerOf(c.alice).played, hasLength(1));
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);

      expect(tester.takeException(), isNull);
      await h.dispose();
    });
  });

  group('responsiveness', () {
    testWidgets('opening the keyboard and typing never rebuild the conversation',
        (tester) async {
      final c = await _openChat(tester);
      final h = c.h;
      await h.real(() async {
        for (var i = 0; i < 24; i++) {
          await c.alice.controller.sendDirect(c.bob.id, 'message number $i');
        }
      });
      await h.until(() => find.text('message number 23').evaluate().isNotEmpty);
      await h.settle();
      final before = MessageBubble.debugBuilds;
      expect(before, greaterThan(0));

      // The keyboard slides up over a quarter of a second: a new, larger inset
      // on every frame.
      addTearDown(tester.view.resetViewInsets);
      for (var i = 1; i <= 15; i++) {
        tester.view.viewInsets = FakeViewPadding(bottom: i * 60.0);
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(MessageBubble.debugBuilds, before,
          reason: 'moving the keyboard must not rebuild a single bubble');
      expect(tester.getBottomLeft(_field).dy, lessThanOrEqualTo(760 - 300 + 1),
          reason: 'the composer sits right above the keyboard');
      expect(find.text('message number 23'), findsOneWidget,
          reason: 'the latest message stays visible above the keyboard');

      // Typing only touches the composer.
      const text = 'typing quickly while the keyboard is open';
      for (var i = 1; i <= text.length; i++) {
        await tester.enterText(_field, text.substring(0, i));
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(MessageBubble.debugBuilds, before, reason: 'typing must not rebuild the bubbles');
      expect((tester.widget(_field) as TextField).controller!.text, text);

      expect(tester.takeException(), isNull);
      await h.dispose();
    });

    testWidgets('pictures and voice messages fit the smallest phone with large system text',
        (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final c = await _openChat(tester, width: 320, height: 568);
      final h = c.h;
      final draft = await h.real(() => c.bob.controller.prepareImage(_photo(640, 480, seed: 9)));
      await h.real(() => c.bob.controller.sendMedia(c.bobsConversation, draft));
      await h.until(() => find.byKey(const Key('image-open')).evaluate().isNotEmpty,
          timeoutMs: 30000, reason: 'the picture arrives');
      expect(tester.takeException(), isNull, reason: 'a picture bubble');

      await h.real(() => c.bob.controller.sendMedia(
            c.bobsConversation,
            MediaDraft(
              kind: MediaKind.voice,
              bytes: Uint8List.fromList(List<int>.filled(1800, 3)),
              durationMs: 29000,
              waveform: List<int>.generate(32, (i) => (i * 17) & 0xff),
            ),
          ));
      await h.until(() => find.byKey(const Key('voice-play')).evaluate().isNotEmpty,
          timeoutMs: 30000, reason: 'the voice message arrives');
      expect(find.text('0:29'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'a voice bubble');

      await h.real(() => c.bob.controller.sendDirect(
          c.alice.id, 'and a long caption-like text that has to wrap on the narrow screen'));
      await h.until(() => find.textContaining('and a long caption-like text').evaluate().isNotEmpty);
      expect(tester.takeException(), isNull, reason: 'no overflow');

      // The recording bar fits too.
      h.permissionsOf(c.alice).set(AppPermission.microphone, PermissionOutcome.granted);
      await h.tap(find.byKey(const Key('composer-mic')));
      expect(find.byKey(const Key('voice-send')), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'the recording bar fits');
      await h.tap(find.byKey(const Key('voice-cancel')));

      await h.dispose();
    });

    testWidgets('on a tablet the conversation stays a readable column', (tester) async {
      final c = await _openChat(tester, width: 900, height: 640);
      final h = c.h;
      await _say(c, tester, 'hello from a tablet');
      await h.until(() => find.textContaining('Delivered').evaluate().isNotEmpty);
      final bubble = tester.getSize(find
          .ancestor(of: find.text('hello from a tablet'), matching: find.byType(Material))
          .first);
      expect(bubble.width, lessThanOrEqualTo(560), reason: 'bubbles do not stretch');
      expect(tester.takeException(), isNull);
      await h.dispose();
    });
  });
}
