import '../core/app_info.dart';
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../l10n/l10n.dart';
import '../l10n/labels.dart';
import '../mesh/peer_table.dart';
import '../transport/ble_radio.dart';
import '../transport/mesh_transport.dart';
import 'bluetooth_service.dart';
import 'device_info_service.dart';
import 'discovery_service.dart';
import 'network_status_service.dart';

enum CheckState { pending, running, passed, warning, failed, skipped }

class CheckResult {
  CheckResult(this.id, this.title);

  final String id;
  final String title;
  CheckState state = CheckState.pending;
  String detail = '';

  /// What to do about it, when the check did not pass.
  String? advice;

  bool get isProblem => state == CheckState.failed;
}

/// A guided check that Bluetooth really works on THIS phone, with a real
/// second phone if one is available.
///
/// It exercises, in order: BLE support, permission, power, advertising,
/// scanning, discovery of another phone, connecting and the authenticated
/// handshake, round trips of small and large (fragmented) payloads, and
/// multi-hop reachability. Each step reports what it saw and, when something
/// is wrong, what to do. The final report can be copied to compare phones.
///
/// Steps that need another phone are reported as warnings or skipped rather
/// than failures when none is around: an empty room proves nothing about
/// the radio.
class BleSelfTest extends ChangeNotifier {
  BleSelfTest({
    required this.radio,
    required this.bluetooth,
    required this.discovery,
    required this.table,
    required this.device,
    required this.network,
    this.discoveryWindow = const Duration(seconds: 12),
    this.connectWindow = const Duration(seconds: 15),
    this.advertiseWindow = const Duration(seconds: 4),
    AppLocalizations Function()? strings,
  }) : _strings = strings ?? englishStrings {
    final l = _l;
    _results = [
      CheckResult('device', l.bstTitleDevice),
      CheckResult('support', l.bstTitleSupport),
      CheckResult('permission', l.bstTitlePermission),
      CheckResult('power', l.bstTitlePower),
      CheckResult('advertising', l.bstTitleAdvertising),
      CheckResult('scanning', l.bstTitleScanning),
      CheckResult('discovery', l.bstTitleDiscovery),
      CheckResult('connection', l.bstTitleConnection),
      CheckResult('exchange', l.bstTitleExchange),
      CheckResult('multihop', l.bstTitleMultihop),
      CheckResult('network', l.bstTitleNetwork),
    ];
  }

  /// The words of the steps, in the language being shown.
  final AppLocalizations Function() _strings;
  AppLocalizations get _l => _strings();

  final BleRadio radio;
  final BluetoothService bluetooth;
  final DiscoveryService discovery;
  final PeerTable table;
  final DeviceInfoSource device;
  final NetworkStatusSource network;
  final Duration discoveryWindow;
  final Duration connectWindow;
  final Duration advertiseWindow;

  late final List<CheckResult> _results;
  bool _running = false;
  bool _cancelled = false;
  DateTime? _finishedAt;
  String _deviceText = '';

  List<CheckResult> get results => List.unmodifiable(_results);

  bool get running => _running;

  DateTime? get finishedAt => _finishedAt;

  CheckResult _r(String id) => _results.firstWhere((r) => r.id == id);

  /// The worst outcome among the checks that ran.
  CheckState get overall {
    final ran = _results.where((r) => r.state != CheckState.skipped && r.state != CheckState.pending);
    if (ran.any((r) => r.state == CheckState.failed)) return CheckState.failed;
    if (ran.any((r) => r.state == CheckState.warning)) return CheckState.warning;
    if (ran.isEmpty) return CheckState.pending;
    return CheckState.passed;
  }

  void cancel() => _cancelled = true;

  void _set(String id, CheckState state, String detail, {String? advice}) {
    final r = _r(id);
    r
      ..state = state
      ..detail = detail
      ..advice = advice;
    notifyListeners();
  }

  void _start(String id) {
    _r(id).state = CheckState.running;
    notifyListeners();
  }

