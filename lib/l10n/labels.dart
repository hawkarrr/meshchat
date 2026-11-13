import '../protocol/envelope.dart';
import '../services/discovery_service.dart';
import 'app_localizations.dart';

/// Words for the app's enums, in the language of an [AppLocalizations].
extension MediaKindLabels on MediaKind {
  /// What it is called in a one-line summary: "Photo", "Voice message", "Video".
  String label(AppLocalizations l) => switch (this) {
        MediaKind.image => l.previewPhoto,
        MediaKind.voice => l.previewVoice,
        MediaKind.video => l.previewVideo,
      };
}

extension DiscoveryModeLabels on DiscoveryMode {
  /// "Balanced", "Battery saver", "Continuous" in the language of [l].
  String localized(AppLocalizations l) => switch (this) {
        DiscoveryMode.balanced => l.modeBalanced,
        DiscoveryMode.lowPower => l.modeLowPower,
        DiscoveryMode.aggressive => l.modeAggressive,
      };
}
