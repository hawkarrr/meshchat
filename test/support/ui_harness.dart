import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_mesh_chat/app.dart';
import 'package:offline_mesh_chat/theme/theme_controller.dart';
import 'package:offline_mesh_chat/widgets/nav_bar.dart';
import 'package:offline_mesh_chat/widgets/skeleton.dart';
import 'package:offline_mesh_chat/services/network_status_service.dart';

import 'app_harness.dart';
import 'fake_ble_world.dart';
import 'fake_device.dart';
import 'package:offline_mesh_chat/l10n/l10n.dart';

class ClipboardRecorder {
  String? text;
}

/// Bridges the widget tester's fake clock and the real asynchronous work
/// underneath the app (SQLite, the simulated radios, real timers).
///
/// Widgets are pumped in the tester's fake-async zone; database and radio
/// events complete on the real event loop. [settle] lets both make progress,
/// and [until] repeats that until something on screen (or in the controller)
/// is true.
class UiHarness {
  UiHarness(this.tester) : world = FakeBleWorld();

  final WidgetTester tester;
  final FakeBleWorld world;
  final List<AppNode> nodes = <AppNode>[];

  /// Phone-sized logical screen, 3x pixel density.
  void screen([double width = 360, double height = 760]) {
    tester.view
      ..physicalSize = Size(width * 3, height * 3)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<AppNode> node(String name,
      {bool onboarded = false,
      String? nickname,
      NetworkKind network = NetworkKind.none,
      AppLanguage language = AppLanguage.en,
      ThemeController? theme}) async {
    final n = (await tester.runAsync(() async {
      final created =
          await AppNode.create(world, name, network: network, language: language, theme: theme);
      if (nickname != null) await created.controller.setNickname(nickname);
      if (onboarded) await created.startUp();
      return created;
    }))!;
    nodes.add(n);
    return n;
  }

  /// Lets real async work run for [ms], then rebuilds the UI.
  ///
  /// [pumpMs] is how far the fake clock advances. The default is long enough
  /// for a page transition (Material's take up to 800 ms) to finish, so the
  /// next tap does not land on a route that is still sliding in. Flows with
  /// real timeouts (a Bluetooth probe waiting for a reply) need the fake clock
  /// to run no faster than the real one: pass a small value for those.
  Future<void> settle([int ms = 60, int pumpMs = 900]) async {
    await tester.runAsync(() => Future<void>.delayed(Duration(milliseconds: ms)));
    // One frame lets a newly pushed route start its animation (a ticker only
    // starts counting on its first frame); the pump then runs it on.
    await tester.pump();
    await tester.pump(Duration(milliseconds: pumpMs));
    await tester.pump();
  }

  /// Keeps settling until [condition] holds (checked after each round).
  Future<void> until(bool Function() condition,
      {int timeoutMs = 10000, String? reason, int pumpMs = 900}) async {
    final watch = Stopwatch()..start();
    var waited = false;
    while (!condition()) {
      if (watch.elapsedMilliseconds > timeoutMs) {
        fail('Condition not met within ${timeoutMs}ms${reason == null ? '' : ': $reason'}');
      }
      await settle(40, pumpMs);
      waited = true;
    }
    // A change in the controller reaches the widgets through its 80 ms
    // coalescing timer, so give the screen time to catch up with the state
    // that just satisfied the condition before the caller looks at it.
    if (waited) await settle(120, pumpMs);
  }

  /// Like [until], for a condition that has to read something asynchronously
  /// (the database of another phone). It alternates between checking the
  /// condition on the real event loop and pumping the screen, so timers that a
  /// tap started in the tester's fake clock keep running while it waits.
  Future<void> untilAsync(Future<bool> Function() condition,
      {int timeoutMs = 15000, String? reason, int pumpMs = 300}) async {
    final watch = Stopwatch()..start();
    while (!await real(condition)) {
      if (watch.elapsedMilliseconds > timeoutMs) {
        fail('Condition not met within ${timeoutMs}ms${reason == null ? '' : ': $reason'}');
      }
      await settle(40, pumpMs);
    }
  }

  /// Waits until nothing on screen is showing a loading spinner or a skeleton.
  Future<void> loaded({String? reason}) => until(
        () =>
            find.byType(CircularProgressIndicator).evaluate().isEmpty &&
            find.byType(SkeletonPulse).evaluate().isEmpty,
        reason: reason ?? 'the screen should finish loading',
      );

  /// Runs [body] on the real event loop (for controller calls on other phones).
  Future<T> real<T>(Future<T> Function() body) async => (await tester.runAsync(body)) as T;

  /// Opens the app on [n]'s phone.
  ///
  /// The app opens on the public room, the first place of the bar. Most flows, though,
  /// start from the list of private chats (the people who are available, the chats), so
  /// [show] goes there once the home screen is up; `landing: true` leaves the app where
  /// it opened, for the tests of that.
  Future<void> show(AppNode n, {bool landing = false}) async {
    await tester.pumpWidget(DamataqeApp(controller: n.controller));
    await settle();
    if (!landing && find.byType(AppNavBar).evaluate().isNotEmpty) await openTab('private');
  }

  /// A place of the bottom bar by its id: `public`, `private`, `groups` or `settings`.
  Future<void> openTab(String id) async {
    await tap(find.byKey(Key('nav-$id')));
    // The floating button changes with the place: the old one shrinks away, then
    // the new one grows. (On a phone frames never stop; in a test they only come
    // when asked for.)
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// One page of the settings, by the id of its row: `profile`, `language`,
  /// `notifications`, `privacy`, `chat`, `help` or `about`.
  Future<void> openSettingsPage(String page) async {
    await openTab('settings');
    await tap(find.byKey(Key('settings-$page')));
  }

  /// Scrolls the first scrollable - or [scrollable], when a screen has more than one
  /// list (the home screen keeps the lists of all its tabs) - until [finder] is
  /// built and on screen.
  Future<void> reveal(Finder finder, {Finder? scrollable}) async {
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(finder, 250,
          scrollable: scrollable ?? find.byType(Scrollable).first, maxScrolls: 60);
    }
    await tester.ensureVisible(finder);
    await tester.pump();
  }

  /// Scrolls the first scrollable back to its start (lists build lazily, so
  /// things above the viewport may not exist until then).
  Future<void> scrollToTop() async {
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 6000));
    await settle();
  }

  Future<void> tap(Finder finder, {int pumpMs = 900, Finder? scrollable}) async {
    await reveal(finder, scrollable: scrollable);
    await tester.tap(finder);
    await settle(60, pumpMs);
  }

  Future<void> tapText(String text) => tap(find.text(text).first);

  /// An item of the bottom bar of the home screen (Public, Private, Groups or Settings).
  Finder navItem(String label) => find.descendant(
        of: find.byType(AppNavBar),
        matching: find.text(label),
      );

  /// Goes to the place of the bar with this word under its icon.
  Future<void> goToTab(String label) async {
    await tap(navItem(label));
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// The fake permission service of [n].
  FakePermissionService permissionsOf(AppNode n) => n.io.permissions as FakePermissionService;

  FakeVoiceRecorder recorderOf(AppNode n) => n.io.recorder as FakeVoiceRecorder;

  FakePhotoPicker pickerOf(AppNode n) => n.io.photos as FakePhotoPicker;

  FakeNotificationSink notificationsOf(AppNode n) => n.io.notifications as FakeNotificationSink;

  FakeKeepAlive keepAliveOf(AppNode n) => n.io.keepAlive as FakeKeepAlive;

  FakeGallery galleryOf(AppNode n) => n.io.gallery as FakeGallery;

  FakeSharer sharerOf(AppNode n) => n.io.sharer as FakeSharer;

  FakeVoicePlayer playerOf(AppNode n) => n.io.player as FakeVoicePlayer;

  /// Records what is copied to the clipboard.
  ClipboardRecorder recordClipboard() {
    final recorder = ClipboardRecorder();
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform,
        (call) async {
      if (call.method == 'Clipboard.setData') {
        recorder.text = (call.arguments as Map<Object?, Object?>)['text'] as String?;
      }
      return null;
    });
    addTearDown(() =>
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    return recorder;
  }

  bool _disposed = false;

  /// Call as the last statement of a test: timers started from a tap live in
  /// the tester's fake-async zone and must be gone before the framework's
  /// end-of-test check (which runs before `addTearDown` callbacks).
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await tester.pumpWidget(const SizedBox.shrink());
    // Shut the phones down from this (fake-async) zone while pumping both
    // clocks. Services that were (re)started by a tap have their timers in this
    // zone; awaiting them from runAsync would wait on a clock that cannot
    // advance there.
    var finished = false;
    Future.wait(<Future<void>>[for (final n in nodes) n.dispose()])
        .whenComplete(() => finished = true);
    await until(() => finished,
        timeoutMs: 20000, pumpMs: 50, reason: 'the phones should shut down');
    await settle(50);
    await tester.pump(const Duration(seconds: 1));
  }
}
