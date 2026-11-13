
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_mesh_chat/core/bidi.dart';
import 'package:offline_mesh_chat/core/byte_limit.dart';
import 'package:offline_mesh_chat/core/format.dart';
import 'package:offline_mesh_chat/device/gallery.dart';
import 'package:offline_mesh_chat/device/image_tools.dart';
import 'package:offline_mesh_chat/device/voice.dart';
import 'package:offline_mesh_chat/l10n/l10n.dart';
import 'package:offline_mesh_chat/l10n/labels.dart';
import 'package:offline_mesh_chat/models/delivery_problem.dart';
import 'package:offline_mesh_chat/models/message.dart';
import 'package:offline_mesh_chat/models/message_preview.dart';
import 'package:offline_mesh_chat/protocol/envelope.dart';
import 'package:offline_mesh_chat/services/discovery_service.dart';
import 'package:offline_mesh_chat/services/network_status_service.dart';

AppLocalizations _l(AppLanguage l) => lookupAppLocalizations(l.locale);

ChatMessage _message({
  String body = 'hello',
  MessageKind kind = MessageKind.text,
  bool outgoing = false,
  String? nick,
  MessageStatus status = MessageStatus.received,
}) =>
    ChatMessage(
      id: 'm1',
      conversationId: 'gr:g',
      senderId: 'sender',
      senderNickname: nick,
      isOutgoing: outgoing,
      kind: kind,
      body: body,
      sortTimeMs: 1,
      claimedTimestampMs: 1,
      status: status,
    );

