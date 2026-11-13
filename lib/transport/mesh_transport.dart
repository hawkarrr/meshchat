import 'dart:typed_data';

import '../core/bytes.dart';

/// Which side of the GATT connection this phone played on a link.
enum LinkRole {
  /// We scanned, connected and write to the remote's characteristic.
  central,

  /// The remote connected to our GATT server; we notify it.
  peripheral,
}

/// A directly connected, **authenticated** neighbour: the remote proved it
/// holds the private key behind [signingKey] during the link handshake.
class NeighborInfo {
  NeighborInfo({
    required this.signingKey,
    required this.agreementKey,
    required this.nickname,
    required this.sinceMs,
    this.role,
    this.maxChunk,
    this.rssi,
  });

  final Uint8List signingKey;
  final Uint8List agreementKey;
  final String nickname;
  final int sinceMs;
  final LinkRole? role;
  final int? maxChunk;
  int? rssi;

  String get peerId => bytesToHex(signingKey);

  @override
  String toString() => 'Neighbor(${peerId.substring(0, 8)} "$nickname")';
}

/// Events a transport reports to the mesh layer.
sealed class TransportEvent {
  const TransportEvent();
}

/// A neighbour finished the handshake and is ready for traffic.
class NeighborUp extends TransportEvent {
  const NeighborUp(this.info);

  final NeighborInfo info;
}

/// The link to a neighbour went away (disconnect, timeout, bad behaviour).
class NeighborDown extends TransportEvent {
  const NeighborDown(this.peerId, this.reason);

  final String peerId;
  final String reason;
}

/// Raw bytes of one `MeshPacket` arrived from a directly connected neighbour.
/// Nothing about them is trusted yet.
class PacketReceived extends TransportEvent {
  const PacketReceived(this.fromPeerId, this.bytes);

  final String fromPeerId;
  final Uint8List bytes;
}

/// The mesh layer's view of the radio: "send these bytes to that neighbour"
/// and "tell me who is connected and what they send". Everything BLE-specific
/// stays behind this interface.
abstract interface class MeshTransport {
  Stream<TransportEvent> get events;

  /// Currently connected, authenticated neighbours.
  List<NeighborInfo> get neighbors;

  /// Sends one serialized packet to a directly connected neighbour.
  /// Returns false if there is no such neighbour or the send failed.
  Future<bool> sendPacket(String peerId, Uint8List packetBytes);

  /// Disconnects a neighbour that is misbehaving (invalid packets, flooding).
  Future<void> dropNeighbor(String peerId, String reason);

  Future<void> start();

  Future<void> stop();
}
