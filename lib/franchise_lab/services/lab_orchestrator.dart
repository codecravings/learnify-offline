import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../core/ai/gemma_service.dart';
import '../../features/story_learning/models/story_response.dart';
import '../../features/story_learning/models/story_scene.dart';
import '../data/franchise_loader.dart';
import 'lab_memory_service.dart';

/// One progressive piece of a lab story as it streams in.
enum LabStoryChunkKind { intro, moreScenes, quiz }

class LabStoryChunk {
  const LabStoryChunk._({
    required this.kind,
    this.title,
    this.characters = const [],
    this.scenes = const [],
    this.quiz = const [],
  });

  factory LabStoryChunk.intro({
    required String title,
    required List<FranchiseCharacter> characters,
    required List<StoryScene> firstScenes,
  }) =>
      LabStoryChunk._(
        kind: LabStoryChunkKind.intro,
        title: title,
        characters: characters,
        scenes: firstScenes,
      );

  factory LabStoryChunk.moreScenes(List<StoryScene> scenes) => LabStoryChunk._(
        kind: LabStoryChunkKind.moreScenes,
        scenes: scenes,
      );

  factory LabStoryChunk.quiz(List<StoryQuizQuestion> questions) =>
      LabStoryChunk._(
        kind: LabStoryChunkKind.quiz,
        quiz: questions,
      );

  final LabStoryChunkKind kind;
  final String? title;
  final List<FranchiseCharacter> characters;
  final List<StoryScene> scenes;
  final List<StoryQuizQuestion> quiz;
}

/// Lab orchestrator for franchise-style story generation + companion chat.
///
/// Reuses the production GemmaService singleton (no model duplication) but
/// builds its own prompt shape from the franchise persona dataset rather
/// than the production AgentPrompts.story shell.
class LabOrchestrator {
  LabOrchestrator._();
  static final LabOrchestrator instance = LabOrchestrator._();

  final _gemma = GemmaService.instance;
  final _memory = LabMemoryService.instance;

  // ── SUB-TOPICS ─────────────────────────────────────────────────────────────

  /// Break a topic into a list of sub-topics so the user can pick which
  /// concept to learn first. Difficulty drives how many we ask for.
  /// Returns a list of `{title, description}` maps.
  Future<List<Map<String, dynamic>>> generateSubtopics({
    required String topic,
    required String difficulty,
  }) async {
    final count = switch (difficulty) {
      'intermediate' => 6,
      'advanced' => 8,
      _ => 5,
    };
    final depth = switch (difficulty) {
      'intermediate' => 'normal',
      'advanced' => 'deep',
      _ => 'normal',
    };
    final systemPrompt = '''
You are the Sub-topic Splitter. Output ONLY a JSON object — no prose, no markdown.
First char "{", last char "}".

Break "$topic" into EXACTLY $count sub-topics suited for a $difficulty learner.

RULES:
- Use simple, friendly English. NO jargon. NO heavy academic words.
- Each "title" is a real concept name in 2-5 words a 10-year-old could understand.
- Each "description" is one short sentence (under 18 words) about what the sub-topic covers.
- Order from easiest to hardest.
- Avoid these words entirely: encapsulation, polymorphism, abstraction, paradigm, leverage, ecosystem, vectorization, deployment, modularity, methodology, framework, optimization.

SCHEMA:
{"subtopics":[{"title":"...","description":"..."}]}

EXAMPLE for topic "Fractions" at beginner level, count=5:
{"subtopics":[{"title":"What is a Fraction","description":"How a fraction shows part of a whole, like a slice of pizza."},{"title":"Numerator and Denominator","description":"The top number tells how many pieces; the bottom tells the total."},{"title":"Equivalent Fractions","description":"Different fractions that show the same amount, like 1/2 and 2/4."},{"title":"Comparing Fractions","description":"Which slice is bigger? Easy ways to tell."},{"title":"Adding Fractions","description":"How to add fractions when the bottoms match."}]}
''';

    Future<String> run(String user) => _gemma.generate(
          systemPrompt: systemPrompt,
          userPrompt: user,
          maxTokens: 2048,
        );

    String raw = await run(
        'Topic: "$topic". Difficulty: $difficulty. Count: $count. Output the JSON now.');
    debugPrint('[Lab.subtopics] raw 1 length=${raw.length} depth=$depth');
    var parsed = _tryParseOrRepair(raw);
    if (parsed == null) {
      raw = await run(
          'Your previous response was unusable. Topic: "$topic". Output ONLY a JSON object with key "subtopics" containing exactly $count entries. Start with { and end with }.');
      debugPrint('[Lab.subtopics] raw 2 length=${raw.length}');
      parsed = _tryParseOrRepair(raw);
    }
    if (parsed == null) return const [];
    final list = parsed['subtopics'];
    if (list is! List) return const [];
    final placeholderRe = RegExp(
      r'^(sub[\s\-]?topic|topic|item|subtopic|untitled)\s*\d*$',
      caseSensitive: false,
    );
    return list
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .where((m) {
      final t = (m['title'] as String?)?.trim() ?? '';
      return t.isNotEmpty && !placeholderRe.hasMatch(t);
    }).toList();
  }

