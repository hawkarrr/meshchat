import '../core/app_info.dart';
import 'dart:typed_data';

import 'package:gal/gal.dart';
import '../l10n/l10n.dart';

/// Why a picture or video could not be copied to the gallery, in words for the
/// person.
class GalleryException implements Exception {
  const GalleryException(this.message, {this.problem});

  /// The words in English, for logs and for a problem nobody has a translation of.
  final String message;
  final GalleryProblem? problem;

  /// What to tell the person, in the language of [l].
  String text(AppLocalizations l) => switch (problem) {
        GalleryProblem.denied => l.galDenied,
        GalleryProblem.noSpace => l.galNoSpace,
        GalleryProblem.unsupported => l.galUnsupported,
        GalleryProblem.failed => l.galFailed,
        GalleryProblem.pictureGone => l.galPictureGone,
        GalleryProblem.videoGone => l.galVideoGone,
        GalleryProblem.voice => l.galVoice,
        null => message,
      };

  @override
  String toString() => message;
}

enum GalleryProblem { denied, noSpace, unsupported, failed, pictureGone, videoGone, voice }

/// Copies a received picture or video out of Damatqe's private storage into the
/// phone's gallery. Behind an interface so the screens can be tested without a
/// phone.
abstract interface class GallerySaver {
  Future<void> saveImage(Uint8List bytes);

  /// [path] is the video's file inside the app's private folder.
  Future<void> saveVideo(String path);
}

/// The real gallery, through the `gal` plugin. On Android 10 and newer nothing
/// is asked; Android 9 and older ask for storage access, iPhone for permission
/// to add to the photo library.
class PluginGallerySaver implements GallerySaver {
  const PluginGallerySaver();

  static const String _denied =
      "${AppInfo.name} was not allowed to add to your gallery. You can allow it in your phone's settings.";

  Future<void> _guard(Future<void> Function() save) async {
    try {
      if (!await Gal.hasAccess() && !await Gal.requestAccess()) {
        throw const GalleryException(_denied, problem: GalleryProblem.denied);
      }
      await save();
    } on GalException catch (e) {
      throw switch (e.type) {
        GalExceptionType.accessDenied =>
          const GalleryException(_denied, problem: GalleryProblem.denied),
        GalExceptionType.notEnoughSpace => const GalleryException(
            'There is not enough space on this phone to save it.',
            problem: GalleryProblem.noSpace),
        GalExceptionType.notSupportedFormat => const GalleryException(
            'This phone cannot save that kind of file to the gallery.',
            problem: GalleryProblem.unsupported),
        GalExceptionType.unexpected => const GalleryException(
            'It could not be saved to the gallery.',
            problem: GalleryProblem.failed),
      };
    }
  }

  @override
  Future<void> saveImage(Uint8List bytes) => _guard(() => Gal.putImageBytes(bytes));

  @override
  Future<void> saveVideo(String path) => _guard(() => Gal.putVideo(path));
}
