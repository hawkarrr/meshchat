import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../core/format.dart';
import '../theme/app_theme.dart';
import '../theme/surfaces.dart';
import 'peer_avatar.dart';
import 'status_pill.dart';
import '../l10n/l10n.dart';

/// A person in a list: avatar ringed by reachability, name with a short id
/// (nicknames are not unique, the id is), verification badge and live status.
class PeerTile extends StatelessWidget {
  const PeerTile({super.key, required this.view, this.onTap, this.trailing, this.onLongPress});

  final PeerView view;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final peer = view.peer;
    final status = view.status;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: AppPanel(
        radius: 20,
        child: ListTile(
          onTap: onTap,
          onLongPress: onLongPress,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          leading: PeerAvatar(name: peer.displayName, seed: peer.id, status: status),
          title: Row(
            children: [
              Flexible(
                child: Text(
                  peer.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
              const SizedBox(width: 6),
              Text('#${peer.shortId.substring(0, 4)}',
                  style: TextStyle(color: context.palette.textMuted, fontSize: 12)),
              if (peer.verified) ...[
                const SizedBox(width: 6),
                Icon(Icons.verified_user_rounded, size: 16, color: context.palette.accentSoft),
              ],
              if (peer.blocked) ...[
                const SizedBox(width: 6),
                Icon(Icons.block_rounded, size: 15, color: context.palette.danger),
              ],
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ReachabilityPill(status, dense: true),
                if (!status.isReachable)
                  Text(
                    context.l10n.peerSeenAgo(formatAgo(peer.lastSeenMs, context.l10n)),
                    style: TextStyle(color: context.palette.textMuted, fontSize: 12),
                  ),
                if (!peer.canReceiveEncrypted)
                  Text(context.l10n.peerNoKeyYet,
                      style: TextStyle(color: context.palette.pending, fontSize: 12)),
              ],
            ),
          ),
          trailing: trailing ?? Icon(Icons.chevron_right_rounded, color: context.palette.textMuted),
        ),
      ),
    );
  }
}
