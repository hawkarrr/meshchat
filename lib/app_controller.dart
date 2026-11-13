import 'dart:async';
import 'dart:io' show File;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode;

import 'core/app_log.dart';
import 'core/clock.dart';
import 'core/text.dart';
import 'crypto/fingerprint.dart';
import 'crypto/key_store.dart';
import 'database/database_helper.dart';
import 'device/device_io.dart';
import 'l10n/l10n.dart';
import 'database/group_repository.dart';
import 'database/media_repository.dart';
import 'database/message_repository.dart';
import 'database/outbox_repository.dart';
import 'database/room_repository.dart';
import 'mesh/duplicate_filter.dart';
import 'mesh/mesh_router.dart';
import 'mesh/message_queue.dart';
import 'mesh/peer_table.dart';
import 'mesh/relay_manager.dart';
import 'models/conversation.dart';
import 'models/group.dart';
import 'models/media.dart';
import 'models/message.dart';
import 'models/peer.dart';
import 'models/room.dart';
import 'services/ble_self_test.dart';
import 'services/bluetooth_service.dart';
import 'services/device_info_service.dart';
import 'services/discovery_service.dart';
import 'services/encryption_service.dart';
import 'services/group_keyring.dart';
import 'services/message_service.dart';
import 'services/network_status_service.dart';
import 'services/notification_coordinator.dart';
import 'services/plugin_ble_radio.dart';
import 'services/secure_key_store.dart';
import 'services/service_context.dart';
import 'theme/theme_controller.dart';
import 'transport/ble_radio.dart';

/// A known phone together with what can truthfully be said about reaching it
/// right now.
/// What is stored on the phone (the storage screen).
class StorageUsage {
  const StorageUsage({
    required this.messages,
    required this.mediaCount,
    required this.mediaBytes,
    required this.publicMessages,
    required this.databaseBytes,
    required this.lastCleanupAtMs,
    required this.lastCleanupRemoved,
  });

  final int messages;
  final int mediaCount;
  final int mediaBytes;

  /// Messages of public rooms, which are removed six hours after they arrive.
  final int publicMessages;

  /// The size of the database file, 0 when it cannot be told.
  final int databaseBytes;

  /// When the public chats were last cleaned and how many messages went, if
  /// anything was ever removed.
  final int? lastCleanupAtMs;
  final int lastCleanupRemoved;
}

class PeerView {
  const PeerView(this.peer, this.status);

  final Peer peer;
  final PeerStatus status;

  bool get isReachable => status.isReachable;
}

/// What the connection indicators show. Published as one value so a screen
/// that shows it rebuilds only when something it displays actually changed.
class NetworkSnapshot {
  const NetworkSnapshot({
    this.radioStatus = RadioStatus.unknown,
    this.radioError,
    this.advertising = false,
    this.scanning = false,
    this.neighborCount = 0,
    this.reachableCount = 0,
    this.starting = false,
    this.started = false,
    this.startError,
    this.newerVersionNearby = false,
    this.olderVersionNearby = false,
  });

  final RadioStatus radioStatus;
  final String? radioError;
  final bool advertising;
  final bool scanning;

  /// Phones directly connected to this one.
  final int neighborCount;

  /// Phones reachable right now, directly or through relays.
  final int reachableCount;
  final bool starting;
  final bool started;
  final String? startError;

  /// A phone nearby was turned away lately because it runs a newer version of
  /// the protocol: this phone needs an update to talk to it.
  final bool newerVersionNearby;

  /// A phone nearby was turned away lately because it runs an older version:
  /// that phone needs an update.
  final bool olderVersionNearby;

  /// At least one other phone can be reached now.
  bool get hasPeers => reachableCount > 0;

  @override
  bool operator ==(Object other) =>
      other is NetworkSnapshot &&
      other.radioStatus == radioStatus &&
      other.radioError == radioError &&
      other.advertising == advertising &&
      other.scanning == scanning &&
      other.neighborCount == neighborCount &&
      other.reachableCount == reachableCount &&
      other.starting == starting &&
      other.started == started &&
      other.startError == startError &&
      other.newerVersionNearby == newerVersionNearby &&
      other.olderVersionNearby == olderVersionNearby;

  @override
  int get hashCode => Object.hash(radioStatus, radioError, advertising, scanning, neighborCount,
      reachableCount, starting, started, startError, newerVersionNearby, olderVersionNearby);
}

enum _Slice { peers, conversations, groups, rooms }

/// Fires (at most four times a second) whenever anything about the radio, the
/// links, the devices in range or the routes changed. For the diagnostic
/// screens, which show raw live state; ordinary screens use the narrower
/// listenables instead.
class LiveChanges extends ChangeNotifier {
  void ping() => notifyListeners();
}

/// Everything the UI needs, and every action it can take.
///
/// It builds and owns the whole stack (database, identity, radio, link layer,
/// discovery, router, message manager) and republishes their changes.
///
/// The lists the screens show - conversations, people, groups, rooms, the
/// connection state - are separate [ValueListenable]s that only change when
/// their content does, so typing or scrolling in one screen never rebuilds
/// another. The controller itself notifies only about settings. The
/// destructive actions - [resetIdentity] and [clearAllData] - do nothing unless
/// the UI has already obtained an explicit confirmation from the user.
class AppController extends ChangeNotifier {
  AppController({
    required this.keyStore,
    required this.database,
    required this.radioFactory,
    required this.mediaStore,
    DeviceIo? io,
    this.clock = const SystemClock(),
    DeviceInfoSource? deviceInfo,
    NetworkStatusSource? network,
    this.routerConfig = const MeshRouterConfig(),
    this.queueConfig = const QueueConfig(),
    this.linkConfig = const BluetoothServiceConfig(),
    this.discoveryOverride,
    this.ackBatchDelay = const Duration(milliseconds: 250),
    this.defaultLanguage = AppLanguage.main,
    ThemeController? theme,
    AppLog? log,
  })  : io = io ?? DeviceIo.real(),
        deviceInfo = deviceInfo ?? DeviceInfoService(),
        network = network ?? NetworkStatusService(),
        theme = theme ?? ThemeController(mode: ThemeMode.dark),
        log = log ?? AppLog.instance;

