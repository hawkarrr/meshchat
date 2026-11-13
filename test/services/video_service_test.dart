import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:offline_mesh_chat/core/bytes.dart';
import 'package:offline_mesh_chat/database/message_repository.dart';
import 'package:offline_mesh_chat/models/conversation.dart';
import 'package:offline_mesh_chat/models/message.dart';
import 'package:offline_mesh_chat/protocol/protocol_constants.dart';
import 'package:offline_mesh_chat/services/encryption_service.dart';
import 'package:offline_mesh_chat/services/message_service.dart';

import '../support/fake_clock.dart';
import '../support/memory_network.dart';
import '../support/message_node.dart';
import '../support/test_node.dart';
import 'package:offline_mesh_chat/l10n/l10n.dart';

Matcher _error(MessageErrorKind kind) =>
    throwsA(isA<MessageError>().having((e) => e.kind, 'kind', kind));

const _mesh = PublicRooms.meshIdHex;

MediaDraft _video(Uint8List bytes, {String caption = '', int seconds = 6}) => MediaDraft(
      kind: MediaKind.video,
      bytes: bytes,
      width: 320,
      height: 240,
      durationMs: seconds * 1000,
      caption: caption,
    );

/// Short videos: a new kind of media with its own, bigger size cap; private
/// chats and groups only; cut into chunks, hash-checked, resumable like the rest.
void main() {
  late MemoryNetwork net;
  late FakeClock clock;
  final nodes = <MessageNode>[];

  setUp(() {
    net = MemoryNetwork();
    clock = FakeClock(1700000000000);
    nodes.clear();
  });

  tearDown(() async {
    for (final n in nodes) {
      await n.close();
    }
  });

  Future<MessageNode> mk(String name, int seed) async {
    final n = await MessageNode.create(name, net, clock, seed: seed);
    nodes.add(n);
    return n;
  }

  Future<void> run() => settle(net, nodes.map((n) => n.node),
      extraBusy: () => nodes.any((n) => n.service.hasPendingWork));

  Future<void> connect(List<(MessageNode, MessageNode)> pairs) async {
    for (final (a, b) in pairs) {
      await net.connect(a.id, b.id);
    }
    await run();
  }

  Future<(MessageNode, MessageNode)> pair() async {
    final a = await mk('Alice', 1);
    final b = await mk('Bob', 2);
    await connect([(a, b)]);
    return (a, b);
  }

  group('sending a video', () {
    test('arrives in a private chat byte for byte, and is delivered', () async {
      final (a, b) = await pair();
      final bytes = fakeBytes(200 * 1024, 4);
      final sent = await a.service.sendMedia('dm:${b.id}', _video(bytes, caption: 'the lake'));
      expect(sent.kind, MessageKind.video);
      await run();

      expect((await a.message(sent.id))!.status, MessageStatus.delivered);
      final got = (await b.chatWith(a)).single;
      expect([got.kind, got.body], [MessageKind.video, 'the lake']);
      final item = (await b.mediaOf(got.id))!;
      expect(item.kind, MediaKind.video);
      expect(item.isReady, isTrue);
      expect([item.byteLength, item.width, item.height, item.durationMs], [200 * 1024, 320, 240, 6000]);
      expect(await b.service.media.read(item), bytes, reason: 'every byte, checked against the hash');
      expect((await b.repo.getConversation('dm:${a.id}'))!.previewIn(englishStrings()), '🎬 the lake');
    });

    test('works in a group', () async {
      final a = await mk('Alice', 1);
      final b = await mk('Bob', 2);
      final c = await mk('Carol', 3);
      await connect([(a, b), (a, c), (b, c)]);
      final g = await a.service.groups.create(name: 'Trip', memberIds: [b.id, c.id]);
      await run();
      await b.service.groups.accept(g.id);
      await c.service.groups.accept(g.id);
      await run();
      final bytes = fakeBytes(120 * 1024, 5);
      await a.service.sendMedia(Conversation.groupConversationId(g.id), _video(bytes));
      await run();
      for (final n in [b, c]) {
        final m = (await n.repo.getMessages(Conversation.groupConversationId(g.id))).single;
        expect(m.kind, MessageKind.video, reason: n.name);
        expect(await n.service.media.read((await n.mediaOf(m.id))!), bytes, reason: n.name);
      }
    });

    test('a video can be an answer, and can be forwarded to another chat', () async {
      final (a, b) = await pair();
      final question = await b.service.sendDirect(a.id, 'show me');
      await run();
      final bytes = fakeBytes(60 * 1024, 6);
      final sent = await a.service.sendMedia(
          'dm:${b.id}', _video(bytes).copyWith(replyToId: question.id));
      await run();
      expect((await b.message(sent.id))!.replyToId, question.id);

      final c = await mk('Carol', 3);
      await connect([(a, c)]);
      await c.node.router.announceNow();
      await run();
      final forwarded = await a.service.forward([sent.id], 'dm:${c.id}');
      await run();
      expect(forwarded.single.forwardedFrom, 'Alice');
      expect(await c.service.media.read((await c.mediaOf(forwarded.single.id))!), bytes);
    });

    test('the largest video crosses a relay, and the relay keeps no copy of the file', () async {
      final a = await mk('Alice', 1);
      final relay = await mk('Relay', 2);
      final c = await mk('Carol', 3);
      await connect([(a, relay), (relay, c)]);
      await c.node.router.announceNow();
      await a.node.router.announceNow();
      await run();

      final bytes = fakeBytes(Protocol.maxVideoBytes, 12);
      final sent = await a.service.sendMedia('dm:${c.id}', _video(bytes));
      await run();
      expect((await a.message(sent.id))!.status, MessageStatus.delivered);
      final got = (await c.chatWith(a)).single;
      expect(await c.service.media.read((await c.mediaOf(got.id))!), bytes);
      expect(relay.mediaStore.files, isEmpty, reason: 'a relay carries sealed chunks, it never assembles the file');
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('deleting it for everyone removes the file on both phones', () async {
      final (a, b) = await pair();
      final sent = await a.service.sendMedia('dm:${b.id}', _video(fakeBytes(50 * 1024, 7)));
      await run();
      expect(a.mediaStore.files, isNotEmpty);
      expect(b.mediaStore.files, isNotEmpty);

      await a.service.actions.deleteForEveryone('dm:${b.id}', [sent.id]);
      await run();
      expect(a.mediaStore.files, isEmpty);
      expect(b.mediaStore.files, isEmpty);
      expect(await b.mediaOf(sent.id), isNull);
    });

    test('a transfer that is cut half way is finished when the phones meet again', () async {
      final (a, b) = await pair();
      await net.disconnect(a.id, b.id);
      await run();
      final bytes = fakeBytes(90 * 1024, 8);
      final sent = await a.service.sendMedia('dm:${b.id}', _video(bytes));
      await run();
      expect((await a.message(sent.id))!.status, MessageStatus.queued);
      expect(await b.chatWith(a), isEmpty);

      await connect([(a, b)]);
      final got = (await b.chatWith(a)).single;
      expect(await b.service.media.read((await b.mediaOf(got.id))!), bytes);
      expect((await a.message(sent.id))!.status, MessageStatus.delivered);
    });
  });

  group('the limits', () {
    test('up to 512 KB, and not a byte more', () async {
      final (a, b) = await pair();
      await a.service.sendMedia('dm:${b.id}', _video(fakeBytes(Protocol.maxVideoBytes, 9)));
      await expectLater(
        a.service.sendMedia('dm:${b.id}', _video(fakeBytes(Protocol.maxVideoBytes + 1, 9))),
        _error(MessageErrorKind.mediaTooLarge),
      );
    });

    test('the largest video, all 342 chunks of it, still arrives complete', () async {
      final (a, b) = await pair();
      final bytes = fakeBytes(Protocol.maxVideoBytes, 11);
      final sent = await a.service.sendMedia('dm:${b.id}', _video(bytes));
      await run();
      expect((await a.message(sent.id))!.status, MessageStatus.delivered);
      final got = (await b.chatWith(a)).single;
      expect(await b.service.media.read((await b.mediaOf(got.id))!), bytes);
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('the person can lower their own sending limit, never raise it above the protocol cap',
        () async {
      final (a, b) = await pair();
      a.service.media.maxVideoSendBytes = 128 * 1024;
      await expectLater(
        a.service.sendMedia('dm:${b.id}', _video(fakeBytes(200 * 1024, 1))),
        throwsA(isA<MessageError>()
            .having((e) => e.kind, 'kind', MessageErrorKind.mediaTooLarge)
            .having((e) => e.message, 'message', contains('128 KB'))),
      );
      await a.service.sendMedia('dm:${b.id}', _video(fakeBytes(100 * 1024, 1)));

      a.service.media.maxVideoSendBytes = 10 * 1024 * 1024;
      await expectLater(
        a.service.sendMedia('dm:${b.id}', _video(fakeBytes(Protocol.maxVideoBytes + 1, 1))),
        _error(MessageErrorKind.mediaTooLarge),
      );
    });

    test('pictures and voice messages keep their 64 KB cap', () async {
      final (a, b) = await pair();
      await expectLater(
        a.service.sendMedia(
          'dm:${b.id}',
          MediaDraft(kind: MediaKind.image, bytes: fakeBytes(Protocol.maxMediaBytes + 1), width: 10, height: 10),
        ),
        _error(MessageErrorKind.mediaTooLarge),
      );
    });

    test('an empty file is not a video', () async {
      final (a, b) = await pair();
      await expectLater(a.service.sendMedia('dm:${b.id}', _video(Uint8List(0))),
          _error(MessageErrorKind.invalidMedia));
    });
  });

  group('public rooms', () {
    test('a video cannot be sent to one, and the reason is given', () async {
      final a = await mk('Alice', 1);
      await expectLater(
        a.service.sendMedia('rm:$_mesh', _video(fakeBytes(20 * 1024, 2))),
        throwsA(isA<MessageError>()
            .having((e) => e.kind, 'kind', MessageErrorKind.notAllowed)
            .having((e) => e.message, 'message', contains('public rooms'))),
      );
      expect(await a.repo.getMessages('rm:$_mesh'), isEmpty);
    });

    test('nor forwarded to one', () async {
      final (a, b) = await pair();
      final sent = await a.service.sendMedia('dm:${b.id}', _video(fakeBytes(20 * 1024, 2)));
      await run();
      await expectLater(a.service.forward([sent.id], 'rm:$_mesh'), _error(MessageErrorKind.notAllowed));
    });

    test('a selection with a video in it is refused whole: the text before it is not sent either',
        () async {
      final (a, b) = await pair();
      final text = await a.service.sendDirect(b.id, 'for the room');
      final video = await a.service.sendMedia('dm:${b.id}', _video(fakeBytes(20 * 1024, 2)));
      await run();

      await expectLater(
          a.service.forward([text.id, video.id], 'rm:$_mesh'), _error(MessageErrorKind.notAllowed));
      expect(await a.repo.getMessages('rm:$_mesh'), isEmpty, reason: 'nothing went ahead of it');

      final sent = await a.service.forward([text.id, video.id], 'dm:${b.id}');
      expect(sent, hasLength(2), reason: 'the same selection is fine for a private chat');
    });

    test('one that arrives anyway, from a phone that does not follow the rules, is not shown',
        () async {
      final a = await mk('Alice', 1);
      final b = await mk('Bob', 2);
      await connect([(a, b)]);

      final bytes = fakeBytes(8 * 1024, 3);
      final manifest = MediaEnvelope(
        mediaKind: MediaKind.video,
        mediaId: a.node.crypto.randomBytes(Protocol.messageIdLength),
        mimeCode: MediaMime.mp4,
        byteLength: bytes.length,
        chunkCount: EnvelopeCodec.chunkCountFor(bytes.length),
        sha256: Uint8List(32)..fillRange(0, 32, 7),
        width: 10,
        height: 10,
        nickname: 'Alice',
      );
      final packet = await a.node.crypto.buildRoomMessage(roomId: hexToBytes(_mesh), envelope: manifest);
      await a.node.router.submit(packet);
      await run();

      expect(await b.repo.getMessages('rm:$_mesh'), isEmpty);
      final events = await b.repo.securityEvents();
      expect(events.where((e) => e.kind == SecurityEventKind.malformed && (e.detail ?? '').contains('video')),
          hasLength(1));
    });
  });
}
