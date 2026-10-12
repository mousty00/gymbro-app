import 'json.dart';
import 'user.dart';

class Post {
  const Post({
    required this.id,
    required this.user,
    required this.content,
    this.image,
    this.createdAt,
    this.updatedAt,
    this.comments = const [],
    this.likes = const [],
    this.numLikes = 0,
    this.numComments = 0,
  });

  final String id;
  final User user;
  final String content;
  final String? image;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<SimpleComment> comments;
  final List<SimpleLike> likes;
  final int numLikes;
  final int numComments;

  SimpleLike? likeBy(String username) {
    for (final l in likes) {
      if (l.username == username) return l;
    }
    return null;
  }

  factory Post.fromJson(Json j) => Post(
        id: '${j['id']}',
        user: User.fromJson(Map<String, dynamic>.from(j['user'] as Map? ?? const {})),
        content: j['content'] as String? ?? '',
        image: j['image'] as String?,
        createdAt: parseInstant(j['createdAt']),
        updatedAt: parseInstant(j['updatedAt']),
        comments: parseList(j['comments'], SimpleComment.fromJson),
        likes: parseList(j['likes'], SimpleLike.fromJson),
        numLikes: parseInt(j['numLikes']),
        numComments: parseInt(j['numComments']),
      );

  Post copyWith({List<SimpleLike>? likes, int? numLikes, List<SimpleComment>? comments, int? numComments}) => Post(
        id: id,
        user: user,
        content: content,
        image: image,
        createdAt: createdAt,
        updatedAt: updatedAt,
        comments: comments ?? this.comments,
        likes: likes ?? this.likes,
        numLikes: numLikes ?? this.numLikes,
        numComments: numComments ?? this.numComments,
      );
}

class SimpleComment {
  const SimpleComment({
    required this.id,
    required this.postId,
    required this.username,
    required this.content,
    this.createdAt,
  });

  final String id;
  final String postId;
  final String username;
  final String content;
  final DateTime? createdAt;

  factory SimpleComment.fromJson(Json j) => SimpleComment(
        id: '${j['id']}',
        postId: '${j['postId']}',
        username: j['username'] as String? ?? '',
        content: j['content'] as String? ?? '',
        createdAt: parseInstant(j['createdAt']),
      );

  /// CommentDTO → SimpleComment (la create restituisce l'utente completo).
  factory SimpleComment.fromCommentJson(Json j) => SimpleComment(
        id: '${j['id']}',
        postId: '${j['postId']}',
        username: (j['user'] as Map?)?['username'] as String? ?? '',
        content: j['content'] as String? ?? '',
        createdAt: parseInstant(j['createdAt']),
      );
}

class SimpleLike {
  const SimpleLike({required this.id, required this.username, this.createdAt});

  final String id;
  final String username;
  final DateTime? createdAt;

  factory SimpleLike.fromJson(Json j) => SimpleLike(
        id: '${j['id']}',
        username: j['username'] as String? ?? '',
        createdAt: parseInstant(j['createdAt']),
      );

  /// LikeDTO → SimpleLike.
  factory SimpleLike.fromLikeJson(Json j) => SimpleLike(
        id: '${j['id']}',
        username: (j['user'] as Map?)?['username'] as String? ?? '',
        createdAt: parseInstant(j['createdAt']),
      );
}

enum FriendshipStatus { pending, accepted, blocked, unknown }

class Friendship {
  const Friendship({
    required this.id,
    required this.user,
    required this.friend,
    required this.status,
    this.createdAt,
  });

  final String id;

  /// Chi ha inviato la richiesta.
  final SimpleUser user;

  /// Chi l'ha ricevuta.
  final SimpleUser friend;
  final FriendshipStatus status;
  final DateTime? createdAt;

  /// L'altra persona rispetto a [me].
  SimpleUser other(String me) => user.username == me ? friend : user;

  factory Friendship.fromJson(Json j) => Friendship(
        id: '${j['id']}',
        user: SimpleUser.fromJson(Map<String, dynamic>.from(j['user'] as Map? ?? const {})),
        friend: SimpleUser.fromJson(Map<String, dynamic>.from(j['friend'] as Map? ?? const {})),
        status: switch ((j['status'] as String? ?? '').toLowerCase()) {
          'pending' => FriendshipStatus.pending,
          'accepted' => FriendshipStatus.accepted,
          'blocked' => FriendshipStatus.blocked,
          _ => FriendshipStatus.unknown,
        },
        createdAt: parseInstant(j['createdAt']),
      );
}
