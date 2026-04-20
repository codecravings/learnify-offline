import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ai/gemma_orchestrator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_container.dart';

/// Breaks any topic into 6–8 sub-topics using the local Gemma Explorer Agent.
class TopicExplorerScreen extends StatefulWidget {
  const TopicExplorerScreen({super.key, required this.topic});

  final String topic;

  @override
  State<TopicExplorerScreen> createState() => _TopicExplorerScreenState();
}

class _TopicExplorerScreenState extends State<TopicExplorerScreen> {
  final _orchestrator = GemmaOrchestrator.instance;

  List<Map<String, dynamic>> _subtopics = const [];
  bool _loading = true;
  String? _error;
  final Set<int> _completed = {};

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await _orchestrator.exploreTopic(widget.topic);
      if (!mounted) return;
      setState(() {
        _subtopics = results;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not break down this topic.\n\n$e';
        _loading = false;
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
          child: _loading
              ? _buildLoading(context)
              : _error != null
                  ? _buildError(context)
                  : _buildList(context),
        ),
      ),
    );
  }

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
            'Gemma is on-device • 100% offline',
            style: AppTheme.bodyStyle(
              fontSize: 12,
              color: AppTheme.textSecondaryOf(context),
            ),
          ),
        ],
      ),
    );
  }

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
            Text('Explorer failed',
                style: AppTheme.headerStyle(fontSize: 20)),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: AppTheme.bodyStyle(
                fontSize: 13,
                color: AppTheme.textSecondaryOf(context),
              ),
            ),
            const SizedBox(height: 20),
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

  Widget _buildList(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Text(
          'EXPLORING',
          style: AppTheme.headerStyle(
            fontSize: 11,
            letterSpacing: 2.4,
            color: AppTheme.accentCyanOf(context),
          ),
        ),
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
