import 'json.dart';

/// UserDTO completo (profilo).
class User {
  const User({
    required this.id,
    required this.username,
    this.email,
    this.firstName,
    this.lastName,
    this.birthDate,
    this.image,
    this.roleName,
    this.isAccountVerified,
    this.createdAt,
  });

  final String id;
  final String username;
  final String? email;
  final String? firstName;
  final String? lastName;
  final DateTime? birthDate;
  final String? image;
  final String? roleName;
  final bool? isAccountVerified;
  final DateTime? createdAt;

  String get displayName {
    final full = [firstName, lastName].whereType<String>().where((s) => s.isNotEmpty).join(' ');
    return full.isEmpty ? username : full;
  }

  factory User.fromJson(Json j) => User(
        id: '${j['id']}',
        username: j['username'] as String? ?? '',
        email: j['email'] as String?,
        firstName: j['firstName'] as String?,
        lastName: j['lastName'] as String?,
        birthDate: parseLocalDate(j['birthDate']),
        image: j['image'] as String?,
        roleName: j['roleName'] as String?,
        isAccountVerified: j['isAccountVerified'] as bool?,
        createdAt: parseInstant(j['createdAt']),
      );

  SimpleUser toSimple() =>
      SimpleUser(id: id, username: username, image: image, isAccountVerified: isAccountVerified);
}

/// SimpleUserDTO (liste, ricerca, amicizie).
class SimpleUser {
  const SimpleUser({
    required this.id,
    required this.username,
    this.image,
    this.isAccountVerified,
  });

  final String id;
  final String username;
  final String? image;
  final bool? isAccountVerified;

  factory SimpleUser.fromJson(Json j) => SimpleUser(
        id: '${j['id']}',
        username: j['username'] as String? ?? '',
        image: j['image'] as String?,
        isAccountVerified: j['isAccountVerified'] as bool?,
      );
}
