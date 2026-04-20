import 'dart:math';

import 'package:flutter/material.dart';

/// A hexagonal league badge with league-specific colours, icon, glow,
/// and a pulse animation for high-tier leagues.
class LeagueBadge extends StatefulWidget {
  final String league;
  final double size;

  const LeagueBadge({
    super.key,
    required this.league,
    this.size = 100,
  });

  @override
  State<LeagueBadge> createState() => _LeagueBadgeState();
}

class _LeagueBadgeState extends State<LeagueBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  bool get _shouldPulse =>
      ['Archmage', 'GrandSorcerer', 'SupremeWizard'].contains(widget.league);

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    if (_shouldPulse) _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = _leagueConfig(widget.league);

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final pulseValue =
            _shouldPulse ? 0.4 + 0.6 * _pulseController.value : 0.7;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Badge
            Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: config.glowColor.withOpacity(0.35 * pulseValue),
                    blurRadius: 28 * pulseValue,
                    spreadRadius: 4 * pulseValue,
                  ),
                ],
              ),
              child: CustomPaint(
                painter: _HexagonPainter(
                  colors: config.gradientColors,
                  glowOpacity: pulseValue * 0.6,
                ),
                child: Center(
                  child: Icon(
                    config.icon,
                    size: widget.size * 0.38,
                    color: Colors.white.withOpacity(0.95),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            // League name
            widget.league == 'SupremeWizard'
                ? ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [
                        Color(0xFFFF0000),
                        Color(0xFFFF8800),
                        Color(0xFFFFFF00),
                        Color(0xFF00FF00),
                        Color(0xFF3B82F6),
                        Color(0xFF0044FF),
                        Color(0xFF8B5CF6),
                      ],
                    ).createShader(bounds),
                    child: Text(
                      _displayName(widget.league),
                      style: TextStyle(
                        fontSize: widget.size * 0.15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 1.5,
                      ),
                    ),
                  )
                : Text(
                    _displayName(widget.league),
                    style: TextStyle(
                      fontSize: widget.size * 0.15,
                      fontWeight: FontWeight.w800,
                      color: config.glowColor.withOpacity(0.9),
                      letterSpacing: 1.5,
                    ),
                  ),
          ],
        );
      },
    );
  }

  String _displayName(String league) {
    // Insert space before capitals: GrandSorcerer -> Grand Sorcerer
    return league.replaceAllMapped(
        RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}');
  }
}

// ---------------------------------------------------------------------------
// Config per league
// ---------------------------------------------------------------------------
class _LeagueConfig {
  final List<Color> gradientColors;
  final Color glowColor;
  final IconData icon;

  const _LeagueConfig({
    required this.gradientColors,
    required this.glowColor,
    required this.icon,
  });
}

_LeagueConfig _leagueConfig(String league) {
  switch (league) {
    case 'Spellcaster':
      return const _LeagueConfig(
        gradientColors: [Color(0xFF2244AA), Color(0xFF4488FF)],
        glowColor: Color(0xFF4488FF),
        icon: Icons.bolt_rounded,
      );
    case 'Mage':
      return const _LeagueConfig(
        gradientColors: [Color(0xFF6B1FA0), Color(0xFF8B5CF6)],
        glowColor: Color(0xFF8B5CF6),
        icon: Icons.local_fire_department_rounded,
      );
    case 'Archmage':
      return const _LeagueConfig(
        gradientColors: [Color(0xFF8B0000), Color(0xFFFF4444)],
        glowColor: Color(0xFFFF4444),
        icon: Icons.whatshot_rounded,
      );
    case 'GrandSorcerer':
      return const _LeagueConfig(
        gradientColors: [Color(0xFFB8860B), Color(0xFFF59E0B)],
        glowColor: Color(0xFFF59E0B),
        icon: Icons.diamond_rounded,
      );
    case 'SupremeWizard':
      return const _LeagueConfig(
        gradientColors: [
          Color(0xFFFF0000),
          Color(0xFFFF8800),
          Color(0xFFFFFF00),
          Color(0xFF00FF00),
          Color(0xFF3B82F6),
          Color(0xFF0044FF),
          Color(0xFF8B5CF6),
        ],
        glowColor: Color(0xFF3B82F6),
        icon: Icons.stars_rounded,
      );
    case 'Apprentice':
    default:
      return const _LeagueConfig(
        gradientColors: [Color(0xFF444444), Color(0xFF888888)],
        glowColor: Color(0xFF888888),
        icon: Icons.auto_awesome,
      );
  }
}

// ---------------------------------------------------------------------------
// Hexagon painter
// ---------------------------------------------------------------------------
class _HexagonPainter extends CustomPainter {
  final List<Color> colors;
  final double glowOpacity;

  _HexagonPainter({required this.colors, required this.glowOpacity});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;
    final path = _hexPath(center, radius);

    // Glow
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.fill
        ..color = colors.first.withOpacity(glowOpacity * 0.15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );

    // Gradient fill
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.fill
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ).createShader(rect),
    );

    // Inner dark overlay for depth
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.fill
        ..shader = RadialGradient(
          colors: [
            Colors.white.withOpacity(0.12),
            Colors.transparent,
            Colors.black.withOpacity(0.2),
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(rect),
    );

    // Border
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = Colors.white.withOpacity(0.2)
        ..strokeWidth = 1.5,
    );
  }

  Path _hexPath(Offset center, double radius) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (pi / 3) * i - pi / 2;
      final x = center.dx + radius * cos(angle);
      final y = center.dy + radius * sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _HexagonPainter old) =>
      old.glowOpacity != glowOpacity;
}
