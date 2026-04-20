import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/services/local_profile_service.dart';

// =============================================================================
// MathGameScreen -- INTERACTIVE NUMBER LINE MINI-GAME
//
// Four-phase gamified lesson:
//   Phase 0  PLAY   -- 5 rounds of placing numbers on an interactive number line
//   Phase 1  LEARN  -- Educational cards about number-line concepts
//   Phase 2  QUIZ   -- 3 multiple-choice questions
//   Phase 3  RESULTS-- Stars, XP, celebration, Firestore save
//
// Design language matches the rest of the app:
//   Deep-space dark + glassmorphism + neon cyan accents + particles
// =============================================================================

// ─── Round data model ────────────────────────────────────────────────────────

class _NumberLineRound {
  final String question;
  final double correctValue;
  final double rangeMin;
  final double rangeMax;
  final String hint;

  const _NumberLineRound({
    required this.question,
    required this.correctValue,
    required this.rangeMin,
    required this.rangeMax,
    this.hint = '',
  });
}

// ─── Quiz data model ─────────────────────────────────────────────────────────

class _QuizQuestion {
  final String question;
  final List<String> options;
  final int correctIndex;
  final String explanation;

  const _QuizQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });
}

// ─── Learn card model ────────────────────────────────────────────────────────

class _LearnCard {
  final String title;
  final IconData icon;
  final List<String> points;

  const _LearnCard({
    required this.title,
    required this.icon,
    required this.points,
  });
}

// =============================================================================
// MathGameScreen Widget
// =============================================================================

class MathGameScreen extends StatefulWidget {
  final String lessonId;
  final String subjectId;
  final String chapterId;

  const MathGameScreen({
    super.key,
    required this.lessonId,
    this.subjectId = 'math',
    this.chapterId = 'math_numbers',
  });

  @override
  State<MathGameScreen> createState() => _MathGameScreenState();
}

