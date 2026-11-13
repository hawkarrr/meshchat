import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../app_scope.dart';
import '../models/conversation.dart';
import '../models/group.dart';
import '../models/message.dart';
import '../models/peer.dart';
import '../services/message_service.dart';
import '../theme/app_theme.dart';
import '../theme/surfaces.dart';
import '../widgets/chat_header.dart';
import '../widgets/composer.dart';
import '../widgets/date_chip.dart';
import '../widgets/empty_state.dart' show ChatIntro, ErrorState;
import '../widgets/error_strip.dart';
import '../widgets/message_bubble.dart';
import '../widgets/message_menu.dart';
import '../widgets/peer_avatar.dart';
import '../widgets/quote_views.dart';
import '../widgets/radio_status_banner.dart';
import '../widgets/reveal.dart';
import '../widgets/skeleton.dart';
import '../widgets/status_pill.dart';
import 'conversation_actions.dart';
import 'conversation_feed.dart';
import 'group_detail_screen.dart';
import 'image_viewer_screen.dart';
import 'message_search_screen.dart';
import 'peer_detail_screen.dart';
import 'room_screen.dart';
import '../l10n/l10n.dart';

/// Opens the right screen for a conversation: the Telegram-style chat for
/// private chats and groups, the public-room view for rooms.
Future<void> openConversation(BuildContext context, String conversationId) {
  final page = conversationId.startsWith('rm:')
      ? RoomScreen(conversationId: conversationId)
      : ChatScreen(conversationId: conversationId);
  return Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
}

/// Opens (creating if needed) the private chat with [peerId].
Future<void> openChatWith(BuildContext context, String peerId) async {
  final c = AppScope.read(context);
  final navigator = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);
  try {
    final Conversation conversation = await c.openChat(peerId);
    await navigator.push(MaterialPageRoute<void>(
      builder: (_) => ChatScreen(conversationId: conversation.id),
    ));
  } on MessageError catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
  }
}

