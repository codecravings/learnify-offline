import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/services/dynamic_catalog_service.dart';
import '../../../core/services/local_memory_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../core/widgets/particle_background.dart';

/// Concept map built from the learner's own studied topics. Nodes = topics the
/// user has studied; edges = prerequisite relationships inferred on-device by
/// Gemma through DynamicCatalogService. Replaces the old static prerequisite
/// graph which only covered Physics + Math.
class ConceptMapScreen extends StatefulWidget {
  const ConceptMapScreen({super.key, this.focusConcept});

  final String? focusConcept;

  @override
  State<ConceptMapScreen> createState() => _ConceptMapScreenState();
}

class _ConceptMapScreenState extends State<ConceptMapScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _topics = const [];
  List<Map<String, dynamic>> _edges = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool force = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final topics = await LocalMemoryService.instance.getAllTopicProgress();
      final topicNames = topics
          .map((t) => (t['name'] as String?)?.trim() ?? '')
          .where((n) => n.isNotEmpty)
          .toList();

      List<Map<String, dynamic>> edges = const [];
      if (topicNames.length >= 2) {
        edges = await DynamicCatalogService.instance
            .prerequisiteEdges(topicNames, force: force);
      }

      if (!mounted) return;
      setState(() {
        _topics = topics;
        _edges = edges;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('CONCEPT MAP'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Re-infer edges with Gemma',
            onPressed: _loading ? null : () => _load(force: true),
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
          SafeArea(child: _buildBody(context)),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 44,
              height: 44,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                valueColor: AlwaysStoppedAnimation(AppTheme.accentPurpleOf(context)),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'INFERRING EDGES',
              style: AppTheme.headerStyle(
                fontSize: 11,
                letterSpacing: 2.2,
                color: AppTheme.accentPurpleOf(context),
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Failed to build map:\n$_error',
            textAlign: TextAlign.center,
            style: AppTheme.bodyStyle(
              color: AppTheme.accentMagentaOf(context),
            ),
          ),
        ),
      );
    }

    if (_topics.isEmpty) {
      return _buildEmptyState(context);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        Text(
          'YOUR KNOWLEDGE GRAPH',
          style: AppTheme.headerStyle(
            fontSize: 11,
            letterSpacing: 2.4,
            color: AppTheme.accentCyanOf(context),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${_topics.length} nodes • ${_edges.length} inferred links',
          style: AppTheme.bodyStyle(
            fontSize: 12,
            color: AppTheme.textSecondaryOf(context),
          ),
        ),
        const SizedBox(height: 18),
        _buildLegend(context),
        const SizedBox(height: 14),
        _sectionLabel(context, 'NODES'),
        for (int i = 0; i < _topics.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _buildNode(_topics[i]).animate(delay: (40 * i).ms).fadeIn(
                  duration: 220.ms,
                ),
          ),
        const SizedBox(height: 12),
        if (_edges.isNotEmpty) ...[
          _sectionLabel(context, 'PREREQUISITE LINKS'),
          for (int i = 0; i < _edges.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildEdge(_edges[i]).animate(delay: (40 * i).ms).fadeIn(
                    duration: 220.ms,
                  ),
            ),
        ] else if (_topics.length < 2) ...[
          _sectionLabel(context, 'LINKS'),
          Text(
            'Study at least 2 topics to let Gemma infer prerequisite links between them.',
            style: AppTheme.bodyStyle(
              fontSize: 13,
              color: AppTheme.textTertiaryOf(context),
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.account_tree_rounded,
              size: 56,
              color: AppTheme.accentPurpleOf(context).withAlpha(160),
            ),
            const SizedBox(height: 14),
            Text(
              'Your concept map is empty',
              style: AppTheme.headerStyle(fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              'Complete your first Story lesson and the topic will appear here. Once you have two or more topics, Gemma will infer prerequisite links between them.',
              textAlign: TextAlign.center,
              style: AppTheme.bodyStyle(
                fontSize: 13,
                color: AppTheme.textSecondaryOf(context),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => context.go('/home'),
              icon: const Icon(Icons.home_rounded),
              label: const Text('Back to home'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend(BuildContext context) {
    return GlassContainer(
      borderColor: AppTheme.accentCyanOf(context).withAlpha(50),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          _legendDot(AppTheme.accentGreenOf(context), 'Mastered'),
          const SizedBox(width: 12),
          _legendDot(AppTheme.accentGoldOf(context), 'In progress'),
          const SizedBox(width: 12),
          _legendDot(AppTheme.accentPurpleOf(context), 'Started'),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 11,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      );

  Widget _sectionLabel(BuildContext context, String label) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 6),
        child: Text(
          label,
          style: AppTheme.headerStyle(
            fontSize: 10,
            letterSpacing: 2.2,
            color: AppTheme.textTertiaryOf(context),
          ),
        ),
      );

  Widget _buildNode(Map<String, dynamic> topic) {
    final name = topic['name'] as String? ?? 'Topic';
    final accuracy = (topic['accuracy'] as num?)?.toInt() ?? 0;
    final stars = (topic['stars'] as num?)?.toInt() ?? 0;
    final level = topic['level'] as String? ?? 'basics';

    final status = accuracy >= 80 && stars >= 2
        ? ('Mastered', AppTheme.accentGreenOf(context))
        : accuracy >= 50
            ? ('In progress', AppTheme.accentGoldOf(context))
            : ('Started', AppTheme.accentPurpleOf(context));

    return GlassContainer(
      onTap: () => context.push('/lesson', extra: {
        'customTopic': name,
        'level': level,
      }),
      borderColor: status.$2.withAlpha(60),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: status.$2.withAlpha(30),
              border: Border.all(color: status.$2.withAlpha(110)),
            ),
            child: Icon(
              Icons.bolt_rounded,
              color: status.$2,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppTheme.bodyStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimaryOf(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${status.$1} • $accuracy% • ${'★' * stars}${'☆' * (3 - stars)}',
                  style: AppTheme.bodyStyle(
                    fontSize: 11,
                    color: AppTheme.textTertiaryOf(context),
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios_rounded,
              size: 12, color: status.$2.withAlpha(180)),
        ],
      ),
    );
  }

  Widget _buildEdge(Map<String, dynamic> edge) {
    final from = edge['from'] as String? ?? '';
    final to = edge['to'] as String? ?? '';
    final reason = edge['reason'] as String? ?? '';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: AppTheme.surfaceLightOf(context).withAlpha(40),
        border: Border.all(
          color: AppTheme.accentPurpleOf(context).withAlpha(40),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  from,
                  style: AppTheme.bodyStyle(
                    fontSize: 12,
                    color: AppTheme.accentCyanOf(context),
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(Icons.arrow_forward_rounded,
                  size: 14,
                  color: AppTheme.textTertiaryOf(context)),
              Flexible(
                child: Text(
                  to,
                  style: AppTheme.bodyStyle(
                    fontSize: 12,
                    color: AppTheme.accentPurpleOf(context),
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (reason.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              reason,
              style: AppTheme.bodyStyle(
                fontSize: 11,
                color: AppTheme.textSecondaryOf(context),
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
