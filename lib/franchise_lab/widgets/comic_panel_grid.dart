import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';

/// Renders a comic-book-style grid (canonically 2x2) of dialogue panels.
///
/// The widget is intentionally pure-Flutter — no SVG, no image deps.
/// Each panel uses a `ClipPath` based [_SpeechBubbleClipper] for the
/// classic comic speech tail, plus a small [_SpeedLinesPainter] flourish.
class ComicPanelGrid extends StatelessWidget {
  const ComicPanelGrid({
    super.key,
    required this.payload,
    this.compact = false,
  });

  /// Shape (see CLAUDE.md story_learn comic spec):
  /// {
  ///   "title": String,
  ///   "topic": String,
  ///   "franchiseName": String?,
  ///   "panels": [
  ///     { "characterId", "characterName", "characterColor",
  ///       "emotion", "dialogue", "narration" }, ...
  ///   ]
  /// }
  final Map<String, dynamic> payload;

  /// When true, renders as a thumbnail (no speed lines, no narration,
  /// dialogue truncated, smaller fonts).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final title = (payload['title'] as String?)?.trim() ?? '';
    final topic = (payload['topic'] as String?)?.trim() ?? '';
    final franchiseName = (payload['franchiseName'] as String?)?.trim();
    final rawPanels = payload['panels'];
    final panels = rawPanels is List
        ? rawPanels.whereType<Map>().map((m) => m.cast<String, dynamic>()).toList()
        : <Map<String, dynamic>>[];

