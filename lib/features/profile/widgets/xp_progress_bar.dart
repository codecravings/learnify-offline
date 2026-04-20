import 'package:flutter/material.dart';

/// Animated XP progress bar showing current XP relative to next league threshold.
///
/// Displays a neon-gradient filled bar with glow, league milestone markers,
/// and animates on first appearance.
class XpProgressBar extends StatefulWidget {
  final int currentXp;
  final int currentLeagueMinXp;
  final int nextLeagueMinXp;
  final String currentLeagueName;
  final String nextLeagueName;
  final Color barColor;
  final Duration animationDuration;

  const XpProgressBar({
    super.key,
    required this.currentXp,
    required this.currentLeagueMinXp,
    required this.nextLeagueMinXp,
    required this.currentLeagueName,
    required this.nextLeagueName,
    this.barColor = const Color(0xFF3B82F6),
    this.animationDuration = const Duration(milliseconds: 1500),
  });

  @override
  State<XpProgressBar> createState() => _XpProgressBarState();
}

class _XpProgressBarState extends State<XpProgressBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progressAnim;

  double get _targetProgress {
    final range = widget.nextLeagueMinXp - widget.currentLeagueMinXp;
    if (range <= 0) return 1.0;
    return ((widget.currentXp - widget.currentLeagueMinXp) / range)
        .clamp(0.0, 1.0);
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );
    _progressAnim = Tween<double>(begin: 0, end: _targetProgress).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant XpProgressBar old) {
    super.didUpdateWidget(old);
    if (old.currentXp != widget.currentXp) {
      _progressAnim = Tween<double>(
        begin: _progressAnim.value,
        end: _targetProgress,
      ).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
      );
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final xpInRange = widget.currentXp - widget.currentLeagueMinXp;
    final rangeTotal = widget.nextLeagueMinXp - widget.currentLeagueMinXp;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Labels
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                _leagueIcon(widget.currentLeagueName, 16),
                const SizedBox(width: 6),
                Text(
                  widget.currentLeagueName,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Text(
                  widget.nextLeagueName,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 6),
                _leagueIcon(widget.nextLeagueName, 16),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Bar
        AnimatedBuilder(
          animation: _progressAnim,
          builder: (context, _) {
            return Container(
              height: 22,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.white.withOpacity(0.06),
                border: Border.all(
                  color: Colors.white.withOpacity(0.08),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  children: [
                    // Fill
                    FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: _progressAnim.value,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  const Color(0xFF3B82F6).withOpacity(0.5),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Shimmer overlay
                    FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: _progressAnim.value,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withOpacity(0.0),
                              Colors.white.withOpacity(0.15),
                              Colors.white.withOpacity(0.0),
                            ],
                            stops: const [0.0, 0.5, 1.0],
                          ),
                        ),
                      ),
                    ),

                    // Milestone markers (25%, 50%, 75%)
                    for (final pct in [0.25, 0.5, 0.75])
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 0,
                        bottom: 0,
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: pct,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Container(
                              width: 2,
                              color: Colors.white.withOpacity(0.1),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),

        const SizedBox(height: 8),

        // XP text
        Center(
          child: Text(
            '$xpInRange / $rangeTotal XP',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 12,
              fontWeight: FontWeight.w500,
              letterSpacing: 1,
            ),
          ),
        ),
      ],
    );
  }

  Widget _leagueIcon(String league, double size) {
    final Map<String, IconData> icons = {
      'Apprentice': Icons.auto_awesome,
      'Spellcaster': Icons.bolt_rounded,
      'Mage': Icons.local_fire_department_rounded,
      'Archmage': Icons.whatshot_rounded,
      'GrandSorcerer': Icons.diamond_rounded,
      'SupremeWizard': Icons.stars_rounded,
    };

    final Map<String, Color> colors = {
      'Apprentice': Colors.grey,
      'Spellcaster': const Color(0xFF4488FF),
      'Mage': const Color(0xFF8B5CF6),
      'Archmage': const Color(0xFFFF4444),
      'GrandSorcerer': const Color(0xFFF59E0B),
      'SupremeWizard': const Color(0xFF3B82F6),
    };

    return Icon(
      icons[league] ?? Icons.star_rounded,
      size: size,
      color: colors[league] ?? Colors.white54,
    );
  }
}
