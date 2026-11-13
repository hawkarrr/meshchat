import 'dart:async';
import 'dart:typed_data';

import '../core/app_log.dart';
import '../core/clock.dart';
import '../core/serial_executor.dart';
import '../crypto/signatures.dart';
import '../database/message_repository.dart' show SecurityEventKind;
import '../database/outbox_repository.dart';
import '../protocol/mesh_packet.dart';
import '../protocol/packet_payloads.dart';
import '../protocol/room_record.dart';
import '../transport/mesh_transport.dart';
import 'duplicate_filter.dart';
import 'message_queue.dart';
import 'peer_table.dart';
import 'rate_limiter.dart';
import 'relay_manager.dart';

/// What the router needs from the layer above it (the message manager).
///
/// Callbacks run inside the router's inbound pipeline: they must not wait on
/// work that itself waits for the pipeline (calling [MeshRouter.submit] is
/// fine; it never blocks on inbound processing).
abstract interface class MeshDelegate {
  /// Whether this phone is an active member of the group with this id. Packets
  /// of other groups are still carried onward, just not opened.
  Future<bool> wantsGroup(Uint8List groupId);

  /// Whether this phone has joined the public room with this id.
  Future<bool> wantsRoom(Uint8List roomId);

  /// A direct packet addressed to us: a message, a media manifest, a group
  /// invitation, or (see [MeshPacket.isChunk]) one chunk of an image / voice
  /// message.
  Future<void> onDirectMessage(MeshPacket packet, {required int relayHops});

  /// A packet of a group we belong to (a message, or a chunk).
  Future<void> onGroupPacket(MeshPacket packet, {required int relayHops});

  /// A packet of a public room we joined (a message, or a chunk).
  Future<void> onRoomPacket(MeshPacket packet, {required int relayHops});

  /// A public-room announcement. Returns whether it was valid *and* news, i.e.
  /// worth passing on to the neighbours; stale repeats stop here.
  Future<bool> onRoomAnnounce(MeshPacket packet, RoomRecord record, {required int relayHops});

  Future<void> onAck(MeshPacket packet, AckContent ack, {required int relayHops});

  Future<void> onAnnounce(MeshPacket packet, AnnounceContent content, {required int relayHops});

  Future<void> onNeighborUp(NeighborInfo neighbor);

  Future<void> onNeighborDown(String peerId);

  /// A direct message addressed to us arrived again - its sender evidently
  /// never got our receipt.
  Future<void> onDuplicateDirect(MeshPacket packet);

  /// One of our own packets was handed to a neighbour for the first time.
  Future<void> onOwnPacketSent(MeshPacket packet);

  /// One of our own queued packets ran out of time undelivered.
  Future<void> onOwnPacketExpired(OutboxEntry entry);

  Future<void> onSecurityEvent(String kind, {String? peerId, String? detail});

  /// Builds a freshly signed announcement, or null when announcing is off.
  Future<MeshPacket?> buildAnnouncement();

  /// Freshly signed announcements of the public rooms worth telling
  /// neighbours about (rooms we created, joined or recently heard of).
  Future<List<MeshPacket>> buildRoomAnnouncements();
}

class MeshRouterConfig {
  const MeshRouterConfig({
    this.announceInterval = const Duration(seconds: 30),
    this.roomAnnounceInterval = const Duration(seconds: 90),
    this.flushInterval = const Duration(seconds: 5),
    this.maintenanceInterval = const Duration(seconds: 30),
    this.autoTimers = true,
    // An image is dozens of packets from one author arriving back to back, and
    // the largest video (512 KB) is 342 chunks, so the bursts are generous; BLE
    // itself is the real speed limit.
    this.inboundBurst = 400,
    this.inboundPerSecond = 40,
    this.senderBurst = 400,
    this.senderPerSecond = 25,
    this.announceBurst = 2,
    this.announcePerSecond = 0.1,
    this.roomAnnounceBurst = 12,
    this.roomAnnouncePerSecond = 0.5,
    this.maxStrikes = 12,
    this.strikeWindow = const Duration(minutes: 1),
    this.eventGap = const Duration(seconds: 30),
    this.maxRelayAttempts = 8,
    this.maxAckAttempts = 5,
  });

