import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/services/local_memory_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../core/widgets/particle_background.dart';
import '../../courses/data/course_data.dart';
import '../models/skill_node_state.dart';
import '../widgets/skill_detail_sheet.dart';
import '../widgets/skill_tree_painter.dart';

/// Interactive skill tree visualization showing topic mastery.
class SkillTreeScreen extends StatefulWidget {
  const SkillTreeScreen({super.key});

  @override
  State<SkillTreeScreen> createState() => _SkillTreeScreenState();
}

class _SkillTreeScreenState extends State<SkillTreeScreen> {
  List<SkillNodeState> _nodes = [];
  String _selectedFilter = 'All';
  String? _selectedNodeId;
  bool _loading = true;

  final _transformCtrl = TransformationController();

  static const _filters = ['All', 'Physics', 'Math', 'AI/ML', 'Custom'];

  @override
  void initState() {
    super.initState();
    _loadTree();
  }

  @override
  void dispose() {
    _transformCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTree() async {
    final studiedTopics = <String, dynamic>{};
    try {
      final topics =
          await LocalMemoryService.instance.getAllTopicProgress();
      for (final t in topics) {
        final name = t['name'] as String? ?? '';
        if (name.isEmpty) continue;
        final key =
            name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
        studiedTopics[key] = {
          'name': name,
          'accuracy': t['accuracy'],
          'level': t['level'],
          'stars': t['stars'],
        };
      }
    } catch (_) {}

    final nodes = _buildNodes(studiedTopics);
    if (mounted) setState(() { _nodes = nodes; _loading = false; });
  }

  List<SkillNodeState> _buildNodes(Map<String, dynamic> studiedTopics) {
    final nodes = <SkillNodeState>[];
    final studiedKeys = studiedTopics.keys.toSet();

    // Build nodes from course data (Physics, Math)
    for (final course in CourseData.allCourses) {
      if (course.comingSoon) continue;

      for (int ci = 0; ci < course.chapters.length; ci++) {
        final chapter = course.chapters[ci];
        final topicKey = chapter.title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');

        final topicData = studiedTopics[topicKey] as Map<String, dynamic>?;
        final prevChapterKey = ci > 0
            ? course.chapters[ci - 1].title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')
            : null;

        SkillNodeStatus status;
        double accuracy = 0;
        int stars = 0;
        String level = 'basics';
        DateTime? lastStudied;

        if (topicData != null) {
          accuracy = ((topicData['accuracy'] as num?)?.toDouble() ?? 0) / 100;
          stars = (topicData['stars'] as num?)?.toInt() ?? 0;
          level = topicData['level'] as String? ?? 'basics';
          final ls = topicData['lastStudied'];
          if (ls is String) {
            lastStudied = DateTime.tryParse(ls);
          } else if (ls is DateTime) {
            lastStudied = ls;
          }
          status = accuracy >= 0.8 && stars >= 2
              ? SkillNodeStatus.mastered
              : SkillNodeStatus.inProgress;
        } else {
          // First chapter of each course is always available (not locked)
          if (ci == 0 || (prevChapterKey != null && studiedKeys.contains(prevChapterKey))) {
            status = SkillNodeStatus.available;
          } else {
            status = SkillNodeStatus.locked;
          }
        }

        nodes.add(SkillNodeState(
          id: '${course.id}_$topicKey',
          name: chapter.title,
          subject: course.name,
          status: status,
          accuracy: accuracy,
          stars: stars,
          level: level,
          lastStudied: lastStudied,
          prerequisiteIds: prevChapterKey != null ? ['${course.id}_$prevChapterKey'] : [],
        ));
      }
    }

    // Add custom topics from studiedTopics that aren't course chapters
    final courseTopicKeys = nodes.map((n) {
      final parts = n.id.split('_');
      return parts.length > 1 ? parts.sublist(1).join('_') : n.id;
    }).toSet();

    for (final entry in studiedTopics.entries) {
      if (courseTopicKeys.contains(entry.key)) continue;
      final data = entry.value as Map<String, dynamic>? ?? {};
      final name = data['name'] as String? ?? entry.key.replaceAll('_', ' ');
      final accuracy = ((data['accuracy'] as num?)?.toDouble() ?? 0) / 100;
      final stars = (data['stars'] as num?)?.toInt() ?? 0;
      final level = data['level'] as String? ?? 'basics';
      DateTime? lastStudied;
      final ls = data['lastStudied'];
      if (ls is String) {
        lastStudied = DateTime.tryParse(ls);
      } else if (ls is DateTime) {
        lastStudied = ls;
      }

      nodes.add(SkillNodeState(
        id: 'custom_${entry.key}',
        name: name,
        subject: 'Custom',
        status: accuracy >= 0.8 && stars >= 2
            ? SkillNodeStatus.mastered
            : SkillNodeStatus.inProgress,
        accuracy: accuracy,
        stars: stars,
        level: level,
        lastStudied: lastStudied,
      ));
    }

    // Compute layout positions
    return _layoutNodes(nodes);
  }

  List<SkillNodeState> _layoutNodes(List<SkillNodeState> nodes) {
    // Group by subject
    final groups = <String, List<SkillNodeState>>{};
    for (final node in nodes) {
      groups.putIfAbsent(node.subject, () => []).add(node);
    }

    final result = <SkillNodeState>[];
    double xOffset = 80;
    const yStart = 80.0;
    const yGap = 100.0;
    const xGroupGap = 200.0;

    for (final subject in groups.keys) {
      final group = groups[subject]!;
      double y = yStart;

      for (final node in group) {
        result.add(SkillNodeState(
          id: node.id,
          name: node.name,
          subject: node.subject,
          status: node.status,
          accuracy: node.accuracy,
          stars: node.stars,
          level: node.level,
          lastStudied: node.lastStudied,
          position: Offset(xOffset, y),
          prerequisiteIds: node.prerequisiteIds,
        ));
        y += yGap;
      }
      xOffset += xGroupGap;
    }

    return result;
  }

  List<SkillNodeState> get _filteredNodes {
    if (_selectedFilter == 'All') return _nodes;
    return _nodes.where((n) => n.subject == _selectedFilter).toList();
  }

  // Stats
  int get _masteredCount => _nodes.where((n) => n.isMastered).length;
  int get _inProgressCount => _nodes.where((n) => n.isInProgress).length;
  double get _overallProgress {
    if (_nodes.isEmpty) return 0;
    final active = _nodes.where((n) => !n.isLocked).length;
    return active == 0 ? 0 : _masteredCount / _nodes.length;
  }

  void _onTapNode(Offset localPosition, Matrix4 transform) {
    // Convert local position back through the transform
    final inverted = Matrix4.inverted(transform);
    final point = MatrixUtils.transformPoint(inverted, localPosition);

    for (final node in _filteredNodes) {
      if ((node.position - point).distance < 30) {
        setState(() => _selectedNodeId = node.id);
        showSkillDetailSheet(context, node);
        return;
      }
    }
    setState(() => _selectedNodeId = null);
  }

  @override
  Widget build(BuildContext context) {
    final dark = AppTheme.isDark(context);
    final accent = AppTheme.accentCyanOf(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: AppTheme.scaffoldDecorationOf(context),
        child: Stack(
          children: [
            if (dark) const ParticleBackground(
              particleCount: 15,
              particleColor: AppTheme.accentCyan,
              maxRadius: 0.8,
            ),
            SafeArea(
              child: Column(
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Icon(Icons.arrow_back_ios_rounded,
                              color: AppTheme.textPrimaryOf(context), size: 20),
                        ),
                        const SizedBox(width: 12),
                        ShaderMask(
                          shaderCallback: (bounds) =>
                              AppTheme.primaryGradientOf(context).createShader(bounds),
                          child: Text('Skill Tree',
                            style: GoogleFonts.orbitron(
                              fontSize: 18, fontWeight: FontWeight.w800,
                              color: Colors.white, letterSpacing: 1,
                            ),
                          ),
                        ),
                        const Spacer(),
                        // Progress badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: AppTheme.accentGreenOf(context).withAlpha(20),
                            border: Border.all(color: AppTheme.accentGreenOf(context).withAlpha(60)),
                          ),
                          child: Text(
                            '${(_overallProgress * 100).toInt()}%',
                            style: GoogleFonts.orbitron(
                              fontSize: 10, fontWeight: FontWeight.w700,
                              color: AppTheme.accentGreenOf(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 400.ms),
                  const SizedBox(height: 10),
                  // Stats row
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        _StatPill(
                          icon: Icons.check_circle_rounded,
                          label: '$_masteredCount mastered',
                          color: AppTheme.accentGreenOf(context),
                        ),
                        const SizedBox(width: 8),
                        _StatPill(
                          icon: Icons.pending_rounded,
                          label: '$_inProgressCount in progress',
                          color: accent,
                        ),
                        const SizedBox(width: 8),
                        _StatPill(
                          icon: Icons.account_tree_rounded,
                          label: '${_nodes.length} total',
                          color: AppTheme.textTertiaryOf(context),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Filter tabs
                  SizedBox(
                    height: 34,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: _filters.length,
                      itemBuilder: (_, i) {
                        final f = _filters[i];
                        final sel = f == _selectedFilter;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedFilter = f),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                color: sel ? accent.withAlpha(20) : Colors.transparent,
                                border: Border.all(
                                  color: sel ? accent : AppTheme.glassBorderOf(context),
                                  width: sel ? 1.2 : 0.5,
                                ),
                              ),
                              child: Text(f,
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 12, fontWeight: FontWeight.w600,
                                  color: sel ? accent : AppTheme.textSecondaryOf(context),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Tree visualization
                  Expanded(
                    child: _loading
                        ? Center(child: CircularProgressIndicator(color: accent))
                        : _nodes.isEmpty
                            ? _buildEmptyState()
                            : GestureDetector(
                                onTapUp: (details) {
                                  _onTapNode(
                                    details.localPosition,
                                    _transformCtrl.value,
                                  );
                                },
                                child: InteractiveViewer(
                                  transformationController: _transformCtrl,
                                  minScale: 0.3,
                                  maxScale: 3.0,
                                  boundaryMargin: const EdgeInsets.all(200),
                                  child: CustomPaint(
                                    size: _canvasSize,
                                    painter: SkillTreePainter(
                                      nodes: _filteredNodes,
                                      isDark: dark,
                                      selectedId: _selectedNodeId,
                                    ),
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

  Size get _canvasSize {
    if (_filteredNodes.isEmpty) return const Size(400, 600);
    double maxX = 0, maxY = 0;
    for (final n in _filteredNodes) {
      if (n.position.dx > maxX) maxX = n.position.dx;
      if (n.position.dy > maxY) maxY = n.position.dy;
    }
    return Size(maxX + 160, maxY + 160);
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.account_tree_rounded, size: 64,
                color: AppTheme.textTertiaryOf(context).withAlpha(80)),
            const SizedBox(height: 16),
            Text('No skills yet',
              style: GoogleFonts.orbitron(
                fontSize: 16, fontWeight: FontWeight.w700,
                color: AppTheme.textSecondaryOf(context),
              ),
            ),
            const SizedBox(height: 8),
            Text('Complete lessons to grow your skill tree!',
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 13, color: AppTheme.textTertiaryOf(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GlassContainer(
        borderColor: color.withAlpha(25),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 12),
            const SizedBox(width: 4),
            Flexible(
              child: Text(label,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 10, fontWeight: FontWeight.w600, color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
