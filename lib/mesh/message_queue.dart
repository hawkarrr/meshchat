import 'dart:math';

import '../core/clock.dart';
import '../database/outbox_repository.dart';
import '../protocol/mesh_packet.dart';
import '../protocol/protocol_constants.dart';

/// Tunables for the store-and-forward queue.
class QueueConfig {
  const QueueConfig({
    // A relay holds a packet until the recipient confirms it, so a whole video
    // (up to 342 chunks) from one author has to fit in the allowance of that
    // author, or most of it is dropped at the first relay and has to be resent.
    this.maxRelayEntries = 900,
    this.maxRelayPerSender = 360,
    this.maxFloodEntries = 1200,
    this.maxFloodPerSender = 400,
    this.baseRetry = const Duration(seconds: 10),
    this.maxRetry = const Duration(minutes: 15),
    this.idleRetry = const Duration(seconds: 15),
    this.floodIdleRetry = const Duration(minutes: 5),
    this.maxSendsPerNeighbor = 3,
    this.resendCooldown = const Duration(seconds: 30),
    this.relayResendCooldown = const Duration(minutes: 5),
    this.relayRetention = const Duration(hours: 4),
    this.floodRelayRetention = const Duration(hours: 12),
  });

  /// How long a packet is carried on behalf of somebody else, whatever
  /// expiry its sender wrote. Own packets use the full retention limit.
  final Duration relayRetention;

  /// The same for group and room packets, which are carried for people who are
  /// not in range yet (store, carry and forward).
  final Duration floodRelayRetention;

  /// Hard cap on directed packets held for other people (bounds storage and
  /// abuse).
  final int maxRelayEntries;

  /// One sender may occupy at most this many directed relay slots.
  final int maxRelayPerSender;

  /// Hard cap on group and room packets held for other people. Separate from
  /// [maxRelayEntries] so a burst of photos can never push out a receipt.
  final int maxFloodEntries;

  /// One sender may occupy at most this many flood slots (one photo alone is
  /// dozens of packets).
  final int maxFloodPerSender;

  /// Re-check delay for a flood packet everybody in range already has. A new
  /// neighbour makes it due at once, so this is only a safety net.
  final Duration floodIdleRetry;

  /// First retry delay; doubles after every attempt up to [maxRetry].
  final Duration baseRetry;
  final Duration maxRetry;

  /// Re-check delay when there was nobody to send to (no attempt is counted).
  final Duration idleRetry;

  /// A message is sent to its *final recipient* at most this many times.
  final int maxSendsPerNeighbor;

  /// Minimum gap before re-sending to the same neighbour (doubles per send).
  final Duration resendCooldown;

  /// A relay neighbour that already has a message gets one more copy only
  /// after this long (in case it lost it).
  final Duration relayResendCooldown;
}

enum EnqueueOutcome { stored, duplicate, rejectedSenderQuota, rejectedExpired }

/// The persistent store-and-forward queue for directed packets.
///
/// Packets stay here until they are acknowledged, expire, or run out of
/// attempts; they are retried with exponential back-off and whenever the
/// topology changes. Everything in it is already encrypted and signed.
class MessageQueue {
  MessageQueue({
    required this.store,
    this.config = const QueueConfig(),
    this.clock = const SystemClock(),
    Random? random,
  }) : _random = random ?? Random();

  final OutboxRepository store;
  final QueueConfig config;
  final Clock clock;
  final Random _random;

  /// Our own retention limit: min(sender's claim, now + maxRetention).
  int retainUntil(MeshPacket p) {
    final cap = clock.nowMs + Protocol.maxRetention.inMilliseconds;
    return p.expiresAtMs < cap ? p.expiresAtMs : cap;
  }

  /// How urgently a packet should be sent: receipts first, then one-to-one
  /// messages, then group and room messages, and image / voice chunks last.
  static int priorityFor(MeshPacket p) {
    if (p.isChunk) return OutboxPriority.chunk;
    return switch (p.type) {
      PacketType.ack => OutboxPriority.ack,
      PacketType.direct => OutboxPriority.direct,
      PacketType.group ||
      PacketType.room ||
      PacketType.announce ||
      PacketType.roomAnnounce =>
        OutboxPriority.message,
    };
  }

  Future<EnqueueOutcome> enqueueOwn(MeshPacket packet, {required String? recipientId}) async {
    final expires = retainUntil(packet);
    if (expires <= clock.nowMs) return EnqueueOutcome.rejectedExpired;
    final stored = await store.enqueue(OutboxEntry(
      messageId: packet.messageIdHex,
      kind: OutboxKind.own,
      senderId: packet.senderHex,
      recipientId: recipientId,
      packet: packet.encode(),
      createdAtMs: clock.nowMs,
      expiresAtMs: expires,
      nextAttemptAtMs: clock.nowMs,
      priority: priorityFor(packet),
      flood: packet.type.isPersistentFlood,
    ));
    return stored ? EnqueueOutcome.stored : EnqueueOutcome.duplicate;
  }

