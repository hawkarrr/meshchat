import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import '../core/app_log.dart';
import '../core/bytes.dart';
import '../core/clock.dart';
import '../core/serial_executor.dart';
import '../core/text.dart';
import '../crypto/weak_keys.dart';
import '../database/message_repository.dart' show SecurityEventKind;
import '../protocol/fragmenter.dart';
import '../protocol/link_frame.dart';
import '../protocol/protocol_constants.dart';
import '../transport/ble_radio.dart';
import '../transport/mesh_transport.dart';
import 'encryption_service.dart';

/// Where a link is in its life.
enum LinkPhase {
  /// GATT link is up; HELLO / AUTH are being exchanged. Carries no traffic.
  handshaking,

  /// The remote proved it owns its key; packets may flow.
  ready,

  /// Being torn down.
  closing,
}

/// A point-in-time description of one link, for the UI and diagnostics.
class LinkSnapshot {
  const LinkSnapshot({
    required this.linkId,
    required this.role,
    required this.deviceId,
    required this.phase,
    required this.peerId,
    required this.nickname,
    required this.maxChunk,
    required this.rssi,
    required this.openedAtMs,
    required this.idleMs,
    required this.framesIn,
    required this.framesOut,
    required this.bytesIn,
    required this.bytesOut,
    required this.lastRttMs,
  });

  final String linkId;
  final LinkRole role;
  final String deviceId;
  final LinkPhase phase;
  final String? peerId;
  final String? nickname;
  final int maxChunk;
  final int? rssi;
  final int openedAtMs;
  final int idleMs;
  final int framesIn;
  final int framesOut;
  final int bytesIn;
  final int bytesOut;
  final int? lastRttMs;
}

/// Result of [BluetoothService.probe].
class ProbeResult {
  const ProbeResult({
    required this.sent,
    required this.received,
    required this.rttMs,
    required this.payloadBytes,
    this.error,
  });

  final int sent;
  final int received;
  final List<int> rttMs;
  final int payloadBytes;
  final String? error;

  int get lost => sent - received;
  int? get minMs => rttMs.isEmpty ? null : rttMs.reduce(min);
  int? get maxMs => rttMs.isEmpty ? null : rttMs.reduce(max);
  int? get avgMs => rttMs.isEmpty ? null : (rttMs.reduce((a, b) => a + b) / rttMs.length).round();
  bool get passed => error == null && sent > 0 && received == sent;
}

/// A phone that was turned away because it speaks another version of the
/// protocol. The two phones cannot talk until one of them is updated.
class VersionMismatch {
  const VersionMismatch({required this.deviceId, required this.version, required this.atMs});

  /// The radio's handle for the other phone (not its identity: the handshake
  /// stopped before that was proven).
  final String deviceId;

  /// The protocol version the other phone speaks.
  final int version;
  final int atMs;

  /// The other phone runs a newer version than this one.
  bool get peerIsNewer => version > Protocol.version;
}

class BluetoothServiceConfig {
  const BluetoothServiceConfig({
    this.maxLinks = 6,
    this.extraIncomingLinks = 2,
    this.maxUnauthenticated = 4,
    this.handshakeTimeout = const Duration(seconds: 10),
    this.maintenanceInterval = const Duration(seconds: 5),
    this.pingAfterIdle = const Duration(seconds: 15),
    this.deadAfter = const Duration(seconds: 45),
    this.frameSendTimeout = const Duration(seconds: 30),
    this.maxStrikes = 5,
    this.rssiInterval = const Duration(seconds: 15),
    this.earlyChunkGrace = const Duration(seconds: 2),
  });

  /// Links this phone will start by connecting out.
  final int maxLinks;

  /// Extra links accepted when others connect to us (we cannot refuse a BLE
  /// connection, only close it afterwards).
  final int extraIncomingLinks;

  /// Links allowed to sit in the handshake at the same time.
  final int maxUnauthenticated;

  final Duration handshakeTimeout;
  final Duration maintenanceInterval;

  /// A silent link gets a keepalive PING after this long...
  final Duration pingAfterIdle;