class _MathGameScreenState extends State<MathGameScreen>
    with TickerProviderStateMixin {
  // ── design tokens ─────────────────────────────────────────────────────────
  static const Color _bg = Color(0xFF111827);
  static const Color _bgSecondary = Color(0xFF1F2937);
  static const Color _surfaceDark = Color(0xFF1F2937);
  static const Color _glassBorder = Color(0x33FFFFFF);
  static const Color _textPrimary = Color(0xFFF0F0F0);
  static const Color _textSecondary = Color(0xFFB0B0C8);
  static const Color _textTertiary = Color(0xFF6B6B8A);
  static const Color _green = Color(0xFF22C55E);
  static const Color _red = Color(0xFFEF4444);
  static const Color _gold = Color(0xFFF59E0B);
  static const Color _cyan = Color(0xFF3B82F6);
  static const Color _purple = Color(0xFF8B5CF6);
  static const Color _accent = _cyan;

  // ── game data ─────────────────────────────────────────────────────────────

  late List<_NumberLineRound> _rounds;
  late List<_QuizQuestion> _quizQuestions;
  final _rng = Random();

  // ── round generator ─────────────────────────────────────────────────────
  // Generates 7 randomized rounds with increasing difficulty

  List<_NumberLineRound> _generateRounds() {
    final rounds = <_NumberLineRound>[];

    // Round 1: Easy whole number (positive)
    final r1val = _rng.nextInt(4) + 1; // 1-4
    rounds.add(_NumberLineRound(
      question: 'Place $r1val on the number line',
      correctValue: r1val.toDouble(),
      rangeMin: 0,
      rangeMax: (r1val + 3).toDouble(),
      hint: 'Find the tick mark labeled $r1val',
    ));

    // Round 2: Negative whole number
    final r2val = -(_rng.nextInt(4) + 1); // -1 to -4
    rounds.add(_NumberLineRound(
      question: 'Place $r2val on the number line',
      correctValue: r2val.toDouble(),
      rangeMin: (r2val - 2).toDouble(),
      rangeMax: (r2val.abs() + 2).toDouble(),
      hint: 'Negative numbers are to the left of zero',
    ));

    // Round 3: Simple decimal
    final r3base = _rng.nextInt(3); // 0-2
    final r3val = r3base + 0.5;
    rounds.add(_NumberLineRound(
      question: 'Place $r3val on the number line',
      correctValue: r3val,
      rangeMin: (r3base - 1).toDouble(),
      rangeMax: (r3base + 3).toDouble(),
      hint: '$r3val is halfway between $r3base and ${r3base + 1}',
    ));

    // Round 4: Negative decimal
    final r4base = _rng.nextInt(4) + 1; // 1-4
    final r4val = -(r4base + 0.5);
    rounds.add(_NumberLineRound(
      question: 'Place $r4val on the number line',
      correctValue: r4val,
      rangeMin: (r4val - 2).toDouble(),
      rangeMax: 2,
      hint: '$r4val is halfway between ${-(r4base + 1)} and ${-r4base}',
    ));

    // Round 5: Addition result — "Where does 2 + 3 land?"
    final r5a = _rng.nextInt(3) + 1;
    final r5b = _rng.nextInt(3) + 1;
    final r5val = (r5a + r5b).toDouble();
    rounds.add(_NumberLineRound(
      question: 'Place the result of $r5a + $r5b',
      correctValue: r5val,
      rangeMin: 0,
      rangeMax: (r5val + 3).clamp(6, 12),
      hint: '$r5a + $r5b = ${r5val.toInt()}. Find that number on the line.',
    ));

    // Round 6: Subtraction with negative result
    final r6a = _rng.nextInt(3) + 1;
    final r6b = _rng.nextInt(3) + r6a + 1; // b > a to ensure negative
    final r6val = (r6a - r6b).toDouble();
    rounds.add(_NumberLineRound(
      question: 'Place the result of $r6a \u2212 $r6b',
      correctValue: r6val,
      rangeMin: (r6val - 2).toDouble(),
      rangeMax: (r6a + 2).toDouble(),
      hint: '$r6a \u2212 $r6b = ${r6val.toInt()}. It\'s negative!',
    ));

    // Round 7: Tricky quarter/fraction
    final r7options = [0.25, 0.75, 1.25, 1.75, -0.25, -0.75, 2.25, 2.75];
    final r7val = r7options[_rng.nextInt(r7options.length)];
    rounds.add(_NumberLineRound(
      question: 'Place $r7val on the number line',
      correctValue: r7val,
      rangeMin: (r7val - 2).floorToDouble(),
      rangeMax: (r7val + 2).ceilToDouble(),
      hint: '$r7val is between ${r7val.floor()} and ${r7val.ceil()}',
    ));

    return rounds;
  }

  List<_QuizQuestion> _generateQuizQuestions() {
    // Generate dynamic quiz questions based on what happened in the game
    final pool = <_QuizQuestion>[];

    // Basic ordering question
    final nums = <int>[];
    while (nums.length < 4) {
      final n = _rng.nextInt(11) - 5;
      if (!nums.contains(n)) nums.add(n);
    }
    final sorted = List<int>.from(nums)..sort();
    final rightmost = sorted.last;
    final correctIdx = nums.indexOf(rightmost);
    pool.add(_QuizQuestion(
      question:
          'Which number is furthest to the right on a number line?',
      options: nums.map((n) => '$n').toList(),
      correctIndex: correctIdx,
      explanation:
          '$rightmost is the largest number, so it is furthest to the right. On a number line, numbers increase as you move right.',
    ));

    // Number type question
    final typeNums = [-7, -3, -12, -1];
    final typeN = typeNums[_rng.nextInt(typeNums.length)];
    pool.add(_QuizQuestion(
      question: 'What type of number is $typeN?',
      options: [
        'Natural number',
        'Integer',
        'Only a fraction',
        'Not a real number',
      ],
      correctIndex: 1,
      explanation:
          '$typeN is an integer. Integers include all whole numbers and their negatives: ...-3, -2, -1, 0, 1, 2, 3...',
    ));

    // Decimal placement question
    final decVals = [1.5, 2.5, 3.5, 4.5, 0.5];
    final decV = decVals[_rng.nextInt(decVals.length)];
    final decLow = decV.floor();
    final decHigh = decV.ceil();
    pool.add(_QuizQuestion(
      question: 'Where would $decV be on a number line?',
      options: [
        'Between ${decLow - 1} and $decLow',
        'Between $decLow and $decHigh',
        'Exactly on $decLow',
        'Between $decHigh and ${decHigh + 1}',
      ],
      correctIndex: 1,
      explanation:
          '$decV is halfway between $decLow and $decHigh. Decimal numbers sit between the whole number tick marks.',
    ));

    // Distance/absolute value question
    final absA = _rng.nextInt(5) + 1;
    final absB = -(_rng.nextInt(5) + 1);
    final dist = absA - absB;
    pool.add(_QuizQuestion(
      question:
          'What is the distance between $absB and $absA on a number line?',
      options: [
        '${dist - 2}',
        '$dist',
        '${absA + absB.abs() - 1}',
        '${dist + 2}',
      ],
      correctIndex: 1,
      explanation:
          'Distance = |$absA \u2212 ($absB)| = |$absA + ${absB.abs()}| = $dist. Distance is always positive, found by taking the absolute difference.',
    ));

    // Operation on number line
    final opA = _rng.nextInt(5) + 1;
    final opB = _rng.nextInt(5) + 1;
    pool.add(_QuizQuestion(
      question:
          'Starting at $opA, if you move $opB units left, where do you land?',
      options: [
        '${opA + opB}',
        '${opA - opB}',
        '${opB - opA}',
        '${opA * opB}',
      ],
      correctIndex: 1,
      explanation:
          'Moving left means subtracting: $opA \u2212 $opB = ${opA - opB}. Left = subtract, right = add on a number line.',
    ));

    pool.shuffle(_rng);
    return pool.take(3).toList();
  }

  // ── phase management ──────────────────────────────────────────────────────
  // 0 = play, 1 = learn, 2 = quiz, 3 = results
  int _phase = 0;

  // ── PLAY phase state ──────────────────────────────────────────────────────
  int _currentRound = 0;
  int _playScore = 0; // how many rounds correct
  double? _markerValue; // user-placed marker (null = not placed yet)
  bool _roundAnswered = false;
  bool _roundCorrect = false;
  double _numberLineOffset = 0.0; // pan offset in logical units
  final List<Offset> _markerTrail = [];
  bool _showXpFloater = false;

  // Timer per round
  double _roundTimeLeft = 0;
  static const double _roundTimeLimit = 15.0; // seconds per round
  int _speedBonusTotal = 0;
  int _streak = 0;
  int _bestStreak = 0;

  // Type-2 round state (pick the number at a given marker)
  // Every 3rd round (2, 5) is type-2 for variety
  bool get _isType2Round => _currentRound == 2 || _currentRound == 5;
  // For type-2 rounds we show the marker at correct position and let user pick
  int? _type2Selected;
  List<double> _type2Options = [];

  // ── LEARN phase state ─────────────────────────────────────────────────────
  late final PageController _learnPageCtrl;
  int _currentLearnPage = 0;

  // ── QUIZ phase state ──────────────────────────────────────────────────────
  int _currentQuizQ = 0;
  int _quizCorrect = 0;
  int? _quizSelected;
  bool _quizAnswered = false;

  // ── RESULTS phase state ───────────────────────────────────────────────────
  bool _resultsSaved = false;

  // ── animation controllers ─────────────────────────────────────────────────
  late final AnimationController _particleCtrl;
  late final AnimationController _pulseCtrl;
  late final AnimationController _celebrationCtrl;
  late final AnimationController _xpCountCtrl;
  late final AnimationController _starCtrl;
  late final AnimationController _scoreCountCtrl;
  late final AnimationController _markerPulseCtrl;
  late final AnimationController _correctFlashCtrl;
  late final AnimationController _wrongFlashCtrl;

  late final Animation<double> _xpCountAnim;
  late final Animation<double> _scoreCountAnim;

  // ── particle data ─────────────────────────────────────────────────────────
  late final List<_FloatingParticle> _particles;
  late final List<_CelebrationParticle> _celebrationParticles;
  late final List<_CorrectParticle> _correctParticles;

  // ── lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    _learnPageCtrl = PageController();

    // --- animation controllers ---

    _particleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _celebrationCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );

    _xpCountCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _xpCountAnim = CurvedAnimation(
      parent: _xpCountCtrl,
      curve: Curves.easeOutCubic,
    );

    _scoreCountCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _scoreCountAnim = CurvedAnimation(
      parent: _scoreCountCtrl,
      curve: Curves.easeOutCubic,
    );

    _starCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _markerPulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _correctFlashCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _wrongFlashCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    // --- particles ---

    final rng = Random(42);
    _particles = List.generate(60, (_) {
      return _FloatingParticle(
        x: rng.nextDouble(),
        y: rng.nextDouble(),
        radius: 0.3 + rng.nextDouble() * 1.8,
        alpha: 0.05 + rng.nextDouble() * 0.3,
        dx: (rng.nextDouble() - 0.5) * 0.2,
        dy: (rng.nextDouble() - 0.5) * 0.2,
        twinklePhase: rng.nextDouble() * 2 * pi,
      );
    });

    _celebrationParticles = List.generate(80, (_) {
      return _CelebrationParticle(
        startX: 0.3 + rng.nextDouble() * 0.4,
        startY: 0.3 + rng.nextDouble() * 0.2,
        dx: (rng.nextDouble() - 0.5) * 2.0,
        dy: -0.5 - rng.nextDouble() * 1.5,
        gravity: 0.8 + rng.nextDouble() * 0.6,
        rotation: rng.nextDouble() * 2 * pi,
        rotationSpeed: (rng.nextDouble() - 0.5) * 8,
        size: 3 + rng.nextDouble() * 5,
        colorIndex: rng.nextInt(6),
        shape: rng.nextInt(3),
      );
    });

    _correctParticles = List.generate(40, (_) {
      return _CorrectParticle(
        angle: rng.nextDouble() * 2 * pi,
        speed: 60 + rng.nextDouble() * 140,
        size: 2 + rng.nextDouble() * 4,
        colorIndex: rng.nextInt(3),
      );
    });

    // Generate randomized rounds and quiz
    _rounds = _generateRounds();
    _quizQuestions = _generateQuizQuestions();

    // Initialize type-2 options for the first round if needed
    _prepareRound();
  }

  @override
  void dispose() {
    _learnPageCtrl.dispose();
    _particleCtrl.dispose();
    _pulseCtrl.dispose();
    _celebrationCtrl.dispose();
    _xpCountCtrl.dispose();
    _starCtrl.dispose();
    _scoreCountCtrl.dispose();
    _markerPulseCtrl.dispose();
    _correctFlashCtrl.dispose();
    _wrongFlashCtrl.dispose();
    super.dispose();
  }

  // ── computed values ───────────────────────────────────────────────────────

  int get _totalPlayRounds => _rounds.length;
  int get _totalQuizQuestions => _quizQuestions.length;
  int get _totalCorrect => _playScore + _quizCorrect;
  int get _totalPossible => _totalPlayRounds + _totalQuizQuestions;

  bool get _isPerfect => _totalCorrect == _totalPossible;

  int get _xpEarned {
    const base = 100;
    final ratio = _totalCorrect / _totalPossible;
    int xp;
    if (ratio >= 1.0) {
      xp = (base * 1.5).round();
    } else if (ratio >= 0.66) {
      xp = base;
    } else if (ratio >= 0.33) {
      xp = (base * 0.7).round();
    } else {
      xp = (base * 0.4).round();
    }
    // Add speed bonus and streak bonus
    xp += _speedBonusTotal;
    if (_bestStreak >= 5) {
      xp += 20;
    } else if (_bestStreak >= 3) {
      xp += 10;
    }
    return xp;
  }

  int get _starRating {
    final ratio = _totalCorrect / _totalPossible;
    if (ratio >= 1.0) return 3;
    if (ratio >= 0.66) return 2;
    return 1;
  }

  // ── round preparation ─────────────────────────────────────────────────────

  void _prepareRound() {
    _markerValue = null;
    _roundAnswered = false;
    _roundCorrect = false;
    _markerTrail.clear();
    _showXpFloater = false;
    _type2Selected = null;
    _numberLineOffset = 0.0;
    _roundTimeLeft = _roundTimeLimit;

    // Start countdown timer
    _startRoundTimer();

    if (_currentRound < _rounds.length && _isType2Round) {
      _prepareType2Options();
    }
  }

  void _startRoundTimer() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted || _roundAnswered || _phase != 0) return false;
      setState(() {
        _roundTimeLeft -= 0.1;
        if (_roundTimeLeft <= 0) {
          _roundTimeLeft = 0;
          // Auto-submit as wrong if time runs out
          _onTimeUp();
        }
      });
      return _roundTimeLeft > 0 && !_roundAnswered && _phase == 0;
    });
  }

  void _onTimeUp() {
    if (_roundAnswered) return;
    setState(() {
      _roundAnswered = true;
      _roundCorrect = false;
      _streak = 0;
    });
    _wrongFlashCtrl.forward(from: 0);

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      if (_currentRound + 1 >= _totalPlayRounds) {
        _goToLearnPhase();
      } else {
        setState(() {
          _currentRound++;
          _prepareRound();
        });
      }
    });
  }

  void _prepareType2Options() {
    final round = _rounds[_currentRound];
    final correct = round.correctValue;
    final rng = Random();
    final options = <double>{correct};

    while (options.length < 4) {
      final offset = (rng.nextInt(5) - 2) * 0.5;
      final candidate = correct + offset;
      if (candidate != correct &&
          candidate >= round.rangeMin &&
          candidate <= round.rangeMax) {
        options.add(candidate);
      }
      // Fallback to ensure we always get 4 options
      if (options.length < 4) {
        final fallback = correct + (options.length) * 1.0;
        if (fallback <= round.rangeMax) {
          options.add(fallback);
        } else {
          options.add(correct - (options.length) * 1.0);
        }
      }
    }

    _type2Options = options.toList()..shuffle(rng);
  }

  // ── phase transitions ─────────────────────────────────────────────────────

  void _goToLearnPhase() {
    setState(() => _phase = 1);
  }

  void _goToQuizPhase() {
    _quizQuestions = _generateQuizQuestions();
    setState(() {
      _phase = 2;
      _currentQuizQ = 0;
      _quizCorrect = 0;
      _quizSelected = null;
      _quizAnswered = false;
    });
  }

  void _goToResultsPhase() {
    setState(() => _phase = 3);
    _startResultsAnimations();
  }

  Future<void> _startResultsAnimations() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    _scoreCountCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    _xpCountCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    _starCtrl.forward();
    if (_isPerfect) {
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      _celebrationCtrl.repeat();
    }
  }

  Future<void> _saveProgressAndExit() async {
    if (_resultsSaved) {
      if (mounted) context.pop();
      return;
    }
    setState(() => _resultsSaved = true);

    try {
      await LocalProfileService.instance.addXP(_xpEarned);
    } catch (_) {
      // Silently fail
    }

    if (mounted) context.pop();
  }

  // ── PLAY phase logic ──────────────────────────────────────────────────────

  void _onNumberLineTap(double value) {
    if (_roundAnswered) return;

    // Snap to nearest 0.25 (finer precision for harder rounds)
    final snapped = (value * 4).roundToDouble() / 4;
    setState(() {
      _markerValue = snapped;
      _markerTrail.add(Offset(snapped, 0));
      if (_markerTrail.length > 20) _markerTrail.removeAt(0);
    });
  }

  void _onMarkerDrag(double value) {
    if (_roundAnswered) return;

    final round = _rounds[_currentRound];
    final clamped = value.clamp(round.rangeMin.toDouble(), round.rangeMax.toDouble());
    final snapped = (clamped * 4).roundToDouble() / 4;
    setState(() {
      _markerValue = snapped;
      _markerTrail.add(Offset(snapped, 0));
      if (_markerTrail.length > 20) _markerTrail.removeAt(0);
    });
  }

  void _confirmPlacement() {
    if (_markerValue == null || _roundAnswered) return;

    final round = _rounds[_currentRound];
    final diff = (_markerValue! - round.correctValue).abs();
    final correct = diff <= 0.26;

    // Speed bonus: faster = more points (max 5 bonus points)
    final speedBonus = correct
        ? (_roundTimeLeft / _roundTimeLimit * 5).round().clamp(0, 5)
        : 0;

    setState(() {
      _roundAnswered = true;
      _roundCorrect = correct;
      if (correct) {
        _playScore++;
        _streak++;
        if (_streak > _bestStreak) _bestStreak = _streak;
        _speedBonusTotal += speedBonus;
        _showXpFloater = true;
      } else {
        _streak = 0;
      }
    });

    if (correct) {
      _correctFlashCtrl.forward(from: 0);
    } else {
      _wrongFlashCtrl.forward(from: 0);
    }

    // Advance after delay
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (!mounted) return;
      if (_currentRound + 1 >= _totalPlayRounds) {
        _goToLearnPhase();
      } else {
        setState(() {
          _currentRound++;
          _prepareRound();
        });
      }
    });
  }

  void _selectType2Option(int index) {
    if (_roundAnswered) return;

    final round = _rounds[_currentRound];
    final selected = _type2Options[index];
    final correct = (selected - round.correctValue).abs() < 0.01;

    final speedBonus = correct
        ? (_roundTimeLeft / _roundTimeLimit * 5).round().clamp(0, 5)
        : 0;

    setState(() {
      _type2Selected = index;
      _roundAnswered = true;
      _roundCorrect = correct;
      if (correct) {
        _playScore++;
        _streak++;
        if (_streak > _bestStreak) _bestStreak = _streak;
        _speedBonusTotal += speedBonus;
        _showXpFloater = true;
      } else {
        _streak = 0;
      }
    });

    if (correct) {
      _correctFlashCtrl.forward(from: 0);
    } else {
      _wrongFlashCtrl.forward(from: 0);
    }

    Future.delayed(const Duration(milliseconds: 2000), () {
      if (!mounted) return;
      if (_currentRound + 1 >= _totalPlayRounds) {
        _goToLearnPhase();
      } else {
        setState(() {
          _currentRound++;
          _prepareRound();
        });
      }
    });
  }

  // ── QUIZ phase logic ──────────────────────────────────────────────────────

  void _selectQuizOption(int index) {
    if (_quizAnswered) return;

    final question = _quizQuestions[_currentQuizQ];
    final correct = index == question.correctIndex;

    setState(() {
      _quizSelected = index;
      _quizAnswered = true;
      if (correct) _quizCorrect++;
    });
  }

  void _nextQuizQuestion() {
    if (_currentQuizQ + 1 >= _totalQuizQuestions) {
      _goToResultsPhase();
    } else {
      setState(() {
        _currentQuizQ++;
        _quizSelected = null;
        _quizAnswered = false;
      });
    }
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═════════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          _buildBackground(),
          _buildParticleField(),
          _buildAmbientGlows(),
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                Expanded(child: _buildPhaseContent()),
              ],
            ),
          ),
          if (_phase == 3 && _isPerfect) _buildCelebrationOverlay(),
        ],
      ),
    );
  }

  // ─── background layers ────────────────────────────────────────────────────

  Widget _buildBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_bg, _bgSecondary, _surfaceDark],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
    );
  }

  Widget _buildParticleField() {
    return AnimatedBuilder(
      animation: _particleCtrl,
      builder: (context, _) {
        return CustomPaint(
          size: MediaQuery.of(context).size,
          painter: _ParticleFieldPainter(
            particles: _particles,
            progress: _particleCtrl.value,
            color: _accent,
          ),
        );
      },
    );
  }

  Widget _buildAmbientGlows() {
    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (context, _) {
        final pulse = _pulseCtrl.value;
        return Stack(
          children: [
            Positioned(
              top: -80,
              right: -60,
              child: Container(
                width: 200 + pulse * 40,
                height: 200 + pulse * 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _accent.withAlpha((20 + pulse * 15).round()),
                      _accent.withAlpha(0),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -100,
              left: -80,
              child: Container(
                width: 250 + pulse * 30,
                height: 250 + pulse * 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _accent.withAlpha((10 + pulse * 10).round()),
                      _accent.withAlpha(0),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCelebrationOverlay() {
    return AnimatedBuilder(
      animation: _celebrationCtrl,
      builder: (context, _) {
        return CustomPaint(
          size: MediaQuery.of(context).size,
          painter: _CelebrationPainter(
            particles: _celebrationParticles,
            progress: _celebrationCtrl.value,
            colors: [_cyan, _purple, _green, _gold, _red, const Color(0xFFFF8C00)],
          ),
        );
      },
    );
  }

  // ─── top bar ──────────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withAlpha(13),
                border: Border.all(color: _glassBorder, width: 0.5),
              ),
              child: Icon(Icons.arrow_back_rounded, color: _accent, size: 20),
            ),
          ),
          const SizedBox(width: 12),

          // Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Number Line',
                  style: GoogleFonts.orbitron(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                    letterSpacing: 0.8,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Interactive Math Game',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 11,
                    color: _textTertiary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Phase indicator
          _buildPhaseIndicator(),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.3, duration: 400.ms);
  }

  Widget _buildPhaseIndicator() {
    final labels = ['PLAY', 'LEARN', 'QUIZ', 'DONE'];
    final icons = [
      Icons.sports_esports_rounded,
      Icons.auto_stories_rounded,
      Icons.quiz_rounded,
      Icons.emoji_events_rounded,
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: _accent.withAlpha(20),
        border: Border.all(color: _accent.withAlpha(60), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icons[_phase], color: _accent, size: 14),
          const SizedBox(width: 4),
          Text(
            labels[_phase],
            style: GoogleFonts.orbitron(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: _accent,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ─── phase router ─────────────────────────────────────────────────────────

  Widget _buildPhaseContent() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.05, 0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: switch (_phase) {
        0 => _buildPlayPhase(),
        1 => _buildLearnPhase(),
        2 => _buildQuizPhase(),
        3 => _buildResultsPhase(),
        _ => const SizedBox.shrink(),
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PHASE 0: PLAY
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildPlayPhase() {
    final round = _rounds[_currentRound];

    return Padding(
      key: ValueKey('play_phase_$_currentRound'),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          const SizedBox(height: 8),

          // Round & score row
          _buildPlayHeader(),
          const SizedBox(height: 16),

          // Question
          _buildPlayQuestion(round),
          const SizedBox(height: 24),

          // Number line
          Expanded(child: _buildNumberLineArea(round)),

          // Type-2 options or confirm button
          if (_isType2Round)
            _buildType2Options(round)
          else
            _buildConfirmButton(),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildPlayHeader() {
    final timerColor = _roundTimeLeft <= 3
        ? _red
        : _roundTimeLeft <= 7
            ? _gold
            : _accent;
    final timerFrac = (_roundTimeLeft / _roundTimeLimit).clamp(0.0, 1.0);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Round counter
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.white.withAlpha(10),
                border: Border.all(color: _glassBorder, width: 0.5),
              ),
              child: Text(
                'Round ${_currentRound + 1}/$_totalPlayRounds',
                style: GoogleFonts.orbitron(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: _textSecondary,
                  letterSpacing: 1,
                ),
              ),
            ),

            // Streak indicator
            if (_streak >= 2)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: _gold.withAlpha(20),
                  border:
                      Border.all(color: _gold.withAlpha(60), width: 0.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.local_fire_department_rounded,
                        color: _gold, size: 14),
                    const SizedBox(width: 3),
                    Text(
                      '$_streak',
                      style: GoogleFonts.orbitron(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _gold,
                      ),
                    ),
                  ],
                ),
              ),

            // Score
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: _green.withAlpha(15),
                border:
                    Border.all(color: _green.withAlpha(50), width: 0.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_rounded,
                      color: _green, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    '$_playScore',
                    style: GoogleFonts.orbitron(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _green,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        // Timer bar
        if (!_roundAnswered)
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 4,
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(12),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: timerFrac,
                    alignment: Alignment.centerLeft,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        gradient: LinearGradient(
                          colors: [timerColor, timerColor.withAlpha(180)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: timerColor.withAlpha(80),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildPlayQuestion(_NumberLineRound round) {
    final questionText = _isType2Round
        ? 'What number is at the marker?'
        : round.question;

    return Column(
      children: [
        Text(
          questionText,
          textAlign: TextAlign.center,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: _textPrimary,
            height: 1.4,
          ),
        ),
        if (!_roundAnswered && round.hint.isNotEmpty && !_isType2Round) ...[
          const SizedBox(height: 6),
          Text(
            round.hint,
            textAlign: TextAlign.center,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 12,
              color: _textTertiary,
            ),
          ),
        ],
        // Feedback
        if (_roundAnswered) ...[
          const SizedBox(height: 8),
          _buildRoundFeedback(),
        ],
      ],
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildRoundFeedback() {
    if (_roundCorrect) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_rounded, color: _green, size: 20),
          const SizedBox(width: 8),
          Text(
            'Correct!',
            style: GoogleFonts.orbitron(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _green,
              letterSpacing: 1,
            ),
          ),
          if (_showXpFloater) ...[
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: _gold.withAlpha(20),
                border: Border.all(color: _gold.withAlpha(60)),
              ),
              child: Text(
                '+20 XP',
                style: GoogleFonts.orbitron(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: _gold,
                ),
              ),
            )
                .animate()
                .fadeIn(duration: 300.ms)
                .slideY(begin: 0.5, duration: 600.ms, curve: Curves.easeOutCubic),
          ],
        ],
      )
          .animate()
          .fadeIn(duration: 300.ms)
          .scale(begin: const Offset(0.8, 0.8), duration: 400.ms, curve: Curves.elasticOut);
    } else {
      final round = _rounds[_currentRound];
      return Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.close_rounded, color: _red, size: 20),
              const SizedBox(width: 8),
              Text(
                'Not quite!',
                style: GoogleFonts.orbitron(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _red,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'The answer was ${_formatNumber(round.correctValue)}',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 13,
              color: _textSecondary,
            ),
          ),
        ],
      ).animate().fadeIn(duration: 300.ms);
    }
  }

  String _formatNumber(double v) {
    if (v == v.roundToDouble()) return v.round().toString();
    return v.toString();
  }

  // ─── number line ──────────────────────────────────────────────────────────

  Widget _buildNumberLineArea(_NumberLineRound round) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;

        return GestureDetector(
          onPanUpdate: (details) {
            if (_isType2Round) return; // no drag for type 2
            if (_roundAnswered) return;
            final renderBox = context.findRenderObject() as RenderBox;
            final localX = renderBox.globalToLocal(details.globalPosition).dx;
            final value = _pixelToValue(localX, width, round);
            _onMarkerDrag(value);
          },
          onTapDown: (details) {
            if (_isType2Round) return;
            if (_roundAnswered) return;
            final renderBox = context.findRenderObject() as RenderBox;
            final localX = renderBox.globalToLocal(details.globalPosition).dx;
            final value = _pixelToValue(localX, width, round);
            _onNumberLineTap(value);
          },
          child: Stack(
            children: [
              // Number line canvas
              AnimatedBuilder(
                animation: Listenable.merge([_markerPulseCtrl, _correctFlashCtrl, _wrongFlashCtrl]),
                builder: (context, _) {
                  return CustomPaint(
                    size: Size(width, height),
                    painter: _NumberLinePainter(
                      rangeMin: round.rangeMin.toDouble(),
                      rangeMax: round.rangeMax.toDouble(),
                      offset: _numberLineOffset,
                      markerValue: _isType2Round ? round.correctValue : _markerValue,
                      correctValue: _roundAnswered ? round.correctValue : null,
                      isCorrect: _roundCorrect,
                      isAnswered: _roundAnswered,
                      markerPulse: _markerPulseCtrl.value,
                      correctFlash: _correctFlashCtrl.value,
                      wrongFlash: _wrongFlashCtrl.value,
                      trail: _isType2Round ? [] : _markerTrail,
                      showCorrectMarker: _roundAnswered && !_roundCorrect,
                    ),
                  );
                },
              ),

              // Correct-answer particle burst
              if (_roundAnswered && _roundCorrect)
                AnimatedBuilder(
                  animation: _correctFlashCtrl,
                  builder: (context, _) {
                    final markerX = _isType2Round
                        ? _valueToPixel(round.correctValue, width, round)
                        : (_markerValue != null
                            ? _valueToPixel(_markerValue!, width, round)
                            : 0.0);
                    return CustomPaint(
                      size: Size(width, height),
                      painter: _CorrectBurstPainter(
                        particles: _correctParticles,
                        progress: _correctFlashCtrl.value,
                        centerX: markerX,
                        centerY: height * 0.5,
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  double _pixelToValue(double px, double width, _NumberLineRound round) {
    const hPad = 40.0;
    final lineWidth = width - hPad * 2;
    final fraction = ((px - hPad) / lineWidth).clamp(0.0, 1.0);
    return round.rangeMin + fraction * (round.rangeMax - round.rangeMin);
  }

  double _valueToPixel(double value, double width, _NumberLineRound round) {
    const hPad = 40.0;
    final lineWidth = width - hPad * 2;
    final fraction = (value - round.rangeMin) / (round.rangeMax - round.rangeMin);
    return hPad + fraction * lineWidth;
  }

  // ─── type-2 options (pick the number) ─────────────────────────────────────

  Widget _buildType2Options(_NumberLineRound round) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        alignment: WrapAlignment.center,
        children: List.generate(_type2Options.length, (i) {
          final value = _type2Options[i];
          final isSelected = _type2Selected == i;
          final isCorrect = (value - round.correctValue).abs() < 0.01;
          final showCorrect = _roundAnswered && isCorrect;
          final showWrong = _roundAnswered && isSelected && !isCorrect;

          Color bg = Colors.white.withAlpha(10);
          Color border = _glassBorder;
          Color text = _textPrimary;

          if (showCorrect) {
            bg = _green.withAlpha(25);
            border = _green.withAlpha(150);
            text = _green;
          } else if (showWrong) {
            bg = _red.withAlpha(25);
            border = _red.withAlpha(150);
            text = _red;
          } else if (isSelected && !_roundAnswered) {
            bg = _accent.withAlpha(20);
            border = _accent.withAlpha(120);
            text = _accent;
          }

          return GestureDetector(
            onTap: () => _selectType2Option(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: bg,
                border: Border.all(color: border, width: 1),
                boxShadow: showCorrect
                    ? [BoxShadow(color: _green.withAlpha(40), blurRadius: 12)]
                    : null,
              ),
              child: Text(
                _formatNumber(value),
                style: GoogleFonts.orbitron(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: text,
                ),
              ),
            ),
          );
        }),
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms, delay: 200.ms)
        .slideY(begin: 0.15, duration: 400.ms, delay: 200.ms);
  }

  // ─── confirm button ───────────────────────────────────────────────────────

  Widget _buildConfirmButton() {
    final canConfirm = _markerValue != null && !_roundAnswered;

    return GestureDetector(
      onTap: canConfirm ? _confirmPlacement : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: canConfirm
              ? LinearGradient(colors: [_accent, _accent.withAlpha(200)])
              : null,
          color: canConfirm ? null : Colors.white.withAlpha(8),
          border: canConfirm
              ? null
              : Border.all(color: Colors.white.withAlpha(20), width: 0.8),
          boxShadow: canConfirm
              ? [
                  BoxShadow(
                    color: _accent.withAlpha(60),
                    blurRadius: 20,
                    spreadRadius: 1,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_rounded,
              color: canConfirm ? _bg : _textTertiary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              _markerValue != null
                  ? 'CONFIRM: ${_formatNumber(_markerValue!)}'
                  : 'TAP THE NUMBER LINE',
              style: GoogleFonts.orbitron(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: canConfirm ? _bg : _textTertiary,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PHASE 1: LEARN
  // ═══════════════════════════════════════════════════════════════════════════

  List<_LearnCard> get _learnCards => [
        const _LearnCard(
          title: 'Number Line Basics',
          icon: Icons.straighten_rounded,
          points: [
            'Every number has a unique position on the number line',
            'Numbers increase to the right, decrease to the left',
            'Zero is the center reference point',
          ],
        ),
        _LearnCard(
          title: 'Types of Numbers',
          icon: Icons.category_rounded,
          points: [
            'Natural numbers: 1, 2, 3... (counting)',
            'Integers: ...-2, -1, 0, 1, 2... (including negatives)',
            'Rational numbers: fractions like 1/2, 0.75, -3/4',
            'You scored $_playScore/$_totalPlayRounds on the placement challenges!',
          ],
        ),
        const _LearnCard(
          title: 'Why It Matters',
          icon: Icons.auto_awesome_rounded,
          points: [
            'The number line is the foundation of all mathematics',
            'Algebra, calculus, and even physics all use number lines',
            'Understanding number positions helps with: comparing, adding, and graphing',
          ],
        ),
      ];

  Widget _buildLearnPhase() {
    final cards = _learnCards;
    final isLastCard = _currentLearnPage >= cards.length - 1;

    return Column(
      key: const ValueKey('learn_phase'),
      children: [
        // Progress dots
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: _buildProgressDots(cards.length, _currentLearnPage),
        ),

        // Card PageView
        Expanded(
          child: PageView.builder(
            controller: _learnPageCtrl,
            itemCount: cards.length,
            onPageChanged: (i) => setState(() => _currentLearnPage = i),
            physics: const BouncingScrollPhysics(),
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildLearnCard(cards[index], index),
              );
            },
          ),
        ),

        // Nav button
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: _buildLearnNavButton(isLastCard),
        ),
      ],
    );
  }

  Widget _buildProgressDots(int total, int current) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final isActive = i == current;
        final isPast = i < current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          width: isActive ? 24 : 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: isActive
                ? _accent
                : isPast
                    ? _accent.withAlpha(100)
                    : Colors.white.withAlpha(30),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: _accent.withAlpha(100),
                      blurRadius: 8,
                      spreadRadius: 1,
                    )
                  ]
                : null,
          ),
        );
      }),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildLearnCard(_LearnCard card, int index) {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _accent.withAlpha(40), width: 1),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withAlpha(18),
                  Colors.white.withAlpha(8),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: _accent.withAlpha(15),
                  blurRadius: 30,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon + title
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _accent.withAlpha(25),
                          border: Border.all(color: _accent.withAlpha(60), width: 0.8),
                        ),
                        child: Icon(card.icon, color: _accent, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: ShaderMask(
                          shaderCallback: (bounds) => LinearGradient(
                            colors: [_accent, _accent.withAlpha(180)],
                          ).createShader(bounds),
                          child: Text(
                            card.title,
                            style: GoogleFonts.orbitron(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Points
                  ...card.points.map((point) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(top: 6),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _accent.withAlpha(180),
                              boxShadow: [
                                BoxShadow(
                                  color: _accent.withAlpha(60),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              point,
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 15,
                                color: _textSecondary,
                                height: 1.6,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms, delay: 100.ms)
        .slideY(begin: 0.05, duration: 400.ms, delay: 100.ms);
  }

  Widget _buildLearnNavButton(bool isLastCard) {
    return GestureDetector(
      onTap: () {
        if (isLastCard) {
          _goToQuizPhase();
        } else {
          _learnPageCtrl.nextPage(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
          );
        }
      },
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: isLastCard
                ? [_accent, _accent.withAlpha(200)]
                : [_accent.withAlpha(40), _accent.withAlpha(20)],
          ),
          border: isLastCard
              ? null
              : Border.all(color: _accent.withAlpha(60), width: 0.8),
          boxShadow: isLastCard
              ? [
                  BoxShadow(
                    color: _accent.withAlpha(60),
                    blurRadius: 20,
                    spreadRadius: 1,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              isLastCard ? 'START QUIZ' : 'NEXT',
              style: GoogleFonts.orbitron(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isLastCard ? _bg : _accent,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              isLastCard ? Icons.quiz_rounded : Icons.arrow_forward_rounded,
              color: isLastCard ? _bg : _accent,
              size: 18,
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.2, duration: 300.ms);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PHASE 2: QUIZ
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildQuizPhase() {
    final question = _quizQuestions[_currentQuizQ];

    return Padding(
      key: const ValueKey('quiz_phase'),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const SizedBox(height: 8),
          _buildQuizProgressBar(),
          const SizedBox(height: 24),
          _buildQuizQuestionNumber(),
          const SizedBox(height: 16),
          _buildQuizQuestionText(question.question),
          const SizedBox(height: 28),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  ...List.generate(question.options.length, (i) {
                    return _buildQuizOptionButton(question, i)
                        .animate()
                        .fadeIn(
                          duration: 300.ms,
                          delay: Duration(milliseconds: 100 + i * 80),
                        )
                        .slideX(
                          begin: 0.1,
                          duration: 300.ms,
                          delay: Duration(milliseconds: 100 + i * 80),
                        );
                  }),
                  if (_quizAnswered) ...[
                    const SizedBox(height: 16),
                    _buildQuizExplanation(question),
                    const SizedBox(height: 16),
                    _buildQuizContinueButton(),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuizProgressBar() {
    final progress =
        (_currentQuizQ + (_quizAnswered ? 1 : 0)) / _totalQuizQuestions;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Question ${_currentQuizQ + 1} of $_totalQuizQuestions',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 12,
                color: _textTertiary,
                fontWeight: FontWeight.w500,
              ),
            ),
            Row(
              children: [
                Icon(Icons.check_circle_rounded, color: _green, size: 14),
                const SizedBox(width: 4),
                Text(
                  '$_quizCorrect',
                  style: GoogleFonts.orbitron(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _green,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 6,
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: progress.clamp(0.0, 1.0),
                  alignment: Alignment.centerLeft,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOutCubic,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      gradient: LinearGradient(
                        colors: [_accent, _accent.withAlpha(180)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _accent.withAlpha(80),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildQuizQuestionNumber() {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [_accent, _accent.withAlpha(150)],
            ),
            boxShadow: [
              BoxShadow(
                color: _accent.withAlpha(60),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            '${_currentQuizQ + 1}',
            style: GoogleFonts.orbitron(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: _bg,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          'QUESTION',
          style: GoogleFonts.orbitron(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: _textTertiary,
            letterSpacing: 3,
          ),
        ),
      ],
    ).animate().fadeIn(duration: 300.ms).slideX(begin: -0.1, duration: 300.ms);
  }

  Widget _buildQuizQuestionText(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: GoogleFonts.spaceGrotesk(
          fontSize: 19,
          fontWeight: FontWeight.w600,
          color: _textPrimary,
          height: 1.5,
        ),
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 50.ms);
  }

  Widget _buildQuizOptionButton(_QuizQuestion question, int index) {
    final isSelected = _quizSelected == index;
    final isCorrect = index == question.correctIndex;
    final showCorrect = _quizAnswered && isCorrect;
    final showWrong = _quizAnswered && isSelected && !isCorrect;

    Color borderColor = _glassBorder;
    Color bgColor = Colors.white.withAlpha(10);
    Color textColor = _textPrimary;
    Color? glowColor;

    if (showCorrect) {
      borderColor = _green.withAlpha(150);
      bgColor = _green.withAlpha(20);
      textColor = _green;
      glowColor = _green;
    } else if (showWrong) {
      borderColor = _red.withAlpha(150);
      bgColor = _red.withAlpha(20);
      textColor = _red;
      glowColor = _red;
    } else if (isSelected && !_quizAnswered) {
      borderColor = _accent.withAlpha(150);
      bgColor = _accent.withAlpha(15);
      textColor = _accent;
    }

    const optionLetters = ['A', 'B', 'C', 'D'];

    return GestureDetector(
      onTap: () => _selectQuizOption(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor, width: 1),
                color: bgColor,
                boxShadow: glowColor != null
                    ? [
                        BoxShadow(
                          color: glowColor.withAlpha(40),
                          blurRadius: 16,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: showCorrect
                          ? _green.withAlpha(30)
                          : showWrong
                              ? _red.withAlpha(30)
                              : Colors.white.withAlpha(10),
                      border: Border.all(
                        color: showCorrect
                            ? _green.withAlpha(100)
                            : showWrong
                                ? _red.withAlpha(100)
                                : Colors.white.withAlpha(20),
                        width: 0.8,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: showCorrect
                        ? Icon(Icons.check_rounded, color: _green, size: 18)
                        : showWrong
                            ? Icon(Icons.close_rounded, color: _red, size: 18)
                            : Text(
                                optionLetters[index],
                                style: GoogleFonts.orbitron(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: textColor,
                                ),
                              ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      question.options[index],
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: textColor,
                        height: 1.4,
                      ),
                    ),
                  ),
                  if (showCorrect && isSelected)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: _gold.withAlpha(20),
                        border: Border.all(color: _gold.withAlpha(60)),
                      ),
                      child: Text(
                        '+XP',
                        style: GoogleFonts.orbitron(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: _gold,
                        ),
                      ),
                    )
                        .animate()
                        .fadeIn(duration: 300.ms)
                        .scale(begin: const Offset(0.5, 0.5), duration: 300.ms),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuizExplanation(_QuizQuestion question) {
    final isCorrect = _quizSelected == question.correctIndex;
    final color = isCorrect ? _green : _red;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withAlpha(50), width: 0.8),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withAlpha(12),
                color.withAlpha(5),
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isCorrect
                        ? Icons.celebration_rounded
                        : Icons.info_outline_rounded,
                    color: color,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isCorrect ? 'CORRECT!' : 'NOT QUITE',
                    style: GoogleFonts.orbitron(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: color,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                question.explanation,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 13,
                  color: _textSecondary,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms)
        .slideY(begin: 0.1, duration: 400.ms);
  }

  Widget _buildQuizContinueButton() {
    final isLast = _currentQuizQ + 1 >= _totalQuizQuestions;

    return GestureDetector(
      onTap: _nextQuizQuestion,
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [_accent, _accent.withAlpha(200)],
          ),
          boxShadow: [
            BoxShadow(
              color: _accent.withAlpha(60),
              blurRadius: 20,
              spreadRadius: 1,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              isLast ? 'SEE RESULTS' : 'CONTINUE',
              style: GoogleFonts.orbitron(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _bg,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              isLast ? Icons.emoji_events_rounded : Icons.arrow_forward_rounded,
              color: _bg,
              size: 18,
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 300.ms, delay: 200.ms)
        .slideY(begin: 0.2, duration: 300.ms, delay: 200.ms);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PHASE 3: RESULTS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildResultsPhase() {
    return SingleChildScrollView(
      key: const ValueKey('results_phase'),
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const SizedBox(height: 24),
          _buildResultsHeader(),
          const SizedBox(height: 32),
          _buildScoreDisplay(),
          const SizedBox(height: 24),
          _buildXpDisplay(),
          const SizedBox(height: 28),
          _buildStarRating(),
          const SizedBox(height: 32),
          if (_isPerfect) _buildPerfectScoreBanner(),
          if (_isPerfect) const SizedBox(height: 24),
          _buildResultsButton(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildResultsHeader() {
    final title = _isPerfect
        ? 'PERFECT!'
        : _starRating >= 2
            ? 'WELL DONE!'
            : 'KEEP GOING!';
    final subtitle = _isPerfect
        ? 'Flawless mastery - you nailed every question!'
        : _starRating >= 2
            ? 'Great work! You\'re making solid progress.'
            : 'Practice makes perfect. Try again for a better score!';

    final gradientColors = _isPerfect
        ? [_gold, const Color(0xFFFF8C00)]
        : _starRating >= 2
            ? [_accent, _accent.withAlpha(180)]
            : [_purple, _red];

    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: gradientColors.first.withAlpha(20),
            boxShadow: [
              BoxShadow(
                color: gradientColors.first.withAlpha(40),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Icon(
            _isPerfect
                ? Icons.emoji_events_rounded
                : _starRating >= 2
                    ? Icons.military_tech_rounded
                    : Icons.school_rounded,
            color: gradientColors.first,
            size: 42,
          ),
        )
            .animate()
            .scale(
              begin: const Offset(0.0, 0.0),
              end: const Offset(1.0, 1.0),
              duration: 600.ms,
              curve: Curves.elasticOut,
            ),
        const SizedBox(height: 20),

        ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: gradientColors,
          ).createShader(bounds),
          child: Text(
            title,
            style: GoogleFonts.orbitron(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 4,
            ),
          ),
        )
            .animate()
            .fadeIn(duration: 400.ms, delay: 200.ms)
            .scale(begin: const Offset(0.8, 0.8), duration: 400.ms, delay: 200.ms),

        const SizedBox(height: 10),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 14,
            color: _textSecondary,
            height: 1.5,
          ),
        ).animate().fadeIn(duration: 400.ms, delay: 300.ms),
      ],
    );
  }

  Widget _buildScoreDisplay() {
    return AnimatedBuilder(
      animation: _scoreCountAnim,
      builder: (context, _) {
        final animatedCorrect = (_scoreCountAnim.value * _totalCorrect).round();
        return ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _accent.withAlpha(40), width: 1),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withAlpha(15),
                    Colors.white.withAlpha(5),
                  ],
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'SCORE',
                    style: GoogleFonts.orbitron(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _textTertiary,
                      letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '$animatedCorrect',
                        style: GoogleFonts.orbitron(
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          color: _accent,
                        ),
                      ),
                      Text(
                        ' / $_totalPossible',
                        style: GoogleFonts.orbitron(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: _textTertiary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildScoreChip('Play', _playScore, _totalPlayRounds, _cyan),
                      const SizedBox(width: 16),
                      _buildScoreChip('Quiz', _quizCorrect, _totalQuizQuestions, _purple),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      height: 8,
                      width: 200,
                      child: Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: _totalPossible > 0
                                ? (animatedCorrect / _totalPossible).clamp(0.0, 1.0)
                                : 0,
                            alignment: Alignment.centerLeft,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                                gradient: LinearGradient(
                                  colors: [_accent, _accent.withAlpha(180)],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: _accent.withAlpha(80),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    )
        .animate()
        .fadeIn(duration: 400.ms, delay: 100.ms)
        .slideY(begin: 0.1, duration: 400.ms, delay: 100.ms);
  }

  Widget _buildScoreChip(String label, int correct, int total, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: color.withAlpha(15),
        border: Border.all(color: color.withAlpha(50), width: 0.5),
      ),
      child: Text(
        '$label: $correct/$total',
        style: GoogleFonts.spaceGrotesk(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildXpDisplay() {
    return AnimatedBuilder(
      animation: _xpCountAnim,
      builder: (context, _) {
        final animatedXP = (_xpCountAnim.value * _xpEarned).round();
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: _gold.withAlpha(12),
            border: Border.all(color: _gold.withAlpha(40), width: 0.8),
            boxShadow: [
              BoxShadow(
                color: _gold.withAlpha(20),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.auto_awesome_rounded, color: _gold, size: 24),
              const SizedBox(width: 12),
              Text(
                '+$animatedXP XP',
                style: GoogleFonts.orbitron(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: _gold,
                ),
              ),
            ],
          ),
        );
      },
    )
        .animate()
        .fadeIn(duration: 400.ms, delay: 300.ms)
        .slideY(begin: 0.1, duration: 400.ms, delay: 300.ms);
  }

  Widget _buildStarRating() {
    return AnimatedBuilder(
      animation: _starCtrl,
      builder: (context, _) {
        final starProgress = _starCtrl.value;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (i) {
            final earned = i < _starRating;
            final delay = i * 0.25;
            final localProgress = ((starProgress - delay) / 0.4).clamp(0.0, 1.0);
            final scale = earned ? Curves.elasticOut.transform(localProgress) : 0.6;
            final alpha = earned ? (localProgress * 255).round() : 60;

            return Transform.scale(
              scale: earned ? scale : 0.6,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Icon(
                  earned ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: earned
                      ? _gold.withAlpha(alpha)
                      : Colors.white.withAlpha(30),
                  size: 50,
                  shadows: earned && localProgress > 0.5
                      ? [
                          Shadow(
                            color: _gold.withAlpha(100),
                            blurRadius: 20,
                          ),
                        ]
                      : null,
                ),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildPerfectScoreBanner() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _gold.withAlpha(80), width: 1.2),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _gold.withAlpha(20),
                _gold.withAlpha(5),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: _gold.withAlpha(30),
                blurRadius: 24,
                spreadRadius: 3,
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(Icons.emoji_events_rounded, color: _gold, size: 40),
              const SizedBox(height: 8),
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [_gold, Color(0xFFFF8C00)],
                ).createShader(bounds),
                child: Text(
                  'FLAWLESS VICTORY',
                  style: GoogleFonts.orbitron(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 3,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'You answered every question correctly. Legendary!',
                textAlign: TextAlign.center,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 13,
                  color: _gold.withAlpha(200),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 500.ms, delay: 600.ms)
        .scale(
          begin: const Offset(0.9, 0.9),
          duration: 500.ms,
          delay: 600.ms,
          curve: Curves.elasticOut,
        );
  }

  Widget _buildResultsButton() {
    return Column(
      children: [
        // Continue button
        GestureDetector(
          onTap: _saveProgressAndExit,
          child: Container(
            width: double.infinity,
            height: 58,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [_accent, _accent.withAlpha(200)],
              ),
              boxShadow: [
                BoxShadow(
                  color: _accent.withAlpha(60),
                  blurRadius: 24,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: _resultsSaved
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(_bg),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'CONTINUE',
                        style: GoogleFonts.orbitron(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _bg,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Icon(Icons.arrow_forward_rounded, color: _bg, size: 20),
                    ],
                  ),
          ),
        ),

        const SizedBox(height: 12),

        // Play again button
        GestureDetector(
          onTap: () {
            setState(() {
              _phase = 0;
              _currentRound = 0;
              _playScore = 0;
              _streak = 0;
              _bestStreak = 0;
              _speedBonusTotal = 0;
              _resultsSaved = false;
              _rounds = _generateRounds();
              _quizQuestions = _generateQuizQuestions();
              _prepareRound();
            });
          },
          child: Container(
            width: double.infinity,
            height: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.white.withAlpha(8),
              border: Border.all(color: _glassBorder, width: 0.8),
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.replay_rounded, color: _textSecondary, size: 18),
                const SizedBox(width: 8),
                Text(
                  'PLAY AGAIN',
                  style: GoogleFonts.orbitron(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _textSecondary,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Stats
        if (_bestStreak >= 2 || _speedBonusTotal > 0) ...[
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_bestStreak >= 2) ...[
                Icon(Icons.local_fire_department_rounded,
                    color: _gold, size: 16),
                const SizedBox(width: 4),
                Text(
                  'Best streak: $_bestStreak',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 12,
                    color: _gold,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              if (_bestStreak >= 2 && _speedBonusTotal > 0)
                const SizedBox(width: 16),
              if (_speedBonusTotal > 0) ...[
                Icon(Icons.bolt_rounded, color: _accent, size: 16),
                const SizedBox(width: 4),
                Text(
                  'Speed bonus: +$_speedBonusTotal',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 12,
                    color: _accent,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    )
        .animate()
        .fadeIn(duration: 400.ms, delay: 500.ms)
        .slideY(begin: 0.2, duration: 400.ms, delay: 500.ms);
  }
}

// =============================================================================
// CUSTOM PAINTERS
// =============================================================================

// ─── Number Line Painter ────────────────────────────────────────────────────

class _NumberLinePainter extends CustomPainter {
  final double rangeMin;
  final double rangeMax;
  final double offset;
  final double? markerValue;
  final double? correctValue;
  final bool isCorrect;
  final bool isAnswered;
  final double markerPulse;
  final double correctFlash;
  final double wrongFlash;
  final List<Offset> trail;
  final bool showCorrectMarker;

  static const Color _cyan = Color(0xFF3B82F6);
  static const Color _green = Color(0xFF22C55E);
  static const Color _red = Color(0xFFEF4444);

  _NumberLinePainter({
    required this.rangeMin,
    required this.rangeMax,
    required this.offset,
    required this.markerValue,
    required this.correctValue,
    required this.isCorrect,
    required this.isAnswered,
    required this.markerPulse,
    required this.correctFlash,
    required this.wrongFlash,
    required this.trail,
    required this.showCorrectMarker,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const hPad = 40.0;
    final lineY = size.height * 0.5;
    final lineLeft = hPad;
    final lineRight = size.width - hPad;
    final lineWidth = lineRight - lineLeft;
    final range = rangeMax - rangeMin;

    // ── Helper: value → x ────────────────────────────────────────────────
    double valueToX(double v) {
      return lineLeft + ((v - rangeMin) / range) * lineWidth;
    }

    // ── Draw the main number line ────────────────────────────────────────
    // Glow behind the line
    final glowPaint = Paint()
      ..color = _cyan.withAlpha(30)
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawLine(Offset(lineLeft, lineY), Offset(lineRight, lineY), glowPaint);

    // Main line
    final linePaint = Paint()
      ..color = _cyan.withAlpha(200)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(lineLeft, lineY), Offset(lineRight, lineY), linePaint);

    // Arrow tips
    final arrowPaint = Paint()
      ..color = _cyan.withAlpha(180)
      ..style = PaintingStyle.fill;
    // Left arrow
    final leftArrow = Path()
      ..moveTo(lineLeft - 8, lineY)
      ..lineTo(lineLeft + 4, lineY - 6)
      ..lineTo(lineLeft + 4, lineY + 6)
      ..close();
    canvas.drawPath(leftArrow, arrowPaint);
    // Right arrow
    final rightArrow = Path()
      ..moveTo(lineRight + 8, lineY)
      ..lineTo(lineRight - 4, lineY - 6)
      ..lineTo(lineRight - 4, lineY + 6)
      ..close();
    canvas.drawPath(rightArrow, arrowPaint);

    // ── Tick marks & labels ──────────────────────────────────────────────
    // Determine tick step: use 0.5 increments
    for (double v = rangeMin; v <= rangeMax; v += 0.5) {
      final x = valueToX(v);
      final isInteger = (v - v.roundToDouble()).abs() < 0.01;
      final isZero = v.abs() < 0.01;

      // Tick height
      final tickH = isInteger ? 14.0 : 8.0;
      final tickAlpha = isInteger ? 200 : 80;

      final tickPaint = Paint()
        ..color = Colors.white.withAlpha(tickAlpha)
        ..strokeWidth = isInteger ? 1.5 : 0.8;

      canvas.drawLine(
        Offset(x, lineY - tickH),
        Offset(x, lineY + tickH),
        tickPaint,
      );

      // Label for integers
      if (isInteger) {
        final labelStr = v.round().toString();
        final textStyle = TextStyle(
          color: isZero
              ? _cyan.withAlpha(255)
              : Colors.white.withAlpha(200),
          fontSize: isZero ? 14 : 12,
          fontWeight: isZero ? FontWeight.w700 : FontWeight.w500,
          fontFamily: 'monospace',
        );
        final tp = TextPainter(
          text: TextSpan(text: labelStr, style: textStyle),
          textDirection: TextDirection.ltr,
        );
        tp.layout();
        tp.paint(canvas, Offset(x - tp.width / 2, lineY + tickH + 6));
      }
    }

    // ── Marker trail (fading dots) ───────────────────────────────────────
    if (trail.isNotEmpty) {
      for (int i = 0; i < trail.length; i++) {
        final t = trail[i];
        final x = valueToX(t.dx);
        final alpha = ((i / trail.length) * 60).round();
        final trailPaint = Paint()
          ..color = _cyan.withAlpha(alpha)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(x, lineY), 3, trailPaint);
      }
    }

    // ── Correct position marker (when wrong) ─────────────────────────────
    if (showCorrectMarker && correctValue != null) {
      final cx = valueToX(correctValue!);

      // Green glow
      final correctGlowPaint = Paint()
        ..color = _green.withAlpha(40)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
      canvas.drawCircle(Offset(cx, lineY), 16, correctGlowPaint);

      // Vertical line
      final correctLinePaint = Paint()
        ..color = _green.withAlpha(180)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      canvas.drawLine(Offset(cx, lineY - 30), Offset(cx, lineY + 30), correctLinePaint);

      // Circle marker
      final correctCirclePaint = Paint()
        ..color = _green.withAlpha(200)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(cx, lineY), 8, correctCirclePaint);

      // Inner
      final correctInnerPaint = Paint()
        ..color = const Color(0xFF111827)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(cx, lineY), 4, correctInnerPaint);

      // Label
      final correctLabel = _formatVal(correctValue!);
      final correctTp = TextPainter(
        text: TextSpan(
          text: correctLabel,
          style: TextStyle(
            color: _green,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            fontFamily: 'monospace',
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      correctTp.layout();
      correctTp.paint(canvas, Offset(cx - correctTp.width / 2, lineY - 48));
    }

    // ── User marker ──────────────────────────────────────────────────────
    if (markerValue != null) {
      final mx = valueToX(markerValue!);

      // Determine marker color
      Color markerColor;
      if (isAnswered) {
        markerColor = isCorrect ? _green : _red;
      } else {
        markerColor = _cyan;
      }

      // Pulsing outer glow
      final pulseRadius = 18.0 + markerPulse * 8;
      final pulseAlpha = isAnswered
          ? (isCorrect ? 40 + (correctFlash * 60).round() : 40 + (wrongFlash * 60).round())
          : (20 + markerPulse * 30).round();
      final outerGlowPaint = Paint()
        ..color = markerColor.withAlpha(pulseAlpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
      canvas.drawCircle(Offset(mx, lineY), pulseRadius, outerGlowPaint);

      // Vertical drop line from marker
      final dropPaint = Paint()
        ..color = markerColor.withAlpha(120)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      canvas.drawLine(Offset(mx, lineY - 40), Offset(mx, lineY + 40), dropPaint);

      // Marker circle - outer ring
      final ringPaint = Paint()
        ..color = markerColor.withAlpha(220)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;
      canvas.drawCircle(Offset(mx, lineY), 10, ringPaint);

      // Marker circle - filled center
      final fillPaint = Paint()
        ..color = markerColor.withAlpha(180)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(mx, lineY), 6, fillPaint);

      // Inner bright dot
      final innerPaint = Paint()
        ..color = Colors.white.withAlpha(200)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(mx, lineY), 2.5, innerPaint);

      // Value label above marker
      final valStr = _formatVal(markerValue!);
      final valTp = TextPainter(
        text: TextSpan(
          text: valStr,
          style: TextStyle(
            color: markerColor,
            fontSize: 14,
            fontWeight: FontWeight.w800,
            fontFamily: 'monospace',
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      valTp.layout();

      // Label background pill
      final labelRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(mx, lineY - 58),
          width: valTp.width + 16,
          height: valTp.height + 10,
        ),
        const Radius.circular(8),
      );
      final labelBgPaint = Paint()
        ..color = const Color(0xFF111827).withAlpha(200);
      canvas.drawRRect(labelRect, labelBgPaint);
      final labelBorderPaint = Paint()
        ..color = markerColor.withAlpha(100)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      canvas.drawRRect(labelRect, labelBorderPaint);

      valTp.paint(canvas, Offset(mx - valTp.width / 2, lineY - 58 - valTp.height / 2));
    }
  }

  String _formatVal(double v) {
    if ((v - v.roundToDouble()).abs() < 0.01) return v.round().toString();
    return v.toStringAsFixed(1);
  }

  @override
  bool shouldRepaint(covariant _NumberLinePainter old) => true;
}

// ─── Correct-answer burst particles ──────────────────────────────────────────

class _CorrectParticle {
  final double angle;
  final double speed;
  final double size;
  final int colorIndex;

  const _CorrectParticle({
    required this.angle,
    required this.speed,
    required this.size,
    required this.colorIndex,
  });
}

class _CorrectBurstPainter extends CustomPainter {
  final List<_CorrectParticle> particles;
  final double progress;
  final double centerX;
  final double centerY;

  static const _colors = [Color(0xFF22C55E), Color(0xFF3B82F6), Color(0xFFF59E0B)];

  _CorrectBurstPainter({
    required this.particles,
    required this.progress,
    required this.centerX,
    required this.centerY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;

    final paint = Paint()..style = PaintingStyle.fill;
    final t = Curves.easeOut.transform(progress);
    final opacity = (1.0 - progress).clamp(0.0, 1.0);

    for (final p in particles) {
      final dist = p.speed * t;
      final px = centerX + cos(p.angle) * dist;
      final py = centerY + sin(p.angle) * dist;

      final color = _colors[p.colorIndex % _colors.length];
      paint.color = color.withAlpha((opacity * 200).round());

      canvas.drawCircle(Offset(px, py), p.size * (1 - progress * 0.5), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CorrectBurstPainter old) =>
      old.progress != progress;
}

// ─── Background Floating Particles ───────────────────────────────────────────

class _FloatingParticle {
  final double x, y, radius, alpha, dx, dy, twinklePhase;

  const _FloatingParticle({
    required this.x,
    required this.y,
    required this.radius,
    required this.alpha,
    required this.dx,
    required this.dy,
    required this.twinklePhase,
  });
}

class _ParticleFieldPainter extends CustomPainter {
  final List<_FloatingParticle> particles;
  final double progress;
  final Color color;

  _ParticleFieldPainter({
    required this.particles,
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (final p in particles) {
      final px = ((p.x + p.dx * progress) % 1.0) * size.width;
      final py = ((p.y + p.dy * progress) % 1.0) * size.height;

      final twinkle = (sin(progress * 2 * pi * 3 + p.twinklePhase) + 1) / 2;
      final alpha = (p.alpha * (0.3 + 0.7 * twinkle)).clamp(0.0, 1.0);

      paint.color = color.withAlpha((alpha * 255).round());
      canvas.drawCircle(Offset(px, py), p.radius, paint);

      if (p.radius > 1.2) {
        paint.color = color.withAlpha((alpha * 40).round());
        canvas.drawCircle(Offset(px, py), p.radius * 2.5, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ParticleFieldPainter old) => true;
}

// ─── Celebration Confetti ────────────────────────────────────────────────────

class _CelebrationParticle {
  final double startX, startY, dx, dy, gravity;
  final double rotation, rotationSpeed, size;
  final int colorIndex, shape;

  const _CelebrationParticle({
    required this.startX,
    required this.startY,
    required this.dx,
    required this.dy,
    required this.gravity,
    required this.rotation,
    required this.rotationSpeed,
    required this.size,
    required this.colorIndex,
    required this.shape,
  });
}

class _CelebrationPainter extends CustomPainter {
  final List<_CelebrationParticle> particles;
  final double progress;
  final List<Color> colors;

  _CelebrationPainter({
    required this.particles,
    required this.progress,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (final p in particles) {
      final t = progress;
      final x = (p.startX + p.dx * t) * size.width;
      final y = (p.startY + p.dy * t + 0.5 * p.gravity * t * t) * size.height;

      final opacity = (1.0 - t * 0.7).clamp(0.0, 1.0);
      if (opacity <= 0) continue;

      final color = colors[p.colorIndex % colors.length];
      paint.color = color.withAlpha((opacity * 220).round());

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.rotation + p.rotationSpeed * t);

      switch (p.shape) {
        case 0:
          canvas.drawRect(
            Rect.fromCenter(
                center: Offset.zero, width: p.size * 2, height: p.size * 0.6),
            paint,
          );
          break;
        case 1:
          canvas.drawCircle(Offset.zero, p.size * 0.5, paint);
          break;
        default:
          final path = Path()
            ..moveTo(0, -p.size * 0.6)
            ..lineTo(p.size * 0.4, 0)
            ..lineTo(0, p.size * 0.6)
            ..lineTo(-p.size * 0.4, 0)
            ..close();
          canvas.drawPath(path, paint);
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _CelebrationPainter old) =>
      old.progress != progress;
}
