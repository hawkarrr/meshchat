import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../app_scope.dart';
import '../core/bidi.dart';
import '../models/conversation.dart';
import '../models/media.dart';
import '../models/message.dart';
import '../models/room.dart';
import '../services/message_service.dart';
import '../theme/app_theme.dart';
import '../theme/surfaces.dart';
import '../widgets/chat_header.dart';
import '../widgets/composer.dart';
import '../widgets/connection_indicator.dart';
import '../widgets/date_chip.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_strip.dart';
import '../widgets/ghost_mark.dart';
import '../widgets/message_bubble.dart';
import '../widgets/message_menu.dart' show SelectionBar;
import '../widgets/min_touch.dart';
import '../widgets/peer_avatar.dart';
import '../widgets/prompts.dart';
import '../widgets/quote_views.dart';
import '../widgets/radio_status_banner.dart';
import '../widgets/reveal.dart';
import '../widgets/skeleton.dart';
import 'conversation_actions.dart';
import 'conversation_feed.dart';
import 'discovery_screen.dart';
import 'image_viewer_screen.dart';
import 'message_search_screen.dart';
import 'rooms_sheet.dart';
import '../l10n/l10n.dart';

/// The screen for the public room with this id.
Widget openRoomPage(String roomId) => RoomScreen(conversationId: Conversation.roomConversationId(roomId));

/// A public room on a page of its own: opened from a notification, a search or a
/// forwarded message. Back returns to where the person was. (Among the tabs the same
/// room is [RoomChat], the first place of the home screen.)
class RoomScreen extends StatelessWidget {
  const RoomScreen({super.key, required this.conversationId});

  final String conversationId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: AppBackground(
        child: RoomChat(
          conversationId: conversationId,
          // Another room replaces this page instead of piling up behind it.
          onSwitchRoom: (target) => Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(builder: (_) => RoomScreen(conversationId: target)),
          ),
        ),
      ),
    );
  }
}

/// A public room as a conversation, in the manner of a group chat: the room's name at
/// the top (it opens the list of rooms), the messages as bubbles with the writer's name
/// in their colour, and the composer below. Everything said here is visible to every
/// phone that carries it, and the screen says so: in the line under the name, in the
/// field's hint and in the empty room.
///
/// It is the first place of the home screen ([embedded]) and also a page of its own
/// ([RoomScreen]). It shows a skeleton while the messages are read, the empty room
/// when there are none, and an error with a retry button when they cannot be read.
class RoomChat extends StatefulWidget {
  const RoomChat({
    super.key,
    required this.conversationId,
    required this.onSwitchRoom,
    this.embedded = false,
    this.active = true,
  });

  final String conversationId;

  /// Another room was chosen from the list: the id of its conversation.
  final ValueChanged<String> onSwitchRoom;

  /// It is one of the tabs of the home screen: no back button, and the field floats
  /// above the bottom bar instead of sitting on a strip of its own.
  final bool embedded;

  /// The person can see it. A room kept ready behind another tab does not mark its
  /// messages as read until it comes to the front.
  final bool active;

  @override
  State<RoomChat> createState() => _RoomChatState();
}

class _RoomChatState extends State<RoomChat> with WidgetsBindingObserver {
  late final AppController _c;
  late final ConversationFeed _feed;
  late final ConversationActions _a;
  late final MessageJumper _jump;
  final ScrollController _scroll = ScrollController();
  final ValueNotifier<String?> _error = ValueNotifier<String?>(null);
  int _pinCursor = 0;
  Timer? _minute;

  String get _roomId => widget.conversationId.substring(3);

  @override
  void initState() {
    super.initState();
    _c = AppScope.read(context);
    _feed = ConversationFeed(
      _c,
      widget.conversationId,
      isActive: () => widget.active && _c.isForeground,
    )..start();
    WidgetsBinding.instance.addObserver(this);
    // Lines dim over their last hour; the clock hand moves them along.
    _minute = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
    _jump = MessageJumper(_scroll);
    _a = ConversationActions(
      controller: _c,
      conversationId: widget.conversationId,
      feed: _feed.state,
      contextOf: () => context,
      isMounted: () => mounted,
      canSend: () => _c.rooms.where((r) => r.id == _roomId).firstOrNull?.joined ?? true,
      onError: (m) => _error.value = m,
      onJump: (id) => _jump.jumpTo(id, _feed.state.value.messages),
    )..start();
  }