  /// ...and is closed after this long without ANY data. This is the only
  /// reliable way to notice a vanished neighbour on an iOS peripheral, which
  /// is told nothing when a central disappears.
  final Duration deadAfter;

  final Duration frameSendTimeout;

  /// Protocol violations tolerated on one link before it is dropped.
  final int maxStrikes;
  final Duration rssiInterval;
  final Duration earlyChunkGrace;
}

typedef SecurityEventSink = Future<void> Function(
  String kind, {
  String? peerId,
  String? detail,
});

class _PeerLink {
  _PeerLink({
    required this.linkId,
    required this.role,
    required this.deviceId,
    required this.openedAtMs,
    required this.myNonce,
    required this.myNickname,
    required this.nextFrameId,
    required Clock clock,
  })  : reassembler = FrameReassembler(clock: clock),
        lastRxMs = openedAtMs,
        lastTxMs = openedAtMs;

  final String linkId;
  final LinkRole role;
  final String deviceId;
  final int openedAtMs;
  final Uint8List myNonce;
  final String myNickname;
  final FrameReassembler reassembler;

  /// Whole frames go out one at a time so their chunks never interleave.
  final SerialExecutor sender = SerialExecutor();

  /// Received frames are processed one at a time, in order, because handling
  /// one (verifying a signature) is asynchronous and the next must not
  /// overtake it.
  final SerialExecutor receiver = SerialExecutor();

  int nextFrameId;
  LinkPhase phase = LinkPhase.handshaking;
  HelloFrame? remoteHello;
  bool authSent = false;
  bool authVerified = false;
  String? peerId;
  String? peerNickname;
  int lastRxMs;
  int lastTxMs;
  int lastPingMs = 0;
  int lastRssiMs = 0;
  int? rssi;
  int? lastRttMs;
  int framesIn = 0;
  int framesOut = 0;
  int bytesIn = 0;
  int bytesOut = 0;
  int strikes = 0;
  int pingSeq = 0;
  final Map<int, (int sentAtMs, Completer<int> done)> pendingPings =
      <int, (int, Completer<int>)>{};
}

/// The Bluetooth transport: turns the radio's raw per-link byte chunks into
/// authenticated, packet-carrying neighbour connections for the mesh layer.
///
/// For every link, whichever side opened it:
///  1. both ends send HELLO (identity keys, nickname, fresh random challenge);
///  2. each answers the other's challenge with AUTH - a signature over both
///     challenges and both identities, proving it holds the private key;
///  3. only then is the neighbour announced ([NeighborUp]) and packets flow.
///
/// Frames larger than one BLE write are fragmented and reassembled. Keepalives
/// detect dead links. If two links to the same phone exist (both phones
/// connected to each other at once), exactly one survives - chosen by a rule
/// both ends compute identically.
class BluetoothService implements MeshTransport {
  BluetoothService({
    required this.radio,
    required this.crypto,
    required this.nickname,
    this.config = const BluetoothServiceConfig(),
    this.clock = const SystemClock(),
    this.onSecurityEvent,
    AppLog? log,
    Random? random,
  })  : _log = log ?? AppLog.instance,
        _random = random ?? Random.secure();

  final BleRadio radio;
  final EncryptionService crypto;

  /// Supplies the current display name (read when a link opens).
  final String Function() nickname;
  final BluetoothServiceConfig config;
  final Clock clock;
  final SecurityEventSink? onSecurityEvent;
  final AppLog _log;
  final Random _random;

  static const String _tag = 'Link';

  final Map<String, _PeerLink> _links = <String, _PeerLink>{};
  final Map<String, _PeerLink> _byPeer = <String, _PeerLink>{};

  /// Which authenticated peer each remote device handle turned out to be.
  /// Kept after a link closes so the discovery policy can tell "that device is
  /// somebody we are already connected to through another link" and NOT
  /// reconnect to it (which would just recreate a duplicate link forever).
  final Map<String, String> _deviceToPeer = <String, String>{};
  final Map<String, List<Uint8List>> _earlyChunks = <String, List<Uint8List>>{};
  final Map<String, int> _earlyStartedAt = <String, int>{};

  /// Phones turned away for speaking another protocol version, oldest first.
  final List<VersionMismatch> _versionMismatches = <VersionMismatch>[];
  static const int _maxVersionMismatches = 32;

