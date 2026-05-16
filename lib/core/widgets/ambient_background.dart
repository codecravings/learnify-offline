import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/platform.dart';

/// A static refraction surface for glass to sit on top of. Three colored
/// radial blobs (cyan / purple / magenta) drifting on a slow loop. Without
/// something colorful behind it, BackdropFilter blur is invisible.
///
/// Cheap: blurs are baked into [RadialGradient]s, no real-time filter cost.
/// The drift uses a single AnimationController so it doesn't compound on
/// long-lived screens.
class AmbientBackground extends StatefulWidget {
  const AmbientBackground({
    super.key,
    this.child,
    this.intensity = 1.0,
  });

  final Widget? child;

  /// 0..1 multiplier on blob opacity. Drop to ~0.6 on small screens where
  /// the blobs otherwise overpower text.
  final double intensity;

  @override
  State<AmbientBackground> createState() => _AmbientBackgroundState();
}

class _AmbientBackgroundState extends State<AmbientBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      // Long enough that the motion reads as ambient, not animated.
      duration: const Duration(seconds: 22),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = AppTheme.isDark(context);
    return Stack(
      children: [
        // Base gradient — covers every gap between blobs.
        Container(
          decoration: BoxDecoration(
            gradient: dark
                ? AppTheme.backgroundGradient
                : AppTheme.lightBackgroundGradient,
          ),
        ),
        // Blobs.
        AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            final t = _ctrl.value * 2 * math.pi;
            return CustomPaint(
              size: Size.infinite,
              painter: _BlobsPainter(
                t: t,
                dark: dark,
                intensity: widget.intensity,
              ),
            );
          },
        ),
        if (widget.child != null) widget.child!,
      ],
    );
  }
}

class _BlobsPainter extends CustomPainter {
  _BlobsPainter({
    required this.t,
    required this.dark,
    required this.intensity,
  });

  final double t;
  final bool dark;
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Three blobs. Each gets its own slow orbital path.
    final blobs = <_Blob>[
      _Blob(
        center: Offset(
          w * (0.20 + 0.05 * math.sin(t)),
          h * (0.22 + 0.04 * math.cos(t * 0.8)),
        ),
        radius: w * 0.55,
        color: dark ? AppTheme.accentCyan : AppTheme.accentCyan,
      ),
      _Blob(
        center: Offset(
          w * (0.85 + 0.06 * math.cos(t * 1.1)),
          h * (0.42 + 0.05 * math.sin(t * 0.9)),
        ),
        radius: w * 0.55,
        color: dark ? AppTheme.accentPurple : AppTheme.accentPurple,
      ),
      _Blob(
        center: Offset(
          w * (0.50 + 0.07 * math.sin(t * 0.7)),
          h * (0.85 + 0.04 * math.cos(t * 0.6)),
        ),
        radius: w * 0.55,
        color: dark ? AppTheme.accentMagenta : AppTheme.accentMagenta,
      ),
    ];

    final maskFilter =
        MaskFilter.blur(BlurStyle.normal, PlatformX.isIOS ? 80 : 60);

    for (final b in blobs) {
      final paint = Paint()
        ..maskFilter = maskFilter
        ..color = b.color.withAlpha(((dark ? 60 : 38) * intensity).round());
      canvas.drawCircle(b.center, b.radius * 0.85, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BlobsPainter old) =>
      old.t != t || old.dark != dark || old.intensity != intensity;
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