  /// Builds the production controller: secure key storage, the real database
  /// and media folder in the app's private directory, and the real Bluetooth
  /// plugin. [theme] is the appearance the app has already started in.
  static Future<AppController> bootstrap({ThemeController? theme}) async {
    // The two do not depend on each other, so they open side by side. An error of
    // the one that is not waited for first is still kept for its own await.
    final opening = DatabaseHelper.open()..ignore();
    final folder = FileMediaStore.openDefault()..ignore();
    final controller = AppController(
      keyStore: SecureKeyStore(),
      database: await opening,
      radioFactory: () => PluginBleRadio(),
      mediaStore: await folder,
      theme: theme,
    );
    await controller.init();
    if (controller.onboardingDone) {
      unawaited(controller.startNetworking());
    }
    return controller;
  }

  static const String _kNickname = 'nickname';
  static const String _kMode = 'discovery_mode';
  static const String _kOnboarded = 'onboarded';
  static const String _kIdentity = 'identity_public';
  static const String _kRetentionDays = 'retention_days';
  static const String _kNotify = 'notify_enabled';
  static const String _kNotifyPrivacy = 'notify_privacy';
  static const String _kNotifyPublic = 'notify_public';
  static const String _kRelay = 'relay_enabled';
  static const String _kKeepAlive = 'keep_alive';
  static const String _kVideoLimit = 'video_limit';
  static const String _kLanguage = 'language';

  final KeyStore keyStore;
  final DatabaseHelper database;
  final BleRadio Function() radioFactory;
  final MediaStore mediaStore;

  /// The phone's permissions, camera roll, microphone and speaker.
  final DeviceIo io;
  final Clock clock;
  final DeviceInfoSource deviceInfo;
  final NetworkStatusSource network;
  final MeshRouterConfig routerConfig;
  final QueueConfig queueConfig;
  final BluetoothServiceConfig linkConfig;
  final DiscoveryConfig? discoveryOverride;

  /// How long receipts wait to be sent together. Tests shorten it.
  final Duration ackBatchDelay;

  /// The language used until the person picks one. Kurdish for the app; the
  /// tests that look for English words pass English.
  final AppLanguage defaultLanguage;
  final AppLog log;

  /// Whether the app is light, dark or follows the phone, and the memory of it. It lives
  /// beside the other settings so every screen reaches it the same way, but it is created
  /// before this controller and stored apart from the database (see [ThemeController]); a
  /// controller built without one (the tests) starts dark, as the app was before it had a
  /// light appearance. It is not disposed here: whoever made it owns it.
  final ThemeController theme;

  // ---- storage (independent of the identity, created once) --------------------
  late final ChangeBus bus;
  late final MessageRepository repo;
  late final GroupRepository groupRepo;
  late final RoomRepository roomRepo;
  late final MediaRepository mediaRepo;
  late final OutboxRepository outbox;

  // ---- services (rebuilt when the identity changes) ----------------------------
  late EncryptionService crypto;
  late BleRadio radio;
  late BluetoothService bluetooth;
  late DiscoveryService discovery;
  late PeerTable table;
  late MeshRouter router;
  late MessageService messages;

  // ---- what the screens listen to ----------------------------------------------
  final ValueNotifier<List<Conversation>> conversationsListenable =
      ValueNotifier<List<Conversation>>(const <Conversation>[]);
  final ValueNotifier<List<PeerView>> peersListenable =
      ValueNotifier<List<PeerView>>(const <PeerView>[]);
  final ValueNotifier<List<GroupChat>> groupsListenable =
      ValueNotifier<List<GroupChat>>(const <GroupChat>[]);
  final ValueNotifier<List<PublicRoom>> roomsListenable =
      ValueNotifier<List<PublicRoom>>(const <PublicRoom>[]);
  final ValueNotifier<int> unreadListenable = ValueNotifier<int>(0);
  final ValueNotifier<NetworkSnapshot> networkListenable =
      ValueNotifier<NetworkSnapshot>(const NetworkSnapshot());

  /// Live radio / link / discovery state, for the diagnostics-style screens.
  final LiveChanges liveChanges = LiveChanges();

  final Map<Object, String> _published = <Object, String>{};
  Timer? _liveTimer;
  final List<StreamSubscription<Object?>> _subs = <StreamSubscription<Object?>>[];
  final Set<_Slice> _dirty = <_Slice>{};
  Timer? _refreshTimer;
  Timer? _notifyTimer;
  Timer? _housekeeping;
  int _ticks = 0;
  bool _initialised = false;
  bool _started = false;
  bool _disposed = false;
  bool _starting = false;

  bool _notificationsEnabled = true;
  NotificationPrivacy _notificationPrivacy = NotificationPrivacy.sender;
  bool _notifyPublic = false;
  bool _relayEnabled = true;
  bool _keepAliveEnabled = false;
  int _videoLimit = defaultVideoSendLimit;
  bool _foreground = true;

  /// Decides which incoming messages become notifications (see there).
  late NotificationCoordinator notifier;

  /// A conversation to open because its notification was tapped. The home
  /// screen opens it and clears this.
  final ValueNotifier<String?> openRequest = ValueNotifier<String?>(null);

