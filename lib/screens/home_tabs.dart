import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../app_scope.dart';
import '../core/bidi.dart';
import '../core/format.dart';
import '../models/conversation.dart';
import '../models/group.dart';
import '../protocol/room_record.dart';
import '../services/message_service.dart';
import '../theme/app_theme.dart';
import '../theme/surfaces.dart';
import '../widgets/empty_state.dart';
import '../widgets/ghost_mark.dart' show GhostMood;
import '../widgets/peer_avatar.dart';
import '../widgets/prompts.dart';
import '../widgets/status_pill.dart';
import 'chat_screen.dart';
import 'contacts_screen.dart';
import 'create_group_screen.dart';
import '../l10n/l10n.dart';

/// Whether [query] is part of any of the [haystack] texts (ignoring case).
bool _matches(String query, Iterable<String?> haystack) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  return haystack.any((s) => s != null && s.toLowerCase().contains(q));
}

/// One row of a conversation list: avatar, name, last message, time and the
/// unread count. A flat row on the page, as in Telegram: no card, no border.
class ConversationTile extends StatelessWidget {
  const ConversationTile({
    super.key,
    required this.conversation,
    required this.avatar,
    this.title,
    this.subtitleOverride,
    this.onLongPress,
    this.trailingExtra,
  });

  final Conversation conversation;
  final Widget avatar;
  final String? title;
  final String? subtitleOverride;
  final VoidCallback? onLongPress;
  final Widget? trailingExtra;

  @override
  Widget build(BuildContext context) {
    final unread = conversation.unreadCount;
    final time = conversation.lastMessageAtMs ?? conversation.createdAtMs;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        key: Key('conversation-${conversation.id}'),
        onTap: () => openConversation(context, conversation.id),
        onLongPress: onLongPress,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSizes.listRow),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.l, vertical: 10),
            child: Row(
              children: [
                avatar,
                const SizedBox(width: AppSpace.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              conversation.isRoom
                                  ? isolatedIn(context, title ?? conversation.title)
                                  : (title ?? conversation.title),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontWeight: unread > 0 ? FontWeight.w700 : FontWeight.w600,
                                  fontSize: 16.5),
                            ),
                          ),
                          const SizedBox(width: AppSpace.s),
                          Text(
                            formatListTime(time, context.l10n),
                            style: TextStyle(
                              fontSize: 12.5,
                              color: unread > 0 ? context.palette.accentSoft : context.palette.textMuted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              subtitleOverride ??
                                  conversation.previewIn(context.l10n) ??
                                  context.l10n.homeNoMessagesYet,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: unread > 0 ? context.palette.textSecondary : context.palette.textMuted,
                                  fontSize: 14.5),
                            ),
                          ),
                          ?trailingExtra,
                          if (unread > 0)
                            Padding(
                                padding: const EdgeInsetsDirectional.only(start: AppSpace.s),
                                child: UnreadBadge(unread)),
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
    );
  }
}

// =============================================================================
// Private
// =============================================================================

/// Private chats, plus a strip of the people who can be reached right now.
class PrivateTab extends StatelessWidget {
  const PrivateTab({super.key, required this.query});

  final ValueListenable<String> query;

