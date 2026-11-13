import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../theme/app_theme.dart';
import '../l10n/l10n.dart';

/// A video full screen: play and pause, a progress bar you can drag, and the time.
/// The file is played from the app's private folder; nothing leaves the phone.
class VideoPlayerScreen extends StatefulWidget {
  const VideoPlayerScreen({super.key, required this.path, this.title = ''});

  final String path;
  final String title;

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late final VideoPlayerController _controller = VideoPlayerController.file(File(widget.path));
  Object? _error;

  @override
  void initState() {
    super.initState();
    _controller.initialize().then((_) {
      if (!mounted) return;
      setState(() {});
      _controller.play();
    }).catchError((Object e) {
      if (mounted) setState(() => _error = e);
    });
    _controller.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static String _clock(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final value = _controller.value;
    return Scaffold(
      backgroundColor: AppColors.viewerBackground,
      appBar: AppBar(
        backgroundColor: AppColors.mediaBar,
        foregroundColor: AppColors.onMedia,
        title: Text(widget.title, style: const TextStyle(fontSize: 16)),
      ),
      extendBodyBehindAppBar: true,
      body: Center(
        child: _error != null
            ? Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  context.l10n.videoCouldNotPlay,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.palette.textSecondary),
                ),
              )
            : !value.isInitialized
                ? const CircularProgressIndicator()
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AspectRatio(
                        aspectRatio: value.aspectRatio == 0 ? 16 / 9 : value.aspectRatio,
                        child: GestureDetector(
                          key: const Key('video-surface'),
                          onTap: () => value.isPlaying ? _controller.pause() : _controller.play(),
                          child: VideoPlayer(_controller),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                        child: Row(
                          children: [
                            IconButton(
                              key: const Key('video-toggle'),
                              tooltip: value.isPlaying ? context.l10n.commonPause : context.l10n.commonPlay,
                              color: AppColors.onMedia,
                              icon: Icon(value.isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded),
                              onPressed: () => value.isPlaying ? _controller.pause() : _controller.play(),
                            ),
                            Text(_clock(value.position),
                                style: const TextStyle(color: AppColors.onMediaMuted, fontSize: 12.5)),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                child: VideoProgressIndicator(
                                  _controller,
                                  allowScrubbing: true,
                                  colors: VideoProgressColors(
                                    playedColor: context.palette.accent,
                                    bufferedColor: AppColors.mediaTrack,
                                    backgroundColor: AppColors.mediaTrackFaint,
                                  ),
                                ),
                              ),
                            ),
                            Text(_clock(value.duration),
                                style: const TextStyle(color: AppColors.onMediaMuted, fontSize: 12.5)),
                          ],
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}