  /// A phone turned away for its version again within this time is not written
  /// to the security log again.
  static const Duration _versionMismatchQuiet = Duration(minutes: 10);

  final StreamController<TransportEvent> _events = StreamController<TransportEvent>.broadcast();
  final StreamController<void> _linksChanged = StreamController<void>.broadcast();

  StreamSubscription<RadioLinkEvent>? _linkSub;
  StreamSubscription<RadioChunk>? _chunkSub;
  Timer? _maintenanceTimer;
  bool _started = false;

  // ---------------------------------------------------------------------------
  // MeshTransport
  // ---------------------------------------------------------------------------

  @override
  Stream<TransportEvent> get events => _events.stream;

  /// Fires whenever any link appears, changes phase or goes away.
  Stream<void> get linksChanged => _linksChanged.stream;

  @override
  List<NeighborInfo> get neighbors => _byPeer.values
      .where((l) => l.phase == LinkPhase.ready)
      .map(_neighborInfo)
      .toList(growable: false);

  /// Links of every phase, handshaking ones included.
  int get linkCount => _links.length;

  bool hasLink(String linkId) => _links.containsKey(linkId);

  /// The authenticated peer behind a remote device handle, if a handshake
  /// with that device ever completed.
  String? peerForDevice(String deviceId) => _deviceToPeer[deviceId];

  /// Whether [peerId] currently has a ready link.
  bool isNeighbor(String peerId) => _byPeer[peerId]?.phase == LinkPhase.ready;

  List<LinkSnapshot> get linkSnapshots => _links.values.map(_snapshot).toList(growable: false);

  /// Phones turned away because they speak another protocol version, oldest
  /// first (the last 32 are remembered, in memory only).
  List<VersionMismatch> get versionMismatches => List.unmodifiable(_versionMismatches);

  /// Those turned away after [afterMs].
  List<VersionMismatch> versionMismatchesAfter(int afterMs) =>
      [for (final m in _versionMismatches) if (m.atMs > afterMs) m];

  /// When [deviceId] was last turned away for its protocol version, or null.
  int? otherVersionSeenAt(String deviceId) {
    for (final m in _versionMismatches.reversed) {
      if (m.deviceId == deviceId) return m.atMs;
    }
    return null;
  }

  @override
  Future<void> start() async {
    if (_started) return;
    _started = true;
    _linkSub = radio.linkEvents.listen(_onLinkEvent);
    _chunkSub = radio.chunks.listen(_onChunk);
    _maintenanceTimer = Timer.periodic(config.maintenanceInterval, (_) => _maintain());
  }

  @override
  Future<void> stop() async {
    if (!_started) return;
    _started = false;
    _maintenanceTimer?.cancel();
    await _linkSub?.cancel();
    await _chunkSub?.cancel();
    for (final link in _links.values.toList()) {
      await _closeLink(link,
          reason: 'shutting down', sendBye: true, bye: ByeReason.shuttingDown);
    }
    _earlyChunks.clear();
    _earlyStartedAt.clear();
  }

  /// Closes streams. The service cannot be restarted afterwards.
  Future<void> dispose() async {
    await stop();
    await _events.close();
    await _linksChanged.close();
  }

  @override
  Future<bool> sendPacket(String peerId, Uint8List packetBytes) async {
    final link = _byPeer[peerId];
    if (link == null || link.phase != LinkPhase.ready) return false;
    if (packetBytes.length > Protocol.maxPacketBytes) return false;
    try {
      await _sendFrame(link, PacketFrame(packetBytes)).timeout(config.frameSendTimeout);
      return true;
    } on TimeoutException {
      _log.w(_tag, 'send to ${_short(peerId)} timed out; dropping the link');
      unawaited(_closeLink(link, reason: 'send timed out'));
      return false;
    } catch (e) {
      _log.d(_tag, 'send to ${_short(peerId)} failed: $e');
      return false;
    }
  }

  @override
  Future<void> dropNeighbor(String peerId, String reason) async {
    final link = _byPeer[peerId];
    if (link == null) return;
    await _closeLink(link, reason: reason, sendBye: true, bye: ByeReason.rateLimited);
  }

