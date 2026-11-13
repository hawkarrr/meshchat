import '../core/app_info.dart';
import 'dart:async';
import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';

import '../core/app_log.dart';
import '../core/serial_executor.dart';
import '../protocol/protocol_constants.dart';
import '../transport/ble_radio.dart';
import '../transport/mesh_transport.dart' show LinkRole;

/// The platform the plugin is running on. Several plugin members exist on
/// Android only and THROW on iOS, so behaviour must branch on this.
enum BlePlatform {
  android,
  ios,
  other;

  static BlePlatform detect() {
    if (Platform.isAndroid) return BlePlatform.android;
    if (Platform.isIOS) return BlePlatform.ios;
    return BlePlatform.other;
  }
}

/// Time budgets. Tests shrink them; the defaults suit real radios.
class RadioTimings {
  const RadioTimings({
    this.connectGuard = const Duration(seconds: 20),
    this.postConnectDelay = const Duration(milliseconds: 300),
    this.mtuTimeout = const Duration(seconds: 5),
    this.discoverTimeout = const Duration(seconds: 12),
    this.subscribeTimeout = const Duration(seconds: 8),
    this.operationTimeout = const Duration(seconds: 8),
    this.stateWait = const Duration(seconds: 3),
    this.advertiseRetry = const Duration(seconds: 5),
    this.sendRetryBase = const Duration(milliseconds: 40),
  });

  final Duration connectGuard;

  /// Android is more reliable if a freshly established connection is left
  /// alone for a moment before the first GATT operation.
  final Duration postConnectDelay;
  final Duration mtuTimeout;
  final Duration discoverTimeout;
  final Duration subscribeTimeout;
  final Duration operationTimeout;
  final Duration stateWait;
  final Duration advertiseRetry;
  final Duration sendRetryBase;
}

class _Link {
  _Link({
    required this.id,
    required this.role,
    required this.deviceId,
    required this.maxChunk,
  });

  final String id;
  final LinkRole role;
  final String deviceId;
  int maxChunk;
  bool closed = false;

  /// True once [RadioLinkOpened] has been published. Until then the link is
  /// registered (so early data is not lost) but not usable for sending.
  bool opened = false;

  /// Data that arrived before the link was announced. The remote starts
  /// talking the instant it has subscribed - possibly before our own
  /// bookkeeping (an async call or two) is finished - and a dropped first
  /// chunk would stall the handshake. Flushed, in order, right after the
  /// link-opened event.
  final List<Uint8List> early = <Uint8List>[];

  static const int maxEarlyChunks = 64;

  /// All GATT operations of one link run strictly one at a time: the plugin
  /// does not queue them, and a second concurrent operation fails ("busy") or
  /// overwrites the first one's completion callback.
  final SerialExecutor io = SerialExecutor();

  // Central role.
  Peripheral? peripheral;
  GATTCharacteristic? remoteCharacteristic;

  // Peripheral role.
  Central? central;
}

/// [BleRadio] implemented with the `bluetooth_low_energy` plugin, which is
/// the only maintained Flutter plugin that offers BOTH the central and the
/// peripheral role on Android and iOS.
///
/// Both roles run at the same time on one shared GATT layout:
///
///  * service  [BleIds.serviceUuid]  (advertised, nothing else is advertised)
///  * one characteristic [BleIds.dataCharacteristicUuid] with WRITE + NOTIFY
///
/// Centrals WRITE chunks to it, peripherals NOTIFY chunks on it. Writes are
/// "with response" so the ATT layer acknowledges each chunk, which also gives
/// natural back-pressure (the plugin offers no flow control for
/// write-without-response).
///
/// Plugin behaviours this class is written around (verified in the plugin
/// sources, bluetooth_low_energy 6.2.1):
///  * Android's central does NOT request a larger MTU on connect; we do.
///  * `PeripheralManager.notifyCharacteristic` silently does nothing for a
///    central that has not subscribed yet, so we only notify subscribed ones.
///  * After Bluetooth is toggled the plugin re-opens an EMPTY GATT server, so
///    the service must be added (and advertising restarted) again.
///  * Passing an advertisement `name` renames the phone's Bluetooth adapter
///    system-wide; we never do, which also avoids broadcasting a name.
///  * `connectionStateChanged`/`mtuChanged` on the peripheral side and
///    `requestMTU`/`mtuChanged` on the central side exist on Android only.
///  * iOS' `connect` never times out, so we time it out ourselves.
class PluginBleRadio implements BleRadio {
  PluginBleRadio({
    this._central,
    this._peripheral,
    BlePlatform? platform,
    AppLog? log,
    this.timings = const RadioTimings(),
  })  : _platform = platform ?? BlePlatform.detect(),
        _log = log ?? AppLog.instance;