  /// Polls [condition] until it holds or [timeout] passes. Returns the result.
  Future<bool> _waitFor(bool Function() condition, Duration timeout) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (_cancelled) return false;
      if (condition()) return true;
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
    return condition();
  }

  Future<void> run() async {
    if (_running) return;
    _running = true;
    _cancelled = false;
    _finishedAt = null;
    for (final r in _results) {
      r
        ..state = CheckState.pending
        ..detail = ''
        ..advice = null;
    }
    notifyListeners();
    try {
      await _checkDevice();
      final basicsOk = await _checkBasics();
      if (basicsOk && !_cancelled) {
        final steps = <(String, Future<void> Function())>[
          ('advertising', _checkAdvertising),
          ('scanning', _checkScanning),
          ('discovery', _checkDiscovery),
          ('connection', _checkConnection),
          ('exchange', _checkExchange),
          ('multihop', () async => _checkMultihop()),
        ];
        for (final (id, step) in steps) {
          if (_cancelled) break;
          await step();
          // A step interrupted by "stop" would otherwise report a failure it
          // never actually observed.
          if (_cancelled) _set(id, CheckState.skipped, _l.bstStopped);
        }
      } else if (!basicsOk) {
        for (final id in ['advertising', 'scanning', 'discovery', 'connection', 'exchange', 'multihop']) {
          _set(id, CheckState.skipped, _l.bstFixAbove);
        }
      }
      if (_cancelled) {
        for (final r in _results) {
          if (r.state == CheckState.pending || r.state == CheckState.running) {
            _set(r.id, CheckState.skipped, _l.bstStopped);
          }
        }
      } else {
        await _checkNetwork();
      }
    } finally {
      _running = false;
      _finishedAt = DateTime.now();
      notifyListeners();
    }
  }

  bool _disposed = false;

  // The screen that shows a run may be closed while the run is still winding
  // down; late updates must then be dropped instead of throwing.
  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelled = true;
    super.dispose();
  }

  // ---------------------------------------------------------------------------

  Future<void> _checkDevice() async {
    _start('device');
    _deviceText = await device.describe();
    _set('device', CheckState.passed, _deviceText);
  }

  Future<bool> _checkBasics() async {
    final s = radio.status;
    var ok = true;

    _start('support');
    if (s.central == RadioAvailability.unsupported && s.peripheral == RadioAvailability.unsupported) {
      _set('support', CheckState.failed, _l.bstNoBle,
          advice: _l.bstNoBleAdvice);
      ok = false;
    } else {
      _set('support', CheckState.passed, _l.bstBleAvailable);
    }

    _start('permission');
    if (s.central == RadioAvailability.unauthorized || s.peripheral == RadioAvailability.unauthorized) {
      final sdk = await device.androidSdk();
      final where = sdk == null
          ? _l.bstWhereIos
          : sdk >= 31
              ? _l.bstWhereAndroid12
              : _l.bstWhereOlder;
      _set('permission', CheckState.failed, _l.bstPermDenied,
          advice: _l.bstPermAdvice(where));
      ok = false;
    } else {
      _set('permission', CheckState.passed, _l.bstPermGranted);
    }

    _start('power');
    if (s.central == RadioAvailability.poweredOff || s.peripheral == RadioAvailability.poweredOff) {
      _set('power', CheckState.failed, _l.bstOff,
          advice: _l.bstOffAdvice);
      ok = false;
    } else if (s.central == RadioAvailability.unknown) {
      _set('power', CheckState.warning, _l.bstPowerUnknown,
          advice: _l.bstPowerUnknownAdvice);
      ok = false;
    } else {
      _set('power', CheckState.passed, _l.bstOn);
    }
    return ok;
  }

  Future<void> _checkAdvertising() async {
    _start('advertising');
    final s = radio.status;
    if (s.peripheral == RadioAvailability.unsupported) {
      _set('advertising', CheckState.warning,
          _l.bstCannotAdvertise,
          advice: _l.bstCannotAdvertiseAdvice);
      return;
    }
    final ok = await _waitFor(() => radio.isAdvertising, advertiseWindow);
    if (ok) {
      _set('advertising', CheckState.passed,
          _l.bstAdvertising);
    } else {
      _set('advertising', CheckState.failed,
          radio.lastError ?? _l.bstNotAdvertising,
          advice: _l.bstNotAdvertisingAdvice);
    }
  }

  Future<void> _checkScanning() async {
    _start('scanning');
    if (!discovery.isRunning) {
      _set('scanning', CheckState.failed, _l.bstDiscoveryStopped,
          advice: _l.bstDiscoveryStoppedAdvice);
      return;
    }
    final ok = await _waitFor(() => discovery.scanStarts > 0, const Duration(seconds: 5));
    if (ok) {
      _set('scanning', CheckState.passed,
          _l.bstScanning(discovery.mode.localized(_l).toLowerCase(), discovery.scanStarts));
    } else {
      _set('scanning', CheckState.failed, radio.lastError ?? _l.bstNoScan,
          advice: _l.bstNoScanAdvice);
    }
  }

  Future<void> _checkDiscovery() async {
    _start('discovery');
    final heard = await _waitFor(
      () => discovery.devices.isNotEmpty || bluetooth.neighbors.isNotEmpty,
      discoveryWindow,
    );
    if (heard) {
      final devices = discovery.devices;
      final strongest = devices.isEmpty ? null : devices.first.rssi;
      _set(
        'discovery',
        CheckState.passed,
        strongest == null
            ? _l.bstHeardCount(devices.length)
            : _l.bstHeardStrongest(devices.length, strongest),
      );
    } else {
      final sdk = await device.androidSdk();
      _set('discovery', CheckState.warning, _l.bstNoneHeard(discoveryWindow.inSeconds),
          advice: '${_l.bstNoneHeardAdvice}${sdk != null && sdk <= 30 ? _l.bstOlderAndroidLocation : ''}');
    }
  }

  Future<void> _checkConnection() async {
    _start('connection');
    if (discovery.devices.isEmpty && bluetooth.neighbors.isEmpty) {
      _set('connection', CheckState.skipped, _l.bstNeedsPhone);
      return;
    }
    await _waitFor(() => bluetooth.neighbors.isNotEmpty, connectWindow);
    final neighbors = bluetooth.neighbors;
    if (neighbors.isNotEmpty) {
      final lines = neighbors.map((n) {
        final role = n.role == LinkRole.central ? _l.bstWeConnected : _l.bstTheyConnected;
        return '${n.nickname.isEmpty ? n.peerId.substring(0, 8) : n.nickname} '
            '($role, ${n.maxChunk ?? '?'} bytes per write)';
      });
      _set('connection', CheckState.passed,
          'Connected and verified key ownership with: ${lines.join('; ')}.');
    } else {
      final errors = discovery.devices
          .map((d) => d.lastError)
          .whereType<String>()
          .toSet()
          .take(3)
          .join(' | ');
      _set('connection', CheckState.failed,
          errors.isEmpty ? _l.bstNotConnected : _l.bstNotConnectedWith(errors),
          advice: _l.bstNotConnectedAdvice);
    }
  }

  Future<void> _checkExchange() async {
    _start('exchange');
    final neighbors = bluetooth.neighbors;
    if (neighbors.isEmpty) {
      _set('exchange', CheckState.skipped, _l.bstNeedsConnected);
      return;
    }
    final lines = <String>[];
    var worst = CheckState.passed;
    String? advice;
    for (final n in neighbors.take(3)) {
      if (_cancelled) return;
      final label = n.nickname.isEmpty ? n.peerId.substring(0, 8) : n.nickname;
      final small = await bluetooth.probe(n.peerId, count: 5, payloadBytes: 16);
      final large = await bluetooth.probe(n.peerId, count: 3, payloadBytes: 1200);
      final smallText = _l.bstSmall(small.received, small.sent);
      final largeText = _l.bstLarge(large.received, large.sent);
      final rtt = small.avgMs == null
          ? ''
          : _l.bstRtt(small.avgMs!.round(), small.minMs!.round(), small.maxMs!.round());
      lines.add(_l.bstExchangeLine(label, smallText, largeText, rtt));
      if (small.received == 0 && large.received == 0) {
        worst = CheckState.failed;
        advice = _l.bstNothingBack;
      } else if (!small.passed || !large.passed) {
        if (worst != CheckState.failed) worst = CheckState.warning;
        advice ??= _l.bstSomeLost;
      }
      if ((n.maxChunk ?? 20) <= 20 && worst != CheckState.failed) {
        if (worst == CheckState.passed) worst = CheckState.warning;
        advice ??= _l.bstSlowChunk;
      }
    }
    _set('exchange', worst, lines.join('\n'), advice: advice);
  }

  void _checkMultihop() {
    _start('multihop');
    final neighborIds = bluetooth.neighbors.map((n) => n.peerId).toSet();
    final relayed = table.reachablePeerIds.difference(neighborIds);
    if (relayed.isEmpty) {
      _set('multihop', CheckState.skipped,
          _l.bstNoRelay);
      return;
    }
    final lines = relayed.map((id) {
      final s = table.statusOf(id);
      return _l.bstRelayLine(id.substring(0, 8), '${s.viaPeerId?.substring(0, 8)}', s.hops);
    });
    _set('multihop', CheckState.passed, _l.bstRelayOk(lines.join('; ')));
  }

  Future<void> _checkNetwork() async {
    _start('network');
    final kind = await network.current();
    final text = describeNetwork(kind, _l);
    if (kind == NetworkKind.none) {
      _set('network', CheckState.passed, _l.bstNetOffline(text));
    } else {
      _set('network', CheckState.passed, _l.bstNetOnline(text));
    }
  }

  // ---------------------------------------------------------------------------

  /// A plain-text report suitable for pasting into a message or issue. It
  /// contains no keys, no message content and no personal identifiers beyond
  /// the nicknames of the phones that were around.
  String report({List<String> logLines = const []}) {
    final b = StringBuffer()
      ..writeln('${AppInfo.latinName} - BLE self-test')
      ..writeln('When:   ${(_finishedAt ?? DateTime.now()).toIso8601String()}')
      ..writeln('Phone:  $_deviceText')
      ..writeln('Result: ${overall.name.toUpperCase()}')
      ..writeln();
    for (final r in _results) {
      final mark = switch (r.state) {
        CheckState.passed => '[PASS]',
        CheckState.warning => '[WARN]',
        CheckState.failed => '[FAIL]',
        CheckState.skipped => '[SKIP]',
        CheckState.running => '[....]',
        CheckState.pending => '[    ]',
      };
      b.writeln('$mark ${r.title}');
      if (r.detail.isNotEmpty) {
        for (final line in r.detail.split('\n')) {
          b.writeln('       $line');
        }
      }
      if (r.advice != null) b.writeln('       -> ${r.advice}');
    }
    final links = bluetooth.linkSnapshots;
    if (links.isNotEmpty) {
      b
        ..writeln()
        ..writeln('Links:');
      for (final l in links) {
        b.writeln('  ${l.role.name} ${l.phase.name} chunk=${l.maxChunk}B '
            'rssi=${l.rssi ?? '?'} rtt=${l.lastRttMs ?? '?'}ms '
            'frames in/out=${l.framesIn}/${l.framesOut} bytes in/out=${l.bytesIn}/${l.bytesOut}');
      }
    }
    if (logLines.isNotEmpty) {
      b
        ..writeln()
        ..writeln('Recent log:');
      for (final line in logLines) {
        b.writeln('  $line');
      }
    }
    return b.toString();
  }
}
