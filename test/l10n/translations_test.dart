import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Locale, TextDirection;

import 'package:flutter_test/flutter_test.dart';
import 'package:offline_mesh_chat/core/app_info.dart';
import 'package:offline_mesh_chat/l10n/l10n.dart';

/// The three .arb files are the app's text. These tests keep them complete and
/// consistent, so a new English message can never reach a Kurdish or Arabic phone
/// as a gap, as the wrong alphabet, or as a sentence that lost its blanks.
Map<String, dynamic> _arb(String code) =>
    jsonDecode(File('lib/l10n/app_$code.arb').readAsStringSync()) as Map<String, dynamic>;

Map<String, String> _messages(Map<String, dynamic> arb) => {
      for (final e in arb.entries)
        if (!e.key.startsWith('@')) e.key: e.value as String,
    };

/// The names a message fills in: `{name}`, and the number of a `{n, plural, ...}`.
Set<String> _placeholders(String message) => {
      for (final m in RegExp(r'\{\s*([A-Za-z_]\w*)\s*(?=[,}])').allMatches(message)) m.group(1)!,
    };

/// Latin words that may stay as they are in a Kurdish or Arabic sentence: names,
/// units and technical terms.
const Set<String> _latinOk = {
  'Damatqe', 'Bluetooth', 'BLE', 'KB', 'MB', 'GATT', 'ID', 'SHA', 'mesh', 'E2EE', 'MTU', 'RSSI',
  'Android', 'iPhone', 'iOS', 'dBm', 'ms', 'B', 'x', 'a', 'h', 'd', 's', 'min', 'v', 'Low',
  'Energy', 'Keystore', 'Keychain', 'HPKE', 'X', 'ChaCha', 'Poly', 'Ed', 'Wi', 'Fi', 'status',
  'A', 'C', 'dB',
};

String _withoutPlaceholders(String message) => message
    .replaceAll(RegExp(r'\{\s*\w+\s*,\s*(plural|select)\s*,'), ' ')
    .replaceAll(RegExp(r'(=\d+|zero|one|two|few|many|other)(?=\{)'), ' ')
    .replaceAll(RegExp(r'\{\s*\w+\s*\}'), ' ');