  // ---------------------------------------------------------------------------
  // Connecting out
  // ---------------------------------------------------------------------------

  /// Whether this phone may start another outgoing connection now.
  bool get hasFreeLinkSlot => _links.length < config.maxLinks;

  /// Connects to a discovered device. Returns the link id once the GATT link
  /// is usable; the handshake then proceeds in the background and ends in a
  /// [NeighborUp] (or the link being closed).
  Future<String> connectTo(String deviceId) async {
    if (!hasFreeLinkSlot) {
      throw const RadioException(RadioErrorKind.notReady, 'Link limit reached');
    }
    return radio.connect(deviceId);
  }

  // ---------------------------------------------------------------------------
  // Radio events
  // ---------------------------------------------------------------------------

  void _onLinkEvent(RadioLinkEvent event) {
    switch (event) {
      case RadioLinkOpened():
        _handleOpened(event);
      case RadioLinkClosed():
        final link = _links[event.linkId];
        if (link != null) {
          unawaited(_closeLink(link, reason: event.reason, fromRadio: true));
        }
        _earlyChunks.remove(event.linkId);
        _earlyStartedAt.remove(event.linkId);
    }
  }

  void _handleOpened(RadioLinkOpened e) {
    if (_links.containsKey(e.linkId)) return;
    final handshaking = _links.values.where((l) => l.phase == LinkPhase.handshaking).length;
    if (_links.length >= config.maxLinks + config.extraIncomingLinks ||
        handshaking >= config.maxUnauthenticated) {
      _log.w(_tag, 'refusing link ${e.linkId}: at capacity');
      unawaited(radio.disconnect(e.linkId));
      return;
    }
    final link = _PeerLink(
      linkId: e.linkId,
      role: e.role,
      deviceId: e.deviceId,
      openedAtMs: clock.nowMs,
      myNonce: Uint8List.fromList(List<int>.generate(HelloFrame.nonceLength, (_) => _random.nextInt(256))),
      myNickname: sanitizeDisplayName(nickname()),
      nextFrameId: _random.nextInt(0x10000),
      clock: clock,
    );
    _links[e.linkId] = link;
    _log.i(_tag, 'link ${e.linkId} opened (${e.role.name}, chunk ${e.maxChunk})');
    _notifyLinks();

    // Data that raced ahead of this event.
    final early = _earlyChunks.remove(e.linkId);
    _earlyStartedAt.remove(e.linkId);
    if (early != null) {
      for (final chunk in early) {
        _receiveChunk(link, chunk);
      }
    }
    unawaited(_sendHello(link));
  }

  void _onChunk(RadioChunk c) {
    final link = _links[c.linkId];
    if (link == null) {
      // Can beat the matching link-opened event by a moment.
      final list = _earlyChunks.putIfAbsent(c.linkId, () => <Uint8List>[]);
      _earlyStartedAt.putIfAbsent(c.linkId, () => clock.nowMs);
      if (list.length < 32) list.add(c.data);
      return;
    }
    _receiveChunk(link, c.data);
  }

  // ---------------------------------------------------------------------------
  // Receiving
  // ---------------------------------------------------------------------------

  void _receiveChunk(_PeerLink link, Uint8List data) {
    if (link.phase == LinkPhase.closing) return;
    link.lastRxMs = clock.nowMs;
    link.bytesIn += data.length;
    final Uint8List? frameBytes;
    try {
      frameBytes = link.reassembler.add(data);
    } on FormatException catch (e) {
      _strike(link, 'bad chunk: ${e.message}');
      return;
    }
    if (frameBytes == null) return;
    link.framesIn++;
    final LinkFrame frame;
    try {
      frame = LinkFrame.decode(frameBytes);
    } on UnsupportedVersionException catch (e) {
      // Not a broken frame: a phone with another version of the app.
      unawaited(link.receiver.run(() => _onOtherVersion(link, e.version)).catchError((Object err) {
        _log.e(_tag, 'turning away ${link.linkId} failed: $err');
      }));
      return;
    } on LinkFrameException catch (e) {
      _strike(link, 'bad frame: ${e.message}');
      return;
    }
    unawaited(link.receiver.run(() => _handleFrame(link, frame)).catchError((Object e) {
      _log.e(_tag, 'handling a frame on ${link.linkId} failed: $e');
    }));
  }

