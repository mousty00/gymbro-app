import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';

/// Contenitore delle 5 tab con la barra di navigazione flottante a pillola.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  static const _items = [
    (Icons.home_rounded, 'Home'),
    (Icons.dynamic_feed_rounded, 'Community'),
    (Icons.fitness_center_rounded, 'Allenamenti'),
    (Icons.groups_rounded, 'Gruppi'),
    (Icons.person_rounded, 'Profilo'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: shell,
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.only(bottom: 12),
        child: Center(
          heightFactor: 1,
          child: FloatingNavBar(
            index: shell.currentIndex,
            items: _items,
            onTap: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
          ),
        ),
      ),
    );
  }
}

/// Radice di una tab diversa dalla Home: il gesto/tasto indietro di sistema
/// riporta alla Home invece di chiudere l'app.
class BackToHome extends StatelessWidget {
  const BackToHome({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go('/home');
      },
      child: child,
    );
  }
}

class FloatingNavBar extends StatelessWidget {
  const FloatingNavBar({super.key, required this.index, required this.items, required this.onTap});

  final int index;
  final List<(IconData, String)> items;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(48),
        border: Border.all(color: Colors.white),
        boxShadow: AppShadows.float,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < items.length; i++)
            Padding(
              padding: EdgeInsets.only(left: i == 0 ? 0 : 6),
              child: _NavItem(
                icon: items[i].$1,
                label: items[i].$2,
                selected: i == index,
                onTap: () => onTap(i),
              ),
            ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.label, required this.selected, required this.onTap});

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      selected: selected,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          width: selected ? 60 : 52,
          height: selected ? 60 : 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? AppColors.ink : AppColors.bg,
            boxShadow: selected
                ? [BoxShadow(color: AppColors.ink.withValues(alpha: 0.25), blurRadius: 16, offset: const Offset(0, 6))]
                : null,
          ),
          child: Icon(icon, color: selected ? Colors.white : AppColors.inkSoft, size: 24),
        ),
      ),
    );
  }
}

/// Spazio in fondo alle liste delle tab per non finire sotto la barra flottante.
const navBarClearance = 110.0;
