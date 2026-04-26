import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
import '../../features/story_learning/models/story_response.dart';
import '../../features/story_learning/models/story_scene.dart';
import '../data/franchise_loader.dart';
import '../services/lab_memory_service.dart';
import '../services/lab_orchestrator.dart';
import '../widgets/franchise_picker.dart';

/// Story Learning flow:
///   topic → difficulty → franchise → loading → story → quiz → results
class StoryLearnScreen extends StatefulWidget {
  const StoryLearnScreen({super.key});

  @override
  State<StoryLearnScreen> createState() => _StoryLearnScreenState();
}

enum _Phase {
  topic,
  difficulty,
  franchise,
  subtopicsLoading,
  subtopics,
  loading,
  story,
  quiz,
  results,
  error,
}

class _StoryLearnScreenState extends State<StoryLearnScreen> {
  final _topicCtrl = TextEditingController();
  final _orchestrator = LabOrchestrator.instance;
  final _memory = LabMemoryService.instance;

  _Phase _phase = _Phase.topic;
  String _topic = '';
  String _difficulty = 'beginner';
  Franchise? _franchise;

  // Sub-topic phase state
  List<Map<String, dynamic>> _subtopics = const [];
  String? _chosenSubtopic;

  StoryResponse? _story;
  int _sceneIdx = 0;
  int _questionIdx = 0;
  int _correct = 0;
  int? _selected;
  bool _showExplain = false;
  final List<String> _missed = [];

  // Streaming state — set true while we're still waiting for parts.
  bool _moreScenesPending = false;
  bool _quizPending = false;

  String? _error;

  @override
  void dispose() {
    _topicCtrl.dispose();
    super.dispose();
  }

  // ── Flow transitions ─────────────────────────────────────────────────────

  void _submitTopic() {
    final t = _topicCtrl.text.trim();
    if (t.isEmpty) return;
    setState(() {
      _topic = t;
      _phase = _Phase.difficulty;
    });
  }

  void _pickDifficulty(String d) {
    setState(() {
      _difficulty = d;
      _phase = _Phase.franchise;
    });
  }

