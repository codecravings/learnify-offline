import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ai/gemma_orchestrator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_container.dart';

/// Topic Explorer:
///   1. DIFFICULTY — pick how many sub-topics (normal=5, exam-ready=8, deep=12)
///   2. LOADING    — Explorer agent breaks the topic down
///   3. LIST       — tap a sub-topic to launch Story (style is asked there)
///   4. ERROR      — retry path when the model returns unusable JSON
class TopicExplorerScreen extends StatefulWidget {
  const TopicExplorerScreen({super.key, required this.topic});

  final String topic;

  @override
  State<TopicExplorerScreen> createState() => _TopicExplorerScreenState();
}

enum _Phase { difficulty, loading, list, error }

class _TopicExplorerScreenState extends State<TopicExplorerScreen> {
  final _orchestrator = GemmaOrchestrator.instance;

  _Phase _phase = _Phase.difficulty;
  int _count = 5;
  String _depth = 'normal'; // 'normal' | 'exam' | 'deep'

  List<Map<String, dynamic>> _subtopics = const [];
  String? _error;
  final Set<int> _completed = {};

  void _pickDifficulty(int count, String depth) {
    setState(() {
      _count = count;
      _depth = depth;
    });
    _generate();
  }

  Future<void> _generate() async {
    setState(() {
      _phase = _Phase.loading;
      _error = null;
    });
    try {
      final results = await _orchestrator.exploreTopic(
        widget.topic,
        count: _count,
        depth: _depth,
      );
      if (!mounted) return;
      setState(() {
        _subtopics = results;
        _phase = _Phase.list;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _phase = _Phase.error;
      });
    }
  }

  void _startSubtopic(Map<String, dynamic> sub) {
    final title = sub['title'] as String? ?? widget.topic;
    final difficulty = (sub['difficulty'] as String?) ?? 'beginner';
    final level = switch (difficulty.toLowerCase()) {
      'intermediate' => 'intermediate',
      'advanced' || 'pro' => 'advanced',
      _ => 'basics',
    };
    context.push('/lesson', extra: {
      'customTopic': '${widget.topic}: $title',
      'level': level,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('TOPIC EXPLORER'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: Container(
        decoration: AppTheme.scaffoldDecorationOf(context),
        child: SafeArea(
          child: switch (_phase) {
            _Phase.difficulty => _buildDifficulty(context),
            _Phase.loading => _buildLoading(context),
            _Phase.error => _buildError(context),
            _Phase.list => _buildList(context),
          },
        ),
      ),
    );
  }

  // ── Phase 1: Difficulty ────────────────────────────────────────────────────

  Widget _buildDifficulty(BuildContext context) {
    final options = [
      (label: 'NORMAL', count: 5, depth: 'normal', blurb: 'A quick overview — 5 sub-topics, mostly beginner + intermediate.', color: AppTheme.accentGreenOf(context), icon: Icons.school_rounded),
      (label: 'EXAM-READY', count: 8, depth: 'exam', blurb: '8 sub-topics in exam phrasing. Covers common question areas.', color: AppTheme.accentGoldOf(context), icon: Icons.fact_check_rounded),
      (label: 'DEEP', count: 12, depth: 'deep', blurb: '12 sub-topics pushing into advanced territory + edge cases.', color: AppTheme.accentMagentaOf(context), icon: Icons.psychology_rounded),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        _eyebrow(context, 'EXPLORE'),
        const SizedBox(height: 6),
        Text(
          widget.topic,
          style: AppTheme.headerStyle(
            fontSize: 26,
            color: AppTheme.textPrimaryOf(context),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'How deep do you want to go?',
          style: AppTheme.bodyStyle(
            fontSize: 14,
            color: AppTheme.textSecondaryOf(context),
          ),
        ),
        const SizedBox(height: 22),
        for (int i = 0; i < options.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _ChoiceCard(
              label: options[i].label,
              title: '${options[i].count} sub-topics',
              blurb: options[i].blurb,
              icon: options[i].icon,
              color: options[i].color,
              onTap: () => _pickDifficulty(options[i].count, options[i].depth),
            ).animate(delay: (60 * i).ms).fadeIn(duration: 220.ms).slideY(
                  begin: 0.08,
                  end: 0,
                  curve: Curves.easeOutCubic,
                ),
          ),
      ],
    );
  }

  // ── Phase 2: Loading ───────────────────────────────────────────────────────

  Widget _buildLoading(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor:
                  AlwaysStoppedAnimation(AppTheme.accentCyanOf(context)),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'BREAKING DOWN',
            style: AppTheme.headerStyle(
              fontSize: 11,
              letterSpacing: 2.4,
              color: AppTheme.accentCyanOf(context),
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              widget.topic,
              style: AppTheme.headerStyle(
                fontSize: 20,
                color: AppTheme.textPrimaryOf(context),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$_count sub-topics • Gemma on-device • 100% offline',
            style: AppTheme.bodyStyle(
              fontSize: 12,
              color: AppTheme.textSecondaryOf(context),
            ),
          ),
        ],
      ),
    );
  }

  // ── Phase 4: Error ─────────────────────────────────────────────────────────

