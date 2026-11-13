// Builds the app's icon files from assets/icon/source.png (the glass bubble).
//
//   dart run tool/make_icons.dart
//
// Writes:
//   assets/icon/icon_full.png        1024x1024, opaque: iOS and legacy Android icon
//   assets/icon/icon_foreground.png  1024x1024, transparent margin: Android adaptive icon
//   assets/branding/logo.png         512x512: the mark shown inside the app
//
// and prints the colour of the picture's corners, which is used as the
// adaptive icon's background so the picture melts into it.
import 'dart:io';

import 'package:image/image.dart' as img;

void main() {
  final source = img.decodePng(File('assets/icon/source.png').readAsBytesSync());
  if (source == null) {
    stderr.writeln('assets/icon/source.png is not a PNG');
    exit(1);
  }
  final side = source.width;

  // The colour of the corners (average of a small patch in each).
  int r = 0, g = 0, b = 0, n = 0;
  for (final (cx, cy) in [(0, 0), (side - 12, 0), (0, side - 12), (side - 12, side - 12)]) {
    for (var y = 0; y < 12; y++) {
      for (var x = 0; x < 12; x++) {
        final p = source.getPixel(cx + x, cy + y);
        r += p.r.toInt();
        g += p.g.toInt();
        b += p.b.toInt();
        n++;
      }
    }
  }
  final hex = '#${(r ~/ n).toRadixString(16).padLeft(2, '0')}'
      '${(g ~/ n).toRadixString(16).padLeft(2, '0')}'
      '${(b ~/ n).toRadixString(16).padLeft(2, '0')}';
  stdout.writeln('corner colour: $hex');

  // Opaque 1024 (no alpha channel: iOS rejects icons with one).
  final full = img.copyResize(source, width: 1024, height: 1024, interpolation: img.Interpolation.cubic);
  final opaque = img.Image(width: 1024, height: 1024, numChannels: 3);
  img.compositeImage(opaque, full);
  File('assets/icon/icon_full.png').writeAsBytesSync(img.encodePng(opaque));

  // Adaptive foreground: the picture at 74% on a transparent canvas, so the
  // glass tile sits inside the safe zone whatever mask the launcher applies.
  final inner = img.copyResize(source, width: 758, height: 758, interpolation: img.Interpolation.cubic);
  final canvas = img.Image(width: 1024, height: 1024, numChannels: 4);
  img.compositeImage(canvas, inner, dstX: 133, dstY: 133);
  File('assets/icon/icon_foreground.png').writeAsBytesSync(img.encodePng(canvas));

  // The in-app mark: crop to the glass tile (its edge plus a hair) and shrink.
  const margin = 92;
  final tile = img.copyCrop(source,
      x: margin, y: margin, width: side - 2 * margin, height: side - 2 * margin);
  final logo = img.copyResize(tile, width: 512, height: 512, interpolation: img.Interpolation.cubic);
  File('assets/branding/logo.png').writeAsBytesSync(img.encodePng(logo));
  stdout.writeln('icons written');
}
