import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:offline_mesh_chat/core/app_log.dart';
import 'package:offline_mesh_chat/core/bytes.dart';
import 'package:offline_mesh_chat/crypto/key_store.dart';
import 'package:offline_mesh_chat/protocol/fragmenter.dart';
import 'package:offline_mesh_chat/protocol/link_frame.dart';
import 'package:offline_mesh_chat/services/bluetooth_service.dart';
import 'package:offline_mesh_chat/services/discovery_service.dart';
import 'package:offline_mesh_chat/services/encryption_service.dart';
import 'package:offline_mesh_chat/services/plugin_ble_radio.dart';
import 'package:offline_mesh_chat/transport/ble_radio.dart';
import 'package:offline_mesh_chat/transport/mesh_transport.dart';

import 'fake_ble_world.dart';
import 'radio_harness.dart';

/// Quick timings so handshakes, keepalives and retries run in milliseconds.
const BluetoothServiceConfig fastService = BluetoothServiceConfig(
  handshakeTimeout: Duration(milliseconds: 2500),
  maintenanceInterval: Duration(milliseconds: 40),
  pingAfterIdle: Duration(milliseconds: 300),
  deadAfter: Duration(milliseconds: 1500),
  frameSendTimeout: Duration(seconds: 3),
  rssiInterval: Duration(milliseconds: 100),
  earlyChunkGrace: Duration(milliseconds: 500),
);

const DiscoveryConfig fastDiscovery = DiscoveryConfig(
  scanOn: Duration(milliseconds: 250),
  scanOff: Duration(milliseconds: 100),
  minScanStartGap: Duration.zero,
  connectTick: Duration(milliseconds: 20),
  candidateFreshness: Duration(seconds: 3),
  connectJitterMax: Duration(milliseconds: 25),
  baseBackoff: Duration(milliseconds: 60),
  maxBackoff: Duration(milliseconds: 500),
  reconnectDelay: Duration(milliseconds: 60),
  notifyGap: Duration.zero,
);

/// One phone running the real radio adapter, link layer, discovery policy and
/// identity on top of the simulated BLE world.
class BleNode {
  BleNode._({
    required this.name,
    required this.phone,
    required this.radio,
    required this.crypto,
    required this.bluetooth,
    required this.discovery,
  }) {
    _sub = bluetooth.events.listen((e) {
      events.add(e);
      switch (e) {
        case NeighborUp(:final info):
          ups.add(info);
        case NeighborDown(:final peerId):
          downs.add(peerId);
        case PacketReceived(:final fromPeerId, :final bytes):
          packets.add((fromPeerId, bytes));
      }
    });
  }

  final String name;
  final FakePhone phone;
  final PluginBleRadio radio;
  final EncryptionService crypto;
  final BluetoothService bluetooth;
  final DiscoveryService discovery;
  late final StreamSubscription<TransportEvent> _sub;

  final List<TransportEvent> events = <TransportEvent>[];
  final List<NeighborInfo> ups = <NeighborInfo>[];
  final List<String> downs = <String>[];
  final List<(String, Uint8List)> packets = <(String, Uint8List)>[];
  final List<String> securityEvents = <String>[];

  String get id => crypto.identity.id;

  static Future<BleNode> create(
    FakeBleWorld world,
    String name, {
    int seed = 1,
    BlePlatform platform = BlePlatform.android,
    int maxMtu = 247,
    BluetoothServiceConfig service = fastService,
    DiscoveryConfig discoveryConfig = fastDiscovery,
    KeyStore? keys,
    String? nickname,
  }) async {
    final phone = world.addPhone(name, platform: platform, maxMtu: maxMtu);
    final log = AppLog(echo: false);
    final radio = PluginBleRadio(
      central: phone.central,
      peripheral: phone.peripheral,
      platform: platform,
      log: log,
      timings: fastTimings,
    );
    final crypto = await EncryptionService.loadOrCreate(
      keys ?? MemoryKeyStore(),
      random: Random(seed),
    );
    late final BleNode node;
    final bluetooth = BluetoothService(
      radio: radio,
      crypto: crypto,
      nickname: () => nickname ?? name,
      config: service,
      log: log,
      random: Random(seed + 77),
      onSecurityEvent: (kind, {String? peerId, String? detail}) async {
        node.securityEvents.add(kind);
      },
    );
    final discovery = DiscoveryService(
      radio: radio,
      bluetooth: bluetooth,
      config: discoveryConfig,
      log: log,
      random: Random(seed + 99),
    );
    node = BleNode._(
      name: name,
      phone: phone,
      radio: radio,
      crypto: crypto,
      bluetooth: bluetooth,
      discovery: discovery,
    );
    return node;
  }

  /// Starts radio, link layer; optionally the automatic discovery policy.
  Future<void> start({bool discover = true}) async {
    await radio.initialize();
    await bluetooth.start();
    if (discover) {
      await discovery.start();
    } else {
      await radio.startAdvertising();
    }
  }

