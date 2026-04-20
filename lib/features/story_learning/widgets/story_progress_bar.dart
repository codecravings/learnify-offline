import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Scene progress dots displayed at the top of the story screen.
class StoryProgressBar extends StatelessWidget {
  const StoryProgressBar({
    super.key,
    required this.totalScenes,
    required this.currentScene,
    this.accentColor = AppTheme.accentCyan,
  });

  final int totalScenes;
  final int currentScene;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalScenes, (index) {
        final isActive = index == currentScene;
        final isPast = index < currentScene;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isActive ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: isActive
                ? accentColor
                : isPast
                    ? accentColor.withAlpha(120)
                    : AppTheme.surfaceLight,
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: accentColor.withAlpha(100),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
        );
      }),
    );
  }
}
