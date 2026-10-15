import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/backgrounds.dart';
import '../../core/widgets/skeleton.dart';
import '../../core/widgets/ui.dart';
import '../../data/providers.dart';
import '../../data/running_repository.dart';
import '../../models/running.dart';
import '../auth/session.dart';
import 'geo.dart';
import '../share/share_actions.dart';
import 'route_map.dart';

class RouteDetailScreen extends ConsumerStatefulWidget {
  const RouteDetailScreen({super.key, required this.routeId});

  final String routeId;

  @override
  ConsumerState<RouteDetailScreen> createState() => _RouteDetailScreenState();
}

class _RouteDetailScreenState extends ConsumerState<RouteDetailScreen> {
  bool _copying = false;

  Future<void> _copy(RunRoute route) async {
    setState(() => _copying = true);
    try {
      final copy = await ref.read(runningRepositoryProvider).copyRoute(route.id);
      ref.invalidate(myRoutesProvider);
      if (!mounted) return;
      showMessage(context, 'Salvato nei tuoi percorsi');
      context.pushReplacement('/running/route/${copy.id}');
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _copying = false);
    }
  }

  Future<void> _delete(RunRoute route) async {
    final ok = await confirm(
      context,
      title: 'Eliminare "${route.name}"?',
      message: 'Vengono eliminate anche le corse di gruppo organizzate su questo percorso. Le corse già registrate restano.',
      ok: 'Elimina',
      destructive: true,
    );
    if (!ok) return;
    try {
      await ref.read(runningRepositoryProvider).deleteRoute(route.id);
      ref.invalidate(myRoutesProvider);
      ref.invalidate(runEventsProvider);
      if (mounted) context.pop();
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider).username;
    final value = ref.watch(runRouteProvider(widget.routeId));
    return Scaffold(
      body: SkyBackground(
        child: SafeArea(
          child: AsyncView<RunRoute>(
            value: value,
            onRetry: () => ref.invalidate(runRouteProvider(widget.routeId)),
            loading: const SkeletonDetail(),
            data: (route) {
              final mine = route.isMine(me);
              return Column(
                children: [
                  TopBar(
                    title: '',
                    actions: [
                      CircleIconButton(
                        icon: Icons.ios_share_rounded,
                        size: 44,
                        tooltip: 'Condividi',
                        onTap: () => shareRoute(context, route,
                            loadGpx: () => ref.read(runningRepositoryProvider).routeGpx(route.id)),
                      ),
                      if (mine) ...[
                        CircleIconButton(
                          icon: Icons.edit_outlined,
                          size: 44,
                          tooltip: 'Modifica',
                          onTap: () => context.push('/running/route/${route.id}/edit'),
                        ),
                        CircleIconButton(icon: Icons.delete_outline_rounded, size: 44, tooltip: 'Elimina', onTap: () => _delete(route)),
                      ],
                    ],
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                      children: [
                        RouteMap(route: route.points, height: 300),
                        const SizedBox(height: 18),
                        Text(route.name, style: Theme.of(context).textTheme.displaySmall),
                        const SizedBox(height: 6),
                        Text(
                          route.originalAuthor != null
                              ? 'Disegnato da @${route.originalAuthor!.username}'
                              : mine
                                  ? (route.isPublic ? 'Pubblico: i tuoi amici lo vedono' : 'Privato: lo vedi solo tu')
                                  : 'Di @${route.owner.username}',
                          style: TextStyle(color: AppColors.inkSoft),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            _Metric(label: 'Distanza', value: formatDistance(route.distanceM)),
                            _Metric(label: 'Dislivello', value: route.elevationGainM == null ? '–' : '+${route.elevationGainM} m'),
                            _Metric(label: 'Tempo', value: estimateTime(route.distanceM)),
                          ],
                        ),
                        if (route.description != null && route.description!.isNotEmpty) ...[
                          const SizedBox(height: 18),
                          Text(route.description!, style: Theme.of(context).textTheme.bodyLarge),
                        ],
                        const SizedBox(height: 22),
                        if (mine)
                          OutlinedButton.icon(
                            onPressed: () => context.push('/running/event/new?route=${route.id}'),
                            icon: const Icon(Icons.groups_rounded),
                            label: const Text('Organizza una corsa di gruppo'),
                          )
                        else if (route.isPublic)
                          OutlinedButton.icon(
                            onPressed: _copying ? null : () => _copy(route),
                            icon: const Icon(Icons.bookmark_add_outlined),
                            label: const Text('Salva nei miei percorsi'),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: PillActionButton(
                      label: 'Corri questo percorso',
                      icon: Icons.directions_run_rounded,
                      onPressed: () => context.push('/running/run?route=${route.id}'),
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

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: Theme.of(context).textTheme.titleLarge),
            Text(label, style: TextStyle(color: AppColors.muted, fontSize: 13)),
          ],
        ),
      );
}
