import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/surfaces.dart';
import '../l10n/l10n.dart';

/// The top bar of a conversation: back, avatar, name, a live status line and
/// actions, on a flat charcoal bar that runs the width of the screen.
class ChatHeader extends StatelessWidget {
  const ChatHeader({
    super.key,
    required this.avatar,
    required this.title,
    this.subtitle,
    this.subtitleColor,
    this.actions = const <Widget>[],
    this.onTap,
    this.titleSuffix,
    this.titleKey,
    this.subtitleWidget,
  });

  final Widget avatar;
  final String title;
  final String? subtitle;

  /// The colour of the subtitle; the muted text colour unless given.
  final Color? subtitleColor;
  final List<Widget> actions;

  /// Tapping the name opens the details (person, group).
  final VoidCallback? onTap;

  /// A small mark after the name (the arrow that says the name opens a list).
  final Widget? titleSuffix;

  /// The key of the tappable name area.
  final Key? titleKey;

  /// Instead of the [subtitle] text: a line with an icon, such as the connection state.
  final Widget? subtitleWidget;

  /// The height of the bar below the phone's status bar.
  static const double height = 60;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.palette.surface,
      child: SafeArea(
        bottom: false,
        // At least the height of the bar; taller when large system text needs it.
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: height),
          child: Padding(
            padding: const EdgeInsetsDirectional.only(start: 4, end: 4),
            child: Row(
              children: [
                // This page's own back button: a sheet or a dialog opened above the page
                // does not make one appear.
                if (ModalRoute.of(context)?.canPop ?? false)
                  RoundButton(
                    key: const Key('header-back'),
                    icon: Icons.arrow_back_rounded,
                    tooltip: context.l10n.commonBack,
                    flat: true,
                    onPressed: () => Navigator.of(context).maybePop(),
                  )
                else
                  const SizedBox(width: AppSpace.s),
                Expanded(
                  child: InkWell(
                    key: titleKey,
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    onTap: onTap,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                      child: Row(
                        children: [
                          avatar,
                          const SizedBox(width: AppSpace.m),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontSize: 17, fontWeight: FontWeight.w600, height: 1.25),
                                      ),
                                    ),
                                    ?titleSuffix,
                                  ],
                                ),
                                if (subtitleWidget != null)
                                  subtitleWidget!
                                else if (subtitle != null && subtitle!.isNotEmpty)
                                  Text(
                                    subtitle!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 12.5, height: 1.3, color: subtitleColor ?? context.palette.textMuted),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                ...actions,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
