import 'dart:async';
import 'dart:typed_data';

import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import 'package:offline_mesh_chat/protocol/protocol_constants.dart';
import 'package:offline_mesh_chat/services/plugin_ble_radio.dart' show BlePlatform;

// ---------------------------------------------------------------------------
// A simulated Bluetooth environment that implements the bluetooth_low_energy
// plugin's CentralManager / PeripheralManager interfaces.
//
// It deliberately reproduces the behaviours of the REAL plugin that the app's
// radio code has to be written around (all verified in the plugin sources):
//
//  * members that exist on Android only THROW UnsupportedError on iOS;
//  * GATT operations on one connection must not overlap (the real plugin
//    fails the second one or overwrites its completion callback);
//  * notifyCharacteristic() to a central that has not subscribed does nothing;
//  * the ATT MTU is 23 until negotiated; Android must ask for more itself;
//  * the peripheral side only learns the MTU via Android's mtuChanged event;
//  * toggling Bluetooth empties the GATT server;
//  * passing an advertisement name would rename the whole phone;
//  * iOS' connect() never times out by itself.
//
// Every breach of the plugin's contract by the code under test is recorded in
// [FakeBleWorld.violations] so tests can assert that there were none.
// ---------------------------------------------------------------------------

/// What happens when a central tries to connect to a phone.
enum ConnectBehavior { succeed, failFast, hang }

class FakeGattCharacteristic implements GATTCharacteristic {
  FakeGattCharacteristic(this.uuid, this.properties);

  @override
  final UUID uuid;

  @override
  final List<GATTCharacteristicProperty> properties;

  @override
  List<GATTDescriptor> get descriptors => const [];
}

class FakeGattService implements GATTService {
  FakeGattService(this.uuid, this.characteristics);

  @override
  final UUID uuid;

  @override
  final List<GATTCharacteristic> characteristics;

  @override
  bool get isPrimary => true;

  @override
  List<GATTService> get includedServices => const [];
}

class FakePeripheral implements Peripheral {
  FakePeripheral(this.phone);

  final FakePhone phone;

  @override
  UUID get uuid => phone.deviceUuid;
}

class FakeCentral implements Central {
  FakeCentral(this.phone);

  final FakePhone phone;

  @override
  UUID get uuid => phone.deviceUuid;
}

class FakeWriteRequest implements GATTWriteRequest {
  FakeWriteRequest(this.value, this.responseNeeded);

  @override
  final Uint8List value;

  final bool responseNeeded;
  final Completer<void> responded = Completer<void>();

  @override
  int get offset => 0;
}

/// One established GATT connection between two phones.
class _Connection {
  _Connection(this.central, this.peripheral);

  final FakePhone central;
  final FakePhone peripheral;

  /// The real ATT MTU of this connection (starts at the BLE minimum, 23).
  int mtu = 23;

  /// What the peripheral side has been told (Android: only via mtuChanged).
  int mtuKnownToPeripheral = 23;

  bool subscribed = false;
  bool centralBusy = false;
  bool peripheralNotifyBusy = false;
  bool alive = true;
  final List<Completer<void>> pending = <Completer<void>>[];
}

class FakeBleWorld {
  FakeBleWorld({
    this.latency = const Duration(milliseconds: 1),
    this.scanTick = const Duration(milliseconds: 20),
  });

  final Duration latency;
  final Duration scanTick;

  final List<FakePhone> phones = <FakePhone>[];
  final Set<String> _blocked = <String>{};
  final Set<String> _blackholed = <String>{};

  /// Every call the code under test made that the real plugin would reject,
  /// misreport or silently ignore.
  final List<String> violations = <String>[];

  /// Chronological log of plugin calls, e.g. "A: central.connect(B)".
  final List<String> calls = <String>[];

  FakePhone addPhone(
    String name, {
    BlePlatform platform = BlePlatform.android,
    int maxMtu = 247,
  }) {
    final phone = FakePhone._(this, name, platform, maxMtu, phones.length + 1);
    phones.add(phone);
    return phone;
  }

  static String _pair(FakePhone a, FakePhone b) {
    final names = [a.name, b.name]..sort();
    return names.join('|');
  }

  bool inRange(FakePhone a, FakePhone b) => !_blocked.contains(_pair(a, b));

