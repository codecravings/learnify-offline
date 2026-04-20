import 'dart:ui';

enum SkillNodeStatus { locked, available, inProgress, mastered }

/// Represents one node in the skill tree.
class SkillNodeState {
  final String id;
  final String name;
  final String subject; // e.g. 'Physics', 'Math', 'Custom'
  final SkillNodeStatus status;
  final double accuracy; // 0.0–1.0
  final int stars; // 0–3
  final String level; // 'basics', 'intermediate', 'advanced'
  final DateTime? lastStudied;
  final Offset position; // computed layout position
  final List<String> prerequisiteIds; // IDs of prerequisite nodes

  const SkillNodeState({
    required this.id,
    required this.name,
    required this.subject,
    this.status = SkillNodeStatus.locked,
    this.accuracy = 0.0,
    this.stars = 0,
    this.level = 'basics',
    this.lastStudied,
    this.position = Offset.zero,
    this.prerequisiteIds = const [],
  });

  bool get isMastered => status == SkillNodeStatus.mastered;
  bool get isInProgress => status == SkillNodeStatus.inProgress;
  bool get isAvailable => status == SkillNodeStatus.available;
  bool get isLocked => status == SkillNodeStatus.locked;
}
