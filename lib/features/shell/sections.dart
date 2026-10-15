import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n.dart';
import '../exercises/exercises_screen.dart';
import '../feed/feed_screen.dart';
import '../friends/friends_screen.dart';
import '../running/running_screen.dart';
import '../workouts/workouts_screen.dart';
import 'app_shell.dart';

// Le tab con più sezioni (Allenati, Community): un selettore in alto al posto
// del titolo, e ogni sezione resta viva quando cambi (scroll, filtri).
// La sezione scelta sta in un provider, così altre schermate possono aprirla
// (es. Profilo → Amici).

enum TrainSection { workouts, running, exercises }

enum CommunitySection { feed, explore, friends }

class SectionNotifier<T extends Enum> extends Notifier<T> {
  SectionNotifier(this._initial);

  final T _initial;

  @override
  T build() => _initial;

  void show(T section) => state = section;
}

final trainSectionProvider =
    NotifierProvider<SectionNotifier<TrainSection>, TrainSection>(() => SectionNotifier(TrainSection.workouts));

final communitySectionProvider = NotifierProvider<SectionNotifier<CommunitySection>, CommunitySection>(
  () => SectionNotifier(CommunitySection.feed),
);

/// Tab Allenati: Schede · Corsa · Esercizi.
class TrainScreen extends ConsumerWidget {
  const TrainScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final section = ref.watch(trainSectionProvider);
    final title = SegmentedPill(
      options: [tr('Schede'), tr('Corsa'), tr('Esercizi')],
      index: section.index,
      onChanged: (i) => ref.read(trainSectionProvider.notifier).show(TrainSection.values[i]),
    );
    return IndexedStack(
      index: section.index,
      children: [
        WorkoutsScreen(title: title),
        _AboveNavBar(child: RunningScreen(title: title)),
        _AboveNavBar(child: ExercisesScreen(title: title)),
      ],
    );
  }
}

/// Tab Community: Feed (amici) · Esplora · Amici.
class CommunityScreen extends ConsumerWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final section = ref.watch(communitySectionProvider);
    final title = SegmentedPill(
      options: [tr('Feed'), tr('Esplora'), tr('Amici')],
      index: section.index,
      onChanged: (i) => ref.read(communitySectionProvider.notifier).show(CommunitySection.values[i]),
    );
    return IndexedStack(
      index: section.index,
      children: [
        FeedScreen(explore: false, title: title),
        FeedScreen(explore: true, title: title),
        _AboveNavBar(child: FriendsScreen(title: title)),
      ],
    );
  }
}

/// Per le schermate nate a tutto schermo: il loro SafeArea in basso lascia
/// spazio alla barra di navigazione che galleggia sopra.
class _AboveNavBar extends StatelessWidget {
  const _AboveNavBar({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return MediaQuery(
      data: mq.copyWith(padding: mq.padding.copyWith(bottom: navBarClearance)),
      child: child,
    );
  }
}
