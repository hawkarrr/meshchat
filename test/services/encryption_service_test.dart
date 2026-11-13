import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:offline_mesh_chat/core/bytes.dart';
import 'package:offline_mesh_chat/crypto/key_store.dart';
import 'package:offline_mesh_chat/crypto/signatures.dart';
import 'package:offline_mesh_chat/protocol/mesh_packet.dart';
import 'package:offline_mesh_chat/protocol/protocol_constants.dart';
import 'package:offline_mesh_chat/services/encryption_service.dart';

import '../support/fake_clock.dart';

Future<EncryptionService> _newService(int seed, {FakeClock? clock}) =>
    EncryptionService.loadOrCreate(MemoryKeyStore(),
        random: Random(seed), clock: clock ?? FakeClock());

MeshPacket _replace(
  MeshPacket p, {
  Uint8List? senderKey,
  Uint8List? recipientKey,
  Uint8List? payload,
  int? expiresAtMs,
  Uint8List? signature,
}) =>
    MeshPacket(
      type: p.type,
      flags: p.flags,
      hopLimit: p.hopLimit,
      hops: p.hops,
      messageId: p.messageId,
      timestampMs: p.timestampMs,
      expiresAtMs: expiresAtMs ?? p.expiresAtMs,
      senderKey: senderKey ?? p.senderKey,
      recipientKey: recipientKey ?? p.recipientKey,
      payload: payload ?? p.payload,
      signature: signature ?? p.signature,
    );