  @override
  Widget build(BuildContext context) {
    final c = AppScope.read(context);
    return ValueListenableBuilder<String>(
      valueListenable: query,
      builder: (context, q, _) => ValueListenableBuilder<List<Conversation>>(
        valueListenable: c.conversationsListenable,
        builder: (context, all, _) => ValueListenableBuilder<List<PeerView>>(
          valueListenable: c.peersListenable,
          builder: (context, peers, _) {
            final l = context.l10n;
            final byId = {for (final v in peers) v.peer.id: v};
            final chats = all
                .where((x) => x.isDirect)
                .where((x) => _matches(q, [x.title, x.previewIn(l)]))
                .toList();
            final available = peers.where((p) => p.isReachable && !p.peer.blocked).toList();
            final chatPeerIds = {for (final x in all) if (x.isDirect) x.peerId};
            final others = q.trim().isEmpty
                ? const <PeerView>[]
                : peers
                    .where((v) =>
                        !chatPeerIds.contains(v.peer.id) &&
                        !v.peer.blocked &&
                        _matches(q, [v.peer.displayName]))
                    .toList();
            // The strip of available people only shows when nothing is searched for.
            final stripShown = available.isNotEmpty && q.trim().isEmpty;
            if (chats.isEmpty && others.isEmpty && !stripShown) {
              return EmptyState(
                mood: q.trim().isEmpty ? GhostMood.sleepy : GhostMood.oops,
                title: q.trim().isEmpty ? context.l10n.homePrivateEmptyTitle : context.l10n.homeNothingFound,
                message: q.trim().isEmpty
                    ? context.l10n.homePrivateEmptyBody
                    : context.l10n.homeNoMatchChat(q),
                action: q.trim().isEmpty
                    ? OutlinedButton.icon(
                        key: const Key('see-people'),
                        onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(builder: (_) => const ContactsScreen())),
                        icon: const Icon(Icons.people_outline_rounded),
                        label: Text(context.l10n.homeSeePeople),
                      )
                    : null,
              );
            }
            return ListView(
              // The search field is above these lists: scrolling them puts the keyboard away.
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.only(top: 4, bottom: 96),
              children: [
                if (stripShown) _AvailableStrip(peers: available),
                for (final conv in chats)
                  ConversationTile(
                    conversation: conv,
                    avatar: PeerAvatar(
                      name: conv.title,
                      seed: conv.peerId ?? conv.id,
                      status: byId[conv.peerId]?.status,
                    ),
                    title: byId[conv.peerId]?.peer.displayName,
                    onLongPress: () => confirmAndRun(
                      context,
                      title: context.l10n.homeDeleteChatTitle,
                      message: context.l10n.homeDeleteChatBody,
                      action: context.l10n.commonDelete,
                      run: () => c.deleteConversation(conv.id),
                    ),
                  ),
                if (others.isNotEmpty) ...[
                  _SectionLabel(context.l10n.homePeople),
                  for (final v in others)
                    Material(
                      type: MaterialType.transparency,
                      child: InkWell(
                        onTap: () => openChatWith(context, v.peer.id),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpace.l, vertical: 8),
                          child: Row(
                            children: [
                              PeerAvatar(
                                  name: v.peer.displayName, seed: v.peer.id, status: v.status),
                              const SizedBox(width: AppSpace.m),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(v.peer.displayName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600, fontSize: 16.5)),
                                    Text(reachabilityShort(context.l10n, v.status),
                                        style: TextStyle(
                                            color: reachabilityColor(v.status.reachability, context.palette),
                                            fontSize: 13)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AvailableStrip extends StatelessWidget {
  const _AvailableStrip({required this.peers});

  final List<PeerView> peers;

  @override
  Widget build(BuildContext context) {
    // The two text lines under each avatar grow with the system font size.
    final textScale = (MediaQuery.textScalerOf(context).scale(14) / 14).clamp(1.0, 3.0);
    final height = 64 + 36 * textScale;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(context.l10n.homeAvailableNow),
        SizedBox(
          height: height,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.m),
            itemCount: peers.length,
            separatorBuilder: (context, index) => const SizedBox(width: AppSpace.s),
            itemBuilder: (context, i) {
              final v = peers[i];
              return InkWell(
                key: Key('available-${v.peer.id}'),
                borderRadius: BorderRadius.circular(AppRadii.md),
                onTap: v.peer.canReceiveEncrypted ? () => openChatWith(context, v.peer.id) : null,
                child: SizedBox(
                  width: 76,
                  child: Column(
                    children: [
                      PeerAvatar(
                          name: v.peer.displayName, seed: v.peer.id, status: v.status, size: 58),
                      const SizedBox(height: 6),
                      Text(v.peer.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12.5)),
                      Text(reachabilityShort(context.l10n, v.status),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 11, color: reachabilityColor(v.status.reachability, context.palette))),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 6),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(AppSpace.l, 12, AppSpace.l, 6),
        child: Text(text,
            style: TextStyle(
                color: context.palette.accentSoft, fontWeight: FontWeight.w700, fontSize: 13.5)),
      );
}

// =============================================================================
// Groups
// =============================================================================

/// Group chats, and the invitations waiting to be accepted.
class GroupsTab extends StatelessWidget {
  const GroupsTab({super.key, required this.query});

  final ValueListenable<String> query;

  @override
  Widget build(BuildContext context) {
    final c = AppScope.read(context);
    return ValueListenableBuilder<String>(
      valueListenable: query,
      builder: (context, q, _) => ValueListenableBuilder<List<GroupChat>>(
        valueListenable: c.groupsListenable,
        builder: (context, groups, _) => ValueListenableBuilder<List<Conversation>>(
          valueListenable: c.conversationsListenable,
          builder: (context, all, _) {
            final invites = groups
                .where((g) => g.state == GroupState.invited)
                .where((g) => _matches(q, [g.name]))
                .toList();
            final l = context.l10n;
            final byId = {for (final g in groups) g.id: g};
            final chats = all
                .where((x) => x.isGroup)
                .where((x) => _matches(q, [x.title, x.previewIn(l)]))
                .toList();
            if (invites.isEmpty && chats.isEmpty) {
              return EmptyState(
                mood: q.trim().isEmpty ? GhostMood.sleepy : GhostMood.oops,
                title: q.trim().isEmpty ? context.l10n.homeGroupsEmptyTitle : context.l10n.homeNothingFound,
                message: q.trim().isEmpty
                    ? context.l10n.homeGroupsEmptyBody
                    : context.l10n.homeNoMatchGroup(q),
                action: q.trim().isEmpty
                    ? FilledButton.icon(
                        key: const Key('empty-create-group'),
                        onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(builder: (_) => const CreateGroupScreen())),
                        icon: const Icon(Icons.group_add_rounded),
                        label: Text(context.l10n.homeCreateGroup),
                      )
                    : null,
              );
            }
            return ListView(
              // The search field is above these lists: scrolling them puts the keyboard away.
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.only(top: 4, bottom: 96),
              children: [
                if (invites.isNotEmpty) ...[
                  _SectionLabel(context.l10n.homeInvitations(invites.length)),
                  for (final g in invites) _InviteCard(group: g),
                ],
                if (chats.isNotEmpty && invites.isNotEmpty) _SectionLabel(context.l10n.homeYourGroups),
                for (final conv in chats)
                  Builder(builder: (context) {
                    final g = byId[conv.groupId];
                    final inactive = g != null && !g.isActive;
                    return ConversationTile(
                      conversation: conv,
                      avatar: PeerAvatar(
                          name: conv.title, seed: conv.groupId ?? conv.id, kind: AvatarKind.group),
                      title: g?.name,
                      subtitleOverride: inactive
                          ? (g.state == GroupState.left ? context.l10n.homeYouLeft : context.l10n.homeYouWereRemoved)
                          : null,
                      onLongPress: () => confirmAndRun(
                        context,
                        title: g != null && g.isActive
                            ? (g.adminId == c.identityId ? context.l10n.homeDeleteGroupTitle : context.l10n.homeLeaveGroupTitle)
                            : context.l10n.homeDeleteThisChatTitle,
                        message: g != null && g.isActive
                            ? (g.adminId == c.identityId
                                ? context.l10n.homeDeleteGroupBody
                                : context.l10n.homeLeaveGroupBody)
                            : context.l10n.homeDeleteThisChatBody,
                        action: context.l10n.commonContinue,
                        run: () => c.removeGroupFromPhone(conv.groupId!),
                      ),
                    );
                  }),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _InviteCard extends StatelessWidget {
  const _InviteCard({required this.group});

  final GroupChat group;

  @override
  Widget build(BuildContext context) {
    final c = AppScope.read(context);
    final inviter = group.invitedBy == null
        ? null
        : c.peersListenable.value.where((v) => v.peer.id == group.invitedBy).firstOrNull;
    final name = inviter?.peer.displayName ??
        group.members
            .where((m) => m.id == group.invitedBy)
            .map((m) => m.nickname)
            .firstOrNull ??
        context.l10n.homeSomeone;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.m, vertical: 4),
      child: AppPanel(
        key: Key('invite-${group.id}'),
        radius: AppRadii.lg,
        tint: context.palette.accent,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                PeerAvatar(name: group.name, seed: group.id, size: 46, kind: AvatarKind.group),
                const SizedBox(width: AppSpace.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(group.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16.5)),
                      Text(context.l10n.homeInvitedYou(name, group.members.length),
                          style: TextStyle(color: context.palette.textSecondary, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.m),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: Key('decline-${group.id}'),
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        await c.declineGroup(group.id);
                      } on MessageError catch (e) {
                        messenger.showSnackBar(SnackBar(content: Text(e.message)));
                      }
                    },
                    child: Text(context.l10n.commonDecline),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    key: Key('accept-${group.id}'),
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final navigator = Navigator.of(context);
                      try {
                        final g = await c.acceptGroup(group.id);
                        await navigator.push(MaterialPageRoute<void>(
                          builder: (_) =>
                              ChatScreen(conversationId: Conversation.groupConversationId(g.id)),
                        ));
                      } on MessageError catch (e) {
                        messenger.showSnackBar(SnackBar(content: Text(e.message)));
                      }
                    },
                    child: Text(context.l10n.commonAccept),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The #mesh room's id, for places that need it.
const String meshRoomId = PublicRooms.meshIdHex;

/// Everything the home screen's floating button can start.
Future<void> startNewPrivateChat(BuildContext context) => pickPeerAndChat(context);

Future<void> startNewGroup(BuildContext context) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const CreateGroupScreen()));
