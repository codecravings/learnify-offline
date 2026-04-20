enum ChallengeType { logic, coding, reasoning, cybersecurity, math }

class ChallengeModel {
  final String id;
  final String title;
  final String description;
  final int difficulty;
  final ChallengeType type;
  final String solution;
  final List<String> hints;
  final List<String> tags;
  final String creatorId;
  final String creatorUsername;
  final int solveCount;
  final int attemptCount;
  final int avgSolveTime;
  final int xpReward;
  final DateTime createdAt;
  final List<Map<String, dynamic>> testCases;

  const ChallengeModel({
    required this.id,
    required this.title,
    required this.description,
    required this.difficulty,
    required this.type,
    required this.solution,
    this.hints = const [],
    this.tags = const [],
    required this.creatorId,
    required this.creatorUsername,
    this.solveCount = 0,
    this.attemptCount = 0,
    this.avgSolveTime = 0,
    this.xpReward = 10,
    required this.createdAt,
    this.testCases = const [],
  }) : assert(difficulty >= 1 && difficulty <= 5, 'Difficulty must be 1-5');

  factory ChallengeModel.fromJson(Map<String, dynamic> json) {
    return ChallengeModel(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      difficulty: json['difficulty'] as int,
      type: ChallengeType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => ChallengeType.logic,
      ),
      solution: json['solution'] as String,
      hints: List<String>.from(json['hints'] ?? []),
      tags: List<String>.from(json['tags'] ?? []),
      creatorId: json['creatorId'] as String,
      creatorUsername: json['creatorUsername'] as String,
      solveCount: json['solveCount'] as int? ?? 0,
      attemptCount: json['attemptCount'] as int? ?? 0,
      avgSolveTime: json['avgSolveTime'] as int? ?? 0,
      xpReward: json['xpReward'] as int? ?? 10,
      createdAt: DateTime.parse(json['createdAt'] as String),
      testCases: (json['testCases'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'difficulty': difficulty,
      'type': type.name,
      'solution': solution,
      'hints': hints,
      'tags': tags,
      'creatorId': creatorId,
      'creatorUsername': creatorUsername,
      'solveCount': solveCount,
      'attemptCount': attemptCount,
      'avgSolveTime': avgSolveTime,
      'xpReward': xpReward,
      'createdAt': createdAt.toIso8601String(),
      'testCases': testCases,
    };
  }

  ChallengeModel copyWith({
    String? id,
    String? title,
    String? description,
    int? difficulty,
    ChallengeType? type,
    String? solution,
    List<String>? hints,
    List<String>? tags,
    String? creatorId,
    String? creatorUsername,
    int? solveCount,
    int? attemptCount,
    int? avgSolveTime,
    int? xpReward,
    DateTime? createdAt,
    List<Map<String, dynamic>>? testCases,
  }) {
    return ChallengeModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      difficulty: difficulty ?? this.difficulty,
      type: type ?? this.type,
      solution: solution ?? this.solution,
      hints: hints ?? this.hints,
      tags: tags ?? this.tags,
      creatorId: creatorId ?? this.creatorId,
      creatorUsername: creatorUsername ?? this.creatorUsername,
      solveCount: solveCount ?? this.solveCount,
      attemptCount: attemptCount ?? this.attemptCount,
      avgSolveTime: avgSolveTime ?? this.avgSolveTime,
      xpReward: xpReward ?? this.xpReward,
      createdAt: createdAt ?? this.createdAt,
      testCases: testCases ?? this.testCases,
    );
  }

  @override
  String toString() => 'ChallengeModel(id: $id, title: $title, difficulty: $difficulty, type: ${type.name})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ChallengeModel && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
