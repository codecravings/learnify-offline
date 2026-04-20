import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Glass speech bubble with typewriter text animation.
class SpeechBubble extends StatelessWidget {
  const SpeechBubble({
    super.key,
    required this.text,
    required this.visibleCharCount,
    this.narration,
    this.accentColor = AppTheme.accentCyan,
    this.isComplete = false,
  });

  /// Full dialogue text.
  final String text;

  /// Number of characters currently visible (for typewriter effect).
  final int visibleCharCount;

  /// Optional narration shown above the dialogue.
  final String? narration;

  /// Accent color for the bubble border.
  final Color accentColor;

  /// Whether the typewriter animation has completed.
  final bool isComplete;

  @override
  Widget build(BuildContext context) {
    final visibleText = visibleCharCount >= text.length
        ? text
        : text.substring(0, visibleCharCount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (narration != null && narration!.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 4),
            child: Text(
              narration!,
              style: AppTheme.bodyStyle(
                fontSize: 12,
                color: AppTheme.textTertiary,
                fontWeight: FontWeight.w300,
              ).copyWith(fontStyle: FontStyle.italic),
            ),
          ),
        ],
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: accentColor.withAlpha(80),
                  width: 1,
                ),
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withAlpha(20),
                    Colors.white.withAlpha(8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    visibleText,
                    style: AppTheme.bodyStyle(
                      fontSize: 15,
                      color: AppTheme.textPrimary,
                      height: 1.6,
                    ),
                  ),
                  if (isComplete) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          'Tap to continue',
                          style: AppTheme.bodyStyle(
                            fontSize: 11,
                            color: accentColor.withAlpha(150),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 10,
                          color: accentColor.withAlpha(150),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
