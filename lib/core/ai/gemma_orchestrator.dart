import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../services/local_memory_service.dart';
import '../services/local_profile_service.dart';
import '../../features/story_learning/models/story_response.dart';
import 'agent_prompts.dart';
import 'gemma_service.dart';

/// Routes requests to the correct Gemma 4 agent based on intent.
///
/// All agents share one on-device Gemma 4 E4B instance.
/// Agent identity = system prompt. The orchestrator selects the right one.
class GemmaOrchestrator {
  GemmaOrchestrator._();
  static final GemmaOrchestrator instance = GemmaOrchestrator._();

  final _gemma = GemmaService.instance;
  final _memory = LocalMemoryService.instance;
  final _profile = LocalProfileService.instance;

  String get _lang => _profile.currentProfile?.language ?? 'English';

  // ── STORY AGENT ─────────────────────────────────────────────────────────────

  Future<StoryResponse> generateStory({
    required String topic,
    required String style,
    String franchiseName = '',
    String level = 'basics',
  }) async {
    final memCtx = await _memory.getStudyContext(topic);
    await _memory.retainTopicInterest(topic, level: level);

    final systemPrompt = AgentPrompts.story(
      style: style,
      franchiseName: franchiseName,
      memoryContext: memCtx,
      language: _lang,
    );

    final userPrompt = _storyUserPrompt(topic, level);
    final raw = await _gemma.generate(
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
      maxTokens: 4096,
    );

    return StoryResponse.fromJson(_parseJson(raw));
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
    String franchiseName = '',
  }) async {
    final analysis = await analyzeTextbookImage(imageBytes);
    final topic = analysis['topic'] as String? ?? 'Unknown Topic';
    final level = analysis['level'] as String? ?? 'basics';
    final concepts = (analysis['concepts'] as List?)?.cast<String>() ?? [];

    final memCtx = await _memory.getStudyContext(topic);

    final systemPrompt = AgentPrompts.story(
      style: style,
      franchiseName: franchiseName,
      memoryContext: memCtx,
      language: _lang,
    );

    final userPrompt = '''
Create a story lesson for this topic extracted from a student's textbook:

Topic: $topic
Level: $level
Key concepts to teach: ${concepts.join(', ')}

Make the lesson engaging and cover all concepts thoroughly.
''';

    final raw = await _gemma.generate(
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
      maxTokens: 4096,
    );

    return StoryResponse.fromJson(_parseJson(raw));
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
    final raw = await _gemma.generate(
      systemPrompt: AgentPrompts.quiz(
        topic: topic,
        level: level,
        language: _lang,
        weakAreas: weakAreas,
      ),
      userPrompt: 'Generate 5 quiz questions for topic: $topic at $level level.',
    );
    final parsed = _parseJson(raw);
    return List<Map<String, dynamic>>.from(parsed['questions'] ?? []);
  }

  // ── EXPLORER AGENT (topic breakdown) ─────────────────────────────────────

  Future<List<Map<String, dynamic>>> exploreTopic(String topic) async {
    Future<String> run(String userMsg) => _gemma.generate(
          systemPrompt: AgentPrompts.explorer(language: _lang),
          userPrompt: userMsg,
          maxTokens: 3072,
        );

    Map<String, dynamic> coerceItem(dynamic item) {
      // Gemma sometimes returns bare strings instead of objects — wrap them.
      if (item is String) {
        return {
          'title': item,
          'description': '',
          'emoji': '📌',
          'difficulty': 'beginner',
        };
      }
      if (item is Map) return Map<String, dynamic>.from(item);
      return {'title': item.toString(), 'description': '', 'emoji': '📌', 'difficulty': 'beginner'};
    }

    List<Map<String, dynamic>> extract(dynamic decoded) {
      if (decoded is List) return decoded.map(coerceItem).toList();
      if (decoded is Map<String, dynamic>) {
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
            return v.map(coerceItem).toList();
          }
        }
      }
      return const [];
    }

    String raw = await run(
      'Topic: "$topic". Output the JSON object now. Begin your response with { and nothing else. Include 6 to 8 entries in "subtopics".',
    );
    debugPrint('[Explorer] raw 1: ${raw.substring(0, raw.length.clamp(0, 300))}');
    var result = extract(_tryParse(raw));

    // Retry once if we got nothing usable (empty list or unparseable).
    if (result.isEmpty) {
      raw = await run(
        'Your previous response was unusable. Topic: "$topic". '
        'Output ONLY a JSON object with key "subtopics" containing a non-empty '
        'array of 6 to 8 objects. Start with { and end with }.',
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
    return _gemma.generate(
      systemPrompt: AgentPrompts.learnerTwin(
        language: _lang,
        learningHistory: history,
        query: query,
      ),
      userPrompt: query,
    );
  }

  Stream<String> queryLearnerTwinStream(String query) async* {
    final history = await _memory.getFormattedHistory();
    yield* _gemma.generateStream(
      systemPrompt: AgentPrompts.learnerTwin(
        language: _lang,
        learningHistory: history,
        query: query,
      ),
      userPrompt: query,
    );
  }

  // ── TEACHER AGENT ─────────────────────────────────────────────────────────

  Future<String> teacherQuery({
    required String request,
    List<Map<String, dynamic>> classData = const [],
  }) async {
    return _gemma.generate(
      systemPrompt: AgentPrompts.teacher(
        language: _lang,
        classData: classData,
        request: request,
      ),
      userPrompt: request,
    );
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

  String _storyUserPrompt(String topic, String level) {
    final levelGuide = switch (level) {
      'intermediate' =>
        'Student already knows fundamentals. Go deeper — connections, applications, technical vocab.',
      'advanced' =>
        'Expert level. Focus on nuances, edge cases, cutting-edge aspects. Challenge them.',
      _ =>
        'Complete beginner. Simple language, lots of analogies, build step by step.',
    };

    return '''
Create a story lesson:
Topic: $topic
Level: $level
Level guidance: $levelGuide
Requirements: 5–8 scenes, every concept with a real-world example, 3 quiz questions.
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
