import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/services/local_memory_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CoursesScreen – "KNOWLEDGE REALMS"
// A jaw-dropping, visually insane course-category browser for Learnify.
// ─────────────────────────────────────────────────────────────────────────────

class CoursesScreen extends StatefulWidget {
  const CoursesScreen({super.key});

  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen>
    with TickerProviderStateMixin {
  // ── palette ──────────────────────────────────────────────────────────────
  static const Color _bg = Color(0xFF111827);
  static const Color _cyan = Color(0xFF3B82F6);
  static const Color _purple = Color(0xFF8B5CF6);
  static const Color _magenta = Color(0xFFEF4444);
  static const Color _green = Color(0xFF22C55E);
  static const Color _gold = Color(0xFFF59E0B);
  static const Color _orange = Color(0xFFFF8C00);
  static const Color _lime = Color(0xFF39FF14);

  // ── controllers ──────────────────────────────────────────────────────────
  late final AnimationController _particleCtrl;
  late final AnimationController _pulseCtrl;
  late final AnimationController _bannerCtrl;
  late final PageController _featuredPageCtrl;
  late final ScrollController _scrollCtrl;
  final TextEditingController _searchCtrl = TextEditingController();

  late final List<_Particle> _particles;
  String _searchQuery = '';
  String _selectedFilter = 'All';
  int _featuredPage = 0;

  /// Real progress data from Firestore studiedTopics
  /// Key: sanitized topic name, Value: {accuracy, level, stars, ...}
  Map<String, Map<String, dynamic>> _studiedTopicsMap = {};

  final List<String> _filters = [
    'All',
    'Trending',
    'New',
    'Popular',
    'Advanced',
  ];

  // ── category data ────────────────────────────────────────────────────────
  final List<_CategoryData> _categories = [
    _CategoryData(
      name: 'Artificial Intelligence',
      tagline: 'Master the machines',
      icon: Icons.psychology_alt,
      color: _cyan,
      secondaryColor: Color(0xFF0088CC),
      courseCount: 47,
      difficulty: 'Advanced',
      xpReward: 2500,
      progress: 0.34,
      tag: 'Trending',
      subcategories: [
        'Neural Networks',
        'NLP & Transformers',
        'Computer Vision',
        'Reinforcement Learning',
        'Generative AI',
        'AI Ethics',
      ],
    ),
    _CategoryData(
      name: 'Data Structures & Algorithms',
      tagline: 'Think in structures',
      icon: Icons.account_tree,
      color: _green,
      secondaryColor: Color(0xFF00AA55),
      courseCount: 63,
      difficulty: 'Intermediate',
      xpReward: 2000,
      progress: 0.58,
      tag: 'Popular',
      subcategories: [
        'Arrays & Strings',
        'Trees & Graphs',
        'Dynamic Programming',
        'Sorting & Searching',
        'Greedy Algorithms',
        'Hashing',
      ],
    ),
    _CategoryData(
      name: 'Physics',
      tagline: 'Decode the universe',
      icon: Icons.blur_circular,
      color: _purple,
      secondaryColor: Color(0xFF7B1FA2),
      courseCount: 38,
      difficulty: 'Intermediate',
      xpReward: 1800,
      progress: 0.22,
      tag: 'New',
      subcategories: [
        'Quantum Mechanics',
        'Classical Mechanics',
        'Electromagnetism',
        'Thermodynamics',
        'Optics',
        'Relativity',
      ],
    ),
    _CategoryData(
      name: 'Cybersecurity',
      tagline: 'Hack the planet',
      icon: Icons.security,
      color: _magenta,
      secondaryColor: Color(0xFFCC0033),
      courseCount: 41,
      difficulty: 'Advanced',
      xpReward: 2800,
      progress: 0.12,
      tag: 'Trending',
      subcategories: [
        'Penetration Testing',
        'Cryptography',
        'Network Security',
        'Web App Security',
        'Malware Analysis',
        'Forensics',
      ],
    ),
    _CategoryData(
      name: 'Mathematics',
      tagline: 'Numbers are power',
      icon: Icons.functions,
      color: _gold,
      secondaryColor: Color(0xFFCC9900),
      courseCount: 55,
      difficulty: 'All Levels',
      xpReward: 1500,
      progress: 0.45,
      tag: 'Popular',
      subcategories: [
        'Linear Algebra',
        'Calculus',
        'Probability & Statistics',
        'Discrete Mathematics',
        'Number Theory',
        'Abstract Algebra',
      ],
    ),
    _CategoryData(
      name: 'Web Development',
      tagline: 'Build the web',
      icon: Icons.code,
      color: _orange,
      secondaryColor: Color(0xFFCC6600),
      courseCount: 72,
      difficulty: 'Beginner',
      xpReward: 1200,
      progress: 0.67,
      tag: 'Popular',
      subcategories: [
        'HTML & CSS',
        'JavaScript',
        'React / Next.js',
        'Backend (Node / Django)',
        'Databases',
        'DevOps & Deployment',
      ],
    ),
    _CategoryData(
      name: 'Machine Learning',
      tagline: 'Train your models',
      icon: Icons.model_training,
      color: Color(0xFFFF2EAA),
      secondaryColor: _cyan,
      courseCount: 51,
      difficulty: 'Advanced',
      xpReward: 2600,
      progress: 0.29,
      tag: 'Trending',
      subcategories: [
        'Supervised Learning',
        'Unsupervised Learning',
        'Deep Learning',
        'Feature Engineering',
        'Model Optimization',
        'MLOps',
      ],
    ),
    _CategoryData(
      name: 'Blockchain',
      tagline: 'Decentralize everything',
      icon: Icons.link,
      color: _lime,
      secondaryColor: Color(0xFF22BB33),
      courseCount: 29,
      difficulty: 'Intermediate',
      xpReward: 2200,
      progress: 0.08,
      tag: 'New',
      subcategories: [
        'Smart Contracts',
        'Solidity',
        'DeFi Protocols',
        'NFT Development',
        'Consensus Algorithms',
        'Web3.js / Ethers.js',
      ],
    ),
  ];

  // ── featured courses ─────────────────────────────────────────────────────
  final List<_FeaturedCourse> _featuredCourses = [
    _FeaturedCourse(
      title: 'Build GPT from Scratch',
      subtitle: 'Deep-dive into transformer architecture',
      category: 'AI',
      xp: 500,
      gradient: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
      icon: Icons.auto_awesome,
      enrolled: 12400,
    ),
    _FeaturedCourse(
      title: 'Ethical Hacking Bootcamp',
      subtitle: 'Become a white-hat penetration tester',
      category: 'Cybersecurity',
      xp: 750,
      gradient: [Color(0xFFEF4444), Color(0xFFFF8C00)],
      icon: Icons.shield,
      enrolled: 8900,
    ),
    _FeaturedCourse(
      title: 'Quantum Computing 101',
      subtitle: 'Qubits, gates, and entanglement',
      category: 'Physics',
      xp: 600,
      gradient: [Color(0xFF8B5CF6), Color(0xFF3B82F6)],
      icon: Icons.blur_circular,
      enrolled: 6200,
    ),
  ];

  // ── lifecycle ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    _particleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 40),
    )..repeat();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _bannerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    _featuredPageCtrl = PageController(viewportFraction: 0.88);
    _scrollCtrl = ScrollController();

