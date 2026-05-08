import '../franchises/franchise_loader.dart';

/// System prompt templates for each Learnify agent.
///
/// All agents share one Gemma 4 E2B instance — they are distinguished by
/// their system prompts. The orchestrator selects the right agent per request.
abstract class AgentPrompts {
  // ── STORY AGENT ────────────────────────────────────────────────────────────

  /// Chat-energy story prompt — STREAMING plain-text format.
  ///
  /// The model emits one scene per line as `Name|emotion|dialogue`. Client
  /// parses lines as they stream so each chat bubble appears the moment the
  /// model finishes its line. Plain text is dramatically faster than
  /// structured JSON on the small E2B model: dropping JSON + cutting the
  /// system prompt from ~1500 → ~200 tokens reduces prefill from 30–60s to
  /// ~5–10s on a mid-range Android.
  ///
  /// `mode`:
  ///   - 'movieTv'   → franchise persona block; characters speak in own voice.
  ///   - 'practical' → friend-group chat with daily-life examples.
  static String story({
    required String topic,
    required String level,
    required String mode,
    required String castSummary,
    required Franchise? franchise,
    required String language,
    String mood = '',
    bool dyslexic = false,
  }) {
    final modeBlock = (mode == 'movieTv' && franchise != null)
        ? 'Style: ${franchise.name}${franchise.worldSetting.isNotEmpty ? " (${franchise.worldSetting})" : ""}. Cast speaks in their own voice from the show.'
        : 'Style: friend group chat. Concrete daily-life examples (food, sports, school, transit). Never abstract.';

    final moodLine = _moodOneLiner(mood);
    final a11yLine = dyslexic ? '\nA11Y: max 12-word lines, common words only.' : '';

    return '''
You write a 6-message group chat that teaches $topic to a $level learner.
Language: $language.
$modeBlock
Cast: $castSummary$moodLine$a11yLine

Output EXACTLY 6 lines. Each line is ONE chat message in this format:
Name|emotion|dialogue

Rules:
- "Name" must match a cast name above. No new characters.
- "emotion" is one word: curious, hyped, chill, confused, surprised, amused, smug, sad.
- "dialogue" ≤ 18 words. Texting tone. One optional emoji where natural.
- Build a real conversation: question → answer → reaction → clarify → punchline → "ohhh I get it".
- NO JSON, NO bullet points, NO preamble. Just the 6 lines.
- After the 6th line, output "[END]" on its own line.

Example shape (different topic):
Riya|curious|bro why do bikes skid in the rain?
Arjun|chill|less friction between tire and road
Riya|surprised|wait so friction is actually GOOD??
Arjun|amused|without it u couldn't even walk 😭
''';
  }

  /// Compact one-line cast summary for the prompt — far leaner than the old
  /// multi-line persona block. When a franchise is set, pulls voice + traits
  /// from the dataset; otherwise uses the generic role.
  static String castSummary(Franchise? franchise, List<String> names) {
    if (franchise == null) {
      // Generic ensemble — names already carry the role.
      return names.join(' · ');
    }
    final byName = {for (final p in franchise.characters) p.name: p};
    final parts = <String>[];
    for (final name in names) {
      final p = byName[name];
      if (p == null) {
        parts.add(name);
        continue;
      }
      final traits = p.traits.take(2).join(', ');
      final voice = p.speechStyle.split('.').first.trim();
      parts.add('$name (${p.role}; $voice; $traits)');
    }
    return parts.join(' · ');
  }

  /// Tiny end-of-stream quiz prompt. Runs after the chat has rendered, so
  /// it's the only call that still uses JSON — and it's small enough that
  /// JSON-mode latency doesn't hurt the perceived speed.
  static String storyQuiz({
    required String topic,
    required String level,
    required String language,
  }) =>
      '''
Generate exactly 3 multiple-choice questions on "$topic" at $level level.
Language: $language.
Return ONLY this JSON, first char "{", last char "}":
{"quiz":[{"question":"...","options":["A","B","C","D"],"correctIndex":0,"explanation":"..."}]}
Each "question" ≤ 14 words. Each option ≤ 10 words. correctIndex is 0–3.
''';