/// A private chat or a group chat.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.conversationId});

  final String conversationId;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final AppController _c;
  late final ConversationFeed _feed;
  late final ConversationActions _a;
  late final MessageJumper _jump;
  final ScrollController _scroll = ScrollController();
  final ValueNotifier<String?> _error = ValueNotifier<String?>(null);
  int _pinCursor = 0;

  bool get _isGroup => widget.conversationId.startsWith('gr:');

  String get _refId => widget.conversationId.substring(3);

  @override
  void initState() {
    super.initState();
    _c = AppScope.read(context);
    _feed = ConversationFeed(_c, widget.conversationId)..start();
    _jump = MessageJumper(_scroll);
    _a = ConversationActions(
      controller: _c,
      conversationId: widget.conversationId,
      feed: _feed.state,
      contextOf: () => context,
      isMounted: () => mounted,
      canSend: _canSend,
      onError: (m) => _error.value = m,
      onJump: (id) => _jump.jumpTo(id, _feed.state.value.messages),
    )..start();
  }

  @override
  void dispose() {
    _a.dispose();
    _jump.dispose();
    _feed.dispose();
    _scroll.dispose();
    _error.dispose();
    super.dispose();
  }

  /// Whether this person can write here right now.
  bool _canSend() {
    if (_isGroup) {
      return _c.groups.where((g) => g.id == _refId).firstOrNull?.isActive ?? false;
    }
    return !(_c.peers.where((p) => p.peer.id == _refId).firstOrNull?.peer.blocked ?? false);
  }

  void _scrollToEnd() {
    if (_scroll.hasClients) {
      unawaited(_scroll.animateTo(0,
          duration: const Duration(milliseconds: 200), curve: Curves.easeOut));
    }
  }

  Future<void> _sendText(String text) async {
    _error.value = null;
    await _a.sendText(text);
    _scrollToEnd();
  }

  Future<void> _sendDraft(MediaDraft draft) async {
    _error.value = null;
    await _a.sendDraft(draft);
    _scrollToEnd();
  }

  Future<void> _retry(ChatMessage m) async {
    try {
      await _c.retry(m.id);
    } on MessageError catch (e) {
      _error.value = e.message;
    }
  }

  void _openImage(Uint8List bytes, String title) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ImageViewerScreen(bytes: bytes, title: title),
    ));
  }

  Future<void> _search() async {
    final title =
        _c.conversations.where((c) => c.id == widget.conversationId).firstOrNull?.title ?? context.l10n.chatFallbackLower;
    final id = await Navigator.of(context).push<String>(MaterialPageRoute<String>(
      builder: (_) => MessageSearchScreen(
        conversationId: widget.conversationId,
        title: title,
        authorOf: _a.authorOf,
      ),
    ));
    if (id != null && mounted) await _a.jumpTo(id);
  }

  // ---- header ------------------------------------------------------------------

  Widget _searchButton() => RoundButton(
        key: const Key('chat-search'),
        icon: Icons.search_rounded,
        tooltip: context.l10n.chatSearchTooltip,
        flat: true,
        onPressed: _search,
      );

  Widget _header() {
    if (_isGroup) {
      return ValueListenableBuilder<List<GroupChat>>(
        valueListenable: _c.groupsListenable,
        builder: (context, groups, _) {
          final group = groups.where((g) => g.id == _refId).firstOrNull;
          return ValueListenableBuilder<List<PeerView>>(
            valueListenable: _c.peersListenable,
            builder: (context, peers, _) {
              final title = group?.name ?? context.l10n.chatFallbackGroup;
              var nearby = 0;
              if (group != null) {
                for (final v in peers) {
                  if (v.isReachable && group.hasMember(v.peer.id)) nearby++;
                }
              }
              final subtitle = group == null
                  ? ''
                  : switch (group.state) {
                      GroupState.active => nearby > 0
                          ? context.l10n.chatGroupMembersNearby(group.members.length, nearby)
                          : context.l10n.chatGroupMembers(group.members.length),
                      GroupState.left => context.l10n.homeYouLeft,
                      GroupState.removed => context.l10n.homeYouWereRemoved,
                      GroupState.invited => context.l10n.chatInvitation,
                    };
              return ChatHeader(
                avatar: PeerAvatar(
                    name: title,
                    seed: _refId,
                    size: AppSizes.avatarHeader,
                    kind: AvatarKind.group),
                title: title,
                subtitle: subtitle,
                onTap: group == null ? null : () => _openGroupDetails(),
                actions: [
                  _searchButton(),
                  RoundButton(
                    key: const Key('group-info'),
                    icon: Icons.info_outline_rounded,
                    tooltip: context.l10n.chatGroupDetails,
                    flat: true,
                    onPressed: group == null ? null : _openGroupDetails,
                  ),
                ],
              );
            },
          );
        },
      );
    }
    return ValueListenableBuilder<List<PeerView>>(
      valueListenable: _c.peersListenable,
      builder: (context, peers, _) {
        final view = peers.where((p) => p.peer.id == _refId).firstOrNull;
        final title = view?.peer.displayName ?? context.l10n.chatFallbackChat;
        return ChatHeader(
          avatar: PeerAvatar(
            name: title,
            seed: _refId,
            status: view?.status,
            size: AppSizes.avatarHeader,
            ringColor: context.palette.surface,
          ),
          title: title,
          subtitle: view == null ? '' : reachabilityLabel(context.l10n, view.status),
          subtitleColor:
              view == null ? context.palette.textMuted : reachabilityColor(view.status.reachability, context.palette),
          onTap: view == null ? null : _openPeerDetails,
          actions: [
            _searchButton(),
            if (view != null)
              RoundButton(
                key: const Key('verify-contact'),
                icon: view.peer.verified ? Icons.verified_user_rounded : Icons.shield_outlined,
                color: view.peer.verified ? context.palette.accentSoft : context.palette.textMuted,
                tooltip: view.peer.verified ? context.l10n.chatVerifiedContact : context.l10n.chatVerifyContact,
                flat: true,
                onPressed: _openPeerDetails,
              ),
          ],
        );
      },
    );
  }

  void _openPeerDetails() => Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => PeerDetailScreen(peerId: _refId)));

  void _openGroupDetails() => Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => GroupDetailScreen(groupId: _refId)));

  /// The selection bar while messages are selected, the normal header otherwise.
  Widget _top() {
    return ValueListenableBuilder<Set<String>>(
      valueListenable: _a.selection,
      builder: (context, selected, _) => selected.isEmpty
          ? _header()
          : SelectionBar(
              count: selected.length,
              onClose: _a.clearSelection,
              onForward: _a.canForwardSelected ? _a.forwardSelected : null,
              onDelete: _a.deleteSelected,
              more: _a.selectionMenu(),
            ),
    );
  }

  /// The pinned message and the honest note about delete requests still on
  /// their way.
  Widget _strips() {
    return ValueListenableBuilder<FeedState>(
      valueListenable: _feed.state,
      builder: (context, feed, _) {
        final pinned = feed.pinned;
        final cursor = pinned.isEmpty ? 0 : _pinCursor % pinned.length;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Reveal(
              show: pinned.isNotEmpty,
              child: pinned.isEmpty
                  ? const SizedBox.shrink()
                  : PinnedBanner(
                      message: pinned[cursor],
                      author: _a.authorOf(pinned[cursor]),
                      index: cursor,
                      count: pinned.length,
                      onTap: () {
                        final target = pinned[cursor];
                        setState(() => _pinCursor = (cursor + 1) % pinned.length);
                        unawaited(_a.jumpTo(target.id));
                      },
                      onList: _a.openPinnedList,
                    ),
            ),
            if (!_isGroup)
              DeletionStatusStrip(
                counts: feed.deletions,
                otherName: _c.peers.where((p) => p.peer.id == _refId).firstOrNull?.peer.displayName ??
                    context.l10n.chatTheOtherPerson,
              ),
          ],
        );
      },
    );
  }

  // ---- body --------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Set<String>>(
      valueListenable: _a.selection,
      builder: (context, selected, child) => PopScope(
        // Back first leaves the selection, then the chat.
        canPop: selected.isEmpty,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _a.clearSelection();
        },
        child: child!,
      ),
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: AppBackground(
          child: Column(
            children: [
              _top(),
              const RadioStatusBanner(),
              if (!_isGroup) _ReachabilityStrip(peerId: _refId),
              _strips(),
              Expanded(child: _messages()),
              ValueListenableBuilder<String?>(
                valueListenable: _error,
                builder: (context, error, _) => error == null
                    ? const SizedBox.shrink()
                    : ErrorStrip(message: error, onClose: () => _error.value = null),
              ),
              _composer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _composer() {
    if (_isGroup) {
      return ValueListenableBuilder<List<GroupChat>>(
        valueListenable: _c.groupsListenable,
        builder: (context, groups, _) {
          final group = groups.where((g) => g.id == _refId).firstOrNull;
          final active = group?.isActive ?? false;
          return _buildComposer(
            enabled: active,
            disabledHint: group == null || active
                ? context.l10n.composerHint
                : (group.state == GroupState.left
                    ? context.l10n.homeYouLeft
                    : context.l10n.chatRemovedFromGroup),
          );
        },
      );
    }
    return ValueListenableBuilder<List<PeerView>>(
      valueListenable: _c.peersListenable,
      builder: (context, peers, _) {
        final blocked = peers.where((p) => p.peer.id == _refId).firstOrNull?.peer.blocked ?? false;
        return _buildComposer(
          enabled: !blocked,
          disabledHint: context.l10n.chatYouBlocked,
        );
      },
    );
  }

  Widget _buildComposer({required bool enabled, required String disabledHint}) {
    return ChatComposer(
      hint: context.l10n.composerHint,
      enabled: enabled,
      disabledHint: disabledHint,
      target: _a.target,
      onSendText: _sendText,
      onSendDraft: _sendDraft,
      onError: (m) => _error.value = m,
    );
  }

  Widget _messages() {
    return ValueListenableBuilder<FeedState>(
      valueListenable: _feed.state,
      builder: (context, feed, _) {
        if (feed.failed) {
          return ErrorState(
            title: context.l10n.feedErrorTitle,
            message: context.l10n.feedErrorBody,
            onRetry: () => unawaited(_feed.reload()),
          );
        }
        if (!feed.loaded) return const ChatSkeleton();
        if (feed.messages.isEmpty) {
          final l = context.l10n;
          return ChatIntro(
            title: _isGroup
                ? l.introGroupTitle(
                    _c.groups.where((g) => g.id == _refId).firstOrNull?.name ?? l.chatFallbackGroup)
                : l.introDirectTitle(_c.peers
                        .where((p) => p.peer.id == _refId)
                        .firstOrNull
                        ?.peer
                        .displayName ??
                    l.chatTheOtherPerson),
            message: _isGroup ? l.chatEmptyGroup : l.chatEmptyDirect,
          );
        }
        final names = <String, String>{
          for (final v in _c.peersListenable.value) v.peer.id: v.peer.displayName,
        };
        final messages = feed.messages;
        final pinnedIds = feed.pinnedIds;
        _jump.prune({for (final m in messages) m.id});
        return ValueListenableBuilder<Set<String>>(
          valueListenable: _a.selection,
          builder: (context, selection, _) => ValueListenableBuilder<String?>(
            valueListenable: _jump.highlighted,
            builder: (context, highlighted, _) => ListView.builder(
              key: const Key('message-list'),
              controller: _scroll,
              reverse: true,
              // Dragging the conversation puts the keyboard away, as in every messenger.
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final i = messages.length - 1 - index;
                final m = messages[i];
                final prev = i > 0 ? messages[i - 1] : null;
                final newDay = prev == null || !sameDay(prev.sortTimeMs, m.sortTimeMs);
                final media = m.mediaId == null ? null : feed.media[m.mediaId];
                return Column(
                  key: _jump.keyFor(m.id),
                  children: [
                    if (newDay) DateChip(ms: m.sortTimeMs),
                    MessageBubble(
                      message: m,
                      controller: _c,
                      media: media,
                      showSender: _isGroup,
                      senderName: names[m.senderId] ?? m.senderNickname,
                      onRetry: m.status == MessageStatus.failed ? () => _retry(m) : null,
                      onTap: () => _a.onTap(m, media),
                      onLongPress: () => _a.onLongPress(m, media),
                      onOpenImage: (bytes) => _openImage(bytes, names[m.senderId] ?? ''),
                      quote: _a.quoteFor(m),
                      onQuoteTap: m.replyToId == null ? null : () => _a.jumpTo(m.replyToId!),
                      selecting: selection.isNotEmpty,
                      selected: selection.contains(m.id),
                      pinned: pinnedIds.contains(m.id),
                      highlighted: highlighted == m.id,
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}

/// Says honestly what will happen to a message sent right now.
class _ReachabilityStrip extends StatelessWidget {
  const _ReachabilityStrip({required this.peerId});

  final String peerId;

  @override
  Widget build(BuildContext context) {
    final c = AppScope.read(context);
    return ValueListenableBuilder<List<PeerView>>(
      valueListenable: c.peersListenable,
      builder: (context, peers, _) {
        final view = peers.where((p) => p.peer.id == peerId).firstOrNull;
        if (view == null) return const SizedBox.shrink();
        final s = view.status;
        final color = reachabilityColor(s.reachability, context.palette);
        final needsKey = !view.peer.canReceiveEncrypted;
        // Directly connected is the ordinary case, and the header already says so in
        // green: the strip is for what the person would not guess.
        if (!needsKey && s.reachability == Reachability.direct) return const SizedBox.shrink();
        final text = needsKey
            ? context.l10n.stripWaitingForKey
            : switch (s.reachability) {
                Reachability.direct => context.l10n.stripDirect,
                Reachability.relayed =>
                  context.l10n.stripRelayed(s.hops),
                Reachability.offline =>
                  context.l10n.stripOffline,
              };
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 2, 12, 2),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: needsKey ? context.palette.pending : color.withValues(alpha: 0.95),
              fontSize: 12,
              height: 1.3,
            ),
          ),
        );
      },
    );
  }
}
