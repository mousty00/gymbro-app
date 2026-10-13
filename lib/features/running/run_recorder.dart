import 'package:latlong2/latlong.dart';

import 'geo.dart';

/// Una posizione GPS.
class Fix {
  const Fix(this.point, {required this.time, this.accuracy = 5, this.altitude});

  final LatLng point;
  final DateTime time;

  /// Raggio di incertezza in metri.
  final double accuracy;
  final double? altitude;
}

/// Registra una corsa a partire dalle posizioni GPS: distanza, tempo in
/// movimento (senza le pause), passo e traccia da salvare. Se c'è un percorso
/// da seguire segnala quando si esce dal tracciato.
///
/// Non sa niente di Flutter né del GPS: riceve le posizioni con [add], così la
/// logica si testa con posizioni finte.
class RunRecorder {
  RunRecorder({this.route = const [], this.offRouteMeters = 40});

  /// Linea del percorso, vuota per una corsa libera.
  final List<LatLng> route;
  final double offRouteMeters;

  /// Posizioni meno precise di così vengono scartate (tipico al chiuso o in partenza).
  static const maxAccuracy = 30.0;

  /// Spostamenti sotto questa soglia sono rumore del GPS da fermi.
  static const minStep = 3.0;

  /// Un passo più veloce di 2'00"/km tra due posizioni è un salto del GPS.
  static const maxSpeed = 8.5;

  DateTime? startedAt;
  DateTime? _segmentStart;
  Duration _moving = Duration.zero;
  bool _paused = false;
  Fix? _last;
  double distance = 0;

  /// `[lat, lng, quota o null, secondi dall'inizio]`, il formato di `POST /runs/create`.
  final List<List<double?>> track = [];
  final List<LatLng> points = [];

  /// (tempo in movimento, distanza) delle ultime posizioni, per il passo attuale.
  final List<(Duration, double)> _recent = [];

  int _offRouteStreak = 0;
  double? distanceFromRoute;

  bool get isRunning => startedAt != null && !_paused;
  bool get isPaused => _paused;

  /// Fuori dal tracciato per almeno 3 posizioni di fila.
  bool get isOffRoute => _offRouteStreak >= 3;

  void start(DateTime now) {
    startedAt = now;
    _segmentStart = now;
  }

  void pause(DateTime now) {
    if (_paused || _segmentStart == null) return;
    _moving += now.difference(_segmentStart!);
    _paused = true;
    _recent.clear();
  }

  void resume(DateTime now) {
    if (!_paused) return;
    _paused = false;
    _segmentStart = now;
    // la prima posizione dopo la pausa riparte da lì, senza contare il tratto fatto da fermi
    _last = null;
  }

  Duration movingTime(DateTime now) =>
      _paused || _segmentStart == null ? _moving : _moving + now.difference(_segmentStart!);

  /// Passo medio in secondi al km.
  int? averagePace(DateTime now) => _pace(movingTime(now), distance);

  /// Passo sugli ultimi ~30 secondi.
  int? currentPace() {
    if (_recent.length < 2) return null;
    final (t0, d0) = _recent.first;
    final (t1, d1) = _recent.last;
    return _pace(t1 - t0, d1 - d0);
  }

  static int? _pace(Duration time, double meters) =>
      meters < 50 ? null : (time.inMilliseconds / meters).round();

  /// Una nuova posizione; ritorna true se è stata usata.
  bool add(Fix fix) {
    if (startedAt == null || _paused || fix.accuracy > maxAccuracy) return false;
    if (route.length >= 2) {
      distanceFromRoute = distanceToLine(fix.point, route);
      _offRouteStreak = distanceFromRoute! > offRouteMeters + fix.accuracy / 2 ? _offRouteStreak + 1 : 0;
    }
    final last = _last;
    if (last != null) {
      final step = metersBetween(last.point, fix.point);
      final seconds = fix.time.difference(last.time).inMilliseconds / 1000;
      if (step < minStep) return false;
      if (seconds > 0 && step / seconds > maxSpeed) return false;
      distance += step;
    }
    _last = fix;
    points.add(fix.point);
    track.add([
      fix.point.latitude,
      fix.point.longitude,
      fix.altitude,
      fix.time.difference(startedAt!).inMilliseconds / 1000,
    ]);
    final moving = movingTime(fix.time);
    _recent.add((moving, distance));
    while (_recent.length > 2 && (moving - _recent.first.$1).inSeconds > 30) {
      _recent.removeAt(0);
    }
    return true;
  }
}
