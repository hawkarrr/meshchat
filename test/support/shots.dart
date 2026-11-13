import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_mesh_chat/app.dart';

/// What the visual checks (`test/visual/`) share: a comparator that writes the
/// picture to `build/shots/` instead of comparing it, the fonts, and the one-line
/// way to take a shot. They are for a person to look at; they never fail on how a
/// screen looks, only if drawing it throws.
class ShotWriter extends GoldenFileComparator {
  ShotWriter(this.directory);

  final Directory directory;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    directory.createSync(recursive: true);
    File('${directory.path}/${golden.pathSegments.last}').writeAsBytesSync(imageBytes);
    return true;
  }

  @override
  Future<void> update(Uri golden, Uint8List imageBytes) => compare(imageBytes, golden);
}

/// Loads the fonts the app draws with: the bundled Noto Sans Arabic (the very files
/// that ship in the app, `assets/fonts/`), the Roboto of the Flutter SDK for the Latin
/// letters the Arabic font lacks, the Material icons, and Courier New for the
/// monospace face. What a shot shows is what a phone draws, not a stand-in.
Future<void> loadShotFonts() async {
  final root = Platform.environment['FLUTTER_ROOT'] ?? 'C:/src/flutter';
  final sdkFonts = '$root/bin/cache/artifacts/material_fonts';
  final windowsFonts = '${Platform.environment['WINDIR'] ?? 'C:/Windows'}/Fonts';

  ByteData? read(String path) {
    final file = File(path);
    return file.existsSync() ? ByteData.sublistView(file.readAsBytesSync()) : null;
  }

  Future<void> load(String family, Iterable<String> paths) async {
    final loader = FontLoader(family);
    var any = false;
    for (final path in paths) {
      final data = read(path);
      if (data == null) continue;
      loader.addFont(Future<ByteData>.value(data));
      any = true;
    }
    if (any) await loader.load();
  }

  await load('NotoSansArabic', [
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) 'assets/fonts/NotoSansArabic-$weight.ttf',
  ]);
  await load('Roboto', [
    for (final name in ['roboto-regular.ttf', 'roboto-medium.ttf', 'roboto-bold.ttf', 'roboto-italic.ttf'])
      '$sdkFonts/$name',
  ]);
  await load('MaterialIcons', ['$sdkFonts/materialicons-regular.otf']);
  await load('monospace', ['$windowsFonts/cour.ttf']);
}

/// Draws the app as it is now to `build/shots/<name>.png`.
Future<void> shot(WidgetTester tester, String name) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
  await tester.pump(const Duration(milliseconds: 50));
  await expectLater(find.byType(DamataqeApp), matchesGoldenFile('$name.png'));
}