void main() {
  late EncryptionService alice;
  late EncryptionService bob;
  late EncryptionService mallory;

  setUp(() async {
    alice = await _newService(1);
    bob = await _newService(2);
    mallory = await _newService(3);
  });

  Future<MeshPacket> aliceToBob(String text) => alice.buildDirect(
        recipientSigningKey: bob.identity.signingPublicKey,
        recipientAgreementKey: bob.identity.agreementPublicKey,
        text: text,
      );

  group('identity persistence', () {
    test('first load creates and stores keys, second load reuses them', () async {
      final store = MemoryKeyStore();
      final first = await EncryptionService.loadOrCreate(store);
      expect(first.createdNewIdentity, isTrue);
      expect(store.snapshot.keys, containsAll(['identity.signing.seed', 'identity.agreement.seed']));

      final second = await EncryptionService.loadOrCreate(store);
      expect(second.createdNewIdentity, isFalse);
      expect(second.identity.signingPublicKey, first.identity.signingPublicKey);
      expect(second.identity.agreementPublicKey, first.identity.agreementPublicKey);
    });

    test('a corrupt seed produces a fresh identity instead of crashing', () async {
      final store = MemoryKeyStore();
      final first = await EncryptionService.loadOrCreate(store);
      await store.write('identity.signing.seed', Uint8List(5));
      final second = await EncryptionService.loadOrCreate(store);
      expect(second.createdNewIdentity, isTrue);
      expect(second.identity.signingPublicKey, isNot(first.identity.signingPublicKey));
    });

    test('signing and agreement keys are independent and well-formed', () {
      expect(alice.identity.signingPublicKey.length, 32);
      expect(alice.identity.agreementPublicKey.length, 32);
      expect(alice.identity.signingPublicKey, isNot(alice.identity.agreementPublicKey));
      expect(alice.identity.id, bytesToHex(alice.identity.signingPublicKey));
    });

    test('identities from different random sources differ', () {
      expect(alice.identity.signingPublicKey, isNot(bob.identity.signingPublicKey));
    });

    test('deleteStoredIdentity removes the seeds', () async {
      final store = MemoryKeyStore();
      await EncryptionService.loadOrCreate(store);
      await EncryptionService.deleteStoredIdentity(store);
      expect(store.snapshot, isEmpty);
    });
  });

  group('direct messages', () {
    test('Bob decrypts what Alice sent, and the signature verifies', () async {
      final p = await aliceToBob('hello bob 👋');
      expect(await verifyPacketSignature(p), isTrue);
      expect((await bob.openDirect(p)).text, 'hello bob 👋');
    });

    test('survives serialisation through the wire format', () async {
      final p = await aliceToBob('over the wire');
      final decoded = MeshPacket.decode(p.encode());
      expect(await verifyPacketSignature(decoded), isTrue);
      expect((await bob.openDirect(decoded)).text, 'over the wire');
    });

    test('a relay can forward it (hops change) without breaking verification', () async {
      final p = (await aliceToBob('relayed')).relayed().relayed();
      expect(await verifyPacketSignature(p), isTrue);
      expect((await bob.openDirect(p)).text, 'relayed');
    });

    test('a relay cannot read it, and the plaintext is not in the packet', () async {
      final secret = 'the-eagle-lands-at-midnight';
      final p = await aliceToBob(secret);
      await expectLater(mallory.openDirect(p), throwsA(isA<DecryptionFailure>()));
      expect(utf8.decode(p.encode(), allowMalformed: true), isNot(contains(secret)));
      expect(bytesToHex(p.encode()), isNot(contains(bytesToHex(utf8.encode(secret)))));
    });

    test('Alice cannot open her own outgoing message', () async {
      final p = await aliceToBob('x');
      await expectLater(
        alice.openDirect(p),
        throwsA(isA<DecryptionFailure>()
            .having((e) => e.reason, 'reason', DecryptionFailureReason.notForUs)),
      );
    });

    test('flipping any payload bit is detected by the signature AND the AEAD', () async {
      final p = await aliceToBob('integrity matters');
      final rng = Random(5);
      for (var i = 0; i < 40; i++) {
        final payload = Uint8List.fromList(p.payload);
        payload[rng.nextInt(payload.length)] ^= 1 << rng.nextInt(8);
        final tampered = _replace(p, payload: payload);
        expect(await verifyPacketSignature(tampered), isFalse);
        await expectLater(bob.openDirect(tampered), throwsA(isA<DecryptionFailure>()));
      }
    });

    test('changing the expiry invalidates the signature', () async {
      final p = await aliceToBob('hello');
      final extended = _replace(p, expiresAtMs: p.expiresAtMs + 100000000);
      expect(await verifyPacketSignature(extended), isFalse);
    });

    test('re-addressing to another recipient is rejected', () async {
      final p = await aliceToBob('for bob only');
      final readdressed = _replace(p, recipientKey: mallory.identity.signingPublicKey);
      expect(await verifyPacketSignature(readdressed), isFalse);
      await expectLater(mallory.openDirect(readdressed), throwsA(isA<DecryptionFailure>()));
    });

    test('Mallory cannot pass off Alice\'s ciphertext as her own (sender binding)', () async {
      // Mallory takes Alice's valid ciphertext, claims it as hers, and signs the
      // result with her own key. The signature is valid - but the AEAD binds the
      // sender key, so Bob's decryption must fail.
      final p = await aliceToBob('I am alice');
      final relabelled = MeshPacket.buildSigningBytes(
        type: p.type,
        hopLimit: p.hopLimit,
        messageId: p.messageId,
        timestampMs: p.timestampMs,
        expiresAtMs: p.expiresAtMs,
        senderKey: mallory.identity.signingPublicKey,
        recipientKey: p.recipientKey,
        payload: p.payload,
      );
      final forged = _replace(
        p,
        senderKey: mallory.identity.signingPublicKey,
        signature: await mallory.sign(relabelled),
      );
      expect(await verifyPacketSignature(forged), isTrue);
      await expectLater(
        bob.openDirect(forged),
        throwsA(isA<DecryptionFailure>().having(
            (e) => e.reason, 'reason', DecryptionFailureReason.authenticationFailed)),
      );
    });

    test('a replay is detectable: identical packets share a message id', () async {
      final p = await aliceToBob('once');
      final copy = MeshPacket.decode(p.encode());
      expect(copy.messageIdHex, p.messageIdHex);
    });

    test('message ids and ciphertexts are unique per message', () async {
      final a = await aliceToBob('same text');
      final b = await aliceToBob('same text');
      expect(a.messageIdHex, isNot(b.messageIdHex));
      expect(a.payload, isNot(b.payload));
    });

    test('padding hides small length differences but not large ones', () async {
      final short = await aliceToBob('a');
      final sixty = await aliceToBob('b' * 60);
      final long = await aliceToBob('c' * 200);
      expect(short.payload.length, sixty.payload.length);
      expect(long.payload.length, greaterThan(short.payload.length));
    });

    test('sets lifetimes and hop limit from the protocol constants', () async {
      final clock = FakeClock(5000);
      final a = await _newService(1, clock: clock);
      final p = await a.buildDirect(
        recipientSigningKey: bob.identity.signingPublicKey,
        recipientAgreementKey: bob.identity.agreementPublicKey,
        text: 'hi',
      );
      expect(p.timestampMs, 5000);
      expect(p.expiresAtMs, 5000 + Protocol.directMessageTtl.inMilliseconds);
      expect(p.hopLimit, Protocol.directHopLimit);
      expect(p.hops, 0);
    });

    test('enforces the text limits (in bytes, not characters)', () async {
      await expectLater(aliceToBob(''), throwsArgumentError);
      await expectLater(aliceToBob('   '), throwsArgumentError);
      expect(await aliceToBob('x' * Protocol.maxTextBytes), isA<MeshPacket>());
      await expectLater(aliceToBob('x' * (Protocol.maxTextBytes + 1)), throwsArgumentError);
      // 334 three-byte characters = 1002 bytes.
      await expectLater(aliceToBob('€' * 334), throwsArgumentError);
      final fits = await aliceToBob('€' * 333);
      expect((await bob.openDirect(fits)).text, '€' * 333);
    });

    test('a maximum-size message still fits in a packet', () async {
      final p = await aliceToBob('x' * Protocol.maxTextBytes);
      expect(p.encode().length, lessThanOrEqualTo(Protocol.maxPacketBytes));
    });

    test('refuses to message yourself and invalid keys', () async {
      await expectLater(
        alice.buildDirect(
          recipientSigningKey: alice.identity.signingPublicKey,
          recipientAgreementKey: alice.identity.agreementPublicKey,
          text: 'me',
        ),
        throwsArgumentError,
      );
      await expectLater(
        alice.buildDirect(
          recipientSigningKey: Uint8List(32),
          recipientAgreementKey: bob.identity.agreementPublicKey,
          text: 'x',
        ),
        throwsArgumentError,
      );
      await expectLater(
        alice.buildDirect(
          recipientSigningKey: bob.identity.signingPublicKey,
          recipientAgreementKey: Uint8List(5),
          text: 'x',
        ),
        throwsArgumentError,
      );
    });

    test('rejects malformed payloads cleanly', () async {
      final p = await aliceToBob('hello');
      for (final bad in [Uint8List(0), Uint8List(10), Uint8List(60)]) {
        await expectLater(
          bob.openDirect(_replace(p, payload: bad)),
          throwsA(isA<DecryptionFailure>()),
        );
      }
    });

    test('wrong packet type is refused', () async {
      final ack = await bob.buildAck(
        recipientSigningKey: alice.identity.signingPublicKey,
        ackedMessageIds: [Uint8List(16)],
      );
      await expectLater(alice.openDirect(ack), throwsA(isA<DecryptionFailure>()));
    });
  });

  group('announcements', () {
    test('carry a verifiable binding of agreement key and nickname', () async {
      final p = await alice.buildAnnounce(nickname: 'Alice');
      expect(await verifyPacketSignature(p), isTrue);
      expect(p.isBroadcast, isTrue);
      final c = EncryptionService.parseAnnounce(p);
      expect(c.nickname, 'Alice');
      expect(c.agreementKey, alice.identity.agreementPublicKey);
    });

    test('a swapped agreement key (key-substitution attempt) breaks the signature', () async {
      final p = await alice.buildAnnounce(nickname: 'Alice');
      final payload = Uint8List.fromList(p.payload)
        ..setRange(0, 32, mallory.identity.agreementPublicKey);
      expect(await verifyPacketSignature(_replace(p, payload: payload)), isFalse);
    });

    test('nickname limits and malformed payloads', () async {
      await expectLater(alice.buildAnnounce(nickname: 'x' * 33), throwsArgumentError);
      final p = await alice.buildAnnounce(nickname: 'Al');
      expect(
        () => EncryptionService.parseAnnounce(_replace(p, payload: Uint8List(10))),
        throwsA(isA<DecryptionFailure>()),
      );
      final badUtf8 = Uint8List.fromList(p.payload)..[33] = 1;
      badUtf8[34] = 0xff;
      expect(
        () => EncryptionService.parseAnnounce(
            _replace(p, payload: badUtf8.sublist(0, 35))),
        throwsA(isA<DecryptionFailure>()),
      );
    });

    test('are short-lived and limited to a few hops', () async {
      final p = await alice.buildAnnounce(nickname: 'A');
      expect(p.expiresAtMs - p.timestampMs, Protocol.announceTtl.inMilliseconds);
      expect(p.hopLimit, Protocol.announceHopLimit);
    });
  });

  group('acknowledgements', () {
    test('are signed, addressed to the sender, and reference the message id', () async {
      final msg = await aliceToBob('hi');
      final ack = await bob.buildAck(
        recipientSigningKey: alice.identity.signingPublicKey,
        ackedMessageIds: [msg.messageId],
      );
      expect(await verifyPacketSignature(ack), isTrue);
      expect(ack.senderKey, bob.identity.signingPublicKey);
      expect(ack.recipientKey, alice.identity.signingPublicKey);
      final c = EncryptionService.parseAck(ack);
      expect(c.status, AckContent.delivered);
      expect(c.ackedMessageIds.single, msg.messageId);
    });

    test('one receipt can confirm up to sixteen messages', () async {
      final ids = [for (var i = 0; i < AckContent.maxIds; i++) alice.randomBytes(16)];
      final ack = await bob.buildAck(
        recipientSigningKey: alice.identity.signingPublicKey,
        ackedMessageIds: ids,
      );
      expect(await verifyPacketSignature(ack), isTrue);
      final parsed = EncryptionService.parseAck(MeshPacket.decode(ack.encode()));
      expect(parsed.ackedMessageIds, ids);
      await expectLater(
        bob.buildAck(
          recipientSigningKey: alice.identity.signingPublicKey,
          ackedMessageIds: [...ids, alice.randomBytes(16)],
        ),
        throwsArgumentError,
      );
      await expectLater(
        bob.buildAck(recipientSigningKey: alice.identity.signingPublicKey, ackedMessageIds: []),
        throwsArgumentError,
      );
    });

    test('an ack whose count disagrees with its length is rejected', () async {
      final ack = await bob.buildAck(
        recipientSigningKey: alice.identity.signingPublicKey,
        ackedMessageIds: [alice.randomBytes(16), alice.randomBytes(16)],
      );
      final shortened = Uint8List.fromList(ack.payload)..[1] = 3;
      expect(() => EncryptionService.parseAck(_replace(ack, payload: shortened)),
          throwsA(isA<DecryptionFailure>()));
      final zero = Uint8List.fromList(ack.payload)..[1] = 0;
      expect(() => EncryptionService.parseAck(_replace(ack, payload: zero)),
          throwsA(isA<DecryptionFailure>()));
    });

    test('malformed ack payloads are rejected', () async {
      final ack = await bob.buildAck(
        recipientSigningKey: alice.identity.signingPublicKey,
        ackedMessageIds: [Uint8List(16)],
      );
      expect(() => EncryptionService.parseAck(_replace(ack, payload: Uint8List(3))),
          throwsA(isA<DecryptionFailure>()));
    });
  });

  group('direct envelopes (media manifests and group invitations)', () {
    MediaEnvelope manifest(Uint8List key) => MediaEnvelope(
          mediaKind: MediaKind.image,
          mediaId: alice.randomBytes(16),
          mimeCode: MediaMime.jpeg,
          byteLength: 3000,
          chunkCount: 2,
          sha256: alice.randomBytes(32),
          key: key,
          width: 100,
          height: 80,
          caption: 'look',
        );

    test('a media manifest is sealed to the recipient and carries its key', () async {
      final key = alice.randomBytes(32);
      final p = await alice.buildDirectEnvelope(
        recipientSigningKey: bob.identity.signingPublicKey,
        recipientAgreementKey: bob.identity.agreementPublicKey,
        envelope: manifest(key),
      );
      expect(await verifyPacketSignature(p), isTrue);
      final opened = await bob.openDirectEnvelope(p) as MediaEnvelope;
      expect(opened.key, key);
      expect(opened.caption, 'look');
      expect(bytesToHex(p.payload), isNot(contains(bytesToHex(key))));
      await expectLater(mallory.openDirectEnvelope(p), throwsA(isA<DecryptionFailure>()));
    });

    test('openDirect refuses anything that is not plain text', () async {
      final p = await alice.buildDirectEnvelope(
        recipientSigningKey: bob.identity.signingPublicKey,
        recipientAgreementKey: bob.identity.agreementPublicKey,
        envelope: manifest(alice.randomBytes(32)),
      );
      await expectLater(
        bob.openDirect(p),
        throwsA(isA<DecryptionFailure>()
            .having((e) => e.reason, 'reason', DecryptionFailureReason.wrongType)),
      );
    });

    test('a group invitation round-trips', () async {
      final key = alice.newGroupKey();
      final snapshot = GroupSnapshot(
        isUpdate: false,
        groupId: key.groupId,
        epoch: key.epoch,
        groupKey: key.key,
        name: 'Trip',
        adminKey: alice.identity.signingPublicKey,
        members: [
          GroupMemberInfo(key: alice.identity.signingPublicKey, nickname: 'Alice'),
          GroupMemberInfo(key: bob.identity.signingPublicKey, nickname: 'Bob'),
        ],
      );
      final p = await alice.buildDirectEnvelope(
        recipientSigningKey: bob.identity.signingPublicKey,
        recipientAgreementKey: bob.identity.agreementPublicKey,
        envelope: snapshot,
      );
      final opened = await bob.openDirectEnvelope(p) as GroupSnapshot;
      expect(opened.groupKey, key.key);
      expect(opened.members.map((m) => m.nickname), ['Alice', 'Bob']);
      // The group key never appears on the wire.
      expect(bytesToHex(p.encode()), isNot(contains(bytesToHex(key.key))));
    });

    test('a chunk packet is not accepted as a direct message', () async {
      final key = alice.randomBytes(32);
      final chunk = await alice.buildChunk(
        type: PacketType.direct,
        recipientKey: bob.identity.signingPublicKey,
        mediaId: alice.randomBytes(16),
        index: 0,
        count: 1,
        data: Uint8List(100),
        key: key,
      );
      await expectLater(bob.openDirectEnvelope(chunk), throwsA(isA<DecryptionFailure>()));
    });
  });

  group('groups', () {
    late GroupSealKey group;

    setUp(() => group = alice.newGroupKey());

    Future<MeshPacket> post(String text, {EncryptionService? from, GroupSealKey? key}) =>
        (from ?? alice).buildGroupMessage(
          group: key ?? group,
          envelope: TextEnvelope(text, nickname: 'Alice'),
        );

    test('new keys are random, 32 bytes, epoch 0, and unique', () {
      final other = alice.newGroupKey();
      expect(group.key.length, 32);
      expect(group.groupId.length, 32);
      expect(group.epoch, 0);
      expect(other.groupId, isNot(group.groupId));
      expect(other.key, isNot(group.key));
    });

    test('a member decrypts, sees the nickname, and the signature verifies', () async {
      final p = await post('hello group');
      expect(await verifyPacketSignature(p), isTrue);
      expect(p.type, PacketType.group);
      expect(p.recipientKey, group.groupId);
      final env = await EncryptionService.openGroupMessage(p, group) as TextEnvelope;
      expect(env.text, 'hello group');
      expect(env.nickname, 'Alice');
    });

    test('a relay without the key cannot read it', () async {
      final p = await post('private to the group');
      final wrong = GroupSealKey(groupId: group.groupId, epoch: 0, key: alice.randomBytes(32));
      await expectLater(
        EncryptionService.openGroupMessage(p, wrong),
        throwsA(isA<DecryptionFailure>().having(
            (e) => e.reason, 'reason', DecryptionFailureReason.authenticationFailed)),
      );
      expect(bytesToHex(p.encode()), isNot(contains(bytesToHex(utf8.encode('private to the group')))));
    });

    test('survives a relay hop and the wire format', () async {
      final p = MeshPacket.decode((await post('hop')).relayed().relayed().encode());
      expect(await verifyPacketSignature(p), isTrue);
      expect((await EncryptionService.openGroupMessage(p, group) as TextEnvelope).text, 'hop');
    });

    test('the key epoch is readable so the right key can be chosen', () async {
      final next = alice.rotatedGroupKey(group);
      expect(next.epoch, 1);
      expect(next.groupId, group.groupId);
      expect(next.key, isNot(group.key));
      final p = await post('after rotation', key: next);
      expect(EncryptionService.groupPacketEpoch(p), 1);
      expect((await EncryptionService.openGroupMessage(p, next) as TextEnvelope).text, 'after rotation');
      // A removed member still holding the old key can read nothing new.
      await expectLater(
        EncryptionService.openGroupMessage(p, group),
        throwsA(isA<DecryptionFailure>()),
      );
    });

    test('a message for another group is not for us', () async {
      final other = alice.newGroupKey();
      final p = await post('x', key: other);
      await expectLater(
        EncryptionService.openGroupMessage(p, group),
        throwsA(isA<DecryptionFailure>()
            .having((e) => e.reason, 'reason', DecryptionFailureReason.notForUs)),
      );
    });

    test('tampering with the ciphertext or the epoch is detected', () async {
      final p = await post('integrity');
      final flipped = Uint8List.fromList(p.payload)..[20] ^= 1;
      await expectLater(
        EncryptionService.openGroupMessage(_replace(p, payload: flipped), group),
        throwsA(isA<DecryptionFailure>()),
      );
      final epoch = Uint8List.fromList(p.payload)..[3] = 7;
      await expectLater(
        EncryptionService.openGroupMessage(_replace(p, payload: epoch), group),
        throwsA(isA<DecryptionFailure>()),
      );
    });

    test('a ciphertext re-signed by another member does not decrypt (sender binding)', () async {
      final p = await post('from alice');
      final bytes = MeshPacket.buildSigningBytes(
        type: p.type,
        hopLimit: p.hopLimit,
        messageId: p.messageId,
        timestampMs: p.timestampMs,
        expiresAtMs: p.expiresAtMs,
        senderKey: mallory.identity.signingPublicKey,
        recipientKey: p.recipientKey,
        payload: p.payload,
      );
      final forged = _replace(
        p,
        senderKey: mallory.identity.signingPublicKey,
        signature: await mallory.sign(bytes),
      );
      expect(await verifyPacketSignature(forged), isTrue);
      await expectLater(
        EncryptionService.openGroupMessage(forged, group),
        throwsA(isA<DecryptionFailure>().having(
            (e) => e.reason, 'reason', DecryptionFailureReason.authenticationFailed)),
      );
    });

    test('padding hides small length differences', () async {
      final a = await post('a');
      final b = await post('b' * 40);
      expect(a.payload.length, b.payload.length);
    });

    test('uses the group hop limit and TTL', () async {
      final p = await post('x');
      expect(p.hopLimit, Protocol.groupHopLimit);
      expect(p.expiresAtMs - p.timestampMs, Protocol.groupMessageTtl.inMilliseconds);
      expect(p.hops, 0);
    });

    test('oversize and empty text are refused', () async {
      await expectLater(post(''), throwsArgumentError);
      await expectLater(post('x' * (Protocol.maxTextBytes + 1)), throwsArgumentError);
      expect(
        (await post('x' * Protocol.maxTextBytes)).encode().length,
        lessThanOrEqualTo(Protocol.maxPacketBytes),
      );
    });

    test('group media keys are per-object and depend on the group key', () async {
      final id1 = alice.randomBytes(16);
      final id2 = alice.randomBytes(16);
      final k1 = await EncryptionService.groupMediaKey(group.key, id1);
      expect(await EncryptionService.groupMediaKey(group.key, id1), k1);
      expect(await EncryptionService.groupMediaKey(group.key, id2), isNot(k1));
      expect(await EncryptionService.groupMediaKey(alice.randomBytes(32), id1), isNot(k1));
    });
  });

  group('media chunks', () {
    final data = Uint8List.fromList(List<int>.generate(1500, (i) => i % 251));

    test('a direct chunk is sealed with the manifest key and opens in place', () async {
      final key = alice.randomBytes(32);
      final mediaId = alice.randomBytes(16);
      final p = await alice.buildChunk(
        type: PacketType.direct,
        recipientKey: bob.identity.signingPublicKey,
        mediaId: mediaId,
        index: 1,
        count: 3,
        data: data,
        key: key,
      );
      expect(p.isChunk, isTrue);
      expect(await verifyPacketSignature(p), isTrue);
      expect(p.encode().length, lessThanOrEqualTo(Protocol.maxPacketBytes));

      final decoded = MeshPacket.decode(p.encode());
      final parsed = EncryptionService.parseChunkPacket(decoded);
      expect(parsed.epoch, isNull);
      expect(parsed.chunk.mediaId, mediaId);
      expect(parsed.chunk.index, 1);
      expect(parsed.chunk.count, 3);
      final plain = await EncryptionService.openChunkBody(
        packet: decoded,
        chunk: parsed.chunk,
        key: key,
      );
      expect(plain, data);
    });

    test('a chunk does not decrypt under the wrong key or in the wrong place', () async {
      final key = alice.randomBytes(32);
      final p = await alice.buildChunk(
        type: PacketType.direct,
        recipientKey: bob.identity.signingPublicKey,
        mediaId: alice.randomBytes(16),
        index: 0,
        count: 2,
        data: data,
        key: key,
      );
      final parsed = EncryptionService.parseChunkPacket(p);
      await expectLater(
        EncryptionService.openChunkBody(
            packet: p, chunk: parsed.chunk, key: alice.randomBytes(32)),
        throwsA(isA<DecryptionFailure>()),
      );
      // Moving the body to a different index (same packet header) must fail.
      final moved = MediaChunk(
        mediaId: parsed.chunk.mediaId,
        index: 1,
        count: 2,
        body: parsed.chunk.body,
      );
      await expectLater(
        EncryptionService.openChunkBody(packet: p, chunk: moved, key: key),
        throwsA(isA<DecryptionFailure>()),
      );
      // ...and into a different media object.
      final other = MediaChunk(
        mediaId: alice.randomBytes(16),
        index: 0,
        count: 2,
        body: parsed.chunk.body,
      );
      await expectLater(
        EncryptionService.openChunkBody(packet: p, chunk: other, key: key),
        throwsA(isA<DecryptionFailure>()),
      );
    });

    test('a group chunk carries the key epoch and uses the derived media key', () async {
      final group = alice.newGroupKey();
      final mediaId = alice.randomBytes(16);
      final key = await EncryptionService.groupMediaKey(group.key, mediaId);
      final p = await alice.buildChunk(
        type: PacketType.group,
        recipientKey: group.groupId,
        mediaId: mediaId,
        index: 0,
        count: 1,
        data: data,
        key: key,
        epoch: group.epoch,
      );
      final parsed = EncryptionService.parseChunkPacket(p);
      expect(parsed.epoch, 0);
      final plain = await EncryptionService.openChunkBody(
        packet: p,
        chunk: parsed.chunk,
        key: key,
        epoch: parsed.epoch,
      );
      expect(plain, data);
      // The epoch is authenticated: claiming another one fails.
      await expectLater(
        EncryptionService.openChunkBody(packet: p, chunk: parsed.chunk, key: key, epoch: 1),
        throwsA(isA<DecryptionFailure>()),
      );
    });

    test('a room chunk is plain but signed', () async {
      final roomId = PublicRooms.meshId;
      final p = await alice.buildChunk(
        type: PacketType.room,
        recipientKey: roomId,
        mediaId: alice.randomBytes(16),
        index: 0,
        count: 1,
        data: data,
      );
      expect(await verifyPacketSignature(p), isTrue);
      expect(EncryptionService.parseChunkPacket(p).chunk.body, data);
    });

    test('invalid builder arguments are refused', () async {
      Future<MeshPacket> make({
        PacketType type = PacketType.direct,
        Uint8List? key,
        int? epoch,
        int index = 0,
        int count = 1,
        Uint8List? body,
      }) =>
          alice.buildChunk(
            type: type,
            recipientKey: bob.identity.signingPublicKey,
            mediaId: alice.randomBytes(16),
            index: index,
            count: count,
            data: body ?? data,
            key: key,
            epoch: epoch,
          );
      final k = alice.randomBytes(32);
      await expectLater(make(type: PacketType.ack, key: k), throwsArgumentError);
      await expectLater(make(), throwsArgumentError); // direct chunk without a key
      await expectLater(make(type: PacketType.room, key: k), throwsArgumentError);
      await expectLater(make(key: k, epoch: 2), throwsArgumentError); // epoch only for groups
      await expectLater(make(type: PacketType.group, key: k), throwsArgumentError);
      await expectLater(make(key: k, body: Uint8List(0)), throwsArgumentError);
      await expectLater(
          make(key: k, body: Uint8List(Protocol.mediaChunkBytes + 1)), throwsArgumentError);
      await expectLater(make(key: k, index: 1), throwsArgumentError);
      await expectLater(make(key: k, count: Protocol.maxMediaChunks + 1), throwsArgumentError);
    });

    test('a non-chunk packet cannot be parsed as a chunk', () async {
      final p = await alice.buildRoomMessage(
        roomId: PublicRooms.meshId,
        envelope: const TextEnvelope('hi', nickname: 'A'),
      );
      expect(() => EncryptionService.parseChunkPacket(p), throwsA(isA<DecryptionFailure>()));
    });
  });

  group('public rooms', () {
    test('a room message is readable by anyone, signed, and carries the nickname', () async {
      final p = await alice.buildRoomMessage(
        roomId: PublicRooms.meshId,
        envelope: const TextEnvelope('hi everyone', nickname: 'Alice'),
      );
      expect(await verifyPacketSignature(p), isTrue);
      expect(p.type, PacketType.room);
      expect(p.recipientKey, PublicRooms.meshId);
      final env = EncryptionService.openRoomMessage(p) as TextEnvelope;
      expect(env.text, 'hi everyone');
      expect(env.nickname, 'Alice');
    });

    test('a relay cannot alter the text without breaking the signature', () async {
      final p = await alice.buildRoomMessage(
        roomId: PublicRooms.meshId,
        envelope: const TextEnvelope('pay Alice 5', nickname: 'Alice'),
      );
      final changed = Uint8List.fromList(p.payload);
      changed[changed.length - 1] ^= 1;
      expect(await verifyPacketSignature(_replace(p, payload: changed)), isFalse);
    });

    test('uses the room hop limit and TTL', () async {
      final p = await alice.buildRoomMessage(
        roomId: PublicRooms.meshId,
        envelope: const TextEnvelope('x'),
      );
      expect(p.hopLimit, Protocol.roomHopLimit);
      expect(p.expiresAtMs - p.timestampMs, Protocol.roomMessageTtl.inMilliseconds);
    });

    test('group-control envelopes are never built into, or accepted from, room traffic', () async {
      final snapshot = GroupSnapshot(
        isUpdate: false,
        groupId: alice.randomBytes(32),
        epoch: 0,
        groupKey: alice.randomBytes(32),
        name: 'x',
        adminKey: alice.identity.signingPublicKey,
        members: [GroupMemberInfo(key: alice.identity.signingPublicKey, nickname: 'A')],
      );
      await expectLater(
        alice.buildRoomMessage(roomId: PublicRooms.meshId, envelope: snapshot),
        throwsArgumentError,
      );
      await expectLater(
        alice.buildGroupMessage(group: alice.newGroupKey(), envelope: snapshot),
        throwsArgumentError,
      );
      // A hostile peer crafts one by hand: the receiving side refuses it too.
      final text = await alice.buildRoomMessage(
        roomId: PublicRooms.meshId,
        envelope: const TextEnvelope('x'),
      );
      final crafted = _replace(
        text,
        payload: EnvelopeCodec.encode(snapshot, withNickname: true),
      );
      expect(
        () => EncryptionService.openRoomMessage(crafted),
        throwsA(isA<DecryptionFailure>()
            .having((e) => e.reason, 'reason', DecryptionFailureReason.wrongType)),
      );
    });
  });

  group('room records', () {
    test('create, sign, verify', () async {
      final r = await alice.createRoomRecord(name: 'Cafe', description: 'Tables');
      expect(r.version, 1);
      expect(r.creatorKey, alice.identity.signingPublicKey);
      expect(await EncryptionService.verifyRoomRecord(r), isTrue);
      expect(RoomRecord.parse(r.encode()).name, 'Cafe');
      expect(r.expiresAtMs - r.createdAtMs, Protocol.roomRecordLifetime.inMilliseconds);
    });

    test('a record altered in transit fails verification', () async {
      final r = await alice.createRoomRecord(name: 'Cafe');
      final bytes = r.encode();
      // Flip a bit in the name.
      bytes[1 + 32 + 1] ^= 1;
      final parsed = RoomRecord.parse(bytes);
      expect(await EncryptionService.verifyRoomRecord(parsed), isFalse);
    });

    test('a record cannot be re-attributed to another creator', () async {
      final r = await alice.createRoomRecord(name: 'Cafe');
      final stolen = RoomRecord(
        roomId: r.roomId,
        name: r.name,
        description: r.description,
        creatorKey: mallory.identity.signingPublicKey,
        createdAtMs: r.createdAtMs,
        expiresAtMs: r.expiresAtMs,
        version: r.version,
        signature: r.signature,
      );
      expect(await EncryptionService.verifyRoomRecord(stolen), isFalse);
    });

    test('only the creator can refresh; a refresh bumps the version and lifetime', () async {
      final clock = FakeClock(1000);
      final a = await _newService(1, clock: clock);
      final r = await a.createRoomRecord(name: 'Cafe');
      clock.advance(const Duration(hours: 3));
      final fresh = await a.refreshRoomRecord(r);
      expect(fresh.version, 2);
      expect(fresh.roomId, r.roomId);
      expect(fresh.createdAtMs, r.createdAtMs, reason: 'the creation time is part of the id');
      expect(fresh.expiresAtMs, greaterThan(r.expiresAtMs));
      expect(await EncryptionService.verifyRoomRecord(fresh), isTrue);
      await expectLater(mallory.refreshRoomRecord(r), throwsArgumentError);
    });

    test('the room id is bound to its creator', () async {
      final r = await alice.createRoomRecord(name: 'Cafe');
      expect(await r.hasDerivedId(), isTrue);
      // Mallory copies Alice's room id and signs her own record under it.
      final hijack = RoomRecord(
        roomId: r.roomId,
        name: 'Cafe (official)',
        description: '',
        creatorKey: mallory.identity.signingPublicKey,
        createdAtMs: r.createdAtMs,
        expiresAtMs: r.expiresAtMs,
        version: 99,
        signature: Uint8List(64),
      );
      final signed = hijack.withSignature(await mallory.sign(hijack.signingBytes()));
      expect(
        await verifySignature(
          publicKey: signed.creatorKey,
          message: signed.signingBytes(),
          signature: signed.signature,
        ),
        isTrue,
        reason: 'the signature itself is genuine...',
      );
      expect(await EncryptionService.verifyRoomRecord(signed), isFalse,
          reason: '...but the id does not belong to Mallory');
    });

    test('an announcement packet wraps the record and anyone can relay it', () async {
      final r = await alice.createRoomRecord(name: 'Cafe');
      // Bob passes Alice's room on, signing the packet with his own key.
      final p = await bob.buildRoomAnnounce(r);
      expect(await verifyPacketSignature(p), isTrue);
      expect(p.senderKey, bob.identity.signingPublicKey);
      expect(p.isBroadcast, isTrue);
      final parsed = EncryptionService.parseRoomAnnounce(MeshPacket.decode(p.encode()));
      expect(parsed.roomId, r.roomId);
      expect(await EncryptionService.verifyRoomRecord(parsed), isTrue);
    });

    test('malformed announcements are rejected cleanly', () async {
      final r = await alice.createRoomRecord(name: 'Cafe');
      final p = await bob.buildRoomAnnounce(r);
      expect(() => EncryptionService.parseRoomAnnounce(_replace(p, payload: Uint8List(9))),
          throwsA(isA<DecryptionFailure>()));
      final ack = await bob.buildAck(
        recipientSigningKey: alice.identity.signingPublicKey,
        ackedMessageIds: [Uint8List(16)],
      );
      expect(() => EncryptionService.parseRoomAnnounce(ack), throwsA(isA<DecryptionFailure>()));
    });
  });

  group('link authentication', () {
    final nonceA = Uint8List.fromList(List.generate(16, (i) => i));
    final nonceB = Uint8List.fromList(List.generate(16, (i) => 100 + i));

    Future<Uint8List> aliceProof() => alice.signLinkAuth(
          verifierNonce: nonceB,
          proverNonce: nonceA,
          verifierSigningKey: bob.identity.signingPublicKey,
          nickname: 'Alice',
        );

    test('a prover that owns its key passes', () async {
      final sig = await aliceProof();
      expect(
        await EncryptionService.verifyLinkAuth(
          signature: sig,
          verifierNonce: nonceB,
          proverNonce: nonceA,
          proverSigningKey: alice.identity.signingPublicKey,
          proverAgreementKey: alice.identity.agreementPublicKey,
          proverNickname: 'Alice',
          verifierSigningKey: bob.identity.signingPublicKey,
        ),
        isTrue,
      );
    });

    Future<bool> check(
      Uint8List sig, {
      Uint8List? verifierNonce,
      Uint8List? proverKey,
      Uint8List? agreementKey,
      Uint8List? verifierKey,
      String nickname = 'Alice',
    }) =>
        EncryptionService.verifyLinkAuth(
          signature: sig,
          verifierNonce: verifierNonce ?? nonceB,
          proverNonce: nonceA,
          proverSigningKey: proverKey ?? alice.identity.signingPublicKey,
          proverAgreementKey: agreementKey ?? alice.identity.agreementPublicKey,
          proverNickname: nickname,
          verifierSigningKey: verifierKey ?? bob.identity.signingPublicKey,
        );

    test('claiming someone else\'s key fails', () async {
      final sig = await mallory.signLinkAuth(
        verifierNonce: nonceB,
        proverNonce: nonceA,
        verifierSigningKey: bob.identity.signingPublicKey,
        nickname: 'Alice',
      );
      expect(await check(sig), isFalse); // Mallory claims to be Alice
    });

    test('a replay with a different challenge fails', () async {
      final sig = await aliceProof();
      expect(await check(sig, verifierNonce: Uint8List(16)), isFalse);
    });

    test('a proof made for Bob cannot be replayed to Carol', () async {
      final sig = await aliceProof();
      expect(await check(sig, verifierKey: mallory.identity.signingPublicKey), isFalse);
    });

    test('swapping the claimed agreement key fails', () async {
      final sig = await aliceProof();
      expect(await check(sig, agreementKey: mallory.identity.agreementPublicKey), isFalse);
    });

    test('a nickname altered in transit fails', () async {
      final sig = await aliceProof();
      expect(await check(sig, nickname: 'Administrator'), isFalse);
    });

    test('garbage signatures and keys never throw', () async {
      expect(await check(Uint8List(64)), isFalse);
      expect(await check(Uint8List(3)), isFalse);
      expect(await check(Uint8List(64), proverKey: Uint8List(32)), isFalse);
    });
  });

  group('key verification', () {
    test('both sides compute the same safety number', () async {
      final a = await alice.safetyNumberWith(
        remoteSigningKey: bob.identity.signingPublicKey,
        remoteAgreementKey: bob.identity.agreementPublicKey,
      );
      final b = await bob.safetyNumberWith(
        remoteSigningKey: alice.identity.signingPublicKey,
        remoteAgreementKey: alice.identity.agreementPublicKey,
      );
      expect(a, b);
      expect(a, matches(RegExp(r'^\d{5}( \d{5}){5}$')));
    });

    test('a substituted key changes the safety number', () async {
      final real = await alice.safetyNumberWith(
        remoteSigningKey: bob.identity.signingPublicKey,
        remoteAgreementKey: bob.identity.agreementPublicKey,
      );
      final fake = await alice.safetyNumberWith(
        remoteSigningKey: bob.identity.signingPublicKey,
        remoteAgreementKey: mallory.identity.agreementPublicKey,
      );
      expect(fake, isNot(real));
    });

    test('fingerprints are stable per identity', () async {
      expect(await alice.identity.fingerprint(), await alice.identity.fingerprint());
      expect(await alice.identity.fingerprint(), isNot(await bob.identity.fingerprint()));
    });
  });
}
