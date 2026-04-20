import 'package:flutter/material.dart';

import '../models/story_character.dart';

/// The 8 story characters available in the visual novel system.
const List<StoryCharacter> storyCharacters = [
  StoryCharacter(
    id: 'nova',
    name: 'Nova',
    role: 'Curious Explorer',
    personality:
        'Endlessly curious, asks "why?" and "what if?", loves discovering new things',
    accentColor: Color(0xFF3B82F6),
    emotion: 'wonder',
    imagePath: 'assets/images/characters/nova.png',
  ),
  StoryCharacter(
    id: 'blaze',
    name: 'Blaze',
    role: 'Hype Coach',
    personality:
        'Energetic motivator, uses exclamation marks, pumps everyone up',
    accentColor: Color(0xFFF97316),
    emotion: 'excitement',
    imagePath: 'assets/images/characters/blaze.png',
  ),
  StoryCharacter(
    id: 'luna',
    name: 'Luna',
    role: 'Wise Storyteller',
    personality:
        'Calm and wise, tells parables and analogies, speaks poetically',
    accentColor: Color(0xFF8B5CF6),
    emotion: 'calm',
    imagePath: 'assets/images/characters/luna.png',
  ),
  StoryCharacter(
    id: 'pixel',
    name: 'Pixel',
    role: 'Class Clown',
    personality:
        'Funny prankster, makes puns and jokes, uses humor to teach',
    accentColor: Color(0xFF22C55E),
    emotion: 'humor',
    imagePath: 'assets/images/characters/pixel.png',
  ),
  StoryCharacter(
    id: 'sage',
    name: 'Sage',
    role: 'Patient Mentor',
    personality:
        'Kind and patient, breaks things down step by step, never judges',
    accentColor: Color(0xFFF59E0B),
    emotion: 'kindness',
    imagePath: 'assets/images/characters/sage.png',
  ),
  StoryCharacter(
    id: 'spark',
    name: 'Spark',
    role: 'Mad Scientist',
    personality:
        'Wild inventor, loves experiments and "what could go wrong?" energy',
    accentColor: Color(0xFFEF4444),
    emotion: 'creativity',
    imagePath: 'assets/images/characters/spark.png',
  ),
  StoryCharacter(
    id: 'echo',
    name: 'Echo',
    role: 'Philosopher',
    personality:
        'Deep thinker, asks thought-provoking questions, connects ideas to life',
    accentColor: Color(0xFF4488FF),
    emotion: 'thoughtful',
    imagePath: 'assets/images/characters/echo.png',
  ),
  StoryCharacter(
    id: 'bolt',
    name: 'Bolt',
    role: 'The Rival',
    personality:
        'Competitive and challenging, pushes others to be better, friendly rival',
    accentColor: Color(0xFFFF4444),
    emotion: 'competitive',
    imagePath: 'assets/images/characters/bolt.png',
  ),
];

/// Lookup a character by ID. Returns null if not found.
StoryCharacter? getCharacterById(String id) {
  try {
    return storyCharacters.firstWhere((c) => c.id == id);
  } catch (_) {
    return null;
  }
}
