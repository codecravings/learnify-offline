import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/services/local_profile_service.dart';
import '../data/course_data.dart';

// ─────────────────────────────────────────────────────────────────────────────
// LessonScreen – THE CORE GAMIFIED LEARNING EXPERIENCE
//
// Three-phase game level:
//   1. Content Phase  – Swipeable cards teaching the concept
//   2. Quiz Phase     – Interactive questions with instant feedback
//   3. Results Phase  – Animated score, XP, stars, celebration
//
// Design: Deep space dark + glassmorphism + neon accents + particles
// ─────────────────────────────────────────────────────────────────────────────

class LessonScreen extends StatefulWidget {
  final String subjectId;
  final String chapterId;
  final String lessonId;

  const LessonScreen({
    super.key,
    required this.subjectId,
    required this.chapterId,
    required this.lessonId,
  });

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen>
    with TickerProviderStateMixin {
  // ── constants ──────────────────────────────────────────────────────────────
  static const Color _bg = Color(0xFF111827);
  static const Color _bgSecondary = Color(0xFF1F2937);
  static const Color _surfaceDark = Color(0xFF1F2937);
  static const Color _glassBorder = Color(0x33FFFFFF);
  static const Color _textPrimary = Color(0xFFF0F0F0);
  static const Color _textSecondary = Color(0xFFB0B0C8);
  static const Color _textTertiary = Color(0xFF6B6B8A);
  static const Color _green = Color(0xFF22C55E);
  static const Color _red = Color(0xFFEF4444);
  static const Color _gold = Color(0xFFF59E0B);
  static const Color _cyan = Color(0xFF3B82F6);
  static const Color _purple = Color(0xFF8B5CF6);

  // ── data ───────────────────────────────────────────────────────────────────
  late final CourseSubject _subject;
  late final CourseChapter _chapter;
  late final Lesson _lesson;
  late final Color _accent;

  // ── phase management ───────────────────────────────────────────────────────
  // 0 = content, 1 = quiz, 2 = results
  int _phase = 0;

  // ── content phase ──────────────────────────────────────────────────────────
  late final PageController _contentPageCtrl;
  int _currentContentPage = 0;

  // ── quiz phase ─────────────────────────────────────────────────────────────
  int _currentQuestion = 0;
  int _correctCount = 0;
  int? _selectedOption;
  bool _answered = false;
  bool _showExplanation = false;

  // ── results phase ──────────────────────────────────────────────────────────
  bool _resultsSaved = false;

  // ── animation controllers ──────────────────────────────────────────────────
  late final AnimationController _particleCtrl;
  late final AnimationController _pulseCtrl;
  late final AnimationController _celebrationCtrl;
  late final AnimationController _xpCountCtrl;
  late final AnimationController _starCtrl;
  late final AnimationController _scoreCountCtrl;

  late final Animation<double> _xpCountAnim;
  late final Animation<double> _scoreCountAnim;

  // ── particles ──────────────────────────────────────────────────────────────
  late final List<_FloatingParticle> _particles;
  late final List<_CelebrationParticle> _celebrationParticles;

  // ─── lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    // Look up lesson data
    _subject = CourseData.allCourses.firstWhere((s) => s.id == widget.subjectId);
    _chapter = _subject.chapters.firstWhere((c) => c.id == widget.chapterId);
    _lesson = _chapter.lessons.firstWhere((l) => l.id == widget.lessonId);
    _accent = _subject.accentColor;

    _contentPageCtrl = PageController();

    // Background particle field
    _particleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat();

    // Ambient pulse glow
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    // Celebration confetti
    _celebrationCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );

    // XP counter animation
    _xpCountCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _xpCountAnim = CurvedAnimation(
      parent: _xpCountCtrl,
      curve: Curves.easeOutCubic,
    );

    // Score counter animation
    _scoreCountCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _scoreCountAnim = CurvedAnimation(
      parent: _scoreCountCtrl,
      curve: Curves.easeOutCubic,
    );

    // Star reveal animation
    _starCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Generate ambient particles
    final rng = Random(42);
    _particles = List.generate(60, (_) {
      return _FloatingParticle(
        x: rng.nextDouble(),
        y: rng.nextDouble(),
        radius: 0.3 + rng.nextDouble() * 1.8,
        alpha: 0.05 + rng.nextDouble() * 0.3,
        dx: (rng.nextDouble() - 0.5) * 0.2,
        dy: (rng.nextDouble() - 0.5) * 0.2,
        twinklePhase: rng.nextDouble() * 2 * pi,
      );
    });

