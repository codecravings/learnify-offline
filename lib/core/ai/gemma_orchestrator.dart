import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../franchises/franchise_loader.dart';
import '../services/local_memory_service.dart';
import '../services/local_profile_service.dart';
import '../../features/story_learning/models/story_response.dart';
import '../../features/story_learning/models/story_scene.dart';
import 'agent_prompts.dart';
import 'gemma_service.dart';

/// Which "turn" of a Feynman / role-reversal session is being generated.
enum FeynmanTurn { opening, followUp, lightbulb }

/// Routes requests to the correct Gemma 4 agent based on intent.
///
/// All agents share one on-device Gemma 4 E2B instance.
/// Agent identity = system prompt. The orchestrator selects the right one.
class GemmaOrchestrator {
  GemmaOrchestrator._();
  static final GemmaOrchestrator instance = GemmaOrchestrator._();

  final _gemma = GemmaService.instance;
  final _memory = LocalMemoryService.instance;
  final _profile = LocalProfileService.instance;

  String get _lang => _profile.currentProfile?.language ?? 'English';
  String get _mood => _profile.currentProfile?.currentMood ?? '';
  bool get _dyslexic => _profile.currentProfile?.dyslexicMode ?? false;

  // ── STORY AGENT ─────────────────────────────────────────────────────────────

  /// One-shot story generation. Use this when you need the whole story before
  /// rendering anything (e.g. legacy callers). For the new chat-bubble UI use
  /// [streamStoryChunks] instead — same total wall-time but the user sees
  /// the first scenes within seconds instead of waiting for everything.
  Future<StoryResponse> generateStory({
    required String topic,
    required String style,
    Franchise? franchise,
    String franchiseName = '',
    String level = 'basics',
  }) async {
    // Resolve franchise: typed object wins, otherwise look up by name.
    Franchise? f = franchise;
    if (f == null && franchiseName.isNotEmpty) {
      f = await FranchiseLoader.instance.findByName(franchiseName);
    }

    final cast = _buildStoryCast(f);
    final castIds = cast.map((c) => c.id).toList();
    final castIdsCsv = castIds.map((id) => '"$id"').join(', ');
    final castDescription = _castDescriptionForPrompt(f, cast);
    final mode = (style == 'movie_tv' && f != null) ? 'movieTv' : 'practical';

    final memCtx = await _memory.getStudyContext(topic);
    await _memory.retainTopicInterest(topic, level: level);

    final systemPrompt = AgentPrompts.story(
      topic: topic,
      level: level,
      mode: mode,
      castDescription: castDescription,
      castIdsCsv: castIdsCsv,
      franchise: f,
      memoryContext: memCtx,
      language: _lang,
      mood: _mood,
      dyslexic: _dyslexic,
    );

    Future<String> run(String userPrompt) => _gemma.generate(
          systemPrompt: systemPrompt,
          userPrompt: userPrompt,
          maxTokens: 4096,
        );

    String raw = await run(_storyUserPrompt(topic, level, castIdsCsv));
    debugPrint('[Story] raw 1: ${raw.substring(0, raw.length.clamp(0, 300))}');
    Map<String, dynamic>? parsed;
    try {
      parsed = _parseJson(raw);
    } catch (_) {
      // Fall through to retry.
    }

    if (parsed == null) {
      raw = await run(
        'Your previous response was unusable JSON. Topic: "$topic". '
        'Output ONLY the JSON — no prose, no markdown fences. Start with { and '
        'end with }. Keep scenes short. characterId MUST be one of $castIdsCsv.',
      );
      debugPrint('[Story] raw 2: ${raw.substring(0, raw.length.clamp(0, 300))}');
      try {
        parsed = _parseJson(raw);
      } catch (e) {
        throw FormatException(
            'Story JSON parse failed twice. Last response: '
            '${raw.substring(0, raw.length.clamp(0, 200))}');
      }
    }

    final scenes = _retagSceneIds(_parseScenes(parsed['scenes']), castIds);
    final quiz = _parseQuiz(parsed['quiz']);
    final title = parsed['title'] as String? ?? topic;

    return StoryResponse(
      title: title,
      scenes: scenes,
      quiz: quiz,
      franchiseCharacters: cast,
    );
  }