  /// Moves two phones out of / back into radio range of each other.
  /// Going out of range drops any connection between them.
  void setInRange(FakePhone a, FakePhone b, bool inRange) {
    if (inRange) {
      _blocked.remove(_pair(a, b));
    } else {
      _blocked.add(_pair(a, b));
      for (final c in <_Connection>[...a._connections, ...b._connections]) {
        if ((c.central == a && c.peripheral == b) || (c.central == b && c.peripheral == a)) {
          _drop(c);
        }
      }
    }
  }

  /// Radio traffic between the phones silently disappears (but the
  /// connection stays "up"), like a link whose far end froze.
  void blackhole(FakePhone a, FakePhone b, bool on) {
    if (on) {
      _blackholed.add(_pair(a, b));
    } else {
      _blackholed.remove(_pair(a, b));
    }
  }

  bool isBlackholed(FakePhone a, FakePhone b) => _blackholed.contains(_pair(a, b));

  void violation(String text) => violations.add(text);

  void log(String text) => calls.add(text);

  void _drop(_Connection c, {bool notifyCentral = true, bool notifyPeripheral = true}) {
    if (!c.alive) return;
    c.alive = false;
    c.central._connections.remove(c);
    c.peripheral._connections.remove(c);
    for (final p in c.pending) {
      if (!p.isCompleted) {
        p.completeError(StateError('GATT is disconnected with status: 8'));
      }
    }
    c.pending.clear();
    if (notifyCentral) {
      c.central.central._emitConnection(c.peripheral, ConnectionState.disconnected);
    }
    if (notifyPeripheral) {
      c.peripheral.peripheral._connectionLost(c);
    }
  }
}

class FakePhone {
  FakePhone._(this.world, this.name, this.platform, this.maxMtu, int index)
      : deviceUuid = UUID.fromString(
          '00000000-0000-0000-0000-${index.toRadixString(16).padLeft(12, '0')}',
        ) {
    central = FakeCentralManager._(this);
    peripheral = FakePeripheralManager._(this);
  }

  final FakeBleWorld world;
  final String name;
  final BlePlatform platform;

  /// The largest MTU this phone's stack supports.
  final int maxMtu;
  final UUID deviceUuid;

  late final FakeCentralManager central;
  late final FakePeripheralManager peripheral;

  bool bluetoothOn = true;
  bool _permissionsGranted = true;
  bool _bleSupported = true;
  bool _advertisingSupported = true;

  // Changing any of these is something the OS reports through the managers'
  // state streams, so they refresh (and emit) the states like the plugin.
  bool get permissionsGranted => _permissionsGranted;
  set permissionsGranted(bool v) {
    _permissionsGranted = v;
    _refreshStates();
  }

  bool get bleSupported => _bleSupported;
  set bleSupported(bool v) {
    _bleSupported = v;
    _refreshStates();
  }

  bool get advertisingSupported => _advertisingSupported;
  set advertisingSupported(bool v) {
    _advertisingSupported = v;
    _refreshStates();
  }

  /// What the (simulated) user answers when a permission dialog appears.
  bool userGrantsPermissions = true;

  /// How incoming connection attempts to this phone behave.
  ConnectBehavior connectBehavior = ConnectBehavior.succeed;

  int maxConnections = 7;

  int settingsOpened = 0;

  /// Next N writes from this phone's central fail with an exception.
  int failNextWrites = 0;

  /// MTU requests from this phone fail (the connection stays at MTU 23).
  bool failMtuRequests = false;

  /// Makes `getMaximumNotifyLength` slow, widening the window in which a
  /// central that has just subscribed can already be writing to us.
  Duration notifyLengthDelay = Duration.zero;

  /// Delays the acknowledgement of this phone's own CCCD write, widening the
  /// window in which the peripheral can already be notifying us.
  Duration subscribeAckDelay = Duration.zero;

  /// Signal strength at which other phones hear this phone's advertisements.
  int advertisedRssi = -55;

  final List<_Connection> _connections = <_Connection>[];

  int get connectionCount => _connections.length;

  /// Whether this phone is currently advertising the mesh service.
  bool get isAdvertising => peripheral._advertisedServices.contains(_serviceUuid);

  /// Whether the mesh GATT service is currently published.
  bool get hasMeshService => peripheral._hasMeshService;

  bool get isScanning => central._scanning;

