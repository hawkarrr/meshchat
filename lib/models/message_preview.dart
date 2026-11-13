import 'dart:convert';

import '../l10n/l10n.dart';
import 'message.dart';

/// What the chat list says about the last message of a conversation: its text,
/// or "Photo" / "Voice message" / "Video", and who wrote it in a group or room.
///
/// It is stored in the conversation row as a small piece of structure, not as
/// words, so the list reads in the language the app is in *now* ("Photo" /
/// "وێنە" / "صورة"), and changes with it when the person switches language.
class MessagePreview {
  const MessagePreview({
    required this.kind,
    this.text = '',
    this.author,
    this.fromMe = false,
  });

  final PreviewKind kind;

  /// The message text, or the caption of a picture or video. One line, shortened.
  final String text;

  /// Who wrote it, for groups and rooms (null in a private chat).
  final String? author;
  final bool fromMe;

  static const int maxLength = 80;

  static String _singleLine(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

  static String _clip(String s) =>
      s.length <= maxLength ? s : '${s.substring(0, maxLength - 1)}…';

  /// The preview of [m]. [showAuthor] is true outside private chats.
  factory MessagePreview.of(ChatMessage m, {required bool showAuthor}) {
    if (m.status == MessageStatus.undecryptable) {
      return const MessagePreview(kind: PreviewKind.undecryptable);
    }
    final kind = switch (m.kind) {
      MessageKind.text => PreviewKind.text,
      MessageKind.image => PreviewKind.image,
      MessageKind.voice => PreviewKind.voice,
      MessageKind.video => PreviewKind.video,
    };
    final nick = (m.senderNickname ?? '').trim();
    return MessagePreview(
      kind: kind,
      text: m.kind == MessageKind.voice ? '' : _clip(_singleLine(m.body)),
      fromMe: showAuthor && m.isOutgoing,
      author: showAuthor && !m.isOutgoing && nick.isNotEmpty ? nick : null,
    );
  }

  /// What goes into the database.
  String encode() => jsonEncode(<String, Object>{
        'k': kind.name,
        if (text.isNotEmpty) 't': text,
        'a': ?author,
        if (fromMe) 'me': 1,
      });

  /// The preview stored as [stored], or null when it is plain text (written by
  /// an older version, which kept the words themselves).
  static MessagePreview? decode(String? stored) {
    if (stored == null || !stored.startsWith('{"k":"')) return null;
    try {
      final map = jsonDecode(stored);
      if (map is! Map<String, dynamic>) return null;
      final kind = PreviewKind.values.where((k) => k.name == map['k']).firstOrNull;
      if (kind == null) return null;
      return MessagePreview(
        kind: kind,
        text: (map['t'] as String?) ?? '',
        author: map['a'] as String?,
        fromMe: map['me'] == 1,
      );
    } on FormatException {
      return null;
    }
  }

  /// The one line to show, in the language of [l].
  String render(AppLocalizations l) {
    if (kind == PreviewKind.undecryptable) return l.previewUndecryptable;
    final core = switch (kind) {
      PreviewKind.text => text,
      PreviewKind.image => '📷 ${text.isEmpty ? l.previewPhoto : text}',
      PreviewKind.voice => '🎤 ${l.previewVoice}',
      PreviewKind.video => '🎬 ${text.isEmpty ? l.previewVideo : text}',
      PreviewKind.undecryptable => '',
    };
    final prefix = fromMe
        ? '${l.previewYou}: '
        : (author != null && author!.isNotEmpty)
            ? '$author: '
            : '';
    return '$prefix$core';
  }

  /// [stored] as one line in the language of [l]; null if there is no preview.
  static String? show(String? stored, AppLocalizations l) {
    if (stored == null) return null;
    return decode(stored)?.render(l) ?? stored;
  }
}

enum PreviewKind { text, image, voice, video, undecryptable }
