import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
import '../data/franchise_loader.dart';

/// A bottom-sheet style searchable franchise picker.
///
/// Returns the selected `Franchise` via `Navigator.pop(context, franchise)`.
/// Pop with `null` to cancel.
class FranchisePickerSheet extends StatefulWidget {
  const FranchisePickerSheet({super.key, this.suggestedMood = ''});

  /// Optional mood (calm|hyped|curious|anxious|sad). If non-empty, the picker
  /// surfaces a "Best for your mood" section above the full list.
  final String suggestedMood;

  @override
  State<FranchisePickerSheet> createState() => _FranchisePickerSheetState();
}

class _FranchisePickerSheetState extends State<FranchisePickerSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  List<Franchise> _all = const [];
  bool _loading = true;
  List<Franchise> _moodMatches = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await FranchiseLoader.instance.all();
    if (!mounted) return;
    setState(() {
      _all = list;
      _moodMatches = _rankByMood(list, widget.suggestedMood);
      _loading = false;
    });
  }

  // Mood → tone keywords. Score each franchise as max-keyword-hits across its
  // characters' emotional/speech/humor styles. Cheap heuristic, no model call.
  static const _moodKeywords = <String, List<String>>{
    'calm': [
      'measured', 'thoughtful', 'quiet', 'patient', 'serene', 'gentle',
      'composed', 'steady', 'reflective', 'soft-spoken', 'wise'
    ],
    'hyped': [
      'energetic', 'loud', 'enthusiastic', 'high-energy', 'bombastic',
      'fiery', 'passionate', 'exuberant', 'punchy', 'wild', 'over the top'
    ],
    'curious': [
      'inquisitive', 'curious', 'exploratory', 'questioning', 'wondering',
      'analytical', 'observant', 'investigative', 'open-minded'
    ],
    'anxious': [
      'reassuring', 'patient', 'gentle', 'soft', 'kind', 'warm',
      'calm', 'understanding', 'protective', 'supportive'
    ],
    'sad': [
      'warm', 'kind', 'gentle', 'uplifting', 'supportive', 'compassionate',
      'tender', 'empathetic', 'hopeful', 'caring'
    ],
  };

  List<Franchise> _rankByMood(List<Franchise> list, String mood) {
    if (mood.isEmpty) return const [];
    final keywords = _moodKeywords[mood];
    if (keywords == null || keywords.isEmpty) return const [];
    final scored = <(Franchise, int)>[];
    for (final f in list) {
      var best = 0;
      for (final c in f.characters) {
        final blob = (c.emotionalStyle + ' ' + c.speechStyle +
                ' ' + c.humorStyle + ' ' + c.teachingStyle +
                ' ' + c.traits.join(' '))
            .toLowerCase();
        var score = 0;
        for (final kw in keywords) {
          if (blob.contains(kw)) score++;
        }
        if (score > best) best = score;
      }
      if (best > 0) scored.add((f, best));
    }
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    return scored.take(3).map((e) => e.$1).toList();
  }

  List<Franchise> get _filtered {
    if (_query.isEmpty) return _all;
    final q = _query.toLowerCase();
    return _all
        .where((f) =>
            f.name.toLowerCase().contains(q) ||
            f.category.toLowerCase().contains(q))
        .toList();
  }

  Color _categoryColor(String category) {
    switch (category) {
      case 'anime':
        return AppTheme.accentMagenta;
      case 'cartoons':
        return AppTheme.accentGold;
      case 'live_action':
        return AppTheme.accentCyan;
      case 'movies':
        return AppTheme.accentPurple;
      case 'indian':
        return AppTheme.accentGreen;
      case 'k_drama':
        return const Color(0xFFFF6B9D);
      case 'gaming':
        return const Color(0xFF00FF88);
      default:
        return AppTheme.accentCyan;
    }
  }

  String _categoryLabel(String category) {
    switch (category) {
      case 'anime':
        return 'ANIME';
      case 'cartoons':
        return 'CARTOON';
      case 'live_action':
        return 'TV';
      case 'movies':
        return 'MOVIE';
      case 'indian':
        return 'INDIAN';
      case 'k_drama':
        return 'K-DRAMA';
      case 'gaming':
        return 'GAMING';
      default:
        return category.toUpperCase();
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Widget _buildList() {
    final showMoodHeader = _query.isEmpty &&
        widget.suggestedMood.isNotEmpty &&
        _moodMatches.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: [
        if (showMoodHeader) ...[
          Row(
            children: [
              Icon(Icons.psychology_alt_rounded,
                  color: AppTheme.accentPurple, size: 14),
              const SizedBox(width: 6),
              Text(
                'BEST FOR YOUR MOOD',
                style: GoogleFonts.orbitron(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.accentPurple,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final f in _moodMatches) ...[
            _franchiseRow(f, highlighted: true),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 8),
          Text(
            'ALL FRANCHISES',
            style: GoogleFonts.orbitron(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.white54,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 8),
        ],
        for (final f in _filtered) ...[
          _franchiseRow(f, highlighted: false),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _franchiseRow(Franchise f, {required bool highlighted}) {
    final color = _categoryColor(f.category);
    final accent = highlighted ? AppTheme.accentPurple : color;
    return InkWell(
      onTap: () => Navigator.of(context).pop(f),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: accent.withAlpha(highlighted ? 28 : 14),
          border: Border.all(
              color: accent.withAlpha(highlighted ? 120 : 60),
              width: highlighted ? 1.2 : 0.7),
        ),
        child: Row(
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                color: color.withAlpha(40),
              ),
              child: Text(
                _categoryLabel(f.category),
                style: GoogleFonts.orbitron(
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  color: color,
                  letterSpacing: 1,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                f.name,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
            if (highlighted)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(Icons.auto_awesome_rounded,
                    color: AppTheme.accentPurple, size: 14),
              ),
            Text(
              '${f.characters.length} chars',
              style: const TextStyle(
                fontSize: 11,
                color: Colors.white38,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: AppTheme.backgroundSecondary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: AppTheme.glassBorder, width: 0.5),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
            child: Row(
              children: [
                Text(
                  'PICK A FRANCHISE',
                  style: GoogleFonts.orbitron(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.accentCyan,
                    letterSpacing: 1.6,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  onPressed: () => Navigator.of(context).pop(null),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              onChanged: (v) => setState(() => _query = v.trim()),
              decoration: InputDecoration(
                hintText: 'Search franchises…',
                hintStyle: const TextStyle(color: Colors.white30),
                prefixIcon: const Icon(Icons.search_rounded, color: Colors.white54),
                filled: true,
                fillColor: Colors.white.withAlpha(15),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.accentCyan, width: 1.5),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? Center(
                        child: Text(
                          'No matches for "$_query"',
                          style: const TextStyle(color: Colors.white38),
                        ),
                      )
                    : _buildList(),
          ),
        ],
      ),
    );
  }
}