  BluetoothLowEnergyState get _centralState {
    if (!bleSupported) return BluetoothLowEnergyState.unsupported;
    if (!permissionsGranted) return BluetoothLowEnergyState.unauthorized;
    return bluetoothOn ? BluetoothLowEnergyState.poweredOn : BluetoothLowEnergyState.poweredOff;
  }

  BluetoothLowEnergyState get _peripheralState {
    if (!bleSupported || !advertisingSupported) return BluetoothLowEnergyState.unsupported;
    if (!permissionsGranted) return BluetoothLowEnergyState.unauthorized;
    return bluetoothOn ? BluetoothLowEnergyState.poweredOn : BluetoothLowEnergyState.poweredOff;
  }

  void _refreshStates() {
    central._setState(_centralState);
    peripheral._setState(_peripheralState);
  }

  /// Switches Bluetooth off or on, as a user would from the quick settings.
  void setBluetooth(bool on) {
    if (bluetoothOn == on) return;
    bluetoothOn = on;
    if (!on) {
      for (final c in List<_Connection>.of(_connections)) {
        world._drop(c);
      }
      central._scanning = false;
      peripheral._advertisedServices.clear();
      peripheral._services.clear(); // the server is gone
    } else {
      peripheral._services.clear(); // re-opened EMPTY: the app must re-add
    }
    _refreshStates();
  }

  void setPermissions(bool granted) => permissionsGranted = granted;

  /// Simulates the OS killing the connection to [other] from the radio side.
  void dropConnectionsTo(FakePhone other) {
    for (final c in List<_Connection>.of(_connections)) {
      if (c.central == other || c.peripheral == other) world._drop(c);
    }
  }

  static final UUID _serviceUuid = UUID.fromString(BleIds.serviceUuid);
  static final UUID _characteristicUuid = UUID.fromString(BleIds.dataCharacteristicUuid);
}

// ---------------------------------------------------------------------------
// CentralManager
// ---------------------------------------------------------------------------

class FakeCentralManager implements CentralManager {
  FakeCentralManager._(this._phone) {
    _state = _phone._centralState;
  }

  final FakePhone _phone;
  late BluetoothLowEnergyState _state;
  bool _scanning = false;
  Timer? _scanTimer;
  List<UUID> _scanFilter = const [];

  final StreamController<BluetoothLowEnergyStateChangedEventArgs> _stateController =
      StreamController<BluetoothLowEnergyStateChangedEventArgs>.broadcast();
  final StreamController<DiscoveredEventArgs> _discoveredController =
      StreamController<DiscoveredEventArgs>.broadcast();
  final StreamController<PeripheralConnectionStateChangedEventArgs> _connectionController =
      StreamController<PeripheralConnectionStateChangedEventArgs>.broadcast();
  final StreamController<PeripheralMTUChangedEventArgs> _mtuController =
      StreamController<PeripheralMTUChangedEventArgs>.broadcast();
  final StreamController<GATTCharacteristicNotifiedEventArgs> _notifiedController =
      StreamController<GATTCharacteristicNotifiedEventArgs>.broadcast();

  bool get _isAndroid => _phone.platform == BlePlatform.android;

  void _log(String s) => _phone.world.log('${_phone.name}: central.$s');

  void _setState(BluetoothLowEnergyState s) {
    if (s == _state) return;
    _state = s;
    if (s != BluetoothLowEnergyState.poweredOn) _stopScanTimer();
    _stateController.add(BluetoothLowEnergyStateChangedEventArgs(s));
  }

  void _emitConnection(FakePhone peripheralPhone, ConnectionState state) {
    _connectionController.add(
      PeripheralConnectionStateChangedEventArgs(FakePeripheral(peripheralPhone), state),
    );
  }

  _Connection? _connectionTo(Peripheral p) {
    final target = (p as FakePeripheral).phone;
    for (final c in _phone._connections) {
      if (c.central == _phone && c.peripheral == target && c.alive) return c;
    }
    return null;
  }

  // ---- state ----------------------------------------------------------------

  @override
  BluetoothLowEnergyState get state => _state;

  @override
  Stream<BluetoothLowEnergyStateChangedEventArgs> get stateChanged => _stateController.stream;

