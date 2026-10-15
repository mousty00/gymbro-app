import 'package:latlong2/latlong.dart';

import '../core/l10n/l10n.dart';
import 'json.dart';
import 'user.dart';

/// Punti `[lat, lng]` o `[lat, lng, quota]` del backend.
List<LatLng> parsePoints(Object? v) {
  if (v is! List) return const [];
  return [
    for (final p in v)
      if (p is List && p.length >= 2 && p[0] is num && p[1] is num) LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble()),
  ];
}

/// Come [parsePoints] ma tiene tutte le coordinate (la quota serve al backend).
List<List<double>> parseRawPoints(Object? v) => [
      if (v is List)
        for (final p in v)
          if (p is List) [for (final c in p) if (c is num) c.toDouble()],
    ];

List<List<double>> pointsToJson(List<LatLng> points) => [
      for (final p in points) [p.latitude, p.longitude],
    ];

/// Un percorso di corsa disegnato sulla mappa (`RunRouteDTO`).
class RunRoute {
  const RunRoute({
    required this.id,
    required this.name,
    required this.owner,
    required this.waypoints,
    required this.points,
    required this.distanceM,
    this.description,
    this.isPublic = false,
    this.originalAuthor,
    this.sourceRouteId,
    this.elevationGainM,
    this.rawPoints = const [],
    this.createdAt,
  });

  final String id;
  final String name;
  final String? description;
  final bool isPublic;
  final SimpleUser owner;

  /// Su una copia salvata dal percorso di un amico: chi l'ha disegnato.
  final SimpleUser? originalAuthor;
  final String? sourceRouteId;

  /// I punti toccati dall'utente, per modificarlo.
  final List<LatLng> waypoints;

  /// La linea da seguire.
  final List<LatLng> points;

  /// [points] come arrivano dal backend (con la quota, se c'è).
  final List<List<double>> rawPoints;
  final int distanceM;
  final int? elevationGainM;
  final DateTime? createdAt;

  bool isMine(String username) => owner.username == username;

  factory RunRoute.fromJson(Json j) => RunRoute(
        id: '${j['id']}',
        name: j['name'] as String? ?? '',
        description: j['description'] as String?,
        isPublic: j['isPublic'] == true,
        owner: SimpleUser.fromJson(Map<String, dynamic>.from(j['owner'] as Map? ?? const {})),
        originalAuthor: j['originalAuthor'] is Map
            ? SimpleUser.fromJson(Map<String, dynamic>.from(j['originalAuthor'] as Map))
            : null,
        sourceRouteId: j['sourceRouteId']?.toString(),
        waypoints: parsePoints(j['waypoints']),
        points: parsePoints(j['points']),
        rawPoints: parseRawPoints(j['points']),
        distanceM: parseInt(j['distanceM']),
        elevationGainM: j['elevationGainM'] == null ? null : parseInt(j['elevationGainM']),
        createdAt: parseInstant(j['createdAt']),
      );
}

/// Risposta di `POST /routes/plan`. [snapped] è falso quando la linea è fatta
/// di segmenti dritti (nessun servizio di percorsi configurato sul server).
class RoutePlan {
  const RoutePlan({required this.points, required this.rawPoints, required this.distanceM, this.elevationGainM, this.snapped = false});

  final List<LatLng> points;
  final List<List<double>> rawPoints;
  final int distanceM;
  final int? elevationGainM;
  final bool snapped;

  factory RoutePlan.fromJson(Json j) => RoutePlan(
        points: parsePoints(j['points']),
        rawPoints: parseRawPoints(j['points']),
        distanceM: parseInt(j['distanceM']),
        elevationGainM: j['elevationGainM'] == null ? null : parseInt(j['elevationGainM']),
        snapped: j['snapped'] == true,
      );
}

enum RunParticipantStatus { invited, accepted, unknown }

class RunEventParticipant {
  const RunEventParticipant({required this.id, required this.user, required this.status});

  final String id;
  final SimpleUser user;
  final RunParticipantStatus status;

