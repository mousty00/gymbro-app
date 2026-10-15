import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/backgrounds.dart';
import '../../core/widgets/ui.dart';
import '../../data/providers.dart';
import '../../data/workout_repository.dart';
import '../../models/workout.dart';
import '../auth/session.dart';
import '../share/share_actions.dart';
import 'exercise_picker.dart';
import '../../core/widgets/skeleton.dart';

class WorkoutDetailScreen extends ConsumerWidget {
  const WorkoutDetailScreen({super.key, required this.workoutId});

  final String workoutId;

  void _refresh(WidgetRef ref) {
    ref.invalidate(workoutProvider(workoutId));
    ref.invalidate(myWorkoutsProvider);
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    if (!await confirm(context,
        title: 'Eliminare la scheda?', message: 'Verranno rimossi anche i suoi esercizi.', ok: 'Elimina', destructive: true)) {
      return;
    }
    try {
      await ref.read(workoutRepositoryProvider).delete(workoutId);
      ref.invalidate(myWorkoutsProvider);
      ref.invalidate(exploreWorkoutsProvider);
      if (context.mounted) context.pop();
    } on ApiException catch (e) {
      if (context.mounted) showMessage(context, e.message, error: true);
    }
  }

  Future<void> _addExercise(BuildContext context, WidgetRef ref, Workout w) async {
    final input = await showExerciseEditor(context, workoutId: w.id, position: w.exercises.length + 1);
    if (input == null) return;
    try {
      await ref.read(workoutRepositoryProvider).addExercise(input);
      _refresh(ref);
    } on ApiException catch (e) {
      if (context.mounted) showMessage(context, e.message, error: true);
    }
  }

  Future<void> _editExercise(BuildContext context, WidgetRef ref, WorkoutExercise we) async {
    final input = await showExerciseEditor(context, workoutId: we.workoutId, position: we.position, initial: we);
    if (input == null) return;
    try {
      await ref.read(workoutRepositoryProvider).updateExercise(input);
      _refresh(ref);
    } on ApiException catch (e) {
      if (context.mounted) showMessage(context, e.message, error: true);
    }
  }

  Future<void> _removeExercise(BuildContext context, WidgetRef ref, WorkoutExercise we) async {
    try {
      await ref.read(workoutRepositoryProvider).removeExercise(we.id);
      _refresh(ref);
    } on ApiException catch (e) {
      if (context.mounted) showMessage(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider);
    final workout = ref.watch(workoutProvider(workoutId));

    return Scaffold(
      body: SkyBackground(
        child: SafeArea(
          child: AsyncView<Workout>(
            value: workout,
            onRetry: () => ref.invalidate(workoutProvider(workoutId)),
            loading: const SkeletonDetail(),
            data: (w) {
              final mine = w.user?.username == me.username;
              final totalSets = w.exercises.fold<int>(0, (a, e) => a + e.sets);
              final estMinutes = w.exercises.fold<int>(0, (a, e) => a + e.sets * (45 + e.restSeconds)) ~/ 60;
              return Column(
                children: [
                  TopBar(
                    title: '',
                    actions: [
                      CircleIconButton(
                        icon: Icons.ios_share_rounded,
                        size: 44,
                        tooltip: 'Condividi',
                        onTap: () => shareWorkout(context, w, mine: mine),
                      ),
                      if (mine) ...[
                        CircleIconButton(
                          icon: Icons.edit_rounded,
                          size: 44,
                          tooltip: 'Modifica',
                          onTap: () => context.push('/workout/${w.id}/edit', extra: w),
                        ),
                        CircleIconButton(
                          icon: Icons.delete_outline_rounded,
                          size: 44,
                          tooltip: 'Elimina',
                          onTap: () => _delete(context, ref),
                        ),
                      ],
                    ],
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      children: [
                        Wrap(
                          spacing: 8,
                          children: [
                            Tag(weekdaysLabel(w.dayOfWeek), icon: Icons.event_repeat_rounded),
                            if (w.startTime != null)
                              Tag(w.startTime!.label, icon: Icons.schedule_rounded, color: AppColors.lilac),
                            Tag(w.isPublic ? 'Pubblica' : 'Privata',
                                icon: w.isPublic ? Icons.public_rounded : Icons.lock_outline_rounded,
                                color: AppColors.inkSoft),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(w.name, style: Theme.of(context).textTheme.displaySmall),
                        if (!mine && w.user != null) ...[
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: () => context.push('/u/${w.user!.username}'),
                            child: Text('di @${w.user!.username}',
                                style: const TextStyle(color: AppColors.blue, fontWeight: FontWeight.w600)),
                          ),
                        ],
                        if (w.description?.isNotEmpty == true) ...[
                          const SizedBox(height: 10),
                          Text(w.description!, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.inkSoft)),
                        ],
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            _Metric(value: '${w.exercises.length}', label: 'Esercizi'),
                            const SizedBox(width: 10),
                            _Metric(value: '$totalSets', label: 'Serie'),
                            const SizedBox(width: 10),
                            _Metric(value: estMinutes > 0 ? '~$estMinutes' : '—', label: 'Minuti'),
                          ],
                        ),
                        const SizedBox(height: 22),
                        SectionHeader(
                          'Esercizi',
                          action: mine ? '+ Aggiungi' : null,
                          onAction: () => _addExercise(context, ref, w),
                        ),
                        if (w.exercises.isEmpty)
                          EmptyState(
                            icon: Icons.playlist_add_rounded,
                            title: 'Scheda vuota',
                            message: mine ? 'Aggiungi il primo esercizio dalla libreria.' : null,
                            action: mine ? 'Aggiungi esercizio' : null,
                            onAction: () => _addExercise(context, ref, w),
                          ),
                        for (final e in w.exercises)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _ExerciseRow(
                              exercise: e,
                              editable: mine,
                              onEdit: () => _editExercise(context, ref, e),
                              onDelete: () => _removeExercise(context, ref, e),
                            ),
                          ),
                        if (mine) ...[
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: () => context.push('/group/new?workout=${w.id}'),
                            icon: const Icon(Icons.groups_rounded),
                            label: const Text('Allenati in gruppo con questa scheda'),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (w.exercises.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                      child: PillActionButton(
                        label: 'Inizia allenamento',
                        icon: Icons.play_arrow_rounded,
                        onPressed: () => context.push('/workout/${w.id}/session'),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: SoftCard(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
        radius: AppRadius.md,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: Theme.of(context).textTheme.headlineSmall),
            Text(label, style: TextStyle(color: AppColors.muted, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  const _ExerciseRow({required this.exercise, required this.editable, required this.onEdit, required this.onDelete});

  final WorkoutExercise exercise;
  final bool editable;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final card = SoftCard(
      padding: const EdgeInsets.all(14),
      radius: AppRadius.md + 2,
      onTap: editable ? onEdit : null,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: AppColors.bg, shape: BoxShape.circle),
            child: Text('${exercise.position}', style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(exercise.exerciseName ?? 'Esercizio', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 2),
                Text(exercise.summary, style: TextStyle(color: AppColors.inkSoft, fontSize: 13)),
              ],
            ),
          ),
          Tag('${exercise.restSeconds}s recupero', icon: Icons.hourglass_bottom_rounded, color: AppColors.lilac),
        ],
      ),
    );
    if (!editable) return card;
    return Dismissible(
      key: ValueKey(exercise.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => confirm(context, title: 'Rimuovere l\'esercizio?', ok: 'Rimuovi', destructive: true),
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.md + 2),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
      ),
      child: card,
    );
  }
}
