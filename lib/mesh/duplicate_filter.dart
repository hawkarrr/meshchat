import 'dart:collection';

import '../core/clock.dart';
import '../database/outbox_repository.dart';

/// Remembers the ids of packets already processed so each is acted on once,
/// however many neighbours send it and however often it is retransmitted.
///
/// The memory is persisted, otherwise a restart would forget everything and
/// re-deliver or re-forward old traffic. It is bounded by [capacity] (oldest
/// entries are evicted first) and entries expire with the packet.
class DuplicateFilter {
  DuplicateFilter({
    required this._store,
    this.capacity = 20000,
    this._clock = const SystemClock(),
  });

  final OutboxRepository _store;
  final Clock _clock;
  final int capacity;

  /// Insertion-ordered: the first key is the oldest.
  final LinkedHashMap<String, int> _seen = LinkedHashMap<String, int>();

  int get size => _seen.length;

  /// Loads persisted ids. Call once at start-up.
  Future<void> load() async {
    final now = _clock.nowMs;
    await _store.pruneSeen(now);
    final stored = await _store.loadSeen(now, limit: capacity);
    _seen
      ..clear()
      ..addAll(stored);
  }

  /// Whether [messageId] was already processed and has not expired.
  bool contains(String messageId) {
    final expires = _seen[messageId];
    if (expires == null) return false;
    if (expires <= _clock.nowMs) {
      _seen.remove(messageId);
      return false;
    }
    return true;
  }

  /// Records [messageId] as processed until [expiresAtMs]. Returns false if
  /// it was already known.
  Future<bool> mark(String messageId, int expiresAtMs) async {
    if (contains(messageId)) return false;
    _seen[messageId] = expiresAtMs;
    while (_seen.length > capacity) {
      _seen.remove(_seen.keys.first);
    }
    await _store.addSeen(messageId, expiresAtMs);
    return true;
  }

  /// Drops expired entries from memory and storage.
  Future<void> prune() async {
    final now = _clock.nowMs;
    _seen.removeWhere((_, expires) => expires <= now);
    await _store.pruneSeen(now);
  }
}