  late AppLanguage _language = defaultLanguage;
  String _nickname = '';
  DiscoveryMode _mode = DiscoveryMode.balanced;
  bool _onboardingDone = false;
  bool _identityWasReset = false;
  int _retentionDays = 0;
  String? _startError;
  String _fingerprintText = '';

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Opens settings and identity and builds the services. Does not touch Bluetooth.
  Future<void> init() async {
    if (_initialised) return;
    _initialised = true;
    bus = ChangeBus();
    repo = MessageRepository(database.db, bus: bus);
    groupRepo = GroupRepository(database.db, bus: bus);
    roomRepo = RoomRepository(database.db, bus: bus);
    mediaRepo = MediaRepository(database.db, bus: bus);
    outbox = OutboxRepository(database.db);
    crypto = await EncryptionService.loadOrCreate(keyStore, clock: clock);

    // Every setting in one read: this is on the way to the first screen.
    final stored = await repo.allSettings();

    // Detect an identity that vanished (secure storage was wiped or became
    // unreadable) while the message database survived.
    final remembered = stored[_kIdentity];
    _identityWasReset = remembered != null && remembered != crypto.identity.id;
    await repo.setSetting(_kIdentity, crypto.identity.id);

    _language = AppLanguage.parse(stored[_kLanguage]) ?? defaultLanguage;
    _nickname = stored[_kNickname] ?? _defaultNickname();
    final storedMode = stored[_kMode];
    _mode = DiscoveryMode.values.firstWhere(
      (m) => m.name == storedMode,
      orElse: () => DiscoveryMode.balanced,
    );
    _onboardingDone = stored[_kOnboarded] == '1';
    _retentionDays = int.tryParse(stored[_kRetentionDays] ?? '') ?? 0;
    _notificationsEnabled = stored[_kNotify] != '0';
    _notificationPrivacy = NotificationPrivacy.parse(stored[_kNotifyPrivacy]);
    _notifyPublic = stored[_kNotifyPublic] == '1';
    _relayEnabled = stored[_kRelay] != '0';
    _keepAliveEnabled = stored[_kKeepAlive] == '1';
    _videoLimit = _clampVideoLimit(
        int.tryParse(stored[_kVideoLimit] ?? '') ?? defaultVideoSendLimit);

    notifier = NotificationCoordinator(
      sink: io.notifications,
      strings: () => l10n,
      permissions: io.permissions,
      policy: () => NotificationPolicy(
        enabled: _notificationsEnabled,
        privacy: _notificationPrivacy,
        publicRooms: _notifyPublic,
      ),
      isForeground: () => _foreground,
    );
    try {
      await io.notifications.initialize(onTap: (conversationId) => openRequest.value = conversationId);
      final launched = await io.notifications.launchConversation();
      if (launched != null) openRequest.value = launched;
    } catch (e) {
      // Notifications are a convenience: the app works without them.
      log.w('App', 'notifications are not available: $e');
    }

    await _buildServices();
    await _refreshAll();
    await _applyRetention();
    _housekeeping = Timer.periodic(const Duration(seconds: 5), (_) => _tick());
  }

  /// "Phone A1B2" in the language of the app: a name other people on the mesh
  /// can tell apart until the person picks their own.
  String _defaultNickname() => l10n.defaultNickname(crypto.identity.id.substring(0, 4).toUpperCase());

  Future<void> _buildServices() async {
    radio = radioFactory();
    bluetooth = BluetoothService(
      radio: radio,
      crypto: crypto,
      nickname: () => _nickname,
      config: linkConfig,
      clock: clock,
      log: log,
      onSecurityEvent: (kind, {String? peerId, String? detail}) => repo.recordSecurityEvent(
        kind,
        peerId: peerId,
        detail: detail,
        atMs: clock.nowMs,
      ),
    );
    table = PeerTable(clock: clock);
    final seen = DuplicateFilter(store: outbox, clock: clock);
    final queue = MessageQueue(store: outbox, config: queueConfig, clock: clock);
    final relay = RelayManager(table: table, queue: queue);
    router = MeshRouter(
      transport: bluetooth,
      localId: crypto.identity.id,
      table: table,
      seen: seen,
      queue: queue,
      relay: relay,
      config: routerConfig,
      clock: clock,
      log: log,
    );
    messages = MessageService(
      context: ServiceContext(
        crypto: crypto,
        repo: repo,
        groupRepo: groupRepo,
        roomRepo: roomRepo,
        mediaRepo: mediaRepo,
        router: router,
        nickname: () => _nickname,
        clock: clock,
        ackBatchDelay: ackBatchDelay,
        strings: () => l10n,
        log: log,
      ),
      keyring: GroupKeyring(keyStore),
      mediaStore: mediaStore,
    );
    router.delegate = messages;
    router.relayForOthers = _relayEnabled;
    messages.media.maxVideoSendBytes = _videoLimit;
    // A notification that quotes a message goes when that message does.
    messages.actions.onRemoved = (removed) => unawaited(notifier.removed(removed));
    messages.publicCleanup.onRemoved = (removed) => unawaited(notifier.removed(removed));
    await messages.start();
    discovery = DiscoveryService(
      radio: radio,
      bluetooth: bluetooth,
      mode: _mode,
      config: discoveryOverride,
      clock: clock,
      log: log,
    );
    _fingerprintText = Fingerprints.formatHex(await crypto.identity.fingerprint());

    _subs
      ..add(bus.stream.listen((c) {
        switch (c) {
          case DataChange.peers:
            _markDirty(_Slice.peers);
          case DataChange.conversations:
          case DataChange.messages:
            _markDirty(_Slice.conversations);
          case DataChange.groups:
            _markDirty(_Slice.groups);
            _markDirty(_Slice.conversations);
          case DataChange.rooms:
            _markDirty(_Slice.rooms);
            _markDirty(_Slice.conversations);
          case DataChange.media:
          case DataChange.securityEvents:
            break;
        }
      }))
      ..add(messages.incoming.listen((notice) => unawaited(notifier.onNotice(notice))))
      ..add(table.changes.listen((_) {
        _markDirty(_Slice.peers);
        _publishNetwork();
      }))
      ..add(bluetooth.linksChanged.listen((_) => _publishNetwork()))
      ..add(discovery.changes.listen((_) => _publishNetwork()))
      ..add(radio.statusChanges.listen((_) => _publishNetwork()));
  }

  Future<void> _disposeServices() async {
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    try {
      await discovery.dispose();
      await router.stop();
      await bluetooth.dispose();
      await radio.dispose();
      await messages.dispose();
    } catch (e) {
      log.w('App', 'error while stopping services: $e');
    }
  }

  Future<void> _refreshAll() async {
    for (final s in _Slice.values) {
      await _refresh(s);
    }
    _publishNetwork();
    _scheduleNotify();
  }

  /// Starts Bluetooth: creates the platform managers (which makes iOS show
  /// its permission prompt), then the link layer, router and discovery.
  Future<void> startNetworking() async {
    if (_started || _starting || _disposed) return;
    _starting = true;
    _startError = null;
    _publishNetwork();
    notifyListeners();
    try {
      await radio.initialize();
      await bluetooth.start();
      await router.start();
      await discovery.start();
      _started = true;
      unawaited(_syncKeepAlive());
    } catch (e) {
      // Kept as the system's own words; the screens put "Bluetooth could not
      // start" above them in the language of the app.
      _startError = '$e';
      log.e('App', 'Bluetooth could not be started: $e');
    } finally {
      _starting = false;
      _publishNetwork();
      notifyListeners();
    }
  }

  Future<void> stopNetworking() async {
    if (!_started) return;
    _started = false;
    await discovery.stop();
    await router.stop();
    await bluetooth.stop();
    unawaited(io.keepAlive.stop());
    _publishNetwork();
    notifyListeners();
  }

