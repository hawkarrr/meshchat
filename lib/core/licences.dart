import 'package:flutter/foundation.dart'
    show LicenseEntry, LicenseEntryWithLineBreaks, LicenseRegistry;
import 'package:flutter/services.dart' show rootBundle;

/// The licence of the bundled font (SIL Open Font License 1.1), as a licence page entry.
Future<LicenseEntry> bundledFontLicence() async => LicenseEntryWithLineBreaks(
      const <String>['Noto Sans Arabic'],
      await rootBundle.loadString('assets/fonts/OFL.txt'),
    );

/// Adds the licence of the bundled font to the list that Settings > About shows
/// (Flutter and the packages the app uses are listed by the framework itself).
void registerBundledLicences() {
  LicenseRegistry.addLicense(() async* {
    yield await bundledFontLicence();
  });
}