  Widget _buildError(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded,
                size: 48, color: AppTheme.accentMagentaOf(context)),
            const SizedBox(height: 12),
            Text('Gemma returned an unexpected format.',
                textAlign: TextAlign.center,
                style: AppTheme.headerStyle(fontSize: 18)),
            const SizedBox(height: 8),
            Text(
              'Tap Try again — the model sometimes needs a second attempt.',
              textAlign: TextAlign.center,
              style: AppTheme.bodyStyle(
                fontSize: 13,
                color: AppTheme.textSecondaryOf(context),
              ),
            ),
            const SizedBox(height: 16),
            if (_error != null)
              ExpansionTile(
                title: Text(
                  'Show details',
                  style: AppTheme.bodyStyle(
                    fontSize: 12,
                    color: AppTheme.textTertiaryOf(context),
                  ),
                ),
                iconColor: AppTheme.textTertiaryOf(context),
                collapsedIconColor: AppTheme.textTertiaryOf(context),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      _error!,
                      style: AppTheme.bodyStyle(
                        fontSize: 11,
                        color: AppTheme.textTertiaryOf(context),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _generate,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Phase 5: List ──────────────────────────────────────────────────────────

  Widget _buildList(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        _eyebrow(context, 'EXPLORING'),
        const SizedBox(height: 6),
        Text(
          widget.topic,
          style: AppTheme.headerStyle(
            fontSize: 28,
            color: AppTheme.textPrimaryOf(context),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${_subtopics.length} sub-topics • tap any card to begin',
          style: AppTheme.bodyStyle(
            fontSize: 12,
            color: AppTheme.textSecondaryOf(context),
          ),
        ),
        const SizedBox(height: 20),
        for (int i = 0; i < _subtopics.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _SubtopicCard(
              index: i,
              data: _subtopics[i],
              completed: _completed.contains(i),
              onStart: () => _startSubtopic(_subtopics[i]),
              onToggleDone: () => setState(() {
                if (_completed.contains(i)) {
                  _completed.remove(i);
                } else {
                  _completed.add(i);
                }
              }),
            ).animate(delay: (60 * i).ms).fadeIn(duration: 220.ms).slideY(
                  begin: 0.08,
                  end: 0,
                  curve: Curves.easeOutCubic,
                ),
          ),
      ],
    );
  }

  Widget _eyebrow(BuildContext context, String label) => Text(
        label,
        style: AppTheme.headerStyle(
          fontSize: 11,
          letterSpacing: 2.4,
          color: AppTheme.accentCyanOf(context),
        ),
      );
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.label,
    required this.title,
    required this.blurb,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final String title;
  final String blurb;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      onTap: onTap,
      borderColor: color.withAlpha(70),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: color.withAlpha(28),
              border: Border.all(color: color.withAlpha(90), width: 1),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTheme.headerStyle(
                    fontSize: 12,
                    letterSpacing: 1.8,
                    color: color,
                  ),
                ),
                if (title.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    title,
                    style: AppTheme.bodyStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimaryOf(context),
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  blurb,
                  style: AppTheme.bodyStyle(
                    fontSize: 12.5,
                    color: AppTheme.textSecondaryOf(context),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios_rounded,
              size: 14, color: color.withAlpha(200)),
        ],
      ),
    );
  }
}

class _SubtopicCard extends StatelessWidget {
  const _SubtopicCard({
    required this.index,
    required this.data,
    required this.completed,
    required this.onStart,
    required this.onToggleDone,
  });

  final int index;
  final Map<String, dynamic> data;
  final bool completed;
  final VoidCallback onStart;
  final VoidCallback onToggleDone;

  Color _diffColor(BuildContext context) {
    final d = (data['difficulty'] as String?)?.toLowerCase() ?? 'beginner';
    return switch (d) {
      'advanced' || 'pro' => AppTheme.accentMagentaOf(context),
      'intermediate' => AppTheme.accentGoldOf(context),
      _ => AppTheme.accentGreenOf(context),
    };
  }

  @override
  Widget build(BuildContext context) {
    final emoji = data['emoji'] as String? ?? '📘';
    final title = data['title'] as String? ?? 'Sub-topic';
    final description = data['description'] as String? ?? '';
    final difficulty =
        (data['difficulty'] as String?)?.toUpperCase() ?? 'BEGINNER';
    final diffColor = _diffColor(context);

    return GlassContainer(
      onTap: onStart,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: AppTheme.accentCyanOf(context).withAlpha(28),
              border: Border.all(
                color: AppTheme.accentCyanOf(context).withAlpha(70),
                width: 1,
              ),
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 24)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${index + 1}. ',
                      style: AppTheme.bodyStyle(
                        fontSize: 13,
                        color: AppTheme.textTertiaryOf(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        title,
                        style: AppTheme.bodyStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimaryOf(context),
                          letterSpacing: 0.2,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: AppTheme.bodyStyle(
                    fontSize: 12.5,
                    color: AppTheme.textSecondaryOf(context),
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: diffColor.withAlpha(32),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: diffColor.withAlpha(90),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        difficulty,
                        style: AppTheme.bodyStyle(
                          fontSize: 9.5,
                          color: diffColor,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: onToggleDone,
                      child: Icon(
                        completed
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        size: 20,
                        color: completed
                            ? AppTheme.accentGreenOf(context)
                            : AppTheme.textTertiaryOf(context),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
