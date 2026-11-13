import 'dart:typed_data';

import 'package:sqflite/sqlite_api.dart';

/// Why a packet is in the outbox.
enum OutboxKind {
  /// Originated by this phone (a message, ack or announcement we created).
  own,

  /// Received from a neighbour and held so it can be forwarded later
  /// (store-and-forward).
  relay,
}

/// Which packets are sent first when several are waiting. Receipts are tiny
/// and unblock the other side, so they go first; image and voice chunks are
/// the bulk and go last, so a photo never holds up a text message.
abstract final class OutboxPriority {
  static const int ack = 0;
  static const int direct = 1;
  static const int message = 2;
  static const int chunk = 3;
}

/// A serialized, already-encrypted and signed packet waiting for delivery.
/// It contains no plaintext: this table can be inspected without revealing
/// message contents.
class OutboxEntry {
  const OutboxEntry({
    required this.messageId,
    required this.kind,
    required this.senderId,
    this.recipientId,
    required this.packet,
    required this.createdAtMs,
    required this.expiresAtMs,
    this.attempts = 0,
    required this.nextAttemptAtMs,
    this.priority = OutboxPriority.direct,
    this.flood = false,
  });

  final String messageId;
  final OutboxKind kind;
  final String senderId;

  /// Hex recipient key; null for broadcast packets.
  final String? recipientId;
  final Uint8List packet;
  final int createdAtMs;

  /// Local deadline after which the entry is dropped (already clamped to our
  /// own maximum retention, never the sender's raw claim).
  final int expiresAtMs;
  final int attempts;
  final int nextAttemptAtMs;

  /// Lower numbers are sent first (see [OutboxPriority]).
  final int priority;

  /// A group or room packet: kept and offered once to every neighbour that
  /// comes into range until it expires, rather than steered to one recipient.
  final bool flood;
}

/// How many times a packet has been sent to one neighbour.
class SentRecord {
  const SentRecord({required this.neighborId, required this.sentAtMs, required this.sendCount});

  final String neighborId;
  final int sentAtMs;
  final int sendCount;
}

/// Persistence for the store-and-forward queue and the duplicate-detection
/// memory. Both must survive restarts: otherwise a reboot would re-deliver or
/// re-forward everything.
class OutboxRepository {
  OutboxRepository(this._db);

  final Database _db;

  OutboxEntry _fromRow(Map<String, Object?> r) => OutboxEntry(
        messageId: r['message_id']! as String,
        kind: r['kind'] == 'relay' ? OutboxKind.relay : OutboxKind.own,
        senderId: r['sender_key']! as String,
        recipientId: r['recipient_key'] as String?,
        packet: Uint8List.fromList(r['packet']! as List<int>),
        createdAtMs: r['created_at']! as int,
        expiresAtMs: r['expires_at']! as int,
        attempts: r['attempts']! as int,
        nextAttemptAtMs: r['next_attempt_at']! as int,
        priority: (r['priority'] as int?) ?? OutboxPriority.direct,
        flood: ((r['flood'] as int?) ?? 0) == 1,
      );

  /// Adds [e]. Returns false (and changes nothing) if that message id is
  /// already queued.
  Future<bool> enqueue(OutboxEntry e) {
    return _db.transaction<bool>((txn) async {
      final existing = await txn.query('outbox',
          columns: ['message_id'], where: 'message_id = ?', whereArgs: [e.messageId], limit: 1);
      if (existing.isNotEmpty) return false;
      await txn.insert('outbox', {
        'message_id': e.messageId,
        'kind': e.kind.name,
        'sender_key': e.senderId,
        'recipient_key': e.recipientId,
        'packet': e.packet,
        'created_at': e.createdAtMs,
        'expires_at': e.expiresAtMs,
        'attempts': e.attempts,
        'next_attempt_at': e.nextAttemptAtMs,
        'priority': e.priority,
        'flood': e.flood ? 1 : 0,
      });
      return true;
    });
  }

  Future<OutboxEntry?> get(String messageId) async {
    final rows = await _db.query('outbox', where: 'message_id = ?', whereArgs: [messageId], limit: 1);
    return rows.isEmpty ? null : _fromRow(rows.first);
  }

