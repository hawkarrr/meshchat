import 'dart:async';
import 'dart:math';

import '../core/app_log.dart';
import '../core/clock.dart';
import '../transport/ble_radio.dart';
import 'bluetooth_service.dart';

/// How aggressively to look for other phones. The trade-off is battery.
enum DiscoveryMode {
  /// Scan about half of the time. Good default.
  balanced,

  /// Scan a few seconds every half minute. Slow to find people, light on battery.
  lowPower,

  /// Scan continuously. Fastest, hungriest.
  aggressive;

  String get label => switch (this) {
        DiscoveryMode.balanced => 'Balanced',
        DiscoveryMode.lowPower => 'Battery saver',
        DiscoveryMode.aggressive => 'Continuous',
      };
}

class DiscoveryConfig {
  const DiscoveryConfig({
    this.scanOn = const Duration(seconds: 8),
    this.scanOff = const Duration(seconds: 8),
    this.minScanStartGap = const Duration(seconds: 6),
    this.connectTick = const Duration(seconds: 1),
    this.candidateFreshness = const Duration(seconds: 20),
    this.connectJitterMax = const Duration(milliseconds: 1200),
    this.baseBackoff = const Duration(seconds: 3),
    this.maxBackoff = const Duration(seconds: 90),
    this.reconnectDelay = const Duration(seconds: 3),
    this.notifyGap = const Duration(milliseconds: 500),
    this.forgetAfter = const Duration(minutes: 2),
    this.otherVersionRetry = const Duration(minutes: 10),
  });

  factory DiscoveryConfig.forMode(DiscoveryMode mode) => switch (mode) {
        DiscoveryMode.balanced => const DiscoveryConfig(),
        DiscoveryMode.lowPower => const DiscoveryConfig(
            scanOn: Duration(seconds: 5),
            scanOff: Duration(seconds: 25),
          ),
        DiscoveryMode.aggressive => const DiscoveryConfig(
            scanOn: Duration(seconds: 30),
            scanOff: Duration.zero,
          ),
      };

  /// Length of one scan window and of the pause after it. A zero pause means
  /// "never stop" (the window is only a re-check interval).
  final Duration scanOn;
  final Duration scanOff;

  /// Android refuses an app that starts scans more than 5 times in 30 s, so
  /// scan starts are never closer together than this whatever else is set.
  final Duration minScanStartGap;

  final Duration connectTick;

  /// A device not heard from for longer than this is not worth connecting to.
  final Duration candidateFreshness;

  /// Random delay before connecting, so two phones that find each other at the
  /// same instant do not both connect at the same instant.
  final Duration connectJitterMax;

  final Duration baseBackoff;
  final Duration maxBackoff;
  final Duration reconnectDelay;

  /// Minimum gap between UI change notifications (advertisements arrive
  /// several times per second per device).
  final Duration notifyGap;

  /// Devices not heard for this long (and not linked) are dropped from the list.
  final Duration forgetAfter;

  /// A phone turned away because it speaks another protocol version is not
  /// called again for this long: it cannot be talked to until one of the two is
  /// updated, and calling it every few seconds would only cost both batteries.
  final Duration otherVersionRetry;
}

enum DeviceState {
  /// Heard in a scan; no connection attempt under way.
  seen,

  connecting,

  /// A link to it is up (it may still be handshaking).
  connected,

  /// Waiting before the next connection attempt (after a failure or loss).
  backoff,

  /// Skipped because this phone is already connected to the same peer through
  /// another link.
  alreadyLinked,
}

class NearbyDevice {
  NearbyDevice({
    required this.deviceId,
    required this.rssi,
    required this.firstSeenMs,
    required this.lastSeenMs,
  });

  final String deviceId;
  int rssi;
  final int firstSeenMs;
  int lastSeenMs;
  DeviceState state = DeviceState.seen;
  int failures = 0;
  int nextAttemptAtMs = 0;
  String? lastError;

  /// Authenticated peer behind this device, once a handshake with it succeeded.
  String? peerId;
}

/// Finds nearby phones and decides whom to connect to.
///
/// It keeps this phone advertising, runs a duty-cycled scan (continuous
/// scanning is the biggest battery cost and Android rate-limits scan starts),
/// remembers what it hears, and opens connections one at a time with
/// exponential back-off after failures. Whether a connected device is really
/// a Damatqe peer is decided later by the handshake, not here.
class DiscoveryService {
  DiscoveryService({
    required this.radio,
    required this.bluetooth,
    DiscoveryMode mode = DiscoveryMode.balanced,
    DiscoveryConfig? config,
    this.clock = const SystemClock(),
    AppLog? log,
    Random? random,
  })  : _mode = mode,
        _config = config ?? DiscoveryConfig.forMode(mode),
        _log = log ?? AppLog.instance,
        _random = random ?? Random();

