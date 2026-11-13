import 'dart:typed_data';

import 'package:sqflite/sqlite_api.dart';

import '../models/media.dart';
import 'data_changes.dart';

/// One piece of a media object held on this phone.
class StoredChunk {
  const StoredChunk({
    required this.mediaId,
    required this.index,
    required this.data,
    required this.sealed,
    required this.senderId,
    required this.receivedAtMs,
  });

  final String mediaId;
  final int index;

  /// Plain media bytes - or, when [sealed], the encoded packet that carried a
  /// chunk we could not open yet because its manifest has not arrived.
  final Uint8List data;
  final bool sealed;
  final String senderId;
  final int receivedAtMs;
}

/// Where an outgoing media message stands.
class OutgoingProgress {
  const OutgoingProgress({required this.messageId, required this.remaining});

  final String messageId;

  /// Parts (manifest and chunks) that have not been acknowledged yet.
  final int remaining;
}

/// Persistence for image and voice messages: their metadata, the chunks
/// collected so far, and which parts of our own uploads were acknowledged.
/// The finished files themselves live in the app's private media folder.
class MediaRepository {
  MediaRepository(this._db, {required this._bus});

  final Database _db;
  final ChangeBus _bus;

  /// The ids of the packets (manifest and chunks) of one of our uploads.
  Future<List<String>> partIds(String messageId) async {
    final rows = await _db.query('outgoing_parts',
        columns: ['packet_id'], where: 'message_id = ?', whereArgs: [messageId]);
    return [for (final r in rows) r['packet_id']! as String];
  }

  MediaItem _fromRow(Map<String, Object?> r) => MediaItem(
        id: r['id']! as String,
        messageId: r['message_id']! as String,
        kind: MediaKind.values.firstWhere((k) => k.name == r['kind'], orElse: () => MediaKind.image),
        mimeCode: r['mime']! as int,
        byteLength: r['byte_length']! as int,
        chunkCount: r['chunk_count']! as int,
        sha256: Uint8List.fromList(r['sha256']! as List<int>),
        width: r['width']! as int,
        height: r['height']! as int,
        durationMs: r['duration_ms']! as int,
        waveform: r['waveform'] == null ? const <int>[] : List<int>.from(r['waveform']! as List<int>),
        state: MediaState.parse(r['state']! as String),
        receivedChunks: r['received_chunks']! as int,
        fileName: r['file_name'] as String?,
        error: r['error'] as String?,
        createdAtMs: r['created_at']! as int,
        expiresAtMs: r['expires_at']! as int,
      );

  /// Stores the metadata of a media message. Its message row must exist.
  /// [key] is the key still needed to open chunks that arrive later (direct
  /// messages only).
  Future<void> insert(MediaItem item, {Uint8List? key}) async {
    await _db.insert('media', {
      'id': item.id,
      'message_id': item.messageId,
      'kind': item.kind.name,
      'mime': item.mimeCode,
      'byte_length': item.byteLength,
      'chunk_count': item.chunkCount,
      'sha256': item.sha256,
      'key': key,
      'width': item.width,
      'height': item.height,
      'duration_ms': item.durationMs,
      'waveform': item.waveform.isEmpty ? null : Uint8List.fromList(item.waveform),
      'state': item.state.name,
      'received_chunks': item.receivedChunks,
      'file_name': item.fileName,
      'error': item.error,
      'created_at': item.createdAtMs,
      'expires_at': item.expiresAtMs,
    });
    _bus.notify(DataChange.media);
  }

