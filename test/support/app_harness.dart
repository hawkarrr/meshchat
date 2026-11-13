import 'package:offline_mesh_chat/app_controller.dart';
import 'package:offline_mesh_chat/core/app_log.dart';
import 'package:offline_mesh_chat/crypto/key_store.dart';
import 'package:offline_mesh_chat/database/database_helper.dart';
import 'package:offline_mesh_chat/device/device_io.dart';
import 'package:offline_mesh_chat/l10n/l10n.dart';
import 'package:offline_mesh_chat/models/peer.dart';
import 'package:offline_mesh_chat/services/bluetooth_service.dart';
import 'package:offline_mesh_chat/services/device_info_service.dart';
import 'package:offline_mesh_chat/services/media_store.dart';
import 'package:offline_mesh_chat/services/network_status_service.dart';
import 'package:offline_mesh_chat/services/plugin_ble_radio.dart';
import 'package:offline_mesh_chat/theme/theme_controller.dart';

import 'ble_stack.dart';
import 'fake_device.dart';
import 'fake_ble_world.dart';
import 'full_stack_node.dart';
import 'radio_harness.dart';
import 'test_database.dart';

/// Link and radio timings for application-level tests. They are not about
/// timeouts (the radio and link suites cover those with tiny budgets), so they
/// are forgiving enough that a busy test machine does not look like a dead radio.
const BluetoothServiceConfig tolerantService = BluetoothServiceConfig(
  handshakeTimeout: Duration(seconds: 6),
  maintenanceInterval: Duration(milliseconds: 100),
  pingAfterIdle: Duration(seconds: 1),
  deadAfter: Duration(seconds: 6),
  frameSendTimeout: Duration(seconds: 8),
  rssiInterval: Duration(milliseconds: 500),
  earlyChunkGrace: Duration(seconds: 1),
);

const RadioTimings tolerantTimings = RadioTimings(
  connectGuard: Duration(seconds: 3),
  postConnectDelay: Duration.zero,
  mtuTimeout: Duration(milliseconds: 1500),
  discoverTimeout: Duration(milliseconds: 1500),
  subscribeTimeout: Duration(milliseconds: 1500),
  operationTimeout: Duration(seconds: 2),
  stateWait: Duration(milliseconds: 500),
  advertiseRetry: Duration(milliseconds: 200),
  sendRetryBase: Duration(milliseconds: 5),
);

/// One phone running the complete application controller - the same object the
/// UI uses - on top of the simulated BLE world. Everything real except the
/// Bluetooth plugin itself.
class AppNode {
  AppNode._(this.name, this.phone, this.controller, this.keys, this.db, this.log, this.media, this.io);

  final String name;
  final FakePhone phone;
  final AppController controller;
  final KeyStore keys;
  final DatabaseHelper db;
  final AppLog log;
  final MediaStore media;

  /// The fake permissions, picker, recorder and player of this phone.
  final DeviceIo io;

  String get id => controller.identityId;

  static Future<AppNode> create(
    FakeBleWorld world,
    String name, {
    BlePlatform platform = BlePlatform.android,
    KeyStore? keys,
    DatabaseHelper? db,
    FakePhone? phone,
    NetworkKind network = NetworkKind.none,
    MediaStore? media,
    DeviceIo? io,

    /// The tests read English words on screen; the ones about the other
    /// languages ask for them.
    AppLanguage language = AppLanguage.en,

    /// The appearance; dark (what the app was before it had a light one) unless given.
    ThemeController? theme,
  }) async {
    final fake = phone ?? world.addPhone(name, platform: platform);
    final store = keys ?? MemoryKeyStore();
    final database = db ?? await openMemoryDatabase();
    final log = AppLog(echo: false);
    final mediaStore = media ?? MemoryMediaStore();
    final deviceIo = io ?? fakeDeviceIo(compressor: const ImageCompressor(useIsolate: false));
    final controller = AppController(
      keyStore: store,
      database: database,
      mediaStore: mediaStore,
      io: deviceIo,
      radioFactory: () => PluginBleRadio(
        central: fake.central,
        peripheral: fake.peripheral,
        platform: platform,
        log: log,
        timings: tolerantTimings,
      ),
      deviceInfo: StaticDeviceInfo('$name - test phone'),
      network: StaticNetworkStatus(network),
      routerConfig: liveRouterConfig,
      queueConfig: liveQueueConfig,
      linkConfig: tolerantService,
      discoveryOverride: fastDiscovery,
      ackBatchDelay: const Duration(milliseconds: 20),
      defaultLanguage: language,
      theme: theme,
      log: log,
    );
    await controller.init();
    return AppNode._(name, fake, controller, store, database, log, mediaStore, deviceIo);
  }

  /// What the first-run page does: mark onboarding done and start Bluetooth.
  Future<void> startUp() async {
    await controller.requestPermissions();
    await controller.completeOnboarding();
  }

  /// A reachable peer entry for [other], or null.
  PeerView? viewOf(AppNode other) =>
      controller.peers.where((p) => p.peer.id == other.id).firstOrNull;

  bool directlyReaches(AppNode other) =>
      viewOf(other)?.status.reachability == Reachability.direct;

  Future<void> dispose() async {
    await controller.stopNetworking();
    controller.dispose();
    // Let the controller's asynchronous teardown (and any refresh that was
    // already reading the database) finish before the database is closed.
    await Future<void>.delayed(const Duration(milliseconds: 80));
    await db.close();
  }
}

/// Waits until [a] and [b] each list the other as a direct, verified link.
Future<void> waitForDirect(AppNode a, AppNode b,
    {Duration timeout = const Duration(seconds: 8)}) async {
  await eventually(
    () => a.directlyReaches(b) && b.directlyReaches(a),
    timeout: timeout,
    reason: '${a.name} and ${b.name} should see each other as directly connected',
  );
}
