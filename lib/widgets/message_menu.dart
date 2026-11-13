import 'package:flutter/material.dart';

import '../models/conversation.dart';
import '../models/message.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../theme/surfaces.dart';
import 'chat_header.dart';
import 'composer_target.dart';
import '../l10n/l10n.dart';

/// What the long-press menu of a message can do.
enum MessageAction { reply, copy, forward, share, save, retry, pin, unpin, edit, select, details, delete }

/// Which of the actions make sense for this message, right now.
class MessageMenuOptions {
  const MessageMenuOptions({
    this.canReply = true,
    this.canCopy = true,
    this.canForward = true,
    this.canPin = true,
    this.pinned = false,
    this.canEdit = false,
    this.canSave = false,
    this.canShare = true,
    this.canRetry = false,
  });

  final bool canReply;
  final bool canCopy;
  final bool canForward;
  final bool canPin;
  final bool pinned;
  final bool canEdit;

  /// A complete picture or video can be copied to the phone's gallery.
  final bool canSave;

  /// There is something to hand to another app.
  final bool canShare;

  /// The message failed to send and can be sent again.
  final bool canRetry;
}

/// The menu that opens when a message is pressed and held: the message at the
/// top so it is clear which one this is, then what can be done to it.
Future<MessageAction?> showMessageMenu(
  BuildContext context, {
  required ChatMessage message,
  required String author,
  required MessageMenuOptions options,
}) {
  return showAppSheet<MessageAction>(
    context: context,
    builder: (context) => _MessageMenu(message: message, author: author, options: options),
  );
}

class _MessageMenu extends StatelessWidget {
  const _MessageMenu({required this.message, required this.author, required this.options});

  final ChatMessage message;
  final String author;
  final MessageMenuOptions options;

