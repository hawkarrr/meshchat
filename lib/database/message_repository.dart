import 'dart:async';
import 'dart:typed_data';

import 'package:sqflite/sqlite_api.dart';

import '../core/bytes.dart';
import '../models/conversation.dart';
import '../models/message.dart';
import '../models/peer.dart';
import '../protocol/protocol_constants.dart';
import 'data_changes.dart';
import '../models/message_preview.dart';

export 'data_changes.dart';

/// Result of recording a (verified) sighting of a peer.
class PeerUpdate {
  const PeerUpdate({required this.peer, required this.isNew, required this.keyChanged});

  final Peer peer;
  final bool isNew;

  /// The peer's X25519 key changed while its Ed25519 identity stayed the
  /// same. Any earlier verification is revoked; the user should re-verify.
  final bool keyChanged;
}

/// What happened to an edit event that arrived.
enum EditOutcome {
  /// The text was replaced.
  applied,

  /// The message already has this edit or a newer one.
  older,

  /// The message is not here yet; the edit waits for it.
  pending,

  /// Not allowed: wrong author, wrong conversation, not text, or the message was removed.
  rejected,
}

/// Categories recorded in the security log.
abstract final class SecurityEventKind {
  static const String badSignature = 'bad_signature';
  static const String decryptFailed = 'decrypt_failed';
  static const String linkAuthFailed = 'link_auth_failed';
  static const String malformed = 'malformed';
  static const String rateLimited = 'rate_limited';
  static const String keyChanged = 'key_changed';
  static const String protocolError = 'protocol_error';
  static const String notAMember = 'not_a_member';
  static const String badMedia = 'bad_media';

  /// Somebody asked to change or delete a message they did not write.
  static const String unauthorizedChange = 'unauthorized_change';
}

class SecurityEvent {
  const SecurityEvent({
    required this.id,
    required this.atMs,
    required this.kind,
    this.peerId,
    this.detail,
  });

  final int id;
  final int atMs;
  final String kind;
  final String? peerId;
  final String? detail;
}

/// Persistence for everything the chat UI shows: peers, conversations,
/// messages, the security log and small settings. Groups, rooms and media have
/// their own repositories on the same database.
class MessageRepository {
  MessageRepository(this._db,
      {ChangeBus? bus,
      this.publicRetention = Protocol.publicMessageRetention,
      this.maxPendingEdits = Protocol.maxPendingEdits,
      this.maxRemoteDeletionRecords = Protocol.maxRemoteDeletionRecords})
      : _bus = bus ?? ChangeBus(),
        _ownsBus = bus == null;

  /// How long messages of public rooms are kept (see [Protocol.publicMessageRetention]).
  final Duration publicRetention;

  /// See [Protocol.maxPendingEdits].
  final int maxPendingEdits;

  /// See [Protocol.maxRemoteDeletionRecords].
  final int maxRemoteDeletionRecords;

  final Database _db;
  final ChangeBus _bus;
  final bool _ownsBus;

  static const int _maxSecurityEvents = 300;

  Stream<DataChange> get changes => _bus.stream;

  void _notify(DataChange c) => _bus.notify(c);

  /// Closes the change stream, unless it is shared with other repositories
  /// (whoever created the [ChangeBus] closes it).
  Future<void> dispose() => _ownsBus ? _bus.dispose() : Future<void>.value();

  // ---------------------------------------------------------------------------
  // Peers
  // ---------------------------------------------------------------------------

  Peer _peerFromRow(Map<String, Object?> r) => Peer(
        signingKey: hexToBytes(r['public_key']! as String),
        agreementKey: (r['agreement_key'] as String?) == null
            ? null
            : hexToBytes(r['agreement_key']! as String),
        nickname: (r['nickname'] as String?) ?? '',
        alias: r['alias'] as String?,
        verified: (r['verified'] as int) == 1,
        isContact: (r['is_contact'] as int) == 1,
        blocked: (r['blocked'] as int) == 1,
        firstSeenMs: r['first_seen']! as int,
        lastSeenMs: r['last_seen']! as int,
      );

  /// Records that [signingKey] was seen (after its signature was verified).
  ///
  /// Never changes the verified flag except to revoke it when the peer's
  /// agreement key changes.
  Future<PeerUpdate> upsertPeer({
    required Uint8List signingKey,
    Uint8List? agreementKey,
    String? nickname,
    required int seenAtMs,
  }) async {
    final id = bytesToHex(signingKey);
    final update = await _db.transaction<PeerUpdate>((txn) async {
      final rows = await txn.query('peers', where: 'public_key = ?', whereArgs: [id], limit: 1);
      if (rows.isEmpty) {
        final peer = Peer(
          signingKey: signingKey,
          agreementKey: agreementKey,
          nickname: nickname ?? '',
          firstSeenMs: seenAtMs,
          lastSeenMs: seenAtMs,
        );
        await txn.insert('peers', {
          'public_key': id,
          'agreement_key': agreementKey == null ? null : bytesToHex(agreementKey),
          'nickname': nickname ?? '',
          'verified': 0,
          'is_contact': 0,
          'blocked': 0,
          'first_seen': seenAtMs,
          'last_seen': seenAtMs,
        });
        return PeerUpdate(peer: peer, isNew: true, keyChanged: false);
      }
      final existing = _peerFromRow(rows.first);
      final changes = <String, Object?>{
        'last_seen': seenAtMs > existing.lastSeenMs ? seenAtMs : existing.lastSeenMs,
      };
      var keyChanged = false;
      if (agreementKey != null) {
        final old = existing.agreementKey;
        if (old != null && !constantTimeEquals(old, agreementKey)) {
          keyChanged = true;
          changes['verified'] = 0;
        }
        changes['agreement_key'] = bytesToHex(agreementKey);
      }
      if (nickname != null && nickname.isNotEmpty) {
        changes['nickname'] = nickname;
      }
      await txn.update('peers', changes, where: 'public_key = ?', whereArgs: [id]);
      if (changes.containsKey('nickname')) {
        await _refreshDirectTitle(txn, id);
      }
      final fresh = await txn.query('peers', where: 'public_key = ?', whereArgs: [id], limit: 1);
      return PeerUpdate(peer: _peerFromRow(fresh.first), isNew: false, keyChanged: keyChanged);
    });
    _notify(DataChange.peers);
    return update;
  }

