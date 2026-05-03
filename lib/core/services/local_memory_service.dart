import '../db/app_database.dart';
import 'local_profile_service.dart';

/// Local replacement for HindsightService.
///
/// Stores all learning events in SQLite. Before lesson generation,
/// formats relevant history as a context string injected into Gemma's prompt —
/// the same "memory injection" pattern as Hindsight, but fully offline.
class LocalMemoryService {
  LocalMemoryService._();
  static final LocalMemoryService instance = LocalMemoryService._();

  final _db = AppDatabase.instance;
  final _profile = LocalProfileService.instance;

  int? get _pid => _profile.currentProfile?.id;

  // ── RETAIN ───────────────────────────────────────────────────────────────────

  Future<void> retainQuizResult({
    required String topic,
    required String level,
    required String style,
    required int score,
    required int total,
    List<String> missedQuestions = const [],
    List<String> concepts = const [],
    String? pathTopicKey,
    int? pathStepIndex,
  }) async {
    final pid = _pid;
    if (pid == null) return;

    final accuracy = total > 0 ? (score / total * 100).round() : 0;
    final now = DateTime.now().toIso8601String();
    final topicKey = _sanitizeKey(topic);

    // Store raw quiz result
    await _db.insertQuizResult(pid, {
      'topic': topic,
      'level': level,
      'style': style,
      'score': score,
      'total': total,
      'missed_questions': AppDatabase.encodeList(missedQuestions),
      'concepts': AppDatabase.encodeList(concepts),
      'timestamp': now,
    });

    // Store memory event (Hindsight-style rich content)
    final content = [
      'Studied "$topic" at $level level using $style style.',
      'Score: $score/$total ($accuracy%).',
      if (missedQuestions.isNotEmpty)
        'Struggled with: ${missedQuestions.take(3).join(", ")}.',
      if (accuracy >= 70) 'Good performance — approaching mastery.',
      if (accuracy < 50) 'Needs review — low score on this attempt.',
    ].join(' ');

    await _db.insertMemoryEvent(pid, {
      'type': 'quiz_result',
      'content': content,
      'topic': topic,
      'tags': AppDatabase.encodeList([
        'topic:$topicKey',
        'level:$level',
        'accuracy:$accuracy',
        if (accuracy >= 70) 'mastered',
        if (accuracy < 50) 'needs_review',
      ]),
      'timestamp': now,
    });

    // Update or insert topic progress
    final stars = accuracy >= 90 ? 3 : accuracy >= 70 ? 2 : 1;
    final nextLevel = accuracy >= 70
        ? (level == 'basics' ? 'intermediate' : level == 'intermediate' ? 'advanced' : 'advanced')
        : level;

    await _db.upsertTopic(pid, {
      'name': topic,
      'topic_key': topicKey,
      'level': nextLevel,
      'accuracy': accuracy.toDouble(),
      'stars': stars,
      'quiz_count': await _getQuizCount(pid, topic) + 1,
      'last_studied': now,
    });

    // Update XP
    final xpGain = 35 + (accuracy >= 100 ? 15 : 0);
    await _profile.addXP(xpGain);

    // If this quiz was launched from a Mastery Path step, mark it complete on pass.
    if (pathTopicKey != null && pathStepIndex != null && accuracy >= 70) {
      final row = await _db.getTopicPath(pid, pathTopicKey);
      if (row != null) {
        final completed =
            AppDatabase.decodeList(row['completed_step_indices'] as String?)
                .map((e) => (e as num).toInt())
                .toSet()
              ..add(pathStepIndex);
        final steps = AppDatabase.decodeList(row['steps_json'] as String);
        var next = pathStepIndex + 1;
        while (next < steps.length && completed.contains(next)) {
          next++;
        }
        if (next >= steps.length) next = steps.length - 1;
        await _db.updateTopicPathProgress(
          pid,
          pathTopicKey,
          currentStepIndex: next,
          completedStepIndices: completed.toList()..sort(),
        );
      }
    }
  }