    if (panels.isEmpty) {
      return _emptyState(title);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!compact) _buildHeader(title, topic, franchiseName),
        if (!compact) const SizedBox(height: 14),
        _buildGrid(panels),
      ],
    );
  }

  // ── header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(String title, String topic, String? franchiseName) {
    final subtitle = (franchiseName != null && franchiseName.isNotEmpty)
        ? '$topic  ·  $franchiseName'
        : topic;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty)
          Text(
            title,
            style: GoogleFonts.orbitron(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 12,
              color: AppTheme.textTertiary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }

  // ── grid ───────────────────────────────────────────────────────────────────

  Widget _buildGrid(List<Map<String, dynamic>> panels) {
    final n = panels.length;
    if (n == 1) {
      return _aspect(child: _buildPanel(panels[0]));
    }
    if (n == 2) {
      return Row(
        children: [
          Expanded(child: _aspect(child: _buildPanel(panels[0]))),
          SizedBox(width: compact ? 6 : 10),
          Expanded(child: _aspect(child: _buildPanel(panels[1]))),
        ],
      );
    }
    if (n == 3) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(child: _aspect(child: _buildPanel(panels[0]))),
              SizedBox(width: compact ? 6 : 10),
              Expanded(child: _aspect(child: _buildPanel(panels[1]))),
            ],
          ),
          SizedBox(height: compact ? 6 : 10),
          _aspect(child: _buildPanel(panels[2])),
        ],
      );
    }
    // 4+ canonical: 2x2 grid (extras ignored).
    final p = panels.take(4).toList();
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _aspect(child: _buildPanel(p[0]))),
            SizedBox(width: compact ? 6 : 10),
            Expanded(child: _aspect(child: _buildPanel(p[1]))),
          ],
        ),
        SizedBox(height: compact ? 6 : 10),
        Row(
          children: [
            Expanded(child: _aspect(child: _buildPanel(p[2]))),
            SizedBox(width: compact ? 6 : 10),
            Expanded(child: _aspect(child: _buildPanel(p[3]))),
          ],
        ),
      ],
    );
  }

  Widget _aspect({required Widget child}) =>
      AspectRatio(aspectRatio: 1, child: child);

  // ── single panel ───────────────────────────────────────────────────────────

  Widget _buildPanel(Map<String, dynamic> panel) {
    final color = _parseHexColor(panel['characterColor'] as String?);
    final name = (panel['characterName'] as String?)?.trim() ?? 'NARRATOR';
    final emotion = (panel['emotion'] as String?)?.trim() ?? '';
    final dialogue = (panel['dialogue'] as String?)?.trim() ?? '';
    final narration = (panel['narration'] as String?)?.trim() ?? '';

    final outerBorder = compact ? 3.0 : 5.0;
    final innerRadius = compact ? 6.0 : 10.0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(innerRadius + 2),
      ),
      padding: EdgeInsets.all(outerBorder),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(innerRadius),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withAlpha(60),
                color.withAlpha(20),
                Colors.black.withAlpha(160),
              ],
            ),
            border: Border.all(
              color: Colors.black,
              width: compact ? 1 : 1.5,
            ),
            borderRadius: BorderRadius.circular(innerRadius),
          ),
          child: Stack(
            children: [
              // Speed lines flourish (skipped when compact).
              if (!compact)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _SpeedLinesPainter(color: color.withAlpha(80)),
                    ),
                  ),
                ),
              // Narration ribbon (skipped when compact).
              if (!compact && narration.isNotEmpty)
                Positioned(
                  left: 8,
                  right: 8,
                  top: 36,
                  child: _narrationBox(narration),
                ),
              // Speech bubble.
              Positioned(
                left: compact ? 6 : 10,
                right: compact ? 6 : 10,
                bottom: compact ? 6 : 10,
                child: _speechBubble(dialogue),
              ),
              // Top-left name plate.
              Positioned(
                left: compact ? 4 : 8,
                top: compact ? 4 : 8,
                child: _namePlate(name, color),
              ),
              // Top-right emotion pill.
              if (emotion.isNotEmpty)
                Positioned(
                  right: compact ? 4 : 8,
                  top: compact ? 4 : 8,
                  child: _emotionPill(emotion, color),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── pieces ─────────────────────────────────────────────────────────────────

  Widget _namePlate(String name, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 5 : 8,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.black, width: 1.2),
      ),
      child: Text(
        name.toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.orbitron(
          fontSize: compact ? 7 : 10,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: compact ? 0.6 : 1.0,
        ),
      ),
    );
  }

  Widget _emotionPill(String emotion, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 4 : 7,
        vertical: compact ? 1 : 3,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(180),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        emotion.toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.orbitron(
          fontSize: compact ? 6 : 8,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _narrationBox(String narration) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.accentGold.withAlpha(220),
        border: Border.all(color: Colors.black, width: 1.2),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(
        narration,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.spaceGrotesk(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.black,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }

  Widget _speechBubble(String dialogue) {
    if (dialogue.isEmpty) return const SizedBox.shrink();
    return ClipPath(
      clipper: const _SpeechBubbleClipper(tailWidth: 14, tailHeight: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(240),
          border: Border.all(color: Colors.black, width: 1.5),
        ),
        padding: EdgeInsets.fromLTRB(
          compact ? 8 : 12,
          compact ? 6 : 10,
          compact ? 8 : 12,
          compact ? 16 : 22, // extra room for the tail
        ),
        child: Text(
          dialogue,
          maxLines: compact ? 2 : 5,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.spaceGrotesk(
            fontSize: compact ? 9 : 12,
            fontWeight: FontWeight.w500,
            color: Colors.black,
            height: 1.25,
          ),
        ),
      ),
    );
  }

  Widget _emptyState(String title) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.image_not_supported_outlined,
              color: Colors.white38, size: 40),
          const SizedBox(height: 10),
          Text(
            title.isNotEmpty ? title : 'Empty comic',
            textAlign: TextAlign.center,
            style: GoogleFonts.orbitron(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'No panels in this comic',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 12,
              color: AppTheme.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── helpers ──────────────────────────────────────────────────────────────────

/// Parses '#FF7A00' or 'FF7A00' (case-insensitive) into a [Color].
/// Falls back to accentCyan on any failure.
Color _parseHexColor(String? raw) {
  const fallback = Color(0xFF00F5FF);
  if (raw == null) return fallback;
  var hex = raw.trim();
  if (hex.startsWith('#')) hex = hex.substring(1);
  if (hex.length == 6) hex = 'FF$hex';
  if (hex.length != 8) return fallback;
  final v = int.tryParse(hex, radix: 16);
  if (v == null) return fallback;
  return Color(v);
}

/// Custom clipper that turns a rectangle into a comic speech bubble:
/// rounded corners + a triangular tail pointing toward the top-left
/// (where the character name plate lives).
class _SpeechBubbleClipper extends CustomClipper<Path> {
  const _SpeechBubbleClipper({
    this.tailWidth = 14,
    this.tailHeight = 12,
  });

  static const double _cornerRadius = 10;

  final double tailWidth;
  final double tailHeight;

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    final r = _cornerRadius.clamp(0.0, h / 2);
    final body = Path()
      ..moveTo(r, 0)
      ..lineTo(w - r, 0)
      ..quadraticBezierTo(w, 0, w, r)
      ..lineTo(w, h - tailHeight - r)
      ..quadraticBezierTo(w, h - tailHeight, w - r, h - tailHeight)
      // tail apex points down-left toward the character plate
      ..lineTo(w * 0.30 + tailWidth, h - tailHeight)
      ..lineTo(w * 0.18, h)
      ..lineTo(w * 0.30, h - tailHeight)
      ..lineTo(r, h - tailHeight)
      ..quadraticBezierTo(0, h - tailHeight, 0, h - tailHeight - r)
      ..lineTo(0, r)
      ..quadraticBezierTo(0, 0, r, 0)
      ..close();
    return body;
  }

  @override
  bool shouldReclip(covariant _SpeechBubbleClipper old) =>
      old.tailWidth != tailWidth || old.tailHeight != tailHeight;
}

/// Manga-style speed lines: a few thin diagonal strokes from the corner.
class _SpeedLinesPainter extends CustomPainter {
  _SpeedLinesPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    // Top-right corner -> sweep diagonally inward.
    final origin = Offset(size.width, 0);
    final lengths = [0.55, 0.42, 0.35];
    final angles = [2.55, 2.75, 2.95]; // radians, pointing down-left
    for (var i = 0; i < lengths.length; i++) {
      final l = lengths[i] * size.width;
      final a = angles[i];
      final end = Offset(
        origin.dx + l * _cos(a),
        origin.dy + l * _sin(a),
      );
      canvas.drawLine(origin, end, paint);
    }
  }

  // Tiny inline trig helpers — avoid importing dart:math just for two ops.
  double _cos(double a) => _approx(a, true);
  double _sin(double a) => _approx(a, false);
  double _approx(double a, bool cos) {
    // Use Flutter's built-in via Offset.fromDirection for accuracy.
    final o = Offset.fromDirection(a, 1);
    return cos ? o.dx : o.dy;
  }

  @override
  bool shouldRepaint(covariant _SpeedLinesPainter old) => old.color != color;
}
