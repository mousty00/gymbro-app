import 'package:intl/intl.dart';

/// "adesso", "5 min fa", "3 h fa", "ieri", "12 ott".
String timeAgo(DateTime? date) {
  if (date == null) return '';
  final diff = DateTime.now().difference(date);
  if (diff.inMinutes < 1) return 'adesso';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min fa';
  if (diff.inHours < 24) return '${diff.inHours} h fa';
  if (diff.inDays == 1) return 'ieri';
  if (diff.inDays < 7) return '${diff.inDays} g fa';
  return DateFormat('d MMM', 'it').format(date);
}

String formatDay(DateTime? date) =>
    date == null ? '' : DateFormat('EEE d MMM', 'it').format(date);

String formatDate(DateTime? date) =>
    date == null ? '' : DateFormat('d MMMM yyyy', 'it').format(date);

String formatMonthYear(DateTime? date) =>
    date == null ? '' : DateFormat('MMMM yyyy', 'it').format(date);

String formatDayTime(DateTime? date) =>
    date == null ? '' : DateFormat("EEE d MMM 'alle' HH:mm", 'it').format(date);

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
  if (h < 12) return 'Buongiorno';
  if (h < 18) return 'Buon pomeriggio';
  return 'Buonasera';
}

bool isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

DateTime startOfWeek(DateTime d) {
  final day = DateTime(d.year, d.month, d.day);
  return day.subtract(Duration(days: day.weekday - 1));
}
