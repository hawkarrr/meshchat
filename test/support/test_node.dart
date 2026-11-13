import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:offline_mesh_chat/core/app_log.dart';
import 'package:offline_mesh_chat/core/bytes.dart';
import 'package:offline_mesh_chat/crypto/key_store.dart';
import 'package:offline_mesh_chat/database/database_helper.dart';
import 'package:offline_mesh_chat/database/outbox_repository.dart';
import 'package:offline_mesh_chat/mesh/duplicate_filter.dart';
import 'package:offline_mesh_chat/mesh/mesh_router.dart';
import 'package:offline_mesh_chat/mesh/message_queue.dart';
import 'package:offline_mesh_chat/mesh/peer_table.dart';
import 'package:offline_mesh_chat/mesh/relay_manager.dart';
import 'package:offline_mesh_chat/protocol/mesh_packet.dart';
import 'package:offline_mesh_chat/services/encryption_service.dart';
import 'package:offline_mesh_chat/transport/mesh_transport.dart';

import 'fake_clock.dart';
import 'memory_network.dart';
import 'test_database.dart';

/// A direct message as seen by the recipient's delegate.
class ReceivedDirect {
  ReceivedDirect(this.packet, this.text, this.relayHops);

  final MeshPacket packet;
  final String text;
  final int relayHops;
}

/// What the recording delegate needs from the phone it belongs to.
abstract interface class DelegateHost {
  String get name;

  EncryptionService get crypto;

  MeshRouter get router;
}

/// Minimal [MeshDelegate]: records what happens and behaves like the real
/// message manager for the parts the router depends on (decrypt, acknowledge).
class RecordingDelegate implements MeshDelegate {
  RecordingDelegate(this.node);

  final DelegateHost node;

  final List<ReceivedDirect> directs = <ReceivedDirect>[];

  /// Direct packets addressed to us that were not plain text (manifests,
  /// invitations) and direct chunks.
  final List<Envelope> otherDirects = <Envelope>[];
  final List<MeshPacket> directChunks = <MeshPacket>[];
  final List<MeshPacket> groupPackets = <MeshPacket>[];
  final List<MeshPacket> roomPackets = <MeshPacket>[];
  final List<RoomRecord> roomAnnounces = <RoomRecord>[];
  final List<AckContent> acks = <AckContent>[];
  final List<int> ackHops = <int>[];
  final List<AnnounceContent> announces = <AnnounceContent>[];
  final List<String> neighborUps = <String>[];
  final List<String> neighborDowns = <String>[];
  final List<MeshPacket> duplicateDirects = <MeshPacket>[];
  final List<MeshPacket> ownSent = <MeshPacket>[];
  final List<OutboxEntry> ownExpired = <OutboxEntry>[];
  final List<String> securityEvents = <String>[];
  final Set<String> memberOfGroups = <String>{};
  final Set<String> joinedRooms = <String>{};

  /// Records handed to the router when it asks which rooms to announce.
  final List<RoomRecord> roomsToAnnounce = <RoomRecord>[];

  /// What [onRoomAnnounce] answers: is the announcement worth forwarding?
  bool roomAnnounceIsNews = true;
  bool autoAck = true;
  bool announcing = true;

  @override
  Future<bool> wantsGroup(Uint8List groupId) async => memberOfGroups.contains(bytesToHex(groupId));

  @override
  Future<bool> wantsRoom(Uint8List roomId) async => joinedRooms.contains(bytesToHex(roomId));

  @override
  Future<void> onDirectMessage(MeshPacket packet, {required int relayHops}) async {
    if (packet.isChunk) {
      directChunks.add(packet);
    } else {
      final envelope = await node.crypto.openDirectEnvelope(packet);
      if (envelope is TextEnvelope) {
        directs.add(ReceivedDirect(packet, envelope.text, relayHops));
      } else {
        otherDirects.add(envelope);
      }
    }
    if (autoAck) {
      final ack = await node.crypto.buildAck(
        recipientSigningKey: packet.senderKey,
        ackedMessageIds: [packet.messageId],
      );
      await node.router.submit(ack);
    }
  }