  /// Progressive story generation. Yields a [StoryChunk] each time a piece is
  /// ready — first an `intro` chunk (title + cast + first 4 scenes) so the UI
  /// can paint within seconds, then a `tail` chunk (remaining 2 scenes + quiz).
  ///
  /// The user starts reading scene 1 while Gemma is still working on the rest.
  /// This is THE fix for "small model = slow first paint".
  Stream<StoryChunk> streamStoryChunks({
    required String topic,
    required String style,
    Franchise? franchise,
    String franchiseName = '',
    String level = 'basics',
  }) async* {
    Franchise? f = franchise;
    if (f == null && franchiseName.isNotEmpty) {
      f = await FranchiseLoader.instance.findByName(franchiseName);
    }

    final cast = _buildStoryCast(f);
    final castIds = cast.map((c) => c.id).toList();
    final castIdsCsv = castIds.map((id) => '"$id"').join(', ');
    final castDescription = _castDescriptionForPrompt(f, cast);
    final mode = (style == 'movie_tv' && f != null) ? 'movieTv' : 'practical';

    final memCtx = await _memory.getStudyContext(topic);
    await _memory.retainTopicInterest(topic, level: level);

    final systemPrompt = AgentPrompts.story(
      topic: topic,
      level: level,
      mode: mode,
      castDescription: castDescription,
      castIdsCsv: castIdsCsv,
      franchise: f,
      memoryContext: memCtx,
      language: _lang,
      mood: _mood,
      dyslexic: _dyslexic,
    );

    // ── Call A: title + first 4 scenes ───────────────────────────────────
    final introUser = '''
Topic: "$topic". Cast: $castIdsCsv.

Output ONLY this JSON shape:
{
  "title": "2–6 word vibey title",
  "scenes": [
    {"characterId":"<one of $castIdsCsv>","emotion":"string","dialogue":"string","narration":"string","conceptTag":"string"}
  ]
}

Rules:
- Exactly 4 scenes (this is the opening — scenes 1–4 of 6).
- characterId MUST be one of $castIdsCsv. No new ids.
- Dialogue ≤ 18 words. Chat-energy. Each scene = one chat message.
- Build a hook in scene 1, drop one real-world analogy by scene 2, name the term by scene 4.
''';
    final intro = await _runStoryJsonRetry('storyIntro', systemPrompt, introUser, castIdsCsv);
    final introScenes = intro == null
        ? const <StoryScene>[]
        : _retagSceneIds(_parseScenes(intro['scenes']), castIds);
    if (introScenes.isEmpty) {
      throw const FormatException(
          'Could not generate the opening scenes. Try again, or pick a simpler topic.');
    }
    final title = (intro?['title'] as String?) ?? topic;
    yield StoryChunk.intro(title: title, characters: cast, scenes: introScenes);

    // ── Call B: scenes 5-6 + quiz ────────────────────────────────────────
    final priorSummary = _previousScenesSummary(introScenes);
    final tailUser = '''
Final part of the lesson. Topic: "$topic". Cast: $castIdsCsv.

$priorSummary

Output ONLY this JSON (BOTH keys, in this exact shape):
{
  "scenes": [
    {"characterId":"<one of $castIdsCsv>","emotion":"string","dialogue":"string","narration":"string","conceptTag":"string"}
  ],
  "quiz": [
    {"question":"string","options":["A","B","C","D"],"correctIndex":0,"explanation":"string"}
  ]
}

Rules:
- "scenes" has exactly 2 entries that wrap up the lesson — the curious one says "ohhh I get it" by the end.
- "quiz" has exactly 3 questions reviewing what was taught.
- Dialogue ≤ 18 words. Quiz options ≤ 12 words.
- characterId MUST be one of $castIdsCsv.
- Do NOT repeat dialogue verbatim from the prior scenes — build on them.
''';
    final tail = await _runStoryJsonRetry('storyTail', systemPrompt, tailUser, castIdsCsv);
    final tailScenes = tail == null
        ? const <StoryScene>[]
        : _retagSceneIds(_parseScenes(tail['scenes']), castIds);
    final tailQuiz = tail == null ? const <StoryQuizQuestion>[] : _parseQuiz(tail['quiz']);
    yield StoryChunk.tail(scenes: tailScenes, quiz: tailQuiz);
  }

