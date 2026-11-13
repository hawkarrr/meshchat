import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_controller.dart';
import '../core/bidi.dart';
import '../models/conversation.dart';
import '../models/media.dart';
import '../models/message.dart';
import '../device/gallery.dart' show GalleryException;
import '../services/media_service.dart' show MediaDraft;
import '../services/message_actions.dart' show DeleteResult, MessagePolicy;
import '../services/message_service.dart' show MessageError, MessageErrorKind;
import '../theme/app_theme.dart';
import '../theme/surfaces.dart';
import '../widgets/composer_target.dart';
import '../widgets/message_menu.dart';
import '../widgets/prompts.dart';
import '../widgets/quote_views.dart';
import 'conversation_feed.dart';
import 'forward_sheet.dart';
import 'message_details.dart';
import '../l10n/l10n.dart';

/// Everything a conversation screen does with messages beyond showing them:
/// the long-press menu, selecting several, answering, editing, forwarding,
/// pinning, deleting and looking at the details. The private/group screen and
/// the public room share it, so both behave the same.
///
/// The screen owns the widgets; this owns the state (what is selected, what the
/// composer is answering or editing) and the decisions (what each person may do
/// to each message), and it talks to the [AppController].
class ConversationActions {
  ConversationActions({
    required this.controller,
    required this.conversationId,
    required this.feed,
    required this.contextOf,
    required this.isMounted,
    required this.canSend,
    required this.onError,
    required this.onJump,
  });

  final AppController controller;
  final String conversationId;
  final ValueListenable<FeedState> feed;

  /// The screen's context, and whether the screen is still on show.
  final BuildContext Function() contextOf;
  final bool Function() isMounted;

  /// Whether this person can send here right now (not blocked, still in the group).
  final bool Function() canSend;
  final void Function(String message) onError;

  /// Scrolls the conversation to a message.
  final Future<bool> Function(String messageId) onJump;

  static const MessagePolicy _policy = MessagePolicy();

  /// The ids of the selected messages. Empty means "not selecting".
  final ValueNotifier<Set<String>> selection = ValueNotifier<Set<String>>(const <String>{});

  /// The message the composer is answering or editing.
  final ValueNotifier<ComposerTarget?> target = ValueNotifier<ComposerTarget?>(null);

  FeedState get _f => feed.value;

  BuildContext get _ctx => contextOf();

  bool get _alive => isMounted();

  ConversationType get type => conversationId.startsWith('gr:')
      ? ConversationType.group
      : conversationId.startsWith('rm:')
          ? ConversationType.room
          : ConversationType.direct;

  String get _refId => conversationId.substring(3);

  bool get selecting => selection.value.isNotEmpty;

  void start() {
    feed.addListener(_onFeedChanged);
  }

  void dispose() {
    feed.removeListener(_onFeedChanged);
    selection.dispose();
    target.dispose();
  }

  // ---- who is who ---------------------------------------------------------------

  /// Who wrote [m], as this person knows them.
  String authorOf(ChatMessage m) {
    if (m.isOutgoing) return type == ConversationType.room ? controller.nickname : _l.commonYou;
    final peer = controller.peers.where((p) => p.peer.id == m.senderId).firstOrNull;
    if (peer != null) return peer.peer.displayName;
    final nick = m.senderNickname;
    if (nick != null && nick.trim().isNotEmpty) return nick;
    return _l.authorUnknown(isolatedIn(_ctx, '#${m.senderId.substring(0, 4)}'));
  }

  /// What a reply quotes, or null when [m] is not a reply.
  QuoteData? quoteFor(ChatMessage m) {
    final id = m.replyToId;
    if (id == null) return null;
    final original = _f.byId(id);
    if (original == null) return QuoteData.gone(id);
    return QuoteData.of(original, author: authorOf(original), l: _l);
  }

  AppLocalizations get _l => controller.l10n;

  bool get _isGroupAdmin {
    if (type != ConversationType.group) return false;
    final group = controller.groups.where((g) => g.id == _refId).firstOrNull;
    return group != null && group.adminId == controller.identityId;
  }

  String get _otherName {
    if (type != ConversationType.direct) return '';
    return controller.peers.where((p) => p.peer.id == _refId).firstOrNull?.peer.displayName ??
        _l.chatTheOtherPerson;
  }

  // ---- what may be done -----------------------------------------------------------

  int _age(ChatMessage m) => controller.clock.nowMs - m.sortTimeMs;

  /// Only the author, only text, only for two days.
  bool canEdit(ChatMessage m) =>
      m.isOutgoing &&
      m.kind == MessageKind.text &&
      m.status != MessageStatus.failed &&
      _age(m) <= _policy.editWindow.inMilliseconds;