  // ── STORY ──────────────────────────────────────────────────────────────────

  /// Progressive story generation. Yields a [LabStoryChunk] each time a
  /// piece of the story is ready (intro → more scenes → quiz). The UI can
  /// render scene 1 while Gemma is still working on later scenes + quiz.
  Stream<LabStoryChunk> streamFranchiseStory({
    required String topic,
    required String difficulty,
    required Franchise? franchise,
  }) async* {
    final memCtx = await _memory.getStudyContext(topic);
    await _memory.retainTopicInterest(topic, level: difficulty);
    if (franchise != null) {
      await _memory.bumpFranchiseUsage(
        franchiseId: franchise.id,
        franchiseName: franchise.name,
      );
    }

    // Build the cast in DART, not in Gemma. Gemma physically cannot pick
    // wrong names because we never ask it to produce the cast — we only
    // ask it to write scenes referencing characterIds we hand it.
    final cast = _buildCast(franchise);
    final castIds = cast.map((c) => c.id).toList();
    final castIdsCsv = castIds.map((id) => '"$id"').join(', ');
    final castDescription = _castDescriptionForPrompt(franchise, cast);

    final systemPrompt = _buildSystemPrompt(franchise, memCtx);
    final levelHint = _levelHint(difficulty);
    final title = _topicTitle(topic, difficulty);

    // ── Call A: scene 1 ─────────────────────────────────────────────────
    final introUser = _scenesUserPrompt(
      part: 1,
      totalParts: 3,
      topic: topic,
      difficulty: difficulty,
      levelHint: levelHint,
      castDescription: castDescription,
      castIdsCsv: castIdsCsv,
      sceneCount: 1,
      previousScenes: 0,
    );
    final intro = await _runJsonRetry('scenes1', systemPrompt, introUser);
    final scene1 = intro == null ? const <StoryScene>[] : _parseScenes(intro['scenes']);
    if (scene1.isEmpty) {
      throw const FormatException(
          'Could not generate the opening scene. Try again, or pick a simpler topic.');
    }
    yield LabStoryChunk.intro(
      title: title,
      characters: cast,
      firstScenes: _retagSceneIds(scene1, castIds),
    );

    // ── Call B: scenes 2 + 3 ────────────────────────────────────────────
    final moreUser = _scenesUserPrompt(
      part: 2,
      totalParts: 3,
      topic: topic,
      difficulty: difficulty,
      levelHint: levelHint,
      castDescription: castDescription,
      castIdsCsv: castIdsCsv,
      sceneCount: 2,
      previousScenes: scene1.length,
    );
    final more = await _runJsonRetry('scenes2', systemPrompt, moreUser);
    final moreScenes =
        more == null ? const <StoryScene>[] : _parseScenes(more['scenes']);
    yield LabStoryChunk.moreScenes(_retagSceneIds(moreScenes, castIds));

    // ── Call C: quiz ────────────────────────────────────────────────────
    final quizUser = '''
Generate the quiz. Topic: $topic.

Output ONLY this JSON:
{"quiz":[{"question":"string","options":["A","B","C","D"],"correctIndex":0,"explanation":"string"}]}

Rules: exactly 3 questions. Each option ≤12 words. Plain English.
''';
    final quiz = await _runJsonRetry('quiz', systemPrompt, quizUser);
    final quizQuestions =
        quiz == null ? const <StoryQuizQuestion>[] : _parseQuiz(quiz['quiz']);
    yield LabStoryChunk.quiz(quizQuestions);
  }

