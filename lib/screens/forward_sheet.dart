import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../core/bidi.dart';
import '../models/conversation.dart';
import '../theme/app_theme.dart';
import '../theme/surfaces.dart';
import '../widgets/peer_avatar.dart';
import '../l10n/l10n.dart';

/// Where a message can be forwarded to: a conversation that is open for
/// sending - a contact who is not blocked and whose encryption key we have, a
/// group we are still in, a public room we have joined.
class ForwardTarget {
  const ForwardTarget(this.conversation, this.title);

  final Conversation conversation;
  final String title;
}

List<ForwardTarget> forwardTargets(AppController c) {
  final out = <ForwardTarget>[];
  for (final conv in c.conversations) {
    switch (conv.type) {
      case ConversationType.direct:
        final view = c.peers.where((p) => p.peer.id == conv.peerId).firstOrNull;
        if (view == null || view.peer.blocked || !view.peer.canReceiveEncrypted) continue;
        out.add(ForwardTarget(conv, view.peer.displayName));
      case ConversationType.group:
        final group = c.groups.where((g) => g.id == conv.groupId).firstOrNull;
        if (group == null || !group.isActive) continue;
        out.add(ForwardTarget(conv, group.name));
      case ConversationType.room:
        final room = c.rooms.where((r) => r.id == conv.roomId).firstOrNull;
        if (room == null || !room.joined) continue;
        out.add(ForwardTarget(conv, room.label));
    }
  }
  return out;
}

/// "Forward to...": a searchable list of the conversations a message can go to.
/// Returns the id of the one picked.
///
/// With [hasVideo] the public rooms are shown but cannot be chosen: a video would
/// have to be carried by every phone in range, so it only goes to private chats and
/// groups. Saying so here is kinder than refusing after the choice.
Future<String?> showForwardSheet(
  BuildContext context, {
  required AppController controller,
  required int count,
  bool hasVideo = false,
}) {
  return showAppSheet<String>(
    context: context,
    builder: (context) =>
        _ForwardList(targets: forwardTargets(controller), count: count, hasVideo: hasVideo),
  );
}

class _ForwardList extends StatefulWidget {
  const _ForwardList({required this.targets, required this.count, required this.hasVideo});

  final List<ForwardTarget> targets;
  final int count;
  final bool hasVideo;

  @override
  State<_ForwardList> createState() => _ForwardListState();
}

class _ForwardListState extends State<_ForwardList> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final shown = [
      for (final t in widget.targets)
        if (q.isEmpty || t.title.toLowerCase().contains(q)) t,
    ];
    final maxHeight = MediaQuery.sizeOf(context).height * 0.42;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.l10n.fwdTitle(widget.count),
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        TextField(
          key: const Key('forward-search'),
          onChanged: (v) => setState(() => _query = v),
          decoration: InputDecoration(
            hintText: context.l10n.fwdSearchHint,
            prefixIcon: Icon(Icons.search_rounded),
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        if (shown.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              widget.targets.isEmpty
                  ? context.l10n.fwdNoTargets
                  : context.l10n.fwdNoMatch(_query),
              textAlign: TextAlign.center,
              style: TextStyle(color: context.palette.textMuted, height: 1.4),
            ),
          )
        else
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: ListView.builder(
              shrinkWrap: true,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              itemCount: shown.length,
              itemBuilder: (context, i) {
                final t = shown[i];
                final conv = t.conversation;
                final blocked = widget.hasVideo && conv.type == ConversationType.room;
                return ListTile(
                  key: Key('forward-target-${conv.id}'),
                  enabled: !blocked,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  leading: switch (conv.type) {
                    ConversationType.direct => PeerAvatar(name: t.title, seed: conv.peerId!, size: 40),
                    ConversationType.group =>
                      PeerAvatar(name: t.title, seed: conv.groupId!, size: 40, kind: AvatarKind.group),
                    ConversationType.room =>
                      PeerAvatar(name: t.title, seed: conv.roomId!, size: 40, kind: AvatarKind.room),
                  },
                  title: Text(conv.type == ConversationType.room ? isolatedIn(context, t.title) : t.title,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    blocked
                        ? context.l10n.fwdNoVideoInRooms
                        : switch (conv.type) {
                            ConversationType.direct => context.l10n.fwdPrivateChat,
                            ConversationType.group => context.l10n.chatFallbackGroup,
                            ConversationType.room => context.l10n.fwdPublicRoom,
                          },
                    style: TextStyle(
                      color: conv.type == ConversationType.room
                          ? context.palette.pending
                          : context.palette.textMuted,
                      fontSize: 12.5,
                    ),
                  ),
                  onTap: blocked ? null : () => Navigator.pop(context, conv.id),
                );
              },
            ),
          ),
      ],
    );
  }
}