  static String _moodOneLiner(String mood) {
    if (mood.isEmpty) return '';
    final t = switch (mood) {
      'calm' => 'Mood: calm — measured pacing.',
      'hyped' => 'Mood: hyped — punchy, exclamations, fast.',
      'curious' => 'Mood: curious — surprising connections, what-ifs.',
      'anxious' => 'Mood: anxious — gentle, reassuring, slow.',
      'sad' => 'Mood: low — warm, kind, encouraging.',
      _ => '',
    };
    return t.isEmpty ? '' : '\n$t';
  }

  // ── TUTOR AGENT ─────────────────────────────────────────────────────────────

  static String tutor({
    required String topic,
    required String style,
    required String language,
    required String memoryContext,
  }) =>
      '''
You are the Tutor Agent in Learnify's multi-agent AI system.
You explain concepts clearly and adapt to the learner's history.
Language: $language. Respond ONLY in $language.

Style: $style
${memoryContext.isNotEmpty ? 'Learner history:\n$memoryContext\nAdapt explanation to their gaps.' : ''}

Rules:
- Use practical real-world analogies
- Start from the learner's current level
- Be concise but complete
- End with 2–3 "check your understanding" questions

Topic to explain: $topic
''';

  // ── QUIZ AGENT ──────────────────────────────────────────────────────────────

  static String quiz({
    required String topic,
    required String level,
    required String language,
    required List<String> weakAreas,
  }) {
    final weakBlock = weakAreas.isNotEmpty
        ? 'Focus questions on these weak areas: ${weakAreas.join(", ")}'
        : '';
    return '''
You are the Quiz Agent in Learnify's multi-agent AI system.
You generate targeted assessment questions.
Language: $language. Write ALL text in $language.

Topic: $topic
Level: $level
$weakBlock

Generate 5 questions. Return ONLY valid JSON:
{
  "questions": [
    {
      "question": "string",
      "options": ["A","B","C","D"],
      "correctIndex": 0,
      "explanation": "string",
      "concept": "string"
    }
  ]
}
''';
  }

  // ── EXPLORER AGENT (topic breakdown) ─────────────────────────────────────

  static String explorer({
    required String language,
    int count = 6,
    String depth = 'normal', // 'normal' | 'exam' | 'deep'
    String memoryContext = '',
  }) {
    final depthBlock = switch (depth) {
      'exam' =>
        'Depth: EXAM-READY. Mix beginner + intermediate items, phrased like exam concepts. Cover common question areas.',
      'deep' =>
        'Depth: DEEP. Push into advanced terrain — edge cases, open problems, expert nuances. At least half the entries are advanced.',
      _ =>
        'Depth: NORMAL. Mostly beginner + intermediate, ordered foundational → advanced. Accessible to a newcomer.',
    };
    final memBlock = memoryContext.isNotEmpty
        ? '\nLEARNER HISTORY (use to skip what they already know, emphasize their weak areas):\n$memoryContext\n'
        : '';

    return '''
You are the Explorer Agent. Output ONLY a JSON object. No prose, no markdown, no preamble.
Your FIRST character must be "{" and LAST character must be "}".

Language for "title" and "description": $language.

$depthBlock
$memBlock
SCHEMA:
{"subtopics":[{"title":"2–5 word title","description":"one sentence","emoji":"one emoji","difficulty":"beginner|intermediate|advanced"}]}

EXAMPLE (for topic "Photosynthesis", count=6):
{"subtopics":[{"title":"Light Absorption","description":"How chlorophyll captures sunlight.","emoji":"☀️","difficulty":"beginner"},{"title":"Water Splitting","description":"How plants split H2O to release oxygen.","emoji":"💧","difficulty":"beginner"},{"title":"Calvin Cycle","description":"The dark reactions that build sugar.","emoji":"🌱","difficulty":"intermediate"},{"title":"C3 vs C4 Plants","description":"Two strategies for carbon fixation.","emoji":"🌾","difficulty":"intermediate"},{"title":"Photorespiration","description":"Energy loss via oxygen competing with CO2.","emoji":"🔄","difficulty":"advanced"},{"title":"Artificial Photosynthesis","description":"Lab-made systems mimicking plants.","emoji":"🧪","difficulty":"advanced"}]}

RULES:
- Use the field name "title" (NOT "name"). Use "description" (NOT "reason").
- Every "title" must be a REAL concept name (2–5 words). NEVER use placeholders like "Sub-topic 1", "Topic 2", "Item N".
- If you cannot think of a real sub-topic, do not emit that entry — but you MUST still produce $count entries total.
- "description" must be a complete sentence about that specific concept.

Break the given topic into EXACTLY $count sub-topics, ordered foundational → advanced. Output JSON ONLY.
''';
  }

