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

  // ── HELPERS ──────────────────────────────────────────────────────────────────

  String _sanitizeKey(String topic) =>
      topic.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');

  Future<int> _getQuizCount(int pid, String topic) async {
    final results = await _db.getQuizResults(pid, topic: topic);
    return results.length;
  }
}