  final BleRadio radio;
  final BluetoothService bluetooth;
  final Clock clock;
  final AppLog _log;
  final Random _random;

  static const String _tag = 'Discovery';

  DiscoveryMode _mode;
  DiscoveryConfig _config;

  final Map<String, NearbyDevice> _devices = <String, NearbyDevice>{};
  final StreamController<void> _changes = StreamController<void>.broadcast();

  StreamSubscription<RadioDiscovery>? _discoverySub;
  StreamSubscription<RadioStatus>? _statusSub;
  Timer? _connectTimer;
  bool _running = false;
  bool _connecting = false;
  bool _scanWindowOpen = false;
  int _generation = 0;
  int _lastScanStartMs = 0;
  int _lastNotifyMs = 0;
  Completer<void>? _wake;
  int scanStarts = 0;

  DiscoveryMode get mode => _mode;
  DiscoveryConfig get config => _config;
  bool get isRunning => _running;

  /// True while a scan window is open (for the UI's "scanning" indicator).
  bool get isScanning => _scanWindowOpen;

  Stream<void> get changes => _changes.stream;

  /// Devices heard recently, strongest first.
  List<NearbyDevice> get devices {
    final list = _devices.values.toList()..sort((a, b) => b.rssi.compareTo(a.rssi));
    return list;
  }

  Future<void> start() async {
    if (_running) return;
    _running = true;
    final generation = ++_generation;
    _discoverySub = radio.discoveries.listen(_onDiscovered);
    _statusSub = radio.statusChanges.listen((_) {
      _wakeUp();
      _notify(force: true);
    });
    _connectTimer = Timer.periodic(_config.connectTick, (_) => _tick());
    await radio.startAdvertising();
    unawaited(_scanLoop(generation));
  }

  Future<void> stop() async {
    if (!_running) return;
    _running = false;
    _generation++;
    _connectTimer?.cancel();
    await _discoverySub?.cancel();
    await _statusSub?.cancel();
    _wakeUp();
    _scanWindowOpen = false;
    await radio.stopScan();
    await radio.stopAdvertising();
    _notify(force: true);
  }

  Future<void> dispose() async {
    await stop();
    await _changes.close();
  }

  /// Switches scan cadence on the fly.
  void setMode(DiscoveryMode mode) {
    if (mode == _mode) return;
    _mode = mode;
    _config = DiscoveryConfig.forMode(mode);
    _wakeUp();
    _notify(force: true);
  }

  // ---------------------------------------------------------------------------
  // Scanning
  // ---------------------------------------------------------------------------

  Future<void> _scanLoop(int generation) async {
    bool alive() => _running && generation == _generation;
    while (alive()) {
      if (!radio.status.canScan) {
        _scanWindowOpen = false;
        _notify(force: true);
        await _sleep(const Duration(seconds: 2));
        continue;
      }
      // Never start scans closer together than Android tolerates.
      final sinceStart = clock.nowMs - _lastScanStartMs;
      final gap = _config.minScanStartGap.inMilliseconds;
      if (_lastScanStartMs != 0 && sinceStart < gap) {
        await _sleep(Duration(milliseconds: gap - sinceStart));
        continue;
      }
      _lastScanStartMs = clock.nowMs;
      scanStarts++;
      await radio.startScan();
      _scanWindowOpen = true;
      _notify(force: true);
      await _sleep(_config.scanOn);
      if (!alive()) break;
      if (_config.scanOff > Duration.zero) {
        await radio.stopScan();
        _scanWindowOpen = false;
        _notify(force: true);
        await _sleep(_config.scanOff);
      }
    }
    _scanWindowOpen = false;
  }

  /// A sleep that [_wakeUp] can cut short (mode change, Bluetooth change, stop).
  Future<void> _sleep(Duration d) {
    final wake = _wake = Completer<void>();
    final timer = Timer(d, () {
      if (!wake.isCompleted) wake.complete();
    });
    return wake.future.whenComplete(timer.cancel);
  }

  void _wakeUp() {
    final w = _wake;
    if (w != null && !w.isCompleted) w.complete();
  }

  void _onDiscovered(RadioDiscovery d) {
    final now = clock.nowMs;
    final device = _devices.putIfAbsent(
      d.deviceId,
      () => NearbyDevice(deviceId: d.deviceId, rssi: d.rssi, firstSeenMs: now, lastSeenMs: now),
    );
    device
      ..rssi = d.rssi
      ..lastSeenMs = now
      ..peerId = bluetooth.peerForDevice(d.deviceId) ?? device.peerId;
    _notify();
  }

  // ---------------------------------------------------------------------------
  // Connecting
  // ---------------------------------------------------------------------------

