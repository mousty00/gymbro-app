// Helper di parsing tolleranti per i tipi java.time serializzati dal backend.

typedef Json = Map<String, dynamic>;

DateTime? parseInstant(Object? v) {
  if (v == null) return null;
  if (v is num) {
    // epoch seconds (con decimali) nel caso il backend scriva timestamp numerici
    return DateTime.fromMillisecondsSinceEpoch((v * 1000).round(), isUtc: true).toLocal();
  }
  return DateTime.tryParse(v.toString())?.toLocal();
}

DateTime? parseLocalDate(Object? v) {
  if (v == null) return null;
  if (v is List && v.length >= 3) {
    return DateTime(v[0] as int, v[1] as int, v[2] as int);
  }
  return DateTime.tryParse(v.toString());
}

String? formatLocalDate(DateTime? d) {
  if (d == null) return null;
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year.toString().padLeft(4, '0')}-${two(d.month)}-${two(d.day)}';
}

/// Orario locale (java.time.LocalTime), es. "07:30" o "07:30:00".
class TimeOfDayValue {
  const TimeOfDayValue(this.hour, this.minute);

  final int hour;
  final int minute;

  static TimeOfDayValue? parse(Object? v) {
    if (v == null) return null;
    if (v is List && v.length >= 2) return TimeOfDayValue(v[0] as int, v[1] as int);
    final parts = v.toString().split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDayValue(h, m);
  }

  String toJson() => '$label:00';

  String get label =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

List<T> parseList<T>(Object? v, T Function(Json) fromJson) {
  if (v is! List) return const [];
  return v.whereType<Map>().map((e) => fromJson(Map<String, dynamic>.from(e))).toList();
}

double? parseDouble(Object? v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

int parseInt(Object? v, [int fallback = 0]) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse('$v') ?? fallback;
}
