import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/backgrounds.dart';
import '../../core/widgets/ui.dart';
import '../../data/providers.dart';
import '../../models/group.dart';
import '../../models/user.dart';
import '../../models/workout.dart';
import '../auth/session.dart';
import '../shell/app_shell.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(myWorkoutsProvider);
    ref.invalidate(historyProvider);
    ref.invalidate(groupsProvider);
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
                      tooltip: tr('Notifiche'),
                      onTap: () => context.push('/notifications'),
                    ),
                    const SizedBox(width: 10),
                    CircleIconButton(
                      icon: Icons.add_rounded,
                      dark: true,
                      tooltip: tr('Crea'),
                      onTap: () => showQuickCreate(context),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                // Una cosa alla volta: cosa fare oggi, scorciatoie, la settimana, cosa arriva.
                const _TodaySection(),
                const SizedBox(height: 14),
                const _Shortcuts(),
                const SizedBox(height: 32),
                const _WeekCard(),
                const SizedBox(height: 32),
                const _Upcoming(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Cosa c'è da fare oggi: la prossima scheda in grande, il resto in righe compatte.
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

    final doneToday = history.where((h) => h.startedAt != null && isSameDay(h.startedAt!.toLocal(), now)).toList();
    final doneIds = doneToday.map((h) => h.workoutId).toSet();
    final minutesToday = doneToday.fold<int>(0, (a, h) => a + (h.duration?.inMinutes ?? 0));
    final today = workouts.where((w) => w.isScheduledOn(now)).toList()
      ..sort((a, b) => (a.startTime?.label ?? '').compareTo(b.startTime?.label ?? ''));
    final next = today.where((w) => !doneIds.contains(w.id)).toList();
    final done = today.where((w) => doneIds.contains(w.id)).toList();
    final groupsToday = groups.where((g) => g.scheduledFor != null && isSameDay(g.scheduledFor!.toLocal(), now)).toList()
      ..sort((a, b) => a.scheduledFor!.compareTo(b.scheduledFor!));
    final runsToday = events
        .where((e) => e.canRun && e.startsAt != null && isSameDay(e.startsAt!.toLocal(), now))
        .toList()
      ..sort((a, b) => a.startsAt!.compareTo(b.startsAt!));

    final rows = <Widget>[
      for (final w in next.skip(1))
        _Row(
          icon: Icons.fitness_center_rounded,
          title: w.name,
          subtitle: w.startTime != null ? tr('Alle {time}', {'time': w.startTime!.label}) : tr('Scheda'),
          onTap: () => context.push('/workout/${w.id}'),
        ),
      for (final g in groupsToday)
        _Row(
          icon: Icons.groups_rounded,
          title: g.name,
          subtitle: tr('Di gruppo alle {time}', {'time': formatTime(g.scheduledFor!.toLocal())}),
          onTap: () => context.push('/group/${g.id}'),
        ),
      for (final e in runsToday)
        _Row(
          icon: Icons.directions_run_rounded,
          title: e.title,
          subtitle: tr('Corsa alle {time}', {'time': formatTime(e.startsAt!.toLocal())}),
          onTap: () => context.push('/running/event/${e.id}'),
        ),
      for (final w in done)
        _Row(
          icon: Icons.check_rounded,
          done: true,
          title: w.name,
          subtitle: tr('Fatta oggi'),
          onTap: () => context.push('/workout/${w.id}'),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(tr('Oggi'), style: t.headlineMedium),
        const SizedBox(height: 2),
        Text(
          doneToday.isEmpty
              ? formatDay(now)
              : tr('{day} · {amount} fatto', {
                  'day': formatDay(now),
                  'amount': minutesToday > 0 ? formatDuration(Duration(minutes: minutesToday)) : tr('allenamento'),
                }),
          style: t.bodyMedium?.copyWith(color: AppColors.muted),
        ),
        const SizedBox(height: 16),
        if (next.isNotEmpty)
          TodayWorkoutCard(workout: next.first)
        else
          _RestDay(allDone: done.isNotEmpty),
        if (rows.isNotEmpty) ...[
          const SizedBox(height: 10),
          SoftCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) const Divider(indent: 60, endIndent: 16),
                rows[i],
              ],
            ]),
          ),
        ],
      ],
    );
  }
}

