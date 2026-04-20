import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/story_character.dart';

/// Displays a character image with a neon glow border matching their accent color.
class CharacterPortrait extends StatelessWidget {
  const CharacterPortrait({
    super.key,
    required this.character,
    this.size = 120,
    this.showName = true,
  });

  final StoryCharacter character;
  final double size;
  final bool showName;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: character.accentColor, width: 2.5),
            boxShadow: AppTheme.neonGlow(character.accentColor, blur: 16),
          ),
          child: ClipOval(
            child: Image.asset(
              character.imagePath,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: character.accentColor.withAlpha(30),
                child: Center(
                  child: Text(
                    character.name[0],
                    style: AppTheme.headerStyle(
                      fontSize: size * 0.4,
                      color: character.accentColor,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (showName) ...[
          const SizedBox(height: 8),
          Text(
            character.name,
            style: AppTheme.headerStyle(
              fontSize: 12,
              color: character.accentColor,
              letterSpacing: 1.5,
            ),
          ),
          Text(
            character.role,
            style: AppTheme.bodyStyle(
              fontSize: 10,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}