    final rng = Random(77);
    _particles = List.generate(100, (_) {
      return _Particle(
        x: rng.nextDouble(),
        y: rng.nextDouble(),
        radius: 0.4 + rng.nextDouble() * 2.0,
        alpha: 0.05 + rng.nextDouble() * 0.35,
        dx: (rng.nextDouble() - 0.5) * 0.25,
        dy: (rng.nextDouble() - 0.5) * 0.25,
        twinklePhase: rng.nextDouble() * 2 * pi,
      );
    });

    // Auto-scroll featured banner
    _startAutoScroll();

    _loadStudiedTopics();
  }

  Future<void> _loadStudiedTopics() async {
    try {
      final topics = await LocalMemoryService.instance.getAllTopicProgress();
      final map = <String, Map<String, dynamic>>{};
      for (final t in topics) {
        final name = t['name'] as String?;
        if (name == null) continue;
        final sanitized =
            name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
        map[sanitized] = t;
        map[name.toLowerCase()] = t;
      }
      if (mounted) setState(() => _studiedTopicsMap = map);
    } catch (_) {}
  }

  /// Get real progress for a topic by name.
  /// Returns 0.0-1.0 based on accuracy, or 0.0 if not studied.
  double _topicProgress(String topicName) {
    final key = topicName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
    final byKey = _studiedTopicsMap[key];
    final byName = _studiedTopicsMap[topicName.toLowerCase()];
    final data = byKey ?? byName;
    if (data == null) return 0.0;
    final accuracy = (data['accuracy'] as num?)?.toDouble() ?? 0.0;
    return (accuracy / 100.0).clamp(0.0, 1.0);
  }

  /// Compute overall category progress by averaging subcategory progress.
  double _categoryProgress(_CategoryData cat) {
    if (cat.subcategories.isEmpty) return 0.0;
    double total = 0;
    for (final sub in cat.subcategories) {
      total += _topicProgress(sub);
    }
    return total / cat.subcategories.length;
  }

  void _startAutoScroll() {
    Future.delayed(const Duration(seconds: 4), () {
      if (!mounted) return;
      final next = (_featuredPage + 1) % _featuredCourses.length;
      _featuredPageCtrl.animateToPage(
        next,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
      _startAutoScroll();
    });
  }

  @override
  void dispose() {
    _particleCtrl.dispose();
    _pulseCtrl.dispose();
    _bannerCtrl.dispose();
    _featuredPageCtrl.dispose();
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── filtering ────────────────────────────────────────────────────────────

  List<_CategoryData> get _filteredCategories {
    var list = _categories;
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list
          .where((c) =>
              c.name.toLowerCase().contains(q) ||
              c.tagline.toLowerCase().contains(q))
          .toList();
    }
    if (_selectedFilter != 'All') {
      if (_selectedFilter == 'Advanced') {
        list = list.where((c) => c.difficulty == 'Advanced').toList();
      } else {
        list = list.where((c) => c.tag == _selectedFilter).toList();
      }
    }
    return list;
  }

  // ── build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          // Animated particle background
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _particleCtrl,
              builder: (context, _) {
                return CustomPaint(
                  painter: _CoursesParticlePainter(
                    particles: _particles,
                    progress: _particleCtrl.value,
                  ),
                );
              },
            ),
          ),
          // Ambient glow orbs
          Positioned(
            top: -80,
            left: -60,
            child: _ambientOrb(_cyan, 220),
          ),
          Positioned(
            top: 300,
            right: -100,
            child: _ambientOrb(_purple, 260),
          ),
          Positioned(
            bottom: 100,
            left: -40,
            child: _ambientOrb(_magenta, 200),
          ),
          // Main content
          SafeArea(
            child: CustomScrollView(
              controller: _scrollCtrl,
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Header
                SliverToBoxAdapter(child: _buildHeader()),
                // Search bar
                SliverToBoxAdapter(child: _buildSearchBar()),
                // Filter chips
                SliverToBoxAdapter(child: _buildFilterChips()),
                // Featured banner
                SliverToBoxAdapter(child: _buildFeaturedBanner()),
                // Section title
                SliverToBoxAdapter(child: _buildSectionTitle()),
                // Staggered grid
                _buildStaggeredGrid(),
                // Bottom padding
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── ambient orb ──────────────────────────────────────────────────────────

  Widget _ambientOrb(Color color, double size) {
    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (context, child) {
        final scale = 0.85 + 0.3 * _pulseCtrl.value;
        return Transform.scale(
          scale: scale,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  color.withAlpha(30),
                  color.withAlpha(8),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── header ───────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: _glassIconButton(Icons.arrow_back_ios_new_rounded),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [_cyan, _purple, _magenta],
                  ).createShader(bounds),
                  child: Text(
                    'KNOWLEDGE REALMS',
                    style: GoogleFonts.orbitron(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 2.0,
                    ),
                  ),
                ).animate().fadeIn(duration: 600.ms).slideX(begin: -0.1),
                const SizedBox(height: 4),
                Text(
                  'Choose your domain of mastery',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 13,
                    color: Colors.white38,
                    fontWeight: FontWeight.w400,
                  ),
                ).animate().fadeIn(delay: 200.ms, duration: 500.ms),
              ],
            ),
          ),
          _glassIconButton(Icons.tune_rounded),
        ],
      ),
    );
  }

  Widget _glassIconButton(IconData icon) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(15),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withAlpha(30)),
          ),
          child: Icon(icon, color: Colors.white70, size: 20),
        ),
      ),
    );
  }

  // ── search bar ───────────────────────────────────────────────────────────

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.white.withAlpha(15),
              border: Border.all(color: Colors.white.withAlpha(25)),
            ),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _searchQuery = v),
              style: GoogleFonts.spaceGrotesk(
                color: Colors.white,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: 'Search realms, topics, skills...',
                hintStyle: GoogleFonts.spaceGrotesk(
                  color: Colors.white24,
                  fontSize: 14,
                ),
                prefixIcon: ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [_cyan, _purple],
                  ).createShader(bounds),
                  child: const Icon(Icons.search_rounded,
                      color: Colors.white, size: 22),
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? GestureDetector(
                        onTap: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                        child: const Icon(Icons.close_rounded,
                            color: Colors.white24, size: 20),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
        ),
      ),
    ).animate().fadeIn(delay: 100.ms, duration: 500.ms).slideY(begin: 0.1);
  }

  // ── filter chips ─────────────────────────────────────────────────────────

  Widget _buildFilterChips() {
    return SizedBox(
      height: 54,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
        itemCount: _filters.length,
        itemBuilder: (context, i) {
          final f = _filters[i];
          final selected = _selectedFilter == f;
          return GestureDetector(
            onTap: () => setState(() => _selectedFilter = f),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: selected
                    ? const LinearGradient(colors: [_cyan, _purple])
                    : null,
                color: selected ? null : Colors.white.withAlpha(13),
                border: Border.all(
                  color:
                      selected ? Colors.transparent : Colors.white.withAlpha(25),
                  width: 1,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: _cyan.withAlpha(50),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Text(
                f,
                style: GoogleFonts.spaceGrotesk(
                  color: selected ? Colors.white : Colors.white54,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  fontSize: 13,
                ),
              ),
            ),
          );
        },
      ),
    ).animate().fadeIn(delay: 200.ms, duration: 400.ms);
  }

  // ── featured banner ──────────────────────────────────────────────────────

  Widget _buildFeaturedBanner() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  gradient:
                      const LinearGradient(colors: [_cyan, _purple]),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'FEATURED',
                style: GoogleFonts.orbitron(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white54,
                  letterSpacing: 3.0,
                ),
              ),
              const Spacer(),
              // Dot indicators
              Row(
                children: List.generate(_featuredCourses.length, (i) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: _featuredPage == i ? 20 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      gradient: _featuredPage == i
                          ? const LinearGradient(colors: [_cyan, _purple])
                          : null,
                      color: _featuredPage == i
                          ? null
                          : Colors.white.withAlpha(40),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 170,
          child: PageView.builder(
            controller: _featuredPageCtrl,
            onPageChanged: (i) => setState(() => _featuredPage = i),
            itemCount: _featuredCourses.length,
            itemBuilder: (context, i) {
              return _buildFeaturedCard(_featuredCourses[i], i);
            },
          ),
        ),
      ],
    ).animate().fadeIn(delay: 300.ms, duration: 600.ms).slideY(begin: 0.08);
  }

  Widget _buildFeaturedCard(_FeaturedCourse course, int index) {
    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (context, child) {
        final glow = 0.6 + 0.4 * _pulseCtrl.value;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: LinearGradient(
                    colors: [
                      course.gradient[0].withAlpha(50),
                      course.gradient[1].withAlpha(30),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: course.gradient[0].withAlpha((70 * glow).round()),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color:
                          course.gradient[0].withAlpha((40 * glow).round()),
                      blurRadius: 24,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Background icon watermark
                    Positioned(
                      right: -20,
                      bottom: -20,
                      child: Icon(
                        course.icon,
                        size: 120,
                        color: course.gradient[0].withAlpha(18),
                      ),
                    ),
                    // Content
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Category pill
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: course.gradient[0].withAlpha(40),
                              border: Border.all(
                                color: course.gradient[0].withAlpha(80),
                              ),
                            ),
                            child: Text(
                              course.category,
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: course.gradient[0],
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            course.title,
                            style: GoogleFonts.orbitron(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            course.subtitle,
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 12,
                              color: Colors.white54,
                            ),
                          ),
                          const Spacer(),
                          Row(
                            children: [
                              Icon(Icons.bolt_rounded,
                                  color: _gold, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                '+${course.xp} XP',
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: _gold,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Icon(Icons.people_alt_rounded,
                                  color: Colors.white38, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                _formatNumber(course.enrolled),
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 12,
                                  color: Colors.white38,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 7),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  gradient: LinearGradient(
                                    colors: course.gradient,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: course.gradient[0]
                                          .withAlpha(80),
                                      blurRadius: 12,
                                    ),
                                  ],
                                ),
                                child: Text(
                                  'Enroll',
                                  style: GoogleFonts.orbitron(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ── section title ────────────────────────────────────────────────────────

  Widget _buildSectionTitle() {
    final count = _filteredCategories.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 14),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              gradient: const LinearGradient(colors: [_magenta, _orange]),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'ALL REALMS',
            style: GoogleFonts.orbitron(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.white54,
              letterSpacing: 3.0,
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: _cyan.withAlpha(25),
              border: Border.all(color: _cyan.withAlpha(50)),
            ),
            child: Text(
              '$count',
              style: GoogleFonts.orbitron(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: _cyan,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 400.ms, duration: 400.ms);
  }

  // ── staggered grid ───────────────────────────────────────────────────────

  Widget _buildStaggeredGrid() {
    final cats = _filteredCategories;
    if (cats.isEmpty) {
      return SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.only(top: 60),
            child: Column(
              children: [
                Icon(Icons.search_off_rounded,
                    color: Colors.white24, size: 64),
                const SizedBox(height: 16),
                Text(
                  'No realms found',
                  style: GoogleFonts.spaceGrotesk(
                    color: Colors.white38,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Build staggered pairs (2 columns, alternating heights)
    final List<Widget> rows = [];
    for (int i = 0; i < cats.length; i += 2) {
      final left = cats[i];
      final right = i + 1 < cats.length ? cats[i + 1] : null;
      final isEven = (i ~/ 2) % 2 == 0;

      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      top: isEven ? 0 : 28,
                      bottom: 8,
                      right: 6,
                    ),
                    child: _buildCategoryCard(left, i),
                  ),
                ),
                if (right != null)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        top: isEven ? 28 : 0,
                        bottom: 8,
                        left: 6,
                      ),
                      child: _buildCategoryCard(right, i + 1),
                    ),
                  )
                else
                  const Expanded(child: SizedBox()),
              ],
            ),
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, i) => rows[i],
        childCount: rows.length,
      ),
    );
  }

  // ── category card ────────────────────────────────────────────────────────

  Widget _buildCategoryCard(_CategoryData cat, int index) {
    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (context, _) {
        final pulse = _pulseCtrl.value;
        final borderAlpha = (40 + 40 * pulse).round();

        return GestureDetector(
          onTap: () {
            context.push('/lesson', extra: {
              'customTopic': cat.name,
            });
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withAlpha(15),
                      Colors.white.withAlpha(6),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: cat.color.withAlpha(borderAlpha),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: cat.color.withAlpha((20 * pulse).round()),
                      blurRadius: 20,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon area with neon glow
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Glow circle behind icon
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: cat.color
                                      .withAlpha((80 + 40 * pulse).round()),
                                  blurRadius: 28,
                                  spreadRadius: 4,
                                ),
                                BoxShadow(
                                  color: cat.color
                                      .withAlpha((40 + 20 * pulse).round()),
                                  blurRadius: 48,
                                  spreadRadius: 8,
                                ),
                              ],
                            ),
                          ),
                          // Outer ring
                          Container(
                            width: 58,
                            height: 58,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: cat.color.withAlpha(50),
                                width: 1.5,
                              ),
                              gradient: RadialGradient(
                                colors: [
                                  cat.color.withAlpha(20),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                          // Icon
                          Icon(
                            cat.icon,
                            size: 30,
                            color: cat.color,
                            shadows: [
                              Shadow(
                                color: cat.color.withAlpha(180),
                                blurRadius: 16,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Tag pill
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          color: cat.color.withAlpha(20),
                          border:
                              Border.all(color: cat.color.withAlpha(45)),
                        ),
                        child: Text(
                          cat.tag,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: cat.color,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Name
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Text(
                        cat.name,
                        style: GoogleFonts.orbitron(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Tagline
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Text(
                        cat.tagline,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 11,
                          color: Colors.white38,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Stats row
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Row(
                        children: [
                          Icon(Icons.menu_book_rounded,
                              color: Colors.white24, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            '${cat.courseCount}',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 11,
                              color: Colors.white54,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Icon(Icons.bolt_rounded,
                              color: _gold.withAlpha(150), size: 12),
                          const SizedBox(width: 2),
                          Text(
                            '${cat.xpReward}',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 11,
                              color: _gold.withAlpha(180),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Difficulty badge
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Text(
                        cat.difficulty,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 10,
                          color: _difficultyColor(cat.difficulty),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Progress bar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Builder(builder: (context) {
                        final realProgress = _categoryProgress(cat);
                        return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Progress',
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 9,
                                  color: Colors.white24,
                                ),
                              ),
                              Text(
                                '${(realProgress * 100).toInt()}%',
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: cat.color.withAlpha(200),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Stack(
                              children: [
                                // Track
                                Container(
                                  height: 5,
                                  decoration: BoxDecoration(
                                    borderRadius:
                                        BorderRadius.circular(4),
                                    color: Colors.white.withAlpha(13),
                                  ),
                                ),
                                // Fill
                                FractionallySizedBox(
                                  widthFactor: realProgress,
                                  child: Container(
                                    height: 5,
                                    decoration: BoxDecoration(
                                      borderRadius:
                                          BorderRadius.circular(4),
                                      gradient: LinearGradient(
                                        colors: [
                                          cat.color,
                                          cat.secondaryColor,
                                        ],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color:
                                              cat.color.withAlpha(120),
                                          blurRadius: 6,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                      }),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    )
        .animate()
        .fadeIn(
          delay: Duration(milliseconds: 150 + index * 100),
          duration: 500.ms,
        )
        .slideY(begin: 0.15);
  }

  Color _difficultyColor(String difficulty) {
    switch (difficulty) {
      case 'Beginner':
        return _green;
      case 'Intermediate':
        return _gold;
      case 'Advanced':
        return _magenta;
      default:
        return _cyan;
    }
  }

  // ── subcategory modal ────────────────────────────────────────────────────

  void _showSubcategoryModal(_CategoryData cat) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.72,
          minChildSize: 0.4,
          maxChildSize: 0.92,
          builder: (ctx, scrollCtrl) {
            return ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(28)),
                    color: const Color(0xFF0D1229).withAlpha(240),
                    border: Border(
                      top: BorderSide(
                        color: cat.color.withAlpha(80),
                        width: 2,
                      ),
                      left: BorderSide(
                        color: cat.color.withAlpha(30),
                        width: 1,
                      ),
                      right: BorderSide(
                        color: cat.color.withAlpha(30),
                        width: 1,
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: cat.color.withAlpha(30),
                        blurRadius: 40,
                        offset: const Offset(0, -10),
                      ),
                    ],
                  ),
                  child: ListView(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.all(24),
                    children: [
                      // Drag handle
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(2),
                            color: cat.color.withAlpha(80),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Icon + title row
                      Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  cat.color.withAlpha(40),
                                  Colors.transparent,
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: cat.color.withAlpha(60),
                                  blurRadius: 20,
                                ),
                              ],
                            ),
                            child: Icon(cat.icon,
                                size: 26, color: cat.color),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  cat.name,
                                  style: GoogleFonts.orbitron(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    height: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  cat.tagline,
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: 13,
                                    color: cat.color.withAlpha(180),
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Stats row
                      Row(
                        children: [
                          _modalStat(
                            Icons.menu_book_rounded,
                            '${cat.courseCount} Courses',
                            Colors.white54,
                          ),
                          const SizedBox(width: 16),
                          _modalStat(
                            Icons.bolt_rounded,
                            '${cat.xpReward} XP',
                            _gold,
                          ),
                          const SizedBox(width: 16),
                          _modalStat(
                            Icons.trending_up_rounded,
                            cat.difficulty,
                            _difficultyColor(cat.difficulty),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Overall progress
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Stack(
                          children: [
                            Container(
                              height: 8,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(6),
                                color: Colors.white.withAlpha(13),
                              ),
                            ),
                            FractionallySizedBox(
                              widthFactor: cat.progress,
                              child: Container(
                                height: 8,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  gradient: LinearGradient(
                                    colors: [
                                      cat.color,
                                      cat.secondaryColor,
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: cat.color.withAlpha(120),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '${(_categoryProgress(cat) * 100).toInt()}% complete',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 11,
                            color: cat.color.withAlpha(160),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Divider
                      Container(
                        height: 1,
                        color: Colors.white.withAlpha(13),
                      ),
                      const SizedBox(height: 20),
                      // Section header
                      Text(
                        'TOPICS',
                        style: GoogleFonts.orbitron(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white38,
                          letterSpacing: 3.0,
                        ),
                      ),
                      const SizedBox(height: 14),
                      // Topic list
                      ...List.generate(cat.subcategories.length, (i) {
                        final sub = cat.subcategories[i];
                        final topicProg = _topicProgress(sub);
                        return _buildTopicTile(
                          sub,
                          i,
                          cat.color,
                          topicProg,
                          cat.subcategories.length,
                        );
                      }),
                      const SizedBox(height: 16),
                      // Start Learning button
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(ctx);
                          final topic = cat.subcategories.isNotEmpty
                              ? cat.subcategories.first
                              : cat.name;
                          context.push('/lesson', extra: {
                            'customTopic': topic,
                          });
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: LinearGradient(
                              colors: [cat.color, cat.secondaryColor],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: cat.color.withAlpha(80),
                                blurRadius: 20,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              'START LEARNING',
                              style: GoogleFonts.orbitron(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 2.0,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _modalStat(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 11,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildTopicTile(
    String name,
    int index,
    Color accentColor,
    double progress,
    int lessons,
  ) {
    final isComplete = progress >= 0.99;
    return GestureDetector(
      onTap: () {
        Navigator.pop(context); // close the modal
        context.push('/lesson', extra: {
          'customTopic': name,
        });
      },
      child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: Colors.white.withAlpha(isComplete ? 10 : 8),
              border: Border.all(
                color: isComplete
                    ? accentColor.withAlpha(50)
                    : Colors.white.withAlpha(15),
              ),
            ),
            child: Row(
              children: [
                // Index circle
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: isComplete
                        ? LinearGradient(
                            colors: [
                              accentColor.withAlpha(60),
                              accentColor.withAlpha(25),
                            ],
                          )
                        : null,
                    color: isComplete ? null : Colors.white.withAlpha(10),
                    border: Border.all(
                      color: isComplete
                          ? accentColor.withAlpha(80)
                          : Colors.white.withAlpha(20),
                    ),
                  ),
                  child: Center(
                    child: isComplete
                        ? Icon(Icons.check_rounded,
                            color: accentColor, size: 18)
                        : Text(
                            '${index + 1}',
                            style: GoogleFonts.orbitron(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white38,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 14),
                // Topic info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withAlpha(220),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            '$lessons lessons',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 11,
                              color: Colors.white30,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 3,
                            height: 3,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withAlpha(51),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${(progress * 100).toInt()}%',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 11,
                              color: accentColor.withAlpha(180),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Mini progress bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: Stack(
                          children: [
                            Container(
                              height: 3,
                              color: Colors.white.withAlpha(10),
                            ),
                            FractionallySizedBox(
                              widthFactor: progress,
                              child: Container(
                                height: 3,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      accentColor,
                                      accentColor.withAlpha(150),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white24,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
    );
  }

  // ── helpers ──────────────────────────────────────────────────────────────

  String _formatNumber(int n) {
    if (n >= 1000) {
      return '${(n / 1000).toStringAsFixed(1)}K';
    }
    return n.toString();
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Data models
// ═══════════════════════════════════════════════════════════════════════════════

class _CategoryData {
  final String name;
  final String tagline;
  final IconData icon;
  final Color color;
  final Color secondaryColor;
  final int courseCount;
  final String difficulty;
  final int xpReward;
  final double progress;
  final String tag;
  final List<String> subcategories;

  const _CategoryData({
    required this.name,
    required this.tagline,
    required this.icon,
    required this.color,
    required this.secondaryColor,
    required this.courseCount,
    required this.difficulty,
    required this.xpReward,
    required this.progress,
    required this.tag,
    required this.subcategories,
  });
}

class _FeaturedCourse {
  final String title;
  final String subtitle;
  final String category;
  final int xp;
  final List<Color> gradient;
  final IconData icon;
  final int enrolled;

  const _FeaturedCourse({
    required this.title,
    required this.subtitle,
    required this.category,
    required this.xp,
    required this.gradient,
    required this.icon,
    required this.enrolled,
  });
}

class _Particle {
  final double x;
  final double y;
  final double radius;
  final double alpha;
  final double dx;
  final double dy;
  final double twinklePhase;

  const _Particle({
    required this.x,
    required this.y,
    required this.radius,
    required this.alpha,
    required this.dx,
    required this.dy,
    required this.twinklePhase,
  });
}

// ═══════════════════════════════════════════════════════════════════════════════
// Particle painter
// ═══════════════════════════════════════════════════════════════════════════════

class _CoursesParticlePainter extends CustomPainter {
  _CoursesParticlePainter({
    required this.particles,
    required this.progress,
  });

  final List<_Particle> particles;
  final double progress;

  // Cycle through multiple neon colors for variety
  static const List<Color> _colors = [
    Color(0xFF3B82F6),
    Color(0xFF8B5CF6),
    Color(0xFF22C55E),
    Color(0xFFEF4444),
    Color(0xFFF59E0B),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < particles.length; i++) {
      final p = particles[i];
      final color = _colors[i % _colors.length];

      final px = ((p.x + p.dx * progress) % 1.0) * size.width;
      final py = ((p.y + p.dy * progress) % 1.0) * size.height;

      final twinkle =
          (sin(progress * 2 * pi * 3 + p.twinklePhase) + 1) / 2;
      final alpha = (p.alpha * (0.3 + 0.7 * twinkle)).clamp(0.0, 1.0);

      paint.color = color.withAlpha((alpha * 255).round());
      canvas.drawCircle(Offset(px, py), p.radius, paint);

      // Glow on larger particles
      if (p.radius > 1.0) {
        paint.color = color.withAlpha((alpha * 40).round());
        canvas.drawCircle(Offset(px, py), p.radius * 3.0, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CoursesParticlePainter old) => true;
}
