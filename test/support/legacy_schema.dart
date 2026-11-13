import 'package:offline_mesh_chat/database/database_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

bool _initialised = false;

/// The schema of the first release (v1), kept verbatim so the upgrade path to
/// the current schema is tested against what real installs actually contain.
const List<String> legacyV1Schema = <String>[
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
      channel_name    TEXT,
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
      body            TEXT NOT NULL,
      sort_time       INTEGER NOT NULL,
      claimed_time    INTEGER NOT NULL,
      status          TEXT NOT NULL,
      hops            INTEGER NOT NULL DEFAULT 0,
      error           TEXT
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
      next_attempt_at INTEGER NOT NULL
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
    CREATE TABLE channels (
      name         TEXT PRIMARY KEY,
      has_password INTEGER NOT NULL DEFAULT 0,
      joined_at    INTEGER NOT NULL
    )''',
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
];

/// Creates a version-1 database file at [path] and returns it open.
Future<Database> createLegacyV1Database(String path) async {
  if (!_initialised) {
    sqfliteFfiInit();
    _initialised = true;
  }
  return databaseFactoryFfi.openDatabase(
    path,
    options: OpenDatabaseOptions(
      version: 1,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, _) async {
        for (final s in legacyV1Schema) {
          await db.execute(s);
        }
      },
    ),
  );
}


/// The schema of the second release (v2): today's schema without what v3 added
/// (message links, edits and expiry; pins; deletion records; pending edits; the
/// public-chat cleanup log).
List<String> get legacyV2Schema => <String>[
      for (final statement in DatabaseHelper.schemaStatements)
        if (!_v3Only.any(statement.contains))
          statement.contains('CREATE TABLE messages (') ? _messagesV2 : statement,
    ];

const List<String> _v3Only = <String>[
  'pinned_messages',
  'deletion_events',
  'edit_events',
  'public_chat_cleanups',
  'idx_messages_expires',
];

const String _messagesV2 = '''
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
      recipient_count INTEGER NOT NULL DEFAULT 0
    )''';

/// Creates a version-2 database file at [path] and returns it open.
Future<Database> createLegacyV2Database(String path) async {
  if (!_initialised) {
    sqfliteFfiInit();
    _initialised = true;
  }
  return databaseFactoryFfi.openDatabase(
    path,
    options: OpenDatabaseOptions(
      version: 2,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, _) async {
        for (final s in legacyV2Schema) {
          await db.execute(s);
        }
      },
    ),
  );
}