  /// The author - or, in a group, its admin - for two days.
  bool canDeleteForEveryone(ChatMessage m) =>
      (m.isOutgoing || _isGroupAdmin) &&
      m.status != MessageStatus.undecryptable &&
      _age(m) <= _policy.deleteForEveryoneWindow.inMilliseconds;

  /// Something to hand to another app: some text, or a complete file.
  bool _shareable(ChatMessage m) {
    if (m.status == MessageStatus.undecryptable) return false;
    if (m.body.isNotEmpty) return true;
    final item = m.mediaId == null ? null : _f.media[m.mediaId];
    return item != null && item.isReady;
  }

  bool _forwardable(ChatMessage m) {
    if (m.status == MessageStatus.undecryptable) return false;
    if (!m.isMedia) return true;
    final item = m.mediaId == null ? null : _f.media[m.mediaId];
    return item != null && item.isReady;
  }

  List<ChatMessage> selectedMessages() =>
      [for (final m in _f.messages) if (selection.value.contains(m.id)) m];

  bool get canCopySelected => selectedMessages().any((m) => m.body.isNotEmpty);

  bool get canForwardSelected {
    final ms = selectedMessages();
    return ms.isNotEmpty && ms.every(_forwardable);
  }

  // ---- reacting to the feed --------------------------------------------------------

  /// A message that is deleted or expires while it is selected, or being
  /// answered, leaves that state instead of leaving a dangling reference.
  void _onFeedChanged() {
    final alive = {for (final m in _f.messages) m.id};
    final gone = selection.value.where((id) => !alive.contains(id)).toSet();
    if (gone.isNotEmpty) selection.value = {...selection.value}..removeAll(gone);
    final t = target.value;
    if (t != null && !alive.contains(t.message.id)) {
      target.value = null;
      _say(t is EditTarget
          ? _l.actEditingGone
          : _l.actReplyingGone);
    }
  }

  void _say(String text) {
    if (!_alive) return;
    ScaffoldMessenger.maybeOf(_ctx)?.showSnackBar(SnackBar(content: Text(text)));
  }

  // ---- taps ---------------------------------------------------------------------------

  void toggle(String id) {
    final next = {...selection.value};
    if (!next.remove(id)) next.add(id);
    selection.value = next;
  }

  void clearSelection() {
    if (selection.value.isNotEmpty) selection.value = const <String>{};
  }

  /// A tap: picks the message while selecting, otherwise shows its details.
  void onTap(ChatMessage m, MediaItem? media) {
    if (selecting) {
      toggle(m.id);
    } else {
      unawaited(showDetails(m, media));
    }
  }

  /// Press and hold: the menu (or, while selecting, picks the message).
  Future<void> onLongPress(ChatMessage m, MediaItem? media) async {
    if (selecting) {
      toggle(m.id);
      return;
    }
    unawaited(HapticFeedback.mediumImpact());
    await openMenu(m, media);
  }

  Future<void> openMenu(ChatMessage m, MediaItem? media) async {
    final undecryptable = m.status == MessageStatus.undecryptable;
    final sendable = canSend();
    final action = await showMessageMenu(
      _ctx,
      message: m,
      author: authorOf(m),
      options: MessageMenuOptions(
        canReply: !undecryptable && sendable,
        canCopy: !undecryptable && m.body.isNotEmpty,
        canForward: _forwardable(m),
        canSave: !undecryptable && media != null && media.isReady && !media.isVoice,
        canShare: _shareable(m),
        canRetry: m.isOutgoing && m.status == MessageStatus.failed && sendable,
        canPin: !undecryptable,
        pinned: _f.pinnedIds.contains(m.id),
        canEdit: sendable && canEdit(m),
      ),
    );
    if (action == null || !_alive) return;
    switch (action) {
      case MessageAction.reply:
        target.value = ReplyTarget(m, author: authorOf(m));
      case MessageAction.copy:
        await copy([m]);
      case MessageAction.forward:
        await forward([m]);
      case MessageAction.share:
        await share([m]);
      case MessageAction.save:
        if (media != null) await saveToGallery([media]);
      case MessageAction.retry:
        await retry(m);
      case MessageAction.pin:
        await setPinned(m, true);
      case MessageAction.unpin:
        await setPinned(m, false);
      case MessageAction.edit:
        target.value = EditTarget(m);
      case MessageAction.select:
        selection.value = {m.id};
      case MessageAction.details:
        await showDetails(m, media);
      case MessageAction.delete:
        await delete([m]);
    }
  }

