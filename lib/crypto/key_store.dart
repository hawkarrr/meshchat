import 'dart:typed_data';

/// Storage for small secrets (identity key seeds, channel keys).
///
/// The production implementation is backed by the platform keystore
/// (Android Keystore / iOS Keychain); tests use [MemoryKeyStore].
abstract interface class KeyStore {
  Future<Uint8List?> read(String name);

  Future<void> write(String name, Uint8List value);

  Future<void> delete(String name);

  /// Removes every secret held by this store.
  Future<void> deleteAll();
}

class MemoryKeyStore implements KeyStore {
  final Map<String, Uint8List> _values = <String, Uint8List>{};

  /// Visible for tests.
  Map<String, Uint8List> get snapshot => Map.unmodifiable(_values);

  @override
  Future<Uint8List?> read(String name) async {
    final v = _values[name];
    return v == null ? null : Uint8List.fromList(v);
  }

  @override
  Future<void> write(String name, Uint8List value) async {
    _values[name] = Uint8List.fromList(value);
  }

  @override
  Future<void> delete(String name) async {
    _values.remove(name);
  }

  @override
  Future<void> deleteAll() async {
    _values.clear();
  }
}