  @override
  Future<bool> authorize() async {
    _log('authorize()');
    if (!_isAndroid) throw UnsupportedError('authorize is not supported on Darwin.');
    if (_phone.permissionsGranted) return true;
    await Future<void>.delayed(_phone.world.latency);
    if (_phone.userGrantsPermissions) {
      _phone.setPermissions(true);
      return true;
    }
    return false;
  }

  @override
  Future<void> showAppSettings() async {
    _log('showAppSettings()');
    _phone.settingsOpened++;
  }

  // ---- scanning -------------------------------------------------------------

  @override
  Stream<DiscoveredEventArgs> get discovered => _discoveredController.stream;

  @override
  Future<void> startDiscovery({List<UUID>? serviceUUIDs}) async {
    _log('startDiscovery(${serviceUUIDs?.length ?? 0} filters)');
    if (_state != BluetoothLowEnergyState.poweredOn) {
      throw StateError('Start discovery failed: bluetooth is ${_state.name}');
    }
    if (serviceUUIDs == null || serviceUUIDs.isEmpty) {
      _phone.world.violation('${_phone.name}: scanning without a service filter');
    }
    _scanFilter = serviceUUIDs ?? const [];
    _scanning = true;
    _scanTimer?.cancel();
    _scanTimer = Timer.periodic(_phone.world.scanTick, (_) => _emitDiscoveries());
  }

  @override
  Future<void> stopDiscovery() async {
    _log('stopDiscovery()');
    _stopScanTimer();
  }

  void _stopScanTimer() {
    _scanning = false;
    _scanTimer?.cancel();
    _scanTimer = null;
  }

  void _emitDiscoveries() {
    if (_state != BluetoothLowEnergyState.poweredOn || _discoveredController.isClosed) return;
    for (final other in _phone.world.phones) {
      if (other == _phone || !other.bluetoothOn) continue;
      if (!_phone.world.inRange(_phone, other)) continue;
      final advertised = other.peripheral._advertisedServices;
      if (advertised.isEmpty) continue;
      if (_scanFilter.isNotEmpty && !_scanFilter.any(advertised.contains)) continue;
      _discoveredController.add(DiscoveredEventArgs(
        FakePeripheral(other),
        other.advertisedRssi,
        Advertisement(serviceUUIDs: advertised.toList()),
      ));
    }
  }

  // ---- connecting -----------------------------------------------------------

  @override
  Stream<PeripheralConnectionStateChangedEventArgs> get connectionStateChanged =>
      _connectionController.stream;

  @override
  Stream<PeripheralMTUChangedEventArgs> get mtuChanged {
    if (!_isAndroid) {
      throw UnsupportedError('mtuChanged is not supported on Darwin.');
    }
    return _mtuController.stream;
  }

  @override
  Stream<GATTCharacteristicNotifiedEventArgs> get characteristicNotified =>
      _notifiedController.stream;

  @override
  Future<void> connect(Peripheral peripheral) async {
    final target = (peripheral as FakePeripheral).phone;
    _log('connect(${target.name})');
    if (_state != BluetoothLowEnergyState.poweredOn) {
      throw StateError('Connect failed: bluetooth is ${_state.name}');
    }
    await Future<void>.delayed(_phone.world.latency);
    if (!target.bluetoothOn || !_phone.world.inRange(_phone, target)) {
      if (_isAndroid) throw StateError('Connect failed with status: 133');
      return Completer<void>().future; // iOS: waits forever
    }
    if (_connectionTo(peripheral) != null) return;
    switch (target.connectBehavior) {
      case ConnectBehavior.failFast:
        throw StateError('Connect failed with status: 133');
      case ConnectBehavior.hang:
        return Completer<void>().future;
      case ConnectBehavior.succeed:
        break;
    }
    if (target._connections.length >= target.maxConnections ||
        _phone._connections.length >= _phone.maxConnections) {
      throw StateError('Connect failed with status: 133');
    }
    final c = _Connection(_phone, target);
    // iOS negotiates the MTU by itself during connection setup.
    if (!_isAndroid) {
      c.mtu = [185, target.maxMtu, _phone.maxMtu].reduce((a, b) => a < b ? a : b);
      c.mtuKnownToPeripheral = c.mtu;
    }
    _phone._connections.add(c);
    target._connections.add(c);
    _emitConnection(target, ConnectionState.connected);
    target.peripheral._connectionEstablished(c);
  }

