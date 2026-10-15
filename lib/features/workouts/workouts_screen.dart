import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/backgrounds.dart';
import '../../core/widgets/ui.dart';
import '../../data/providers.dart';
import '../../models/workout.dart';
import '../auth/session.dart';
import '../shell/app_shell.dart';
import '../../core/widgets/skeleton.dart';

class WorkoutsScreen extends ConsumerStatefulWidget {
  const WorkoutsScreen({super.key, required this.title});

  /// Il selettore di sezione della tab Allenati.
  final Widget title;

  @override
  ConsumerState<WorkoutsScreen> createState() => _WorkoutsScreenState();
}

class _WorkoutsScreenState extends ConsumerState<WorkoutsScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider);
    final provider = _tab == 0 ? myWorkoutsProvider : exploreWorkoutsProvider;
    final workouts = ref.watch(provider);

    return Scaffold(
      body: SkyBackground(
        child: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            onRefresh: () => ref.refresh(provider.future),
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: widget.title),
                            const SizedBox(width: 10),
                            CircleIconButton(
                              icon: Icons.add_rounded,
                              dark: true,
                              tooltip: tr('Nuova scheda'),
                              onTap: () => context.push('/workout/new'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          children: [
                            for (final (i, label) in [tr('Le mie schede'), tr('Esplora')].indexed)
                              ChoiceChip(
                                label: Text(label),
                                selected: _tab == i,
                                showCheckmark: false,
                                onSelected: (_) => setState(() => _tab = i),
                              ),
                          ],
                        ),
                        const SizedBox(height: 18),
                      ],
                    ),
                  ),
                ),
                AsyncView<List<Workout>>(
                  value: workouts,
                  sliver: true,
                  onRetry: () => ref.invalidate(provider),
                  loading: const SkeletonList(
                    item: SkeletonTile(leading: 56, trailing: true, padding: EdgeInsets.all(18), radius: AppRadius.lg),
                    count: 4,
                    spacing: 12,
                    padding: EdgeInsets.symmetric(horizontal: 20),
                  ),
                  data: (list) {
                    final shown = _tab == 0 ? list : list.where((w) => w.user?.username != me.username).toList();
                    if (shown.isEmpty) {
                      return SliverToBoxAdapter(
                        child: EmptyState(
                          icon: _tab == 0 ? Icons.assignment_rounded : Icons.explore_rounded,
                          title: _tab == 0 ? tr('Nessuna scheda') : tr('Niente da esplorare'),
                          message: _tab == 0
                              ? tr('Crea la tua prima scheda: esercizi, serie, giorni e orario.')
                              : tr('Le schede pubbliche della community appariranno qui.'),
                          action: _tab == 0 ? tr('Crea scheda') : null,
                          onAction: () => context.push('/workout/new'),
                        ),
                      );
                    }
                    return SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, navBarClearance),
                      sliver: SliverList.separated(
                        itemCount: shown.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (_, i) => WorkoutCard(workout: shown[i], index: i, showOwner: _tab == 1),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Card scheda con colore pastello a rotazione.
class WorkoutCard extends StatelessWidget {
  const WorkoutCard({super.key, required this.workout, this.index = 0, this.showOwner = false});

  final Workout workout;
  final int index;
  final bool showOwner;

  static const _accents = [AppColors.blue, AppColors.lilac, AppColors.pink, AppColors.mint];

  @override
  Widget build(BuildContext context) {
    final accent = _accents[index % _accents.length];
    final totalSets = workout.exercises.fold<int>(0, (a, e) => a + e.sets);
    return SoftCard(
      onTap: () => context.push('/workout/${workout.id}'),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(Icons.fitness_center_rounded, color: accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        workout.name,
                        style: Theme.of(context).textTheme.titleMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (workout.isPublic) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.public_rounded, size: 15, color: AppColors.muted),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  showOwner && workout.user != null
                      ? tr('@{username} · {count} esercizi', {'username': workout.user!.username, 'count': workout.exercises.length})
                      : '${weekdaysLabel(workout.dayOfWeek)}${workout.startTime != null ? ' · ${workout.startTime!.label}' : ''}',
                  style: TextStyle(color: AppColors.inkSoft, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${workout.exercises.length}', style: Theme.of(context).textTheme.titleLarge),
              Text(totalSets > 0 ? tr('{count} serie', {'count': totalSets}) : tr('esercizi'),
                  style: TextStyle(color: AppColors.muted, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}