  Future<Peer?> getPeer(String id) async {
    final rows = await _db.query('peers', where: 'public_key = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : _peerFromRow(rows.first);
  }

  /// Contacts first, then recently seen, newest first.
  Future<List<Peer>> listPeers({bool contactsOnly = false}) async {
    final rows = await _db.query(
      'peers',
      where: contactsOnly ? 'is_contact = 1' : null,
      orderBy: 'is_contact DESC, last_seen DESC',
    );
    return rows.map(_peerFromRow).toList();
  }

  Future<void> setContact(String id, bool isContact) async {
    await _db.update('peers', {'is_contact': isContact ? 1 : 0},
        where: 'public_key = ?', whereArgs: [id]);
    _notify(DataChange.peers);
  }

  Future<void> setVerified(String id, bool verified) async {
    await _db.update('peers', {'verified': verified ? 1 : 0},
        where: 'public_key = ?', whereArgs: [id]);
    _notify(DataChange.peers);
  }

  Future<void> setBlocked(String id, bool blocked) async {
    await _db.update('peers', {'blocked': blocked ? 1 : 0},
        where: 'public_key = ?', whereArgs: [id]);
    _notify(DataChange.peers);
  }

  Future<void> setAlias(String id, String? alias) async {
    final value = (alias == null || alias.trim().isEmpty) ? null : alias.trim();
    await _db.transaction((txn) async {
      await txn.update('peers', {'alias': value},
          where: 'public_key = ?', whereArgs: [id]);
      await _refreshDirectTitle(txn, id);
    });
    _notify(DataChange.peers);
    _notify(DataChange.conversations);
  }

  Future<void> deletePeer(String id) async {
    await _db.transaction((txn) async {
      await txn.delete('conversations', where: 'id = ?', whereArgs: [Conversation.directId(id)]);
      await txn.delete('peers', where: 'public_key = ?', whereArgs: [id]);
    });
    _notify(DataChange.peers);
    _notify(DataChange.conversations);
    _notify(DataChange.messages);
  }

  Future<void> _refreshDirectTitle(Transaction txn, String peerId) async {
    final rows = await txn.query('peers', where: 'public_key = ?', whereArgs: [peerId], limit: 1);
    if (rows.isEmpty) return;
    final peer = _peerFromRow(rows.first);
    await txn.update('conversations', {'title': peer.displayName},
        where: 'id = ?', whereArgs: [Conversation.directId(peerId)]);
  }

  // ---------------------------------------------------------------------------
  // Conversations
  // ---------------------------------------------------------------------------

  static ConversationType _typeFromName(String name) => switch (name) {
        'group' => ConversationType.group,
        'room' => ConversationType.room,
        _ => ConversationType.direct,
      };

  Conversation _conversationFromRow(Map<String, Object?> r) => Conversation(
        id: r['id']! as String,
        type: _typeFromName(r['type']! as String),
        title: r['title']! as String,
        peerId: r['peer_key'] as String?,
        groupId: r['group_id'] as String?,
        roomId: r['room_id'] as String?,
        createdAtMs: r['created_at']! as int,
        lastMessageAtMs: r['last_message_at'] as int?,
        lastMessagePreview: r['last_preview'] as String?,
        unreadCount: r['unread_count']! as int,
      );

  Future<Conversation> ensureDirectConversation(Peer peer, {required int nowMs}) async {
    final id = Conversation.directId(peer.id);
    await _db.insert(
      'conversations',
      {
        'id': id,
        'type': 'direct',
        'title': peer.displayName,
        'peer_key': peer.id,
        'created_at': nowMs,
        'unread_count': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    _notify(DataChange.conversations);
    return (await getConversation(id))!;
  }

  Future<Conversation> ensureGroupConversation(
    String groupId,
    String title, {
    required int nowMs,
  }) async {
    final id = Conversation.groupConversationId(groupId);
    await _db.insert(
      'conversations',
      {
        'id': id,
        'type': 'group',
        'title': title,
        'group_id': groupId,
        'created_at': nowMs,
        'unread_count': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    _notify(DataChange.conversations);
    return (await getConversation(id))!;
  }

  Future<Conversation> ensureRoomConversation(
    String roomId,
    String title, {
    required int nowMs,
  }) async {
    final id = Conversation.roomConversationId(roomId);
    await _db.insert(
      'conversations',
      {
        'id': id,
        'type': 'room',
        'title': title,
        'room_id': roomId,
        'created_at': nowMs,
        'unread_count': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    _notify(DataChange.conversations);
    return (await getConversation(id))!;
  }

  Future<void> renameConversation(String id, String title) async {
    await _db.update('conversations', {'title': title}, where: 'id = ?', whereArgs: [id]);
    _notify(DataChange.conversations);
  }

  Future<Conversation?> getConversation(String id) async {
    final rows = await _db.query('conversations', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : _conversationFromRow(rows.first);
  }

  /// Most recently active first; conversations without messages last.
  Future<List<Conversation>> listConversations() async {
    final rows = await _db.query(
      'conversations',
      orderBy: 'COALESCE(last_message_at, created_at) DESC',
    );
    return rows.map(_conversationFromRow).toList();
  }

  /// Resets the unread counter. Notifies only if something changed: a screen
  /// that reloads when conversations change would otherwise trigger itself
  /// forever.
  Future<void> markConversationRead(String id) async {
    final changed = await _db.update('conversations', {'unread_count': 0},
        where: 'id = ? AND unread_count != 0', whereArgs: [id]);
    if (changed > 0) _notify(DataChange.conversations);
  }

  Future<int> totalUnread() async {
    final rows = await _db.rawQuery('SELECT COALESCE(SUM(unread_count), 0) AS n FROM conversations');
    return (rows.first['n'] as int?) ?? 0;
  }

  Future<void> deleteConversation(String id) async {
    await _db.delete('conversations', where: 'id = ?', whereArgs: [id]);
    _notify(DataChange.conversations);
    _notify(DataChange.messages);
  }

  // ---------------------------------------------------------------------------
  // Messages
  // ---------------------------------------------------------------------------

  static const String _messageSelect = 'SELECT m.*, '
      '(SELECT COUNT(*) FROM message_receipts r WHERE r.message_id = m.id) AS receipt_count '
      'FROM messages m';

  ChatMessage _messageFromRow(Map<String, Object?> r) => ChatMessage(
        id: r['id']! as String,
        conversationId: r['conversation_id']! as String,
        senderId: r['sender_key']! as String,
        senderNickname: r['sender_nickname'] as String?,
        isOutgoing: (r['is_outgoing'] as int) == 1,
        kind: MessageKind.parse((r['kind'] as String?) ?? 'text'),
        body: r['body']! as String,
        mediaId: r['media_id'] as String?,
        sortTimeMs: r['sort_time']! as int,
        claimedTimestampMs: r['claimed_time']! as int,
        status: MessageStatus.parse(r['status']! as String),
        hops: r['hops']! as int,
        error: r['error'] as String?,
        recipientCount: (r['recipient_count'] as int?) ?? 0,
        receiptCount: (r['receipt_count'] as int?) ?? 0,
        replyToId: r['reply_to'] as String?,
        forwardedFrom: r['forwarded_from'] as String?,
        editedAtMs: r['edited_at'] as int?,
        editVersion: (r['edit_version'] as int?) ?? 0,
        expiresAtMs: r['expires_at'] as int?,
      );

  /// The summary shown in the chat list, stored as structure (see
  /// [MessagePreview]) so it can be read in any language.
  static String previewOf(ChatMessage m, {required bool showAuthor}) =>
      MessagePreview.of(m, showAuthor: showAuthor).encode();

  /// Stores [m]. Returns false, changing nothing, when a message with the
  /// same id already exists - so relayed or retransmitted copies of a
  /// message can never produce a second chat entry.
  Future<bool> insertMessage(ChatMessage m) async {
    final inserted = await _db.transaction<bool>((txn) async {
      final existing = await txn.query('messages',
          columns: ['id'], where: 'id = ?', whereArgs: [m.id], limit: 1);
      if (existing.isNotEmpty) return false;
      final conv = await txn.query('conversations',
          columns: ['type', 'group_id'], where: 'id = ?', whereArgs: [m.conversationId], limit: 1);
      // Something that was removed (here, by its author, or by expiry) must not
      // come back when a late copy of it arrives.
      if (await _removedForGood(txn, m, conv.isEmpty ? null : conv.first)) return false;
      final showAuthor = conv.isNotEmpty && conv.first['type'] != 'direct';
      final isPublic = conv.isNotEmpty && conv.first['type'] == 'room';
      await txn.insert('messages', {
        'id': m.id,
        'conversation_id': m.conversationId,
        'sender_key': m.senderId,
        'sender_nickname': m.senderNickname,
        'is_outgoing': m.isOutgoing ? 1 : 0,
        'kind': m.kind.name,
        'body': m.body,
        'media_id': m.mediaId,
        'sort_time': m.sortTimeMs,
        'claimed_time': m.claimedTimestampMs,
        'status': m.status.name,
        'hops': m.hops,
        'error': m.error,
        'recipient_count': m.recipientCount,
        'reply_to': m.replyToId,
        'forwarded_from': m.forwardedFrom,
        'edited_at': m.editedAtMs,
        'edit_version': m.editVersion,
        'expires_at': m.expiresAtMs ??
            (isPublic ? m.sortTimeMs + publicRetention.inMilliseconds : null),
      });
      final shown = await _applyPendingEdit(txn, m);
      await txn.rawUpdate(
        'UPDATE conversations SET '
        'last_message_at = MAX(COALESCE(last_message_at, 0), ?), '
        'last_preview = ?, '
        'unread_count = unread_count + ? '
        'WHERE id = ?',
        [
          m.sortTimeMs,
          previewOf(shown, showAuthor: showAuthor),
          m.isOutgoing ? 0 : 1,
          m.conversationId,
        ],
      );
      return true;
    });
    if (inserted) {
      _notify(DataChange.messages);
      _notify(DataChange.conversations);
    }
    return inserted;
  }

  Future<ChatMessage?> getMessage(String id) async {
    final rows = await _db.rawQuery('$_messageSelect WHERE m.id = ? LIMIT 1', [id]);
    return rows.isEmpty ? null : _messageFromRow(rows.first);
  }

  /// The latest [limit] messages of a conversation, oldest first.
  Future<List<ChatMessage>> getMessages(String conversationId, {int limit = 300}) async {
    final rows = await _db.rawQuery(
      '$_messageSelect WHERE m.conversation_id = ? '
      'ORDER BY m.sort_time DESC, m.rowid DESC LIMIT ?',
      [conversationId, limit],
    );
    return rows.reversed.map(_messageFromRow).toList();
  }

  /// Applies a delivery-state transition to an outgoing message.
  ///
  /// Allowed transitions: queued->sent, queued|sent->delivered,
  /// queued|sent->failed, failed->queued. Anything else (in particular a
  /// late "sent" arriving after "delivered") is ignored. Returns whether a
  /// row changed.
  Future<bool> updateOutgoingStatus(
    String id,
    MessageStatus status, {
    int? hops,
    String? error,
  }) async {
    final String allowedFrom;
    switch (status) {
      case MessageStatus.sent:
        allowedFrom = "('queued')";
      case MessageStatus.delivered:
        allowedFrom = "('queued','sent','failed')";
      case MessageStatus.failed:
        allowedFrom = "('queued','sent')";
      case MessageStatus.queued:
        allowedFrom = "('failed')";
      case MessageStatus.received:
      case MessageStatus.undecryptable:
        return false;
    }
    final changed = await _db.rawUpdate(
      'UPDATE messages SET status = ?, hops = COALESCE(?, hops), error = ? '
      'WHERE id = ? AND is_outgoing = 1 AND status IN $allowedFrom',
      [status.name, hops, error, id],
    );
    if (changed > 0) _notify(DataChange.messages);
    return changed > 0;
  }

  Future<void> deleteMessage(String id) async {
    await _db.delete('messages', where: 'id = ?', whereArgs: [id]);
    _notify(DataChange.messages);
  }

  /// Outgoing messages that have not reached a final state.
  Future<List<ChatMessage>> unfinishedOutgoing() async {
    final rows = await _db.rawQuery(
        "$_messageSelect WHERE m.is_outgoing = 1 AND m.status IN ('queued','sent') "
        'ORDER BY m.sort_time ASC');
    return rows.map(_messageFromRow).toList();
  }

  /// Removes messages older than [olderThanMs] (retention policy).
  Future<int> pruneMessagesBefore(int olderThanMs) async {
    final n = await _db.delete('messages', where: 'sort_time < ?', whereArgs: [olderThanMs]);
    if (n > 0) {
      _notify(DataChange.messages);
      _notify(DataChange.conversations);
    }
    return n;
  }

  // ---------------------------------------------------------------------------
  // Removing, editing, pinning and searching messages
  // ---------------------------------------------------------------------------

  /// Whether a deletion record says [m] must not be stored.
  ///
  /// A record made here ("me") or by expiry applies to every copy. A record made
  /// because someone asked all phones to remove a message (it arrived before the
  /// message did) applies only if that someone is allowed to: the author, or the
  /// admin of the group.
  Future<bool> _removedForGood(
    DatabaseExecutor txn,
    ChatMessage m,
    Map<String, Object?>? conversation,
  ) async {
    final rows = await txn.query('deletion_events',
        where: 'message_id = ?', whereArgs: [m.id], limit: 1);
    if (rows.isEmpty) return false;
    final scope = rows.first['scope']! as String;
    if (scope != 'remote') return true;
    final requester = rows.first['requested_by']! as String;
    if (requester == m.senderId) return true;
    final groupId = conversation?['group_id'] as String?;
    if (groupId == null) return false;
    final admin = await txn.query('group_chats',
        columns: ['admin_key'], where: 'id = ?', whereArgs: [groupId], limit: 1);
    return admin.isNotEmpty && admin.first['admin_key'] == requester;
  }

  /// An edit that arrived before its message is applied now that it is here.
  /// Returns the message as it should be shown.
  Future<ChatMessage> _applyPendingEdit(DatabaseExecutor txn, ChatMessage m) async {
    if (m.kind != MessageKind.text || m.isOutgoing) return m;
    final rows = await txn.query('edit_events',
        where: 'message_id = ? AND sender_key = ?',
        whereArgs: [m.id, m.senderId],
        orderBy: 'version DESC',
        limit: 1);
    await txn.delete('edit_events', where: 'message_id = ?', whereArgs: [m.id]);
    if (rows.isEmpty) return m;
    final version = rows.first['version']! as int;
    final body = rows.first['body']! as String;
    final at = rows.first['at']! as int;
    await txn.update('messages', {'body': body, 'edited_at': at, 'edit_version': version},
        where: 'id = ?', whereArgs: [m.id]);
    return ChatMessage(
      id: m.id,
      conversationId: m.conversationId,
      senderId: m.senderId,
      senderNickname: m.senderNickname,
      isOutgoing: m.isOutgoing,
      kind: m.kind,
      body: body,
      mediaId: m.mediaId,
      sortTimeMs: m.sortTimeMs,
      claimedTimestampMs: m.claimedTimestampMs,
      status: m.status,
      hops: m.hops,
      replyToId: m.replyToId,
      forwardedFrom: m.forwardedFrom,
      editedAtMs: at,
      editVersion: version,
    );
  }

  /// Brings the last-message preview and the unread count of a conversation in
  /// line with the messages that are really there.
  Future<void> _refreshSummary(DatabaseExecutor txn, String conversationId) async {
    final conv = await txn.query('conversations',
        columns: ['type'], where: 'id = ?', whereArgs: [conversationId], limit: 1);
    if (conv.isEmpty) return;
    final last = await txn.rawQuery(
        '$_messageSelect WHERE m.conversation_id = ? '
        'ORDER BY m.sort_time DESC, m.rowid DESC LIMIT 1',
        [conversationId]);
    if (last.isEmpty) {
      await txn.update(
          'conversations', {'last_message_at': null, 'last_preview': null, 'unread_count': 0},
          where: 'id = ?', whereArgs: [conversationId]);
      return;
    }
    final m = _messageFromRow(last.first);
    await txn.rawUpdate(
      'UPDATE conversations SET last_message_at = ?, last_preview = ?, '
      'unread_count = MIN(unread_count, '
      '(SELECT COUNT(*) FROM messages WHERE conversation_id = ? AND is_outgoing = 0)) '
      'WHERE id = ?',
      [
        m.sortTimeMs,
        previewOf(m, showAuthor: conv.first['type'] != 'direct'),
        conversationId,
        conversationId,
      ],
    );
  }

  Future<List<ChatMessage>> getMessagesByIds(Iterable<String> ids) async {
    final wanted = ids.toList();
    if (wanted.isEmpty) return const <ChatMessage>[];
    final marks = List.filled(wanted.length, '?').join(',');
    final rows = await _db.rawQuery(
        '$_messageSelect WHERE m.id IN ($marks) ORDER BY m.sort_time ASC, m.rowid ASC', wanted);
    return rows.map(_messageFromRow).toList();
  }

  /// Removes the given messages of [conversationId] from the data layer - not
  /// merely from the screen - together with everything that hangs off them
  /// (picture and voice records, pins, receipts), and records why they are gone
  /// so a late copy is refused. Ids that do not belong to the conversation are
  /// ignored. Returns the messages that were removed.
  ///
  /// [scope] says why: `me` (the person deleted it here), `everyone` (the person
  /// asked all phones to), `remote` (someone else's request, already checked),
  /// `expired` (a public message that ran out of time).
  Future<List<ChatMessage>> removeMessages(
    String conversationId,
    Iterable<String> ids, {
    required String scope,
    required String requestedBy,
    required int atMs,
    String? controlPacket,
    String state = 'applied',
  }) async {
    final removed = <ChatMessage>[];
    await _db.transaction((txn) async {
      for (final id in ids.toSet()) {
        final rows = await txn.rawQuery('$_messageSelect WHERE m.id = ? LIMIT 1', [id]);
        if (rows.isEmpty) continue;
        final m = _messageFromRow(rows.first);
        if (m.conversationId != conversationId) continue;
        await txn.delete('messages', where: 'id = ?', whereArgs: [id]);
        await _recordRemoval(txn, conversationId, id,
            requestedBy: requestedBy,
            scope: scope,
            state: state,
            controlPacket: controlPacket,
            atMs: atMs);
        removed.add(m);
      }
      if (removed.isNotEmpty) await _refreshSummary(txn, conversationId);
    });
    if (removed.isNotEmpty) {
      _notify(DataChange.messages);
      _notify(DataChange.conversations);
    }
    return removed;
  }

  Future<void> _recordRemoval(
    DatabaseExecutor txn,
    String conversationId,
    String messageId, {
    required String requestedBy,
    required String scope,
    required String state,
    String? controlPacket,
    required int atMs,
  }) =>
      txn.insert(
        'deletion_events',
        {
          'message_id': messageId,
          'conversation_id': conversationId,
          'requested_by': requestedBy,
          'scope': scope,
          'state': state,
          'control_packet': controlPacket,
          'at': atMs,
          'expires_at': atMs + Protocol.deletionRecordRetention.inMilliseconds,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  /// Someone asked all phones to remove a message this phone has not received
  /// (yet). It is dropped on arrival if the request came from somebody allowed
  /// to make it.
  Future<void> rememberRemoteDeletion(
    String conversationId,
    String messageId,
    String requestedBy,
    int atMs,
  ) async {
    await _db.insert(
      'deletion_events',
      {
        'message_id': messageId,
        'conversation_id': conversationId,
        'requested_by': requestedBy,
        'scope': 'remote',
        'state': 'applied',
        'at': atMs,
        'expires_at': atMs + Protocol.deletionRecordRetention.inMilliseconds,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    await _keepNewest(_db, 'deletion_events', maxRemoteDeletionRecords, where: "scope = 'remote'");
  }

  /// Keeps [table] to at most [cap] rows (of those matching [where]), dropping the
  /// oldest first. Both arguments come from constants in this file, never from the
  /// network. A flood of made-up records must not grow the database without end.
  Future<void> _keepNewest(DatabaseExecutor db, String table, int cap,
      {String where = '1 = 1'}) async {
    await db.rawDelete(
      'DELETE FROM $table WHERE rowid IN ('
      'SELECT rowid FROM $table WHERE $where ORDER BY at ASC, rowid ASC '
      'LIMIT MAX(0, (SELECT COUNT(*) FROM $table WHERE $where) - ?))',
      [cap],
    );
  }

  Future<bool> wasRemoved(String messageId) async {
    final rows = await _db.query('deletion_events',
        columns: ['message_id'], where: 'message_id = ?', whereArgs: [messageId], limit: 1);
    return rows.isNotEmpty;
  }

  /// How far our own "delete for everyone" request got: `queued`, `sent` or
  /// `delivered` (a direct recipient confirmed it). Null if we never asked.
  Future<String?> deletionRequestState(String messageId) async {
    final rows = await _db.query('deletion_events',
        columns: ['scope', 'state'], where: 'message_id = ?', whereArgs: [messageId], limit: 1);
    if (rows.isEmpty || rows.first['scope'] != 'everyone') return null;
    return rows.first['state']! as String;
  }

  /// The record of a delete request we sent, found by the id of its packet.
  Future<({String messageId, String conversationId})?> deletionByControlPacket(
      String controlPacket) async {
    final rows = await _db.query('deletion_events',
        columns: ['message_id', 'conversation_id'],
        where: 'control_packet = ?',
        whereArgs: [controlPacket],
        limit: 1);
    if (rows.isEmpty) return null;
    return (
      messageId: rows.first['message_id']! as String,
      conversationId: rows.first['conversation_id']! as String
    );
  }

  /// A delete request ran out of time without being confirmed.
  Future<void> expireDeletionRequest(String controlPacket) async {
    final changed = await _db.update(
      'deletion_events',
      {'state': 'expired'},
      where: "control_packet = ? AND state NOT IN ('delivered', 'expired')",
      whereArgs: [controlPacket],
    );
    if (changed > 0) _notify(DataChange.messages);
  }

  /// How many of our "delete for everyone" requests in [conversationId] are in
  /// each state (`queued`, `sent`, `delivered`, `expired`), for the honest
  /// "waiting for the other phone" line.
  Future<Map<String, int>> deletionRequestCounts(String conversationId) async {
    final rows = await _db.rawQuery(
        'SELECT state, COUNT(*) AS n FROM deletion_events '
        "WHERE conversation_id = ? AND scope = 'everyone' AND control_packet IS NOT NULL "
        'GROUP BY state',
        [conversationId]);
    return {for (final r in rows) r['state']! as String: r['n']! as int};
  }

  /// Moves the state of our own delete request forward (never back).
  Future<void> advanceDeletionRequest(String controlPacket, String state) async {
    const order = {'queued': 0, 'sent': 1, 'delivered': 2};
    final rows = await _db.query('deletion_events',
        columns: ['message_id', 'state'],
        where: "control_packet = ? AND state != 'expired'",
        whereArgs: [controlPacket]);
    var changed = false;
    for (final r in rows) {
      final current = order[r['state']] ?? 0;
      if ((order[state] ?? 0) > current) {
        await _db.update('deletion_events', {'state': state},
            where: 'message_id = ?', whereArgs: [r['message_id']]);
        changed = true;
      }
    }
    // The chat shows how far its delete requests got.
    if (changed) _notify(DataChange.messages);
  }

  /// Applies an edit made by [senderKey] to the text of [messageId].
  ///
  /// Accepted only for a text message of that conversation written by that
  /// sender, and only if [version] is newer than what is there. An edit that
  /// arrives before its message is kept until the message shows up.
  Future<EditOutcome> applyEdit({
    required String conversationId,
    required String messageId,
    required String senderKey,
    required int version,
    required String text,
    required int atMs,
  }) async {
    final outcome = await _db.transaction<EditOutcome>((txn) async {
      final rows = await txn.rawQuery('$_messageSelect WHERE m.id = ? LIMIT 1', [messageId]);
      if (rows.isEmpty) {
        final gone = await txn.query('deletion_events',
            columns: ['message_id'], where: 'message_id = ?', whereArgs: [messageId], limit: 1);
        if (gone.isNotEmpty) return EditOutcome.rejected;
        await txn.insert(
          'edit_events',
          {
            'message_id': messageId,
            'version': version,
            'sender_key': senderKey,
            'body': text,
            'at': atMs,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        await _keepNewest(txn, 'edit_events', maxPendingEdits);
        return EditOutcome.pending;
      }
      final m = _messageFromRow(rows.first);
      if (m.conversationId != conversationId ||
          m.senderId != senderKey ||
          m.isOutgoing ||
          m.kind != MessageKind.text) {
        return EditOutcome.rejected;
      }
      if (version <= m.editVersion) return EditOutcome.older;
      await txn.update('messages', {'body': text, 'edited_at': atMs, 'edit_version': version},
          where: 'id = ?', whereArgs: [messageId]);
      await _refreshSummary(txn, conversationId);
      return EditOutcome.applied;
    });
    if (outcome == EditOutcome.applied) {
      _notify(DataChange.messages);
      _notify(DataChange.conversations);
    }
    return outcome;
  }

  /// Changes the text of one of our own messages. [version] must be newer than
  /// the one before it.
  Future<bool> updateOwnText(String messageId, String text, int version, int atMs) async {
    final changed = await _db.transaction<bool>((txn) async {
      final n = await txn.rawUpdate(
        'UPDATE messages SET body = ?, edited_at = ?, edit_version = ? '
        "WHERE id = ? AND is_outgoing = 1 AND kind = 'text' AND edit_version < ?",
        [text, atMs, version, messageId, version],
      );
      if (n == 0) return false;
      final conv = await txn.query('messages',
          columns: ['conversation_id'], where: 'id = ?', whereArgs: [messageId], limit: 1);
      await _refreshSummary(txn, conv.first['conversation_id']! as String);
      return true;
    });
    if (changed) {
      _notify(DataChange.messages);
      _notify(DataChange.conversations);
    }
    return changed;
  }

  // ---- pins (personal) ---------------------------------------------------------------

  Future<bool> setPinned(String conversationId, String messageId, bool pinned, int atMs) async {
    final changed = await _db.transaction<bool>((txn) async {
      if (!pinned) {
        return await txn.delete('pinned_messages',
                where: 'conversation_id = ? AND message_id = ?',
                whereArgs: [conversationId, messageId]) >
            0;
      }
      final exists = await txn.query('messages',
          columns: ['id'],
          where: 'id = ? AND conversation_id = ?',
          whereArgs: [messageId, conversationId],
          limit: 1);
      if (exists.isEmpty) return false;
      final id = await txn.insert(
        'pinned_messages',
        {'conversation_id': conversationId, 'message_id': messageId, 'pinned_at': atMs},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      return id > 0;
    });
    if (changed) _notify(DataChange.messages);
    return changed;
  }

  /// The pinned messages of a conversation, most recently pinned first.
  Future<List<ChatMessage>> pinnedMessages(String conversationId) async {
    final rows = await _db.rawQuery(
      '$_messageSelect JOIN pinned_messages p ON p.message_id = m.id '
      'WHERE p.conversation_id = ? ORDER BY p.pinned_at DESC, m.rowid DESC',
      [conversationId],
    );
    return rows.map(_messageFromRow).toList();
  }

  Future<Set<String>> pinnedIds(String conversationId) async {
    final rows = await _db.query('pinned_messages',
        columns: ['message_id'], where: 'conversation_id = ?', whereArgs: [conversationId]);
    return {for (final r in rows) r['message_id']! as String};
  }

  // ---- search ------------------------------------------------------------------------------

  /// Messages of one conversation that match [query] (in the text or the
  /// caption), optionally only of some [kinds] or from one sender. Newest first.
  /// Removed and expired messages are gone from the table, so they never show up.
  Future<List<ChatMessage>> searchMessages(
    String conversationId, {
    String query = '',
    Set<MessageKind>? kinds,
    String? senderId,
    int limit = 200,
  }) async {
    final where = <String>['m.conversation_id = ?'];
    final args = <Object?>[conversationId];
    final needle = query.trim();
    if (needle.isNotEmpty) {
      where.add("m.body LIKE ? ESCAPE '\\'");
      args.add('%${needle.replaceAll('\\', '\\\\').replaceAll('%', '\\%').replaceAll('_', '\\_')}%');
    }
    if (kinds != null && kinds.isNotEmpty) {
      where.add('m.kind IN (${List.filled(kinds.length, '?').join(',')})');
      args.addAll(kinds.map((k) => k.name));
    }
    if (senderId != null) {
      where.add('m.sender_key = ?');
      args.add(senderId);
    }
    args.add(limit);
    final rows = await _db.rawQuery(
      '$_messageSelect WHERE ${where.join(' AND ')} '
      'ORDER BY m.sort_time DESC, m.rowid DESC LIMIT ?',
      args,
    );
    return rows.map(_messageFromRow).toList();
  }

  // ---- public chat expiry ------------------------------------------------------------

  /// Removes every public-room message whose time is up, remembering their ids
  /// as expired. Touches nothing else: only rows that have an expiry (set for
  /// public rooms alone) can be removed here. Returns what was removed.
  Future<List<ChatMessage>> removeExpiredPublic(int nowMs) async {
    final removed = <ChatMessage>[];
    await _db.transaction((txn) async {
      final rows = await txn.rawQuery(
          '$_messageSelect WHERE m.expires_at IS NOT NULL AND m.expires_at <= ? '
          "AND m.conversation_id IN (SELECT id FROM conversations WHERE type = 'room')",
          [nowMs]);
      final touched = <String>{};
      for (final r in rows) {
        final m = _messageFromRow(r);
        await txn.delete('messages', where: 'id = ?', whereArgs: [m.id]);
        await _recordRemoval(txn, m.conversationId, m.id,
            requestedBy: '', scope: 'expired', state: 'applied', atMs: nowMs);
        touched.add(m.conversationId);
        removed.add(m);
      }
      for (final c in touched) {
        await _refreshSummary(txn, c);
      }
    });
    if (removed.isNotEmpty) {
      _notify(DataChange.messages);
      _notify(DataChange.conversations);
    }
    return removed;
  }

  Future<void> recordPublicCleanup(int atMs, {required int removed, int files = 0}) async {
    await _db.insert('public_chat_cleanups', {'at': atMs, 'removed': removed, 'files': files},
        conflictAlgorithm: ConflictAlgorithm.replace);
    await _db.delete('public_chat_cleanups',
        where: 'at < ?', whereArgs: [atMs - const Duration(days: 30).inMilliseconds]);
  }

  /// When the public chats were last cleaned, and how many messages went.
  Future<({int at, int removed})?> lastPublicCleanup() async {
    final rows = await _db.query('public_chat_cleanups', orderBy: 'at DESC', limit: 1);
    if (rows.isEmpty) return null;
    return (at: rows.first['at']! as int, removed: rows.first['removed']! as int);
  }

  Future<int> messageCount() async {
    final rows = await _db.rawQuery('SELECT COUNT(*) AS n FROM messages');
    return (rows.first['n'] as int?) ?? 0;
  }

  /// The ids of every message that carries a picture, recording or video, by
  /// conversation.
  Future<Map<String, List<String>>> mediaMessageIds() async {
    final rows = await _db.rawQuery("SELECT conversation_id, id FROM messages WHERE kind != 'text'");
    final out = <String, List<String>>{};
    for (final r in rows) {
      (out[r['conversation_id']! as String] ??= <String>[]).add(r['id']! as String);
    }
    return out;
  }

  /// Messages of public rooms that are waiting to expire.
  Future<int> publicMessageCount() async {
    final rows = await _db.rawQuery(
        "SELECT COUNT(*) AS n FROM messages WHERE conversation_id IN "
        "(SELECT id FROM conversations WHERE type = 'room')");
    return (rows.first['n'] as int?) ?? 0;
  }

  /// Forgets deletion records and pending edits that can no longer matter.
  Future<void> purgeStaleRecords(int nowMs) async {
    await _db.delete('deletion_events', where: 'expires_at <= ?', whereArgs: [nowMs]);
    await _db.delete('edit_events',
        where: 'at < ?',
        whereArgs: [nowMs - Protocol.deletionRecordRetention.inMilliseconds]);
  }

  // ---------------------------------------------------------------------------
  // Group delivery receipts
  // ---------------------------------------------------------------------------

  /// Records that [memberKey] confirmed receiving [messageId]. Returns false
  /// when that member had already confirmed (or the message is gone).
  Future<bool> addReceipt(String messageId, String memberKey, int atMs) async {
    final added = await _db.transaction<bool>((txn) async {
      final message = await txn.query('messages',
          columns: ['id'], where: 'id = ?', whereArgs: [messageId], limit: 1);
      if (message.isEmpty) return false;
      final existing = await txn.query('message_receipts',
          columns: ['member_key'],
          where: 'message_id = ? AND member_key = ?',
          whereArgs: [messageId, memberKey],
          limit: 1);
      if (existing.isNotEmpty) return false;
      await txn.insert('message_receipts',
          {'message_id': messageId, 'member_key': memberKey, 'at': atMs});
      return true;
    });
    if (added) _notify(DataChange.messages);
    return added;
  }

  Future<int> receiptCount(String messageId) async {
    final rows = await _db.rawQuery(
        'SELECT COUNT(*) AS n FROM message_receipts WHERE message_id = ?', [messageId]);
    return (rows.first['n'] as int?) ?? 0;
  }

  Future<Set<String>> receiptMembers(String messageId) async {
    final rows = await _db.query('message_receipts',
        columns: ['member_key'], where: 'message_id = ?', whereArgs: [messageId]);
    return {for (final r in rows) r['member_key']! as String};
  }

  // ---------------------------------------------------------------------------
  // Security log
  // ---------------------------------------------------------------------------

  Future<void> recordSecurityEvent(
    String kind, {
    String? peerId,
    String? detail,
    required int atMs,
  }) async {
    await _db.transaction((txn) async {
      await txn.insert('security_events', {
        'at': atMs,
        'kind': kind,
        'peer_key': peerId,
        'detail': detail,
      });
      await txn.rawDelete(
        'DELETE FROM security_events WHERE id <= '
        '(SELECT MAX(id) FROM security_events) - ?',
        [_maxSecurityEvents],
      );
    });
    _notify(DataChange.securityEvents);
  }

  Future<List<SecurityEvent>> securityEvents({int limit = 100}) async {
    final rows = await _db.query('security_events', orderBy: 'id DESC', limit: limit);
    return rows
        .map((r) => SecurityEvent(
              id: r['id']! as int,
              atMs: r['at']! as int,
              kind: r['kind']! as String,
              peerId: r['peer_key'] as String?,
              detail: r['detail'] as String?,
            ))
        .toList();
  }

  Future<int> securityEventCountSince(int sinceMs) async {
    final rows = await _db.rawQuery(
        'SELECT COUNT(*) AS n FROM security_events WHERE at >= ?', [sinceMs]);
    return (rows.first['n'] as int?) ?? 0;
  }

  Future<void> clearSecurityEvents() async {
    await _db.delete('security_events');
    _notify(DataChange.securityEvents);
  }

  // ---------------------------------------------------------------------------
  // Settings
  // ---------------------------------------------------------------------------

  Future<String?> getSetting(String key) async {
    final rows = await _db.query('settings', where: 'key = ?', whereArgs: [key], limit: 1);
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  /// Every setting at once: one query where [getSetting] for each would be a dozen. The app
  /// reads its settings this way when it starts, which is on the way to the first screen.
  Future<Map<String, String>> allSettings() async {
    final rows = await _db.query('settings');
    return {for (final row in rows) row['key'] as String: row['value'] as String};
  }

  Future<void> setSetting(String key, String value) => _db.insert(
        'settings',
        {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  Future<void> removeSetting(String key) =>
      _db.delete('settings', where: 'key = ?', whereArgs: [key]);
}
