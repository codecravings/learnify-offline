import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/local_memory_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_container.dart';

/// Searches the learner's own studied topics locally. No network, no Firebase.
/// Matches against topic names; also offers "Learn '<query>'" as a fast path
/// to start a new lesson on anything that isn't in the library yet.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _memory = LocalMemoryService.instance;
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;

  List<Map<String, dynamic>> _allTopics = const [];
  List<Map<String, dynamic>> _results = const [];
  String _query = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final topics = await _memory.getAllTopicProgress();
    if (!mounted) return;
    setState(() {
      _allTopics = topics;
      _results = topics;
      _loading = false;
    });
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 120), () {
      final query = q.trim().toLowerCase();
      setState(() {
        _query = query;
        if (query.isEmpty) {
          _results = _allTopics;
        } else {
          _results = _allTopics.where((t) {
            final name = (t['name'] as String? ?? '').toLowerCase();
            return name.contains(query);
          }).toList();
        }
      });
    });
  }

  void _startNewLesson(String topic) {
    if (topic.trim().isEmpty) return;
    context.push('/lesson', extra: {'customTopic': topic.trim()});
  }

  void _continueTopic(Map<String, dynamic> topic) {
    final name = topic['name'] as String;
    final level = (topic['level'] as String?) ?? 'basics';
    context.push('/lesson', extra: {'customTopic': name, 'level': level});
  }

  void _exploreQuery(String q) {
    if (q.trim().isEmpty) return;
    context.push('/topic-explorer', extra: {'topic': q.trim()});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('SEARCH'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: Container(
        decoration: AppTheme.scaffoldDecorationOf(context),
        child: SafeArea(
          child: Column(
            children: [
              _buildSearchBar(context),
              const SizedBox(height: 4),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _buildResults(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
      child: GlassContainer(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        borderRadius: 14,
        child: Row(
          children: [
            Icon(Icons.search_rounded,
                color: AppTheme.textSecondaryOf(context), size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _ctrl,
                focusNode: _focus,
                onChanged: _onChanged,
                onSubmitted: _startNewLesson,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search your topics or start a new one…',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  hintStyle: AppTheme.bodyStyle(
                    fontSize: 14,
                    color: AppTheme.textTertiaryOf(context),
                  ),
                ),
                style: AppTheme.bodyStyle(
                  fontSize: 14,
                  color: AppTheme.textPrimaryOf(context),
                ),
              ),
            ),
            if (_ctrl.text.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: () {
                  _ctrl.clear();
                  _onChanged('');
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults(BuildContext context) {
    final hasQuery = _query.isNotEmpty;
    final hasMatches = _results.isNotEmpty;

    if (!hasQuery && _allTopics.isEmpty) {
      return _buildEmptyHint(context);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      children: [
        if (hasQuery) _buildQueryActions(context),
        if (hasQuery) const SizedBox(height: 12),
        if (hasMatches)
          Text(
            hasQuery
                ? '${_results.length} match${_results.length == 1 ? '' : 'es'} in your library'
                : 'YOUR LIBRARY',
            style: AppTheme.headerStyle(
              fontSize: 11,
              letterSpacing: 2.0,
              color: AppTheme.textSecondaryOf(context),
            ),
          ),
        if (hasMatches) const SizedBox(height: 10),
        if (hasMatches)
          for (int i = 0; i < _results.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ResultTile(
                topic: _results[i],
                onTap: () => _continueTopic(_results[i]),
              )
                  .animate(delay: (30 * i).ms)
                  .fadeIn(duration: 180.ms)
                  .slideY(begin: 0.04, end: 0),
            )
        else if (hasQuery)
          _buildNoMatch(context)
        else
          _buildEmptyHint(context),
      ],
    );
  }

  Widget _buildQueryActions(BuildContext context) {
    return Column(
      children: [
        _ActionRow(
          icon: Icons.auto_stories_rounded,
          title: 'Learn "$_query" now',
          subtitle: 'Start a full story lesson',
          color: AppTheme.accentCyanOf(context),
          onTap: () => _startNewLesson(_query),
        ),
        const SizedBox(height: 8),
        _ActionRow(
          icon: Icons.account_tree_rounded,
          title: 'Explore "$_query"',
          subtitle: 'Break it into 6–8 sub-topics first',
          color: AppTheme.accentPurpleOf(context),
          onTap: () => _exploreQuery(_query),
        ),
      ],
    );
  }

  Widget _buildNoMatch(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded,
              size: 40, color: AppTheme.textTertiaryOf(context)),
          const SizedBox(height: 10),
          Text('Not in your library yet',
              style: AppTheme.bodyStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimaryOf(context),
              )),
          const SizedBox(height: 4),
          Text(
            'Use the quick actions above to start learning it.',
            textAlign: TextAlign.center,
            style: AppTheme.bodyStyle(
              fontSize: 12,
              color: AppTheme.textSecondaryOf(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyHint(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      child: Column(
        children: [
          Icon(Icons.travel_explore_rounded,
              size: 52, color: AppTheme.textTertiaryOf(context)),
          const SizedBox(height: 14),
          Text('Your library is empty',
              style: AppTheme.headerStyle(fontSize: 18)),
          const SizedBox(height: 6),
          Text(
            'Type any topic to start a lesson — even obscure ones. Gemma 4 runs fully on this device.',
            textAlign: TextAlign.center,
            style: AppTheme.bodyStyle(
              fontSize: 13,
              color: AppTheme.textSecondaryOf(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.topic, required this.onTap});
  final Map<String, dynamic> topic;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = topic['name'] as String? ?? 'Topic';
    final level = (topic['level'] as String?) ?? 'basics';
    final accuracy = topic['accuracy'] as int? ?? 0;
    final stars = topic['stars'] as int? ?? 0;

    final levelColor = switch (level.toLowerCase()) {
      'advanced' => AppTheme.accentMagentaOf(context),
      'intermediate' => AppTheme.accentGoldOf(context),
      _ => AppTheme.accentGreenOf(context),
    };

    return GlassContainer(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: AppTheme.accentCyanOf(context).withAlpha(28),
              border: Border.all(
                  color: AppTheme.accentCyanOf(context).withAlpha(80),
                  width: 1),
            ),
            child: Icon(Icons.history_edu_rounded,
                color: AppTheme.accentCyanOf(context), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.bodyStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimaryOf(context),
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: levelColor.withAlpha(32),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                            color: levelColor.withAlpha(90), width: 0.7),
                      ),
                      child: Text(
                        level.toUpperCase(),
                        style: AppTheme.bodyStyle(
                          fontSize: 9,
                          color: levelColor,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    for (int i = 0; i < 3; i++)
                      Icon(
                        i < stars
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        size: 12,
                        color: i < stars
                            ? AppTheme.accentGoldOf(context)
                            : AppTheme.textTertiaryOf(context),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Text(
            '$accuracy%',
            style: AppTheme.bodyStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: accuracy >= 80
                  ? AppTheme.accentGreenOf(context)
                  : accuracy >= 60
                      ? AppTheme.accentGoldOf(context)
                      : AppTheme.accentMagentaOf(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withAlpha(90), width: 1),
          gradient: LinearGradient(
            colors: [color.withAlpha(42), color.withAlpha(14)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withAlpha(60),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: AppTheme.bodyStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimaryOf(context),
                      )),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: AppTheme.bodyStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondaryOf(context),
                      )),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_rounded, color: color, size: 20),
          ],
        ),
      ),
    );
  }
}
