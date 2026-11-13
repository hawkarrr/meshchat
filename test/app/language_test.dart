import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:offline_mesh_chat/crypto/key_store.dart';
import 'package:offline_mesh_chat/l10n/l10n.dart';
import 'package:offline_mesh_chat/models/conversation.dart';
import 'package:offline_mesh_chat/services/message_service.dart';

import '../support/app_harness.dart';
import '../support/fake_ble_world.dart';
import '../support/radio_harness.dart';
import '../support/test_database.dart';

/// The language of the whole app: Kurdish until the person picks another, kept
/// across restarts, and used by everything that is said outside the screens -
/// errors, the first nickname, the summaries in the chat list.
void main() {
  late FakeBleWorld world;
  final nodes = <AppNode>[];
  final tempDirs = <Directory>[];

  setUp(() {
    world = FakeBleWorld();
    nodes.clear();
    tempDirs.clear();
  });

  tearDown(() async {
    for (final n in nodes) {
      await n.dispose();
    }
    for (final d in tempDirs) {
      try {
        d.deleteSync(recursive: true);
      } on FileSystemException {
        // Best effort: it is a temp directory.
      }
    }
  });

  Future<AppNode> phone(String name, {AppLanguage language = AppLanguage.main, KeyStore? keys}) async {
    final n = await AppNode.create(world, name, language: language, keys: keys);
    nodes.add(n);
    return n;
  }

  test('a new install is in Kurdish, and its first name is Kurdish too', () async {
    final a = await phone('Alice');
    expect(a.controller.language, AppLanguage.ckb);
    expect(a.controller.l10n.navPrivate, 'تایبەت');
    expect(a.controller.nickname, matches(RegExp(r'^مۆبایل [0-9A-F]{4}$')));
  });

  test('English is only used when it was chosen', () async {
    final a = await phone('Alice', language: AppLanguage.en);
    expect(a.controller.l10n.navPrivate, 'Private');
    expect(a.controller.nickname, matches(RegExp(r'^Phone [0-9A-F]{4}$')));
  });

  test('switching the language changes the words at once and tells the listeners', () async {
    final a = await phone('Alice');
    var told = 0;
    a.controller.addListener(() => told++);
    await a.controller.setLanguage(AppLanguage.ar);
    expect(a.controller.language, AppLanguage.ar);
    expect(a.controller.l10n.navPrivate, 'خاصة');
    expect(told, greaterThan(0));
    final before = told;
    await a.controller.setLanguage(AppLanguage.ar);
    expect(told, before, reason: 'choosing the language that is already on changes nothing');
    await a.controller.setLanguage(AppLanguage.en);
    expect(a.controller.l10n.navPrivate, 'Private');
  });

  test('the choice survives restarting the app, whatever the default is', () async {
    final dir = makeTempDir('mesh_language_');
    tempDirs.add(dir);
    final dbPath = '${dir.path}${Platform.pathSeparator}app.db';
    final keys = MemoryKeyStore();

    final first = await AppNode.create(world, 'Alice',
        keys: keys, db: await openFileDatabase(dbPath), language: AppLanguage.main);
    await first.controller.setLanguage(AppLanguage.ar);
    await first.dispose();

    final second = await AppNode.create(world, 'Alice',
        keys: keys, db: await openFileDatabase(dbPath), language: AppLanguage.en);
    nodes.add(second);
    expect(second.controller.language, AppLanguage.ar,
        reason: 'a stored choice wins over the default');
  });

  test('"delete all local data" keeps the language the person reads, also after a restart',
      () async {
    final dir = makeTempDir('mesh_language_wipe_');
    tempDirs.add(dir);
    final dbPath = '${dir.path}${Platform.pathSeparator}app.db';
    final keys = MemoryKeyStore();

    final first = await AppNode.create(world, 'Alice',
        keys: keys, db: await openFileDatabase(dbPath), language: AppLanguage.main);
    await first.controller.setLanguage(AppLanguage.en);
    await first.controller.clearAllData();
    expect(first.controller.language, AppLanguage.en);
    await first.dispose();

    final second = await AppNode.create(world, 'Alice',
        keys: keys, db: await openFileDatabase(dbPath), language: AppLanguage.main);
    nodes.add(second);
    expect(second.controller.language, AppLanguage.en,
        reason: 'the wipe must not quietly switch the app back to Kurdish');
  });

  test('an unknown stored language falls back to the default', () async {
    final dir = makeTempDir('mesh_language_bad_');
    tempDirs.add(dir);
    final dbPath = '${dir.path}${Platform.pathSeparator}app.db';
    final keys = MemoryKeyStore();
    final first = await AppNode.create(world, 'Alice',
        keys: keys, db: await openFileDatabase(dbPath), language: AppLanguage.main);
    await first.controller.repo.setSetting('language', 'klingon');
    await first.dispose();
    final second = await AppNode.create(world, 'Alice',
        keys: keys, db: await openFileDatabase(dbPath), language: AppLanguage.main);
    nodes.add(second);
    expect(second.controller.language, AppLanguage.ckb);
  });

  group('what the services say follows the language', () {
    Future<String> sendToStranger(AppNode a) async {
      try {
        await a.controller.sendDirect('ab' * 32, 'hi');
      } on MessageError catch (e) {
        return e.message;
      }
      fail('a message to somebody unknown must be refused');
    }

    test('an error is worded in the language on screen when it happens', () async {
      final a = await phone('Alice');
      expect(await sendToStranger(a), 'ئەم کەسە هێشتا نەناسراوە.');
      await a.controller.setLanguage(AppLanguage.ar);
      expect(await sendToStranger(a), 'جهة الاتصال هذه غير معروفة بعد.');
      await a.controller.setLanguage(AppLanguage.en);
      expect(await sendToStranger(a), 'That contact is not known yet.');
    });

    test('the checks on a message are worded in each language', () {
      Object? refused(AppLanguage language, String text) {
        try {
          validateMessageText(text, language.strings);
        } on MessageError catch (e) {
          return e;
        }
        return null;
      }

      expect((refused(AppLanguage.en, '  ') as MessageError).message, 'Type a message first.');
      expect((refused(AppLanguage.ckb, '  ') as MessageError).message, 'سەرەتا نامەیەک بنووسە.');
      expect((refused(AppLanguage.ar, '  ') as MessageError).message, 'اكتب رسالة أولاً.');
      final long = 'x' * 2000;
      expect((refused(AppLanguage.en, long) as MessageError).message, contains('is too long'));
      expect((refused(AppLanguage.ar, long) as MessageError).message, contains('طويلة جدًا'));
    });

    test('the chat list reads the same stored summary in the language chosen', () async {
      final a = await phone('Alice', language: AppLanguage.en);
      final b = await phone('Bob', language: AppLanguage.en);
      await a.startUp();
      await b.startUp();
      await waitForDirect(a, b);
      await eventually(() => a.viewOf(b)?.peer.canReceiveEncrypted ?? false);
      await a.controller.sendDirect(b.id, 'hello Bob');
      final dm = Conversation.directId(a.id);
      await eventually(() => b.controller.conversations.any((c) => c.id == dm));
      final conv = b.controller.conversations.firstWhere((c) => c.id == dm);
      expect(conv.previewIn(b.controller.l10n), 'hello Bob');

      // A stored summary is structure, so the same row can be read in any language.
      expect(conv.lastMessagePreview, startsWith('{"k":"text"'));
    });
  });
}
