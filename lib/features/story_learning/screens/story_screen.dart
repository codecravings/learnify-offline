import 'dart:math' show pi;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/ai/gemma_orchestrator.dart';
import '../../../core/services/local_memory_service.dart';
import '../../../core/services/local_profile_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../core/widgets/neon_button.dart';
import '../../../core/widgets/particle_background.dart';
import '../../courses/data/course_data.dart';
import '../models/story_response.dart';
import '../models/story_style.dart';

enum _Phase { levelSelect, styleSelect, loading, story, quiz, results }

class StoryScreen extends StatefulWidget {
  const StoryScreen({
    super.key,
    this.lessonId,
    this.subjectId,
    this.chapterId,
    this.customTopic,
    this.preselectedLevel,
    this.preselectedStyle,
    this.franchiseName,
  });

  final String? lessonId;
  final String? subjectId;
  final String? chapterId;
  final String? customTopic;
  final String? preselectedLevel;
  final String? preselectedStyle;
  final String? franchiseName;

  @override
  State<StoryScreen> createState() => _StoryScreenState();
}

class _StoryScreenState extends State<StoryScreen> {
  final _orchestrator = GemmaOrchestrator.instance;
  final _memory = LocalMemoryService.instance;
  final _profile = LocalProfileService.instance;

  _Phase _phase = _Phase.levelSelect;
  String _level = 'basics';
  StoryStyle _style = StoryStyle.story;
  String _franchise = '';

  Map<String, dynamic>? _levelAssessment;
  bool _assessing = false;
  String _loadingStage = 'Calling Gemma 4 E2B on-device…';

  StoryResponse? _story;
  int _sceneIndex = 0;
  int _questionIndex = 0;
  int _correctCount = 0;
  final List<String> _missedQuestions = [];
  int? _selectedOption;
  bool _showExplanation = false;

  String _topic = '';
  String _chapterTitle = '';
  Lesson? _lesson;
  CourseSubject? _subject;

  @override
  void initState() {
    super.initState();
    _initContext();
  }

  void _initContext() {
    // Resolve topic + lesson context
    if (widget.customTopic != null && widget.customTopic!.trim().isNotEmpty) {
      _topic = widget.customTopic!.trim();
    }

    if (widget.subjectId != null) {
      _subject = CourseData.allCourses
          .where((c) => c.id == widget.subjectId)
          .cast<CourseSubject?>()
          .firstWhere((c) => c != null, orElse: () => null);

      if (_subject != null && widget.chapterId != null) {
        for (final chapter in _subject!.chapters) {
          if (chapter.id == widget.chapterId) {
            _chapterTitle = chapter.title;
            if (widget.lessonId != null) {
              for (final lesson in chapter.lessons) {
                if (lesson.id == widget.lessonId) {
                  _lesson = lesson;
                  _topic = lesson.title;
                  break;
                }
              }
            }
            break;
          }
        }
      }
    }

    if (widget.preselectedStyle != null) {
      _style = StoryStyle.values.firstWhere(
        (s) => s.promptKey == widget.preselectedStyle,
        orElse: () => StoryStyle.story,
      );
    }
    _franchise = widget.franchiseName ?? '';

    // Decide starting phase
    final hasPreselectedLevel = widget.preselectedLevel != null;
    final isCourseLesson = _lesson != null;

    if (hasPreselectedLevel) {
      _level = widget.preselectedLevel!;
      _phase = widget.preselectedStyle != null
          ? _Phase.loading
          : _Phase.styleSelect;
      if (_phase == _Phase.loading) _generateStory();
    } else if (isCourseLesson) {
      _phase = _Phase.styleSelect;
    } else if (_topic.isNotEmpty) {
      _phase = _Phase.levelSelect;
      _assessLevel();
    } else {
      _phase = _Phase.levelSelect;
    }
  }

