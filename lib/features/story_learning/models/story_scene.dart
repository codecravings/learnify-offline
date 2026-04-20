/// A single scene in the visual novel story.
class StoryScene {
  const StoryScene({
    required this.characterId,
    required this.emotion,
    required this.dialogue,
    this.narration,
    this.conceptTag,
  });

  /// ID of the speaking character.
  final String characterId;

  /// Current emotion for this line (e.g. "excited", "thinking", "laughing").
  final String emotion;

  /// The dialogue text shown in the speech bubble.
  final String dialogue;

  /// Optional narrator text shown above the dialogue.
  final String? narration;

  /// Optional concept tag linking this scene to a lesson concept.
  final String? conceptTag;

  factory StoryScene.fromJson(Map<String, dynamic> json) {
    return StoryScene(
      characterId: json['characterId'] as String? ?? '',
      emotion: json['emotion'] as String? ?? 'neutral',
      dialogue: json['dialogue'] as String? ?? '',
      narration: json['narration'] as String?,
      conceptTag: json['conceptTag'] as String?,
    );
  }
}
