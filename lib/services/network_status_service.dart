import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import '../l10n/l10n.dart';

/// What kind of internet-style connection the phone currently has.
///
/// This is INFORMATION ONLY. The app never sends a byte over Wi-Fi or mobile
/// data; the status is shown so a person testing "does it work without
/// internet?" can see that the phone really is offline. It is not a transport
/// and nothing depends on it.
enum NetworkKind { none, wifi, mobile, ethernet, other, unknown }

abstract interface class NetworkStatusSource {
  Future<NetworkKind> current();

  Stream<NetworkKind> get changes;
}

class NetworkStatusService implements NetworkStatusSource {
  NetworkStatusService({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  static NetworkKind _map(List<ConnectivityResult> results) {
    if (results.isEmpty || results.every((r) => r == ConnectivityResult.none)) {
      return NetworkKind.none;
    }
    if (results.contains(ConnectivityResult.wifi)) return NetworkKind.wifi;
    if (results.contains(ConnectivityResult.mobile)) return NetworkKind.mobile;
    if (results.contains(ConnectivityResult.ethernet)) return NetworkKind.ethernet;
    return NetworkKind.other;
  }

  @override
  Future<NetworkKind> current() async {
    try {
      return _map(await _connectivity.checkConnectivity());
    } catch (_) {
      return NetworkKind.unknown;
    }
  }

  @override
  Stream<NetworkKind> get changes =>
      _connectivity.onConnectivityChanged.map(_map).handleError((Object _) {});
}

class StaticNetworkStatus implements NetworkStatusSource {
  StaticNetworkStatus(this.kind);

  NetworkKind kind;

  @override
  Future<NetworkKind> current() async => kind;

  @override
  Stream<NetworkKind> get changes => const Stream<NetworkKind>.empty();
}

/// What the phone's network is doing, in words. [l] is the language; English
/// when none is given (the Bluetooth self-test report).
String describeNetwork(NetworkKind kind, [AppLocalizations? l]) {
  final s = l ?? englishStrings();
  return switch (kind) {
    NetworkKind.none => s.netNone,
    NetworkKind.wifi => s.netWifi,
    NetworkKind.mobile => s.netMobile,
    NetworkKind.ethernet => s.netWired,
    NetworkKind.other => s.netOther,
    NetworkKind.unknown => s.netUnknown,
  };
}
