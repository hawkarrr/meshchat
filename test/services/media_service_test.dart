import 'dart:async';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_mesh_chat/core/bytes.dart';
import 'package:offline_mesh_chat/database/message_repository.dart';
import 'package:offline_mesh_chat/models/media.dart';
import 'package:offline_mesh_chat/models/message.dart';
import 'package:offline_mesh_chat/protocol/mesh_packet.dart';
import 'package:offline_mesh_chat/protocol/protocol_constants.dart';
import 'package:offline_mesh_chat/services/encryption_service.dart';
import 'package:offline_mesh_chat/services/message_service.dart';

import '../support/fake_clock.dart';
import '../support/memory_network.dart';
import '../support/message_node.dart';
import '../support/test_node.dart';
import 'package:offline_mesh_chat/l10n/l10n.dart';
import 'package:offline_mesh_chat/models/delivery_problem.dart';

Matcher _error(MessageErrorKind kind) =>
    throwsA(isA<MessageError>().having((e) => e.kind, 'kind', kind));

const _mesh = PublicRooms.meshIdHex;

MediaDraft _image(
  Uint8List bytes, {
  String caption = '',
  int width = 320,
  int height = 240,
}) =>
    MediaDraft(kind: MediaKind.image, bytes: bytes, width: width, height: height, caption: caption);

MediaDraft _voice(Uint8List bytes, {int ms = 12000}) => MediaDraft(
      kind: MediaKind.voice,
      bytes: bytes,
      durationMs: ms,
      waveform: List<int>.generate(40, (i) => (i * 6) & 0xff),
    );

