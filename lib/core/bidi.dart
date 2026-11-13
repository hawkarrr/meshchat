import 'package:flutter/widgets.dart' show BuildContext, Directionality, TextDirection;

final RegExp _letter = RegExp(r'\p{L}', unicode: true);

/// Whether [rune] (a letter) belongs to a script written right to left: Hebrew,
/// Arabic (which Kurdish uses), Syriac, Thaana and the others of that family.
bool _isRightToLeft(int rune) =>
    (rune >= 0x0590 && rune <= 0x08FF) ||
    (rune >= 0xFB1D && rune <= 0xFDFF) ||
    (rune >= 0xFE70 && rune <= 0xFEFF) ||
    (rune >= 0x10800 && rune <= 0x10FFF) ||
    (rune >= 0x1E800 && rune <= 0x1EFFF);

/// The way a piece of text written by a person reads, judged by its first letter:
/// Arabic-script text right to left, Latin (and any other) text left to right.
/// Null when it has no letters yet (empty, digits only, an emoji).
///
/// A Kurdish phone shows an English message, and an English phone shows a
/// Kurdish one: each message has to be laid out in its own direction, not the
/// direction of the app, or its punctuation ends up on the wrong side.
TextDirection? textDirectionOf(String text) {
  for (final rune in text.runes) {
    if (!_letter.hasMatch(String.fromCharCode(rune))) continue;
    return _isRightToLeft(rune) ? TextDirection.rtl : TextDirection.ltr;
  }
  return null;
}

/// Starts a run that reads left to right as one block, whatever surrounds it.
const String leftToRightIsolate = '\u2066';

/// Starts a run that reads in the direction of its own first letter.
const String firstStrongIsolate = '\u2068';

/// Ends a run started by either isolate.
const String isolateEnd = '\u2069';

/// [text], a name made by the app, kept together inside a sentence of the language
/// being shown.
///
/// A room's name starts with "#". In a right-to-left sentence the hash, which has
/// no direction of its own, is pulled to the far side of an English name: "#mesh"
/// reads "mesh#". Marking the whole tag as one block that takes the direction of
/// its first letter keeps the hash where it was written, for a Latin name and for
/// an Arabic-script one alike.
///
/// Left alone in a left-to-right app, where nothing can be reordered, so the text
/// stays exactly what it is.
String isolatedIn(BuildContext context, String text) =>
    Directionality.of(context) == TextDirection.rtl
        ? '$firstStrongIsolate$text$isolateEnd'
        : text;
