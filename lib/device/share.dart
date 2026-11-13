import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

/// A file to hand to another app: either a file in the app's private folder
/// ([path]) or its bytes (for stores that are not backed by files).
class SharedFile {
  const SharedFile({this.path, this.bytes, required this.name, required this.mimeType})
      : assert(path != null || bytes != null);

  final String? path;
  final Uint8List? bytes;
  final String name;
  final String mimeType;
}

/// Hands text and files to another app through the system share sheet. The
/// person picks the app; what that app does with the content is out of Damatqe's
/// hands. Behind an interface so the screens can be tested without a phone.
abstract interface class Sharer {
  Future<void> shareText(String text);

  Future<void> shareFiles(List<SharedFile> files, {String? text});
}

/// The real system share sheet, through `share_plus`.
class PluginSharer implements Sharer {
  const PluginSharer();

  @override
  Future<void> shareText(String text) async {
    await SharePlus.instance.share(ShareParams(text: text));
  }

  @override
  Future<void> shareFiles(List<SharedFile> files, {String? text}) async {
    await SharePlus.instance.share(ShareParams(
      text: text,
      files: [
        for (final f in files)
          f.path != null
              ? XFile(f.path!, name: f.name, mimeType: f.mimeType)
              : XFile.fromData(f.bytes!, name: f.name, mimeType: f.mimeType),
      ],
    ));
  }
}
