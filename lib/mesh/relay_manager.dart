import '../database/outbox_repository.dart';
import '../protocol/mesh_packet.dart';
import 'message_queue.dart';
import 'peer_table.dart';

/// How a packet is being steered.
enum RelayStrategy {
  /// The recipient is a directly connected neighbour: send only to it.
  direct,

  /// A fresh route exists: send only to its next hop.
  route,

  /// No better information (or a broadcast): send to several eligible
  /// neighbours and let them carry it on.
  flood,

  /// Somebody already holds the packet or a route exists but is exhausted;
  /// wait instead of sending more copies.
  hold,
}

class RelayDecision {
  const RelayDecision(this.strategy, this.targets);

  final RelayStrategy strategy;

  /// Neighbour ids to send to now. May be empty.
  final List<String> targets;
}

/// Decides *which neighbours* should receive a packet. Pure: it reads the
/// neighbour/route tables and the send history but changes nothing.
///
/// Rules, in order of preference for directed packets (direct / ack):
///  1. recipient is a neighbour  -> send to it alone;
///  2. a fresh signed route      -> send to its next hop alone;
///  3. otherwise                 -> flood to a few eligible neighbours.
/// Presence-style packets (announce, room announcement) flood to a few
/// neighbours right now and are not kept.
///
/// Group and room packets have no single recipient: they go to *every*
/// neighbour that does not have them yet, exactly once each, and are kept for
/// neighbours that arrive later (store, carry and forward).
///
/// A neighbour is never chosen if it is the one we received the packet from,
/// the packet's author, or it already got a copy (see
/// [MessageQueue.mayResend]). Hop limits are enforced by the caller.
class RelayManager {
  RelayManager({
    required this.table,
    required this.queue,
    this.floodFanout = 4,
  });

  final PeerTable table;
  final MessageQueue queue;

  /// Upper bound on neighbours a single flood goes to, limiting amplification.
  final int floodFanout;

  RelayDecision decide({
    required MeshPacket packet,
    required Map<String, SentRecord> sentTo,
    String? receivedFromId,
  }) {
    final author = packet.senderHex;

    bool usable(String neighborId, {required bool isFinalRecipient}) {
      if (neighborId == receivedFromId || neighborId == author) return false;
      return queue.mayResend(
        previous: sentTo[neighborId],
        neighborIsFinalRecipient: isFinalRecipient,
      );
    }

    List<String> floodTargets() {
      final ids = table.neighbors
          .map((n) => n.peerId)
          .where((id) => usable(id, isFinalRecipient: false))
          .toList()
        ..sort();
      return ids.length > floodFanout ? ids.sublist(0, floodFanout) : ids;
    }

    switch (packet.type) {
      case PacketType.announce:
      case PacketType.roomAnnounce:
        return RelayDecision(RelayStrategy.flood, floodTargets());

      case PacketType.group:
      case PacketType.room:
        // Once per neighbour, no fan-out cap: the number of simultaneous BLE
        // links is small, and every neighbour is a potential carrier.
        final ids = table.neighbors
            .map((n) => n.peerId)
            .where((id) => id != receivedFromId && id != author && !sentTo.containsKey(id))
            .toList()
          ..sort();
        return RelayDecision(ids.isEmpty ? RelayStrategy.hold : RelayStrategy.flood, ids);

      case PacketType.direct:
      case PacketType.ack:
        final recipient = packet.recipientHex;

        if (table.isNeighbor(recipient)) {
          return usable(recipient, isFinalRecipient: true)
              ? RelayDecision(RelayStrategy.direct, [recipient])
              : const RelayDecision(RelayStrategy.hold, <String>[]);
        }

        final routes = table.routesTo(recipient);
        if (routes.isNotEmpty) {
          for (final r in routes) {
            if (usable(r.nextHopId, isFinalRecipient: false)) {
              return RelayDecision(RelayStrategy.route, [r.nextHopId]);
            }
          }
          return const RelayDecision(RelayStrategy.hold, <String>[]);
        }

        final flood = floodTargets();
        return RelayDecision(
          flood.isEmpty ? RelayStrategy.hold : RelayStrategy.flood,
          flood,
        );
    }
  }
}
