import 'package:flutter/material.dart';

import 'story_scene.dart';

/// Quiz question generated as part of the story.
class StoryQuizQuestion {
  const StoryQuizQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });

  final String question;
  final List<String> options;
  final int correctIndex;
  final String explanation;

  factory StoryQuizQuestion.fromJson(Map<String, dynamic> json) {
    return StoryQuizQuestion(
      question: json['question'] as String? ?? '',
      options: (json['options'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      correctIndex: json['correctIndex'] as int? ?? 0,
      explanation: json['explanation'] as String? ?? '',
    );
  }
}

/// A character from a franchise, returned by the AI for custom style stories.
class FranchiseCharacter {
  const FranchiseCharacter({
    required this.id,
    required this.name,
    required this.role,
    required this.colorHex,
  });

  final String id;
  final String name;
  final String role;
  final String colorHex;

  Color get color {
    try {
      final hex = colorHex.replaceFirst('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return const Color(0xFF3B82F6);
    }
  }

  factory FranchiseCharacter.fromJson(Map<String, dynamic> json) {
    return FranchiseCharacter(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Character',
      role: json['role'] as String? ?? '',
      colorHex: json['color'] as String? ?? '#00F5FF',
    );
  }
}

/// The full response from the AI story generator.
class StoryResponse {
  const StoryResponse({
    required this.title,
    required this.scenes,
    required this.quiz,
    this.franchiseCharacters = const [],
  });

  final String title;
  final List<StoryScene> scenes;
  final List<StoryQuizQuestion> quiz;

  /// AI-generated characters for the story (populated for all styles).
  final List<FranchiseCharacter> franchiseCharacters;

  /// Look up a franchise character by ID.
  FranchiseCharacter? getFranchiseCharacter(String id) {
    try {
      return franchiseCharacters.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  factory StoryResponse.fromJson(Map<String, dynamic> json) {
    return StoryResponse(
      title: json['title'] as String? ?? 'Story',
      scenes: (json['scenes'] as List<dynamic>?)
              ?.map((e) => StoryScene.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      quiz: (json['quiz'] as List<dynamic>?)
              ?.map(
                  (e) => StoryQuizQuestion.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      franchiseCharacters: (json['characters'] as List<dynamic>?)
              ?.map((e) =>
                  FranchiseCharacter.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

/// Progressive story-chunk shape. The orchestrator yields one [intro] chunk
/// (title + cast + first scenes) so the UI can paint immediately, then a
/// [tail] chunk (remaining scenes + quiz). Total wall-time is ~the same as
/// one big call but time-to-first-paint drops from "minutes" to "seconds".
enum StoryChunkKind { intro, tail }

class StoryChunk {
  const StoryChunk._({
    required this.kind,
    this.title,
    this.characters = const [],
    this.scenes = const [],
    this.quiz = const [],
  });

  factory StoryChunk.intro({
    required String title,
    required List<FranchiseCharacter> characters,
    required List<StoryScene> scenes,
  }) =>
      StoryChunk._(
        kind: StoryChunkKind.intro,
        title: title,
        characters: characters,
        scenes: scenes,
      );

  factory StoryChunk.tail({
    required List<StoryScene> scenes,
    required List<StoryQuizQuestion> quiz,
  }) =>
      StoryChunk._(
        kind: StoryChunkKind.tail,
        scenes: scenes,
        quiz: quiz,
      );

  final StoryChunkKind kind;
  final String? title;
  final List<FranchiseCharacter> characters;
  final List<StoryScene> scenes;
  final List<StoryQuizQuestion> quiz;
}