  Future<void> _assessLevel() async {
    setState(() => _assessing = true);
    try {
      final assessment = await _orchestrator.assessTopicLevel(_topic);
      if (mounted) {
        setState(() {
          _levelAssessment = assessment;
          _level = assessment['level'] as String? ?? 'basics';
          _assessing = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _assessing = false);
    }
  }

  Future<void> _generateStory() async {
    setState(() {
      _phase = _Phase.loading;
      _loadingStage = 'Checking your learning memory…';
    });

    try {
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) {
        setState(() =>
            _loadingStage = 'Gemma 4 E2B is crafting your ${_style.label.toLowerCase()} lesson…');
      }

      final story = await _orchestrator.generateStory(
        topic: _topic,
        style: _style.promptKey,
        franchiseName: _franchise,
        level: _level,
      );

      if (!mounted) return;
      setState(() {
        _story = story;
        _phase = _Phase.story;
        _sceneIndex = 0;
      });
    } catch (e) {
      if (!mounted) return;
      _showError('Generation failed: $e');
    }
  }

  void _showError(String msg) {
    // Always bounce back to where the user pressed GENERATE — the styleSelect
    // screen. Bouncing custom-topic errors to levelSelect creates an
    // apparent "loop" because the user has to walk forward again before
    // hitting the same failure.
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, maxLines: 4, overflow: TextOverflow.ellipsis),
      backgroundColor: Colors.red,
      duration: const Duration(seconds: 6),
    ));
    setState(() => _phase = _Phase.styleSelect);
  }

  void _advanceScene() {
    final story = _story;
    if (story == null) return;
    if (_sceneIndex < story.scenes.length - 1) {
      setState(() => _sceneIndex++);
    } else {
      setState(() {
        _phase = _Phase.quiz;
        _questionIndex = 0;
        _correctCount = 0;
        _selectedOption = null;
        _showExplanation = false;
      });
    }
  }

  void _submitAnswer(int index) {
    final question = _story!.quiz[_questionIndex];
    setState(() {
      _selectedOption = index;
      _showExplanation = true;
      if (index == question.correctIndex) {
        _correctCount++;
      } else {
        _missedQuestions.add(question.question);
      }
    });
  }

  Future<void> _nextQuestion() async {
    final quizLen = _story!.quiz.length;
    if (_questionIndex < quizLen - 1) {
      setState(() {
        _questionIndex++;
        _selectedOption = null;
        _showExplanation = false;
      });
    } else {
      await _finishLesson();
    }
  }

  Future<void> _finishLesson() async {
    final total = _story!.quiz.length;
    final concepts = _story!.scenes
        .map((s) => s.conceptTag)
        .whereType<String>()
        .toSet()
        .toList();

    await _memory.retainQuizResult(
      topic: _topic,
      level: _level,
      style: _style.promptKey,
      score: _correctCount,
      total: total,
      missedQuestions: _missedQuestions,
      concepts: concepts,
    );

    await _profile.updateStreak((_profile.currentProfile?.streak ?? 0) + 1);

    if (mounted) setState(() => _phase = _Phase.results);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundPrimary,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: AppTheme.backgroundGradient,
            ),
          ),
          if (_phase != _Phase.story && _phase != _Phase.loading)
            const ParticleBackground(
              particleCount: 30,
              particleColor: AppTheme.accentPurple,
              maxRadius: 1.2,
            ),
          SafeArea(child: _buildPhase()),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            child: IconButton(
              onPressed: () => context.pop(),
              icon: const Icon(Icons.close_rounded, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhase() {
    return switch (_phase) {
      _Phase.levelSelect => _buildLevelSelect(),
      _Phase.styleSelect => _buildStyleSelect(),
      _Phase.loading => _buildLoading(),
      _Phase.story => _buildStory(),
      _Phase.quiz => _buildQuiz(),
      _Phase.results => _buildResults(),
    };
  }

  // ── LEVEL SELECT ───────────────────────────────────────────────────────

  Widget _buildLevelSelect() {
    final hasHistory = _levelAssessment?['has_history'] == true;
    final pastAccuracy =
        (_levelAssessment?['past_accuracy'] as num?)?.toInt() ?? 0;
    final aiPick = _levelAssessment?['level'] as String? ?? 'basics';
    final reason = _levelAssessment?['reason'] as String? ?? '';

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 40),
      children: [
        Text(
          _topic.isEmpty ? 'Pick a topic first' : 'Ready to learn?',
          style: GoogleFonts.orbitron(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _topic.isEmpty
              ? 'This screen needs a topic from the home search.'
              : _topic,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 14,
            color: AppTheme.accentCyan,
          ),
        ),
        const SizedBox(height: 24),
        if (_assessing)
          GlassContainer(
            borderColor: AppTheme.accentPurple.withAlpha(60),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.accentPurple,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Gemma is checking your learning memory…',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          )
        else if (_levelAssessment != null)
          GlassContainer(
            borderColor: AppTheme.accentPurple.withAlpha(80),
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      hasHistory
                          ? Icons.memory_rounded
                          : Icons.fiber_new_rounded,
                      color: AppTheme.accentPurple,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      hasHistory ? 'I REMEMBER YOU' : 'NEW TOPIC',
                      style: GoogleFonts.orbitron(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.accentPurple,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const Spacer(),
                    if (hasHistory)
                      Text(
                        '$pastAccuracy% past accuracy',
                        style: GoogleFonts.orbitron(
                          fontSize: 10,
                          color: AppTheme.textTertiary,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  reason,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 24),
        Text(
          'CHOOSE YOUR LEVEL',
          style: GoogleFonts.orbitron(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppTheme.accentCyan,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        _buildLevelCard('basics', 'Basics', Icons.emoji_objects_rounded,
            AppTheme.accentGreen, 'Start from scratch',
            isAiPick: aiPick == 'basics'),
        const SizedBox(height: 10),
        _buildLevelCard('intermediate', 'Intermediate',
            Icons.trending_up_rounded, AppTheme.accentCyan,
            'You know the basics',
            isAiPick: aiPick == 'intermediate'),
        const SizedBox(height: 10),
        _buildLevelCard('advanced', 'Advanced', Icons.workspace_premium_rounded,
            AppTheme.accentPurple, 'Expert-level nuances',
            isAiPick: aiPick == 'advanced'),
        const SizedBox(height: 24),
        NeonButton(
          label: 'CONTINUE',
          icon: Icons.arrow_forward_rounded,
          onTap: _topic.isEmpty
              ? () => context.pop()
              : () => setState(() => _phase = _Phase.styleSelect),
        ),
      ],
    );
  }

  Widget _buildLevelCard(
    String level,
    String label,
    IconData icon,
    Color color,
    String subtitle, {
    bool isAiPick = false,
  }) {
    final selected = _level == level;
    return GestureDetector(
      onTap: () => setState(() => _level = level),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: selected ? color.withAlpha(25) : Colors.white.withAlpha(8),
          border: Border.all(
            color: selected ? color : color.withAlpha(50),
            width: selected ? 1.5 : 0.8,
          ),
          boxShadow: selected
              ? [BoxShadow(color: color.withAlpha(60), blurRadius: 16)]
              : null,
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        label,
                        style: GoogleFonts.orbitron(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                      if (isAiPick) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            color: AppTheme.accentGold.withAlpha(30),
                            border: Border.all(
                              color: AppTheme.accentGold.withAlpha(90),
                              width: 0.5,
                            ),
                          ),
                          child: Text(
                            'AI PICK',
                            style: GoogleFonts.orbitron(
                              fontSize: 7,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.accentGold,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ],
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
              ),
            ),
            if (selected)
              Icon(Icons.check_circle_rounded, color: color, size: 22),
          ],
        ),
      ),
    );
  }

  // ── STYLE SELECT ───────────────────────────────────────────────────────

  Widget _buildStyleSelect() {
    final styles = StoryStyle.values;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 40),
      children: [
        Text(
          'Pick how you learn',
          style: GoogleFonts.orbitron(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Gemma will tell the story your way. Switch anytime.',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 12,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 24),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.15,
          children: styles.map(_buildStyleCard).toList(),
        ),
        if (_style == StoryStyle.movieTv) ...[
          const SizedBox(height: 18),
          Text(
            'FRANCHISE NAME',
            style: GoogleFonts.orbitron(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppTheme.accentCyan,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            onChanged: (v) => _franchise = v,
            controller: TextEditingController(text: _franchise)
              ..selection = TextSelection.collapsed(offset: _franchise.length),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'e.g. Harry Potter, Naruto, Stranger Things',
              hintStyle: const TextStyle(color: Colors.white30),
              filled: true,
              fillColor: Colors.white.withAlpha(10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _style.color.withAlpha(60)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _style.color.withAlpha(60)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _style.color, width: 1.5),
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        NeonButton(
          label: 'GENERATE LESSON',
          icon: Icons.auto_awesome,
          colors: [_style.color, AppTheme.accentCyan],
          onTap: _generateStory,
        ),
      ],
    );
  }

  Widget _buildStyleCard(StoryStyle style) {
    final selected = _style == style;
    return GestureDetector(
      onTap: () => setState(() => _style = style),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color:
              selected ? style.color.withAlpha(25) : Colors.white.withAlpha(8),
          border: Border.all(
            color: selected ? style.color : style.color.withAlpha(50),
            width: selected ? 1.5 : 0.8,
          ),
          boxShadow: selected
              ? [BoxShadow(color: style.color.withAlpha(60), blurRadius: 14)]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(style.icon, color: style.color, size: 24),
            const Spacer(),
            Text(
              style.label,
              style: GoogleFonts.orbitron(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: style.color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              style.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 10,
                color: AppTheme.textTertiary,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── LOADING ────────────────────────────────────────────────────────────

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _GemmaThinkingOrb(color: _style.color),
          const SizedBox(height: 32),
          Text(
            'GEMMA 4 · ON-DEVICE',
            style: GoogleFonts.orbitron(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: _style.color,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _loadingStage,
            textAlign: TextAlign.center,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 13,
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
          ).animate(onPlay: (c) => c.repeat()).fadeIn(duration: 700.ms).then().fadeOut(duration: 700.ms),
          const SizedBox(height: 20),
          SizedBox(
            width: 200,
            child: LinearProgressIndicator(
              backgroundColor: Colors.white.withAlpha(10),
              color: _style.color,
              minHeight: 3,
            ),
          ),
        ],
      ),
    );
  }

  // ── STORY ──────────────────────────────────────────────────────────────

  Widget _buildStory() {
    final story = _story!;
    final scene = story.scenes[_sceneIndex];
    final character = story.getFranchiseCharacter(scene.characterId);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
      child: Column(
        children: [
          // Progress bar
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: (_sceneIndex + 1) / story.scenes.length,
                    backgroundColor: Colors.white.withAlpha(10),
                    color: _style.color,
                    minHeight: 4,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${_sceneIndex + 1}/${story.scenes.length}',
                style: GoogleFonts.orbitron(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _style.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            story.title,
            textAlign: TextAlign.center,
            style: GoogleFonts.orbitron(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const Spacer(),
          // Character portrait
          _buildCharacterPortrait(character, scene.emotion),
          const SizedBox(height: 18),
          // Dialogue box
          Expanded(
            flex: 3,
            child: GestureDetector(
              onTap: _advanceScene,
              child: GlassContainer(
                borderColor: (character?.color ?? _style.color).withAlpha(80),
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (character != null)
                      Text(
                        character.name.toUpperCase(),
                        style: GoogleFonts.orbitron(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: character.color,
                          letterSpacing: 1.5,
                        ),
                      ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (scene.narration != null &&
                                scene.narration!.isNotEmpty) ...[
                              Text(
                                scene.narration!,
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                  color: AppTheme.textTertiary,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                            Text(
                              scene.dialogue,
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 15,
                                color: AppTheme.textPrimary,
                                height: 1.5,
                              ),
                            ),
                            if (scene.conceptTag != null) ...[
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  color: _style.color.withAlpha(20),
                                  border: Border.all(
                                      color: _style.color.withAlpha(60),
                                      width: 0.5),
                                ),
                                child: Text(
                                  '# ${scene.conceptTag}',
                                  style: GoogleFonts.orbitron(
                                    fontSize: 9,
                                    color: _style.color,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          _sceneIndex == story.scenes.length - 1
                              ? 'Tap for quiz'
                              : 'Tap to continue',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 10,
                            color: AppTheme.textTertiary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 14,
                          color: _style.color.withAlpha(180),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCharacterPortrait(FranchiseCharacter? char, String emotion) {
    final color = char?.color ?? _style.color;
    final initial =
        (char?.name.isNotEmpty ?? false) ? char!.name[0].toUpperCase() : '?';

    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [color, color.withAlpha(120)],
        ),
        boxShadow: [
          BoxShadow(color: color.withAlpha(120), blurRadius: 24, spreadRadius: 2),
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
    ).animate(key: ValueKey(_sceneIndex)).scale(
          begin: const Offset(0.85, 0.85),
          end: const Offset(1.0, 1.0),
          duration: 300.ms,
        );
  }

  // ── QUIZ ───────────────────────────────────────────────────────────────

  Widget _buildQuiz() {
    final story = _story!;
    if (story.quiz.isEmpty) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _finishLesson());
      return const Center(child: CircularProgressIndicator());
    }
    final q = story.quiz[_questionIndex];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.quiz_rounded, color: AppTheme.accentCyan, size: 18),
              const SizedBox(width: 8),
              Text(
                'QUESTION ${_questionIndex + 1}/${story.quiz.length}',
                style: GoogleFonts.orbitron(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.accentCyan,
                  letterSpacing: 1.5,
                ),
              ),
              const Spacer(),
              Text(
                '$_correctCount correct',
                style: GoogleFonts.orbitron(
                  fontSize: 11,
                  color: AppTheme.accentGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GlassContainer(
            borderColor: AppTheme.accentCyan.withAlpha(60),
            padding: const EdgeInsets.all(18),
            child: Text(
              q.question,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 15,
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.separated(
              itemCount: q.options.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _buildAnswerOption(q, i),
            ),
          ),
          if (_showExplanation) ...[
            GlassContainer(
              borderColor: _selectedOption == q.correctIndex
                  ? AppTheme.accentGreen.withAlpha(80)
                  : AppTheme.accentOrange.withAlpha(80),
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selectedOption == q.correctIndex
                        ? 'CORRECT'
                        : 'NOT QUITE',
                    style: GoogleFonts.orbitron(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _selectedOption == q.correctIndex
                          ? AppTheme.accentGreen
                          : AppTheme.accentOrange,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    q.explanation,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            NeonButton(
              label: _questionIndex < story.quiz.length - 1
                  ? 'NEXT QUESTION'
                  : 'SEE RESULTS',
              icon: Icons.arrow_forward_rounded,
              onTap: _nextQuestion,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAnswerOption(StoryQuizQuestion q, int i) {
    final locked = _showExplanation;
    final isSelected = _selectedOption == i;
    final isCorrect = i == q.correctIndex;

    Color borderColor = AppTheme.glassBorder;
    Color bgColor = Colors.white.withAlpha(8);

    if (locked) {
      if (isCorrect) {
        borderColor = AppTheme.accentGreen;
        bgColor = AppTheme.accentGreen.withAlpha(25);
      } else if (isSelected) {
        borderColor = AppTheme.accentOrange;
        bgColor = AppTheme.accentOrange.withAlpha(25);
      }
    } else if (isSelected) {
      borderColor = AppTheme.accentCyan;
      bgColor = AppTheme.accentCyan.withAlpha(25);
    }

    return GestureDetector(
      onTap: locked ? null : () => _submitAnswer(i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: bgColor,
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: borderColor.withAlpha(40),
                border: Border.all(color: borderColor, width: 0.8),
              ),
              child: Center(
                child: Text(
                  String.fromCharCode(65 + i),
                  style: GoogleFonts.orbitron(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: borderColor,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                q.options[i],
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 13,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            if (locked && isCorrect)
              const Icon(Icons.check_circle_rounded,
                  color: AppTheme.accentGreen, size: 20),
            if (locked && isSelected && !isCorrect)
              const Icon(Icons.cancel_rounded,
                  color: AppTheme.accentOrange, size: 20),
          ],
        ),
      ),
    );
  }

  // ── RESULTS ────────────────────────────────────────────────────────────

  Widget _buildResults() {
    final total = _story!.quiz.length;
    final accuracy = total > 0 ? (_correctCount / total * 100).round() : 0;
    final stars = accuracy >= 90 ? 3 : accuracy >= 70 ? 2 : 1;
    final xp = 35 + (accuracy == 100 ? 15 : 0);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 80, 20, 40),
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                colors: [AppTheme.accentGold, AppTheme.accentOrange],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.accentGold.withAlpha(120),
                  blurRadius: 40,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: const Icon(Icons.emoji_events_rounded,
                size: 64, color: Colors.white),
          ),
        )
            .animate()
            .scale(duration: 600.ms, curve: Curves.elasticOut)
            .then()
            .shimmer(duration: 1200.ms),
        const SizedBox(height: 24),
        Text(
          'LESSON COMPLETE',
          textAlign: TextAlign.center,
          style: GoogleFonts.orbitron(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppTheme.accentGold,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _topic,
          textAlign: TextAlign.center,
          style: GoogleFonts.orbitron(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 30),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            3,
            (i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Icon(
                i < stars ? Icons.star_rounded : Icons.star_border_rounded,
                size: 44,
                color: i < stars
                    ? AppTheme.accentGold
                    : AppTheme.textTertiary,
              )
                  .animate(delay: (i * 200).ms)
                  .scale(duration: 400.ms, curve: Curves.elasticOut),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: _buildResultStat(
                  '$accuracy%', 'accuracy', AppTheme.accentCyan),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildResultStat(
                  '$_correctCount/$total', 'correct', AppTheme.accentGreen),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildResultStat(
                  '+$xp', 'XP earned', AppTheme.accentGold),
            ),
          ],
        ),
        const SizedBox(height: 30),
        NeonButton(
          label: 'CONTINUE',
          icon: Icons.check_rounded,
          onTap: () => context.pop(),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: () {
            setState(() {
              _phase = _Phase.styleSelect;
              _story = null;
              _sceneIndex = 0;
              _correctCount = 0;
              _missedQuestions.clear();
            });
          },
          child: Text(
            'Try another style →',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 12,
              color: AppTheme.accentCyan,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResultStat(String value, String label, Color color) {
    return GlassContainer(
      borderColor: color.withAlpha(60),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.orbitron(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 9,
              color: AppTheme.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Gemma thinking orb animation ────────────────────────────────────────

class _GemmaThinkingOrb extends StatefulWidget {
  const _GemmaThinkingOrb({required this.color});
  final Color color;

  @override
  State<_GemmaThinkingOrb> createState() => _GemmaThinkingOrbState();
}

class _GemmaThinkingOrbState extends State<_GemmaThinkingOrb>
    with TickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final t = _ctrl.value;
        return Stack(
          alignment: Alignment.center,
          children: [
            for (var i = 0; i < 3; i++)
              Transform.rotate(
                angle: t * 2 * pi + i * 2 * pi / 3,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: widget.color.withAlpha(80 - i * 20),
                      width: 1.2,
                    ),
                  ),
                ),
              ),
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [widget.color, widget.color.withAlpha(80)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withAlpha(120),
                    blurRadius: 40,
                    spreadRadius: 4,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
