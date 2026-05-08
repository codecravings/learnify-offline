import 'dart:async';
import 'dart:math' show pi;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/ai/gemma_orchestrator.dart';
import '../../../core/franchises/franchise_loader.dart';
import '../../../core/services/local_memory_service.dart';
import '../../../core/services/local_profile_service.dart';
import '../../../core/services/text_to_speech_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/bionic_text.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../core/widgets/karaoke_text.dart';
import '../../../core/widgets/neon_button.dart';
import '../../../core/widgets/particle_background.dart';
import '../../../routes/app_router.dart';
import '../models/story_response.dart';
import '../models/story_scene.dart';
import '../models/story_style.dart';
import '../widgets/franchise_picker_sheet.dart';

enum _Phase { levelSelect, styleSelect, loading, story, quiz, results }

class StoryScreen extends StatefulWidget {
  const StoryScreen({
    super.key,
    this.customTopic,
    this.preselectedLevel,
    this.preselectedStyle,
    this.franchiseName,
    this.pathTopicKey,
    this.pathStepIndex,
  });

  final String? customTopic;
  final String? preselectedLevel;
  final String? preselectedStyle;
  final String? franchiseName;
  final String? pathTopicKey;
  final int? pathStepIndex;

  @override
  State<StoryScreen> createState() => _StoryScreenState();
}

class _StoryScreenState extends State<StoryScreen> {
  final _orchestrator = GemmaOrchestrator.instance;
  final _memory = LocalMemoryService.instance;
  final _profile = LocalProfileService.instance;

  _Phase _phase = _Phase.levelSelect;
  String _level = 'basics';
  StoryStyle _style = StoryStyle.practical;
  String _franchise = '';
  Franchise? _franchiseObj;

  Map<String, dynamic>? _levelAssessment;
  bool _assessing = false;
  String _loadingStage = 'Calling Gemma 4 E2B on-device…';

  StoryResponse? _story;
  // Number of scenes the user has revealed so far. Drives the chat-bubble feed.
  int _revealedSceneCount = 0;
  // True while the tail-chunk Gemma call is still in flight (so the UI can
  // show a subtle "writing..." pill if the user reaches the bottom early).
  bool _isGeneratingMore = false;
  StreamSubscription<StoryChunk>? _streamSub;
  // Stagger reveal: scenes arrive from Gemma in bursts, but we expose them
  // to the UI one at a time on a fixed cadence so the chat feels live (and
  // the typing pill between bubbles soaks up generation latency).
  Timer? _revealTimer;
  static const Duration _revealCadence = Duration(milliseconds: 1700);
  final ScrollController _chatScroll = ScrollController();

  int _ttsActiveWord = -1;
  String? _ttsActiveDialogue;
  StreamSubscription<int>? _ttsSub;
  int _questionIndex = 0;
  int _correctCount = 0;
  final List<String> _missedQuestions = [];
  int? _selectedOption;
  bool _showExplanation = false;

  String _topic = '';

  @override
  void initState() {
    super.initState();
    _initContext();
  }

  @override
  void dispose() {
    _streamSub?.cancel();
    _revealTimer?.cancel();
    _ttsSub?.cancel();
    _chatScroll.dispose();
    TextToSpeechService.instance.stop();
    super.dispose();
  }

  Widget _buildDialogue(String dialogue) {
    final dyslexic = _profile.currentProfile?.dyslexicMode ?? false;
    final baseStyle = AppTheme.bodyStyle(
      fontSize: 15,
      color: AppTheme.textPrimary,
      height: 1.5,
      dyslexic: dyslexic,
    );
    final isActiveScene = _ttsActiveDialogue == dialogue && _ttsActiveWord >= 0;
    if (isActiveScene) {
      return KaraokeText(
        text: dialogue,
        style: baseStyle,
        activeWordIndex: _ttsActiveWord,
      );
    }
    if (dyslexic) {
      return BionicText(text: dialogue, style: baseStyle);
    }
    return Text(dialogue, style: baseStyle);
  }

