import 'dart:convert';

import 'package:flutter/services.dart';

/// Keeps what is typed within [maxBytes] of UTF-8.
///
/// Names and captions are limited in bytes because that is what the Bluetooth
/// packets carry. A Latin letter is one byte, a Kurdish or Arabic letter two, an
/// emoji four: a plain character limit would let a long Kurdish name through
/// only to have its end cut off silently later. This stops the typing instead,
/// at a whole character, and also trims pasted text to fit.
class ByteLimitFormatter extends TextInputFormatter {
  const ByteLimitFormatter(this.maxBytes);

  final int maxBytes;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (utf8.encode(newValue.text).length <= maxBytes) return newValue;
    final kept = StringBuffer();
    var bytes = 0;
    for (final rune in newValue.text.runes) {
      final ch = String.fromCharCode(rune);
      final n = utf8.encode(ch).length;
      if (bytes + n > maxBytes) break;
      kept.write(ch);
      bytes += n;
    }
    final text = kept.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
