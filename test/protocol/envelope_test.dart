import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:offline_mesh_chat/protocol/envelope.dart';
import 'package:offline_mesh_chat/protocol/protocol_constants.dart';

Uint8List _bytes(int length, int seed) {
  final rng = Random(seed);
  return Uint8List.fromList(List<int>.generate(length, (_) => 1 + rng.nextInt(255)));
}

MediaEnvelope _image({
  int byteLength = 40000,
  Uint8List? key,
  String caption = '',
  String? nickname,
}) =>
    MediaEnvelope(
      mediaKind: MediaKind.image,
      mediaId: _bytes(16, 1),
      mimeCode: MediaMime.jpeg,
      byteLength: byteLength,
      chunkCount: EnvelopeCodec.chunkCountFor(byteLength),
      sha256: _bytes(32, 2),
      key: key,
      width: 640,
      height: 480,
      caption: caption,
      nickname: nickname,
    );

MediaEnvelope _video({
  int byteLength = 200 * 1024,
  Uint8List? key,
  int width = 320,
  int height = 240,
  int durationMs = 8000,
  String caption = '',
  Uint8List? replyTo,
}) =>
    MediaEnvelope(
      mediaKind: MediaKind.video,
      mediaId: _bytes(16, 6),
      mimeCode: MediaMime.mp4,
      byteLength: byteLength,
      chunkCount: EnvelopeCodec.chunkCountFor(byteLength),
      sha256: _bytes(32, 7),
      key: key,
      width: width,
      height: height,
      durationMs: durationMs,
      caption: caption,
      replyTo: replyTo,
    );

MediaEnvelope _voice({List<int>? waveform, int durationMs = 12000, int byteLength = 24000}) =>
    MediaEnvelope(
      mediaKind: MediaKind.voice,
      mediaId: _bytes(16, 3),
      mimeCode: MediaMime.aacM4a,
      byteLength: byteLength,
      chunkCount: EnvelopeCodec.chunkCountFor(byteLength),
      sha256: _bytes(32, 4),
      durationMs: durationMs,
      waveform: waveform ?? List<int>.generate(48, (i) => i * 5),
    );

GroupSnapshot _snapshot({
  bool isUpdate = false,
  String name = 'Family',
  List<GroupMemberInfo>? members,
  Uint8List? adminKey,
}) {
  final admin = adminKey ?? _bytes(32, 10);
  return GroupSnapshot(
    isUpdate: isUpdate,
    groupId: _bytes(32, 11),
    epoch: 3,
    groupKey: _bytes(32, 12),
    name: name,
    adminKey: admin,
    members: members ??
        [
          GroupMemberInfo(key: admin, nickname: 'Admin'),
          GroupMemberInfo(key: _bytes(32, 13), nickname: 'Sara'),
        ],
  );
}

