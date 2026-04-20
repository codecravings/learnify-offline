import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/ai/gemma_orchestrator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_container.dart';

enum _ScanPhase { start, preview, analyzing, result, error }

class ScanTextbookScreen extends StatefulWidget {
  const ScanTextbookScreen({super.key});

  @override
  State<ScanTextbookScreen> createState() => _ScanTextbookScreenState();
}

class _ScanTextbookScreenState extends State<ScanTextbookScreen> {
  final _picker = ImagePicker();
  final _orchestrator = GemmaOrchestrator.instance;

  _ScanPhase _phase = _ScanPhase.start;
  Uint8List? _imageBytes;
  String? _errorMsg;

  // Result data
  String _topic = '';
  String _level = 'basics';
  List<String> _concepts = const [];

  Future<void> _pick(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (file == null) return;
      final bytes = await File(file.path).readAsBytes();
      setState(() {
        _imageBytes = bytes;
        _phase = _ScanPhase.preview;
      });
    } catch (e) {
      setState(() {
        _errorMsg = 'Could not load image: $e';
        _phase = _ScanPhase.error;
      });
    }
  }

  Future<void> _analyze() async {
    if (_imageBytes == null) return;
    setState(() => _phase = _ScanPhase.analyzing);

    try {
      final result = await _orchestrator.analyzeTextbookImage(_imageBytes!);
      if (!mounted) return;
      setState(() {
        _topic = (result['topic'] as String?)?.trim().isNotEmpty == true
            ? result['topic'] as String
            : 'Unknown Topic';
        _level = (result['level'] as String?) ?? 'basics';
        _concepts = (result['concepts'] as List?)?.cast<String>() ?? const [];
        _phase = _ScanPhase.result;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMsg = 'Gemma could not read this page. Try a clearer photo.\n\n$e';
        _phase = _ScanPhase.error;
      });
    }
  }

  void _reset() {
    setState(() {
      _imageBytes = null;
      _topic = '';
      _level = 'basics';
      _concepts = const [];
      _errorMsg = null;
      _phase = _ScanPhase.start;
    });
  }

  void _createLesson() {
    context.push('/lesson', extra: {
      'customTopic': _topic,
      'level': _level,
    });
  }

  void _askCompanion() {
    context.push('/home/companion', extra: {
      'seed': 'Explain this topic to me: $_topic. Key concepts: ${_concepts.join(", ")}.',
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('SCAN TEXTBOOK'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: Container(
        decoration: AppTheme.scaffoldDecorationOf(context),
        child: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: switch (_phase) {
              _ScanPhase.start => _buildStart(context),
              _ScanPhase.preview => _buildPreview(context),
              _ScanPhase.analyzing => _buildAnalyzing(context),
              _ScanPhase.result => _buildResult(context),
              _ScanPhase.error => _buildError(context),
            },
          ),
        ),
      ),
    );
  }

  // ── Phase: start ─────────────────────────────────────────────────────────

  Widget _buildStart(BuildContext context) {
    return SingleChildScrollView(
      key: const ValueKey('start'),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          _HeroBanner(),
          const SizedBox(height: 24),
          Text(
            'POINT • SCAN • LEARN',
            style: AppTheme.headerStyle(
              fontSize: 14,
              color: AppTheme.textSecondaryOf(context),
              letterSpacing: 2.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Snap any textbook page. Gemma reads it on-device and turns it into a lesson you actually enjoy.',
            style: AppTheme.bodyStyle(
              fontSize: 15,
              color: AppTheme.textSecondaryOf(context),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          _ActionCard(
            icon: Icons.photo_camera_rounded,
            title: 'Take a photo',
            subtitle: 'Best for live textbook pages',
            color: AppTheme.accentCyanOf(context),
            onTap: () => _pick(ImageSource.camera),
          ),
          const SizedBox(height: 12),
          _ActionCard(
            icon: Icons.photo_library_rounded,
            title: 'Pick from gallery',
            subtitle: 'Scans, screenshots or saved images',
            color: AppTheme.accentPurpleOf(context),
            onTap: () => _pick(ImageSource.gallery),
          ),
          const SizedBox(height: 28),
          _TipsCard(),
        ],
      ),
    );
  }

  // ── Phase: preview ───────────────────────────────────────────────────────

  Widget _buildPreview(BuildContext context) {
    return Column(
      key: const ValueKey('preview'),
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.memory(_imageBytes!, fit: BoxFit.cover),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: GlassContainer(
                      borderRadius: 999,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_awesome_rounded,
                              size: 14, color: AppTheme.accentCyanOf(context)),
                          const SizedBox(width: 6),
                          Text('Ready for Gemma',
                              style: AppTheme.bodyStyle(fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _reset,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retake'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _analyze,
                  icon: const Icon(Icons.auto_fix_high_rounded),
                  label: const Text('Analyze with Gemma'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Phase: analyzing ─────────────────────────────────────────────────────

  Widget _buildAnalyzing(BuildContext context) {
    return Center(
      key: const ValueKey('analyzing'),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _GemmaThinkingOrb(),
            const SizedBox(height: 28),
            Text(
              'READING YOUR PAGE',
              style: AppTheme.headerStyle(
                fontSize: 14,
                letterSpacing: 2.4,
                color: AppTheme.accentCyanOf(context),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Gemma 4 is running entirely on this device.\nNo internet. No cloud. No data leaves your phone.',
              style: AppTheme.bodyStyle(
                fontSize: 14,
                color: AppTheme.textSecondaryOf(context),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ── Phase: result ────────────────────────────────────────────────────────

  Widget _buildResult(BuildContext context) {
    return SingleChildScrollView(
      key: const ValueKey('result'),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_imageBytes != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 140,
                width: double.infinity,
                child: Image.memory(_imageBytes!, fit: BoxFit.cover),
              ),
            ),
          const SizedBox(height: 20),
          Row(
            children: [
              Icon(Icons.check_circle_rounded,
                  size: 18, color: AppTheme.accentGreenOf(context)),
              const SizedBox(width: 8),
              Text(
                'PAGE DECODED',
                style: AppTheme.headerStyle(
                  fontSize: 12,
                  color: AppTheme.accentGreenOf(context),
                  letterSpacing: 2.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _topic,
            style: AppTheme.headerStyle(
              fontSize: 26,
              color: AppTheme.textPrimaryOf(context),
            ),
          ),
          const SizedBox(height: 12),
          _LevelChip(level: _level),
          const SizedBox(height: 24),
          if (_concepts.isNotEmpty) ...[
            Text(
              'KEY CONCEPTS',
              style: AppTheme.headerStyle(
                fontSize: 11,
                color: AppTheme.textSecondaryOf(context),
                letterSpacing: 2.0,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in _concepts) _ConceptChip(label: c),
              ],
            ),
            const SizedBox(height: 28),
          ],
          _PrimaryCta(
            icon: Icons.auto_stories_rounded,
            title: 'Create Story Lesson',
            subtitle: 'Turn this page into an interactive lesson',
            color: AppTheme.accentCyanOf(context),
            onTap: _createLesson,
          ),
          const SizedBox(height: 12),
          _PrimaryCta(
            icon: Icons.chat_bubble_outline_rounded,
            title: 'Ask Companion',
            subtitle: 'Discuss this topic with your Learner Twin',
            color: AppTheme.accentPurpleOf(context),
            onTap: _askCompanion,
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _reset,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Scan another page'),
          ),
        ],
      ),
    );
  }

  // ── Phase: error ─────────────────────────────────────────────────────────

  Widget _buildError(BuildContext context) {
    return Center(
      key: const ValueKey('error'),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded,
                size: 56, color: AppTheme.accentMagentaOf(context)),
            const SizedBox(height: 16),
            Text('Scan failed',
                style: AppTheme.headerStyle(fontSize: 20)),
            const SizedBox(height: 10),
            Text(
              _errorMsg ?? 'Something went wrong.',
              style: AppTheme.bodyStyle(
                fontSize: 13,
                color: AppTheme.textSecondaryOf(context),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _reset,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Private widgets
// ─────────────────────────────────────────────────────────────────────────────

class _HeroBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(24),
      borderRadius: 24,
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppTheme.primaryGradientOf(context),
              boxShadow: AppTheme.neonGlow(AppTheme.accentCyanOf(context)),
            ),
            child: const Icon(Icons.document_scanner_rounded,
                color: Colors.white, size: 34),
          ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(
                duration: 2400.ms,
                begin: const Offset(1, 1),
                end: const Offset(1.06, 1.06),
                curve: Curves.easeInOut,
              ),
          const SizedBox(height: 16),
          Text(
            'Turn pages into lessons',
            style: AppTheme.headerStyle(
              fontSize: 22,
              color: AppTheme.textPrimaryOf(context),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Multimodal • 100% Offline • Private',
            style: AppTheme.bodyStyle(
              fontSize: 12,
              color: AppTheme.accentCyanOf(context),
              letterSpacing: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      onTap: onTap,
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withAlpha(38),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withAlpha(90), width: 1),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppTheme.bodyStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimaryOf(context),
                    )),
                const SizedBox(height: 3),
                Text(subtitle,
                    style: AppTheme.bodyStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondaryOf(context),
                    )),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios_rounded,
              size: 14, color: AppTheme.textTertiaryOf(context)),
        ],
      ),
    );
  }
}

class _TipsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tips = const [
      'Fill the frame with the page',
      'Good lighting, no shadows',
      'Hold steady — one page at a time',
    ];
    return GlassContainer(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tips_and_updates_rounded,
                  size: 18, color: AppTheme.accentGoldOf(context)),
              const SizedBox(width: 8),
              Text('TIPS FOR A GREAT SCAN',
                  style: AppTheme.headerStyle(
                    fontSize: 11,
                    letterSpacing: 2.0,
                    color: AppTheme.accentGoldOf(context),
                  )),
            ],
          ),
          const SizedBox(height: 12),
          for (final t in tips)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_rounded,
                      size: 15, color: AppTheme.accentGreenOf(context)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(t,
                        style: AppTheme.bodyStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondaryOf(context),
                        )),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _LevelChip extends StatelessWidget {
  const _LevelChip({required this.level});
  final String level;

  Color _color(BuildContext context) => switch (level.toLowerCase()) {
        'advanced' => AppTheme.accentMagentaOf(context),
        'intermediate' => AppTheme.accentGoldOf(context),
        _ => AppTheme.accentGreenOf(context),
      };

  @override
  Widget build(BuildContext context) {
    final c = _color(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: c.withAlpha(32),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withAlpha(100), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.signal_cellular_alt_rounded, size: 14, color: c),
          const SizedBox(width: 6),
          Text(
            level.toUpperCase(),
            style: AppTheme.bodyStyle(
              fontSize: 11,
              color: c,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConceptChip extends StatelessWidget {
  const _ConceptChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.glassFillOf(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.glassBorderOf(context), width: 0.8),
      ),
      child: Text(
        label,
        style: AppTheme.bodyStyle(
          fontSize: 12,
          color: AppTheme.textPrimaryOf(context),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _PrimaryCta extends StatelessWidget {
  const _PrimaryCta({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withAlpha(120), width: 1.2),
          gradient: LinearGradient(
            colors: [color.withAlpha(48), color.withAlpha(16)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color.withAlpha(60),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: AppTheme.bodyStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimaryOf(context),
                      )),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: AppTheme.bodyStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondaryOf(context),
                      )),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_rounded, color: color, size: 22),
          ],
        ),
      ),
    );
  }
}

// ─── Gemma thinking orb (offline AI indicator) ──────────────────────────────

class _GemmaThinkingOrb extends StatefulWidget {
  const _GemmaThinkingOrb();

  @override
  State<_GemmaThinkingOrb> createState() => _GemmaThinkingOrbState();
}

class _GemmaThinkingOrbState extends State<_GemmaThinkingOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 3))
        ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cyan = AppTheme.accentCyanOf(context);
    final purple = AppTheme.accentPurpleOf(context);
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final t = _c.value;
        return SizedBox(
          width: 120,
          height: 120,
          child: Stack(
            alignment: Alignment.center,
            children: [
              for (int i = 0; i < 3; i++)
                Transform.scale(
                  scale: 0.6 + ((t + i / 3) % 1.0) * 0.7,
                  child: Opacity(
                    opacity: 1.0 - ((t + i / 3) % 1.0),
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: (i.isEven ? cyan : purple).withAlpha(180),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
              Transform.rotate(
                angle: t * 2 * math.pi,
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppTheme.primaryGradientOf(context),
                    boxShadow: AppTheme.neonGlow(cyan, blur: 28),
                  ),
                  child: const Icon(Icons.auto_awesome_rounded,
                      color: Colors.white, size: 26),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
