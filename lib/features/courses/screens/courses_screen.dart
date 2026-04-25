import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/services/dynamic_catalog_service.dart';
import '../../../core/services/local_memory_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../core/widgets/particle_background.dart';

/// Thin dynamic catalogue screen. Shows Gemma-suggested subjects at the top,
/// then the user's own studied topics. Replaces the previous placeholder
/// catalogue that shipped with hardcoded category metadata.
class CoursesScreen extends StatefulWidget {
  const CoursesScreen({super.key});

  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen> {
  bool _subjectsLoading = true;
  List<Map<String, dynamic>> _subjects = const [];
  List<Map<String, dynamic>> _topics = const [];

  static const _subjectColors = [
    AppTheme.accentCyan,
    AppTheme.accentPurple,
    AppTheme.accentGreen,
    AppTheme.accentGold,
    AppTheme.accentMagenta,
    AppTheme.accentOrange,
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool force = false}) async {
    setState(() => _subjectsLoading = true);
    try {
      final subjects = await DynamicCatalogService.instance
          .suggestedSubjects(force: force);
      final topics = await LocalMemoryService.instance.getAllTopicProgress();
      if (!mounted) return;
      setState(() {
        _subjects = subjects;
        _topics = topics;
        _subjectsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _subjects = const [];
        _subjectsLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('EXPLORE SUBJECTS'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Re-generate suggestions',
            onPressed: _subjectsLoading ? null : () => _load(force: true),
          ),
        ],
      ),
      body: Stack(
        children: [
          Container(decoration: AppTheme.scaffoldDecorationOf(context)),
          const ParticleBackground(
            particleCount: 30,
            particleColor: AppTheme.accentPurple,
            maxRadius: 1.0,
          ),
          SafeArea(
            child: RefreshIndicator(
              onRefresh: () => _load(force: true),
              color: AppTheme.accentCyan,
              backgroundColor: AppTheme.surfaceDark,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                children: [
                  _buildHero(context),
                  const SizedBox(height: 22),
                  _sectionLabel(context, 'SUGGESTED FOR YOU'),
                  const SizedBox(height: 10),
                  if (_subjectsLoading)
                    _buildSkeleton(context)
                  else if (_subjects.isEmpty)
                    _buildEmptySubjects(context)
                  else
                    ..._buildSubjectList(context),
                  const SizedBox(height: 22),
                  _sectionLabel(context, 'YOUR TOPICS'),
                  const SizedBox(height: 10),
                  if (_topics.isEmpty)
                    _buildEmptyTopics(context)
                  else
                    ..._buildTopicList(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero(BuildContext context) {
    return GlassContainer(
      borderColor: AppTheme.accentCyanOf(context).withAlpha(50),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: const LinearGradient(
                colors: [AppTheme.accentCyan, AppTheme.accentPurple],
              ),
            ),
            child: const Icon(Icons.auto_awesome_rounded,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI-CURATED CATALOGUE',
                  style: AppTheme.headerStyle(
                    fontSize: 11,
                    letterSpacing: 2.2,
                    color: AppTheme.accentCyanOf(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Gemma picks subjects from your profile, grade, and topic history — all on-device.',
                  style: AppTheme.bodyStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondaryOf(context),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String label) => Text(
        label,
        style: AppTheme.headerStyle(
          fontSize: 10,
          letterSpacing: 2.4,
          color: AppTheme.textTertiaryOf(context),
        ),
      );

  Widget _buildSkeleton(BuildContext context) {
    return Column(
      children: List.generate(
        4,
        (i) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            height: 72,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: AppTheme.surfaceLightOf(context).withAlpha(40),
              border: Border.all(color: Colors.white.withAlpha(14)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptySubjects(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(18),
      borderColor: AppTheme.accentCyanOf(context).withAlpha(40),
      child: Row(
        children: [
          Icon(Icons.psychology_rounded,
              color: AppTheme.accentCyanOf(context).withAlpha(140),
              size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Tap refresh — Gemma will suggest subjects tailored to your profile.',
              style: AppTheme.bodyStyle(
                fontSize: 12,
                color: AppTheme.textSecondaryOf(context),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSubjectList(BuildContext context) {
    return [
      for (int i = 0; i < _subjects.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _SubjectCard(
            data: _subjects[i],
            color: _subjectColors[i % _subjectColors.length],
            onTap: () {
              final name = (_subjects[i]['name'] as String?)?.trim() ?? '';
              if (name.isEmpty) return;
              context.push('/topic-explorer', extra: {'topic': name});
            },
          )
              .animate(delay: (40 * i).ms)
              .fadeIn(duration: 220.ms)
              .slideY(begin: 0.06, end: 0, curve: Curves.easeOutCubic),
        ),
    ];
  }

  Widget _buildEmptyTopics(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(18),
      borderColor: AppTheme.accentPurpleOf(context).withAlpha(40),
      child: Row(
        children: [
          Icon(Icons.school_rounded,
              color: AppTheme.accentPurpleOf(context).withAlpha(140),
              size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Studied topics will appear here after your first Story lesson.',
              style: AppTheme.bodyStyle(
                fontSize: 12,
                color: AppTheme.textSecondaryOf(context),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildTopicList(BuildContext context) {
    return [
      for (int i = 0; i < _topics.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _TopicTile(data: _topics[i]).animate(delay: (40 * i).ms).fadeIn(
                duration: 220.ms,
              ),
        ),
    ];
  }
}

class _SubjectCard extends StatelessWidget {
  const _SubjectCard({
    required this.data,
    required this.color,
    required this.onTap,
  });

  final Map<String, dynamic> data;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = (data['name'] as String?)?.trim() ?? 'Subject';
    final emoji = (data['emoji'] as String?)?.trim();
    final reason = (data['reason'] as String?)?.trim() ?? '';

    return GlassContainer(
      onTap: onTap,
      borderColor: color.withAlpha(70),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: color.withAlpha(30),
              border: Border.all(color: color.withAlpha(110), width: 1),
            ),
            child: emoji != null && emoji.isNotEmpty
                ? Text(emoji, style: const TextStyle(fontSize: 22))
                : Icon(Icons.school_rounded, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.orbitron(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color,
                    letterSpacing: 0.6,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (reason.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    reason,
                    style: AppTheme.bodyStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondaryOf(context),
                      height: 1.35,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
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

class _TopicTile extends StatelessWidget {
  const _TopicTile({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final name = data['name'] as String? ?? 'Topic';
    final level = data['level'] as String? ?? 'basics';
    final accuracy = (data['accuracy'] as num?)?.toInt() ?? 0;
    final stars = (data['stars'] as num?)?.toInt() ?? 0;

    final color = switch (level) {
      'intermediate' => AppTheme.accentCyanOf(context),
      'advanced' => AppTheme.accentMagentaOf(context),
      _ => AppTheme.accentGreenOf(context),
    };

    return GlassContainer(
      onTap: () => context.push('/lesson', extra: {
        'customTopic': name,
        'level': level,
      }),
      borderColor: color.withAlpha(50),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withAlpha(30),
              border: Border.all(color: color.withAlpha(100)),
            ),
            child: Icon(Icons.bolt_rounded, color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppTheme.bodyStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimaryOf(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${level.toUpperCase()} • $accuracy% • ${'★' * stars}${'☆' * (3 - stars)}',
                  style: AppTheme.bodyStyle(
                    fontSize: 10,
                    color: AppTheme.textTertiaryOf(context),
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios_rounded,
              size: 12, color: color.withAlpha(180)),
        ],
      ),
    );
  }
}