  final Duration announceInterval;

  /// How often the rooms we know are announced to our neighbours, so phones
  /// that arrive later learn about them.
  final Duration roomAnnounceInterval;
  final Duration flushInterval;
  final Duration maintenanceInterval;

  /// Tests switch the timers off and drive [MeshRouter.flush] /
  /// [MeshRouter.maintain] / [MeshRouter.announceNow] themselves.
  final bool autoTimers;

  /// Per-neighbour inbound allowance (burst, then per second).
  final double inboundBurst;
  final double inboundPerSecond;

  /// Per-author allowance, so one chatty phone cannot dominate relays.
  final double senderBurst;
  final double senderPerSecond;

  /// Per-author allowance for announcements (they are never needed often).
  final double announceBurst;
  final double announcePerSecond;

  /// Per-author allowance for room announcements (one packet per room).
  final double roomAnnounceBurst;
  final double roomAnnouncePerSecond;

  /// A neighbour that sends this many invalid/over-limit packets within
  /// [strikeWindow] is disconnected.
  final int maxStrikes;
  final Duration strikeWindow;

  /// Minimum gap between two identical security-log entries.
  final Duration eventGap;

  final int maxRelayAttempts;
  final int maxAckAttempts;
}

/// Counters shown on the diagnostics screen.
class RouterStats {
  int received = 0;
  int delivered = 0;
  int relayedIn = 0;
  int duplicates = 0;
  int invalid = 0;
  int expired = 0;
  int rateLimited = 0;
  int hopLimitDrops = 0;
  int sentOk = 0;
  int sentFailed = 0;

  /// Packets for other people that were not passed on because relaying is off.
  int relayRefused = 0;
}

enum SubmitOutcome { queued, duplicate, expired }

/// Multi-hop store-and-forward routing on top of a [MeshTransport].
///
/// Inbound pipeline for every packet from a neighbour (in order):
///  1. per-neighbour rate limit;  2. structural decode;  3. expiry;
///  4. duplicate check;  5. per-author rate limit;
///  6. Ed25519 signature verification - nothing below is trusted before this;
///  7. mark as seen;  8. act on it: deliver locally and/or forward.
///
/// Relays never decrypt anything: direct messages stay sealed for their
/// recipient, and the signature lets every relay discard forgeries.
class MeshRouter {
  MeshRouter({
    required this.transport,
    required this.localId,
    required this.table,
    required this.seen,
    required this.queue,
    required this.relay,
    this.config = const MeshRouterConfig(),
    this.clock = const SystemClock(),
    AppLog? log,
  })  : _log = log ?? AppLog.instance,
        _inboundLimiter = TokenBucketRateLimiter(
          capacity: config.inboundBurst,
          refillPerSecond: config.inboundPerSecond,
          clock: clock,
        ),
        _senderLimiter = TokenBucketRateLimiter(
          capacity: config.senderBurst,
          refillPerSecond: config.senderPerSecond,
          clock: clock,
        ),
        _announceLimiter = TokenBucketRateLimiter(
          capacity: config.announceBurst,
          refillPerSecond: config.announcePerSecond,
          clock: clock,
        ),
        _roomAnnounceLimiter = TokenBucketRateLimiter(
          capacity: config.roomAnnounceBurst,
          refillPerSecond: config.roomAnnouncePerSecond,
          clock: clock,
        );

  /// Whether this phone passes on packets that are not for it. The person can
  /// turn it off ("Help relay messages for others"): the phone then still
  /// receives everything addressed to it and to its groups and rooms, and sends
  /// its own, but carries nothing for anybody else.
  bool relayForOthers = true;

  final MeshTransport transport;

  /// Hex id (signing key) of this phone.
  final String localId;
  final PeerTable table;
  final DuplicateFilter seen;
  final MessageQueue queue;
  final RelayManager relay;
  final MeshRouterConfig config;
  final Clock clock;
  final AppLog _log;

  static const String _tag = 'Mesh';

  MeshDelegate? delegate;
  final RouterStats stats = RouterStats();

  final TokenBucketRateLimiter _inboundLimiter;
  final TokenBucketRateLimiter _senderLimiter;
  final TokenBucketRateLimiter _announceLimiter;
  final TokenBucketRateLimiter _roomAnnounceLimiter;