  @override
  Future<void> disconnect(Peripheral peripheral) async {
    final target = (peripheral as FakePeripheral).phone;
    _log('disconnect(${target.name})');
    final c = _connectionTo(peripheral);
    if (c == null) return;
    _phone.world._drop(c);
  }

  // ---- GATT operations ------------------------------------------------------

  /// Runs one GATT operation, enforcing the "one at a time" rule.
  Future<T> _gatt<T>(String op, Peripheral p, Future<T> Function(_Connection c) body) async {
    final c = _connectionTo(p);
    if (c == null || !c.alive) {
      throw StateError('GATT is disconnected with status: 8');
    }
    if (c.centralBusy) {
      _phone.world.violation('${_phone.name}: overlapping GATT operations ($op while busy)');
      throw StateError('Illegal state: GATT busy');
    }
    c.centralBusy = true;
    try {
      await Future<void>.delayed(_phone.world.latency);
      if (!c.alive) throw StateError('GATT is disconnected with status: 8');
      return await body(c);
    } finally {
      c.centralBusy = false;
    }
  }

  @override
  Future<int> requestMTU(Peripheral peripheral, {required int mtu}) async {
    _log('requestMTU($mtu)');
    if (!_isAndroid) throw UnsupportedError('requestMTU is not supported on Darwin.');
    if (_phone.failMtuRequests) throw StateError('Illegal state');
    return _gatt('requestMTU', peripheral, (c) async {
      final negotiated = [mtu, c.central.maxMtu, c.peripheral.maxMtu].reduce((a, b) => a < b ? a : b);
      c.mtu = negotiated < 23 ? 23 : negotiated;
      _mtuController.add(PeripheralMTUChangedEventArgs(FakePeripheral(c.peripheral), c.mtu));
      c.peripheral.peripheral._mtuChanged(c);
      return c.mtu;
    });
  }

  @override
  Future<int> getMaximumWriteLength(
    Peripheral peripheral, {
    required GATTCharacteristicWriteType type,
  }) async {
    _log('getMaximumWriteLength()');
    final c = _connectionTo(peripheral);
    if (c == null) throw StateError('not connected');
    if (_isAndroid) {
      // The Android implementation derives it from the mtu it was told of,
      // whatever the write type.
      return (c.mtu - 3).clamp(20, 512);
    }
    // CoreBluetooth: for writes WITH response it reports the ATT maximum (512),
    // because it silently splits bigger values into multi-step "long writes".
    // Only the without-response figure is the real single-packet limit.
    return type == GATTCharacteristicWriteType.withResponse ? 512 : c.mtu - 3;
  }

  @override
  Future<int> readRSSI(Peripheral peripheral) async {
    _log('readRSSI()');
    return _gatt('readRSSI', peripheral, (c) async => -60);
  }

  @override
  Future<List<GATTService>> discoverGATT(Peripheral peripheral) async {
    _log('discoverGATT()');
    return _gatt('discoverGATT', peripheral, (c) async {
      return c.peripheral.peripheral._services
          .map((s) => FakeGattService(s.uuid, List<GATTCharacteristic>.of(s.characteristics)))
          .toList();
    });
  }

  @override
  Future<void> setCharacteristicNotifyState(
    Peripheral peripheral,
    GATTCharacteristic characteristic, {
    required bool state,
  }) async {
    _log('setCharacteristicNotifyState($state)');
    return _gatt('setNotify', peripheral, (c) async {
      c.subscribed = state;
      c.peripheral.peripheral._subscriptionChanged(c, state);
      if (_phone.subscribeAckDelay > Duration.zero) {
        await Future<void>.delayed(_phone.subscribeAckDelay);
      }
    });
  }

