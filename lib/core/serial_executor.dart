import 'dart:async';

/// Runs async tasks strictly one after another.
///
/// Used where a check-then-act sequence must be atomic with respect to other
/// tasks (for example "have I seen this packet? if not, mark it and deliver
/// it"): two neighbours can hand us the same packet at the same moment, and
/// without serialisation both would pass the check.
class SerialExecutor {
  Future<void> _tail = Future<void>.value();
  int _pending = 0;

  /// Tasks queued or running right now.
  int get pending => _pending;

  /// Completes when everything submitted so far has finished.
  Future<void> get idle => _tail;

  /// Runs [task] after all earlier tasks. The returned future carries the
  /// task's result or error; a failing task never blocks later ones.
  Future<T> run<T>(Future<T> Function() task) {
    final completer = Completer<T>();
    _pending++;
    _tail = _tail.then((_) async {
      try {
        completer.complete(await task());
      } catch (e, s) {
        completer.completeError(e, s);
      } finally {
        _pending--;
      }
    });
    return completer.future;
  }
}
