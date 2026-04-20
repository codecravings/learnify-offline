import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Renders a field of slowly drifting particles (dots/stars) behind content.
///
/// Uses a single [AnimationController] driving a [CustomPainter] for
/// a smooth, continuous, atmospheric effect.
class ParticleBackground extends StatefulWidget {
  const ParticleBackground({
    super.key,
    this.particleCount = 80,
    this.particleColor = AppTheme.accentCyan,
    this.maxRadius = 2.0,
    this.speed = 0.3,
  });

  /// Number of floating particles.
  final int particleCount;

  /// Base color for particles (alpha is varied per particle).
  final Color particleColor;

  /// Maximum dot radius.
  final double maxRadius;

  /// Movement speed multiplier (0..1 range recommended).
  final double speed;

  @override
  State<ParticleBackground> createState() => _ParticleBackgroundState();
}

class _ParticleBackgroundState extends State<ParticleBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat();

    final rng = Random(42);
    _particles = List.generate(widget.particleCount, (_) {
      return _Particle(
        x: rng.nextDouble(),
        y: rng.nextDouble(),
        radius: 0.3 + rng.nextDouble() * widget.maxRadius,
        alpha: 0.1 + rng.nextDouble() * 0.5,
        dx: (rng.nextDouble() - 0.5) * widget.speed,
        dy: (rng.nextDouble() - 0.5) * widget.speed,
        twinklePhase: rng.nextDouble() * 2 * pi,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _ParticlePainter(
              particles: _particles,
              progress: _controller.value,
              color: widget.particleColor,
            ),
          );
        },
      ),
    );
  }
}

// ─── Data ────────────────────────────────────────────────────────────────────

class _Particle {
  _Particle({
    required this.x,
    required this.y,
    required this.radius,
    required this.alpha,
    required this.dx,
    required this.dy,
    required this.twinklePhase,
  });

  /// Normalised position [0..1].
  final double x;
  final double y;

  /// Dot radius.
  final double radius;

  /// Base alpha [0..1].
  final double alpha;

  /// Normalised velocity per full animation cycle.
  final double dx;
  final double dy;

  /// Phase offset for the twinkle sine wave.
  final double twinklePhase;
}

// ─── Painter ─────────────────────────────────────────────────────────────────

class _ParticlePainter extends CustomPainter {
  _ParticlePainter({
    required this.particles,
    required this.progress,
    required this.color,
  });

  final List<_Particle> particles;
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (final p in particles) {
      // Position wraps around.
      final px = ((p.x + p.dx * progress) % 1.0) * size.width;
      final py = ((p.y + p.dy * progress) % 1.0) * size.height;

      // Twinkle effect.
      final twinkle =
          (sin(progress * 2 * pi * 3 + p.twinklePhase) + 1) / 2;
      final alpha = (p.alpha * (0.4 + 0.6 * twinkle)).clamp(0.0, 1.0);

      paint.color = color.withAlpha((alpha * 255).round());
      canvas.drawCircle(Offset(px, py), p.radius, paint);

      // Subtle glow on larger particles.
      if (p.radius > 1.2) {
        paint.color = color.withAlpha((alpha * 60).round());
        canvas.drawCircle(Offset(px, py), p.radius * 2.5, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter old) => true;
}
