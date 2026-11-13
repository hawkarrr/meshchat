import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite/sqlite_api.dart';

import '../protocol/protocol_constants.dart';

/// Opens and owns the app's SQLite database.
///
/// The database holds conversations, messages, groups, public rooms, media
/// metadata and the persistent outbox. It holds NO key material (those live in
/// the platform keystore) and message bodies are stored decrypted, so it
/// relies on the OS app sandbox and device encryption for protection at rest.
class DatabaseHelper {
  DatabaseHelper._(this.db, this.path);

  static const int schemaVersion = 3;
  static const String fileName = 'offline_mesh_chat.db';

  final Database db;
  final String path;

  /// Opens (creating and migrating if needed) the database.
  ///
  /// [path] and [databaseFactory] are injectable for tests (an in-memory
  /// database through sqflite_common_ffi). In the app both are left null:
  /// the file goes in the private application-support directory.
  static Future<DatabaseHelper> open({
    String? path,
    DatabaseFactory? databaseFactory,
    bool singleInstance = true,
  }) async {
    final factory = databaseFactory ?? sqflite.databaseFactory;
    final resolved = path ?? await defaultPath();
    final db = await factory.openDatabase(
      resolved,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        singleInstance: singleInstance,
        onConfigure: _onConfigure,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      ),
    );
    return DatabaseHelper._(db, resolved);
  }

  /// `<application support>/offline_mesh_chat.db`. The application-support
  /// directory is private to the app and, unlike the documents directory, is
  /// not exposed to the user's file browser.
  static Future<String> defaultPath() async {
    final dir = await getApplicationSupportDirectory();
    return p.join(dir.path, fileName);
  }

  Future<void> close() => db.close();

  static Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  static Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();
    for (final statement in schemaStatements) {
      batch.execute(statement);
    }
    await batch.commit(noResult: true);
  }

  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) await _migrateV1ToV2(db);
    if (oldVersion < 3) await _migrateV2ToV3(db);
  }

  /// v1 -> v2: channels are gone, conversations gain groups and rooms,
  /// messages gain a kind and media, the outbox gains priorities.
  ///
  /// Uses `ALTER TABLE ... ADD COLUMN` only, never a table rebuild: dropping a
  /// parent table with foreign keys on would cascade-delete the chat history.
  /// The old `conversations.channel_name` column stays in place, unused.
  static Future<void> _migrateV1ToV2(Database db) async {
    // Channel chats cannot be carried over: they used a different security
    // model (password-derived keys) that v2 no longer has.
    await db.execute("DELETE FROM conversations WHERE type = 'channel'");
    await db.execute('DROP TABLE IF EXISTS channels');

    // Queued v1 packets use the old wire format and can no longer be sent.
    await db.execute('DELETE FROM outbox_sent');
    await db.execute('DELETE FROM outbox');
    await db.execute('DELETE FROM seen_messages');
    await db.execute(
      "UPDATE messages SET status = 'failed', "
      "error = 'The app was updated before this message could be delivered.' "
      "WHERE is_outgoing = 1 AND status IN ('queued', 'sent')",
    );

    await db.execute('ALTER TABLE conversations ADD COLUMN group_id TEXT');
    await db.execute('ALTER TABLE conversations ADD COLUMN room_id TEXT');
    await db.execute("ALTER TABLE messages ADD COLUMN kind TEXT NOT NULL DEFAULT 'text'");
    await db.execute('ALTER TABLE messages ADD COLUMN media_id TEXT');
    await db.execute(
        'ALTER TABLE messages ADD COLUMN recipient_count INTEGER NOT NULL DEFAULT 0');
    await db.execute('ALTER TABLE outbox ADD COLUMN priority INTEGER NOT NULL DEFAULT 1');
    await db.execute('ALTER TABLE outbox ADD COLUMN flood INTEGER NOT NULL DEFAULT 0');
    for (final statement in _newInV2) {
      await db.execute(statement);
    }
  }

  /// v2 -> v3: messages can answer, be forwarded, be edited and expire; pins,
  /// deletion records, pending edits and the public-chat cleanup log get their
  /// own tables.
  ///
  /// Again only `ALTER TABLE ... ADD COLUMN` and new tables: no existing row is
  /// removed or rewritten, and every old message keeps working as it was (never
  /// edited). Messages of public rooms get their expiry.
  static Future<void> _migrateV2ToV3(Database db) async {
    for (final column in _messageColumnsInV3) {
      await db.execute('ALTER TABLE messages ADD COLUMN $column');
    }
    for (final statement in _newInV3) {
      await db.execute(statement);
    }
    // The six-hour rule covers the history public rooms already have: it is
    // counted from each message's own time, so what is overdue goes at the first
    // clean-up.
    await db.execute(
      'UPDATE messages SET expires_at = sort_time + ? '
      "WHERE conversation_id IN (SELECT id FROM conversations WHERE type = 'room')",
      [Protocol.publicMessageRetention.inMilliseconds],
    );
  }

  /// Deletes every row of every table (the schema stays). Used for the
  /// user-confirmed "clear all local data" action.
  Future<void> deleteAllData() async {
    await db.transaction((txn) async {
      for (final table in _tablesInDeleteOrder) {
        await txn.delete(table);
      }
    });
    // Release the freed pages so deleted messages are not left in the file.
    await db.execute('VACUUM');
  }

  static const List<String> _tablesInDeleteOrder = <String>[
    'pinned_messages',
    'deletion_events',
    'edit_events',
    'public_chat_cleanups',
    'outbox_sent',
    'outbox',
    'seen_messages',
    'outgoing_parts',
    'message_receipts',
    'media_chunks',
    'media',
    'messages',
    'conversations',
    'group_members',
    'group_chats',
    'rooms',
    'peers',
    'security_events',
    'settings',
  ];

  /// Tables and indexes that did not exist in v1 (also part of
  /// [schemaStatements] for fresh installs).
  static const List<String> _newInV2 = <String>[
    '''
    CREATE TABLE message_receipts (
      message_id TEXT NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
      member_key TEXT NOT NULL,
      at         INTEGER NOT NULL,
      PRIMARY KEY (message_id, member_key)
    )''',
    '''
    CREATE TABLE group_chats (
      id         TEXT PRIMARY KEY,
      name       TEXT NOT NULL,
      admin_key  TEXT NOT NULL,
      epoch      INTEGER NOT NULL,
      state      TEXT NOT NULL,
      invited_by TEXT,
      created_at INTEGER NOT NULL,
      joined_at  INTEGER
    )''',
    '''
    CREATE TABLE group_members (
      group_id   TEXT NOT NULL REFERENCES group_chats(id) ON DELETE CASCADE,
      member_key TEXT NOT NULL,
      nickname   TEXT NOT NULL DEFAULT '',
      PRIMARY KEY (group_id, member_key)
    )''',
    '''
    CREATE TABLE rooms (
      id            TEXT PRIMARY KEY,
      name          TEXT NOT NULL,
      description   TEXT NOT NULL DEFAULT '',
      creator_key   TEXT NOT NULL,
      created_at    INTEGER NOT NULL,
      expires_at    INTEGER NOT NULL,
      version       INTEGER NOT NULL,
      record        BLOB,
      joined        INTEGER NOT NULL DEFAULT 0,
      builtin       INTEGER NOT NULL DEFAULT 0,
      discovered_at INTEGER NOT NULL,
      last_heard_at INTEGER NOT NULL
    )''',
    '''
    CREATE TABLE media (
      id              TEXT PRIMARY KEY,
      message_id      TEXT NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
      kind            TEXT NOT NULL,
      mime            INTEGER NOT NULL,
      byte_length     INTEGER NOT NULL,
      chunk_count     INTEGER NOT NULL,
      sha256          BLOB NOT NULL,
      key             BLOB,
      width           INTEGER NOT NULL DEFAULT 0,
      height          INTEGER NOT NULL DEFAULT 0,
      duration_ms     INTEGER NOT NULL DEFAULT 0,
      waveform        BLOB,
      state           TEXT NOT NULL,
      received_chunks INTEGER NOT NULL DEFAULT 0,
      file_name       TEXT,
      error           TEXT,
      created_at      INTEGER NOT NULL,
      expires_at      INTEGER NOT NULL
    )''',
    'CREATE INDEX idx_media_message ON media(message_id)',
    '''
    CREATE TABLE media_chunks (
      media_id    TEXT NOT NULL,
      idx         INTEGER NOT NULL,
      data        BLOB NOT NULL,
      sealed      INTEGER NOT NULL DEFAULT 0,
      sender_key  TEXT NOT NULL,
      received_at INTEGER NOT NULL,
      PRIMARY KEY (media_id, idx)
    )''',
    'CREATE INDEX idx_media_chunks_received ON media_chunks(received_at)',
    '''
    CREATE TABLE outgoing_parts (
      packet_id  TEXT PRIMARY KEY,
      message_id TEXT NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
      acked      INTEGER NOT NULL DEFAULT 0
    )''',
    'CREATE INDEX idx_outgoing_parts_message ON outgoing_parts(message_id)',
  ];

  /// Columns messages gained in v3 (part of the table of a fresh install).
  static const List<String> _messageColumnsInV3 = <String>[
    'reply_to        TEXT',
    'forwarded_from  TEXT',
    'edited_at       INTEGER',
    'edit_version    INTEGER NOT NULL DEFAULT 0',
    'expires_at      INTEGER',
  ];

  /// Tables and indexes that did not exist before v3 (also part of
  /// [schemaStatements] for fresh installs).
  static const List<String> _newInV3 = <String>[
    // Pins are personal: nobody else sees or is told about them.
    '''
    CREATE TABLE pinned_messages (
      conversation_id TEXT NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
      message_id      TEXT NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
      pinned_at       INTEGER NOT NULL,
      PRIMARY KEY (conversation_id, message_id)
    )''',
    'CREATE INDEX idx_pinned_conversation ON pinned_messages(conversation_id, pinned_at)',
    // What must never come back: a message deleted here, deleted for everyone,
    // or expired. Holds no content, only the id and why it is gone.
    '''
    CREATE TABLE deletion_events (
      message_id      TEXT PRIMARY KEY,
      conversation_id TEXT NOT NULL,
      requested_by    TEXT NOT NULL,
      scope           TEXT NOT NULL,
      state           TEXT NOT NULL DEFAULT 'applied',
      control_packet  TEXT,
      at              INTEGER NOT NULL,
      expires_at      INTEGER NOT NULL
    )''',
    'CREATE INDEX idx_deletion_expires ON deletion_events(expires_at)',
    'CREATE INDEX idx_deletion_control ON deletion_events(control_packet)',
    // Edits that arrived before the message they change.
    '''
    CREATE TABLE edit_events (
      message_id TEXT NOT NULL,
      version    INTEGER NOT NULL,
      sender_key TEXT NOT NULL,
      body       TEXT NOT NULL,
      at         INTEGER NOT NULL,
      PRIMARY KEY (message_id, version)
    )''',
    // When the public chats were last cleaned, and how much went.
    '''
    CREATE TABLE public_chat_cleanups (
      at       INTEGER PRIMARY KEY,
      removed  INTEGER NOT NULL,
      files    INTEGER NOT NULL DEFAULT 0
    )''',
    'CREATE INDEX idx_messages_expires ON messages(expires_at)',
  ];

  /// The full schema of a freshly installed database.
  static const List<String> schemaStatements = <String>[
    '''
    CREATE TABLE peers (
      public_key    TEXT PRIMARY KEY,
      agreement_key TEXT,
      nickname      TEXT NOT NULL DEFAULT '',
      alias         TEXT,
      verified      INTEGER NOT NULL DEFAULT 0,
      is_contact    INTEGER NOT NULL DEFAULT 0,
      blocked       INTEGER NOT NULL DEFAULT 0,
      first_seen    INTEGER NOT NULL,
      last_seen     INTEGER NOT NULL
    )''',
    '''
    CREATE TABLE conversations (
      id              TEXT PRIMARY KEY,
      type            TEXT NOT NULL,
      title           TEXT NOT NULL,
      peer_key        TEXT,
      group_id        TEXT,
      room_id         TEXT,
      created_at      INTEGER NOT NULL,
      last_message_at INTEGER,
      last_preview    TEXT,
      unread_count    INTEGER NOT NULL DEFAULT 0
    )''',
    '''
    CREATE TABLE messages (
      id              TEXT PRIMARY KEY,
      conversation_id TEXT NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
      sender_key      TEXT NOT NULL,
      sender_nickname TEXT,
      is_outgoing     INTEGER NOT NULL,
      kind            TEXT NOT NULL DEFAULT 'text',
      body            TEXT NOT NULL,
      media_id        TEXT,
      sort_time       INTEGER NOT NULL,
      claimed_time    INTEGER NOT NULL,
      status          TEXT NOT NULL,
      hops            INTEGER NOT NULL DEFAULT 0,
      error           TEXT,
      recipient_count INTEGER NOT NULL DEFAULT 0,
      reply_to        TEXT,
      forwarded_from  TEXT,
      edited_at       INTEGER,
      edit_version    INTEGER NOT NULL DEFAULT 0,
      expires_at      INTEGER
    )''',
    'CREATE INDEX idx_messages_conversation ON messages(conversation_id, sort_time)',
    'CREATE INDEX idx_messages_status ON messages(status)',
    '''
    CREATE TABLE outbox (
      message_id      TEXT PRIMARY KEY,
      kind            TEXT NOT NULL,
      sender_key      TEXT NOT NULL,
      recipient_key   TEXT,
      packet          BLOB NOT NULL,
      created_at      INTEGER NOT NULL,
      expires_at      INTEGER NOT NULL,
      attempts        INTEGER NOT NULL DEFAULT 0,
      next_attempt_at INTEGER NOT NULL,
      priority        INTEGER NOT NULL DEFAULT 1,
      flood           INTEGER NOT NULL DEFAULT 0
    )''',
    'CREATE INDEX idx_outbox_next ON outbox(next_attempt_at)',
    'CREATE INDEX idx_outbox_sender ON outbox(sender_key)',
    '''
    CREATE TABLE outbox_sent (
      message_id   TEXT NOT NULL REFERENCES outbox(message_id) ON DELETE CASCADE,
      neighbor_key TEXT NOT NULL,
      sent_at      INTEGER NOT NULL,
      send_count   INTEGER NOT NULL DEFAULT 1,
      PRIMARY KEY (message_id, neighbor_key)
    )''',
    '''
    CREATE TABLE seen_messages (
      message_id TEXT PRIMARY KEY,
      expires_at INTEGER NOT NULL
    )''',
    'CREATE INDEX idx_seen_expires ON seen_messages(expires_at)',
    '''
    CREATE TABLE security_events (
      id       INTEGER PRIMARY KEY AUTOINCREMENT,
      at       INTEGER NOT NULL,
      kind     TEXT NOT NULL,
      peer_key TEXT,
      detail   TEXT
    )''',
    '''
    CREATE TABLE settings (
      key   TEXT PRIMARY KEY,
      value TEXT NOT NULL
    )''',
    ..._newInV2,
    ..._newInV3,
  ];
}
