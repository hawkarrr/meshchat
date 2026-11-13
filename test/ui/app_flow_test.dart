import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_mesh_chat/core/app_info.dart';
import 'package:offline_mesh_chat/screens/home_screen.dart';
import 'package:offline_mesh_chat/screens/onboarding_screen.dart';
import 'package:offline_mesh_chat/screens/room_screen.dart' show RoomChat;

import '../support/ui_harness.dart';

void main() {
  testWidgets('first run explains the app, then starts Bluetooth only when asked', (tester) async {
    final h = UiHarness(tester)..screen();
    final alice = await h.node('Alice');

    await h.show(alice, landing: true);
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.text(AppInfo.name), findsWidgets);
    expect(find.textContaining('No internet needed'), findsOneWidget);
    expect(find.textContaining('Bluetooth'), findsWidgets);
    expect(find.byType(HomeScreen), findsNothing);
    expect(alice.controller.networkingStarted, isFalse);
    expect(h.world.calls.where((c) => c.startsWith('Alice:')), isEmpty,
        reason: 'the explanation page must come before any Bluetooth call');
    // Nothing else is asked for until a feature needs it.
    expect(h.permissionsOf(alice).requested, isEmpty);

    // The page says which permissions will be asked, and when.
    await h.reveal(find.textContaining('Asks before it uses anything'));
    expect(find.textContaining('microphone, camera and photos only when you send'), findsOneWidget);
    expect(find.textContaining('Experimental'), findsOneWidget, reason: 'the honest note stays');

    await h.reveal(find.byKey(const Key('onboarding-name')));
    await tester.enterText(find.byKey(const Key('onboarding-name')), 'Alicia');
    await h.tap(find.byKey(const Key('onboarding-start')));
    await h.until(() => find.byType(HomeScreen).evaluate().isNotEmpty,
        reason: 'the home screen should replace the first-run page');
    expect(find.byType(RoomChat), findsOneWidget, reason: 'and it opens on the public room');

    expect(alice.controller.onboardingDone, isTrue);
    expect(alice.controller.nickname, 'Alicia');
    expect(h.permissionsOf(alice).requested, isEmpty,
        reason: 'microphone, camera and photos are never requested at start-up');
    await h.until(() => alice.controller.networkingStarted);
    await h.dispose();
  });
}
