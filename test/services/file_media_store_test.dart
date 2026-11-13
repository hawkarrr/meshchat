import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:offline_mesh_chat/services/media_store.dart';
import 'package:path/path.dart' as p;

import '../support/message_node.dart' show fakeBytes;
import '../support/test_database.dart' show makeTempDir;

/// A valid media file name: 32 hex digits and an extension.
String _name(int n, [String extension = 'jpg']) =>
    '${n.toRadixString(16).padLeft(32, '0')}.$extension';

/// The store that keeps pictures and voice messages as files in the app's
/// private folder, exercised on a real disk (a temporary folder).
void main() {
  late Directory root;
  late Directory folder;
  late FileMediaStore store;

  setUp(() {
    root = makeTempDir('damataqe_media_');
    // Two levels that do not exist yet, like a first run.
    folder = Directory(p.join(root.path, 'support', 'media'));
    store = FileMediaStore(folder);
  });

  tearDown(() {
    try {
      root.deleteSync(recursive: true);
    } on FileSystemException {
      // Best effort: it is a temp directory.
    }
  });

  group('writing and reading', () {
    test('a file comes back byte for byte, and really is a file in the folder', () async {
      final bytes = fakeBytes(40 * 1024, 3);
      await store.save(_name(1), bytes);

      expect(await store.read(_name(1)), bytes);
      final path = await store.pathOf(_name(1));
      expect(path, p.join(folder.path, _name(1)));
      expect(File(path!).readAsBytesSync(), bytes);
    });

    test('the folder is created on the first save, parents included', () async {
      expect(folder.existsSync(), isFalse);
      await store.save(_name(1), fakeBytes(100));
      expect(folder.existsSync(), isTrue);
    });

    test('the largest object (64 KB) and a tiny one both round trip', () async {
      final big = fakeBytes(64 * 1024, 9);
      await store.save(_name(1), big);
      await store.save(_name(2, 'm4a'), Uint8List.fromList(<int>[7]));
      expect(await store.read(_name(1)), big);
      expect(await store.read(_name(2, 'm4a')), <int>[7]);
    });

    test('saving a name again replaces the content and leaves no temporary file', () async {
      await store.save(_name(1), fakeBytes(1000, 1));
      final newer = fakeBytes(2000, 2);
      await store.save(_name(1), newer);

      expect(await store.read(_name(1)), newer);
      expect(folder.listSync().map((e) => p.basename(e.path)), [_name(1)],
          reason: 'only the real file is left');
    });

    test('a new store over the same folder (an app restart) sees the same files', () async {
      final photo = fakeBytes(9000, 5);
      final voice = fakeBytes(4000, 6);
      await store.save(_name(1), photo);
      await store.save(_name(2, 'm4a'), voice);

      final reopened = FileMediaStore(Directory(folder.path));
      expect(await reopened.read(_name(1)), photo);
      expect(await reopened.read(_name(2, 'm4a')), voice);
      expect((await reopened.list()).map((f) => f.name).toSet(), {_name(1), _name(2, 'm4a')});
    });
  });

  group('deleting and listing', () {
    test('delete removes the file; deleting it again is harmless', () async {
      await store.save(_name(1), fakeBytes(500));
      await store.delete(_name(1));
      expect(await store.read(_name(1)), isNull);
      expect(await store.pathOf(_name(1)), isNull);
      expect(File(p.join(folder.path, _name(1))).existsSync(), isFalse);
      await store.delete(_name(1));
    });

    test('before anything was saved, every operation is harmless and creates nothing', () async {
      expect(await store.read(_name(1)), isNull);
      expect(await store.pathOf(_name(1)), isNull);
      expect(await store.list(), isEmpty);
      await store.delete(_name(1));
      await store.deleteTemporaries();
      expect(folder.existsSync(), isFalse);
    });

    test('list shows only media files, with when they were written; other things stay', () async {
      await store.save(_name(1), fakeBytes(300, 1));
      await store.save(_name(2, 'm4a'), fakeBytes(300, 2));
      File(p.join(folder.path, 'notes.txt')).writeAsStringSync('not ours');
      File(p.join(folder.path, '${_name(3)}.tmp')).writeAsBytesSync(<int>[1]);
      Directory(p.join(folder.path, 'sub')).createSync();

      final listed = await store.list();
      expect(listed.map((f) => f.name).toSet(), {_name(1), _name(2, 'm4a')});
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final f in listed) {
        expect(f.modifiedMs, closeTo(now, const Duration(minutes: 1).inMilliseconds));
      }
      expect(File(p.join(folder.path, 'notes.txt')).existsSync(), isTrue,
          reason: 'nothing but our own files is ever touched');
    });

    test('deleteTemporaries removes what an interrupted write left, and only that', () async {
      final keep = fakeBytes(800, 4);
      await store.save(_name(1), keep);
      final leftover = File(p.join(folder.path, '${_name(2)}.tmp'))
        ..writeAsBytesSync(<int>[1, 2, 3]);

      await store.deleteTemporaries();

      expect(leftover.existsSync(), isFalse);
      expect(await store.read(_name(1)), keep);
    });

    test('openDefault style start-up: leftovers are cleared, real files stay', () async {
      await store.save(_name(1), fakeBytes(50));
      File(p.join(folder.path, '${_name(9)}.tmp')).writeAsBytesSync(<int>[9]);
      final restarted = FileMediaStore(Directory(folder.path));
      await restarted.deleteTemporaries();
      expect(folder.listSync().map((e) => p.basename(e.path)), [_name(1)]);
    });
  });

  group('names', () {
    final bad = <String>[
      '../escape.jpg',
      r'..\escape.jpg',
      'a.jpg',
      '${'0' * 32}.png',
      '${'0' * 32}.jpg/..',
      '/${'0' * 32}.jpg',
      '${'A' * 32}.jpg',
      '${_name(1)}.tmp',
      '',
    ];

    test('anything that is not one of our own names is refused by every operation', () async {
      for (final name in bad) {
        expect(store.save(name, fakeBytes(10)), throwsArgumentError, reason: 'save "$name"');
        expect(store.read(name), throwsArgumentError, reason: 'read "$name"');
        expect(store.delete(name), throwsArgumentError, reason: 'delete "$name"');
        expect(store.pathOf(name), throwsArgumentError, reason: 'pathOf "$name"');
      }
    });

    test('so nothing is ever written outside the media folder', () async {
      for (final name in bad) {
        await store.save(name, fakeBytes(10)).then((_) {}, onError: (Object _) {});
      }
      final outside = root
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => !p.isWithin(folder.path, f.path))
          .toList();
      expect(outside, isEmpty);
      expect(folder.existsSync() ? folder.listSync() : const <FileSystemEntity>[], isEmpty);
    });
  });
}
