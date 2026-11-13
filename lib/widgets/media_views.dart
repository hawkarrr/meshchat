import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../core/format.dart';
import '../device/device_io.dart';
import '../models/media.dart';
import '../screens/video_player_screen.dart';
import '../theme/app_theme.dart';
import '../l10n/l10n.dart';

String formatDuration(Duration d) {
  final total = d.inSeconds;
  return '${total ~/ 60}:${(total % 60).toString().padLeft(2, '0')}';
}

/// Draws a voice message's loudness as a row of rounded bars; the part already
/// played is highlighted.
class WaveformBars extends StatelessWidget {
  const WaveformBars({
    super.key,
    required this.samples,
    this.progress = 0,
    this.height = 30,
    this.active,
    this.inactive,
    this.barCount = 32,
  });

  /// 0..255 per bar. Empty draws a neutral pattern.
  final List<int> samples;

  /// 0..1: how much of the message has been played.
  final double progress;
  final double height;

  /// The colour of the bars that are played; the text colour of the theme unless given.
  final Color? active;

  /// The colour of the bars still to play; [active] at 40% unless given.
  final Color? inactive;
  final int barCount;

  @override
  Widget build(BuildContext context) {
    final played = active ?? context.palette.text;
    return RepaintBoundary(
      child: CustomPaint(
        size: Size(double.infinity, height),
        painter: _WaveformPainter(
            samples, progress, played, inactive ?? played.withValues(alpha: 0.4), barCount),
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter(this.samples, this.progress, this.active, this.inactive, this.barCount);

  final List<int> samples;
  final double progress;
  final Color active;
  final Color inactive;
  final int barCount;

  @override
  void paint(Canvas canvas, Size size) {
    final gap = 2.0;
    final barWidth = math.max(1.5, (size.width - gap * (barCount - 1)) / barCount);
    final paint = Paint()..strokeCap = StrokeCap.round;
    for (var i = 0; i < barCount; i++) {
      final double level;
      if (samples.isEmpty) {
        level = 0.25 + 0.2 * (math.sin(i * 0.9) + 1) / 2;
      } else {
        final from = (i * samples.length / barCount).floor();
        final to = math.max(from + 1, ((i + 1) * samples.length / barCount).floor());
        var peak = 0;
        for (var j = from; j < to && j < samples.length; j++) {
          peak = math.max(peak, samples[j]);
        }
        level = (peak / 255).clamp(0.12, 1.0);
      }
      final h = math.max(3.0, size.height * level);
      final x = i * (barWidth + gap) + barWidth / 2;
      paint
        ..color = (i + 0.5) / barCount <= progress ? active : inactive
        ..strokeWidth = barWidth;
      canvas.drawLine(
        Offset(x, (size.height - h) / 2),
        Offset(x, (size.height + h) / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.progress != progress ||
      old.samples != samples ||
      old.active != active ||
      old.inactive != inactive;
}

/// A voice message inside a bubble: play / pause, a waveform that doubles as a
/// seek bar, the time, and a speed button while it is playing.
class VoiceMessageView extends StatelessWidget {
  const VoiceMessageView({
    super.key,
    required this.messageId,
    required this.media,
    required this.controller,
    this.compact = false,
    this.onBlue = false,
  });

  final String messageId;
  final MediaItem media;
  final AppController controller;

  /// A smaller version for the public room's text-line layout.
  final bool compact;

  /// It sits on the blue bubble (a message we sent): everything on it is white, whatever the
  /// appearance, and the play button is a white disc.
  final bool onBlue;

  Future<void> _toggle(BuildContext context) async {
    final path = await controller.mediaPath(media) ?? media.fileName;
    if (path == null) return;
    await controller.io.player.toggle(messageId, path);
  }

  @override
  Widget build(BuildContext context) {
    final player = controller.io.player;
    final ready = media.isReady;
    final p = context.palette;
    // The bars and the time: white on the blue bubble, the text colours elsewhere.
    final ink = onBlue ? p.onAccent : p.text;
    final timeColor = onBlue ? p.onAccent : p.textSecondary;
    final speedColor = onBlue ? p.onAccent : p.accentSoft;
    return ValueListenableBuilder<PlaybackState>(
      valueListenable: player.state,
      builder: (context, state, _) {
        final current = state.isCurrent(messageId);
        final playing = state.isPlaying(messageId);
        final total = media.duration;
        final position = current ? state.position : Duration.zero;
        final progress = !current || total.inMilliseconds == 0
            ? 0.0
            : (position.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
        final shown = current && position > Duration.zero ? position : total;

        return SizedBox(
          width: compact ? 220 : 230,
          child: Row(
            children: [
              _RoundPlayButton(
                playing: playing,
                enabled: ready,
                onBlue: onBlue,
                onPressed: () => _toggle(context),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (ready)
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown: current
                            ? (d) {
                                final box = context.findRenderObject() as RenderBox?;
                                if (box == null) return;
                                // Tapping the bars jumps there.
                                final local = d.localPosition.dx;
                                final width = box.size.width - 60;
                                final f = (local / math.max(1, width)).clamp(0.0, 1.0);
                                player.seek(Duration(
                                    milliseconds: (total.inMilliseconds * f).round()));
                              }
                            : null,
                        child: WaveformBars(
                          samples: media.waveform,
                          progress: progress,
                          height: 28,
                          active: ink,
                          inactive: ink.withValues(alpha: 0.4),
                        ),
                      )
                    else
                      _TransferBar(media: media, onBlue: onBlue),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(
                          formatDuration(shown),
                          style: TextStyle(color: timeColor, fontSize: 11.5),
                        ),
                        const Spacer(),
                        if (current && ready)
                          InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: player.cycleSpeed,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              child: Text(
                                '${state.speed == state.speed.roundToDouble() ? state.speed.toInt() : state.speed}x',
                                style: TextStyle(
                                    color: speedColor,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RoundPlayButton extends StatelessWidget {
  const _RoundPlayButton({
    required this.playing,
    required this.enabled,
    required this.onBlue,
    required this.onPressed,
  });

  final bool playing;
  final bool enabled;

  /// On the blue bubble: a white disc with a blue symbol, which stands out from it.
  final bool onBlue;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final disc = !enabled ? p.offline : (onBlue ? p.onAccent : p.accent);
    return Semantics(
      button: true,
      label: playing ? context.l10n.voicePause : context.l10n.voicePlay,
      child: Material(
        color: disc,
        shape: const CircleBorder(),
        child: InkWell(
          key: const Key('voice-play'),
          customBorder: const CircleBorder(),
          onTap: enabled ? onPressed : null,
          child: SizedBox(
            width: 42,
            height: 42,
            child: Icon(
              playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: onBlue && enabled ? p.accentFill : AppColors.onMedia,
              size: 26,
            ),
          ),
        ),
      ),
    );
  }
}

/// Shows how much of a file has arrived, or why it never will.
class _TransferBar extends StatelessWidget {
  const _TransferBar({required this.media, required this.onBlue});

  final MediaItem media;
  final bool onBlue;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    if (media.state == MediaState.failed) {
      return Text(context.l10n.mediaNotReceived,
          style: TextStyle(color: onBlue ? p.onAccent : p.danger, fontSize: 12.5));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: media.progress == 0 ? null : media.progress,
            minHeight: 5,
            color: onBlue ? p.onAccent : null,
            backgroundColor: onBlue ? p.onAccent.withValues(alpha: 0.3) : p.track,
          ),
        ),
        const SizedBox(height: 4),
        Text(context.l10n.mediaReceiving((media.progress * 100).round()),
            style: TextStyle(color: onBlue ? p.onAccent : p.textSecondary, fontSize: 11.5)),
      ],
    );
  }
}

/// A picture inside a bubble. It reserves its final size from the width and
/// height in the message, so the chat does not jump when the bytes arrive.
class ImageMessageView extends StatefulWidget {
  const ImageMessageView({
    super.key,
    required this.media,
    required this.controller,
    this.onOpen,
    this.maxWidth = 250,
    this.radius = 14,
  });

  final MediaItem media;
  final AppController controller;
  final void Function(Uint8List bytes)? onOpen;
  final double maxWidth;
  final double radius;

  @override
  State<ImageMessageView> createState() => _ImageMessageViewState();
}

class _ImageMessageViewState extends State<ImageMessageView> {
  Future<Uint8List?>? _bytes;
  MediaState? _loadedFor;

  void _maybeLoad() {
    if (widget.media.isReady && _loadedFor != MediaState.ready) {
      _loadedFor = MediaState.ready;
      _bytes = widget.controller.cachedMediaBytes(widget.media);
    }
  }

  @override
  void initState() {
    super.initState();
    _maybeLoad();
  }

  @override
  void didUpdateWidget(ImageMessageView old) {
    super.didUpdateWidget(old);
    if (old.media.id != widget.media.id) {
      _loadedFor = null;
      _bytes = null;
    }
    _maybeLoad();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.media;
    final aspect = (m.width > 0 && m.height > 0 ? m.width / m.height : 4 / 3).clamp(0.6, 1.8);
    final width = widget.maxWidth;
    final height = width / aspect;
    final shape = BorderRadius.circular(widget.radius);

    Widget placeholder(Widget child) => Container(
          width: width,
          height: height,
          decoration: BoxDecoration(color: context.palette.mediaPlaceholder, borderRadius: shape),
          alignment: Alignment.center,
          child: child,
        );

    if (m.state == MediaState.failed) {
      return placeholder(Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.broken_image_outlined, color: context.palette.textMuted, size: 34),
          SizedBox(height: 6),
          Text(context.l10n.pictureNotReceived,
              style: TextStyle(color: context.palette.textMuted, fontSize: 12.5)),
        ],
      ));
    }
    if (!m.isReady) {
      return placeholder(Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: CircularProgressIndicator(
              value: m.progress == 0 ? null : m.progress,
              strokeWidth: 3,
              backgroundColor: context.palette.track,
            ),
          ),
          const SizedBox(height: 8),
          Text('${(m.progress * 100).round()}%',
              style: TextStyle(color: context.palette.textSecondary, fontSize: 12)),
        ],
      ));
    }
    return FutureBuilder<Uint8List?>(
      future: _bytes,
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null) {
          return placeholder(snapshot.connectionState == ConnectionState.done
              ? Icon(Icons.broken_image_outlined, color: context.palette.textMuted)
              : const SizedBox(
                  width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.5)));
        }
        return Semantics(
          image: true,
          label: context.l10n.bubblePicture,
          child: GestureDetector(
            key: const Key('image-open'),
            onTap: widget.onOpen == null ? null : () => widget.onOpen!(bytes),
            child: ClipRRect(
              borderRadius: shape,
              child: Image.memory(
                bytes,
                width: width,
                height: height,
                fit: BoxFit.cover,
                cacheWidth: (width * 2).round(),
                gaplessPlayback: true,
                errorBuilder: (context, error, stack) => placeholder(
                    Icon(Icons.broken_image_outlined, color: context.palette.textMuted)),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A video inside a bubble: a dark card with a play button, its size and length.
/// While it arrives it shows progress; a video that could not be completed says
/// so. There is no preview frame: showing one would need a video decoder for
/// every message, and the card keeps the chat light.
class VideoMessageView extends StatelessWidget {
  const VideoMessageView({
    super.key,
    required this.media,
    required this.controller,
    this.width = 230,
    this.title = '',
  });

  final MediaItem media;
  final AppController controller;
  final double width;

  /// Shown in the player's title bar (who sent it).
  final String title;

  Future<void> _open(BuildContext context) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final l = context.l10n;
    final path = await controller.mediaPath(media);
    if (path == null) {
      messenger.showSnackBar(
          SnackBar(content: Text(l.videoCannotPlay)));
      return;
    }
    await navigator.push(MaterialPageRoute<void>(
      builder: (_) => VideoPlayerScreen(path: path, title: title),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final aspect = (media.width > 0 && media.height > 0 ? media.width / media.height : 16 / 9)
        .clamp(0.6, 1.8);
    final height = width / aspect;
    final shape = BorderRadius.circular(14);

    Widget card(Widget child) => Container(
          width: width,
          height: height,
          decoration: BoxDecoration(color: context.palette.videoCard, borderRadius: shape),
          alignment: Alignment.center,
          child: child,
        );

    if (media.state == MediaState.failed) {
      return card(Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.videocam_off_outlined, color: AppColors.onMediaMuted, size: 34),
          const SizedBox(height: 6),
          Text(context.l10n.videoNotReceived,
              style: const TextStyle(color: AppColors.onMediaMuted, fontSize: 12.5)),
        ],
      ));
    }
    if (!media.isReady) {
      return card(Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: CircularProgressIndicator(
              value: media.progress == 0 ? null : media.progress,
              strokeWidth: 3,
              backgroundColor: AppColors.mediaTrack,
            ),
          ),
          const SizedBox(height: 8),
          Text(context.l10n.videoReceiving((media.progress * 100).round()),
              style: const TextStyle(color: AppColors.onMediaMuted, fontSize: 12)),
        ],
      ));
    }
    final length = media.durationMs > 0 ? '${formatDuration(media.duration)} · ' : '';
    return Semantics(
      button: true,
      label: context.l10n.videoPlay,
      child: GestureDetector(
        key: const Key('video-open'),
        onTap: () => _open(context),
        child: card(Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration:
                  BoxDecoration(color: context.palette.accent, shape: BoxShape.circle),
              child: const Icon(Icons.play_arrow_rounded, color: AppColors.onMedia, size: 34),
            ),
            PositionedDirectional(
              start: 10,
              bottom: 8,
              child: Row(
                children: [
                  const Icon(Icons.videocam_rounded, size: 15, color: AppColors.onMediaMuted),
                  const SizedBox(width: 4),
                  Text('$length${formatBytes(media.byteLength)}',
                      style: const TextStyle(color: AppColors.onMediaMuted, fontSize: 12)),
                ],
              ),
            ),
          ],
        )),
      ),
    );
  }
}