  Future<Map<String, dynamic>?> _runJsonRetry(
    String tag,
    String systemPrompt,
    String userPrompt,
  ) async {
    Future<String> run(String user) => _gemma.generate(
          systemPrompt: systemPrompt,
          userPrompt: user,
          maxTokens: 4096,
        );
    String raw = await run(userPrompt);
    debugPrint('[Lab.$tag] raw 1 length=${raw.length}');
    var parsed = _tryParseOrRepair(raw);
    if (parsed != null) return parsed;
    raw = await run(
      'Previous response was unusable. Output ONLY a JSON object that matches '
      'the schema described — no prose, no markdown, no wrapper key. Start '
      'with { and end with }. Keep strings short.',
    );
    debugPrint('[Lab.$tag] raw 2 length=${raw.length}');
    return _tryParseOrRepair(raw);
  }

  String _levelHint(String difficulty) => switch (difficulty) {
        'intermediate' =>
          'Knows the basics. Show one connection + one real-world use.',
        'advanced' =>
          'Cover one edge case + one common misconception. Plain language.',
        _ => 'Complete beginner. Use analogies first.',
      };

  /// Build the cast directly from the dataset. Generic ensemble if no franchise.
  List<FranchiseCharacter> _buildCast(Franchise? franchise) {
    const palette = ['#3B82F6', '#EF4444', '#22C55E', '#F59E0B', '#8B5CF6'];
    if (franchise == null) {
      return const [
        FranchiseCharacter(
            id: 'mentor',
            name: 'Mentor',
            role: 'patient teacher',
            colorHex: '#3B82F6'),
        FranchiseCharacter(
            id: 'apprentice',
            name: 'Apprentice',
            role: 'eager learner',
            colorHex: '#EF4444'),
        FranchiseCharacter(
            id: 'skeptic',
            name: 'Skeptic',
            role: 'asks the hard questions',
            colorHex: '#22C55E'),
      ];
    }
    final out = <FranchiseCharacter>[];
    for (var i = 0; i < franchise.characters.length; i++) {
      final c = franchise.characters[i];
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
      return 'Generic cast (use these ids in characterId):\n${lines.join('\n')}';
    }
    final byName = {for (final p in franchise.characters) p.name: p};
    final buf = StringBuffer('Cast personalities (refer to them by id only):');
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

  /// Coerce any characterId not in the locked cast back to the first cast id.
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

  String _topicTitle(String topic, String difficulty) {
    final cap = topic.isEmpty
        ? 'Lesson'
        : topic[0].toUpperCase() + topic.substring(1);
    return '$cap — $difficulty';
  }

  String _scenesUserPrompt({
    required int part,
    required int totalParts,
    required String topic,
    required String difficulty,
    required String levelHint,
    required String castDescription,
    required String castIdsCsv,
    required int sceneCount,
    required int previousScenes,
  }) {
    return '''
Visual-novel lesson — part $part of $totalParts.
Topic: $topic
Difficulty: $difficulty
Level guidance: $levelHint

$castDescription

Already shown: $previousScenes scene${previousScenes == 1 ? '' : 's'}.

Output ONLY this JSON shape (no other keys, no wrapper):
{
  "scenes": [
    {"characterId":"<one of $castIdsCsv>","emotion":"string","dialogue":"string","narration":"string","conceptTag":"string"}
  ]
}

Rules:
- Exactly $sceneCount scene${sceneCount == 1 ? '' : 's'}.
- characterId MUST be one of $castIdsCsv. No new ids.
- Dialogue ≤25 words. Each scene introduces ONE idea via a real-world analogy first.
- Plain, friendly English. Avoid jargon.
''';
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

  /// Try strict parse first; on failure, try repairing a truncated/unterminated
  /// response. Returns null if both fail. Also tolerates Gemma wrapping the
  /// real payload in an extra outer key like {"story_lesson": {...real...}}.
  Map<String, dynamic>? _tryParseOrRepair(String raw) {
    if (raw.trim().isEmpty) return null;

    Map<String, dynamic>? decoded;
    try {
      decoded = _parseJson(raw);
    } catch (_) {
      // Fall through to repair.
    }
    if (decoded == null) {
      try {
        final repaired = _repairTruncatedJson(raw);
        if (repaired != null) {
          final v = jsonDecode(repaired);
          if (v is Map<String, dynamic>) decoded = v;
        }
      } catch (e) {
        debugPrint('[Lab] repair failed: $e');
      }
    }
    if (decoded == null) return null;

    // Schema keys we actually use across the lab calls.
    const expected = {
      'title', 'characters', 'scenes', 'quiz', 'subtopics',
    };
    final hasExpected = decoded.keys.any(expected.contains);
    if (hasExpected) return decoded;

    // No expected keys — Gemma probably wrapped it. If there's exactly one
    // Map child, hoist it.
    final mapChildren = decoded.entries.where((e) => e.value is Map).toList();
    if (mapChildren.length == 1) {
      final unwrapped = Map<String, dynamic>.from(mapChildren.first.value as Map);
      debugPrint('[Lab] unwrapped outer key "${mapChildren.first.key}"');
      return unwrapped;
    }
    return decoded;
  }

  /// Repair a JSON object that was cut off mid-stream (model hit a token cap
  /// or emitted EOS too early). Walks the string once, tracking string + escape
  /// state, finds the depth at the end, and closes everything that's still open.
  /// Trims any trailing partial value (string/number/keyword) before closing.
  String? _repairTruncatedJson(String raw) {
    var s = raw.trim();
    s = s.replaceAll(RegExp(r'```[a-zA-Z]*\n?'), '').replaceAll('```', '').trim();
    final start = s.indexOf('{');
    if (start < 0) return null;
    s = s.substring(start);

    final stack = <String>[];
    var inStr = false;
    var esc = false;
    var lastSafeIdx = -1;
    for (var i = 0; i < s.length; i++) {
      final c = s[i];
      if (inStr) {
        if (esc) {
          esc = false;
        } else if (c == '\\') {
          esc = true;
        } else if (c == '"') {
          inStr = false;
          lastSafeIdx = i;
        }
        continue;
      }
      if (c == '"') {
        inStr = true;
        continue;
      }
      if (c == '{' || c == '[') {
        stack.add(c);
      } else if (c == '}') {
        if (stack.isEmpty || stack.removeLast() != '{') return null;
        lastSafeIdx = i;
      } else if (c == ']') {
        if (stack.isEmpty || stack.removeLast() != '[') return null;
        lastSafeIdx = i;
      } else if (c == ',' || c == ':') {
        lastSafeIdx = i;
      }
    }

    if (lastSafeIdx < 0) return null;
    var trimmed = s.substring(0, lastSafeIdx + 1);

    // Re-walk the trimmed body to recompute the open-stack.
    stack.clear();
    inStr = false;
    esc = false;
    for (var i = 0; i < trimmed.length; i++) {
      final c = trimmed[i];
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
      } else if (c == '{' || c == '[') {
        stack.add(c);
      } else if (c == '}' || c == ']') {
        if (stack.isNotEmpty) stack.removeLast();
      }
    }

    final trailingComma = RegExp(r',\s*$');
    trimmed = trimmed.replaceAll(trailingComma, '');

    final closer = StringBuffer(trimmed);
    while (stack.isNotEmpty) {
      final open = stack.removeLast();
      closer.write(open == '{' ? '}' : ']');
    }
    return closer.toString();
  }

  // ── COMPANION ──────────────────────────────────────────────────────────────

  /// Streaming companion reply. Caller persists exchanges via
  /// `LabMemoryService.retainChatExchange` once the stream completes.
  Stream<String> companionStream(String query) async* {
    final history = await _memory.getFormattedHistory();
    final systemPrompt = '''
You are the Learner Twin Companion in Franchise Lab — a warm, on-device study buddy.
You answer questions about what the learner has studied, what they're weak in, what
to study next, and offer encouragement. Be specific — reference actual topics from
their history when answering. Keep replies under 150 words unless they explicitly
ask for a plan.

## Learner History
${history.isEmpty ? '(empty — they have not studied anything yet)' : history}
''';

    yield* _gemma.generateStream(
      systemPrompt: systemPrompt,
      userPrompt: query,
    );
  }

  // ── PROMPT BUILDERS ────────────────────────────────────────────────────────

  String _buildSystemPrompt(Franchise? franchise, String memoryContext) {
    final personaBlock = franchise == null
        ? _genericStoryBlock()
        : _franchisePersonaBlock(franchise);

    final memBlock = memoryContext.isEmpty
        ? ''
        : '''
## Learner History (use to personalise — recap mastered points, target weak ones)
$memoryContext
''';

    return '''
You are the Franchise Lab Story Agent — a creative educational storyteller.
You produce short visual-novel scenes where 2-4 characters teach the topic through dialogue.

$personaBlock
$memBlock

## Story Rules
- 3 to 5 scenes total. Each scene = one character speaking.
- Every scene must teach something — no fluff.
- After the scenes, generate exactly 3 quiz questions, 4 options each (correctIndex is 0-based).

## Output — return ONLY valid JSON, no markdown fences, no preamble:
{
  "title": "string — short lesson title",
  "characters": [{"id":"slug","name":"persona name","role":"short role","color":"#HEX"}],
  "scenes": [{"characterId":"slug","emotion":"string","dialogue":"string","narration":"string","conceptTag":"string"}],
  "quiz": [{"question":"string","options":["A","B","C","D"],"correctIndex":0,"explanation":"string"}]
}
''';
  }

  String _franchisePersonaBlock(Franchise f) {
    final buf = StringBuffer()
      ..writeln('## Franchise Mode — ${f.name}')
      ..writeln('Cast — use these EXACT character names in dialogue:');
    for (final c in f.characters) {
      final sample = c.sampleDialogues.isNotEmpty ? c.sampleDialogues.first : '';
      buf.writeln(
        '- ${c.name} — ${c.role}; traits ${c.traits.take(3).join('/')}; '
        'voice ${c.speechStyle}'
        '${sample.isNotEmpty ? '; vibe-line "$sample"' : ''}',
      );
    }
    return buf.toString();
  }

  String _genericStoryBlock() => '''
## Story Mode
Pick 2-4 distinct original characters who would be interesting teachers of this topic.
Make their voices distinct.
''';

  // ── JSON ───────────────────────────────────────────────────────────────────

  Map<String, dynamic> _parseJson(String raw) {
    var s = raw.trim();
    s = s.replaceAll(RegExp(r'```[a-zA-Z]*\n?'), '').replaceAll('```', '').trim();
    final startIdx = s.indexOf('{');
    if (startIdx < 0) {
      throw const FormatException('No { found in response');
    }
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
      } else if (c == '{') {
        depth++;
      } else if (c == '}') {
        depth--;
        if (depth == 0) {
          endIdx = i;
          break;
        }
      }
    }
    final body = endIdx > 0 ? s.substring(startIdx, endIdx + 1) : s.substring(startIdx);
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    throw const FormatException('JSON root is not an object');
  }
}
