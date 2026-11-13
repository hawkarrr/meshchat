import 'dart:typed_data';

/// Lower-case hex encoding of [bytes].
String bytesToHex(List<int> bytes) {
  final out = StringBuffer();
  for (final b in bytes) {
    out.write((b & 0xff).toRadixString(16).padLeft(2, '0'));
  }
  return out.toString();
}

/// Decodes a hex string (upper or lower case, no separators).
///
/// Throws [FormatException] for odd length or non-hex characters.
Uint8List hexToBytes(String hex) {
  if (hex.length.isOdd) {
    throw const FormatException('Hex string has odd length');
  }
  final out = Uint8List(hex.length ~/ 2);
  for (var i = 0; i < out.length; i++) {
    final v = int.tryParse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    if (v == null) {
      throw const FormatException('Hex string contains non-hex characters');
    }
    out[i] = v;
  }
  return out;
}

/// Compares two byte sequences without short-circuiting on the first mismatch.
bool constantTimeEquals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}

/// Concatenates all [parts] into one new [Uint8List].
Uint8List concatBytes(Iterable<List<int>> parts) {
  var total = 0;
  for (final p in parts) {
    total += p.length;
  }
  final out = Uint8List(total);
  var offset = 0;
  for (final p in parts) {
    out.setRange(offset, offset + p.length, p);
    offset += p.length;
  }
  return out;
}

/// True when every byte of [bytes] is zero.
bool isAllZero(List<int> bytes) {
  var acc = 0;
  for (final b in bytes) {
    acc |= b;
  }
  return acc == 0;
}

/// Lexicographic comparison of two byte sequences (shorter is smaller on a tie).
int compareBytes(List<int> a, List<int> b) {
  final n = a.length < b.length ? a.length : b.length;
  for (var i = 0; i < n; i++) {
    if (a[i] != b[i]) return a[i] < b[i] ? -1 : 1;
  }
  return a.length.compareTo(b.length);
}

/// Big-endian writer used by the binary codecs.
class ByteWriter {
  final BytesBuilder _b = BytesBuilder(copy: false);

  void u8(int v) => _b.addByte(v & 0xff);

  void u16(int v) {
    _b.addByte((v >> 8) & 0xff);
    _b.addByte(v & 0xff);
  }

  void u32(int v) {
    _b.addByte((v >> 24) & 0xff);
    _b.addByte((v >> 16) & 0xff);
    _b.addByte((v >> 8) & 0xff);
    _b.addByte(v & 0xff);
  }

  /// Unsigned 64-bit; Dart ints are 64-bit so values >= 2^63 are not expected.
  void u64(int v) {
    for (var shift = 56; shift >= 0; shift -= 8) {
      _b.addByte((v >> shift) & 0xff);
    }
  }

  void bytes(List<int> v) => _b.add(v);

  Uint8List toBytes() => _b.toBytes();

  int get length => _b.length;
}

/// Bounds-checked big-endian reader. Every accessor throws [FormatException]
/// instead of reading past the end, so malformed network input cannot crash
/// the caller with a [RangeError].
class ByteReader {
  ByteReader(this._data);

  final Uint8List _data;
  int _pos = 0;

  int get position => _pos;
  int get remaining => _data.length - _pos;

  void _need(int n) {
    if (n < 0 || remaining < n) {
      throw const FormatException('Truncated data');
    }
  }

  int u8() {
    _need(1);
    return _data[_pos++];
  }

  int u16() {
    _need(2);
    final v = (_data[_pos] << 8) | _data[_pos + 1];
    _pos += 2;
    return v;
  }

  int u32() {
    _need(4);
    final v = (_data[_pos] << 24) |
        (_data[_pos + 1] << 16) |
        (_data[_pos + 2] << 8) |
        _data[_pos + 3];
    _pos += 4;
    return v;
  }

  int u64() {
    _need(8);
    var v = 0;
    for (var i = 0; i < 8; i++) {
      v = (v << 8) | _data[_pos + i];
    }
    _pos += 8;
    if (v < 0) {
      throw const FormatException('64-bit value out of range');
    }
    return v;
  }

  Uint8List bytes(int n) {
    _need(n);
    final out = Uint8List.sublistView(_data, _pos, _pos + n);
    _pos += n;
    return Uint8List.fromList(out);
  }

  Uint8List rest() => bytes(remaining);
}
