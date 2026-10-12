import 'json.dart';
import 'user.dart';

class WorkoutGroup {
  const WorkoutGroup({
    required this.id,
    required this.name,
    required this.workoutId,
    required this.workoutName,
    required this.createdBy,
    this.scheduledFor,
    this.status = 'active',
    this.createdAt,
    this.members = const [],
  });

  final String id;
  final String name;
  final String workoutId;
  final String workoutName;
  final SimpleUser createdBy;
  final DateTime? scheduledFor;
  final String status;
  final DateTime? createdAt;
  final List<GroupMember> members;

  List<GroupMember> get acceptedMembers =>
      members.where((m) => m.status == GroupMemberStatus.accepted).toList();

  bool get isUpcoming => scheduledFor != null && scheduledFor!.isAfter(DateTime.now());

  factory WorkoutGroup.fromJson(Json j) {
    final w = (j['workout'] as Map?) ?? const {};
    return WorkoutGroup(
      id: '${j['id']}',
      name: j['name'] as String? ?? '',
      workoutId: '${w['id']}',
      workoutName: w['name'] as String? ?? '',
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
  });

  final String id;
  final String groupId;
  final SimpleUser user;
  final GroupMemberStatus status;
  final DateTime? createdAt;

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
      );
}
