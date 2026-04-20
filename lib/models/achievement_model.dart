enum AchievementRarity { common, rare, epic, legendary }

class AchievementModel {
  final String id;
  final String name;
  final String description;
  final String iconName;
  final Map<String, dynamic> requirement;
  final int xpReward;
  final AchievementRarity rarity;
  final DateTime? unlockedAt;

  const AchievementModel({
    required this.id,
    required this.name,
    required this.description,
    required this.iconName,
    required this.requirement,
    this.xpReward = 50,
    this.rarity = AchievementRarity.common,
    this.unlockedAt,
  });

  factory AchievementModel.fromJson(Map<String, dynamic> json) {
    return AchievementModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      iconName: json['iconName'] as String,
      requirement: Map<String, dynamic>.from(json['requirement'] as Map),
      xpReward: json['xpReward'] as int? ?? 50,
      rarity: AchievementRarity.values.firstWhere(
        (e) => e.name == json['rarity'],
        orElse: () => AchievementRarity.common,
      ),
      unlockedAt: json['unlockedAt'] != null
          ? DateTime.parse(json['unlockedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'iconName': iconName,
      'requirement': requirement,
      'xpReward': xpReward,
      'rarity': rarity.name,
      'unlockedAt': unlockedAt?.toIso8601String(),
    };
  }

  AchievementModel copyWith({
    String? id,
    String? name,
    String? description,
    String? iconName,
    Map<String, dynamic>? requirement,
    int? xpReward,
    AchievementRarity? rarity,
    DateTime? unlockedAt,
  }) {
    return AchievementModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      iconName: iconName ?? this.iconName,
      requirement: requirement ?? this.requirement,
      xpReward: xpReward ?? this.xpReward,
      rarity: rarity ?? this.rarity,
      unlockedAt: unlockedAt ?? this.unlockedAt,
    );
  }

  bool get isUnlocked => unlockedAt != null;

  @override
  String toString() => 'AchievementModel(id: $id, name: $name, rarity: ${rarity.name})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is AchievementModel && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
