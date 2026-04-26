import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../core/ai/gemma_service.dart';
import '../../features/story_learning/models/story_response.dart';
import '../data/franchise_loader.dart';
import 'lab_memory_service.dart';

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

  // ── STORY ──────────────────────────────────────────────────────────────────

  /// Generates a franchise-styled story lesson in a single Gemma call.
  Future<StoryResponse> generateFranchiseStory({
    required String topic,
    required String difficulty, // 'beginner' | 'intermediate' | 'advanced'
    required Franchise? franchise,
  }) async {
    final memCtx = await _memory.getStudyContext(topic);
    await _memory.retainTopicInterest(topic, level: difficulty);
    if (franchise != null) {
      await _memory.bumpFranchiseUsage(
        franchiseId: franchise.id,
        franchiseName: franchise.name,
      );
    }

    final systemPrompt = _buildSystemPrompt(franchise, memCtx);
    final userPrompt = _buildUserPrompt(topic, difficulty);

    Future<String> run(String user) => _gemma.generate(
          systemPrompt: systemPrompt,
          userPrompt: user,
          maxTokens: 8192,
        );

    String raw = await run(userPrompt);
    debugPrint('[Lab.story] raw 1 length=${raw.length}');
    Map<String, dynamic>? parsed = _tryParseOrRepair(raw);

    if (parsed == null) {
      raw = await run(
        'Your previous response was unusable JSON. Generate the lesson again.\n'
        'Topic: "$topic". Difficulty: $difficulty.\n'
        'Output ONLY the JSON object — start with { and end with }. Keep ALL '
        'dialogue under 80 characters so the JSON fits in one response.',
      );
      debugPrint('[Lab.story] raw 2 length=${raw.length}');
      parsed = _tryParseOrRepair(raw);
      if (parsed == null) {
        throw FormatException(
            'Lab story JSON parse failed twice. Last response (first 240 chars): '
            '${raw.substring(0, raw.length.clamp(0, 240))}');
      }
    }
    return StoryResponse.fromJson(parsed);
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

  String _buildUserPrompt(String topic, String difficulty) {
    final levelHint = switch (difficulty) {
      'intermediate' =>
        'Knows the basics. Show one connection + one real-world use.',
      'advanced' =>
        'Cover one edge case + one common misconception. Plain language.',
      _ => 'Complete beginner. Use analogies first.',
    };
    return '''
Create a franchise-styled visual-novel story lesson:
Topic: $topic
Difficulty: $difficulty
Level guidance: $levelHint

Use plain, friendly English. Dialogue ≤25 words per line. Quiz options ≤12 words.
''';
  }

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
