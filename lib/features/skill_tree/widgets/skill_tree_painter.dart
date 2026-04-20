import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../models/skill_node_state.dart';

/// CustomPainter that draws the skill tree: nodes + bezier edge connections.
class SkillTreePainter extends CustomPainter {
  SkillTreePainter({
    required this.nodes,
    required this.isDark,
    this.selectedId,
  });

  final List<SkillNodeState> nodes;
  final bool isDark;
  final String? selectedId;

  // Colors
  Color get _lockedColor => isDark ? const Color(0xFF4B5563) : const Color(0xFF9CA3AF);
  Color get _availableColor => const Color(0xFF8B5CF6); // Purple for ready-to-start
  Color get _progressColor => const Color(0xFF3B82F6);
  Color get _masteredColor => const Color(0xFF22C55E);
  Color get _edgeDefault => isDark ? const Color(0xFF374151) : const Color(0xFFD1D5DB);

  @override
  void paint(Canvas canvas, Size size) {
    // Build lookup
    final nodeMap = {for (final n in nodes) n.id: n};

    // Draw edges first (behind nodes)
    for (final node in nodes) {
      for (final preId in node.prerequisiteIds) {
        final pre = nodeMap[preId];
        if (pre == null) continue;
        _drawEdge(canvas, pre, node);
      }
    }

    // Draw nodes
    for (final node in nodes) {
      _drawNode(canvas, node, node.id == selectedId);
    }
  }

  void _drawEdge(Canvas canvas, SkillNodeState from, SkillNodeState to) {
    final Color color;
    if (from.isMastered && to.isMastered) {
      color = _masteredColor.withAlpha(120);
    } else if (from.isMastered || from.isInProgress) {
      color = _progressColor.withAlpha(80);
    } else if (from.isAvailable || to.isAvailable) {
      color = _availableColor.withAlpha(60);
    } else {
      color = _edgeDefault;
    }

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final path = Path();
    final start = from.position;
    final end = to.position;
    final midY = (start.dy + end.dy) / 2;

    path.moveTo(start.dx, start.dy + 24);
    path.cubicTo(
      start.dx, midY,
      end.dx, midY,
      end.dx, end.dy - 24,
    );

    canvas.drawPath(path, paint);
  }

  void _drawNode(Canvas canvas, SkillNodeState node, bool isSelected) {
    final center = node.position;
    const radius = 24.0;

    // Background fill
    final bgColor = switch (node.status) {
      SkillNodeStatus.mastered => _masteredColor.withAlpha(30),
      SkillNodeStatus.inProgress => _progressColor.withAlpha(25),
      SkillNodeStatus.available => _availableColor.withAlpha(20),
      SkillNodeStatus.locked => _lockedColor.withAlpha(15),
    };

    final bgPaint = Paint()..color = bgColor;
    canvas.drawCircle(center, radius, bgPaint);

    // Border
    final borderColor = switch (node.status) {
      SkillNodeStatus.mastered => _masteredColor,
      SkillNodeStatus.inProgress => _progressColor,
      SkillNodeStatus.available => _availableColor,
      SkillNodeStatus.locked => _lockedColor,
    };

    final borderPaint = Paint()
      ..color = isSelected ? borderColor : borderColor.withAlpha(150)
      ..strokeWidth = isSelected ? 3.0 : 2.0
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius, borderPaint);

    // Progress arc for in-progress nodes
    if (node.isInProgress && node.accuracy > 0) {
      final arcPaint = Paint()
        ..color = _progressColor
        ..strokeWidth = 3.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final arcRect = Rect.fromCircle(center: center, radius: radius + 2);
      canvas.drawArc(
        arcRect,
        -math.pi / 2,
        2 * math.pi * node.accuracy,
        false,
        arcPaint,
      );
    }

    // Star icons for mastered
    if (node.isMastered && node.stars > 0) {
      final starColor = const Color(0xFFF59E0B);
      final starPaint = Paint()..color = starColor;
      for (int i = 0; i < node.stars && i < 3; i++) {
        final sx = center.dx - 8 + (i * 8);
        final sy = center.dy + radius + 8;
        canvas.drawCircle(Offset(sx, sy), 3, starPaint);
      }
    }

    // Icon/text inside
    final textColor = switch (node.status) {
      SkillNodeStatus.mastered => _masteredColor,
      SkillNodeStatus.inProgress => _progressColor,
      SkillNodeStatus.available => _availableColor,
      SkillNodeStatus.locked => _lockedColor,
    };

    final icon = switch (node.status) {
      SkillNodeStatus.mastered => '✓',
      SkillNodeStatus.inProgress => '${(node.accuracy * 100).toInt()}%',
      SkillNodeStatus.available => '▶',
      SkillNodeStatus.locked => '🔒',
    };

    final textPainter = TextPainter(
      text: TextSpan(
        text: icon,
        style: TextStyle(
          fontSize: node.isInProgress ? 10 : 14,
          color: textColor,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(center.dx - textPainter.width / 2, center.dy - textPainter.height / 2),
    );

    // Label below
    final labelPainter = TextPainter(
      text: TextSpan(
        text: node.name,
        style: TextStyle(
          fontSize: 9,
          color: (isDark ? Colors.white : Colors.black).withAlpha(180),
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 2,
      textAlign: TextAlign.center,
    );
    labelPainter.layout(maxWidth: 80);
    final labelY = node.isMastered && node.stars > 0
        ? center.dy + radius + 14
        : center.dy + radius + 6;
    labelPainter.paint(
      canvas,
      Offset(center.dx - labelPainter.width / 2, labelY),
    );
  }

  @override
  bool shouldRepaint(covariant SkillTreePainter old) =>
      old.selectedId != selectedId || old.nodes != nodes || old.isDark != isDark;
}
