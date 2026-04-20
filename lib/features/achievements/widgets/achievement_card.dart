import 'dart:ui';
import 'package:flutter/material.dart';

enum AchievementRarity { common, rare, epic, legendary }

class AchievementData {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final String category;
  final AchievementRarity rarity;
  final int xpReward;
  final double progress; // 0.0 - 1.0
  final bool isUnlocked;
  final String? unlockedDate;

  const AchievementData({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.category,
    required this.rarity,
    required this.xpReward,
    required this.progress,
    required this.isUnlocked,
    this.unlockedDate,
  });

  Color get rarityColor {
    switch (rarity) {
      case AchievementRarity.common:
        return const Color(0xFF8899A6);
      case AchievementRarity.rare:
        return const Color(0xFF3B82F6);
      case AchievementRarity.epic:
        return const Color(0xFF8B5CF6);
      case AchievementRarity.legendary:
        return const Color(0xFFF59E0B);
    }
  }
}

class AchievementCard extends StatefulWidget {
  final AchievementData data;

  const AchievementCard({super.key, required this.data});

  @override
  State<AchievementCard> createState() => _AchievementCardState();
}

class _AchievementCardState extends State<AchievementCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    if (widget.data.isUnlocked) {
      _glowController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final color = d.rarityColor;

    return AnimatedBuilder(
      animation: _glowController,
      builder: (context, child) {
        final glowIntensity = d.isUnlocked ? 0.15 + _glowController.value * 0.2 : 0.0;

        return ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: d.isUnlocked
                      ? [
                          color.withOpacity(0.12),
                          Colors.white.withOpacity(0.05),
                        ]
                      : [
                          Colors.white.withOpacity(0.04),
                          Colors.white.withOpacity(0.02),
                        ],
                ),
                border: Border.all(
                  color: d.isUnlocked
                      ? color.withOpacity(0.4 + _glowController.value * 0.3)
                      : Colors.white.withOpacity(0.06),
                  width: d.isUnlocked ? 1.5 : 1,
                ),
                boxShadow: d.isUnlocked
                    ? [BoxShadow(color: color.withOpacity(glowIntensity), blurRadius: 20)]
                    : null,
              ),
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon + rarity badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              color.withOpacity(d.isUnlocked ? 0.25 : 0.06),
                              Colors.transparent,
                            ],
                          ),
                        ),
                        child: Icon(
                          d.icon,
                          color: d.isUnlocked ? color : Colors.white.withOpacity(0.15),
                          size: 26,
                        ),
                      ),
                      // Rarity tag
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: color.withOpacity(d.isUnlocked ? 0.15 : 0.05),
                          border: Border.all(
                            color: color.withOpacity(d.isUnlocked ? 0.4 : 0.1),
                          ),
                        ),
                        child: Text(
                          d.rarity.name[0].toUpperCase() + d.rarity.name.substring(1),
                          style: TextStyle(
                            color: d.isUnlocked ? color : Colors.white24,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Name
                  Text(
                    d.name,
                    style: TextStyle(
                      color: d.isUnlocked ? Colors.white : Colors.white38,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  // Description
                  Text(
                    d.description,
                    style: TextStyle(
                      color: d.isUnlocked ? Colors.white54 : Colors.white24,
                      fontSize: 11,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
                  // Progress bar (if not fully unlocked)
                  if (!d.isUnlocked) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${(d.progress * 100).toInt()}%',
                          style: TextStyle(
                            color: color.withOpacity(0.7),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.bolt, color: Colors.amber.withOpacity(0.5), size: 12),
                            Text(
                              '${d.xpReward} XP',
                              style: TextStyle(
                                color: Colors.amber.withOpacity(0.5),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: d.progress,
                        backgroundColor: Colors.white.withOpacity(0.06),
                        valueColor: AlwaysStoppedAnimation(
                          d.isUnlocked ? color : color.withOpacity(0.5),
                        ),
                        minHeight: 5,
                      ),
                    ),
                  ],
                  if (d.isUnlocked) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle, color: Color(0xFF22C55E), size: 14),
                            const SizedBox(width: 4),
                            const Text(
                              'Unlocked',
                              style: TextStyle(
                                color: Color(0xFF22C55E),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.bolt, color: Colors.amber, size: 12),
                            Text(
                              '${d.xpReward} XP',
                              style: const TextStyle(
                                color: Colors.amber,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