  Future<List<OutboxEntry>> all() async {
    final rows = await _db.query('outbox', orderBy: 'created_at ASC');
    return rows.map(_fromRow).toList();
  }

  /// Entries whose retry time has come and which have not expired, most urgent
  /// first (see [OutboxPriority]), then oldest first.
  Future<List<OutboxEntry>> due(int nowMs, {int limit = 100}) async {
    final rows = await _db.query(
      'outbox',
      where: 'next_attempt_at <= ? AND expires_at > ?',
      whereArgs: [nowMs, nowMs],
      orderBy: 'priority ASC, created_at ASC, rowid ASC',
      limit: limit,
    );
    return rows.map(_fromRow).toList();
  }

  Future<void> recordAttempt(String messageId, {required int nextAttemptAtMs}) =>
      _db.rawUpdate(
        'UPDATE outbox SET attempts = attempts + 1, next_attempt_at = ? WHERE message_id = ?',
        [nextAttemptAtMs, messageId],
      );

  /// Moves the next attempt without counting it as an attempt.
  Future<void> reschedule(String messageId, {required int nextAttemptAtMs}) =>
      _db.rawUpdate(
        'UPDATE outbox SET next_attempt_at = ? WHERE message_id = ?',
        [nextAttemptAtMs, messageId],
      );

  /// Makes an entry eligible for sending immediately (used when the network
  /// topology changes, e.g. a new neighbour appears).
  Future<void> makeDueNow(int nowMs) => _db.rawUpdate(
        'UPDATE outbox SET next_attempt_at = ? WHERE next_attempt_at > ?',
        [nowMs, nowMs],
      );

  Future<void> remove(String messageId) =>
      _db.delete('outbox', where: 'message_id = ?', whereArgs: [messageId]);

  Future<List<OutboxEntry>> expired(int nowMs) async {
    final rows = await _db.query('outbox', where: 'expires_at <= ?', whereArgs: [nowMs]);
    return rows.map(_fromRow).toList();
  }

  Future<int> removeExpired(int nowMs) =>
      _db.delete('outbox', where: 'expires_at <= ?', whereArgs: [nowMs]);

  Future<int> count({OutboxKind? kind}) async {
    final rows = kind == null
        ? await _db.rawQuery('SELECT COUNT(*) AS n FROM outbox')
        : await _db.rawQuery('SELECT COUNT(*) AS n FROM outbox WHERE kind = ?', [kind.name]);
    return (rows.first['n'] as int?) ?? 0;
  }

  /// Packets held for somebody else that came from [senderId]. Group and room
  /// floods are counted apart from directed packets ([flood]): one image alone
  /// is dozens of packets.
  Future<int> countRelayBySender(String senderId, {bool flood = false}) async {
    final rows = await _db.rawQuery(
        'SELECT COUNT(*) AS n FROM outbox WHERE kind = ? AND sender_key = ? AND flood = ?',
        [OutboxKind.relay.name, senderId, flood ? 1 : 0]);
    return (rows.first['n'] as int?) ?? 0;
  }

  /// Drops the oldest relayed packets of one class (directed, or [flood]) until
  /// at most [keep] remain. Own packets are never evicted this way, and one
  /// class can never push out the other.
  Future<int> evictOldestRelay({required int keep, bool flood = false}) async {
    final rows = await _db.rawQuery(
        'SELECT COUNT(*) AS n FROM outbox WHERE kind = ? AND flood = ?',
        [OutboxKind.relay.name, flood ? 1 : 0]);
    final total = (rows.first['n'] as int?) ?? 0;
    if (total <= keep) return 0;
    return _db.rawDelete(
      'DELETE FROM outbox WHERE message_id IN ('
      'SELECT message_id FROM outbox WHERE kind = ? AND flood = ? '
      'ORDER BY created_at ASC, rowid ASC LIMIT ?)',
      [OutboxKind.relay.name, flood ? 1 : 0, total - keep],
    );
  }

