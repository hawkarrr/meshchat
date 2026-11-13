import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// A file held in the media store.
class MediaFileInfo {
  const MediaFileInfo(this.name, this.modifiedMs);

  final String name;
  final int modifiedMs;
}

/// Where finished images and voice messages are kept: a private folder of the
/// app, never the user's gallery. Names are always `<media id>.<extension>`.
abstract interface class MediaStore {
  Future<void> save(String name, Uint8List bytes);

  Future<Uint8List?> read(String name);

  Future<void> delete(String name);

  Future<List<MediaFileInfo>> list();

  /// Where the file lives, for APIs that need a path (audio playback). Null for
  /// stores that are not backed by files.
  Future<String?> pathOf(String name);
}

final RegExp _validName = RegExp(r'^[0-9a-f]{32}\.(jpg|m4a|mp4)$');

/// Rejects anything that is not one of our own file names, so a name can never
/// point outside the media folder.
void _checkName(String name) {
  if (!_validName.hasMatch(name)) throw ArgumentError.value(name, 'name', 'not a media file name');
}

class FileMediaStore implements MediaStore {
  FileMediaStore(this.directory);

  final Directory directory;

  /// `<application support>/media`, private to the app.
  static Future<FileMediaStore> openDefault() async {
    final base = await getApplicationSupportDirectory();
    final store = FileMediaStore(Directory(p.join(base.path, 'media')));
    await store.deleteTemporaries();
    return store;
  }

  Future<void> _ensure() async {
    if (!await directory.exists()) await directory.create(recursive: true);
  }

  File _file(String name) {
    _checkName(name);
    return File(p.join(directory.path, name));
  }

  @override
  Future<void> save(String name, Uint8List bytes) async {
    await _ensure();
    final target = _file(name);
    // Write beside the target, then rename, so a crash never leaves a
    // half-written file under the real name.
    final temp = File('${target.path}.tmp');
    await temp.writeAsBytes(bytes, flush: true);
    await temp.rename(target.path);
  }

  @override
  Future<Uint8List?> read(String name) async {
    final f = _file(name);
    if (!await f.exists()) return null;
    return f.readAsBytes();
  }

  @override
  Future<void> delete(String name) async {
    final f = _file(name);
    if (await f.exists()) await f.delete();
  }

  @override
  Future<List<MediaFileInfo>> list() async {
    if (!await directory.exists()) return const <MediaFileInfo>[];
    final out = <MediaFileInfo>[];
    await for (final entity in directory.list()) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      if (!_validName.hasMatch(name)) continue;
      out.add(MediaFileInfo(name, (await entity.lastModified()).millisecondsSinceEpoch));
    }
    return out;
  }

  @override
  Future<String?> pathOf(String name) async {
    final f = _file(name);
    return await f.exists() ? f.path : null;
  }

  /// Removes temporary files an interrupted write left behind.
  Future<void> deleteTemporaries() async {
    if (!await directory.exists()) return;
    await for (final entity in directory.list()) {
      if (entity is File && entity.path.endsWith('.tmp')) await entity.delete();
    }
  }
}

/// Keeps media in memory. For tests.
class MemoryMediaStore implements MediaStore {
  MemoryMediaStore([this._nowMs]);

  final int Function()? _nowMs;
  final Map<String, Uint8List> _files = <String, Uint8List>{};
  final Map<String, int> _times = <String, int>{};

  Map<String, Uint8List> get files => Map.unmodifiable(_files);

  @override
  Future<void> save(String name, Uint8List bytes) async {
    _checkName(name);
    _files[name] = Uint8List.fromList(bytes);
    _times[name] = _nowMs?.call() ?? DateTime.now().millisecondsSinceEpoch;
  }

  @override
  Future<Uint8List?> read(String name) async {
    _checkName(name);
    final b = _files[name];
    return b == null ? null : Uint8List.fromList(b);
  }

  @override
  Future<void> delete(String name) async {
    _checkName(name);
    _files.remove(name);
    _times.remove(name);
  }

  @override
  Future<List<MediaFileInfo>> list() async =>
      [for (final e in _times.entries) MediaFileInfo(e.key, e.value)];

  @override
  Future<String?> pathOf(String name) async => null;
}