  Future<void> _pickFranchise() async {
    final selected = await showModalBottomSheet<Franchise?>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const FranchisePickerSheet(),
    );
    if (selected == null) return;
    setState(() => _franchise = selected);
    _loadSubtopics();
  }

  void _skipFranchise() {
    setState(() => _franchise = null);
    _loadSubtopics();
  }

  Future<void> _loadSubtopics() async {
    setState(() {
      _phase = _Phase.subtopicsLoading;
      _subtopics = const [];
      _chosenSubtopic = null;
      _error = null;
    });
    try {
      final list = await _orchestrator.generateSubtopics(
        topic: _topic,
        difficulty: _difficulty,
      );
      if (!mounted) return;
      if (list.isEmpty) {
        // Soft-fail: skip the picker and go straight to a story for the
        // whole topic so the lesson doesn't grind to a halt.
        debugPrint('[Story] sub-topic generation empty — skipping');
        setState(() => _chosenSubtopic = _topic);
        _generate();
        return;
      }
      setState(() {
        _subtopics = list;
        _phase = _Phase.subtopics;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _phase = _Phase.error;
      });
    }
  }

  void _pickSubtopic(Map<String, dynamic> sub) {
    final title = (sub['title'] as String?)?.trim();
    if (title == null || title.isEmpty) return;
    setState(() => _chosenSubtopic = title);
    _generate();
  }

  String get _effectiveTopic {
    final sub = _chosenSubtopic;
    if (sub == null || sub.isEmpty) return _topic;
    return '$_topic: $sub';
  }

  Future<void> _generate() async {
    setState(() {
      _phase = _Phase.loading;
      _error = null;
      _story = null;
      _moreScenesPending = true;
      _quizPending = true;
    });
    try {
      await for (final chunk in _orchestrator.streamFranchiseStory(
        topic: _effectiveTopic,
        difficulty: _difficulty,
        franchise: _franchise,
      )) {
        if (!mounted) return;
        switch (chunk.kind) {
          case LabStoryChunkKind.intro:
            // Build a placeholder StoryResponse with just the opening scene(s).
            // More scenes + quiz will be patched in as they arrive.
            final story = StoryResponse(
              title: chunk.title ?? _effectiveTopic,
              franchiseCharacters: chunk.characters,
              scenes: List<StoryScene>.from(chunk.scenes),
              quiz: const [],
            );
            setState(() {
              _story = story;
              _sceneIdx = 0;
              _phase = _Phase.story;
            });
            break;

          case LabStoryChunkKind.moreScenes:
            final current = _story;
            if (current == null) break;
            setState(() {
              _story = StoryResponse(
                title: current.title,
                franchiseCharacters: current.franchiseCharacters,
                scenes: [...current.scenes, ...chunk.scenes],
                quiz: current.quiz,
              );
              // Don't clear `_moreScenesPending` yet — multiple moreScenes
              // chunks can fire before the final quiz chunk closes the run.
            });
            break;

          case LabStoryChunkKind.quiz:
            final current = _story;
            if (current == null) break;
            setState(() {
              _story = StoryResponse(
                title: current.title,
                franchiseCharacters: current.franchiseCharacters,
                scenes: current.scenes,
                quiz: chunk.quiz,
              );
              // Quiz chunk is always last in the stream — both flags clear.
              _moreScenesPending = false;
              _quizPending = false;
            });
            _maybeAdvanceFromLoading();
            break;
        }
      }
    } catch (e) {
      if (!mounted) return;
      // If at least one scene already arrived, keep the user on the story
      // screen — they can read what we've got. Otherwise show the error.
      if (_story != null && _story!.scenes.isNotEmpty) {
        setState(() {
          _moreScenesPending = false;
          _quizPending = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Stopped early: $e',
              maxLines: 3, overflow: TextOverflow.ellipsis),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 5),
        ));
      } else {
        setState(() {
          _error = e.toString();
          _phase = _Phase.error;
        });
      }
    }
  }

  void _nextScene() {
    final s = _story;
    if (s == null) return;
    if (_sceneIdx < s.scenes.length - 1) {
      setState(() => _sceneIdx++);
      return;
    }

    // Last visible scene. If more scenes are still streaming, wait.
    if (_moreScenesPending) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Next scene is still generating…'),
        duration: Duration(seconds: 2),
      ));
      return;
    }
    // No more scenes — go to quiz if it's ready, else hold on the loading screen.
    if (_quizPending || s.quiz.isEmpty) {
      setState(() => _phase = _Phase.loading);
      return;
    }
    setState(() {
      _phase = _Phase.quiz;
      _questionIdx = 0;
      _correct = 0;
      _selected = null;
      _showExplain = false;
      _missed.clear();
    });
  }

  /// Auto-advance to the quiz when it arrives while user is on the loading screen.
  void _maybeAdvanceFromLoading() {
    if (_phase != _Phase.loading) return;
    final s = _story;
    if (s == null) return;
    if (!_quizPending && s.quiz.isNotEmpty) {
      setState(() {
        _phase = _Phase.quiz;
        _questionIdx = 0;
        _correct = 0;
        _selected = null;
        _showExplain = false;
        _missed.clear();
      });
    }
  }

  void _answer(int idx) {
    final q = _story!.quiz[_questionIdx];
    setState(() {
      _selected = idx;
      _showExplain = true;
      if (idx == q.correctIndex) {
        _correct++;
      } else {
        _missed.add(q.question);
      }
    });
  }

  Future<void> _nextQuestion() async {
    final total = _story!.quiz.length;
    if (_questionIdx < total - 1) {
      setState(() {
        _questionIdx++;
        _selected = null;
        _showExplain = false;
      });
    } else {
      await _finish();
    }
  }

  Future<void> _finish() async {
    final total = _story!.quiz.length;
    final concepts = _story!.scenes
        .map((s) => s.conceptTag)
        .whereType<String>()
        .toSet()
        .toList();
    await _memory.retainQuizResult(
      topic: _effectiveTopic,
      level: _difficulty,
      style: _franchise?.id ?? 'generic',
      score: _correct,
      total: total,
      missedQuestions: _missed,
      concepts: concepts,
    );
    if (mounted) setState(() => _phase = _Phase.results);
  }

  void _restart() {
    setState(() {
      _topicCtrl.clear();
      _topic = '';
      _difficulty = 'beginner';
      _franchise = null;
      _subtopics = const [];
      _chosenSubtopic = null;
      _story = null;
      _sceneIdx = 0;
      _questionIdx = 0;
      _correct = 0;
      _selected = null;
      _showExplain = false;
      _missed.clear();
      _phase = _Phase.topic;
      _error = null;
    });
  }

  // ── BUILD ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundPrimary,
      body: SafeArea(
        child: switch (_phase) {
          _Phase.topic => _buildTopic(),
          _Phase.difficulty => _buildDifficulty(),
          _Phase.franchise => _buildFranchise(),
          _Phase.subtopicsLoading => _buildSubtopicsLoading(),
          _Phase.subtopics => _buildSubtopics(),
          _Phase.loading => _buildLoading(),
          _Phase.story => _buildStory(),
          _Phase.quiz => _buildQuiz(),
          _Phase.results => _buildResults(),
          _Phase.error => _buildError(),
        },
      ),
    );
  }

  // ── Phase: topic ─────────────────────────────────────────────────────────
  Widget _buildTopic() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      child: ListView(
        children: [
          const SizedBox(height: 12),
          _eyebrow('STEP 1'),
          const SizedBox(height: 6),
          Text('What do you want to learn?',
              style: GoogleFonts.orbitron(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              )),
          const SizedBox(height: 8),
          Text(
            'Type any topic. Gemma + a franchise persona will turn it into a short scene.',
            style: AppTheme.bodyStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _topicCtrl,
            autofocus: true,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            textInputAction: TextInputAction.go,
            onSubmitted: (_) => _submitTopic(),
            decoration: InputDecoration(
              hintText: 'e.g. Fractions, Newton\'s Laws, Photosynthesis',
              hintStyle: const TextStyle(color: Colors.white30),
              filled: true,
              fillColor: Colors.white.withAlpha(15),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Colors.white24),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Colors.white24),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: AppTheme.accentMagenta, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 18),
          ElevatedButton(
            onPressed: _submitTopic,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentMagenta,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'CONTINUE',
              style: GoogleFonts.orbitron(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                letterSpacing: 2,
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'Try ideas',
            style: GoogleFonts.orbitron(
              fontSize: 10,
              color: AppTheme.textTertiary,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              'Fractions',
              "Newton's Laws",
              'Photosynthesis',
              'Variables in coding',
              'Pythagoras Theorem',
              'World War II',
            ]
                .map((t) => InkWell(
                      onTap: () {
                        _topicCtrl.text = t;
                        _submitTopic();
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: Colors.white.withAlpha(12),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Text(
                          t,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12),
                        ),
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  // ── Phase: difficulty ────────────────────────────────────────────────────
  Widget _buildDifficulty() {
    final options = [
      ('beginner', 'Beginner', 'Start from zero. Simple words, lots of analogies.', AppTheme.accentGreen),
      ('intermediate', 'Intermediate', 'You know the basics. Go a level deeper.', AppTheme.accentCyan),
      ('advanced', 'Advanced', 'Edge cases, common misconceptions, expert nuance.', AppTheme.accentMagenta),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      children: [
        _eyebrow('STEP 2'),
        const SizedBox(height: 6),
        Text(_topic,
            style: GoogleFonts.orbitron(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            )),
        const SizedBox(height: 4),
        Text('Pick your level',
            style: AppTheme.bodyStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
            )),
        const SizedBox(height: 22),
        for (final o in options) ...[
          _DifficultyCard(
            label: o.$2,
            blurb: o.$3,
            color: o.$4,
            onTap: () => _pickDifficulty(o.$1),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  // ── Phase: franchise ─────────────────────────────────────────────────────
  Widget _buildFranchise() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      children: [
        _eyebrow('STEP 3'),
        const SizedBox(height: 6),
        Text('Pick a franchise vibe',
            style: GoogleFonts.orbitron(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            )),
        const SizedBox(height: 6),
        Text(
          'Choose a TV show, movie, anime, or cartoon — Gemma will adopt that vibe '
          'while teaching $_topic.',
          style: AppTheme.bodyStyle(
            fontSize: 13,
            color: AppTheme.textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: _pickFranchise,
          icon: const Icon(Icons.movie_filter_rounded),
          label: const Text('Browse franchises'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.accentCyan,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _skipFranchise,
          icon: const Icon(Icons.skip_next_rounded),
          label: const Text('Skip — use a generic story'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white70,
            padding: const EdgeInsets.symmetric(vertical: 16),
            side: const BorderSide(color: Colors.white24),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  // ── Phase: sub-topics loading ─────────────────────────────────────────────
  Widget _buildSubtopicsLoading() {
    return _LoadingPanel(
      detail: 'Breaking "$_topic" down into bite-sized sub-topics…',
      accent: AppTheme.accentCyan,
    );
  }

  // ── Phase: sub-topics list ────────────────────────────────────────────────
  Widget _buildSubtopics() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      children: [
        _eyebrow('STEP 4 — PICK A SUB-TOPIC'),
        const SizedBox(height: 6),
        Text(_topic,
            style: GoogleFonts.orbitron(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            )),
        const SizedBox(height: 4),
        Text(
          _franchise == null
              ? '${_subtopics.length} sub-topics • tap one to begin'
              : '${_subtopics.length} sub-topics • ${_franchise!.name} cast • tap one',
          style: AppTheme.bodyStyle(
            fontSize: 12,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 18),
        for (int i = 0; i < _subtopics.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _SubtopicCard(
              index: i,
              data: _subtopics[i],
              onTap: () => _pickSubtopic(_subtopics[i]),
            ),
          ),
      ],
    );
  }

  // ── Phase: loading ───────────────────────────────────────────────────────
  Widget _buildLoading() {
    final detail = _quizPending && _story != null
        ? 'Quiz on the way…'
        : _franchise == null
            ? 'Crafting "$_topic" at $_difficulty level…'
            : '${_franchise!.name} cast on duty for "$_topic"…';
    return _LoadingPanel(
      detail: detail,
      accent: AppTheme.accentMagenta,
    );
  }

  // ── Phase: story ─────────────────────────────────────────────────────────
  Widget _buildStory() {
    final story = _story!;
    if (story.scenes.isEmpty) {
      return _buildErrorBody('Gemma returned a story with no scenes.');
    }
    final scene = story.scenes[_sceneIdx];
    final character =
        story.getFranchiseCharacter(scene.characterId);
    final color = character?.color ?? AppTheme.accentMagenta;

    // Pagination: end of currently-streamed scenes? If more are still
    // arriving, label the button "CONTINUE"; if everything is done, "TAKE THE QUIZ".
    final atEndOfLoadedScenes = _sceneIdx == story.scenes.length - 1;
    final isFinalEnd =
        atEndOfLoadedScenes && !_moreScenesPending && !_quizPending;
    final showQuizCta = atEndOfLoadedScenes && !_moreScenesPending;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      child: Column(
        children: [
          Row(
            children: [
              _eyebrow('SCENE ${_sceneIdx + 1} / ${story.scenes.length}'),
              const Spacer(),
              IconButton(
                tooltip: 'Restart',
                icon: const Icon(Icons.close_rounded, color: Colors.white70),
                onPressed: _restart,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(story.title,
              style: GoogleFonts.orbitron(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              )),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: color.withAlpha(18),
                  border: Border.all(color: color.withAlpha(110)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (character != null)
                      Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: color.withAlpha(40),
                              border: Border.all(color: color),
                            ),
                            child: Text(
                              character.name.isEmpty
                                  ? '?'
                                  : character.name[0].toUpperCase(),
                              style: GoogleFonts.orbitron(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: color,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  character.name,
                                  style: GoogleFonts.orbitron(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: color,
                                  ),
                                ),
                                Text(
                                  character.role,
                                  style: const TextStyle(
                                    color: Colors.white60,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (scene.emotion.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: Colors.white.withAlpha(20),
                              ),
                              child: Text(
                                scene.emotion,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                        ],
                      ),
                    const SizedBox(height: 14),
                    if ((scene.narration ?? '').isNotEmpty) ...[
                      Text(
                        scene.narration ?? '',
                        style: const TextStyle(
                          color: Colors.white60,
                          fontStyle: FontStyle.italic,
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    _Typewriter(
                      // Re-key on scene index so the typewriter restarts
                      // every time the user advances.
                      key: ValueKey('scene-$_sceneIdx'),
                      text: scene.dialogue,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        height: 1.55,
                      ),
                    ),
                    if ((scene.conceptTag ?? '').isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          color: Colors.white.withAlpha(15),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Text(
                          scene.conceptTag ?? '',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: _nextScene,
            icon: Icon(isFinalEnd
                ? Icons.fact_check_rounded
                : showQuizCta
                    ? Icons.fact_check_rounded
                    : Icons.arrow_forward_rounded),
            label: Text(isFinalEnd
                ? 'TAKE THE QUIZ'
                : showQuizCta
                    ? 'TAKE THE QUIZ'
                    : 'CONTINUE'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentMagenta,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(
                  horizontal: 22, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: GoogleFonts.orbitron(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Phase: quiz ──────────────────────────────────────────────────────────
  Widget _buildQuiz() {
    final quiz = _story!.quiz;
    if (quiz.isEmpty) {
      return _buildErrorBody('Gemma returned a story with no quiz questions.');
    }
    final q = quiz[_questionIdx];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      child: ListView(
        children: [
          _eyebrow('QUESTION ${_questionIdx + 1} / ${quiz.length}'),
          const SizedBox(height: 16),
          Text(
            q.question,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          for (int i = 0; i < q.options.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _quizOption(i, q),
            ),
          if (_showExplain) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: AppTheme.accentCyan.withAlpha(20),
                border: Border.all(color: AppTheme.accentCyan.withAlpha(80)),
              ),
              child: Text(
                q.explanation,
                style: const TextStyle(color: Colors.white, height: 1.5),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _nextQuestion,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentMagenta,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                _questionIdx == quiz.length - 1 ? 'SEE RESULTS' : 'NEXT QUESTION',
                style: GoogleFonts.orbitron(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  letterSpacing: 1.6,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _quizOption(int i, StoryQuizQuestion q) {
    Color bg = Colors.white.withAlpha(12);
    Color border = Colors.white24;
    if (_showExplain) {
      if (i == q.correctIndex) {
        bg = AppTheme.accentGreen.withAlpha(30);
        border = AppTheme.accentGreen;
      } else if (i == _selected && i != q.correctIndex) {
        bg = AppTheme.accentMagenta.withAlpha(30);
        border = AppTheme.accentMagenta;
      }
    } else if (_selected == i) {
      bg = AppTheme.accentCyan.withAlpha(30);
      border = AppTheme.accentCyan;
    }
    return InkWell(
      onTap: _showExplain ? null : () => _answer(i),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: bg,
          border: Border.all(color: border, width: 1.2),
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withAlpha(15),
                border: Border.all(color: Colors.white38),
              ),
              child: Text(String.fromCharCode(65 + i),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(q.options[i],
                  style: const TextStyle(
                      color: Colors.white, fontSize: 15)),
            ),
            if (_showExplain && i == q.correctIndex)
              const Icon(Icons.check_circle_rounded,
                  color: Colors.greenAccent, size: 20),
          ],
        ),
      ),
    );
  }

  // ── Phase: results ───────────────────────────────────────────────────────
  Widget _buildResults() {
    final total = _story!.quiz.length;
    final accuracy = total > 0 ? (_correct / total * 100).round() : 0;
    final stars = accuracy >= 90
        ? 3
        : accuracy >= 70
            ? 2
            : 1;
    final xp = 35 + (_correct == total ? 15 : 0);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.emoji_events_rounded,
                size: 72, color: AppTheme.accentGold),
            const SizedBox(height: 12),
            Text('LESSON COMPLETE',
                style: GoogleFonts.orbitron(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.accentGold,
                  letterSpacing: 2,
                )),
            const SizedBox(height: 8),
            Text(_topic,
                textAlign: TextAlign.center,
                style: GoogleFonts.orbitron(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                )),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                3,
                (i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: AppTheme.accentGold,
                    size: 38,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _statChip('+$xp XP', AppTheme.accentMagenta),
                _statChip('$accuracy% accuracy', AppTheme.accentCyan),
                _statChip('$_correct / $total correct', AppTheme.accentGreen),
              ],
            ),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: _restart,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentMagenta,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                    horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text('NEW LESSON',
                  style: GoogleFonts.orbitron(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    letterSpacing: 1.6,
                  )),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statChip(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: color.withAlpha(40),
          border: Border.all(color: color),
        ),
        child: Text(
          label,
          style: GoogleFonts.orbitron(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      );

  // ── Phase: error ─────────────────────────────────────────────────────────
  Widget _buildError() => _buildErrorBody(_error ?? 'Something went wrong.');

  Widget _buildErrorBody(String msg) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 56, color: Colors.redAccent),
            const SizedBox(height: 14),
            Text('Generation failed',
                style: GoogleFonts.orbitron(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                )),
            const SizedBox(height: 8),
            Text(
              msg,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white60, height: 1.5),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton(
                  onPressed: _restart,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                  ),
                  child: const Text('Start over'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _generate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentMagenta,
                    foregroundColor: Colors.black,
                  ),
                  child: const Text('Try again'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────
  Widget _eyebrow(String text) => Text(
        text,
        style: GoogleFonts.orbitron(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppTheme.accentMagenta,
          letterSpacing: 2,
        ),
      );
}

class _DifficultyCard extends StatelessWidget {
  const _DifficultyCard({
    required this.label,
    required this.blurb,
    required this.color,
    required this.onTap,
  });

  final String label;
  final String blurb;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: color.withAlpha(18),
          border: Border.all(color: color.withAlpha(90)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label.toUpperCase(),
                    style: GoogleFonts.orbitron(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: color,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    blurb,
                    style: AppTheme.bodyStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: color, size: 14),
          ],
        ),
      ),
    );
  }
}

class _SubtopicCard extends StatelessWidget {
  const _SubtopicCard({
    required this.index,
    required this.data,
    required this.onTap,
  });

  final int index;
  final Map<String, dynamic> data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = (data['title'] as String?)?.trim() ?? '';
    final description = (data['description'] as String?)?.trim() ?? '';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Colors.white.withAlpha(12),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.accentMagenta.withAlpha(30),
                border: Border.all(color: AppTheme.accentMagenta.withAlpha(120)),
              ),
              child: Text(
                '${index + 1}',
                style: GoogleFonts.orbitron(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.accentMagenta,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.3,
                    ),
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                size: 12, color: Colors.white38),
          ],
        ),
      ),
    );
  }
}

class _LoadingPanel extends StatefulWidget {
  const _LoadingPanel({required this.detail, required this.accent});

  final String detail;
  final Color accent;

  @override
  State<_LoadingPanel> createState() => _LoadingPanelState();
}

class _LoadingPanelState extends State<_LoadingPanel> {
  static const _quotes = [
    "On-device. No cloud. No spying.",
    "Small model, big stories.",
    "Your data stays on your phone — always.",
    "Gemma is daydreaming up your scene…",
    "Casting the perfect persona…",
    "Tiny brain, mighty heart.",
    "Building a lesson, one analogy at a time.",
    "Offline-first. Friend-shaped AI.",
    "Picking words a 10-year-old would love.",
    "Compressing wisdom into pocket-sized scenes.",
  ];

  late final Stream<int> _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Stream.periodic(
      const Duration(seconds: 3),
      (i) => i % _quotes.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 56,
              height: 56,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation(widget.accent),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              "GEMMA IS WRITING",
              style: GoogleFonts.orbitron(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: widget.accent,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              widget.detail,
              textAlign: TextAlign.center,
              style: AppTheme.bodyStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 30),
            StreamBuilder<int>(
              stream: _ticker,
              initialData: 0,
              builder: (_, snap) {
                final idx = snap.data ?? 0;
                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  child: Text(
                    _quotes[idx],
                    key: ValueKey(idx),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.spaceGrotesk(
                      fontStyle: FontStyle.italic,
                      fontSize: 13,
                      color: Colors.white60,
                      height: 1.4,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Reveals [text] one character at a time. Tap to skip the animation.
class _Typewriter extends StatefulWidget {
  const _Typewriter({
    super.key,
    required this.text,
    required this.style,
    this.charDelay = const Duration(milliseconds: 22),
  });

  final String text;
  final TextStyle style;
  final Duration charDelay;

  @override
  State<_Typewriter> createState() => _TypewriterState();
}

class _TypewriterState extends State<_Typewriter> {
  int _shown = 0;
  bool _done = false;
  bool _cancelled = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    final total = widget.text.characters.length;
    while (_shown < total && !_cancelled && mounted) {
      await Future.delayed(widget.charDelay);
      if (!mounted || _cancelled) return;
      setState(() => _shown++);
    }
    if (mounted) setState(() => _done = true);
  }

  void _skip() {
    if (_done) return;
    setState(() {
      _shown = widget.text.characters.length;
      _cancelled = true;
      _done = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final visible = widget.text.characters.take(_shown).toString();
    return GestureDetector(
      onTap: _skip,
      behavior: HitTestBehavior.opaque,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 80),
        alignment: Alignment.topLeft,
        child: Text(
          visible,
          style: widget.style,
        ),
      ),
    );
  }
}
