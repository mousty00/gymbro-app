import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'rep_bird.dart';

/// Sfondo "cielo" azzurro → lilla che sfuma nel grigio chiaro (tema chiaro);
/// a tinta unita nel tema scuro.
class SkyBackground extends StatelessWidget {
  const SkyBackground({super.key, required this.child, this.height = 420, this.tint});

  final Widget child;
  final double height;
  /// Colore in cima al gradiente; di default [AppColors.skyTop].
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    // Nel tema scuro niente gradiente: sfondo a tinta unita.
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
        Positioned.fill(child: child),
      ],
    );
  }
}

/// Il logo dell'app: l'uccellino bianco su un cerchio del colore del brand.
/// Con [animate] fa vedere il bicipite e sbatte l'occhio ogni tanto.
class BrandMark extends StatefulWidget {
  const BrandMark({super.key, this.size = 120, this.animate = false});

  final double size;
  final bool animate;

  @override
  State<BrandMark> createState() => _BrandMarkState();
}

class _BrandMarkState extends State<BrandMark> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (widget.animate && !still) {
      if (!_c.isAnimating) _c.repeat();
    } else {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mark = AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final v = _c.value;
        // due flessioni all'inizio del giro, un occhiolino a metà
        final flex = v < 0.3 ? math.sin(v / 0.3 * math.pi * 2).abs() : 0.0;
        final blink = v > 0.55 && v < 0.6 ? math.sin((v - 0.55) / 0.05 * math.pi) : 0.0;
        return RepBird(size: widget.size * 0.62, eyeColor: AppColors.brand, flex: flex, blink: blink);
      },
    );
    return Container(
      width: widget.size,
      height: widget.size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.brand,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: AppColors.brand.withValues(alpha: 0.35), blurRadius: widget.size * 0.3, offset: Offset(0, widget.size * 0.1)),
        ],
      ),
      child: mark,
    );
  }
}
