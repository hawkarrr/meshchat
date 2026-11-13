import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:offline_mesh_chat/app.dart';
import 'package:offline_mesh_chat/database/database_helper.dart';
import 'package:offline_mesh_chat/device/device_io.dart';
import 'package:offline_mesh_chat/services/media_store.dart';
import 'package:offline_mesh_chat/services/secure_key_store.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Runs on a real phone, not on a computer:
///
///     flutter test integration_test -d <device-id>
///
/// The 1,200-odd tests in `test/` replace every plugin with a stand-in. These
/// check the plugins themselves on the phone - SQLite, the private folders, the
/// keystore, notifications, the background-service channel - and that the app
/// starts. Use a test phone: the last test opens the app's real storage (it only
/// reads it and shows the first screen; it does not touch Bluetooth unless the
/// app on that phone was already set up).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('SQLite: a database in a private folder opens, keeps a row and reopens',
      (tester) async {
    final dir = await getTemporaryDirectory();
    final path = p.join(dir.path, 'it_${DateTime.now().microsecondsSinceEpoch}.db');
    var db = await DatabaseHelper.open(path: path, singleInstance: false);
    await db.db.insert('settings', {'key': 'probe', 'value': 'ok'});
    await db.close();
    db = await DatabaseHelper.open(path: path, singleInstance: false);
    final rows = await db.db.query('settings', where: 'key = ?', whereArgs: ['probe']);
    expect(rows.single['value'], 'ok');
    await db.close();
    await File(path).delete();
  });

  testWidgets('the keystore keeps a key and forgets it', (tester) async {
    final keys = SecureKeyStore();
    const name = 'integration-test-probe';
    final value = Uint8List.fromList(List<int>.generate(32, (i) => i));
    await keys.write(name, value);
    expect(await keys.read(name), value);
    await keys.delete(name);
    expect(await keys.read(name), isNull);
  });

  testWidgets('media files are written whole and read back', (tester) async {
    final dir = await getTemporaryDirectory();
    final store = FileMediaStore(Directory(p.join(dir.path, 'it_media')));
    const name = '0123456789abcdef0123456789abcdef.jpg';
    final bytes = Uint8List.fromList(List<int>.generate(5000, (i) => i & 0xff));
    await store.save(name, bytes);
    expect(await store.read(name), bytes);
    expect(await store.pathOf(name), isNotNull);
    await store.delete(name);
    expect(await store.read(name), isNull);
  });

  testWidgets('notifications and the background-service channel answer', (tester) async {
    final io = DeviceIo.real();
    await io.notifications.initialize(onTap: (_) {});
    await io.notifications.cancelAll();
    if (io.keepAlive.supported) {
      // Asking is harmless; it only reads the phone's state.
      expect(await io.keepAlive.isRunning(), isA<bool>());
      expect(await io.keepAlive.batteryRestricted(), isNotNull);
    }
  });

  testWidgets('the app starts and shows its first screen', (tester) async {
    await tester.pumpWidget(const BootstrapApp());
    for (var i = 0; i < 50 && find.byType(MaterialApp).evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    await tester.pump(const Duration(seconds: 2));
    expect(find.textContaining('could not start'), findsNothing,
        reason: 'the database, the keys and the media folder all opened');
  });
}