  // ---- sending (answering and editing) -----------------------------------------------------

  /// Sends the composer's text: a new message, an answer, or the edit of an
  /// earlier message, depending on what the composer is doing.
  Future<void> sendText(String text) async {
    final t = target.value;
    try {
      if (t is EditTarget) {
        await controller.editMessage(t.message.id, text);
      } else {
        await controller.sendText(conversationId, text,
            replyToId: t is ReplyTarget ? t.message.id : null);
      }
    } on MessageError catch (e) {
      // The message is gone for good: there is nothing left to answer or edit.
      if (e.kind == MessageErrorKind.unknownMessage || e.kind == MessageErrorKind.tooOld) {
        target.value = null;
      }
      rethrow;
    }
    if (t != null) target.value = null;
  }

  Future<void> sendDraft(MediaDraft draft) async {
    final t = target.value;
    await controller.sendMedia(
      conversationId,
      t is ReplyTarget ? draft.copyWith(replyToId: t.message.id) : draft,
    );
    if (t is ReplyTarget) target.value = null;
  }

  // ---- the individual actions ----------------------------------------------------------------

  Future<void> copy(List<ChatMessage> messages) async {
    final withText = messages.where((m) => m.body.isNotEmpty).toList();
    if (withText.isEmpty) {
      _say(_l.actNoTextToCopy);
      return;
    }
    final text = withText.length == 1
        ? withText.single.body
        : withText.map((m) => '${authorOf(m)}: ${m.body}').join('\n');
    await Clipboard.setData(ClipboardData(text: text));
    clearSelection();
    _say(withText.length == 1 ? _l.actCopied : _l.actCopiedMany(withText.length));
  }

  /// Copies a picture or video out of the app's private storage into the
  /// gallery, after saying what that means.
  Future<void> saveToGallery(List<MediaItem> items) async {
    if (items.isEmpty) return;
    final go = await showAppDialog<bool>(
      context: _ctx,
      title: _l.actSaveTitle,
      message: items.length > 1
          ? _l.actSaveBodyFiles(items.length)
          : items.single.isVideo
              ? _l.actSaveBodyVideo
              : _l.actSaveBodyPicture,
      actions: [
        TextButton(
          key: const Key('save-cancel'),
          onPressed: () => Navigator.pop(_ctx, false),
          child: Text(_l.commonCancel),
        ),
        FilledButton(
          key: const Key('save-confirm'),
          onPressed: () => Navigator.pop(_ctx, true),
          child: Text(_l.commonSave),
        ),
      ],
    );
    if (go != true || !_alive) return;
    var saved = 0;
    try {
      for (final item in items) {
        await controller.saveToGallery(item);
        saved++;
      }
      clearSelection();
      _say(saved == 1 ? _l.actSaved : _l.actSavedMany(saved));
    } on GalleryException catch (e) {
      onError(saved == 0 ? e.text(_l) : _l.actSavedSome(saved, items.length, e.text(_l)));
    }
  }

  /// Hands the text and files of [messages] to another app.
  Future<void> share(List<ChatMessage> messages) async {
    try {
      await controller.shareMessages(messages, _f.media);
      clearSelection();
    } on MessageError catch (e) {
      onError(e.message);
    }
  }

  Future<void> retry(ChatMessage m) async {
    try {
      await controller.retry(m.id);
    } on MessageError catch (e) {
      onError(e.message);
    }
  }

  Future<void> setPinned(ChatMessage m, bool pinned) async {
    try {
      await controller.setPinned(conversationId, m.id, pinned);
      _say(pinned ? _l.actPinnedNote : _l.actUnpinnedNote);
    } on MessageError catch (e) {
      onError(e.message);
    }
  }

  Future<void> forward(List<ChatMessage> messages) async {
    if (messages.isEmpty) return;
    final targetId = await showForwardSheet(_ctx,
        controller: controller,
        count: messages.length,
        hasVideo: messages.any((m) => m.kind == MessageKind.video));
    if (targetId == null || !_alive) return;
    final destination = controller.conversations.where((c) => c.id == targetId).firstOrNull;
    final ctx = _ctx;
    if (!ctx.mounted) return;
    if (destination != null && destination.isRoom && type != ConversationType.room) {
      final go = await showDangerConfirm(
        ctx,
        title: _l.actForwardPublicTitle,
        body: _l.actForwardPublicBody,
        action: _l.actForwardPublicAction,
      );
      if (!go || !_alive || !ctx.mounted) return;
    }
    // The name as it is shown: a room's tag is kept in one piece.
    final title = destination == null
        ? _l.actTheChat
        : (destination.isRoom ? isolatedIn(ctx, destination.title) : destination.title);
    try {
      final sent = await controller.forwardMessages([for (final m in messages) m.id], targetId);
      clearSelection();
      if (sent.length == messages.length) {
        _say(sent.length == 1 ? _l.actForwardedTo(title) : _l.actForwardedMany(sent.length, title));
      } else {
        _say(_l.actForwardedSome(sent.length, messages.length, title));
      }
    } on MessageError catch (e) {
      onError(e.message);
    }
  }

