import 'json.dart';
import 'user.dart';

/// Tipi di notifica del backend (`NotificationType`).
enum NotificationKind {
  friendRequest('FRIEND_REQUEST'),
  friendAccepted('FRIEND_ACCEPTED'),
  groupInvite('GROUP_INVITE'),
  groupInviteAccepted('GROUP_INVITE_ACCEPTED'),
  postLiked('POST_LIKED'),
  postCommented('POST_COMMENTED'),
  unknown('');

  const NotificationKind(this.wire);

  final String wire;

  static NotificationKind parse(Object? v) =>
      values.firstWhere((k) => k.wire == v, orElse: () => NotificationKind.unknown);
}

/// Una notifica di `GET /notifications`. [referenceId] punta all'amicizia,
/// all'invito, al gruppo o al post a seconda di [kind].
class AppNotification {
  const AppNotification({
    required this.id,
    required this.kind,
    this.actor,
    this.referenceId,
    this.detail,
    this.read = false,
    this.createdAt,
  });

  final String id;
  final NotificationKind kind;
  final SimpleUser? actor;
  final String? referenceId;
  final String? detail;
  final bool read;
  final DateTime? createdAt;

  factory AppNotification.fromJson(Json j) => AppNotification(
        id: '${j['id']}',
        kind: NotificationKind.parse(j['type']),
        actor: j['actor'] is Map ? SimpleUser.fromJson(Map<String, dynamic>.from(j['actor'] as Map)) : null,
        referenceId: j['referenceId']?.toString(),
        detail: j['detail'] as String?,
        read: j['read'] == true,
        createdAt: parseInstant(j['createdAt']),
      );

  /// Testo mostrato in lista, dopo "@utente".
  String get text => switch (kind) {
        NotificationKind.friendRequest => 'ti ha inviato una richiesta di amicizia',
        NotificationKind.friendAccepted => 'ha accettato la tua richiesta di amicizia',
        NotificationKind.groupInvite => 'ti ha invitato${detail != null ? ' in $detail' : ' in un gruppo'}',
        NotificationKind.groupInviteAccepted => 'è entrato${detail != null ? ' in $detail' : ' nel tuo gruppo'}',
        NotificationKind.postLiked => 'ha messo mi piace al tuo post',
        NotificationKind.postCommented => 'ha commentato: ${detail ?? ''}',
        NotificationKind.unknown => 'ha interagito con te',
      };

  /// Dove porta il tap (sulla riga o sulla push), null se non c'è una schermata.
  String? get route => routeFor(kind, referenceId, actor?.username);

  static String? routeFor(NotificationKind kind, String? referenceId, [String? actorUsername]) {
    switch (kind) {
      case NotificationKind.postLiked:
      case NotificationKind.postCommented:
        return referenceId != null ? '/posts/$referenceId' : null;
      case NotificationKind.groupInviteAccepted:
        return referenceId != null ? '/group/$referenceId' : null;
      case NotificationKind.friendAccepted:
        return actorUsername != null ? '/u/$actorUsername' : '/friends';
      case NotificationKind.friendRequest:
      case NotificationKind.groupInvite:
        return '/notifications';
      case NotificationKind.unknown:
        return null;
    }
  }
}