  Widget _buildSpeakButton(String dialogue) {
    final isActive = _ttsActiveDialogue == dialogue;
    return GestureDetector(
      onTap: () => _toggleSpeak(dialogue),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isActive
              ? AppTheme.accentCyan.withAlpha(40)
              : Colors.white.withAlpha(15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? AppTheme.accentCyan : Colors.white24,
            width: 0.7,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? Icons.stop_rounded : Icons.volume_up_rounded,
              size: 14,
              color: isActive ? AppTheme.accentCyan : Colors.white70,
            ),
            const SizedBox(width: 6),
            Text(
              isActive ? 'Stop' : 'Read aloud',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isActive ? AppTheme.accentCyan : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleSpeak(String dialogue) async {
    final tts = TextToSpeechService.instance;
    if (_ttsActiveDialogue == dialogue && tts.isSpeaking) {
      await tts.stop();
      if (mounted) {
        setState(() {
          _ttsActiveDialogue = null;
          _ttsActiveWord = -1;
        });
      }
      return;
    }
    setState(() {
      _ttsActiveDialogue = dialogue;
      _ttsActiveWord = -1;
    });
    _ttsSub ??= tts.wordIndexStream.listen((idx) {
      if (!mounted) return;
      setState(() => _ttsActiveWord = idx);
      if (idx < 0) {
        setState(() => _ttsActiveDialogue = null);
      }
    });
    final lang = _profile.currentProfile?.language ?? 'English';
    final result = await tts.speak(dialogue, language: _languageToBcp47(lang));
    if (!mounted) return;
    if (result.isError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.accentMagenta,
          duration: const Duration(seconds: 3),
          content: Text(
            result.message ??
                'TTS not available. Install a text-to-speech language pack from Settings.',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
      setState(() {
        _ttsActiveDialogue = null;
        _ttsActiveWord = -1;
      });
    } else if (result.status == TtsStatus.fallbackToDefault) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.accentGold,
          duration: const Duration(seconds: 2),
          content: Text(
            result.message ?? 'Reading in device default voice',
            style: const TextStyle(color: Colors.black),
          ),
        ),
      );
    }
  }

  String _languageToBcp47(String human) => switch (human) {
        'Hindi' => 'hi-IN',
        'Spanish' => 'es-ES',
        'French' => 'fr-FR',
        'Arabic' => 'ar-SA',
        'Portuguese' => 'pt-BR',
        'Bengali' => 'bn-IN',
        'Mandarin' => 'zh-CN',
        'Swahili' => 'sw-KE',
        'Urdu' => 'ur-PK',
        _ => 'en-US',
      };

  void _initContext() {
    if (widget.customTopic != null && widget.customTopic!.trim().isNotEmpty) {
      _topic = widget.customTopic!.trim();
    }

    if (widget.preselectedStyle != null) {
      _style = StoryStyle.values.firstWhere(
        (s) => s.promptKey == widget.preselectedStyle,
        orElse: () => StoryStyle.practical,
      );
    }
    _franchise = widget.franchiseName ?? '';

    if (widget.preselectedLevel != null) {
      _level = widget.preselectedLevel!;
      _phase = widget.preselectedStyle != null
          ? _Phase.loading
          : _Phase.styleSelect;
      if (_phase == _Phase.loading) _generateStory();
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
    // Movie/TV mode requires a franchise pick. Bounce them back if missing.
    if (_style == StoryStyle.movieTv && _franchiseObj == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppTheme.accentMagenta,
        duration: const Duration(seconds: 2),
        content: Text(
          'Pick a franchise first ✨',
          style: GoogleFonts.spaceGrotesk(color: Colors.white),
        ),
      ));
      return;
    }

    setState(() {
      _phase = _Phase.loading;
      _loadingStage = 'Checking your learning memory…';
      _story = null;
      _revealedSceneCount = 0;
      _isGeneratingMore = true;
    });

    await _streamSub?.cancel();
    _revealTimer?.cancel();
    _revealTimer = null;

    final stream = _orchestrator.streamStoryChunks(
      topic: _topic,
      style: _style.promptKey,
      franchise: _franchiseObj,
      franchiseName: _franchise,
      level: _level,
    );

    final completer = Completer<void>();
    _streamSub = stream.listen(
      (chunk) {
        if (!mounted) return;
        if (chunk.kind == StoryChunkKind.intro) {
          // Cast + title arrive up front. Scenes start as empty — they
          // stream in over subsequent tail chunks (one per scene).
          setState(() {
            _story = StoryResponse(
              title: chunk.title ?? _topic,
              scenes: List<StoryScene>.from(chunk.scenes),
              quiz: const [],
              franchiseCharacters: chunk.characters,
            );
            _revealedSceneCount = chunk.scenes.length;
            _phase = _Phase.story;
          });
          _scheduleAutoScroll();
        } else {
          // Tail chunks arrive one-per-scene (and one final chunk with just
          // the quiz). Scenes are appended to the buffer and revealed on a
          // 1.7s cadence by `_revealTimer` — so the user sees a "typing…"
          // pill between bubbles and Gemma gets extra wall-clock to stream
          // the next scene without a visible stall.
          final prev = _story;
          if (prev != null) {
            final newScenes = [...prev.scenes, ...chunk.scenes];
            final hasQuiz = chunk.quiz.isNotEmpty;
            setState(() {
              _story = StoryResponse(
                title: prev.title,
                scenes: newScenes,
                quiz: hasQuiz ? chunk.quiz : prev.quiz,
                franchiseCharacters: prev.franchiseCharacters,
              );
              // First scene: reveal instantly so the user isn't staring at
              // an empty chat. The rest are paced by the timer.
              if (_revealedSceneCount == 0 && newScenes.isNotEmpty) {
                _revealedSceneCount = 1;
              }
              if (hasQuiz) _isGeneratingMore = false;
            });
            _kickRevealTimer();
            _scheduleAutoScroll();
          }
        }
      },
      onError: (e) {
        if (!mounted) return;
        _isGeneratingMore = false;
        _showError('Generation failed: $e');
        if (!completer.isCompleted) completer.complete();
      },
      onDone: () {
        if (mounted) setState(() => _isGeneratingMore = false);
        if (!completer.isCompleted) completer.complete();
      },
    );

    await completer.future;
  }

