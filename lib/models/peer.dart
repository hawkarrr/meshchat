import 'dart:typed_data';

import '../core/bytes.dart';

/// A phone (identity) this app has seen: either a contact the user chose to
/// talk to, or simply somebody whose signed announcement passed through.
///
/// A peer is identified by its Ed25519 public key. Nicknames are chosen by
/// their owners and are NOT unique or authenticated: two people can pick the
/// same nickname. Always show [shortId] next to a nickname.
class Peer {
  Peer({
    required this.signingKey,
    this.agreementKey,
    this.nickname = '',
    this.alias,
    this.verified = false,
    this.isContact = false,
    this.blocked = false,
    required this.firstSeenMs,
    required this.lastSeenMs,
  });

  final Uint8List signingKey;

  /// X25519 key direct messages are encrypted to. Null until a signed
  /// announcement or link handshake from this peer has been seen.
  final Uint8List? agreementKey;

  /// Name the peer announced for itself (untrusted, may collide).
  final String nickname;

  /// Name the local user gave this contact; overrides [nickname] in the UI.
  final String? alias;

  /// True once the user confirmed the safety number out-of-band.
  final bool verified;
  final bool isContact;
  final bool blocked;
  final int firstSeenMs;
  final int lastSeenMs;

  String get id => bytesToHex(signingKey);

  /// First 4 bytes of the id; disambiguates identical nicknames.
  String get shortId => id.substring(0, 8);

  String get displayName {
    final a = alias;
    if (a != null && a.isNotEmpty) return a;
    if (nickname.isNotEmpty) return nickname;
    return 'Peer $shortId';
  }

  /// True when direct messages can be encrypted to this peer.
  bool get canReceiveEncrypted => agreementKey != null;

  Peer copyWith({
    Uint8List? agreementKey,
    String? nickname,
    String? alias,
    bool clearAlias = false,
    bool? verified,
    bool? isContact,
    bool? blocked,
    int? lastSeenMs,
  }) =>
      Peer(
        signingKey: signingKey,
        agreementKey: agreementKey ?? this.agreementKey,
        nickname: nickname ?? this.nickname,
        alias: clearAlias ? null : (alias ?? this.alias),
        verified: verified ?? this.verified,
        isContact: isContact ?? this.isContact,
        blocked: blocked ?? this.blocked,
        firstSeenMs: firstSeenMs,
        lastSeenMs: lastSeenMs ?? this.lastSeenMs,
      );

  @override
  String toString() => 'Peer($displayName $shortId verified=$verified)';
}

/// How (and whether) a peer can be reached right now. Derived only from live
/// evidence: an authenticated link, or a fresh signed announcement received
/// through a currently connected neighbour. Never from stored history alone.
enum Reachability {
  /// Authenticated BLE link to this peer is up.
  direct,

  /// Not connected, but a fresh signed announcement shows a route through
  /// one or more relays and the first hop is currently connected.
  relayed,

  /// No evidence of a usable route.
  offline,
}

class PeerStatus {
  const PeerStatus(this.reachability, {this.hops = 0, this.viaPeerId});

  static const PeerStatus offline = PeerStatus(Reachability.offline);

  final Reachability reachability;

  /// Number of radio links to the peer (1 = direct).
  final int hops;

  /// Id of the neighbour traffic is relayed through (for [Reachability.relayed]).
  final String? viaPeerId;

  bool get isReachable => reachability != Reachability.offline;

  @override
  bool operator ==(Object other) =>
      other is PeerStatus &&
      other.reachability == reachability &&
      other.hops == hops &&
      other.viaPeerId == viaPeerId;

  @override
  int get hashCode => Object.hash(reachability, hops, viaPeerId);

  @override
  String toString() => 'PeerStatus(${reachability.name}, hops=$hops)';
}
