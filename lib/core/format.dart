import '../l10n/l10n.dart';

/// Short time formatting for chat lists and bubbles. The clock and dates use the
/// same digits in every language; the words ("Yesterday", "5 min ago", the days
/// of the week) come from the app's text in the language being shown.
String two(int v) => v.toString().padLeft(2, '0');

String formatClock(int ms) {
  final t = DateTime.fromMillisecondsSinceEpoch(ms);
  return '${two(t.hour)}:${two(t.minute)}';
}

String formatClockSeconds(int ms) {
  final t = DateTime.fromMillisecondsSinceEpoch(ms);
  return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
}

/// "14:03" today, "Yesterday", a weekday within the last week, else "12/09".
String formatListTime(int ms, AppLocalizations l, {DateTime? now}) {
  final t = DateTime.fromMillisecondsSinceEpoch(ms);
  final n = now ?? DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  final day = DateTime(t.year, t.month, t.day);
  final diff = today.difference(day).inDays;
  if (diff <= 0) return formatClock(ms);
  if (diff == 1) return l.timeYesterday;
  if (diff < 7) {
    final names = [
      l.weekdayMon,
      l.weekdayTue,
      l.weekdayWed,
      l.weekdayThu,
      l.weekdayFri,
      l.weekdaySat,
      l.weekdaySun,
    ];
    return names[t.weekday - 1];
  }
  return '${two(t.day)}/${two(t.month)}';
}

/// "just now", "5 min ago", "2 h ago", "3 d ago".
String formatAgo(int ms, AppLocalizations l, {int? nowMs}) {
  final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
  final s = ((now - ms) / 1000).round();
  if (s < 10) return l.agoJustNow;
  if (s < 60) return l.agoSeconds(s);
  final m = s ~/ 60;
  if (m < 60) return l.agoMinutes(m);
  final h = m ~/ 60;
  if (h < 48) return l.agoHours(h);
  return l.agoDays(h ~/ 24);
}

String formatDateTime(int ms) {
  final t = DateTime.fromMillisecondsSinceEpoch(ms);
  return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
}

/// Signal strength as a 0..4 bar count.
int rssiBars(int rssi) {
  if (rssi >= -60) return 4;
  if (rssi >= -70) return 3;
  if (rssi >= -80) return 2;
  if (rssi >= -90) return 1;
  return 0;
}

String formatBytes(int n) {
  if (n < 1024) return '$n B';
  if (n < 1024 * 1024) return '${(n / 1024).toStringAsFixed(1)} KB';
  return '${(n / 1024 / 1024).toStringAsFixed(1)} MB';
}
