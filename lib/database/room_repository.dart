import 'dart:typed_data';

import 'package:sqflite/sqlite_api.dart';

import '../models/room.dart';
import '../protocol/room_record.dart';
import 'data_changes.dart';

enum RoomUpsertOutcome {
  /// A room we had not heard of.
  added,

  /// A newer version of a room we knew.
  updated,

  /// Same or older version, another creator's claim on a known id, or
  /// something we do not keep: nothing changed except when we last heard it.
  unchanged,
}

/// Persistence for public rooms: the built-in `#mesh`, rooms we created or
/// joined, and rooms we merely heard about.
class RoomRepository {
  RoomRepository(
    this._db, {
    required this._bus,
    this.maxDiscovered = 100,
    this.maxDiscoveredPerCreator = 10,
  });

  final Database _db;
  final ChangeBus _bus;

  /// Rooms we only heard about (not joined, not built in) are capped so a
  /// crowd of bogus announcements cannot fill the phone; the least recently
  /// heard are forgotten first.
  final int maxDiscovered;
  final int maxDiscoveredPerCreator;

  static final String _noCreator = '0' * 64;

  /// Far-future expiry of the built-in room.
  static const int _neverMs = 9007199254740991;

  PublicRoom _fromRow(Map<String, Object?> r) => PublicRoom(
        id: r['id']! as String,
        name: r['name']! as String,
        description: (r['description'] as String?) ?? '',
        creatorId: r['creator_key']! as String,
        createdAtMs: r['created_at']! as int,
        expiresAtMs: r['expires_at']! as int,
        version: r['version']! as int,
        joined: (r['joined'] as int) == 1,
        builtin: (r['builtin'] as int) == 1,
        discoveredAtMs: r['discovered_at']! as int,
        lastHeardAtMs: r['last_heard_at']! as int,
        record: r['record'] == null ? null : Uint8List.fromList(r['record']! as List<int>),
      );

  /// Makes sure the built-in `#mesh` room exists and is joined.
  Future<void> ensureBuiltin(int nowMs) async {
    final existing = await _db.query('rooms',
        columns: ['id'], where: 'id = ?', whereArgs: [PublicRooms.meshIdHex], limit: 1);
    if (existing.isNotEmpty) return;
    await _db.insert('rooms', {
      'id': PublicRooms.meshIdHex,
      'name': PublicRooms.meshName,
      'description': PublicRooms.meshDescription,
      'creator_key': _noCreator,
      'created_at': nowMs,
      'expires_at': _neverMs,
      'version': 1,
      'joined': 1,
      'builtin': 1,
      'discovered_at': nowMs,
      'last_heard_at': nowMs,
    });
    _bus.notify(DataChange.rooms);
  }

