import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/ui.dart';
import '../../models/user.dart';
import '../../models/workout.dart';
import 'share_links.dart';

// Card riepilogo da condividere come immagine (storie, chat, feed). Hanno
// dimensioni fisse 4:5 così l'immagine esportata è sempre uguale, a
// prescindere dallo schermo: 340×425 punti, salvati a 3× = 1020×1275 px.

const shareCardSize = Size(340, 425);

/// Scheda: nome, autore, numeri e i primi esercizi.
class WorkoutShareCard extends StatelessWidget {
  const WorkoutShareCard({super.key, required this.workout});

  final Workout workout;

  @override
  Widget build(BuildContext context) {
    final w = workout;
    final sets = w.exercises.fold<int>(0, (a, e) => a + e.sets);
    final minutes = w.exercises.fold<int>(0, (a, e) => a + e.sets * (45 + e.restSeconds)) ~/ 60;
    const maxRows = 5;
    final shown = w.exercises.take(maxRows).toList();
    return _CardFrame(
      label: 'Scheda',
      icon: Icons.fitness_center_rounded,
      footer: ShareLinks.workout(w.id),
      children: [
        Text(w.name, style: _title, maxLines: 2, overflow: TextOverflow.ellipsis),
        if (w.user != null) Text('di @${w.user!.username}', style: _subtitle),
        const SizedBox(height: 14),
        Row(
          children: [
            _Stat(value: '${w.exercises.length}', label: 'esercizi'),
            _Stat(value: '$sets', label: 'serie'),
            _Stat(value: minutes > 0 ? '~$minutes' : '—', label: 'minuti'),
          ],
        ),
        const SizedBox(height: 14),
        for (final e in shown)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    e.exerciseName ?? 'Esercizio',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: AppColors.ink),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(e.summary, style: const TextStyle(fontSize: 13, color: AppColors.inkSoft)),
              ],
            ),
          ),
        if (w.exercises.length > maxRows)
          Text('+ altri ${w.exercises.length - maxRows}', style: const TextStyle(fontSize: 13, color: AppColors.muted)),
      ],
    );
  }
}

/// Sessione completata: quando, quanto è durata, che scheda.
class SessionShareCard extends StatelessWidget {
  const SessionShareCard({super.key, required this.session, this.workout, this.username});

  final WorkoutHistory session;

  /// La scheda della sessione, se la conosciamo (nome ed esercizi).
  final Workout? workout;
  final String? username;

  @override
  Widget build(BuildContext context) {
    final w = workout;
    final sets = w?.exercises.fold<int>(0, (a, e) => a + e.sets) ?? 0;
    return _CardFrame(
      label: 'Completato',
      icon: Icons.emoji_events_rounded,
      footer: w != null ? ShareLinks.workout(w.id) : ShareLinks.webBaseUrl.replaceFirst(RegExp('^https?://'), ''),
      children: [
        Text(formatDate(session.startedAt), style: _subtitle),
        const SizedBox(height: 6),
        Text(w?.name ?? 'Allenamento', style: _title, maxLines: 1, overflow: TextOverflow.ellipsis),
        if (username != null) Text('@$username', style: _subtitle),
        const Spacer(),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            formatDuration(session.duration),
            style: const TextStyle(fontSize: 44, height: 1, fontWeight: FontWeight.w800, color: AppColors.ink),
          ),
        ),
        const Text('di allenamento', style: TextStyle(color: AppColors.inkSoft, fontSize: 14)),
        const SizedBox(height: 16),
        Row(
          children: [
            if (w != null) ...[
              _Stat(value: '${w.exercises.length}', label: 'esercizi'),
              _Stat(value: '$sets', label: 'serie'),
            ],
            if (session.groupId != null) const _Stat(value: '👥', label: 'di gruppo'),
          ],
        ),
        if (session.notes?.isNotEmpty == true) ...[
          const SizedBox(height: 12),
          Text(
            '"${session.notes}"',
            style: const TextStyle(fontStyle: FontStyle.italic, color: AppColors.inkSoft, fontSize: 13),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        const Spacer(),
      ],
    );
  }
}

/// Profilo: foto, nome e i numeri principali.
class ProfileShareCard extends StatelessWidget {
  const ProfileShareCard({super.key, required this.user, this.sessions, this.trained, this.friends});

  final User user;
  final int? sessions;
  final Duration? trained;
  final int? friends;

  @override
  Widget build(BuildContext context) {
    return _CardFrame(
      label: 'Allenati con me',
      icon: Icons.waving_hand_rounded,
      footer: ShareLinks.profile(user.username),
      children: [
        const Spacer(),
        Center(
          child: UserAvatar(username: user.username, imageUrl: user.image, size: 112, ring: true),
        ),
        const SizedBox(height: 14),
        Center(
          child: Text(user.displayName, style: _title, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        Center(child: Text('@${user.username}', style: _subtitle)),
        const SizedBox(height: 18),
        Row(
          children: [
            if (sessions != null) _Stat(value: '$sessions', label: 'sessioni', center: true),
            if (trained != null)
              _Stat(
                value: trained!.inHours > 0 ? '${trained!.inHours} h' : formatDuration(trained),
                label: 'allenato',
                center: true,
              ),
            if (friends != null) _Stat(value: '$friends', label: 'amici', center: true),
          ],
        ),
        const Spacer(),
      ],
    );
  }
}

const _title = TextStyle(fontSize: 26, height: 1.15, fontWeight: FontWeight.w800, color: AppColors.ink);
const _subtitle = TextStyle(fontSize: 14, color: AppColors.inkSoft, fontWeight: FontWeight.w500);

class _CardFrame extends StatelessWidget {
  const _CardFrame({required this.label, required this.icon, required this.footer, required this.children});

  final String label;
  final IconData icon;
  final String footer;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SizedBox.fromSize(
      size: shareCardSize,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.skyTop, AppColors.skyMid, Colors.white],
            stops: [0, 0.5, 1],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -60,
              right: -50,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.lilac.withValues(alpha: 0.18)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ShaderMask(
                        shaderCallback: AppColors.brandGradient.createShader,
                        child: const Text(
                          'RepBirds',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Tag(label, icon: icon, color: AppColors.blue),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    footer.replaceFirst(RegExp('^https?://'), ''),
                    style: const TextStyle(fontSize: 11, color: AppColors.muted, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, this.center = false});

  final String value;
  final String label;
  final bool center;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: center ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 28,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.ink),
                maxLines: 1,
              ),
            ),
          ),
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        ],
      ),
    );
  }
}
