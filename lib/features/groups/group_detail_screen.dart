import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/backgrounds.dart';
import '../../core/widgets/ui.dart';
import '../../data/providers.dart';
import '../../data/workout_repository.dart';
import '../../models/group.dart';
import '../../models/social.dart';
import '../../models/workout.dart';
import '../auth/session.dart';

class GroupDetailScreen extends ConsumerWidget {
  const GroupDetailScreen({super.key, required this.groupId});

  final String groupId;

  void _refresh(WidgetRef ref) {
    ref.invalidate(groupProvider(groupId));
    ref.invalidate(groupsProvider);
  }

  Future<void> _invite(BuildContext context, WidgetRef ref, WorkoutGroup g) async {
    final username = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _InviteSheet(group: g),
    );
    if (username == null) return;
    try {
      await ref.read(groupRepositoryProvider).invite(groupId: g.id, username: username);
      _refresh(ref);
      if (context.mounted) showMessage(context, 'Invito inviato a @$username');
    } on ApiException catch (e) {
      if (context.mounted) showMessage(context, e.message, error: true);
    }
  }

  Future<void> _removeMember(BuildContext context, WidgetRef ref, GroupMember m, {required bool self}) async {
    final ok = await confirm(
      context,
      title: self ? 'Uscire dal gruppo?' : 'Rimuovere @${m.user.username}?',
      ok: self ? 'Esci' : 'Rimuovi',
      destructive: true,
    );
    if (!ok) return;
    try {
      await ref.read(groupRepositoryProvider).removeMember(m.id);
      if (self) {
        ref.invalidate(groupsProvider);
        if (context.mounted) context.pop();
      } else {
        _refresh(ref);
      }
    } on ApiException catch (e) {
      if (context.mounted) showMessage(context, e.message, error: true);
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    if (!await confirm(context, title: 'Eliminare il gruppo?', ok: 'Elimina', destructive: true)) return;
    try {
      await ref.read(groupRepositoryProvider).delete(groupId);
      ref.invalidate(groupsProvider);
      if (context.mounted) context.pop();
    } on ApiException catch (e) {
      if (context.mounted) showMessage(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider);
    final group = ref.watch(groupProvider(groupId));

    return Scaffold(
      body: SkyBackground(
        tint: AppColors.mintSoft,
        child: SafeArea(
          child: AsyncView<WorkoutGroup>(
            value: group,
            onRetry: () => ref.invalidate(groupProvider(groupId)),
            data: (g) {
              final isOwner = g.createdBy.username == me.username;
              final myMembership = g.members.where((m) => m.user.username == me.username).firstOrNull;
              final history = ref.watch(groupHistoryProvider(g.id));
              return Column(
                children: [
                  TopBar(
                    title: '',
                    actions: [
                      if (isOwner)
                        CircleIconButton(icon: Icons.delete_outline_rounded, size: 44, tooltip: 'Elimina', onTap: () => _delete(context, ref))
                      else if (myMembership != null)
                        CircleIconButton(
                          icon: Icons.logout_rounded,
                          size: 44,
                          tooltip: 'Esci dal gruppo',
                          onTap: () => _removeMember(context, ref, myMembership, self: true),
                        ),
                    ],
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () async {
                        ref.invalidate(groupHistoryProvider(g.id));
                        return ref.refresh(groupProvider(groupId).future);
                      },
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                        children: [
                          if (g.scheduledFor != null)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Tag(formatDayTime(g.scheduledFor), icon: Icons.schedule_rounded, color: AppColors.ink),
                            ),
                          const SizedBox(height: 12),
                          Text(g.name, style: Theme.of(context).textTheme.displaySmall),
                          const SizedBox(height: 6),
                          Text('Organizzato da @${g.createdBy.username}', style: const TextStyle(color: AppColors.inkSoft)),
                          const SizedBox(height: 20),
                          SoftCard(
                            onTap: () => context.push('/workout/${g.workoutId}'),
                            child: Row(
                              children: [
                                const IconChip(icon: Icons.fitness_center_rounded, color: AppColors.blue),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Scheda', style: TextStyle(color: AppColors.muted, fontSize: 12)),
                                      Text(g.workoutName, style: const TextStyle(fontWeight: FontWeight.w700)),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
                              ],
                            ),
                          ),
                          const SizedBox(height: 22),
                          SectionHeader(
                            'Partecipanti',
                            action: isOwner ? '+ Invita' : null,
                            onAction: () => _invite(context, ref, g),
                          ),
                          _MemberTile(username: g.createdBy.username, image: g.createdBy.image, status: 'Organizzatore'),
                          for (final m in g.members)
                            _MemberTile(
                              username: m.user.username,
                              image: m.user.image,
                              status: switch (m.status) {
                                GroupMemberStatus.accepted => 'Partecipa',
                                GroupMemberStatus.invited => 'Invitato',
                                GroupMemberStatus.rejected => 'Ha rifiutato',
                                GroupMemberStatus.unknown => '',
                              },
                              muted: m.status != GroupMemberStatus.accepted,
                              onRemove: isOwner ? () => _removeMember(context, ref, m, self: false) : null,
                            ),
                          const SizedBox(height: 22),
                          const SectionHeader('Sessioni del gruppo'),
                          AsyncView<List<WorkoutHistory>>(
                            value: history,
                            loading: const LoadingBlock(height: 80),
                            onRetry: () => ref.invalidate(groupHistoryProvider(g.id)),
                            data: (list) => list.isEmpty
                                ? const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    child: Text('Ancora nessuna sessione registrata.', style: TextStyle(color: AppColors.muted)),
                                  )
                                : Column(
                                    children: [
                                      for (final h in list)
                                        Padding(
                                          padding: const EdgeInsets.only(bottom: 8),
                                          child: SoftCard(
                                            padding: const EdgeInsets.all(14),
                                            radius: AppRadius.md,
                                            child: Row(
                                              children: [
                                                const IconChip(icon: Icons.check_circle_rounded, color: AppColors.mint, size: 34),
                                                const SizedBox(width: 12),
                                                Expanded(child: Text(formatDayTime(h.startedAt), style: const TextStyle(fontWeight: FontWeight.w600))),
                                                Text(formatDuration(h.duration), style: const TextStyle(color: AppColors.inkSoft)),
                                              ],
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: PillActionButton(
                      label: 'Inizia la sessione di gruppo',
                      icon: Icons.play_arrow_rounded,
                      onPressed: () => context.push('/workout/${g.workoutId}/session?group=${g.id}'),
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

class _MemberTile extends StatelessWidget {
  const _MemberTile({required this.username, this.image, required this.status, this.muted = false, this.onRemove});

  final String username;
  final String? image;
  final String status;
  final bool muted;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SoftCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        radius: AppRadius.md,
        onTap: () => context.push('/u/$username'),
        child: Row(
          children: [
            UserAvatar(username: username, imageUrl: image, size: 40),
            const SizedBox(width: 12),
            Expanded(child: Text('@$username', style: const TextStyle(fontWeight: FontWeight.w600))),
            Tag(status, color: muted ? AppColors.muted : AppColors.mint),
            if (onRemove != null)
              IconButton(icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.muted), onPressed: onRemove),
          ],
        ),
      ),
    );
  }
}

/// Scegli un amico da invitare (o scrivi uno username).
class _InviteSheet extends ConsumerStatefulWidget {
  const _InviteSheet({required this.group});

  final WorkoutGroup group;

  @override
  ConsumerState<_InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends ConsumerState<_InviteSheet> {
  final _username = TextEditingController();

  @override
  void dispose() {
    _username.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider);
    final friends = ref.watch(friendsProvider);
    final already = {widget.group.createdBy.username, ...widget.group.members.map((m) => m.user.username)};

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Invita', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _username,
                    decoration: const InputDecoration(hintText: 'Username'),
                    onSubmitted: (v) => v.trim().isEmpty ? null : Navigator.pop(context, v.trim()),
                  ),
                ),
                const SizedBox(width: 10),
                CircleIconButton(
                  icon: Icons.send_rounded,
                  dark: true,
                  onTap: () {
                    if (_username.text.trim().isNotEmpty) Navigator.pop(context, _username.text.trim());
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('I tuoi amici', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Expanded(
              child: AsyncView<List<Friendship>>(
                value: friends,
                onRetry: () => ref.invalidate(friendsProvider),
                data: (list) {
                  final candidates = list.map((f) => f.other(me.username)).where((u) => !already.contains(u.username)).toList();
                  if (candidates.isEmpty) {
                    return const Center(child: Text('Nessun amico da invitare', style: TextStyle(color: AppColors.muted)));
                  }
                  return ListView(
                    children: [
                      for (final u in candidates)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: UserAvatar(username: u.username, imageUrl: u.image, size: 40),
                          title: Text('@${u.username}', style: const TextStyle(fontWeight: FontWeight.w600)),
                          trailing: const Tag('Invita'),
                          onTap: () => Navigator.pop(context, u.username),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
