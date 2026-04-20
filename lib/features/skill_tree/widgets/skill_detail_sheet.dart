import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_container.dart';
import '../models/skill_node_state.dart';

/// Bottom sheet showing details for a selected skill tree node.
void showSkillDetailSheet(BuildContext context, SkillNodeState node) {
  final dark = AppTheme.isDark(context);
  final accent = switch (node.status) {
    SkillNodeStatus.mastered => AppTheme.accentGreenOf(context),
    SkillNodeStatus.inProgress => AppTheme.accentCyanOf(context),
    SkillNodeStatus.available => const Color(0xFF8B5CF6),
    SkillNodeStatus.locked => AppTheme.textTertiaryOf(context),
  };

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return Container(
        decoration: BoxDecoration(
          color: dark ? const Color(0xFF111827).withAlpha(245) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: accent.withAlpha(60), width: 1.5)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: (dark ? Colors.white : Colors.black).withAlpha(30),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Title + status badge
            Row(
              children: [
                Expanded(
                  child: Text(
                    node.name,
                    style: GoogleFonts.orbitron(
                      fontSize: 16, fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimaryOf(ctx),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: accent.withAlpha(20),
                    border: Border.all(color: accent.withAlpha(60)),
                  ),
                  child: Text(
                    switch (node.status) {
                      SkillNodeStatus.mastered => 'MASTERED',
                      SkillNodeStatus.inProgress => 'IN PROGRESS',
                      SkillNodeStatus.available => 'READY',
                      SkillNodeStatus.locked => 'LOCKED',
                    },
                    style: GoogleFonts.orbitron(
                      fontSize: 8, fontWeight: FontWeight.w700,
                      color: accent, letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Stats
            Row(
              children: [
                _StatChip(label: 'Subject', value: node.subject, color: accent),
                const SizedBox(width: 8),
                _StatChip(label: 'Level', value: node.level, color: accent),
                const SizedBox(width: 8),
                _StatChip(
                  label: 'Accuracy',
                  value: '${(node.accuracy * 100).toInt()}%',
                  color: accent,
                ),
              ],
            ),
            if (node.stars > 0) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Text('Stars: ', style: GoogleFonts.spaceGrotesk(
                    fontSize: 12, color: AppTheme.textSecondaryOf(ctx),
                  )),
                  for (int i = 0; i < 3; i++)
                    Icon(
                      i < node.stars ? Icons.star_rounded : Icons.star_border_rounded,
                      color: const Color(0xFFF59E0B),
                      size: 18,
                    ),
                ],
              ),
            ],
            if (node.lastStudied != null) ...[
              const SizedBox(height: 6),
              Text(
                'Last studied: ${_formatDate(node.lastStudied!)}',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 11, color: AppTheme.textTertiaryOf(ctx),
                ),
              ),
            ],
            // Accuracy progress bar
            if (!node.isLocked && !node.isAvailable) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: node.accuracy,
                  minHeight: 6,
                  backgroundColor: accent.withAlpha(20),
                  valueColor: AlwaysStoppedAnimation(accent),
                ),
              ),
            ],
            const SizedBox(height: 16),
            // Action button
            if (!node.isLocked)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    context.push('/lesson', extra: {
                      'customTopic': node.name,
                      'preselectedLevel': node.isAvailable ? null : node.level,
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    node.isMastered ? 'REVIEW TOPIC' : node.isAvailable ? 'START LEARNING' : 'CONTINUE STUDYING',
                    style: GoogleFonts.orbitron(
                      fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}

String _formatDate(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inDays == 0) return 'Today';
  if (diff.inDays == 1) return 'Yesterday';
  if (diff.inDays < 7) return '${diff.inDays} days ago';
  return '${dt.day}/${dt.month}/${dt.year}';
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GlassContainer(
        borderColor: color.withAlpha(25),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          children: [
            Text(label, style: GoogleFonts.spaceGrotesk(
              fontSize: 9, color: AppTheme.textTertiaryOf(context),
            )),
            const SizedBox(height: 2),
            Text(value, style: GoogleFonts.spaceGrotesk(
              fontSize: 12, fontWeight: FontWeight.w700,
              color: AppTheme.textPrimaryOf(context),
            )),
          ],
        ),
      ),
    );
  }
}
