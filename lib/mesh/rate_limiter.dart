import '../core/clock.dart';

class _Bucket {
  _Bucket(this.tokens, this.lastMs);

  double tokens;
  int lastMs;
}

/// Token-bucket rate limiter keyed by an arbitrary string (a neighbour id, a
/// sender id, ...). Each key may burst up to [capacity] operations and then
/// proceeds at [refillPerSecond]. This bounds both abuse and the battery a
/// chatty or hostile neighbour can make us burn.
class TokenBucketRateLimiter {
  TokenBucketRateLimiter({
    required this.capacity,
    required this.refillPerSecond,
    this._clock = const SystemClock(),
  });

  final double capacity;
  final double refillPerSecond;
  final Clock _clock;
  final Map<String, _Bucket> _buckets = <String, _Bucket>{};

  /// Takes [cost] tokens for [key]; false means "over the limit, drop it".
  bool tryAcquire(String key, {double cost = 1}) {
    final now = _clock.nowMs;
    final bucket = _buckets.putIfAbsent(key, () => _Bucket(capacity, now));
    final elapsedSeconds = (now - bucket.lastMs) / 1000.0;
    if (elapsedSeconds > 0) {
      bucket.tokens = (bucket.tokens + elapsedSeconds * refillPerSecond).clamp(0, capacity);
      bucket.lastMs = now;
    }
    if (bucket.tokens + 1e-9 < cost) return false;
    bucket.tokens -= cost;
    return true;
  }

  void forget(String key) => _buckets.remove(key);

  /// Removes buckets that have been idle (and so are full again).
  void prune({int idleMs = 300000}) {
    final now = _clock.nowMs;
    _buckets.removeWhere((_, b) => now - b.lastMs > idleMs);
  }

  int get trackedKeys => _buckets.length;
}
