import 'dart:typed_data';

import 'package:offline_mesh_chat/core/app_log.dart';
import 'package:offline_mesh_chat/crypto/key_store.dart';
import 'package:offline_mesh_chat/database/group_repository.dart';
import 'package:offline_mesh_chat/database/media_repository.dart';
import 'package:offline_mesh_chat/database/message_repository.dart';
import 'package:offline_mesh_chat/database/room_repository.dart';
import 'package:offline_mesh_chat/models/media.dart';
import 'package:offline_mesh_chat/models/message.dart';
import 'package:offline_mesh_chat/services/group_keyring.dart';
import 'package:offline_mesh_chat/services/message_service.dart';
import 'package:offline_mesh_chat/services/service_context.dart';

import 'fake_clock.dart';
import 'memory_network.dart';
import 'test_node.dart';

/// A phone with the real Message Manager (instead of the recording delegate)
/// on the in-memory mesh.
class MessageNode {
  MessageNode._({
    required this.node,
    required this.bus,
    required this.repo,
    required this.groupRepo,
    required this.roomRepo,
    required this.mediaRepo,
    required this.context,
    required this.service,
    required this.keyStore,
    required this.mediaStore,
  });

  final TestNode node;
  final ChangeBus bus;
  final MessageRepository repo;
  final GroupRepository groupRepo;
  final RoomRepository roomRepo;
  final MediaRepository mediaRepo;
  final ServiceContext context;
  final MessageService service;
  final KeyStore keyStore;
  final MemoryMediaStore mediaStore;

  String get id => node.id;

  String get name => node.name;

  static Future<MessageNode> create(
    String name,
    MemoryNetwork network,
    FakeClock clock, {
    int seed = 1,
    String? nickname,
    MediaConfig mediaConfig = const MediaConfig(),
    MemoryMediaStore? mediaStore,
  }) async {
    final node = await TestNode.create(name, network, clock, seed: seed, start: false);
    final bus = ChangeBus();
    final repo = MessageRepository(node.db.db, bus: bus);
    final groupRepo = GroupRepository(node.db.db, bus: bus);
    final roomRepo = RoomRepository(node.db.db, bus: bus);
    final mediaRepo = MediaRepository(node.db.db, bus: bus);
    final keyStore = MemoryKeyStore();
    final store = mediaStore ?? MemoryMediaStore(() => clock.nowMs);
    final context = ServiceContext(
      crypto: node.crypto,
      repo: repo,
      groupRepo: groupRepo,
      roomRepo: roomRepo,
      mediaRepo: mediaRepo,
      router: node.router,
      nickname: () => nickname ?? name,
      clock: clock,
      // Receipts go out on the very next turn of the event loop in tests.
      ackBatchDelay: Duration.zero,
      log: AppLog(echo: false),
    );
    final service = MessageService(
      context: context,
      keyring: GroupKeyring(keyStore),
      mediaStore: store,
      mediaConfig: mediaConfig,
    );
    node.router.delegate = service;
    await service.start();
    await node.router.start();
    return MessageNode._(
      node: node,
      bus: bus,
      repo: repo,
      groupRepo: groupRepo,
      roomRepo: roomRepo,
      mediaRepo: mediaRepo,
      context: context,
      service: service,
      keyStore: keyStore,
      mediaStore: store,
    );
  }

  /// All messages of the direct conversation with [peer].
  Future<List<ChatMessage>> chatWith(MessageNode peer) async =>
      repo.getMessages('dm:${peer.id}');

  Future<ChatMessage?> message(String id) => repo.getMessage(id);

  /// The media of a message, or null.
  Future<MediaItem?> mediaOf(String messageId) => mediaRepo.forMessage(messageId);

  Future<void> close() async {
    await service.dispose();
    await repo.dispose();
    await bus.dispose();
    await node.close();
  }
}

/// Deterministic pseudo-random bytes (not a real JPEG: the services only move
/// and verify bytes).
Uint8List fakeBytes(int length, [int seed = 1]) =>
    Uint8List.fromList(List<int>.generate(length, (i) => (i * 31 + seed * 17 + (i >> 8)) & 0xff));
