import 'package:flutter/widgets.dart';

import '../../models/user.dart';
import '../../models/workout.dart';
import '../running/gpx_share.dart';
import 'send_workout_sheet.dart';
import 'share_cards.dart';
import 'share_links.dart';
import 'share_sheet.dart';

/// Condividi una scheda. [canSendInApp] è falso per una scheda privata di
/// qualcun altro: la puoi usare, ma non passarla ad altri.
Future<void> shareWorkout(BuildContext context, Workout workout, {required bool mine}) {
  final canSendInApp = mine || workout.isPublic;
  return showShareSheet(
    context,
    ShareContent(
      card: WorkoutShareCard(workout: workout),
      message: mine ? 'La mia scheda "${workout.name}" su RepBirds 💪' : 'Scheda "${workout.name}" su RepBirds 💪',
      link: ShareLinks.workout(workout.id),
      fileName: gpxFileName(workout.name),
      onSendInApp: canSendInApp ? (ctx) => showSendWorkoutSheet(ctx, workout) : null,
    ),
  );
}

/// Condividi una sessione completata (dallo storico).
Future<void> shareSession(BuildContext context, WorkoutHistory session, {Workout? workout, String? username}) {
  final name = workout?.name ?? 'Allenamento';
  final canSendInApp = workout != null && (workout.user?.username == username || workout.isPublic);
  return showShareSheet(
    context,
    ShareContent(
      card: SessionShareCard(session: session, workout: workout, username: username),
      message: 'Allenamento completato: $name 🔥',
      link: workout != null ? ShareLinks.workout(workout.id) : ShareLinks.webBaseUrl,
      fileName: 'allenamento-${gpxFileName(name)}',
      onSendInApp: canSendInApp ? (ctx) => showSendWorkoutSheet(ctx, workout) : null,
    ),
  );
}

/// Condividi un profilo (il mio, con i numeri, o quello di un altro).
Future<void> shareProfile(
  BuildContext context,
  User user, {
  bool mine = false,
  int? sessions,
  Duration? trained,
  int? friends,
}) {
  return showShareSheet(
    context,
    ShareContent(
      card: ProfileShareCard(user: user, sessions: sessions, trained: trained, friends: friends),
      message: mine ? 'Allenati con me su RepBirds! Sono @${user.username}' : '@${user.username} su RepBirds',
      link: ShareLinks.profile(user.username),
      fileName: 'repbirds-${gpxFileName(user.username)}',
      allowFeed: mine,
    ),
  );
}
