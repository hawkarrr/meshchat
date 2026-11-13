import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_mesh_chat/l10n/l10n.dart';
import 'package:offline_mesh_chat/models/conversation.dart';
import 'package:offline_mesh_chat/screens/home_screen.dart';
import 'package:offline_mesh_chat/theme/app_theme.dart';
import 'package:offline_mesh_chat/widgets/nav_bar.dart';

import '../support/ui_harness.dart';

/// The places of the bar, in the order of the bar: Public first.
const _items = <(String id, String label, IconData outlined, IconData filled)>[
  ('public', 'Public', Icons.public_outlined, Icons.public_rounded),
  ('private', 'Private', Icons.lock_outline_rounded, Icons.lock_rounded),
  ('groups', 'Groups', Icons.groups_outlined, Icons.groups_rounded),
  ('settings', 'Settings', Icons.settings_outlined, Icons.settings_rounded),
];

Finder _item(String id) => find.byKey(Key('nav-$id'));

Finder _icon(String id, IconData icon) =>
    find.descendant(of: _item(id), matching: find.byIcon(icon));

/// The highlight behind the current item: a soft blue pill the width of an item.
Finder get _pill => find.byWidgetPredicate(
      (w) => w is Container && w.constraints == BoxConstraints.tightFor(width: 74, height: 56),
      description: 'the highlight pill',
    );

double _pillX(WidgetTester tester) => tester.getCenter(_pill).dx;

double _iconX(WidgetTester tester, String id) => tester.getCenter(_item(id)).dx;

Future<void> _openHome(UiHarness h, {String name = 'Alice', AppLanguage? language}) async {
  final alice = await h.node(name,
      onboarded: true, nickname: name, language: language ?? AppLanguage.en);
  await h.show(alice, landing: true);
}