  /// Holds a packet received from a neighbour so it can be forwarded later.
  /// [packet] must already carry the incremented hop count.
  Future<EnqueueOutcome> enqueueRelay(MeshPacket packet) async {
    final flood = packet.type.isPersistentFlood;
    final retention = flood ? config.floodRelayRetention : config.relayRetention;
    final relayCap = clock.nowMs + retention.inMilliseconds;
    final expires = retainUntil(packet) < relayCap ? retainUntil(packet) : relayCap;
    if (expires <= clock.nowMs) return EnqueueOutcome.rejectedExpired;
    final quota = flood ? config.maxFloodPerSender : config.maxRelayPerSender;
    if (await store.countRelayBySender(packet.senderHex, flood: flood) >= quota) {
      return EnqueueOutcome.rejectedSenderQuota;
    }
    final stored = await store.enqueue(OutboxEntry(
      messageId: packet.messageIdHex,
      kind: OutboxKind.relay,
      senderId: packet.senderHex,
      recipientId: packet.isBroadcast || flood ? null : packet.recipientHex,
      packet: packet.encode(),
      createdAtMs: clock.nowMs,
      expiresAtMs: expires,
      nextAttemptAtMs: clock.nowMs,
      priority: priorityFor(packet),
      flood: flood,
    ));
    if (!stored) return EnqueueOutcome.duplicate;
    await store.evictOldestRelay(
      keep: flood ? config.maxFloodEntries : config.maxRelayEntries,
      flood: flood,
    );
    return EnqueueOutcome.stored;
  }

  /// Entries whose retry time has come, most urgent first.
  Future<List<OutboxEntry>> due({int limit = 100}) => store.due(clock.nowMs, limit: limit);

  Future<OutboxEntry?> get(String messageId) => store.get(messageId);

  Future<Map<String, SentRecord>> sentTo(String messageId) => store.sentTo(messageId);

  Future<void> recordSent(String messageId, String neighborId) =>
      store.recordSent(messageId, neighborId, clock.nowMs);

  /// [neighborId] already holds this message (it sent it to us).
  Future<void> recordNeighborHas(String messageId, String neighborId) =>
      store.recordNeighborHas(messageId, neighborId, clock.nowMs);

  /// Drops the queued copy of [messageId] if the acknowledgement really came
  /// from its intended recipient. Returns whether something was removed.
  /// A group or room packet has no single recipient and is never cancelled
  /// this way: other people may still need it.
  Future<bool> cancelIfAckedBy(String messageId, String ackSenderId) async {
    final entry = await store.get(messageId);
    if (entry == null || entry.flood || entry.recipientId != ackSenderId) return false;
    await store.remove(messageId);
    return true;
  }

  /// Schedules the next retry after a real attempt: exponential back-off with
  /// +-20% jitter so neighbours do not retry in lock-step.
  Future<void> scheduleRetry(OutboxEntry e) async {
    final exp = min(e.attempts, 20);
    var delayMs = config.baseRetry.inMilliseconds * (1 << exp);
    if (delayMs > config.maxRetry.inMilliseconds || delayMs <= 0) {
      delayMs = config.maxRetry.inMilliseconds;
    }
    final jitter = 0.8 + _random.nextDouble() * 0.4;
    await store.recordAttempt(
      e.messageId,
      nextAttemptAtMs: clock.nowMs + (delayMs * jitter).round(),
    );
  }

  /// Re-check later without counting an attempt (nobody to send to yet).
  Future<void> deferIdle(OutboxEntry e) => store.reschedule(
        e.messageId,
        nextAttemptAtMs: clock.nowMs +
            (e.flood ? config.floodIdleRetry : config.idleRetry).inMilliseconds,
      );

  Future<void> remove(String messageId) => store.remove(messageId);

  /// Makes every waiting entry eligible immediately (a neighbour appeared or
  /// a route was learned).
  Future<void> nudge() => store.makeDueNow(clock.nowMs);

  /// Removes and returns entries whose retention has run out.
  Future<List<OutboxEntry>> expireOld() async {
    final expired = await store.expired(clock.nowMs);
    if (expired.isNotEmpty) await store.removeExpired(clock.nowMs);
    return expired;
  }

  Future<int> size() => store.count();

  /// May we send [messageId] to [neighborId] now, given what we already sent?
  ///
  /// This is what stops the same message being pushed at the same neighbour
  /// over and over: a neighbour that already has it only gets another copy
  /// when it is the *final recipient* (the first copy may have been lost and
  /// no receipt came back), after a growing cool-down and a hard cap; a mere
  /// relay gets a second chance only after a long wait.
  bool mayResend({
    required SentRecord? previous,
    required bool neighborIsFinalRecipient,
  }) {
    if (previous == null) return true;
    final now = clock.nowMs;
    if (neighborIsFinalRecipient) {
      if (previous.sendCount >= config.maxSendsPerNeighbor) return false;
      final wait = config.resendCooldown.inMilliseconds * (1 << (previous.sendCount - 1));
      return now - previous.sentAtMs >= wait;
    }
    return previous.sendCount < 2 &&
        now - previous.sentAtMs >= config.relayResendCooldown.inMilliseconds;
  }
}
