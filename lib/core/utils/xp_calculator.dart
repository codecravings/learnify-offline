import 'dart:math' as math;

import 'package:vidyasetu/core/constants/app_constants.dart';

/// Stateless utility for everything XP-related: awarding points, mapping
/// totals to leagues, computing progress bars, and applying multipliers.
class XPCalculator {
  XPCalculator._();

  // ─── XP Award Calculation ────────────────────────────────────────────

  /// Base XP for a known [action].
  static int baseXP(XPAction action) {
    return switch (action) {
      XPAction.solveChallenge => AppConstants.xpSolveChallenge,
      XPAction.winBattle => AppConstants.xpWinBattle,
      XPAction.createPuzzle => AppConstants.xpCreatePuzzle,
      XPAction.helpForum => AppConstants.xpHelpForum,
      XPAction.dailyLogin => AppConstants.xpDailyLogin,
      XPAction.completeLesson => AppConstants.xpCompleteLesson,
      XPAction.perfectScore => AppConstants.xpPerfectScore,
    };
  }

  /// Returns the difficulty multiplier for a [Difficulty] tier.
  static double difficultyMultiplier(Difficulty difficulty) {
    return switch (difficulty) {
      Difficulty.easy => AppConstants.difficultyMultiplierEasy,
      Difficulty.medium => AppConstants.difficultyMultiplierMedium,
      Difficulty.hard => AppConstants.difficultyMultiplierHard,
      Difficulty.expert => AppConstants.difficultyMultiplierExpert,
    };
  }

  /// Calculates the total XP earned for an [action] at the given
  /// [difficulty], after applying the optional [streakDays] bonus and any
  /// [hintsUsed] penalties.
  ///
  /// Formula:
  /// ```
  /// base * difficultyMul * streakMul - hintPenalty
  /// ```
  /// The result is clamped so it never drops below 1.
  static int calculate({
    required XPAction action,
    Difficulty difficulty = Difficulty.medium,
    int streakDays = 0,
    int hintsUsed = 0,
  }) {
    final base = baseXP(action).toDouble();
    final diffMul = difficultyMultiplier(difficulty);
    final streakMul = streakMultiplier(streakDays);

    double earned = base * diffMul * streakMul;

    // Apply hint penalties (each hint reduces the earned XP cumulatively).
    if (hintsUsed > 0) {
      final capped = math.min(hintsUsed, AppConstants.maxHintsPerQuestion);
      final penalty = AppConstants.hintPenalties[capped - 1];
      earned *= (1.0 - penalty);
    }

    return math.max(1, earned.round());
  }

  /// Streak multiplier: 1.0 base + 2 % per consecutive day, capped at 2.0x.
  static double streakMultiplier(int streakDays) {
    if (streakDays <= 0) return 1.0;
    return math.min(1.0 + (streakDays * 0.02), 2.0);
  }

  // ─── League Determination ────────────────────────────────────────────

  /// Returns the [League] that [totalXP] falls into.
  static League currentLeague(int totalXP) {
    final leagues = AppConstants.leagues;
    // Walk backward to find the highest qualifying league.
    for (int i = leagues.length - 1; i >= 0; i--) {
      if (totalXP >= leagues[i].minXP) return leagues[i];
    }
    return leagues.first;
  }

  /// Returns the next [League] after the player's current one,
  /// or `null` if the player is already in the highest league.
  static League? nextLeague(int totalXP) {
    final leagues = AppConstants.leagues;
    for (int i = 0; i < leagues.length - 1; i++) {
      if (totalXP < leagues[i + 1].minXP) return leagues[i + 1];
    }
    return null; // already at the top
  }

  /// Returns the 0-based index of the current league (useful for badges).
  static int leagueIndex(int totalXP) {
    final leagues = AppConstants.leagues;
    for (int i = leagues.length - 1; i >= 0; i--) {
      if (totalXP >= leagues[i].minXP) return i;
    }
    return 0;
  }

  // ─── Progress Calculation ────────────────────────────────────────────

  /// Fractional progress (0.0 .. 1.0) toward the next league.
  /// Returns 1.0 if already in the highest league.
  static double progressToNextLeague(int totalXP) {
    final current = currentLeague(totalXP);
    final next = nextLeague(totalXP);
    if (next == null) return 1.0;

    final rangeSize = next.minXP - current.minXP;
    if (rangeSize <= 0) return 1.0;

    final progress = (totalXP - current.minXP) / rangeSize;
    return progress.clamp(0.0, 1.0);
  }

  /// Absolute XP still needed to reach the next league.
  /// Returns 0 when already at max league.
  static int xpToNextLeague(int totalXP) {
    final next = nextLeague(totalXP);
    if (next == null) return 0;
    return math.max(0, next.minXP - totalXP);
  }

  // ─── Battle Score Helpers ────────────────────────────────────────────

  /// Given a time-based battle, computes a bonus XP for finishing early.
  ///
  /// [elapsedSeconds] is how long the player took; [totalSeconds] is the
  /// battle duration. Returns a bonus between 0 and [maxBonus].
  static int timeBonusXP({
    required int elapsedSeconds,
    required int totalSeconds,
    int maxBonus = 50,
  }) {
    if (elapsedSeconds >= totalSeconds || totalSeconds <= 0) return 0;
    final fraction = 1.0 - (elapsedSeconds / totalSeconds);
    return (fraction * maxBonus).round();
  }

  /// Computes accuracy-based XP bonus.
  /// [correct] out of [total] questions.
  static int accuracyBonusXP({
    required int correct,
    required int total,
    int maxBonus = 50,
  }) {
    if (total <= 0) return 0;
    final accuracy = correct / total;
    if (accuracy >= 1.0) return maxBonus;
    if (accuracy >= 0.8) return (maxBonus * 0.6).round();
    if (accuracy >= 0.6) return (maxBonus * 0.3).round();
    return 0;
  }

  /// Total XP for a completed battle combining base win XP, time bonus, and
  /// accuracy bonus.
  static int battleTotalXP({
    required bool won,
    required Difficulty difficulty,
    required int elapsedSeconds,
    required int totalSeconds,
    required int correctAnswers,
    required int totalQuestions,
    int streakDays = 0,
  }) {
    if (!won) {
      // Losers still get a participation reward (25 % of base).
      return math.max(
        1,
        (baseXP(XPAction.winBattle) *
                difficultyMultiplier(difficulty) *
                0.25)
            .round(),
      );
    }

    final base = calculate(
      action: XPAction.winBattle,
      difficulty: difficulty,
      streakDays: streakDays,
    );

    final timeBonus = timeBonusXP(
      elapsedSeconds: elapsedSeconds,
      totalSeconds: totalSeconds,
    );

    final accuracyBonus = accuracyBonusXP(
      correct: correctAnswers,
      total: totalQuestions,
    );

    return base + timeBonus + accuracyBonus;
  }
}

// ─── Enums ───────────────────────────────────────────────────────────────

/// Actions that can earn XP.
enum XPAction {
  solveChallenge,
  winBattle,
  createPuzzle,
  helpForum,
  dailyLogin,
  completeLesson,
  perfectScore,
}

/// Challenge / battle difficulty tiers.
enum Difficulty {
  easy,
  medium,
  hard,
  expert;

  /// Human-readable label.
  String get label => switch (this) {
        easy => 'Easy',
        medium => 'Medium',
        hard => 'Hard',
        expert => 'Expert',
      };
}