  void _kickRevealTimer() {
    if (_revealTimer != null && _revealTimer!.isActive) return;
    _revealTimer = Timer.periodic(_revealCadence, (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      final story = _story;
      if (story == null) return;
      if (_revealedSceneCount < story.scenes.length) {
        setState(() => _revealedSceneCount++);
        _scheduleAutoScroll();
      } else if (!_isGeneratingMore) {
        t.cancel();
        _revealTimer = null;
      }
    });
  }

  void _scheduleAutoScroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_chatScroll.hasClients) return;
      _chatScroll.animateTo(
        _chatScroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
      );
    });
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

  Future<void> _openFranchisePicker() async {
    final mood = _profile.currentProfile?.currentMood ?? '';
    final picked = await showModalBottomSheet<Franchise?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FranchisePickerSheet(suggestedMood: mood),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _franchiseObj = picked;
      _franchise = picked.name;
    });
  }

  void _revealNextScene() {
    final story = _story;
    if (story == null) return;
    if (_revealedSceneCount < story.scenes.length) {
      setState(() => _revealedSceneCount++);
      _scheduleAutoScroll();
    } else if (!_isGeneratingMore && story.quiz.isNotEmpty) {
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
      pathTopicKey: widget.pathTopicKey,
      pathStepIndex: widget.pathStepIndex,
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
    // Brief: only two main modes — Practical (friend chat) + Movie/TV (franchise).
    // Hidden styles still resolve via promptKey for back-compat call sites.
    const styles = [StoryStyle.practical, StoryStyle.movieTv];
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
            'FRANCHISE',
            style: GoogleFonts.orbitron(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppTheme.accentCyan,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _openFranchisePicker,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.white.withAlpha(10),
                border: Border.all(
                  color: _franchiseObj != null
                      ? _style.color
                      : _style.color.withAlpha(60),
                  width: _franchiseObj != null ? 1.5 : 0.8,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _franchiseObj != null
                        ? Icons.auto_awesome_rounded
                        : Icons.search_rounded,
                    color: _style.color,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _franchiseObj?.name ?? 'Pick a franchise…',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _franchiseObj != null
                            ? Colors.white
                            : Colors.white54,
                      ),
                    ),
                  ),
                  if (_franchiseObj != null)
                    Text(
                      '${_franchiseObj!.characters.length} chars',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white38,
                      ),
                    )
                  else
                    const Icon(Icons.chevron_right_rounded,
                        color: Colors.white54),
                ],
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

  // ── STORY (chat-bubble feed) ──────────────────────────────────────────

  Widget _buildStory() {
    final story = _story!;
    final totalKnown = story.scenes.length;
    final reveal = _revealedSceneCount.clamp(0, totalKnown);
    final hasMore = reveal < totalKnown;
    final allRevealed = !hasMore && !_isGeneratingMore && story.quiz.isNotEmpty;

    // Header — minimal: title + tiny progress dots.
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(20, 56, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: _style.color.withAlpha(28),
                  border: Border.all(color: _style.color.withAlpha(80), width: 0.6),
                ),
                child: Text(
                  _franchiseObj != null ? _franchiseObj!.name.toUpperCase() : 'CHAT',
                  style: GoogleFonts.orbitron(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: _style.color,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  story.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.orbitron(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              Text(
                '$reveal/${_isGeneratingMore ? "…" : totalKnown}',
                style: GoogleFonts.orbitron(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textTertiary,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    // Chat list — one bubble per revealed scene.
    final chat = Expanded(
      child: ListView.builder(
        controller: _chatScroll,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        itemCount: reveal,
        itemBuilder: (_, i) {
          final scene = story.scenes[i];
          final character = story.getFranchiseCharacter(scene.characterId);
          // Alternate alignment by character id so the chat reads like a real
          // group chat instead of a single column of bubbles.
          final castIds = story.franchiseCharacters.map((c) => c.id).toList();
          final idx = castIds.indexOf(scene.characterId);
          final alignRight = idx == 0; // first character = "you", on the right.
          return _ChatBubble(
            scene: scene,
            character: character,
            styleColor: _style.color,
            alignRight: alignRight,
            dialogueBuilder: (text) => _buildDialogue(text),
            speakButton: (_profile.currentProfile?.ttsEnabled ?? false)
                ? _buildSpeakButton(scene.dialogue)
                : null,
          )
              .animate(key: ValueKey('bubble-$i'))
              .fadeIn(duration: 280.ms)
              .slideY(begin: 0.15, end: 0, duration: 320.ms, curve: Curves.easeOut);
        },
      ),
    );

    // Bottom CTA — scenes auto-reveal as they stream, so the only manual
    // step is the tap that advances to quiz once everything has arrived.
    Widget cta;
    if (allRevealed) {
      cta = NeonButton(
        label: 'ONE LAST CHECK',
        icon: Icons.quiz_rounded,
        colors: [AppTheme.accentCyan, _style.color],
        onTap: _revealNextScene,
      );
    } else {
      // Streaming or quiz still pending. Either way: typing indicator.
      cta = const _WritingPill();
    }

    return Column(
      children: [
        header,
        chat,
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 18),
          child: cta,
        ),
      ],
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

    // Feynman gate: strong score + a real franchise was used + non-beginner.
    final canTeach = accuracy >= 70 &&
        _franchiseObj != null &&
        _franchiseObj!.characters.isNotEmpty &&
        _level != 'basics';

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
        if (canTeach) ...[
          NeonButton(
            label: 'TEACH ${_franchiseObj!.characters.first.name.toUpperCase()}',
            icon: Icons.school_rounded,
            colors: const [AppTheme.accentPurple, AppTheme.accentMagenta],
            onTap: () {
              context.push(AppRoutes.feynman, extra: {
                'topic': _topic,
                'franchise': _franchiseObj,
                'character': _franchiseObj!.characters.first,
              });
            },
          ),
          const SizedBox(height: 10),
          NeonButton(
            label: 'DONE',
            icon: Icons.check_rounded,
            onTap: () => context.pop(),
          ),
        ] else
          NeonButton(
            label: 'CONTINUE',
            icon: Icons.check_rounded,
            onTap: () => context.pop(),
          ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: () {
            _revealTimer?.cancel();
            _revealTimer = null;
            setState(() {
              _phase = _Phase.styleSelect;
              _story = null;
              _revealedSceneCount = 0;
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

// ── Chat-bubble helpers ─────────────────────────────────────────────────

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    required this.scene,
    required this.character,
    required this.styleColor,
    required this.alignRight,
    required this.dialogueBuilder,
    this.speakButton,
  });

  final StoryScene scene;
  final FranchiseCharacter? character;
  final Color styleColor;
  final bool alignRight;
  final Widget Function(String) dialogueBuilder;
  final Widget? speakButton;

  @override
  Widget build(BuildContext context) {
    final color = character?.color ?? styleColor;
    final initial =
        (character?.name.isNotEmpty ?? false) ? character!.name[0].toUpperCase() : '?';
    final name = character?.name ?? scene.characterId;

    final avatar = Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: [color, color.withAlpha(120)]),
        boxShadow: [BoxShadow(color: color.withAlpha(80), blurRadius: 10)],
      ),
      child: Center(
        child: Text(
          initial,
          style: GoogleFonts.orbitron(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
      ),
    );

    final bubble = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.72,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(alignRight ? 16 : 4),
          bottomRight: Radius.circular(alignRight ? 4 : 16),
        ),
        color: color.withAlpha(28),
        border: Border.all(color: color.withAlpha(95), width: 0.7),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          dialogueBuilder(scene.dialogue),
          if (speakButton != null) ...[
            const SizedBox(height: 6),
            speakButton!,
          ],
        ],
      ),
    );

    final namePlate = Padding(
      padding: const EdgeInsets.only(left: 4, right: 4, bottom: 3),
      child: Row(
        mainAxisAlignment:
            alignRight ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Text(
            name,
            style: GoogleFonts.orbitron(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 1,
            ),
          ),
          if (scene.emotion.isNotEmpty && scene.emotion != 'neutral') ...[
            const SizedBox(width: 6),
            Text(
              '· ${scene.emotion}',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 10,
                color: AppTheme.textTertiary,
              ),
            ),
          ],
        ],
      ),
    );

    final body = Column(
      crossAxisAlignment:
          alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        if (scene.narration != null && scene.narration!.trim().isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Text(
              scene.narration!,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: AppTheme.textTertiary,
                height: 1.4,
              ),
              textAlign: alignRight ? TextAlign.right : TextAlign.left,
            ),
          ),
        ],
        namePlate,
        Row(
          mainAxisAlignment:
              alignRight ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: alignRight
              ? [
                  Flexible(child: bubble),
                  const SizedBox(width: 8),
                  avatar,
                ]
              : [
                  avatar,
                  const SizedBox(width: 8),
                  Flexible(child: bubble),
                ],
        ),
        if (scene.conceptTag != null && scene.conceptTag!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '# ${scene.conceptTag}',
              style: GoogleFonts.orbitron(
                fontSize: 8,
                color: styleColor.withAlpha(160),
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ],
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: body,
    );
  }
}

class _WritingPill extends StatelessWidget {
  const _WritingPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withAlpha(10),
        border: Border.all(color: Colors.white24, width: 0.6),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 10,
            height: 10,
            child: CircularProgressIndicator(
              strokeWidth: 1.6,
              color: AppTheme.accentCyan,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'gemma is typing…',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 11,
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
