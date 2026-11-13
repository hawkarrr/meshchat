import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../crypto/key_store.dart';

/// [KeyStore] backed by the platform keystore through flutter_secure_storage
/// (Android Keystore-wrapped AES-GCM, iOS Keychain).
///
/// Items use the "this device only" Keychain class so they are excluded from
/// iCloud Keychain sync and device-to-device migration: an identity must not
/// silently appear on another phone.
class SecureKeyStore implements KeyStore {
  SecureKeyStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
              ),
            );

  final FlutterSecureStorage _storage;

  static const String _prefix = 'meshchat.v1.';

  @override
  Future<Uint8List?> read(String name) async {
    final v = await _storage.read(key: '$_prefix$name');
    if (v == null) return null;
    try {
      return base64Decode(v);
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> write(String name, Uint8List value) =>
      _storage.write(key: '$_prefix$name', value: base64Encode(value));

  @override
  Future<void> delete(String name) => _storage.delete(key: '$_prefix$name');

  @override
  Future<void> deleteAll() async {
    final all = await _storage.readAll();
    for (final k in all.keys) {
      if (k.startsWith(_prefix)) {
        await _storage.delete(key: k);
      }
    }
  }
}
