import '../data/lab_database.dart';
import 'lab_profile_service.dart';

/// Lab-scoped memory service.
///
/// Mirrors LocalMemoryService API surface so screens can call the same
/// method names — but every read/write hits the isolated `franchise_lab.db`
/// instead of the main app database.
class LabMemoryService {
  LabMemoryService._();
  static final LabMemoryService instance = LabMemoryService._();

  final _db = LabDatabase.instance;
  final _profile = LabProfileService.instance;

  int? get _pid => _profile.currentProfile?.id;

  // ── RETAIN ───────────────────────────────────────────────────────────────────

  Future<void> retainQuizResult({
    required String topic,
    required String level,
    required String style,
    required int score,
    required int total,
    required List<String> missedQuestions,
    required List<String> concepts,
  }) async {
    final pid = _pid;
    if (pid == null) return;

    final accuracy = total > 0 ? (score / total * 100).round() : 0;
    final now = DateTime.now().toIso8601String();
    final topicKey = LabDatabase.sanitizeKey(topic);

    // Store raw quiz result
    await _db.insertQuizResult(pid, {
      'topic': topic,
      'level': level,
      'style': style,
      'score': score,
      'total': total,
      'missed_questions': LabDatabase.encodeList(missedQuestions),
      'concepts': LabDatabase.encodeList(concepts),
      'taken_at': now,
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
      'type': 'quiz_completed',
      'content': content,
      'topic': topic,
      'tags': LabDatabase.encodeList([
        'topic:$topicKey',
        'level:$level',
        'accuracy:$accuracy',
        if (accuracy >= 70) 'mastered',
        if (accuracy < 50) 'needs_review',
      ]),
      'created_at': now,
    });

    // Update or insert topic progress (with level promotion on >= 70%)
    final stars = accuracy >= 90
        ? 3
        : accuracy >= 70
            ? 2
            : 1;
    final nextLevel = accuracy >= 70
        ? (level == 'basics'
            ? 'intermediate'
            : level == 'intermediate'
                ? 'advanced'
                : 'advanced')
        : level;

    await _db.upsertTopic(pid, {
      'topic_key': topicKey,
      'topic_name': topic,
      'level': nextLevel,
      'accuracy': accuracy,
      'stars': stars,
      'quiz_count': await _getQuizCount(pid, topic) + 1,
      'last_studied': now,
    });

    // Update XP (35 base + 15 perfect bonus)
    final xpGain = 35 + (score == total ? 15 : 0);
    await _profile.addXP(xpGain);
  }

  Future<void> retainTopicInterest(String topic, {String level = 'basics'}) async {
    final pid = _pid;
    if (pid == null) return;
    await _db.insertMemoryEvent(pid, {
      'type': 'topic_started',
      'content': 'Student explored topic "$topic" at $level level.',
      'topic': topic,
      'tags': LabDatabase.encodeList([
        'topic:${LabDatabase.sanitizeKey(topic)}',
        'level:$level',
      ]),
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> retainChatExchange({
    required String question,
    required String answer,
  }) async {
    final pid = _pid;
    if (pid == null) return;
    await _db.insertMemoryEvent(pid, {
      'type': 'chat',
      'content': 'Q: $question\nA: $answer',
      'topic': null,
      'tags': LabDatabase.encodeList(['chat']),
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  // ── RECALL (used to build context for Gemma prompts) ─────────────────────────

  /// Returns a formatted context string about a topic — injected into Gemma prompts.
  /// Mirrors LocalMemoryService.getStudyContext().
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
        final missed =
            LabDatabase.decodeList(r['missed_questions'] as String?);
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
    final recentEvents = await _db.getMemoryEvents(pid, limit: 10);

    if (topics.isEmpty && recentEvents.isEmpty) return 'No learning history yet.';

    final buffer = StringBuffer();

    if (topics.isNotEmpty) {
      buffer.writeln('## Topics Studied');
      for (final t in topics) {
        buffer.writeln(
            '- ${t['topic_name']}: ${t['level']} level, ${t['accuracy']}% accuracy, '
            '${t['stars']} stars, ${t['quiz_count']} quizzes');
      }
      buffer.writeln();
    }

    if (recentEvents.isNotEmpty) {
      buffer.writeln('## Recent Activity');
      for (final e in recentEvents.take(10)) {
        buffer.writeln('- ${e['content']}');
      }
    }

    return buffer.toString();
  }

  Future<List<Map<String, dynamic>>> getAllTopicProgress() async {
    final pid = _pid;
    if (pid == null) return [];
    final topics = await _db.getTopics(pid);
    return topics
        .map((t) => {
              'name': t['topic_name'],
              'level': t['level'],
              'accuracy': t['accuracy'],
              'stars': t['stars'],
              'quizCount': t['quiz_count'],
              'lastStudied': t['last_studied'],
            })
        .toList();
  }

  // ── FRANCHISE USAGE ──────────────────────────────────────────────────────────

  Future<void> bumpFranchiseUsage({
    required String franchiseId,
    required String franchiseName,
  }) async {
    final pid = _pid;
    if (pid == null) return;
    final now = DateTime.now().toIso8601String();

    final existing = await _db.getFranchiseUsage(pid, franchiseId);
    final nextCount = (existing?['use_count'] as int? ?? 0) + 1;

    await _db.upsertFranchiseUsage(pid, {
      if (existing != null) 'id': existing['id'],
      'franchise_id': franchiseId,
      'franchise_name': franchiseName,
      'use_count': nextCount,
      'last_used': now,
    });
  }

  Future<List<Map<String, dynamic>>> getTopFranchises({int limit = 3}) async {
    final pid = _pid;
    if (pid == null) return [];
    return _db.getTopFranchises(pid, limit: limit);
  }

  Future<List<Map<String, dynamic>>> getRecentEvents({int limit = 10}) async {
    final pid = _pid;
    if (pid == null) return [];
    return _db.getMemoryEvents(pid, limit: limit);
  }

  // ── HELPERS ──────────────────────────────────────────────────────────────────

  Future<int> _getQuizCount(int pid, String topic) async {
    final results = await _db.getQuizResults(pid, topic: topic);
    return results.length;
  }
}
