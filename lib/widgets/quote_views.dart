import 'package:flutter/material.dart';

import '../models/message.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../theme/surfaces.dart';
import 'composer_target.dart';
import 'reveal.dart';
import '../l10n/l10n.dart';

/// What a reply quotes: who wrote the original and what it said - or that it
/// is gone. Nothing of a deleted message is kept, so [gone] quotes show no
/// content at all.
class QuoteData {
  const QuoteData({
    required this.messageId,
    required this.author,
    required this.authorSeed,
    required this.snippet,
    this.icon,
    this.gone = false,
  });

  /// A quote of a message that no longer exists here.
  const QuoteData.gone(this.messageId)
      : author = '',
        authorSeed = '',
        snippet = '',
        icon = null,
        gone = true;

  final String messageId;
  final String author;
  final String authorSeed;
  final String snippet;
  final IconData? icon;
  final bool gone;

  factory QuoteData.of(ChatMessage original, {required String author, required AppLocalizations l}) =>
      QuoteData(
        messageId: original.id,
        author: author,
        authorSeed: original.senderId,
        snippet: messageSnippet(original, l),
        icon: messageSnippetIcon(original),
      );
}

/// The quoted message inside a bubble.
class QuoteView extends StatelessWidget {
  const QuoteView({super.key, required this.quote, this.onTap, this.onBlue = false});

  final QuoteData quote;
  final VoidCallback? onTap;

  /// The bubble is the blue one (a message we sent): the quote is written in white.
  final bool onBlue;

  @override
  Widget build(BuildContext context) {
    final color = quote.gone
        ? (onBlue ? context.palette.onAccent : context.palette.textMuted)
        : (onBlue ? context.palette.onAccent : context.palette.nameColorFor(quote.authorSeed));
    final snippetColor = onBlue ? context.palette.onAccent : context.palette.textSecondary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: InkWell(
        key: const Key('quote-view'),
        onTap: quote.gone ? null : onTap,
        borderRadius: BorderRadius.circular(AppRadii.sm - 4),
        child: Container(
          padding: const EdgeInsetsDirectional.fromSTEB(8, 3, 8, 3),
          decoration: BoxDecoration(
            color: context.palette.inset,
            borderRadius: BorderRadius.circular(AppRadii.sm - 4),
            border: BorderDirectional(start: BorderSide(color: color, width: 3)),
          ),
          child: quote.gone
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.delete_outline_rounded, size: 14, color: color),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        context.l10n.quoteOriginalDeleted,
                        style: TextStyle(color: color, fontSize: 12.5, fontStyle: FontStyle.italic),
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(quote.author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12.5)),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (quote.icon != null) ...[
                          Icon(quote.icon, size: 13, color: snippetColor),
                          const SizedBox(width: 3),
                        ],
                        Flexible(
                          child: Text(
                            quote.snippet,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: snippetColor, fontSize: 12.5),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// "Forwarded from Bob".
class ForwardedLabel extends StatelessWidget {
  const ForwardedLabel(this.name, {super.key, this.onBlue = false});

  final String name;

  /// The bubble is the blue one: the label is white, the light blue would vanish on it.
  final bool onBlue;

  @override
  Widget build(BuildContext context) {
    final color = onBlue ? context.palette.onAccent : context.palette.accentSoft;
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(AppIcons.forward, size: 14, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              context.l10n.forwardedFrom(name),
              key: const Key('forwarded-label'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontSize: 12.5, fontStyle: FontStyle.italic),
            ),
          ),
        ],
      ),
    );
  }
}

/// The strip under the header that shows a pinned message. Tapping it goes to
/// that message (and on to the next pinned one); the button opens the list.
class PinnedBanner extends StatelessWidget {
  const PinnedBanner({
    super.key,
    required this.message,
    required this.author,
    required this.index,
    required this.count,
    required this.onTap,
    required this.onList,
  });

  final ChatMessage message;
  final String author;

  /// Which pinned message this is (0-based) out of [count].
  final int index;
  final int count;
  final VoidCallback onTap;
  final VoidCallback onList;

  @override
  Widget build(BuildContext context) {
    final icon = messageSnippetIcon(message);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 2),
      child: AppPanel(
        radius: 16,
        padding: EdgeInsets.zero,
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                key: const Key('pinned-banner'),
                borderRadius: BorderRadius.circular(16),
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(12, 6, 4, 6),
                  child: Row(
                    children: [
                      Icon(Icons.push_pin_rounded, size: 18, color: context.palette.accentSoft),
                      const SizedBox(width: 10),
                      Container(width: 3, height: 30, color: context.palette.accent),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              count > 1 ? context.l10n.pinnedOf(index + 1, count) : context.l10n.pinnedMessage,
                              style: TextStyle(
                                  color: context.palette.accentSoft,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12.5),
                            ),
                            Row(
                              children: [
                                if (icon != null) ...[
                                  Icon(icon, size: 14, color: context.palette.textSecondary),
                                  const SizedBox(width: 4),
                                ],
                                Expanded(
                                  child: Text(
                                    '$author: ${messageSnippet(message, context.l10n)}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        color: context.palette.textSecondary, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            IconButton(
              key: const Key('pinned-list-open'),
              tooltip: context.l10n.pinnedAll,
              icon: const Icon(Icons.format_list_bulleted_rounded, size: 20),
              onPressed: onList,
            ),
          ],
        ),
      ),
    );
  }
}

/// Says honestly where this person's "delete for everyone" requests stand in a
/// private chat: they are only a request until the other phone has it.
class DeletionStatusStrip extends StatelessWidget {
  const DeletionStatusStrip({super.key, required this.counts, required this.otherName});

  final Map<String, int> counts;
  final String otherName;

  @override
  Widget build(BuildContext context) {
    final waiting = (counts['queued'] ?? 0) + (counts['sent'] ?? 0);
    final expired = counts['expired'] ?? 0;
    final show = waiting > 0 || expired > 0;
    final l = context.l10n;
    final lines = <String>[
      if (waiting > 0) l.delWaiting(waiting, otherName),
      if (expired > 0) l.delExpired(expired, otherName),
    ];
    return Reveal(
      show: show,
      child: !show
          ? const SizedBox.shrink()
          : Padding(
              key: const Key('deletion-status'),
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(waiting > 0 ? Icons.schedule_rounded : Icons.info_outline_rounded,
                      size: 14, color: context.palette.pending),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(lines.join(' '),
                        style: TextStyle(color: context.palette.pending, fontSize: 12, height: 1.3)),
                  ),
                ],
              ),
            ),
    );
  }
}
