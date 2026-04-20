import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// The narrative style for AI-generated stories.
/// One-tap switch between these = the hackathon demo's "wow" moment.
enum StoryStyle {
  story,
  practical,
  professional,
  beginner,
  exam,
  movieTv;

  String get label => switch (this) {
        StoryStyle.story => 'Story',
        StoryStyle.practical => 'Practical',
        StoryStyle.professional => 'Professional',
        StoryStyle.beginner => 'Beginner',
        StoryStyle.exam => 'Exam',
        StoryStyle.movieTv => 'Movie / TV',
      };

  String get description => switch (this) {
        StoryStyle.story =>
          'Immersive narrative — characters live the concept through a story',
        StoryStyle.practical =>
          'Real-world approach — see how concepts work in actual life',
        StoryStyle.professional =>
          'Industry-grade — technical depth for professionals',
        StoryStyle.beginner =>
          'Absolute simplest — no jargon, lots of analogies',
        StoryStyle.exam =>
          'Exam-focused — concise, precise, test-ready',
        StoryStyle.movieTv =>
          'Through your favorite movie, TV show, anime or cartoon',
      };

  IconData get icon => switch (this) {
        StoryStyle.story => Icons.auto_stories_rounded,
        StoryStyle.practical => Icons.build_circle_rounded,
        StoryStyle.professional => Icons.workspace_premium_rounded,
        StoryStyle.beginner => Icons.child_care_rounded,
        StoryStyle.exam => Icons.fact_check_rounded,
        StoryStyle.movieTv => Icons.live_tv_rounded,
      };

  Color get color => switch (this) {
        StoryStyle.story => AppTheme.accentPurple,
        StoryStyle.practical => AppTheme.accentGreen,
        StoryStyle.professional => AppTheme.accentCyan,
        StoryStyle.beginner => const Color(0xFFFFB74D),
        StoryStyle.exam => const Color(0xFFFF6B9D),
        StoryStyle.movieTv => AppTheme.accentCyan,
      };

  /// Key used in Gemma system prompts — maps to [AgentPrompts._styleBlock].
  String get promptKey => switch (this) {
        StoryStyle.story => 'story',
        StoryStyle.practical => 'practical',
        StoryStyle.professional => 'professional',
        StoryStyle.beginner => 'beginner',
        StoryStyle.exam => 'exam',
        StoryStyle.movieTv => 'movie_tv',
      };

  /// Back-compat for older call sites.
  String get promptInstructions => '';

  static String franchisePromptInstructions(String name) =>
      'Set the story in the universe of "$name" using its actual characters.';
}
