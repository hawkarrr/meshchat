/// Source of wall-clock time. Injected everywhere time matters so that
/// expiry, retry back-off and rate limiting can be tested deterministically.
abstract interface class Clock {
  /// Milliseconds since the Unix epoch.
  int get nowMs;
}

class SystemClock implements Clock {
  const SystemClock();

  @override
  int get nowMs => DateTime.now().millisecondsSinceEpoch;
}
