import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/ui.dart';
import '../../data/providers.dart';
import '../../data/running_repository.dart';
import '../../models/running.dart';
import '../../models/social.dart';
import '../auth/auth_widgets.dart';
import '../auth/session.dart';
import 'geo.dart';

/// Nuova corsa di gruppo su uno dei miei percorsi: quando, dove ci si trova, chi invitare.
class RunEventFormScreen extends ConsumerStatefulWidget {
  const RunEventFormScreen({super.key, this.routeId});

  final String? routeId;

  @override
  ConsumerState<RunEventFormScreen> createState() => _RunEventFormScreenState();
}

class _RunEventFormScreenState extends ConsumerState<RunEventFormScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _meeting = TextEditingController();
  final _notes = TextEditingController();
  late String? _routeId = widget.routeId;
  DateTime? _when;
  final _invited = <String>{};
  bool _loading = false;

  @override
  void dispose() {
    _title.dispose();
    _meeting.dispose();
    _notes.dispose();
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
      initialTime: TimeOfDay.fromDateTime(_when ?? DateTime(now.year, now.month, now.day, 7, 30)),
    );
    if (time == null) return;
    setState(() => _when = DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_routeId == null) {
      showMessage(context, 'Scegli il percorso', error: true);
      return;
    }
    if (_when == null) {
      showMessage(context, 'Scegli giorno e ora', error: true);
      return;
    }
    setState(() => _loading = true);
    try {
      String? text(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
      final event = await ref.read(runningRepositoryProvider).createEvent(
            routeId: _routeId!,
            title: _title.text.trim(),
            startsAt: _when!,
            meetingPoint: text(_meeting),
            notes: text(_notes),
            invited: _invited.toList(),
          );
      ref.invalidate(runEventsProvider);
      if (mounted) context.pushReplacement('/running/event/${event.id}');
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider).username;
    final routes = ref.watch(myRoutesProvider);
    final friends = ref.watch(friendsProvider);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const TopBar(title: 'Corsa di gruppo'),
            Expanded(
              child: Form(
                key: _form,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  children: [
                    LabeledField(
                      label: 'Titolo',
                      controller: _title,
                      hint: 'es. Lungo della domenica',
                      validator: (v) => v == null || v.trim().isEmpty ? 'Dai un titolo alla corsa' : null,
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
                    const SizedBox(height: 14),
                    LabeledField(
                      label: 'Punto di ritrovo',
                      controller: _meeting,
                      hint: 'es. Ingresso del parco, lato fontana',
                    ),
                    LabeledField(label: 'Note', controller: _notes, hint: 'Passo, cosa portare…', maxLines: 2),
                    const SectionHeader('Percorso'),
                    AsyncView<List<RunRoute>>(
                      value: routes,
                      onRetry: () => ref.invalidate(myRoutesProvider),
                      data: (list) {
                        if (list.isEmpty) {
                          return EmptyState(
                            title: 'Nessun percorso',
                            message: 'Per correre insieme disegna prima il percorso.',
                            action: 'Disegna un percorso',
                            onAction: () => context.push('/running/route/new'),
                          );
                        }
                        return Column(
                          children: [
                            for (final r in list)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Material(
                                  color: r.id == _routeId ? AppColors.ink : AppColors.card,
                                  borderRadius: BorderRadius.circular(AppRadius.md),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(AppRadius.md),
                                    onTap: () => setState(() => _routeId = r.id),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(r.name,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  color: r.id == _routeId ? AppColors.onInk : AppColors.ink,
                                                )),
                                          ),
                                          Text(formatDistance(r.distanceM),
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: r.id == _routeId ? AppColors.onInk.withValues(alpha: 0.7) : AppColors.muted,
                                              )),
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
                    const SizedBox(height: 10),
                    const SectionHeader('Invita'),
                    AsyncView<List<Friendship>>(
                      value: friends,
                      onRetry: () => ref.invalidate(friendsProvider),
                      data: (list) {
                        final people = list.map((f) => f.other(me)).toList();
                        if (people.isEmpty) {
                          return Text('Aggiungi degli amici per invitarli; puoi anche correre da solo.',
                              style: TextStyle(color: AppColors.muted));
                        }
                        return Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final u in people)
                              FilterChip(
                                avatar: UserAvatar(username: u.username, imageUrl: u.image, size: 24),
                                label: Text('@${u.username}'),
                                selected: _invited.contains(u.username),
                                onSelected: (on) => setState(() => on ? _invited.add(u.username) : _invited.remove(u.username)),
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
              child: PrimaryButton(label: 'Crea la corsa', loading: _loading, onPressed: _save),
            ),
          ],
        ),
      ),
    );
  }
}
