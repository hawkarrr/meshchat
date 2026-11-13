import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every colour of the interface comes from the palette in `lib/theme/app_theme.dart`: a
/// screen that wrote a colour of its own would be the one that stops matching the day the
/// palette changes. This reads the sources and names the line.
void main() {
  test('no screen or widget writes a colour of its own', () {
    // The palette itself (and the theme built from it), and the ghost: an illustration,
    // drawn in its own colours.
    const allowed = {
      'lib/theme/app_theme.dart',
      'lib/theme/app_palette.dart',
      'lib/widgets/ghost_mark.dart',
    };
    // "Colors." on its own - the Flutter palette - not "AppColors.", ours.
    final colour = RegExp(r'Color\(0x|(?<![A-Za-z])Colors\.(?!transparent)');
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File) continue;
      final path = entity.path.replaceAll('\\', '/');
      if (!path.endsWith('.dart') || path.startsWith('lib/l10n/') || allowed.contains(path)) continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i].trimLeft();
        if (line.startsWith('//') || line.startsWith('///')) continue;
        if (colour.hasMatch(line)) offenders.add('$path:${i + 1}: $line');
      }
    }
    expect(offenders, isEmpty, reason: 'colours written outside the palette:\n${offenders.join('\n')}');
  });

  test('the font family is named once, in the theme', () {
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File) continue;
      final path = entity.path.replaceAll('\\', '/');
      if (!path.endsWith('.dart') || path.startsWith('lib/l10n/') || path == 'lib/theme/app_theme.dart') continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].contains("fontFamily: '") && !lines[i].contains('MaterialIcons')) {
          offenders.add('$path:${i + 1}: ${lines[i].trim()}');
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}
