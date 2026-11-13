import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../core/format.dart';
import '../models/media.dart';
import '../models/message.dart';
import '../theme/app_theme.dart';
import '../theme/motion.dart';
import 'media_views.dart';
import 'peer_avatar.dart';
import 'quote_views.dart';
import 'status_pill.dart';
import '../l10n/l10n.dart';
import '../core/bidi.dart';
import '../models/delivery_problem.dart';

/// The round tick shown at the left of a message while messages are selected.
/// Choosing one fills the circle and pops the tick in within a tenth of a second,
/// so a tap is answered at once; with "remove animations" it just changes.
class SelectCheck extends StatelessWidget {
  const SelectCheck({super.key, required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final quick = AppMotion.of(context, AppMotion.press);
    return AnimatedContainer(
      duration: quick,
      curve: AppMotion.out,
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? context.palette.accent : Colors.transparent,
        border: Border.all(color: selected ? context.palette.accent : context.palette.textMuted, width: 1.6),
      ),
      child: AnimatedScale(
        scale: selected ? 1 : 0.4,
        duration: quick,
        curve: AppMotion.out,
        child: AnimatedOpacity(
          opacity: selected ? 1 : 0,
          duration: quick,
          // The key says which state this is (the tests count them); it sits on the
          // tick so that the circle around it keeps animating from one state to the next.
          child: Icon(
            Icons.check_rounded,
            key: Key(selected ? 'select-check-on' : 'select-check-off'),
            size: 17,
            color: context.palette.onAccent,
          ),
        ),
      ),
    );
  }
}