  final BlePlatform _platform;
  final AppLog _log;
  final RadioTimings timings;

  static const String _tag = 'BLE';

  CentralManager? _central;
  PeripheralManager? _peripheral;

  final UUID _serviceUuid = UUID.fromString(BleIds.serviceUuid);
  final UUID _characteristicUuid = UUID.fromString(BleIds.dataCharacteristicUuid);

  GATTCharacteristic? _localCharacteristic;
  bool _gattReady = false;
  bool _gattBusy = false;

  bool _initialized = false;
  bool _disposed = false;
  bool _wantAdvertising = false;
  bool _wantScan = false;
  bool _advertising = false;
  bool _scanning = false;
  String? _lastError;
  Timer? _advertiseRetryTimer;

  /// Each manager's state as last REPORTED BY ITS EVENT STREAM. Transitions
  /// are processed from these events one by one rather than by comparing the
  /// live state, so an off->on toggle that completes before our handler runs
  /// is still seen as two transitions (and the lost GATT service rebuilt).
  BluetoothLowEnergyState _centralState = BluetoothLowEnergyState.unknown;
  BluetoothLowEnergyState _peripheralState = BluetoothLowEnergyState.unknown;
  RadioStatus _publishedStatus = RadioStatus.unknown;

  final List<StreamSubscription<Object?>> _subscriptions = <StreamSubscription<Object?>>[];
  final Map<String, _Link> _links = <String, _Link>{};
  final Map<String, Peripheral> _peripherals = <String, Peripheral>{};
  final SerialExecutor _connectLock = SerialExecutor();

  final StreamController<RadioStatus> _statusController = StreamController<RadioStatus>.broadcast();
  final StreamController<RadioDiscovery> _discoveryController =
      StreamController<RadioDiscovery>.broadcast();
  final StreamController<RadioLinkEvent> _linkController =
      StreamController<RadioLinkEvent>.broadcast();
  final StreamController<RadioChunk> _chunkController = StreamController<RadioChunk>.broadcast();

  @override
  Stream<RadioStatus> get statusChanges => _statusController.stream;

  @override
  Stream<RadioDiscovery> get discoveries => _discoveryController.stream;

  @override
  Stream<RadioLinkEvent> get linkEvents => _linkController.stream;

  @override
  Stream<RadioChunk> get chunks => _chunkController.stream;

  @override
  bool get isAdvertising => _advertising;

  @override
  bool get isScanning => _scanning;

  @override
  String? get lastError => _lastError;

  @override
  RadioStatus get status => RadioStatus(
        central: _availability(_centralState),
        peripheral: _availability(_peripheralState),
      );

  static RadioAvailability _availability(BluetoothLowEnergyState s) => switch (s) {
        BluetoothLowEnergyState.unknown => RadioAvailability.unknown,
        BluetoothLowEnergyState.unsupported => RadioAvailability.unsupported,
        BluetoothLowEnergyState.unauthorized => RadioAvailability.unauthorized,
        BluetoothLowEnergyState.poweredOff => RadioAvailability.poweredOff,
        BluetoothLowEnergyState.poweredOn => RadioAvailability.poweredOn,
      };

  // ---------------------------------------------------------------------------
  // Initialisation and permissions
  // ---------------------------------------------------------------------------

