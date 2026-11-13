import 'package:flutter/material.dart';

import '../models/message.dart';
import '../theme/app_theme.dart';
import '../l10n/l10n.dart';

/// What the composer is doing besides sending a brand new message: answering
/// one, or rewriting one of our own.
sealed class ComposerTarget {
  const ComposerTarget(this.message);

  final ChatMessage message;
}

class ReplyTarget extends ComposerTarget {
  const ReplyTarget(super.message, {required this.author});

  /// Who wrote the message being answered, as the person knows them.
  final String author;
}

class EditTarget extends ComposerTarget {
  const EditTarget(super.message);
}

/// One line saying what a message is, for quotes, banners and lists. A picture
/// or voice message says so; a caption wins over the word "Photo".
String messageSnippet(ChatMessage m, AppLocalizations l) {
  if (m.status == MessageStatus.undecryptable) return l.snippetUnreadable;
  final text = m.body.replaceAll(RegExp(r'\s+'), ' ').trim();
  switch (m.kind) {
    case MessageKind.text:
      return text;
    case MessageKind.image:
      return text.isEmpty ? l.previewPhoto : text;
    case MessageKind.voice:
      return l.previewVoice;
    case MessageKind.video:
      return text.isEmpty ? l.previewVideo : text;
  }
}

/// The small icon that goes with [messageSnippet] for pictures and voice.
IconData? messageSnippetIcon(ChatMessage m) => switch (m.kind) {
      MessageKind.text => null,
      MessageKind.image => Icons.photo_rounded,
      MessageKind.voice => Icons.mic_rounded,
      MessageKind.video => Icons.videocam_rounded,
    };

/// The bar above the text field: "Replying to Bob" or "Edit message", with the
/// message in one line and a way out.
class ComposerBanner extends StatelessWidget {
  const ComposerBanner({super.key, required this.target, required this.onCancel});

  final ComposerTarget target;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final editing = target is EditTarget;
    final title = switch (target) {
      ReplyTarget(:final author) => context.l10n.replyingTo(author),
      EditTarget() => context.l10n.editMessageTitle,
    };
    final icon = messageSnippetIcon(target.message);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        key: Key(editing ? 'composer-edit-banner' : 'composer-reply-banner'),
        padding: const EdgeInsetsDirectional.fromSTEB(12, 6, 4, 6),
        decoration: BoxDecoration(
          color: context.palette.surfaceHigh,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.palette.outline),
        ),
        child: Row(
          children: [
            Icon(editing ? Icons.edit_rounded : Icons.reply_rounded,
                size: 20, color: context.palette.accentSoft),
            const SizedBox(width: 10),
            Container(width: 3, height: 32, color: context.palette.accent),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: context.palette.accentSoft, fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  Row(
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: 14, color: context.palette.textSecondary),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          messageSnippet(target.message, context.l10n),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: context.palette.textSecondary, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              key: const Key('composer-target-cancel'),
              tooltip: editing ? context.l10n.cancelEditing : context.l10n.cancelReply,
              icon: const Icon(Icons.close_rounded, size: 20),
              onPressed: onCancel,
            ),
          ],
        ),
      ),
    );
  }
}