void main() {
  group('the bottom bar', () {
    testWidgets('has the four places, each with its own icon and word, Public first and current',
        (tester) async {
      final h = UiHarness(tester)..screen();
      await _openHome(h);

      expect(find.byType(AppNavBar), findsOneWidget);
      for (final (id, label, _, _) in _items) {
        expect(_item(id), findsOneWidget, reason: id);
        expect(find.descendant(of: _item(id), matching: find.text(label)), findsOneWidget);
      }
      // Public is current: its icon is filled, the others are outlines.
      expect(_icon('public', Icons.public_rounded), findsOneWidget);
      expect(_icon('private', Icons.lock_outline_rounded), findsOneWidget);
      expect(_icon('groups', Icons.groups_outlined), findsOneWidget);
      expect(_icon('settings', Icons.settings_outlined), findsOneWidget);

      // In English the first place is at the left, then to the right in this order.
      final xs = [for (final (id, _, _, _) in _items) _iconX(tester, id)];
      expect(xs, orderedEquals([...xs]..sort()), reason: 'public, private, groups, settings');

      expect(tester.takeException(), isNull);
      await h.dispose();
    });

    testWidgets('floats above the page as a rounded pill, inside the safe area', (tester) async {
      final h = UiHarness(tester)..screen();
      await _openHome(h);

      final bar = tester.getRect(find.byType(AppNavBar));
      expect(bar.bottom, closeTo(760, 0.5), reason: 'at the bottom of the screen');
      expect(bar.width, 360);
      final pill = tester.getRect(find.byKey(const Key('nav-bar-items')));
      expect(pill.left, 16, reason: 'clear of the left edge');
      expect(pill.right, 344, reason: 'and of the right edge');
      expect(pill.height, AppNavBar.height);
      expect(760 - pill.bottom, greaterThanOrEqualTo(8), reason: 'it does not touch the bottom edge');

      final box = tester.widget<DecoratedBox>(find
          .ancestor(of: find.byKey(const Key('nav-bar-items')), matching: find.byType(DecoratedBox))
          .first);
      final decoration = box.decoration as BoxDecoration;
      expect(decoration.color, AppPalette.dark.surface);
      expect(decoration.borderRadius, BorderRadius.circular(AppNavBar.height / 2),
          reason: 'fully rounded ends');
      expect(decoration.gradient, isNull, reason: 'no gradient on the bar');
      expect(tester.takeException(), isNull);
      await h.dispose();
    });

    testWidgets('every item is a comfortable target, evenly spread', (tester) async {
      final h = UiHarness(tester)..screen();
      await _openHome(h);

      final rects = [for (final (id, _, _, _) in _items) tester.getRect(_item(id))];
      for (final r in rects) {
        expect(r.width, greaterThanOrEqualTo(44));
        expect(r.height, greaterThanOrEqualTo(44));
        expect(r.width, closeTo(82, 0.5), reason: 'four equal parts of the 328 points of the pill');
      }
      for (var i = 1; i < rects.length; i++) {
        expect(rects[i].left, closeTo(rects[i - 1].right, 0.5));
      }
      expect(tester.takeException(), isNull);
      await h.dispose();
    });

    testWidgets('in Kurdish the first place, Public, is the rightmost', (tester) async {
      final h = UiHarness(tester)..screen();
      await _openHome(h, language: AppLanguage.ckb);

      final xs = [for (final (id, _, _, _) in _items) _iconX(tester, id)];
      expect(xs, orderedEquals([...xs]..sort((a, b) => b.compareTo(a))),
          reason: 'public is at the right, settings at the left');
      expect(xs.first, greaterThan(300));
      expect(_pillX(tester), closeTo(xs.first, 0.5), reason: 'the highlight is under Public');
      expect(tester.takeException(), isNull);
      await h.dispose();
    });

    testWidgets('tapping an item changes the page at once, fills its icon, and the header follows',
        (tester) async {
      final h = UiHarness(tester)..screen();
      await _openHome(h);
      // Public: the room, with its own header and its composer; no list header.
      expect(find.byKey(const Key('room-label')), findsOneWidget);
      expect(find.byKey(const Key('composer-field')), findsOneWidget);
      expect(find.byKey(const Key('search-toggle')), findsNothing);
      for (final k in ['fab-private', 'fab-groups']) {
        expect(find.byKey(Key(k)), findsNothing, reason: k);
      }

      await h.tap(_item('private'));
      expect(_icon('private', Icons.lock_rounded), findsOneWidget);
      expect(_icon('public', Icons.public_outlined), findsOneWidget);
      expect(find.text('Private chats'), findsOneWidget, reason: 'the header of the list');
      expect(find.byKey(const Key('search-toggle')), findsOneWidget);
      expect(find.byKey(const Key('fab-private')), findsOneWidget);

      await h.tap(_item('groups'));
      expect(_icon('groups', Icons.groups_rounded), findsOneWidget);
      expect(find.text('No groups yet'), findsOneWidget);
      expect(find.byKey(const Key('fab-groups')), findsOneWidget);

      await h.tap(_item('settings'));
      expect(_icon('settings', Icons.settings_rounded), findsOneWidget);
      expect(_icon('groups', Icons.groups_outlined), findsOneWidget);
      expect(find.byKey(const Key('settings-language')), findsOneWidget, reason: 'the menu itself');
      // Settings has no search and no People button, and no floating button.
      expect(find.byKey(const Key('search-toggle')), findsNothing);
      expect(find.byKey(const Key('open-people')), findsNothing);
      for (final k in ['fab-private', 'fab-groups']) {
        expect(find.byKey(Key(k)), findsNothing, reason: k);
      }
      expect(find.descendant(of: find.byType(HomeScreen), matching: find.text('Settings')),
          findsWidgets);

      await h.tap(_item('public'));
      expect(_icon('public', Icons.public_rounded), findsOneWidget);
      expect(find.text('#mesh'), findsOneWidget);

      expect(tester.takeException(), isNull);
      await h.dispose();
    });

    testWidgets('the page changes at the first frame; only the highlight takes a moment to move',
        (tester) async {
      final h = UiHarness(tester)..screen();
      await _openHome(h);
      final from = _pillX(tester);
      expect(from, closeTo(_iconX(tester, 'public'), 1), reason: 'starts under Public');

      await tester.tap(_item('groups'));
      await tester.pump();
      expect(find.text('No groups yet'), findsOneWidget, reason: 'no waiting for an animation');

      await tester.pump(const Duration(milliseconds: 60));
      final during = _pillX(tester);
      expect(during, greaterThan(from + 5), reason: 'moving');
      expect(during, lessThan(_iconX(tester, 'groups') - 5), reason: 'not there yet');

      await tester.pump(const Duration(milliseconds: 700));
      expect(_pillX(tester), closeTo(_iconX(tester, 'groups'), 0.5), reason: 'settled, no overshoot');
      expect(tester.takeException(), isNull);
      await h.dispose();
    });

    testWidgets('choosing another place while it is still moving redirects it without a jump',
        (tester) async {
      final h = UiHarness(tester)..screen();
      await _openHome(h);

      await tester.tap(_item('private'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 70));
      final before = _pillX(tester);

      await tester.tap(_item('settings'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      final after = _pillX(tester);
      expect(after, greaterThan(before - 1), reason: 'keeps going the same way, it does not snap back');
      expect(after - before, lessThan(40), reason: 'and does not jump either');

      await tester.pump(const Duration(milliseconds: 800));
      expect(_pillX(tester), closeTo(_iconX(tester, 'settings'), 0.5));
      expect(_icon('settings', Icons.settings_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);
      await h.dispose();
    });

    testWidgets('an item answers the finger the moment it touches, and lets go when it lifts',
        (tester) async {
      final h = UiHarness(tester)..screen();
      await _openHome(h);
      double scale(String id) => tester
          .widget<AnimatedScale>(find.descendant(of: _item(id), matching: find.byType(AnimatedScale)))
          .scale;
      expect(scale('groups'), 1);

      final finger = await tester.startGesture(tester.getCenter(_item('groups')));
      await tester.pump(const Duration(milliseconds: 20));
      expect(scale('groups'), lessThan(1), reason: 'shrinks on touch-down, before the tap is complete');
      expect(find.text('No groups yet'), findsNothing, reason: 'nothing has been chosen yet');

      await finger.up();
      await tester.pump(const Duration(milliseconds: 300));
      expect(scale('groups'), 1);
      expect(find.text('No groups yet'), findsOneWidget, reason: 'chosen on release');

      // Sliding the finger away cancels the press: nothing is chosen.
      final other = await tester.startGesture(tester.getCenter(_item('private')));
      await tester.pump(const Duration(milliseconds: 20));
      await other.moveBy(const Offset(0, -300));
      await other.up();
      await tester.pump(const Duration(milliseconds: 300));
      expect(_icon('private', Icons.lock_outline_rounded), findsOneWidget, reason: 'Private was not chosen');
      expect(_icon('groups', Icons.groups_rounded), findsOneWidget);
      expect(scale('private'), 1);

      expect(tester.takeException(), isNull);
      await h.dispose();
    });

    testWidgets('the icon grows a little when chosen, and no item changes size', (tester) async {
      final h = UiHarness(tester)..screen();
      await _openHome(h);
      final before = [for (final (id, _, _, _) in _items) tester.getRect(_item(id))];

      await h.tap(_item('settings'));
      final after = [for (final (id, _, _, _) in _items) tester.getRect(_item(id))];
      expect(after, before, reason: 'choosing an item moves and resizes nothing');
      final chosen = tester.getSize(find.descendant(of: _item('settings'), matching: find.byIcon(Icons.settings_rounded)));
      final other = tester.getSize(find.descendant(of: _item('groups'), matching: find.byIcon(Icons.groups_outlined)));
      expect(chosen.width, greaterThan(other.width - 0.01), reason: 'the chosen icon is a touch larger');
      expect(tester.takeException(), isNull);
      await h.dispose();
    });

    testWidgets('unread counts sit on the chat icons, the words say them aloud, and they clear when read',
        (tester) async {
      final h = UiHarness(tester)..screen();
      final alice = await h.node('Alice', onboarded: true, nickname: 'Alice');
      final bob = await h.node('Bob', onboarded: true, nickname: 'Bob');
      await h.show(alice, landing: true);
      await h.until(() => alice.directlyReaches(bob) && bob.directlyReaches(alice));
      final semantics = tester.ensureSemantics();

      await h.real(() => bob.controller.sendDirect(alice.id, 'one'));
      await h.real(() => bob.controller.sendDirect(alice.id, 'two'));
      await h.until(() => alice.controller.totalUnread == 2);
      expect(find.descendant(of: _item('private'), matching: find.text('2')), findsOneWidget);
      for (final id in ['public', 'groups', 'settings']) {
        expect(find.descendant(of: _item(id), matching: find.text('2')), findsNothing, reason: id);
      }
      expect(tester.getSemantics(_item('private')).label, 'Private, 2 unread');
      expect(tester.getSemantics(_item('groups')).label, 'Groups');
      expect(tester.getSemantics(_item('private')), matchesSemantics(
        label: 'Private, 2 unread',
        isButton: true,
        hasTapAction: true,
        hasSelectedState: true,
      ));
      expect(tester.getSemantics(_item('public')), matchesSemantics(
        label: 'Public',
        isButton: true,
        isSelected: true,
        hasTapAction: true,
        hasSelectedState: true,
      ), reason: 'Public is the current place');

      await h.tap(_item('private'));
      await h.tap(find.byKey(Key('conversation-${Conversation.directId(bob.id)}')));
      await h.until(() => alice.controller.totalUnread == 0);
      await tester.pageBack();
      await h.settle();
      expect(find.descendant(of: _item('private'), matching: find.text('2')), findsNothing);

      semantics.dispose();
      expect(tester.takeException(), isNull);
      await h.dispose();
    });

    testWidgets('Back goes to the first place before it leaves the app, and closes the search first',
        (tester) async {
      final h = UiHarness(tester)..screen();
      await _openHome(h);

      await h.tap(_item('settings'));
      expect(await tester.binding.handlePopRoute(), isTrue, reason: 'handled: not leaving yet');
      await h.settle();
      expect(_icon('public', Icons.public_rounded), findsOneWidget, reason: 'back at the first place');
      expect(find.byKey(const Key('settings-language')), findsNothing);

      // With a search open, Back closes it and stays where it is.
      await h.tap(_item('groups'));
      await h.tap(find.byKey(const Key('search-toggle')));
      expect(find.byKey(const Key('search-field')), findsOneWidget);
      expect(await tester.binding.handlePopRoute(), isTrue);
      await h.settle();
      expect(find.byKey(const Key('search-field')), findsNothing);
      expect(_icon('groups', Icons.groups_rounded), findsOneWidget, reason: 'still in Groups');

      // Opening Settings while searching closes the search.
      await h.tap(find.byKey(const Key('search-toggle')));
      await h.tap(_item('settings'));
      expect(find.byKey(const Key('search-field')), findsNothing);

      expect(tester.takeException(), isNull);
      await h.dispose();
    });

    testWidgets('the bar stays at the bottom, under the keyboard, and the room rises above it',
        (tester) async {
      final h = UiHarness(tester)..screen();
      await _openHome(h);
      final before = tester.getRect(find.byType(AppNavBar));
      final composerBefore = tester.getRect(find.byKey(const Key('composer-field')));

      addTearDown(tester.view.resetViewInsets);
      // 900 device pixels, three to a point: 300 points of keyboard.
      for (var i = 1; i <= 15; i++) {
        tester.view.viewInsets = FakeViewPadding(bottom: i * 60.0);
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(tester.getRect(find.byType(AppNavBar)), before,
          reason: 'it stays at the bottom, under the keyboard');
      final composer = tester.getRect(find.byKey(const Key('composer-field')));
      expect(composer.bottom, lessThanOrEqualTo(760 - 300 + 0.5),
          reason: 'the field is above the 300 points of keyboard');
      expect(composerBefore.bottom, greaterThan(600), reason: 'before, it sat above the bar');
      expect(tester.takeException(), isNull);
      await h.dispose();
    });
  });

  group('the bar adapts', () {
    testWidgets('with animations switched off the highlight jumps instead of moving',
        (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      final h = UiHarness(tester)..screen();
      await _openHome(h);

      await tester.tap(_item('private'));
      await tester.pump();
      expect(_pillX(tester), closeTo(_iconX(tester, 'private'), 0.5), reason: 'already there');
      expect(tester.takeException(), isNull);
      await h.dispose();
    });

    testWidgets('with high contrast the bar gets an outline', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(highContrast: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      final h = UiHarness(tester)..screen();
      await _openHome(h);

      final box = tester.widget<DecoratedBox>(find
          .ancestor(of: find.byKey(const Key('nav-bar-items')), matching: find.byType(DecoratedBox))
          .first);
      final border = (box.decoration as BoxDecoration).border! as Border;
      expect(border.top.color, AppPalette.dark.outline);
      expect(tester.takeException(), isNull);
      await h.dispose();
    });

    testWidgets('the smallest phone with very large system text keeps the bar the same size',
        (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final h = UiHarness(tester)..screen(320, 568);
      await _openHome(h);

      expect(tester.getSize(find.byKey(const Key('nav-bar-items'))).height, 64);
      for (final (id, label, _, _) in _items) {
        await h.tap(_item(id));
        expect(tester.takeException(), isNull, reason: label);
      }
      await h.dispose();
    });

    testWidgets('on a tablet the pill stays a readable size in the middle', (tester) async {
      final h = UiHarness(tester)..screen(900, 640);
      await _openHome(h);

      final items = tester.getRect(find.byKey(const Key('nav-bar-items')));
      expect(items.width, lessThanOrEqualTo(520));
      expect(items.center.dx, closeTo(450, 0.5));
      expect(tester.takeException(), isNull);
      await h.dispose();
    });

    testWidgets('a long list of unread chats shows 99+ without growing the bar', (tester) async {
      final h = UiHarness(tester)..screen();
      final alice = await h.node('Alice', onboarded: true, nickname: 'Alice');
      final bob = await h.node('Bob', onboarded: true, nickname: 'Bob');
      await h.show(alice, landing: true);
      await h.until(() => alice.directlyReaches(bob) && bob.directlyReaches(alice));
      await h.real(() async {
        for (var i = 0; i < 101; i++) {
          await bob.controller.sendDirect(alice.id, 'm$i');
        }
      });
      await h.until(() => alice.controller.totalUnread >= 100, timeoutMs: 40000);
      expect(find.descendant(of: _item('private'), matching: find.text('99+')), findsOneWidget);
      expect(tester.getSize(find.byKey(const Key('nav-bar-items'))).height, 64);
      expect(tester.takeException(), isNull);
      await h.dispose();
    });
  });
}