  /// Inbound pipeline: strictly sequential so "seen? then mark" is atomic.
  final SerialExecutor _rx = SerialExecutor();

  /// Outbound attempts: strictly sequential so queue bookkeeping is too.
  final SerialExecutor _tx = SerialExecutor();

  StreamSubscription<TransportEvent>? _sub;
  Timer? _announceTimer;
  Timer? _roomAnnounceTimer;
  Timer? _flushTimer;
  Timer? _maintainTimer;
  bool _running = false;

  final Map<String, List<int>> _strikes = <String, List<int>>{};
  final Map<String, int> _lastEventAt = <String, int>{};

  bool get isRunning => _running;

  /// True while any inbound or outbound task is queued or running.
  bool get isBusy => _rx.pending > 0 || _tx.pending > 0;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  Future<void> start() async {
    if (_running) return;
    _running = true;
    await seen.load();
    for (final n in transport.neighbors) {
      table.neighborUp(n);
    }
    _sub = transport.events.listen(_onTransportEvent);
    if (config.autoTimers) {
      _announceTimer = Timer.periodic(config.announceInterval, (_) => announceNow());
      _roomAnnounceTimer =
          Timer.periodic(config.roomAnnounceInterval, (_) => announceRoomsNow());
      _flushTimer = Timer.periodic(config.flushInterval, (_) => flush());
      _maintainTimer = Timer.periodic(config.maintenanceInterval, (_) => maintain());
    }
    _txGuarded(_flushDue);
  }

  Future<void> stop() async {
    _running = false;
    _announceTimer?.cancel();
    _roomAnnounceTimer?.cancel();
    _flushTimer?.cancel();
    _maintainTimer?.cancel();
    await _sub?.cancel();
    _sub = null;
    await settled();
  }

  /// Waits until both pipelines are idle. For tests and orderly shutdown.
  Future<void> settled() async {
    do {
      await _rx.idle;
      await _tx.idle;
    } while (_rx.pending > 0 || _tx.pending > 0);
  }

  // ---------------------------------------------------------------------------
  // Transport events
  // ---------------------------------------------------------------------------

  void _onTransportEvent(TransportEvent event) {
    switch (event) {
      case NeighborUp(:final info):
        _rxGuarded(() => _handleNeighborUp(info));
      case NeighborDown(:final peerId):
        _rxGuarded(() => _handleNeighborDown(peerId));
      case PacketReceived(:final fromPeerId, :final bytes):
        _rxGuarded(() => _handleInbound(fromPeerId, bytes));
    }
  }

  void _rxGuarded(Future<void> Function() task) {
    unawaited(_rx.run(task).catchError((Object e, StackTrace s) {
      _log.e(_tag, 'inbound task failed: $e');
    }));
  }

  void _txGuarded(Future<void> Function() task) {
    unawaited(_tx.run(task).catchError((Object e, StackTrace s) {
      _log.e(_tag, 'outbound task failed: $e');
    }));
  }

  Future<void> _handleNeighborUp(NeighborInfo info) async {
    table.neighborUp(info);
    _log.i(_tag, 'neighbor up ${info.peerId.substring(0, 8)} "${info.nickname}"');
    await delegate?.onNeighborUp(info);
    // A new neighbour may unblock queued messages and should hear about us.
    await queue.nudge();
    _txGuarded(_flushDue);
    if (config.autoTimers) {
      _txGuarded(_announce);
      _txGuarded(_announceRooms);
    }
  }

  Future<void> _handleNeighborDown(String peerId) async {
    table.neighborDown(peerId);
    _inboundLimiter.forget('in:$peerId');
    _strikes.remove(peerId);
    _log.i(_tag, 'neighbor down ${peerId.substring(0, 8)}');
    await delegate?.onNeighborDown(peerId);
  }

  // ---------------------------------------------------------------------------
  // Inbound pipeline
  // ---------------------------------------------------------------------------

