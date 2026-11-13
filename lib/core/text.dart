import 'dart:convert';

bool _isHiddenOrControl(int r) =>
    r < 0x20 ||
    (r >= 0x7f && r <= 0x9f) ||
    (r >= 0x200b && r <= 0x200f) || // zero-width and directional marks
    (r >= 0x2028 && r <= 0x202e) || // line/paragraph separators, bidi overrides
    (r >= 0x2060 && r <= 0x2064) ||
    (r >= 0x2066 && r <= 0x2069) || // bidi isolates
    r == 0xfeff;

/// Cleans a name that came from the network (or the keyboard) before it is
/// shown or stored: removes control, zero-width and bidirectional-override
/// characters (used to spoof or reorder text), collapses whitespace, and
/// truncates to [maxBytes] of UTF-8 without splitting a character.
String sanitizeDisplayName(String raw, {int maxBytes = 32}) {
  final kept = raw.runes.where((r) => !_isHiddenOrControl(r));
  final collapsed = String.fromCharCodes(kept).replaceAll(RegExp(r'\s+'), ' ').trim();
  final out = StringBuffer();
  var bytes = 0;
  for (final rune in collapsed.runes) {
    final ch = String.fromCharCode(rune);
    final n = utf8.encode(ch).length;
    if (bytes + n > maxBytes) break;
    out.write(ch);
    bytes += n;
  }
  return out.toString().trim();
}