  Future<void> delete(List<ChatMessage> messages) async {
    if (messages.isEmpty) return;
    final everyone = messages.every(canDeleteForEveryone);
    final choice = await showDeleteDialog(
      _ctx,
      count: messages.length,
      canEveryone: everyone,
      type: type,
      who: _otherName,
      mixed: !everyone,
    );
    if (choice == null || !_alive) return;
    final ids = [for (final m in messages) m.id];
    try {
      final DeleteResult r = choice == DeleteChoice.forMe
          ? await controller.deleteForMe(conversationId, ids)
          : await controller.deleteForEveryone(conversationId, ids);
      clearSelection();
      final many = r.removed > 1;
      // How many the sentence is about: what was asked, when nothing went.
      final n = r.removed == 0 ? messages.length : r.removed;
      if (r.removed == 0) {
        _say(_l.actNothingDeleted(n));
      } else if (choice == DeleteChoice.forMe) {
        _say(r.cancelled == r.removed
            ? _l.actDeletedUnsent(n)
            : many
                ? _l.actDeletedManyHere(r.removed)
                : _l.actDeletedHere);
      } else if (r.askedOthers) {
        _say(_l.actDeletedAskedOthers(n));
      } else {
        _say(_l.actDeletedNeverSent(n));
      }
    } on MessageError catch (e) {
      onError(e.message);
    }
  }

  Future<void> showDetails(ChatMessage m, MediaItem? media) async {
    final conversation = await controller.conversation(conversationId);
    final ctx = _ctx;
    if (conversation == null || !ctx.mounted) return;
    await showMessageDetails(
      ctx,
      controller: controller,
      message: m,
      media: media,
      author: authorOf(m),
      quote: quoteFor(m),
      pinned: _f.pinnedIds.contains(m.id),
      conversation: conversation,
    );
  }

  // ---- bulk (selection bar) -----------------------------------------------------------------------

  Future<void> copySelected() => copy(selectedMessages());

  Future<void> forwardSelected() => forward(selectedMessages());

  Future<void> deleteSelected() => delete(selectedMessages());

  Future<void> shareSelected() => share(selectedMessages());

  /// The pictures and videos among the selected messages that can be saved.
  List<MediaItem> _savableSelected() => [
        for (final m in selectedMessages())
          if (m.status != MessageStatus.undecryptable && m.mediaId != null)
            if (_f.media[m.mediaId] case final item? when item.isReady && !item.isVoice) item,
      ];

  Future<void> saveSelected() => saveToGallery(_savableSelected());

  /// Every message of the conversation that is loaded.
  void selectAll() => selection.value = {for (final m in _f.messages) m.id};

  bool get allSelectedPinned {
    final selected = selection.value;
    return selected.isNotEmpty && selected.every(_f.pinnedIds.contains);
  }

  /// Pins the selected messages - or, when they are all pinned already, unpins them.
  Future<void> pinSelected() async {
    final unpin = allSelectedPinned;
    var changed = 0;
    for (final m in selectedMessages()) {
      if (m.status == MessageStatus.undecryptable) continue;
      try {
        if (await controller.setPinned(conversationId, m.id, !unpin)) changed++;
      } on MessageError catch (e) {
        onError(e.message);
        return;
      }
    }
    clearSelection();
    _say(unpin ? _l.actUnpinnedCount(changed) : _l.actPinnedCount(changed));
  }

  /// What the selection bar's "more" menu offers right now.
  List<SelectionMenuItem> selectionMenu() => [
        if (canCopySelected)
          SelectionMenuItem(const Key('sel-copy'), Icons.copy_rounded, _l.commonCopy,
              () => unawaited(copySelected())),
        SelectionMenuItem(const Key('sel-all'), Icons.select_all_rounded, _l.actSelectAll, selectAll),
        SelectionMenuItem(
          const Key('sel-pin'),
          allSelectedPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
          allSelectedPinned ? _l.actUnpin : _l.actPin,
          () => unawaited(pinSelected()),
        ),
        SelectionMenuItem(const Key('sel-share'), Icons.ios_share_rounded, _l.commonShare,
            () => unawaited(shareSelected())),
        if (_savableSelected().isNotEmpty)
          SelectionMenuItem(const Key('sel-save'), Icons.download_rounded, _l.actSaveToGallery,
              () => unawaited(saveSelected())),
      ];

