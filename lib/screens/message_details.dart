import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_controller.dart';
import '../core/format.dart';
import '../models/conversation.dart';
import '../models/delivery_problem.dart';
import '../models/media.dart';
import '../models/message.dart';
import '../theme/app_theme.dart';
import '../theme/surfaces.dart';
import '../widgets/quote_views.dart';
import '../widgets/status_pill.dart';
import '../l10n/l10n.dart';

/// Everything this phone knows about one message: who, when, how it travelled,
/// whether it was edited, forwarded or answered, who confirmed it, and - in a
/// public room - when it disappears.
Future<void> showMessageDetails(
  BuildContext context, {
  required AppController controller,
  required ChatMessage message,
  required MediaItem? media,
  required String author,
  required QuoteData? quote,
  required bool pinned,
  required Conversation conversation,
}) {
  return showAppSheet<void>(
    context: context,
    builder: (sheet) => _Details(
      controller: controller,
      message: message,
      media: media,
      author: author,
      quote: quote,
      pinned: pinned,
      conversation: conversation,
      closeTo: context,
    ),
  );
}

class _Details extends StatefulWidget {
  const _Details({
    required this.controller,
    required this.message,
    required this.media,
    required this.author,
    required this.quote,
    required this.pinned,
    required this.conversation,
    required this.closeTo,
  });

  final AppController controller;
  final ChatMessage message;
  final MediaItem? media;
  final String author;
  final QuoteData? quote;
  final bool pinned;
  final Conversation conversation;
  final BuildContext closeTo;

  @override
  State<_Details> createState() => _DetailsState();
}

class _DetailsState extends State<_Details> {
  Set<String>? _confirmed;

  ChatMessage get m => widget.message;

  @override
  void initState() {
    super.initState();
    if (m.isOutgoing && widget.conversation.isGroup) {
      widget.controller.receiptMembers(m.id).then((s) {
        if (mounted) setState(() => _confirmed = s);
      });
    }
  }

  String _name(String id) {
    final peer = widget.controller.peers.where((p) => p.peer.id == id).firstOrNull;
    if (peer != null) return peer.peer.displayName;
    final group = widget.controller.groups
        .where((g) => g.id == widget.conversation.groupId)
        .firstOrNull;
    final member = group?.members.where((x) => x.id == id).firstOrNull;
    return member?.nickname ?? context.l10n.detailUnknownPhone;
  }

  Widget _row(String k, String v, {Key? key}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
                width: 110,
                child: Text(k, style: TextStyle(color: context.palette.textMuted, fontSize: 13))),
            Expanded(child: Text(v, key: key, style: const TextStyle(fontSize: 13.5))),
          ],
        ),
      );

  String _remaining(int ms) {
    final l = context.l10n;
    if (ms <= 0) return l.detailAnyMoment;
    final minutes = (ms / 60000).ceil();
    if (minutes < 60) return l.detailInMinutes(minutes);
    final h = minutes ~/ 60;
    final r = minutes % 60;
    return r == 0 ? l.detailInHours(h) : l.detailInHoursMinutes(h, r);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final (_, statusLabel, _) = deliveryAppearance(context.l10n, m, context.palette);
    final clockSkew =
        (m.claimedTimestampMs - m.sortTimeMs).abs() > const Duration(minutes: 10).inMilliseconds;
    final expires = m.expiresAtMs;
    final conv = widget.conversation;
    List<String> confirmedNames = const [];
    List<String> waitingNames = const [];
    if (_confirmed != null) {
      final group = c.groups.where((g) => g.id == conv.groupId).firstOrNull;
      final others = [
        for (final member in group?.members ?? const []) if (member.id != c.identityId) member.id,
      ];
      confirmedNames = [for (final id in others) if (_confirmed!.contains(id)) _name(id)];
      waitingNames = [for (final id in others) if (!_confirmed!.contains(id)) _name(id)];
    }
    return SingleChildScrollView(
      child: Column(
        key: const Key('message-details'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.l10n.detailTitle, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          _row(context.l10n.detailFrom, m.isOutgoing ? context.l10n.commonYou : widget.author),
          _row(context.l10n.detailDirection, m.isOutgoing ? context.l10n.detailSentByYou : context.l10n.detailReceived),
          if (m.isMedia)
            _row(context.l10n.detailType, switch (m.kind) {
              MessageKind.image => context.l10n.bubblePicture,
              MessageKind.video => context.l10n.bubbleVideo,
              _ => context.l10n.bubbleVoice,
            }),
          if (widget.media != null) _row(context.l10n.detailSize, formatBytes(widget.media!.byteLength)),
          _row(context.l10n.detailStatus, statusLabel.isEmpty ? context.l10n.detailReceived : statusLabel),
          if (m.recipientCount > 0)
            _row(context.l10n.detailConfirmedBy, context.l10n.detailConfirmedOf(m.receiptCount, m.recipientCount)),
          if (confirmedNames.isNotEmpty) _row(context.l10n.detailHasIt, confirmedNames.join(', ')),
          if (waitingNames.isNotEmpty) _row(context.l10n.detailNotYet, waitingNames.join(', ')),
          // Two different facts: what the sender's clock said, and when this phone
          // really stored it. The first is only the sender's word.
          if (!m.isOutgoing)
            _row(context.l10n.detailSentTheirClock, formatDateTime(m.claimedTimestampMs),
                key: const Key('detail-sent')),
          _row(m.isOutgoing ? context.l10n.detailWrittenSaved : context.l10n.detailReceivedSaved, formatDateTime(m.sortTimeMs),
              key: const Key('detail-saved')),
          if (m.isEdited)
            _row(context.l10n.detailEdited, formatDateTime(m.editedAtMs!), key: const Key('detail-edited')),
          if (m.isForwarded)
            _row(context.l10n.detailForwardedFrom, m.forwardedFrom!, key: const Key('detail-forwarded')),
          if (m.replyToId != null)
            _row(
              context.l10n.detailReplyTo,
              widget.quote == null || widget.quote!.gone
                  ? context.l10n.detailReplyDeleted
                  : '${widget.quote!.author}: ${widget.quote!.snippet}',
              key: const Key('detail-reply'),
            ),
          if (widget.pinned) _row(context.l10n.detailPinned, context.l10n.detailPinnedValue),
          if (expires != null)
            _row(
              context.l10n.detailDisappears,
              context.l10n.detailDisappearsValue(formatDateTime(expires), _remaining(expires - c.clock.nowMs)),
              key: const Key('detail-expires'),
            ),
          if (m.hops > 0)
            _row(
              m.isOutgoing ? context.l10n.detailReceiptPath : context.l10n.detailRoute,
              m.isOutgoing
                  ? context.l10n.detailRadioHops(m.hops + 1)
                  : context.l10n.detailPassedThrough(m.hops),
            ),
          if (clockSkew && !m.isOutgoing)
            _row(context.l10n.detailNote, context.l10n.detailClockSkew),
          if (m.error != null)
            _row(context.l10n.detailProblem, DeliveryProblem.describe(context.l10n, m.error) ?? ''),
          _row(context.l10n.detailMessageId, m.id.substring(0, 16)),
          const SizedBox(height: 12),
          if (m.body.isNotEmpty)
            OutlinedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: m.body));
                Navigator.pop(context);
                ScaffoldMessenger.of(widget.closeTo)
                    .showSnackBar(SnackBar(content: Text(context.l10n.actCopied)));
              },
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: Text(context.l10n.actCopyText),
            ),
        ],
      ),
    );
  }
}
