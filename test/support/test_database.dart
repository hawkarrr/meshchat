import 'dart:io';

import 'package:offline_mesh_chat/database/database_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

bool _initialised = false;

void _initFfi() {
  if (_initialised) return;
  sqfliteFfiInit();
  _initialised = true;
}

/// A fresh in-memory database using the real production schema and SQL
/// (sqflite on the host through FFI).
Future<DatabaseHelper> openMemoryDatabase() async {
  _initFfi();
  return DatabaseHelper.open(
    path: inMemoryDatabasePath,
    databaseFactory: databaseFactoryFfi,
    singleInstance: false,
  );
}

/// A database stored in a file, for tests that close and re-open it to prove
/// data survives an application restart.
Future<DatabaseHelper> openFileDatabase(String path) async {
  _initFfi();
  return DatabaseHelper.open(path: path, databaseFactory: databaseFactoryFfi);
}

/// Creates a temp directory removed again by [tearDown] callers.
Directory makeTempDir(String prefix) => Directory.systemTemp.createTempSync(prefix);