  @override
  void didUpdateWidget(RoomChat oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Coming to the front: what arrived meanwhile has now been seen.
    if (widget.active && !oldWidget.active) _feed.markRead();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.active) _feed.markRead();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _minute?.cancel();
    _a.dispose();
    _jump.dispose();
    _feed.dispose();
    _scroll.dispose();
    _error.dispose();
    super.dispose();
  }

  PublicRoom? _roomOf(List<PublicRoom> rooms) => rooms.where((r) => r.id == _roomId).firstOrNull;

  Future<void> _search() async {
    final label = _roomOf(_c.rooms)?.label ?? '#room';
    final id = await Navigator.of(context).push<String>(MaterialPageRoute<String>(
      builder: (_) => MessageSearchScreen(
        conversationId: widget.conversationId,
        title: isolatedIn(context, label),
        authorOf: _a.authorOf,
      ),
    ));
    if (id != null && mounted) await _a.jumpTo(id);
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

  void _openNearby() => Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => const DiscoveryScreen()));

  Future<void> _rename() async {
    final name = await showTextPrompt(
      context,
      title: context.l10n.roomYourNameTitle,
      message: context.l10n.roomYourNameBody,
      initial: _c.nickname,
      fieldKey: const Key('nickname-field'),
      confirmKey: const Key('nickname-save'),
    );
    if (name != null) await _c.setNickname(name);
  }

  Future<void> _pickRoom() async {
    final target = await showRoomsSheet(context, currentRoomId: _roomId);
    if (target == null || !mounted || target == widget.conversationId) return;
    widget.onSwitchRoom(target);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Set<String>>(
      valueListenable: _a.selection,
      builder: (context, selected, child) => PopScope(
        // Back first leaves the selection, then the room.
        canPop: selected.isEmpty,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _a.clearSelection();
        },
        child: child!,
      ),
      child: Column(
        children: [
          _top(),
          const RadioStatusBanner(),
          _infoStrip(),
          _pinned(),
          Expanded(child: _body()),
          ValueListenableBuilder<String?>(
            valueListenable: _error,
            builder: (context, error, _) => error == null
                ? const SizedBox.shrink()
                : ErrorStrip(message: error, onClose: () => _error.value = null),
          ),
          _composer(),
        ],
      ),
    );
  }

  // ---- top ---------------------------------------------------------------------

  /// The selection bar while messages are selected, the room's header otherwise.
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

  Widget _header() {
    return ValueListenableBuilder<List<PublicRoom>>(
      valueListenable: _c.roomsListenable,
      builder: (context, rooms, _) {
        final room = _roomOf(rooms);
        final label = room?.label ?? '#room';
        return ValueListenableBuilder<NetworkSnapshot>(
          valueListenable: _c.networkListenable,
          builder: (context, n, _) {
            final s = ConnectionSummary.of(n, context.l10n, context.palette);
            return ChatHeader(
              avatar: PeerAvatar(
                name: room?.name ?? label,
                seed: _roomId,
                kind: AvatarKind.room,
                size: AppSizes.avatarHeader,
              ),
              title: isolatedIn(context, label),
              titleKey: const Key('room-label'),
              // The arrow says the name opens the list of rooms.
              titleSuffix: Padding(
                padding: EdgeInsetsDirectional.only(start: 2),
                child: Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: context.palette.textMuted),
              ),
              onTap: _pickRoom,
              // How we are connected, at a glance: the colour and the words.
              subtitleWidget: Row(
                key: const Key('room-connection'),
                children: [
                  Icon(s.icon, size: 13, color: s.color),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      s.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, height: 1.3, color: s.color),
                    ),
                  ),
                ],
              ),
              actions: [
                RoundButton(
                  key: const Key('room-search'),
                  icon: Icons.search_rounded,
                  tooltip: context.l10n.roomSearchTooltip,
                  flat: true,
                  onPressed: _search,
                ),
                Tooltip(
                  message: s.label,
                  child: InkWell(
                    key: const Key('room-people'),
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                    onTap: _openNearby,
                    child: MinTouch(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.people_alt_rounded,
                                size: 18, color: context.palette.textSecondary),
                            const SizedBox(width: 4),
                            Text('${n.reachableCount}',
                                style: TextStyle(
                                    color: context.palette.textSecondary, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Under the header: what makes this room different (what is said fades away, as
  /// ghosts do), and the name it is said under, which can be changed.
  Widget _infoStrip() {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(AppSpace.l, 0, AppSpace.s, 0),
      child: Row(
        children: [
          const GhostMark(size: 18),
          const SizedBox(width: AppSpace.s),
          Expanded(
            child: Text(
              context.l10n.roomExpiryNote,
              key: const Key('room-expiry-note'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: context.palette.textMuted, fontSize: 11.5),
            ),
          ),
          InkWell(
            key: const Key('room-nickname'),
            borderRadius: BorderRadius.circular(AppRadii.sm),
            onTap: _rename,
            child: MinTouch(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: AnimatedBuilder(
                  animation: _c,
                  builder: (context, _) => ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: (MediaQuery.sizeOf(context).width * 0.4).clamp(96.0, 200.0),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            isolatedIn(context, '@${_c.nickname}'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: context.palette.accentSoft,
                                fontWeight: FontWeight.w600,
                                fontSize: 13),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.edit_rounded, size: 13, color: context.palette.accentSoft),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pinned() {
    return ValueListenableBuilder<FeedState>(
      valueListenable: _feed.state,
      builder: (context, feed, _) {
        final pinned = feed.pinned;
        final cursor = pinned.isEmpty ? 0 : _pinCursor % pinned.length;
        return Reveal(
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
        );
      },
    );
  }

  // ---- bottom ------------------------------------------------------------------

  Widget _composer() {
    return ValueListenableBuilder<List<PublicRoom>>(
      valueListenable: _c.roomsListenable,
      builder: (context, rooms, _) {
        final room = _roomOf(rooms);
        return ChatComposer(
          style: ComposerStyle.public,
          docked: !widget.embedded,
          hint: context.l10n.roomComposerHint(isolatedIn(context, room?.label ?? '#room')),
          enabled: room?.joined ?? true,
          disabledHint: context.l10n.roomJoinToPost,
          target: _a.target,
          onSendText: _sendText,
          onSendDraft: _sendDraft,
          onError: (m) => _error.value = m,
        );
      },
    );
  }

  // ---- messages ----------------------------------------------------------------

  Widget _body() {
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
          return EmptyState(
            key: const Key('room-empty'),
            mood: GhostMood.sleepy,
            title: context.l10n.homeNoMessagesYet,
            message: context.l10n.roomEmpty,
          );
        }
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
              // Dragging the room puts the keyboard away, as in every messenger.
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.symmetric(vertical: AppSpace.s),
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
                    PublicLine(
                      message: m,
                      media: media,
                      controller: _c,
                      onRetry: m.status == MessageStatus.failed ? () => _retry(m) : null,
                      onOpenImage: (bytes) => Navigator.of(context).push(MaterialPageRoute<void>(
                        builder: (_) =>
                            ImageViewerScreen(bytes: bytes, title: m.senderNickname ?? ''),
                      )),
                      onTap: () => _a.onTap(m, media),
                      onLongPress: () => _a.onLongPress(m, media),
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

/// How strongly a message of the public room is drawn: fully until the last hour of
/// its six, then a little less every minute, down to one half at the moment it is
/// removed. Nothing here is announced; the message only grows faint, which is how one
/// that is about to go looks.
double publicLineOpacity(int nowMs, int? expiresAtMs) {
  if (expiresAtMs == null) return 1;
  const hour = 60 * 60 * 1000;
  final left = expiresAtMs - nowMs;
  if (left >= hour) return 1;
  return 0.5 + 0.5 * (left < 0 ? 0 : left) / hour;
}

/// One message in the public room: the ordinary bubble, with the writer's name and the
/// first characters of their id on top (two people can have the same name here), and
/// dimmed when it is about to disappear.
class PublicLine extends StatelessWidget {
  const PublicLine({
    super.key,
    required this.message,
    required this.media,
    required this.controller,
    this.onRetry,
    this.onOpenImage,
    this.onTap,
    this.onLongPress,
    this.quote,
    this.onQuoteTap,
    this.selecting = false,
    this.selected = false,
    this.pinned = false,
    this.highlighted = false,
    this.nowMs,
  });

  /// The time the message is judged at, to dim it near its end; the controller's clock
  /// when not given.
  final int? nowMs;

  /// How many lines were built; the keyboard tests use it to prove that the
  /// keyboard opening does not rebuild the room.
  @visibleForTesting
  static int debugBuilds = 0;

  final ChatMessage message;
  final MediaItem? media;
  final AppController controller;
  final VoidCallback? onRetry;
  final void Function(Uint8List bytes)? onOpenImage;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final QuoteData? quote;
  final VoidCallback? onQuoteTap;
  final bool selecting;
  final bool selected;
  final bool pinned;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    assert(() {
      debugBuilds++;
      return true;
    }());
    final m = message;
    final mine = m.isOutgoing;
    return MessageBubble(
      message: m,
      controller: controller,
      media: media,
      showSender: true,
      senderName: mine ? controller.nickname : (m.senderNickname ?? m.senderId.substring(0, 8)),
      // Names are not unique: the first characters of the id tell two "Alex" apart.
      senderTag: mine ? null : '#${m.senderId.substring(0, 4)}',
      onRetry: onRetry,
      onTap: onTap,
      onLongPress: onLongPress,
      onOpenImage: onOpenImage,
      quote: quote,
      onQuoteTap: onQuoteTap,
      selecting: selecting,
      selected: selected,
      pinned: pinned,
      highlighted: highlighted,
      fade: publicLineOpacity(nowMs ?? controller.clock.nowMs, m.expiresAtMs),
    );
  }
}
