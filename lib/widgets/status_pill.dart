import 'package:flutter/material.dart';

import '../models/message.dart';
import '../models/peer.dart';
import '../theme/app_theme.dart';
import '../l10n/l10n.dart';

/// A small rounded label with a coloured dot or icon.
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.dense = false,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 8 : 10, vertical: dense ? 2 : 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Icon(icon, size: dense ? 12 : 14, color: color)
          else
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          const SizedBox(width: 6),
          // Shrinks (with an ellipsis) instead of overflowing when space is
          // tight: narrow screens, or large system font sizes.
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: dense ? 11 : 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Color reachabilityColor(Reachability r, AppPalette p) => switch (r) {
      Reachability.direct => p.direct,
      Reachability.relayed => p.relay,
      Reachability.offline => p.offline,
    };

String reachabilityLabel(AppLocalizations l, PeerStatus s) => switch (s.reachability) {
      Reachability.direct => l.reachDirectLong,
      Reachability.relayed => l.reachRelayLong(s.hops),
      Reachability.offline => l.reachOffline,
    };

String reachabilityShort(AppLocalizations l, PeerStatus s) => switch (s.reachability) {
      Reachability.direct => l.reachDirectShort,
      Reachability.relayed => l.reachRelayShort(s.hops),
      Reachability.offline => l.reachOffline,
    };

/// Directly connected / reachable through a relay / offline - shown only on
/// the strength of live evidence (see PeerTable).
class ReachabilityPill extends StatelessWidget {
  const ReachabilityPill(this.status, {super.key, this.dense = false, this.long = false});

  final PeerStatus status;
  final bool dense;
  final bool long;

  @override
  Widget build(BuildContext context) => StatusPill(
        label: long
            ? reachabilityLabel(context.l10n, status)
            : reachabilityShort(context.l10n, status),
        color: reachabilityColor(status.reachability, context.palette),
        dense: dense,
      );
}

/// Delivery state of one message, with its icon.
class DeliveryStatusView extends StatelessWidget {
  const DeliveryStatusView(this.message, {super.key, this.compact = false, this.onBlue = false});

  final ChatMessage message;
  final bool compact;

  /// It is drawn on the blue bubble: the greys and light blues of the other
  /// states would not show on it, so they are white (the icon still tells them
  /// apart). A failure keeps its own colour; the bubble of a failed message is not blue.
  final bool onBlue;

  @override
  Widget build(BuildContext context) {
    final (icon, label, plain) = deliveryAppearance(context.l10n, message, context.palette);
    if (label.isEmpty) return const SizedBox.shrink();
    final failed = message.status == MessageStatus.failed ||
        message.status == MessageStatus.undecryptable;
    final color = onBlue && !failed ? context.palette.onAccent : plain;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: compact ? 13 : 15, color: color),
        if (!compact) ...[
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ],
    );
  }
}

/// The icon, words and colour for a message's delivery state.
///
/// In a group the sender sees how many members have it ("Delivered 2/3" only
/// once everybody does); in a public room nobody can confirm receipt, so the
/// furthest it goes is "Sent".
(IconData, String, Color) deliveryAppearance(AppLocalizations l, ChatMessage m, AppPalette p) {
  switch (m.status) {
    case MessageStatus.queued:
      return (Icons.schedule_rounded, l.deliveryPending, p.pending);
    case MessageStatus.sent:
      if (m.recipientCount > 0) {
        return (
          Icons.check_rounded,
          l.deliverySentCount(m.receiptCount, m.recipientCount),
          p.textMuted
        );
      }
      return (Icons.check_rounded, l.deliverySent, p.textMuted);
    case MessageStatus.delivered:
      final text = m.hops > 0 ? l.deliveryDeliveredVia(m.hops + 1) : l.deliveryDelivered;
      return (Icons.done_all_rounded, text, p.delivered);
    case MessageStatus.failed:
      return (Icons.error_outline_rounded, l.deliveryFailed, p.danger);
    case MessageStatus.undecryptable:
      return (Icons.gpp_bad_rounded, l.deliveryUndecryptable, p.danger);
    case MessageStatus.received:
      return (Icons.check_rounded, '', p.textMuted);
  }
}