  @override
  Future<void> initialize() async {
    if (_initialized || _disposed) return;
    _initialized = true;

    // Creating the managers is what makes iOS show its permission prompt, so
    // it happens here and not at construction time.
    final central = _central ??= CentralManager();
    final peripheral = _peripheral ??= PeripheralManager();

    _listen(central.stateChanged, (e) => _onCentralState(e.state));
    _listen(peripheral.stateChanged, (e) => _onPeripheralState(e.state));
    _listen(central.discovered, _onDiscovered);
    _listen(central.connectionStateChanged, _onCentralConnectionChanged);
    _listen(central.characteristicNotified, _onNotified);
    _listen(peripheral.characteristicWriteRequested, _onWriteRequested);
    _listen(peripheral.characteristicNotifyStateChanged, _onNotifyStateChanged);

    if (_platform == BlePlatform.android) {
      // These streams exist on Android only; on iOS merely reading the getter
      // throws UnsupportedError.
      _guard('central.mtuChanged', () {
        _listen(central.mtuChanged, _onCentralMtuChanged);
      });
      _guard('peripheral.mtuChanged', () {
        _listen(peripheral.mtuChanged, _onPeripheralMtuChanged);
      });
      _guard('peripheral.connectionStateChanged', () {
        _listen(peripheral.connectionStateChanged, _onPeripheralConnectionChanged);
      });
    }

    await _waitForKnownState();
    // Adopt the plugin's current state for any manager whose event we have
    // not seen yet; events seen meanwhile take precedence.
    if (_centralState == BluetoothLowEnergyState.unknown) {
      _centralState = central.state;
    }
    final peripheralWasUnknown = _peripheralState == BluetoothLowEnergyState.unknown;
    if (peripheralWasUnknown) {
      _peripheralState = peripheral.state;
    }
    _log.i(_tag, 'initialised on ${_platform.name}: $status');
    if (status.canAdvertise && !_gattReady) {
      await _setupGatt();
    }
    _publishStatus();
  }

  void _publishStatus() {
    final now = status;
    if (now == _publishedStatus || _statusController.isClosed) return;
    _publishedStatus = now;
    _statusController.add(now);
  }

  void _listen<T>(Stream<T> stream, void Function(T) onData) {
    _subscriptions.add(stream.listen(
      onData,
      onError: (Object e) => _log.w(_tag, 'stream error: $e'),
    ));
  }

  void _guard(String what, void Function() body) {
    try {
      body();
    } on UnsupportedError catch (e) {
      _log.d(_tag, '$what unsupported here: ${e.message}');
    } catch (e) {
      _log.w(_tag, '$what failed: $e');
    }
  }

  Future<void> _waitForKnownState() async {
    final deadline = DateTime.now().add(timings.stateWait);
    while (DateTime.now().isBefore(deadline)) {
      final central = _centralState != BluetoothLowEnergyState.unknown ||
          _central!.state != BluetoothLowEnergyState.unknown;
      final peripheral = _peripheralState != BluetoothLowEnergyState.unknown ||
          _peripheral!.state != BluetoothLowEnergyState.unknown;
      if (central && peripheral) return;
      await Future<void>.delayed(const Duration(milliseconds: 40));
    }
  }

  @override
  Future<void> requestPermissions() async {
    await initialize();
    if (_platform != BlePlatform.android) {
      // iOS shows its prompt when the managers are created; nothing to ask.
      return;
    }
    final s = status;
    final needsAnswer = s.central == RadioAvailability.unauthorized ||
        s.peripheral == RadioAvailability.unauthorized ||
        s.central == RadioAvailability.unknown ||
        s.peripheral == RadioAvailability.unknown;
    if (!needsAnswer) {
      // Already allowed (or not something permission can fix): no dialog, and
      // no state change to wait for.
      return;
    }
    // Run one after the other: each registers a single pending callback.
    var anyGranted = false;
    for (final request in <Future<bool> Function()>[
      () => _central!.authorize(),
      () => _peripheral!.authorize(),
    ]) {
      try {
        final granted = await request();
        anyGranted = anyGranted || granted;
        _log.i(_tag, 'permission request result: $granted');
      } on UnsupportedError {
        // Not Android after all.
      } catch (e) {
        _log.w(_tag, 'permission request failed: $e');
      }
    }
    // The state change that follows a grant is reported a moment after the
    // dialog closes (the plugin re-reads it when the app resumes). Wait for it
    // - but not when the answer was no: nothing is going to change then.
    if (anyGranted) await _waitUntilAuthorized(const Duration(seconds: 2));
  }

