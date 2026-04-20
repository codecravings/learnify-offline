import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/local_memory_service.dart';
import '../../../core/services/local_profile_service.dart';
import '../../../core/theme/app_theme.dart';
import '../widgets/achievement_card.dart';

/// Achievements computed from real on-device data — XP, streak, and
/// topic/quiz progress from the local SQLite store.
class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  String _selected = 'All';
  final _categories = const ['All', 'Study', 'Quiz', 'Streak', 'Special'];

  List<AchievementData> _achievements = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = LocalProfileService.instance.currentProfile;
    final topics = await LocalMemoryService.instance.getAllTopicProgress();

    final xp = profile?.xp ?? 0;
    final streak = profile?.streak ?? 0;
    final topicCount = topics.length;
    final masteredCount = topics
        .where((t) =>
            (t['stars'] as int? ?? 0) >= 3 ||
            (t['accuracy'] as int? ?? 0) >= 90)
        .length;
    final perfectCount = topics
        .where((t) => (t['accuracy'] as int? ?? 0) == 100)
        .length;
    final advancedCount = topics
        .where((t) =>
            ((t['level'] as String?) ?? '').toLowerCase() == 'advanced')
        .length;

    final list = <AchievementData>[
      _studyBadge(
        id: 's1',
        name: 'First Spark',
        description: 'Complete your first lesson',
        icon: Icons.school_rounded,
        rarity: AchievementRarity.common,
        xp: 50,
        target: 1,
        current: topicCount,
      ),
      _studyBadge(
        id: 's2',
        name: 'Knowledge Seeker',
        description: 'Study 5 different topics',
        icon: Icons.explore_rounded,
        rarity: AchievementRarity.common,
        xp: 100,
        target: 5,
        current: topicCount,
      ),
      _studyBadge(
        id: 's3',
        name: 'Topic Master',
        description: 'Study 10 different topics',
        icon: Icons.workspace_premium_rounded,
        rarity: AchievementRarity.rare,
        xp: 250,
        target: 10,
        current: topicCount,
      ),
      _studyBadge(
        id: 's4',
        name: 'Scholar Elite',
        description: 'Study 25 different topics',
        icon: Icons.auto_awesome,
        rarity: AchievementRarity.legendary,
        xp: 1000,
        target: 25,
        current: topicCount,
      ),
      _quizBadge(
        id: 'q1',
        name: 'Perfect Score',
        description: 'Hit 100% accuracy on any topic',
        icon: Icons.stars_rounded,
        rarity: AchievementRarity.rare,
        xp: 200,
        target: 1,
        current: perfectCount,
      ),
      _quizBadge(
        id: 'q2',
        name: 'Master of Three',
        description: 'Earn 3 stars on 3 topics',
        icon: Icons.star_rounded,
        rarity: AchievementRarity.epic,
        xp: 400,
        target: 3,
        current: masteredCount,
      ),
      _quizBadge(
        id: 'q3',
        name: 'Advanced Scholar',
        description: 'Complete an advanced level lesson',
        icon: Icons.psychology_rounded,
        rarity: AchievementRarity.epic,
        xp: 400,
        target: 1,
        current: advancedCount,
      ),
      _streakBadge(
        id: 'st1',
        name: 'Getting Started',
        description: '3-day learning streak',
        icon: Icons.local_fire_department_rounded,
        rarity: AchievementRarity.common,
        xp: 75,
        target: 3,
        current: streak,
      ),
      _streakBadge(
        id: 'st2',
        name: 'Week Warrior',
        description: '7-day learning streak',
        icon: Icons.whatshot_rounded,
        rarity: AchievementRarity.rare,
        xp: 200,
        target: 7,
        current: streak,
      ),
      _streakBadge(
        id: 'st3',
        name: 'Fortnight Focus',
        description: '14-day learning streak',
        icon: Icons.local_fire_department,
        rarity: AchievementRarity.epic,
        xp: 500,
        target: 14,
        current: streak,
      ),
      _streakBadge(
        id: 'st4',
        name: 'Monthly Master',
        description: '30-day learning streak',
        icon: Icons.military_tech_rounded,
        rarity: AchievementRarity.legendary,
        xp: 1000,
        target: 30,
        current: streak,
      ),
      _specialBadge(
        id: 'sp1',
        name: 'Early Adopter',
        description: 'Joined Learnify in its early days',
        icon: Icons.rocket_launch,
        rarity: AchievementRarity.rare,
        xp: 500,
        unlocked: profile != null,
      ),
      _specialBadge(
        id: 'sp2',
        name: 'XP Hunter',
        description: 'Earn 1000 total XP',
        icon: Icons.bolt_rounded,
        rarity: AchievementRarity.epic,
        xp: 300,
        unlocked: xp >= 1000,
        progress: (xp / 1000).clamp(0.0, 1.0),
      ),
      _specialBadge(
        id: 'sp3',
        name: 'XP Legend',
        description: 'Earn 5000 total XP',
        icon: Icons.diamond_rounded,
        rarity: AchievementRarity.legendary,
        xp: 2000,
        unlocked: xp >= 5000,
        progress: (xp / 5000).clamp(0.0, 1.0),
      ),
    ];

    if (!mounted) return;
    setState(() {
      _achievements = list;
      _loading = false;
    });
  }

  AchievementData _studyBadge({
    required String id,
    required String name,
    required String description,
    required IconData icon,
    required AchievementRarity rarity,
    required int xp,
    required int target,
    required int current,
  }) {
    return AchievementData(
      id: id,
      name: name,
      description: description,
      icon: icon,
      category: 'Study',
      rarity: rarity,
      xpReward: xp,
      progress: (current / target).clamp(0.0, 1.0),
      isUnlocked: current >= target,
    );
  }

  AchievementData _quizBadge({
    required String id,
    required String name,
    required String description,
    required IconData icon,
    required AchievementRarity rarity,
    required int xp,
    required int target,
    required int current,
  }) {
    return AchievementData(
      id: id,
      name: name,
      description: description,
      icon: icon,
      category: 'Quiz',
      rarity: rarity,
      xpReward: xp,
      progress: (current / target).clamp(0.0, 1.0),
      isUnlocked: current >= target,
    );
  }

  AchievementData _streakBadge({
    required String id,
    required String name,
    required String description,
    required IconData icon,
    required AchievementRarity rarity,
    required int xp,
    required int target,
    required int current,
  }) {
    return AchievementData(
      id: id,
      name: name,
      description: description,
      icon: icon,
      category: 'Streak',
      rarity: rarity,
      xpReward: xp,
      progress: (current / target).clamp(0.0, 1.0),
      isUnlocked: current >= target,
    );
  }

  AchievementData _specialBadge({
    required String id,
    required String name,
    required String description,
    required IconData icon,
    required AchievementRarity rarity,
    required int xp,
    required bool unlocked,
    double progress = 0.0,
  }) {
    return AchievementData(
      id: id,
      name: name,
      description: description,
      icon: icon,
      category: 'Special',
      rarity: rarity,
      xpReward: xp,
      progress: unlocked ? 1.0 : progress,
      isUnlocked: unlocked,
    );
  }

  List<AchievementData> get _filtered {
    if (_selected == 'All') return _achievements;
    return _achievements.where((a) => a.category == _selected).toList();
  }

  @override
  Widget build(BuildContext context) {
    final unlocked = _achievements.where((a) => a.isUnlocked).length;
    final total = _achievements.length;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('ACHIEVEMENTS'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: Container(
        decoration: AppTheme.scaffoldDecorationOf(context),
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    _buildSummary(context, unlocked, total),
                    const SizedBox(height: 10),
                    _buildCategoryTabs(context),
                    const SizedBox(height: 12),
                    Expanded(
                      child: GridView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.78,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                        ),
                        itemCount: _filtered.length,
                        itemBuilder: (_, i) {
                          final a = _filtered[i];
                          return GestureDetector(
                            onTap: () => _showDetail(a),
                            child: AchievementCard(data: a),
                          );
                        },
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildSummary(BuildContext context, int unlocked, int total) {
    final pct = total == 0 ? 0.0 : unlocked / total;
    final green = AppTheme.accentGreenOf(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$unlocked of $total unlocked',
                  style: AppTheme.bodyStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondaryOf(context),
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 6,
                    backgroundColor: AppTheme.glassFillOf(context),
                    valueColor: AlwaysStoppedAnimation(green),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: green.withAlpha(32),
              border: Border.all(color: green.withAlpha(90), width: 1),
            ),
            child: Text(
              '${(pct * 100).round()}%',
              style: AppTheme.headerStyle(
                fontSize: 13,
                color: green,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTabs(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _categories.length,
        itemBuilder: (_, i) {
          final cat = _categories[i];
          final selected = _selected == cat;
          final cyan = AppTheme.accentCyanOf(context);
          return GestureDetector(
            onTap: () => setState(() => _selected = cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              margin: const EdgeInsets.only(right: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: selected
                    ? cyan.withAlpha(42)
                    : AppTheme.glassFillOf(context),
                border: Border.all(
                  color:
                      selected ? cyan : AppTheme.glassBorderOf(context),
                  width: selected ? 1.2 : 0.8,
                ),
              ),
              child: Text(
                cat,
                style: AppTheme.bodyStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? cyan
                      : AppTheme.textSecondaryOf(context),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showDetail(AchievementData a) {
    final rarityColor = a.rarityColor;
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: AppTheme.backgroundSecondary,
                border: Border.all(
                  color: rarityColor.withAlpha(160),
                  width: 1.4,
                ),
                boxShadow: AppTheme.neonGlow(rarityColor, blur: 28),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [rarityColor, rarityColor.withAlpha(120)],
                      ),
                    ),
                    child: Icon(a.icon, size: 36, color: Colors.white),
                  ),
                  const SizedBox(height: 14),
                  Text(a.name, style: AppTheme.headerStyle(fontSize: 20)),
                  const SizedBox(height: 6),
                  Text(
                    a.description,
                    textAlign: TextAlign.center,
                    style: AppTheme.bodyStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondaryOf(context),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: rarityColor.withAlpha(38),
                      border: Border.all(
                          color: rarityColor.withAlpha(120), width: 1),
                    ),
                    child: Text(
                      '+${a.xpReward} XP',
                      style: AppTheme.bodyStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: rarityColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (!a.isUnlocked)
                    Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: a.progress,
                            minHeight: 6,
                            backgroundColor: AppTheme.glassFillOf(context),
                            valueColor: AlwaysStoppedAnimation(rarityColor),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${(a.progress * 100).round()}% complete',
                          style: AppTheme.bodyStyle(
                            fontSize: 11,
                            color: AppTheme.textTertiaryOf(context),
                          ),
                        ),
                      ],
                    )
                  else
                    Text(
                      'UNLOCKED',
                      style: AppTheme.headerStyle(
                        fontSize: 12,
                        letterSpacing: 2.0,
                        color: AppTheme.accentGreenOf(context),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