  @override
  Future<void> onGroupPacket(MeshPacket packet, {required int relayHops}) async =>
      groupPackets.add(packet);

  @override
  Future<void> onRoomPacket(MeshPacket packet, {required int relayHops}) async =>
      roomPackets.add(packet);

  @override
  Future<bool> onRoomAnnounce(MeshPacket packet, RoomRecord record, {required int relayHops}) async {
    roomAnnounces.add(record);
    return roomAnnounceIsNews;
  }

  @override
  Future<void> onAck(MeshPacket packet, AckContent ack, {required int relayHops}) async {
    acks.add(ack);
    ackHops.add(relayHops);
  }

  @override
  Future<void> onAnnounce(MeshPacket packet, AnnounceContent content, {required int relayHops}) async {
    announces.add(content);
  }

  @override
  Future<void> onNeighborUp(NeighborInfo neighbor) async => neighborUps.add(neighbor.peerId);

  @override
  Future<void> onNeighborDown(String peerId) async => neighborDowns.add(peerId);

  @override
  Future<void> onDuplicateDirect(MeshPacket packet) async => duplicateDirects.add(packet);

  @override
  Future<void> onOwnPacketSent(MeshPacket packet) async => ownSent.add(packet);

  @override
  Future<void> onOwnPacketExpired(OutboxEntry entry) async => ownExpired.add(entry);

  @override
  Future<void> onSecurityEvent(String kind, {String? peerId, String? detail}) async =>
      securityEvents.add(kind);

  @override
  Future<MeshPacket?> buildAnnouncement() async =>
      announcing ? node.crypto.buildAnnounce(nickname: node.name) : null;

  @override
  Future<List<MeshPacket>> buildRoomAnnouncements() async =>
      [for (final r in roomsToAnnounce) await node.crypto.buildRoomAnnounce(r)];
}

/// Set to true while debugging a test to see each router's log on the console.
bool traceLogs = false;

/// A complete phone: identity, database, queue, routing table and router on a
/// shared in-memory radio network.
class TestNode implements DelegateHost {
  TestNode._({
    required this.name,
    required this.crypto,
    required this.db,
    required this.transport,
    required this.clock,
    required this.network,
    required this.table,
    required this.seen,
    required this.queue,
    required this.relay,
    required this.router,
    required this.outbox,
  }) {
    delegate = RecordingDelegate(this);
    router.delegate = delegate;
  }

  @override
  final String name;
  @override
  final EncryptionService crypto;
  final DatabaseHelper db;
  final MemoryTransport transport;
  final FakeClock clock;
  final MemoryNetwork network;
  final PeerTable table;
  final DuplicateFilter seen;
  final MessageQueue queue;
  final RelayManager relay;
  @override
  final MeshRouter router;
  final OutboxRepository outbox;
  late final RecordingDelegate delegate;

  String get id => crypto.identity.id;

  Uint8List get signingKey => crypto.identity.signingPublicKey;

  Uint8List get agreementKey => crypto.identity.agreementPublicKey;

