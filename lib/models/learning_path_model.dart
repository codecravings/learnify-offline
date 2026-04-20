class PathStage {
  final String id;
  final String name;
  final String description;
  final List<String> challengeIds;
  final int xpReward;
  final bool isCompleted;
  final int order;

  const PathStage({
    required this.id,
    required this.name,
    required this.description,
    this.challengeIds = const [],
    this.xpReward = 100,
    this.isCompleted = false,
    required this.order,
  });

  factory PathStage.fromJson(Map<String, dynamic> json) {
    return PathStage(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      challengeIds: List<String>.from(json['challengeIds'] ?? []),
      xpReward: json['xpReward'] as int? ?? 100,
      isCompleted: json['isCompleted'] as bool? ?? false,
      order: json['order'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'challengeIds': challengeIds,
      'xpReward': xpReward,
      'isCompleted': isCompleted,
      'order': order,
    };
  }

  PathStage copyWith({
    String? id,
    String? name,
    String? description,
    List<String>? challengeIds,
    int? xpReward,
    bool? isCompleted,
    int? order,
  }) {
    return PathStage(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      challengeIds: challengeIds ?? this.challengeIds,
      xpReward: xpReward ?? this.xpReward,
      isCompleted: isCompleted ?? this.isCompleted,
      order: order ?? this.order,
    );
  }

  @override
  String toString() => 'PathStage(id: $id, name: $name, order: $order, isCompleted: $isCompleted)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is PathStage && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class LearningPathModel {
  final String id;
  final String name;
  final String description;
  final String iconName;
  final List<PathStage> stages;
  final String requiredLeague;

  const LearningPathModel({
    required this.id,
    required this.name,
    required this.description,
    required this.iconName,
    this.stages = const [],
    this.requiredLeague = 'Bronze',
  });

  factory LearningPathModel.fromJson(Map<String, dynamic> json) {
    return LearningPathModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      iconName: json['iconName'] as String,
      stages: (json['stages'] as List<dynamic>?)
              ?.map((e) => PathStage.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      requiredLeague: json['requiredLeague'] as String? ?? 'Bronze',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'iconName': iconName,
      'stages': stages.map((s) => s.toJson()).toList(),
      'requiredLeague': requiredLeague,
    };
  }

  LearningPathModel copyWith({
    String? id,
    String? name,
    String? description,
    String? iconName,
    List<PathStage>? stages,
    String? requiredLeague,
  }) {
    return LearningPathModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      iconName: iconName ?? this.iconName,
      stages: stages ?? this.stages,
      requiredLeague: requiredLeague ?? this.requiredLeague,
    );
  }

  int get totalXp => stages.fold(0, (sum, stage) => sum + stage.xpReward);
  int get completedStages => stages.where((s) => s.isCompleted).length;
  double get progress => stages.isEmpty ? 0.0 : completedStages / stages.length;
  bool get isCompleted => stages.isNotEmpty && completedStages == stages.length;

  @override
  String toString() => 'LearningPathModel(id: $id, name: $name, progress: ${(progress * 100).toStringAsFixed(0)}%)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is LearningPathModel && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
