import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/session.dart';
import '../models/group.dart';
import '../models/social.dart';
import '../models/user.dart';
import '../models/workout.dart';
import 'social_repository.dart';
import 'user_repository.dart';
import 'workout_repository.dart';

// Provider di lettura condivisi tra le schermate. Dopo una modifica si fa
// `ref.invalidate(...)` sul provider interessato.

/// Id dell'utente loggato: i provider non autoDispose lo osservano così
/// vengono ricaricati quando cambia account.
final userKeyProvider = Provider<String?>((ref) => ref.watch(sessionProvider).value?.id);

// Allenamenti

final myWorkoutsProvider = FutureProvider<List<Workout>>((ref) {
  ref.watch(userKeyProvider);
  return ref.watch(workoutRepositoryProvider).mine();
});

final exploreWorkoutsProvider = FutureProvider<List<Workout>>((ref) async {
  ref.watch(userKeyProvider);
  return (await ref.watch(workoutRepositoryProvider).explore()).results;
});

final workoutProvider = FutureProvider.autoDispose.family<Workout, String>(
  (ref, id) => ref.watch(workoutRepositoryProvider).byId(id),
);

final exercisesProvider = FutureProvider<List<Exercise>>((ref) {
  ref.watch(userKeyProvider);
  return ref.watch(workoutRepositoryProvider).exercises();
});

final historyProvider = FutureProvider<List<WorkoutHistory>>((ref) {
  ref.watch(userKeyProvider);
  return ref.watch(workoutRepositoryProvider).history();
});

// Gruppi

final groupsProvider = FutureProvider<List<WorkoutGroup>>((ref) {
  ref.watch(userKeyProvider);
  return ref.watch(groupRepositoryProvider).all();
});

final groupProvider = FutureProvider.autoDispose.family<WorkoutGroup, String>(
  (ref, id) => ref.watch(groupRepositoryProvider).byId(id),
);

final groupHistoryProvider = FutureProvider.autoDispose.family<List<WorkoutHistory>, String>(
  (ref, id) => ref.watch(workoutRepositoryProvider).groupHistory(id),
);

/// Inviti ai gruppi ancora da accettare.
final groupInvitesProvider = FutureProvider<List<GroupMember>>((ref) async {
  ref.watch(userKeyProvider);
  final all = await ref.watch(groupRepositoryProvider).myMemberships();
  return all.where((m) => m.status == GroupMemberStatus.invited).toList();
});

// Social

final friendsProvider = FutureProvider<List<Friendship>>((ref) {
  ref.watch(userKeyProvider);
  return ref.watch(friendshipRepositoryProvider).all();
});

final friendRequestsProvider = FutureProvider<List<Friendship>>((ref) {
  ref.watch(userKeyProvider);
  return ref.watch(friendshipRepositoryProvider).pendingRequests();
});

final friendsPostsProvider = FutureProvider<List<Post>>((ref) {
  ref.watch(userKeyProvider);
  return ref.watch(postRepositoryProvider).friendsPosts();
});

final explorePostsProvider = FutureProvider<List<Post>>((ref) async {
  ref.watch(userKeyProvider);
  return (await ref.watch(postRepositoryProvider).all()).results;
});

final postProvider = FutureProvider.autoDispose.family<Post, String>(
  (ref, id) => ref.watch(postRepositoryProvider).byId(id),
);

final userPostsProvider = FutureProvider.autoDispose.family<List<Post>, String>(
  (ref, username) => ref.watch(postRepositoryProvider).byUser(username),
);

final userProfileProvider = FutureProvider.autoDispose.family<User, String>(
  (ref, username) => ref.watch(userRepositoryProvider).byUsername(username),
);

/// Numero di notifiche (richieste di amicizia + inviti ai gruppi).
final notificationCountProvider = Provider<int>((ref) {
  final requests = ref.watch(friendRequestsProvider).value?.length ?? 0;
  final invites = ref.watch(groupInvitesProvider).value?.length ?? 0;
  return requests + invites;
});

/// Invalida i feed dei post (dopo like, commenti, nuovi post).
void refreshPosts(WidgetRef ref) {
  ref.invalidate(friendsPostsProvider);
  ref.invalidate(explorePostsProvider);
}