void main() {
  final en = _messages(_arb('en'));
  final ckb = _messages(_arb('ckb'));
  final ar = _messages(_arb('ar'));

  group('the three languages', () {
    test('Kurdish is the main language, then Arabic, then English', () {
      expect(AppLanguage.main, AppLanguage.ckb);
      expect(AppLanguage.supportedLocales, const [Locale('ckb'), Locale('ar'), Locale('en')]);
      expect(AppLanguage.ckb.direction, TextDirection.rtl);
      expect(AppLanguage.ar.direction, TextDirection.rtl);
      expect(AppLanguage.en.direction, TextDirection.ltr);
      expect([for (final l in AppLanguage.values) l.nativeName], ['کوردی', 'العربية', 'English']);
    });

    test('a stored code is understood, and an unknown one is not', () {
      expect(AppLanguage.parse('ckb'), AppLanguage.ckb);
      expect(AppLanguage.parse('ar'), AppLanguage.ar);
      expect(AppLanguage.parse('en'), AppLanguage.en);
      expect(AppLanguage.parse('fr'), isNull);
      expect(AppLanguage.parse(null), isNull);
    });

    test('every language has every message', () {
      expect(ckb.keys.toSet(), en.keys.toSet(), reason: 'Kurdish must have exactly the English keys');
      expect(ar.keys.toSet(), en.keys.toSet(), reason: 'Arabic must have exactly the English keys');
      expect(en.length, greaterThan(700));
    });

    test('no message is empty', () {
      for (final lang in {'en': en, 'ckb': ckb, 'ar': ar}.entries) {
        for (final m in lang.value.entries) {
          expect(m.value.trim(), isNotEmpty, reason: '${lang.key}.${m.key}');
        }
      }
    });

    test('a translation fills in the same blanks as the English', () {
      for (final key in en.keys) {
        expect(_placeholders(ckb[key]!), _placeholders(en[key]!), reason: 'ckb.$key');
        expect(_placeholders(ar[key]!), _placeholders(en[key]!), reason: 'ar.$key');
      }
    });

    test('the braces of every message are balanced', () {
      for (final lang in {'en': en, 'ckb': ckb, 'ar': ar}.entries) {
        for (final m in lang.value.entries) {
          var depth = 0;
          for (final c in m.value.runes) {
            if (c == 0x7B) depth++;
            if (c == 0x7D) depth--;
            expect(depth, greaterThanOrEqualTo(0), reason: '${lang.key}.${m.key}');
          }
          expect(depth, 0, reason: '${lang.key}.${m.key}');
        }
      }
    });
  });

  group('the writing', () {
    test('Kurdish uses the Kurdish letters, not the Arabic ones', () {
      // Arabic kaf, Arabic yeh, alef maksura, teh marbuta and the hamza carriers
      // that Kurdish does not use are the usual typing slips.
      final wrong = RegExp('[\u0643\u064a\u0649\u0629\u06c1\u06be\u0624\u0623\u0625]');
      for (final m in ckb.entries) {
        expect(wrong.hasMatch(m.value), isFalse, reason: 'ckb.${m.key}: ${m.value}');
      }
    });

    test('Arabic uses the Arabic letters, not the Kurdish or Persian ones', () {
      final wrong = RegExp('[\u06a9\u06cc\u06d5\u06c6\u06ce\u0695\u06b5\u06a4\u06af\u067e\u0686\u0698]');
      for (final m in ar.entries) {
        // The app's own name is written in Kurdish letters, in every language.
        final text = m.value.replaceAll(AppInfo.name, '');
        expect(wrong.hasMatch(text), isFalse, reason: 'ar.${m.key}: ${m.value}');
      }
    });

    test('digits are the same in every language', () {
      final eastern = RegExp('[\u0660-\u0669\u06f0-\u06f9]');
      for (final lang in {'ckb': ckb, 'ar': ar}.entries) {
        for (final m in lang.value.entries) {
          expect(eastern.hasMatch(m.value), isFalse, reason: '${lang.key}.${m.key}');
        }
      }
    });

    test('nothing was left in English inside a Kurdish or Arabic sentence', () {
      for (final lang in {'ckb': ckb, 'ar': ar}.entries) {
        for (final m in lang.value.entries) {
          final bare = _withoutPlaceholders(m.value);
          for (final word in RegExp('[A-Za-z]+').allMatches(bare).map((x) => x.group(0)!)) {
            expect(_latinOk, contains(word), reason: '${lang.key}.${m.key} has "$word"');
          }
        }
      }
    });
  });

  group('words and numbers', () {
    AppLocalizations of(AppLanguage l) => lookupAppLocalizations(l.locale);

    test('the same message reads in each language', () {
      expect(of(AppLanguage.en).settingsTitle, 'Settings');
      expect(of(AppLanguage.ckb).settingsTitle, 'ڕێکخستنەکان');
      expect(of(AppLanguage.ar).settingsTitle, 'الإعدادات');
      expect(of(AppLanguage.ckb).navPrivate, 'تایبەت');
      expect(of(AppLanguage.ar).navPublic, 'عامة');
    });

    test('Arabic counts the way Arabic does', () {
      final l = of(AppLanguage.ar);
      expect(l.chatGroupMembers(1), 'عضو واحد');
      expect(l.chatGroupMembers(2), 'عضوان');
      expect(l.chatGroupMembers(5), '5 أعضاء');
      expect(l.chatGroupMembers(11), '11 عضوًا');
      expect(l.chatGroupMembers(100), '100 عضو');
    });

    test('English and Kurdish do too', () {
      expect(of(AppLanguage.en).chatGroupMembers(1), '1 member');
      expect(of(AppLanguage.en).chatGroupMembers(3), '3 members');
      expect(of(AppLanguage.ckb).chatGroupMembers(1), '1 ئەندام');
      expect(of(AppLanguage.ckb).chatGroupMembers(7), '7 ئەندام');
    });

    test('a number and a name end up where the sentence wants them', () {
      expect(of(AppLanguage.en).errMessageTooLong(300, 200),
          'That message is too long (300 of 200 bytes). Please shorten it.');
      expect(of(AppLanguage.ckb).errMessageTooLong(300, 200), contains('300'));
      expect(of(AppLanguage.ar).errBlockedNamed('Sara'), 'لقد حظرت Sara.');
      expect(of(AppLanguage.ckb).defaultNickname('A1B2'), 'مۆبایل A1B2');
      expect(of(AppLanguage.en).defaultNickname('A1B2'), 'Phone A1B2');
    });
  });
}
