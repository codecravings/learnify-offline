import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A refraction surface for frosted glass to sit on top of. Without
/// something colorful behind it, BackdropFilter blur is invisible.
///
/// This first version only lays down the base theme gradient. Blob
/// painter + drift animation follow in later commits.
class AmbientBackground extends StatelessWidget {
  const AmbientBackground({
    super.key,
    this.child,
  });

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final dark = AppTheme.isDark(context);
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: dark
                ? AppTheme.backgroundGradient
                : AppTheme.lightBackgroundGradient,
          ),
        ),
        if (child != null) child!,
      ],
    );
  }
}