  Future<void> _handleInbound(String fromId, Uint8List bytes) async {
    stats.received++;

    if (!_inboundLimiter.tryAcquire('in:$fromId')) {
      stats.rateLimited++;
      await _securityEvent(SecurityEventKind.rateLimited, fromId, 'neighbour exceeded inbound rate');
      await _strike(fromId);
      return;
    }

    final MeshPacket packet;
    try {
      packet = MeshPacket.decode(bytes);
    } on PacketFormatException catch (e) {
      stats.invalid++;
      await _securityEvent(SecurityEventKind.malformed, fromId, e.message);
      await _strike(fromId);
      return;
    }

    if (packet.isExpiredAt(clock.nowMs)) {
      stats.expired++;
      return;
    }

    final id = packet.messageIdHex;
    if (seen.contains(id)) {
      stats.duplicates++;
      await _handleDuplicate(packet, fromId);
      return;
    }

    final isAnnounce =
        packet.type == PacketType.announce || packet.type == PacketType.roomAnnounce;
    final limiter = switch (packet.type) {
      PacketType.announce => _announceLimiter,
      PacketType.roomAnnounce => _roomAnnounceLimiter,
      _ => _senderLimiter,
    };
    if (!limiter.tryAcquire('from:${packet.senderHex}')) {
      stats.rateLimited++;
      if (isAnnounce) {
        // Not an alarm: an honest phone announces itself each time a neighbour
        // connects, so a group arriving together legitimately exceeds the
        // allowance. The excess is simply dropped (the next periodic
        // announcement carries the same information).
        _log.d(_tag,
            'announcement from ${packet.senderHex.substring(0, 8)} dropped: too frequent');
      } else {
        await _securityEvent(SecurityEventKind.rateLimited, fromId,
            'author ${packet.senderHex.substring(0, 8)} exceeded rate');
      }
      return;
    }

    if (!await verifyPacketSignature(packet)) {
      // Deliberately NOT marked as seen: a forged copy must not be able to
      // suppress the genuine packet that follows.
      stats.invalid++;
      await _securityEvent(SecurityEventKind.badSignature, fromId,
          'invalid signature on ${packet.type.name}');
      await _strike(fromId);
      return;
    }

    await seen.mark(id, queue.retainUntil(packet));

    switch (packet.type) {
      case PacketType.announce:
        await _handleAnnounce(packet, fromId);
      case PacketType.direct:
        if (packet.recipientHex == localId) {
          stats.delivered++;
          await delegate?.onDirectMessage(packet, relayHops: packet.hops);
        } else {
          await _carry(packet, fromId);
        }
      case PacketType.group:
        // Everybody carries group traffic (it is sealed, so carrying it reveals
        // nothing); only members open it.
        if (packet.senderHex != localId && (await delegate?.wantsGroup(packet.recipientKey) ?? false)) {
          stats.delivered++;
          await delegate!.onGroupPacket(packet, relayHops: packet.hops);
        }
        await _carry(packet, fromId);
      case PacketType.room:
        if (packet.senderHex != localId && (await delegate?.wantsRoom(packet.recipientKey) ?? false)) {
          stats.delivered++;
          await delegate!.onRoomPacket(packet, relayHops: packet.hops);
        }
        await _carry(packet, fromId);
      case PacketType.roomAnnounce:
        await _handleRoomAnnounce(packet, fromId);
      case PacketType.ack:
        await _handleAck(packet, fromId);
    }
  }

  Future<void> _handleDuplicate(MeshPacket packet, String fromId) async {
    // Whoever sent it obviously has it already.
    await queue.recordNeighborHas(packet.messageIdHex, fromId);
    if (packet.type == PacketType.direct && packet.recipientHex == localId) {
      await delegate?.onDuplicateDirect(packet);
    }
  }

  Future<void> _handleRoomAnnounce(MeshPacket packet, String fromId) async {
    if (packet.senderHex == localId) return;
    final RoomRecord record;
    try {
      record = RoomRecord.parse(packet.payload);
    } on FormatException catch (e) {
      stats.invalid++;
      await _securityEvent(SecurityEventKind.malformed, fromId, 'room announcement: ${e.message}');
      return;
    }
    // Only a valid record that taught us something is passed on, so a room is
    // not shouted around the neighbourhood by every phone every time it is
    // heard.
    final worthForwarding = await delegate?.onRoomAnnounce(packet, record, relayHops: packet.hops) ?? false;
    if (worthForwarding) _forwardOnce(packet, fromId);
  }