  Future<void> _handleFrame(_PeerLink link, LinkFrame frame) async {
    if (link.phase == LinkPhase.closing) return;
    switch (frame) {
      case HelloFrame():
        await _onHello(link, frame);
      case AuthFrame():
        await _onAuth(link, frame);
      case PingFrame():
        if (link.remoteHello != null) {
          try {
            await _sendFrame(link, PongFrame(frame.data));
          } catch (_) {
            // The link is failing; the keepalive logic will notice.
          }
        }
      case PongFrame():
        _onPong(link, frame);
      case ByeFrame():
        _log.i(_tag, 'link ${link.linkId}: peer said goodbye (${frame.reason.name})');
        await _closeLink(link, reason: 'peer closed: ${frame.reason.name}');
      case PacketFrame():
        if (link.phase != LinkPhase.ready || link.peerId == null) {
          _strike(link, 'packet before the handshake finished');
        } else {
          _events.add(PacketReceived(link.peerId!, frame.packetBytes));
        }
    }
  }

  // ---------------------------------------------------------------------------
  // Handshake
  // ---------------------------------------------------------------------------

  Future<void> _sendHello(_PeerLink link) async {
    final hello = HelloFrame(
      protocolVersion: Protocol.version,
      signingKey: crypto.identity.signingPublicKey,
      agreementKey: crypto.identity.agreementPublicKey,
      nonce: link.myNonce,
      nickname: link.myNickname,
    );
    try {
      await _sendFrame(link, hello);
    } catch (e) {
      await _closeLink(link, reason: 'could not send HELLO: $e');
    }
  }

  Future<void> _onHello(_PeerLink link, HelloFrame hello) async {
    if (link.remoteHello != null) {
      _strike(link, 'second HELLO');
      return;
    }
    if (hello.protocolVersion != Protocol.version) {
      // Decoding already refuses another version; this is a second guard.
      await _onOtherVersion(link, hello.protocolVersion);
      return;
    }
    if (!isUsableEd25519PublicKey(hello.signingKey) || isAllZero(hello.agreementKey)) {
      await _reject(link, ByeReason.authFailed, 'peer presented degenerate keys',
          kind: SecurityEventKind.linkAuthFailed);
      return;
    }
    if (constantTimeEquals(hello.signingKey, crypto.identity.signingPublicKey)) {
      await _reject(link, ByeReason.normal, 'connected to ourselves');
      return;
    }
    link.remoteHello = hello;
    final signature = await crypto.signLinkAuth(
      verifierNonce: hello.nonce,
      proverNonce: link.myNonce,
      verifierSigningKey: hello.signingKey,
      nickname: link.myNickname,
    );
    try {
      await _sendFrame(link, AuthFrame(signature));
    } catch (e) {
      await _closeLink(link, reason: 'could not send AUTH: $e');
      return;
    }
    link.authSent = true;
    await _maybePromote(link);
  }

  Future<void> _onAuth(_PeerLink link, AuthFrame auth) async {
    final hello = link.remoteHello;
    if (hello == null) {
      _strike(link, 'AUTH before HELLO');
      return;
    }
    if (link.authVerified) {
      _strike(link, 'second AUTH');
      return;
    }
    final ok = await EncryptionService.verifyLinkAuth(
      signature: auth.signature,
      verifierNonce: link.myNonce,
      proverNonce: hello.nonce,
      proverSigningKey: hello.signingKey,
      proverAgreementKey: hello.agreementKey,
      proverNickname: hello.nickname,
      verifierSigningKey: crypto.identity.signingPublicKey,
    );
    if (!ok) {
      await _reject(
        link,
        ByeReason.authFailed,
        'peer failed to prove it owns the key it claimed',
        kind: SecurityEventKind.linkAuthFailed,
        claimedPeerId: bytesToHex(hello.signingKey),
      );
      return;
    }
    link.authVerified = true;
    await _maybePromote(link);
  }

