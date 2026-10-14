import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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

/// Nuovo allenamento di gruppo: nome, scheda, data e ora.
class GroupFormScreen extends ConsumerStatefulWidget {
  const GroupFormScreen({super.key, this.workoutId});

  final String? workoutId;

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
    if (_workoutId == null) {
      showMessage(context, 'Scegli la scheda da fare insieme', error: true);
      return;
    }
    setState(() => _loading = true);
    try {
      final group = await ref.read(groupRepositoryProvider).create(
            name: _name.text.trim(),
            workoutId: _workoutId!,
            scheduledFor: _when,
          );
      ref.invalidate(groupsProvider);
      if (mounted) context.pushReplacement('/group/${group.id}');
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
            const TopBar(title: 'Nuovo gruppo'),
            Expanded(
              child: Form(
                key: _form,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  children: [
                    LabeledField(
                      label: 'Nome del gruppo',
                      controller: _name,
                      hint: 'es. Leg day del sabato',
                      validator: (v) => v == null || v.trim().isEmpty ? 'Dai un nome al gruppo' : null,
                    ),
                    SoftCard(
                      onTap: _pickWhen,
                      padding: const EdgeInsets.all(16),
                      radius: AppRadius.md,
                      child: Row(
                        children: [
                          const IconChip(icon: Icons.event_rounded, color: AppColors.lilac),
                          const SizedBox(width: 12),
                          const Expanded(child: Text('Quando', style: TextStyle(fontWeight: FontWeight.w600))),
                          Text(_when == null ? 'Scegli data e ora' : formatDayTime(_when),
                              style: TextStyle(color: AppColors.inkSoft)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    const SectionHeader('Scheda'),
                    AsyncView<List<Workout>>(
                      value: workouts,
                      onRetry: () => ref.invalidate(myWorkoutsProvider),
                      loading: const SkeletonList(item: SkeletonTile(leading: 0), count: 3, spacing: 8, padding: EdgeInsets.zero),
                      data: (list) {
                        if (list.isEmpty) {
                          return EmptyState(
                            title: 'Nessuna scheda',
                            message: 'Per allenarvi insieme serve una scheda.',
                            action: 'Crea scheda',
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
                                            '${w.exercises.length} esercizi',
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
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: PrimaryButton(label: 'Crea gruppo', loading: _loading, onPressed: _save),
            ),
          ],
        ),
      ),
    );
  }
}
