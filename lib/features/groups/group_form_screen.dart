import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/ui.dart';
import '../../data/providers.dart';
import '../../data/workout_repository.dart';
import '../../models/workout.dart';
import '../auth/auth_widgets.dart';
import '../../core/widgets/skeleton.dart';

/// Nuovo gruppo fisso (solo il nome), oppure, con [groupId], nuova sessione del
/// gruppo: scheda, data e ora.
class GroupFormScreen extends ConsumerStatefulWidget {
  const GroupFormScreen({super.key, this.groupId, this.workoutId});

  final String? groupId;

  /// Scheda già scelta (es. "Allenati con un gruppo" dalla scheda).
  final String? workoutId;

  bool get isSession => groupId != null;

  @override
  ConsumerState<GroupFormScreen> createState() => _GroupFormScreenState();
}

class _GroupFormScreenState extends ConsumerState<GroupFormScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  late String? _workoutId = widget.workoutId;
  DateTime? _when;
  bool _loading = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickWhen() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _when ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_when ?? DateTime(now.year, now.month, now.day, 18)),
    );
    if (time == null) return;
    setState(() => _when = DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (widget.isSession && _workoutId == null) {
      showMessage(context, tr('Scegli la scheda da fare insieme'), error: true);
      return;
    }
    setState(() => _loading = true);
    try {
      final repo = ref.read(groupRepositoryProvider);
      if (widget.isSession) {
        final session = await repo.createSession(groupId: widget.groupId!, workoutId: _workoutId!, scheduledFor: _when);
        ref.invalidate(groupSessionsProvider(widget.groupId!));
        ref.invalidate(upcomingSessionsProvider);
        if (mounted) context.pushReplacement('/group-session/${session.id}');
        return;
      }
      final group = await repo.create(name: _name.text.trim());
      ref.invalidate(groupsProvider);
      if (!mounted) return;
      // arrivato da una scheda: subito la prima sessione con quella scheda
      context.pushReplacement(widget.workoutId == null
          ? '/group/${group.id}'
          : '/group/${group.id}/session/new?workout=${widget.workoutId}');
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final workouts = ref.watch(myWorkoutsProvider);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            TopBar(title: widget.isSession ? tr('Nuova sessione') : tr('Nuovo gruppo')),
            Expanded(
              child: Form(
                key: _form,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  children: [
                    if (!widget.isSession) ...[
                      LabeledField(
                        label: tr('Nome del gruppo'),
                        controller: _name,
                        hint: tr('es. Squadra del martedì'),
                        validator: (v) => v == null || v.trim().isEmpty ? tr('Dai un nome al gruppo') : null,
                      ),
                      Text(
                        tr('Il gruppo resta fisso: dopo inviti gli amici e crei le sessioni, ognuna con il suo giorno e la sua scheda.'),
                        style: TextStyle(color: AppColors.inkSoft),
                      ),
                    ] else ...[
                    SoftCard(
                      onTap: _pickWhen,
                      padding: const EdgeInsets.all(16),
                      radius: AppRadius.md,
                      child: Row(
                        children: [
                          const IconChip(icon: Icons.event_rounded, color: AppColors.lilac),
                          const SizedBox(width: 12),
                          Expanded(child: Text(tr('Quando'), style: const TextStyle(fontWeight: FontWeight.w600))),
                          Text(_when == null ? tr('Scegli data e ora') : formatDayTime(_when),
                              style: TextStyle(color: AppColors.inkSoft)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    SectionHeader(tr('Scheda')),
                    AsyncView<List<Workout>>(
                      value: workouts,
                      onRetry: () => ref.invalidate(myWorkoutsProvider),
                      loading: const SkeletonList(item: SkeletonTile(leading: 0), count: 3, spacing: 8, padding: EdgeInsets.zero),
                      data: (list) {
                        if (list.isEmpty) {
                          return EmptyState(
                            icon: Icons.assignment_rounded,
                            title: tr('Nessuna scheda'),
                            message: tr('Per allenarvi insieme serve una scheda.'),
                            action: tr('Crea scheda'),
                            onAction: () => context.push('/workout/new'),
                          );
                        }
                        return Column(
                          children: [
                            for (final w in list)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Material(
                                  color: w.id == _workoutId ? AppColors.ink : AppColors.card,
                                  borderRadius: BorderRadius.circular(AppRadius.md),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(AppRadius.md),
                                    onTap: () => setState(() => _workoutId = w.id),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              w.name,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                color: w.id == _workoutId ? AppColors.onInk : AppColors.ink,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            w.exercises.length == 1 ? tr('{n} esercizio', {'n': 1}) : tr('{n} esercizi', {'n': w.exercises.length}),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: w.id == _workoutId ? AppColors.onInk.withValues(alpha: 0.7) : AppColors.muted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: PrimaryButton(label: widget.isSession ? tr('Crea sessione') : tr('Crea gruppo'), loading: _loading, onPressed: _save),
            ),
          ],
        ),
      ),
    );
  }
}
