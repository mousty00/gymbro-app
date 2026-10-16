import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/backgrounds.dart';
import '../../core/widgets/ui.dart';
import '../../data/providers.dart';
import '../../models/group.dart';
import '../friends/notifications_screen.dart';
import '../home/home_screen.dart';
import '../shell/app_shell.dart';
import '../../core/widgets/skeleton.dart';

class GroupsScreen extends ConsumerWidget {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(groupsProvider);
    final invites = ref.watch(groupInvitesProvider).value ?? const <GroupMember>[];

    return Scaffold(
      body: SkyBackground(
        child: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(groupInvitesProvider);
              ref.invalidate(upcomingSessionsProvider);
              return ref.refresh(groupsProvider.future);
            },
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
                            Expanded(child: Text(tr('Gruppi'), style: Theme.of(context).textTheme.headlineMedium)),
                            CircleIconButton(
                              icon: Icons.add_rounded,
                              dark: true,
                              tooltip: tr('Nuovo gruppo'),
                              onTap: () => context.push('/group/new'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(tr('Allenarsi insieme è più facile.'), style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.inkSoft)),
                        const SizedBox(height: 18),
                        if (invites.isNotEmpty) ...[
                          SectionHeader(tr('Inviti · {count}', {'count': invites.length})),
                          for (final m in invites)
                            Padding(padding: const EdgeInsets.only(bottom: 10), child: GroupInviteTile(member: m)),
                          const SizedBox(height: 10),
                        ],
                      ],
                    ),
                  ),
                ),
                AsyncView<List<WorkoutGroup>>(
                  value: groups,
                  sliver: true,
                  onRetry: () => ref.invalidate(groupsProvider),
                  loading: const SkeletonList(
                    item: SkeletonGroupCard(),
                    count: 3,
                    spacing: 12,
                    padding: EdgeInsets.symmetric(horizontal: 20),
                  ),
                  data: (list) {
                    if (list.isEmpty) {
                      return SliverToBoxAdapter(
                        child: EmptyState(
                          icon: Icons.groups_rounded,
                          title: tr('Nessun gruppo'),
                          message: tr('Crea un allenamento di gruppo e invita i tuoi amici.'),
                          action: tr('Crea gruppo'),
                          onAction: () => context.push('/group/new'),
                        ),
                      );
                    }
                    // prima i gruppi con la sessione più vicina
                    final sessions = ref.watch(upcomingSessionsProvider).value ?? const <GroupSession>[];
                    DateTime nextOf(WorkoutGroup g) =>
                        sessions.where((s) => s.groupId == g.id && s.scheduledFor != null).firstOrNull?.scheduledFor ?? DateTime(2100);
                    final sorted = [...list]..sort((a, b) => nextOf(a).compareTo(nextOf(b)));
                    return SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, navBarClearance),
                      sliver: SliverList.separated(
                        itemCount: sorted.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (_, i) => GroupCard(group: sorted[i], index: i),
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

class GroupCard extends ConsumerWidget {
  const GroupCard({super.key, required this.group, this.index = 0});

  final WorkoutGroup group;
  final int index;

  static List<Color> get _bgs => [AppColors.blueSoft, AppColors.lilacSoft, AppColors.pinkSoft, AppColors.mintSoft];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = [group.createdBy, ...group.acceptedMembers.map((m) => m.user)];
    // la prossima sessione del gruppo, se c'è
    final next = (ref.watch(upcomingSessionsProvider).value ?? const <GroupSession>[])
        .where((s) => s.groupId == group.id)
        .firstOrNull;
    return SoftCard(
      color: _bgs[index % _bgs.length],
      onTap: () => context.push('/group/${group.id}'),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (next?.scheduledFor != null)
                Tag(formatDayTime(next!.scheduledFor!.toLocal()), color: AppColors.ink, icon: Icons.schedule_rounded)
              else
                Tag(tr('Nessuna sessione in programma'), color: AppColors.inkSoft),
              const Spacer(),
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
          Text(group.name, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 2),
          if (next != null) Text(tr('Prossima: {name}', {'name': next.workoutName}), style: TextStyle(color: AppColors.inkSoft)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: AvatarStack(users: members, size: 32)),
              Text(members.length == 1 ? tr('{n} persona', {'n': 1}) : tr('{n} persone', {'n': members.length}),
                  style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.inkSoft, fontSize: 13)),
            ],
          ),
        ],
      ),
    );
  }
}
