import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/ai/gemma_orchestrator.dart';
import '../../../core/services/local_profile_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../core/widgets/particle_background.dart';

// ─────────────────────────────────────────────────────────────────────────────
// HomeScreen — Shell with 3-tab glass bottom nav
// ─────────────────────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.child});
  final Widget child;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _tabs = <_NavTab>[
    _NavTab(icon: Icons.dashboard_rounded, label: 'Home', path: '/home'),
    _NavTab(
        icon: Icons.psychology_rounded,
        label: 'Companion',
        path: '/home/companion'),
    _NavTab(
        icon: Icons.person_rounded, label: 'Profile', path: '/home/profile'),
  ];

  int get _currentIndex {
    final loc = GoRouterState.of(context).uri.toString();
    for (var i = 0; i < _tabs.length; i++) {
      if (loc == _tabs[i].path) return i;
    }
    return 0;
  }

  void _onTabTap(int index) {
    if (index == _currentIndex) return;
    context.go(_tabs[index].path);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: AppTheme.backgroundGradient,
            ),
          ),
          widget.child,
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomNav(),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final current = _currentIndex;

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.only(
            top: 10,
            bottom: bottomPadding + 10,
            left: 8,
            right: 8,
          ),
          decoration: BoxDecoration(
            color: AppTheme.backgroundPrimary.withAlpha(180),
            border: Border(
              top: BorderSide(color: AppTheme.glassBorder, width: 0.5),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_tabs.length, (i) {
              final isSelected = i == current;
              return _buildNavItem(_tabs[i], isSelected, () => _onTabTap(i));
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(_NavTab tab, bool isSelected, VoidCallback onTap) {
    final color = isSelected ? AppTheme.accentCyan : AppTheme.textTertiary;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: isSelected
                  ? BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.accentCyan.withAlpha(90),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    )
                  : null,
              child: Icon(tab.icon, color: color, size: 24),
            ),
            const SizedBox(height: 4),
            Text(
              tab.label,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavTab {
  const _NavTab({required this.icon, required this.label, required this.path});
  final IconData icon;
  final String label;
  final String path;
}

// ─────────────────────────────────────────────────────────────────────────────
// HomeDashboard — on-device, profile-driven
// ─────────────────────────────────────────────────────────────────────────────

class HomeDashboard extends StatefulWidget {
  const HomeDashboard({super.key});

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard>
    with WidgetsBindingObserver {
  final _topicCtrl = TextEditingController();
  final _profile = LocalProfileService.instance;
  final _orchestrator = GemmaOrchestrator.instance;

  String? _studyPulse;
  bool _pulseLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _profile.addListener(_onProfileChanged);
    _loadStudyPulse();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _profile.removeListener(_onProfileChanged);
    _topicCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadStudyPulse();
  }

  void _onProfileChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadStudyPulse() async {
    if (!mounted) return;
    setState(() => _pulseLoading = true);
    try {
      final pulse = await _orchestrator.getStudyPulse();
      if (mounted) {
        setState(() {
          _studyPulse = pulse;
          _pulseLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _studyPulse =
              'Start your first lesson — I\'ll begin building your learning twin.';
          _pulseLoading = false;
        });
      }
    }
  }

  Future<void> _refresh() async {
    await _loadStudyPulse();
  }

  String get _displayName => _profile.currentProfile?.name ?? 'Learner';
  int get _xp => _profile.currentProfile?.xp ?? 0;
  int get _streak => _profile.currentProfile?.streak ?? 0;

  void _launchCustomTopic() {
    final topic = _topicCtrl.text.trim();
    if (topic.isEmpty) return;
    context.push('/lesson', extra: {'customTopic': topic});
    _topicCtrl.clear();
  }

  void _launchMasteryPath() {
    final topic = _topicCtrl.text.trim();
    if (topic.isEmpty) return;
    context.push('/mastery-path', extra: {'topic': topic});
    _topicCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom + 90;

    return Stack(
      children: [
        const ParticleBackground(
          particleCount: 40,
          particleColor: AppTheme.accentPurple,
          maxRadius: 1.2,
        ),
        SafeArea(
          bottom: false,
          child: RefreshIndicator(
            onRefresh: _refresh,
            color: AppTheme.accentCyan,
            backgroundColor: AppTheme.surfaceDark,
            child: ListView(
              padding: EdgeInsets.fromLTRB(20, 16, 20, bottomPadding),
              children: [
                _buildWelcomeHeader()
                    .animate()
                    .fadeIn(duration: 500.ms)
                    .slideX(begin: -0.05, duration: 500.ms),
                if (_profile.currentProfile?.needsMoodCheckIn ?? false) ...[
                  const SizedBox(height: 16),
                  _buildMoodCheckInCard()
                      .animate()
                      .fadeIn(delay: 30.ms, duration: 500.ms)
                      .slideY(begin: 0.04, duration: 500.ms),
                ],
                const SizedBox(height: 20),
                _buildHeroLearnCard()
                    .animate()
                    .fadeIn(delay: 60.ms, duration: 600.ms)
                    .slideY(begin: 0.04, duration: 600.ms),
                const SizedBox(height: 18),
                _buildScanTextbookCard()
                    .animate()
                    .fadeIn(delay: 120.ms, duration: 600.ms)
                    .slideY(begin: 0.04, duration: 600.ms),
                const SizedBox(height: 18),
                _buildStudyPulseCard()
                    .animate()
                    .fadeIn(delay: 180.ms, duration: 600.ms)
                    .slideY(begin: 0.04, duration: 600.ms),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Welcome header ─────────────────────────────────────────────────────────

  Widget _buildWelcomeHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hey, $_displayName',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              ShaderMask(
                shaderCallback: (b) =>
                    AppTheme.primaryGradient.createShader(b),
                child: Text(
                  'What do you want\nto learn today?',
                  style: GoogleFonts.orbitron(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 1,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _iconBtn(Icons.dark_mode_rounded, AppTheme.accentPurple,
                () => ThemeProvider.instance.toggleTheme()),
            const SizedBox(height: 6),
            _statChip(Icons.bolt_rounded, '$_xp XP', AppTheme.accentGold),
            const SizedBox(height: 6),
            _statChip(Icons.local_fire_department_rounded,
                '$_streak day', AppTheme.accentOrange),
          ],
        ),
      ],
    );
  }

  Widget _iconBtn(IconData icon, Color color, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withAlpha(15),
            border: Border.all(color: color.withAlpha(60)),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
      );

  Widget _statChip(IconData icon, String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withAlpha(60), width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.orbitron(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      );

  // ── Mood check-in card (daily, dismissable) ────────────────────────────────

  static const _moods = <_MoodOption>[
    _MoodOption('calm', '🧘', 'Calm', AppTheme.accentCyan),
    _MoodOption('hyped', '⚡', 'Hyped', AppTheme.accentGold),
    _MoodOption('curious', '🔍', 'Curious', AppTheme.accentPurple),
    _MoodOption('anxious', '😰', 'Anxious', AppTheme.accentOrange),
    _MoodOption('sad', '💙', 'Low', AppTheme.accentGreen),
  ];

  Future<void> _setMood(String mood) async {
    await _profile.setMood(mood);
    if (mounted) setState(() {});
  }

  Widget _buildMoodCheckInCard() {
    return GlassContainer(
      borderColor: AppTheme.accentPurple.withAlpha(80),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.psychology_alt_rounded,
                  color: AppTheme.accentPurple, size: 18),
              const SizedBox(width: 8),
              Text(
                'HOW ARE YOU FEELING?',
                style: GoogleFonts.orbitron(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.accentPurple,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            "Tell me your mood — I'll match the lesson tone today.",
            style: GoogleFonts.spaceGrotesk(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final m in _moods) ...[
                Expanded(
                  child: GestureDetector(
                    onTap: () => _setMood(m.id),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: m.color.withAlpha(22),
                        borderRadius: BorderRadius.circular(10),
                        border:
                            Border.all(color: m.color.withAlpha(80), width: 0.7),
                      ),
                      child: Column(
                        children: [
                          Text(m.emoji, style: const TextStyle(fontSize: 22)),
                          const SizedBox(height: 4),
                          Text(
                            m.label,
                            style: GoogleFonts.orbitron(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: m.color,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (m != _moods.last) const SizedBox(width: 6),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ── Hero card: Learn Anything ──────────────────────────────────────────────

  Widget _buildHeroLearnCard() {
    return GlassContainer(
      borderColor: AppTheme.accentCyan.withAlpha(60),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: const LinearGradient(
                    colors: [AppTheme.accentCyan, AppTheme.accentPurple],
                  ),
                ),
                child: const Icon(Icons.auto_awesome,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'LEARN ANYTHING',
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.orbitron(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.accentCyan,
                    letterSpacing: 2,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              _pill('ON-DEVICE', AppTheme.accentGreen),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Type any topic. Gemma 4 crafts a story lesson — fully offline.',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 12,
              color: AppTheme.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _topicCtrl,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 14,
                    color: AppTheme.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'e.g. Photosynthesis, Blockchain, WW2…',
                    hintStyle: GoogleFonts.spaceGrotesk(
                      fontSize: 12,
                      color: AppTheme.textTertiary,
                    ),
                    filled: true,
                    fillColor: Colors.white.withAlpha(8),
                    prefixIcon: Icon(Icons.search,
                        color: AppTheme.accentCyan.withAlpha(140), size: 20),
                    border: _border(AppTheme.accentCyan.withAlpha(50)),
                    enabledBorder: _border(AppTheme.accentCyan.withAlpha(50)),
                    focusedBorder:
                        _border(AppTheme.accentCyan, width: 1.5),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                  textInputAction: TextInputAction.go,
                  onSubmitted: (_) => _launchCustomTopic(),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _launchCustomTopic,
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: const LinearGradient(
                      colors: [AppTheme.accentPurple, AppTheme.accentCyan],
                    ),
                  ),
                  child: const Icon(Icons.arrow_forward_rounded,
                      color: Colors.white, size: 22),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _launchMasteryPath,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.route_rounded,
                    size: 14, color: AppTheme.accentCyan.withAlpha(200)),
                const SizedBox(width: 6),
                Text(
                  'Build mastery path instead →',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.accentCyan,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  OutlineInputBorder _border(Color c, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c, width: width),
      );

  // ── Scan Textbook (multimodal wow) ─────────────────────────────────────────

  Widget _buildScanTextbookCard() {
    return GestureDetector(
      onTap: () => context.push('/scan'),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [
              AppTheme.accentPurple.withAlpha(50),
              AppTheme.accentCyan.withAlpha(30),
            ],
          ),
          border: Border.all(color: AppTheme.accentPurple.withAlpha(120)),
          boxShadow: [
            BoxShadow(
              color: AppTheme.accentPurple.withAlpha(40),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(
                  colors: [AppTheme.accentPurple, AppTheme.accentMagenta],
                ),
              ),
              child: const Icon(Icons.document_scanner_rounded,
                  color: Colors.white, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          'SCAN TEXTBOOK',
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.orbitron(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      _pill('NEW', AppTheme.accentGold),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Photograph any page — Gemma reads it & teaches it.',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 12,
                      color: Colors.white.withAlpha(220),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.white70, size: 14),
          ],
        ),
      ),
    );
  }

  // ── Study Pulse (Learner Twin) ─────────────────────────────────────────────

  Widget _buildStudyPulseCard() {
    return GlassContainer(
      borderColor: AppTheme.accentPurple.withAlpha(50),
      padding: const EdgeInsets.all(14),
      onTap: () => context.go('/home/companion'),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: const LinearGradient(
                colors: [AppTheme.accentCyan, AppTheme.accentPurple],
              ),
            ),
            child: const Icon(Icons.psychology_rounded,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'STUDY PULSE',
                      style: GoogleFonts.orbitron(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.accentPurple,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(width: 6),
                    _pill('TWIN', AppTheme.accentCyan),
                  ],
                ),
                const SizedBox(height: 4),
                if (_pulseLoading)
                  Container(
                    height: 12,
                    width: 200,
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceLight,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  )
                else
                  Text(
                    _studyPulse ?? 'Tap to open your AI companion',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios_rounded,
              color: AppTheme.accentPurple.withAlpha(120), size: 14),
        ],
      ),
    );
  }


  Widget _pill(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: color.withAlpha(25),
          border: Border.all(color: color.withAlpha(80), width: 0.6),
        ),
        child: Text(
          label,
          style: GoogleFonts.orbitron(
            fontSize: 8,
            fontWeight: FontWeight.w700,
            color: color,
            letterSpacing: 1,
          ),
        ),
      );
}

class _MoodOption {
  const _MoodOption(this.id, this.emoji, this.label, this.color);
  final String id;
  final String emoji;
  final String label;
  final Color color;
}
