import 'package:flutter/material.dart';

import 'app_theme.dart';

/// The page behind everything: near-black, with the faintest blue at the top.
///
/// It is painted once from plain gradients (no blur filter, no animation), so it
/// costs next to nothing - including while the keyboard slides in.
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [context.palette.backgroundTop, context.palette.background, context.palette.backgroundDeep],
          stops: [0, 0.4, 1],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(child: RepaintBoundary(child: _Glow())),
          child,
        ],
      ),
    );
  }
}

/// One soft blue light from the top corner: a highlight, not a pattern.
class _Glow extends StatelessWidget {
  const _Glow();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0.9, -1.0),
            radius: 0.95,
            colors: [
              context.palette.accent.withValues(alpha: 0.1),
              context.palette.accent.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}

/// A [Scaffold] on the app background, so an app bar, the body and the floating
/// button all share one gradient.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.floatingActionButton,
    this.resizeToAvoidBottomInset = true,
  });

  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? floatingActionButton;
  final bool resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: resizeToAvoidBottomInset,
        appBar: appBar,
        floatingActionButton: floatingActionButton,
        body: body,
      ),
    );
  }
}

/// A flat layer of charcoal with rounded corners: the one surface of the interface.
///
/// No border and no shadow unless asked for. [raised] is a step lighter, for what
/// sits on another panel or must stand out; [tint] washes it with a colour (an
/// attention banner, a chosen row); [outlined] draws the hairline.
class AppPanel extends StatelessWidget {
  const AppPanel({
    super.key,
    required this.child,
    this.radius = AppRadii.lg,
    this.padding,
    this.margin,
    this.raised = false,
    this.tint,
    this.outlined = false,
    this.borderColor,
    this.width,
    this.height,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  /// One step lighter than the ordinary layer.
  final bool raised;

  /// Colours the layer (an accent-tinted panel).
  final Color? tint;

  /// A hairline around it. Rarely needed.
  final bool outlined;
  final Color? borderColor;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final base = raised ? context.palette.surfaceHigh : context.palette.surface;
    final fill = tint == null ? base : Color.alphaBlend(tint!.withValues(alpha: 0.16), base);
    final border = borderColor != null
        ? Border.all(color: borderColor!)
        : (outlined ? Border.all(color: context.palette.outline) : null);
    Widget panel = DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(radius),
        border: border,
      ),
      // Ink (a tapped row inside the panel) paints on the nearest Material, which has to
      // be above the colour of the panel or the colour would hide it.
      child: Material(
        type: MaterialType.transparency,
        child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
      ),
    );
    if (width != null || height != null) {
      panel = SizedBox(width: width, height: height, child: panel);
    }
    if (margin != null) panel = Padding(padding: margin!, child: panel);
    return panel;
  }
}

/// A round button with an icon (back, search, menu...): a charcoal disc, the brand
/// blue when it is the main action, or just the icon ([flat]) on a bar.
class RoundButton extends StatelessWidget {
  const RoundButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.size = AppSizes.tap,
    this.color,
    this.filled = false,
    this.flat = false,
    this.badge = 0,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;
  final Color? color;

  /// A solid blue button (the primary action).
  final bool filled;

  /// No disc behind the icon: for the buttons of a bar, where a disc would be noise.
  final bool flat;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final fg = filled ? context.palette.onAccent : (color ?? context.palette.text);
    Widget button = Semantics(
      button: true,
      enabled: enabled,
      label: tooltip,
      child: Material(
        color: filled
            ? context.palette.accentFill
            : (flat ? Colors.transparent : context.palette.surfaceHigh),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon,
                size: flat ? AppSizes.icon : size * 0.5,
                color: enabled ? fg : fg.withValues(alpha: 0.4)),
          ),
        ),
      ),
    );
    if (badge > 0) {
      button = Badge(label: Text(badge > 99 ? '99+' : '$badge'), child: button);
    }
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

/// The count badge used in conversation lists.
class UnreadBadge extends StatelessWidget {
  const UnreadBadge(this.count, {super.key});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      constraints: const BoxConstraints(minWidth: 22),
      decoration: BoxDecoration(
        color: context.palette.accentFill,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12,
          height: 1.25,
          fontWeight: FontWeight.w700,
          color: context.palette.onAccent,
        ),
      ),
    );
  }
}

/// A bottom sheet: a charcoal layer with rounded top corners and a handle, as in
/// Telegram. It rises above the keyboard and respects the phone's own bottom bar.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    backgroundColor: Colors.transparent,
    barrierColor: context.palette.scrim,
    // The sheet draws its own handle.
    showDragHandle: false,
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
        // A Material, not a coloured box: a tapped row in the sheet needs it for its ink.
        child: Material(
          color: context.palette.surface,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: context.palette.outline,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Flexible(child: builder(context)),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// The look of a dialog: a rounded charcoal layer with a title, an optional message
/// and content, and a row of actions. Use it as the whole body of a [Dialog] (see
/// [showAppDialog]) - or inside a dialog that keeps its own state, such as one with a
/// text field.
class AppDialogFrame extends StatelessWidget {
  const AppDialogFrame({
    super.key,
    required this.title,
    this.message,
    this.content,
    required this.actions,
  });

  final String title;
  final String? message;
  final Widget? content;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: AppPanel(
        radius: AppRadii.xl,
        raised: true,
        padding: const EdgeInsets.fromLTRB(22, 22, 14, 10),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          // Long explanations scroll instead of overflowing small screens.
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
                ),
                if (message != null) ...[
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: Text(message!,
                        style: TextStyle(
                            color: context.palette.textSecondary, fontSize: 14.5, height: 1.45)),
                  ),
                ],
                if (content != null) ...[
                  const SizedBox(height: 12),
                  Padding(padding: const EdgeInsetsDirectional.only(end: 8), child: content!),
                ],
                const SizedBox(height: 10),
                // Full width, so the buttons sit at the end edge as in any dialog.
                SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 4,
                    runSpacing: 4,
                    children: actions,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A dialog with a title, message and actions. For a dialog with a text field, write
/// a small stateful widget around [AppDialogFrame] so the controller lives exactly as
/// long as the dialog does.
Future<T?> showAppDialog<T>({
  required BuildContext context,
  required String title,
  Widget? content,
  String? message,
  required List<Widget> actions,
  bool barrierDismissible = true,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: context.palette.scrim,
    builder: (context) => AppDialogFrame(
      title: title,
      message: message,
      content: content,
      actions: actions,
    ),
  );
}

/// The look of the button that does something that cannot be undone: red, with dark
/// text (white on this red would not be readable).
ButtonStyle dangerButtonStyle(BuildContext context) => FilledButton.styleFrom(
      backgroundColor: context.palette.danger,
      foregroundColor: context.palette.onStatus,
    );
