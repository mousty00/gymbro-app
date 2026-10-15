import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/backgrounds.dart';
import '../../core/widgets/ui.dart';
import '../../data/providers.dart';
import '../../data/workout_repository.dart';
import '../../models/workout.dart';
import '../../core/widgets/skeleton.dart';

/// Sessione live: cronometro, serie da spuntare, recupero, salvataggio nello storico.
class WorkoutSessionScreen extends ConsumerStatefulWidget {
  const WorkoutSessionScreen({super.key, required this.workoutId, this.groupId});

  final String workoutId;
  final String? groupId;

  @override
  ConsumerState<WorkoutSessionScreen> createState() => _WorkoutSessionScreenState();
}

class _WorkoutSessionScreenState extends ConsumerState<WorkoutSessionScreen> {
  final DateTime _startedAt = DateTime.now();
  final _notes = TextEditingController();
  final Map<String, int> _doneSets = {};
  Timer? _ticker;
  Duration _elapsed = Duration.zero;
  /// Recupero tra una serie e l'altra: conto alla rovescia separato dalla
  /// durata dell'allenamento, che invece continua a scorrere.
  int _restLeft = 0;
  int _restTotal = 0;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _elapsed = DateTime.now().difference(_startedAt);
        if (_restLeft > 0) {
          _restLeft--;
          if (_restLeft == 0) HapticFeedback.heavyImpact();
        }
      });
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _notes.dispose();
    super.dispose();
  }

  void _toggleSet(WorkoutExercise e, int index) {
    setState(() {
      final done = _doneSets[e.id] ?? 0;
      if (index < done) {
        _doneSets[e.id] = index;
      } else {
        _doneSets[e.id] = index + 1;
        _restLeft = _restTotal = e.restSeconds;
      }
    });
  }

  void _addRest(int seconds) => setState(() {
        _restLeft += seconds;
        _restTotal += seconds;
      });

  void _skipRest() => setState(() => _restLeft = 0);

  Future<void> _finish(Workout w) async {
    final ok = await confirm(context, title: tr('Terminare l\'allenamento?'), message: tr('La sessione verrà salvata nello storico.'), ok: tr('Termina'));
    if (!ok) return;
    setState(() => _saving = true);
    try {
      await ref.read(workoutRepositoryProvider).logSession(
            workoutId: w.id,
            groupId: widget.groupId,
            startedAt: _startedAt,
            completedAt: DateTime.now(),
            notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
          );
      ref.invalidate(historyProvider);
      if (widget.groupId != null) ref.invalidate(groupHistoryProvider(widget.groupId!));
      if (!mounted) return;
      showMessage(context, tr('Allenamento salvato. Grande! 💪'));
      context.pop();
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final workout = ref.watch(workoutProvider(widget.workoutId));
    final t = Theme.of(context).textTheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await confirm(context, title: tr('Abbandonare la sessione?'), message: tr('I progressi non verranno salvati.'), ok: tr('Esci'), destructive: true);
        if (leave && context.mounted) context.pop();
      },
      child: Scaffold(
        body: SkyBackground(
          child: SafeArea(
            child: AsyncView<Workout>(
              value: workout,
              onRetry: () => ref.invalidate(workoutProvider(widget.workoutId)),
              loading: const SkeletonDetail(),
              data: (w) {
                final totalSets = w.exercises.fold<int>(0, (a, e) => a + e.sets);
                final doneSets = _doneSets.values.fold<int>(0, (a, b) => a + b);
                final progress = totalSets == 0 ? 0.0 : doneSets / totalSets;
                return Column(
                  children: [
                    TopBar(title: w.name),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                        children: [
                          SoftCard(
                            color: AppColors.inkCard,
                            padding: const EdgeInsets.all(22),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.timer_outlined, size: 16, color: Colors.white.withValues(alpha: 0.6)),
                                    const SizedBox(width: 6),
                                    Text(widget.groupId != null ? tr('Durata sessione di gruppo') : tr('Durata allenamento'),
                                        style: TextStyle(color: Colors.white.withValues(alpha: 0.6))),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  formatClock(_elapsed),
                                  style: t.displayLarge?.copyWith(color: Colors.white, fontFeatures: const [FontFeature.tabularFigures()]),
                                ),
                                const SizedBox(height: 16),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: LinearProgressIndicator(
                                    value: progress,
                                    minHeight: 8,
                                    backgroundColor: Colors.white.withValues(alpha: 0.12),
                                    color: AppColors.lilac,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(tr('{done} / {total} serie completate', {'done': doneSets, 'total': totalSets}),
                                    style: TextStyle(color: AppColors.onInk.withValues(alpha: 0.7), fontSize: 13)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          _RestCard(
                            left: _restLeft,
                            total: _restTotal,
                            onAdd: () => _addRest(15),
                            onSkip: _skipRest,
                          ),
                          const SizedBox(height: 18),
                          for (final e in w.exercises)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: SoftCard(
                                padding: const EdgeInsets.all(16),
                                radius: AppRadius.md + 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(e.exerciseName ?? tr('Esercizio'), style: t.titleMedium),
                                        ),
                                        Text(e.summary, style: TextStyle(color: AppColors.inkSoft)),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        for (var i = 0; i < e.sets; i++)
                                          _SetDot(
                                            index: i + 1,
                                            done: i < (_doneSets[e.id] ?? 0),
                                            onTap: () => _toggleSet(e, i),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _notes,
                            minLines: 2,
                            maxLines: 4,
                            decoration: InputDecoration(hintText: tr('Note sulla sessione (opzionale)')),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                      child: PillActionButton(
                        label: tr('Termina e salva'),
                        icon: Icons.check_rounded,
                        loading: _saving,
                        onPressed: () => _finish(w),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _SetDot extends StatelessWidget {
  const _SetDot({required this.index, required this.done, required this.onTap});

  final int index;
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 46,
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: done ? AppColors.mint : AppColors.bg,
        ),
        child: done
            ? const Icon(Icons.check_rounded, color: Colors.white)
            : Text('$index', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.inkSoft)),
      ),
    );
  }
}

/// Recupero tra le serie: parte da solo quando spunti una serie e conta alla
/// rovescia i secondi impostati nella scheda. Non ferma la durata
/// dell'allenamento.
class _RestCard extends StatelessWidget {
  const _RestCard({required this.left, required this.total, required this.onAdd, required this.onSkip});

  final int left;
  final int total;
  final VoidCallback onAdd;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final resting = left > 0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.fromLTRB(18, 14, 12, 14),
      decoration: BoxDecoration(
        color: resting ? AppColors.lilac : AppColors.card.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(AppRadius.md + 2),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: resting && total > 0 ? left / total : 0,
                  strokeWidth: 4,
                  color: Colors.white,
                  backgroundColor: resting ? Colors.white.withValues(alpha: 0.25) : AppColors.bg,
                ),
                Icon(Icons.hourglass_bottom_rounded, size: 20, color: resting ? Colors.white : AppColors.muted),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  resting ? tr('Recupero tra le serie') : tr('Recupero'),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: resting ? Colors.white : AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  resting ? tr('Riposa, poi fai la prossima serie') : tr('Parte da solo quando spunti una serie'),
                  style: TextStyle(fontSize: 12, color: resting ? Colors.white70 : AppColors.muted),
                ),
              ],
            ),
          ),
          if (resting) ...[
            Text(
              formatClock(Duration(seconds: left)),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w700,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: tr('+15 secondi'),
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
            ),
            IconButton(
              tooltip: tr('Salta recupero'),
              onPressed: onSkip,
              icon: const Icon(Icons.skip_next_rounded, color: Colors.white),
            ),
          ],
        ],
      ),
    );
  }
}
