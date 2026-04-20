import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/services/local_memory_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../core/widgets/particle_background.dart';
import '../data/prerequisite_graph.dart';
import '../widgets/concept_detail_sheet.dart';
import '../widgets/concept_node_painter.dart';

/// Interactive concept map visualization showing prerequisite relationships.
class ConceptMapScreen extends StatefulWidget {
  const ConceptMapScreen({super.key, this.focusConcept});

  final String? focusConcept;

  @override
  State<ConceptMapScreen> createState() => _ConceptMapScreenState();
}

class _ConceptMapScreenState extends State<ConceptMapScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  late final Animation<double> _animation;

  String _subjectFilter = 'all'; // 'all', 'physics', 'math'
  String? _focusedNodeId;
  Set<String> _highlightedPath = {};

  // Pan & zoom
  Offset _panOffset = Offset.zero;
  double _scale = 1.0;
  Offset? _lastFocalPoint;
  double _lastScale = 1.0;

  // Student accuracy data
  Map<String, double> _accuracyMap = {};

  // Computed layout
  List<NodeLayout> _nodes = [];

  @override
  void initState() {
    super.initState();
    _focusedNodeId = widget.focusConcept;
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _animation = CurvedAnimation(
      parent: _animCtrl,
      curve: Curves.easeOutCubic,
    );
    _loadAccuracyData();
    _animCtrl.forward();

    // If focus concept provided, highlight its prerequisite chain
    if (widget.focusConcept != null && widget.focusConcept!.isNotEmpty) {
      _highlightChain(widget.focusConcept!);
    }
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAccuracyData() async {
    try {
      final topics =
          await LocalMemoryService.instance.getAllTopicProgress();
      final map = <String, double>{};
      for (final t in topics) {
        final name = (t['name'] as String? ?? '').toLowerCase();
        final accuracy = (t['accuracy'] as num?)?.toDouble() ?? 0;
        if (name.isEmpty) continue;
        map[name] = accuracy;

        final concept = PrerequisiteGraph.findConceptForTopic(name);
        if (concept != null) {
          map[concept.id] = accuracy;
        }
      }
      if (mounted) setState(() => _accuracyMap = map);
    } catch (_) {}
  }

  void _highlightChain(String conceptId) {
    final chain = PrerequisiteGraph.getPrerequisiteChain(conceptId);
    setState(() {
      _highlightedPath = {
        conceptId,
        ...chain.map((c) => c.id),
      };
      _focusedNodeId = conceptId;
    });
  }

  void _clearHighlight() {
    setState(() {
      _highlightedPath = {};
      _focusedNodeId = null;
    });
  }

  void _resetView() {
    setState(() {
      _panOffset = Offset.zero;
      _scale = 1.0;
    });
  }

  void _zoomIn() {
    setState(() => _scale = (_scale * 1.25).clamp(0.4, 3.0));
  }

  void _zoomOut() {
    setState(() => _scale = (_scale / 1.25).clamp(0.4, 3.0));
  }

  Color _nodeColor(ConceptNode concept) {
    final acc = _accuracyMap[concept.id] ??
        _accuracyMap[concept.name.toLowerCase()] ??
        -1;
    if (acc < 0) return AppTheme.accentPurple; // not studied
    if (acc >= 80) return AppTheme.accentGreen; // mastered
    if (acc >= 50) return AppTheme.accentCyan; // learning
    return const Color(0xFFF97316); // weak
  }

  double _nodeAccuracy(ConceptNode concept) {
    return _accuracyMap[concept.id] ??
        _accuracyMap[concept.name.toLowerCase()] ??
        -1;
  }

  List<NodeLayout> _buildLayout(Size size) {
    final concepts = _subjectFilter == 'all'
        ? PrerequisiteGraph.concepts
        : PrerequisiteGraph.getBySubject(_subjectFilter);

    if (concepts.isEmpty) return [];

    // Layered layout: group by depth in the prerequisite graph
    final depths = <String, int>{};
    for (final c in concepts) {
      depths[c.id] = _computeDepth(c.id, {});
    }
    final maxDepth = depths.values.fold(0, math.max);

    // Group by depth
    final layers = <int, List<ConceptNode>>{};
    for (final c in concepts) {
      final d = depths[c.id] ?? 0;
      layers.putIfAbsent(d, () => []).add(c);
    }

    final nodes = <NodeLayout>[];
    final halfW = size.width / 2 - 50;
    final halfH = size.height / 2 - 70;
    final layerSpacing = maxDepth > 0
        ? (halfH * 2) / (maxDepth + 1)
        : 90.0;

    for (int depth = 0; depth <= maxDepth; depth++) {
      final layerConcepts = layers[depth] ?? [];
      final count = layerConcepts.length;
      final rowWidth = count > 1 ? halfW * 2 : 0.0;

      for (int i = 0; i < count; i++) {
        final c = layerConcepts[i];
        final x = count > 1
            ? -halfW + (rowWidth / (count - 1)) * i
            : 0.0;
        final y = -halfH + layerSpacing * depth;

        // Slight offset for dense layers to avoid overlap
        final jitter = (c.id.hashCode % 16 - 8).toDouble();

        nodes.add(NodeLayout(
          concept: c,
          position: Offset(x + jitter, y),
          radius: _focusedNodeId == c.id ? 28 : 22,
          color: _nodeColor(c),
        ));
      }
    }

    return nodes;
  }

  int _computeDepth(String conceptId, Set<String> visited) {
    if (visited.contains(conceptId)) return 0;
    visited.add(conceptId);
    final concept = PrerequisiteGraph.getById(conceptId);
    if (concept == null || concept.prerequisiteIds.isEmpty) return 0;

    int maxPrereqDepth = 0;
    for (final pid in concept.prerequisiteIds) {
      final d = _computeDepth(pid, visited);
      if (d > maxPrereqDepth) maxPrereqDepth = d;
    }
    return maxPrereqDepth + 1;
  }

  void _onTapUp(TapUpDetails details) {
    final center = Offset(
      MediaQuery.of(context).size.width / 2,
      MediaQuery.of(context).size.height / 2,
    );
    // Transform tap to graph coordinates
    final graphPoint = (details.localPosition - center - _panOffset) / _scale;

    for (final node in _nodes) {
      if (node.containsPoint(graphPoint)) {
        setState(() => _focusedNodeId = node.concept.id);
        _showDetailSheet(node.concept);
        return;
      }
    }
    // Tapped empty space — clear selection
    _clearHighlight();
  }

  void _showDetailSheet(ConceptNode concept) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ConceptDetailSheet(
        concept: concept,
        accuracy: _nodeAccuracy(concept),
        onHighlightPrereqs: () => _highlightChain(concept.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = AppTheme.isDark(context);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: dark
                ? [const Color(0xFF111827), const Color(0xFF060A18)]
                : [const Color(0xFFF5F7FF), const Color(0xFFEEF0FA)],
          ),
        ),
        child: Stack(
          children: [
            if (dark)
              const Positioned.fill(
                child: ParticleBackground(
                  particleCount: 35,
                  particleColor: AppTheme.accentCyan,
                  speed: 0.12,
                ),
              ),
            SafeArea(
              child: Column(
                children: [
                  _buildAppBar(),
                  _buildFilterTabs(),
                  _buildLegend(),
                  Expanded(
                    child: Stack(
                      children: [
                        _buildGraph(),
                        // Zoom controls
                        Positioned(
                          right: 12,
                          bottom: 12,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _zoomButton(Icons.add_rounded, _zoomIn),
                              const SizedBox(height: 6),
                              _zoomButton(Icons.remove_rounded, _zoomOut),
                              const SizedBox(height: 6),
                              _zoomButton(
                                  Icons.center_focus_strong_rounded, _resetView),
                            ],
                          ).animate().fadeIn(delay: 600.ms, duration: 400.ms),
                        ),
                        // Scale indicator
                        Positioned(
                          left: 12,
                          bottom: 12,
                          child: GlassContainer(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            child: Text(
                              '${(_scale * 100).round()}%',
                              style: GoogleFonts.orbitron(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textTertiaryOf(context),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildStats(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _zoomButton(IconData icon, VoidCallback onTap) {
    final dark = AppTheme.isDark(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: dark
              ? Colors.white.withAlpha(12)
              : Colors.black.withAlpha(8),
          border: Border.all(
            color: AppTheme.glassBorderOf(context),
            width: 0.5,
          ),
        ),
        child: Icon(
          icon,
          size: 18,
          color: AppTheme.textSecondaryOf(context),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    final dark = AppTheme.isDark(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: dark
                    ? Colors.white.withAlpha(12)
                    : Colors.black.withAlpha(8),
                border: Border.all(
                    color: AppTheme.glassBorderOf(context), width: 0.5),
              ),
              child: Icon(
                Icons.arrow_back_ios_new,
                color: AppTheme.textPrimaryOf(context),
                size: 16,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) =>
                      AppTheme.primaryGradientOf(context).createShader(bounds),
                  child: Text(
                    'Concept Map',
                    style: GoogleFonts.orbitron(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                Text(
                  'Tap a concept to explore',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 11,
                    color: AppTheme.textTertiaryOf(context),
                  ),
                ),
              ],
            ),
          ),
          if (_highlightedPath.isNotEmpty)
            GestureDetector(
              onTap: _clearHighlight,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.accentCyan.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.accentCyan.withAlpha(60),
                    width: 0.5,
                  ),
                ),
                child: Text(
                  'Clear',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 11,
                    color: dark
                        ? AppTheme.accentCyan
                        : AppTheme.accentPurple,
                  ),
                ),
              ),
            ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildFilterTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          _filterChip('All', 'all'),
          const SizedBox(width: 8),
          _filterChip('Physics', 'physics'),
          const SizedBox(width: 8),
          _filterChip('Math', 'math'),
          const SizedBox(width: 8),
          _filterChip('AI/ML', 'ai_ml'),
        ],
      ),
    ).animate().fadeIn(delay: 100.ms, duration: 400.ms);
  }

  Widget _filterChip(String label, String value) {
    final selected = _subjectFilter == value;
    final dark = AppTheme.isDark(context);
    final color = value == 'physics'
        ? AppTheme.accentPurple
        : value == 'math'
            ? AppTheme.accentCyan
            : value == 'ai_ml'
                ? const Color(0xFFFF6B6B)
                : AppTheme.textPrimaryOf(context);

    return GestureDetector(
      onTap: () {
        setState(() {
          _subjectFilter = value;
          _highlightedPath = {};
          _focusedNodeId = null;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? color.withAlpha(20)
              : (dark ? Colors.white.withAlpha(6) : Colors.black.withAlpha(5)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? color.withAlpha(100)
                : AppTheme.glassBorderOf(context),
            width: selected ? 1.2 : 0.5,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
            color: selected ? color : AppTheme.textTertiaryOf(context),
          ),
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          _legendDot(AppTheme.accentGreen, 'Mastered'),
          const SizedBox(width: 14),
          _legendDot(AppTheme.accentCyan, 'Learning'),
          const SizedBox(width: 14),
          _legendDot(const Color(0xFFF97316), 'Weak'),
          const SizedBox(width: 14),
          _legendDot(AppTheme.accentPurple, 'New'),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms, duration: 400.ms);
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: [
              BoxShadow(color: color.withAlpha(80), blurRadius: 6),
            ],
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 10,
            color: AppTheme.textTertiaryOf(context),
          ),
        ),
      ],
    );
  }

  Widget _buildGraph() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        _nodes = _buildLayout(size);

        return GestureDetector(
          onTapUp: _onTapUp,
          onScaleStart: (d) {
            _lastFocalPoint = d.focalPoint;
            _lastScale = _scale;
          },
          onScaleUpdate: (d) {
            setState(() {
              if (_lastFocalPoint != null) {
                _panOffset += d.focalPoint - _lastFocalPoint!;
              }
              _scale = (_lastScale * d.scale).clamp(0.4, 3.0);
              _lastFocalPoint = d.focalPoint;
            });
          },
          onScaleEnd: (_) => _lastFocalPoint = null,
          child: AnimatedBuilder(
            animation: _animation,
            builder: (context, _) {
              return CustomPaint(
                size: size,
                painter: ConceptGraphPainter(
                  nodes: _nodes,
                  animationProgress: _animation.value,
                  focusedNodeId: _focusedNodeId,
                  highlightedPath: _highlightedPath,
                  panOffset: _panOffset,
                  scale: _scale,
                  isDark: AppTheme.isDark(context),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildStats() {
    final dark = AppTheme.isDark(context);
    final concepts = _subjectFilter == 'all'
        ? PrerequisiteGraph.concepts
        : PrerequisiteGraph.getBySubject(_subjectFilter);

    int mastered = 0, learning = 0, weak = 0, notStarted = 0;
    for (final c in concepts) {
      final acc = _nodeAccuracy(c);
      if (acc < 0) {
        notStarted++;
      } else if (acc >= 80) {
        mastered++;
      } else if (acc >= 50) {
        learning++;
      } else {
        weak++;
      }
    }

    final total = concepts.length;
    final studied = mastered + learning + weak;
    final pct = total > 0 ? (studied / total * 100).round() : 0;

    return GlassContainer(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _statItem('$mastered', 'Mastered', AppTheme.accentGreen),
              _statItem('$learning', 'Learning', AppTheme.accentCyan),
              _statItem('$weak', 'Weak', const Color(0xFFF97316)),
              _statItem('$notStarted', 'New', AppTheme.accentPurple),
            ],
          ),
          const SizedBox(height: 8),
          // Overall coverage bar
          Row(
            children: [
              Text(
                'Coverage',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 10,
                  color: AppTheme.textTertiaryOf(context),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: total > 0 ? studied / total : 0,
                    backgroundColor: dark
                        ? Colors.white.withAlpha(10)
                        : Colors.black.withAlpha(10),
                    color: AppTheme.accentCyan,
                    minHeight: 4,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$pct%',
                style: GoogleFonts.orbitron(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.accentCyanOf(context),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: 400.ms, duration: 400.ms).slideY(begin: 0.1);
  }

  Widget _statItem(String value, String label, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: GoogleFonts.orbitron(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 9,
            color: AppTheme.textTertiaryOf(context),
          ),
        ),
      ],
    );
  }
}
