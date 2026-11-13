import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/app_theme.dart';
import '../theme/surfaces.dart';
import '../theme/motion.dart';
import 'ghost_mark.dart';

/// A friendly explanation shown instead of an empty list: the little ghost, what is
/// (not) here, and what to do about it. The ghost's face follows the mood of the
/// screen - asleep where nothing has happened yet, curious where something is being
/// looked for, pleased where all is well, sheepish where nothing was found.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    this.mood = GhostMood.sleepy,
    required this.title,
    required this.message,
    this.action,
  });

  final GhostMood mood;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    // Scrolls instead of overflowing when the space is short (small phones,
    // landscape, large text sizes).
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GhostMark(size: 104, mood: mood, float: true),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(color: context.palette.textMuted, height: 1.4),
              ),
              if (action != null) ...[const SizedBox(height: 20), action!],
            ],
          ),
        ),
      ),
    );
  }
}

/// What a conversation shows until its first message: the ghost, a greeting that
/// names the other side, and a line about who can read what is written here. It
/// comes in once, with a short rise and fade, and is gone with the first message.
class ChatIntro extends StatelessWidget {
  const ChatIntro({super.key, required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: 1),
          duration: AppMotion.of(context, AppMotion.enter),
          curve: AppMotion.out,
          builder: (context, t, child) => Opacity(
            opacity: t,
            child: Transform.translate(offset: Offset(0, 10 * (1 - t)), child: child),
          ),
          child: AppPanel(
            key: const Key('chat-intro'),
            radius: 26,
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const GhostMark(size: 88, mood: GhostMood.happy, float: true),
                const SizedBox(height: 8),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.palette.textSecondary, height: 1.4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// What a screen shows when it could not read what it needs: the ghost looking
/// sheepish, what went wrong in a line, and a button to try again.
class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      mood: GhostMood.oops,
      title: title,
      message: message,
      action: FilledButton.icon(
        key: const Key('retry'),
        onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded),
        label: Text(context.l10n.commonTryAgain),
      ),
    );
  }
}