  Future<void> _maybePromote(_PeerLink link) async {
    if (link.phase == LinkPhase.handshaking && link.authSent && link.authVerified) {
      await _promote(link);
    }
  }

  /// Which of two parallel links to the same phone is kept: the one in which
  /// the phone with the numerically smaller key is the central. Both phones
  /// evaluate this on the same pair of keys, so they always agree.
  bool _isPreferred(LinkRole role, Uint8List theirKey) {
    final iAmSmaller = compareBytes(crypto.identity.signingPublicKey, theirKey) < 0;
    return (role == LinkRole.central) == iAmSmaller;
  }

  Future<void> _promote(_PeerLink link) async {
    final hello = link.remoteHello!;
    final peerId = bytesToHex(hello.signingKey);
    link.peerId = peerId;
    link.peerNickname = sanitizeDisplayName(hello.nickname);
    _deviceToPeer[link.deviceId] = peerId;
    if (_deviceToPeer.length > 256) {
      _deviceToPeer.remove(_deviceToPeer.keys.first);
    }

    final existing = _byPeer[peerId];
    if (existing != null && !identical(existing, link) && existing.phase == LinkPhase.ready) {
      // Two links to one phone. Keep the preferred one; if neither or both are
      // preferred, the newer wins (the older may be half-dead).
      final keepNew = _isPreferred(link.role, hello.signingKey) ||
          !_isPreferred(existing.role, hello.signingKey);
      if (!keepNew) {
        _log.i(_tag, 'duplicate link ${link.linkId} to ${_short(peerId)}; keeping ${existing.linkId}');
        await _closeLink(link, reason: 'duplicate link', sendBye: true, bye: ByeReason.duplicateLink);
        return;
      }
      _log.i(_tag, 'link ${link.linkId} replaces ${existing.linkId} for ${_short(peerId)}');
      link.phase = LinkPhase.ready;
      _byPeer[peerId] = link; // reassign first: closing `existing` must not look like a loss
      _notifyLinks();
      await _closeLink(existing,
          reason: 'replaced by a preferred link', sendBye: true, bye: ByeReason.duplicateLink);
      return;
    }

    link.phase = LinkPhase.ready;
    _byPeer[peerId] = link;
    _log.i(_tag, 'neighbour ${_short(peerId)} "${link.peerNickname}" ready via ${link.linkId}');
    _notifyLinks();
    _events.add(NeighborUp(_neighborInfo(link)));
  }

  /// The other phone speaks protocol [version], which this app does not. The link
  /// is closed (the BYE frame is the same in every version, so the other phone
  /// learns why), and the phone is remembered so the person can be told that one
  /// of the two needs an update, and so it is not called again every few seconds.
  Future<void> _onOtherVersion(_PeerLink link, int version) async {
    if (link.phase == LinkPhase.closing) return;
    final now = clock.nowMs;
    final before = otherVersionSeenAt(link.deviceId);
    final again = before != null && now - before < _versionMismatchQuiet.inMilliseconds;
    _versionMismatches.add(VersionMismatch(deviceId: link.deviceId, version: version, atMs: now));
    if (_versionMismatches.length > _maxVersionMismatches) _versionMismatches.removeAt(0);
    await _reject(
      link,
      ByeReason.protocolError,
      'peer speaks protocol v$version, we speak v${Protocol.version}',
      // Once is enough for the security log; the same phone calling again and
      // again would only fill it.
      kind: again ? null : SecurityEventKind.protocolError,
    );
  }

  Future<void> _reject(
    _PeerLink link,
    ByeReason bye,
    String reason, {
    String? kind,
    String? claimedPeerId,
  }) async {
    _log.w(_tag, 'rejecting ${link.linkId}: $reason');
    if (kind != null) {
      await _reportSecurity(kind, claimedPeerId, '${link.role.name} link: $reason');
    }
    await _closeLink(link, reason: reason, sendBye: true, bye: bye);
  }

  Future<void> _reportSecurity(String kind, String? peerId, String detail) async {
    try {
      await onSecurityEvent?.call(kind, peerId: peerId, detail: detail);
    } catch (e) {
      _log.w(_tag, 'security event sink failed: $e');
    }
  }

