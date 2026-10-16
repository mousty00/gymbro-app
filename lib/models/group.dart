import 'json.dart';
import 'user.dart';

class WorkoutGroup {
  const WorkoutGroup({
    required this.id,
    required this.name,
    this.workoutId,
    this.workoutName,
    required this.createdBy,
    this.scheduledFor,
    this.status = 'active',
    this.createdAt,
    this.members = const [],
  });

  final String id;
  final String name;
  /// Solo sui gruppi creati prima delle sessioni: ora la scheda sta su ogni sessione.
  final String? workoutId;
  final String? workoutName;
  final SimpleUser createdBy;
  final DateTime? scheduledFor;
  final String status;
  final DateTime? createdAt;
  final List<GroupMember> members;

  List<GroupMember> get acceptedMembers =>
      members.where((m) => m.status == GroupMemberStatus.accepted).toList();

  bool get isUpcoming => scheduledFor != null && scheduledFor!.isAfter(DateTime.now());

  factory WorkoutGroup.fromJson(Json j) {
    final w = j['workout'] as Map?;
    return WorkoutGroup(
      id: '${j['id']}',
      name: j['name'] as String? ?? '',
      workoutId: w == null ? null : '${w['id']}',
      workoutName: w?['name'] as String?,
      createdBy: SimpleUser.fromJson(Map<String, dynamic>.from(j['createdBy'] as Map? ?? const {})),
      scheduledFor: parseInstant(j['scheduledFor']),
      status: j['status'] as String? ?? 'active',
      createdAt: parseInstant(j['createdAt']),
      members: parseList(j['groupMembers'], GroupMember.fromJson),
    );
  }
}

enum GroupMemberStatus { invited, accepted, rejected, unknown }

class GroupMember {
  const GroupMember({
    required this.id,
    required this.groupId,
    required this.user,
    required this.status,
    this.createdAt,
    this.groupName,
    this.groupCreatedBy,
    this.groupScheduledFor,
  });

  final String id;
  final String groupId;
  final SimpleUser user;
  final GroupMemberStatus status;
  final DateTime? createdAt;

  /// Riepilogo del gruppo: chi è solo invitato non può leggere il gruppo
  /// finché non accetta, quindi il backend lo allega all'invito.
  final String? groupName;
  final String? groupCreatedBy;
  final DateTime? groupScheduledFor;

  factory GroupMember.fromJson(Json j) => GroupMember(
        id: '${j['id']}',
        groupId: '${j['workoutGroupId']}',
        user: SimpleUser.fromJson(Map<String, dynamic>.from(j['user'] as Map? ?? const {})),
        status: switch ((j['status'] as String? ?? '').toLowerCase()) {
          'invited' => GroupMemberStatus.invited,
          'accepted' => GroupMemberStatus.accepted,
          'rejected' => GroupMemberStatus.rejected,
          _ => GroupMemberStatus.unknown,
        },
        createdAt: parseInstant(j['createdAt']),
        groupName: j['groupName'] as String?,
        groupCreatedBy: j['groupCreatedBy'] as String?,
        groupScheduledFor: parseInstant(j['groupScheduledFor']),
      );
}

enum Attendance { going, declined, pending }

Attendance _attendance(Object? v) => switch ('$v'.toLowerCase()) {
      'going' => Attendance.going,
      'declined' => Attendance.declined,
      _ => Attendance.pending,
    };

/// Una sessione di un gruppo fisso: giorno, scheda e chi c'è. L'organizzatore la
/// avvia e per tutti il cronometro parte da [startedAt].
class GroupSession {
  const GroupSession({
    required this.id,
    required this.groupId,
    required this.groupName,
    required this.organizer,
    required this.workoutId,
    required this.workoutName,
    this.scheduledFor,
    this.startedAt,
    this.myStatus = Attendance.pending,
    this.attendees = const [],
  });

  final String id;
  final String groupId;
  final String groupName;
  final SimpleUser organizer;
  final String workoutId;
  final String workoutName;
  final DateTime? scheduledFor;
  final DateTime? startedAt;
  final Attendance myStatus;
  final List<SessionAttendee> attendees;

  bool get started => startedAt != null;
  List<SessionAttendee> withStatus(Attendance a) => attendees.where((x) => x.status == a).toList();

  factory GroupSession.fromJson(Json j) => GroupSession(
        id: '${j['id']}',
        groupId: '${j['groupId']}',
        groupName: j['groupName'] as String? ?? '',
        organizer: SimpleUser.fromJson(Map<String, dynamic>.from(j['organizer'] as Map? ?? const {})),
        workoutId: '${(j['workout'] as Map?)?['id']}',
        workoutName: (j['workout'] as Map?)?['name'] as String? ?? '',
        scheduledFor: parseInstant(j['scheduledFor']),
        startedAt: parseInstant(j['startedAt']),
        myStatus: _attendance(j['myStatus']),
        attendees: parseList(j['attendees'], SessionAttendee.fromJson),
      );
}

class SessionAttendee {
  const SessionAttendee({required this.user, required this.status, this.connected = false, this.organizer = false});

  final SimpleUser user;
  final Attendance status;

  /// Ha la sessione aperta adesso: aspetta l'avvio.
  final bool connected;
  final bool organizer;

  factory SessionAttendee.fromJson(Json j) => SessionAttendee(
        user: SimpleUser.fromJson(Map<String, dynamic>.from(j['user'] as Map? ?? const {})),
        status: _attendance(j['status']),
        connected: j['connected'] == true,
        organizer: j['organizer'] == true,
      );
}
