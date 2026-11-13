import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_mesh_chat/theme/app_theme.dart';
import 'package:offline_mesh_chat/theme/page_transitions.dart';

/// Opening and closing a page is what a person waits for most often, so it is quick: 300 ms on
/// Android instead of Flutter's 450, and the native slide on iPhone.
void main() {
  test('Android uses the app\'s transition, iPhone the native one, in both appearances', () {
    for (final brightness in Brightness.values) {
      final builders = buildAppTheme(brightness: brightness).pageTransitionsTheme.builders;
      expect(builders[TargetPlatform.android], isA<AppPageTransitionsBuilder>());
      expect(builders[TargetPlatform.iOS], isA<CupertinoPageTransitionsBuilder>(),
          reason: 'the swipe back gesture stays');
    }
  });

  test('it keeps the platform\'s motion and changes only how long it takes', () {
    const builder = AppPageTransitionsBuilder();
    expect(builder, isA<PredictiveBackPageTransitionsBuilder>());
    expect(builder.transitionDuration, kPageTransitionDuration);
    expect(builder.reverseTransitionDuration, kPageTransitionDuration);
    expect(kPageTransitionDuration, lessThan(const Duration(milliseconds: 450)));
  });

  testWidgets('a page opens and closes in 300 ms', (tester) async {
    late BuildContext context;
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: Builder(builder: (c) {
        context = c;
        return const Scaffold(body: Text('first'));
      }),
    ));

    unawaited(Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => const Scaffold(body: Text('second')),
    )));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    final route = ModalRoute.of(tester.element(find.text('second')))!;
    expect(route.transitionDuration, kPageTransitionDuration);
    expect(route.reverseTransitionDuration, kPageTransitionDuration);

    await tester.pump(kPageTransitionDuration + const Duration(milliseconds: 20));
    expect(tester.hasRunningAnimations, isFalse, reason: 'it is in place after 300 ms');
    expect(find.text('second'), findsOneWidget);

    Navigator.of(tester.element(find.text('second'))).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(kPageTransitionDuration + const Duration(milliseconds: 20));
    expect(tester.hasRunningAnimations, isFalse, reason: 'and gone after 300 ms');
    expect(find.text('second'), findsNothing);
  });
}