  // ── FEYNMAN MODE (kid teaches the franchise character) ────────────────────

  /// Streaming Feynman / role-reversal turn. Three deterministic turns:
  ///   - opening:    character admits confusion + asks ONE opening question
  ///   - followUp:   character paraphrases + asks ONE clarifying question
  ///   - lightbulb:  character has the "I get it!" moment + 1-line recap
  ///
  /// Plain text streaming — NEVER JSON. Caller assembles the running
  /// transcript and decides when to stop (always after lightbulb).
  Stream<String> streamFeynmanTurn({
    required String topic,
    required Franchise franchise,
    required FranchisePersona character,
    required FeynmanTurn turn,
    required List<({String role, String text})> transcript,
  }) {
    final systemPrompt = _buildFeynmanSystemPrompt(
      topic: topic,
      franchise: franchise,
      character: character,
    );

    final transcriptBlock = transcript.isEmpty
        ? '(no exchanges yet — this is your opening)'
        : transcript
            .map((e) =>
                '${e.role == 'character' ? character.name : 'STUDENT'}: ${e.text}')
            .join('\n');

    final userPrompt = switch (turn) {
      FeynmanTurn.opening => '''
You are about to learn about "$topic" from the student.
Open the conversation. In 1–3 sentences, IN YOUR AUTHENTIC VOICE:
1) Admit you don't fully get $topic.
2) Ask the student ONE specific opening question that gets them teaching.
Stay in character. Keep it under 40 words. Plain text — NO JSON, NO quotes around the whole reply.
''',
      FeynmanTurn.followUp => '''
The conversation so far:
$transcriptBlock

The student just explained something. React IN YOUR AUTHENTIC VOICE:
1) Show that you partially understood (paraphrase or react).
2) Ask ONE clarifying follow-up question about a piece you didn't fully get.
Stay in character. Keep it under 45 words. Plain text — NO JSON.
''',
      FeynmanTurn.lightbulb => '''
The conversation so far:
$transcriptBlock

You finally get it. IN YOUR AUTHENTIC VOICE:
1) Have a "lightbulb moment" — react with excitement/relief in your style.
2) Recap the topic IN ONE SENTENCE in your own words.
3) Thank the student briefly.
Stay in character. Keep it under 50 words. Plain text — NO JSON.
''',
    };

    return _gemma.generateStream(
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
    );
  }

  String _buildFeynmanSystemPrompt({
    required String topic,
    required Franchise franchise,
    required FranchisePersona character,
  }) {
    final sample = character.sampleDialogues.isNotEmpty
        ? character.sampleDialogues.first
        : '';
    return '''
You are roleplaying as ${character.name} from "${franchise.name}".
${franchise.worldSetting.isNotEmpty ? 'World: ${franchise.worldSetting}' : ''}

## YOUR CHARACTER (stay in this voice no matter what)
Role: ${character.role}
Speech style: ${character.speechStyle}
Humor style: ${character.humorStyle}
Emotional style: ${character.emotionalStyle}
Traits: ${character.traits.join(', ')}
${sample.isNotEmpty ? 'Example of how you talk: "$sample"' : ''}

## SITUATION — ROLE REVERSAL
Normally you'd be the teacher in a story lesson. Right now the tables are turned:
the student is teaching YOU about "$topic". You are the curious learner.
Be warm, lean into your own quirks, react like a real character would.

## GROUND RULES
- NEVER break character.
- NEVER act like an AI assistant or a teacher.
- NEVER list facts, bullet points, or numbered explanations — you are LEARNING, not lecturing.
- Be vulnerable: it's okay to be confused, surprised, excited.
- One reply at a time. Plain text. NO JSON, no markdown fences.
- Maximum 50 words per reply.

You are about to receive a turn instruction telling you what to do next. Follow it.
''';
  }