  Future<void> dispose() async {
    await _sub.cancel();
    await discovery.dispose();
    await bluetooth.dispose();
    await radio.dispose();
  }

  /// True when this node has a ready link to [other].
  bool linkedTo(BleNode other) => bluetooth.isNeighbor(other.id);

  /// Looks for [other] by scanning, then connects to it (no automatic policy).
  Future<String> connectManually(BleNode other) async {
    final target = other.phone.deviceUuid.toString();
    await radio.startScan();
    await eventually(() => radio.isScanning);
    // Wait until its advertisement has been heard.
    final seen = Completer<void>();
    final sub = radio.discoveries.listen((d) {
      if (d.deviceId == target && !seen.isCompleted) seen.complete();
    });
    await seen.future.timeout(const Duration(seconds: 2));
    await sub.cancel();
    return bluetooth.connectTo(target);
  }
}

/// Waits for [a] and [b] to have a ready link to each other.
Future<void> waitLinked(BleNode a, BleNode b, {Duration timeout = const Duration(seconds: 5)}) =>
    eventually(() => a.linkedTo(b) && b.linkedTo(a),
        timeout: timeout, reason: '${a.name} and ${b.name} should be linked');

/// Like [waitLinked], and also waits until each side holds exactly one link:
/// when two phones find each other at the same moment both connect, and the
/// redundant second link is closed a moment later.
Future<void> waitStableLink(BleNode a, BleNode b,
    {Duration timeout = const Duration(seconds: 6)}) async {
  await waitLinked(a, b, timeout: timeout);
  // A second connection attempt that began during the first handshake can
  // still complete a moment later (and is then closed again), so "one link"
  // must hold steadily, not just once.
  final deadline = DateTime.now().add(timeout);
  DateTime? stableSince;
  while (DateTime.now().isBefore(deadline)) {
    final single = a.bluetooth.linkCount == 1 &&
        b.bluetooth.linkCount == 1 &&
        a.linkedTo(b) &&
        b.linkedTo(a);
    if (single) {
      stableSince ??= DateTime.now();
      if (DateTime.now().difference(stableSince) >= const Duration(milliseconds: 350)) return;
    } else {
      stableSince = null;
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('${a.name}/${b.name} did not settle on a single link '
      '(${a.bluetooth.linkCount}/${b.bluetooth.linkCount})');
}

/// A bare device that speaks the link protocol by hand, to play a hostile or
/// broken peer: it can send any frame, including ones a correct peer never would.
class RogueDevice {
  RogueDevice._(this.phone, this.radio) {
    _sub = radio.linkEvents.listen((e) {
      if (e is RadioLinkOpened) {
        links.add(e.linkId);
      } else if (e is RadioLinkClosed) {
        closedLinks.add(e.linkId);
      }
    });
    _chunkSub = radio.chunks.listen((c) {
      final frame = reassemblers.putIfAbsent(c.linkId, FrameReassembler.new).add(c.data);
      if (frame != null) received.add(LinkFrame.decode(frame));
    });
  }

  final FakePhone phone;
  final PluginBleRadio radio;
  final List<String> links = <String>[];
  final List<String> closedLinks = <String>[];
  final List<LinkFrame> received = <LinkFrame>[];
  final Map<String, FrameReassembler> reassemblers = <String, FrameReassembler>{};
  late final StreamSubscription<RadioLinkEvent> _sub;
  late final StreamSubscription<RadioChunk> _chunkSub;
  int _frameId = 0;

  static Future<RogueDevice> create(FakeBleWorld world, String name,
      {BlePlatform platform = BlePlatform.android}) async {
    final phone = world.addPhone(name, platform: platform);
    final radio = PluginBleRadio(
      central: phone.central,
      peripheral: phone.peripheral,
      platform: platform,
      log: AppLog(echo: false),
      timings: fastTimings,
    );
    await radio.initialize();
    await radio.startAdvertising();
    return RogueDevice._(phone, radio);
  }

  Future<void> send(String linkId, LinkFrame frame) => sendBytes(linkId, frame.encode());

  /// Sends any bytes as one frame, also ones this app could never encode (a
  /// frame of another protocol version, say).
  Future<void> sendBytes(String linkId, List<int> frameBytes) async {
    final chunks = FrameChunker.split(Uint8List.fromList(frameBytes),
        frameId: _frameId++, maxChunk: radio.maxChunkSize(linkId));
    for (final c in chunks) {
      await radio.sendChunk(linkId, c);
    }
  }

  Future<void> dispose() async {
    await _sub.cancel();
    await _chunkSub.cancel();
    await radio.dispose();
  }
}

/// Sample payload of [length] bytes.
Uint8List sampleBytes(int length, [int seed = 0]) =>
    Uint8List.fromList(List<int>.generate(length, (i) => (i * 7 + seed) & 0xff));

String shortId(String id) => id.substring(0, 8);

String hex(List<int> b) => bytesToHex(b);
