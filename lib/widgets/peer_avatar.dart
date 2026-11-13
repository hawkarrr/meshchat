import 'package:flutter/material.dart';

import '../core/bidi.dart';
import '../models/peer.dart';
import '../theme/app_theme.dart';

/// What an avatar stands for.
enum AvatarKind { person, group, room }

/// Round avatar. People get initials on a colour derived from their id (so two
/// people with the same nickname still look different); groups and rooms get an icon.
/// When a [status] is given, a small dot at the corner shows how the person can be
/// reached right now: green when directly connected, blue through a relay, and none
/// when they cannot be reached.
class PeerAvatar extends StatelessWidget {
  const PeerAvatar({
    super.key,
    required this.name,
    required this.seed,
    this.status,
    this.size = AppSizes.avatarList,
    this.kind = AvatarKind.person,
    this.ringColor,
  });

  final String name;

  /// Stable string (the peer id) the colour is derived from.
  final String seed;
  final PeerStatus? status;
  final double size;
  final AvatarKind kind;

  /// The colour of what the avatar sits on: the dot has a ring of it, so it looks cut
  /// out of the avatar. The page's own colour unless given.
  final Color? ringColor;

  static String initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    final first = String.fromCharCode(parts.first.runes.first);
    if (parts.length == 1) return first.toUpperCase();
    return (first + String.fromCharCode(parts.last.runes.first)).toUpperCase();
  }

  Color _hue(double lightness) {
    var h = 0;
    for (final c in seed.codeUnits) {
      h = (h * 31 + c) & 0xffff;
    }
    return HSLColor.fromAHSL(1, (h % 360).toDouble(), 0.5, lightness).toColor();
  }

  @override
  Widget build(BuildContext context) {
    final Widget face;
    switch (kind) {
      case AvatarKind.person:
        face = Text(
          initials(name),
          style: TextStyle(
            color: context.palette.onAccent,
            fontWeight: FontWeight.w700,
            fontSize: size * 0.36,
          ),
        );
      case AvatarKind.group:
        face = Icon(Icons.groups_rounded, size: size * 0.52, color: context.palette.onAccent);
      case AvatarKind.room:
        face = Icon(Icons.tag_rounded, size: size * 0.5, color: context.palette.onAccent);
    }
    final colors = switch (kind) {
      AvatarKind.person => [_hue(0.44), _hue(0.30)],
      AvatarKind.group => AppColors.groupAvatar,
      AvatarKind.room => AppColors.roomAvatar,
    };
    final avatar = SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
        ),
        child: Center(child: face),
      ),
    );
    final dot = switch (status?.reachability) {
      Reachability.direct => context.palette.direct,
      Reachability.relayed => context.palette.relay,
      Reachability.offline || null => null,
    };
    if (dot == null) return avatar;
    final dotSize = size * 0.3;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          PositionedDirectional(
            end: -size * 0.02,
            bottom: -size * 0.02,
            child: Container(
              key: const Key('avatar-online-dot'),
              width: dotSize,
              height: dotSize,
              decoration: BoxDecoration(
                color: dot,
                shape: BoxShape.circle,
                border: Border.all(
                    color: ringColor ?? context.palette.background, width: size * 0.05 + 1),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The name of a person in a shared chat, in their own colour.
class SenderName extends StatelessWidget {
  const SenderName(this.name, {super.key, required this.seed, this.tag, this.fontSize = 13});

  final String name;
  final String seed;

  /// A few characters of the person's id, for a public room, where two people can
  /// have the same name.
  final String? tag;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final color = context.palette.nameColorFor(seed);
    return Text.rich(
      TextSpan(children: [
        TextSpan(
          text: name,
          style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: fontSize),
        ),
        if (tag != null && tag!.isNotEmpty)
          TextSpan(
            // "#79e2" is Latin and digits: left to right as one block, so that the hash
            // does not move to its far side in a right-to-left app.
            text: Directionality.of(context) == TextDirection.rtl
                ? ' $leftToRightIsolate$tag$isolateEnd'
                : ' $tag',
            style: TextStyle(
              color: context.palette.textMuted,
              fontWeight: FontWeight.w500,
              fontSize: fontSize - 1,
            ),
          ),
      ]),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