/// Niente in programma (o tutto fatto): una sola card tranquilla.
class _RestDay extends StatelessWidget {
  const _RestDay({required this.allDone});

  final bool allDone;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      onTap: () => context.go('/workouts'),
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          IconChip(
            icon: allDone ? Icons.check_rounded : Icons.self_improvement_rounded,
            color: allDone ? AppColors.mint : AppColors.blue,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              allDone ? tr('Hai finito per oggi. Ottimo lavoro!') : tr('Niente in programma. Scegli una scheda.'),
              style: const TextStyle(fontWeight: FontWeight.w600, height: 1.35),
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: AppColors.muted),
        ],
      ),
    );
  }
}

/// Riga compatta dentro una card (attività di oggi, prossimi appuntamenti).
class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.title, required this.subtitle, required this.onTap, this.done = false});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: IconChip(icon: icon, color: done ? AppColors.mint : AppColors.ink, size: 36),
      title: Text(title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: done ? AppColors.muted : AppColors.ink,
          )),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.muted, fontSize: 13)),
      trailing: Icon(Icons.chevron_right_rounded, color: AppColors.muted),
    );
  }
}

/// Card scura della prossima scheda di oggi, con il pulsante per iniziare.
class TodayWorkoutCard extends StatelessWidget {
  const TodayWorkoutCard({super.key, required this.workout});

  final Workout workout;