  void _tick() {
    if (!_running) return;
    _reconcile();
    _forgetStale();
    _maybeConnect();
  }

  /// Brings device states in line with the links that actually exist.
  void _reconcile() {
    final now = clock.nowMs;
    var changed = false;
    for (final d in _devices.values) {
      final peer = bluetooth.peerForDevice(d.deviceId);
      if (peer != null && d.peerId != peer) {
        d.peerId = peer;
        changed = true;
      }
      final linked = bluetooth.hasLink('c:${d.deviceId}');
      if (d.state == DeviceState.connected && !linked) {
        // The link we had is gone.
        d.state = DeviceState.backoff;
        d.nextAttemptAtMs = now + _config.reconnectDelay.inMilliseconds;
        changed = true;
      } else if (linked && d.state != DeviceState.connected) {
        d.state = DeviceState.connected;
        changed = true;
      }
      if (d.state == DeviceState.backoff && now >= d.nextAttemptAtMs) {
        d.state = DeviceState.seen;
        changed = true;
      }
      if (d.state == DeviceState.alreadyLinked) {
        final p = d.peerId;
        if (p == null || !bluetooth.isNeighbor(p)) {
          d.state = DeviceState.seen;
          changed = true;
        }
      }
    }
    if (changed) _notify();
  }

  void _forgetStale() {
    final cutoff = clock.nowMs - _config.forgetAfter.inMilliseconds;
    _devices.removeWhere((_, d) =>
        d.lastSeenMs < cutoff &&
        d.state != DeviceState.connected &&
        d.state != DeviceState.connecting);
  }

  void _maybeConnect() {
    if (_connecting || !radio.status.canScan || !bluetooth.hasFreeLinkSlot) return;
    final now = clock.nowMs;
    final fresh = _config.candidateFreshness.inMilliseconds;
    final candidates = _devices.values.where((d) {
      if (d.state != DeviceState.seen) return false;
      if (now - d.lastSeenMs > fresh) return false;
      if (now < d.nextAttemptAtMs) return false;
      final otherVersionAt = bluetooth.otherVersionSeenAt(d.deviceId);
      if (otherVersionAt != null && now - otherVersionAt < _config.otherVersionRetry.inMilliseconds) {
        return false;
      }
      // Already connected to this very phone through another link? Don't
      // build a duplicate that the link layer would only tear down again.
      final peer = bluetooth.peerForDevice(d.deviceId) ?? d.peerId;
      if (peer != null && bluetooth.isNeighbor(peer)) {
        d.state = DeviceState.alreadyLinked;
        d.peerId = peer;
        return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => b.rssi.compareTo(a.rssi));
    if (candidates.isEmpty) return;
    unawaited(_connect(candidates.first));
  }

  Future<void> _connect(NearbyDevice device) async {
    _connecting = true;
    device.state = DeviceState.connecting;
    _notify(force: true);
    try {
      if (_config.connectJitterMax > Duration.zero) {
        await _sleep(Duration(
          milliseconds: _random.nextInt(_config.connectJitterMax.inMilliseconds + 1),
        ));
      }
      if (!_running) {
        device.state = DeviceState.seen;
        return;
      }
      // The other phone may have connected to us during the jitter.
      final peer = bluetooth.peerForDevice(device.deviceId);
      if (peer != null && bluetooth.isNeighbor(peer)) {
        device.state = DeviceState.alreadyLinked;
        device.peerId = peer;
        return;
      }
      _log.i(_tag, 'connecting to ${device.deviceId} (rssi ${device.rssi})');
      await bluetooth.connectTo(device.deviceId);
      device
        ..state = DeviceState.connected
        ..failures = 0
        ..lastError = null;
    } on RadioException catch (e) {
      _fail(device, e.message);
    } catch (e) {
      _fail(device, '$e');
    } finally {
      _connecting = false;
      _notify(force: true);
    }
  }

  void _fail(NearbyDevice device, String message) {
    device.failures++;
    device.lastError = message;
    device.state = DeviceState.backoff;
    final exp = min(device.failures - 1, 10);
    var delayMs = _config.baseBackoff.inMilliseconds * (1 << exp);
    if (delayMs > _config.maxBackoff.inMilliseconds) {
      delayMs = _config.maxBackoff.inMilliseconds;
    }
    final jitter = 0.8 + _random.nextDouble() * 0.4;
    device.nextAttemptAtMs = clock.nowMs + (delayMs * jitter).round();
    _log.w(_tag, 'connect to ${device.deviceId} failed (#${device.failures}): $message');
  }

  void _notify({bool force = false}) {
    final now = clock.nowMs;
    if (!force && now - _lastNotifyMs < _config.notifyGap.inMilliseconds) return;
    _lastNotifyMs = now;
    if (!_changes.isClosed) _changes.add(null);
  }
}
