import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A setting that is on or off: an icon, a title with the switch beside it, and
/// the explanation under the title across the full width.
///
/// Putting the switch on the title's line - not at the far side of the whole row,
/// as a list tile does - leaves the explanation the width of the card minus the
/// icon. That matters in languages whose sentences are longer than English and
/// with large system text, where a list tile squeezes the explanation into a
/// column a few letters wide.
class SettingSwitch extends StatelessWidget {
  const SettingSwitch({
    super.key,
    this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
    this.padding = const EdgeInsetsDirectional.fromSTEB(16, 8, 8, 12),
  });

  /// Left out where the switch sits inside a section that already has its own icon.
  final IconData? icon;
  final String title;
  final String? subtitle;
  final bool value;

  /// Null makes the whole row inert and dims it, like a disabled switch.
  final ValueChanged<bool>? onChanged;
  final EdgeInsetsGeometry padding;

  /// The icon's width and the gap after it: where the words start.
  static const double _iconSlot = 24 + 16;

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    final textColor = enabled ? null : context.palette.textMuted;
    return MergeSemantics(
      child: InkWell(
        onTap: enabled ? () => onChanged!(!value) : null,
        child: Padding(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: context.palette.textMuted),
                    const SizedBox(width: 16),
                  ],
                  Expanded(child: Text(title, style: TextStyle(fontSize: 16, color: textColor))),
                  Switch(value: value, onChanged: onChanged),
                ],
              ),
              if (subtitle != null)
                Padding(
                  padding: EdgeInsetsDirectional.only(start: icon == null ? 0 : _iconSlot, end: 8),
                  child: Text(
                    subtitle!,
                    style: TextStyle(color: context.palette.textMuted, fontSize: 13.5, height: 1.3),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