  // Long-running work (starting Bluetooth, a database read) can finish after
  // the controller was disposed; its late updates must be dropped, not thrown.
  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _notifyTimer?.cancel();
    _refreshTimer?.cancel();
    _housekeeping?.cancel();
    _liveTimer?.cancel();
    unawaited(_disposeServices().whenComplete(() => bus.dispose()));
    unawaited(io.dispose());
    for (final n in [
      conversationsListenable,
      peersListenable,
      groupsListenable,
      roomsListenable,
      unreadListenable,
      networkListenable,
      openRequest,
      liveChanges,
    ]) {
      n.dispose();
    }
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Publishing: only real changes reach the screens
  // ---------------------------------------------------------------------------

  void _scheduleNotify() {
    if (_disposed || (_notifyTimer?.isActive ?? false)) return;
    _notifyTimer = Timer(const Duration(milliseconds: 80), () {
      if (!_disposed) notifyListeners();
    });
  }

  void _publish<T>(ValueNotifier<T> notifier, T value, String signature) {
    if (_disposed || _published[notifier] == signature) return;
    _published[notifier] = signature;
    notifier.value = value;
  }

  void _markDirty(_Slice slice) {
    if (_disposed) return;
    _dirty.add(slice);
    _refreshTimer ??= Timer(const Duration(milliseconds: 60), () {
      _refreshTimer = null;
      final todo = _dirty.toList();
      _dirty.clear();
      for (final s in todo) {
        unawaited(_refresh(s));
      }
    });
  }

  Future<void> _refresh(_Slice slice) async {
    if (_disposed) return;
    switch (slice) {
      case _Slice.peers:
        final peers = await repo.listPeers();
        if (_disposed) return;
        final views = [for (final p in peers) PeerView(p, table.statusOf(p.id))]..sort((a, b) {
            int rank(PeerView v) => switch (v.status.reachability) {
                  Reachability.direct => 0,
                  Reachability.relayed => 1,
                  Reachability.offline => 2,
                };
            final byReach = rank(a).compareTo(rank(b));
            if (byReach != 0) return byReach;
            if (a.peer.isContact != b.peer.isContact) return a.peer.isContact ? -1 : 1;
            return b.peer.lastSeenMs.compareTo(a.peer.lastSeenMs);
          });
        _publish(
          peersListenable,
          views,
          views
              .map((v) => '${v.peer.id}|${v.peer.displayName}|${v.peer.verified}|'
                  '${v.peer.isContact}|${v.peer.blocked}|${v.status}|'
                  '${v.peer.lastSeenMs ~/ 60000}')
              .join(';'),
        );
        _publishNetwork();
      case _Slice.conversations:
        final list = await repo.listConversations();
        final unread = await repo.totalUnread();
        if (_disposed) return;
        _publish(
          conversationsListenable,
          list,
          list
              .map((c) => '${c.id}|${c.title}|${c.lastMessagePreview}|${c.lastMessageAtMs}|'
                  '${c.unreadCount}')
              .join(';'),
        );
        _publish(unreadListenable, unread, '$unread');
      case _Slice.groups:
        final list = await groupRepo.listGroups();
        if (_disposed) return;
        _publish(
          groupsListenable,
          list,
          list
              .map((g) => '${g.id}|${g.name}|${g.state.name}|${g.epoch}|'
                  '${g.members.map((m) => '${m.id}:${m.nickname}').join(',')}')
              .join(';'),
        );
      case _Slice.rooms:
        final list = await roomRepo.listRooms();
        if (_disposed) return;
        _publish(
          roomsListenable,
          list,
          list
              .map((r) => '${r.id}|${r.name}|${r.description}|${r.joined}|${r.version}|'
                  '${r.lastHeardAtMs ~/ 60000}')
              .join(';'),
        );
    }
  }

  void _publishNetwork() {
    if (_disposed) return;
    // Phones turned away for another protocol version: those of the last few
    // minutes, and only those after the person last dismissed the notice.
    final windowStart = clock.nowMs - versionNoticeWindow.inMilliseconds;
    final otherVersions = bluetooth.versionMismatchesAfter(
        windowStart > _versionNoticeDismissedAtMs ? windowStart : _versionNoticeDismissedAtMs);
    final snapshot = NetworkSnapshot(
      radioStatus: radio.status,
      radioError: radio.lastError,
      advertising: radio.isAdvertising,
      scanning: discovery.isScanning,
      neighborCount: bluetooth.neighbors.length,
      reachableCount: table.reachablePeerIds.length,
      starting: _starting,
      started: _started,
      startError: _startError,
      newerVersionNearby: otherVersions.any((m) => m.peerIsNewer),
      olderVersionNearby: otherVersions.any((m) => !m.peerIsNewer),
    );
    if (snapshot != networkListenable.value) networkListenable.value = snapshot;
    _pingLive();
  }

  void _pingLive() {
    if (_disposed || (_liveTimer?.isActive ?? false)) return;
    _liveTimer = Timer(const Duration(milliseconds: 250), () {
      if (!_disposed) liveChanges.ping();
    });
  }

  void _tick() {
    if (_disposed) return;
    _ticks++;
    _markDirty(_Slice.peers);
    _publishNetwork();
    // Every five minutes: give up on incomplete files, forget lapsed rooms.
    if (_ticks % 60 == 0) unawaited(_maintain());
  }

