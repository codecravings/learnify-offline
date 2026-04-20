import 'package:flutter/material.dart';

/// A character in the story-based learning system.
class StoryCharacter {
  const StoryCharacter({
    required this.id,
    required this.name,
    required this.role,
    required this.personality,
    required this.accentColor,
    required this.emotion,
    required this.imagePath,
  });

  final String id;
  final String name;
  final String role;
  final String personality;
  final Color accentColor;
  final String emotion;
  final String imagePath;

  /// One-line description for AI prompt context.
  String get promptDescription =>
      '$name the $role — personality: $personality, default emotion: $emotion';
}
