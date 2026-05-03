import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
import '../services/lab_memory_service.dart';
import '../services/lab_profile_service.dart';
import 'comic_album_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _profile = LabProfileService.instance;
  final _memory = LabMemoryService.instance;

  List<Map<String, dynamic>> _topics = const [];
  List<Map<String, dynamic>> _favorites = const [];
  List<Map<String, dynamic>> _recent = const [];
  int _comicCount = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _profile.addListener(_onChange);
    _load();
  }

  @override
  void dispose() {
    _profile.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) _load();
  }

  Future<void> _load() async {
    final t = await _memory.getAllTopicProgress();
    final f = await _memory.getTopFranchises(limit: 3);
    final r = await _memory.getRecentEvents(limit: 10);
    final c = await _memory.getComics();
    if (!mounted) return;
    setState(() {
      _topics = t;
      _favorites = f;
      _recent = r;
      _comicCount = c.length;
      _loading = false;
    });
  }

  void _openAlbum() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const ComicAlbumScreen()))
        .then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final p = _profile.currentProfile;
    return Scaffold(
      backgroundColor: AppTheme.backgroundPrimary,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          color: AppTheme.accentMagenta,
          backgroundColor: AppTheme.surfaceDark,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
            children: [
              _buildHeader(p),
              const SizedBox(height: 20),
              _statRow(p),
              const SizedBox(height: 16),
              _comicAlbumEntry(),
              const SizedBox(height: 12),
              _sectionLabel('TOPICS MASTERED'),
              const SizedBox(height: 10),
              _topicsList(mastered: true),
              const SizedBox(height: 24),
              _sectionLabel('WEAK TOPICS'),
              const SizedBox(height: 10),
              _topicsList(mastered: false),
              const SizedBox(height: 24),
              _sectionLabel('FAVORITE STORY WORLDS'),
              const SizedBox(height: 10),
              _favoritesList(),
              const SizedBox(height: 24),
              _sectionLabel('RECENT ACTIVITY'),
              const SizedBox(height: 10),
              _recentList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(LabProfile? p) {
    final initial = (p?.name.isNotEmpty == true)
        ? p!.name[0].toUpperCase()
        : '?';
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [AppTheme.accentMagenta, AppTheme.accentPurple],
            ),
          ),
          child: Text(initial,
              style: GoogleFonts.orbitron(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              )),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(p?.name ?? 'Lab user',
                  style: GoogleFonts.orbitron(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  )),
              Text('Lab profile · isolated DB',
                  style: AppTheme.bodyStyle(
                    fontSize: 11,
                    color: AppTheme.textTertiary,
                  )),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statRow(LabProfile? p) {
    return Row(
      children: [
        _statTile(
            'XP', '${p?.xp ?? 0}', Icons.bolt_rounded, AppTheme.accentMagenta),
        const SizedBox(width: 10),
        _statTile('STREAK', '${p?.streak ?? 0}d',
            Icons.local_fire_department_rounded, AppTheme.accentGold),
        const SizedBox(width: 10),
        _statTile('TOPICS', '${_topics.length}',
            Icons.menu_book_rounded, AppTheme.accentCyan),
      ],
    );
  }

  Widget _statTile(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: color.withAlpha(20),
          border: Border.all(color: color.withAlpha(60)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(value,
                style: GoogleFonts.orbitron(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                )),
            Text(label,
                style: GoogleFonts.orbitron(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: color,
                  letterSpacing: 1.2,
                )),
          ],
        ),
      ),
    );
  }

  Widget _comicAlbumEntry() {
    return GestureDetector(
      onTap: _openAlbum,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.accentMagenta.withAlpha(40),
              AppTheme.accentCyan.withAlpha(28),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.accentMagenta.withAlpha(80)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppTheme.accentMagenta.withAlpha(50),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.collections_bookmark_rounded,
                  color: AppTheme.accentMagenta, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'COMIC ALBUM',
                    style: GoogleFonts.orbitron(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.accentMagenta,
                      letterSpacing: 1.6,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _comicCount == 0
                        ? 'Save lessons as 4-panel manga to remember them'
                        : '$_comicCount comic${_comicCount == 1 ? '' : 's'} saved',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 12,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.white54, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(text,
      style: GoogleFonts.orbitron(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: AppTheme.textTertiary,
        letterSpacing: 2,
      ));

  Widget _topicsList({required bool mastered}) {
    if (_loading) return _placeholder();
    final filtered = _topics.where((t) {
      final acc = (t['accuracy'] as int?) ?? 0;
      return mastered ? acc >= 70 : acc < 70;
    }).toList();
    if (filtered.isEmpty) {
      return _emptyText(mastered
          ? 'Score 70%+ on a topic to see it here.'
          : 'No weak topics — nice.');
    }
    return Column(
      children: filtered
          .map((t) => Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.white.withAlpha(10),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        t['name'] as String? ?? '',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    Text('${t['accuracy']}%',
                        style: TextStyle(
                          color: mastered
                              ? AppTheme.accentGreen
                              : AppTheme.accentMagenta,
                          fontWeight: FontWeight.w700,
                        )),
                  ],
                ),
              ))
          .toList(),
    );
  }

  Widget _favoritesList() {
    if (_loading) return _placeholder();
    if (_favorites.isEmpty) {
      return _emptyText('Use a franchise in a lesson to see it here.');
    }
    return Column(
      children: _favorites
          .map((f) => Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: AppTheme.accentMagenta.withAlpha(15),
                  border: Border.all(
                      color: AppTheme.accentMagenta.withAlpha(80)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.movie_filter_rounded,
                        color: AppTheme.accentMagenta, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        f['franchise_name'] as String? ?? '',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    Text('${f['use_count']}× used',
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 11)),
                  ],
                ),
              ))
          .toList(),
    );
  }

  Widget _recentList() {
    if (_loading) return _placeholder();
    if (_recent.isEmpty) {
      return _emptyText('No activity yet.');
    }
    return Column(
      children: _recent
          .map((e) => Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.white.withAlpha(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (e['type'] as String? ?? '').toUpperCase(),
                      style: GoogleFonts.orbitron(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.accentCyan,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      e['content'] as String? ?? '',
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 12, height: 1.4),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }

  Widget _placeholder() => Container(
        height: 60,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: Colors.white.withAlpha(8),
        ),
      );

  Widget _emptyText(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(text,
            style: const TextStyle(color: Colors.white38, fontSize: 12)),
      );
}
