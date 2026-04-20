import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/services/local_memory_service.dart';
import '../../../core/services/local_profile_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/widgets/glass_container.dart';

/// Local-first profile screen. No Firebase, no leagues, no battles.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  final _profile = LocalProfileService.instance;
  final _memory = LocalMemoryService.instance;

  late final TabController _tabs;
  List<Map<String, dynamic>> _topics = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _profile.addListener(_onProfileChanged);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _profile.removeListener(_onProfileChanged);
    super.dispose();
  }

  void _onProfileChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    final topics = await _memory.getAllTopicProgress();
    if (mounted) {
      setState(() {
        _topics = topics;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _profile.currentProfile;
    if (p == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.accentCyan),
        ),
      );
    }

    final bottomPadding = MediaQuery.of(context).padding.bottom + 90;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _load,
          color: AppTheme.accentCyan,
          backgroundColor: AppTheme.surfaceDark,
          child: ListView(
            padding: EdgeInsets.fromLTRB(20, 16, 20, bottomPadding),
            children: [
              _buildHeader(p).animate().fadeIn(duration: 500.ms),
              const SizedBox(height: 18),
              _buildStatsRow(p).animate().fadeIn(delay: 80.ms, duration: 500.ms),
              const SizedBox(height: 18),
              _buildTabs().animate().fadeIn(delay: 140.ms, duration: 500.ms),
              const SizedBox(height: 10),
              AnimatedBuilder(
                animation: _tabs,
                builder: (_, __) => _tabs.index == 0
                    ? _buildOverviewTab(p)
                    : _buildAchievementsTab(p),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(LocalProfile p) {
    final initial = p.name.isNotEmpty ? p.name[0].toUpperCase() : '?';
    return GlassContainer(
      borderColor: AppTheme.accentCyan.withAlpha(50),
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [AppTheme.accentCyan, AppTheme.accentPurple],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accentCyan.withAlpha(120),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    initial,
                    style: GoogleFonts.orbitron(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: GestureDetector(
                  onTap: _showSettings,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.backgroundPrimary,
                      border: Border.all(
                          color: AppTheme.accentCyan.withAlpha(120),
                          width: 1.2),
                    ),
                    child: const Icon(Icons.settings_rounded,
                        size: 14, color: AppTheme.accentCyan),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            p.name,
            style: GoogleFonts.orbitron(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${p.grade}  ·  ${p.language}',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(LocalProfile p) {
    final topicsCount = _topics.length;
    final masteredCount =
        _topics.where((t) => (t['accuracy'] as num) >= 70).length;

    return Row(
      children: [
        Expanded(
            child: _statBox(
                'XP', '${p.xp}', Icons.bolt_rounded, AppTheme.accentGold)),
        const SizedBox(width: 10),
        Expanded(
            child: _statBox('Streak', '${p.streak}d',
                Icons.local_fire_department_rounded, AppTheme.accentOrange)),
        const SizedBox(width: 10),
        Expanded(
            child: _statBox('Topics', '$topicsCount',
                Icons.menu_book_rounded, AppTheme.accentCyan)),
        const SizedBox(width: 10),
        Expanded(
            child: _statBox('Mastered', '$masteredCount',
                Icons.verified_rounded, AppTheme.accentGreen)),
      ],
    );
  }

  Widget _statBox(String label, String value, IconData icon, Color color) {
    return GlassContainer(
      borderColor: color.withAlpha(40),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.orbitron(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label.toUpperCase(),
            style: GoogleFonts.orbitron(
              fontSize: 8,
              color: AppTheme.textTertiary,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.glassBorder),
      ),
      child: TabBar(
        controller: _tabs,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const LinearGradient(
            colors: [AppTheme.accentCyan, AppTheme.accentPurple],
          ),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: AppTheme.textTertiary,
        labelStyle: GoogleFonts.orbitron(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
        tabs: const [
          Tab(text: 'OVERVIEW'),
          Tab(text: 'ACHIEVEMENTS'),
        ],
      ),
    );
  }

  Widget _buildOverviewTab(LocalProfile p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        _sectionLabel('Studied Topics', Icons.history_rounded,
            AppTheme.accentPurple),
        const SizedBox(height: 10),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: CircularProgressIndicator(color: AppTheme.accentCyan),
            ),
          )
        else if (_topics.isEmpty)
          _emptyState('No topics yet',
              'Start a lesson and Gemma will build your local learning memory.')
        else
          ..._topics.map(_buildTopicRow),
        const SizedBox(height: 24),
        _sectionLabel('Interests', Icons.interests_rounded,
            AppTheme.accentCyan),
        const SizedBox(height: 10),
        _buildInterests(p),
      ],
    );
  }

  Widget _buildTopicRow(Map<String, dynamic> t) {
    final name = t['name'] as String? ?? 'Topic';
    final level = t['level'] as String? ?? 'basics';
    final accuracy = (t['accuracy'] as num?)?.toInt() ?? 0;
    final stars = (t['stars'] as num?)?.toInt() ?? 0;

    final color = switch (level) {
      'intermediate' => AppTheme.accentCyan,
      'advanced' => AppTheme.accentPurple,
      _ => AppTheme.accentGreen,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassContainer(
        borderColor: color.withAlpha(40),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withAlpha(25),
              ),
              child: Icon(Icons.book_rounded, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: color.withAlpha(20),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                              color: color.withAlpha(60), width: 0.5),
                        ),
                        child: Text(
                          level.toUpperCase(),
                          style: GoogleFonts.orbitron(
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            color: color,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      ...List.generate(
                        3,
                        (i) => Icon(
                          i < stars ? Icons.star : Icons.star_border,
                          size: 12,
                          color: i < stars
                              ? AppTheme.accentGold
                              : AppTheme.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Text(
              '$accuracy%',
              style: GoogleFonts.orbitron(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: accuracy >= 70
                    ? AppTheme.accentGreen
                    : AppTheme.accentOrange,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInterests(LocalProfile p) {
    if (p.interests.isEmpty) {
      return _emptyState('No interests set',
          'Add topics you\'re curious about — Gemma will tailor lessons.');
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: p.interests
          .map((interest) => Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: AppTheme.accentCyan.withAlpha(20),
                  border: Border.all(
                      color: AppTheme.accentCyan.withAlpha(60), width: 0.6),
                ),
                child: Text(
                  interest,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.accentCyan,
                  ),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildAchievementsTab(LocalProfile p) {
    final mastered =
        _topics.where((t) => (t['accuracy'] as num) >= 70).length;
    final achievements = <_Achievement>[
      _Achievement(
        name: 'First Spark',
        description: 'Complete your first lesson',
        icon: Icons.bolt_rounded,
        color: AppTheme.accentCyan,
        unlocked: _topics.isNotEmpty,
      ),
      _Achievement(
        name: 'Knowledge Seeker',
        description: 'Study 5 different topics',
        icon: Icons.travel_explore_rounded,
        color: AppTheme.accentPurple,
        unlocked: _topics.length >= 5,
        progress: _topics.length / 5,
      ),
      _Achievement(
        name: 'Topic Master',
        description: 'Master 5 topics (70%+ accuracy)',
        icon: Icons.verified_rounded,
        color: AppTheme.accentGreen,
        unlocked: mastered >= 5,
        progress: mastered / 5,
      ),
      _Achievement(
        name: 'Week Warrior',
        description: 'Maintain a 7-day streak',
        icon: Icons.local_fire_department_rounded,
        color: AppTheme.accentOrange,
        unlocked: p.streak >= 7,
        progress: p.streak / 7,
      ),
      _Achievement(
        name: 'XP Hunter',
        description: 'Earn 1000 XP',
        icon: Icons.emoji_events_rounded,
        color: AppTheme.accentGold,
        unlocked: p.xp >= 1000,
        progress: p.xp / 1000,
      ),
      _Achievement(
        name: 'Scholar Elite',
        description: 'Study 25 topics',
        icon: Icons.school_rounded,
        color: AppTheme.accentMagenta,
        unlocked: _topics.length >= 25,
        progress: _topics.length / 25,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.95,
        ),
        itemCount: achievements.length,
        itemBuilder: (_, i) => _buildAchievementCard(achievements[i]),
      ),
    );
  }

  Widget _buildAchievementCard(_Achievement a) {
    final color = a.unlocked ? a.color : AppTheme.textTertiary;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: a.unlocked ? color.withAlpha(15) : Colors.white.withAlpha(5),
        border: Border.all(
            color: a.unlocked ? color.withAlpha(70) : AppTheme.glassBorder,
            width: 0.8),
        boxShadow: a.unlocked
            ? [BoxShadow(color: color.withAlpha(30), blurRadius: 12)]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withAlpha(a.unlocked ? 30 : 15),
            ),
            child: Icon(a.icon, color: color, size: 22),
          ),
          const Spacer(),
          Text(
            a.name,
            style: GoogleFonts.orbitron(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            a.description,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 9,
              color: AppTheme.textTertiary,
              height: 1.3,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (!a.unlocked && a.progress != null) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: a.progress!.clamp(0, 1),
                backgroundColor: Colors.white.withAlpha(15),
                color: a.color,
                minHeight: 3,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.backgroundSecondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SettingsSheet(profile: _profile.currentProfile!),
    );
  }

  Widget _sectionLabel(String text, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Text(
          text.toUpperCase(),
          style: GoogleFonts.orbitron(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _emptyState(String title, String subtitle) {
    return GlassContainer(
      borderColor: AppTheme.glassBorder,
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Text(
            title,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 11,
              color: AppTheme.textTertiary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _Achievement {
  const _Achievement({
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.unlocked,
    this.progress,
  });

  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final bool unlocked;
  final double? progress;
}

// ─────────────────────────────────────────────────────────────────────────
// Settings sheet
// ─────────────────────────────────────────────────────────────────────────

class _SettingsSheet extends StatefulWidget {
  const _SettingsSheet({required this.profile});
  final LocalProfile profile;

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          _row(Icons.edit_rounded, 'Edit profile', AppTheme.accentCyan,
              _openEditProfile),
          _row(Icons.interests_rounded, 'Edit interests',
              AppTheme.accentPurple, _openEditInterests),
          _row(
            Icons.dark_mode_rounded,
            'Toggle theme',
            AppTheme.accentGold,
            () {
              ThemeProvider.instance.toggleTheme();
              Navigator.of(context).pop();
            },
          ),
          _row(Icons.info_outline_rounded, 'About', AppTheme.accentGreen,
              _openAbout),
        ],
      ),
    );
  }

  Widget _row(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                size: 12, color: color.withAlpha(120)),
          ],
        ),
      ),
    );
  }

  void _openEditProfile() {
    Navigator.of(context).pop();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.backgroundSecondary,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _EditProfileSheet(profile: widget.profile),
    );
  }

  void _openEditInterests() {
    Navigator.of(context).pop();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.backgroundSecondary,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _EditInterestsSheet(profile: widget.profile),
    );
  }

  void _openAbout() {
    Navigator.of(context).pop();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.backgroundSecondary,
        title: Text('About',
            style: GoogleFonts.orbitron(color: Colors.white)),
        content: Text(
          'Learnify · Gemma 4 E4B on-device\n\n'
          'All learning happens privately on your phone. '
          'No servers, no cloud, no account needed.',
          style: GoogleFonts.spaceGrotesk(
            color: AppTheme.textSecondary,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK',
                style: GoogleFonts.orbitron(color: AppTheme.accentCyan)),
          ),
        ],
      ),
    );
  }
}

class _EditProfileSheet extends StatefulWidget {
  const _EditProfileSheet({required this.profile});
  final LocalProfile profile;

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final TextEditingController _nameCtrl;
  late String _language;
  late String _grade;

  static const _languages = [
    'English', 'Hindi', 'Spanish', 'French', 'Arabic',
    'Portuguese', 'Bengali', 'Mandarin', 'Swahili', 'Urdu',
  ];

  static const _grades = [
    'Student', 'Grade 6–8', 'Grade 9–10', 'Grade 11–12',
    'College', 'Professional', 'Teacher',
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.profile.name);
    _language = widget.profile.language;
    _grade = widget.profile.grade;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await LocalProfileService.instance.updateProfile(
      name: _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
      language: _language,
      grade: _grade,
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Edit profile',
              style: GoogleFonts.orbitron(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              )),
          const SizedBox(height: 16),
          TextField(
            controller: _nameCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration('Name'),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _language,
            dropdownColor: AppTheme.surfaceDark,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration('Language'),
            items: _languages
                .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                .toList(),
            onChanged: (v) => setState(() => _language = v ?? _language),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _grade,
            dropdownColor: AppTheme.surfaceDark,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration('Grade'),
            items: _grades
                .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                .toList(),
            onChanged: (v) => setState(() => _grade = v ?? _grade),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentCyan,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('SAVE',
                  style: GoogleFonts.orbitron(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  )),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: Colors.white.withAlpha(15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: AppTheme.accentCyan, width: 1.5),
        ),
      );
}

class _EditInterestsSheet extends StatefulWidget {
  const _EditInterestsSheet({required this.profile});
  final LocalProfile profile;

  @override
  State<_EditInterestsSheet> createState() => _EditInterestsSheetState();
}

class _EditInterestsSheetState extends State<_EditInterestsSheet> {
  late List<String> _interests;
  final _ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _interests = List<String>.from(widget.profile.interests);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _add() {
    final v = _ctrl.text.trim();
    if (v.isEmpty || _interests.contains(v)) return;
    setState(() {
      _interests.add(v);
      _ctrl.clear();
    });
  }

  Future<void> _save() async {
    await LocalProfileService.instance.updateProfile(interests: _interests);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Interests',
              style: GoogleFonts.orbitron(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              )),
          const SizedBox(height: 6),
          Text('Gemma will tailor lessons based on these.',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 12,
                color: AppTheme.textSecondary,
              )),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'e.g. astronomy, football, biology',
                    hintStyle: const TextStyle(color: Colors.white30),
                    filled: true,
                    fillColor: Colors.white.withAlpha(15),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.white12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.white12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: AppTheme.accentCyan, width: 1.5),
                    ),
                  ),
                  onSubmitted: (_) => _add(),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _add,
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: AppTheme.accentCyan.withAlpha(30),
                    border: Border.all(
                        color: AppTheme.accentCyan.withAlpha(100)),
                  ),
                  child: const Icon(Icons.add_rounded,
                      color: AppTheme.accentCyan),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _interests
                .map((i) => Chip(
                      label: Text(i,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 11,
                            color: AppTheme.accentCyan,
                          )),
                      backgroundColor: AppTheme.accentCyan.withAlpha(20),
                      side: BorderSide(
                          color: AppTheme.accentCyan.withAlpha(60)),
                      deleteIcon: const Icon(Icons.close, size: 14),
                      deleteIconColor: AppTheme.accentCyan,
                      onDeleted: () =>
                          setState(() => _interests.remove(i)),
                    ))
                .toList(),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentCyan,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('SAVE',
                  style: GoogleFonts.orbitron(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  )),
            ),
          ),
        ],
      ),
    );
  }
}
