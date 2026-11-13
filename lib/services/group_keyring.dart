import 'dart:typed_data';

import '../core/bytes.dart';
import '../crypto/key_store.dart';
import 'encryption_service.dart' show GroupSealKey;

/// Holds the keys of the groups this phone belongs to, in the platform
/// keystore (never in the database).
///
/// A group has one key per *epoch*; the epoch rises whenever the membership
/// changes, so a removed member's key stops working for new messages. Older
/// epochs are kept so messages that were still travelling when the key changed
/// can be read.
class GroupKeyring {
  GroupKeyring(this._store);

  final KeyStore _store;

  static String _keyName(String groupId, int epoch) => 'group.$groupId.key.$epoch';

  static String _latestName(String groupId) => 'group.$groupId.latest';

  Uint8List _epochBytes(int epoch) => (ByteWriter()..u32(epoch)).toBytes();

  Future<int?> latestEpoch(String groupId) async {
    final raw = await _store.read(_latestName(groupId));
    if (raw == null || raw.length != 4) return null;
    return ByteReader(raw).u32();
  }

  /// Stores [key] for [epoch]. The newest epoch becomes the one used to send.
  Future<void> put(String groupId, int epoch, Uint8List key) async {
    if (key.length != 32) throw ArgumentError.value(key.length, 'key', 'must be 32 bytes');
    await _store.write(_keyName(groupId, epoch), key);
    final latest = await latestEpoch(groupId);
    if (latest == null || epoch >= latest) {
      await _store.write(_latestName(groupId), _epochBytes(epoch));
    }
  }

  Future<GroupSealKey?> get(String groupId, int epoch) async {
    final key = await _store.read(_keyName(groupId, epoch));
    if (key == null || key.length != 32) return null;
    return GroupSealKey(groupId: hexToBytes(groupId), epoch: epoch, key: key);
  }

  /// The key used to send new messages.
  Future<GroupSealKey?> latest(String groupId) async {
    final epoch = await latestEpoch(groupId);
    return epoch == null ? null : get(groupId, epoch);
  }

  Future<bool> has(String groupId) async => (await latestEpoch(groupId)) != null;

  /// Forgets every key of the group (leaving, being removed, or declining).
  Future<void> remove(String groupId) async {
    final latest = await latestEpoch(groupId);
    if (latest != null) {
      for (var epoch = 0; epoch <= latest; epoch++) {
        await _store.delete(_keyName(groupId, epoch));
      }
    }
    await _store.delete(_latestName(groupId));
  }
}
