import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_image.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/backgrounds.dart';
import '../../core/widgets/ui.dart';
import '../../data/providers.dart';
import '../../models/social.dart';
import '../../models/user.dart';
import '../auth/session.dart';
import '../feed/moderation.dart';
import '../share/share_actions.dart';
import 'friends_screen.dart';
import '../../core/widgets/skeleton.dart';

/// Profilo pubblico di un altro utente con i suoi post.
class UserProfileScreen extends ConsumerWidget {
  const UserProfileScreen({super.key, required this.username});

  final String username;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider);
    if (username == me.username) {
      // Il proprio profilo vive nella tab Profilo.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/profile');
      });
    }
    final user = ref.watch(userProfileProvider(username));
    final posts = ref.watch(userPostsProvider(username));
    final isFriend = (ref.watch(friendsProvider).value ?? const <Friendship>[])
        .any((f) => f.other(me.username).username == username);

    return Scaffold(
      body: SkyBackground(
        child: SafeArea(
          child: Column(
            children: [
              TopBar(
                title: '',
                actions: [
                  if (user.value != null)
                    CircleIconButton(
                      icon: Icons.ios_share_rounded,
                      size: 44,
                      tooltip: tr('Condividi profilo'),
                      onTap: () => shareProfile(context, user.value!),
                    ),
                  if (user.value != null && username != me.username)
                    ModerationMenu(
                      type: 'USER',
                      targetId: user.value!.id,
                      username: username,
                      onBlocked: () => context.canPop() ? context.pop() : null,
                    ),
                ],
              ),
              Expanded(
                child: AsyncView<User>(
                  value: user,
                  onRetry: () => ref.invalidate(userProfileProvider(username)),
                  loading: const SkeletonProfile(),
                  data: (u) => ListView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    children: [
                      ProfileHeader(user: u),
                      const SizedBox(height: 20),
                      if (isFriend)
                        Center(child: Tag(tr('Siete amici'), color: AppColors.mint, icon: Icons.check_rounded))
                      else
                        AddFriendButton(username: u.username, large: true),
                      const SizedBox(height: 24),
                      SectionHeader(tr('Post')),
                      AsyncView<List<Post>>(
                        value: posts,
                        onRetry: () => ref.invalidate(userPostsProvider(username)),
                        loading: const SkeletonGrid(),
                        data: (list) => PostGrid(posts: list),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Avatar grande, nome e username centrati.
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({super.key, required this.user, this.onEditAvatar});

  final User user;
  final VoidCallback? onEditAvatar;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      children: [
        Stack(
          children: [
            UserAvatar(username: user.username, imageUrl: user.image, size: 112, ring: true),
            if (onEditAvatar != null)
              Positioned(
                right: 0,
                bottom: 0,
                child: CircleIconButton(icon: Icons.photo_camera_rounded, size: 38, dark: true, onTap: onEditAvatar),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(child: Text(user.displayName, style: t.headlineSmall, overflow: TextOverflow.ellipsis)),
            if (user.isAccountVerified == true) ...[
              const SizedBox(width: 6),
              const Icon(Icons.verified_rounded, color: AppColors.blue, size: 20),
            ],
          ],
        ),
        Text('@${user.username}', style: t.bodyMedium),
      ],
    );
  }
}

/// Griglia 3 colonne di anteprime dei post.
class PostGrid extends StatelessWidget {
  const PostGrid({super.key, required this.posts});

  final List<Post> posts;

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(child: Text(tr('Ancora nessun post'), style: TextStyle(color: AppColors.muted))),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: posts.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemBuilder: (_, i) {
        final p = posts[i];
        return GestureDetector(
          onTap: () => context.push('/posts/${p.id}'),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm + 2),
            child: Stack(
              fit: StackFit.expand,
              children: [
                AppImage.supports(p.image)
                    ? AppImage(p.image!, fallback: _TextTile(text: p.content))
                    : _TextTile(text: p.content),
                if (p.numLikes > 0)
                  Positioned(
                    left: 6,
                    bottom: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(20)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.favorite_rounded, size: 12, color: Colors.white),
                          const SizedBox(width: 3),
                          Text('${p.numLikes}',
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TextTile extends StatelessWidget {
  const _TextTile({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
        color: AppColors.lilacSoft,
        padding: const EdgeInsets.all(8),
        alignment: Alignment.center,
        child: Text(text, maxLines: 4, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
      );
}
