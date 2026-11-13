import 'package:flutter_test/flutter_test.dart';
import 'package:offline_mesh_chat/device/voice.dart';
import 'package:offline_mesh_chat/protocol/protocol_constants.dart';

/// A voice recording ends before its file outgrows one voice message, whatever
/// the phone's encoder does with its bitrate.
void main() {
  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 40));

  test('the limit leaves room for the end of the file under the 64 KB cap', () {
    final guard = VoiceSizeGuard(currentBytes: () async => 0, onLimit: () {});
    expect(guard.maxBytes, Protocol.maxMediaBytes - VoiceSizeGuard.reserveBytes);
    // Thirty seconds at the planned 16 kbit/s do not reach it: a normal phone is
    // stopped by the time limit, as before.
    expect(16000 * 30 ~/ 8, lessThan(guard.maxBytes));
  });

  test('a file that grows too fast ends the recording, once', () async {
    var size = 0;
    var fired = 0;
    final guard = VoiceSizeGuard(
      currentBytes: () async => size,
      onLimit: () => fired++,
      maxBytes: 1000,
      every: const Duration(milliseconds: 2),
    )..start();
    size = 500;
    await settle();
    expect(fired, 0);
    size = 1000;
    await settle();
    expect(fired, 1);
    size = 5000;
    await settle();
    expect(fired, 1, reason: 'it fires once');
    expect(guard.fired, isTrue);
  });

  test('a file that is not there yet is not an error, and a stopped guard says nothing', () async {
    var fired = 0;
    var exists = false;
    final guard = VoiceSizeGuard(
      currentBytes: () async => exists ? 2000 : throw StateError('no file'),
      onLimit: () => fired++,
      maxBytes: 1000,
      every: const Duration(milliseconds: 2),
    )..start();
    await settle();
    expect(fired, 0);
    guard.stop();
    exists = true;
    await settle();
    expect(fired, 0);
  });
}
