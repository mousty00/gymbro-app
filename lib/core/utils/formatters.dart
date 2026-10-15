import 'package:intl/intl.dart';

import '../l10n/l10n.dart';

/// "adesso", "5 min fa", "3 h fa", "ieri", "12 ott".
String timeAgo(DateTime? date) {
  if (date == null) return '';
  final diff = DateTime.now().difference(date);
  if (diff.inMinutes < 1) return tr('adesso');
  if (diff.inMinutes < 60) return tr('{n} min fa', {'n': diff.inMinutes});
  if (diff.inHours < 24) return tr('{n} h fa', {'n': diff.inHours});
  if (diff.inDays == 1) return tr('ieri');
  if (diff.inDays < 7) return tr('{n} g fa', {'n': diff.inDays});
  return DateFormat('d MMM', L10n.lang).format(date);
}

String formatDay(DateTime? date) =>
    date == null ? '' : DateFormat('EEE d MMM', L10n.lang).format(date);

String formatDate(DateTime? date) =>
    date == null ? '' : DateFormat('d MMMM yyyy', L10n.lang).format(date);

String formatMonthYear(DateTime? date) =>
    date == null ? '' : DateFormat('MMMM yyyy', L10n.lang).format(date);

String formatDayTime(DateTime? date) =>
    date == null ? '' : DateFormat(tr('EEE d MMM \'alle\' HH:mm'), L10n.lang).format(date);

String formatTime(DateTime? date) => date == null ? '' : DateFormat('HH:mm').format(date);

String formatDuration(Duration? d) {
  if (d == null) return '—';
  if (d.inMinutes < 60) return '${d.inMinutes} min';
  final m = d.inMinutes.remainder(60);
  return m == 0 ? '${d.inHours} h' : '${d.inHours} h $m min';
}

String formatClock(Duration d) {
  String two(int n) => n.toString().padLeft(2, '0');
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
}

String greeting() {
  final h = DateTime.now().hour;
  if (h < 12) return tr('Buongiorno');
  if (h < 18) return tr('Buon pomeriggio');
  return tr('Buonasera');
}

bool isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

DateTime startOfWeek(DateTime d) {
  final day = DateTime(d.year, d.month, d.day);
  return day.subtract(Duration(days: day.weekday - 1));
}
