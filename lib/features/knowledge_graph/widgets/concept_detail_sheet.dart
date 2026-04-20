import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/neon_button.dart';
import '../data/prerequisite_graph.dart';

/// Bottom sheet showing details for a tapped concept node.
class ConceptDetailSheet extends StatelessWidget {
  const ConceptDetailSheet({
    super.key,
    required this.concept,
    required this.accuracy,
    required this.onHighlightPrereqs,
  });

  final ConceptNode concept;
  final double accuracy; // -1 = never studied
  final VoidCallback onHighlightPrereqs;

  Color get _masteryColor {
    if (accuracy < 0) return AppTheme.accentPurple;
    if (accuracy >= 80) return AppTheme.accentGreen;
    if (accuracy >= 50) return AppTheme.accentCyan;
    return const Color(0xFFF97316);
  }

  String get _masteryLabel {
    if (accuracy < 0) return 'Not Studied';
    if (accuracy >= 80) return 'Mastered';
    if (accuracy >= 50) return 'Learning';
    return 'Needs Work';
  }

  @override
  Widget build(BuildContext context) {
    final prereqs = PrerequisiteGraph.getPrerequisites(concept.id);
    final dependents = PrerequisiteGraph.getDependents(concept.id);
    final crossLinks = concept.relatedIds
        .map((id) => PrerequisiteGraph.getById(id))
        .whereType<ConceptNode>()
        .toList();

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(
          top: BorderSide(color: _masteryColor.withAlpha(60)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textTertiary.withAlpha(80),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: name + subject badge
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        concept.name,
                        style: GoogleFonts.orbitron(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: _masteryColor,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _subjectColor.withAlpha(25),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _subjectColor.withAlpha(80),
                          width: 0.5,
                        ),
                      ),
                      child: Text(
                        concept.subject.toUpperCase(),
                        style: GoogleFonts.orbitron(
                          fontSize: 8,
                          fontWeight: FontWeight.w600,
                          color: _subjectColor,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Mastery bar
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _masteryColor,
                        boxShadow: [
                          BoxShadow(
                            color: _masteryColor.withAlpha(80),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _masteryLabel,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _masteryColor,
                      ),
                    ),
                    if (accuracy >= 0) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: accuracy / 100,
                            backgroundColor: Colors.white.withAlpha(10),
                            color: _masteryColor,
                            minHeight: 4,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${accuracy.round()}%',
                        style: GoogleFonts.orbitron(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _masteryColor,
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 12),

                // Description
                Text(
                  concept.description,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 16),

                // Prerequisites section
                if (prereqs.isNotEmpty) ...[
                  _sectionHeader('PREREQUISITES', Icons.arrow_back),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: prereqs.map((p) => _conceptChip(p)).toList(),
                  ),
                  const SizedBox(height: 12),
                ],

                // Unlocks section
                if (dependents.isNotEmpty) ...[
                  _sectionHeader('UNLOCKS', Icons.lock_open),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: dependents.take(6).map((d) => _conceptChip(d)).toList(),
                  ),
                  const SizedBox(height: 12),
                ],

                // Cross-subject links
                if (crossLinks.isNotEmpty) ...[
                  _sectionHeader('CROSS-SUBJECT LINKS', Icons.link),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: crossLinks.map((c) => _conceptChip(c, showSubject: true)).toList(),
                  ),
                  const SizedBox(height: 12),
                ],

                const SizedBox(height: 8),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: NeonButton(
                        label: 'STUDY THIS',
                        icon: Icons.school,
                        height: 40,
                        fontSize: 11,
                        colors: [_masteryColor, AppTheme.accentPurple],
                        onTap: () {
                          Navigator.of(context).pop();
                          context.push('/lesson', extra: {
                            'customTopic': concept.name,
                            'level': 'basics',
                          });
                        },
                      ),
                    ),
                    if (prereqs.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: NeonButton(
                          label: 'SHOW CHAIN',
                          icon: Icons.account_tree,
                          height: 40,
                          fontSize: 11,
                          colors: [AppTheme.accentCyan, AppTheme.accentPurple],
                          onTap: () {
                            Navigator.of(context).pop();
                            onHighlightPrereqs();
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color get _subjectColor =>
      concept.subject == 'physics' ? AppTheme.accentPurple : AppTheme.accentCyan;

  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 12, color: AppTheme.textTertiary),
        const SizedBox(width: 6),
        Text(
          title,
          style: GoogleFonts.orbitron(
            fontSize: 8,
            fontWeight: FontWeight.w600,
            color: AppTheme.textTertiary,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _conceptChip(ConceptNode node, {bool showSubject = false}) {
    final color = node.subject == 'physics'
        ? AppTheme.accentPurple
        : AppTheme.accentCyan;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(50), width: 0.5),
      ),
      child: Text(
        showSubject ? '${node.name} (${node.subject})' : node.name,
        style: GoogleFonts.spaceGrotesk(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
