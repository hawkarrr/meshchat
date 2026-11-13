import 'package:flutter/material.dart';

import '../core/format.dart';
import '../l10n/l10n.dart';
import '../theme/app_theme.dart';
import '../theme/surfaces.dart';

/// Whether two moments (milliseconds since 1970) fall on the same day.
bool sameDay(int a, int b) {
  final x = DateTime.fromMillisecondsSinceEpoch(a);
  final y = DateTime.fromMillisecondsSinceEpoch(b);
  return x.year == y.year && x.month == y.month && x.day == y.day;
}

/// "Today", or the date: the small pill between two days of a conversation.
class DateChip extends StatelessWidget {
  const DateChip({super.key, required this.ms});

  final int ms;

  @override
  Widget build(BuildContext context) {
    final t = DateTime.fromMillisecondsSinceEpoch(ms);
    final today = DateTime.now();
    final label = (t.year == today.year && t.month == today.month && t.day == today.day)
        ? context.l10n.chatToday
        : '${t.year}-${two(t.month)}-${two(t.day)}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.s),
      child: AppPanel(
        radius: AppRadii.pill,
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.m, vertical: 3),
        child: Text(label, style: TextStyle(color: context.palette.textSecondary, fontSize: 12)),
      ),
    );
  }
}