  Future<void> _handleAnnounce(MeshPacket packet, String fromId) async {
    if (packet.senderHex == localId) return;
    final AnnounceContent content;
    try {
      content = AnnounceContent.parse(packet.payload);
    } on FormatException catch (e) {
      stats.invalid++;
      await _securityEvent(SecurityEventKind.malformed, fromId, 'announce: ${e.message}');
      return;
    }
    final routeChanged = table.learnRoute(
      destId: packet.senderHex,
      viaId: fromId,
      relayHops: packet.hops,
    );
    await delegate?.onAnnounce(packet, content, relayHops: packet.hops);
    if (routeChanged) {
      await queue.nudge();
      _txGuarded(_flushDue);
    }
    _forwardOnce(packet, fromId);
  }

  Future<void> _handleAck(MeshPacket packet, String fromId) async {
    final AckContent ack;
    try {
      ack = AckContent.parse(packet.payload);
    } on FormatException catch (e) {
      stats.invalid++;
      await _securityEvent(SecurityEventKind.malformed, fromId, 'ack: ${e.message}');
      return;
    }
    // The recipient confirmed receipt: nobody needs to keep carrying the
    // messages. Only the intended recipient's ack may cancel one.
    for (final id in ack.ackedMessageIdsHex) {
      await queue.cancelIfAckedBy(id, packet.senderHex);
    }
    if (packet.recipientHex == localId) {
      await delegate?.onAck(packet, ack, relayHops: packet.hops);
    } else {
      await _carry(packet, fromId);
    }
  }

  /// Store-and-forward a packet for somebody else: a directed packet (direct
  /// message or receipt), or a group / room packet that is offered to every
  /// neighbour that has not got it.
  Future<void> _carry(MeshPacket packet, String fromId) async {
    if (!relayForOthers) {
      stats.relayRefused++;
      return;
    }
    if (!packet.canBeRelayed) {
      stats.hopLimitDrops++;
      return;
    }
    final forwarded = packet.relayed();
    final outcome = await queue.enqueueRelay(forwarded);
    switch (outcome) {
      case EnqueueOutcome.stored:
        stats.relayedIn++;
        await queue.recordNeighborHas(forwarded.messageIdHex, fromId);
        final id = forwarded.messageIdHex;
        _txGuarded(() => _attemptById(id));
      case EnqueueOutcome.duplicate:
        await queue.recordNeighborHas(forwarded.messageIdHex, fromId);
      case EnqueueOutcome.rejectedSenderQuota:
        await _securityEvent(SecurityEventKind.rateLimited, fromId,
            'relay quota for ${packet.senderHex.substring(0, 8)} is full');
      case EnqueueOutcome.rejectedExpired:
        stats.expired++;
    }
  }

  /// Presence-style packets (announce, room announcement) are flooded once to
  /// the neighbours that are connected right now and are not persisted.
  void _forwardOnce(MeshPacket packet, String fromId) {
    if (!relayForOthers) {
      stats.relayRefused++;
      return;
    }
    if (!packet.canBeRelayed) {
      stats.hopLimitDrops++;
      return;
    }
    final forwarded = packet.relayed();
    stats.relayedIn++;
    _txGuarded(() => _floodNow(forwarded, receivedFrom: fromId));
  }

  // ---------------------------------------------------------------------------
  // Strikes and the security log
  // ---------------------------------------------------------------------------

  Future<void> _strike(String neighborId) async {
    final now = clock.nowMs;
    final list = _strikes.putIfAbsent(neighborId, () => <int>[]);
    list.add(now);
    list.removeWhere((t) => now - t > config.strikeWindow.inMilliseconds);
    if (list.length >= config.maxStrikes) {
      _strikes.remove(neighborId);
      _log.w(_tag, 'dropping misbehaving neighbor ${neighborId.substring(0, 8)}');
      await transport.dropNeighbor(neighborId, 'too many invalid packets');
    }
  }