  @override
  Future<void> writeCharacteristic(
    Peripheral peripheral,
    GATTCharacteristic characteristic, {
    required Uint8List value,
    required GATTCharacteristicWriteType type,
  }) async {
    return _gatt('write', peripheral, (c) async {
      final world = _phone.world;
      if (value.length > c.mtu - 3) {
        world.violation(
            '${_phone.name}: write of ${value.length} bytes exceeds ATT payload ${c.mtu - 3}');
        throw StateError('Invalid attribute length');
      }
      if (_phone.failNextWrites > 0) {
        _phone.failNextWrites--;
        throw StateError('Write characteristic failed with status: 133');
      }
      if (type != GATTCharacteristicWriteType.withResponse) {
        world.violation('${_phone.name}: write without response used (no flow control)');
      }
      if (world.isBlackholed(c.central, c.peripheral)) {
        // The data vanishes and no response ever comes back.
        final never = Completer<void>();
        c.pending.add(never);
        return never.future;
      }
      final request = FakeWriteRequest(Uint8List.fromList(value), type == GATTCharacteristicWriteType.withResponse);
      c.peripheral.peripheral._writeReceived(c, characteristic.uuid, request);
      if (request.responseNeeded) {
        c.pending.add(request.responded);
        await request.responded.future;
        c.pending.remove(request.responded);
      }
    });
  }

  @override
  Future<Uint8List> readCharacteristic(Peripheral peripheral, GATTCharacteristic characteristic) {
    throw UnimplementedError();
  }

  @override
  Future<Uint8List> readDescriptor(Peripheral peripheral, GATTDescriptor descriptor) {
    throw UnimplementedError();
  }

