import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../protocol/protocol_constants.dart';
import '../l10n/l10n.dart';

/// Where a photo to send comes from.
enum PhotoSource { gallery, camera }

/// Lets the person choose or take a photo. Behind an interface so the UI can
/// be tested without a phone.
/// A video the person picked. When it is bigger than the limit the bytes are
/// not read at all (a phone video can be hundreds of megabytes): only its size is
/// reported, so the screen can say how far over the limit it is.
class PickedVideo {
  const PickedVideo({required this.length, this.bytes});

  /// Its size in bytes.
  final int length;

  /// The content, or null when it is over the limit.
  final Uint8List? bytes;

  bool get tooLarge => bytes == null;
}

abstract interface class PhotoPicker {
  /// The chosen photo's bytes, or null if the person backed out.
  Future<Uint8List?> pick(PhotoSource source);

  /// A video, recorded with the camera or chosen from the library; null if the
  /// person backed out. A video above [maxBytes] comes back without its bytes.
  Future<PickedVideo?> pickVideo(PhotoSource source, {required int maxBytes});
}

class PluginPhotoPicker implements PhotoPicker {
  PluginPhotoPicker({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<Uint8List?> pick(PhotoSource source) async {
    // The system shrinks the picture first, so the pure-Dart step below only
    // ever sees a modest image.
    final file = await _picker.pickImage(
      source: source == PhotoSource.camera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 85,
    );
    return file?.readAsBytes();
  }

  @override
  Future<PickedVideo?> pickVideo(PhotoSource source, {required int maxBytes}) async {
    final file = await _picker.pickVideo(
      source: source == PhotoSource.camera ? ImageSource.camera : ImageSource.gallery,
      // Short, so what the camera records has a chance of fitting.
      maxDuration: const Duration(seconds: 10),
    );
    if (file == null) return null;
    final length = await file.length();
    if (length > maxBytes) return PickedVideo(length: length);
    return PickedVideo(length: length, bytes: await file.readAsBytes());
  }
}

class CompressedImage {
  const CompressedImage({required this.bytes, required this.width, required this.height});

  final Uint8List bytes;
  final int width;
  final int height;
}

enum ImageProblem { unreadable, tooDetailed }

class ImageCompressionException implements Exception {
  const ImageCompressionException(this.message, {this.problem});

  /// The words in English, for logs.
  final String message;
  final ImageProblem? problem;

  /// What to tell the person, in the language of [l].
  String text(AppLocalizations l) => switch (problem) {
        ImageProblem.unreadable => l.imgUnreadable,
        ImageProblem.tooDetailed => l.imgTooDetailed,
        null => message,
      };

  @override
  String toString() => message;
}

/// Shrinks a photo to the few dozen kilobytes a Bluetooth mesh can carry: it
/// tries smaller and smaller sizes and lower qualities, and keeps the first
/// JPEG that fits [targetBytes].
class ImageCompressor {
  const ImageCompressor({
    this.targetBytes = 40 * 1024,
    this.maxBytes = Protocol.maxMediaBytes,
    this.sides = const <int>[640, 512, 400, 320, 256],
    this.qualities = const <int>[72, 60, 48, 38, 30],
    this.useIsolate = true,
  });

  /// What to aim for: small enough to cross a hop in a few seconds.
  final int targetBytes;

  /// The most a mesh message may carry. Anything above is refused.
  final int maxBytes;

  /// Longest-edge sizes to try, largest first.
  final List<int> sides;

  /// JPEG qualities to try at each size, best first.
  final List<int> qualities;

  /// Do the work on a background isolate (always, except in some tests).
  final bool useIsolate;

  /// Compresses off the UI thread. Throws [ImageCompressionException] if the
  /// bytes are not a picture, or cannot be made small enough.
  Future<CompressedImage> compress(Uint8List input, {bool? inIsolate}) async {
    if (!(inIsolate ?? useIsolate)) return compressSync(input);
    return Isolate.run(() => compressSync(input));
  }

  CompressedImage compressSync(Uint8List input) {
    final decoded = img.decodeImage(input);
    if (decoded == null) {
      throw const ImageCompressionException('That file is not a picture this phone can read.',
          problem: ImageProblem.unreadable);
    }
    var image = img.bakeOrientation(decoded);
    if (image.hasAlpha) {
      // JPEG has no transparency: put the picture on white.
      final flat = img.Image(width: image.width, height: image.height, numChannels: 3);
      img.fill(flat, color: img.ColorRgb8(255, 255, 255));
      img.compositeImage(flat, image);
      image = flat;
    }
    Uint8List? smallest;
    var smallestImage = image;
    for (final side in sides) {
      final longest = max(image.width, image.height);
      final scaled = longest <= side
          ? image
          : img.copyResize(
              image,
              width: image.width >= image.height ? side : null,
              height: image.height > image.width ? side : null,
              interpolation: img.Interpolation.average,
            );
      for (final quality in qualities) {
        final bytes = Uint8List.fromList(img.encodeJpg(scaled, quality: quality));
        if (smallest == null || bytes.length < smallest.length) {
          smallest = bytes;
          smallestImage = scaled;
        }
        if (bytes.length <= targetBytes) {
          return CompressedImage(bytes: bytes, width: scaled.width, height: scaled.height);
        }
      }
    }
    if (smallest != null && smallest.length <= maxBytes) {
      return CompressedImage(
        bytes: smallest,
        width: smallestImage.width,
        height: smallestImage.height,
      );
    }
    throw const ImageCompressionException('That picture is too detailed to send over Bluetooth.',
        problem: ImageProblem.tooDetailed);
  }
}
