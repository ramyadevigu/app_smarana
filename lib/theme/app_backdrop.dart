import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppBackdrop extends StatelessWidget {
  const AppBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(
          color: isLight ? AppColors.lightBackground : AppColors.deepBlack,
        ),
        Positioned(
          top: -220,
          right: -150,
          child: IgnorePointer(
            child: _AmbientGlow(
              color: colorScheme.primary,
              opacity: isLight ? 0.09 : 0.12,
              size: 470,
            ),
          ),
        ),
        Positioned(
          bottom: -270,
          left: -210,
          child: IgnorePointer(
            child: _AmbientGlow(
              color: colorScheme.tertiary,
              opacity: isLight ? 0.045 : 0.07,
              size: 500,
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _AmbientGlow extends StatelessWidget {
  const _AmbientGlow({
    required this.color,
    required this.opacity,
    required this.size,
  });

  final Color color;
  final double opacity;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: opacity),
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}
