import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../core/widgets/neon_button.dart';
import '../models/story_style.dart';

/// Style selection screen — 2 cards.
/// Practical is a direct tap. Movie/TV expands a search input for the franchise name.
class StyleSelector extends StatefulWidget {
  const StyleSelector({
    super.key,
    required this.onStyleSelected,
  });

  final void Function(StoryStyle style, {String? franchiseName}) onStyleSelected;

  @override
  State<StyleSelector> createState() => _StyleSelectorState();
}

class _StyleSelectorState extends State<StyleSelector> {
  bool _showTvInput = false;
  final _franchiseCtrl = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _franchiseCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submitFranchise() {
    final name = _franchiseCtrl.text.trim();
    if (name.isEmpty) return;
    widget.onStyleSelected(StoryStyle.movieTv, franchiseName: name);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 16),
        ShaderMask(
          shaderCallback: (bounds) =>
              AppTheme.primaryGradientOf(context).createShader(bounds),
          child: Text(
            'HOW DO YOU WANT\nTO LEARN?',
            style: AppTheme.headerStyle(fontSize: 22, letterSpacing: 2),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Pick your vibe, we\'ll create the story',
          style: AppTheme.bodyStyle(
            fontSize: 13,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 28),

        // ── Practical ──
        _DirectStyleCard(
          style: StoryStyle.practical,
          subtitle: 'See it work in real life',
          onTap: () => widget.onStyleSelected(StoryStyle.practical),
        ),
        const SizedBox(height: 14),

        // ── Movie / TV ──
        _buildMovieTvCard(),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildMovieTvCard() {
    final style = StoryStyle.movieTv;

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: Column(
        children: [
          // Card header
          GestureDetector(
            onTap: () {
              setState(() => _showTvInput = !_showTvInput);
              if (_showTvInput) {
                Future.delayed(const Duration(milliseconds: 350), () {
                  if (mounted) _focusNode.requestFocus();
                });
              }
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _showTvInput
                          ? style.color.withAlpha(130)
                          : style.color.withAlpha(70),
                      width: _showTvInput ? 1.5 : 1,
                    ),
                    gradient: LinearGradient(
                      colors: [
                        style.color.withAlpha(_showTvInput ? 35 : 20),
                        Colors.white.withAlpha(6),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: style.color.withAlpha(_showTvInput ? 50 : 25),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: style.color.withAlpha(30),
                          border: Border.all(
                              color: style.color.withAlpha(100), width: 1.5),
                        ),
                        child: Icon(style.icon, color: style.color, size: 26),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              style.label,
                              style: GoogleFonts.orbitron(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: style.color,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              style.description,
                              style: AppTheme.bodyStyle(
                                fontSize: 11,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        _showTvInput
                            ? Icons.keyboard_arrow_up
                            : Icons.arrow_forward_ios,
                        color: style.color.withAlpha(120),
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Expandable search input
          if (_showTvInput) ...[
            const SizedBox(height: 12),
            GlassContainer(
              borderColor: style.color.withAlpha(50),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Which show / movie / anime / cartoon?',
                    style: AppTheme.bodyStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _franchiseCtrl,
                    focusNode: _focusNode,
                    style: AppTheme.bodyStyle(
                      fontSize: 15,
                      color: AppTheme.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText:
                          'e.g. Breaking Bad, Naruto, Taarak Mehta...',
                      hintStyle: AppTheme.bodyStyle(
                        fontSize: 13,
                        color: AppTheme.textTertiary,
                      ),
                      filled: true,
                      fillColor: Colors.white.withAlpha(8),
                      prefixIcon: Icon(Icons.search,
                          color: style.color.withAlpha(120), size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: style.color.withAlpha(50)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: style.color.withAlpha(50)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: style.color, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                    textInputAction: TextInputAction.go,
                    onSubmitted: (_) => _submitFranchise(),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: NeonButton(
                      label: 'START STORY',
                      icon: Icons.auto_stories,
                      colors: [style.color, AppTheme.accentPurple],
                      onTap: _submitFranchise,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A direct-tap style card (no expandable input).
class _DirectStyleCard extends StatelessWidget {
  const _DirectStyleCard({
    required this.style,
    required this.subtitle,
    required this.onTap,
  });

  final StoryStyle style;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: style.color.withAlpha(70), width: 1),
              gradient: LinearGradient(
                colors: [
                  style.color.withAlpha(20),
                  Colors.white.withAlpha(6),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: style.color.withAlpha(25),
                  blurRadius: 20,
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: style.color.withAlpha(30),
                    border: Border.all(
                        color: style.color.withAlpha(100), width: 1.5),
                  ),
                  child: Icon(style.icon, color: style.color, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        style.label,
                        style: GoogleFonts.orbitron(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: style.color,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: AppTheme.bodyStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: style.color.withAlpha(120),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