  @override
  Widget build(BuildContext context) {
    final icon = messageSnippetIcon(message);
    void pick(MessageAction a) => Navigator.pop(context, a);
    return SingleChildScrollView(
      child: Column(
        key: const Key('message-menu'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            decoration: BoxDecoration(
              color: context.palette.inset,
              borderRadius: BorderRadius.circular(14),
              border: BorderDirectional(start: BorderSide(color: context.palette.accent, width: 3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(author,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: context.palette.accentSoft, fontWeight: FontWeight.w700, fontSize: 13)),
                Row(
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 15, color: context.palette.textSecondary),
                      const SizedBox(width: 5),
                    ],
                    Expanded(
                      child: Text(messageSnippet(message, context.l10n),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: context.palette.textSecondary, fontSize: 14)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          if (options.canReply)
            _Tile(const Key('act-reply'), Icons.reply_rounded, context.l10n.actReply, () => pick(MessageAction.reply)),
          if (options.canCopy)
            _Tile(const Key('act-copy'), Icons.copy_rounded, message.isMedia ? context.l10n.actCopyCaption : context.l10n.actCopyText,
                () => pick(MessageAction.copy)),
          if (options.canForward)
            _Tile(const Key('act-forward'), AppIcons.forward, context.l10n.actForward,
                () => pick(MessageAction.forward)),
          if (options.canShare)
            _Tile(const Key('act-share'), Icons.ios_share_rounded, context.l10n.commonShare,
                () => pick(MessageAction.share)),
          if (options.canSave)
            _Tile(const Key('act-save'), Icons.download_rounded, context.l10n.actSaveToGallery,
                () => pick(MessageAction.save)),
          if (options.canRetry)
            _Tile(const Key('act-retry'), Icons.refresh_rounded, context.l10n.actSendAgain,
                () => pick(MessageAction.retry)),
          if (options.canPin)
            options.pinned
                ? _Tile(const Key('act-unpin'), Icons.push_pin_outlined, context.l10n.actUnpin,
                    () => pick(MessageAction.unpin))
                : _Tile(const Key('act-pin'), Icons.push_pin_rounded, context.l10n.actPin,
                    () => pick(MessageAction.pin)),
          if (options.canEdit)
            _Tile(const Key('act-edit'), Icons.edit_rounded, context.l10n.actEdit, () => pick(MessageAction.edit)),
          _Tile(const Key('act-select'), Icons.check_circle_outline_rounded, context.l10n.actSelect,
              () => pick(MessageAction.select)),
          _Tile(const Key('act-details'), Icons.info_outline_rounded, context.l10n.actDetails,
              () => pick(MessageAction.details)),
          const Divider(height: 10),
          _Tile(const Key('act-delete'), Icons.delete_outline_rounded, context.l10n.commonDelete,
              () => pick(MessageAction.delete),
              color: context.palette.danger),
          const SizedBox(height: 2),
          TextButton(
            key: const Key('act-cancel'),
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.commonCancel),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile(Key key, this.icon, this.label, this.onTap, {this.color}) : super(key: key);

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.palette.text;
    return ListTile(
      onTap: onTap,
      dense: false,
      minTileHeight: 48,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      leading: Icon(icon, color: color ?? context.palette.accentSoft, size: 22),
      title: Text(label, style: TextStyle(color: c, fontWeight: FontWeight.w600, fontSize: 15.5)),
    );
  }
}

/// What the person chose when asked how to delete.
enum DeleteChoice { forMe, forEveryone }

/// Asks how to delete [count] messages. "Delete for everyone" appears only when
/// it is allowed, and says plainly what it can and cannot do.
Future<DeleteChoice?> showDeleteDialog(
  BuildContext context, {
  required int count,
  required bool canEveryone,
  required ConversationType type,
  required String who,
  bool mixed = false,
}) {
  final l = context.l10n;
  return showAppDialog<DeleteChoice>(
    context: context,
    title: l.deleteTitle(count),
    message: [
      l.deleteForMeNote(count),
      if (canEveryone)
        switch (type) {
          ConversationType.direct => l.deleteEveryoneDirect(count, who),
          ConversationType.group => l.deleteEveryoneGroup(count),
          ConversationType.room => l.deleteEveryoneRoom(count),
        }
      else if (mixed)
        type == ConversationType.group ? l.deleteEveryoneOwnOrAdmin : l.deleteEveryoneOwnOnly,
    ].join('\n\n'),
    actions: [
      TextButton(
        key: const Key('delete-cancel'),
        onPressed: () => Navigator.pop(context),
        child: Text(context.l10n.commonCancel),
      ),
      TextButton(
        key: const Key('delete-for-me'),
        onPressed: () => Navigator.pop(context, DeleteChoice.forMe),
        child: Text(context.l10n.deleteForMe),
      ),
      if (canEveryone)
        FilledButton(
          key: const Key('delete-for-everyone'),
          style: FilledButton.styleFrom(
            backgroundColor: context.palette.danger,
            foregroundColor: context.palette.onStatus,
          ),
          onPressed: () => Navigator.pop(context, DeleteChoice.forEveryone),
          child: Text(context.l10n.deleteForEveryone),
        ),
    ],
  );
}

/// One entry of the selection bar's "more" menu.
class SelectionMenuItem {
  const SelectionMenuItem(this.key, this.icon, this.label, this.onTap);

  final Key key;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

/// Replaces the header while messages are selected: how many, and what can be
/// done with all of them.
class SelectionBar extends StatelessWidget {
  const SelectionBar({
    super.key,
    required this.count,
    required this.onClose,
    required this.onForward,
    required this.onDelete,
    this.more = const <SelectionMenuItem>[],
  });

  final int count;
  final VoidCallback onClose;
  final VoidCallback? onForward;
  final VoidCallback onDelete;

  /// Copy, select all, pin, share and save, in a menu so the bar fits a narrow phone
  /// and large system text.
  final List<SelectionMenuItem> more;

  @override
  Widget build(BuildContext context) {
    // The same flat strip as a conversation's header, which it replaces.
    return Material(
      color: context.palette.surface,
      child: SafeArea(
        bottom: false,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: ChatHeader.height),
          child: Padding(
            padding: const EdgeInsetsDirectional.only(start: 4, end: 4),
            child: Row(
              children: [
                RoundButton(
                  key: const Key('selection-close'),
                  icon: Icons.close_rounded,
                  tooltip: context.l10n.selCancel,
                  flat: true,
                  onPressed: onClose,
                ),
                const SizedBox(width: AppSpace.s),
                // The count gives way (it shrinks) before the buttons do.
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      context.l10n.selCount(count),
                      key: const Key('selection-count'),
                      maxLines: 1,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                RoundButton(
                  key: const Key('selection-forward'),
                  icon: AppIcons.forward,
                  tooltip: context.l10n.actForward,
                  flat: true,
                  onPressed: onForward,
                ),
                RoundButton(
                  key: const Key('selection-delete'),
                  icon: Icons.delete_outline_rounded,
                  tooltip: context.l10n.commonDelete,
                  color: context.palette.danger,
                  flat: true,
                  onPressed: onDelete,
                ),
                if (more.isNotEmpty)
                  PopupMenuButton<int>(
                    key: const Key('selection-more'),
                    tooltip: context.l10n.commonMore,
                    // Opens below the bar instead of on top of its buttons.
                    offset: const Offset(0, 52),
                    icon: const Icon(Icons.more_vert_rounded),
                    onSelected: (i) => more[i].onTap(),
                    itemBuilder: (context) => [
                      for (var i = 0; i < more.length; i++)
                        PopupMenuItem<int>(
                          key: more[i].key,
                          value: i,
                          child: Row(
                            children: [
                              Icon(more[i].icon, size: 20, color: context.palette.accentSoft),
                              const SizedBox(width: 12),
                              Flexible(child: Text(more[i].label)),
                            ],
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
