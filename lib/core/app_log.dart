import 'package:flutter/foundation.dart';

enum LogLevel { debug, info, warning, error }

class LogEntry {
  const LogEntry(this.atMs, this.level, this.tag, this.message);

  final int atMs;
  final LogLevel level;
  final String tag;
  final String message;

  @override
  String toString() {
    final t = DateTime.fromMillisecondsSinceEpoch(atMs);
    String two(int v) => v.toString().padLeft(2, '0');
    final ms = t.millisecond.toString().padLeft(3, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}.$ms '
        '${level.name.toUpperCase().padRight(5)} [$tag] $message';
  }
}

/// In-memory ring buffer log shown on the BLE diagnostics screen.
///
/// Privacy: the log lives in RAM only (never written to disk or sent
/// anywhere), and callers must never log private keys, shared secrets or
/// message plaintext.
class AppLog extends ChangeNotifier {
  AppLog({this.capacity = 500, bool? echo}) : echo = echo ?? kDebugMode;

  /// Process-wide instance used by the app. Tests construct their own.
  static final AppLog instance = AppLog();

  final int capacity;

  /// Also print entries to the debug console (on by default in debug builds).
  final bool echo;
  final List<LogEntry> _entries = <LogEntry>[];

  List<LogEntry> get entries => List.unmodifiable(_entries);

  void add(LogLevel level, String tag, String message) {
    final entry =
        LogEntry(DateTime.now().millisecondsSinceEpoch, level, tag, message);
    _entries.add(entry);
    if (_entries.length > capacity) {
      _entries.removeRange(0, _entries.length - capacity);
    }
    if (echo) {
      debugPrint(entry.toString());
    }
    notifyListeners();
  }

  void d(String tag, String message) => add(LogLevel.debug, tag, message);
  void i(String tag, String message) => add(LogLevel.info, tag, message);
  void w(String tag, String message) => add(LogLevel.warning, tag, message);
  void e(String tag, String message) => add(LogLevel.error, tag, message);

  void clear() {
    _entries.clear();
    notifyListeners();
  }

  String dump() => _entries.map((e) => e.toString()).join('\n');
}
