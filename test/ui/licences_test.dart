import 'package:flutter/foundation.dart' show LicenseRegistry;
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_mesh_chat/core/licences.dart';

/// The licence page of the app lists the bundled font with its real licence: the font may
/// be used and shipped only with that text.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the licence of the bundled font is the real one, with its full text', () async {
    final entry = await bundledFontLicence();
    expect(entry.packages, ['Noto Sans Arabic']);
    final text = entry.paragraphs.map((p) => p.text).join(' ');
    expect(text, contains('SIL OPEN FONT LICENSE'));
    expect(text, contains('Noto Project Authors'));
  });

  test('it is on the list the licence page shows', () async {
    registerBundledLicences();
    final packages = <String>{};
    await for (final entry in LicenseRegistry.licenses) {
      packages.addAll(entry.packages);
      if (packages.contains('Noto Sans Arabic')) break;
    }
    expect(packages, contains('Noto Sans Arabic'));
  });
}