void main() {
  group('text envelopes', () {
    test('round-trip with and without a nickname', () {
      final withNick = EnvelopeCodec.encode(const TextEnvelope('hello', nickname: 'Ann'), withNickname: true);
      final a = EnvelopeCodec.decode(withNick, withNickname: true) as TextEnvelope;
      expect(a.text, 'hello');
      expect(a.nickname, 'Ann');

      final plain = EnvelopeCodec.encode(const TextEnvelope('hello'), withNickname: false);
      final b = EnvelopeCodec.decode(plain, withNickname: false) as TextEnvelope;
      expect(b.text, 'hello');
      expect(b.nickname, isNull);
    });

    test('the direct text format: 1 | link flags | u16 len | text', () {
      final bytes = EnvelopeCodec.encode(const TextEnvelope('hi'), withNickname: false);
      expect(bytes, [1, 0, 0, 2, 0x68, 0x69]);
    });

    test('unicode survives and the limit is counted in bytes', () {
      const text = '€uro 👋 مرحبا';
      final bytes = EnvelopeCodec.encode(const TextEnvelope(text), withNickname: false);
      expect((EnvelopeCodec.decode(bytes, withNickname: false) as TextEnvelope).text, text);
      expect(() => EnvelopeCodec.encode(TextEnvelope('€' * 334), withNickname: false),
          throwsArgumentError);
      expect(EnvelopeCodec.encode(TextEnvelope('€' * 333), withNickname: false), isNotEmpty);
    });

    test('empty, blank and oversize text are refused', () {
      for (final bad in ['', '   ', '\n\t', 'x' * (Protocol.maxTextBytes + 1)]) {
        expect(() => EnvelopeCodec.encode(TextEnvelope(bad), withNickname: false),
            throwsArgumentError,
            reason: 'text of ${bad.length} chars');
      }
    });

    test('an oversize nickname is refused', () {
      expect(
        () => EnvelopeCodec.encode(TextEnvelope('x', nickname: 'n' * 33), withNickname: true),
        throwsArgumentError,
      );
    });

    test('trailing zero padding is accepted, other trailing bytes are not', () {
      final bytes = EnvelopeCodec.encode(const TextEnvelope('pad me'), withNickname: false);
      final padded = Uint8List(64)..setRange(0, bytes.length, bytes);
      expect((EnvelopeCodec.decode(padded, withNickname: false) as TextEnvelope).text, 'pad me');
      padded[63] = 1;
      expect(() => EnvelopeCodec.decode(padded, withNickname: false),
          throwsA(isA<EnvelopeFormatException>()));
    });
  });

  group('media envelopes', () {
    test('an image manifest round-trips, key included', () {
      final key = _bytes(32, 20);
      final original = _image(key: key, caption: 'sunset', nickname: 'Ann');
      final decoded = EnvelopeCodec.decode(
        EnvelopeCodec.encode(original, withNickname: true),
        withNickname: true,
      ) as MediaEnvelope;
      expect(decoded.mediaKind, MediaKind.image);
      expect(decoded.mediaId, original.mediaId);
      expect(decoded.byteLength, 40000);
      expect(decoded.chunkCount, EnvelopeCodec.chunkCountFor(40000));
      expect(decoded.sha256, original.sha256);
      expect(decoded.key, key);
      expect(decoded.width, 640);
      expect(decoded.height, 480);
      expect(decoded.caption, 'sunset');
      expect(decoded.nickname, 'Ann');
    });

    test('a voice manifest keeps its duration and waveform', () {
      final original = _voice();
      final decoded = EnvelopeCodec.decode(
        EnvelopeCodec.encode(original, withNickname: false),
        withNickname: false,
      ) as MediaEnvelope;
      expect(decoded.mediaKind, MediaKind.voice);
      expect(decoded.durationMs, 12000);
      expect(decoded.waveform, original.waveform);
      expect(decoded.key, isNull);
    });

    test('chunk count must match the byte length', () {
      final bad = MediaEnvelope(
        mediaKind: MediaKind.image,
        mediaId: _bytes(16, 1),
        mimeCode: MediaMime.jpeg,
        byteLength: 40000,
        chunkCount: 3,
        sha256: _bytes(32, 2),
      );
      expect(() => EnvelopeCodec.encode(bad, withNickname: false),
          throwsA(isA<EnvelopeFormatException>()));
    });

    test('size, type and dimension limits are enforced', () {
      expect(
        () => EnvelopeCodec.encode(_image(byteLength: Protocol.maxMediaBytes + 1), withNickname: false),
        throwsA(isA<EnvelopeFormatException>()),
      );
      expect(
        () => EnvelopeCodec.encode(_image(byteLength: 0), withNickname: false),
        throwsA(isA<EnvelopeFormatException>()),
      );
      final wrongMime = MediaEnvelope(
        mediaKind: MediaKind.voice,
        mediaId: _bytes(16, 1),
        mimeCode: MediaMime.jpeg,
        byteLength: 1000,
        chunkCount: 1,
        sha256: _bytes(32, 2),
      );
      expect(() => EnvelopeCodec.encode(wrongMime, withNickname: false),
          throwsA(isA<EnvelopeFormatException>()));
      expect(
        () => EnvelopeCodec.encode(_voice(durationMs: 120000), withNickname: false),
        throwsA(isA<EnvelopeFormatException>()),
      );
    });

    test('the largest allowed object needs exactly maxMediaChunks chunks', () {
      expect(EnvelopeCodec.chunkCountFor(Protocol.maxMediaBytes), lessThanOrEqualTo(Protocol.maxMediaChunks));
      expect(EnvelopeCodec.chunkCountFor(1), 1);
      expect(EnvelopeCodec.chunkCountFor(Protocol.mediaChunkBytes), 1);
      expect(EnvelopeCodec.chunkCountFor(Protocol.mediaChunkBytes + 1), 2);
    });

    test('a forged manifest with an absurd chunk count is rejected on decode', () {
      final bytes = EnvelopeCodec.encode(_image(), withNickname: false);
      // kind(1) + mediaId(16) + mime(1) + byteLength(4) => chunkCount at offset 22.
      final forged = Uint8List.fromList(bytes)
        ..[22] = 0xff
        ..[23] = 0xff;
      expect(() => EnvelopeCodec.decode(forged, withNickname: false),
          throwsA(isA<EnvelopeFormatException>()));
    });
  });

  group('group envelopes', () {
    test('an invitation round-trips', () {
      final s = _snapshot();
      final d = EnvelopeCodec.decode(EnvelopeCodec.encode(s, withNickname: false), withNickname: false)
          as GroupSnapshot;
      expect(d.isUpdate, isFalse);
      expect(d.groupId, s.groupId);
      expect(d.epoch, 3);
      expect(d.groupKey, s.groupKey);
      expect(d.name, 'Family');
      expect(d.adminKey, s.adminKey);
      expect(d.members.map((m) => m.nickname), ['Admin', 'Sara']);
      expect(d.members.first.key, s.adminKey);
    });

    test('an update keeps its kind', () {
      final d = EnvelopeCodec.decode(
        EnvelopeCodec.encode(_snapshot(isUpdate: true), withNickname: false),
        withNickname: false,
      ) as GroupSnapshot;
      expect(d.isUpdate, isTrue);
      expect(d.kind, ContentKind.groupUpdate);
    });

    test('removed and leave notices round-trip', () {
      final id = _bytes(32, 30);
      final removed = EnvelopeCodec.decode(
        EnvelopeCodec.encode(GroupRemovedEnvelope(id), withNickname: false),
        withNickname: false,
      );
      expect(removed, isA<GroupRemovedEnvelope>());
      expect((removed as GroupRemovedEnvelope).groupId, id);
      final left = EnvelopeCodec.decode(
        EnvelopeCodec.encode(GroupLeaveEnvelope(id), withNickname: false),
        withNickname: false,
      );
      expect(left, isA<GroupLeaveEnvelope>());
    });

    test('the admin must be a member', () {
      final admin = _bytes(32, 10);
      final s = _snapshot(
        adminKey: admin,
        members: [GroupMemberInfo(key: _bytes(32, 40), nickname: 'Other')],
      );
      expect(() => EnvelopeCodec.encode(s, withNickname: false),
          throwsA(isA<EnvelopeFormatException>()));
    });

    test('duplicate members, empty names and too many members are rejected', () {
      final admin = _bytes(32, 10);
      expect(
        () => EnvelopeCodec.encode(
          _snapshot(adminKey: admin, members: [
            GroupMemberInfo(key: admin, nickname: 'A'),
            GroupMemberInfo(key: admin, nickname: 'B'),
          ]),
          withNickname: false,
        ),
        throwsA(isA<EnvelopeFormatException>()),
      );
      expect(() => EnvelopeCodec.encode(_snapshot(name: '  '), withNickname: false),
          throwsA(isA<EnvelopeFormatException>()));
      expect(
        () => EnvelopeCodec.encode(
          _snapshot(adminKey: admin, members: [
            GroupMemberInfo(key: admin, nickname: 'A'),
            for (var i = 0; i < Protocol.maxGroupMembers; i++)
              GroupMemberInfo(key: _bytes(32, 100 + i), nickname: 'm$i'),
          ]),
          withNickname: false,
        ),
        throwsA(isA<EnvelopeFormatException>()),
      );
    });

    test('an all-zero group key is rejected', () {
      final admin = _bytes(32, 10);
      final bad = GroupSnapshot(
        isUpdate: false,
        groupId: _bytes(32, 11),
        epoch: 0,
        groupKey: Uint8List(32),
        name: 'x',
        adminKey: admin,
        members: [GroupMemberInfo(key: admin, nickname: 'A')],
      );
      expect(() => EnvelopeCodec.encode(bad, withNickname: false),
          throwsA(isA<EnvelopeFormatException>()));
    });
  });

  group('video envelopes', () {
    test('a video manifest round-trips, key and caption included', () {
      final e = _video(key: _bytes(32, 8), caption: 'the lake', replyTo: _bytes(16, 9));
      final back = EnvelopeCodec.decode(EnvelopeCodec.encode(e, withNickname: false), withNickname: false)
          as MediaEnvelope;
      expect(back.mediaKind, MediaKind.video);
      expect(back.kind, ContentKind.video);
      expect([back.byteLength, back.chunkCount, back.width, back.height, back.durationMs],
          [200 * 1024, e.chunkCount, 320, 240, 8000]);
      expect([back.mimeCode, back.caption, back.replyTo, back.key], [MediaMime.mp4, 'the lake', e.replyTo, e.key]);
      expect(back.waveform, isEmpty);
      expect(MediaMime.extension(MediaMime.mp4), 'mp4');
    });

    test('the documented layout: width, height, then the duration as u32', () {
      final e = _video(width: 0x0102, height: 0x0304, durationMs: 0x00050607);
      final bytes = EnvelopeCodec.encode(e, withNickname: false);
      // kind | links | id(16) mime u32 len u16 chunks sha(32) hasKey | w h dur | caption len
      final afterHasKey = 1 + 1 + 16 + 1 + 4 + 2 + 32 + 1;
      expect(bytes.sublist(afterHasKey, afterHasKey + 8), [1, 2, 3, 4, 0, 5, 6, 7]);
      expect(bytes[0], 4, reason: 'content kind 4 is a video');
    });

    test('a video may be up to 512 KB, a picture or voice message still only 64 KB', () {
      expect(Protocol.maxVideoBytes, 512 * 1024);
      final biggest = _video(byteLength: Protocol.maxVideoBytes);
      expect(biggest.chunkCount, lessThanOrEqualTo(Protocol.maxMediaChunks));
      expect(EnvelopeCodec.decode(EnvelopeCodec.encode(biggest, withNickname: false), withNickname: false),
          isA<MediaEnvelope>());
      expect(() => EnvelopeCodec.encode(_video(byteLength: Protocol.maxVideoBytes + 1), withNickname: false),
          throwsA(anyOf(isA<EnvelopeFormatException>(), isA<ArgumentError>())));
      expect(() => EnvelopeCodec.encode(_image(byteLength: Protocol.maxMediaBytes + 1), withNickname: false),
          throwsA(anyOf(isA<EnvelopeFormatException>(), isA<ArgumentError>())),
          reason: 'the bigger cap is for videos only');
    });

    test('a video needs the video type, and nothing else may claim it', () {
      expect(MediaMime.valid(MediaKind.video, MediaMime.mp4), isTrue);
      expect(MediaMime.valid(MediaKind.video, MediaMime.jpeg), isFalse);
      expect(MediaMime.valid(MediaKind.image, MediaMime.mp4), isFalse);
      expect(MediaMime.valid(MediaKind.voice, MediaMime.mp4), isFalse);
    });

    test('absurd dimensions, durations and chunk counts are refused', () {
      for (final bad in [
        _video(width: 9000),
        _video(height: 9000),
        _video(durationMs: const Duration(hours: 2).inMilliseconds),
      ]) {
        expect(() => EnvelopeCodec.encode(bad, withNickname: false),
            throwsA(anyOf(isA<EnvelopeFormatException>(), isA<ArgumentError>())));
      }
      // A manifest that says a different number of chunks than its size needs.
      final good = EnvelopeCodec.encode(_video(), withNickname: false);
      final forged = Uint8List.fromList(good);
      final chunkCountAt = 1 + 1 + 16 + 1 + 4; // u16 right after the byte length
      forged[chunkCountAt] = 0xff;
      forged[chunkCountAt + 1] = 0xff;
      expect(() => EnvelopeCodec.decode(forged, withNickname: false), throwsA(isA<EnvelopeFormatException>()));
    });

    test('cutting a video manifest short anywhere is only ever a format error', () {
      final full = EnvelopeCodec.encode(_video(key: _bytes(32, 5), caption: 'x'), withNickname: false);
      for (var cut = 0; cut < full.length; cut++) {
        try {
          EnvelopeCodec.decode(Uint8List.fromList(full.sublist(0, cut)), withNickname: false);
        } on EnvelopeFormatException {
          // expected
        }
      }
    });
  });

  group('reply and forward links', () {
    final target = _bytes(16, 21);

    test('a reply carries only the id of the message it answers', () {
      final bytes = EnvelopeCodec.encode(TextEnvelope('hi', replyTo: target), withNickname: false);
      expect(bytes, [1, 1, ...target, 0, 2, 0x68, 0x69]);
      final back = EnvelopeCodec.decode(bytes, withNickname: false) as TextEnvelope;
      expect([back.text, back.replyTo, back.forwardedFrom], ['hi', target, null]);
    });

    test('a forward carries the name of the first author', () {
      final bytes =
          EnvelopeCodec.encode(const TextEnvelope('hi', forwardedFrom: 'Bob'), withNickname: false);
      expect(bytes, [1, 2, 3, 0x42, 0x6f, 0x62, 0, 2, 0x68, 0x69]);
      final back = EnvelopeCodec.decode(bytes, withNickname: false) as TextEnvelope;
      expect([back.replyTo, back.forwardedFrom], [null, 'Bob']);
    });

    test('both together, with a nickname, in group and room messages', () {
      final e = TextEnvelope('both', nickname: 'Ann', replyTo: target, forwardedFrom: 'Zoë');
      final back = EnvelopeCodec.decode(EnvelopeCodec.encode(e, withNickname: true),
          withNickname: true) as TextEnvelope;
      expect([back.text, back.nickname, back.replyTo, back.forwardedFrom],
          ['both', 'Ann', target, 'Zoë']);
    });

    test('pictures and voice messages carry them too', () {
      final image = MediaEnvelope(
        mediaKind: MediaKind.image,
        mediaId: _bytes(16, 1),
        mimeCode: MediaMime.jpeg,
        byteLength: 3000,
        chunkCount: EnvelopeCodec.chunkCountFor(3000),
        sha256: _bytes(32, 2),
        width: 10,
        height: 10,
        caption: 'look',
        replyTo: target,
        forwardedFrom: 'Bob',
      );
      final back = EnvelopeCodec.decode(EnvelopeCodec.encode(image, withNickname: false),
          withNickname: false) as MediaEnvelope;
      expect([back.replyTo, back.forwardedFrom, back.caption], [target, 'Bob', 'look']);
    });

    test('an id of the wrong length, an empty or oversize name is refused', () {
      expect(() => EnvelopeCodec.encode(TextEnvelope('x', replyTo: _bytes(15, 1)), withNickname: false),
          throwsArgumentError);
      expect(() => EnvelopeCodec.encode(const TextEnvelope('x', forwardedFrom: ''), withNickname: false),
          throwsArgumentError);
      expect(
          () => EnvelopeCodec.encode(TextEnvelope('x', forwardedFrom: 'n' * 33), withNickname: false),
          throwsArgumentError);
    });

    test('unknown flags, an empty name and a cut-off id are malformed', () {
      for (final bad in [
        [1, 4, 0, 1, 0x78], // a flag nobody defined
        [1, 2, 0, 0, 1, 0x78], // forwarded, but with no name
        [1, 1, 1, 2, 3], // reply, but the id stops short
      ]) {
        expect(() => EnvelopeCodec.decode(Uint8List.fromList(bad), withNickname: false),
            throwsA(isA<EnvelopeFormatException>()),
            reason: '$bad');
      }
    });
  });

  group('edit envelopes', () {
    final target = _bytes(16, 31);

    test('round-trip, in the documented layout', () {
      final bytes = EnvelopeCodec.encode(
          EditEnvelope(targetId: target, version: 0x0102030405, text: 'hi'),
          withNickname: false);
      expect(bytes, [20, ...target, 0, 0, 0, 1, 2, 3, 4, 5, 0, 2, 0x68, 0x69]);
      final back = EnvelopeCodec.decode(bytes, withNickname: false) as EditEnvelope;
      expect([back.targetId, back.version, back.text], [target, 0x0102030405, 'hi']);
      expect(back.targetHex, hasLength(32));
    });

    test('unicode survives and the text limit is counted in bytes', () {
      final e = EditEnvelope(targetId: target, version: 5, text: '€uro 👋');
      final back =
          EnvelopeCodec.decode(EnvelopeCodec.encode(e, withNickname: false), withNickname: false)
              as EditEnvelope;
      expect(back.text, '€uro 👋');
      expect(
          () => EnvelopeCodec.encode(
              EditEnvelope(targetId: target, version: 5, text: 'x' * (Protocol.maxTextBytes + 1)),
              withNickname: false),
          throwsArgumentError);
    });

    test('an empty text, a non-positive version and a wrong id length are refused', () {
      for (final bad in [
        EditEnvelope(targetId: target, version: 5, text: '  '),
        EditEnvelope(targetId: target, version: 0, text: 'x'),
        EditEnvelope(targetId: target, version: -3, text: 'x'),
        EditEnvelope(targetId: _bytes(8, 1), version: 5, text: 'x'),
      ]) {
        expect(() => EnvelopeCodec.encode(bad, withNickname: false), throwsArgumentError);
      }
    });

    test('malformed edits on the wire are rejected', () {
      Uint8List edit({int version = 5, String text = 'x', int? declaredLength}) {
        final t = text.codeUnits;
        return Uint8List.fromList([
          20,
          ...target,
          ...List<int>.generate(8, (i) => i == 7 ? version : 0),
          0,
          declaredLength ?? t.length,
          ...t,
        ]);
      }

      expect(EnvelopeCodec.decode(edit(), withNickname: false), isA<EditEnvelope>());
      expect(() => EnvelopeCodec.decode(edit(version: 0), withNickname: false),
          throwsA(isA<EnvelopeFormatException>()));
      expect(() => EnvelopeCodec.decode(edit(text: ''), withNickname: false),
          throwsA(isA<EnvelopeFormatException>()));
      expect(() => EnvelopeCodec.decode(edit(text: '  '), withNickname: false),
          throwsA(isA<EnvelopeFormatException>()));
      expect(() => EnvelopeCodec.decode(edit(declaredLength: 9), withNickname: false),
          throwsA(isA<EnvelopeFormatException>()),
          reason: 'it says more text than there is');
    });
  });

  group('delete envelopes', () {
    List<Uint8List> ids(int n) => [for (var i = 0; i < n; i++) _bytes(16, 100 + i)];

    test('round-trip of one message and of the largest batch', () {
      for (final n in [1, 2, Protocol.maxDeleteBatch]) {
        final e = DeleteEnvelope(ids(n));
        final bytes = EnvelopeCodec.encode(e, withNickname: false);
        expect(bytes.length, 2 + 16 * n);
        expect(bytes.sublist(0, 2), [21, n]);
        final back = EnvelopeCodec.decode(bytes, withNickname: false) as DeleteEnvelope;
        expect(back.targets, e.targets, reason: '$n ids');
        expect(back.targetsHex, hasLength(n));
      }
    });

    test('no ids, too many ids and an id of the wrong length are refused', () {
      expect(() => EnvelopeCodec.encode(DeleteEnvelope(const []), withNickname: false),
          throwsArgumentError);
      expect(
          () => EnvelopeCodec.encode(DeleteEnvelope(ids(Protocol.maxDeleteBatch + 1)),
              withNickname: false),
          throwsArgumentError);
      expect(() => EnvelopeCodec.encode(DeleteEnvelope([_bytes(15, 1)]), withNickname: false),
          throwsArgumentError);
    });

    test('malformed deletes on the wire are rejected', () {
      for (final bad in [
        [21, 0],
        [21, Protocol.maxDeleteBatch + 1, ...List<int>.filled(16 * (Protocol.maxDeleteBatch + 1), 1)],
        [21, 2, ...List<int>.filled(16, 1)], // says two, carries one
        [21],
      ]) {
        expect(() => EnvelopeCodec.decode(Uint8List.fromList(bad), withNickname: false),
            throwsA(isA<EnvelopeFormatException>()));
      }
      final withJunk = Uint8List.fromList([...EnvelopeCodec.encode(DeleteEnvelope(ids(1)), withNickname: false), 7]);
      expect(() => EnvelopeCodec.decode(withJunk, withNickname: false),
          throwsA(isA<EnvelopeFormatException>()),
          reason: 'only zero padding may follow');
    });
  });

  group('hostile input', () {
    test('truncating a valid envelope anywhere never throws anything but a format error', () {
      final samples = [
        EnvelopeCodec.encode(const TextEnvelope('hello', nickname: 'A'), withNickname: true),
        EnvelopeCodec.encode(_image(key: _bytes(32, 5)), withNickname: false),
        EnvelopeCodec.encode(_voice(), withNickname: false),
        EnvelopeCodec.encode(_snapshot(), withNickname: false),
        EnvelopeCodec.encode(
            TextEnvelope('re', nickname: 'A', replyTo: _bytes(16, 7), forwardedFrom: 'Bob'),
            withNickname: true),
        EnvelopeCodec.encode(EditEnvelope(targetId: _bytes(16, 8), version: 9, text: 'edit'),
            withNickname: false),
        EnvelopeCodec.encode(DeleteEnvelope([_bytes(16, 9), _bytes(16, 10)]), withNickname: false),
      ];
      for (final full in samples) {
        for (var cut = 0; cut < full.length; cut++) {
          final truncated = Uint8List.sublistView(full, 0, cut);
          for (final withNick in [true, false]) {
            try {
              EnvelopeCodec.decode(Uint8List.fromList(truncated), withNickname: withNick);
            } on EnvelopeFormatException {
              // expected for most cuts
            }
          }
        }
      }
    });

    test('random garbage never throws anything but a format error', () {
      final rng = Random(99);
      for (var i = 0; i < 400; i++) {
        final junk = Uint8List.fromList(List<int>.generate(rng.nextInt(120), (_) => rng.nextInt(256)));
        for (final withNick in [true, false]) {
          try {
            EnvelopeCodec.decode(junk, withNickname: withNick);
          } on EnvelopeFormatException {
            // fine
          }
        }
      }
    });

    test('unknown content kinds and invalid UTF-8 are rejected', () {
      expect(() => EnvelopeCodec.decode(Uint8List.fromList([99, 0, 0]), withNickname: false),
          throwsA(isA<EnvelopeFormatException>()));
      expect(
        () => EnvelopeCodec.decode(Uint8List.fromList([1, 0, 2, 0xff, 0xfe]), withNickname: false),
        throwsA(isA<EnvelopeFormatException>()),
      );
    });
  });
}