  // ── STORY FROM IMAGE (multimodal) ─────────────────────────────────────────

  /// Step 1: Extract topic + concepts from a textbook photo.
  Future<Map<String, dynamic>> analyzeTextbookImage(Uint8List imageBytes) async {
    final raw = await _gemma.generateFromImage(
      imageBytes: imageBytes,
      prompt: 'Analyze this textbook image and extract the topic, key concepts, and difficulty level.',
      systemPrompt: AgentPrompts.imageAnalysis(language: _lang),
    );
    return _parseJson(raw);
  }

  /// Step 2: Generate a full story lesson from the analyzed image data.
  Future<StoryResponse> generateStoryFromImage({
    required Uint8List imageBytes,
    required String style,
    Franchise? franchise,
    String franchiseName = '',
  }) async {
    final analysis = await analyzeTextbookImage(imageBytes);
    final topic = analysis['topic'] as String? ?? 'Unknown Topic';
    final level = analysis['level'] as String? ?? 'basics';

    return generateStory(
      topic: topic,
      style: style,
      franchise: franchise,
      franchiseName: franchiseName,
      level: level,
    );
  }

  // ── STORY HELPERS ──────────────────────────────────────────────────────────

  /// Build the locked cast from a franchise (or a small generic ensemble).
  /// Capped at 3 characters — small model + chat energy = tight cast.
  List<FranchiseCharacter> _buildStoryCast(Franchise? franchise) {
    const palette = ['#3B82F6', '#EF4444', '#22C55E', '#F59E0B', '#8B5CF6'];
    if (franchise == null) {
      return const [
        FranchiseCharacter(
            id: 'curious',
            name: 'Riya',
            role: 'the one with the question',
            colorHex: '#3B82F6'),
        FranchiseCharacter(
            id: 'explainer',
            name: 'Arjun',
            role: 'the friend who explains it through daily life',
            colorHex: '#22C55E'),
        FranchiseCharacter(
            id: 'skeptic',
            name: 'Mei',
            role: 'pushes back, asks the wait-what questions',
            colorHex: '#EF4444'),
      ];
    }
    final out = <FranchiseCharacter>[];
    final chars = franchise.characters.take(3).toList();
    for (var i = 0; i < chars.length; i++) {
      final c = chars[i];
      out.add(FranchiseCharacter(
        id: _slugify(c.name, fallback: 'char$i'),
        name: c.name,
        role: c.role,
        colorHex: palette[i % palette.length],
      ));
    }
    return out;
  }

  String _slugify(String s, {required String fallback}) {
    final cleaned = s
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return cleaned.isEmpty ? fallback : cleaned;
  }

  String _castDescriptionForPrompt(
    Franchise? franchise,
    List<FranchiseCharacter> cast,
  ) {
    if (franchise == null) {
      final lines = cast.map((c) => '- id "${c.id}" — ${c.name} (${c.role})');
      return 'Cast (use these ids in characterId):\n${lines.join('\n')}';
    }
    final byName = {for (final p in franchise.characters) p.name: p};
    final buf = StringBuffer('Cast (refer to them by id only):');
    for (final c in cast) {
      final p = byName[c.name];
      buf.writeln();
      buf.writeln('- id "${c.id}" — ${c.name} (${c.role})');
      if (p != null) {
        buf.writeln('  voice: ${p.speechStyle}');
        buf.writeln('  vibe: ${p.traits.take(3).join(', ')}');
      }
    }
    return buf.toString();
  }

