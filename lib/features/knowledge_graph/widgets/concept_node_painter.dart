import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/prerequisite_graph.dart';

/// Layout data for a positioned concept node.
class NodeLayout {
  final ConceptNode concept;
  final Offset position;
  final double radius;
  final Color color;

  const NodeLayout({
    required this.concept,
    required this.position,
    this.radius = 22,
    this.color = AppTheme.accentPurple,
  });

  bool containsPoint(Offset point) {
    return (point - position).distance <= radius + 8;
  }
}

/// CustomPainter that draws the concept graph: nodes, edges, labels.
class ConceptGraphPainter extends CustomPainter {
  ConceptGraphPainter({
    required this.nodes,
    required this.animationProgress,
    this.focusedNodeId,
    this.highlightedPath = const {},
    this.panOffset = Offset.zero,
    this.scale = 1.0,
    this.isDark = true,
  });

  final List<NodeLayout> nodes;
  final double animationProgress;
  final String? focusedNodeId;
  final Set<String> highlightedPath;
  final Offset panOffset;
  final double scale;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(
      size.width / 2 + panOffset.dx,
      size.height / 2 + panOffset.dy,
    );
    canvas.scale(scale);

    // Draw edges first (below nodes)
    _drawEdges(canvas);
    // Draw cross-subject links
    _drawCrossSubjectLinks(canvas);
    // Draw nodes on top
    _drawNodes(canvas);

    canvas.restore();
  }

  void _drawEdges(Canvas canvas) {
    final nodeMap = {for (final n in nodes) n.concept.id: n};

    for (final node in nodes) {
      for (final prereqId in node.concept.prerequisiteIds) {
        final prereq = nodeMap[prereqId];
        if (prereq == null) continue;

        final isHighlighted = highlightedPath.contains(node.concept.id) &&
            highlightedPath.contains(prereqId);

        final paint = Paint()
          ..strokeWidth = isHighlighted ? 2.5 : 1.0
          ..style = PaintingStyle.stroke
          ..color = isHighlighted
              ? AppTheme.accentCyan.withAlpha((200 * animationProgress).round())
              : (isDark ? Colors.white : Colors.black).withAlpha((30 * animationProgress).round());

        // Draw line from prerequisite to dependent
        final start = prereq.position;
        final end = node.position;
        canvas.drawLine(start, end, paint);

        // Draw arrowhead
        _drawArrowHead(canvas, start, end, paint.color, isHighlighted ? 8 : 5);
      }
    }
  }

  void _drawCrossSubjectLinks(Canvas canvas) {
    final nodeMap = {for (final n in nodes) n.concept.id: n};

    for (final node in nodes) {
      for (final relId in node.concept.relatedIds) {
        final related = nodeMap[relId];
        if (related == null) continue;
        // Only draw if the other subject (avoid duplicates)
        if (node.concept.subject == related.concept.subject) continue;
        if (node.concept.id.compareTo(relId) > 0) continue;

        final paint = Paint()
          ..strokeWidth = 0.8
          ..style = PaintingStyle.stroke
          ..color = AppTheme.accentGold.withAlpha((40 * animationProgress).round());

        // Dashed line
        _drawDashedLine(canvas, node.position, related.position, paint);
      }
    }
  }

  void _drawNodes(Canvas canvas) {
    for (final node in nodes) {
      final isFocused = node.concept.id == focusedNodeId;
      final isInPath = highlightedPath.contains(node.concept.id);
      final alpha = animationProgress;
      final r = node.radius * (0.5 + 0.5 * animationProgress);

      // Glow for focused/highlighted nodes
      if (isFocused || isInPath) {
        final glowPaint = Paint()
          ..color = node.color.withAlpha((40 * alpha).round())
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
        canvas.drawCircle(node.position, r + 8, glowPaint);
      }

      // Node circle fill
      final fillPaint = Paint()
        ..color = node.color.withAlpha((isFocused ? 60 : 35) * alpha ~/ 1)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(node.position, r, fillPaint);

      // Node border
      final borderPaint = Paint()
        ..color = node.color.withAlpha((isFocused ? 220 : 140) * alpha ~/ 1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isFocused ? 2.0 : 1.2;
      canvas.drawCircle(node.position, r, borderPaint);

      // Inner highlight dot
      final dotPaint = Paint()
        ..color = node.color.withAlpha((180 * alpha).round());
      canvas.drawCircle(node.position, 3, dotPaint);

      // Label below node
      final textSpan = TextSpan(
        text: node.concept.name,
        style: TextStyle(
          fontFamily: 'SpaceGrotesk',
          fontSize: isFocused ? 10 : 8,
          fontWeight: isFocused ? FontWeight.w700 : FontWeight.w500,
          color: (isDark ? AppTheme.textSecondary : const Color(0xFF3A3A5C)).withAlpha((220 * alpha).round()),
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 80);

      textPainter.paint(
        canvas,
        node.position + Offset(-textPainter.width / 2, r + 4),
      );
    }
  }

  void _drawArrowHead(
    Canvas canvas, Offset from, Offset to, Color color, double size,
  ) {
    final direction = (to - from);
    if (direction.distance == 0) return;
    final normalized = direction / direction.distance;

    // Arrow at the edge of the target node's radius
    final targetNode = nodes.where((n) => (n.position - to).distance < 1);
    final targetRadius = targetNode.isNotEmpty ? targetNode.first.radius : 22.0;
    final arrowTip = to - normalized * (targetRadius * (0.5 + 0.5 * animationProgress));

    final angle = math.atan2(normalized.dy, normalized.dx);
    final p1 = arrowTip -
        Offset(
          size * math.cos(angle - 0.4),
          size * math.sin(angle - 0.4),
        );
    final p2 = arrowTip -
        Offset(
          size * math.cos(angle + 0.4),
          size * math.sin(angle + 0.4),
        );

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(arrowTip.dx, arrowTip.dy)
      ..lineTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..close();
    canvas.drawPath(path, paint);
  }

  void _drawDashedLine(Canvas canvas, Offset from, Offset to, Paint paint) {
    final direction = to - from;
    final distance = direction.distance;
    if (distance == 0) return;
    final normalized = direction / distance;
    const dashLen = 4.0;
    const gapLen = 4.0;
    var current = 0.0;
    while (current < distance) {
      final start = from + normalized * current;
      final end = from + normalized * math.min(current + dashLen, distance);
      canvas.drawLine(start, end, paint);
      current += dashLen + gapLen;
    }
  }

  @override
  bool shouldRepaint(ConceptGraphPainter oldDelegate) {
    return oldDelegate.animationProgress != animationProgress ||
        oldDelegate.focusedNodeId != focusedNodeId ||
        oldDelegate.highlightedPath != highlightedPath ||
        oldDelegate.panOffset != panOffset ||
        oldDelegate.scale != scale ||
        oldDelegate.isDark != isDark;
  }
}
