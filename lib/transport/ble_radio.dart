import 'dart:typed_data';

import 'mesh_transport.dart' show LinkRole;

/// Whether one BLE role (scanning/connecting, or advertising/serving) can be
/// used right now, and if not, why. Each value maps to a different message
/// and remedy in the UI.
enum RadioAvailability {
  /// The plugin has not reported a state yet.
  unknown,

  /// This device cannot do it (no BLE, or no BLE advertising support).
  unsupported,

  /// Bluetooth permission has not been granted.
  unauthorized,

  /// Bluetooth is switched off.
  poweredOff,

  /// Ready.
  poweredOn,
}

class RadioStatus {
  const RadioStatus({required this.central, required this.peripheral});

  static const RadioStatus unknown = RadioStatus(
    central: RadioAvailability.unknown,
    peripheral: RadioAvailability.unknown,
  );

  /// The scanning / connecting role.
  final RadioAvailability central;

  /// The advertising / GATT server role.
  final RadioAvailability peripheral;

  bool get canScan => central == RadioAvailability.poweredOn;
  bool get canAdvertise => peripheral == RadioAvailability.poweredOn;

  /// Both roles are usable: the phone can find others AND be found.
  bool get ready => canScan && canAdvertise;

  /// The most important problem, or null when everything works.
  RadioAvailability? get blocker {
    for (final s in [central, peripheral]) {
      if (s == RadioAvailability.unsupported) return s;
    }
    for (final s in [central, peripheral]) {
      if (s == RadioAvailability.unauthorized) return s;
    }
    for (final s in [central, peripheral]) {
      if (s == RadioAvailability.poweredOff) return s;
    }
    for (final s in [central, peripheral]) {
      if (s == RadioAvailability.unknown) return s;
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is RadioStatus && other.central == central && other.peripheral == peripheral;

  @override
  int get hashCode => Object.hash(central, peripheral);

  @override
  String toString() => 'RadioStatus(central=${central.name}, peripheral=${peripheral.name})';
}

class RadioDiscovery {
  const RadioDiscovery({required this.deviceId, required this.rssi, required this.atMs});

  /// Stable-for-this-install identifier of the remote device as the OS exposes
  /// it (a derived MAC address on Android, a UUID on iOS). It may change when
  /// the remote rotates its address, so it is only a connection handle: peers
  /// are identified by their authenticated key, never by this.
  final String deviceId;
  final int rssi;
  final int atMs;
}

sealed class RadioLinkEvent {
  const RadioLinkEvent(this.linkId);

  final String linkId;
}

/// A GATT link is fully usable for data (the central finished subscribing, or
/// a remote central subscribed to us).
class RadioLinkOpened extends RadioLinkEvent {
  const RadioLinkOpened({
    required String linkId,
    required this.role,
    required this.deviceId,
    required this.maxChunk,
  }) : super(linkId);

  final LinkRole role;
  final String deviceId;

  /// Largest single write/notification payload on this link.
  final int maxChunk;
}

class RadioLinkClosed extends RadioLinkEvent {
  const RadioLinkClosed(super.linkId, this.reason);

  final String reason;
}

/// One GATT write or notification payload received on a link.
class RadioChunk {
  const RadioChunk(this.linkId, this.data);

  final String linkId;
  final Uint8List data;
}

enum RadioErrorKind {
  notReady,
  timeout,
  notFound,
  connectFailed,
  serviceMissing,
  sendFailed,
  closed,
}

class RadioException implements Exception {
  const RadioException(this.kind, this.message);

  final RadioErrorKind kind;
  final String message;

  @override
  String toString() => 'RadioException(${kind.name}: $message)';
}

/// The seam between the mesh stack and the Bluetooth plugin.
///
/// An implementation owns both BLE roles at once - it advertises and hosts a
/// GATT server so others can connect to us, AND scans and connects out to
/// others - and presents every connection, whichever side initiated it, as a
/// uniform "link" that carries chunks of bytes in both directions.
abstract interface class BleRadio {
  RadioStatus get status;

  Stream<RadioStatus> get statusChanges;

  Stream<RadioDiscovery> get discoveries;

  Stream<RadioLinkEvent> get linkEvents;

  Stream<RadioChunk> get chunks;

  bool get isAdvertising;

  bool get isScanning;

  /// Last non-fatal problem worth showing to the user (e.g. advertising
  /// failed to start), or null.
  String? get lastError;

  /// Prepares the platform managers and the local GATT service. Idempotent.
  /// On iOS this is what first triggers the Bluetooth permission prompt.
  Future<void> initialize();

  /// Asks the OS for the Bluetooth permissions (Android runtime permissions;
  /// a no-op on iOS, where [initialize] triggers the system prompt).
  Future<void> requestPermissions();

  Future<void> openAppSettings();

  Future<void> startAdvertising();

  Future<void> stopAdvertising();

  Future<void> startScan();

  Future<void> stopScan();

  /// Connects to [deviceId] (central role), negotiates MTU, discovers the
  /// service and subscribes. Returns the link id once the link is usable.
  /// Throws [RadioException] on any failure, having cleaned up.
  Future<String> connect(String deviceId, {Duration timeout = const Duration(seconds: 20)});

  /// Sends one chunk (at most [maxChunkSize] bytes). Calls on one link are
  /// serialised internally; the future completes when the BLE stack accepted
  /// the chunk. Throws [RadioException] if the link is gone or the send fails.
  Future<void> sendChunk(String linkId, Uint8List chunk);

  Future<void> disconnect(String linkId);

  int maxChunkSize(String linkId);

  Future<int?> readRssi(String linkId);

  Future<void> dispose();
}
