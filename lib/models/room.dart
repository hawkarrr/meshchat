import 'dart:typed_data';

import '../core/bytes.dart';

/// A public room: a named place anybody in range can read and post in.
///
/// Rooms are announced by their creator with a signed record. Everything said
/// in a room is visible to every phone that carries it - there is no secrecy
/// here, only authorship and integrity.
class PublicRoom {
  const PublicRoom({
    required this.id,
    required this.name,
    this.description = '',
    required this.creatorId,
    required this.createdAtMs,
    required this.expiresAtMs,
    required this.version,
    this.joined = false,
    this.builtin = false,
    required this.discoveredAtMs,
    required this.lastHeardAtMs,
    this.record,
  });

  /// Hex room id.
  final String id;
  final String name;
  final String description;

  /// Hex signing key of the creator (the only one who may refresh the room).
  final String creatorId;
  final int createdAtMs;
  final int expiresAtMs;
  final int version;
  final bool joined;

  /// The built-in `#mesh` room every phone belongs to.
  final bool builtin;
  final int discoveredAtMs;

  /// Last time a record for this room (or a message in it) was heard.
  final int lastHeardAtMs;

  /// The creator-signed record exactly as received, so we can announce the
  /// room to others without being able to alter it.
  final Uint8List? record;

  Uint8List get idBytes => hexToBytes(id);

  bool isExpiredAt(int nowMs) => !builtin && expiresAtMs <= nowMs;

  bool isMine(String ownId) => creatorId == ownId;

  /// `#name`, as shown in the interface.
  String get label => '#$name';
}
