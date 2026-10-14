import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/backgrounds.dart';
import '../../core/widgets/ui.dart';
import '../../data/providers.dart';
import '../../models/group.dart';
import '../../models/workout.dart';
import '../auth/session.dart';
import '../feed/post_card.dart';
import '../shell/app_shell.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(myWorkoutsProvider);
    ref.invalidate(historyProvider);
    ref.invalidate(groupsProvider);
    ref.invalidate(friendsPostsProvider);
    ref.invalidate(friendRequestsProvider);
    ref.invalidate(groupInvitesProvider);
    ref.invalidate(runEventsProvider);
    await ref.read(historyProvider.future).catchError((_) => <WorkoutHistory>[]);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final t = Theme.of(context).textTheme;
    final notifications = ref.watch(notificationCountProvider);

    return Scaffold(
      body: SkyBackground(
        child: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            onRefresh: () => _refresh(ref),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, navBarClearance),
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => context.go('/profile'),
                      child: UserAvatar(username: user.username, imageUrl: user.image, size: 48, ring: true),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(greeting(), style: t.bodyMedium),
                          Text(
                            user.firstName?.isNotEmpty == true ? user.firstName! : user.username,
                            style: t.titleLarge,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    CircleIconButton(
                      icon: Icons.notifications_none_rounded,
                      badge: notifications > 0,
                      tooltip: 'Notifiche',
                      onTap: () => context.push('/notifications'),
                    ),
                    const SizedBox(width: 10),
                    CircleIconButton(
                      icon: Icons.add_rounded,
                      dark: true,
                      tooltip: 'Crea',
                      onTap: () => showQuickCreate(context),
                    ),
                  ],
                ),
                const SizedBox(height: 26),
                // Prima l'attività di oggi, poi andamento e dashboard.
                const _TodaySection(),
                const SectionHeader('Il tuo andamento'),
                const _WeekCard(),
                const SizedBox(height: 14),
                const _StatsGrid(),
                const SizedBox(height: 24),
                const _RunningCard(),
                const _UpcomingGroups(),
                const _FriendsActivity(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Card lilla con le sessioni della settimana (barre lun → dom).
class _WeekCard extends ConsumerWidget {
  const _WeekCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyProvider).value ?? const <WorkoutHistory>[];
    final start = startOfWeek(DateTime.now());
    final perDay = List<double>.filled(7, 0);
    for (final h in history) {
      final d = h.startedAt;
      if (d == null || d.isBefore(start) || d.isAfter(start.add(const Duration(days: 7)))) continue;
      perDay[d.weekday - 1] += (h.duration?.inMinutes ?? 30).toDouble();
    }
    final sessions = history
        .where((h) => h.startedAt != null && !h.startedAt!.isBefore(start))
        .length;
    final minutes = perDay.fold<double>(0, (a, b) => a + b).round();

    return SoftCard(
      color: AppColors.lilacSoft,
      onTap: () => context.push('/history'),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconChip(icon: Icons.bolt_rounded, color: AppColors.lilac, background: Colors.white),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Questa settimana', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.ink.withValues(alpha: 0.12)),
                ),
                child: const Icon(Icons.north_east_rounded, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 18),
          MiniBars(
            values: perDay,
            highlight: DateTime.now().weekday - 1,
            color: Colors.white,
            highlightColor: AppColors.lilac,
            labels: weekdayShort.map((d) => d.substring(0, 1)).toList(),
            height: 70,
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$sessions', style: Theme.of(context).textTheme.displaySmall),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(sessions == 1 ? 'allenamento' : 'allenamenti',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(formatDuration(Duration(minutes: minutes)),
                    style: const TextStyle(color: AppColors.inkSoft, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatsGrid extends ConsumerWidget {
  const _StatsGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyProvider).value ?? const [];
    final workouts = ref.watch(myWorkoutsProvider).value ?? const [];
    final friends = ref.watch(friendsProvider).value ?? const [];
    final groups = ref.watch(groupsProvider).value ?? const [];
    final now = DateTime.now();
    final month = history.where((h) => h.startedAt?.month == now.month && h.startedAt?.year == now.year).length;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.45,
      children: [
        StatTile(
          icon: Icons.calendar_month_rounded,
          label: 'Questo mese',
          value: '$month',
          footnote: 'sessioni',
          color: AppColors.blue,
          onTap: () => context.push('/history'),
        ),
        StatTile(
          icon: Icons.list_alt_rounded,
          label: 'Schede',
          value: '${workouts.length}',
          footnote: 'create da te',
          color: AppColors.lilac,
          onTap: () => context.go('/workouts'),
        ),
        StatTile(
          icon: Icons.people_alt_rounded,
          label: 'Amici',
          value: '${friends.length}',
          footnote: 'nella tua crew',
          color: AppColors.pink,
          onTap: () => context.push('/friends'),
        ),
        StatTile(
          icon: Icons.groups_rounded,
          label: 'Gruppi',
          value: '${groups.length}',
          footnote: 'attivi',
          color: AppColors.mint,
          onTap: () => context.go('/groups'),
        ),
      ],
    );
  }
}