  Future<MediaItem?> get(String id) async {
    final rows = await _db.query('media', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : _fromRow(rows.first);
  }

  /// How many complete pictures, recordings and videos are kept, and how many
  /// bytes they take.
  Future<({int count, int bytes})> usage() async {
    final rows = await _db.rawQuery(
        "SELECT COUNT(*) AS n, COALESCE(SUM(byte_length), 0) AS b FROM media WHERE state = 'ready'");
    return (count: (rows.first['n'] as int?) ?? 0, bytes: (rows.first['b'] as int?) ?? 0);
  }

  Future<MediaItem?> forMessage(String messageId) async {
    final rows =
        await _db.query('media', where: 'message_id = ?', whereArgs: [messageId], limit: 1);
    return rows.isEmpty ? null : _fromRow(rows.first);
  }

  /// Media of many messages at once, keyed by media id.
  Future<Map<String, MediaItem>> getMany(Iterable<String> ids) async {
    final list = ids.toList();
    if (list.isEmpty) return const <String, MediaItem>{};
    final out = <String, MediaItem>{};
    // SQLite limits the number of variables in one statement.
    for (var i = 0; i < list.length; i += 500) {
      final part = list.sublist(i, i + 500 > list.length ? list.length : i + 500);
      final rows = await _db.query(
        'media',
        where: 'id IN (${List.filled(part.length, '?').join(',')})',
        whereArgs: part,
      );
      for (final r in rows) {
        final item = _fromRow(r);
        out[item.id] = item;
      }
    }
    return out;
  }

  Future<Uint8List?> keyOf(String id) async {
    final rows =
        await _db.query('media', columns: ['key'], where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty || rows.first['key'] == null) return null;
    return Uint8List.fromList(rows.first['key']! as List<int>);
  }

  Future<void> setState(
    String id,
    MediaState state, {
    String? fileName,
    String? error,
    bool dropKey = false,
  }) async {
    await _db.update(
      'media',
      {
        'state': state.name,
        'file_name': ?fileName,
        'error': error,
        if (dropKey) 'key': null,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    _bus.notify(DataChange.media);
  }

  // ---------------------------------------------------------------------------
  // Chunks being collected
  // ---------------------------------------------------------------------------

  /// Keeps one chunk. Returns false, changing nothing, when that position was
  /// already stored.
  Future<bool> storeChunk({
    required String mediaId,
    required int index,
    required Uint8List data,
    required bool sealed,
    required String senderId,
    required int nowMs,
  }) async {
    final stored = await _db.transaction<bool>((txn) async {
      final existing = await txn.query('media_chunks',
          columns: ['idx'],
          where: 'media_id = ? AND idx = ?',
          whereArgs: [mediaId, index],
          limit: 1);
      if (existing.isNotEmpty) return false;
      await txn.insert('media_chunks', {
        'media_id': mediaId,
        'idx': index,
        'data': data,
        'sealed': sealed ? 1 : 0,
        'sender_key': senderId,
        'received_at': nowMs,
      });
      return true;
    });
    return stored;
  }

  /// Replaces a held (sealed) chunk by its opened bytes.
  Future<void> replaceChunk(String mediaId, int index, Uint8List plain) => _db.update(
        'media_chunks',
        {'data': plain, 'sealed': 0},
        where: 'media_id = ? AND idx = ?',
        whereArgs: [mediaId, index],
      );

  Future<void> deleteChunk(String mediaId, int index) => _db.delete('media_chunks',
      where: 'media_id = ? AND idx = ?', whereArgs: [mediaId, index]);

  StoredChunk _chunkFromRow(Map<String, Object?> r) => StoredChunk(
        mediaId: r['media_id']! as String,
        index: r['idx']! as int,
        data: Uint8List.fromList(r['data']! as List<int>),
        sealed: (r['sealed'] as int) == 1,
        senderId: r['sender_key']! as String,
        receivedAtMs: r['received_at']! as int,
      );

  /// All chunks held for a media object, in order.
  Future<List<StoredChunk>> chunks(String mediaId, {bool? sealed}) async {
    final rows = await _db.query(
      'media_chunks',
      where: sealed == null ? 'media_id = ?' : 'media_id = ? AND sealed = ?',
      whereArgs: sealed == null ? [mediaId] : [mediaId, sealed ? 1 : 0],
      orderBy: 'idx ASC',
    );
    return rows.map(_chunkFromRow).toList();
  }

  /// How many opened chunks are stored for [mediaId].
  Future<int> plainChunkCount(String mediaId) async {
    final rows = await _db.rawQuery(
        'SELECT COUNT(*) AS n FROM media_chunks WHERE media_id = ? AND sealed = 0', [mediaId]);
    return (rows.first['n'] as int?) ?? 0;
  }

  Future<void> setReceivedChunks(String mediaId, int count) async {
    await _db.update('media', {'received_chunks': count},
        where: 'id = ?', whereArgs: [mediaId]);
    _bus.notify(DataChange.media);
  }

  Future<void> deleteChunks(String mediaId) =>
      _db.delete('media_chunks', where: 'media_id = ?', whereArgs: [mediaId]);

  /// Chunks whose media object we know nothing about (their manifest has not
  /// arrived), counted so they cannot pile up without bound.
  Future<int> orphanChunkCount() async {
    final rows = await _db.rawQuery(
        'SELECT COUNT(*) AS n FROM media_chunks WHERE media_id NOT IN (SELECT id FROM media)');
    return (rows.first['n'] as int?) ?? 0;
  }

  /// Drops chunks older than [olderThanMs] that never found their manifest.
  Future<int> pruneOrphanChunks(int olderThanMs) => _db.rawDelete(
        'DELETE FROM media_chunks WHERE received_at < ? '
        'AND media_id NOT IN (SELECT id FROM media)',
        [olderThanMs],
      );

  /// Media still being received whose deadline has passed.
  Future<List<MediaItem>> expiredPartial(int nowMs) async {
    final rows = await _db.query(
      'media',
      where: 'state = ? AND expires_at <= ?',
      whereArgs: [MediaState.receiving.name, nowMs],
    );
    return rows.map(_fromRow).toList();
  }

  /// Media that was still arriving when the app last stopped.
  Future<List<MediaItem>> receiving() async {
    final rows = await _db.query('media', where: 'state = ?', whereArgs: [MediaState.receiving.name]);
    return rows.map(_fromRow).toList();
  }

  /// Names of the files that belong to stored media, so unreferenced files in
  /// the media folder can be cleaned up.
  Future<Set<String>> referencedFileNames() async {
    final rows = await _db.query('media', columns: ['file_name'], where: 'file_name IS NOT NULL');
    return {for (final r in rows) r['file_name']! as String};
  }

  // ---------------------------------------------------------------------------
  // Our own uploads
  // ---------------------------------------------------------------------------

  /// Remembers which packets make up an outgoing media message, so it can be
  /// marked delivered once all of them were acknowledged.
  Future<void> addOutgoingParts(String messageId, List<String> packetIds) async {
    await _db.transaction((txn) async {
      final batch = txn.batch();
      for (final id in packetIds) {
        batch.insert('outgoing_parts', {'packet_id': id, 'message_id': messageId, 'acked': 0},
            conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      await batch.commit(noResult: true);
    });
  }

  /// The outgoing media message [packetId] belongs to, or null.
  Future<String?> messageOfPart(String packetId) async {
    final rows = await _db.query('outgoing_parts',
        columns: ['message_id'], where: 'packet_id = ?', whereArgs: [packetId], limit: 1);
    return rows.isEmpty ? null : rows.first['message_id']! as String;
  }

  /// Marks one part acknowledged. Returns null when [packetId] is not part of
  /// a media message (or was already acknowledged).
  Future<OutgoingProgress?> ackPart(String packetId) async {
    return _db.transaction<OutgoingProgress?>((txn) async {
      final rows = await txn.query('outgoing_parts',
          where: 'packet_id = ? AND acked = 0', whereArgs: [packetId], limit: 1);
      if (rows.isEmpty) return null;
      final messageId = rows.first['message_id']! as String;
      await txn.update('outgoing_parts', {'acked': 1},
          where: 'packet_id = ?', whereArgs: [packetId]);
      final left = await txn.rawQuery(
          'SELECT COUNT(*) AS n FROM outgoing_parts WHERE message_id = ? AND acked = 0',
          [messageId]);
      return OutgoingProgress(messageId: messageId, remaining: (left.first['n'] as int?) ?? 0);
    });
  }

  Future<int> unackedPartCount(String messageId) async {
    final rows = await _db.rawQuery(
        'SELECT COUNT(*) AS n FROM outgoing_parts WHERE message_id = ? AND acked = 0',
        [messageId]);
    return (rows.first['n'] as int?) ?? 0;
  }
}
