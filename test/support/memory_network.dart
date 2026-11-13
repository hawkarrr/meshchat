import 'dart:async';
import 'dart:typed_data';

import 'package:offline_mesh_chat/transport/mesh_transport.dart';

/// One packet that crossed a link, recorded for assertions.
class Delivery {
  Delivery(this.fromId, this.toId, this.bytes);

  final String fromId;
  final String toId;
  final Uint8List bytes;
}

/// A virtual radio environment: nodes connected by explicit links, with knobs
/// to tamper with, drop, duplicate or fail traffic. Delivery is asynchronous
/// (like a real radio) but deterministic.
class MemoryNetwork {
  final Map<String, MemoryTransport> _nodes = <String, MemoryTransport>{};
  final Set<String> _links = <String>{};

  /// Every packet delivered anywhere, in order.
  final List<Delivery> log = <Delivery>[];

  int _inFlight = 0;

  /// Rewrites bytes in transit; return the (possibly modified) bytes, or null
  /// to drop. Receives sender, receiver and the packet.
  Uint8List? Function(String fromId, String toId, Uint8List bytes)? onWire;

  /// When true, every link delivers each packet twice (radio duplication).
  bool duplicateAll = false;

  int get inFlight => _inFlight;

  MemoryTransport createTransport(NeighborInfo self) {
    final t = MemoryTransport._(this, self);
    _nodes[self.peerId] = t;
    return t;
  }

  static String _key(String a, String b) => a.compareTo(b) < 0 ? '$a|$b' : '$b|$a';

  bool isLinked(String a, String b) => _links.contains(_key(a, b));

  Future<void> connect(String a, String b) async {
    if (!_links.add(_key(a, b))) return;
    final ta = _nodes[a]!;
    final tb = _nodes[b]!;
    ta._neighbors[b] = tb.self;
    tb._neighbors[a] = ta.self;
    ta._emit(NeighborUp(tb.self));
    tb._emit(NeighborUp(ta.self));
  }

  Future<void> disconnect(String a, String b, {String reason = 'test'}) async {
    if (!_links.remove(_key(a, b))) return;
    final ta = _nodes[a]!;
    final tb = _nodes[b]!;
    ta._neighbors.remove(b);
    tb._neighbors.remove(a);
    ta._emit(NeighborDown(b, reason));
    tb._emit(NeighborDown(a, reason));
  }

  void _deliver(String from, String to, Uint8List bytes) {
    var payload = bytes;
    final hook = onWire;
    if (hook != null) {
      final changed = hook(from, to, bytes);
      if (changed == null) return; // dropped
      payload = changed;
    }
    final copies = duplicateAll ? 2 : 1;
    for (var i = 0; i < copies; i++) {
      _inFlight++;
      Future<void>.delayed(Duration.zero, () {
        _inFlight--;
        // The link may have gone away while the packet was in the air.
        if (!isLinked(from, to)) return;
        log.add(Delivery(from, to, payload));
        _nodes[to]?._emit(PacketReceived(from, Uint8List.fromList(payload)));
      });
    }
  }

  /// Number of packets that crossed the link from [from] to [to].
  int countSent(String from, String to) =>
      log.where((d) => d.fromId == from && d.toId == to).length;
}

class MemoryTransport implements MeshTransport {
  MemoryTransport._(this._network, this.self);

  final MemoryNetwork _network;
  final NeighborInfo self;
  final Map<String, NeighborInfo> _neighbors = <String, NeighborInfo>{};
  final StreamController<TransportEvent> _controller =
      StreamController<TransportEvent>.broadcast();

  /// Peers whose sends currently fail (simulates a flaky link).
  final Set<String> failSendsTo = <String>{};

  /// Number of sendPacket calls attempted, per peer.
  final Map<String, int> sendAttempts = <String, int>{};

  /// Neighbours the router asked us to drop, with reasons.
  final Map<String, String> dropped = <String, String>{};

  void _emit(TransportEvent e) {
    if (!_controller.isClosed) _controller.add(e);
  }

  /// Injects raw bytes as if [fromId] had sent them (hostile or malformed).
  void inject(String fromId, Uint8List bytes) => _emit(PacketReceived(fromId, bytes));

  @override
  Stream<TransportEvent> get events => _controller.stream;

  @override
  List<NeighborInfo> get neighbors => List.unmodifiable(_neighbors.values);

  @override
  Future<bool> sendPacket(String peerId, Uint8List packetBytes) async {
    sendAttempts[peerId] = (sendAttempts[peerId] ?? 0) + 1;
    if (!_neighbors.containsKey(peerId) || failSendsTo.contains(peerId)) return false;
    _network._deliver(self.peerId, peerId, packetBytes);
    return true;
  }

  @override
  Future<void> dropNeighbor(String peerId, String reason) async {
    dropped[peerId] = reason;
    await _network.disconnect(self.peerId, peerId, reason: reason);
  }

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}
}
