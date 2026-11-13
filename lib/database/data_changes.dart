import 'dart:async';

/// Which group of tables changed; lets the UI refresh only what it shows.
enum DataChange { peers, conversations, messages, groups, rooms, media, securityEvents }

/// One broadcast stream shared by every repository, so the UI listens in a
/// single place however many tables a change touches.
class ChangeBus {
  final StreamController<DataChange> _controller = StreamController<DataChange>.broadcast();

  Stream<DataChange> get stream => _controller.stream;

  void notify(DataChange change) {
    if (!_controller.isClosed) _controller.add(change);
  }

  Future<void> dispose() => _controller.close();
}
