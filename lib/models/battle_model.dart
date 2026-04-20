enum BattleMode { speedSolve, mindTrap, scenarioBattle }

enum BattleStatus { waiting, inProgress, completed, cancelled }

class BattleModel {
  final String id;
  final BattleMode mode;
  final String player1Id;
  final String player2Id;
  final String player1Username;
  final String player2Username;
  final String challengeId;
  final BattleStatus status;
  final int player1Score;
  final int player2Score;
  final String? winnerId;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final int timeLimit;
  final int spectatorCount;
  final String? player1Answer;
  final String? player2Answer;

  const BattleModel({
    required this.id,
    required this.mode,
    required this.player1Id,
    this.player2Id = '',
    required this.player1Username,
    this.player2Username = '',
    required this.challengeId,
    this.status = BattleStatus.waiting,
    this.player1Score = 0,
    this.player2Score = 0,
    this.winnerId,
    this.startedAt,
    this.endedAt,
    this.timeLimit = 300,
    this.spectatorCount = 0,
    this.player1Answer,
    this.player2Answer,
  });

  factory BattleModel.fromJson(Map<String, dynamic> json) {
    return BattleModel(
      id: json['id'] as String,
      mode: BattleMode.values.firstWhere(
        (e) => e.name == json['mode'],
        orElse: () => BattleMode.speedSolve,
      ),
      player1Id: json['player1Id'] as String,
      player2Id: json['player2Id'] as String? ?? '',
      player1Username: json['player1Username'] as String,
      player2Username: json['player2Username'] as String? ?? '',
      challengeId: json['challengeId'] as String,
      status: BattleStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => BattleStatus.waiting,
      ),
      player1Score: json['player1Score'] as int? ?? 0,
      player2Score: json['player2Score'] as int? ?? 0,
      winnerId: json['winnerId'] as String?,
      startedAt: json['startedAt'] != null
          ? DateTime.parse(json['startedAt'] as String)
          : null,
      endedAt: json['endedAt'] != null
          ? DateTime.parse(json['endedAt'] as String)
          : null,
      timeLimit: json['timeLimit'] as int? ?? 300,
      spectatorCount: json['spectatorCount'] as int? ?? 0,
      player1Answer: json['player1Answer'] as String?,
      player2Answer: json['player2Answer'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'mode': mode.name,
      'player1Id': player1Id,
      'player2Id': player2Id,
      'player1Username': player1Username,
      'player2Username': player2Username,
      'challengeId': challengeId,
      'status': status.name,
      'player1Score': player1Score,
      'player2Score': player2Score,
      'winnerId': winnerId,
      'startedAt': startedAt?.toIso8601String(),
      'endedAt': endedAt?.toIso8601String(),
      'timeLimit': timeLimit,
      'spectatorCount': spectatorCount,
      'player1Answer': player1Answer,
      'player2Answer': player2Answer,
    };
  }

  BattleModel copyWith({
    String? id,
    BattleMode? mode,
    String? player1Id,
    String? player2Id,
    String? player1Username,
    String? player2Username,
    String? challengeId,
    BattleStatus? status,
    int? player1Score,
    int? player2Score,
    String? winnerId,
    DateTime? startedAt,
    DateTime? endedAt,
    int? timeLimit,
    int? spectatorCount,
    String? player1Answer,
    String? player2Answer,
  }) {
    return BattleModel(
      id: id ?? this.id,
      mode: mode ?? this.mode,
      player1Id: player1Id ?? this.player1Id,
      player2Id: player2Id ?? this.player2Id,
      player1Username: player1Username ?? this.player1Username,
      player2Username: player2Username ?? this.player2Username,
      challengeId: challengeId ?? this.challengeId,
      status: status ?? this.status,
      player1Score: player1Score ?? this.player1Score,
      player2Score: player2Score ?? this.player2Score,
      winnerId: winnerId ?? this.winnerId,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      timeLimit: timeLimit ?? this.timeLimit,
      spectatorCount: spectatorCount ?? this.spectatorCount,
      player1Answer: player1Answer ?? this.player1Answer,
      player2Answer: player2Answer ?? this.player2Answer,
    );
  }

  bool get isActive => status == BattleStatus.inProgress;
  bool get isWaiting => status == BattleStatus.waiting;
  bool get isCompleted => status == BattleStatus.completed;

  @override
  String toString() => 'BattleModel(id: $id, mode: ${mode.name}, status: ${status.name})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is BattleModel && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
