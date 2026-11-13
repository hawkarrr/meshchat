import 'dart:async';

import '../core/clock.dart';
import '../models/peer.dart';
import '../transport/mesh_transport.dart';

/// A way to reach [destId] through a currently connected neighbour.
class RouteEntry {
  const RouteEntry({
    required this.destId,
    required this.nextHopId,
    required this.linkHops,
    required this.learnedAtMs,
  });

  final String destId;
  final String nextHopId;

  /// Radio links between this phone and the destination (always >= 2 here;
  /// a direct neighbour is not a "route").
  final int linkHops;
  final int learnedAtMs;
}

/// The local view of the network: who is directly connected, and who is
/// reachable through whom.
///
/// Reachability is claimed only on evidence:
///  * **direct** - an authenticated link to the peer is currently up;
///  * **relayed** - a *signed announcement* from the peer arrived recently
///    through a neighbour that is *still connected*.
/// Routes expire after [routeTtl] and vanish immediately when their next hop
/// disconnects. Nothing is inferred from history alone.
class PeerTable {
  PeerTable({
    this._clock = const SystemClock(),
    this.routeTtl = const Duration(seconds: 100),
    this.maxRoutesPerDestination = 3,
  });

  final Clock _clock;
  final Duration routeTtl;
  final int maxRoutesPerDestination;

  final Map<String, NeighborInfo> _neighbors = <String, NeighborInfo>{};
  final Map<String, List<RouteEntry>> _routes = <String, List<RouteEntry>>{};
  final StreamController<void> _changes = StreamController<void>.broadcast();

  /// Fires whenever reachability may have changed.
  Stream<void> get changes => _changes.stream;

  void _notify() {
    if (!_changes.isClosed) _changes.add(null);
  }

  List<NeighborInfo> get neighbors => List.unmodifiable(_neighbors.values);

  NeighborInfo? neighbor(String peerId) => _neighbors[peerId];

  bool isNeighbor(String peerId) => _neighbors.containsKey(peerId);

  void neighborUp(NeighborInfo info) {
    _neighbors[info.peerId] = info;
    // A neighbour is better than any route to it.
    _routes.remove(info.peerId);
    _notify();
  }

  void neighborDown(String peerId) {
    final removed = _neighbors.remove(peerId);
    var changed = removed != null;
    // Routes through a neighbour that is gone are no longer usable.
    for (final list in _routes.values) {
      final before = list.length;
      list.removeWhere((r) => r.nextHopId == peerId);
      if (list.length != before) changed = true;
    }
    _routes.removeWhere((_, list) => list.isEmpty);
    if (changed) _notify();
  }

  /// Records evidence from a verified announcement that [destId] can be
  /// reached via neighbour [viaId].
  ///
  /// [relayHops] is the number of relays the announcement passed through
  /// before reaching us (0 means [viaId] originated it itself).
  ///
  /// Returns true when this created a route or changed one materially (so
  /// queued messages may now have somewhere to go).
  bool learnRoute({
    required String destId,
    required String viaId,
    required int relayHops,
  }) {
    if (relayHops < 1 || destId == viaId) return false; // direct: not a route
    if (!_neighbors.containsKey(viaId)) return false; // can't route through nobody
    if (_neighbors.containsKey(destId)) return false; // already directly connected

    final now = _clock.nowMs;
    final entry = RouteEntry(
      destId: destId,
      nextHopId: viaId,
      linkHops: relayHops + 1,
      learnedAtMs: now,
    );
    final list = _routes.putIfAbsent(destId, () => <RouteEntry>[]);
    final i = list.indexWhere((r) => r.nextHopId == viaId);
    var materiallyChanged = false;
    if (i >= 0) {
      materiallyChanged = list[i].linkHops != entry.linkHops || _isStale(list[i], now);
      list[i] = entry;
    } else {
      list.add(entry);
      materiallyChanged = true;
    }
    list.sort((a, b) {
      final byHops = a.linkHops.compareTo(b.linkHops);
      return byHops != 0 ? byHops : b.learnedAtMs.compareTo(a.learnedAtMs);
    });
    if (list.length > maxRoutesPerDestination) {
      list.removeRange(maxRoutesPerDestination, list.length);
    }
    if (materiallyChanged) _notify();
    return materiallyChanged;
  }

  bool _isStale(RouteEntry r, int now) => now - r.learnedAtMs > routeTtl.inMilliseconds;

  /// Usable routes to [destId], best first: fresh, with a connected next hop.
  List<RouteEntry> routesTo(String destId) {
    final list = _routes[destId];
    if (list == null) return const <RouteEntry>[];
    final now = _clock.nowMs;
    return list
        .where((r) => !_isStale(r, now) && _neighbors.containsKey(r.nextHopId))
        .toList(growable: false);
  }

  /// What the UI may truthfully say about [peerId] right now.
  PeerStatus statusOf(String peerId) {
    if (_neighbors.containsKey(peerId)) {
      return const PeerStatus(Reachability.direct, hops: 1);
    }
    final routes = routesTo(peerId);
    if (routes.isNotEmpty) {
      final best = routes.first;
      return PeerStatus(
        Reachability.relayed,
        hops: best.linkHops,
        viaPeerId: best.nextHopId,
      );
    }
    return PeerStatus.offline;
  }

  /// Every peer id that is currently reachable one way or the other.
  Set<String> get reachablePeerIds {
    final ids = <String>{..._neighbors.keys};
    for (final dest in _routes.keys) {
      if (routesTo(dest).isNotEmpty) ids.add(dest);
    }
    return ids;
  }

  /// Purges stale routes. Returns true if anything was removed.
  bool expireRoutes() {
    final now = _clock.nowMs;
    var changed = false;
    for (final list in _routes.values) {
      final before = list.length;
      list.removeWhere((r) => _isStale(r, now));
      if (list.length != before) changed = true;
    }
    _routes.removeWhere((_, list) => list.isEmpty);
    if (changed) _notify();
    return changed;
  }

  Future<void> dispose() => _changes.close();
}