  /// Coerce any characterId in [scenes] that doesn't match the locked cast
  /// to the first available cast id. Prevents Gemma from inventing new ids.
  List<StoryScene> _retagSceneIds(List<StoryScene> scenes, List<String> castIds) {
    if (castIds.isEmpty) return scenes;
    final allowed = castIds.toSet();
    return [
      for (final s in scenes)
        allowed.contains(s.characterId)
            ? s
            : StoryScene(
                characterId: castIds.first,
                emotion: s.emotion,
                dialogue: s.dialogue,
                narration: s.narration,
                conceptTag: s.conceptTag,
              ),
    ];
  }

  String _previousScenesSummary(List<StoryScene> scenes) {
    if (scenes.isEmpty) return 'This is the opening — no prior scenes.';
    final buf = StringBuffer(
        'Already shown (${scenes.length} scenes — DO NOT repeat these lines):\n');
    for (var i = 0; i < scenes.length; i++) {
      final s = scenes[i];
      final line = s.dialogue.length > 90
          ? '${s.dialogue.substring(0, 90)}…'
          : s.dialogue;
      buf.writeln('${i + 1}. ${s.characterId}: "$line"');
    }
    return buf.toString();
  }

  Future<Map<String, dynamic>?> _runStoryJsonRetry(
    String tag,
    String systemPrompt,
    String userPrompt,
    String castIdsCsv,
  ) async {
    Future<String> run(String user) => _gemma.generate(
          systemPrompt: systemPrompt,
          userPrompt: user,
          maxTokens: 4096,
        );

    String raw = await run(userPrompt);
    debugPrint('[Story.$tag] raw 1 length=${raw.length}');
    Map<String, dynamic>? parsed;
    try {
      parsed = _parseJson(raw);
    } catch (_) {}
    if (parsed != null) return parsed;

    raw = await run(
      'Previous response was unusable. Output ONLY a JSON object that matches '
      'the schema I described — no prose, no markdown, no wrapper key. Start '
      'with { and end with }. characterId MUST be one of $castIdsCsv.',
    );
    debugPrint('[Story.$tag] raw 2 length=${raw.length}');
    try {
      return _parseJson(raw);
    } catch (_) {
      return null;
    }
  }

