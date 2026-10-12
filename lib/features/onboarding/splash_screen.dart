import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/backgrounds.dart';
import '../auth/session.dart';

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: SkyBackground(
        height: 900,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const GlassOrb(size: 96),
              Text('GymBro', style: t.headlineMedium),
              const SizedBox(height: 24),
              if (session.hasError) ...[
                Text('Non riesco a contattare il server.', style: t.bodyMedium),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => ref.invalidate(sessionProvider),
                  child: const Text('Riprova'),
                ),
              ] else
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.2, color: AppColors.ink),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
