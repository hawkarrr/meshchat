import 'package:sqflite/sqlite_api.dart';

import '../models/group.dart';
import 'data_changes.dart';

/// Persistence for private groups and their members. The group keys are NOT
/// here: they live in the platform keystore (see `GroupKeyring`).
class GroupRepository {
  GroupRepository(this._db, {required this._bus});

  final Database _db;
  final ChangeBus _bus;

  GroupChat _fromRow(Map<String, Object?> r, List<GroupMember> members) => GroupChat(
        id: r['id']! as String,
        name: r['name']! as String,
        adminId: r['admin_key']! as String,
        epoch: r['epoch']! as int,
        state: GroupState.parse(r['state']! as String),
        invitedBy: r['invited_by'] as String?,
        createdAtMs: r['created_at']! as int,
        joinedAtMs: r['joined_at'] as int?,
        members: members,
      );

  Future<List<GroupMember>> _members(DatabaseExecutor db, String groupId) async {
    final rows = await db.query('group_members',
        where: 'group_id = ?', whereArgs: [groupId], orderBy: 'rowid ASC');
    return [
      for (final r in rows)
        GroupMember(id: r['member_key']! as String, nickname: (r['nickname'] as String?) ?? ''),
    ];
  }

  Future<GroupChat?> getGroup(String id) async {
    final rows = await _db.query('group_chats', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return _fromRow(rows.first, await _members(_db, id));
  }

  /// All groups, or only those in [states]; newest first.
  Future<List<GroupChat>> listGroups({Iterable<GroupState>? states}) async {
    final wanted = states?.map((s) => s.name).toList();
    final rows = await _db.query(
      'group_chats',
      where: wanted == null ? null : 'state IN (${List.filled(wanted.length, '?').join(',')})',
      whereArgs: wanted,
      orderBy: 'created_at DESC',
    );
    return [for (final r in rows) _fromRow(r, await _members(_db, r['id']! as String))];
  }

  /// Inserts or replaces a group together with its member list.
  Future<void> save(GroupChat group) async {
    await _db.transaction((txn) async {
      final values = {
        'name': group.name,
        'admin_key': group.adminId,
        'epoch': group.epoch,
        'state': group.state.name,
        'invited_by': group.invitedBy,
        'created_at': group.createdAtMs,
        'joined_at': group.joinedAtMs,
      };
      final existing = await txn.query('group_chats',
          columns: ['id'], where: 'id = ?', whereArgs: [group.id], limit: 1);
      if (existing.isEmpty) {
        await txn.insert('group_chats', {'id': group.id, ...values});
      } else {
        await txn.update('group_chats', values, where: 'id = ?', whereArgs: [group.id]);
      }
      await txn.delete('group_members', where: 'group_id = ?', whereArgs: [group.id]);
      for (final m in group.members) {
        await txn.insert('group_members', {
          'group_id': group.id,
          'member_key': m.id,
          'nickname': m.nickname,
        });
      }
    });
    _bus.notify(DataChange.groups);
  }

  Future<void> setState(String id, GroupState state, {int? joinedAtMs}) async {
    await _db.update(
      'group_chats',
      {'state': state.name, 'joined_at': ?joinedAtMs},
      where: 'id = ?',
      whereArgs: [id],
    );
    _bus.notify(DataChange.groups);
  }

  Future<GroupState?> stateOf(String id) async {
    final rows = await _db.query('group_chats',
        columns: ['state'], where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : GroupState.parse(rows.first['state']! as String);
  }

  Future<void> delete(String id) async {
    await _db.delete('group_chats', where: 'id = ?', whereArgs: [id]);
    _bus.notify(DataChange.groups);
  }
}
