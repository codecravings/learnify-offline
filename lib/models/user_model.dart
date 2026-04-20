class UserModel {
  final String uid;
  final String email;
  final String username;
  final String photoUrl;
  final int xp;
  final String league;
  final Map<String, int> skillRatings;
  final List<String> achievements;
  final List<String> battleHistory;
  final List<String> createdChallenges;
  final List<String> solvedChallenges;
  final List<String> interests;
  final bool onboardingComplete;
  final Map<String, double> courseProgress;
  final DateTime createdAt;
  final DateTime lastActive;
  final int currentStreak;
  final int longestStreak;
  final int totalBattlesWon;
  final int totalBattlesLost;
  final List<String> followers;
  final List<String> following;
  final int followerCount;
  final int followingCount;

  const UserModel({
    required this.uid,
    required this.email,
    required this.username,
    this.photoUrl = '',
    this.xp = 0,
    this.league = 'Bronze',
    this.skillRatings = const {},
    this.achievements = const [],
    this.battleHistory = const [],
    this.createdChallenges = const [],
    this.solvedChallenges = const [],
    this.interests = const [],
    this.onboardingComplete = false,
    this.courseProgress = const {},
    required this.createdAt,
    required this.lastActive,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.totalBattlesWon = 0,
    this.totalBattlesLost = 0,
    this.followers = const [],
    this.following = const [],
    this.followerCount = 0,
    this.followingCount = 0,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid'] as String,
      email: json['email'] as String,
      username: json['username'] as String,
      photoUrl: json['photoUrl'] as String? ?? '',
      xp: json['xp'] as int? ?? 0,
      league: json['league'] as String? ?? 'Bronze',
      skillRatings: (json['skillRatings'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, v as int)) ??
          {},
      achievements: List<String>.from(json['achievements'] ?? []),
      battleHistory: List<String>.from(json['battleHistory'] ?? []),
      createdChallenges: List<String>.from(json['createdChallenges'] ?? []),
      solvedChallenges: List<String>.from(json['solvedChallenges'] ?? []),
      interests: List<String>.from(json['interests'] ?? []),
      onboardingComplete: json['onboardingComplete'] as bool? ?? false,
      courseProgress: (json['courseProgress'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, (v as num).toDouble())) ??
          {},
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastActive: DateTime.parse(json['lastActive'] as String),
      currentStreak: json['currentStreak'] as int? ?? 0,
      longestStreak: json['longestStreak'] as int? ?? 0,
      totalBattlesWon: json['totalBattlesWon'] as int? ?? 0,
      totalBattlesLost: json['totalBattlesLost'] as int? ?? 0,
      followers: List<String>.from(json['followers'] ?? []),
      following: List<String>.from(json['following'] ?? []),
      followerCount: json['followerCount'] as int? ?? 0,
      followingCount: json['followingCount'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'username': username,
      'photoUrl': photoUrl,
      'xp': xp,
      'league': league,
      'skillRatings': skillRatings,
      'achievements': achievements,
      'battleHistory': battleHistory,
      'createdChallenges': createdChallenges,
      'solvedChallenges': solvedChallenges,
      'interests': interests,
      'onboardingComplete': onboardingComplete,
      'courseProgress': courseProgress,
      'createdAt': createdAt.toIso8601String(),
      'lastActive': lastActive.toIso8601String(),
      'currentStreak': currentStreak,
      'longestStreak': longestStreak,
      'totalBattlesWon': totalBattlesWon,
      'totalBattlesLost': totalBattlesLost,
      'followers': followers,
      'following': following,
      'followerCount': followerCount,
      'followingCount': followingCount,
    };
  }

  UserModel copyWith({
    String? uid,
    String? email,
    String? username,
    String? photoUrl,
    int? xp,
    String? league,
    Map<String, int>? skillRatings,
    List<String>? achievements,
    List<String>? battleHistory,
    List<String>? createdChallenges,
    List<String>? solvedChallenges,
    List<String>? interests,
    bool? onboardingComplete,
    Map<String, double>? courseProgress,
    DateTime? createdAt,
    DateTime? lastActive,
    int? currentStreak,
    int? longestStreak,
    int? totalBattlesWon,
    int? totalBattlesLost,
    List<String>? followers,
    List<String>? following,
    int? followerCount,
    int? followingCount,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      username: username ?? this.username,
      photoUrl: photoUrl ?? this.photoUrl,
      xp: xp ?? this.xp,
      league: league ?? this.league,
      skillRatings: skillRatings ?? this.skillRatings,
      achievements: achievements ?? this.achievements,
      battleHistory: battleHistory ?? this.battleHistory,
      createdChallenges: createdChallenges ?? this.createdChallenges,
      solvedChallenges: solvedChallenges ?? this.solvedChallenges,
      interests: interests ?? this.interests,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      courseProgress: courseProgress ?? this.courseProgress,
      createdAt: createdAt ?? this.createdAt,
      lastActive: lastActive ?? this.lastActive,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      totalBattlesWon: totalBattlesWon ?? this.totalBattlesWon,
      totalBattlesLost: totalBattlesLost ?? this.totalBattlesLost,
      followers: followers ?? this.followers,
      following: following ?? this.following,
      followerCount: followerCount ?? this.followerCount,
      followingCount: followingCount ?? this.followingCount,
    );
  }

  @override
  String toString() => 'UserModel(uid: $uid, username: $username, xp: $xp, league: $league)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is UserModel && uid == other.uid;

  @override
  int get hashCode => uid.hashCode;
}
