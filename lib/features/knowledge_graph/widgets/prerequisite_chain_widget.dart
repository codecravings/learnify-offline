import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../data/prerequisite_graph.dart';

/// Visual chain display: Root → ... → Target, with mastery coloring per node.
class PrerequisiteChainWidget extends StatelessWidget {
  const PrerequisiteChainWidget({
    super.key,
    required this.chain,
    required this.accuracyMap,
    this.targetConcept,
    this.rootCauseId,
  });

  final List<ConceptNode> chain;
  final Map<String, double> accuracyMap;
  final ConceptNode? targetConcept;
  final String? rootCauseId;

  Color _nodeColor(ConceptNode node) {
    final acc = accuracyMap[node.id] ??
        accuracyMap[node.name.toLowerCase()] ??
        -1;
    if (acc < 0) return AppTheme.accentPurple; // never studied
    if (acc >= 80) return AppTheme.accentGreen;
    if (acc >= 50) return AppTheme.accentCyan;
    return const Color(0xFFF97316); // orange = weak
  }

  String _nodeLabel(ConceptNode node) {
    final acc = accuracyMap[node.id] ??
        accuracyMap[node.name.toLowerCase()] ??
        -1;
    if (acc < 0) return 'Not studied';
    return '${acc.round()}%';
  }

  @override
  Widget build(BuildContext context) {
    // Show up to 4 nodes in the chain + target
    final displayChain = chain.length > 4 ? chain.sublist(0, 4) : chain;
    final hasMore = chain.length > 4;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < displayChain.length; i++) ...[
            _buildNode(displayChain[i]),
            _buildArrow(),
          ],
          if (hasMore) ...[
            Text(
              '...',
              style: GoogleFonts.spaceGrotesk(
                color: AppTheme.textTertiary,
                fontSize: 14,
              ),
            ),
            _buildArrow(),
          ],
          if (targetConcept != null) _buildNode(targetConcept!, isTarget: true),
        ],
      ),
    );
  }

  Widget _buildNode(ConceptNode node, {bool isTarget = false}) {
    final color = _nodeColor(node);
    final isRoot = node.id == rootCauseId;
    final label = _nodeLabel(node);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.withAlpha(isRoot ? 50 : 25),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: color.withAlpha(isRoot ? 180 : 80),
              width: isRoot ? 1.5 : 0.8,
            ),
            boxShadow: isRoot
                ? [BoxShadow(color: color.withAlpha(60), blurRadius: 10)]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                node.name,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 10,
                  fontWeight: isRoot || isTarget ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 8,
                  color: AppTheme.textTertiary,
                ),
              ),
            ],
          ),
        ),
        if (isRoot) ...[
          const SizedBox(height: 3),
          Text(
            'ROOT CAUSE',
            style: GoogleFonts.orbitron(
              fontSize: 6,
              fontWeight: FontWeight.w700,
              color: const Color(0xFFF97316),
              letterSpacing: 1,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildArrow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Icon(
        Icons.arrow_forward_ios,
        size: 10,
        color: AppTheme.textTertiary.withAlpha(120),
      ),
    );
  }
}