/// The small pieces that make the three languages work: which way a piece of text
/// reads, how names are limited, how a stored summary is read back, and the
/// words behind enums and errors.
void main() {
  group('which way a message reads', () {
    test('by its first letter', () {
      expect(textDirectionOf('hello'), TextDirection.ltr);
      expect(textDirectionOf('سڵاو'), TextDirection.rtl);
      expect(textDirectionOf('مرحبا'), TextDirection.rtl);
      expect(textDirectionOf('  سلام hello'), TextDirection.rtl);
      expect(textDirectionOf('hello سلام'), TextDirection.ltr);
    });

    test('digits, emoji and nothing at all say nothing', () {
      expect(textDirectionOf(''), isNull);
      expect(textDirectionOf('12:30'), isNull);
      expect(textDirectionOf('😀'), isNull);
    });

    test('an emoji in front does not decide', () {
      expect(textDirectionOf('😀 hello'), TextDirection.ltr);
      expect(textDirectionOf('😀 سڵاو'), TextDirection.rtl);
    });
  });

  group('names are limited by what they weigh on the air', () {
    TextEditingValue type(String s) =>
        const ByteLimitFormatter(32).formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: s));

    test('32 Latin letters fit, 33 do not', () {
      expect(type('a' * 32).text, 'a' * 32);
      expect(type('a' * 33).text, 'a' * 32);
    });

    test('a Kurdish letter weighs two bytes, so sixteen fit', () {
      final text = type('ک' * 20).text;
      expect(text.runes.length, 16);
    });

    test('an emoji is never cut in half', () {
      final text = type('${'a' * 30}😀').text;
      expect(text, 'a' * 30, reason: 'the emoji weighs 4 bytes and 30 + 4 is over the limit');
    });

    test('pasted text is trimmed to fit and the cursor goes to its end', () {
      final v = type('x' * 60);
      expect(v.text.length, 32);
      expect(v.selection.baseOffset, 32);
    });

    test('something that already fits is left alone', () {
      expect(type('سڵاو').text, 'سڵاو');
    });
  });

  group('the summary of the last message', () {
    test('is stored as structure and read in the language of the screen', () {
      final stored = MessagePreview.of(_message(kind: MessageKind.image, body: ''), showAuthor: false).encode();
      expect(stored, startsWith('{"k":"image"'));
      expect(MessagePreview.show(stored, _l(AppLanguage.en)), '📷 Photo');
      expect(MessagePreview.show(stored, _l(AppLanguage.ckb)), '📷 وێنە');
      expect(MessagePreview.show(stored, _l(AppLanguage.ar)), '📷 صورة');
    });

    test('names who wrote it in a group', () {
      final theirs = MessagePreview.of(_message(body: 'dinner at 8', nick: 'Sara'), showAuthor: true).encode();
      expect(MessagePreview.show(theirs, _l(AppLanguage.en)), 'Sara: dinner at 8');
      final mine = MessagePreview.of(_message(body: 'ok', outgoing: true), showAuthor: true).encode();
      expect(MessagePreview.show(mine, _l(AppLanguage.en)), 'You: ok');
      expect(MessagePreview.show(mine, _l(AppLanguage.ckb)), 'تۆ: ok');
      expect(MessagePreview.show(mine, _l(AppLanguage.ar)), 'أنت: ok');
    });

    test('says nothing of who in a private chat', () {
      final stored = MessagePreview.of(_message(body: 'hi', outgoing: true), showAuthor: false).encode();
      expect(MessagePreview.show(stored, _l(AppLanguage.en)), 'hi');
    });

    test('a voice message and a video have their words, a caption wins over "Photo"', () {
      final voice = MessagePreview.of(_message(kind: MessageKind.voice, body: ''), showAuthor: false).encode();
      expect(MessagePreview.show(voice, _l(AppLanguage.en)), '🎤 Voice message');
      expect(MessagePreview.show(voice, _l(AppLanguage.ckb)), '🎤 نامەی دەنگی');
      final video = MessagePreview.of(_message(kind: MessageKind.video, body: 'the lake'), showAuthor: false).encode();
      expect(MessagePreview.show(video, _l(AppLanguage.en)), '🎬 the lake');
    });

    test('a message that could not be read never shows its body', () {
      final stored = MessagePreview.of(
              _message(body: 'secret', status: MessageStatus.undecryptable), showAuthor: false)
          .encode();
      expect(stored, isNot(contains('secret')));
      expect(MessagePreview.show(stored, _l(AppLanguage.en)), 'Message could not be decrypted');
    });

    test('a long text is cut to one short line', () {
      final stored = MessagePreview.of(_message(body: 'line one\n\n  line   two'), showAuthor: false).encode();
      expect(MessagePreview.show(stored, _l(AppLanguage.en)), 'line one line two');
      final long = MessagePreview.of(_message(body: 'x' * 200), showAuthor: false).encode();
      final shown = MessagePreview.show(long, _l(AppLanguage.en))!;
      expect(shown.length, MessagePreview.maxLength);
      expect(shown, endsWith('…'));
    });

    test('text written by an older version, as plain words, is shown as it is', () {
      expect(MessagePreview.show('📷 Photo', _l(AppLanguage.ckb)), '📷 Photo');
      expect(MessagePreview.show('hello', _l(AppLanguage.ar)), 'hello');
      expect(MessagePreview.show(null, _l(AppLanguage.ar)), isNull);
    });

    test('what someone typed that looks like a stored summary stays text', () {
      // A message body only ever lives inside the "t" field, properly escaped.
      final tricky = MessagePreview.of(_message(body: '{"k":"image","t":"x"}'), showAuthor: false).encode();
      expect(MessagePreview.show(tricky, _l(AppLanguage.en)), '{"k":"image","t":"x"}');
    });
  });

  group('words for enums, problems and errors', () {
    test('a stored delivery problem is told in the current language', () {
      expect(DeliveryProblem.describe(_l(AppLanguage.en), DeliveryProblem.expired.code),
          contains('could not be reached'));
      expect(DeliveryProblem.describe(_l(AppLanguage.ckb), DeliveryProblem.nobodyInRange.code),
          'کەس لە نزیکدا نەبوو بۆ وەرگرتنی ئەمە.');
      expect(DeliveryProblem.describe(_l(AppLanguage.ar), DeliveryProblem.fileIncomplete.code),
          'لم يصل باقي هذا الملف أبدًا.');
      expect(DeliveryProblem.describe(_l(AppLanguage.ar), 'something older'), 'something older');
      expect(DeliveryProblem.describe(_l(AppLanguage.ar), null), isNull);
    });

    test('every problem has words in every language', () {
      for (final p in DeliveryProblem.values) {
        for (final lang in AppLanguage.values) {
          expect(p.text(_l(lang)), isNotEmpty);
        }
      }
    });

    test('picture, voice, video; discovery modes; the network', () {
      expect(MediaKind.image.label(_l(AppLanguage.ckb)), 'وێنە');
      expect(MediaKind.video.label(_l(AppLanguage.ar)), 'فيديو');
      expect(DiscoveryMode.lowPower.localized(_l(AppLanguage.en)), 'Battery saver');
      expect(DiscoveryMode.balanced.localized(_l(AppLanguage.ckb)), 'هاوسەنگ');
      expect(describeNetwork(NetworkKind.none, _l(AppLanguage.ar)), 'لا Wi-Fi ولا بيانات جوّال');
      expect(describeNetwork(NetworkKind.wifi), 'Wi-Fi is on (not used by this app)');
    });

    test('the phone\'s own problems are told in the current language', () {
      const gallery = GalleryException('x', problem: GalleryProblem.noSpace);
      expect(gallery.text(_l(AppLanguage.en)), 'There is not enough space on this phone to save it.');
      expect(gallery.text(_l(AppLanguage.ckb)), isNot(contains('space')));
      expect(const GalleryException('a plain reason').text(_l(AppLanguage.ckb)), 'a plain reason');
      expect(const ImageCompressionException('x', problem: ImageProblem.tooDetailed).text(_l(AppLanguage.ar)),
          contains('البلوتوث'));
      expect(const VoiceException('x', problem: VoiceProblem.micOff).text(_l(AppLanguage.ckb)),
          contains('مایکرۆفۆن'));
    });
  });

  group('times', () {
    final now = DateTime(2026, 10, 16, 15, 0);
    int at(DateTime t) => t.millisecondsSinceEpoch;

    test('"5 min ago" in each language', () {
      final five = at(now.subtract(const Duration(minutes: 5)));
      expect(formatAgo(five, _l(AppLanguage.en), nowMs: at(now)), '5 min ago');
      expect(formatAgo(five, _l(AppLanguage.ckb), nowMs: at(now)), 'پێش 5 خولەک');
      expect(formatAgo(five, _l(AppLanguage.ar), nowMs: at(now)), 'قبل 5 دقائق');
    });

    test('Arabic gets its dual and its plural', () {
      final two = at(now.subtract(const Duration(hours: 2)));
      expect(formatAgo(two, _l(AppLanguage.ar), nowMs: at(now)), 'قبل ساعتين');
      final eleven = at(now.subtract(const Duration(minutes: 11)));
      expect(formatAgo(eleven, _l(AppLanguage.ar), nowMs: at(now)), 'قبل 11 دقيقة');
    });

    test('just now, seconds, days', () {
      expect(formatAgo(at(now), _l(AppLanguage.ckb), nowMs: at(now)), 'هەر ئێستا');
      expect(formatAgo(at(now.subtract(const Duration(seconds: 30))), _l(AppLanguage.en), nowMs: at(now)),
          '30 s ago');
      expect(formatAgo(at(now.subtract(const Duration(days: 3))), _l(AppLanguage.en), nowMs: at(now)),
          '3 d ago');
    });

    test('the list shows the clock today, then the day', () {
      final today = at(DateTime(2026, 10, 16, 9, 5));
      expect(formatListTime(today, _l(AppLanguage.ar), now: now), '09:05');
      final yesterday = at(DateTime(2026, 10, 15, 9, 5));
      expect(formatListTime(yesterday, _l(AppLanguage.en), now: now), 'Yesterday');
      expect(formatListTime(yesterday, _l(AppLanguage.ckb), now: now), 'دوێنێ');
      expect(formatListTime(yesterday, _l(AppLanguage.ar), now: now), 'أمس');
      // 13 October 2026 is a Tuesday.
      final tuesday = at(DateTime(2026, 10, 13, 9, 5));
      expect(formatListTime(tuesday, _l(AppLanguage.en), now: now), 'Tue');
      expect(formatListTime(tuesday, _l(AppLanguage.ckb), now: now), 'سێشەممە');
      expect(formatListTime(tuesday, _l(AppLanguage.ar), now: now), 'الثلاثاء');
      final old = at(DateTime(2026, 9, 1, 9, 5));
      expect(formatListTime(old, _l(AppLanguage.ar), now: now), '01/09');
    });
  });
}