bool _contains(Uint8List haystack, List<int> needle) {
  for (var i = 0; i + needle.length <= haystack.length; i++) {
    var ok = true;
    for (var j = 0; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) {
        ok = false;
        break;
      }
    }
    if (ok) return true;
  }
  return false;
}

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

  Future<MessageNode> mk(String name, int seed,
      {MediaConfig config = const MediaConfig(), MemoryMediaStore? store}) async {
    final n = await MessageNode.create(name, net, clock,
        seed: seed, mediaConfig: config, mediaStore: store);
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

  Future<void> introduce(MessageNode who) async {
    await who.node.router.announceNow();
    await run();
  }

  /// Advance time and let every router retry what is overdue.
  Future<void> retryRound([Duration by = const Duration(seconds: 45)]) async {
    clock.advance(by);
    for (final n in nodes) {
      await n.node.router.flush();
    }
    await run();
  }

  Future<ChatMessage> only(MessageNode n, String conversationId) async {
    final all = await n.repo.getMessages(conversationId);
    expect(all, hasLength(1));
    return all.single;
  }

  Future<Uint8List?> storedBytes(MessageNode n, ChatMessage m) async {
    final item = await n.mediaRepo.get(m.mediaId!);
    return item == null ? null : n.service.media.read(item);
  }

  group('private images', () {
    test('arrive complete and verified, and the sender sees "delivered"', () async {
      final a = await mk('Alice', 1);
      final b = await mk('Bob', 2);
      await connect([(a, b)]);
      final bytes = fakeBytes(5000);

      final sent = await a.service.sendMedia('dm:${b.id}', _image(bytes, caption: 'Look!'));
      expect(sent.kind, MessageKind.image);
      expect(sent.status, MessageStatus.queued);
      expect(sent.body, 'Look!');
      await run();

      final got = await only(b, 'dm:${a.id}');
      expect(got.kind, MessageKind.image);
      expect(got.body, 'Look!');
      expect(got.isOutgoing, isFalse);
      expect(got.senderId, a.id);
      final item = (await b.mediaRepo.get(got.mediaId!))!;
      expect(item.state, MediaState.ready);
      expect(item.progress, 1);
      expect(item.width, 320);
      expect(item.height, 240);
      expect(item.fileName, endsWith('.jpg'));
      expect(await storedBytes(b, got), bytes);
      expect(await b.mediaRepo.chunks(item.id), isEmpty, reason: 'the pieces are cleaned up');
      expect(await b.mediaRepo.keyOf(item.id), isNull, reason: 'the key is dropped once done');
      expect((await b.repo.getConversation('dm:${a.id}'))!.previewIn(englishStrings()), '📷 Look!');
      expect((await b.repo.getConversation('dm:${a.id}'))!.unreadCount, 1);

      final mine = (await a.message(sent.id))!;
      expect(mine.status, MessageStatus.delivered);
      expect(await a.mediaRepo.unackedPartCount(sent.id), 0);
      // Our own copy is kept locally and shown straight away.
      expect(await storedBytes(a, mine), bytes);
    });

    test('the bytes never appear on the air in the clear', () async {
      final a = await mk('Alice', 1);
      final b = await mk('Bob', 2);
      await connect([(a, b)]);
      final bytes = fakeBytes(4000, 5);
      await a.service.sendMedia('dm:${b.id}', _image(bytes));
      await run();
      final probe = bytes.sublist(1000, 1032);
      for (final d in net.log) {
        expect(_contains(d.bytes, probe), isFalse);
      }
    });

    test('a single-chunk image and the largest allowed image both work', () async {
      final a = await mk('Alice', 1);
      final b = await mk('Bob', 2);
      await connect([(a, b)]);
      await a.service.sendMedia('dm:${b.id}', _image(fakeBytes(300)));
      await run();
      await a.service.sendMedia('dm:${b.id}', _image(fakeBytes(Protocol.maxMediaBytes, 9)));
      await run();
      final all = await b.repo.getMessages('dm:${a.id}');
      expect(all.length, 2);
      for (final m in all) {
        expect((await b.mediaRepo.get(m.mediaId!))!.state, MediaState.ready);
      }
      expect((await storedBytes(b, all.last))!.length, Protocol.maxMediaBytes);
    });

    test('through a relay, which carries sealed packets it cannot open', () async {
      final a = await mk('Alice', 1);
      final r = await mk('Relay', 2);
      final b = await mk('Bob', 3);
      await connect([(a, r), (r, b)]);
      await introduce(b);
      final bytes = fakeBytes(6000, 3);

      final sent = await a.service.sendMedia('dm:${b.id}', _image(bytes));
      await run();

      final got = await only(b, 'dm:${a.id}');
      expect(got.hops, 1);
      expect(await storedBytes(b, got), bytes);
      expect((await a.message(sent.id))!.status, MessageStatus.delivered);

      // The relay has no message, no media and no key - and kept no plaintext.
      expect(await r.repo.listConversations().then((l) => l.where((c) => c.id.startsWith('dm:'))),
          everyElement(isNotNull));
      expect(await r.mediaRepo.getMany([got.mediaId!]), isEmpty);
      final probe = bytes.sublist(2000, 2032);
      for (final e in await r.node.outbox.all()) {
        expect(_contains(e.packet, probe), isFalse);
      }
      for (final d in net.log.where((d) => d.toId == r.id)) {
        expect(_contains(d.bytes, probe), isFalse);
      }
      expect(await r.node.outbox.count(), 0, reason: 'nobody keeps carrying delivered parts');
    });

    test('a bystander who is handed the packets can neither read nor keep the image', () async {
      final a = await mk('Alice', 1);
      final b = await mk('Bob', 2);
      final eve = await mk('Eve', 3);
      await connect([(a, b), (a, eve)]);
      await introduce(b);
      final bytes = fakeBytes(3000, 4);
      await a.service.sendMedia('dm:${b.id}', _image(bytes));
      await run();
      expect(await eve.repo.listConversations().then((l) => l.where((c) => c.type.name != 'room')), isEmpty);
      expect(await eve.mediaStore.list(), isEmpty);
      expect(eve.mediaStore.files, isEmpty);
      expect((await eve.repo.securityEvents()), isEmpty, reason: 'carrying is not an offence');
    });

    test('chunks that arrive before the description are held and used when it arrives', () async {
      final a = await mk('Alice', 1);
      final b = await mk('Bob', 2);
      await connect([(a, b)]);
      var held = false;
      final manifestIds = <String>{};
      net.onWire = (from, to, bytes) {
        final p = MeshPacket.decode(bytes);
        if (from == a.id && p.type == PacketType.direct && !p.isChunk && !held) {
          held = true; // lose the first copy of the description
          manifestIds.add(p.messageIdHex);
          return null;
        }
        return bytes;
      };
      final bytes = fakeBytes(5000, 6);
      final sent = await a.service.sendMedia('dm:${b.id}', _image(bytes));
      await run();
      expect(manifestIds, {sent.id});
      expect(await b.repo.getMessages('dm:${a.id}'), isEmpty, reason: 'no description yet');
      final orphans = await b.mediaRepo.orphanChunkCount();
      expect(orphans, greaterThan(0));

      await retryRound();
      final got = await only(b, 'dm:${a.id}');
      expect(await storedBytes(b, got), bytes);
      expect(await b.mediaRepo.orphanChunkCount(), 0);
      expect((await a.message(sent.id))!.status, MessageStatus.delivered);
    });

    test('a lost chunk is resent until the image is complete', () async {
      final a = await mk('Alice', 1);
      final b = await mk('Bob', 2);
      await connect([(a, b)]);
      var dropped = 0;
      net.onWire = (from, to, bytes) {
        final p = MeshPacket.decode(bytes);
        if (from == a.id && p.isChunk && dropped < 2) {
          dropped++;
          return null;
        }
        return bytes;
      };
      final bytes = fakeBytes(7000, 2);
      final sent = await a.service.sendMedia('dm:${b.id}', _image(bytes));
      await run();
      final item = (await b.mediaRepo.forMessage(sent.id))!;
      expect(item.state, MediaState.receiving);
      expect(item.progress, lessThan(1));
      expect((await a.message(sent.id))!.status, MessageStatus.sent);

      await retryRound();
      expect((await b.mediaRepo.forMessage(sent.id))!.state, MediaState.ready);
      expect((await a.message(sent.id))!.status, MessageStatus.delivered);
      expect(await storedBytes(b, (await b.repo.getMessage(sent.id))!), bytes);
    });

    test('a chunk a relay tampered with is rejected, and the genuine copy still completes it',
        () async {
      final a = await mk('Alice', 1);
      final r = await mk('Relay', 2);
      final b = await mk('Bob', 3);
      await connect([(a, r), (r, b)]);
      await introduce(b);
      var tampered = false;
      net.onWire = (from, to, bytes) {
        final p = MeshPacket.decode(bytes);
        if (from == r.id && to == b.id && p.isChunk && !tampered) {
          tampered = true;
          return Uint8List.fromList(bytes)..[140] ^= 0x01;
        }
        return bytes;
      };
      final data = fakeBytes(5000, 8);
      final sent = await a.service.sendMedia('dm:${b.id}', _image(data));
      await run();
      expect((await b.repo.securityEvents()).map((e) => e.kind), contains(SecurityEventKind.badSignature));
      expect((await b.mediaRepo.forMessage(sent.id))!.state, MediaState.receiving);

      await retryRound();
      expect((await b.mediaRepo.forMessage(sent.id))!.state, MediaState.ready);
      expect(await storedBytes(b, (await b.repo.getMessage(sent.id))!), data);
    });

    test('a file whose checksum does not match its description is discarded', () async {
      final a = await mk('Alice', 1);
      final b = await mk('Bob', 2);
      await connect([(a, b)]);
      // Alice's phone (or someone with her key) describes one file and sends another.
      final real = fakeBytes(3000, 1);
      final different = fakeBytes(3000, 2);
      final key = a.node.crypto.randomBytes(32);
      final mediaId = a.node.crypto.randomBytes(16);
      final sha = Uint8List.fromList((await Sha256().hash(real)).bytes);
      final manifest = MediaEnvelope(
        mediaKind: MediaKind.image,
        mediaId: mediaId,
        mimeCode: MediaMime.jpeg,
        byteLength: real.length,
        chunkCount: 2,
        sha256: sha,
        key: key,
        width: 10,
        height: 10,
      );
      await a.node.router.submit(await a.node.crypto.buildDirectEnvelope(
        recipientSigningKey: b.node.signingKey,
        recipientAgreementKey: b.node.agreementKey,
        envelope: manifest,
      ));
      for (var i = 0; i < 2; i++) {
        await a.node.router.submit(await a.node.crypto.buildChunk(
          type: PacketType.direct,
          recipientKey: b.node.signingKey,
          mediaId: mediaId,
          index: i,
          count: 2,
          data: Uint8List.sublistView(different, i * 1536, i == 0 ? 1536 : 3000),
          key: key,
        ));
      }
      await run();

      final item = (await b.mediaRepo.get(bytesToHex(mediaId)))!;
      expect(item.state, MediaState.failed);
      expect(item.error, contains('damaged'));
      expect(item.fileName, isNull);
      expect(b.mediaStore.files, isEmpty, reason: 'a bad file is never kept');
      expect(await b.mediaRepo.chunks(item.id), isEmpty);
      expect((await b.repo.securityEvents()).map((e) => e.kind), contains(SecurityEventKind.badMedia));
    });

    test('a file of the wrong length is discarded too', () async {
      final a = await mk('Alice', 1);
      final b = await mk('Bob', 2);
      await connect([(a, b)]);
      final real = fakeBytes(3000, 1);
      final key = a.node.crypto.randomBytes(32);
      final mediaId = a.node.crypto.randomBytes(16);
      final manifest = MediaEnvelope(
        mediaKind: MediaKind.image,
        mediaId: mediaId,
        mimeCode: MediaMime.jpeg,
        byteLength: real.length,
        chunkCount: 2,
        sha256: Uint8List.fromList((await Sha256().hash(real)).bytes),
        key: key,
        width: 10,
        height: 10,
      );
      await a.node.router.submit(await a.node.crypto.buildDirectEnvelope(
        recipientSigningKey: b.node.signingKey,
        recipientAgreementKey: b.node.agreementKey,
        envelope: manifest,
      ));
      // The second chunk is shorter than the description says.
      for (var i = 0; i < 2; i++) {
        await a.node.router.submit(await a.node.crypto.buildChunk(
          type: PacketType.direct,
          recipientKey: b.node.signingKey,
          mediaId: mediaId,
          index: i,
          count: 2,
          data: Uint8List.sublistView(real, i * 1536, i == 0 ? 1536 : 2900),
          key: key,
        ));
      }
      await run();
      expect((await b.mediaRepo.get(bytesToHex(mediaId)))!.state, MediaState.failed);
    });

    test('a chunk count that disagrees with the description is rejected', () async {
      final a = await mk('Alice', 1);
      final b = await mk('Bob', 2);
      await connect([(a, b)]);
      final real = fakeBytes(3000, 1);
      final key = a.node.crypto.randomBytes(32);
      final mediaId = a.node.crypto.randomBytes(16);
      await a.node.router.submit(await a.node.crypto.buildDirectEnvelope(
        recipientSigningKey: b.node.signingKey,
        recipientAgreementKey: b.node.agreementKey,
        envelope: MediaEnvelope(
          mediaKind: MediaKind.image,
          mediaId: mediaId,
          mimeCode: MediaMime.jpeg,
          byteLength: real.length,
          chunkCount: 2,
          sha256: Uint8List.fromList((await Sha256().hash(real)).bytes),
          key: key,
          width: 10,
          height: 10,
        ),
      ));
      await a.node.router.submit(await a.node.crypto.buildChunk(
        type: PacketType.direct,
        recipientKey: b.node.signingKey,
        mediaId: mediaId,
        index: 0,
        count: 5, // claims five pieces
        data: Uint8List.sublistView(real, 0, 1536),
        key: key,
      ));
      await run();
      final item = (await b.mediaRepo.get(bytesToHex(mediaId)))!;
      expect(item.state, MediaState.receiving);
      expect(item.receivedChunks, 0);
      expect((await b.repo.securityEvents()).map((e) => e.kind), contains(SecurityEventKind.badMedia));
    });

    test('a private image whose description carries no key is refused', () async {
      final a = await mk('Alice', 1);
      final b = await mk('Bob', 2);
      await connect([(a, b)]);
      final real = fakeBytes(1000);
      await a.node.router.submit(await a.node.crypto.buildDirectEnvelope(
        recipientSigningKey: b.node.signingKey,
        recipientAgreementKey: b.node.agreementKey,
        envelope: MediaEnvelope(
          mediaKind: MediaKind.image,
          mediaId: a.node.crypto.randomBytes(16),
          mimeCode: MediaMime.jpeg,
          byteLength: real.length,
          chunkCount: 1,
          sha256: Uint8List.fromList((await Sha256().hash(real)).bytes),
          width: 10,
          height: 10,
        ),
      ));
      await run();
      expect(await b.repo.getMessages('dm:${a.id}'), isEmpty);
      expect((await b.repo.securityEvents()).map((e) => e.kind), contains(SecurityEventKind.malformed));
    });

    test('repeating packets changes nothing', () async {
      final a = await mk('Alice', 1);
      final b = await mk('Bob', 2);
      await connect([(a, b)]);
      net.duplicateAll = true;
      final bytes = fakeBytes(4500, 7);
      final sent = await a.service.sendMedia('dm:${b.id}', _image(bytes));
      await run();
      expect(await b.repo.getMessages('dm:${a.id}'), hasLength(1));
      expect(await storedBytes(b, (await b.repo.getMessage(sent.id))!), bytes);
      expect((await b.repo.getConversation('dm:${a.id}'))!.unreadCount, 1);
    });

    test('an image that never completes is given up on after twelve hours', () async {
      final a = await mk('Alice', 1);
      final b = await mk('Bob', 2);
      await connect([(a, b)]);
      net.onWire = (from, to, bytes) {
        final p = MeshPacket.decode(bytes);
        return (from == a.id && p.isChunk && p.messageIdHex.compareTo('8') > 0) ? null : bytes;
      };
      final sent = await a.service.sendMedia('dm:${b.id}', _image(fakeBytes(8000, 3)));
      await run();
      final before = (await b.mediaRepo.forMessage(sent.id))!;
      expect(before.state, MediaState.receiving);

      clock.advance(const Duration(hours: 13));
      await b.service.maintain();
      final after = (await b.mediaRepo.forMessage(sent.id))!;
      expect(after.state, MediaState.failed);
      expect(after.error, DeliveryProblem.fileIncomplete.code);
      expect(await b.mediaRepo.chunks(after.id), isEmpty);
    });

    test('too big, empty and malformed pictures are refused with an explanation', () async {
      final a = await mk('Alice', 1);
      final b = await mk('Bob', 2);
      await connect([(a, b)]);
      await expectLater(
        a.service.sendMedia('dm:${b.id}', _image(fakeBytes(Protocol.maxMediaBytes + 1))),
        _error(MessageErrorKind.mediaTooLarge),
      );
      await expectLater(a.service.sendMedia('dm:${b.id}', _image(Uint8List(0))),
          _error(MessageErrorKind.invalidMedia));
      await expectLater(a.service.sendMedia('dm:${b.id}', _image(fakeBytes(100), width: 0)),
          _error(MessageErrorKind.invalidMedia));
      await expectLater(a.service.sendMedia('dm:${b.id}', _image(fakeBytes(100), width: 9000)),
          _error(MessageErrorKind.invalidMedia));
      expect(await a.repo.getMessages('dm:${b.id}'), isEmpty);
      expect(a.mediaStore.files, isEmpty, reason: 'a refused file leaves nothing behind');
    });

    test('captions are limited and cleaned', () async {
      final a = await mk('Alice', 1);
      final b = await mk('Bob', 2);
      await connect([(a, b)]);
      final sent = await a.service.sendMedia('dm:${b.id}', _image(fakeBytes(500), caption: '€' * 300));
      await run();
      expect(sent.body.length * 3, lessThanOrEqualTo(Protocol.maxCaptionBytes));
      expect((await only(b, 'dm:${a.id}')).body, sent.body);
    });

    test('sending to someone we cannot encrypt to is refused', () async {
      final a = await mk('Alice', 1);
      final ghost = await mk('Ghost', 3);
      await a.repo.upsertPeer(signingKey: ghost.node.signingKey, seenAtMs: clock.nowMs);
      await expectLater(a.service.sendMedia('dm:${ghost.id}', _image(fakeBytes(100))),
          _error(MessageErrorKind.noEncryptionKey));
      await expectLater(a.service.sendMedia('dm:${'ab' * 32}', _image(fakeBytes(100))),
          _error(MessageErrorKind.unknownConversation));
    });
  });

  group('interrupted transfers', () {
    test('a relay link that drops mid-transfer: the rest follows when it comes back', () async {
      final a = await mk('Alice', 1);
      final r = await mk('Relay', 2);
      final b = await mk('Bob', 3);
      await connect([(a, r), (r, b)]);
      await introduce(b);

      var chunksToBob = 0;
      net.onWire = (from, to, bytes) {
        final p = MeshPacket.decode(bytes);
        if (from == r.id && to == b.id && p.isChunk && ++chunksToBob == 3) {
          // After the third chunk the relay's link to Bob fails.
          r.node.transport.failSendsTo.add(b.id);
        }
        return bytes;
      };
      final data = fakeBytes(9000, 4);
      final sent = await a.service.sendMedia('dm:${b.id}', _image(data));
      await run();

      var item = (await b.mediaRepo.forMessage(sent.id))!;
      expect(item.state, MediaState.receiving, reason: 'the transfer is half done');
      expect(item.receivedChunks, inInclusiveRange(1, item.chunkCount - 1));
      expect((await a.message(sent.id))!.status, isNot(MessageStatus.delivered));
      expect(await r.node.outbox.count(), greaterThan(0), reason: 'the relay is still carrying the rest');

      r.node.transport.failSendsTo.clear();
      await retryRound(const Duration(minutes: 20));
      item = (await b.mediaRepo.forMessage(sent.id))!;
      expect(item.state, MediaState.ready);
      expect(await storedBytes(b, (await b.repo.getMessage(sent.id))!), data);
      expect((await a.message(sent.id))!.status, MessageStatus.delivered);
    });

    test('the recipient walks out of range and back: sending resumes', () async {
      final a = await mk('Alice', 1);
      final b = await mk('Bob', 2);
      await connect([(a, b)]);
      await net.disconnect(a.id, b.id);
      await run();
      final data = fakeBytes(6000, 5);
      final sent = await a.service.sendMedia('dm:${b.id}', _image(data));
      await run();
      expect((await a.message(sent.id))!.status, MessageStatus.queued);

      clock.advance(const Duration(minutes: 30));
      await connect([(a, b)]);
      expect(await storedBytes(b, (await b.repo.getMessage(sent.id))!), data);
      expect((await a.message(sent.id))!.status, MessageStatus.delivered);
    });

    test('a failed image can be sent again, and the old copy and its file are cleaned up',
        () async {
      final a = await mk('Alice', 1);
      final b = await mk('Bob', 2);
      await connect([(a, b)]);
      await net.disconnect(a.id, b.id);
      await run();
      final data = fakeBytes(2500, 6);
      final sent = await a.service.sendMedia('dm:${b.id}', _image(data, caption: 'again'));
      await run();
      clock.advance(const Duration(hours: 13));
      await a.node.router.maintain();
      await run();
      expect((await a.message(sent.id))!.status, MessageStatus.failed);

      await connect([(a, b)]);
      final fresh = await a.service.retry(sent.id);
      await run();
      expect(fresh.id, isNot(sent.id));
      expect(fresh.body, 'again');
      expect(await a.message(sent.id), isNull);
      expect((await a.message(fresh.id))!.status, MessageStatus.delivered);
      expect(await storedBytes(b, (await b.repo.getMessage(fresh.id))!), data);

      await a.service.maintain();
      expect(a.mediaStore.files.length, 1, reason: 'only the live copy stays on disk');
    });
  });

  group('voice messages', () {
    test('arrive with their duration and waveform, and say so in the chat list', () async {
      final a = await mk('Alice', 1);
      final b = await mk('Bob', 2);
      await connect([(a, b)]);
      final audio = fakeBytes(7000, 8);
      final sent = await a.service.sendMedia('dm:${b.id}', _voice(audio, ms: 21000));
      expect(sent.kind, MessageKind.voice);
      await run();

      final got = await only(b, 'dm:${a.id}');
      expect(got.kind, MessageKind.voice);
      final item = (await b.mediaRepo.get(got.mediaId!))!;
      expect(item.isVoice, isTrue);
      expect(item.state, MediaState.ready);
      expect(item.durationMs, 21000);
      expect(item.duration, const Duration(seconds: 21));
      expect(item.waveform, List<int>.generate(40, (i) => (i * 6) & 0xff));
      expect(item.fileName, endsWith('.m4a'));
      expect(await storedBytes(b, got), audio);
      expect((await b.repo.getConversation('dm:${a.id}'))!.previewIn(englishStrings()), '🎤 Voice message');
    });

    test('are limited to thirty seconds (plus a little slack)', () async {
      final a = await mk('Alice', 1);
      final b = await mk('Bob', 2);
      await connect([(a, b)]);
      await expectLater(a.service.sendMedia('dm:${b.id}', _voice(fakeBytes(500), ms: 60000)),
          _error(MessageErrorKind.invalidMedia));
      await expectLater(a.service.sendMedia('dm:${b.id}', _voice(fakeBytes(500), ms: 0)),
          _error(MessageErrorKind.invalidMedia));
      final ok = await a.service.sendMedia('dm:${b.id}', _voice(fakeBytes(500), ms: 30000));
      expect(ok.kind, MessageKind.voice);
    });
  });

  group('group images and voice', () {
    Future<(MessageNode, MessageNode, MessageNode, String)> trio() async {
      final a = await mk('Alice', 1);
      final b = await mk('Bob', 2);
      final c = await mk('Carol', 3);
      await connect([(a, b), (a, c)]);
      final g = await a.service.groups.create(name: 'Trip', memberIds: [b.id, c.id]);
      await run();
      await b.service.groups.accept(g.id);
      await c.service.groups.accept(g.id);
      return (a, b, c, g.id);
    }

    test('every member receives and verifies it; the sender sees "delivered" only when all have it',
        () async {
      final (a, b, c, gid) = await trio();
      final data = fakeBytes(6500, 9);
      final sent = await a.service.sendMedia('gr:$gid', _image(data, caption: 'the view'));
      await run();

      for (final n in [b, c]) {
        final got = await only(n, 'gr:$gid');
        expect(got.kind, MessageKind.image);
        expect(got.body, 'the view');
        expect(got.senderNickname, 'Alice');
        expect(await storedBytes(n, got), data);
      }
      final mine = (await a.message(sent.id))!;
      expect(mine.receiptCount, 2);
      expect(mine.status, MessageStatus.delivered);
    });

    test('a receipt comes only once the whole file has arrived', () async {
      final (a, b, c, gid) = await trio();
      // Bob receives only part of the file for a while.
      var dropped = 0;
      net.onWire = (from, to, bytes) {
        final p = MeshPacket.decode(bytes);
        if (to == b.id && p.type == PacketType.group && p.isChunk && dropped < 2) {
          dropped++;
          return null;
        }
        return bytes;
      };
      final sent = await a.service.sendMedia('gr:$gid', _image(fakeBytes(6500, 3)));
      await run();
      var mine = (await a.message(sent.id))!;
      expect(mine.receiptCount, 1, reason: 'only Carol has the full file');
      expect(mine.status, MessageStatus.sent);
      expect((await b.mediaRepo.forMessage(sent.id))!.state, MediaState.receiving);

      // Carol, who has everything, is still carrying the pieces Bob lacks; they
      // reach Bob when the radio recovers.
      net.onWire = null;
      await connect([(b, c)]);
      await retryRound(const Duration(minutes: 10));
      mine = (await a.message(sent.id))!;
      expect((await b.mediaRepo.forMessage(sent.id))!.state, MediaState.ready);
      expect(mine.receiptCount, 2);
      expect(mine.status, MessageStatus.delivered);
    });

    test('a non-member relay carries the group image but cannot open it', () async {
      final a = await mk('Alice', 1);
      final r = await mk('Relay', 2);
      final b = await mk('Bob', 3);
      await connect([(a, r), (r, b)]);
      await introduce(b);
      final g = await a.service.groups.create(name: 'Duo', memberIds: [b.id]);
      await run();
      await b.service.groups.accept(g.id);
      final data = fakeBytes(5000, 2);
      await a.service.sendMedia('gr:${g.id}', _image(data));
      await run();
      expect(await storedBytes(b, (await b.repo.getMessages('gr:${g.id}')).single), data);
      expect(await r.repo.getConversation('gr:${g.id}'), isNull);
      expect(r.mediaStore.files, isEmpty);
      final probe = data.sublist(1000, 1032);
      for (final e in await r.node.outbox.all()) {
        expect(_contains(e.packet, probe), isFalse);
      }
    });

    test('another member cannot slip pieces into someone else\'s file', () async {
      final (a, b, c, gid) = await trio();
      // Carol sends Bob garbage chunks that claim to belong to Alice's picture.
      net.onWire = (from, to, bytes) {
        final p = MeshPacket.decode(bytes);
        if (from == a.id && to == b.id && p.type == PacketType.group && p.isChunk) {
          return null; // Bob will not get Alice's own pieces directly
        }
        return bytes;
      };
      final data = fakeBytes(4000, 7);
      final sent = await a.service.sendMedia('gr:$gid', _image(data));
      await run();
      final item = (await b.mediaRepo.forMessage(sent.id))!;

      final cKey = (await c.service.groups.keyring.latest(gid))!;
      final mediaKey = await EncryptionService.groupMediaKey(cKey.key, hexToBytes(item.id));
      final poison = await c.node.crypto.buildChunk(
        type: PacketType.group,
        recipientKey: cKey.groupId,
        mediaId: hexToBytes(item.id),
        index: 0,
        count: item.chunkCount,
        data: fakeBytes(1536, 99),
        key: mediaKey,
        epoch: cKey.epoch,
      );
      b.node.transport.inject(c.id, poison.encode());
      await run();

      expect((await b.repo.securityEvents()).map((e) => e.kind), contains(SecurityEventKind.badMedia));
      expect((await b.mediaRepo.get(item.id))!.receivedChunks, 0);
    });

    test('voice messages work in a group too', () async {
      final (a, b, c, gid) = await trio();
      final audio = fakeBytes(5200, 4);
      await b.service.sendMedia('gr:$gid', _voice(audio, ms: 8000));
      await run();
      final atCarol = await only(c, 'gr:$gid');
      expect(atCarol.kind, MessageKind.voice);
      expect(atCarol.senderNickname, 'Bob');
      expect(await storedBytes(c, atCarol), audio);
      expect(await storedBytes(a, (await a.repo.getMessages('gr:$gid')).single), audio);
    });

    test('a member who left cannot be sent media', () async {
      final (a, b, c, gid) = await trio();
      await c.service.groups.leave(gid);
      await run();
      await expectLater(c.service.sendMedia('gr:$gid', _image(fakeBytes(100))),
          _error(MessageErrorKind.groupNotActive));
    });
  });

  group('public room images and voice', () {
    test('everyone in the room gets the picture, signed by its author', () async {
      final a = await mk('Alice', 1);
      final r = await mk('Relay', 2);
      final b = await mk('Bob', 3);
      await connect([(a, r), (r, b)]);
      final data = fakeBytes(5500, 5);
      await a.service.sendMedia('rm:$_mesh', _image(data, caption: 'hello mesh'));
      await run();
      for (final n in [r, b]) {
        final got = await only(n, 'rm:$_mesh');
        expect(got.kind, MessageKind.image);
        expect(got.senderNickname, 'Alice');
        expect(got.senderId, a.id);
        expect(await storedBytes(n, got), data);
      }
    });

    test('a relay that alters a picture is caught; an honest path still completes it', () async {
      final a = await mk('Alice', 1);
      final bad = await mk('Tamperer', 2);
      final good = await mk('Honest', 3);
      final b = await mk('Bob', 4);
      await connect([(a, bad), (a, good), (bad, b), (good, b)]);
      net.onWire = (from, to, bytes) {
        final p = MeshPacket.decode(bytes);
        if (from == bad.id && to == b.id && p.type == PacketType.room && p.isChunk) {
          return Uint8List.fromList(bytes)..[150] ^= 0xff;
        }
        return bytes;
      };
      final data = fakeBytes(5000, 6);
      final sent = await a.service.sendMedia('rm:$_mesh', _image(data));
      await run();
      expect((await b.repo.securityEvents()).map((e) => e.kind), contains(SecurityEventKind.badSignature));
      final got = (await b.repo.getMessage(sent.id))!;
      expect(await storedBytes(b, got), data, reason: 'the honest path delivered the real pieces');
      expect((await b.mediaRepo.forMessage(sent.id))!.state, MediaState.ready);
    });

    test('with only a tampering path, the picture never completes - it is not accepted wrongly',
        () async {
      final a = await mk('Alice', 1);
      final bad = await mk('Tamperer', 2);
      final b = await mk('Bob', 3);
      await connect([(a, bad), (bad, b)]);
      net.onWire = (from, to, bytes) {
        final p = MeshPacket.decode(bytes);
        if (from == bad.id && to == b.id && p.type == PacketType.room && p.isChunk) {
          return Uint8List.fromList(bytes)..[150] ^= 0xff;
        }
        return bytes;
      };
      final sent = await a.service.sendMedia('rm:$_mesh', _image(fakeBytes(5000, 6)));
      await run();
      final item = (await b.mediaRepo.forMessage(sent.id))!;
      expect(item.state, MediaState.receiving);
      expect(b.mediaStore.files, isEmpty);
    });
    test('a picture for a room we did not join is not kept', () async {
      final a = await mk('Alice', 1);
      final b = await mk('Bob', 2);
      await connect([(a, b)]);
      final room = await a.service.rooms.create(name: 'Cafe');
      await a.service.sendMedia('rm:${room.id}', _image(fakeBytes(2000)));
      await run();
      expect(await b.repo.getConversation('rm:${room.id}'), isNull);
      expect(b.mediaStore.files, isEmpty);
    });

    test('voice in a room', () async {
      final a = await mk('Alice', 1);
      final b = await mk('Bob', 2);
      await connect([(a, b)]);
      final audio = fakeBytes(4000, 1);
      await a.service.sendMedia('rm:$_mesh', _voice(audio));
      await run();
      final got = await only(b, 'rm:$_mesh');
      expect(got.kind, MessageKind.voice);
      expect(await storedBytes(b, got), audio);
    });
  });

  group('limits and housekeeping', () {
    test('chunks without a description are kept only up to a limit', () async {
      final a = await mk('Alice', 1);
      final b = await mk('Bob', 2, config: const MediaConfig(maxHeldChunks: 3));
      await connect([(a, b)]);
      net.onWire = (from, to, bytes) {
        final p = MeshPacket.decode(bytes);
        return (from == a.id && p.type == PacketType.direct && !p.isChunk) ? null : bytes;
      };
      await a.service.sendMedia('dm:${b.id}', _image(fakeBytes(9000, 1))); // 6 chunks
      await run();
      expect(await b.mediaRepo.orphanChunkCount(), 3);
    });

    test('orphan chunks that never find their description are dropped after twelve hours', () async {
      final a = await mk('Alice', 1);
      final b = await mk('Bob', 2);
      await connect([(a, b)]);
      net.onWire = (from, to, bytes) {
        final p = MeshPacket.decode(bytes);
        return (from == a.id && p.type == PacketType.direct && !p.isChunk) ? null : bytes;
      };
      await a.service.sendMedia('dm:${b.id}', _image(fakeBytes(4000, 1)));
      await run();
      expect(await b.mediaRepo.orphanChunkCount(), greaterThan(0));
      clock.advance(const Duration(hours: 13));
      await b.service.maintain();
      expect(await b.mediaRepo.orphanChunkCount(), 0);
    });

    test('the periodic housekeeping removes files nothing refers to', () async {
      final a = await mk('Alice', 1);
      await a.mediaStore.save('${'ab' * 16}.jpg', fakeBytes(10));
      await a.service.maintain();
      expect(a.mediaStore.files, isEmpty, reason: 'no waiting period: nothing refers to it');
    });

    test('deleting a conversation removes its media rows, and the files are swept', () async {
      final a = await mk('Alice', 1);
      final b = await mk('Bob', 2);
      await connect([(a, b)]);
      await a.service.sendMedia('dm:${b.id}', _image(fakeBytes(2000)));
      await run();
      expect(b.mediaStore.files.length, 1);
      await b.repo.deleteConversation('dm:${a.id}');
      await b.service.maintain();
      expect(b.mediaStore.files, isEmpty, reason: 'gone with the chat, with no waiting period');
    });

    test('files nobody refers to are swept at once, files that are in use stay', () async {
      final a = await mk('Alice', 1);
      final b = await mk('Bob', 2);
      await connect([(a, b)]);
      final kept = fakeBytes(1500, 7);
      await a.service.sendMedia('dm:${b.id}', _image(kept));
      await run();
      expect(b.mediaStore.files.length, 1);
      final keptName = b.mediaStore.files.keys.single;

      // A leftover (say, from a crash between writing a file and recording it).
      final leftover = '${'ab' * 16}.m4a';
      await b.mediaStore.save(leftover, fakeBytes(400, 3));
      expect(b.mediaStore.files.keys, containsAll([keptName, leftover]));

      await b.service.media.sweepFiles();

      expect(b.mediaStore.files.keys, [keptName],
          reason: 'the leftover goes immediately, however new it is');
      expect(await b.mediaStore.read(keptName), kept);
    });

    test('a file that is being written is never mistaken for a leftover', () async {
      final gate = Completer<void>();
      final store = _GatedStore(() => gate.future);
      final a = await mk('Alice', 1, store: store);
      final b = await mk('Bob', 2);
      await connect([(a, b)]);
      final bytes = fakeBytes(1800, 11);

      // The file is written, but the row that refers to it is not yet.
      final sending = a.service.sendMedia('dm:${b.id}', _image(bytes));
      for (var i = 0; i < 200 && store.files.isEmpty; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(store.files.length, 1, reason: 'the file is on the "disk"');
      await a.service.media.sweepFiles();
      expect(store.files.length, 1, reason: 'a sweep in that moment must leave it alone');

      gate.complete();
      final message = await sending;
      final item = (await a.mediaOf(message.id))!;
      expect(item.fileName, store.files.keys.single);
      expect(await store.read(item.fileName!), bytes);
      await a.service.media.sweepFiles();
      expect(store.files.length, 1, reason: 'and once recorded it is kept');
    });

    test('a failed write leaves nothing that would block later sweeps', () async {
      final store = _GatedStore(() async => throw StateError('disk full'));
      final a = await mk('Alice', 1, store: store);
      final b = await mk('Bob', 2);
      await connect([(a, b)]);

      await expectLater(a.service.sendMedia('dm:${b.id}', _image(fakeBytes(900))),
          throwsA(isA<StateError>()));
      expect(await a.mediaRepo.referencedFileNames(), isEmpty);
      await a.service.media.sweepFiles();
      expect(store.files, isEmpty, reason: 'the half-done file was removed by the sweep');
    });

    test('a file name can never point outside the media folder', () async {
      final store = MemoryMediaStore();
      for (final bad in ['../x.jpg', 'a/b.jpg', 'x.exe', '', 'ab' * 16, 'AB' * 16 + '.jpg']) {
        await expectLater(store.save(bad, fakeBytes(3)), throwsArgumentError, reason: bad);
      }
      await store.save('${'ab' * 16}.jpg', fakeBytes(3));
      expect(await store.read('${'ab' * 16}.jpg'), fakeBytes(3));
    });
  });
}

/// A media store whose writes finish (on the "disk") and then wait for a signal
/// before returning, so a test can act in the moment between "the file exists"
/// and "its row is recorded".
class _GatedStore extends MemoryMediaStore {
  _GatedStore(this._gate);

  final Future<void> Function() _gate;

  @override
  Future<void> save(String name, Uint8List bytes) async {
    await super.save(name, bytes);
    await _gate();
  }
}
