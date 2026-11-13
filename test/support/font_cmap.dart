import 'dart:typed_data';

/// The characters a TrueType font can draw, read from its `cmap` table (formats 4 and
/// 12, which cover everything in Noto Sans Arabic). A small reader, so a test can say
/// "this font has every letter of the app's text" without a font library.
Set<int> fontCharacters(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  final tableCount = data.getUint16(4);
  int? cmapAt;
  for (var i = 0; i < tableCount; i++) {
    final record = 12 + 16 * i;
    final tag = String.fromCharCodes(bytes.sublist(record, record + 4));
    if (tag == 'cmap') cmapAt = data.getUint32(record + 8);
  }
  if (cmapAt == null) throw const FormatException('the font has no cmap table');

  final characters = <int>{};
  final subtableCount = data.getUint16(cmapAt + 2);
  for (var i = 0; i < subtableCount; i++) {
    final subtable = cmapAt + data.getUint32(cmapAt + 4 + 8 * i + 4);
    final format = data.getUint16(subtable);
    if (format == 4) {
      final segments = data.getUint16(subtable + 6) ~/ 2;
      final ends = subtable + 14;
      final starts = ends + segments * 2 + 2;
      for (var s = 0; s < segments; s++) {
        final end = data.getUint16(ends + 2 * s);
        final start = data.getUint16(starts + 2 * s);
        if (start == 0xFFFF) continue;
        for (var c = start; c <= end; c++) {
          characters.add(c);
        }
      }
    } else if (format == 12) {
      final groups = data.getUint32(subtable + 12);
      for (var g = 0; g < groups; g++) {
        final at = subtable + 16 + 12 * g;
        final start = data.getUint32(at);
        final end = data.getUint32(at + 4);
        for (var c = start; c <= end; c++) {
          characters.add(c);
        }
      }
    }
  }
  return characters;
}