/// Tile statistica stile dashboard (icona, etichetta, numero grande).
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.footnote,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final String footnote;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      radius: AppRadius.md + 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconChip(icon: icon, color: color, size: 30),
              const SizedBox(width: 8),
              Expanded(
                child: Text(label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: AppColors.inkSoft, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const Spacer(),
          Text(value, style: Theme.of(context).textTheme.headlineSmall),
          Text(footnote, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        ],
      ),
    );
  }
}

/// In cima alla home: cosa c'è da fare oggi (schede in programma, gruppi,
/// corse) e cosa hai già fatto.
class _TodaySection extends ConsumerWidget {
  const _TodaySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final t = Theme.of(context).textTheme;
    final workouts = ref.watch(myWorkoutsProvider).value ?? const <Workout>[];
    final history = ref.watch(historyProvider).value ?? const <WorkoutHistory>[];
    final groups = ref.watch(groupsProvider).value ?? const <WorkoutGroup>[];
    final events = ref.watch(runEventsProvider).value ?? const [];

    final today = workouts.where((w) => w.isScheduledOn(now)).toList()
      ..sort((a, b) => (a.startTime?.label ?? '').compareTo(b.startTime?.label ?? ''));
    final doneToday = history.where((h) => h.startedAt != null && isSameDay(h.startedAt!.toLocal(), now)).toList();
    final doneIds = doneToday.map((h) => h.workoutId).toSet();
    final minutesToday = doneToday.fold<int>(0, (a, h) => a + (h.duration?.inMinutes ?? 0));
    final groupsToday = groups.where((g) => g.scheduledFor != null && isSameDay(g.scheduledFor!.toLocal(), now)).toList()
      ..sort((a, b) => a.scheduledFor!.compareTo(b.scheduledFor!));
    final runsToday = events
        .where((e) => e.canRun && e.startsAt != null && isSameDay(e.startsAt!.toLocal(), now))
        .toList()
      ..sort((a, b) => a.startsAt!.compareTo(b.startsAt!));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(formatDay(now), style: t.bodyMedium),
                  Text('Oggi', style: t.displaySmall),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => context.go('/workouts'),
              child: const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text('Tutte le schede', style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (doneToday.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SoftCard(
              color: AppColors.mintSoft,
              onTap: () => context.push('/history'),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const IconChip(icon: Icons.check_rounded, color: AppColors.mint, background: Colors.white, size: 34),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      doneToday.length == 1
                          ? 'Allenamento fatto oggi'
                          : '${doneToday.length} allenamenti fatti oggi',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (minutesToday > 0)
                    Text(formatDuration(Duration(minutes: minutesToday)),
                        style: const TextStyle(color: AppColors.inkSoft, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        if (today.isEmpty && groupsToday.isEmpty && runsToday.isEmpty)
          SoftCard(
            onTap: () => context.go('/workouts'),
            child: Row(
              children: [
                const IconChip(icon: Icons.self_improvement_rounded, color: AppColors.blue),
                const SizedBox(width: 14),
                const Expanded(
                  child: Text(
                    'Nessuna scheda in programma oggi. Scegline una o creane una nuova.',
                    style: TextStyle(color: AppColors.inkSoft, height: 1.4),
                  ),
                ),
                const SizedBox(width: 8),
                CircleIconButton(icon: Icons.arrow_forward_rounded, size: 40, onTap: () => context.go('/workouts')),
              ],
            ),
          ),
        for (final w in today)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TodayWorkoutCard(workout: w, done: doneIds.contains(w.id)),
          ),
        for (final g in groupsToday)
          _TodayRow(
            icon: Icons.groups_rounded,
            color: AppColors.lilac,
            title: g.name,
            subtitle: 'Di gruppo · alle ${formatTime(g.scheduledFor!.toLocal())} · ${g.workoutName}',
            onTap: () => context.push('/group/${g.id}'),
          ),
        for (final e in runsToday)
          _TodayRow(
            icon: Icons.directions_run_rounded,
            color: AppColors.blue,
            title: e.title,
            subtitle: 'Corsa · alle ${formatTime(e.startsAt!.toLocal())}',
            onTap: () => context.push('/running/event/${e.id}'),
          ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _TodayRow extends StatelessWidget {
  const _TodayRow({required this.icon, required this.color, required this.title, required this.subtitle, required this.onTap});

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SoftCard(
        onTap: onTap,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            IconChip(icon: icon, color: color),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(subtitle,
                      style: const TextStyle(color: AppColors.muted, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}

/// Card scura della scheda di oggi con pulsante play.
class TodayWorkoutCard extends StatelessWidget {
  const TodayWorkoutCard({super.key, required this.workout, this.done = false});

  final Workout workout;

  /// Già fatta oggi (c'è una sessione nello storico).
  final bool done;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      color: AppColors.ink,
      onTap: () => context.push('/workout/${workout.id}'),
      padding: const EdgeInsets.fromLTRB(20, 18, 14, 18),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  done
                      ? 'Fatta oggi ✓'
                      : workout.startTime != null
                          ? 'Alle ${workout.startTime!.label}'
                          : 'Scheda di oggi',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  workout.name,
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    '${workout.exercises.length} esercizi',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          Material(
            color: AppColors.lilac,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => context.push('/workout/${workout.id}/session'),
              child: const SizedBox(
                width: 60,
                height: 60,
                child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 32),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Accesso alla corsa: percorsi, corse di gruppo, prossima corsa in programma.
class _RunningCard extends ConsumerWidget {
  const _RunningCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(runEventsProvider).value ?? const [];
    final next = events.where((e) => e.isUpcoming && e.startsAt != null).toList()
      ..sort((a, b) => a.startsAt!.compareTo(b.startsAt!));
    final invites = events.where((e) => e.isInvited && e.isUpcoming).length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: SoftCard(
        gradient: AppColors.brandGradient,
        onTap: () => context.push(invites > 0 ? '/running?tab=2' : '/running'),
        child: Row(
          children: [
            const IconChip(icon: Icons.directions_run_rounded, color: Colors.white, background: Color(0x33FFFFFF), size: 48),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Corsa', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(
                    invites > 0
                        ? '$invites ${invites == 1 ? 'invito' : 'inviti'} a correre'
                        : next.isNotEmpty
                            ? '${next.first.title} · ${formatDayTime(next.first.startsAt)}'
                            : 'Percorsi, corse con gli amici e allenamenti in solitaria',
                    style: const TextStyle(color: Colors.white70),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

class _UpcomingGroups extends ConsumerWidget {
  const _UpcomingGroups();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Quelli di oggi sono già in cima, nella sezione "Oggi".
    final now = DateTime.now();
    final groups = (ref.watch(groupsProvider).value ?? const <WorkoutGroup>[])
        .where((g) => g.isUpcoming && !isSameDay(g.scheduledFor!.toLocal(), now))
        .toList()
      ..sort((a, b) => a.scheduledFor!.compareTo(b.scheduledFor!));
    if (groups.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader('Allenamenti di gruppo', action: 'Vedi tutti', onAction: () => context.go('/groups')),
        SizedBox(
          height: 150,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: groups.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              final g = groups[i];
              final colors = [AppColors.blueSoft, AppColors.pinkSoft, AppColors.mintSoft];
              return SizedBox(
                width: 230,
                child: SoftCard(
                  color: colors[i % colors.length],
                  onTap: () => context.push('/group/${g.id}'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Tag(formatDayTime(g.scheduledFor), color: AppColors.ink, icon: Icons.schedule_rounded),
                      const Spacer(),
                      Text(g.name, style: Theme.of(context).textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(g.workoutName, style: const TextStyle(color: AppColors.inkSoft, fontSize: 13)),
                      const SizedBox(height: 8),
                      AvatarStack(usernames: [g.createdBy.username, ...g.acceptedMembers.map((m) => m.user.username)]),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

/// Avatar sovrapposti (max 4 + contatore).
class AvatarStack extends StatelessWidget {
  const AvatarStack({super.key, required this.usernames, this.size = 28});

  final List<String> usernames;
  final double size;

  @override
  Widget build(BuildContext context) {
    final shown = usernames.take(4).toList();
    final extra = usernames.length - shown.length;
    return SizedBox(
      height: size,
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: i * size * 0.65,
              child: Container(
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                child: UserAvatar(username: shown[i], size: size - 4),
              ),
            ),
          if (extra > 0)
            Positioned(
              left: shown.length * size * 0.65 + 4,
              top: (size - 18) / 2,
              child: Text('+$extra', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
            ),
        ],
      ),
    );
  }
}

class _FriendsActivity extends ConsumerWidget {
  const _FriendsActivity();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final posts = ref.watch(friendsPostsProvider).value ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader('Dai tuoi amici', action: 'Community', onAction: () => context.go('/feed')),
        if (posts.isEmpty)
          SoftCard(
            onTap: () => context.push('/friends'),
            child: const Row(
              children: [
                IconChip(icon: Icons.person_add_alt_1_rounded, color: AppColors.pink),
                SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Aggiungi amici per vedere qui i loro allenamenti.',
                    style: TextStyle(color: AppColors.inkSoft),
                  ),
                ),
              ],
            ),
          )
        else
          for (final p in posts.take(2))
            Padding(padding: const EdgeInsets.only(bottom: 14), child: PostCard(post: p)),
      ],
    );
  }
}

/// Bottom sheet "Crea": post, scheda, gruppo, esercizio.
void showQuickCreate(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    builder: (ctx) {
      Widget item(IconData icon, Color color, String title, String subtitle, String route) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: SoftCard(
              padding: const EdgeInsets.all(14),
              onTap: () {
                Navigator.pop(ctx);
                context.push(route);
              },
              child: Row(
                children: [
                  IconChip(icon: icon, color: color),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text(subtitle, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
                ],
              ),
            ),
          );
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Crea', style: Theme.of(ctx).textTheme.headlineSmall),
              const SizedBox(height: 16),
              item(Icons.photo_camera_rounded, AppColors.pink, 'Nuovo post', 'Condividi il tuo allenamento', '/posts/new'),
              item(Icons.fitness_center_rounded, AppColors.blue, 'Nuova scheda', 'Esercizi, giorni e orario', '/workout/new'),
              item(Icons.groups_rounded, AppColors.lilac, 'Allenamento di gruppo', 'Invita i tuoi amici', '/group/new'),
              item(Icons.add_road_rounded, AppColors.blue, 'Percorso di corsa', 'Disegnalo sulla mappa', '/running/route/new'),
              item(Icons.sports_gymnastics_rounded, AppColors.mint, 'Libreria esercizi', 'Crea o cerca esercizi', '/exercises'),
            ],
          ),
        ),
      );
    },
  );
}