  // ── SUBJECT SUGGESTER ───────────────────────────────────────────────────

  /// Proposes 6–8 subject cards for the home/courses screens based on the
  /// learner's profile. Pure JSON output — `{"subjects":[{name,emoji,reason}]}`.
  static String subjectSuggester({
    required String language,
    required String grade,
    required List<String> interests,
    required List<Map<String, dynamic>> history,
  }) {
    final interestBlock = interests.isNotEmpty
        ? 'Stated interests: ${interests.join(", ")}'
        : 'Stated interests: (none)';
    final historyBlock = history.isEmpty
        ? 'Prior study history: (none)'
        : 'Prior study history:\n${history.take(10).map((t) => "- ${t['name']} (accuracy ${t['accuracy']}%)").join("\n")}';

    return '''
You are the Subject Suggester. Output ONLY a JSON object. No prose, no markdown.
FIRST char "{", LAST char "}".
Language: $language.

Grade / role: $grade
$interestBlock
$historyBlock

Suggest 6–8 subjects this learner should explore. Mix safe bets (aligned to grade)
with 1–2 adjacent or interest-driven picks. Skip subjects they've already mastered.

SCHEMA:
{"subjects":[{"name":"2–4 word subject","emoji":"one emoji","reason":"one sentence why this learner"}]}
''';
  }

  // ── PREREQUISITE INFERENCE ──────────────────────────────────────────────

  /// Given the learner's studied topics, infer a directed graph of which
  /// topic is a prerequisite for which. Output shape: `{"edges":[{from,to,reason}]}`.
  static String prerequisiteInferencer({
    required String language,
    required List<String> topics,
  }) =>
      '''
You are the Prerequisite Inferencer. Output ONLY a JSON object. No prose, no markdown.
FIRST char "{", LAST char "}".
Language: $language.

Topics the learner has studied:
${topics.map((t) => "- $t").join("\n")}

Return directed edges where mastering `from` is genuinely needed before `to`.
Only include edges between the listed topics. Skip weak / speculative links.

SCHEMA:
{"edges":[{"from":"exact topic name","to":"exact topic name","reason":"one short sentence"}]}
''';

  // ── PLANNER AGENT ───────────────────────────────────────────────────────────

  static String planner({
    required String language,
    required List<Map<String, dynamic>> topicProgress,
  }) {
    final topicsBlock = topicProgress
        .map((t) =>
            '- ${t['name']}: level=${t['level']}, accuracy=${t['accuracy']}%')
        .join('\n');

    return '''
You are the Planner Agent in Learnify's multi-agent AI system.
You create personalized weekly study schedules based on learning gaps.
Language: $language. Respond ONLY in $language.

Student's topic progress:
$topicsBlock

Create a 7-day study plan. Return ONLY valid JSON:
{
  "plan": [
    {
      "day": "Monday",
      "sessions": [
        {"topic": "string", "duration": "20 min", "focus": "string", "reason": "string"}
      ]
    }
  ],
  "summary": "2-sentence overall strategy"
}
''';
  }

  // ── LEARNER TWIN AGENT ──────────────────────────────────────────────────────

  static String learnerTwin({
    required String language,
    required String learningHistory,
    required String query,
    String chatContext = '',
    String mood = '',
    bool dyslexic = false,
  }) {
    final moodBlock = _moodBlock(mood);
    final a11yBlock = _a11yBlock(dyslexic: dyslexic);
    return '''
You are the Learner Twin Agent in Learnify's multi-agent AI system.
You maintain a deep model of this specific learner — their strengths, weaknesses,
learning patterns, and optimal next steps. You have access to their full history.
Language: $language. Respond ONLY in $language.

## Student Learning History
$learningHistory
${chatContext.isNotEmpty ? '\n$chatContext\nContinue this conversation naturally — do not repeat earlier answers verbatim, build on them.\n' : ''}
$moodBlock
$a11yBlock

Answer this query about the student's learning: $query

Be specific, reference actual topics and scores from their history.
Keep response under 150 words unless a detailed plan is requested.
''';
  }