  Future<PublicRoom?> getRoom(String id) async {
    final rows = await _db.query('rooms', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : _fromRow(rows.first);
  }

  /// Built-in first, then joined rooms, then the rest by how recently they
  /// were heard.
  Future<List<PublicRoom>> listRooms() async {
    final rows = await _db.query(
      'rooms',
      orderBy: 'builtin DESC, joined DESC, last_heard_at DESC',
    );
    return rows.map(_fromRow).toList();
  }

  Future<List<PublicRoom>> joinedRooms() async {
    final rows = await _db.query('rooms', where: 'joined = 1', orderBy: 'builtin DESC, created_at ASC');
    return rows.map(_fromRow).toList();
  }

  Future<bool> isJoined(String id) async {
    final rows = await _db.query('rooms',
        columns: ['joined'], where: 'id = ? AND joined = 1', whereArgs: [id], limit: 1);
    return rows.isNotEmpty;
  }

  /// Applies a record whose signature and id the caller has already verified.
  ///
  /// A room's id belongs to its first creator: a later record under the same
  /// id from a different key is ignored. Only a higher version replaces what
  /// we have.
  Future<RoomUpsertOutcome> upsertRecord(
    RoomRecord record, {
    required int nowMs,
    bool join = false,
  }) async {
    final outcome = await _db.transaction<RoomUpsertOutcome>((txn) async {
      final id = record.roomIdHex;
      if (id == PublicRooms.meshIdHex) return RoomUpsertOutcome.unchanged;
      final rows = await txn.query('rooms', where: 'id = ?', whereArgs: [id], limit: 1);
      final values = <String, Object?>{
        'name': record.name,
        'description': record.description,
        'creator_key': record.creatorId,
        'created_at': record.createdAtMs,
        'expires_at': record.expiresAtMs,
        'version': record.version,
        'record': record.encode(),
        'last_heard_at': nowMs,
      };
      if (rows.isEmpty) {
        await txn.insert('rooms', {
          'id': id,
          ...values,
          'joined': join ? 1 : 0,
          'builtin': 0,
          'discovered_at': nowMs,
        });
        if (!join) await _enforceCaps(txn, record.creatorId);
        return RoomUpsertOutcome.added;
      }
      final existing = _fromRow(rows.first);
      if (existing.creatorId != record.creatorId) return RoomUpsertOutcome.unchanged;
      if (record.version > existing.version) {
        await txn.update(
          'rooms',
          {...values, if (join) 'joined': 1},
          where: 'id = ?',
          whereArgs: [id],
        );
        return RoomUpsertOutcome.updated;
      }
      await txn.update(
        'rooms',
        {'last_heard_at': nowMs, if (join) 'joined': 1},
        where: 'id = ?',
        whereArgs: [id],
      );
      return RoomUpsertOutcome.unchanged;
    });
    if (outcome != RoomUpsertOutcome.unchanged) _bus.notify(DataChange.rooms);
    return outcome;
  }

  Future<void> _enforceCaps(Transaction txn, String creatorId) async {
    await txn.rawDelete(
      'DELETE FROM rooms WHERE id IN ('
      'SELECT id FROM rooms WHERE joined = 0 AND builtin = 0 AND creator_key = ? '
      'ORDER BY last_heard_at DESC LIMIT -1 OFFSET ?)',
      [creatorId, maxDiscoveredPerCreator],
    );
    await txn.rawDelete(
      'DELETE FROM rooms WHERE id IN ('
      'SELECT id FROM rooms WHERE joined = 0 AND builtin = 0 '
      'ORDER BY last_heard_at DESC LIMIT -1 OFFSET ?)',
      [maxDiscovered],
    );
  }

  Future<void> setJoined(String id, bool joined) async {
    await _db.update('rooms', {'joined': joined ? 1 : 0},
        where: 'id = ? AND builtin = 0', whereArgs: [id]);
    _bus.notify(DataChange.rooms);
  }

  /// Notes that something in this room was just heard.
  Future<void> touch(String id, int nowMs) async {
    await _db.update('rooms', {'last_heard_at': nowMs}, where: 'id = ?', whereArgs: [id]);
  }

  /// Rooms worth announcing to people who arrive: ones we created or joined,
  /// plus recently heard ones, all still unexpired and with a stored record.
  /// The built-in room needs no announcement.
  Future<List<PublicRoom>> announceable(int nowMs) async {
    final rows = await _db.query(
      'rooms',
      where: 'builtin = 0 AND record IS NOT NULL AND expires_at > ?',
      whereArgs: [nowMs],
      orderBy: 'joined DESC, last_heard_at DESC',
    );
    return rows.map(_fromRow).toList();
  }

  /// Forgets rooms that expired and that we have not joined. Joined rooms stay
  /// (so their history and conversation survive) - they simply stop being
  /// announced. Returns how many were removed.
  Future<int> purgeExpired(int nowMs) async {
    final n = await _db.delete(
      'rooms',
      where: 'joined = 0 AND builtin = 0 AND expires_at <= ?',
      whereArgs: [nowMs],
    );
    if (n > 0) _bus.notify(DataChange.rooms);
    return n;
  }

  /// Removes a room we no longer want to see (never the built-in one).
  Future<void> delete(String id) async {
    await _db.delete('rooms', where: 'id = ? AND builtin = 0', whereArgs: [id]);
    _bus.notify(DataChange.rooms);
  }
}
