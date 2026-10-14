import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

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
import '../share/share_actions.dart';
import '../share/share_links.dart';
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

  /// Account e impostazioni: tutto quello che non serve tutti i giorni.
  void _showSettings() {
    final me = ref.read(currentUserProvider);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        void go(VoidCallback action) {
          Navigator.pop(ctx);
          action();
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Account', style: Theme.of(ctx).textTheme.headlineSmall),
                const SizedBox(height: 14),
                SoftCard(
                  child: Column(
                    children: [
                      _InfoRow(label: 'Email', value: me.email ?? '—'),
                      if (me.birthDate != null) _InfoRow(label: 'Data di nascita', value: formatDate(me.birthDate)),
                      if (me.createdAt != null) _InfoRow(label: 'Iscritto da', value: formatMonthYear(me.createdAt)),
                      if (Env.serverLabel != null) _InfoRow(label: 'Server', value: Env.serverLabel!),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SoftCard(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    children: [
                      _MenuRow(
                        icon: Icons.sports_gymnastics_rounded,
                        color: AppColors.mint,
                        label: 'Libreria esercizi',
                        onTap: () => go(() => context.push('/exercises')),
                      ),
                      _MenuRow(
                        icon: Icons.privacy_tip_outlined,
                        color: AppColors.blue,
                        label: 'Privacy policy',
                        onTap: () => go(() => launchUrl(Uri.parse(ShareLinks.privacy))),
                      ),
                      _MenuRow(
                        icon: Icons.description_outlined,
                        color: AppColors.inkSoft,
                        label: 'Termini di servizio',
                        onTap: () => go(() => launchUrl(Uri.parse(ShareLinks.terms))),
                      ),
                      _MenuRow(
                        icon: Icons.logout_rounded,
                        color: AppColors.ink,
                        label: 'Esci',
                        onTap: () => go(_logout),
                        last: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => go(_deleteAccount),
                  child: const Text('Elimina account', style: TextStyle(color: AppColors.danger)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider);
    final posts = ref.watch(userPostsProvider(me.username));
    final history = ref.watch(historyProvider).value ?? const [];
    final friends = ref.watch(friendsProvider).value ?? const <Friendship>[];
    final workouts = ref.watch(myWorkoutsProvider).value ?? const [];
    final total = history.fold<Duration>(Duration.zero, (a, h) => a + (h.duration ?? Duration.zero));
    final t = Theme.of(context).textTheme;

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
                    Expanded(child: Text('@${me.username}', style: t.titleLarge, overflow: TextOverflow.ellipsis)),
                    CircleIconButton(
                      icon: Icons.ios_share_rounded,
                      tooltip: 'Condividi profilo',
                      onTap: () => shareProfile(context, me,
                          mine: true, sessions: history.length, trained: total, friends: friends.length),
                    ),
                    const SizedBox(width: 10),
                    CircleIconButton(icon: Icons.settings_outlined, tooltip: 'Account', onTap: _showSettings),
                  ],
                ),
                const SizedBox(height: 20),
                // Foto, nome e numeri su una riga, come un profilo social.
                Row(
                  children: [
                    GestureDetector(
                      onTap: _uploading ? null : _changeAvatar,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          UserAvatar(username: me.username, imageUrl: me.image, size: 92, ring: true),
                          if (_uploading) const CircularProgressIndicator(),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: AppColors.ink,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Icon(Icons.photo_camera_rounded, size: 14, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _Counter(value: '${posts.value?.length ?? '–'}', label: 'Post'),
                          _Counter(value: '${history.length}', label: 'Sessioni', onTap: () => context.push('/history')),
                          _Counter(value: '${friends.length}', label: 'Amici', onTap: () => context.push('/friends')),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Flexible(child: Text(me.displayName, style: t.titleMedium, overflow: TextOverflow.ellipsis)),
                    if (me.isAccountVerified == true) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.verified_rounded, color: AppColors.blue, size: 18),
                    ],
                  ],
                ),
                if (total > Duration.zero)
                  Text('${formatDuration(total)} di allenamento', style: t.bodyMedium?.copyWith(color: AppColors.muted)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _PillButton(
                        icon: Icons.fitness_center_rounded,
                        label: 'Schede · ${workouts.length}',
                        onTap: () => context.push('/profile/workouts'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _PillButton(icon: Icons.history_rounded, label: 'Storico', onTap: () => context.push('/history')),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _PillButton(icon: Icons.people_alt_rounded, label: 'Amici', onTap: () => context.push('/friends')),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                SectionHeader('I miei post', action: 'Nuovo post', onAction: () => context.push('/posts/new')),
                AsyncView<List<Post>>(
                  value: posts,
                  onRetry: () => ref.invalidate(userPostsProvider(me.username)),
                  loading: const SkeletonGrid(),
                  data: (list) => list.isEmpty
                      ? SoftCard(
                          onTap: () => context.push('/posts/new'),
                          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
                          child: const Column(
                            children: [
                              Icon(Icons.photo_camera_rounded, size: 32, color: AppColors.muted),
                              SizedBox(height: 8),
                              Text('Condividi il tuo primo allenamento',
                                  style: TextStyle(fontWeight: FontWeight.w600)),
                            ],
                          ),
                        )
                      : PostGrid(posts: list),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pulsante a pillola bianco sotto l'intestazione del profilo.
class _PillButton extends StatelessWidget {
  const _PillButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
      radius: AppRadius.md,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: AppColors.inkSoft),
          const SizedBox(width: 6),
          Flexible(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ],
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
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Text(value, style: Theme.of(context).textTheme.titleLarge),
          Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.color, required this.label, required this.onTap, this.last = false});

  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          onTap: onTap,
          leading: IconChip(icon: icon, color: color, size: 36),
          title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
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