  factory RunEventParticipant.fromJson(Json j) => RunEventParticipant(
        id: '${j['id']}',
        user: SimpleUser.fromJson(Map<String, dynamic>.from(j['user'] as Map? ?? const {})),
        status: switch (j['status']) {
          'invited' => RunParticipantStatus.invited,
          'accepted' => RunParticipantStatus.accepted,
          _ => RunParticipantStatus.unknown,
        },
      );
}

/// Corsa di gruppo su un percorso (`RunEventDTO`).
class RunEvent {
  const RunEvent({
    required this.id,
    required this.title,
    required this.startsAt,
    required this.createdBy,
    required this.route,
    this.meetingPoint,
    this.meeting,
    this.notes,
    this.participants = const [],
    this.myStatus,
  });

  final String id;
  final String title;
  final DateTime? startsAt;
  final String? meetingPoint;
  final LatLng? meeting;
  final String? notes;
  final SimpleUser createdBy;
  final RunRoute route;
  final List<RunEventParticipant> participants;

  /// owner, accepted o invited.
  final String? myStatus;

  bool get isOwner => myStatus == 'owner';
  bool get isInvited => myStatus == 'invited';
  bool get canRun => myStatus == 'owner' || myStatus == 'accepted';
  bool get isUpcoming => startsAt != null && startsAt!.isAfter(DateTime.now().subtract(const Duration(hours: 3)));

  List<RunEventParticipant> get accepted =>
      participants.where((p) => p.status == RunParticipantStatus.accepted).toList();

  factory RunEvent.fromJson(Json j) {
    final lat = parseDouble(j['meetingLat']);
    final lng = parseDouble(j['meetingLng']);
    return RunEvent(
      id: '${j['id']}',
      title: j['title'] as String? ?? '',
      startsAt: parseInstant(j['startsAt']),
      meetingPoint: j['meetingPoint'] as String?,
      meeting: lat != null && lng != null ? LatLng(lat, lng) : null,
      notes: j['notes'] as String?,
      createdBy: SimpleUser.fromJson(Map<String, dynamic>.from(j['createdBy'] as Map? ?? const {})),
      route: RunRoute.fromJson(Map<String, dynamic>.from(j['route'] as Map? ?? const {})),
      participants: parseList(j['participants'], RunEventParticipant.fromJson),
      myStatus: j['myStatus'] as String?,
    );
  }
}

/// Una corsa registrata (`RunActivityDTO`).
class RunActivity {
  const RunActivity({
    required this.id,
    required this.user,
    required this.distanceM,
    required this.durationS,
    required this.track,
    this.routeId,
    this.routeName,
    this.eventId,
    this.eventTitle,
    this.startedAt,
    this.paceSPerKm,
    this.elevationGainM,
    this.notes,
  });

  final String id;
  final SimpleUser user;
  final String? routeId;
  final String? routeName;
  final String? eventId;
  final String? eventTitle;
  final DateTime? startedAt;
  final int distanceM;

  /// Tempo in movimento, senza le pause.
  final int durationS;
  final int? paceSPerKm;
  final int? elevationGainM;
  final List<LatLng> track;
  final String? notes;

  String get title => eventTitle ?? routeName ?? tr('Corsa libera');

  factory RunActivity.fromJson(Json j) => RunActivity(
        id: '${j['id']}',
        user: SimpleUser.fromJson(Map<String, dynamic>.from(j['user'] as Map? ?? const {})),
        routeId: j['routeId']?.toString(),
        routeName: j['routeName'] as String?,
        eventId: j['eventId']?.toString(),
        eventTitle: j['eventTitle'] as String?,
        startedAt: parseInstant(j['startedAt']),
        distanceM: parseInt(j['distanceM']),
        durationS: parseInt(j['durationS']),
        paceSPerKm: j['paceSPerKm'] == null ? null : parseInt(j['paceSPerKm']),
        elevationGainM: j['elevationGainM'] == null ? null : parseInt(j['elevationGainM']),
        track: parsePoints(j['track']),
        notes: j['notes'] as String?,
      );
}