  Future<void> _securityEvent(String kind, String? peerId, String detail) async {
    final key = '$kind|${peerId ?? ''}';
    final now = clock.nowMs;
    final last = _lastEventAt[key];
    if (last != null && now - last < config.eventGap.inMilliseconds) return;
    _lastEventAt[key] = now;
    _log.w(_tag, 'security: $kind $detail');
    await delegate?.onSecurityEvent(kind, peerId: peerId, detail: detail);
  }

  // ---------------------------------------------------------------------------
  // Submitting our own packets
  // ---------------------------------------------------------------------------

  /// Queues one of our own packets (direct message, receipt, group or room
  /// message, or a chunk of an image / voice message) for delivery and starts
  /// trying to send it. Returns once it is safely persisted; transmission
  /// continues in the background.
  Future<SubmitOutcome> submit(MeshPacket packet) async {
    if (packet.type == PacketType.announce || packet.type == PacketType.roomAnnounce) {
      throw ArgumentError('Announcements are sent with announceNow() / announceRoomsNow()');
    }
    final id = packet.messageIdHex;
    final outcome = await queue.enqueueOwn(
      packet,
      recipientId: packet.type.isPersistentFlood ? null : packet.recipientHex,
    );
    switch (outcome) {
      case EnqueueOutcome.stored:
        // Remember our own ids so an echo coming back around a loop is
        // ignored.
        await seen.mark(id, queue.retainUntil(packet));
        _txGuarded(() => _attemptById(id));
        return SubmitOutcome.queued;
      case EnqueueOutcome.duplicate:
        return SubmitOutcome.duplicate;
      case EnqueueOutcome.rejectedExpired:
      case EnqueueOutcome.rejectedSenderQuota:
        return SubmitOutcome.expired;
    }
  }

  // ---------------------------------------------------------------------------
  // Outbound
  // ---------------------------------------------------------------------------

  /// Tries every queue entry whose retry time has come.
  Future<void> flush() => _tx.run(_flushDue).catchError((Object e, StackTrace s) {
        _log.e(_tag, 'flush failed: $e');
      });

  /// Attempts every entry that is due, most urgent first. A page at a time:
  /// every attempt reschedules (or removes) its entry, so the next page is
  /// always new work; the page cap only guards against a runaway.
  Future<void> _flushDue() async {
    const pageSize = 100;
    for (var page = 0; page < 30; page++) {
      final due = await queue.due(limit: pageSize);
      if (due.isEmpty) return;
      for (final entry in due) {
        try {
          await _attempt(entry);
        } catch (e) {
          _log.e(_tag, 'attempt failed for ${entry.messageId.substring(0, 8)}: $e');
        }
      }
      if (due.length < pageSize) return;
    }
  }

  Future<void> _attemptById(String messageId) async {
    final entry = await queue.get(messageId);
    if (entry == null) {
      _log.d(_tag, 'attempt ${messageId.substring(0, 8)}: entry is gone');
      return;
    }
    await _attempt(entry);
  }

  Future<bool> _safeSend(String peerId, Uint8List bytes) async {
    try {
      final ok = await transport.sendPacket(peerId, bytes);
      if (ok) {
        stats.sentOk++;
      } else {
        stats.sentFailed++;
      }
      return ok;
    } catch (e) {
      stats.sentFailed++;
      _log.w(_tag, 'send to ${peerId.substring(0, 8)} threw: $e');
      return false;
    }
  }

