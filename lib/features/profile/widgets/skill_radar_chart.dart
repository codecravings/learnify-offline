import 'dart:math';

import 'package:flutter/material.dart';

/// Animated radar / spider chart showing skill ratings per subject.
///
/// Draws a neon-outlined polygon with a semi-transparent fill, axis labels,
/// and animates drawing on first appearance.
class SkillRadarChart extends StatefulWidget {
  /// Map of subject name to a value between 0.0 and 1.0.
  final Map<String, double> skills;
  final double size;
  final Color lineColor;
  final Color fillColor;
  final Duration animationDuration;

  const SkillRadarChart({
    super.key,
    required this.skills,
    this.size = 220,
    this.lineColor = const Color(0xFF3B82F6),
    this.fillColor = const Color(0xFF3B82F6),
    this.animationDuration = const Duration(milliseconds: 1200),
  });

  @override
  State<SkillRadarChart> createState() => _SkillRadarChartState();
}

class _SkillRadarChartState extends State<SkillRadarChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entries = widget.skills.entries.toList();
    if (entries.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      width: widget.size + 80,
      height: widget.size + 80,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, _) {
          return CustomPaint(
            size: Size(widget.size + 80, widget.size + 80),
            painter: _RadarChartPainter(
              entries: entries,
              progress: _animation.value,
              lineColor: widget.lineColor,
              fillColor: widget.fillColor,
              chartRadius: widget.size / 2,
            ),
          );
        },
      ),
    );
  }
}

class _RadarChartPainter extends CustomPainter {
  final List<MapEntry<String, double>> entries;
  final double progress;
  final Color lineColor;
  final Color fillColor;
  final double chartRadius;

  _RadarChartPainter({
    required this.entries,
    required this.progress,
    required this.lineColor,
    required this.fillColor,
    required this.chartRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final n = entries.length;
    final angleStep = (2 * pi) / n;
    // Start from top (-pi/2)
    const startAngle = -pi / 2;

    // --- Draw concentric guide rings ---
    final guidePaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.white.withOpacity(0.07)
      ..strokeWidth = 1;

    for (int ring = 1; ring <= 4; ring++) {
      final r = chartRadius * (ring / 4);
      final guidePath = Path();
      for (int i = 0; i <= n; i++) {
        final angle = startAngle + angleStep * (i % n);
        final p = Offset(center.dx + r * cos(angle), center.dy + r * sin(angle));
        if (i == 0) {
          guidePath.moveTo(p.dx, p.dy);
        } else {
          guidePath.lineTo(p.dx, p.dy);
        }
      }
      canvas.drawPath(guidePath, guidePaint);
    }

    // --- Draw axis lines ---
    final axisPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.white.withOpacity(0.08)
      ..strokeWidth = 1;

    for (int i = 0; i < n; i++) {
      final angle = startAngle + angleStep * i;
      final end = Offset(
        center.dx + chartRadius * cos(angle),
        center.dy + chartRadius * sin(angle),
      );
      canvas.drawLine(center, end, axisPaint);
    }

    // --- Draw data polygon ---
    final dataPath = Path();
    final points = <Offset>[];

    for (int i = 0; i < n; i++) {
      final value = entries[i].value.clamp(0.0, 1.0) * progress;
      final angle = startAngle + angleStep * i;
      final r = chartRadius * value;
      final p = Offset(center.dx + r * cos(angle), center.dy + r * sin(angle));
      points.add(p);
      if (i == 0) {
        dataPath.moveTo(p.dx, p.dy);
      } else {
        dataPath.lineTo(p.dx, p.dy);
      }
    }
    dataPath.close();

    // Fill
    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = fillColor.withOpacity(0.12 * progress);
    canvas.drawPath(dataPath, fillPaint);

    // Stroke with glow
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = lineColor.withOpacity(0.25 * progress)
      ..strokeWidth = 6
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawPath(dataPath, glowPaint);

    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = lineColor.withOpacity(progress)
      ..strokeWidth = 2
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(dataPath, strokePaint);

    // --- Draw data points ---
    for (final p in points) {
      canvas.drawCircle(
        p,
        4,
        Paint()
          ..color = lineColor.withOpacity(0.3 * progress)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      canvas.drawCircle(
        p,
        3,
        Paint()..color = lineColor.withOpacity(progress),
      );
      canvas.drawCircle(
        p,
        1.5,
        Paint()..color = Colors.white.withOpacity(0.9 * progress),
      );
    }

    // --- Draw labels ---
    for (int i = 0; i < n; i++) {
      final angle = startAngle + angleStep * i;
      final labelR = chartRadius + 24;
      final lx = center.dx + labelR * cos(angle);
      final ly = center.dy + labelR * sin(angle);

      final tp = TextPainter(
        text: TextSpan(
          text: entries[i].key,
          style: TextStyle(
            color: Colors.white.withOpacity(0.55 * progress),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      // Center the label around the computed point
      tp.paint(canvas, Offset(lx - tp.width / 2, ly - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _RadarChartPainter old) =>
      old.progress != progress;
}