  // ---------------------------------------------------------------------------
  // Per-neighbour send tracking ("never send the same message to the same
  // peer over and over")
  // ---------------------------------------------------------------------------

  Future<void> recordSent(String messageId, String neighborId, int atMs) {
    return _db.transaction((txn) async {
      final existing = await txn.query(
        'outbox_sent',
        where: 'message_id = ? AND neighbor_key = ?',
        whereArgs: [messageId, neighborId],
        limit: 1,
      );
      if (existing.isEmpty) {
        // The outbox row may be gone (acked and removed meanwhile); the FK
        // would reject the insert, which is the right outcome.
        final parent = await txn.query('outbox',
            columns: ['message_id'], where: 'message_id = ?', whereArgs: [messageId], limit: 1);
        if (parent.isEmpty) return;
        await txn.insert('outbox_sent', {
          'message_id': messageId,
          'neighbor_key': neighborId,
          'sent_at': atMs,
          'send_count': 1,
        });
      } else {
        await txn.update(
          'outbox_sent',
          {'sent_at': atMs, 'send_count': (existing.first['send_count']! as int) + 1},
          where: 'message_id = ? AND neighbor_key = ?',
          whereArgs: [messageId, neighborId],
        );
      }
    });
  }

  /// Marks that [neighborId] is known to hold this message already (we
  /// received it from them, or they sent us a duplicate), so it is never
  /// offered back to them. Implemented as a send count no policy will exceed.
  static const int neighborHasItCount = 1000;

  Future<void> recordNeighborHas(String messageId, String neighborId, int atMs) {
    return _db.transaction((txn) async {
      final parent = await txn.query('outbox',
          columns: ['message_id'], where: 'message_id = ?', whereArgs: [messageId], limit: 1);
      if (parent.isEmpty) return;
      final existing = await txn.query(
        'outbox_sent',
        where: 'message_id = ? AND neighbor_key = ?',
        whereArgs: [messageId, neighborId],
        limit: 1,
      );
      if (existing.isEmpty) {
        await txn.insert('outbox_sent', {
          'message_id': messageId,
          'neighbor_key': neighborId,
          'sent_at': atMs,
          'send_count': neighborHasItCount,
        });
      } else {
        await txn.update(
          'outbox_sent',
          {'sent_at': atMs, 'send_count': neighborHasItCount},
          where: 'message_id = ? AND neighbor_key = ?',
          whereArgs: [messageId, neighborId],
        );
      }
    });
  }

  Future<Map<String, SentRecord>> sentTo(String messageId) async {
    final rows = await _db.query('outbox_sent', where: 'message_id = ?', whereArgs: [messageId]);
    return {
      for (final r in rows)
        r['neighbor_key']! as String: SentRecord(
          neighborId: r['neighbor_key']! as String,
          sentAtMs: r['sent_at']! as int,
          sendCount: r['send_count']! as int,
        ),
    };
  }

  // ---------------------------------------------------------------------------
  // Seen message ids
  // ---------------------------------------------------------------------------

  /// Non-expired seen ids, newest-expiring first, for warming the in-memory
  /// duplicate filter at startup.
  Future<Map<String, int>> loadSeen(int nowMs, {int limit = 20000}) async {
    final rows = await _db.query(
      'seen_messages',
      where: 'expires_at > ?',
      whereArgs: [nowMs],
      orderBy: 'expires_at DESC',
      limit: limit,
    );
    return {for (final r in rows) r['message_id']! as String: r['expires_at']! as int};
  }

  Future<void> addSeen(String messageId, int expiresAtMs) => _db.insert(
        'seen_messages',
        {'message_id': messageId, 'expires_at': expiresAtMs},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  Future<int> pruneSeen(int nowMs) =>
      _db.delete('seen_messages', where: 'expires_at <= ?', whereArgs: [nowMs]);

  /// Forgets the queue and the duplicate memory (used when the identity is
  /// reset: packets signed by the old identity are worthless).
  Future<void> clearAll() async {
    await _db.transaction((txn) async {
      await txn.delete('outbox_sent');
      await txn.delete('outbox');
      await txn.delete('seen_messages');
    });
  }
}
