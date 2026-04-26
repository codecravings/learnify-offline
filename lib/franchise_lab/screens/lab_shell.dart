import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
import 'companion_screen.dart';
import 'profile_screen.dart';
import 'story_learn_screen.dart';

/// 3-tab bottom-nav shell for the lab.
class LabShell extends StatefulWidget {
  const LabShell({super.key});

  @override
  State<LabShell> createState() => _LabShellState();
}

class _LabShellState extends State<LabShell> {
  int _index = 0;

  static const _tabs = [
    _Tab(icon: Icons.movie_filter_rounded, label: 'Story Learn'),
    _Tab(icon: Icons.psychology_rounded, label: 'Companion'),
    _Tab(icon: Icons.person_rounded, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundPrimary,
      extendBody: true,
      body: IndexedStack(
        index: _index,
        children: const [
          StoryLearnScreen(),
          CompanionScreen(),
          ProfileScreen(),
        ],
      ),
      bottomNavigationBar: _buildNav(context),
    );
  }

  Widget _buildNav(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.only(
            top: 10,
            bottom: bottomPadding + 10,
            left: 8,
            right: 8,
          ),
          decoration: BoxDecoration(
            color: AppTheme.backgroundPrimary.withAlpha(180),
            border: Border(
              top: BorderSide(color: AppTheme.glassBorder, width: 0.5),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_tabs.length, (i) {
              final selected = i == _index;
              return _NavItem(
                tab: _tabs[i],
                selected: selected,
                onTap: () => setState(() => _index = i),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _Tab {
  const _Tab({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final _Tab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppTheme.accentMagenta : AppTheme.textTertiary;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: selected
                  ? BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.accentMagenta.withAlpha(90),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    )
                  : null,
              child: Icon(tab.icon, color: color, size: 24),
            ),
            const SizedBox(height: 4),
            Text(
              tab.label,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 10,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
