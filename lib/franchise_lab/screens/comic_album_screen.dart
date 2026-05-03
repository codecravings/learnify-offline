import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass_container.dart';
import '../services/lab_memory_service.dart';
import '../widgets/comic_panel_grid.dart';

/// Album view of all comics the user has saved in the franchise lab.
///
/// Loads from `LabMemoryService.getComics()` and renders each as a 2-col
/// grid card. Tap → fullscreen viewer; long-press → delete confirmation.
class ComicAlbumScreen extends StatefulWidget {
  const ComicAlbumScreen({super.key});

  @override
  State<ComicAlbumScreen> createState() => _ComicAlbumScreenState();
}

class _ComicAlbumScreenState extends State<ComicAlbumScreen> {
  List<_ComicEntry> _entries = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rows = await LabMemoryService.instance.getComics();
    final parsed = <_ComicEntry>[];
    for (final row in rows) {
      final entry = _ComicEntry.tryFrom(row);
      if (entry != null) parsed.add(entry);
    }
    if (!mounted) return;
    setState(() {
      _entries = parsed;
      _loading = false;
    });
  }

  Future<void> _deleteComic(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.backgroundSecondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppTheme.glassBorder),
        ),
        title: Text(
          'Delete comic?',
          style: GoogleFonts.orbitron(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'This will remove the comic from your album permanently.',
          style: GoogleFonts.spaceGrotesk(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Delete',
              style: GoogleFonts.spaceGrotesk(
                color: AppTheme.accentMagenta,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await LabMemoryService.instance.deleteComic(id);
    await _load();
  }

  void _openComic(_ComicEntry entry) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _ComicViewerScreen(entry: entry),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundPrimary,
      body: Container(
        decoration: AppTheme.scaffoldDecoration,
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  // ── header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white),
            onPressed: () => Navigator.of(context).maybePop(),
            tooltip: 'Back',
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              'COMIC ALBUM',
              style: GoogleFonts.orbitron(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 2.4,
              ),
            ),
          ),
          _countBadge(_entries.length),
        ],
      ),
    );
  }

  Widget _countBadge(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.accentCyan, AppTheme.accentPurple],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.neonGlow(AppTheme.accentCyan, blur: 12),
      ),
      child: Text(
        '$count',
        style: GoogleFonts.orbitron(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  // ── body ───────────────────────────────────────────────────────────────────

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.accentCyan),
      );
    }
    if (_entries.isEmpty) {
      return _buildEmptyState();
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: AppTheme.accentCyan,
      backgroundColor: AppTheme.surfaceDark,
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 0.72,
        ),
        itemCount: _entries.length,
        itemBuilder: (ctx, i) {
          final entry = _entries[i];
          return _ComicCard(
            entry: entry,
            onTap: () => _openComic(entry),
            onLongPress: () => _deleteComic(entry.id),
          ).animate().fadeIn(
                duration: 280.ms,
                delay: (40 * i).ms,
              );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: GlassContainer(
          padding: const EdgeInsets.all(28),
          borderRadius: 20,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [AppTheme.accentCyan, AppTheme.accentPurple],
                  ),
                  boxShadow: AppTheme.neonGlow(AppTheme.accentPurple, blur: 18),
                ),
                child: const Icon(Icons.rocket_launch_rounded,
                    color: Colors.white, size: 36),
              ),
              const SizedBox(height: 16),
              Text(
                'NO COMICS YET',
                style: GoogleFonts.orbitron(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Finish a story to save your first comic!',
                textAlign: TextAlign.center,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 320.ms),
      ),
    );
  }
}

// ── card ─────────────────────────────────────────────────────────────────────

class _ComicCard extends StatelessWidget {
  const _ComicCard({
    required this.entry,
    required this.onTap,
    required this.onLongPress,
  });

  final _ComicEntry entry;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final subtitleParts = <String>[
      if (entry.franchiseName != null && entry.franchiseName!.isNotEmpty)
        entry.franchiseName!,
      entry.topic,
    ];
    final subtitle = subtitleParts.join('  ·  ');

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: GlassContainer(
        padding: const EdgeInsets.all(10),
        borderRadius: 16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: AspectRatio(
                aspectRatio: 1,
                child: ComicPanelGrid(payload: entry.payload, compact: true),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              entry.title.isNotEmpty ? entry.title : 'Untitled',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.orbitron(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 11,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              entry.formattedDate,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 10,
                color: AppTheme.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── viewer ───────────────────────────────────────────────────────────────────

class _ComicViewerScreen extends StatelessWidget {
  const _ComicViewerScreen({required this.entry});

  final _ComicEntry entry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundPrimary,
      body: Container(
        decoration: AppTheme.scaffoldDecoration,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: Colors.white, size: 26),
                      onPressed: () => Navigator.of(context).maybePop(),
                      tooltip: 'Close',
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.print_rounded,
                          color: AppTheme.accentCyan),
                      tooltip: 'Print preview',
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Print coming soon',
                              style: GoogleFonts.spaceGrotesk(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            backgroundColor: AppTheme.surfaceLight,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  child: ComicPanelGrid(payload: entry.payload)
                      .animate()
                      .fadeIn(duration: 320.ms),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── model ────────────────────────────────────────────────────────────────────

class _ComicEntry {
  _ComicEntry({
    required this.id,
    required this.topic,
    required this.title,
    required this.franchiseName,
    required this.createdAt,
    required this.payload,
  });

  final int id;
  final String topic;
  final String title;
  final String? franchiseName;
  final DateTime? createdAt;
  final Map<String, dynamic> payload;

  String get formattedDate {
    final d = createdAt;
    if (d == null) return '';
    final now = DateTime.now();
    final sameDay =
        d.year == now.year && d.month == now.month && d.day == now.day;
    if (sameDay) {
      final h = d.hour.toString().padLeft(2, '0');
      final m = d.minute.toString().padLeft(2, '0');
      return 'Today $h:$m';
    }
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  static _ComicEntry? tryFrom(Map<String, dynamic> row) {
    try {
      final id = row['id'];
      final raw = row['panels_json'];
      if (id is! int || raw is! String || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final payload = decoded.cast<String, dynamic>();
      return _ComicEntry(
        id: id,
        topic: (row['topic'] as String?)?.trim() ?? '',
        title: (row['title'] as String?)?.trim() ?? '',
        franchiseName: (row['franchise_name'] as String?)?.trim(),
        createdAt: DateTime.tryParse((row['created_at'] as String?) ?? ''),
        payload: payload,
      );
    } catch (_) {
      return null;
    }
  }
}