  Future<void> _attempt(OutboxEntry entry) async {
    if (entry.expiresAtMs <= clock.nowMs) return; // maintain() handles expiry
    final packet = MeshPacket.decode(entry.packet);
    final sentTo = await queue.sentTo(entry.messageId);
    final decision = relay.decide(packet: packet, sentTo: sentTo);
    _log.d(
      _tag,
      'attempt ${entry.messageId.substring(0, 8)} ${packet.type.name} '
      '${entry.kind.name}: ${decision.strategy.name} -> ${decision.targets.length} target(s)',
    );

    if (decision.targets.isEmpty) {
      // Nobody suitable right now. Wait for a topology change (which nudges
      // the queue) or the idle timer, without burning a retry attempt.
      await queue.deferIdle(entry);
      return;
    }

    final results = await Future.wait(decision.targets.map((target) async {
      final ok = await _safeSend(target, entry.packet);
      return MapEntry(target, ok);
    }));

    var anyOk = false;
    for (final r in results) {
      if (r.value) {
        anyOk = true;
        await queue.recordSent(entry.messageId, r.key);
      }
    }

    if (anyOk && entry.kind == OutboxKind.own) {
      await delegate?.onOwnPacketSent(packet);
    }

    // Decide whether the entry has done its job.
    final attemptsSoFar = entry.attempts + 1;
    if (entry.kind == OutboxKind.own) {
      switch (packet.type) {
        case PacketType.ack:
          // Fire and forget once it has left the building. If the receipt is
          // lost, the sender simply retries the message and the recipient
          // acknowledges the duplicate again (see onDuplicateDirect).
          if (anyOk || attemptsSoFar >= config.maxAckAttempts) {
            await queue.remove(entry.messageId);
            return;
          }
        case PacketType.direct:
        case PacketType.announce:
        case PacketType.roomAnnounce:
          break; // direct messages stay until acknowledged or expired
        case PacketType.group:
        case PacketType.room:
          // Stay until they expire: phones that are not in range yet (or are
          // carrying this onward) will be offered a copy when they arrive.
          break;
      }
    } else {
      // Carrying somebody else's packet. A receipt is forwarded once; a
      // directed packet is given up after a bounded number of attempts (and
      // earlier if the recipient's receipt passes by). Group and room packets
      // are kept until they expire, however many neighbours come and go.
      final forwardedAck = packet.type == PacketType.ack && anyOk;
      final exhausted = !entry.flood && attemptsSoFar >= config.maxRelayAttempts;
      if (forwardedAck || exhausted) {
        await queue.remove(entry.messageId);
        return;
      }
    }
    await queue.scheduleRetry(entry);
  }

  Future<void> _floodNow(MeshPacket packet, {String? receivedFrom}) async {
    final decision = relay.decide(
      packet: packet,
      sentTo: const <String, SentRecord>{},
      receivedFromId: receivedFrom,
    );
    if (decision.targets.isEmpty) return;
    final bytes = packet.encode();
    await Future.wait(decision.targets.map((t) => _safeSend(t, bytes)));
  }

  // ---------------------------------------------------------------------------
  // Periodic work
  // ---------------------------------------------------------------------------

  /// Broadcasts a signed announcement now.
  Future<void> announceNow() => _tx.run(_announce).catchError((Object e, StackTrace s) {
        _log.e(_tag, 'announce failed: $e');
      });

  Future<void> _announce() async {
    final d = delegate;
    if (d == null || transport.neighbors.isEmpty) return;
    final packet = await d.buildAnnouncement();
    if (packet == null) return;
    await seen.mark(packet.messageIdHex, queue.retainUntil(packet));
    await _floodNow(packet);
  }

  /// Broadcasts the public rooms we know to the neighbours, so phones that
  /// arrive later learn about them.
  Future<void> announceRoomsNow() => _tx.run(_announceRooms).catchError((Object e, StackTrace s) {
        _log.e(_tag, 'room announce failed: $e');
      });

  Future<void> _announceRooms() async {
    final d = delegate;
    if (d == null || transport.neighbors.isEmpty) return;
    for (final packet in await d.buildRoomAnnouncements()) {
      await seen.mark(packet.messageIdHex, queue.retainUntil(packet));
      await _floodNow(packet);
    }
  }

  /// Housekeeping: expire routes and queue entries, prune memory.
  Future<void> maintain() => _rx.run(() async {
        table.expireRoutes();
        final expired = await queue.expireOld();
        for (final entry in expired) {
          if (entry.kind == OutboxKind.own) {
            await delegate?.onOwnPacketExpired(entry);
          }
        }
        await seen.prune();
        _inboundLimiter.prune();
        _senderLimiter.prune();
        _announceLimiter.prune();
        _roomAnnounceLimiter.prune();
        final cutoff = clock.nowMs - config.eventGap.inMilliseconds * 4;
        _lastEventAt.removeWhere((_, t) => t < cutoff);
      }).catchError((Object e, StackTrace s) {
        _log.e(_tag, 'maintenance failed: $e');
      });
}
