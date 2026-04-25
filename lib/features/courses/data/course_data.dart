// ─────────────────────────────────────────────────────────────────────────────
// Course Data Models for Learnify
//
// Static subject/chapter/lesson CONTENT has been removed — subjects are now
// suggested dynamically by GemmaOrchestrator.suggestSubjects() based on the
// learner's profile + history. These classes stay because they remain the
// type shape for legacy callers (lesson_screen, story_screen) that handle a
// `lessonId / chapterId / subjectId` route extra — if those fields are ever
// populated again (e.g. by a course-import feature), the types still fit.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

/// A single piece of lesson content (one card in the content phase).
class LessonContent {
  final String type; // 'text', 'code', 'highlight', 'example'
  final String title;
  final String body;

  const LessonContent({
    required this.type,
    required this.title,
    required this.body,
  });
}

/// A quiz question with 4 options.
class QuizQuestion {
  final String question;
  final List<String> options;
  final int correctIndex;
  final String explanation;

  const QuizQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });
}

/// A single lesson containing content cards and quiz questions.
class Lesson {
  final String id;
  final String title;
  final String description;
  final List<LessonContent> content;
  final List<QuizQuestion> quiz;
  final int xpReward;
  final String gameType; // 'interactive', 'quiz', 'simulation'

  const Lesson({
    required this.id,
    required this.title,
    this.description = '',
    required this.content,
    required this.quiz,
    this.xpReward = 100,
    this.gameType = 'quiz',
  });
}

/// A chapter within a subject.
class CourseChapter {
  final String id;
  final String title;
  final String description;
  final List<Lesson> lessons;

  const CourseChapter({
    required this.id,
    required this.title,
    required this.description,
    required this.lessons,
  });
}

/// A top-level subject / course.
class CourseSubject {
  final String id;
  final String name;
  final String icon;
  final Color accentColor;
  final List<CourseChapter> chapters;
  final bool comingSoon;

  const CourseSubject({
    required this.id,
    required this.name,
    required this.icon,
    required this.accentColor,
    required this.chapters,
    this.comingSoon = false,
  });
}

/// Subjects are generated dynamically by the Gemma orchestrator — see
/// `DynamicCatalogService.suggestedSubjects()`. This list is intentionally
/// empty so the home screen falls through to dynamic suggestions.
class CourseData {
  CourseData._();

  static const List<CourseSubject> allCourses = [];
}