  @override
  Widget build(BuildContext context) {
    final details = [
      if (workout.startTime != null) tr('Alle {time}', {'time': workout.startTime!.label}),
      workout.exercises.length == 1 ? tr('{n} esercizio', {'n': 1}) : tr('{n} esercizi', {'n': workout.exercises.length}),
    ].join(' · ');
    return SoftCard(
      color: AppColors.inkCard,
      onTap: () => context.push('/workout/${workout.id}'),
      padding: const EdgeInsets.fromLTRB(20, 20, 16, 20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  workout.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(details, style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 14)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Material(
            color: AppColors.lilac,
            shape: const StadiumBorder(),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: () => context.push('/workout/${workout.id}/session'),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 20, 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.play_arrow_rounded, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(tr('Inizia'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Scorciatoie piccole per ciò che non sta nella barra in basso.
class _Shortcuts extends StatelessWidget {
  const _Shortcuts();

  @override
  Widget build(BuildContext context) {
    Widget chip(IconData icon, String label, String route) => Expanded(
          child: SoftCard(
            onTap: () => context.push(route),
            padding: const EdgeInsets.symmetric(vertical: 12),
            radius: AppRadius.md,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: AppColors.inkSoft),
                const SizedBox(width: 6),
                Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              ],
            ),
          ),
        );
    return Row(
      children: [
        chip(Icons.directions_run_rounded, tr('Corsa'), '/running'),
        const SizedBox(width: 10),
        chip(Icons.history_rounded, tr('Storico'), '/history'),
        const SizedBox(width: 10),
        chip(Icons.sports_gymnastics_rounded, tr('Esercizi'), '/exercises'),
      ],
    );
  }
}

/// La settimana in una card sola: barre lun → dom, sessioni e tempo.
class _WeekCard extends ConsumerWidget {
  const _WeekCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyProvider).value ?? const <WorkoutHistory>[];
    final start = startOfWeek(DateTime.now());
    final perDay = List<double>.filled(7, 0);
    var sessions = 0;
    for (final h in history) {
      final d = h.startedAt?.toLocal();
      if (d == null || d.isBefore(start) || !d.isBefore(start.add(const Duration(days: 7)))) continue;
      perDay[d.weekday - 1] += (h.duration?.inMinutes ?? 30).toDouble();
      sessions++;
    }
    final minutes = perDay.fold<double>(0, (a, b) => a + b).round();
    final t = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(tr('Questa settimana'), action: tr('Storico'), onAction: () => context.push('/history')),
        SoftCard(
          onTap: () => context.push('/history'),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('$sessions', style: t.headlineMedium),
                  const SizedBox(width: 6),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(sessions == 1 ? tr('allenamento') : tr('allenamenti'),
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(formatDuration(Duration(minutes: minutes)),
                        style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              MiniBars(
                values: perDay,
                highlight: DateTime.now().weekday - 1,
                color: AppColors.lilacSoft,
                highlightColor: AppColors.lilac,
                labels: weekdayShort.map((d) => d.substring(0, 1)).toList(),
                height: 56,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// I prossimi appuntamenti (gruppi e corse dei giorni successivi), al massimo tre.
class _Upcoming extends ConsumerWidget {
  const _Upcoming();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final groups = (ref.watch(groupsProvider).value ?? const <WorkoutGroup>[])
        .where((g) => g.isUpcoming && !isSameDay(g.scheduledFor!.toLocal(), now));
    final runs = (ref.watch(runEventsProvider).value ?? const [])
        .where((e) => e.canRun && e.isUpcoming && e.startsAt != null && !isSameDay(e.startsAt!.toLocal(), now));
    final items = <(DateTime, Widget)>[
      for (final g in groups)
        (
          g.scheduledFor!,
          _Row(
            icon: Icons.groups_rounded,
            title: g.name,
            subtitle: formatDayTime(g.scheduledFor!.toLocal()),
            onTap: () => context.push('/group/${g.id}'),
          ),
        ),
      for (final e in runs)
        (
          e.startsAt!,
          _Row(
            icon: Icons.directions_run_rounded,
            title: e.title,
            subtitle: formatDayTime(e.startsAt!.toLocal()),
            onTap: () => context.push('/running/event/${e.id}'),
          ),
        ),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    if (items.isEmpty) return const SizedBox.shrink();
    final shown = items.take(3).map((i) => i.$2).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(tr('In programma'), action: tr('Gruppi'), onAction: () => context.go('/groups')),
        SoftCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(children: [
            for (var i = 0; i < shown.length; i++) ...[
              if (i > 0) const Divider(indent: 60, endIndent: 16),
              shown[i],
            ],
          ]),
        ),
      ],
    );
  }
}

/// Avatar sovrapposti (max 4 + contatore).
class AvatarStack extends StatelessWidget {
  const AvatarStack({super.key, required this.users, this.size = 28});

  final List<SimpleUser> users;
  final double size;

  @override
  Widget build(BuildContext context) {
    final shown = users.take(4).toList();
    final extra = users.length - shown.length;
    return SizedBox(
      height: size,
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: i * size * 0.65,
              child: Container(
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.card, width: 2)),
                child: UserAvatar(username: shown[i].username, imageUrl: shown[i].image, size: size - 4),
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

/// Bottom sheet "Crea": post, scheda, gruppo, esercizio.
void showQuickCreate(BuildContext context) {
  // Sopra la barra di navigazione (root navigator), alto quanto serve e, se lo
  // schermo è piccolo o i testi lunghi, scorrevole invece di tagliarsi.
  showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
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
                        Text(subtitle, style: TextStyle(color: AppColors.muted, fontSize: 13)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: AppColors.muted),
                ],
              ),
            ),
          );
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr('Crea'), style: Theme.of(ctx).textTheme.headlineSmall),
              const SizedBox(height: 16),
              item(Icons.photo_camera_rounded, AppColors.pink, tr('Nuovo post'), tr('Condividi il tuo allenamento'), '/posts/new'),
              item(Icons.fitness_center_rounded, AppColors.blue, tr('Nuova scheda'), tr('Esercizi, giorni e orario'), '/workout/new'),
              item(Icons.groups_rounded, AppColors.lilac, tr('Allenamento di gruppo'), tr('Invita i tuoi amici'), '/group/new'),
              item(Icons.add_road_rounded, AppColors.blue, tr('Percorso di corsa'), tr('Disegnalo sulla mappa'), '/running/route/new'),
              item(Icons.sports_gymnastics_rounded, AppColors.mint, tr('Libreria esercizi'), tr('Crea o cerca esercizi'), '/exercises'),
            ],
          ),
        ),
      );
    },
  );
}
