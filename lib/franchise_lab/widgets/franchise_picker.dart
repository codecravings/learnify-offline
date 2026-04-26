import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
import '../data/franchise_loader.dart';

/// A bottom-sheet style searchable franchise picker.
///
/// Returns the selected `Franchise` via `Navigator.pop(context, franchise)`.
/// Pop with `null` to cancel.
class FranchisePickerSheet extends StatefulWidget {
  const FranchisePickerSheet({super.key});

  @override
  State<FranchisePickerSheet> createState() => _FranchisePickerSheetState();
}

class _FranchisePickerSheetState extends State<FranchisePickerSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  List<Franchise> _all = const [];
  bool _loading = true;

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
      _loading = false;
    });
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
      default:
        return category.toUpperCase();
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
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
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                        itemCount: _filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final f = _filtered[i];
                          final color = _categoryColor(f.category);
                          return InkWell(
                            onTap: () => Navigator.of(context).pop(f),
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                color: color.withAlpha(14),
                                border: Border.all(color: color.withAlpha(60)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 3),
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
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
