import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:offline_mesh_chat/device/device_io.dart';
import 'package:offline_mesh_chat/protocol/protocol_constants.dart';

import '../support/fake_device.dart';

/// A photograph-like test picture: smooth gradients plus noise, so it neither
/// compresses to nothing nor is incompressible.
Uint8List _photo(int w, int h, {int seed = 1, bool alpha = false}) {
  final rng = Random(seed);
  final image = img.Image(width: w, height: h, numChannels: alpha ? 4 : 3);
  for (final p in image) {
    final x = p.x / w, y = p.y / h;
    p
      ..r = (x * 255).round().clamp(0, 255)
      ..g = (y * 255).round().clamp(0, 255)
      ..b = ((x + y) * 120 + rng.nextInt(40)).round().clamp(0, 255);
    if (alpha) p.a = (p.x % 20 < 10) ? 255 : 0;
  }
  return Uint8List.fromList(img.encodeJpg(image, quality: 92));
}

void main() {
  group('ImageCompressor', () {
    const compressor = ImageCompressor();

    test('shrinks a large photo to the target size and a mesh-friendly resolution', () async {
      final out = await compressor.compress(_photo(1600, 1200), inIsolate: false);
      expect(out.bytes.length, lessThanOrEqualTo(40 * 1024));
      expect(out.bytes.length, lessThan(Protocol.maxMediaBytes));
      expect(max(out.width, out.height), lessThanOrEqualTo(640));
      expect(out.width / out.height, closeTo(4 / 3, 0.02), reason: 'the aspect ratio is kept');
      final decoded = img.decodeJpg(out.bytes)!;
      expect(decoded.width, out.width);
      expect(decoded.height, out.height);
    });

    test('keeps portrait pictures portrait', () async {
      final out = await compressor.compress(_photo(900, 1500, seed: 2), inIsolate: false);
      expect(out.height, greaterThan(out.width));
      expect(out.height, lessThanOrEqualTo(640));
    });

    test('a small picture is not enlarged', () async {
      final out = await compressor.compress(_photo(200, 150), inIsolate: false);
      expect(out.width, 200);
      expect(out.height, 150);
    });

    test('transparent PNGs become JPEGs on white', () async {
      final image = img.Image(width: 120, height: 120, numChannels: 4);
      img.fill(image, color: img.ColorRgba8(255, 0, 0, 0)); // fully transparent
      final out = await compressor.compress(Uint8List.fromList(img.encodePng(image)), inIsolate: false);
      final px = img.decodeJpg(out.bytes)!.getPixel(60, 60);
      expect(px.r, greaterThan(240));
      expect(px.g, greaterThan(240));
      expect(px.b, greaterThan(240));
    });

    test('something that is not a picture is refused with a clear message', () async {
      await expectLater(
        compressor.compress(Uint8List.fromList(List<int>.filled(500, 7)), inIsolate: false),
        throwsA(isA<ImageCompressionException>()
            .having((e) => e.message, 'message', contains('not a picture'))),
      );
    });

    test('an impossible budget is refused rather than sending something too big', () async {
      const tiny = ImageCompressor(targetBytes: 10, maxBytes: 50, sides: [256], qualities: [30]);
      await expectLater(
        tiny.compress(_photo(800, 600, seed: 3), inIsolate: false),
        throwsA(isA<ImageCompressionException>()),
      );
    });

    test('runs in a background isolate with the same result', () async {
      final input = _photo(1000, 800, seed: 4);
      final inline = compressor.compressSync(input);
      final isolated = await compressor.compress(input);
      expect(isolated.bytes, inline.bytes);
    });

    test('the output fits the protocol in every case tried', () async {
      for (final size in [(640, 480), (3000, 2000), (1000, 1000), (50, 2000)]) {
        final out = await compressor.compress(_photo(size.$1, size.$2, seed: size.$1), inIsolate: false);
        expect(out.bytes.length, lessThanOrEqualTo(Protocol.maxMediaBytes), reason: '$size');
        expect(out.width, lessThanOrEqualTo(8192));
      }
    });
  });

  group('voice helpers', () {
    test('decibels map to a 0..1 meter', () {
      expect(levelFromDecibels(0), 1);
      expect(levelFromDecibels(-45), 0);
      expect(levelFromDecibels(-90), 0);
      expect(levelFromDecibels(5), 1);
      expect(levelFromDecibels(-22.5), closeTo(0.5, 0.001));
    });

    test('a waveform is at most 48 bars of 0..255, peaks preserved', () {
      expect(waveformFromLevels(const []), isEmpty);
      expect(waveformFromLevels([0.0, 1.0]), [0, 255]);
      final long = [for (var i = 0; i < 300; i++) i == 150 ? 1.0 : 0.1];
      final bars = waveformFromLevels(long);
      expect(bars.length, Protocol.maxWaveformSamples);
      expect(bars.reduce(max), 255, reason: 'the loudest moment is still drawn');
      expect(bars.every((b) => b >= 0 && b <= 255), isTrue);
      expect(waveformFromLevels([for (var i = 0; i < 10; i++) 0.5]).length, 10);
    });

    test('playback state compares by value', () {
      expect(const PlaybackState(playingId: 'a', playing: true),
          const PlaybackState(playingId: 'a', playing: true));
      expect(const PlaybackState(playingId: 'a', playing: true).isPlaying('a'), isTrue);
      expect(const PlaybackState(playingId: 'a').isPlaying('a'), isFalse);
      expect(const PlaybackState(playingId: 'a').isCurrent('a'), isTrue);
      expect(PlaybackState.idle.isCurrent('a'), isFalse);
    });
  });

  group('FakePermissionService (the test double used by the UI tests)', () {
    test('answers like the system: prompt once, permanent denial sticks', () async {
      final p = FakePermissionService(answerWhenAsked: PermissionOutcome.permanentlyDenied);
      expect(await p.status(AppPermission.microphone), PermissionOutcome.denied);
      expect(await p.request(AppPermission.microphone), PermissionOutcome.permanentlyDenied);
      p.answerWhenAsked = PermissionOutcome.granted;
      expect(await p.request(AppPermission.microphone), PermissionOutcome.permanentlyDenied);
      expect(await p.request(AppPermission.camera), PermissionOutcome.granted);
      expect(p.requested, [AppPermission.microphone, AppPermission.microphone, AppPermission.camera]);
    });
  });
}