  void _strike(_PeerLink link, String why) {
    link.strikes++;
    _log.w(_tag, '${link.linkId}: $why (strike ${link.strikes}/${config.maxStrikes})');
    if (link.strikes >= config.maxStrikes && link.phase != LinkPhase.closing) {
      unawaited(_reportSecurity(SecurityEventKind.protocolError, link.peerId, why));
      unawaited(_closeLink(link,
          reason: 'too many protocol errors', sendBye: true, bye: ByeReason.protocolError));
    }
  }

  // ---------------------------------------------------------------------------
  // Sending
  // ---------------------------------------------------------------------------

  /// Fragments [frame] to the link's current chunk size and writes it, as one
  /// uninterrupted unit.
  Future<void> _sendFrame(_PeerLink link, LinkFrame frame, {bool force = false}) {
    final bytes = frame.encode();
    return link.sender.run(() async {
      if (link.phase == LinkPhase.closing && !force) {
        throw const RadioException(RadioErrorKind.closed, 'Link is closing');
      }
      final maxChunk = radio.maxChunkSize(link.linkId);
      final frameId = link.nextFrameId;
      link.nextFrameId = (link.nextFrameId + 1) & 0xffff;
      for (final chunk in FrameChunker.split(bytes, frameId: frameId, maxChunk: maxChunk)) {
        await radio.sendChunk(link.linkId, chunk);
        link.bytesOut += chunk.length;
      }
      link.framesOut++;
      link.lastTxMs = clock.nowMs;
    });
  }

  // ---------------------------------------------------------------------------
  // Keepalive, RTT and diagnostics
  // ---------------------------------------------------------------------------

  void _maintain() {
    final now = clock.nowMs;
    for (final link in _links.values.toList()) {
      switch (link.phase) {
        case LinkPhase.handshaking:
          if (now - link.openedAtMs > config.handshakeTimeout.inMilliseconds) {
            _log.w(_tag, 'handshake on ${link.linkId} timed out');
            unawaited(_closeLink(link,
                reason: 'handshake timed out', sendBye: true, bye: ByeReason.protocolError));
          }
        case LinkPhase.ready:
          final idle = now - link.lastRxMs;
          if (idle > config.deadAfter.inMilliseconds) {
            _log.w(_tag, 'link ${link.linkId} went silent for ${idle ~/ 1000}s; closing');
            unawaited(_closeLink(link, reason: 'keepalive timeout'));
          } else if (idle > config.pingAfterIdle.inMilliseconds &&
              now - link.lastPingMs > config.pingAfterIdle.inMilliseconds) {
            link.lastPingMs = now;
            unawaited(_ping(link).then((_) {}, onError: (Object _) {}));
          }
          if (link.role == LinkRole.central &&
              now - link.lastRssiMs > config.rssiInterval.inMilliseconds) {
            link.lastRssiMs = now;
            unawaited(radio.readRssi(link.linkId).then((v) {
              if (v != null) link.rssi = v;
            }));
          }
        case LinkPhase.closing:
          break;
      }
    }
    final grace = config.earlyChunkGrace.inMilliseconds;
    final stale = _earlyStartedAt.entries
        .where((e) => now - e.value > grace)
        .map((e) => e.key)
        .toList();
    for (final id in stale) {
      _earlyChunks.remove(id);
      _earlyStartedAt.remove(id);
    }
  }

  /// Sends one PING and completes with the round-trip time in milliseconds.
  Future<int> _ping(_PeerLink link, {int padding = 0, Duration timeout = const Duration(seconds: 10)}) {
    final seq = ++link.pingSeq;
    final data = Uint8List(4 + padding);
    ByteData.sublistView(data).setUint32(0, seq);
    final done = Completer<int>();
    final sentAt = clock.nowMs;
    link.pendingPings[seq] = (sentAt, done);
    _sendFrame(link, PingFrame(data)).catchError((Object e) {
      link.pendingPings.remove(seq);
      if (!done.isCompleted) done.completeError(e);
    });
    return done.future.timeout(timeout, onTimeout: () {
      link.pendingPings.remove(seq);
      throw TimeoutException('No PONG for ping $seq');
    });
  }