  bool get _awaitingPermission =>
      status.central == RadioAvailability.unauthorized ||
      status.peripheral == RadioAvailability.unauthorized;

  Future<void> _waitUntilAuthorized(Duration max) async {
    final deadline = DateTime.now().add(max);
    while (_awaitingPermission && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 80));
    }
  }

  @override
  Future<void> openAppSettings() async {
    await initialize();
    try {
      await _central!.showAppSettings();
    } catch (e) {
      _log.w(_tag, 'could not open settings: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // State changes
  // ---------------------------------------------------------------------------

  /// Processes one reported transition of the central manager's state.
  void _onCentralState(BluetoothLowEnergyState state) {
    if (_disposed) return;
    final wasOn = _centralState == BluetoothLowEnergyState.poweredOn;
    _centralState = state;
    final isOn = state == BluetoothLowEnergyState.poweredOn;
    _log.i(_tag, 'central state -> ${state.name}');
    if (wasOn && !isOn) {
      _scanning = false;
      _closeLinksWhere((l) => l.role == LinkRole.central, 'bluetooth unavailable');
    }
    _publishStatus();
    // Coming back: the platform has stopped scanning, so resume if wanted.
    if (isOn && !wasOn && _wantScan) {
      unawaited(startScan());
    }
  }

  /// Processes one reported transition of the peripheral manager's state.
  void _onPeripheralState(BluetoothLowEnergyState state) {
    if (_disposed) return;
    final wasOn = _peripheralState == BluetoothLowEnergyState.poweredOn;
    _peripheralState = state;
    final isOn = state == BluetoothLowEnergyState.poweredOn;
    _log.i(_tag, 'peripheral state -> ${state.name}');
    if (wasOn && !isOn) {
      _advertising = false;
      _gattReady = false;
      _closeLinksWhere((l) => l.role == LinkRole.peripheral, 'bluetooth unavailable');
    }
    _publishStatus();
    // Coming back: the plugin has re-opened an EMPTY GATT server.
    if (isOn && !wasOn) {
      unawaited(_setupGatt());
    }
  }

  void _closeLinksWhere(bool Function(_Link) test, String reason) {
    for (final link in _links.values.toList()) {
      if (test(link)) _closeLink(link.id, reason, disconnectPlatform: false);
    }
  }

  // ---------------------------------------------------------------------------
  // Peripheral role: GATT server and advertising
  // ---------------------------------------------------------------------------

  Future<void> _setupGatt() async {
    final peripheral = _peripheral;
    if (peripheral == null || _gattBusy || _disposed) return;
    _gattBusy = true;
    try {
      try {
        // A previous instance may still exist (iOS keeps services across
        // calls); adding the same service twice would duplicate it.
        await peripheral.removeAllServices();
      } catch (_) {
        // No server open yet / nothing to remove.
      }
      final characteristic = GATTCharacteristic.mutable(
        uuid: _characteristicUuid,
        properties: [GATTCharacteristicProperty.write, GATTCharacteristicProperty.notify],
        permissions: [GATTCharacteristicPermission.write],
        descriptors: const [],
      );
      await peripheral.addService(GATTService(
        uuid: _serviceUuid,
        isPrimary: true,
        includedServices: const [],
        characteristics: [characteristic],
      ));
      _localCharacteristic = characteristic;
      _gattReady = true;
      _log.i(_tag, 'GATT service published');
    } catch (e) {
      _gattReady = false;
      _lastError = 'Could not publish the Bluetooth service: $e';
      _log.e(_tag, _lastError!);
    } finally {
      _gattBusy = false;
    }
    if (_gattReady && _wantAdvertising) {
      await _startAdvertisingNow();
    }
  }

  @override
  Future<void> startAdvertising() async {
    _wantAdvertising = true;
    if (!_initialized) return;
    if (_gattReady) {
      await _startAdvertisingNow();
    } else if (status.canAdvertise) {
      await _setupGatt();
    }
  }

  Future<void> _startAdvertisingNow() async {
    final peripheral = _peripheral;
    if (peripheral == null || _advertising || !_wantAdvertising || !status.canAdvertise) return;
    try {
      // Service UUID only: no name (it would rename the whole phone's
      // Bluetooth and broadcast a human-readable label) and no other data.
      await peripheral.startAdvertising(Advertisement(serviceUUIDs: [_serviceUuid]));
      _advertising = true;
      _lastError = null;
      _log.i(_tag, 'advertising started');
    } catch (e) {
      if (e.toString().contains('error code: 3')) {
        // ADVERTISE_FAILED_ALREADY_STARTED: it is on, which is what we want.
        _advertising = true;
        return;
      }
      _advertising = false;
      _lastError = 'Could not start advertising: $e';
      _log.e(_tag, _lastError!);
      _advertiseRetryTimer?.cancel();
      _advertiseRetryTimer = Timer(timings.advertiseRetry, () {
        if (_wantAdvertising && !_advertising && !_disposed) {
          unawaited(_startAdvertisingNow());
        }
      });
    }
  }

  @override
  Future<void> stopAdvertising() async {
    _wantAdvertising = false;
    _advertiseRetryTimer?.cancel();
    final peripheral = _peripheral;
    if (peripheral == null || !_advertising) return;
    _advertising = false;
    try {
      await peripheral.stopAdvertising();
    } catch (e) {
      _log.w(_tag, 'stop advertising failed: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Central role: scanning
  // ---------------------------------------------------------------------------

  @override
  Future<void> startScan() async {
    _wantScan = true;
    final central = _central;
    if (central == null || _scanning || !status.canScan) return;
    try {
      await central.startDiscovery(serviceUUIDs: [_serviceUuid]);
      _scanning = true;
    } catch (e) {
      _scanning = false;
      _lastError = 'Could not start scanning: $e';
      _log.e(_tag, _lastError!);
    }
  }

  @override
  Future<void> stopScan() async {
    _wantScan = false;
    final central = _central;
    if (central == null || !_scanning) return;
    _scanning = false;
    try {
      await central.stopDiscovery();
    } catch (e) {
      _log.w(_tag, 'stop scan failed: $e');
    }
  }

  void _onDiscovered(DiscoveredEventArgs e) {
    final deviceId = e.peripheral.uuid.toString();
    _peripherals[deviceId] = e.peripheral;
    _discoveryController.add(RadioDiscovery(
      deviceId: deviceId,
      rssi: e.rssi,
      atMs: DateTime.now().millisecondsSinceEpoch,
    ));
  }

  // ---------------------------------------------------------------------------
  // Central role: connecting
  // ---------------------------------------------------------------------------

  @override
  Future<String> connect(String deviceId, {Duration? timeout}) {
    final linkId = _centralLinkId(deviceId);
    final existing = _links[linkId];
    if (existing != null && !existing.closed && existing.opened) return Future.value(linkId);
    // One connection attempt at a time: concurrent attempts are a classic
    // source of Android GATT status 133 failures.
    return _connectLock.run(() => _connectNow(deviceId, timeout ?? timings.connectGuard));
  }

  /// Publishes the link as usable and delivers anything that arrived while it
  /// was being set up, in arrival order.
  void _announceOpened(_Link link) {
    link.opened = true;
    _log.i(_tag, 'link ${link.id} usable (chunk ${link.maxChunk})');
    _linkController.add(RadioLinkOpened(
      linkId: link.id,
      role: link.role,
      deviceId: link.deviceId,
      maxChunk: link.maxChunk,
    ));
    for (final data in link.early) {
      _chunkController.add(RadioChunk(link.id, data));
    }
    link.early.clear();
  }

  static String _centralLinkId(String deviceId) => 'c:$deviceId';

  static String _peripheralLinkId(String deviceId) => 'p:$deviceId';

  Future<String> _connectNow(String deviceId, Duration timeout) async {
    final central = _central;
    if (central == null || !status.canScan) {
      throw const RadioException(RadioErrorKind.notReady, 'Bluetooth is not ready');
    }
    final peripheral = _peripherals[deviceId];
    if (peripheral == null) {
      throw const RadioException(RadioErrorKind.notFound, 'Device is no longer known');
    }
    final linkId = _centralLinkId(deviceId);
    if (_links[linkId] case final _Link existing when !existing.closed && existing.opened) {
      return linkId;
    }

    try {
      await central.connect(peripheral).timeout(timeout);
    } on TimeoutException {
      // iOS never gives up on its own; abandon the pending connection.
      unawaited(_disconnectPeripheral(peripheral));
      throw const RadioException(RadioErrorKind.timeout, 'Connection timed out');
    } catch (e) {
      unawaited(_disconnectPeripheral(peripheral));
      throw RadioException(RadioErrorKind.connectFailed, 'Connect failed: $e');
    }

    // Register the link NOW, before the rest of the setup: the remote may
    // start sending the moment our subscription reaches it, which can be
    // before the subscribe call returns here. That data is held in
    // [_Link.early] until the link is announced.
    final link = _Link(
      id: linkId,
      role: LinkRole.central,
      deviceId: deviceId,
      maxChunk: 20,
    )..peripheral = peripheral;
    _links[linkId] = link;

    try {
      if (_platform == BlePlatform.android && timings.postConnectDelay > Duration.zero) {
        await Future<void>.delayed(timings.postConnectDelay);
      }

      if (_platform == BlePlatform.android) {
        try {
          // 517 is the ATT maximum. Android 14+ forces it on the first
          // request anyway; older versions negotiate the best the peer allows.
          final mtu = await central.requestMTU(peripheral, mtu: 517).timeout(timings.mtuTimeout);
          _log.d(_tag, 'MTU for $deviceId = $mtu');
        } catch (e) {
          // Not fatal: we fall back to whatever the stack ended up with.
          _log.w(_tag, 'MTU request failed ($e); using the default');
        }
      }

      final services = await central.discoverGATT(peripheral).timeout(timings.discoverTimeout);
      final characteristic = _findDataCharacteristic(services);
      if (characteristic == null) {
        throw const RadioException(
          RadioErrorKind.serviceMissing,
          'The device does not offer the ${AppInfo.latinName} service',
        );
      }

      link.remoteCharacteristic = characteristic;
      await central
          .setCharacteristicNotifyState(peripheral, characteristic, state: true)
          .timeout(timings.subscribeTimeout);

      int writable;
      try {
        // Ask for the WITHOUT-response limit even though we write WITH
        // response. That figure is what one ATT packet really carries
        // (MTU - 3). For with-response writes CoreBluetooth reports 512
        // instead, because it silently splits bigger values into multi-step
        // "long writes": slower (several round trips per chunk) and handled
        // less reliably by peripherals. Android ignores the type.
        writable = await central.getMaximumWriteLength(
          peripheral,
          type: GATTCharacteristicWriteType.withoutResponse,
        );
      } catch (_) {
        writable = 20;
      }

      if (link.closed) {
        throw const RadioException(RadioErrorKind.connectFailed, 'Disconnected during setup');
      }
      link.maxChunk = _clampChunk(writable);
      _announceOpened(link);
      return linkId;
    } on RadioException {
      _closeLink(linkId, 'setup failed');
      rethrow;
    } on TimeoutException {
      unawaited(_disconnectPeripheral(peripheral));
      throw const RadioException(RadioErrorKind.timeout, 'Setting up the link timed out');
    } catch (e) {
      unawaited(_disconnectPeripheral(peripheral));
      throw RadioException(RadioErrorKind.connectFailed, 'Setting up the link failed: $e');
    }
  }

  GATTCharacteristic? _findDataCharacteristic(List<GATTService> services) {
    for (final service in services) {
      if (service.uuid != _serviceUuid) continue;
      for (final c in service.characteristics) {
        if (c.uuid != _characteristicUuid) continue;
        final p = c.properties;
        if (p.contains(GATTCharacteristicProperty.write) &&
            p.contains(GATTCharacteristicProperty.notify)) {
          return c;
        }
      }
    }
    return null;
  }

  Future<void> _disconnectPeripheral(Peripheral peripheral) async {
    try {
      await _central?.disconnect(peripheral);
    } catch (_) {
      // Already gone.
    }
  }

  static int _clampChunk(int value) => value.clamp(20, 509);

  void _onCentralConnectionChanged(PeripheralConnectionStateChangedEventArgs e) {
    if (e.state == ConnectionState.disconnected) {
      _closeLink(_centralLinkId(e.peripheral.uuid.toString()), 'disconnected',
          disconnectPlatform: false);
    }
  }

  void _onCentralMtuChanged(PeripheralMTUChangedEventArgs e) {
    final link = _links[_centralLinkId(e.peripheral.uuid.toString())];
    if (link != null) link.maxChunk = _clampChunk(e.mtu - 3);
  }

  void _onNotified(GATTCharacteristicNotifiedEventArgs e) {
    if (e.characteristic.uuid != _characteristicUuid) return;
    final linkId = _centralLinkId(e.peripheral.uuid.toString());
    final link = _links[linkId];
    if (link == null || link.closed) return;
    _deliver(link, Uint8List.fromList(e.value));
  }

  /// Hands a received chunk upwards, or holds it until the link is announced.
  void _deliver(_Link link, Uint8List data) {
    if (link.opened) {
      _chunkController.add(RadioChunk(link.id, data));
    } else if (link.early.length < _Link.maxEarlyChunks) {
      link.early.add(data);
    } else {
      _log.w(_tag, 'dropping early data on ${link.id}: buffer full');
    }
  }

  // ---------------------------------------------------------------------------
  // Peripheral role: remote centrals
  // ---------------------------------------------------------------------------

  Future<void> _onNotifyStateChanged(GATTCharacteristicNotifyStateChangedEventArgs e) async {
    if (e.characteristic.uuid != _characteristicUuid) return;
    final deviceId = e.central.uuid.toString();
    final linkId = _peripheralLinkId(deviceId);
    if (!e.state) {
      _closeLink(linkId, 'central unsubscribed', disconnectPlatform: false);
      return;
    }
    if (_links[linkId] case final _Link existing when !existing.closed) {
      return; // re-subscription of a known link
    }
    // Register first, announce later: the central starts writing as soon as
    // its subscription is acknowledged, i.e. possibly before the async size
    // lookup below returns. Those writes are buffered in the link.
    final link = _Link(
      id: linkId,
      role: LinkRole.peripheral,
      deviceId: deviceId,
      maxChunk: 20,
    )..central = e.central;
    _links[linkId] = link;
    var maxNotify = 20;
    try {
      maxNotify = await _peripheral!.getMaximumNotifyLength(e.central);
    } catch (_) {
      // keep the safe default
    }
    if (link.closed) return; // the central left while we were looking
    link.maxChunk = _clampChunk(maxNotify);
    _announceOpened(link);
  }

  void _onPeripheralMtuChanged(CentralMTUChangedEventArgs e) {
    final link = _links[_peripheralLinkId(e.central.uuid.toString())];
    if (link != null) link.maxChunk = _clampChunk(e.mtu - 3);
  }

  void _onPeripheralConnectionChanged(CentralConnectionStateChangedEventArgs e) {
    if (e.state == ConnectionState.disconnected) {
      _closeLink(_peripheralLinkId(e.central.uuid.toString()), 'central disconnected',
          disconnectPlatform: false);
    }
  }

  Future<void> _onWriteRequested(GATTCharacteristicWriteRequestedEventArgs e) async {
    final peripheral = _peripheral;
    if (peripheral == null) return;
    final linkId = _peripheralLinkId(e.central.uuid.toString());
    final link = _links[linkId];
    final valid = e.characteristic.uuid == _characteristicUuid &&
        link != null &&
        !link.closed &&
        e.request.offset == 0;
    if (valid) {
      // Hand the data upwards BEFORE awaiting the response so chunks keep
      // their arrival order even when several writes are being answered.
      _deliver(link, Uint8List.fromList(e.request.value));
    } else {
      _log.w(_tag, 'ignored a write on unknown link $linkId');
    }
    try {
      if (valid) {
        await peripheral.respondWriteRequest(e.request);
      } else {
        await peripheral.respondWriteRequestWithError(e.request, error: GATTError.writeNotPermitted);
      }
    } catch (err) {
      _log.w(_tag, 'responding to a write failed: $err');
    }
  }

  // ---------------------------------------------------------------------------
  // Sending
  // ---------------------------------------------------------------------------

  @override
  int maxChunkSize(String linkId) => _links[linkId]?.maxChunk ?? 20;

  @override
  Future<void> sendChunk(String linkId, Uint8List chunk) {
    final link = _links[linkId];
    if (link == null || link.closed || !link.opened) {
      return Future<void>.error(
        const RadioException(RadioErrorKind.closed, 'Link is closed'),
      );
    }
    if (chunk.length > link.maxChunk) {
      return Future<void>.error(ArgumentError(
        'Chunk of ${chunk.length} bytes exceeds the link limit ${link.maxChunk}',
      ));
    }
    return link.io.run(() => _sendWithRetry(link, chunk));
  }

  Future<void> _sendWithRetry(_Link link, Uint8List chunk) async {
    const attempts = 3;
    for (var attempt = 0; attempt < attempts; attempt++) {
      if (link.closed) {
        throw const RadioException(RadioErrorKind.closed, 'Link closed while sending');
      }
      try {
        await _sendOnce(link, chunk).timeout(timings.operationTimeout);
        return;
      } on TimeoutException {
        // The stack stopped answering: the link is effectively dead.
        _closeLink(link.id, 'write timed out');
        throw const RadioException(RadioErrorKind.timeout, 'Write timed out');
      } catch (e) {
        if (link.closed) {
          throw const RadioException(RadioErrorKind.closed, 'Link closed while sending');
        }
        if (attempt == attempts - 1) {
          _closeLink(link.id, 'write failed: $e');
          throw RadioException(RadioErrorKind.sendFailed, 'Write failed: $e');
        }
        // Transient ("busy" and friends). A duplicate chunk is harmless: the
        // reassembler discards repeated (frame, index) pairs.
        await Future<void>.delayed(timings.sendRetryBase * (1 << (attempt * 2)));
      }
    }
  }

  Future<void> _sendOnce(_Link link, Uint8List chunk) {
    switch (link.role) {
      case LinkRole.central:
        return _central!.writeCharacteristic(
          link.peripheral!,
          link.remoteCharacteristic!,
          value: chunk,
          type: GATTCharacteristicWriteType.withResponse,
        );
      case LinkRole.peripheral:
        return _peripheral!.notifyCharacteristic(
          link.central!,
          _localCharacteristic!,
          value: chunk,
        );
    }
  }

  @override
  Future<int?> readRssi(String linkId) async {
    final link = _links[linkId];
    if (link == null || link.closed || link.role != LinkRole.central) return null;
    try {
      return await link.io.run(
        () => _central!.readRSSI(link.peripheral!).timeout(timings.operationTimeout),
      );
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Closing
  // ---------------------------------------------------------------------------

  @override
  Future<void> disconnect(String linkId) async {
    _closeLink(linkId, 'requested');
  }

  void _closeLink(String linkId, String reason, {bool disconnectPlatform = true}) {
    final link = _links.remove(linkId);
    if (link == null || link.closed) return;
    link.closed = true;
    _log.i(_tag, 'link $linkId closed: $reason');
    if (disconnectPlatform) {
      switch (link.role) {
        case LinkRole.central:
          final p = link.peripheral;
          if (p != null) unawaited(_disconnectPeripheral(p));
        case LinkRole.peripheral:
          // Only Android lets a peripheral drop a central; on iOS the remote
          // ends the connection (it is told via an application-level BYE).
          if (_platform == BlePlatform.android && link.central != null) {
            unawaited(_peripheral!.disconnect(link.central!).catchError((Object _) {}));
          }
      }
    }
    link.early.clear();
    // A link that was never announced as open has nothing to report closed.
    if (link.opened && !_linkController.isClosed) {
      _linkController.add(RadioLinkClosed(linkId, reason));
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _advertiseRetryTimer?.cancel();
    for (final id in _links.keys.toList()) {
      _closeLink(id, 'radio disposed');
    }
    try {
      await stopScan();
      await stopAdvertising();
    } catch (_) {
      // best effort
    }
    for (final s in _subscriptions) {
      await s.cancel();
    }
    _subscriptions.clear();
    await _statusController.close();
    await _discoveryController.close();
    await _linkController.close();
    await _chunkController.close();
  }
}