    // Generate celebration particles
    _celebrationParticles = List.generate(80, (_) {
      return _CelebrationParticle(
        startX: 0.3 + rng.nextDouble() * 0.4,
        startY: 0.3 + rng.nextDouble() * 0.2,
        dx: (rng.nextDouble() - 0.5) * 2.0,
        dy: -0.5 - rng.nextDouble() * 1.5,
        gravity: 0.8 + rng.nextDouble() * 0.6,
        rotation: rng.nextDouble() * 2 * pi,
        rotationSpeed: (rng.nextDouble() - 0.5) * 8,
        size: 3 + rng.nextDouble() * 5,
        colorIndex: rng.nextInt(6),
        shape: rng.nextInt(3),
      );
    });
  }

  @override
  void dispose() {
    _contentPageCtrl.dispose();
    _particleCtrl.dispose();
    _pulseCtrl.dispose();
    _celebrationCtrl.dispose();
    _xpCountCtrl.dispose();
    _starCtrl.dispose();
    _scoreCountCtrl.dispose();
    super.dispose();
  }

  // ── computed values ────────────────────────────────────────────────────────

  int get _totalQuestions => _lesson.quiz.length;
  bool get _isPerfect => _correctCount == _totalQuestions;
  int get _xpEarned {
    if (_totalQuestions == 0) return _lesson.xpReward;
    final ratio = _correctCount / _totalQuestions;
    final base = _lesson.xpReward;
    if (ratio >= 1.0) return (base * 1.5).round(); // perfect bonus
    if (ratio >= 0.66) return base;
    if (ratio >= 0.33) return (base * 0.7).round();
    return (base * 0.4).round();
  }

  int get _starRating {
    if (_totalQuestions == 0) return 3;
    final ratio = _correctCount / _totalQuestions;
    if (ratio >= 1.0) return 3;
    if (ratio >= 0.66) return 2;
    return 1;
  }

  // ── phase transitions ──────────────────────────────────────────────────────

  void _goToQuizPhase() {
    setState(() => _phase = 1);
  }

  void _goToResultsPhase() {
    setState(() => _phase = 2);
    // Start results animations in sequence
    _startResultsAnimations();
  }

  Future<void> _startResultsAnimations() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    _scoreCountCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    _xpCountCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    _starCtrl.forward();
    if (_isPerfect) {
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      _celebrationCtrl.repeat();
    }
  }

  Future<void> _saveProgressAndExit() async {
    if (_resultsSaved) {
      if (mounted) context.pop();
      return;
    }
    setState(() => _resultsSaved = true);

    try {
      await LocalProfileService.instance.addXP(_xpEarned);
    } catch (_) {}

    if (mounted) context.pop();
  }

  // ── quiz logic ─────────────────────────────────────────────────────────────

  void _selectOption(int index) {
    if (_answered) return;

    final question = _lesson.quiz[_currentQuestion];
    final isCorrect = index == question.correctIndex;

    setState(() {
      _selectedOption = index;
      _answered = true;
      _showExplanation = true;
      if (isCorrect) _correctCount++;
    });
  }

  void _nextQuestion() {
    if (_currentQuestion + 1 >= _totalQuestions) {
      _goToResultsPhase();
    } else {
      setState(() {
        _currentQuestion++;
        _selectedOption = null;
        _answered = false;
        _showExplanation = false;
      });
    }
  }

  // ─── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          // Layer 0: Gradient background
          _buildBackground(),

          // Layer 1: Floating particles
          _buildParticleField(),

          // Layer 2: Ambient glow orbs
          _buildAmbientGlows(),

          // Layer 3: Main content
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                Expanded(child: _buildPhaseContent()),
              ],
            ),
          ),

          // Layer 4: Celebration confetti overlay
          if (_phase == 2 && _isPerfect) _buildCelebrationOverlay(),
        ],
      ),
    );
  }

  // ─── background layers ─────────────────────────────────────────────────────

  Widget _buildBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _bg,
            _bgSecondary,
            _surfaceDark,
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
    );
  }

  Widget _buildParticleField() {
    return AnimatedBuilder(
      animation: _particleCtrl,
      builder: (context, _) {
        return CustomPaint(
          size: MediaQuery.of(context).size,
          painter: _ParticleFieldPainter(
            particles: _particles,
            progress: _particleCtrl.value,
            color: _accent,
          ),
        );
      },
    );
  }

  Widget _buildAmbientGlows() {
    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (context, _) {
        final pulse = _pulseCtrl.value;
        return Stack(
          children: [
            // Top-right glow
            Positioned(
              top: -80,
              right: -60,
              child: Container(
                width: 200 + pulse * 40,
                height: 200 + pulse * 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _accent.withAlpha((20 + pulse * 15).round()),
                      _accent.withAlpha(0),
                    ],
                  ),
                ),
              ),
            ),
            // Bottom-left glow
            Positioned(
              bottom: -100,
              left: -80,
              child: Container(
                width: 250 + pulse * 30,
                height: 250 + pulse * 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _accent.withAlpha((10 + pulse * 10).round()),
                      _accent.withAlpha(0),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCelebrationOverlay() {
    return AnimatedBuilder(
      animation: _celebrationCtrl,
      builder: (context, _) {
        return CustomPaint(
          size: MediaQuery.of(context).size,
          painter: _CelebrationPainter(
            particles: _celebrationParticles,
            progress: _celebrationCtrl.value,
            colors: [_cyan, _purple, _green, _gold, _red, const Color(0xFFFF8C00)],
          ),
        );
      },
    );
  }

  // ─── top bar ───────────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withAlpha(13),
                border: Border.all(color: _glassBorder, width: 0.5),
              ),
              child: Icon(Icons.arrow_back_rounded, color: _accent, size: 20),
            ),
          ),
          const SizedBox(width: 12),

          // Lesson title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _lesson.title,
                  style: GoogleFonts.orbitron(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                    letterSpacing: 0.8,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _chapter.title,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 11,
                    color: _textTertiary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Phase indicator
          _buildPhaseIndicator(),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.3, duration: 400.ms);
  }

  Widget _buildPhaseIndicator() {
    final labels = ['LEARN', 'QUIZ', 'DONE'];
    final icons = [Icons.auto_stories_rounded, Icons.quiz_rounded, Icons.emoji_events_rounded];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: _accent.withAlpha(20),
        border: Border.all(color: _accent.withAlpha(60), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icons[_phase], color: _accent, size: 14),
          const SizedBox(width: 4),
          Text(
            labels[_phase],
            style: GoogleFonts.orbitron(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: _accent,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ─── phase router ─────────────────────────────────────────────────────────

  Widget _buildPhaseContent() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.05, 0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: switch (_phase) {
        0 => _buildContentPhase(),
        1 => _buildQuizPhase(),
        2 => _buildResultsPhase(),
        _ => const SizedBox.shrink(),
      },
    );
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // PHASE 1: CONTENT
  // ═════════════════════════════════════════════════════════════════════════════

  Widget _buildContentPhase() {
    final contentCount = _lesson.content.length;
    final isLastCard = _currentContentPage >= contentCount - 1;

    return Column(
      key: const ValueKey('content_phase'),
      children: [
        // Progress dots
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: _buildProgressDots(contentCount, _currentContentPage),
        ),

        // Content PageView
        Expanded(
          child: PageView.builder(
            controller: _contentPageCtrl,
            itemCount: contentCount,
            onPageChanged: (i) => setState(() => _currentContentPage = i),
            physics: const BouncingScrollPhysics(),
            itemBuilder: (context, index) {
              final content = _lesson.content[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildContentCard(content, index),
              );
            },
          ),
        ),

        // Navigation button
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: _buildContentNavButton(isLastCard),
        ),
      ],
    );
  }

  Widget _buildProgressDots(int total, int current) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final isActive = i == current;
        final isPast = i < current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          width: isActive ? 24 : 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: isActive
                ? _accent
                : isPast
                    ? _accent.withAlpha(100)
                    : Colors.white.withAlpha(30),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: _accent.withAlpha(100),
                      blurRadius: 8,
                      spreadRadius: 1,
                    )
                  ]
                : null,
          ),
        );
      }),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildContentCard(LessonContent content, int index) {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: _accent.withAlpha(40),
                width: 1,
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withAlpha(18),
                  Colors.white.withAlpha(8),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: _accent.withAlpha(15),
                  blurRadius: 30,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildContentTypeChip(content.type),
                  const SizedBox(height: 16),
                  _buildContentTitle(content.title),
                  const SizedBox(height: 16),
                  _buildContentBody(content),
                ],
              ),
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms, delay: 100.ms)
        .slideY(begin: 0.05, duration: 400.ms, delay: 100.ms);
  }

  Widget _buildContentTypeChip(String type) {
    final config = _contentTypeConfig(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: config.color.withAlpha(20),
        border: Border.all(color: config.color.withAlpha(60), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(config.icon, color: config.color, size: 14),
          const SizedBox(width: 6),
          Text(
            config.label.toUpperCase(),
            style: GoogleFonts.orbitron(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: config.color,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentTitle(String title) {
    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        colors: [_accent, _accent.withAlpha(180)],
      ).createShader(bounds),
      child: Text(
        title,
        style: GoogleFonts.orbitron(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: 0.5,
          height: 1.3,
        ),
      ),
    );
  }

  Widget _buildContentBody(LessonContent content) {
    switch (content.type) {
      case 'code':
        return _buildCodeBlock(content.body);
      case 'highlight':
        return _buildHighlightBox(content.body);
      case 'example':
        return _buildExampleBlock(content.body);
      default:
        return _buildTextBlock(content.body);
    }
  }

  Widget _buildTextBlock(String text) {
    return Text(
      text,
      style: GoogleFonts.spaceGrotesk(
        fontSize: 15,
        color: _textSecondary,
        height: 1.7,
        letterSpacing: 0.2,
      ),
    );
  }

  Widget _buildCodeBlock(String code) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFF0D1117),
        border: Border.all(color: _accent.withAlpha(30), width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(100),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Top-left decorative corner
          Positioned(
            top: 0,
            left: 0,
            child: Row(
              children: [
                _codeDot(const Color(0xFFFF5F56)),
                const SizedBox(width: 6),
                _codeDot(const Color(0xFFFFBD2E)),
                const SizedBox(width: 6),
                _codeDot(const Color(0xFF27C93F)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: _buildSyntaxHighlightedCode(code),
          ),
        ],
      ),
    );
  }

  Widget _codeDot(Color color) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }

  Widget _buildSyntaxHighlightedCode(String code) {
    // Simple syntax-like highlighting
    final lines = code.split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.map((line) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: _buildColoredCodeLine(line),
        );
      }).toList(),
    );
  }

  Widget _buildColoredCodeLine(String line) {
    // Simple coloring: comments in gray, strings in green, keywords in purple
    final trimmed = line.trim();

    Color lineColor;
    if (trimmed.startsWith('#') || trimmed.startsWith('//')) {
      lineColor = _textTertiary;
    } else if (trimmed.contains('"') || trimmed.contains("'")) {
      // Lines with strings get a slight green tint
      lineColor = _green.withAlpha(220);
    } else if (_hasKeyword(trimmed)) {
      lineColor = _accent;
    } else {
      lineColor = const Color(0xFFE6E6E6);
    }

    return Text(
      line,
      style: GoogleFonts.jetBrainsMono(
        fontSize: 13,
        color: lineColor,
        height: 1.6,
      ),
    );
  }

  bool _hasKeyword(String line) {
    const keywords = [
      'def ',
      'class ',
      'import ',
      'from ',
      'return ',
      'if ',
      'else',
      'for ',
      'while ',
      'print(',
      'int',
      'float',
      'str',
      'bool',
      'True',
      'False',
      'None',
    ];
    return keywords.any((kw) => line.contains(kw));
  }

  Widget _buildHighlightBox(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _accent.withAlpha(80), width: 1.2),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _accent.withAlpha(15),
            _accent.withAlpha(5),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: _accent.withAlpha(25),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _accent.withAlpha(30),
            ),
            child: Icon(Icons.lightbulb_rounded, color: _accent, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 14,
                color: _textPrimary,
                height: 1.7,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExampleBlock(String text) {
    final steps = text.split('\n');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _gold.withAlpha(50), width: 0.8),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _gold.withAlpha(10),
            _gold.withAlpha(3),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.science_rounded, color: _gold, size: 18),
              const SizedBox(width: 8),
              Text(
                'WORKED EXAMPLE',
                style: GoogleFonts.orbitron(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: _gold,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...steps.map((step) {
            final isStep =
                step.trim().startsWith('Step') || step.trim().startsWith('Answer');
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text(
                step,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 14,
                  color: isStep ? _textPrimary : _textSecondary,
                  fontWeight: isStep ? FontWeight.w600 : FontWeight.w400,
                  height: 1.6,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildContentNavButton(bool isLastCard) {
    return GestureDetector(
      onTap: () {
        if (isLastCard) {
          if (_lesson.quiz.isEmpty) {
            _goToResultsPhase();
          } else {
            _goToQuizPhase();
          }
        } else {
          _contentPageCtrl.nextPage(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
          );
        }
      },
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: isLastCard
                ? [_accent, _accent.withAlpha(200)]
                : [_accent.withAlpha(40), _accent.withAlpha(20)],
          ),
          border: isLastCard
              ? null
              : Border.all(color: _accent.withAlpha(60), width: 0.8),
          boxShadow: isLastCard
              ? [
                  BoxShadow(
                    color: _accent.withAlpha(60),
                    blurRadius: 20,
                    spreadRadius: 1,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              isLastCard ? 'START QUIZ' : 'NEXT',
              style: GoogleFonts.orbitron(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isLastCard ? _bg : _accent,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              isLastCard ? Icons.quiz_rounded : Icons.arrow_forward_rounded,
              color: isLastCard ? _bg : _accent,
              size: 18,
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.2, duration: 300.ms);
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // PHASE 2: QUIZ
  // ═════════════════════════════════════════════════════════════════════════════

  Widget _buildQuizPhase() {
    final question = _lesson.quiz[_currentQuestion];

    return Padding(
      key: const ValueKey('quiz_phase'),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const SizedBox(height: 8),

          // Question progress bar
          _buildQuizProgressBar(),
          const SizedBox(height: 24),

          // Question number
          _buildQuestionNumber(),
          const SizedBox(height: 16),

          // Question text
          _buildQuestionText(question.question),
          const SizedBox(height: 28),

          // Options
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  ...List.generate(question.options.length, (i) {
                    return _buildOptionButton(question, i)
                        .animate()
                        .fadeIn(
                          duration: 300.ms,
                          delay: Duration(milliseconds: 100 + i * 80),
                        )
                        .slideX(
                          begin: 0.1,
                          duration: 300.ms,
                          delay: Duration(milliseconds: 100 + i * 80),
                        );
                  }),
                  // Explanation
                  if (_showExplanation) ...[
                    const SizedBox(height: 16),
                    _buildExplanationCard(question),
                  ],
                  // Continue button
                  if (_answered) ...[
                    const SizedBox(height: 16),
                    _buildContinueButton(),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuizProgressBar() {
    final progress = (_currentQuestion + (_answered ? 1 : 0)) / _totalQuestions;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Question ${_currentQuestion + 1} of $_totalQuestions',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 12,
                color: _textTertiary,
                fontWeight: FontWeight.w500,
              ),
            ),
            Row(
              children: [
                Icon(Icons.check_circle_rounded, color: _green, size: 14),
                const SizedBox(width: 4),
                Text(
                  '$_correctCount',
                  style: GoogleFonts.orbitron(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _green,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 6,
            child: Stack(
              children: [
                // Track
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                // Fill
                FractionallySizedBox(
                  widthFactor: progress.clamp(0.0, 1.0),
                  alignment: Alignment.centerLeft,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOutCubic,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      gradient: LinearGradient(
                        colors: [_accent, _accent.withAlpha(180)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _accent.withAlpha(80),
                          blurRadius: 8,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildQuestionNumber() {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [_accent, _accent.withAlpha(150)],
            ),
            boxShadow: [
              BoxShadow(
                color: _accent.withAlpha(60),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            '${_currentQuestion + 1}',
            style: GoogleFonts.orbitron(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: _bg,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          'QUESTION',
          style: GoogleFonts.orbitron(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: _textTertiary,
            letterSpacing: 3,
          ),
        ),
      ],
    ).animate().fadeIn(duration: 300.ms).slideX(begin: -0.1, duration: 300.ms);
  }

  Widget _buildQuestionText(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: GoogleFonts.spaceGrotesk(
          fontSize: 19,
          fontWeight: FontWeight.w600,
          color: _textPrimary,
          height: 1.5,
        ),
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 50.ms);
  }

  Widget _buildOptionButton(QuizQuestion question, int index) {
    final isSelected = _selectedOption == index;
    final isCorrect = index == question.correctIndex;
    final showCorrect = _answered && isCorrect;
    final showWrong = _answered && isSelected && !isCorrect;

    // Determine colors
    Color borderColor = _glassBorder;
    Color bgColor = Colors.white.withAlpha(10);
    Color textColor = _textPrimary;
    Color? glowColor;

    if (showCorrect) {
      borderColor = _green.withAlpha(150);
      bgColor = _green.withAlpha(20);
      textColor = _green;
      glowColor = _green;
    } else if (showWrong) {
      borderColor = _red.withAlpha(150);
      bgColor = _red.withAlpha(20);
      textColor = _red;
      glowColor = _red;
    } else if (isSelected && !_answered) {
      borderColor = _accent.withAlpha(150);
      bgColor = _accent.withAlpha(15);
      textColor = _accent;
    }

    final optionLetters = ['A', 'B', 'C', 'D'];

    return GestureDetector(
      onTap: () => _selectOption(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor, width: 1),
                color: bgColor,
                boxShadow: glowColor != null
                    ? [
                        BoxShadow(
                          color: glowColor.withAlpha(40),
                          blurRadius: 16,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  // Letter badge
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: showCorrect
                          ? _green.withAlpha(30)
                          : showWrong
                              ? _red.withAlpha(30)
                              : Colors.white.withAlpha(10),
                      border: Border.all(
                        color: showCorrect
                            ? _green.withAlpha(100)
                            : showWrong
                                ? _red.withAlpha(100)
                                : Colors.white.withAlpha(20),
                        width: 0.8,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: showCorrect
                        ? Icon(Icons.check_rounded, color: _green, size: 18)
                        : showWrong
                            ? Icon(Icons.close_rounded, color: _red, size: 18)
                            : Text(
                                optionLetters[index],
                                style: GoogleFonts.orbitron(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: textColor,
                                ),
                              ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      question.options[index],
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: textColor,
                        height: 1.4,
                      ),
                    ),
                  ),
                  // XP flash for correct
                  if (showCorrect && isSelected)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: _gold.withAlpha(20),
                        border: Border.all(color: _gold.withAlpha(60)),
                      ),
                      child: Text(
                        '+XP',
                        style: GoogleFonts.orbitron(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: _gold,
                        ),
                      ),
                    )
                        .animate()
                        .fadeIn(duration: 300.ms)
                        .scale(begin: const Offset(0.5, 0.5), duration: 300.ms),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExplanationCard(QuizQuestion question) {
    final isCorrect = _selectedOption == question.correctIndex;
    final color = isCorrect ? _green : _red;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withAlpha(50), width: 0.8),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withAlpha(12),
                color.withAlpha(5),
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isCorrect
                        ? Icons.celebration_rounded
                        : Icons.info_outline_rounded,
                    color: color,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isCorrect ? 'CORRECT!' : 'NOT QUITE',
                    style: GoogleFonts.orbitron(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: color,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                question.explanation,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 13,
                  color: _textSecondary,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms)
        .slideY(begin: 0.1, duration: 400.ms);
  }

  Widget _buildContinueButton() {
    final isLast = _currentQuestion + 1 >= _totalQuestions;

    return GestureDetector(
      onTap: _nextQuestion,
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [_accent, _accent.withAlpha(200)],
          ),
          boxShadow: [
            BoxShadow(
              color: _accent.withAlpha(60),
              blurRadius: 20,
              spreadRadius: 1,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              isLast ? 'SEE RESULTS' : 'CONTINUE',
              style: GoogleFonts.orbitron(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _bg,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              isLast ? Icons.emoji_events_rounded : Icons.arrow_forward_rounded,
              color: _bg,
              size: 18,
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 300.ms, delay: 200.ms)
        .slideY(begin: 0.2, duration: 300.ms, delay: 200.ms);
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // PHASE 3: RESULTS
  // ═════════════════════════════════════════════════════════════════════════════

  Widget _buildResultsPhase() {
    return SingleChildScrollView(
      key: const ValueKey('results_phase'),
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const SizedBox(height: 24),
          _buildResultsHeader(),
          const SizedBox(height: 32),
          _buildScoreDisplay(),
          const SizedBox(height: 24),
          _buildXpDisplay(),
          const SizedBox(height: 28),
          _buildStarRating(),
          const SizedBox(height: 32),
          if (_isPerfect) _buildPerfectScoreBanner(),
          if (_isPerfect) const SizedBox(height: 24),
          _buildResultsButton(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildResultsHeader() {
    final title = _isPerfect
        ? 'PERFECT!'
        : _starRating >= 2
            ? 'WELL DONE!'
            : 'KEEP GOING!';
    final subtitle = _isPerfect
        ? 'Flawless mastery - you nailed every question!'
        : _starRating >= 2
            ? 'Great work! You\'re making solid progress.'
            : 'Practice makes perfect. Try again for a better score!';

    final gradientColors = _isPerfect
        ? [_gold, const Color(0xFFFF8C00)]
        : _starRating >= 2
            ? [_accent, _accent.withAlpha(180)]
            : [_purple, _red];

    return Column(
      children: [
        // Trophy / medal icon
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: gradientColors.first.withAlpha(20),
            boxShadow: [
              BoxShadow(
                color: gradientColors.first.withAlpha(40),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Icon(
            _isPerfect
                ? Icons.emoji_events_rounded
                : _starRating >= 2
                    ? Icons.military_tech_rounded
                    : Icons.school_rounded,
            color: gradientColors.first,
            size: 42,
          ),
        )
            .animate()
            .scale(
              begin: const Offset(0.0, 0.0),
              end: const Offset(1.0, 1.0),
              duration: 600.ms,
              curve: Curves.elasticOut,
            ),
        const SizedBox(height: 20),

        // Title
        ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: gradientColors,
          ).createShader(bounds),
          child: Text(
            title,
            style: GoogleFonts.orbitron(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 4,
            ),
          ),
        )
            .animate()
            .fadeIn(duration: 400.ms, delay: 200.ms)
            .scale(begin: const Offset(0.8, 0.8), duration: 400.ms, delay: 200.ms),

        const SizedBox(height: 10),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 14,
            color: _textSecondary,
            height: 1.5,
          ),
        ).animate().fadeIn(duration: 400.ms, delay: 300.ms),
      ],
    );
  }

  Widget _buildScoreDisplay() {
    return AnimatedBuilder(
      animation: _scoreCountAnim,
      builder: (context, _) {
        final animatedCorrect = (_scoreCountAnim.value * _correctCount).round();
        return ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _accent.withAlpha(40), width: 1),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withAlpha(15),
                    Colors.white.withAlpha(5),
                  ],
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'SCORE',
                    style: GoogleFonts.orbitron(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _textTertiary,
                      letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '$animatedCorrect',
                        style: GoogleFonts.orbitron(
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          color: _accent,
                        ),
                      ),
                      Text(
                        ' / $_totalQuestions',
                        style: GoogleFonts.orbitron(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: _textTertiary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Accuracy bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      height: 8,
                      width: 200,
                      child: Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: _totalQuestions > 0
                                ? (animatedCorrect / _totalQuestions).clamp(0.0, 1.0)
                                : 0,
                            alignment: Alignment.centerLeft,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                                gradient: LinearGradient(
                                  colors: [_accent, _accent.withAlpha(180)],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: _accent.withAlpha(80),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ).animate().fadeIn(duration: 400.ms, delay: 100.ms).slideY(begin: 0.1, duration: 400.ms, delay: 100.ms);
  }

  Widget _buildXpDisplay() {
    return AnimatedBuilder(
      animation: _xpCountAnim,
      builder: (context, _) {
        final animatedXP = (_xpCountAnim.value * _xpEarned).round();
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: _gold.withAlpha(12),
            border: Border.all(color: _gold.withAlpha(40), width: 0.8),
            boxShadow: [
              BoxShadow(
                color: _gold.withAlpha(20),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.auto_awesome_rounded, color: _gold, size: 24),
              const SizedBox(width: 12),
              Text(
                '+$animatedXP XP',
                style: GoogleFonts.orbitron(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: _gold,
                ),
              ),
            ],
          ),
        );
      },
    ).animate().fadeIn(duration: 400.ms, delay: 300.ms).slideY(begin: 0.1, duration: 400.ms, delay: 300.ms);
  }

  Widget _buildStarRating() {
    return AnimatedBuilder(
      animation: _starCtrl,
      builder: (context, _) {
        final starProgress = _starCtrl.value;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (i) {
            final earned = i < _starRating;
            final delay = i * 0.25;
            final localProgress = ((starProgress - delay) / 0.4).clamp(0.0, 1.0);
            final scale = earned ? Curves.elasticOut.transform(localProgress) : 0.6;
            final alpha = earned ? (localProgress * 255).round() : 60;

            return Transform.scale(
              scale: earned ? scale : 0.6,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Icon(
                  earned ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: earned
                      ? _gold.withAlpha(alpha)
                      : Colors.white.withAlpha(30),
                  size: 50,
                  shadows: earned && localProgress > 0.5
                      ? [
                          Shadow(
                            color: _gold.withAlpha(100),
                            blurRadius: 20,
                          ),
                        ]
                      : null,
                ),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildPerfectScoreBanner() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _gold.withAlpha(80), width: 1.2),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _gold.withAlpha(20),
                _gold.withAlpha(5),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: _gold.withAlpha(30),
                blurRadius: 24,
                spreadRadius: 3,
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                '🏆',
                style: const TextStyle(fontSize: 36),
              ),
              const SizedBox(height: 8),
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [_gold, Color(0xFFFF8C00)],
                ).createShader(bounds),
                child: Text(
                  'FLAWLESS VICTORY',
                  style: GoogleFonts.orbitron(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 3,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'You answered every question correctly. Legendary!',
                textAlign: TextAlign.center,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 13,
                  color: _gold.withAlpha(200),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 500.ms, delay: 600.ms)
        .scale(
          begin: const Offset(0.9, 0.9),
          duration: 500.ms,
          delay: 600.ms,
          curve: Curves.elasticOut,
        );
  }

  Widget _buildResultsButton() {
    return GestureDetector(
      onTap: _saveProgressAndExit,
      child: Container(
        width: double.infinity,
        height: 58,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [_accent, _accent.withAlpha(200)],
          ),
          boxShadow: [
            BoxShadow(
              color: _accent.withAlpha(60),
              blurRadius: 24,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: _resultsSaved
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(_bg),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'CONTINUE',
                    style: GoogleFonts.orbitron(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _bg,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(Icons.arrow_forward_rounded, color: _bg, size: 20),
                ],
              ),
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms, delay: 500.ms)
        .slideY(begin: 0.2, duration: 400.ms, delay: 500.ms);
  }

  // ─── content type config helper ────────────────────────────────────────────

  _ContentTypeConfig _contentTypeConfig(String type) {
    return switch (type) {
      'code' => _ContentTypeConfig(
          label: 'Code',
          icon: Icons.code_rounded,
          color: _cyan,
        ),
      'highlight' => _ContentTypeConfig(
          label: 'Key Concept',
          icon: Icons.lightbulb_rounded,
          color: _accent,
        ),
      'example' => _ContentTypeConfig(
          label: 'Example',
          icon: Icons.science_rounded,
          color: _gold,
        ),
      _ => _ContentTypeConfig(
          label: 'Lesson',
          icon: Icons.auto_stories_rounded,
          color: _accent,
        ),
    };
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper Data Classes
// ─────────────────────────────────────────────────────────────────────────────

class _ContentTypeConfig {
  final String label;
  final IconData icon;
  final Color color;

  const _ContentTypeConfig({
    required this.label,
    required this.icon,
    required this.color,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Floating Particle Data
// ─────────────────────────────────────────────────────────────────────────────

class _FloatingParticle {
  final double x, y, radius, alpha, dx, dy, twinklePhase;

  const _FloatingParticle({
    required this.x,
    required this.y,
    required this.radius,
    required this.alpha,
    required this.dx,
    required this.dy,
    required this.twinklePhase,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Celebration Particle Data
// ─────────────────────────────────────────────────────────────────────────────

class _CelebrationParticle {
  final double startX, startY, dx, dy, gravity;
  final double rotation, rotationSpeed, size;
  final int colorIndex, shape;

  const _CelebrationParticle({
    required this.startX,
    required this.startY,
    required this.dx,
    required this.dy,
    required this.gravity,
    required this.rotation,
    required this.rotationSpeed,
    required this.size,
    required this.colorIndex,
    required this.shape,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Background Particle Painter
// ─────────────────────────────────────────────────────────────────────────────

class _ParticleFieldPainter extends CustomPainter {
  final List<_FloatingParticle> particles;
  final double progress;
  final Color color;

  _ParticleFieldPainter({
    required this.particles,
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (final p in particles) {
      final px = ((p.x + p.dx * progress) % 1.0) * size.width;
      final py = ((p.y + p.dy * progress) % 1.0) * size.height;

      final twinkle = (sin(progress * 2 * pi * 3 + p.twinklePhase) + 1) / 2;
      final alpha = (p.alpha * (0.3 + 0.7 * twinkle)).clamp(0.0, 1.0);

      paint.color = color.withAlpha((alpha * 255).round());
      canvas.drawCircle(Offset(px, py), p.radius, paint);

      if (p.radius > 1.2) {
        paint.color = color.withAlpha((alpha * 40).round());
        canvas.drawCircle(Offset(px, py), p.radius * 2.5, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ParticleFieldPainter old) => true;
}

// ─────────────────────────────────────────────────────────────────────────────
// Celebration Confetti Painter
// ─────────────────────────────────────────────────────────────────────────────

class _CelebrationPainter extends CustomPainter {
  final List<_CelebrationParticle> particles;
  final double progress;
  final List<Color> colors;

  _CelebrationPainter({
    required this.particles,
    required this.progress,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (final p in particles) {
      // Physics-based animation
      final t = progress;
      final x = (p.startX + p.dx * t) * size.width;
      final y = (p.startY + p.dy * t + 0.5 * p.gravity * t * t) * size.height;

      // Fade out over time
      final opacity = (1.0 - t * 0.7).clamp(0.0, 1.0);
      if (opacity <= 0) continue;

      final color = colors[p.colorIndex % colors.length];
      paint.color = color.withAlpha((opacity * 220).round());

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.rotation + p.rotationSpeed * t);

      switch (p.shape) {
        case 0:
          // Rectangle confetti
          canvas.drawRect(
            Rect.fromCenter(center: Offset.zero, width: p.size * 2, height: p.size * 0.6),
            paint,
          );
          break;
        case 1:
          // Circle
          canvas.drawCircle(Offset.zero, p.size * 0.5, paint);
          break;
        default:
          // Diamond
          final path = Path()
            ..moveTo(0, -p.size * 0.6)
            ..lineTo(p.size * 0.4, 0)
            ..lineTo(0, p.size * 0.6)
            ..lineTo(-p.size * 0.4, 0)
            ..close();
          canvas.drawPath(path, paint);
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _CelebrationPainter old) =>
      old.progress != progress;
}
