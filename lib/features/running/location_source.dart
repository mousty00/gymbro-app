import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../core/config/env.dart';
import 'geo.dart';
import 'run_recorder.dart';

/// Perché non si può usare il GPS, in parole per l'utente.
class LocationUnavailable implements Exception {
  const LocationUnavailable(this.message, {this.openSettings = false});

  final String message;

  /// Il permesso è negato per sempre: serve andare nelle impostazioni.
  final bool openSettings;

  @override
  String toString() => message;
}

/// Sorgente delle posizioni durante la corsa.
abstract class LocationSource {
  /// Chiede i permessi se servono; lancia [LocationUnavailable] se il GPS non si può usare.
  Future<void> ensureReady();

  Future<LatLng?> current();

  Stream<Fix> fixes();

  /// In modalità mock (`Env.useMock`) si corre in simulazione lungo il percorso,
  /// così il flusso si prova anche sul simulatore o nel browser.
  static LocationSource create({List<LatLng> route = const []}) =>
      Env.useMock ? SimulatedLocation(route) : GpsLocation();
}

/// GPS vero. Basta il permesso "mentre usi l'app": la registrazione continua a
/// schermo spento grazie al servizio in primo piano (Android, con notifica) e
/// alla modalità background `location` (iOS, con l'indicatore blu).
class GpsLocation implements LocationSource {
  @override
  Future<void> ensureReady() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationUnavailable('Attiva la localizzazione del telefono per registrare la corsa.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationUnavailable(
        'RepBirds non ha accesso alla posizione. Consentilo nelle impostazioni per registrare la corsa.',
        openSettings: true,
      );
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.unableToDetermine) {
      throw const LocationUnavailable('Serve la posizione per registrare la corsa.');
    }
  }

  @override
  Future<LatLng?> current() async {
    try {
      final p = await Geolocator.getLastKnownPosition() ??
          await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(timeLimit: Duration(seconds: 10)));
      return LatLng(p.latitude, p.longitude);
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<Fix> fixes() {
    final LocationSettings settings = switch (defaultTargetPlatform) {
      TargetPlatform.android when !kIsWeb => AndroidSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 3,
          intervalDuration: const Duration(seconds: 1),
          foregroundNotificationConfig: const ForegroundNotificationConfig(
            notificationTitle: 'RepBirds sta registrando la corsa',
            notificationText: 'Tocca per tornare alla corsa',
            notificationChannelName: 'Corsa',
            enableWakeLock: true,
            setOngoing: true,
          ),
        ),
      TargetPlatform.iOS when !kIsWeb => AppleSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          activityType: ActivityType.fitness,
          distanceFilter: 3,
          pauseLocationUpdatesAutomatically: false,
          showBackgroundLocationIndicator: true,
          allowBackgroundLocationUpdates: true,
        ),
      _ => const LocationSettings(accuracy: LocationAccuracy.best, distanceFilter: 3),
    };
    return Geolocator.getPositionStream(locationSettings: settings).map(
      (p) => Fix(
        LatLng(p.latitude, p.longitude),
        time: p.timestamp,
        accuracy: p.accuracy,
        altitude: p.altitude == 0 ? null : p.altitude,
      ),
    );
  }
}

/// Corsa simulata lungo [route] a 5'30"/km, una posizione al secondo.
class SimulatedLocation implements LocationSource {
  SimulatedLocation(List<LatLng> route)
      : _route = route.length >= 2 ? route : const [LatLng(45.4642, 9.1900), LatLng(45.4720, 9.1780)];

  final List<LatLng> _route;
  static const speed = 1000 / 330; // m/s

  @override
  Future<void> ensureReady() async {}

  @override
  Future<LatLng?> current() async => _route.first;

  @override
  Stream<Fix> fixes() async* {
    var segment = 0;
    var along = 0.0;
    var position = _route.first;
    while (segment < _route.length - 1) {
      await Future<void>.delayed(const Duration(seconds: 1));
      var step = speed;
      while (step > 0 && segment < _route.length - 1) {
        final a = _route[segment];
        final b = _route[segment + 1];
        final length = metersBetween(a, b);
        if (along + step < length) {
          along += step;
          step = 0;
          final t = length == 0 ? 0.0 : along / length;
          position = LatLng(a.latitude + (b.latitude - a.latitude) * t, a.longitude + (b.longitude - a.longitude) * t);
        } else {
          step -= length - along;
          along = 0;
          segment++;
          position = b;
        }
      }
      yield Fix(position, time: DateTime.now(), accuracy: 4);
    }
  }
}
