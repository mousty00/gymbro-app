import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

// Calcoli geografici e formati della corsa, senza Flutter così si testano facilmente.

const _distance = Distance();

double metersBetween(LatLng a, LatLng b) => _distance.as(LengthUnit.Meter, a, b);

double lengthOf(List<LatLng> points) {
  var total = 0.0;
  for (var i = 1; i < points.length; i++) {
    total += metersBetween(points[i - 1], points[i]);
  }
  return total;
}

/// Distanza in metri da [p] al segmento più vicino della linea. Su poche
/// centinaia di metri la proiezione equirettangolare è precisa al metro.
double distanceToLine(LatLng p, List<LatLng> line) {
  if (line.isEmpty) return double.infinity;
  if (line.length == 1) return metersBetween(p, line.first);
  const r = 6371008.8;
  final cosLat = math.cos(p.latitudeInRad);
  math.Point<double> project(LatLng q) => math.Point(
        (q.longitudeInRad - p.longitudeInRad) * cosLat * r,
        (q.latitudeInRad - p.latitudeInRad) * r,
      );
  var best = double.infinity;
  var a = project(line.first);
  for (var i = 1; i < line.length; i++) {
    final b = project(line[i]);
    final dx = b.x - a.x;
    final dy = b.y - a.y;
    final len2 = dx * dx + dy * dy;
    // p è l'origine: punto del segmento più vicino a (0, 0)
    final t = len2 == 0 ? 0.0 : (-(a.x * dx + a.y * dy) / len2).clamp(0.0, 1.0);
    final x = a.x + t * dx;
    final y = a.y + t * dy;
    best = math.min(best, math.sqrt(x * x + y * y));
    a = b;
  }
  return best;
}

/// "850 m", "5,2 km", "12,0 km".
String formatDistance(num meters) {
  if (meters < 1000) return '${meters.round()} m';
  return '${(meters / 1000).toStringAsFixed(meters < 100000 ? 2 : 1).replaceAll('.', ',')} km';
}

/// Passo in minuti e secondi al km: 5'30".
String formatPace(int? secondsPerKm) {
  if (secondsPerKm == null || secondsPerKm <= 0 || secondsPerKm > 3600) return '–';
  final m = secondsPerKm ~/ 60;
  final s = secondsPerKm % 60;
  return "$m'${s.toString().padLeft(2, '0')}\"";
}

String formatSeconds(int seconds) {
  String two(int n) => n.toString().padLeft(2, '0');
  final h = seconds ~/ 3600;
  final m = (seconds ~/ 60) % 60;
  final s = seconds % 60;
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
}

/// Tempo stimato a un passo tranquillo (6'00"/km), per i percorsi.
String estimateTime(int meters) {
  final minutes = (meters / 1000 * 6).round();
  if (minutes < 60) return '~$minutes min';
  return '~${minutes ~/ 60} h ${(minutes % 60).toString().padLeft(2, '0')}';
}
