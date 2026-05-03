import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/ai/gemma_orchestrator.dart';
import '../../../core/services/local_memory_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../core/widgets/neon_button.dart';
import '../../../core/widgets/particle_background.dart';

/// Duolingo-style stepped Mastery Path for a single topic.
///
/// Loads a path via [LocalMemoryService.getMasteryPath]. If absent, calls
/// [GemmaOrchestrator.decomposeMasteryPath], persists the result, then renders
/// a vertical sequence of step cards with status indicators and connectors.
class MasteryPathScreen extends StatefulWidget {
  const MasteryPathScreen({
    super.key,
    required this.topic,
    this.level = 'basics',
  });

  final String topic;
  final String level;

  @override
  State<MasteryPathScreen> createState() => _MasteryPathScreenState();
}

class _MasteryPathScreenState extends State<MasteryPathScreen> {
  Map<String, dynamic>? _path;
  bool _loading = true;
  bool _generating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh on return from a lesson so completion ticks update.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _loading || _generating) return;
      _refreshSilently();
    });
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final existing =
          await LocalMemoryService.instance.getMasteryPath(widget.topic);
      if (existing != null) {
        if (!mounted) return;
        setState(() {
          _path = existing;
          _loading = false;
        });
        return;
      }
      await _generatePath();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load path: $e';
      });
    }
  }

  Future<void> _refreshSilently() async {
    try {
      final fresh =
          await LocalMemoryService.instance.getMasteryPath(widget.topic);
      if (!mounted || fresh == null) return;
      setState(() => _path = fresh);
    } catch (_) {
      // Swallow — silent refresh.
    }
  }

  Future<void> _generatePath() async {
    if (!mounted) return;
    setState(() {
      _generating = true;
      _loading = false;
      _error = null;
    });
    try {
      final raw = await GemmaOrchestrator.instance.decomposeMasteryPath(
        topic: widget.topic,
        level: widget.level,
      );
      final stepsRaw = raw['steps'];
      if (stepsRaw is! List || stepsRaw.isEmpty) {
        throw const FormatException('No steps in generated path');
      }
      final steps = stepsRaw
          .whereType<Map>()
          .map((m) => m.cast<String, dynamic>())
          .toList();
      if (steps.isEmpty) {
        throw const FormatException('Steps list parsed empty');
      }
      final estimated = (raw['estimated_minutes'] as num?)?.toInt() ??
          (raw['estimatedMinutes'] as num?)?.toInt() ??
          steps.length * 10;

      await LocalMemoryService.instance.saveMasteryPath(
        topic: widget.topic,
        steps: steps,
        estimatedMinutes: estimated,
      );

      final fresh =
          await LocalMemoryService.instance.getMasteryPath(widget.topic);
      if (!mounted) return;
      setState(() {
        _path = fresh;
        _generating = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _generating = false;
        _error = 'Path generation failed. Try again.';
      });
    }
  }

  void _onTapStep(Map<String, dynamic> step, _StepStatus status) {
    if (status == _StepStatus.locked) return;
    final path = _path;
    if (path == null) return;
    final index = (step['index'] as num?)?.toInt() ?? 0;
    final title = (step['title'] as String?)?.trim() ?? 'Step ${index + 1}';
    final difficulty =
        (step['difficulty'] as String?)?.trim().toLowerCase() ?? 'basics';

    context.push('/lesson', extra: {
      'customTopic': '${widget.topic} — Step ${index + 1}: $title',
      'preselectedLevel': difficulty,
      'pathTopicKey': path['topicKey'],
      'pathStepIndex': index,
    });
  }

  @override
  Widget build(BuildContext context) {
    final dark = AppTheme.isDark(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: AppTheme.scaffoldDecorationOf(context),
        child: Stack(
          children: [
            if (dark)
              const ParticleBackground(
                particleCount: 12,
                particleColor: AppTheme.accentCyan,
                maxRadius: 0.8,
              ),
            SafeArea(child: _buildBody(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) return _LoadingView(label: 'Loading mastery path...');
    if (_generating) {
      return _LoadingView(
        label: 'Designing your mastery path for "${widget.topic}"...',
        showProgress: true,
      );
    }
    if (_error != null || _path == null) {
      return _ErrorView(
        message: _error ?? 'No path available.',
        onRetry: _generatePath,
      );
    }
    return _buildPathView(context);
  }

  Widget _buildPathView(BuildContext context) {
    final path = _path!;
    final steps = (path['steps'] as List).cast<Map<String, dynamic>>();
    final completed =
        (path['completedStepIndices'] as List).cast<int>().toSet();
    final currentIndex = (path['currentStepIndex'] as int?) ?? 0;
    final estMinutes = (path['estimatedMinutes'] as int?) ?? 0;
    final masteredCount = completed.length;
    final progress =
        steps.isEmpty ? 0.0 : masteredCount / steps.length;

    return Column(
      children: [
        _Header(
          topic: path['topic'] as String? ?? widget.topic,
          estimatedMinutes: estMinutes,
          onClose: () => Navigator.of(context).maybePop(),
        ),
        const SizedBox(height: 6),
        _ProgressBar(
          mastered: masteredCount,
          total: steps.length,
          progress: progress,
        ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.15, end: 0),
        const SizedBox(height: 14),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
            itemCount: steps.length,
            itemBuilder: (_, i) {
              final step = steps[i];
              final status = _statusFor(i, currentIndex, completed);
              return _StepCard(
                step: step,
                stepNumber: i + 1,
                isLast: i == steps.length - 1,
                status: status,
                onTap: () => _onTapStep(step, status),
              ).animate().fadeIn(
                    duration: 360.ms,
                    delay: (60 * i).ms,
                  ).slideX(begin: 0.08, end: 0);
            },
          ),
        ),
      ],
    );
  }

  _StepStatus _statusFor(int i, int currentIndex, Set<int> completed) {
    if (completed.contains(i)) return _StepStatus.completed;
    if (i == currentIndex) return _StepStatus.current;
    if (i < currentIndex) return _StepStatus.unlocked;
    return _StepStatus.locked;
  }
}

// ─── Step status ────────────────────────────────────────────────────────────

enum _StepStatus { completed, current, unlocked, locked }

extension on _StepStatus {
  bool get tappable =>
      this == _StepStatus.current ||
      this == _StepStatus.completed ||
      this == _StepStatus.unlocked;
}

// ─── Header ────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({
    required this.topic,
    required this.estimatedMinutes,
    required this.onClose,
  });

  final String topic;
  final int estimatedMinutes;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final cyan = AppTheme.accentCyanOf(context);
    final gold = AppTheme.accentGoldOf(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(
                Icons.arrow_back_ios_rounded,
                color: AppTheme.textPrimaryOf(context),
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: ShaderMask(
              shaderCallback: (b) =>
                  AppTheme.primaryGradientOf(context).createShader(b),
              child: Text(
                topic,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.orbitron(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
          if (estimatedMinutes > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: gold.withAlpha(22),
                border: Border.all(color: gold.withAlpha(70)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.schedule_rounded, color: gold, size: 12),
                  const SizedBox(width: 4),
                  Text(
                    '~$estimatedMinutes min',
                    style: GoogleFonts.orbitron(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: gold,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onClose,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(
                Icons.close_rounded,
                color: cyan,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 350.ms);
  }
}

// ─── Progress bar ──────────────────────────────────────────────────────────

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({
    required this.mastered,
    required this.total,
    required this.progress,
  });

  final int mastered;
  final int total;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final cyan = AppTheme.accentCyanOf(context);
    final green = AppTheme.accentGreenOf(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GlassContainer(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        borderColor: cyan.withAlpha(60),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.flag_rounded, color: green, size: 16),
                const SizedBox(width: 6),
                Text(
                  '$mastered / $total steps mastered',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimaryOf(context),
                  ),
                ),
                const Spacer(),
                Text(
                  '${(progress * 100).round()}%',
                  style: GoogleFonts.orbitron(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: cyan,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                children: [
                  Container(
                    height: 8,
                    color: AppTheme.glassBorderOf(context),
                  ),
                  TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOutCubic,
                    tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
                    builder: (_, v, child) => FractionallySizedBox(
                      widthFactor: v,
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [green, cyan],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: cyan.withAlpha(120),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Step card ─────────────────────────────────────────────────────────────

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.step,
    required this.stepNumber,
    required this.isLast,
    required this.status,
    required this.onTap,
  });

  final Map<String, dynamic> step;
  final int stepNumber;
  final bool isLast;
  final _StepStatus status;
  final VoidCallback onTap;

  Color _statusColor(BuildContext context) {
    switch (status) {
      case _StepStatus.completed:
        return AppTheme.accentGreenOf(context);
      case _StepStatus.current:
        return AppTheme.accentCyanOf(context);
      case _StepStatus.unlocked:
        return AppTheme.accentPurpleOf(context);
      case _StepStatus.locked:
        return AppTheme.textTertiaryOf(context);
    }
  }

  Color _difficultyColor(BuildContext context, String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'advanced':
        return AppTheme.accentPurpleOf(context);
      case 'intermediate':
        return AppTheme.accentCyanOf(context);
      case 'basics':
      default:
        return AppTheme.accentGreenOf(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = (step['title'] as String?)?.trim() ?? 'Step $stepNumber';
    final description = (step['description'] as String?)?.trim() ?? '';
    final concepts = (step['concepts'] as List?)
            ?.whereType<String>()
            .where((c) => c.trim().isNotEmpty)
            .toList() ??
        const <String>[];
    final difficulty =
        (step['difficulty'] as String?)?.trim().toLowerCase() ?? 'basics';

    final indicatorColor = _statusColor(context);
    final diffColor = _difficultyColor(context, difficulty);
    final dimmed = status == _StepStatus.locked;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Indicator + connector column
          SizedBox(
            width: 44,
            child: Column(
              children: [
                _StepIndicator(
                  status: status,
                  number: stepNumber,
                  color: indicatorColor,
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            indicatorColor.withAlpha(140),
                            AppTheme.glassBorderOf(context),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Card body
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
              child: Opacity(
                opacity: dimmed ? 0.5 : 1.0,
                child: GlassContainer(
                  onTap: status.tappable ? onTap : null,
                  borderColor: indicatorColor.withAlpha(
                    status == _StepStatus.current ? 120 : 50,
                  ),
                  borderWidth: status == _StepStatus.current ? 1.4 : 0.8,
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: GoogleFonts.orbitron(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textPrimaryOf(context),
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _DifficultyBadge(
                            label: difficulty,
                            color: diffColor,
                          ),
                        ],
                      ),
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          description,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 12,
                            height: 1.4,
                            color: AppTheme.textSecondaryOf(context),
                          ),
                        ),
                      ],
                      if (concepts.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final c in concepts.take(4))
                              _ConceptChip(label: c),
                          ],
                        ),
                      ],
                      if (status == _StepStatus.current) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Icon(Icons.play_arrow_rounded,
                                color: indicatorColor, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              'TAP TO START',
                              style: GoogleFonts.orbitron(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: indicatorColor,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ] else if (status == _StepStatus.completed) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.check_circle_rounded,
                                color: indicatorColor, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              'COMPLETED',
                              style: GoogleFonts.orbitron(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: indicatorColor,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Step indicator (circle) ───────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({
    required this.status,
    required this.number,
    required this.color,
  });

  final _StepStatus status;
  final int number;
  final Color color;

  @override
  Widget build(BuildContext context) {
    Widget core;
    switch (status) {
      case _StepStatus.completed:
        core = Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: [
              BoxShadow(color: color.withAlpha(120), blurRadius: 12),
            ],
          ),
          child: const Icon(Icons.check_rounded,
              color: Colors.white, size: 20),
        );
        break;
      case _StepStatus.current:
        core = Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [color, color.withAlpha(180)],
            ),
            boxShadow: [
              BoxShadow(color: color.withAlpha(160), blurRadius: 16),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            '$number',
            style: GoogleFonts.orbitron(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .scale(
              begin: const Offset(0.94, 0.94),
              end: const Offset(1.06, 1.06),
              duration: 1100.ms,
              curve: Curves.easeInOut,
            );
        break;
      case _StepStatus.unlocked:
      case _StepStatus.locked:
        final dim = status == _StepStatus.locked;
        core = Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.glassFillOf(context),
            border: Border.all(
              color: color.withAlpha(dim ? 70 : 140),
              width: 1.4,
            ),
          ),
          alignment: Alignment.center,
          child: dim
              ? Icon(Icons.lock_rounded,
                  color: color.withAlpha(160), size: 14)
              : Text(
                  '$number',
                  style: GoogleFonts.orbitron(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
        );
        break;
    }
    return SizedBox(
      width: 36,
      height: 36,
      child: core,
    );
  }
}

// ─── Concept chip ──────────────────────────────────────────────────────────

class _ConceptChip extends StatelessWidget {
  const _ConceptChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final cyan = AppTheme.accentCyanOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: cyan.withAlpha(18),
        border: Border.all(color: cyan.withAlpha(50), width: 0.6),
      ),
      child: Text(
        label,
        style: GoogleFonts.spaceGrotesk(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: cyan,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ─── Difficulty badge ──────────────────────────────────────────────────────

class _DifficultyBadge extends StatelessWidget {
  const _DifficultyBadge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: color.withAlpha(22),
        border: Border.all(color: color.withAlpha(80), width: 0.6),
      ),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.orbitron(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

// ─── Loading view ──────────────────────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  const _LoadingView({required this.label, this.showProgress = false});
  final String label;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    final cyan = AppTheme.accentCyanOf(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                color: cyan,
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 13,
                color: AppTheme.textSecondaryOf(context),
                height: 1.4,
              ),
            ),
            if (showProgress) ...[
              const SizedBox(height: 8),
              Text(
                'Gemma is thinking on-device...',
                style: GoogleFonts.orbitron(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: cyan,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ],
        ),
      ).animate().fadeIn(duration: 300.ms),
    );
  }
}

// ─── Error / empty view ────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: GlassContainer(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          borderColor: AppTheme.accentMagentaOf(context).withAlpha(80),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded,
                  color: AppTheme.accentMagentaOf(context), size: 36),
              const SizedBox(height: 12),
              Text(
                'Something went sideways',
                textAlign: TextAlign.center,
                style: GoogleFonts.orbitron(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimaryOf(context),
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 12,
                  color: AppTheme.textSecondaryOf(context),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: NeonButton(
                  label: 'TRY AGAIN',
                  icon: Icons.refresh_rounded,
                  onTap: onRetry,
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: Text(
                  'Go back',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textTertiaryOf(context),
                  ),
                ),
              ),
            ],
          ),
        ),
      ).animate().fadeIn(duration: 350.ms),
    );
  }
}
