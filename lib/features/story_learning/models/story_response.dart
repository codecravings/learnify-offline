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
