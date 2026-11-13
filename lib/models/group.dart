import 'dart:typed_data';

import '../core/bytes.dart';

/// Where a group stands for this phone.
enum GroupState {
  /// Someone invited us; nothing is shown in chats until we accept.
  invited,

  /// We are a member and can send and receive.
  active,

  /// We left. The history stays, but we cannot read anything new.
  left,

  /// The admin removed us. The history stays, but nothing new can be read.
  removed;

  static GroupState parse(String name) => GroupState.values.firstWhere(
        (s) => s.name == name,
        orElse: () => GroupState.removed,
      );
}

class GroupMember {
  const GroupMember({required this.id, required this.nickname});

  /// Hex of the member's signing key.
  final String id;

  /// The name the member announced (untrusted, may collide).
  final String nickname;

  Uint8List get key => hexToBytes(id);
}

/// A private group: a fixed set of members who share a random key.
class GroupChat {
  const GroupChat({
    required this.id,
    required this.name,
    required this.adminId,
    required this.epoch,
    required this.state,
    this.invitedBy,
    required this.createdAtMs,
    this.joinedAtMs,
    this.members = const <GroupMember>[],
  });

  /// Hex group id. Random; unrelated to any member's identity.
  final String id;
  final String name;

  /// Hex signing key of the only member who may change the group.
  final String adminId;

  /// Counts key rotations (a rotation happens whenever someone is removed).
  final int epoch;
  final GroupState state;

  /// Who invited us, while [state] is [GroupState.invited].
  final String? invitedBy;
  final int createdAtMs;
  final int? joinedAtMs;
  final List<GroupMember> members;

  Uint8List get idBytes => hexToBytes(id);

  bool get isActive => state == GroupState.active;

  bool isAdmin(String peerId) => peerId == adminId;

  bool hasMember(String peerId) => members.any((m) => m.id == peerId);

  String nicknameOf(String peerId) {
    for (final m in members) {
      if (m.id == peerId) return m.nickname;
    }
    return '';
  }
}
