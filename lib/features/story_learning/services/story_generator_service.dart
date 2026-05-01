import '../../../core/ai/gemma_orchestrator.dart';
import '../../../features/courses/data/course_data.dart';
import '../models/story_response.dart';
import '../models/story_style.dart';

/// Thin adapter — delegates to GemmaOrchestrator (on-device Gemma 4 E2B).
///
/// Kept as a service class so existing screens can be migrated without
/// rewriting call sites. All heavy lifting lives in GemmaOrchestrator.
class StoryGeneratorService {
  StoryGeneratorService();

  final _orchestrator = GemmaOrchestrator.instance;

  /// Generates a story for the given lesson and style.
  /// On-device Gemma 4 E2B reads past learning from SQLite and adapts.
  Future<StoryResponse> generateStory({
    required Lesson lesson,
    required String subjectId,
    required String chapterTitle,
    required StoryStyle style,
    String? franchiseName,
  }) async {
    final topic = '${lesson.title} — $chapterTitle';
    return _orchestrator.generateStory(
      topic: topic,
      style: style.promptKey,
      franchiseName: franchiseName ?? '',
      level: 'basics',
    );
  }

  /// Generates a story for a custom topic (user-typed or image-scanned).
  Future<StoryResponse> generateStoryFromTopic({
    required String topic,
    required StoryStyle style,
    String? franchiseName,
    String level = 'basics',
  }) =>
      _orchestrator.generateStory(
        topic: topic,
        style: style.promptKey,
        franchiseName: franchiseName ?? '',
        level: level,
      );
}