  // ---- pinned messages ------------------------------------------------------------------------------

  Future<void> openPinnedList() async {
    final id = await showAppSheet<String>(
      context: _ctx,
      builder: (sheet) => _PinnedList(
        feed: feed,
        authorOf: authorOf,
        onUnpin: (m) => setPinned(m, false),
      ),
    );
    if (id != null && _alive) await _jump(id);
  }

  Future<void> _jump(String id) async {
    final found = await onJump(id);
    if (!found) _say(_l.actFurtherBack);
  }

  Future<void> jumpTo(String id) => _jump(id);
}

class _PinnedList extends StatelessWidget {
  const _PinnedList({required this.feed, required this.authorOf, required this.onUnpin});

  final ValueListenable<FeedState> feed;
  final String Function(ChatMessage) authorOf;
  final Future<void> Function(ChatMessage) onUnpin;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<FeedState>(
      valueListenable: feed,
      builder: (context, state, _) {
        final pinned = state.pinned;
        final maxHeight = MediaQuery.sizeOf(context).height * 0.5;
        return Column(
          key: const Key('pinned-list'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.l10n.pinnedListTitle(pinned.length),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(context.l10n.pinnedListNote,
                style: TextStyle(color: context.palette.textMuted, fontSize: 12.5)),
            const SizedBox(height: 8),
            if (pinned.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text(context.l10n.pinnedListEmpty,
                    textAlign: TextAlign.center, style: TextStyle(color: context.palette.textMuted)),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeight),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: pinned.length,
                  itemBuilder: (context, i) {
                    final m = pinned[i];
                    final icon = messageSnippetIcon(m);
                    return ListTile(
                      key: Key('pinned-item-${m.id}'),
                      contentPadding: const EdgeInsetsDirectional.only(start: 4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      onTap: () => Navigator.pop(context, m.id),
                      title: Text(authorOf(m),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: context.palette.accentSoft,
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5)),
                      subtitle: Row(
                        children: [
                          if (icon != null) ...[
                            Icon(icon, size: 15, color: context.palette.textSecondary),
                            const SizedBox(width: 4),
                          ],
                          Expanded(
                            child: Text(messageSnippet(m, context.l10n),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: context.palette.textSecondary)),
                          ),
                        ],
                      ),
                      trailing: IconButton(
                        key: Key('pinned-unpin-${m.id}'),
                        tooltip: context.l10n.actUnpin,
                        icon: const Icon(Icons.push_pin_outlined, size: 20),
                        onPressed: () => onUnpin(m),
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Finds a message in a reversed, lazily built list and scrolls to it, then
/// outlines it for a moment so the eye finds it.
class MessageJumper {
  MessageJumper(this.scroll);

  final ScrollController scroll;
  final ValueNotifier<String?> highlighted = ValueNotifier<String?>(null);
  final Map<String, GlobalKey> _keys = <String, GlobalKey>{};
  Timer? _timer;

  /// Rough height of a message, to get near one that is not built yet.
  static const double _estimate = 78;

  GlobalKey keyFor(String id) => _keys.putIfAbsent(id, GlobalKey.new);

  /// Forgets the keys of messages that are gone.
  void prune(Set<String> alive) => _keys.removeWhere((id, _) => !alive.contains(id));

  /// Scrolls to [id], which is somewhere in [messages] (oldest first, shown
  /// newest at the bottom). False when it is not among them.
  Future<bool> jumpTo(String id, List<ChatMessage> messages) async {
    final index = messages.indexWhere((m) => m.id == id);
    if (index < 0 || !scroll.hasClients) return false;
    final fromEnd = messages.length - 1 - index;
    for (var attempt = 0; attempt < 6; attempt++) {
      final built = _keys[id]?.currentContext;
      if (built != null && built.mounted) {
        await Scrollable.ensureVisible(
          built,
          alignment: 0.4,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
        break;
      }
      if (!scroll.hasClients) return false;
      scroll.jumpTo((fromEnd * _estimate).clamp(0, scroll.position.maxScrollExtent).toDouble());
      await WidgetsBinding.instance.endOfFrame;
    }
    highlighted.value = id;
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 1400), () => highlighted.value = null);
    return true;
  }

  void dispose() {
    _timer?.cancel();
    highlighted.dispose();
  }
}
