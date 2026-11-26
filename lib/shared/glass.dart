import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'theme.dart';

/// Flutter glass for compact controls. High contrast uses a solid material.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.radius = 28,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final opaque =
        MediaQuery.highContrastOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    final corners = BorderRadius.circular(radius);
    return ClipRRect(
      borderRadius: corners,
      child: BackdropFilter(
        enabled: !opaque,
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: corners,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colors.surface.withValues(alpha: opaque ? 1 : .88),
                colors.canvas.withValues(alpha: opaque ? 1 : .74),
              ],
            ),
            border: colors.isDark && !opaque
                ? null
                : Border.all(color: colors.outline.withValues(alpha: .65)),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

TextStyle glassTitle(BuildContext context) => TextStyle(
  fontFamily: Theme.of(context).textTheme.bodyLarge?.fontFamily,
  color: context.colors.text,
  fontSize: 42,
  height: 1.05,
  letterSpacing: -2.2,
  fontWeight: FontWeight.w700,
);
