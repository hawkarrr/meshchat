import 'package:offline_mesh_chat/core/clock.dart';

/// A clock tests can move by hand.
class FakeClock implements Clock {
  FakeClock([this._now = 1700000000000]);

  int _now;

  @override
  int get nowMs => _now;

  void advance(Duration d) => _now += d.inMilliseconds;

  void set(int ms) => _now = ms;
}
