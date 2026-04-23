import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/ai/gemma_orchestrator.dart';
import '../../../core/services/local_memory_service.dart';
import '../../../core/services/local_profile_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../core/widgets/neon_button.dart';
import '../../../core/widgets/particle_background.dart';
import '../../courses/data/course_data.dart';
import '../../story_learning/models/story_style.dart';

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
  final _memory = LocalMemoryService.instance;
  final _orchestrator = GemmaOrchestrator.instance;

  List<Map<String, dynamic>> _studiedTopics = [];
  String? _studyPulse;
  bool _pulseLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _profile.addListener(_onProfileChanged);
    _loadTopics();
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
    if (state == AppLifecycleState.resumed) _loadTopics();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadTopics();
  }

  void _onProfileChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadTopics() async {
    final topics = await _memory.getAllTopicProgress();
    if (mounted) setState(() => _studiedTopics = topics);
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
    await _loadTopics();
    await _loadStudyPulse();
  }

  String get _displayName => _profile.currentProfile?.name ?? 'Learner';
  int get _xp => _profile.currentProfile?.xp ?? 0;
  int get _streak => _profile.currentProfile?.streak ?? 0;

  void _launchCustomTopic() {
    final topic = _topicCtrl.text.trim();
    if (topic.isEmpty) return;
    context.push('/topic-explorer', extra: {'topic': topic});
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
                const SizedBox(height: 22),
                _buildStyleGrid()
                    .animate()
                    .fadeIn(delay: 240.ms, duration: 600.ms),
                const SizedBox(height: 22),
                _buildSubjectsSection()
                    .animate()
                    .fadeIn(delay: 300.ms, duration: 600.ms),
                const SizedBox(height: 20),
                _buildYourTopics()
                    .animate()
                    .fadeIn(delay: 360.ms, duration: 600.ms),
                const SizedBox(height: 20),
                _buildUtilityRow()
                    .animate()
                    .fadeIn(delay: 420.ms, duration: 600.ms),
                const SizedBox(height: 18),
                _buildTeacherCopilotCard()
                    .animate()
                    .fadeIn(delay: 480.ms, duration: 600.ms),
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
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _iconBtn(Icons.search_rounded, AppTheme.accentCyan,
                    () => context.push('/search')),
                const SizedBox(width: 6),
                _iconBtn(Icons.dark_mode_rounded, AppTheme.accentPurple,
                    () => ThemeProvider.instance.toggleTheme()),
              ],
            ),
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
                      Text(
                        'SCAN TEXTBOOK',
                        style: GoogleFonts.orbitron(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 2,
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

  // ── Style grid (6 narrative styles) ────────────────────────────────────────

  Widget _buildStyleGrid() {
    final styles = StoryStyle.values;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Learning Styles', Icons.palette_rounded,
            AppTheme.accentGold, 'Pick how Gemma explains — switch anytime'),
        const SizedBox(height: 12),
        SizedBox(
          height: 110,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: styles.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) => _buildStyleTile(styles[i]),
          ),
        ),
      ],
    );
  }

  Widget _buildStyleTile(StoryStyle style) {
    return GestureDetector(
      onTap: () {
        // Open topic input prefilled with a sample — user replaces it
        showModalBottomSheet(
          context: context,
          backgroundColor: AppTheme.backgroundSecondary,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (_) => _StylePickerSheet(style: style),
        );
      },
      child: Container(
        width: 130,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: style.color.withAlpha(18),
          border: Border.all(color: style.color.withAlpha(60), width: 0.8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(style.icon, color: style.color, size: 22),
            const Spacer(),
            Text(
              style.label.toUpperCase(),
              style: GoogleFonts.orbitron(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: style.color,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              style.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 9,
                color: AppTheme.textTertiary,
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Subjects ────────────────────────────────────────────────────────────────

  Widget _buildSubjectsSection() {
    final courses = CourseData.allCourses;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Explore Subjects', Icons.menu_book_rounded,
            AppTheme.accentCyan, 'Curated chapters + AI-generated lessons',
            trailingTap: () => context.push('/courses')),
        const SizedBox(height: 12),
        SizedBox(
          height: 140,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: courses.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) => _buildSubjectCard(courses[i]),
          ),
        ),
      ],
    );
  }

  Widget _buildSubjectCard(CourseSubject course) {
    final lessonCount = course.chapters
        .fold<int>(0, (total, ch) => total + ch.lessons.length);
    final color = course.accentColor;

    return GestureDetector(
      onTap: () {
        if (course.chapters.isNotEmpty &&
            course.chapters.first.lessons.isNotEmpty) {
          final chapter = course.chapters.first;
          final lesson = chapter.lessons.first;
          context.push('/lesson', extra: {
            'subjectId': course.id,
            'chapterId': chapter.id,
            'lessonId': lesson.id,
          });
        } else {
          context.push('/lesson', extra: {'customTopic': course.name});
        }
      },
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: color.withAlpha(15),
          border: Border.all(color: color.withAlpha(50), width: 0.8),
          boxShadow: [
            BoxShadow(color: color.withAlpha(15), blurRadius: 12),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withAlpha(30),
                  ),
                  child: Icon(
                    course.id == 'physics'
                        ? Icons.blur_circular
                        : course.id == 'math'
                            ? Icons.functions
                            : Icons.school,
                    color: color,
                    size: 18,
                  ),
                ),
                const Spacer(),
                if (course.chapters.isEmpty) _pill('AI', AppTheme.accentCyan),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              course.name,
              style: GoogleFonts.orbitron(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              '${course.chapters.length} chapters  ·  $lessonCount lessons',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 9,
                color: AppTheme.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Your topics ────────────────────────────────────────────────────────────

  Widget _buildYourTopics() {
    final topics = _studiedTopics;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          'Your Topics',
          Icons.history_rounded,
          AppTheme.accentPurple,
          topics.isEmpty
              ? 'Studied topics will appear here'
              : '${topics.length} topic${topics.length == 1 ? '' : 's'} in memory',
          trailingTap: topics.isEmpty ? null : () => context.push('/topics'),
        ),
        const SizedBox(height: 10),
        if (topics.isEmpty)
          GlassContainer(
            borderColor: AppTheme.accentPurple.withAlpha(40),
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Icon(Icons.school_rounded,
                    color: AppTheme.accentPurple.withAlpha(120), size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Start any lesson — Gemma builds a local learning memory for you.',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          SizedBox(
            height: 130,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: topics.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) => _buildTopicCard(topics[i]),
            ),
          ),
      ],
    );
  }

  Widget _buildTopicCard(Map<String, dynamic> topic) {
    final name = topic['name'] as String? ?? 'Topic';
    final level = topic['level'] as String? ?? 'basics';
    final accuracy = (topic['accuracy'] as num?)?.toInt() ?? 0;
    final stars = (topic['stars'] as num?)?.toInt() ?? 0;

    final color = switch (level) {
      'intermediate' => AppTheme.accentCyan,
      'advanced' => AppTheme.accentPurple,
      _ => AppTheme.accentGreen,
    };

    return GlassContainer(
      width: 170,
      borderColor: color.withAlpha(50),
      padding: const EdgeInsets.all(12),
      onTap: () => context.push('/lesson', extra: {
        'customTopic': name,
        'level': level,
      }),
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
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              color: color.withAlpha(20),
              border: Border.all(color: color.withAlpha(50), width: 0.5),
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
          const SizedBox(height: 6),
          Row(
            children: [
              ...List.generate(
                3,
                (i) => Icon(
                  i < stars ? Icons.star : Icons.star_border,
                  size: 14,
                  color: i < stars
                      ? AppTheme.accentGold
                      : AppTheme.textTertiary,
                ),
              ),
              const Spacer(),
              Text(
                '$accuracy%',
                style: GoogleFonts.orbitron(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: accuracy >= 70
                      ? AppTheme.accentGreen
                      : AppTheme.accentOrange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Utility row: Concept Map + Skill Tree ──────────────────────────────────

  Widget _buildUtilityRow() {
    return Row(
      children: [
        Expanded(
          child: _utilityTile(
            label: 'Concept Map',
            icon: Icons.hub_rounded,
            color: AppTheme.accentPurple,
            onTap: () => context.push('/concept-map'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _utilityTile(
            label: 'Skill Tree',
            icon: Icons.account_tree_rounded,
            color: AppTheme.accentGreen,
            onTap: () => context.push('/skill-tree'),
          ),
        ),
      ],
    );
  }

  Widget _utilityTile({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GlassContainer(
      borderColor: color.withAlpha(50),
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.orbitron(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  // ── Teacher Copilot entry ──────────────────────────────────────────────────

  Widget _buildTeacherCopilotCard() {
    return GestureDetector(
      onTap: () => context.push('/teacher'),
      child: GlassContainer(
        borderColor: AppTheme.accentGold.withAlpha(50),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  colors: [
                    AppTheme.accentGold.withAlpha(60),
                    AppTheme.accentOrange.withAlpha(40),
                  ],
                ),
                border:
                    Border.all(color: AppTheme.accentGold.withAlpha(80)),
              ),
              child: const Icon(Icons.school_rounded,
                  color: AppTheme.accentGold, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TEACHER COPILOT',
                    style: GoogleFonts.orbitron(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.accentGold,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Generate quizzes, worksheets & lesson plans',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                color: AppTheme.accentGold.withAlpha(120), size: 14),
          ],
        ),
      ),
    );
  }

  // ── Shared header ─────────────────────────────────────────────────────────

  Widget _sectionHeader(
    String title,
    IconData icon,
    Color color,
    String subtitle, {
    VoidCallback? trailingTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(
              title.toUpperCase(),
              style: GoogleFonts.orbitron(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
                letterSpacing: 1.2,
              ),
            ),
            const Spacer(),
            if (trailingTap != null)
              GestureDetector(
                onTap: trailingTap,
                child: Text(
                  'See All',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 11,
                    color: color.withAlpha(180),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 11,
            color: AppTheme.textTertiary,
          ),
        ),
      ],
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

// ─────────────────────────────────────────────────────────────────────────────
// Style picker bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

class _StylePickerSheet extends StatefulWidget {
  const _StylePickerSheet({required this.style});
  final StoryStyle style;

  @override
  State<_StylePickerSheet> createState() => _StylePickerSheetState();
}

class _StylePickerSheetState extends State<_StylePickerSheet> {
  final _topicCtrl = TextEditingController();
  final _franchiseCtrl = TextEditingController();

  @override
  void dispose() {
    _topicCtrl.dispose();
    _franchiseCtrl.dispose();
    super.dispose();
  }

  void _launch() {
    final topic = _topicCtrl.text.trim();
    if (topic.isEmpty) return;
    Navigator.of(context).pop();
    context.push('/lesson', extra: {
      'customTopic': topic,
      'preselectedStyle': widget.style.promptKey,
      'franchiseName': _franchiseCtrl.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.style;
    final needsFranchise = style == StoryStyle.movieTv;

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
          Row(
            children: [
              Icon(style.icon, color: style.color, size: 24),
              const SizedBox(width: 10),
              Text(
                style.label,
                style: GoogleFonts.orbitron(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            style.description,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _topicCtrl,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Topic (e.g. Photosynthesis)',
              hintStyle: const TextStyle(color: Colors.white30),
              filled: true,
              fillColor: Colors.white.withAlpha(15),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: style.color.withAlpha(60)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: style.color.withAlpha(60)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: style.color, width: 1.5),
              ),
            ),
          ),
          if (needsFranchise) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _franchiseCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Franchise (e.g. Harry Potter, Naruto)',
                hintStyle: const TextStyle(color: Colors.white30),
                filled: true,
                fillColor: Colors.white.withAlpha(15),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: style.color.withAlpha(60)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: style.color.withAlpha(60)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: style.color, width: 1.5),
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: NeonButton(
              label: 'GENERATE LESSON',
              icon: Icons.auto_awesome,
              colors: [style.color, AppTheme.accentCyan],
              height: 46,
              onTap: _launch,
            ),
          ),
        ],
      ),
    );
  }
}
