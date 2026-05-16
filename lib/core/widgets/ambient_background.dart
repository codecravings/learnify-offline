import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A refraction surface for frosted glass to sit on top of. Without
/// something colorful behind it, BackdropFilter blur is invisible.
///
/// Three colored radial blobs (cyan / purple / magenta) painted with
/// MaskFilter.blur — baked, not real-time, so the surface is cheap.
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
        CustomPaint(
          size: Size.infinite,
          painter: _BlobsPainter(dark: dark),
        ),
        if (child != null) child!,
      ],
    );
  }
}

class _BlobsPainter extends CustomPainter {
  _BlobsPainter({required this.dark});

  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final blobs = <_Blob>[
      _Blob(
        center: Offset(w * 0.20, h * 0.22),
        radius: w * 0.55,
        color: AppTheme.accentCyan,
      ),
      _Blob(
        center: Offset(w * 0.85, h * 0.42),
        radius: w * 0.55,
        color: AppTheme.accentPurple,
      ),
      _Blob(
        center: Offset(w * 0.50, h * 0.85),
        radius: w * 0.55,
        color: AppTheme.accentMagenta,
      ),
    ];

    const maskFilter = MaskFilter.blur(BlurStyle.normal, 60);

    for (final b in blobs) {
      final paint = Paint()
        ..maskFilter = maskFilter
        ..color = b.color.withAlpha(dark ? 60 : 38);
      canvas.drawCircle(b.center, b.radius * 0.85, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BlobsPainter old) => old.dark != dark;
}

class _Blob {
  const _Blob({
    required this.center,
    required this.radius,
    required this.color,
  });
  final Offset center;
  final double radius;
  final Color color;
}
