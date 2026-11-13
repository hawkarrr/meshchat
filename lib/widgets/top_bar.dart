import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The bar at the top of a place of the home screen (private chats, groups, settings):
/// a flat charcoal strip the width of the screen, under the phone's status bar, with
/// the title at the start and the actions at the end. Conversations have their own
/// ([ChatHeader]); the two share their height and colour.
class AppTopBar extends StatelessWidget {
  const AppTopBar({
    super.key,
    required this.title,
    this.actions = const <Widget>[],
    this.bottom,
  });

  final String title;
  final List<Widget> actions;

  /// Something under the title row, still on the strip: the connection state.
  final Widget? bottom;

  /// The height of the title row.
  static const double height = 60;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.palette.surface,
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: height),
              child: Padding(
                padding: const EdgeInsetsDirectional.only(start: AppSpace.l, end: 4),
                child: Row(
                  children: [
                    // The title gives way (with an ellipsis) before the buttons do.
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    ...actions,
                  ],
                ),
              ),
            ),
            if (bottom != null)
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(AppSpace.l, 0, AppSpace.l, AppSpace.s),
                child: bottom,
              ),
          ],
        ),
      ),
    );
  }
}