/// One chat message, Telegram style: blue on the right for what we sent, charcoal
/// on the left for what we received. Text, pictures and voice messages share the
/// same bubble. Outgoing bubbles show their delivery state; a message that failed
/// verification or decryption is shown as such, never silently dropped and never as
/// if it were normal text.
///
/// The public room uses the same bubble, with the writer's name (and the first
/// characters of their id, [senderTag]) on top, and [fade] to dim a message that is
/// about to disappear.
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.controller,
    this.media,
    this.showSender = false,
    this.senderName,
    this.senderTag,
    this.onRetry,
    this.onTap,
    this.onLongPress,
    this.onOpenImage,
    this.quote,
    this.onQuoteTap,
    this.selecting = false,
    this.selected = false,
    this.pinned = false,
    this.highlighted = false,
    this.fade = 1,
  });

  /// How many times a bubble was built; the keyboard tests use it to prove that
  /// opening the keyboard does not rebuild the conversation.
  @visibleForTesting
  static int debugBuilds = 0;

  final ChatMessage message;
  final AppController controller;

  /// The picture / voice file this message carries, once known.
  final MediaItem? media;

  /// Group and room messages show who wrote them.
  final bool showSender;
  final String? senderName;

  /// A few characters of the writer's id, shown after the name: in a public room
  /// two people can have the same name.
  final String? senderTag;
  final VoidCallback? onRetry;
  final VoidCallback? onTap;

  /// Press and hold: opens the message's menu.
  final VoidCallback? onLongPress;
  final void Function(Uint8List bytes)? onOpenImage;

  /// The message this one answers, if it is a reply.
  final QuoteData? quote;
  final VoidCallback? onQuoteTap;

  /// Some messages are being selected: show a tick circle, and [selected] says
  /// whether this one is among them.
  final bool selecting;
  final bool selected;
  final bool pinned;

  /// Briefly outlined after a jump to this message.
  final bool highlighted;

  /// 1 for a message that is here to stay; less for one that is about to go.
  final double fade;

  @override
  Widget build(BuildContext context) {
    assert(() {
      debugBuilds++;
      return true;
    }());
    final outgoing = message.isOutgoing;
    final failure = message.status == MessageStatus.undecryptable;
    final failedSend = message.status == MessageStatus.failed;
    final maxWidth = math.min(560.0, math.max(240.0, MediaQuery.sizeOf(context).width * 0.78));

    final Color background = failure || failedSend
        ? Color.alphaBlend(context.palette.danger.withValues(alpha: 0.16), context.palette.surfaceHigh)
        : outgoing
            ? context.palette.outgoingBubble
            : context.palette.incomingBubble;
    // What is written on the blue bubble is white; on the others it is the usual greys.
    final onBlue = outgoing && !failedSend;
    final metaColor = onBlue ? context.palette.onAccent : context.palette.textMuted;

    final hasMedia = message.isMedia && media != null;
    // Pictures and videos run to the edge of the bubble; voice and text keep their margins.
    final tightMedia = hasMedia && (media!.isImage || media!.isVideo);
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(AppRadii.lg - 2),
      topRight: const Radius.circular(AppRadii.lg - 2),
      bottomLeft: Radius.circular(outgoing ? AppRadii.lg - 2 : 5),
      bottomRight: Radius.circular(outgoing ? 5 : AppRadii.lg - 2),
    );
    final bubble = Material(
      color: background,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        // No line round a bubble, except to say that something is wrong with it, or
        // that this is the one the person jumped to.
        side: failure || failedSend
            ? BorderSide(color: context.palette.danger.withValues(alpha: 0.55))
            : highlighted
                ? BorderSide(color: context.palette.accentSoft)
                : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: EdgeInsets.fromLTRB(tightMedia ? 5 : 12, 7, tightMedia ? 5 : 12, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showSender && !outgoing)
                Padding(
                  padding: EdgeInsetsDirectional.only(bottom: 3, start: tightMedia ? 6 : 0),
                  child: SenderName(
                    senderName ?? message.senderNickname ?? message.senderId.substring(0, 8),
                    seed: message.senderId,
                    tag: senderTag,
                  ),
                ),
              if (!failure && message.isForwarded)
                Padding(
                  padding: EdgeInsetsDirectional.only(start: tightMedia ? 6 : 0),
                  child: ForwardedLabel(message.forwardedFrom!, onBlue: onBlue),
                ),
              if (!failure && quote != null) QuoteView(quote: quote!, onTap: onQuoteTap, onBlue: onBlue),
              if (failure)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.gpp_bad_rounded, size: 18, color: context.palette.danger),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        context.l10n.bubbleUndecryptable,
                        style: TextStyle(color: context.palette.text, fontSize: 13.5, height: 1.35),
                      ),
                    ),
                  ],
                )
              // While messages are being selected a tap only selects: the picture does
              // not open, the video and the voice message do not play.
              else if (message.kind == MessageKind.image && media != null)
                IgnorePointer(
                  ignoring: selecting,
                  child: ImageMessageView(
                    media: media!,
                    controller: controller,
                    onOpen: onOpenImage,
                    maxWidth: math.min(250, maxWidth - 12),
                  ),
                )
              else if (message.kind == MessageKind.video && media != null)
                IgnorePointer(
                  ignoring: selecting,
                  child: VideoMessageView(
                    media: media!,
                    controller: controller,
                    width: math.min(250, maxWidth - 12),
                    title: senderName ?? '',
                  ),
                )
              else if (message.kind == MessageKind.voice && media != null)
                IgnorePointer(
                  ignoring: selecting,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: VoiceMessageView(
                      messageId: message.id,
                      media: media!,
                      controller: controller,
                      onBlue: onBlue,
                    ),
                  ),
                )
              else if (message.isMedia)
                // The file's details are not loaded yet.
                Text(switch (message.kind) {
                  MessageKind.image => context.l10n.bubblePicture,
                  MessageKind.video => context.l10n.bubbleVideo,
                  _ => context.l10n.bubbleVoice,
                },
                    style: TextStyle(color: onBlue ? context.palette.onAccent : context.palette.textSecondary)),
              if (!failure && message.body.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(
                    top: message.isMedia ? 6 : 0,
                    left: tightMedia ? 8 : 0,
                    right: tightMedia ? 8 : 0,
                  ),
                  // Each message reads in its own direction: an English message on
                  // a Kurdish phone keeps its punctuation where an English reader
                  // expects it, and the other way round.
                  child: Text(
                    message.body,
                    textDirection: textDirectionOf(message.body),
                    // White on the blue bubble in both appearances; the theme's text colour
                    // (the default) on the others.
                    style: TextStyle(
                        fontSize: 15.5, height: 1.3, color: onBlue ? context.palette.onAccent : null),
                  ),
                ),
              const SizedBox(height: 3),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: tightMedia ? 8 : 0),
                // A Wrap, not a Row: with large system text the time, the relay
                // note and the delivery state go on a second line instead of
                // running out of the bubble.
                child: Wrap(
                  spacing: 8,
                  runSpacing: 2,
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (pinned) Icon(Icons.push_pin_rounded, size: 12, color: metaColor),
                    if (message.isEdited && !failure)
                      Text(
                        context.l10n.bubbleEdited,
                        key: const Key('edited-label'),
                        style: TextStyle(
                            color: metaColor, fontSize: 11, fontStyle: FontStyle.italic),
                      ),
                    Text(
                      formatClock(message.sortTimeMs),
                      style: TextStyle(color: metaColor, fontSize: 11),
                    ),
                    if (!outgoing && message.hops > 0 && !failure)
                      Text(
                        context.l10n.bubbleViaRelays(message.hops),
                        style: TextStyle(color: context.palette.accentSoft, fontSize: 11),
                      ),
                    if (outgoing) DeliveryStatusView(message, onBlue: onBlue),
                  ],
                ),
              ),
              if (failedSend)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          DeliveryProblem.describe(context.l10n, message.error) ?? context.l10n.bubbleNotDelivered,
                          style: TextStyle(color: context.palette.textSecondary, fontSize: 12),
                        ),
                      ),
                      if (onRetry != null) ...[
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: onRetry,
                          style: TextButton.styleFrom(
                            minimumSize: const Size(0, 30),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                          ),
                          child: Text(context.l10n.actSendAgain),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    // A selected message is shown whole, so that what is chosen can be read.
    final faded = fade < 1 && !selected ? Opacity(opacity: fade, child: bubble) : bubble;
    final aligned = Align(
      alignment: outgoing ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3, horizontal: AppSpace.m),
          child: faded,
        ),
      ),
    );
    return RepaintBoundary(
      child: Semantics(
        selected: selecting ? selected : null,
        child: ColoredBox(
          color: selected ? context.palette.accent.withValues(alpha: 0.16) : Colors.transparent,
          child: selecting
              ? Row(
                  children: [
                    Padding(
                      padding: const EdgeInsetsDirectional.only(start: 10),
                      child: SelectCheck(selected: selected),
                    ),
                    Expanded(child: aligned),
                  ],
                )
              : aligned,
        ),
      ),
    );
  }
}