  Future<void> _maintain() async {
    try {
      await messages.maintain();
      await _applyRetention();
    } catch (e) {
      log.w('App', 'maintenance failed: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // State for the UI
  // ---------------------------------------------------------------------------

  String get nickname => _nickname;

  /// The language of the app (Kurdish until the person picks another).
  AppLanguage get language => _language;

  /// The app's own text in the language being shown, for what is said outside
  /// the widgets: errors from the services, notifications.
  AppLocalizations get l10n => _language.strings;

  String get identityId => crypto.identity.id;

  /// 64 hex characters in groups of four.
  String get fingerprintText => _fingerprintText;

  DiscoveryMode get discoveryMode => _mode;

  bool get onboardingDone => _onboardingDone;

  /// The identity could not be loaded from secure storage although earlier
  /// data exists, so a new one was generated.
  bool get identityWasReset => _identityWasReset;

  int get retentionDays => _retentionDays;

  bool get networkingStarted => _started;

  bool get networkingStarting => _starting;

  String? get startError => _startError;

  RadioStatus get radioStatus => radio.status;

  String? get radioError => radio.lastError;

  bool get isAdvertising => radio.isAdvertising;

  bool get isScanning => discovery.isScanning;

  List<PeerView> get peers => peersListenable.value;

  List<PeerView> get reachablePeers => peers.where((p) => p.isReachable).toList();

  List<Conversation> get conversations => conversationsListenable.value;

  List<GroupChat> get groups => groupsListenable.value;

  List<PublicRoom> get rooms => roomsListenable.value;

  int get totalUnread => unreadListenable.value;

  List<NearbyDevice> get nearbyDevices => discovery.devices;

  List<LinkSnapshot> get links => bluetooth.linkSnapshots;

  int get neighborCount => bluetooth.neighbors.length;

  RouterStats get routerStats => router.stats;

  Stream<IncomingNotice> get incoming => messages.incoming;

  PeerStatus statusOf(String peerId) => table.statusOf(peerId);

  Future<NetworkKind> networkKind() => network.current();

  Stream<NetworkKind> get networkChanges => network.changes;

  // ---------------------------------------------------------------------------
  // Settings
  // ---------------------------------------------------------------------------

  Future<void> setNickname(String raw) async {
    final cleaned = sanitizeDisplayName(raw);
    _nickname = cleaned.isEmpty ? _defaultNickname() : cleaned;
    await repo.setSetting(_kNickname, _nickname);
    notifyListeners();
    // Tell neighbours straight away.
    unawaited(router.announceNow());
  }

  /// Switches the language of the whole app, at once and for good.
  Future<void> setLanguage(AppLanguage language) async {
    if (_language == language) return;
    _language = language;
    await repo.setSetting(_kLanguage, language.code);
    notifyListeners();
    // The ongoing notification of the background service is in the app's language.
    if (_keepAliveEnabled && _started) unawaited(_syncKeepAlive());
  }

  Future<void> setDiscoveryMode(DiscoveryMode mode) async {
    _mode = mode;
    discovery.setMode(mode);
    await repo.setSetting(_kMode, mode.name);
    notifyListeners();
  }

  // ---- notifications, relaying and the background ------------------------------------

  bool get notificationsEnabled => _notificationsEnabled;

  NotificationPrivacy get notificationPrivacy => _notificationPrivacy;

  bool get notifyPublicRooms => _notifyPublic;

  /// Whether this phone passes messages on for other people.
  bool get relayEnabled => _relayEnabled;

  bool get keepAliveEnabled => _keepAliveEnabled;

  bool get keepAliveSupported => io.keepAlive.supported;

  Future<void> setNotificationsEnabled(bool on) async {
    _notificationsEnabled = on;
    await repo.setSetting(_kNotify, on ? '1' : '0');
    if (!on) await notifier.clearedAll();
    notifyListeners();
  }

  Future<void> setNotificationPrivacy(NotificationPrivacy privacy) async {
    _notificationPrivacy = privacy;
    await repo.setSetting(_kNotifyPrivacy, privacy.name);
    notifyListeners();
  }

  Future<void> setNotifyPublicRooms(bool on) async {
    _notifyPublic = on;
    await repo.setSetting(_kNotifyPublic, on ? '1' : '0');
    notifyListeners();
  }

  /// "Help relay messages for others". Off: the phone still receives and sends
  /// its own, but carries nothing for anyone else.
  Future<void> setRelayEnabled(bool on) async {
    _relayEnabled = on;
    router.relayForOthers = on;
    await repo.setSetting(_kRelay, on ? '1' : '0');
    notifyListeners();
  }

  /// "Keep the mesh running in the background". Returns whether it is running
  /// now; the system may refuse (and iPhone has nothing to offer).
  Future<bool> setKeepAlive(bool on) async {
    _keepAliveEnabled = on;
    await repo.setSetting(_kKeepAlive, on ? '1' : '0');
    var running = false;
    if (on) {
      running = await io.keepAlive.start(texts: _keepAliveTexts());
      if (!running) await _keepAliveRefused();
    } else {
      await io.keepAlive.stop();
    }
    notifyListeners();
    return running || !on;
  }

  /// The service could not be started, at once or a moment later: make sure
  /// nothing is left half-started, and do not leave the switch claiming
  /// something that is not so.
  Future<void> _keepAliveRefused() async {
    await io.keepAlive.stop();
    _keepAliveEnabled = false;
    await repo.setSetting(_kKeepAlive, '0');
  }

  KeepAliveTexts _keepAliveTexts() => KeepAliveTexts(
        title: l10n.keepAliveTitle,
        text: l10n.keepAliveText,
        channelName: l10n.keepAliveChannelName,
        channelDescription: l10n.keepAliveChannelDescription,
      );

  Future<void> _syncKeepAlive() async {
    if (_disposed) return;
    if (_keepAliveEnabled && _started) {
      final running = await io.keepAlive.start(texts: _keepAliveTexts());
      if (!running && !_disposed && _keepAliveEnabled) {
        log.w('App', 'the background service could not be started; its switch is now off');
        await _keepAliveRefused();
        notifyListeners();
      }
    } else {
      await io.keepAlive.stop();
    }
  }

  /// Whether the app is on the screen right now.
  bool get isForeground => _foreground;

  /// The app came to the screen or went away. Notifications are only for when
  /// it is away; coming back clears them (the unread badges take over), and
  /// Android only allows starting the background service from the screen.
  void setForeground(bool foreground) {
    if (_foreground == foreground) return;
    _foreground = foreground;
    if (foreground) {
      _inBackground('clearing the notifications', notifier.clearedAll);
      _inBackground('syncing the background service', _syncKeepAlive);
      // Whatever ran out of time while the app was away goes before anything is shown.
      _inBackground('cleaning the public rooms', () async {
        await messages.publicCleanup.run();
      });
    }
  }

  /// Starts [job] and does not wait for it. A failure is written to the log: left
  /// alone it would be an error nobody is waiting for, in a zone nobody watches.
  void _inBackground(String what, Future<void> Function() job) {
    unawaited(() async {
      try {
        await job();
      } catch (e) {
        log.w('App', '$what failed: $e');
      }
    }());
  }

  // ---- storage -----------------------------------------------------------------------

  /// What this phone keeps, for the storage screen.
  Future<StorageUsage> storageUsage() async {
    final media = await mediaRepo.usage();
    var dbBytes = 0;
    try {
      dbBytes = await File(database.path).length();
    } catch (_) {
      // An in-memory database (tests) or a file that is not there.
    }
    final cleanup = await repo.lastPublicCleanup();
    return StorageUsage(
      messages: await repo.messageCount(),
      mediaCount: media.count,
      mediaBytes: media.bytes,
      publicMessages: await repo.publicMessageCount(),
      databaseBytes: dbBytes,
      lastCleanupAtMs: cleanup?.at,
      lastCleanupRemoved: cleanup?.removed ?? 0,
    );
  }

  /// Removes every picture, voice message and video from this phone, with their
  /// messages (nobody else is told). Returns how many messages went.
  Future<int> deleteAllMedia() async {
    var removed = 0;
    for (final e in (await repo.mediaMessageIds()).entries) {
      removed += (await messages.actions.deleteForMe(e.key, e.value)).removed;
    }
    return removed;
  }

  Future<void> setRetentionDays(int days) async {
    _retentionDays = days;
    await repo.setSetting(_kRetentionDays, '$days');
    await _applyRetention();
    notifyListeners();
  }

  Future<void> _applyRetention() async {
    if (_retentionDays <= 0) return;
    final cutoff = clock.nowMs - Duration(days: _retentionDays).inMilliseconds;
    if (await repo.pruneMessagesBefore(cutoff) > 0) {
      await messages.media.sweepFiles();
    }
  }

  Future<void> completeOnboarding() async {
    _onboardingDone = true;
    await repo.setSetting(_kOnboarded, '1');
    notifyListeners();
    await startNetworking();
  }

  void dismissIdentityNotice() {
    _identityWasReset = false;
    notifyListeners();
  }

  /// How long a phone that speaks another protocol version is mentioned after it
  /// was last turned away.
  static const Duration versionNoticeWindow = Duration(minutes: 10);

  /// When the person last dismissed that notice: only phones turned away after
  /// it bring it back.
  int _versionNoticeDismissedAtMs = 0;

  /// Hides the notice about phones with another version of the app until another
  /// such phone is turned away.
  void dismissVersionNotice() {
    _versionNoticeDismissedAtMs = clock.nowMs;
    _publishNetwork();
  }

  // ---------------------------------------------------------------------------
  // Bluetooth permission and power
  // ---------------------------------------------------------------------------

  Future<void> requestPermissions() async {
    if (!_started) await startNetworking();
    await radio.requestPermissions();
    _publishNetwork();
    notifyListeners();
  }

  Future<void> openSystemSettings() => radio.openAppSettings();

  // ---------------------------------------------------------------------------
  // Messaging (private chats, groups and public rooms alike)
  // ---------------------------------------------------------------------------

  /// The conversation with [peerId], created if needed.
  Future<Conversation> openChat(String peerId) async {
    final peer = await repo.getPeer(peerId);
    if (peer == null) {
      throw MessageError(MessageErrorKind.unknownPeer, l10n.errUnknownContact);
    }
    final c = await repo.ensureDirectConversation(peer, nowMs: clock.nowMs);
    await _refresh(_Slice.conversations);
    return c;
  }

  Future<Conversation?> conversation(String id) => repo.getConversation(id);

  Future<ChatMessage> sendText(String conversationId, String text, {String? replyToId}) =>
      messages.sendText(conversationId, text, replyToId: replyToId);

  // ---- message actions ----------------------------------------------------------

  /// Edits one of our own text messages, here and on the phones that have it.
  Future<ChatMessage> editMessage(String messageId, String text) =>
      messages.actions.edit(messageId, text);

  /// Removes messages from this phone only.
  Future<DeleteResult> deleteForMe(String conversationId, List<String> ids) =>
      messages.actions.deleteForMe(conversationId, ids);

  /// Removes messages here and asks every other phone in the conversation to.
  Future<DeleteResult> deleteForEveryone(String conversationId, List<String> ids) =>
      messages.actions.deleteForEveryone(conversationId, ids);

  /// Sends copies of the messages to another conversation.
  Future<List<ChatMessage>> forwardMessages(List<String> ids, String targetConversationId) =>
      messages.forward(ids, targetConversationId);

  /// Pins or unpins a message for this person only.
  Future<bool> setPinned(String conversationId, String messageId, bool pinned) =>
      messages.setPinned(conversationId, messageId, pinned);

  Future<List<ChatMessage>> pinnedMessages(String conversationId) =>
      repo.pinnedMessages(conversationId);

  Future<List<ChatMessage>> searchMessages(
    String conversationId, {
    String query = '',
    Set<MessageKind>? kinds,
    String? senderId,
  }) =>
      repo.searchMessages(conversationId, query: query, kinds: kinds, senderId: senderId);

  Future<ChatMessage?> messageById(String id) => repo.getMessage(id);

  Future<List<ChatMessage>> messagesByIds(Iterable<String> ids) => repo.getMessagesByIds(ids);

  /// How our own "delete for everyone" requests in a chat are doing, by state.
  Future<Map<String, int>> deletionRequests(String conversationId) =>
      repo.deletionRequestCounts(conversationId);

  /// The members of a group who confirmed receiving one of our messages.
  Future<Set<String>> receiptMembers(String messageId) => repo.receiptMembers(messageId);

  /// Runs the public-chat clean-up now (it also runs by itself).
  Future<CleanupResult> cleanPublicChats() => messages.publicCleanup.run();

  Future<ChatMessage> sendMedia(String conversationId, MediaDraft draft) =>
      messages.sendMedia(conversationId, draft);

  Future<ChatMessage> sendDirect(String peerId, String text) => messages.sendDirect(peerId, text);

  /// Shrinks a photo to something a Bluetooth mesh can carry. Throws an
  /// [ImageCompressionException] the UI can show.
  Future<MediaDraft> prepareImage(Uint8List raw, {String caption = ''}) async {
    final c = await io.compressor.compress(raw);
    return MediaDraft(
      kind: MediaKind.image,
      bytes: c.bytes,
      width: c.width,
      height: c.height,
      caption: caption,
    );
  }

  /// The largest video, in bytes, this phone will send.
  static const int defaultVideoSendLimit = 256 * 1024;

  /// What the person can choose as their sending limit.
  static const List<int> videoLimitChoices = <int>[128 * 1024, 256 * 1024, 512 * 1024];

  static int _clampVideoLimit(int bytes) => videoLimitChoices.contains(bytes) ? bytes : defaultVideoSendLimit;

  int get videoSendLimit => _videoLimit;

  Future<void> setVideoSendLimit(int bytes) async {
    _videoLimit = _clampVideoLimit(bytes);
    messages.media.maxVideoSendBytes = _videoLimit;
    await repo.setSetting(_kVideoLimit, '$_videoLimit');
    notifyListeners();
  }

  /// A picked video, ready to send. It must be within the sending limit.
  MediaDraft videoDraft(PickedVideo video, {String caption = ''}) {
    final bytes = video.bytes;
    if (bytes == null) {
      throw MessageError(MessageErrorKind.mediaTooLarge, l10n.errVideoTooLarge);
    }
    return MediaDraft(kind: MediaKind.video, bytes: bytes, caption: caption);
  }

  /// Copies a received (or sent) picture or video to the phone's gallery. Throws a
  /// [GalleryException] with something to tell the person.
  Future<void> saveToGallery(MediaItem item) async {
    switch (item.kind) {
      case MediaKind.image:
        final bytes = await mediaBytes(item);
        if (bytes == null) {
          throw const GalleryException('That picture is no longer on this phone.',
              problem: GalleryProblem.pictureGone);
        }
        await io.gallery.saveImage(bytes);
      case MediaKind.video:
        final path = await mediaPath(item);
        if (path == null) {
          throw const GalleryException('That video cannot be saved from this phone.',
              problem: GalleryProblem.videoGone);
        }
        await io.gallery.saveVideo(path);
      case MediaKind.voice:
        throw const GalleryException('Voice messages cannot be saved to the gallery.',
            problem: GalleryProblem.voice);
    }
  }

  /// Hands the text and the pictures, videos and recordings of [selected]
  /// messages to the system share sheet. [media] holds the files that are known.
  Future<void> shareMessages(List<ChatMessage> selected, Map<String, MediaItem> media) async {
    final lines = <String>[];
    final files = <SharedFile>[];
    for (final m in selected) {
      if (m.status == MessageStatus.undecryptable) continue;
      if (m.body.isNotEmpty) lines.add(m.body);
      final item = m.mediaId == null ? null : media[m.mediaId];
      if (item == null || !item.isReady) continue;
      final path = await mediaPath(item);
      final bytes = path == null ? await mediaBytes(item) : null;
      if (path == null && bytes == null) continue;
      final ext = MediaMime.extension(item.mimeCode);
      files.add(SharedFile(
        path: path,
        bytes: bytes,
        name: '${item.id.substring(0, 8)}.$ext',
        mimeType: switch (item.kind) {
          MediaKind.image => 'image/jpeg',
          MediaKind.video => 'video/mp4',
          MediaKind.voice => 'audio/mp4',
        },
      ));
    }
    if (files.isEmpty && lines.isEmpty) {
      throw MessageError(MessageErrorKind.notAllowed, l10n.errNothingToShare);
    }
    if (files.isEmpty) {
      await io.sharer.shareText(lines.join('\n'));
    } else {
      await io.sharer.shareFiles(files, text: lines.isEmpty ? null : lines.join('\n'));
    }
  }

  MediaDraft voiceDraft(RecordedVoice v) => MediaDraft(
        kind: MediaKind.voice,
        bytes: v.bytes,
        durationMs: v.duration.inMilliseconds,
        waveform: v.waveform,
      );

  Future<ChatMessage> retry(String messageId) => messages.retry(messageId);

  Future<void> markRead(String conversationId) async {
    await repo.markConversationRead(conversationId);
    unawaited(notifier.cleared(conversationId));
  }

  Future<List<ChatMessage>> loadMessages(String conversationId, {int limit = 300}) =>
      repo.getMessages(conversationId, limit: limit);

  /// Image / voice metadata for the given media ids, keyed by media id.
  Future<Map<String, MediaItem>> loadMedia(Iterable<String> mediaIds) => mediaRepo.getMany(mediaIds);

  Future<Uint8List?> mediaBytes(MediaItem item) => messages.media.read(item);

  final Map<String, Uint8List> _bytesCache = <String, Uint8List>{};

  /// Like [mediaBytes], but remembers the last few pictures so scrolling back
  /// through a chat does not read and decode them again.
  Future<Uint8List?> cachedMediaBytes(MediaItem item) async {
    final hit = _bytesCache.remove(item.id);
    if (hit != null) {
      _bytesCache[item.id] = hit;
      return hit;
    }
    final bytes = await messages.media.read(item);
    if (bytes != null) {
      _bytesCache[item.id] = bytes;
      while (_bytesCache.length > 40) {
        _bytesCache.remove(_bytesCache.keys.first);
      }
    }
    return bytes;
  }

  /// A file path for APIs that need one (audio playback), or null.
  Future<String?> mediaPath(MediaItem item) => messages.media.pathOf(item);

  /// Every change to messages, groups, rooms and media, for screens that show
  /// a conversation.
  Stream<DataChange> get dataChanges => bus.stream;

  // The mutating actions below refresh the cached lists before returning, so
  // a screen that reads them right after `await` never sees stale data.

  Future<void> _refreshConversationLists() async {
    await _refresh(_Slice.conversations);
    await _refresh(_Slice.groups);
    await _refresh(_Slice.rooms);
  }

  /// Removes a private chat. Groups and rooms have their own leave actions;
  /// for those this leaves (or forgets) them.
  Future<void> deleteConversation(String id) async {
    final c = await repo.getConversation(id);
    if (c == null) return;
    switch (c.type) {
      case ConversationType.direct:
        await repo.deleteConversation(id);
      case ConversationType.group:
        await removeGroupFromPhone(c.groupId!);
      case ConversationType.room:
        await leaveRoom(c.roomId!);
    }
    await messages.media.sweepFiles();
    await _refreshConversationLists();
  }

  // ---- groups ------------------------------------------------------------------

  Future<GroupChat?> group(String id) => groupRepo.getGroup(id);

  Future<GroupChat> createGroup(String name, List<String> memberIds) async {
    final g = await messages.groups.create(name: name, memberIds: memberIds);
    await _refreshConversationLists();
    return g;
  }

  Future<GroupChat> acceptGroup(String id) async {
    final g = await messages.groups.accept(id);
    await _refreshConversationLists();
    return g;
  }

  Future<void> declineGroup(String id) async {
    await messages.groups.decline(id);
    await _refreshConversationLists();
  }

  Future<void> leaveGroup(String id) async {
    await messages.groups.leave(id);
    await _refreshConversationLists();
  }

  /// The admin ends the group for everybody.
  Future<void> deleteGroup(String id) async {
    await messages.groups.deleteAsAdmin(id);
    await messages.media.sweepFiles();
    await _refreshConversationLists();
  }

  Future<GroupChat> addGroupMembers(String id, List<String> memberIds) async {
    final g = await messages.groups.addMembers(id, memberIds);
    await _refreshConversationLists();
    return g;
  }

  Future<GroupChat> removeGroupMember(String id, String memberId) async {
    final g = await messages.groups.removeMember(id, memberId);
    await _refreshConversationLists();
    return g;
  }

  /// Takes a group (and its chat) off this phone: leaves it if we are still in
  /// it, or just forgets it if we already left or were removed.
  Future<void> removeGroupFromPhone(String id) async {
    final g = await groupRepo.getGroup(id);
    if (g != null) {
      if (g.state == GroupState.active) {
        if (g.adminId == identityId) {
          await messages.groups.deleteAsAdmin(id);
        } else {
          await messages.groups.leave(id);
        }
      } else if (g.state == GroupState.invited) {
        await messages.groups.decline(id);
      }
      await groupRepo.delete(id);
      await messages.groups.keyring.remove(id);
    }
    await repo.deleteConversation(Conversation.groupConversationId(id));
    await messages.media.sweepFiles();
    await _refreshConversationLists();
  }

  // ---- public rooms ------------------------------------------------------------

  Future<PublicRoom?> room(String id) => roomRepo.getRoom(id);

  Future<PublicRoom> createRoom(String name, {String description = ''}) async {
    final room = await messages.rooms.create(name: name, description: description);
    await _refreshConversationLists();
    return room;
  }

  Future<PublicRoom> joinRoom(String id) async {
    final room = await messages.rooms.join(id);
    await _refreshConversationLists();
    return room;
  }

  Future<void> leaveRoom(String id) async {
    await messages.rooms.leave(id);
    await messages.media.sweepFiles();
    await _refreshConversationLists();
  }

  // ---------------------------------------------------------------------------
  // Contacts and verification
  // ---------------------------------------------------------------------------

  Future<Peer?> peer(String id) => repo.getPeer(id);

  Future<String?> safetyNumberFor(Peer peer) async {
    final agreement = peer.agreementKey;
    if (agreement == null) return null;
    return crypto.safetyNumberWith(
      remoteSigningKey: peer.signingKey,
      remoteAgreementKey: agreement,
    );
  }

  Future<String?> fingerprintFor(Peer peer) async {
    final agreement = peer.agreementKey;
    if (agreement == null) return null;
    return Fingerprints.formatHex(
      await Fingerprints.of(signingKey: peer.signingKey, agreementKey: agreement),
    );
  }

  Future<void> setVerified(String peerId, bool verified) async {
    await repo.setVerified(peerId, verified);
    await _refresh(_Slice.peers);
  }

  Future<void> setAlias(String peerId, String? alias) async {
    await repo.setAlias(peerId, alias);
    await _refresh(_Slice.peers);
    await _refresh(_Slice.conversations);
  }

  Future<void> setBlocked(String peerId, bool blocked) async {
    await repo.setBlocked(peerId, blocked);
    await _refresh(_Slice.peers);
  }

  Future<void> deletePeer(String peerId) async {
    await repo.deletePeer(peerId);
    await messages.media.sweepFiles();
    await _refresh(_Slice.peers);
    await _refresh(_Slice.conversations);
  }

  Future<List<SecurityEvent>> securityEvents() => repo.securityEvents(limit: 200);

  Future<void> clearSecurityEvents() => repo.clearSecurityEvents();

  // ---------------------------------------------------------------------------
  // Diagnostics
  // ---------------------------------------------------------------------------

  BleSelfTest createSelfTest() => BleSelfTest(
        radio: radio,
        bluetooth: bluetooth,
        discovery: discovery,
        table: table,
        device: deviceInfo,
        network: network,
        strings: () => l10n,
      );

  // ---------------------------------------------------------------------------
  // Destructive actions (callers must have obtained explicit confirmation)
  // ---------------------------------------------------------------------------

  /// Generates a brand-new identity. Existing chats stay readable on this
  /// phone, but everyone must verify the new keys again, messages addressed to
  /// the old identity can no longer be decrypted, and groups (whose member
  /// lists name the old identity) can no longer be taken part in.
  Future<void> resetIdentity() async {
    final wasStarted = _started;
    await _teardownForRebuild();
    final keyring = GroupKeyring(keyStore);
    for (final g in await groupRepo.listGroups(states: [GroupState.active, GroupState.invited])) {
      await groupRepo.setState(g.id, GroupState.removed);
      await keyring.remove(g.id);
    }
    crypto = await EncryptionService.createFresh(keyStore, clock: clock);
    await repo.setSetting(_kIdentity, crypto.identity.id);
    await outbox.clearAll();
    await _rebuild(restart: wasStarted);
  }

  /// Deletes every message, contact, group, room, file and key, and creates a
  /// fresh identity. Cannot be undone.
  Future<void> clearAllData() async {
    final wasStarted = _started;
    await _teardownForRebuild();
    await database.deleteAllData();
    await keyStore.deleteAll();
    crypto = await EncryptionService.createFresh(keyStore, clock: clock);
    await repo.setSetting(_kIdentity, crypto.identity.id);
    await repo.setSetting(_kOnboarded, '1');
    // The person keeps reading the app in the language they chose; the wipe took
    // the stored choice with every other setting, so it is written again.
    await repo.setSetting(_kLanguage, _language.code);
    _nickname = _defaultNickname();
    _mode = DiscoveryMode.balanced;
    _retentionDays = 0;
    _notificationsEnabled = true;
    _notificationPrivacy = NotificationPrivacy.sender;
    _notifyPublic = false;
    _relayEnabled = true;
    _keepAliveEnabled = false;
    _videoLimit = defaultVideoSendLimit;
    unawaited(io.keepAlive.stop());
    unawaited(notifier.clearedAll());
    _bytesCache.clear();
    // Nothing refers to any file now, so every one of them goes.
    for (final f in await mediaStore.list()) {
      await mediaStore.delete(f.name);
    }
    await _rebuild(restart: wasStarted);
  }

  Future<void> _teardownForRebuild() async {
    _started = false;
    await _disposeServices();
  }

  Future<void> _rebuild({required bool restart}) async {
    _published.clear();
    await _buildServices();
    await _refreshAll();
    notifyListeners();
    if (restart) await startNetworking();
  }
}
