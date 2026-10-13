import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/ui.dart';
import '../../data/providers.dart';
import '../../data/social_repository.dart';
import '../../data/workout_repository.dart';
import '../../models/group.dart';
import '../../models/social.dart';

/// Richieste di amicizia e inviti ai gruppi.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(friendRequestsProvider);
    final invites = ref.watch(groupInvitesProvider);
    final loading = requests.isLoading || invites.isLoading;
    final r = requests.value ?? const <Friendship>[];
    final i = invites.value ?? const <GroupMember>[];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const TopBar(title: 'Notifiche'),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(groupInvitesProvider);
                  return ref.refresh(friendRequestsProvider.future);
                },
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: [
                    if (loading && r.isEmpty && i.isEmpty)
                      const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
                    else if (r.isEmpty && i.isEmpty)
                      const EmptyState(title: 'Tutto tranquillo', message: 'Nessuna richiesta o invito in sospeso.')
                    else ...[
                      if (r.isNotEmpty) ...[
                        SectionHeader('Richieste di amicizia · ${r.length}'),
                        for (final f in r) Padding(padding: const EdgeInsets.only(bottom: 10), child: FriendRequestTile(request: f)),
                        const SizedBox(height: 12),
                      ],
                      if (i.isNotEmpty) ...[
                        SectionHeader('Inviti ai gruppi · ${i.length}'),
                        for (final m in i) Padding(padding: const EdgeInsets.only(bottom: 10), child: GroupInviteTile(member: m)),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FriendRequestTile extends ConsumerStatefulWidget {
  const FriendRequestTile({super.key, required this.request});

  final Friendship request;

  @override
  ConsumerState<FriendRequestTile> createState() => _FriendRequestTileState();
}

class _FriendRequestTileState extends ConsumerState<FriendRequestTile> {
  bool _busy = false;

  Future<void> _act(bool accept) async {
    setState(() => _busy = true);
    final repo = ref.read(friendshipRepositoryProvider);
    try {
      accept ? await repo.accept(widget.request.id) : await repo.reject(widget.request.id);
      ref.invalidate(friendRequestsProvider);
      ref.invalidate(friendsProvider);
      ref.invalidate(friendsPostsProvider);
      if (mounted) showMessage(context, accept ? 'Ora siete amici!' : 'Richiesta rifiutata');
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final from = widget.request.user;
    return SoftCard(
      padding: const EdgeInsets.all(14),
      radius: AppRadius.md + 2,
      onTap: () => context.push('/u/${from.username}'),
      child: Row(
        children: [
          UserAvatar(username: from.username, imageUrl: from.image, size: 46),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('@${from.username}', style: const TextStyle(fontWeight: FontWeight.w700)),
                Text('vuole allenarsi con te · ${timeAgo(widget.request.createdAt)}',
                    style: const TextStyle(color: AppColors.inkSoft, fontSize: 13)),
              ],
            ),
          ),
          if (_busy)
            const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
          else ...[
            CircleIconButton(icon: Icons.close_rounded, size: 40, tooltip: 'Rifiuta', onTap: () => _act(false)),
            const SizedBox(width: 8),
            CircleIconButton(icon: Icons.check_rounded, size: 40, dark: true, tooltip: 'Accetta', onTap: () => _act(true)),
          ],
        ],
      ),
    );
  }
}

class GroupInviteTile extends ConsumerStatefulWidget {
  const GroupInviteTile({super.key, required this.member});

  final GroupMember member;

  @override
  ConsumerState<GroupInviteTile> createState() => _GroupInviteTileState();
}

class _GroupInviteTileState extends ConsumerState<GroupInviteTile> {
  bool _busy = false;

  Future<void> _act(bool accept) async {
    setState(() => _busy = true);
    final repo = ref.read(groupRepositoryProvider);
    try {
      accept ? await repo.acceptInvite(widget.member.id) : await repo.rejectInvite(widget.member.id);
      ref.invalidate(groupInvitesProvider);
      ref.invalidate(groupsProvider);
      if (!mounted) return;
      showMessage(context, accept ? 'Sei nel gruppo!' : 'Invito rifiutato');
      if (accept) context.push('/group/${widget.member.groupId}');
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(14),
      radius: AppRadius.md + 2,
      color: AppColors.lilacSoft,
      child: Row(
        children: [
          const IconChip(icon: Icons.groups_rounded, color: AppColors.lilac, background: Colors.white, size: 46),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.member.groupName ?? 'Invito a un allenamento di gruppo',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  _subtitle(widget.member),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.inkSoft, fontSize: 13),
                ),
              ],
            ),
          ),
          if (_busy)
            const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
          else ...[
            CircleIconButton(icon: Icons.close_rounded, size: 40, tooltip: 'Rifiuta', onTap: () => _act(false)),
            const SizedBox(width: 8),
            CircleIconButton(icon: Icons.check_rounded, size: 40, dark: true, tooltip: 'Accetta', onTap: () => _act(true)),
          ],
        ],
      ),
    );
  }
}

/// "da @marco · sab 17 ott alle 09:00", o quando è arrivato l'invito se il
/// backend non manda il riepilogo del gruppo.
String _subtitle(GroupMember m) {
  final parts = [
    if (m.groupCreatedBy != null) 'da @${m.groupCreatedBy}',
    if (m.groupScheduledFor != null) formatDayTime(m.groupScheduledFor),
  ];
  return parts.isEmpty ? timeAgo(m.createdAt) : parts.join(' · ');
}