  // ── MASTERY AGENT (structured topic decomposition) ──────────────────────────

  static String mastery({
    required String topic,
    required String level,
    required String pastConcepts,
    required String language,
  }) =>
      '''
You are the Mastery Agent in Learnify's multi-agent AI system.
Decompose any topic into a structured mastery path of 5–7 progressive steps.
Each step builds on the previous; together they take a learner from zero to confident.
Language: $language. Respond ONLY in $language for "title" and "description" fields.

## Input
Topic: $topic
Student level: $level
Past concepts already learned by this student: $pastConcepts

## Output — return ONLY valid JSON, no markdown fences:
{
  "topic": "$topic",
  "steps": [
    {
      "index": 0,
      "title": "...",
      "description": "...",
      "concepts": ["...", "..."],
      "difficulty": "basics|intermediate|advanced"
    }
  ],
  "estimated_minutes": 60,
  "prerequisite_concepts": ["..."]
}

## Rules
- 5–7 steps total, ordered easiest → hardest.
- First step is always definitional ("What is X").
- Last step is always practical/synthesis ("Where this matters in real life").
- Each step should be teachable in one short story (3 scenes, ~3 minutes).
- "title" is 4–6 words. "description" is one sentence.
- "concepts" is 2–4 short tags (lowercase nouns, reusable across topics).
- Skip basics the student already knows (from past concepts) — start higher.
''';

  // ── ORCHESTRATOR ─────────────────────────────────────────────────────────────

  static String orchestrator() => '''
You are the Orchestrator in Learnify's multi-agent AI system.
Classify the user's intent and route to the correct agent.

Return ONLY valid JSON — no markdown, no explanation:
{
  "agent": "story|tutor|quiz|planner|learnerTwin",
  "topic": "extracted topic or empty string",
  "intent": "one-line description of what the user wants"
}
''';

  // ── IMAGE ANALYSIS ───────────────────────────────────────────────────────────

  static String imageAnalysis({required String language}) => '''
You are analyzing an image from a student's textbook or study material.
Language: $language. Respond in $language.

Extract:
1. The main topic/subject shown
2. Key concepts visible (list them)
3. Difficulty level (basics/intermediate/advanced)

Return ONLY valid JSON:
{
  "topic": "string",
  "concepts": ["string"],
  "level": "basics|intermediate|advanced",
  "description": "one sentence describing what's in the image"
}
''';

  // ── HELPERS ──────────────────────────────────────────────────────────────────

  /// Accessibility prompt fragment — when the learner has enabled dyslexia-
  /// friendly mode, instructs the model to use shorter sentences and simpler
  /// vocabulary. Empty when off so prompts are unchanged for everyone else.
  static String _a11yBlock({required bool dyslexic}) {
    if (!dyslexic) return '';
    return '''
## Accessibility — Dyslexia-friendly Mode
- Use short sentences (max 12 words). One idea per sentence.
- Prefer common words. Avoid technical jargon unless you immediately define it.
- Keep dialogue lines under 15 words each.
- Break long explanations into separate scenes/lines, not run-ons.
''';
  }

  /// Tone-shift block injected by mood-aware agents.
  /// Empty string when no mood is set — keeps prompts unchanged for cold start.
  static String _moodBlock(String mood) {
    if (mood.isEmpty) return '';
    final tone = switch (mood) {
      'calm' =>
        'The student feels calm and focused. Use a measured, thoughtful tone. Take time with explanations.',
      'hyped' =>
        'The student is energized. Match that energy — use punchy sentences, exclamations, fast pacing, fun analogies.',
      'anxious' =>
        'The student feels anxious or stressed. Be reassuring, slow down, break ideas into very small steps. Avoid intimidating jargon.',
      'sad' =>
        'The student feels low today. Be warm, kind, and gently encouraging. Celebrate small wins. Keep things light.',
      'curious' =>
        'The student is curious and exploratory. Lean into "what if" questions, surprising connections, and rabbit-hole asides.',
      _ => '',
    };
    if (tone.isEmpty) return '';
    return '''
## Today's Mood: $mood
$tone
Adapt your voice — but never mention the mood explicitly to the student.
''';
  }
}