  void _onPong(_PeerLink link, PongFrame pong) {
    if (pong.data.length < 4) return;
    final seq = ByteData.sublistView(pong.data).getUint32(0);
    final pending = link.pendingPings.remove(seq);
    if (pending == null) return;
    final rtt = clock.nowMs - pending.$1;
    link.lastRttMs = rtt;
    if (!pending.$2.isCompleted) pending.$2.complete(rtt);
  }

  /// Round-trip test over the link to [peerId]: sends [count] PING frames of
  /// [payloadBytes] each (large payloads exercise fragmentation) and reports
  /// delivery and latency. Used by the BLE self-test screen.
  Future<ProbeResult> probe(
    String peerId, {
    int count = 5,
    int payloadBytes = 64,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final link = _byPeer[peerId];
    if (link == null || link.phase != LinkPhase.ready) {
      return ProbeResult(
        sent: 0,
        received: 0,
        rttMs: const [],
        payloadBytes: payloadBytes,
        error: 'No ready link to that phone',
      );
    }
    final rtts = <int>[];
    var sent = 0;
    String? error;
    for (var i = 0; i < count; i++) {
      sent++;
      try {
        rtts.add(await _ping(link, padding: payloadBytes, timeout: timeout));
      } on TimeoutException {
        error ??= 'Timed out waiting for a reply';
      } catch (e) {
        error ??= '$e';
        break;
      }
    }
    return ProbeResult(
      sent: sent,
      received: rtts.length,
      rttMs: rtts,
      payloadBytes: payloadBytes,
      error: rtts.length == sent ? null : error,
    );
  }

  // ---------------------------------------------------------------------------
  // Closing
  // ---------------------------------------------------------------------------

  Future<void> _closeLink(
    _PeerLink link, {
    required String reason,
    bool sendBye = false,
    ByeReason bye = ByeReason.normal,
    bool fromRadio = false,
  }) async {
    if (link.phase == LinkPhase.closing) return;
    link.phase = LinkPhase.closing;
    _log.i(_tag, 'closing ${link.linkId}: $reason');

    for (final entry in link.pendingPings.values) {
      if (!entry.$2.isCompleted) {
        entry.$2.completeError(const RadioException(RadioErrorKind.closed, 'Link closed'));
      }
    }
    link.pendingPings.clear();

    _links.remove(link.linkId);
    final peerId = link.peerId;
    if (peerId != null && identical(_byPeer[peerId], link)) {
      _byPeer.remove(peerId);
      _events.add(NeighborDown(peerId, reason));
    }
    _notifyLinks();

    if (fromRadio) return;
    if (sendBye) {
      try {
        await _sendFrame(link, ByeFrame.reason(bye), force: true)
            .timeout(const Duration(milliseconds: 600));
      } catch (_) {
        // Best effort: the link may already be unusable.
      }
    }
    try {
      await radio.disconnect(link.linkId);
    } catch (_) {
      // Already gone.
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  NeighborInfo _neighborInfo(_PeerLink link) {
    final hello = link.remoteHello!;
    return NeighborInfo(
      signingKey: hello.signingKey,
      agreementKey: hello.agreementKey,
      nickname: link.peerNickname ?? '',
      sinceMs: link.openedAtMs,
      role: link.role,
      maxChunk: radio.maxChunkSize(link.linkId),
      rssi: link.rssi,
    );
  }

  LinkSnapshot _snapshot(_PeerLink link) => LinkSnapshot(
        linkId: link.linkId,
        role: link.role,
        deviceId: link.deviceId,
        phase: link.phase,
        peerId: link.peerId,
        nickname: link.peerNickname,
        maxChunk: radio.maxChunkSize(link.linkId),
        rssi: link.rssi,
        openedAtMs: link.openedAtMs,
        idleMs: clock.nowMs - link.lastRxMs,
        framesIn: link.framesIn,
        framesOut: link.framesOut,
        bytesIn: link.bytesIn,
        bytesOut: link.bytesOut,
        lastRttMs: link.lastRttMs,
      );

  void _notifyLinks() {
    if (!_linksChanged.isClosed) _linksChanged.add(null);
  }

  static String _short(String id) => id.length > 8 ? id.substring(0, 8) : id;
}
