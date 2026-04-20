import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/local_memory_service.dart';
import '../../../core/services/local_profile_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_container.dart';

/// Shows every topic the student has studied — pulled from the local SQLite DB.
class YourTopicsScreen extends StatefulWidget {
  const YourTopicsScreen({super.key});

  @override
  State<YourTopicsScreen> createState() => _YourTopicsScreenState();
}

class _YourTopicsScreenState extends State<YourTopicsScreen> {
  final _memory = LocalMemoryService.instance;
  final _profile = LocalProfileService.instance;

  List<Map<String, dynamic>> _topics = const [];
  bool _loading = true;
  _Filter _filter = _Filter.all;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final topics = await _memory.getAllTopicProgress();
    if (!mounted) return;
    setState(() {
      _topics = topics;
      _loading = false;
    });
  }

  List<Map<String, dynamic>> get _filtered {
    switch (_filter) {
      case _Filter.all:
        return _topics;
      case _Filter.needsReview:
        return _topics.where((t) {
          final acc = t['accuracy'] as int? ?? 0;
          return acc < 70;
        }).toList();
      case _Filter.mastered:
        return _topics.where((t) {
          final stars = t['stars'] as int? ?? 0;
          final acc = t['accuracy'] as int? ?? 0;
          return stars >= 3 || acc >= 90;
        }).toList();
    }
  }

  void _continueTopic(Map<String, dynamic> topic) {
    final name = topic['name'] as String;
    final level = (topic['level'] as String?) ?? 'basics';
    final nextLevel = switch (level.toLowerCase()) {
      'basics' => 'intermediate',
      'intermediate' => 'advanced',
      _ => 'advanced',
    };
    context.push('/lesson', extra: {
      'customTopic': name,
      'level': nextLevel,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('YOUR TOPICS'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
          ),
        ],
      ),
      body: Container(
        decoration: AppTheme.scaffoldDecorationOf(context),
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _buildBody(context),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final name = _profile.currentProfile?.name ?? 'Learner';
    final items = _filtered;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$name\'s library',
                style: AppTheme.headerStyle(
                  fontSize: 22,
                  color: AppTheme.textPrimaryOf(context),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${_topics.length} topic${_topics.length == 1 ? '' : 's'} studied',
                style: AppTheme.bodyStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondaryOf(context),
                ),
              ),
            ],
          ),
        ),
        _buildFilterBar(context),
        const SizedBox(height: 8),
        Expanded(
          child: items.isEmpty
              ? _buildEmpty(context)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                    itemCount: items.length,
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _TopicTile(
                        topic: items[i],
                        onContinue: () => _continueTopic(items[i]),
                      )
                          .animate(delay: (40 * i).ms)
                          .fadeIn(duration: 200.ms)
                          .slideY(begin: 0.06, end: 0),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildFilterBar(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          for (final f in _Filter.values) ...[
            _FilterChip(
              label: f.label,
              selected: _filter == f,
              onTap: () => setState(() => _filter = f),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    final headline = switch (_filter) {
      _Filter.all => 'No topics yet',
      _Filter.needsReview => 'Nothing needs review',
      _Filter.mastered => 'No mastered topics yet',
    };
    final sub = switch (_filter) {
      _Filter.all =>
        'Start any lesson from home and your progress shows up here.',
      _Filter.needsReview =>
        'Everything you\'ve studied is holding steady — keep it up.',
      _Filter.mastered =>
        'Reach 90%+ accuracy or 3 stars on a topic to unlock this badge.',
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_rounded,
                size: 48, color: AppTheme.textTertiaryOf(context)),
            const SizedBox(height: 12),
            Text(headline, style: AppTheme.headerStyle(fontSize: 18)),
            const SizedBox(height: 6),
            Text(
              sub,
              textAlign: TextAlign.center,
              style: AppTheme.bodyStyle(
                fontSize: 13,
                color: AppTheme.textSecondaryOf(context),
              ),
            ),
            if (_filter == _Filter.all) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => context.go('/home'),
                icon: const Icon(Icons.auto_stories_rounded),
                label: const Text('Start a lesson'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

enum _Filter { all, needsReview, mastered }

extension on _Filter {
  String get label => switch (this) {
        _Filter.all => 'All',
        _Filter.needsReview => 'Needs review',
        _Filter.mastered => 'Mastered',
      };
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cyan = AppTheme.accentCyanOf(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: selected ? cyan.withAlpha(42) : AppTheme.glassFillOf(context),
          border: Border.all(
            color: selected ? cyan : AppTheme.glassBorderOf(context),
            width: selected ? 1.2 : 0.8,
          ),
        ),
        child: Text(
          label,
          style: AppTheme.bodyStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color:
                selected ? cyan : AppTheme.textSecondaryOf(context),
          ),
        ),
      ),
    );
  }
}

class _TopicTile extends StatelessWidget {
  const _TopicTile({required this.topic, required this.onContinue});
  final Map<String, dynamic> topic;
  final VoidCallback onContinue;

  Color _levelColor(BuildContext context, String level) =>
      switch (level.toLowerCase()) {
        'advanced' => AppTheme.accentMagentaOf(context),
        'intermediate' => AppTheme.accentGoldOf(context),
        _ => AppTheme.accentGreenOf(context),
      };

  @override
  Widget build(BuildContext context) {
    final name = topic['name'] as String? ?? 'Topic';
    final level = (topic['level'] as String?) ?? 'basics';
    final accuracy = topic['accuracy'] as int? ?? 0;
    final stars = topic['stars'] as int? ?? 0;
    final levelColor = _levelColor(context, level);

    return GlassContainer(
      onTap: onContinue,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: AppTheme.accentCyanOf(context).withAlpha(28),
              border: Border.all(
                color: AppTheme.accentCyanOf(context).withAlpha(80),
                width: 1,
              ),
            ),
            child: Icon(Icons.auto_stories_rounded,
                color: AppTheme.accentCyanOf(context), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppTheme.bodyStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimaryOf(context),
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: levelColor.withAlpha(32),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                            color: levelColor.withAlpha(90), width: 0.7),
                      ),
                      child: Text(
                        level.toUpperCase(),
                        style: AppTheme.bodyStyle(
                          fontSize: 9,
                          color: levelColor,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      children: [
                        for (int i = 0; i < 3; i++)
                          Icon(
                            i < stars
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            size: 14,
                            color: i < stars
                                ? AppTheme.accentGoldOf(context)
                                : AppTheme.textTertiaryOf(context),
                          ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      '$accuracy%',
                      style: AppTheme.bodyStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: accuracy >= 80
                            ? AppTheme.accentGreenOf(context)
                            : accuracy >= 60
                                ? AppTheme.accentGoldOf(context)
                                : AppTheme.accentMagentaOf(context),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.arrow_forward_ios_rounded,
              size: 13, color: AppTheme.textTertiaryOf(context)),
        ],
      ),
    );
  }
}
