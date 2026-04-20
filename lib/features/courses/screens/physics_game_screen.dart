import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/services/local_profile_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PhysicsGameScreen – INTERACTIVE PROJECTILE MOTION MINI-GAME
//
// Four-phase game level:
//   1. PLAY Phase    – Launch balls with slingshot aiming, watch physics happen
//   2. LEARN Phase   – Glass cards explaining what just happened with real data
//   3. QUIZ Phase    – Questions referencing actual throws
//   4. RESULTS Phase – XP, stars, celebration
//
// Design: Deep space dark + neon cyberpunk + CustomPainter game canvas
// ─────────────────────────────────────────────────────────────────────────────

class PhysicsGameScreen extends StatefulWidget {
  final String lessonId;
  final String subjectId;
  final String chapterId;

  const PhysicsGameScreen({
    super.key,
    required this.lessonId,
    this.subjectId = 'physics',
    this.chapterId = 'physics_motion',
  });

  @override
  State<PhysicsGameScreen> createState() => _PhysicsGameScreenState();
}

class _PhysicsGameScreenState extends State<PhysicsGameScreen>
    with TickerProviderStateMixin {
  // ── palette ──────────────────────────────────────────────────────────────
  static const Color _bg = Color(0xFF111827);
  static const Color _bgSecondary = Color(0xFF1F2937);
  static const Color _surfaceDark = Color(0xFF1F2937);
  static const Color _glassBorder = Color(0x33FFFFFF);
  static const Color _textPrimary = Color(0xFFF0F0F0);
  static const Color _textSecondary = Color(0xFFB0B0C8);
  static const Color _textTertiary = Color(0xFF6B6B8A);
  static const Color _cyan = Color(0xFF3B82F6);
  static const Color _purple = Color(0xFF8B5CF6);
  static const Color _green = Color(0xFF22C55E);
  static const Color _red = Color(0xFFEF4444);
  static const Color _gold = Color(0xFFF59E0B);
  static const Color _orange = Color(0xFFFF8C00);
  static const Color _accent = Color(0xFF8B5CF6);

  // ── phase management ────────────────────────────────────────────────────
  // 0 = play, 1 = learn, 2 = quiz, 3 = results
  int _phase = 0;

  // ── game state ──────────────────────────────────────────────────────────
  double _ballX = 0, _ballY = 0;
  double _velX = 0, _velY = 0;
  double _launchAngle = 45;
  double _launchPower = 50;
  bool _isFlying = false;
  bool _isDragging = false;
  int _launchCount = 0;
  double _flightTime = 0;
  double _maxHeight = 0;
  bool _showLearnPrompt = false;

  // Drag state
  Offset? _dragStart;
  Offset _dragCurrent = Offset.zero;

  // Physics constants
  static const double _gravity = 9.8;
  static const double _groundY = 0.78;
  static const double _launcherX = 0.12;
  static const double _launcherY = 0.78;
  static const double _pixelsPerMeter = 3.5;
  static const double _airResistance = 0.002;
  static const double _bounceCoefficient = 0.45;

  // Ball trail
  final List<Offset> _trail = [];
  static const int _maxTrailLength = 35;

  // Impact particles
  final List<_ImpactParticle> _impactParticles = [];

  // ── wind system ───────────────────────────────────────────────────────
  double _windSpeed = 0; // negative = left, positive = right (m/s)
  static const double _maxWind = 5.0;

  // ── scoring & targets ─────────────────────────────────────────────────
  static const int _maxLaunches = 5;
  int _playScore = 0;
  bool _hasBounced = false;
  final List<_Target> _targets = [];
  _Target? _lastHitTarget;
  int _lastHitPoints = 0;
  double _hitPopupTimer = 0;

  // Launch history
  final List<_LaunchRecord> _launches = [];

  // ── learn phase ─────────────────────────────────────────────────────────
  late final PageController _learnPageCtrl;
  int _currentLearnPage = 0;

  // ── quiz phase ──────────────────────────────────────────────────────────
  int _currentQuestion = 0;
  int _correctCount = 0;
  int? _selectedOption;
  bool _answered = false;
  bool _showExplanation = false;
  late List<_QuizItem> _quizQuestions;

  // ── results phase ───────────────────────────────────────────────────────
  bool _resultsSaved = false;

  // ── animation controllers ───────────────────────────────────────────────
  late final AnimationController _gameLoopCtrl;
  late final AnimationController _particleCtrl;
  late final AnimationController _pulseCtrl;
  late final AnimationController _celebrationCtrl;
  late final AnimationController _xpCountCtrl;
  late final AnimationController _starCtrl;
  late final AnimationController _scoreCountCtrl;
  late final AnimationController _gridCtrl;

  late final Animation<double> _xpCountAnim;
  late final Animation<double> _scoreCountAnim;

  // ── ambient particles ───────────────────────────────────────────────────
  late final List<_FloatingParticle> _particles;
  late final List<_CelebrationParticle> _celebrationParticles;

  // ── random ──────────────────────────────────────────────────────────────
  final _rng = Random(42);

  // ─── lifecycle ──────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    _learnPageCtrl = PageController();

    // Game loop ticker – drives physics simulation
    _gameLoopCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addListener(_gameTick);

    // Animated background grid
    _gridCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    // Background particle field
    _particleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat();

    // Ambient pulse glow
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    // Celebration confetti
    _celebrationCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );

    // XP counter animation
    _xpCountCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _xpCountAnim = CurvedAnimation(
      parent: _xpCountCtrl,
      curve: Curves.easeOutCubic,
    );

    // Score counter animation
    _scoreCountCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _scoreCountAnim = CurvedAnimation(
      parent: _scoreCountCtrl,
      curve: Curves.easeOutCubic,
    );

    // Star reveal animation
    _starCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Generate ambient particles
    _particles = List.generate(50, (_) {
      return _FloatingParticle(
        x: _rng.nextDouble(),
        y: _rng.nextDouble(),
        radius: 0.3 + _rng.nextDouble() * 1.5,
        alpha: 0.05 + _rng.nextDouble() * 0.25,
        dx: (_rng.nextDouble() - 0.5) * 0.15,
        dy: (_rng.nextDouble() - 0.5) * 0.15,
        twinklePhase: _rng.nextDouble() * 2 * pi,
      );
    });

    // Generate celebration particles
    _celebrationParticles = List.generate(80, (_) {
      return _CelebrationParticle(
        startX: 0.3 + _rng.nextDouble() * 0.4,
        startY: 0.3 + _rng.nextDouble() * 0.2,
        dx: (_rng.nextDouble() - 0.5) * 2.0,
        dy: -0.5 - _rng.nextDouble() * 1.5,
        gravity: 0.8 + _rng.nextDouble() * 0.6,
        rotation: _rng.nextDouble() * 2 * pi,
        rotationSpeed: (_rng.nextDouble() - 0.5) * 8,
        size: 3 + _rng.nextDouble() * 5,
        colorIndex: _rng.nextInt(6),
        shape: _rng.nextInt(3),
      );
    });

    // Generate quiz questions
    _quizQuestions = _generateQuizQuestions();

    // Reset ball to launcher
    _resetBall();

    // Initialize wind
    _randomizeWind();

    // Create scoring targets at different distances
    _generateTargets();
  }

  @override
  void dispose() {
    _gameLoopCtrl.dispose();
    _gridCtrl.dispose();
    _particleCtrl.dispose();
    _pulseCtrl.dispose();
    _celebrationCtrl.dispose();
    _xpCountCtrl.dispose();
    _starCtrl.dispose();
    _scoreCountCtrl.dispose();
    _learnPageCtrl.dispose();
    super.dispose();
  }

  // ── computed values ─────────────────────────────────────────────────────

  int get _totalQuestions => _quizQuestions.length;
  bool get _isPerfect => _correctCount == _totalQuestions;
  int get _xpEarned {
    if (_totalQuestions == 0) return 100;
    final ratio = _correctCount / _totalQuestions;
    const base = 150;
    if (ratio >= 1.0) return (base * 1.5).round();
    if (ratio >= 0.66) return base;
    if (ratio >= 0.33) return (base * 0.7).round();
    return (base * 0.4).round();
  }

  int get _starRating {
    if (_totalQuestions == 0) return 3;
    final ratio = _correctCount / _totalQuestions;
    if (ratio >= 1.0) return 3;
    if (ratio >= 0.66) return 2;
    return 1;
  }

  _LaunchRecord? get _lastLaunch =>
      _launches.isNotEmpty ? _launches.last : null;

  // ── wind & target helpers ───────────────────────────────────────────────

  void _randomizeWind() {
    _windSpeed = (_rng.nextDouble() * 2 - 1) * _maxWind;
    // Make wind more interesting: occasionally strong gusts
    if (_rng.nextDouble() < 0.3) {
      _windSpeed *= 1.5;
      _windSpeed = _windSpeed.clamp(-_maxWind * 1.5, _maxWind * 1.5);
    }
  }

  void _generateTargets() {
    _targets.clear();
    // Close target (easy) — 10 points
    _targets.add(_Target(
      x: 0.30 + _rng.nextDouble() * 0.10,
      radius: 0.035,
      points: 10,
      color: _green,
      label: '10',
    ));
    // Mid target — 25 points
    _targets.add(_Target(
      x: 0.48 + _rng.nextDouble() * 0.12,
      radius: 0.025,
      points: 25,
      color: _cyan,
      label: '25',
    ));
    // Far target (hard) — 50 points
    _targets.add(_Target(
      x: 0.70 + _rng.nextDouble() * 0.12,
      radius: 0.018,
      points: 50,
      color: _gold,
      label: '50',
    ));
    // Bullseye (very hard, tiny) — 100 points
    _targets.add(_Target(
      x: 0.85 + _rng.nextDouble() * 0.08,
      radius: 0.012,
      points: 100,
      color: _red,
      label: '100',
    ));
  }

  _Target? _checkTargetHit() {
    for (final t in _targets) {
      if (t.hit) continue;
      final dx = _ballX - t.x;
      if (dx.abs() <= t.radius) {
        return t;
      }
    }
    return null;
  }

  String get _windLabel {
    if (_windSpeed.abs() < 0.5) return 'CALM';
    final dir = _windSpeed > 0 ? '\u2192' : '\u2190';
    return '$dir ${_windSpeed.abs().toStringAsFixed(1)} m/s';
  }

  // ── physics simulation ──────────────────────────────────────────────────

  void _resetBall() {
    setState(() {
      _ballX = _launcherX;
      _ballY = _launcherY;
      _velX = 0;
      _velY = 0;
      _isFlying = false;
      _flightTime = 0;
      _maxHeight = 0;
      _hasBounced = false;
      _trail.clear();
      _impactParticles.clear();
      _lastHitTarget = null;
      _hitPopupTimer = 0;
    });
  }

  void _launchBall() {
    if (_isFlying || _launchCount >= _maxLaunches) return;

    final radians = _launchAngle * pi / 180;
    final powerScale = _launchPower * 0.012;
    _velX = powerScale * cos(radians);
    _velY = -powerScale * sin(radians);
    _isFlying = true;
    _flightTime = 0;
    _maxHeight = 0;
    _hasBounced = false;
    _trail.clear();
    _impactParticles.clear();
    _lastHitTarget = null;
    _hitPopupTimer = 0;
    _launchCount++;

    // Start game loop
    _gameLoopCtrl.repeat();

    setState(() {});
  }

  void _gameTick() {
    if (!_isFlying) {
      // Tick down hit popup
      if (_hitPopupTimer > 0) {
        _hitPopupTimer -= 0.016;
        setState(() {});
      }
      return;
    }

    const double dt = 0.016; // ~60 fps
    final scaledGravity = _gravity * dt * 0.008;

    // Gravity
    _velY += scaledGravity;

    // Wind force (affects horizontal velocity)
    final windForce = _windSpeed * dt * 0.0004;
    _velX += windForce;

    // Air resistance (subtle drag)
    _velX *= (1.0 - _airResistance);
    _velY *= (1.0 - _airResistance * 0.5);

    _ballX += _velX * dt * 8;
    _ballY += _velY * dt * 8;
    _flightTime += dt;

    // Track max height
    final currentHeight = _launcherY - _ballY;
    if (currentHeight > _maxHeight) {
      _maxHeight = currentHeight;
    }

    // Add to trail
    _trail.add(Offset(_ballX, _ballY));
    if (_trail.length > _maxTrailLength) {
      _trail.removeAt(0);
    }

    // Ground collision
    if (_ballY >= _groundY) {
      _ballY = _groundY;

      // Check target hit
      final hitTarget = _checkTargetHit();
      if (hitTarget != null && !hitTarget.hit) {
        hitTarget.hit = true;
        _playScore += hitTarget.points;
        _lastHitTarget = hitTarget;
        _lastHitPoints = hitTarget.points;
        _hitPopupTimer = 2.0;
        // Animate the popup
        _animateHitPopup();
      }

      // Bounce physics: bounce once if enough velocity
      if (!_hasBounced && _velY.abs() > 0.003) {
        _hasBounced = true;
        _velY = -_velY * _bounceCoefficient;
        _velX *= 0.8; // friction on bounce
        _spawnImpactParticles();
      } else {
        // Final landing
        _isFlying = false;
        _gameLoopCtrl.stop();

        // Calculate distance in "meters"
        final distancePx = _ballX - _launcherX;
        final distanceM =
            (distancePx / _pixelsPerMeter * 100).roundToDouble();

        // Record launch
        _launches.add(_LaunchRecord(
          angle: _launchAngle,
          power: _launchPower,
          distance: distanceM,
          maxHeight: (_maxHeight / _pixelsPerMeter * 100).roundToDouble(),
          flightTime: _flightTime,
          initialVelocity: _launchPower * 0.012 * 800,
        ));

        // Spawn impact particles
        _spawnImpactParticles();

        // Randomize wind for next launch
        _randomizeWind();

        // Auto-advance to learn phase after all launches used
        if (_launchCount >= _maxLaunches) {
          Future.delayed(const Duration(milliseconds: 1200), () {
            if (mounted && _phase == 0) {
              setState(() => _showLearnPrompt = true);
            }
          });
        } else if (_launchCount >= 2 && !_showLearnPrompt) {
          // Show optional learn prompt after 2 launches
          Future.delayed(const Duration(milliseconds: 800), () {
            if (mounted) setState(() => _showLearnPrompt = true);
          });
        }

        // Regenerate quiz with real data
        _quizQuestions = _generateQuizQuestions();
      }
    }

    // Ball off screen right
    if (_ballX > 1.1) {
      _isFlying = false;
      _gameLoopCtrl.stop();
      _randomizeWind();
    }

    setState(() {});
  }

  void _spawnImpactParticles() {
    for (int i = 0; i < 20; i++) {
      _impactParticles.add(_ImpactParticle(
        x: _ballX,
        y: _ballY,
        dx: (_rng.nextDouble() - 0.5) * 0.03,
        dy: -_rng.nextDouble() * 0.02,
        life: 1.0,
        decay: 0.02 + _rng.nextDouble() * 0.03,
        size: 1 + _rng.nextDouble() * 3,
        color: _rng.nextBool() ? _cyan : _purple,
      ));
    }
    // Animate impact particles
    Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 16));
      if (!mounted) return false;
      bool anyAlive = false;
      for (final p in _impactParticles) {
        if (p.life > 0) {
          p.x += p.dx;
          p.y += p.dy;
          p.dy += 0.001; // gravity on particles
          p.life -= p.decay;
          anyAlive = true;
        }
      }
      if (mounted) setState(() {});
      return anyAlive && mounted;
    });
  }

  void _animateHitPopup() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 50));
      if (!mounted || _hitPopupTimer <= 0) return false;
      setState(() {
        _hitPopupTimer -= 0.05;
      });
      return _hitPopupTimer > 0 && mounted;
    });
  }

  // ── drag / aim handling ─────────────────────────────────────────────────

  void _onPanStart(DragStartDetails details) {
    if (_isFlying || _phase != 0) return;
    _resetBall();
    _dragStart = details.localPosition;
    _isDragging = true;
    setState(() {});
  }

  void _onPanUpdate(DragUpdateDetails details, Size canvasSize) {
    if (!_isDragging || _dragStart == null) return;

    _dragCurrent = details.localPosition;
    final dx = _dragStart!.dx - _dragCurrent.dx;
    final dy = _dragStart!.dy - _dragCurrent.dy;

    // Calculate angle from drag direction (dragging down-left aims up-right)
    final angle = atan2(dy, dx) * 180 / pi;
    _launchAngle = angle.clamp(5.0, 85.0);

    // Power from drag distance
    final dist = sqrt(dx * dx + dy * dy);
    _launchPower = (dist / canvasSize.width * 200).clamp(10.0, 120.0);

    setState(() {});
  }

  void _onPanEnd(DragEndDetails details) {
    if (!_isDragging) return;
    _isDragging = false;
    _dragStart = null;
    _launchBall();
  }

  // ── trajectory prediction ───────────────────────────────────────────────

  List<Offset> _predictTrajectory() {
    if (!_isDragging) return [];

    final radians = _launchAngle * pi / 180;
    final powerScale = _launchPower * 0.012;
    double vx = powerScale * cos(radians);
    double vy = -powerScale * sin(radians);
    double px = _launcherX;
    double py = _launcherY;

    final points = <Offset>[];
    const dt = 0.016;
    final scaledGravity = _gravity * dt * 0.008;
    final windForce = _windSpeed * dt * 0.0004;

    for (int i = 0; i < 120; i++) {
      vy += scaledGravity;
      vx += windForce;
      vx *= (1.0 - _airResistance);
      vy *= (1.0 - _airResistance * 0.5);
      px += vx * dt * 8;
      py += vy * dt * 8;
      if (i % 3 == 0) points.add(Offset(px, py));
      if (py >= _groundY) break;
      if (px > 1.1) break;
    }
    return points;
  }

  // ── quiz generation ─────────────────────────────────────────────────────

  List<_QuizItem> _generateQuizQuestions() {
    final last = _lastLaunch;
    final angleStr = last != null ? last.angle.toStringAsFixed(0) : '45';
    final velStr =
        last != null ? last.initialVelocity.toStringAsFixed(1) : '50.0';
    final distStr =
        last != null ? last.distance.toStringAsFixed(1) : '100.0';
    final windStr = _windSpeed.abs().toStringAsFixed(1);
    final windDir = _windSpeed > 0 ? 'rightward' : 'leftward';

    // Pool of questions — pick 3 based on what happened in gameplay
    final pool = <_QuizItem>[
      _QuizItem(
        question:
            'What force caused the ball to follow a curved path downward after launch?',
        options: [
          'Air resistance',
          'Gravity',
          'Magnetic force',
          'The wind',
        ],
        correctIndex: 1,
        explanation:
            'Gravity (9.8 m/s\u00B2 downward) is the primary force curving the ball\'s path. While wind pushed it sideways, the downward curve is purely gravitational.',
      ),
      _QuizItem(
        question:
            'You launched at $angleStr\u00B0. If you doubled the power, horizontal distance would approximately:',
        options: [
          'Stay the same',
          'Double',
          'Quadruple',
          'Halve',
        ],
        correctIndex: 2,
        explanation:
            'Range \u221D v\u00B2. The equation R = v\u00B2sin(2\u03B8)/g means doubling v quadruples R. Your throw at $velStr m/s traveled ${distStr}m \u2014 at double speed, that\'s ~${(double.tryParse(distStr) ?? 100) * 4}m.',
      ),
      _QuizItem(
        question:
            'At the highest point of the trajectory, what is the vertical velocity?',
        options: [
          'Maximum',
          'Equal to horizontal velocity',
          'Zero',
          'Negative',
        ],
        correctIndex: 2,
        explanation:
            'At the peak, vertical velocity is exactly zero \u2014 the ball stops rising before gravity pulls it back down. Horizontal velocity continues unchanged.',
      ),
    ];

    // Wind question
    if (_windSpeed.abs() > 1.0) {
      pool.add(_QuizItem(
        question:
            'You experienced $windStr m/s $windDir wind. How does wind affect the trajectory?',
        options: [
          'It curves the path vertically',
          'It shifts the landing point sideways',
          'It increases gravity',
          'It has no real effect',
        ],
        correctIndex: 1,
        explanation:
            'Wind applies a horizontal force, shifting the ball\'s landing point $windDir. The vertical arc stays the same (gravity dominates), but the horizontal drift changes where the ball lands. Compensate by aiming against the wind!',
      ));
    }

    // Bounce question
    pool.add(_QuizItem(
      question:
          'When the ball bounces, it loses about ${((1 - _bounceCoefficient) * 100).round()}% of its speed. Why?',
      options: [
        'Gravity pulls harder after bounce',
        'Energy is converted to heat and sound',
        'The ball weighs more after landing',
        'Wind slows it during bounce',
      ],
      correctIndex: 1,
      explanation:
          'On impact, kinetic energy converts to heat, sound, and deformation. The coefficient of restitution (~${_bounceCoefficient.toStringAsFixed(2)}) determines how much velocity is retained. A perfectly elastic bounce would lose nothing.',
    ));

    // Angle optimization question
    pool.add(_QuizItem(
      question:
          'Ignoring wind and air resistance, what launch angle gives maximum range?',
      options: [
        '30\u00B0',
        '45\u00B0',
        '60\u00B0',
        '90\u00B0',
      ],
      correctIndex: 1,
      explanation:
          '45\u00B0 maximizes range because sin(2\u03B8) is maximized when 2\u03B8 = 90\u00B0 \u2192 \u03B8 = 45\u00B0. But with wind, you may need to adjust! A headwind favors higher angles, a tailwind favors lower ones.',
    ));

    // Shuffle and pick 3
    pool.shuffle(_rng);
    return pool.take(3).toList();
  }

  // ── phase transitions ───────────────────────────────────────────────────

  void _goToLearnPhase() {
    setState(() {
      _phase = 1;
      _showLearnPrompt = false;
    });
  }

  void _goToQuizPhase() {
    _quizQuestions = _generateQuizQuestions();
    setState(() {
      _phase = 2;
      _currentQuestion = 0;
      _correctCount = 0;
      _selectedOption = null;
      _answered = false;
      _showExplanation = false;
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

  // ── quiz logic ──────────────────────────────────────────────────────────

  void _selectOption(int index) {
    if (_answered) return;
    final question = _quizQuestions[_currentQuestion];
    final isCorrect = index == question.correctIndex;
    setState(() {
      _selectedOption = index;
      _answered = true;
      _showExplanation = true;
      if (isCorrect) _correctCount++;
    });
  }

  void _nextQuestion() {
    if (_currentQuestion + 1 >= _totalQuestions) {
      _goToResultsPhase();
    } else {
      setState(() {
        _currentQuestion++;
        _selectedOption = null;
        _answered = false;
        _showExplanation = false;
      });
    }
  }

  // ── save & exit ─────────────────────────────────────────────────────────

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

  // ═════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          // Layer 0: Gradient background
          _buildBackground(),

          // Layer 1: Floating particles
          _buildParticleField(),

          // Layer 2: Ambient glow orbs
          _buildAmbientGlows(),

          // Layer 3: Main content
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                Expanded(child: _buildPhaseContent()),
              ],
            ),
          ),

          // Layer 4: Celebration overlay
          if (_phase == 3 && _isPerfect) _buildCelebrationOverlay(),
        ],
      ),
    );
  }

  // ─── background layers ──────────────────────────────────────────────────

  Widget _buildBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_bg, _bgSecondary, _surfaceDark],
          stops: [0.0, 0.5, 1.0],
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
                      _cyan.withAlpha((15 + pulse * 10).round()),
                      _cyan.withAlpha(0),
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
                      _purple.withAlpha((10 + pulse * 10).round()),
                      _purple.withAlpha(0),
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
            colors: [_cyan, _purple, _green, _gold, _red, _orange],
          ),
        );
      },
    );
  }

  // ─── top bar ────────────────────────────────────────────────────────────

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
              child: const Icon(Icons.arrow_back_rounded,
                  color: _cyan, size: 20),
            ),
          ),
          const SizedBox(width: 12),

          // Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PROJECTILE MOTION',
                  style: GoogleFonts.orbitron(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                    letterSpacing: 0.8,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Newton\'s Laws & Motion',
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
        color: _cyan.withAlpha(20),
        border: Border.all(color: _cyan.withAlpha(60), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icons[_phase], color: _cyan, size: 14),
          const SizedBox(width: 4),
          Text(
            labels[_phase],
            style: GoogleFonts.orbitron(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: _cyan,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ─── phase router ──────────────────────────────────────────────────────

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

  // ═════════════════════════════════════════════════════════════════════════
  // PHASE 0: PLAY
  // ═════════════════════════════════════════════════════════════════════════

  Widget _buildPlayPhase() {
    return Column(
      key: const ValueKey('play_phase'),
      children: [
        // Stats bar
        _buildStatsBar(),

        // Game canvas
        Expanded(child: _buildGameCanvas()),

        // Bottom controls
        _buildPlayControls(),
      ],
    );
  }

  Widget _buildStatsBar() {
    final last = _lastLaunch;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withAlpha(8),
        border: Border.all(color: _glassBorder, width: 0.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            'WIND',
            _windLabel,
            _windSpeed.abs() > 3 ? _red : _windSpeed.abs() > 1.5 ? _orange : _green,
          ),
          _buildStatDivider(),
          _buildStatItem(
            'ANGLE',
            _isDragging
                ? '${_launchAngle.toStringAsFixed(0)}\u00B0'
                : (last != null
                    ? '${last.angle.toStringAsFixed(0)}\u00B0'
                    : '--'),
            _cyan,
          ),
          _buildStatDivider(),
          _buildStatItem(
            'POWER',
            _isDragging
                ? _launchPower.toStringAsFixed(0)
                : (last != null ? last.power.toStringAsFixed(0) : '--'),
            _purple,
          ),
          _buildStatDivider(),
          _buildStatItem(
            'SCORE',
            '$_playScore',
            _gold,
          ),
          _buildStatDivider(),
          _buildStatItem(
            'LEFT',
            '${_maxLaunches - _launchCount}',
            (_maxLaunches - _launchCount) <= 1 ? _red : _green,
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.2, duration: 300.ms);
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: GoogleFonts.orbitron(
            fontSize: 7,
            fontWeight: FontWeight.w700,
            color: _textTertiary,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: GoogleFonts.orbitron(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildStatDivider() {
    return Container(
      width: 1,
      height: 28,
      color: Colors.white.withAlpha(15),
    );
  }

  Widget _buildGameCanvas() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final canvasSize =
            Size(constraints.maxWidth, constraints.maxHeight);

        return GestureDetector(
          onPanStart: _onPanStart,
          onPanUpdate: (d) => _onPanUpdate(d, canvasSize),
          onPanEnd: _onPanEnd,
          child: AnimatedBuilder(
            animation: _gridCtrl,
            builder: (context, _) {
              return CustomPaint(
                size: canvasSize,
                painter: _GameCanvasPainter(
                  ballX: _ballX,
                  ballY: _ballY,
                  isFlying: _isFlying,
                  isDragging: _isDragging,
                  launchAngle: _launchAngle,
                  launchPower: _launchPower,
                  trail: List.from(_trail),
                  predictedPath: _predictTrajectory(),
                  impactParticles: List.from(_impactParticles),
                  targets: _targets,
                  groundY: _groundY,
                  launcherX: _launcherX,
                  launcherY: _launcherY,
                  gridProgress: _gridCtrl.value,
                  launches: _launches,
                  windSpeed: _windSpeed,
                  hitPopupTimer: _hitPopupTimer,
                  lastHitPoints: _lastHitPoints,
                  lastHitTarget: _lastHitTarget,
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildPlayControls() {
    final remaining = _maxLaunches - _launchCount;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Instruction or learn prompt
          if (_showLearnPrompt)
            _buildLearnPromptButton()
          else if (_launchCount == 0)
            _buildInstructionText()
          else if (remaining > 0)
            _buildRelaunchButton()
          else
            _buildLearnPromptButton(),

          const SizedBox(height: 6),

          // Launch count + score
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                remaining > 0
                    ? '$remaining launches remaining'
                    : 'All launches used!',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 11,
                  color: remaining <= 1 && remaining > 0
                      ? _orange
                      : _textTertiary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (_playScore > 0) ...[
                Text(
                  '  \u2022  ',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 11, color: _textTertiary,
                  ),
                ),
                Text(
                  'Score: $_playScore pts',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 11,
                    color: _gold,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionText() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: _cyan.withAlpha(10),
        border: Border.all(color: _cyan.withAlpha(30), width: 0.8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.touch_app_rounded, color: _cyan, size: 18),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              'Drag anywhere to aim & set power, then release to launch!',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 12,
                color: _cyan,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .fadeIn(duration: 600.ms)
        .then()
        .shimmer(
          duration: 1500.ms,
          color: _cyan.withAlpha(30),
        );
  }

  Widget _buildRelaunchButton() {
    return GestureDetector(
      onTap: _resetBall,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white.withAlpha(8),
          border: Border.all(color: _glassBorder, width: 0.8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.replay_rounded, color: _cyan, size: 18),
            const SizedBox(width: 8),
            Text(
              'Drag to launch again',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 12,
                color: _textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLearnPromptButton() {
    return GestureDetector(
      onTap: _goToLearnPhase,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            colors: [_cyan, _cyan.withAlpha(180)],
          ),
          boxShadow: [
            BoxShadow(
              color: _cyan.withAlpha(60),
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
            const Icon(Icons.auto_stories_rounded, color: _bg, size: 18),
            const SizedBox(width: 8),
            Text(
              'GOT IT! LET\'S LEARN WHAT HAPPENED',
              style: GoogleFonts.orbitron(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: _bg,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms)
        .slideY(begin: 0.3, duration: 400.ms)
        .then()
        .shimmer(
          duration: 2000.ms,
          color: Colors.white.withAlpha(40),
        );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // PHASE 1: LEARN
  // ═════════════════════════════════════════════════════════════════════════

  Widget _buildLearnPhase() {
    final last = _lastLaunch;
    final cards = _buildLearnCards(last);

    return Column(
      key: const ValueKey('learn_phase'),
      children: [
        // Progress dots
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: _buildProgressDots(cards.length, _currentLearnPage),
        ),

        // Learn cards
        Expanded(
          child: PageView.builder(
            controller: _learnPageCtrl,
            itemCount: cards.length,
            onPageChanged: (i) => setState(() => _currentLearnPage = i),
            physics: const BouncingScrollPhysics(),
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: cards[index],
              );
            },
          ),
        ),

        // Navigation
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: _buildLearnNavButton(
              _currentLearnPage >= cards.length - 1),
        ),
      ],
    );
  }

  List<Widget> _buildLearnCards(_LaunchRecord? last) {
    final angleVal = last?.angle.toStringAsFixed(0) ?? '45';
    final powerVal = last?.power.toStringAsFixed(0) ?? '50';
    final distVal = last?.distance.toStringAsFixed(1) ?? '0.0';
    final timeVal = last?.flightTime.toStringAsFixed(2) ?? '0.00';
    final velVal = last?.initialVelocity.toStringAsFixed(1) ?? '0.0';
    final heightVal = last?.maxHeight.toStringAsFixed(1) ?? '0.0';

    return [
      // Card 1: What You Just Did
      _buildLearnCard(
        icon: Icons.rocket_launch_rounded,
        iconColor: _cyan,
        chipLabel: 'YOUR EXPERIMENT',
        title: 'What You Just Did',
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _learnDataRow('Launch Angle', '$angleVal\u00B0', _cyan),
            _learnDataRow('Launch Power', powerVal, _purple),
            _learnDataRow('Distance Traveled', '${distVal}m', _green),
            _learnDataRow('Flight Time', '${timeVal}s', _gold),
            _learnDataRow('Max Height', '${heightVal}m', _orange),
            const SizedBox(height: 16),
            _learnHighlight(
              'This is called Projectile Motion \u2014 an object launched into the air following a curved path under the influence of gravity alone.',
            ),
          ],
        ),
      ),

      // Card 2: Forces at Play
      _buildLearnCard(
        icon: Icons.science_rounded,
        iconColor: _purple,
        chipLabel: 'FORCES AT PLAY',
        title: 'The Physics Behind It',
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _learnEquationBlock('F = ma', 'Force = mass \u00D7 acceleration'),
            const SizedBox(height: 16),
            _learnTextBlock(
              'Gravity pulled the ball down at 9.8 m/s\u00B2. This constant downward acceleration created the parabolic curve you saw.',
            ),
            const SizedBox(height: 12),
            _learnTextBlock(
              'Wind at ${_windSpeed.abs().toStringAsFixed(1)} m/s pushed the ball ${_windSpeed >= 0 ? "rightward" : "leftward"}, adding a horizontal force that shifted the landing point. In real life, air resistance also slows the ball.',
            ),
            const SizedBox(height: 12),
            _learnTextBlock(
              'On bounce, the ball lost ~${((1 - _bounceCoefficient) * 100).round()}% of its speed. This energy went into heat and sound \u2014 that\'s the coefficient of restitution.',
            ),
            const SizedBox(height: 16),
            _learnHighlight(
              'Real projectiles face 3 forces: gravity (down), wind (sideways), and air drag (opposing motion). Mastering all three is what makes this challenging!',
            ),
          ],
        ),
      ),

      // Card 3: The Math
      _buildLearnCard(
        icon: Icons.functions_rounded,
        iconColor: _gold,
        chipLabel: 'THE MATH',
        title: 'Equations of Motion',
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _learnEquationBlock(
              'Horizontal: x = v\u2080 cos(\u03B8) \u00D7 t',
              'Distance = initial velocity \u00D7 cos(angle) \u00D7 time',
            ),
            const SizedBox(height: 12),
            _learnEquationBlock(
              'Vertical: y = v\u2080 sin(\u03B8) \u00D7 t - \u00BDgt\u00B2',
              'Height = initial velocity \u00D7 sin(angle) \u00D7 time - \u00BD \u00D7 gravity \u00D7 time\u00B2',
            ),
            const SizedBox(height: 16),
            _learnHighlight(
              'With your values:\nv\u2080 = $velVal m/s, \u03B8 = $angleVal\u00B0\n'
              'x = $velVal \u00D7 cos($angleVal\u00B0) \u00D7 $timeVal = ${distVal}m\n'
              'Max height = ${heightVal}m at t = ${(last != null ? last.flightTime / 2 : 0).toStringAsFixed(2)}s',
            ),
          ],
        ),
      ),
    ];
  }

  Widget _buildLearnCard({
    required IconData icon,
    required Color iconColor,
    required String chipLabel,
    required String title,
    required Widget content,
  }) {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: iconColor.withAlpha(40), width: 1),
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
                  color: iconColor.withAlpha(15),
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
                  // Chip
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: iconColor.withAlpha(20),
                      border:
                          Border.all(color: iconColor.withAlpha(60), width: 0.8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, color: iconColor, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          chipLabel,
                          style: GoogleFonts.orbitron(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: iconColor,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Title
                  ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: [iconColor, iconColor.withAlpha(180)],
                    ).createShader(bounds),
                    child: Text(
                      title,
                      style: GoogleFonts.orbitron(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.5,
                        height: 1.3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Content
                  content,
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

  Widget _learnDataRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 14,
              color: _textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: color.withAlpha(15),
              border: Border.all(color: color.withAlpha(40), width: 0.8),
            ),
            child: Text(
              value,
              style: GoogleFonts.orbitron(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _learnEquationBlock(String equation, String description) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: const Color(0xFF0D1117),
        border: Border.all(color: _cyan.withAlpha(30), width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(80),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            equation,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _cyan,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 12,
              color: _textTertiary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _learnTextBlock(String text) {
    return Text(
      text,
      style: GoogleFonts.spaceGrotesk(
        fontSize: 14,
        color: _textSecondary,
        height: 1.7,
        letterSpacing: 0.2,
      ),
    );
  }

  Widget _learnHighlight(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _accent.withAlpha(80), width: 1),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _accent.withAlpha(15),
            _accent.withAlpha(5),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: _accent.withAlpha(20),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _accent.withAlpha(30),
            ),
            child: const Icon(Icons.lightbulb_rounded,
                color: _accent, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 13,
                color: _textPrimary,
                height: 1.6,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
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
                ? _cyan
                : isPast
                    ? _cyan.withAlpha(100)
                    : Colors.white.withAlpha(30),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: _cyan.withAlpha(100),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
        );
      }),
    ).animate().fadeIn(duration: 300.ms);
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
                ? [_cyan, _cyan.withAlpha(200)]
                : [_cyan.withAlpha(40), _cyan.withAlpha(20)],
          ),
          border: isLastCard
              ? null
              : Border.all(color: _cyan.withAlpha(60), width: 0.8),
          boxShadow: isLastCard
              ? [
                  BoxShadow(
                    color: _cyan.withAlpha(60),
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
                color: isLastCard ? _bg : _cyan,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              isLastCard ? Icons.quiz_rounded : Icons.arrow_forward_rounded,
              color: isLastCard ? _bg : _cyan,
              size: 18,
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.2, duration: 300.ms);
  }

  // ═════════════════════════════════════════════════════════════════════════
  // PHASE 2: QUIZ
  // ═════════════════════════════════════════════════════════════════════════

  Widget _buildQuizPhase() {
    final question = _quizQuestions[_currentQuestion];

    return Padding(
      key: const ValueKey('quiz_phase'),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const SizedBox(height: 8),
          _buildQuizProgressBar(),
          const SizedBox(height: 24),
          _buildQuestionNumber(),
          const SizedBox(height: 16),
          _buildQuestionText(question.question),
          const SizedBox(height: 28),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  ...List.generate(question.options.length, (i) {
                    return _buildOptionButton(question, i)
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
                  if (_showExplanation) ...[
                    const SizedBox(height: 16),
                    _buildExplanationCard(question),
                  ],
                  if (_answered) ...[
                    const SizedBox(height: 16),
                    _buildContinueButton(),
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
        (_currentQuestion + (_answered ? 1 : 0)) / _totalQuestions;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Question ${_currentQuestion + 1} of $_totalQuestions',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 12,
                color: _textTertiary,
                fontWeight: FontWeight.w500,
              ),
            ),
            Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: _green, size: 14),
                const SizedBox(width: 4),
                Text(
                  '$_correctCount',
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
                        colors: [_cyan, _cyan.withAlpha(180)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _cyan.withAlpha(80),
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

  Widget _buildQuestionNumber() {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [_cyan, _cyan.withAlpha(150)],
            ),
            boxShadow: [
              BoxShadow(
                color: _cyan.withAlpha(60),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            '${_currentQuestion + 1}',
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
    )
        .animate()
        .fadeIn(duration: 300.ms)
        .slideX(begin: -0.1, duration: 300.ms);
  }

  Widget _buildQuestionText(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: GoogleFonts.spaceGrotesk(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: _textPrimary,
          height: 1.5,
        ),
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 50.ms);
  }

  Widget _buildOptionButton(_QuizItem question, int index) {
    final isSelected = _selectedOption == index;
    final isCorrect = index == question.correctIndex;
    final showCorrect = _answered && isCorrect;
    final showWrong = _answered && isSelected && !isCorrect;

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
    } else if (isSelected && !_answered) {
      borderColor = _cyan.withAlpha(150);
      bgColor = _cyan.withAlpha(15);
      textColor = _cyan;
    }

    final optionLetters = ['A', 'B', 'C', 'D'];

    return GestureDetector(
      onTap: () => _selectOption(index),
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
                        ? const Icon(Icons.check_rounded,
                            color: _green, size: 18)
                        : showWrong
                            ? const Icon(Icons.close_rounded,
                                color: _red, size: 18)
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
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
                        .scale(
                          begin: const Offset(0.5, 0.5),
                          duration: 300.ms,
                        ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExplanationCard(_QuizItem question) {
    final isCorrect = _selectedOption == question.correctIndex;
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

  Widget _buildContinueButton() {
    final isLast = _currentQuestion + 1 >= _totalQuestions;

    return GestureDetector(
      onTap: _nextQuestion,
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [_cyan, _cyan.withAlpha(200)],
          ),
          boxShadow: [
            BoxShadow(
              color: _cyan.withAlpha(60),
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

  // ═════════════════════════════════════════════════════════════════════════
  // PHASE 3: RESULTS
  // ═════════════════════════════════════════════════════════════════════════

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
          _buildResultsButtons(),
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
        ? 'Flawless mastery \u2014 you nailed every question!'
        : _starRating >= 2
            ? 'Great work! Physics is your playground.'
            : 'Practice makes perfect. Try again for a better score!';

    final gradientColors = _isPerfect
        ? [_gold, _orange]
        : _starRating >= 2
            ? [_cyan, _purple]
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
            .scale(
              begin: const Offset(0.8, 0.8),
              duration: 400.ms,
              delay: 200.ms,
            ),
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
        final animatedCorrect =
            (_scoreCountAnim.value * _correctCount).round();
        return ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _cyan.withAlpha(40), width: 1),
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
                          color: _cyan,
                        ),
                      ),
                      Text(
                        ' / $_totalQuestions',
                        style: GoogleFonts.orbitron(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: _textTertiary,
                        ),
                      ),
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
                            widthFactor: _totalQuestions > 0
                                ? (animatedCorrect / _totalQuestions)
                                    .clamp(0.0, 1.0)
                                : 0,
                            alignment: Alignment.centerLeft,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                                gradient: LinearGradient(
                                  colors: [_cyan, _cyan.withAlpha(180)],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: _cyan.withAlpha(80),
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
              const Icon(Icons.auto_awesome_rounded,
                  color: _gold, size: 24),
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
            final localProgress =
                ((starProgress - delay) / 0.4).clamp(0.0, 1.0);
            final scale =
                earned ? Curves.elasticOut.transform(localProgress) : 0.6;
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
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [_gold, _orange],
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
                'You mastered projectile motion. Legendary!',
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

  Widget _buildResultsButtons() {
    return Column(
      children: [
        // Continue / next lesson
        GestureDetector(
          onTap: _saveProgressAndExit,
          child: Container(
            width: double.infinity,
            height: 58,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [_cyan, _cyan.withAlpha(200)],
              ),
              boxShadow: [
                BoxShadow(
                  color: _cyan.withAlpha(60),
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
                      const Icon(Icons.arrow_forward_rounded,
                          color: _bg, size: 20),
                    ],
                  ),
          ),
        ),

        const SizedBox(height: 12),

        // Play again
        GestureDetector(
          onTap: () {
            setState(() {
              _phase = 0;
              _launchCount = 0;
              _launches.clear();
              _showLearnPrompt = false;
              _playScore = 0;
              _resetBall();
              _randomizeWind();
              _generateTargets();
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
                const Icon(Icons.replay_rounded,
                    color: _textSecondary, size: 18),
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
      ],
    )
        .animate()
        .fadeIn(duration: 400.ms, delay: 500.ms)
        .slideY(begin: 0.2, duration: 400.ms, delay: 500.ms);
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// DATA CLASSES
// ═══════════════════════════════════════════════════════════════════════════════

class _LaunchRecord {
  final double angle;
  final double power;
  final double distance;
  final double maxHeight;
  final double flightTime;
  final double initialVelocity;

  const _LaunchRecord({
    required this.angle,
    required this.power,
    required this.distance,
    required this.maxHeight,
    required this.flightTime,
    required this.initialVelocity,
  });
}

class _QuizItem {
  final String question;
  final List<String> options;
  final int correctIndex;
  final String explanation;

  const _QuizItem({
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });
}

class _Target {
  final double x;
  final double radius;
  final int points;
  final Color color;
  final String label;
  bool hit = false;

  _Target({
    required this.x,
    required this.radius,
    required this.points,
    required this.color,
    required this.label,
  });
}

class _ImpactParticle {
  double x, y;
  double dx, dy;
  double life;
  double decay;
  double size;
  Color color;

  _ImpactParticle({
    required this.x,
    required this.y,
    required this.dx,
    required this.dy,
    required this.life,
    required this.decay,
    required this.size,
    required this.color,
  });
}

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

// ═══════════════════════════════════════════════════════════════════════════════
// GAME CANVAS PAINTER
// ═══════════════════════════════════════════════════════════════════════════════

class _GameCanvasPainter extends CustomPainter {
  final double ballX, ballY;
  final bool isFlying, isDragging;
  final double launchAngle, launchPower;
  final List<Offset> trail;
  final List<Offset> predictedPath;
  final List<_ImpactParticle> impactParticles;
  final List<_Target> targets;
  final double groundY, launcherX, launcherY;
  final double gridProgress;
  final List<_LaunchRecord> launches;
  final double windSpeed;
  final double hitPopupTimer;
  final int lastHitPoints;
  final _Target? lastHitTarget;

  static const Color _cyan = Color(0xFF3B82F6);
  static const Color _purple = Color(0xFF8B5CF6);
  static const Color _green = Color(0xFF22C55E);
  static const Color _red = Color(0xFFEF4444);

  _GameCanvasPainter({
    required this.ballX,
    required this.ballY,
    required this.isFlying,
    required this.isDragging,
    required this.launchAngle,
    required this.launchPower,
    required this.trail,
    required this.predictedPath,
    required this.impactParticles,
    required this.targets,
    required this.groundY,
    required this.launcherX,
    required this.launcherY,
    required this.gridProgress,
    required this.launches,
    required this.windSpeed,
    required this.hitPopupTimer,
    required this.lastHitPoints,
    required this.lastHitTarget,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawGrid(canvas, size);
    _drawGround(canvas, size);
    _drawDistanceMarkers(canvas, size);
    _drawTargets(canvas, size);
    _drawPreviousLandings(canvas, size);
    _drawWindIndicator(canvas, size);
    _drawPredictedPath(canvas, size);
    _drawLauncher(canvas, size);
    _drawTrail(canvas, size);
    _drawBall(canvas, size);
    _drawImpactParticles(canvas, size);
    _drawHitPopup(canvas, size);
    if (isDragging) {
      _drawAimLine(canvas, size);
      _drawPowerIndicator(canvas, size);
    }
  }

  void _drawGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1A2040).withAlpha(100)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    // Horizontal grid lines
    const gridSpacing = 40.0;
    final offset = (gridProgress * gridSpacing) % gridSpacing;

    for (double y = offset; y < size.height; y += gridSpacing) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }

    // Vertical grid lines
    for (double x = offset; x < size.width; x += gridSpacing) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }
  }

  void _drawGround(Canvas canvas, Size size) {
    final gY = groundY * size.height;

    // Ground glow
    final glowPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          _cyan.withAlpha(0),
          _cyan.withAlpha(20),
          _cyan.withAlpha(40),
        ],
      ).createShader(Rect.fromLTWH(0, gY - 20, size.width, 40));
    canvas.drawRect(Rect.fromLTWH(0, gY - 20, size.width, 40), glowPaint);

    // Ground line
    final linePaint = Paint()
      ..color = _cyan.withAlpha(180)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(0, gY), Offset(size.width, gY), linePaint);

    // Subtle glow line
    final glowLinePaint = Paint()
      ..color = _cyan.withAlpha(40)
      ..strokeWidth = 6.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4)
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
        Offset(0, gY), Offset(size.width, gY), glowLinePaint);
  }

  void _drawDistanceMarkers(Canvas canvas, Size size) {
    final gY = groundY * size.height;
    final markerPaint = Paint()
      ..color = _cyan.withAlpha(40)
      ..strokeWidth = 1.0;

    // Draw distance markers every ~10% across
    for (int i = 1; i <= 8; i++) {
      final x = (launcherX + i * 0.1) * size.width;
      if (x >= size.width) break;
      canvas.drawLine(
        Offset(x, gY - 4),
        Offset(x, gY + 4),
        markerPaint,
      );

      // Distance label
      final label = '${(i * 10)}m';
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: _cyan.withAlpha(50),
            fontSize: 8,
            fontFamily: 'monospace',
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, gY + 8));
    }
  }

  void _drawTargets(Canvas canvas, Size size) {
    for (final t in targets) {
      final tX = t.x * size.width;
      final tY = groundY * size.height;
      final alpha = t.hit ? 40 : 255;

      // Target glow
      final glowPaint = Paint()
        ..color = t.color.withAlpha(t.hit ? 5 : 20)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
      canvas.drawCircle(Offset(tX, tY), t.radius * size.width, glowPaint);

      // Target zone (filled area on ground)
      final zoneWidth = t.radius * 2 * size.width;
      final zonePaint = Paint()
        ..color = t.color.withAlpha(t.hit ? 8 : 25)
        ..style = PaintingStyle.fill;
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(tX, tY),
          width: zoneWidth,
          height: 10,
        ),
        zonePaint,
      );

      // Target rings
      for (int i = 3; i >= 1; i--) {
        final radius = i * (t.radius * size.width / 3).clamp(3.0, 8.0);
        final ringPaint = Paint()
          ..color = t.color.withAlpha(((30 + (3 - i) * 20) * alpha / 255).round())
          ..strokeWidth = 1.0
          ..style = PaintingStyle.stroke;
        canvas.drawCircle(Offset(tX, tY - 2), radius, ringPaint);
      }

      // Center dot
      final dotPaint = Paint()
        ..color = t.color.withAlpha((100 * alpha / 255).round());
      canvas.drawCircle(Offset(tX, tY - 2), 2, dotPaint);

      // Hit checkmark or point label
      if (t.hit) {
        final checkPaint = Paint()
          ..color = _green.withAlpha(120)
          ..strokeWidth = 2.0
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;
        final path = Path()
          ..moveTo(tX - 5, tY - 18)
          ..lineTo(tX - 1, tY - 14)
          ..lineTo(tX + 6, tY - 23);
        canvas.drawPath(path, checkPaint);
      } else {
        // Points label
        final tp = TextPainter(
          text: TextSpan(
            text: t.label,
            style: TextStyle(
              color: t.color.withAlpha(100),
              fontSize: 9,
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(tX - tp.width / 2, tY + 10));
      }
    }
  }

  void _drawWindIndicator(Canvas canvas, Size size) {
    if (windSpeed.abs() < 0.3) return;

    final centerX = size.width / 2;
    final y = 16.0;
    final arrowLen = (windSpeed / 8.0).abs() * 40 + 15;
    final dir = windSpeed > 0 ? 1.0 : -1.0;

    // Wind arrow
    final arrowPaint = Paint()
      ..color = windSpeed.abs() > 3
          ? _red.withAlpha(140)
          : _cyan.withAlpha(100)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final startX = centerX - dir * arrowLen / 2;
    final endX = centerX + dir * arrowLen / 2;
    canvas.drawLine(Offset(startX, y), Offset(endX, y), arrowPaint);

    // Arrow tip
    final tipLen = 6.0;
    canvas.drawLine(
      Offset(endX, y),
      Offset(endX - dir * tipLen, y - tipLen),
      arrowPaint,
    );
    canvas.drawLine(
      Offset(endX, y),
      Offset(endX - dir * tipLen, y + tipLen),
      arrowPaint,
    );

    // Wind streaks (animated feel)
    for (int i = 0; i < 3; i++) {
      final streakY = y + (i - 1) * 8.0;
      final streakLen = arrowLen * (0.3 + i * 0.2);
      final streakPaint = Paint()
        ..color = arrowPaint.color.withAlpha(30 + i * 15)
        ..strokeWidth = 1.0
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(centerX - dir * streakLen * 0.3, streakY),
        Offset(centerX + dir * streakLen * 0.5, streakY),
        streakPaint,
      );
    }
  }

  void _drawHitPopup(Canvas canvas, Size size) {
    if (hitPopupTimer <= 0 || lastHitTarget == null) return;

    final t = lastHitTarget!;
    final tX = t.x * size.width;
    final tY = groundY * size.height;
    final alpha = (hitPopupTimer.clamp(0.0, 1.0) * 255).round();
    final rise = (2.0 - hitPopupTimer) * 30; // float upward

    final tp = TextPainter(
      text: TextSpan(
        text: '+$lastHitPoints',
        style: TextStyle(
          color: t.color.withAlpha(alpha),
          fontSize: 20,
          fontFamily: 'monospace',
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(tX - tp.width / 2, tY - 40 - rise));
  }

  void _drawPreviousLandings(Canvas canvas, Size size) {
    for (int i = 0; i < launches.length; i++) {
      final record = launches[i];
      // Approximate landing position
      final approxX = launcherX * size.width +
          (record.distance / 100 * 3.5 * size.width);
      final landY = groundY * size.height;

      if (approxX > size.width) continue;

      final paint = Paint()
        ..color = _purple.withAlpha(30 + i * 10)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(approxX, landY), 3, paint);

      // Small "x" marker
      final markerPaint = Paint()
        ..color = _purple.withAlpha(60)
        ..strokeWidth = 1.0;
      canvas.drawLine(
        Offset(approxX - 3, landY - 3),
        Offset(approxX + 3, landY + 3),
        markerPaint,
      );
      canvas.drawLine(
        Offset(approxX + 3, landY - 3),
        Offset(approxX - 3, landY + 3),
        markerPaint,
      );
    }
  }

  void _drawLauncher(Canvas canvas, Size size) {
    final lX = launcherX * size.width;
    final lY = launcherY * size.height;

    // Base glow
    final basGlow = Paint()
      ..color = _cyan.withAlpha(25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
    canvas.drawCircle(Offset(lX, lY), 24, basGlow);

    // Base ring
    final basePaint = Paint()
      ..color = _cyan.withAlpha(80)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(Offset(lX, lY), 16, basePaint);

    // Inner fill
    final fillPaint = Paint()
      ..color = _cyan.withAlpha(20)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(lX, lY), 16, fillPaint);

    // Center dot
    final centerPaint = Paint()..color = _cyan.withAlpha(150);
    canvas.drawCircle(Offset(lX, lY), 4, centerPaint);

    // Direction indicator line
    final radians = launchAngle * pi / 180;
    final lineLen = 30.0 + (isDragging ? launchPower * 0.2 : 0);
    final endX = lX + lineLen * cos(radians);
    final endY = lY - lineLen * sin(radians);

    final dirPaint = Paint()
      ..color = _cyan.withAlpha(isDragging ? 200 : 80)
      ..strokeWidth = isDragging ? 2.5 : 1.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(lX, lY), Offset(endX, endY), dirPaint);

    // Arrow tip
    if (isDragging) {
      final tipLen = 8.0;
      final tipAngle = 0.4;
      final tip1X =
          endX - tipLen * cos(radians - tipAngle);
      final tip1Y =
          endY + tipLen * sin(radians - tipAngle);
      final tip2X =
          endX - tipLen * cos(radians + tipAngle);
      final tip2Y =
          endY + tipLen * sin(radians + tipAngle);
      canvas.drawLine(Offset(endX, endY), Offset(tip1X, tip1Y), dirPaint);
      canvas.drawLine(Offset(endX, endY), Offset(tip2X, tip2Y), dirPaint);
    }
  }

  void _drawAimLine(Canvas canvas, Size size) {
    // Already drawn via the launcher direction indicator
  }

  void _drawPowerIndicator(Canvas canvas, Size size) {
    final lX = launcherX * size.width;
    final lY = launcherY * size.height;

    // Power bar background
    final barX = lX - 30;
    final barY = lY - 60;
    final barW = 60.0;
    final barH = 6.0;

    final bgPaint = Paint()
      ..color = Colors.white.withAlpha(15)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(barX, barY, barW, barH),
        const Radius.circular(3),
      ),
      bgPaint,
    );

    // Power fill
    final fillFraction = (launchPower / 120).clamp(0.0, 1.0);
    final fillColor = Color.lerp(_cyan, _red, fillFraction)!;
    final fillPaint = Paint()
      ..color = fillColor.withAlpha(200)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(barX, barY, barW * fillFraction, barH),
        const Radius.circular(3),
      ),
      fillPaint,
    );

    // Power glow
    final glowFillPaint = Paint()
      ..color = fillColor.withAlpha(40)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(barX, barY, barW * fillFraction, barH),
        const Radius.circular(3),
      ),
      glowFillPaint,
    );

    // Angle label
    final tp = TextPainter(
      text: TextSpan(
        text: '${launchAngle.toStringAsFixed(0)}\u00B0',
        style: TextStyle(
          color: _cyan.withAlpha(180),
          fontSize: 10,
          fontFamily: 'monospace',
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(barX + barW + 6, barY - 2));
  }

  void _drawPredictedPath(Canvas canvas, Size size) {
    if (predictedPath.isEmpty) return;

    final paint = Paint()
      ..color = _cyan.withAlpha(60)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < predictedPath.length; i++) {
      final p = predictedPath[i];
      final px = p.dx * size.width;
      final py = p.dy * size.height;

      if (py > groundY * size.height) break;

      // Dotted effect: skip every other point
      if (i % 2 == 0) {
        final alpha = ((1.0 - i / predictedPath.length) * 60).round();
        paint.color = _cyan.withAlpha(alpha.clamp(5, 60));
        canvas.drawCircle(Offset(px, py), 2, paint);
      }
    }
  }

  void _drawTrail(Canvas canvas, Size size) {
    if (trail.isEmpty) return;

    for (int i = 0; i < trail.length; i++) {
      final p = trail[i];
      final px = p.dx * size.width;
      final py = p.dy * size.height;

      final frac = i / trail.length;
      final alpha = (frac * 120).round();
      final radius = 1.0 + frac * 4;

      // Trail glow
      final glowPaint = Paint()
        ..color = _cyan.withAlpha((alpha * 0.3).round())
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(Offset(px, py), radius * 1.5, glowPaint);

      // Trail core
      final corePaint = Paint()
        ..color = _cyan.withAlpha(alpha);
      canvas.drawCircle(Offset(px, py), radius, corePaint);
    }
  }

  void _drawBall(Canvas canvas, Size size) {
    final bx = ballX * size.width;
    final by = ballY * size.height;

    // Outer glow
    final outerGlow = Paint()
      ..color = _cyan.withAlpha(30)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
    canvas.drawCircle(Offset(bx, by), 16, outerGlow);

    // Mid glow
    final midGlow = Paint()
      ..color = _cyan.withAlpha(60)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(Offset(bx, by), 10, midGlow);

    // Ball body
    final ballGradient = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withAlpha(240),
          _cyan.withAlpha(200),
          _cyan.withAlpha(120),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(
          Rect.fromCircle(center: Offset(bx, by), radius: 8));
    canvas.drawCircle(Offset(bx, by), 8, ballGradient);

    // Highlight
    final highlightPaint = Paint()
      ..color = Colors.white.withAlpha(100);
    canvas.drawCircle(Offset(bx - 2, by - 2), 2.5, highlightPaint);
  }

  void _drawImpactParticles(Canvas canvas, Size size) {
    for (final p in impactParticles) {
      if (p.life <= 0) continue;
      final px = p.x * size.width;
      final py = p.y * size.height;
      final alpha = (p.life * 200).round().clamp(0, 255);

      final paint = Paint()
        ..color = p.color.withAlpha(alpha)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(px, py), p.size * p.life, paint);

      // Glow
      final glowPaint = Paint()
        ..color = p.color.withAlpha((alpha * 0.3).round())
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawCircle(Offset(px, py), p.size * p.life * 2, glowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _GameCanvasPainter old) => true;
}

// ═══════════════════════════════════════════════════════════════════════════════
// BACKGROUND PARTICLE PAINTER
// ═══════════════════════════════════════════════════════════════════════════════

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

// ═══════════════════════════════════════════════════════════════════════════════
// CELEBRATION CONFETTI PAINTER
// ═══════════════════════════════════════════════════════════════════════════════

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
      final y =
          (p.startY + p.dy * t + 0.5 * p.gravity * t * t) * size.height;

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
              center: Offset.zero,
              width: p.size * 2,
              height: p.size * 0.6,
            ),
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
  bool shouldRepaint(covariant _CelebrationPainter old) => true;
}
