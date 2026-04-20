/// Centralised asset path constants.
///
/// All raw asset references flow through this class so that path changes
/// only need updating in one place.
class AssetPaths {
  AssetPaths._();

  // ─── Base Directories ────────────────────────────────────────────────
  static const String _images = 'assets/images';
  static const String _icons = 'assets/icons';
  static const String _lottie = 'assets/lottie';
  static const String _svg = 'assets/svg';
  static const String _sounds = 'assets/sounds';

  // ─── Brand / Logo ────────────────────────────────────────────────────
  static const String logo = '$_images/logo.png';
  static const String logoText = '$_images/logo_text.png';
  static const String splashBg = '$_images/splash_bg.png';

  // ─── Onboarding ──────────────────────────────────────────────────────
  static const String onboarding1 = '$_images/onboarding_1.png';
  static const String onboarding2 = '$_images/onboarding_2.png';
  static const String onboarding3 = '$_images/onboarding_3.png';

  // ─── Avatars ─────────────────────────────────────────────────────────
  static const String defaultAvatar = '$_images/default_avatar.png';
  static const String avatarPlaceholder = '$_images/avatar_placeholder.png';

  // ─── League Badges ───────────────────────────────────────────────────
  static const String badgeApprentice = '$_images/badges/apprentice.png';
  static const String badgeSpellcaster = '$_images/badges/spellcaster.png';
  static const String badgeMage = '$_images/badges/mage.png';
  static const String badgeArchmage = '$_images/badges/archmage.png';
  static const String badgeGrandSorcerer =
      '$_images/badges/grand_sorcerer.png';
  static const String badgeSupremeWizard =
      '$_images/badges/supreme_wizard.png';

  /// Returns the badge path for a league icon key.
  static String badgeForLeague(String iconKey) =>
      '$_images/badges/$iconKey.png';

  // ─── SVG Icons ───────────────────────────────────────────────────────
  static const String iconBattle = '$_svg/battle.svg';
  static const String iconLeaderboard = '$_svg/leaderboard.svg';
  static const String iconChallenge = '$_svg/challenge.svg';
  static const String iconForum = '$_svg/forum.svg';
  static const String iconProfile = '$_svg/profile.svg';
  static const String iconSettings = '$_svg/settings.svg';
  static const String iconXp = '$_svg/xp.svg';
  static const String iconStreak = '$_svg/streak.svg';
  static const String iconHint = '$_svg/hint.svg';
  static const String iconTimer = '$_svg/timer.svg';
  static const String iconTrophy = '$_svg/trophy.svg';
  static const String iconSword = '$_svg/sword.svg';
  static const String iconShield = '$_svg/shield.svg';

  // ─── Lottie Animations ───────────────────────────────────────────────
  static const String lottieLoading = '$_lottie/loading.json';
  static const String lottieSuccess = '$_lottie/success.json';
  static const String lottieError = '$_lottie/error.json';
  static const String lottieBattleStart = '$_lottie/battle_start.json';
  static const String lottieVictory = '$_lottie/victory.json';
  static const String lottieDefeat = '$_lottie/defeat.json';
  static const String lottieLevelUp = '$_lottie/level_up.json';
  static const String lottieConfetti = '$_lottie/confetti.json';
  static const String lottieCountdown = '$_lottie/countdown.json';
  static const String lottieEmpty = '$_lottie/empty.json';

  // ─── Subject Icons ───────────────────────────────────────────────────
  static const String iconMathematics = '$_icons/mathematics.png';
  static const String iconPhysics = '$_icons/physics.png';
  static const String iconChemistry = '$_icons/chemistry.png';
  static const String iconBiology = '$_icons/biology.png';
  static const String iconComputerScience = '$_icons/computer_science.png';
  static const String iconEnglish = '$_icons/english.png';
  static const String iconHistory = '$_icons/history.png';
  static const String iconGeography = '$_icons/geography.png';

  /// Returns the subject icon path for a given subject name.
  static String iconForSubject(String subject) {
    final key = subject.toLowerCase().replaceAll(' ', '_');
    return '$_icons/$key.png';
  }

  // ─── Sounds ──────────────────────────────────────────────────────────
  static const String soundCorrect = '$_sounds/correct.mp3';
  static const String soundIncorrect = '$_sounds/incorrect.mp3';
  static const String soundBattleStart = '$_sounds/battle_start.mp3';
  static const String soundVictory = '$_sounds/victory.mp3';
  static const String soundDefeat = '$_sounds/defeat.mp3';
  static const String soundCountdown = '$_sounds/countdown.mp3';
  static const String soundLevelUp = '$_sounds/level_up.mp3';
  static const String soundHint = '$_sounds/hint.mp3';

  // ─── Backgrounds / Patterns ──────────────────────────────────────────
  static const String bgPattern = '$_images/bg_pattern.png';
  static const String bgStars = '$_images/bg_stars.png';
  static const String bgGrid = '$_images/bg_grid.png';
}
