import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_mesh_chat/device/keep_alive.dart';

/// The Dart half of "Keep the mesh running in the background", against a
/// stand-in for the Android method channel: a start counts only once the service
/// itself says it runs, and the battery questions are passed through.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('damataqe/keep_alive');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  const keep = PluginKeepAlive(
    android: true,
    confirmWithin: Duration(milliseconds: 200),
    confirmEvery: Duration(milliseconds: 5),
  );

  final calls = <MethodCall>[];

  void answer(Object? Function(MethodCall call) reply) {
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return reply(call);
    });
  }

  setUp(calls.clear);
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('a start counts once the service says it became a foreground service', () async {
    var asked = 0;
    answer((call) => switch (call.method) {
          'start' => true,
          'isRunning' => ++asked >= 3,
          _ => null,
        });
    expect(await keep.start(), isTrue);
    expect(asked, 3, reason: 'it waited for the service, not only for Android accepting');
  });

  test('a request Android accepted but the service then refused counts as refused', () async {
    answer((call) => switch (call.method) {
          'start' => true,
          'isRunning' => false,
          _ => null,
        });
    expect(await keep.start(), isFalse);
  });

  test('a refusal at once is a refusal', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'start') throw PlatformException(code: 'start_failed');
      return true;
    });
    expect(await keep.start(), isFalse);
  });

  test('the words of the notification reach the service', () async {
    answer((call) => true);
    await keep.start(
      texts: const KeepAliveTexts(title: 't', text: 'x', channelName: 'c', channelDescription: 'd'),
    );
    expect(calls.first.method, 'start');
    expect(calls.first.arguments,
        {'title': 't', 'text': 'x', 'channelName': 'c', 'channelDescription': 'd'});
  });

  test('battery: says what the phone says, and nothing when it would not say', () async {
    answer((call) => switch (call.method) {
          'batteryRestricted' => true,
          'openBatterySettings' => true,
          _ => null,
        });
    expect(await keep.batteryRestricted(), isTrue);
    expect(await keep.openBatterySettings(), isTrue);

    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'battery_unknown');
    });
    expect(await keep.batteryRestricted(), isNull);
    expect(await keep.openBatterySettings(), isFalse);
  });

  test('a phone that is not Android is asked nothing', () async {
    answer((call) => true);
    const notAndroid = PluginKeepAlive(android: false);
    expect(notAndroid.supported, isFalse);
    expect(await notAndroid.start(), isFalse);
    expect(await notAndroid.batteryRestricted(), isNull);
    expect(await notAndroid.openBatterySettings(), isFalse);
    expect(calls, isEmpty);
  });
}
