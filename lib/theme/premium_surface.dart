import 'package:flutter/material.dart';

import 'app_design_tokens.dart';

class PremiumSurface extends StatelessWidget {
  const PremiumSurface({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.margin = EdgeInsets.zero,
    this.color,
    this.borderColor,
    this.radius = AppRadius.card,
    this.elevation = AppElevation.flat,
    this.selected = false,
    this.glass = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Color? color;
  final Color? borderColor;
  final double radius;
  final double elevation;
  final bool selected;
  final bool glass;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isLight = theme.brightness == Brightness.light;
    final baseColor =
        color ??
        (isLight
            ? colorScheme.surfaceContainerLow
            : colorScheme.surfaceContainerLow);
    final surfaceColor = selected
        ? Color.alphaBlend(
            colorScheme.primary.withValues(alpha: isLight ? 0.08 : 0.16),
            baseColor,
          )
        : glass
        ? baseColor.withValues(
            alpha: isLight
                ? AppGlass.lightSurfaceOpacity
                : AppGlass.darkSurfaceOpacity,
          )
        : baseColor;
    final resolvedBorderColor =
        borderColor ??
        (selected
            ? colorScheme.primary.withValues(alpha: isLight ? 0.38 : 0.48)
            : colorScheme.outlineVariant.withValues(
                alpha: isLight
                    ? AppGlass.lightBorderOpacity
                    : AppGlass.darkBorderOpacity,
              ));

    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: resolvedBorderColor),
        boxShadow: elevation <= 0
            ? null
            : [
                BoxShadow(
                  color: colorScheme.shadow.withValues(
                    alpha: isLight ? 0.055 : 0.14,
                  ),
                  blurRadius: elevation * 8,
                  offset: Offset(0, elevation * 2),
                ),
              ],
      ),
      child: child,
    );
  }
}
