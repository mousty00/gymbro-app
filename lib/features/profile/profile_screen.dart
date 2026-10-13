import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/config/env.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/backgrounds.dart';
import '../../core/widgets/ui.dart';
import '../../data/providers.dart';
import '../../data/user_repository.dart';
import '../../models/social.dart';
import '../auth/session.dart';
import '../friends/user_profile_screen.dart';
import '../home/home_screen.dart';
import '../shell/app_shell.dart';
import '../../core/widgets/skeleton.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _uploading = false;

  Future<void> _changeAvatar() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1024, imageQuality: 85);
    if (file == null || !mounted) return;
    setState(() => _uploading = true);
    try {
      await ref.read(userRepositoryProvider).updateProfileImage(await file.readAsBytes(), file.name);
      await ref.read(sessionProvider.notifier).reloadProfile();
      if (mounted) showMessage(context, 'Foto profilo aggiornata');
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _logout() async {
    if (!await confirm(context, title: 'Vuoi uscire?', ok: 'Esci')) return;
    await ref.read(sessionProvider.notifier).logout();
  }

  Future<void> _deleteAccount() async {
    final ok = await confirm(
      context,
      title: 'Eliminare l\'account?',
      message: 'Schede, post e storico verranno cancellati definitivamente.',
      ok: 'Elimina account',
      destructive: true,
    );
    if (!ok) return;
    try {
      await ref.read(userRepositoryProvider).deleteMe();
      await ref.read(sessionProvider.notifier).forget();
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider);
    final posts = ref.watch(userPostsProvider(me.username));
    final history = ref.watch(historyProvider).value ?? const [];
    final friends = ref.watch(friendsProvider).value ?? const <Friendship>[];
    final workouts = ref.watch(myWorkoutsProvider).value ?? const [];
    final total = history.fold<Duration>(Duration.zero, (a, h) => a + (h.duration ?? Duration.zero));

    return Scaffold(
      body: SkyBackground(
        tint: AppColors.lilacSoft,
        child: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(historyProvider);
              ref.invalidate(friendsProvider);
              ref.invalidate(userPostsProvider(me.username));
              await ref.read(sessionProvider.notifier).reloadProfile();
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, navBarClearance),
              children: [
                Row(
                  children: [
                    Expanded(child: Text('Profilo', style: Theme.of(context).textTheme.headlineMedium)),
                    CircleIconButton(icon: Icons.logout_rounded, tooltip: 'Esci', onTap: _logout),
                  ],
                ),
                const SizedBox(height: 16),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    ProfileHeader(user: me, onEditAvatar: _uploading ? null : _changeAvatar),
                    if (_uploading) const Positioned(top: 40, child: CircularProgressIndicator()),
                  ],
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    _Counter(value: '${history.length}', label: 'Sessioni', onTap: () => context.push('/history')),
                    _Counter(value: formatDuration(total), label: 'Allenato', onTap: () => context.push('/history')),
                    _Counter(value: '${friends.length}', label: 'Amici', onTap: () => context.push('/friends')),
                  ],
                ),
                const SizedBox(height: 20),
                SoftCard(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    children: [
                      _MenuRow(icon: Icons.people_alt_rounded, color: AppColors.pink, label: 'Amici e richieste', onTap: () => context.push('/friends')),
                      _MenuRow(icon: Icons.history_rounded, color: AppColors.lilac, label: 'Storico allenamenti', onTap: () => context.push('/history')),
                      _MenuRow(
                        icon: Icons.fitness_center_rounded,
                        color: AppColors.blue,
                        label: 'Le mie schede',
                        trailing: '${workouts.length}',
                        onTap: () => context.go('/workouts'),
                      ),
                      _MenuRow(icon: Icons.sports_gymnastics_rounded, color: AppColors.mint, label: 'Libreria esercizi', onTap: () => context.push('/exercises')),
                      _MenuRow(icon: Icons.add_circle_outline_rounded, color: AppColors.ink, label: 'Crea…', onTap: () => showQuickCreate(context), last: true),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                SoftCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _InfoRow(label: 'Email', value: me.email ?? '—'),
                      if (me.birthDate != null) _InfoRow(label: 'Data di nascita', value: formatDate(me.birthDate)),
                      if (me.createdAt != null) _InfoRow(label: 'Iscritto da', value: formatMonthYear(me.createdAt)),
                      _InfoRow(label: 'Server', value: Env.useMock ? 'Mock (dati finti)' : Env.apiBaseUrl),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const SectionHeader('I miei post'),
                AsyncView<List<Post>>(
                  value: posts,
                  onRetry: () => ref.invalidate(userPostsProvider(me.username)),
                  loading: const SkeletonGrid(),
                  data: (list) => PostGrid(posts: list),
                ),
                const SizedBox(height: 28),
                Center(
                  child: TextButton(
                    onPressed: _deleteAccount,
                    child: const Text('Elimina account', style: TextStyle(color: AppColors.danger)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Counter extends StatelessWidget {
  const _Counter({required this.value, required this.label, this.onTap});

  final String value;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: SoftCard(
          onTap: onTap,
          padding: const EdgeInsets.symmetric(vertical: 14),
          radius: AppRadius.md + 2,
          child: Column(
            children: [
              Text(value, style: Theme.of(context).textTheme.titleLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.color, required this.label, required this.onTap, this.trailing, this.last = false});

  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;
  final String? trailing;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          onTap: onTap,
          leading: IconChip(icon: icon, color: color, size: 36),
          title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (trailing != null) Text(trailing!, style: const TextStyle(color: AppColors.muted)),
              const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
            ],
          ),
        ),
        if (!last) const Divider(indent: 70, endIndent: 16),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(label, style: const TextStyle(color: AppColors.muted)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(value,
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}