  List<StoryScene> _parseScenes(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((m) => StoryScene.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  List<StoryQuizQuestion> _parseQuiz(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((m) => StoryQuizQuestion.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  // ── TUTOR AGENT ─────────────────────────────────────────────────────────────

  Future<String> explainTopic({
    required String topic,
    String style = 'practical',
  }) async {
    final memCtx = await _memory.getStudyContext(topic);
    return _gemma.generate(
      systemPrompt: AgentPrompts.tutor(
        topic: topic,
        style: style,
        language: _lang,
        memoryContext: memCtx,
      ),
      userPrompt: 'Explain: $topic',
    );
  }

  // ── QUIZ AGENT ──────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> generateQuiz({
    required String topic,
    required String level,
    List<String> weakAreas = const [],
  }) async {
    final effectiveWeakAreas =
        weakAreas.isNotEmpty ? weakAreas : await _memory.getWeakAreas(topic);
    final raw = await _gemma.generate(
      systemPrompt: AgentPrompts.quiz(
        topic: topic,
        level: level,
        language: _lang,
        weakAreas: effectiveWeakAreas,
      ),
      userPrompt: 'Generate 5 quiz questions for topic: $topic at $level level.',
    );
    final parsed = _parseJson(raw);
    return List<Map<String, dynamic>>.from(parsed['questions'] ?? []);
  }

  // ── EXPLORER AGENT (topic breakdown) ─────────────────────────────────────

  /// Breaks [topic] into [count] sub-topics using the Explorer agent.
  /// [depth] controls difficulty spread: 'normal' | 'exam' | 'deep'.
  /// Injects the learner's past context for this topic so repeat visits can personalise.
  Future<List<Map<String, dynamic>>> exploreTopic(
    String topic, {
    int count = 6,
    String depth = 'normal',
  }) async {
    final memCtx = await _memory.getStudyContext(topic);

    Future<String> run(String userMsg) => _gemma.generate(
          systemPrompt: AgentPrompts.explorer(
            language: _lang,
            count: count,
            depth: depth,
            memoryContext: memCtx,
          ),
          userPrompt: userMsg,
          maxTokens: 3072,
        );

    // Reject Gemma slop: bare strings, empty titles, and obvious placeholder
    // labels like "sub-topic 1", "item 2", "topic 3". When this fires we
    // surface a real error instead of pretending we got useful data.
    final placeholderRe = RegExp(
      r'^(sub[\s\-]?topic|topic|item|subtopic|untitled)\s*\d*$',
      caseSensitive: false,
    );

    String pickStr(Map<String, dynamic> m, List<String> keys) {
      for (final k in keys) {
        final v = m[k];
        if (v is String && v.trim().isNotEmpty) return v.trim();
      }
      return '';
    }

    Map<String, dynamic>? coerceItem(dynamic item) {
      Map<String, dynamic>? m;
      if (item is Map) {
        m = Map<String, dynamic>.from(item);
      } else if (item is String) {
        m = {'title': item};
      }
      if (m == null) return null;

      // Gemma's schema discipline drifts: it sometimes emits the subject-
      // suggester shape ({name, reason}) here. Accept those as fallbacks.
      final title = pickStr(m, ['title', 'name', 'topic', 'concept']);
      if (title.isEmpty) return null;
      if (placeholderRe.hasMatch(title)) return null;

      final desc = pickStr(m, ['description', 'reason', 'summary', 'detail']);
      final emoji = pickStr(m, ['emoji', 'icon']);
      final diff =
          pickStr(m, ['difficulty', 'level']).toLowerCase();

      return {
        'title': title,
        'description': desc,
        'emoji': emoji.isNotEmpty ? emoji : '📌',
        'difficulty': diff.isNotEmpty ? diff : 'beginner',
      };
    }

    List<Map<String, dynamic>> extract(dynamic decoded) {
      List<dynamic>? raw;
      if (decoded is List) {
        raw = decoded;
      } else if (decoded is Map<String, dynamic>) {
        for (final key in const [
          'subtopics',
          'sub_topics',
          'subTopics',
          'topics',
          'items',
          'list',
        ]) {
          final v = decoded[key];
          if (v is List && v.isNotEmpty) {
            raw = v;
            break;
          }
        }
      }
      if (raw == null) return const [];
      return raw
          .map(coerceItem)
          .whereType<Map<String, dynamic>>()
          .toList();
    }

    String raw = await run(
      'Topic: "$topic". Output the JSON object now. Begin your response with { and nothing else. '
      'Include EXACTLY $count entries in "subtopics".',
    );
    debugPrint('[Explorer] raw 1: ${raw.substring(0, raw.length.clamp(0, 300))}');
    var result = extract(_tryParse(raw));

    // Retry once if we got nothing usable (empty list or unparseable).
    if (result.isEmpty) {
      raw = await run(
        'Your previous response was unusable. Topic: "$topic". '
        'Output ONLY a JSON object with key "subtopics" containing a non-empty '
        'array of EXACTLY $count objects. Start with { and end with }.',
      );
      debugPrint('[Explorer] raw 2: ${raw.substring(0, raw.length.clamp(0, 300))}');
      result = extract(_tryParse(raw));
    }

    if (result.isEmpty) {
      throw FormatException(
          'Explorer returned 0 sub-topics. Last response: ${raw.substring(0, raw.length.clamp(0, 200))}');
    }
    return result;
  }

  dynamic _tryParse(String raw) {
    try {
      return _parseJsonAny(raw);
    } catch (_) {
      return null;
    }
  }

  // ── SUBJECT SUGGESTER ─────────────────────────────────────────────────────

  /// Proposes 6–8 subject cards for the home/courses screens based on the
  /// learner's profile + history. Returns list of `{name, emoji, reason}` maps.
  Future<List<Map<String, dynamic>>> suggestSubjects() async {
    final profile = _profile.currentProfile;
    final grade = profile?.grade ?? 'Student';
    final interests = profile?.interests ?? const <String>[];
    final history = await _memory.getAllTopicProgress();

    final raw = await _gemma.generate(
      systemPrompt: AgentPrompts.subjectSuggester(
        language: _lang,
        grade: grade,
        interests: interests,
        history: history,
      ),
      userPrompt:
          'Suggest 6–8 subjects for this learner. Output the JSON object now.',
      maxTokens: 2048,
    );

    try {
      final decoded = _parseJsonAny(raw);
      if (decoded is Map<String, dynamic>) {
        final list = decoded['subjects'];
        if (list is List) {
          return list
              .whereType<Map>()
              .map((m) => Map<String, dynamic>.from(m))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('[SubjectSuggester] parse failed: $e');
    }
    return const [];
  }

  // ── PREREQUISITE INFERENCE ────────────────────────────────────────────────

  /// Given a list of topic names, asks Gemma which topics are prerequisites
  /// for which. Returns `[{from, to, reason}]`.
  Future<List<Map<String, dynamic>>> inferPrerequisites(
    List<String> topics,
  ) async {
    if (topics.length < 2) return const [];
    final raw = await _gemma.generate(
      systemPrompt: AgentPrompts.prerequisiteInferencer(
        language: _lang,
        topics: topics,
      ),
      userPrompt: 'Output the JSON object of edges now.',
      maxTokens: 2048,
    );

    try {
      final decoded = _parseJsonAny(raw);
      if (decoded is Map<String, dynamic>) {
        final list = decoded['edges'];
        if (list is List) {
          return list
              .whereType<Map>()
              .map((m) => Map<String, dynamic>.from(m))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('[PrereqInferencer] parse failed: $e');
    }
    return const [];
  }

  // ── PLANNER AGENT ───────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> generateStudyPlan() async {
    final topics = await _memory.getAllTopicProgress();
    final raw = await _gemma.generate(
      systemPrompt: AgentPrompts.planner(
        language: _lang,
        topicProgress: topics,
      ),
      userPrompt: 'Create a personalized 7-day study plan based on my progress.',
    );
    return _parseJson(raw);
  }

  // ── LEARNER TWIN AGENT ──────────────────────────────────────────────────────

  Future<String> queryLearnerTwin(String query) async {
    final history = await _memory.getFormattedHistory();
    final chat = await _memory.getRecentChatContext(agent: 'companion');
    return _gemma.generate(
      systemPrompt: AgentPrompts.learnerTwin(
        language: _lang,
        learningHistory: history,
        chatContext: chat,
        query: query,
        mood: _mood,
        dyslexic: _dyslexic,
      ),
      userPrompt: query,
    );
  }

  Stream<String> queryLearnerTwinStream(String query) async* {
    final history = await _memory.getFormattedHistory();
    final chat = await _memory.getRecentChatContext(agent: 'companion');
    yield* _gemma.generateStream(
      systemPrompt: AgentPrompts.learnerTwin(
        language: _lang,
        learningHistory: history,
        chatContext: chat,
        query: query,
        mood: _mood,
        dyslexic: _dyslexic,
      ),
      userPrompt: query,
    );
  }

  // ── MASTERY AGENT (structured topic decomposition) ──────────────────────

  Future<Map<String, dynamic>> decomposeMasteryPath({
    required String topic,
    String level = 'basics',
  }) async {
    final history = await _memory.getAllTopicProgress();
    final pastConcepts = history
        .where((t) => (t['accuracy'] as int) >= 70)
        .map((t) => t['name'] as String)
        .take(10)
        .join(', ');

    final raw = await _gemma.generate(
      systemPrompt: AgentPrompts.mastery(
        topic: topic,
        level: level,
        pastConcepts: pastConcepts.isEmpty ? 'none yet' : pastConcepts,
        language: _lang,
      ),
      userPrompt: 'Decompose "$topic" into a mastery path.',
      maxTokens: 1500,
    );
    return _parseJson(raw);
  }

  // ── ORCHESTRATOR (intent routing) ─────────────────────────────────────────

  Future<Map<String, dynamic>> classifyIntent(String userInput) async {
    final raw = await _gemma.generate(
      systemPrompt: AgentPrompts.orchestrator(),
      userPrompt: 'Classify this request: "$userInput"',
    );
    return _parseJson(raw);
  }

  // ── TOPIC LEVEL ASSESSMENT ─────────────────────────────────────────────────

  Future<Map<String, dynamic>> assessTopicLevel(String topic) async {
    final history = await _memory.getFormattedHistory();
    final raw = await _gemma.generate(
      systemPrompt: '''
You are the Learner Twin Agent. Assess what level this student should study a topic at.
Return ONLY valid JSON:
{
  "level": "basics|intermediate|advanced",
  "reason": "one sentence why",
  "has_history": true|false,
  "past_accuracy": 0-100
}
''',
      userPrompt:
          'Student history:\n$history\n\nWhat level should they study "$topic"?',
    );
    try {
      return _parseJson(raw);
    } catch (_) {
      return {
        'level': 'basics',
        'reason': 'Starting fresh',
        'has_history': false,
        'past_accuracy': 0,
      };
    }
  }

  // ── STUDY PULSE (companion home card) ────────────────────────────────────

  Future<String> getStudyPulse() async {
    final history = await _memory.getFormattedHistory();
    if (history.isEmpty) {
      return "You're just getting started! Begin your first lesson to unlock personalized insights.";
    }
    return _gemma.generate(
      systemPrompt: '''
You are the Learner Twin Agent. Summarize this student's learning progress in 3–4 sentences.
Be specific — mention actual topics, scores, and trends. Be encouraging but honest.
Language: $_lang. Respond in $_lang.
''',
      userPrompt: 'Student learning history:\n$history\n\nWrite a study pulse summary.',
    );
  }

  // ── HELPERS ──────────────────────────────────────────────────────────────────

  String _storyUserPrompt(String topic, String level, String castIdsCsv) {
    return '''
Topic: "$topic". Level: $level. Cast: $castIdsCsv.

Output ONLY the JSON described in the system prompt — title + 6 scenes + 3 quiz questions.
characterId MUST be one of $castIdsCsv. Chat-energy. Dialogue ≤ 18 words.
''';
  }

  Map<String, dynamic> _parseJson(String raw) {
    final decoded = _parseJsonAny(raw);
    if (decoded is Map<String, dynamic>) return decoded;
    throw const FormatException('Expected JSON object');
  }

  /// Extracts the first balanced JSON object or array from [raw] and decodes
  /// it. Gemma often prefixes output with natural language ("Here's the
  /// breakdown...") and/or wraps it in markdown fences — both are stripped.
  dynamic _parseJsonAny(String raw) {
    var s = raw.trim();
    // Strip markdown fences anywhere in the string
    s = s.replaceAll(RegExp(r'```[a-zA-Z]*\n?'), '').replaceAll('```', '').trim();

    // Find the first { or [ and its balanced closer
    final startIdx = s.indexOf(RegExp(r'[\[{]'));
    if (startIdx < 0) {
      throw FormatException('No JSON found in response: '
          '${s.substring(0, s.length.clamp(0, 120))}');
    }
    final opener = s[startIdx];
    final closer = opener == '{' ? '}' : ']';
    var depth = 0;
    var inStr = false;
    var esc = false;
    var endIdx = -1;
    for (var i = startIdx; i < s.length; i++) {
      final c = s[i];
      if (inStr) {
        if (esc) {
          esc = false;
        } else if (c == '\\') {
          esc = true;
        } else if (c == '"') {
          inStr = false;
        }
        continue;
      }
      if (c == '"') {
        inStr = true;
      } else if (c == opener) {
        depth++;
      } else if (c == closer) {
        depth--;
        if (depth == 0) {
          endIdx = i;
          break;
        }
      }
    }
    final body = endIdx > 0 ? s.substring(startIdx, endIdx + 1) : s.substring(startIdx);
    return jsonDecode(body);
  }
}