  @override
  Future<void> writeDescriptor(
    Peripheral peripheral,
    GATTDescriptor descriptor, {
    required Uint8List value,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Peripheral> getPeripheral(String address) => throw UnimplementedError();

  @override
  Future<List<Peripheral>> retrieveConnectedPeripherals() => throw UnimplementedError();
}

// ---------------------------------------------------------------------------
// PeripheralManager
// ---------------------------------------------------------------------------

class FakePeripheralManager implements PeripheralManager {
  FakePeripheralManager._(this._phone) {
    _state = _phone._peripheralState;
  }

  final FakePhone _phone;
  late BluetoothLowEnergyState _state;

  /// Published services (empty after every Bluetooth toggle).
  final List<GATTService> _services = <GATTService>[];
  final Set<UUID> _advertisedServices = <UUID>{};

  final StreamController<BluetoothLowEnergyStateChangedEventArgs> _stateController =
      StreamController<BluetoothLowEnergyStateChangedEventArgs>.broadcast();
  final StreamController<CentralConnectionStateChangedEventArgs> _connectionController =
      StreamController<CentralConnectionStateChangedEventArgs>.broadcast();
  final StreamController<CentralMTUChangedEventArgs> _mtuController =
      StreamController<CentralMTUChangedEventArgs>.broadcast();
  final StreamController<GATTCharacteristicWriteRequestedEventArgs> _writeController =
      StreamController<GATTCharacteristicWriteRequestedEventArgs>.broadcast();
  final StreamController<GATTCharacteristicNotifyStateChangedEventArgs> _notifyController =
      StreamController<GATTCharacteristicNotifyStateChangedEventArgs>.broadcast();

  bool get _isAndroid => _phone.platform == BlePlatform.android;

  void _log(String s) => _phone.world.log('${_phone.name}: peripheral.$s');

  bool get _hasMeshService => _services.any((s) =>
      s.uuid == FakePhone._serviceUuid &&
      s.characteristics.any((c) =>
          c.uuid == FakePhone._characteristicUuid &&
          c.properties.contains(GATTCharacteristicProperty.write) &&
          c.properties.contains(GATTCharacteristicProperty.notify)));

  void _setState(BluetoothLowEnergyState s) {
    if (s == _state) return;
    _state = s;
    _stateController.add(BluetoothLowEnergyStateChangedEventArgs(s));
  }

  GATTCharacteristic? _localCharacteristic(UUID uuid) {
    for (final s in _services) {
      for (final c in s.characteristics) {
        if (c.uuid == uuid) return c;
      }
    }
    return null;
  }

  // Callbacks from the central side ------------------------------------------

  void _connectionEstablished(_Connection c) {
    if (_isAndroid) {
      _connectionController.add(
        CentralConnectionStateChangedEventArgs(FakeCentral(c.central), ConnectionState.connected),
      );
    }
  }

  void _connectionLost(_Connection c) {
    if (_isAndroid) {
      _connectionController.add(
        CentralConnectionStateChangedEventArgs(
            FakeCentral(c.central), ConnectionState.disconnected),
      );
    } else if (c.subscribed) {
      // iOS reports a vanished central as an unsubscription.
      c.subscribed = false;
      final ch = _localCharacteristic(FakePhone._characteristicUuid);
      if (ch != null) {
        _notifyController.add(GATTCharacteristicNotifyStateChangedEventArgs(
            FakeCentral(c.central), ch, false));
      }
    }
  }

  void _mtuChanged(_Connection c) {
    if (_isAndroid) {
      c.mtuKnownToPeripheral = c.mtu;
      _mtuController.add(CentralMTUChangedEventArgs(FakeCentral(c.central), c.mtu));
    }
  }

  void _subscriptionChanged(_Connection c, bool state) {
    final ch = _localCharacteristic(FakePhone._characteristicUuid);
    if (ch == null) return;
    _notifyController.add(
      GATTCharacteristicNotifyStateChangedEventArgs(FakeCentral(c.central), ch, state),
    );
  }

  void _writeReceived(_Connection c, UUID characteristicUuid, FakeWriteRequest request) {
    final ch = _localCharacteristic(characteristicUuid);
    if (ch == null) {
      if (request.responseNeeded) {
        // The stack answers with "attribute not found" by itself.
        scheduleMicrotask(() {
          if (!request.responded.isCompleted) request.responded.completeError(StateError('Write failed with status: 10'));
        });
      }
      return;
    }
    _writeController.add(GATTCharacteristicWriteRequestedEventArgs(FakeCentral(c.central), ch, request));
  }

  _Connection? _connectionFor(Central central) {
    final centralPhone = (central as FakeCentral).phone;
    for (final c in _phone._connections) {
      if (c.peripheral == _phone && c.central == centralPhone && c.alive) return c;
    }
    return null;
  }

  // ---- PeripheralManager interface -------------------------------------------

  @override
  BluetoothLowEnergyState get state => _state;

  @override
  Stream<BluetoothLowEnergyStateChangedEventArgs> get stateChanged => _stateController.stream;

  @override
  Future<bool> authorize() async {
    _log('authorize()');
    if (!_isAndroid) throw UnsupportedError('authorize is not supported on Darwin.');
    if (_phone.permissionsGranted) return true;
    await Future<void>.delayed(_phone.world.latency);
    if (_phone.userGrantsPermissions) {
      _phone.setPermissions(true);
      return true;
    }
    return false;
  }

  @override
  Future<void> showAppSettings() async {
    _log('showAppSettings()');
    _phone.settingsOpened++;
  }

  @override
  Stream<CentralConnectionStateChangedEventArgs> get connectionStateChanged {
    if (!_isAndroid) {
      throw UnsupportedError('connectionStateChanged is not supported on Darwin.');
    }
    return _connectionController.stream;
  }

  @override
  Stream<CentralMTUChangedEventArgs> get mtuChanged {
    if (!_isAndroid) throw UnsupportedError('mtuChanged is not supported on Darwin.');
    return _mtuController.stream;
  }

  @override
  Stream<GATTCharacteristicReadRequestedEventArgs> get characteristicReadRequested =>
      const Stream.empty();

  @override
  Stream<GATTCharacteristicWriteRequestedEventArgs> get characteristicWriteRequested =>
      _writeController.stream;

  @override
  Stream<GATTCharacteristicNotifyStateChangedEventArgs> get characteristicNotifyStateChanged =>
      _notifyController.stream;

  @override
  Stream<GATTDescriptorReadRequestedEventArgs> get descriptorReadRequested {
    if (!_isAndroid) throw UnsupportedError('descriptorReadRequested is not supported on Darwin.');
    return const Stream.empty();
  }

  @override
  Stream<GATTDescriptorWriteRequestedEventArgs> get descriptorWriteRequested {
    if (!_isAndroid) throw UnsupportedError('descriptorWriteRequested is not supported on Darwin.');
    return const Stream.empty();
  }

  @override
  Future<void> addService(GATTService service) async {
    _log('addService(${service.uuid})');
    if (_state != BluetoothLowEnergyState.poweredOn) {
      throw StateError('Add service failed: bluetooth is ${_state.name}');
    }
    await Future<void>.delayed(_phone.world.latency);
    _services.add(service);
  }

  @override
  Future<void> removeService(GATTService service) async {
    _services.remove(service);
  }

  @override
  Future<void> removeAllServices() async {
    _log('removeAllServices()');
    if (_state != BluetoothLowEnergyState.poweredOn) {
      throw StateError('Illegal state');
    }
    _services.clear();
  }

  @override
  Future<void> startAdvertising(Advertisement advertisement) async {
    _log('startAdvertising(${advertisement.serviceUUIDs.length} services)');
    if (_state != BluetoothLowEnergyState.poweredOn) {
      throw StateError('Start advertising failed: bluetooth is ${_state.name}');
    }
    if (advertisement.name != null) {
      _phone.world.violation(
          '${_phone.name}: advertisement name "${advertisement.name}" would rename the phone');
    }
    if (advertisement.manufacturerSpecificData.isNotEmpty || advertisement.serviceData.isNotEmpty) {
      _phone.world.violation('${_phone.name}: advertised more than the service uuid');
    }
    await Future<void>.delayed(_phone.world.latency);
    _advertisedServices
      ..clear()
      ..addAll(advertisement.serviceUUIDs);
  }

  @override
  Future<void> stopAdvertising() async {
    _log('stopAdvertising()');
    _advertisedServices.clear();
  }

  @override
  Future<int> getMaximumNotifyLength(Central central) async {
    if (_phone.notifyLengthDelay > Duration.zero) {
      await Future<void>.delayed(_phone.notifyLengthDelay);
    }
    final c = _connectionFor(central);
    if (c == null) throw StateError('central not connected');
    if (_isAndroid) {
      // Only what the stack was told through mtuChanged.
      return (c.mtuKnownToPeripheral - 3).clamp(20, 512);
    }
    return c.mtu - 3;
  }

  @override
  Future<void> respondWriteRequest(GATTWriteRequest request) async {
    final r = request as FakeWriteRequest;
    if (!r.responseNeeded) return;
    await Future<void>.delayed(_phone.world.latency);
    if (!r.responded.isCompleted) r.responded.complete();
  }

  @override
  Future<void> respondWriteRequestWithError(
    GATTWriteRequest request, {
    required GATTError error,
  }) async {
    final r = request as FakeWriteRequest;
    if (!r.responseNeeded) return;
    if (!r.responded.isCompleted) {
      r.responded.completeError(StateError('Write characteristic failed with status: $error'));
    }
  }

  @override
  Future<void> notifyCharacteristic(
    Central central,
    GATTCharacteristic characteristic, {
    required Uint8List value,
  }) async {
    final world = _phone.world;
    final c = _connectionFor(central);
    if (c == null) {
      throw ArgumentError.notNull('central connection');
    }
    if (!c.subscribed) {
      // The real plugin logs a warning and returns normally: the data is lost.
      world.violation('${_phone.name}: notified a central that has not subscribed');
      return;
    }
    if (c.peripheralNotifyBusy) {
      world.violation('${_phone.name}: overlapping notifications to one central');
      throw StateError('Illegal state: notify busy');
    }
    if (value.length > c.mtu - 3) {
      world.violation('${_phone.name}: notification of ${value.length} bytes exceeds ${c.mtu - 3}');
      throw StateError('Notify characteristic value changed failed');
    }
    c.peripheralNotifyBusy = true;
    try {
      await Future<void>.delayed(world.latency);
      if (!c.alive) throw StateError('GATT is disconnected');
      if (world.isBlackholed(c.central, c.peripheral)) return;
      c.central.central._notifiedController.add(
        GATTCharacteristicNotifiedEventArgs(
          FakePeripheral(c.peripheral),
          characteristic,
          Uint8List.fromList(value),
        ),
      );
    } finally {
      c.peripheralNotifyBusy = false;
    }
  }

  @override
  Future<void> respondReadRequestWithValue(GATTReadRequest request, {required Uint8List value}) =>
      throw UnimplementedError();

  @override
  Future<void> respondReadRequestWithError(GATTReadRequest request, {required GATTError error}) =>
      throw UnimplementedError();

  @override
  Future<Central> getCentral(String address) => throw UnimplementedError();

  @override
  Future<List<Central>> retrieveConnectedCentrals() => throw UnimplementedError();

  @override
  Future<void> disconnect(Central central) async {
    _log('disconnect(central)');
    if (!_isAndroid) throw UnsupportedError('disconnect is not supported on Darwin.');
    final c = _connectionFor(central);
    if (c != null) _phone.world._drop(c);
  }
}