  Future<void> retainTopicInterest(String topic, {String level = 'basics'}) async {
    final pid = _pid;
    if (pid == null) return;
    await _db.insertMemoryEvent(pid, {
      'type': 'topic_interest',
      'content': 'Student explored topic "$topic" at $level level.',
      'topic': topic,
      'tags': AppDatabase.encodeList(['topic:${_sanitizeKey(topic)}', 'level:$level']),
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  Future<void> retainChatExchange(String query, String response, {String agent = 'companion'}) async {
    final pid = _pid;
    if (pid == null) return;
    await _db.insertChatMessage(pid, {
      'query': query,
      'response': response,
      'agent': agent,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  // ── RECALL (used to build context for Gemma prompts) ─────────────────────────

  /// Returns a formatted context string about a topic — injected into Gemma prompts.
  /// Mirrors HindsightService.getStudyContext().
  Future<String> getStudyContext(String topic) async {
    final pid = _pid;
    if (pid == null) return '';

    final events = await _db.getMemoryEvents(pid, topic: topic, limit: 10);
    final quizResults = await _db.getQuizResults(pid, topic: topic, limit: 5);

    if (events.isEmpty && quizResults.isEmpty) return '';

    final buffer = StringBuffer();
    buffer.writeln('## Student Learning History for "$topic"');

    if (quizResults.isNotEmpty) {
      buffer.writeln('Past quiz performance:');
      for (final r in quizResults.take(3)) {
        final acc = (r['score'] as int) / (r['total'] as int) * 100;
        final missed = AppDatabase.decodeList(r['missed_questions'] as String?);
        buffer.writeln(
            '- ${r['level']} level: ${acc.round()}% accuracy${missed.isNotEmpty ? ", struggled with: ${missed.take(2).join(", ")}" : ""}');
      }
    }

    if (events.isNotEmpty) {
      buffer.writeln('Learning events:');
      for (final e in events.take(5)) {
        buffer.writeln('- ${e['content']}');
      }
    }

    return buffer.toString();
  }

  /// Full history formatted for Learner Twin and companion queries.
  Future<String> getFormattedHistory() async {
    final pid = _pid;
    if (pid == null) return '';

    final topics = await _db.getTopics(pid);
    final recentEvents = await _db.getMemoryEvents(pid, limit: 30);

    if (topics.isEmpty && recentEvents.isEmpty) return 'No learning history yet.';

    final buffer = StringBuffer();

    if (topics.isNotEmpty) {
      buffer.writeln('## Topics Studied');
      for (final t in topics) {
        buffer.writeln(
            '- ${t['name']}: ${t['level']} level, ${(t['accuracy'] as double).round()}% accuracy, '
            '${t['stars']} stars, ${t['quiz_count']} quizzes');
      }
      buffer.writeln();
    }

    if (recentEvents.isNotEmpty) {
      buffer.writeln('## Recent Activity');
      for (final e in recentEvents.take(15)) {
        buffer.writeln('- ${e['content']}');
      }
    }

    return buffer.toString();
  }

  Future<List<Map<String, dynamic>>> getAllTopicProgress() async {
    final pid = _pid;
    if (pid == null) return [];
    final topics = await _db.getTopics(pid);
    return topics.map((t) => {
      'name': t['name'],
      'level': t['level'],
      'accuracy': (t['accuracy'] as double).round(),
      'stars': t['stars'],
    }).toList();
  }

  /// Past missed questions + low-accuracy concepts for a topic — fed into
  /// the Quiz / Story prompt so generated questions target real weak spots.
  Future<List<String>> getWeakAreas(String topic, {int limit = 5}) async {
    final pid = _pid;
    if (pid == null) return [];
    final results = await _db.getQuizResults(pid, topic: topic, limit: 10);
    final seen = <String>{};
    final out = <String>[];
    for (final r in results) {
      final missed = AppDatabase.decodeList(r['missed_questions'] as String?);
      for (final m in missed) {
        if (m.trim().isEmpty) continue;
        if (seen.add(m)) out.add(m);
        if (out.length >= limit) return out;
      }
    }
    return out;
  }

  // ── MASTERY PATHS ────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> getMasteryPath(String topic) async {
    final pid = _pid;
    if (pid == null) return null;
    final row = await _db.getTopicPath(pid, _sanitizeKey(topic));
    if (row == null) return null;
    return _decodePath(row);
  }

  Future<List<Map<String, dynamic>>> getActiveMasteryPaths() async {
    final pid = _pid;
    if (pid == null) return [];
    final rows = await _db.getAllTopicPaths(pid);
    return rows.map(_decodePath).toList();
  }

  Future<void> saveMasteryPath({
    required String topic,
    required List<Map<String, dynamic>> steps,
    int estimatedMinutes = 0,
  }) async {
    final pid = _pid;
    if (pid == null) return;
    final now = DateTime.now().toIso8601String();
    await _db.upsertTopicPath(pid, {
      'topic_key': _sanitizeKey(topic),
      'topic_name': topic,
      'steps_json': AppDatabase.encodeList(steps),
      'current_step_index': 0,
      'completed_step_indices': '[]',
      'estimated_minutes': estimatedMinutes,
      'created_at': now,
      'updated_at': now,
    });
  }

  /// Mark a step done. Auto-advances current_step_index to the next unfinished step.
  Future<void> markStepComplete(String topic, int stepIndex) async {
    final pid = _pid;
    if (pid == null) return;
    final row = await _db.getTopicPath(pid, _sanitizeKey(topic));
    if (row == null) return;

    final completed = AppDatabase.decodeList(row['completed_step_indices'] as String?)
        .map((e) => (e as num).toInt())
        .toSet()
      ..add(stepIndex);

    final steps = AppDatabase.decodeList(row['steps_json'] as String);
    final totalSteps = steps.length;
    var next = stepIndex + 1;
    while (next < totalSteps && completed.contains(next)) {
      next++;
    }
    if (next >= totalSteps) next = totalSteps - 1;

    await _db.updateTopicPathProgress(
      pid,
      _sanitizeKey(topic),
      currentStepIndex: next,
      completedStepIndices: completed.toList()..sort(),
    );
  }

  Map<String, dynamic> _decodePath(Map<String, dynamic> row) {
    final steps = AppDatabase.decodeList(row['steps_json'] as String?)
        .cast<Map<String, dynamic>>();
    final completed = AppDatabase.decodeList(row['completed_step_indices'] as String?)
        .map((e) => (e as num).toInt())
        .toList();
    return {
      'topic': row['topic_name'],
      'topicKey': row['topic_key'],
      'steps': steps,
      'currentStepIndex': row['current_step_index'] as int? ?? 0,
      'completedStepIndices': completed,
      'estimatedMinutes': row['estimated_minutes'] as int? ?? 0,
    };
  }

  /// Last N chat exchanges with this agent, formatted as a short transcript.
  /// Injected into Learner-Twin prompts so the Companion remembers prior turns
  /// across sessions instead of starting cold every time.
  Future<String> getRecentChatContext({String agent = 'companion', int limit = 8}) async {
    final pid = _pid;
    if (pid == null) return '';
    final rows = await _db.getChatHistory(pid, agent: agent, limit: limit);
    if (rows.isEmpty) return '';
    final buf = StringBuffer('## Recent Conversation (oldest first)\n');
    for (final r in rows) {
      final q = (r['query'] as String?)?.trim() ?? '';
      final a = (r['response'] as String?)?.trim() ?? '';
      if (q.isEmpty && a.isEmpty) continue;
      if (q.isNotEmpty) buf.writeln('Student: $q');
      if (a.isNotEmpty) buf.writeln('You: $a');
    }
    return buf.toString();
  }

  // ── HELPERS ──────────────────────────────────────────────────────────────────

  String _sanitizeKey(String topic) =>
      topic.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');

  Future<int> _getQuizCount(int pid, String topic) async {
    final results = await _db.getQuizResults(pid, topic: topic);
    return results.length;
  }
}
