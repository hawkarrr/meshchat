import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_mesh_chat/l10n/l10n.dart';
import 'package:offline_mesh_chat/theme/app_theme.dart';
import 'package:offline_mesh_chat/widgets/empty_state.dart';
import 'package:offline_mesh_chat/widgets/skeleton.dart';

/// The three states a screen is in before it has something to show: still reading
/// (a skeleton), nothing there (the ghost), and could not read (an error with a button).
Widget _app(Widget child, {AppLanguage language = AppLanguage.en, bool reduceMotion = false}) {
  return MaterialApp(
    theme: buildAppTheme(language: language),
    locale: language.locale,
    supportedLocales: AppLanguage.supportedLocales,
    localizationsDelegates: AppLanguage.delegates,
    builder: (context, page) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
      child: page!,
    ),
    home: Scaffold(body: child),
  );
}

void main() {
  group('the skeleton', () {
    testWidgets('of a chat says it is loading, and breathes', (tester) async {
      await tester.pumpWidget(_app(const ChatSkeleton()));
      expect(find.byKey(const Key('chat-skeleton')), findsOneWidget);
      expect(find.bySemanticsLabel('Loading…'), findsOneWidget);

      double opacity() => tester.widget<FadeTransition>(find.descendant(
              of: find.byType(SkeletonPulse), matching: find.byType(FadeTransition))).opacity.value;
      final first = opacity();
      await tester.pump(const Duration(milliseconds: 500));
      expect(opacity(), isNot(first), reason: 'it moves while it waits');
      expect(tester.takeException(), isNull);
    });

    testWidgets('holds still when the system asks for less motion', (tester) async {
      await tester.pumpWidget(_app(const ChatSkeleton(), reduceMotion: true));
      final before = tester
          .widget<FadeTransition>(find.descendant(of: find.byType(SkeletonPulse), matching: find.byType(FadeTransition)))
          .opacity
          .value;
      await tester.pump(const Duration(milliseconds: 600));
      final after = tester
          .widget<FadeTransition>(find.descendant(of: find.byType(SkeletonPulse), matching: find.byType(FadeTransition)))
          .opacity
          .value;
      expect(after, before);
      expect(tester.hasRunningAnimations, isFalse, reason: 'nothing keeps the frames coming');
    });

    testWidgets('of a list has rows of a picture and two lines, and fits the smallest phone',
        (tester) async {
      tester.view
        ..physicalSize = const Size(320, 568)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_app(const ListSkeleton(rows: 6)));
      expect(find.byKey(const Key('list-skeleton')), findsOneWidget);
      expect(find.byType(SkeletonBox), findsNWidgets(18), reason: 'a circle and two lines, six times');
      expect(tester.takeException(), isNull);
    });
  });

  group('the error state', () {
    testWidgets('says what happened and tries again when asked', (tester) async {
      var tries = 0;
      await tester.pumpWidget(_app(ErrorState(
        title: 'Could not load the messages',
        message: 'Nothing was deleted.',
        onRetry: () => tries++,
      )));
      expect(find.text('Could not load the messages'), findsOneWidget);
      expect(find.text('Nothing was deleted.'), findsOneWidget);
      await tester.tap(find.byKey(const Key('retry')));
      expect(tries, 1);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('reads right to left in Kurdish, with the button in Kurdish', (tester) async {
      final l = AppLanguage.ckb.strings;
      await tester.pumpWidget(_app(
          ErrorState(title: l.feedErrorTitle, message: l.feedErrorBody, onRetry: () {}),
          language: AppLanguage.ckb));
      expect(find.text(l.feedErrorTitle), findsOneWidget);
      expect(find.text(l.commonTryAgain), findsOneWidget);
      expect(Directionality.of(tester.element(find.byType(ErrorState))), TextDirection.rtl);
      expect(tester.takeException(), isNull);
    });
  });
}