  /// Builds a node. Pass an existing [identityStore] and [db] to simulate a
  /// restart of the same phone.
  static Future<TestNode> create(
    String name,
    MemoryNetwork network,
    FakeClock clock, {
    int seed = 1,
    KeyStore? identityStore,
    DatabaseHelper? db,
    QueueConfig queueConfig = const QueueConfig(),
    MeshRouterConfig routerConfig = const MeshRouterConfig(autoTimers: false),
    int floodFanout = 4,
    bool start = true,
  }) async {
    final crypto = await EncryptionService.loadOrCreate(
      identityStore ?? MemoryKeyStore(),
      random: Random(seed),
      clock: clock,
    );
    final database = db ?? await openMemoryDatabase();
    final outbox = OutboxRepository(database.db);
    final table = PeerTable(clock: clock);
    final seen = DuplicateFilter(store: outbox, clock: clock);
    final queue = MessageQueue(
      store: outbox,
      config: queueConfig,
      clock: clock,
      random: Random(seed + 1000),
    );
    final relay = RelayManager(table: table, queue: queue, floodFanout: floodFanout);
    final self = NeighborInfo(
      signingKey: crypto.identity.signingPublicKey,
      agreementKey: crypto.identity.agreementPublicKey,
      nickname: name,
      sinceMs: clock.nowMs,
    );
    final transport = network.createTransport(self);
    final router = MeshRouter(
      transport: transport,
      localId: crypto.identity.id,
      table: table,
      seen: seen,
      queue: queue,
      relay: relay,
      config: routerConfig,
      clock: clock,
      log: AppLog(echo: traceLogs),
    );
    final node = TestNode._(
      name: name,
      crypto: crypto,
      db: database,
      transport: transport,
      clock: clock,
      network: network,
      table: table,
      seen: seen,
      queue: queue,
      relay: relay,
      router: router,
      outbox: outbox,
    );
    if (start) await router.start();
    return node;
  }

  /// Builds an encrypted direct message to [to] and submits it.
  Future<MeshPacket> sendDirect(
    TestNode to,
    String text, {
    int? hopLimit,
  }) async {
    final packet = await crypto.buildDirect(
      recipientSigningKey: to.signingKey,
      recipientAgreementKey: to.agreementKey,
      text: text,
      hopLimit: hopLimit ?? 5,
    );
    await router.submit(packet);
    return packet;
  }

  /// Builds a group message sealed under [key] and submits it.
  Future<MeshPacket> sendGroup(GroupSealKey key, String text) async {
    final packet = await crypto.buildGroupMessage(
      group: key,
      envelope: TextEnvelope(text, nickname: name),
    );
    await router.submit(packet);
    return packet;
  }

  /// Builds a public-room message and submits it.
  Future<MeshPacket> sendRoom(Uint8List roomId, String text) async {
    final packet = await crypto.buildRoomMessage(
      roomId: roomId,
      envelope: TextEnvelope(text, nickname: name),
    );
    await router.submit(packet);
    return packet;
  }

  Future<void> stop() => router.stop();

  Future<void> close() async {
    await router.stop();
    await db.close();
  }
}

/// Lets a set of nodes finish everything that is in flight: packets in the
/// air, router pipelines, follow-up sends. Returns once the network has been
/// quiet for several consecutive rounds.
Future<void> settle(
  MemoryNetwork network,
  Iterable<TestNode> nodes, {
  int maxRounds = 600,
  bool Function()? extraBusy,
}) async {
  var quietRounds = 0;
  for (var round = 0; round < maxRounds; round++) {
    // Yields to the event loop so stream events and timers get delivered.
    await Future<void>.delayed(Duration.zero);
    for (final n in nodes) {
      await n.router.settled();
    }
    // "Quiet" must hold at this very instant for the whole network: nothing
    // in the air AND every router idle (and, if given, nothing else pending,
    // such as receipts waiting to be sent). Checking only the packets in
    // flight is not enough - a router that has just received one is still
    // working.
    final busy = network.inFlight != 0 ||
        nodes.any((n) => n.router.isBusy) ||
        (extraBusy?.call() ?? false);
    if (busy) {
      quietRounds = 0;
    } else if (++quietRounds >= 2) {
      return;
    }
  }
  fail('network did not settle after $maxRounds rounds');
}

/// Connects every pair in [pairs] and lets the network settle.
Future<void> link(
  MemoryNetwork network,
  Iterable<TestNode> nodes,
  List<(TestNode, TestNode)> pairs,
) async {
  for (final (a, b) in pairs) {
    await network.connect(a.id, b.id);
  }
  await settle(network, nodes);
}
