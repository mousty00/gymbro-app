import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../core/network/api_client.dart';
import '../models/json.dart';
import '../models/page.dart';
import '../models/running.dart';

/// Corsa: percorsi (`/routes`), corse di gruppo (`/run-events`) e corse registrate (`/runs`).
class RunningRepository {
  RunningRepository(this._api);

  final ApiClient _api;

  // Percorsi

  Future<List<RunRoute>> myRoutes() async {
    final res = await _api.get<Json>('/routes', query: {'page': 0, 'size': 100});
    return PageResult.fromJson(res, RunRoute.fromJson).results;
  }

  /// Percorsi pubblici dei miei amici.
  Future<List<RunRoute>> friendsRoutes() async {
    final res = await _api.get<Json>('/routes/friends', query: {'page': 0, 'size': 100});
    return PageResult.fromJson(res, RunRoute.fromJson).results;
  }

  Future<RunRoute> route(String id) async => RunRoute.fromJson(await _api.get<Json>('/routes/$id'));

  /// Aggancia i punti toccati a strade e sentieri (lato server); niente viene salvato.
  Future<RoutePlan> plan(List<LatLng> waypoints, {bool trails = false}) async => RoutePlan.fromJson(
        await _api.post<Json>('/routes/plan', data: {'waypoints': pointsToJson(waypoints), 'trails': trails}),
      );

  Future<RunRoute> saveRoute({
    String? id,
    required String name,
    String? description,
    required bool isPublic,
    required List<LatLng> waypoints,
    List<List<double>>? points,
    bool trails = false,
  }) async {
    final data = {
      'name': name,
      'description': description,
      'isPublic': isPublic,
      'waypoints': pointsToJson(waypoints),
      'points': points,
      'trails': trails,
    };
    final res = id == null
        ? await _api.post<Json>('/routes/create', data: data)
        : await _api.put<Json>('/routes/update/$id', data: data);
    return RunRoute.fromJson(Map<String, dynamic>.from(res['result'] as Map));
  }

  Future<void> deleteRoute(String id) => _api.delete<dynamic>('/routes/delete/$id');

  /// Salva una copia privata del percorso pubblico di un amico.
  Future<RunRoute> copyRoute(String id) async {
    final res = await _api.post<Json>('/routes/$id/save');
    return RunRoute.fromJson(Map<String, dynamic>.from(res['result'] as Map));
  }

  Future<String> routeGpx(String id) => _api.get<String>('/routes/$id/gpx');

  // Corse di gruppo

  Future<List<RunEvent>> events() async {
    final res = await _api.get<Json>('/run-events', query: {'page': 0, 'size': 100});
    return PageResult.fromJson(res, RunEvent.fromJson).results;
  }

  Future<RunEvent> event(String id) async => RunEvent.fromJson(await _api.get<Json>('/run-events/$id'));

  Future<RunEvent> createEvent({
    required String routeId,
    required String title,
    required DateTime startsAt,
    String? meetingPoint,
    String? notes,
    List<String> invited = const [],
  }) async {
    final res = await _api.post<Json>('/run-events/create', data: {
      'routeId': routeId,
      'title': title,
      'startsAt': startsAt.toUtc().toIso8601String(),
      'meetingPoint': meetingPoint,
      'notes': notes,
      'invitedUsernames': invited,
    });
    return RunEvent.fromJson(Map<String, dynamic>.from(res['result'] as Map));
  }

  Future<void> invite(String eventId, String username) =>
      _api.post<dynamic>('/run-events/$eventId/invite', data: {'username': username});

  Future<void> accept(String eventId) => _api.post<dynamic>('/run-events/$eventId/accept');

  Future<void> reject(String eventId) => _api.post<dynamic>('/run-events/$eventId/reject');

  /// Uscire da una corsa o togliere un partecipante (se sei l'organizzatore).
  Future<void> removeParticipant(String participantId) =>
      _api.delete<dynamic>('/run-events/participants/$participantId');

  Future<void> deleteEvent(String id) => _api.delete<dynamic>('/run-events/delete/$id');

  Future<List<RunActivity>> eventRuns(String id) async =>
      parseList(await _api.get<List<dynamic>>('/run-events/$id/runs'), RunActivity.fromJson);

  // Corse registrate

  Future<List<RunActivity>> myRuns() async {
    final res = await _api.get<Json>('/runs', query: {'page': 0, 'size': 50});
    return PageResult.fromJson(res, RunActivity.fromJson).results;
  }

  Future<RunActivity> run(String id) async => RunActivity.fromJson(await _api.get<Json>('/runs/$id'));

  Future<RunActivity> saveRun({
    String? routeId,
    String? eventId,
    required DateTime startedAt,
    required DateTime completedAt,
    required int durationS,
    required List<List<double?>> track,
    String? notes,
  }) async {
    final res = await _api.post<Json>('/runs/create', data: {
      'routeId': routeId,
      'eventId': eventId,
      'startedAt': startedAt.toUtc().toIso8601String(),
      'completedAt': completedAt.toUtc().toIso8601String(),
      'durationS': durationS,
      'track': track,
      'notes': notes,
    });
    return RunActivity.fromJson(Map<String, dynamic>.from(res['result'] as Map));
  }

  Future<void> deleteRun(String id) => _api.delete<dynamic>('/runs/delete/$id');

  Future<String> runGpx(String id) => _api.get<String>('/runs/$id/gpx');
}

final runningRepositoryProvider =
    Provider<RunningRepository>((ref) => RunningRepository(ref.watch(apiClientProvider)));
