import 'dart:math';

import 'package:offline_mesh_chat/core/app_log.dart';
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
import 'package:offline_mesh_chat/services/plugin_ble_radio.dart';

import 'ble_stack.dart';
import 'fake_ble_world.dart';
import 'test_database.dart';
import 'test_node.dart';

/// Real-time router settings: short timers so retries and announcements
/// happen within a test's lifetime.
const MeshRouterConfig liveRouterConfig = MeshRouterConfig(
  announceInterval: Duration(milliseconds: 400),
  flushInterval: Duration(milliseconds: 100),
  maintenanceInterval: Duration(milliseconds: 500),
);

const QueueConfig liveQueueConfig = QueueConfig(
  baseRetry: Duration(milliseconds: 120),
  maxRetry: Duration(milliseconds: 600),
  idleRetry: Duration(milliseconds: 120),
  resendCooldown: Duration(milliseconds: 250),
  relayResendCooldown: Duration(milliseconds: 800),
);

/// A complete phone: simulated BLE radio, link layer, discovery, identity,
/// SQLite, store-and-forward queue and mesh router - everything except the UI.
class FullStackNode implements DelegateHost {
  FullStackNode._(this.ble, this.db, this.outbox, this.table, this.queue, this.router) {
    delegate = RecordingDelegate(this);
    router.delegate = delegate;
  }

  final BleNode ble;
  final DatabaseHelper db;
  final OutboxRepository outbox;
  final PeerTable table;
  final MessageQueue queue;
  @override
  final MeshRouter router;
  late final RecordingDelegate delegate;

  @override
  String get name => ble.name;

  @override
  EncryptionService get crypto => ble.crypto;

  String get id => ble.id;

  FakePhone get phone => ble.phone;

  static Future<FullStackNode> create(
    FakeBleWorld world,
    String name, {
    int seed = 1,
    BlePlatform platform = BlePlatform.android,
    int maxMtu = 247,
    KeyStore? keys,
    DatabaseHelper? db,
  }) async {
    final ble = await BleNode.create(world, name,
        seed: seed, platform: platform, maxMtu: maxMtu, keys: keys);
    final database = db ?? await openMemoryDatabase();
    final store = OutboxRepository(database.db);
    final table = PeerTable();
    final seen = DuplicateFilter(store: store);
    final queue = MessageQueue(store: store, config: liveQueueConfig, random: Random(seed));
    final relay = RelayManager(table: table, queue: queue);
    final router = MeshRouter(
      transport: ble.bluetooth,
      localId: ble.id,
      table: table,
      seen: seen,
      queue: queue,
      relay: relay,
      config: liveRouterConfig,
      log: AppLog(echo: false),
    );
    return FullStackNode._(ble, database, store, table, queue, router);
  }

  /// Brings the whole phone up: radio, link layer, router, then discovery.
  Future<void> start() async {
    await ble.radio.initialize();
    await ble.bluetooth.start();
    await router.start();
    await ble.discovery.start();
  }

  Future<MeshPacket> sendDirect(FullStackNode to, String text, {int? hopLimit}) async {
    final packet = await crypto.buildDirect(
      recipientSigningKey: to.crypto.identity.signingPublicKey,
      recipientAgreementKey: to.crypto.identity.agreementPublicKey,
      text: text,
      hopLimit: hopLimit ?? 5,
    );
    await router.submit(packet);
    return packet;
  }

  Future<void> dispose() async {
    await router.stop();
    await ble.dispose();
    await db.close();
  }
}
