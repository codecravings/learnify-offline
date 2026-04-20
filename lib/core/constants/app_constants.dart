/// Central repository of magic numbers, thresholds, and identifiers
/// used throughout the Learnify competitive learning platform.
class AppConstants {
  AppConstants._();

  // ─── App Meta ────────────────────────────────────────────────────────
  static const String appName = 'Learnify';
  static const String appTagline = 'Learn. Play. Grow.';
  static const int currentAppVersion = 1;

  // ─── League System ───────────────────────────────────────────────────
  /// Ordered list of leagues from lowest to highest.
  static const List<League> leagues = [
    League(name: 'Apprentice', minXP: 0, icon: 'apprentice'),
    League(name: 'Spellcaster', minXP: 500, icon: 'spellcaster'),
    League(name: 'Mage', minXP: 1500, icon: 'mage'),
    League(name: 'Archmage', minXP: 3500, icon: 'archmage'),
    League(name: 'Grand Sorcerer', minXP: 7000, icon: 'grand_sorcerer'),
    League(name: 'Supreme Wizard', minXP: 15000, icon: 'supreme_wizard'),
  ];

  // ─── XP Rewards ──────────────────────────────────────────────────────
  static const int xpSolveChallenge = 50;
  static const int xpWinBattle = 100;
  static const int xpCreatePuzzle = 30;
  static const int xpHelpForum = 20;
  static const int xpDailyLogin = 10;
  static const int xpCompleteLesson = 25;
  static const int xpPerfectScore = 150;
  static const int xpCompleteStory = 35;
  static const int xpStreakBonusPerDay = 5;
  static const int xpAskQuestion = 10;
  static const int xpAcceptedAnswer = 25;
  static const int xpAnswerUpvote = 5;

  // ─── Difficulty Multipliers ──────────────────────────────────────────
  static const double difficultyMultiplierEasy = 1.0;
  static const double difficultyMultiplierMedium = 1.5;
  static const double difficultyMultiplierHard = 2.0;
  static const double difficultyMultiplierExpert = 3.0;

  // ─── Battle Settings ─────────────────────────────────────────────────
  /// Durations in seconds.
  static const int battleDurationQuick = 120; // 2 min
  static const int battleDurationStandard = 300; // 5 min
  static const int battleDurationMarathon = 600; // 10 min
  static const int battleMatchmakingTimeout = 30; // seconds
  static const int battleRoundCount = 5;
  static const int battleCountdownSeconds = 3;

  // ─── Hint Penalties ──────────────────────────────────────────────────
  /// Each successive hint costs a larger fraction of the question's XP.
  static const double hintPenalty1 = 0.25; // 25 %
  static const double hintPenalty2 = 0.50; // 50 %
  static const double hintPenalty3 = 0.75; // 75 %
  static const List<double> hintPenalties = [
    hintPenalty1,
    hintPenalty2,
    hintPenalty3,
  ];
  static const int maxHintsPerQuestion = 3;

  // ─── Achievement IDs ─────────────────────────────────────────────────
  static const String achievementFirstBlood = 'first_blood';
  static const String achievementWinStreak5 = 'win_streak_5';
  static const String achievementWinStreak10 = 'win_streak_10';
  static const String achievementPerfectBattle = 'perfect_battle';
  static const String achievementSpeedDemon = 'speed_demon';
  static const String achievementPuzzleMaster = 'puzzle_master';
  static const String achievementHelperHand = 'helper_hand';
  static const String achievementBookworm = 'bookworm';
  static const String achievementRisingstar = 'risingstar';
  static const String achievementLeaguePromotion = 'league_promotion';
  static const String achievementDailyStreak7 = 'daily_streak_7';
  static const String achievementDailyStreak30 = 'daily_streak_30';
  static const String achievementCenturion = 'centurion_100_wins';
  static const String achievementMentor = 'mentor_50_helps';
  static const String achievementCreator = 'creator_20_puzzles';

  // ─── Learning Paths ──────────────────────────────────────────────────
  static const String pathMathematics = 'Mathematics';
  static const String pathPhysics = 'Physics';
  static const String pathChemistry = 'Chemistry';
  static const String pathBiology = 'Biology';
  static const String pathComputerScience = 'Computer Science';
  static const String pathEnglish = 'English';
  static const String pathHistory = 'History';
  static const String pathGeography = 'Geography';

  static const List<String> learningPaths = [
    pathMathematics,
    pathPhysics,
    pathChemistry,
    pathBiology,
    pathComputerScience,
    pathEnglish,
    pathHistory,
    pathGeography,
  ];

  // ─── Firestore Collections ───────────────────────────────────────────
  static const String collectionUsers = 'users';
  static const String collectionBattles = 'battles';
  static const String collectionChallenges = 'challenges';
  static const String collectionLeaderboard = 'leaderboard';
  static const String collectionForumPosts = 'forum_posts';
  static const String collectionAchievements = 'achievements';
  static const String collectionNotifications = 'notifications';

  // ─── Pagination ──────────────────────────────────────────────────────
  static const int defaultPageSize = 20;
  static const int leaderboardPageSize = 50;

  // ─── Miscellaneous ───────────────────────────────────────────────────
  static const int maxUsernameLength = 20;
  static const int minPasswordLength = 8;
  static const int maxBioLength = 200;
  static const Duration splashDuration = Duration(seconds: 2);
  static const Duration snackBarDuration = Duration(seconds: 3);
  static const Duration animationFast = Duration(milliseconds: 200);
  static const Duration animationMedium = Duration(milliseconds: 400);
  static const Duration animationSlow = Duration(milliseconds: 800);
}

/// Immutable model representing one competitive league tier.
class League {
  const League({
    required this.name,
    required this.minXP,
    required this.icon,
  });

  /// Display name (e.g. "Grand Sorcerer").
  final String name;

  /// Minimum cumulative XP required to enter this league.
  final int minXP;

  /// Icon asset key (resolved via [AssetPaths]).
  final String icon;

  @override
  String toString() => 'League($name, minXP: $minXP)';
}
