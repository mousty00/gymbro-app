import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Sfondo "cielo" azzurro → lilla che sfuma nel grigio chiaro, con macchie morbide.
class SkyBackground extends StatelessWidget {
  const SkyBackground({super.key, required this.child, this.height = 420, this.tint});

  final Widget child;
  final double height;
  /// Colore in cima al gradiente; di default [AppColors.skyTop].
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    // Nel tema scuro niente gradiente né macchie: sfondo a tinta unita.
    if (AppColors.isDark) return ColoredBox(color: AppColors.bg, child: child);
    return Stack(
      children: [
        Positioned.fill(child: ColoredBox(color: AppColors.bg)),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: height,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [tint ?? AppColors.skyTop, AppColors.skyMid.withValues(alpha: 0.6), AppColors.bg],
                stops: const [0, 0.55, 1],
              ),
            ),
          ),
        ),
        Positioned(
          top: -80,
          right: -60,
          child: _Blob(color: AppColors.lilac.withValues(alpha: 0.18), size: 260),
        ),
        Positioned(
          top: 120,
          left: -90,
          child: _Blob(color: AppColors.blue.withValues(alpha: 0.12), size: 220),
        ),
        Positioned.fill(child: child),
      ],
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
        ),
      ),
    );
  }
}

/// Sfera iridescente (rosa / azzurro / lilla), elemento decorativo del brand.
class GlassOrb extends StatelessWidget {
  const GlassOrb({super.key, this.size = 120});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size * 1.6,
      height: size * 1.6,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // alone
          Container(
            width: size * 1.6,
            height: size * 1.6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                AppColors.pink.withValues(alpha: 0.35),
                AppColors.lilac.withValues(alpha: 0.12),
                Colors.transparent,
              ]),
            ),
          ),
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const SweepGradient(
                colors: [
                  Color(0xFFB9D3FF),
                  Color(0xFFF5B8EE),
                  Color(0xFFC9B6FF),
                  Color(0xFF9FE7F5),
                  Color(0xFFB9D3FF),
                ],
                transform: GradientRotation(math.pi / 5),
              ),
              boxShadow: [
                BoxShadow(color: AppColors.lilac.withValues(alpha: 0.35), blurRadius: 40, offset: const Offset(0, 16)),
              ],
            ),
          ),
          // riflesso
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: const Alignment(-0.35, -0.45),
                radius: 0.7,
                colors: [Colors.white.withValues(alpha: 0.95), Colors.white.withValues(alpha: 0)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
