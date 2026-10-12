import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/backgrounds.dart';
import '../../core/widgets/ui.dart';
import '../../data/providers.dart';
import '../../models/social.dart';
import '../../models/user.dart';
import '../auth/session.dart';
import 'friends_screen.dart';

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
              const TopBar(title: ''),
              Expanded(
                child: AsyncView<User>(
                  value: user,
                  onRetry: () => ref.invalidate(userProfileProvider(username)),
                  data: (u) => ListView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    children: [
                      ProfileHeader(user: u),
                      const SizedBox(height: 20),
                      if (isFriend)
                        const Center(child: Tag('Siete amici', color: AppColors.mint, icon: Icons.check_rounded))
                      else
                        AddFriendButton(username: u.username, large: true),
                      const SizedBox(height: 24),
                      const SectionHeader('Post'),
                      AsyncView<List<Post>>(
                        value: posts,
                        onRetry: () => ref.invalidate(userPostsProvider(username)),
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
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: Text('Ancora nessun post', style: TextStyle(color: AppColors.muted))),
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
            child: p.image != null && p.image!.startsWith('http')
                ? Image.network(
                    p.image!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _TextTile(text: p.content),
                  )
                : _TextTile(text: p.content),
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
