import 'dart:ui';

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Reusable glassmorphism container — adapts to dark/light theme.
class GlassContainer extends StatelessWidget {
  const GlassContainer({
    super.key,
    required this.child,
    this.blur = 10,
    this.borderRadius = 16,
    this.borderColor,
    this.borderWidth = 0.8,
    this.padding,
    this.margin,
    this.onTap,
    this.width,
    this.height,
  });

  final Widget child;
  final double blur;
  final double borderRadius;
  final Color? borderColor;
  final double borderWidth;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final dark = AppTheme.isDark(context);
    final effectiveBorder =
        borderColor ?? (dark ? AppTheme.glassBorder : AppTheme.lightGlassBorder);

    final gradientColors = dark
        ? [Colors.white.withAlpha(26), Colors.white.withAlpha(13)]
        : [Colors.white.withAlpha(200), Colors.white.withAlpha(140)];

    Widget glass = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          width: width,
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: effectiveBorder, width: borderWidth),
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: dark
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withAlpha(8),
                      blurRadius: 12,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: child,
        ),
      ),
    );

    if (margin != null) {
      glass = Padding(padding: margin!, child: glass);
    }

    if (onTap != null) {
      glass = GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: glass,
      );
    }

    return glass;
  }
}
