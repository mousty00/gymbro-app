import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/backgrounds.dart';
import '../../core/widgets/ui.dart';
import '../../data/providers.dart';
import '../../models/social.dart';
import '../shell/app_shell.dart';
import '../auth/session.dart';
import '../shell/sections.dart';
import 'post_card.dart';
import '../../core/widgets/skeleton.dart';

/// Community: post degli amici ([explore] false) o di tutti.
class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key, required this.explore, required this.title});

  final bool explore;

  /// Il selettore di sezione della tab Community.
  final Widget title;

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  bool get _friends => !widget.explore;

  FutureProvider<List<Post>> get _provider => _friends ? friendsPostsProvider : explorePostsProvider;

  @override
  Widget build(BuildContext context) {
    final posts = ref.watch(_provider);
    return Scaffold(
      body: SkyBackground(
        child: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            onRefresh: () => ref.refresh(_provider.future),
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
                            Expanded(child: widget.title),
                            const SizedBox(width: 10),
                            CircleIconButton(
                              icon: Icons.add_rounded,
                              dark: true,
                              tooltip: tr('Nuovo post'),
                              onTap: () => context.push('/posts/new'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                      ],
                    ),
                  ),
                ),
                AsyncView<List<Post>>(
                  value: posts,
                  onRetry: () => ref.invalidate(_provider),
                  sliver: true,
                  loading: const SkeletonList(
                    item: SkeletonPost(),
                    count: 2,
                    spacing: 14,
                    padding: EdgeInsets.symmetric(horizontal: 20),
                  ),
                  data: (all) {
                    // in Esplora solo gli altri: i miei post stanno nel profilo
                    final me = ref.watch(currentUserProvider).username;
                    final list = _friends ? all : all.where((p) => p.user.username != me).toList();
                    if (list.isEmpty) {
                      return SliverToBoxAdapter(
                        child: EmptyState(
                          icon: Icons.dynamic_feed_rounded,
                          title: _friends ? tr('Ancora nessun post') : tr('Nessun post per ora'),
                          message: _friends
                              ? tr('Quando i tuoi amici pubblicano un allenamento lo vedrai qui.')
                              : tr('Sii il primo a condividere un allenamento.'),
                          action: _friends ? tr('Trova amici') : tr('Pubblica un post'),
                          onAction: () => _friends
                              ? ref.read(communitySectionProvider.notifier).show(CommunitySection.friends)
                              : context.push('/posts/new'),
                        ),
                      );
                    }
                    return SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, navBarClearance),
                      sliver: SliverList.separated(
                        itemCount: list.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 14),
                        itemBuilder: (_, i) => PostCard(post: list[i]),
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

/// Selettore a pillola con due o più opzioni.
class SegmentedPill extends StatelessWidget {
  const SegmentedPill({super.key, required this.options, required this.index, required this.onChanged});

  final List<String> options;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: AppColors.card.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(40),
        boxShadow: AppShadows.soft,
      ),
      child: Row(
        children: [
          for (var i = 0; i < options.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: i == index ? AppColors.ink : Colors.transparent,
                    borderRadius: BorderRadius.circular(40),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    options[i],
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: i == index ? AppColors.onInk : AppColors.inkSoft,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
