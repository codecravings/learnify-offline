import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/services/local_profile_service.dart';

// =============================================================================
// DSAGameScreen – INTERACTIVE SORTING & DATA STRUCTURE MINI-GAME
//
// Four-phase gamified lesson:
//   Phase 0  PLAY    – Sort array bars by dragging / watch algorithm animate
//   Phase 1  LEARN   – Educational cards about sorting, Big-O, data structures
//   Phase 2  QUIZ    – Multiple-choice questions
//   Phase 3  RESULTS – Stars, XP, celebration, Firestore save
//
// Design: Deep space dark + glassmorphism + neon green accents
// =============================================================================

// ─── Models ──────────────────────────────────────────────────────────────────

class _SortStep {
  final List<int> array;
  final int highlightA;
  final int highlightB;
  final String description;
  const _SortStep(this.array, this.highlightA, this.highlightB, this.description);
}

class _QuizQuestion {
  final String question;
  final List<String> options;
  final int correctIndex;
  final String explanation;
  const _QuizQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });
}

class _LearnCard {
  final String title;
  final IconData icon;
  final List<String> points;
  const _LearnCard({required this.title, required this.icon, required this.points});
}

// =============================================================================
// DSAGameScreen Widget
// =============================================================================

class DSAGameScreen extends StatefulWidget {
  final String lessonId;
  final String subjectId;
  final String chapterId;

  const DSAGameScreen({
    super.key,
    required this.lessonId,
    this.subjectId = 'dsa',
    this.chapterId = 'dsa_sorting',
  });

  @override
  State<DSAGameScreen> createState() => _DSAGameScreenState();
}

class _DSAGameScreenState extends State<DSAGameScreen>
    with TickerProviderStateMixin {
  // ── palette ──────────────────────────────────────────────────────────────
  static const Color _bg = Color(0xFF111827);
  static const Color _bgSecondary = Color(0xFF1F2937);
  static const Color _glassBorder = Color(0x33FFFFFF);
  static const Color _textPrimary = Color(0xFFF0F0F0);
  static const Color _textSecondary = Color(0xFFB0B0C8);
  static const Color _textTertiary = Color(0xFF6B6B8A);
  static const Color _green = Color(0xFF22C55E);
  static const Color _cyan = Color(0xFF3B82F6);
  static const Color _purple = Color(0xFF8B5CF6);
  static const Color _red = Color(0xFFEF4444);
  static const Color _gold = Color(0xFFF59E0B);
  static const Color _orange = Color(0xFFFF8C00);
  static const Color _accent = Color(0xFF22C55E);

  // ── phase ────────────────────────────────────────────────────────────────
  int _phase = 0; // 0=play, 1=learn, 2=quiz, 3=results

  // ── game state ───────────────────────────────────────────────────────────
  late List<int> _array;
  List<_SortStep> _sortSteps = [];
  int _currentStep = 0;
  bool _isAnimating = false;
  bool _userSorted = false;
  int _dragIndex = -1;
  int _userAttempts = 0;
  int _correctPlacements = 0;
  String _selectedAlgorithm = 'bubble';
  bool _showAlgorithmPicker = false;

  // Manual sort mode
  int _swapCount = 0;
  int _optimalSwaps = 0;

  // ── learn state ──────────────────────────────────────────────────────────
  final PageController _learnPageCtrl = PageController();
  int _learnPage = 0;

  // ── quiz state ───────────────────────────────────────────────────────────
  int _quizIndex = 0;
  int _quizCorrect = 0;
  int? _selectedAnswer;
  bool _answered = false;

  // ── animation controllers ────────────────────────────────────────────────
  late AnimationController _barAnimCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _celebrationCtrl;

  // ── data ──────────────────────────────────────────────────────────────────

  final _learnCards = const [
    _LearnCard(
      title: 'What is Sorting?',
      icon: Icons.sort_rounded,
      points: [
        'Sorting arranges elements in a specific order (ascending/descending).',
        'It\'s one of the most fundamental operations in computer science.',
        'Efficient sorting is crucial for search, databases, and data analysis.',
        'There are many algorithms, each with different trade-offs.',
      ],
    ),
    _LearnCard(
      title: 'Bubble Sort',
      icon: Icons.bubble_chart_rounded,
      points: [
        'Repeatedly swaps adjacent elements if they\'re in wrong order.',
        'Time Complexity: O(n²) average and worst case.',
        'Space Complexity: O(1) – sorts in place.',
        'Simple but inefficient for large datasets.',
        'Like bubbles rising – larger elements "bubble up" to the end.',
      ],
    ),
    _LearnCard(
      title: 'Selection Sort',
      icon: Icons.check_circle_outline_rounded,
      points: [
        'Finds the minimum element and places it at the beginning.',
        'Time Complexity: O(n²) in all cases.',
        'Makes at most O(n) swaps – good when writes are expensive.',
        'Not adaptive – performs same regardless of initial order.',
      ],
    ),
    _LearnCard(
      title: 'Big-O Notation',
      icon: Icons.trending_up_rounded,
      points: [
        'Describes how algorithm performance scales with input size.',
        'O(1) → Constant | O(log n) → Logarithmic | O(n) → Linear',
        'O(n log n) → Linearithmic | O(n²) → Quadratic',
        'Merge Sort & Quick Sort: O(n log n) average – much faster!',
        'Always aim for the lowest possible time complexity.',
      ],
    ),
    _LearnCard(
      title: 'Choosing the Right Sort',
      icon: Icons.psychology_rounded,
      points: [
        'Small arrays (< 50): Insertion sort is fast due to low overhead.',
        'Large arrays: Merge sort or Quick sort for O(n log n).',
        'Nearly sorted data: Insertion sort is O(n) best case!',
        'Memory constrained: Heap sort uses O(1) extra space.',
        'Stability matters? Use Merge sort (preserves equal element order).',
      ],
    ),
  ];

  final _quizQuestions = const [
    _QuizQuestion(
      question: 'What is the time complexity of Bubble Sort in the worst case?',
      options: ['O(n)', 'O(n log n)', 'O(n²)', 'O(log n)'],
      correctIndex: 2,
      explanation:
          'Bubble Sort compares every pair in each pass, leading to n × n = O(n²) comparisons in the worst case.',
    ),
    _QuizQuestion(
      question: 'Which sorting algorithm has the best average time complexity?',
      options: ['Bubble Sort', 'Selection Sort', 'Merge Sort', 'Insertion Sort'],
      correctIndex: 2,
      explanation:
          'Merge Sort has O(n log n) average time complexity, while the others are O(n²).',
    ),
    _QuizQuestion(
      question: 'What does "in-place sorting" mean?',
      options: [
        'Sorting without a computer',
        'Using O(1) extra memory',
        'Sorting in O(1) time',
        'Sorting only integers',
      ],
      correctIndex: 1,
      explanation:
          'In-place sorting means the algorithm uses only a constant amount of extra memory beyond the input array.',
    ),
    _QuizQuestion(
      question: 'In Selection Sort, what happens in each pass?',
      options: [
        'Adjacent elements are swapped',
        'The array is divided in half',
        'The minimum element is found and placed correctly',
        'Elements bubble up to the top',
      ],
      correctIndex: 2,
      explanation:
          'Selection Sort finds the minimum element from the unsorted portion and swaps it to the correct position.',
    ),
    _QuizQuestion(
      question: 'Which sorting algorithm is STABLE?',
      options: ['Selection Sort', 'Quick Sort', 'Merge Sort', 'Heap Sort'],
      correctIndex: 2,
      explanation:
          'A stable sort preserves the relative order of equal elements. Merge Sort is stable, while Quick Sort and Heap Sort are not.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _barAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _celebrationCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _generateArray();
  }

  @override
  void dispose() {
    _barAnimCtrl.dispose();
    _pulseCtrl.dispose();
    _celebrationCtrl.dispose();
    _learnPageCtrl.dispose();
    super.dispose();
  }

  void _generateArray() {
    final rng = Random();
    _array = List.generate(8, (_) => rng.nextInt(90) + 10);
    // Make sure array is NOT already sorted
    while (_isSorted(_array)) {
      _array.shuffle();
    }
    _optimalSwaps = _countInversions(List.of(_array));
    _swapCount = 0;
    _userSorted = false;
  }

  bool _isSorted(List<int> arr) {
    for (int i = 0; i < arr.length - 1; i++) {
      if (arr[i] > arr[i + 1]) return false;
    }
    return true;
  }

  int _countInversions(List<int> arr) {
    int count = 0;
    for (int i = 0; i < arr.length; i++) {
      for (int j = i + 1; j < arr.length; j++) {
        if (arr[i] > arr[j]) count++;
      }
    }
    return count;
  }

  // ── Sorting algorithms (generate steps) ──────────────────────────────────

  List<_SortStep> _bubbleSortSteps(List<int> arr) {
    final steps = <_SortStep>[];
    final a = List.of(arr);
    for (int i = 0; i < a.length - 1; i++) {
      for (int j = 0; j < a.length - i - 1; j++) {
        steps.add(_SortStep(List.of(a), j, j + 1, 'Comparing ${a[j]} and ${a[j + 1]}'));
        if (a[j] > a[j + 1]) {
          final tmp = a[j];
          a[j] = a[j + 1];
          a[j + 1] = tmp;
          steps.add(_SortStep(List.of(a), j, j + 1, 'Swapped! ${a[j + 1]} > ${a[j]}'));
        }
      }
    }
    steps.add(_SortStep(List.of(a), -1, -1, 'Array sorted!'));
    return steps;
  }

  List<_SortStep> _selectionSortSteps(List<int> arr) {
    final steps = <_SortStep>[];
    final a = List.of(arr);
    for (int i = 0; i < a.length - 1; i++) {
      int minIdx = i;
      for (int j = i + 1; j < a.length; j++) {
        steps.add(_SortStep(List.of(a), minIdx, j, 'Finding minimum: comparing ${a[minIdx]} and ${a[j]}'));
        if (a[j] < a[minIdx]) {
          minIdx = j;
        }
      }
      if (minIdx != i) {
        final tmp = a[i];
        a[i] = a[minIdx];
        a[minIdx] = tmp;
        steps.add(_SortStep(List.of(a), i, minIdx, 'Placed minimum ${a[i]} at position $i'));
      }
    }
    steps.add(_SortStep(List.of(a), -1, -1, 'Array sorted!'));
    return steps;
  }

  List<_SortStep> _insertionSortSteps(List<int> arr) {
    final steps = <_SortStep>[];
    final a = List.of(arr);
    for (int i = 1; i < a.length; i++) {
      int j = i;
      steps.add(_SortStep(List.of(a), i, j, 'Inserting ${a[i]} into sorted portion'));
      while (j > 0 && a[j - 1] > a[j]) {
        final tmp = a[j];
        a[j] = a[j - 1];
        a[j - 1] = tmp;
        steps.add(_SortStep(List.of(a), j - 1, j, 'Shifted ${a[j]} right'));
        j--;
      }
    }
    steps.add(_SortStep(List.of(a), -1, -1, 'Array sorted!'));
    return steps;
  }

  void _startAlgorithmAnimation() {
    List<_SortStep> steps;
    switch (_selectedAlgorithm) {
      case 'selection':
        steps = _selectionSortSteps(_array);
        break;
      case 'insertion':
        steps = _insertionSortSteps(_array);
        break;
      default:
        steps = _bubbleSortSteps(_array);
    }
    setState(() {
      _sortSteps = steps;
      _currentStep = 0;
      _isAnimating = true;
    });
    _animateNextStep();
  }

  void _animateNextStep() {
    if (_currentStep >= _sortSteps.length || !_isAnimating) {
      setState(() => _isAnimating = false);
      return;
    }
    setState(() {
      _array = List.of(_sortSteps[_currentStep].array);
      _currentStep++;
    });
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) _animateNextStep();
    });
  }

  void _swapElements(int i, int j) {
    if (i == j || _isAnimating || _userSorted) return;
    setState(() {
      final tmp = _array[i];
      _array[i] = _array[j];
      _array[j] = tmp;
      _swapCount++;
      _dragIndex = -1;
    });
    if (_isSorted(_array)) {
      setState(() {
        _userSorted = true;
        _correctPlacements = 8;
      });
    }
  }

  void _advanceToLearn() {
    setState(() => _phase = 1);
  }

  void _advanceToQuiz() {
    setState(() {
      _phase = 2;
      _quizIndex = 0;
      _quizCorrect = 0;
      _selectedAnswer = null;
      _answered = false;
    });
  }

  void _advanceToResults() {
    setState(() => _phase = 3);
    _celebrationCtrl.forward();
  }

  int get _totalXp {
    int xp = 50; // base
    xp += _quizCorrect * 30;
    if (_userSorted) xp += 40;
    if (_swapCount > 0 && _swapCount <= _optimalSwaps + 3) xp += 30; // efficiency bonus
    return xp;
  }

  int get _starCount {
    final pct = _quizCorrect / _quizQuestions.length;
    if (pct >= 0.8) return 3;
    if (pct >= 0.5) return 2;
    return 1;
  }

  Future<void> _saveProgress() async {
    try {
      await LocalProfileService.instance.addXP(_totalXp);
    } catch (_) {}
  }

  // ========================================================================
  // BUILD
  // ========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [_bg, _bgSecondary, _bg],
              ),
            ),
          ),
          // Ambient glow
          Positioned(
            top: -80,
            right: -60,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [_accent.withAlpha(30), Colors.transparent],
                ),
              ),
            ),
          ),
          // Main content
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                Expanded(child: _buildPhaseContent()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    final titles = ['SORT THE ARRAY', 'HOW SORTING WORKS', 'QUIZ TIME', 'RESULTS'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withAlpha(15),
                border: Border.all(color: _glassBorder),
              ),
              child: const Icon(Icons.arrow_back_rounded, color: _textPrimary, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              titles[_phase],
              style: GoogleFonts.orbitron(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _textPrimary,
                letterSpacing: 1.5,
              ),
            ),
          ),
          // Phase dots
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(4, (i) {
              final isActive = i == _phase;
              final isDone = i < _phase;
              return Container(
                width: isActive ? 20 : 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: isDone
                      ? _accent
                      : isActive
                          ? _accent.withAlpha(200)
                          : _textTertiary.withAlpha(60),
                  boxShadow: isActive
                      ? [BoxShadow(color: _accent.withAlpha(80), blurRadius: 8)]
                      : null,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildPhaseContent() {
    switch (_phase) {
      case 0:
        return _buildPlayPhase();
      case 1:
        return _buildLearnPhase();
      case 2:
        return _buildQuizPhase();
      case 3:
        return _buildResultsPhase();
      default:
        return const SizedBox.shrink();
    }
  }

  // ========================================================================
  // PHASE 0: PLAY – Interactive Sorting
  // ========================================================================

  Widget _buildPlayPhase() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const SizedBox(height: 8),
          // Instructions
          _glassCard(
            child: Column(
              children: [
                Text(
                  _isAnimating
                      ? '${_selectedAlgorithm.toUpperCase()} SORT'
                      : _userSorted
                          ? 'SORTED! WELL DONE!'
                          : 'Tap two bars to swap them, or watch an algorithm!',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _userSorted ? _green : _textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (_isAnimating && _currentStep > 0 && _currentStep <= _sortSteps.length)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      _sortSteps[_currentStep - 1].description,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 11,
                        color: _cyan,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms),

          const SizedBox(height: 16),

          // Array bars visualization
          Expanded(
            flex: 3,
            child: _buildArrayBars(),
          ),

          const SizedBox(height: 12),

          // Stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStatChip(Icons.swap_vert_rounded, 'Swaps: $_swapCount', _cyan),
              const SizedBox(width: 12),
              _buildStatChip(
                Icons.bar_chart_rounded,
                'Elements: ${_array.length}',
                _purple,
              ),
              if (_userSorted) ...[
                const SizedBox(width: 12),
                _buildStatChip(Icons.check_circle_rounded, 'Sorted!', _green),
              ],
            ],
          ),

          const SizedBox(height: 16),

          // Algorithm picker
          if (!_userSorted && !_isAnimating) ...[
            _buildAlgorithmPicker(),
            const SizedBox(height: 12),
          ],

          // Action buttons
          Row(
            children: [
              if (!_isAnimating && !_userSorted)
                Expanded(
                  child: _neonButton(
                    'VISUALIZE',
                    Icons.play_arrow_rounded,
                    _cyan,
                    onTap: _startAlgorithmAnimation,
                  ),
                ),
              if (!_isAnimating && !_userSorted) const SizedBox(width: 10),
              if (!_isAnimating && !_userSorted)
                Expanded(
                  child: _neonButton(
                    'SHUFFLE',
                    Icons.shuffle_rounded,
                    _orange,
                    onTap: () => setState(() => _generateArray()),
                  ),
                ),
              if (_isAnimating)
                Expanded(
                  child: _neonButton(
                    'STOP',
                    Icons.stop_rounded,
                    _red,
                    onTap: () => setState(() => _isAnimating = false),
                  ),
                ),
              if (_userSorted || (_isSorted(_array) && !_isAnimating))
                Expanded(
                  child: _neonButton(
                    'CONTINUE',
                    Icons.arrow_forward_rounded,
                    _green,
                    onTap: _advanceToLearn,
                  ),
                ),
            ],
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildArrayBars() {
    final maxVal = _array.reduce(max);
    final highlightA = _isAnimating && _currentStep > 0 && _currentStep <= _sortSteps.length
        ? _sortSteps[_currentStep - 1].highlightA
        : -1;
    final highlightB = _isAnimating && _currentStep > 0 && _currentStep <= _sortSteps.length
        ? _sortSteps[_currentStep - 1].highlightB
        : -1;

    return LayoutBuilder(
      builder: (context, constraints) {
        final barWidth = (constraints.maxWidth - (_array.length - 1) * 6) / _array.length;
        final maxHeight = constraints.maxHeight - 30;

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(_array.length, (i) {
            final val = _array[i];
            final heightPct = val / maxVal;
            final barHeight = maxHeight * heightPct;
            final isHighlighted = i == highlightA || i == highlightB;
            final isSelected = i == _dragIndex;
            final isSortedBar = _userSorted || (_isSorted(_array) && !_isAnimating);

            Color barColor;
            if (isSortedBar) {
              barColor = _green;
            } else if (isSelected) {
              barColor = _gold;
            } else if (isHighlighted) {
              barColor = _red;
            } else {
              barColor = _cyan;
            }

            return GestureDetector(
              onTap: () {
                if (_isAnimating || _userSorted) return;
                if (_dragIndex == -1) {
                  setState(() => _dragIndex = i);
                } else {
                  _swapElements(_dragIndex, i);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                width: barWidth.clamp(20, 60),
                height: barHeight.clamp(20, maxHeight),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      barColor,
                      barColor.withAlpha(150),
                    ],
                  ),
                  border: isSelected
                      ? Border.all(color: _gold, width: 2)
                      : Border.all(color: barColor.withAlpha(80), width: 0.5),
                  boxShadow: [
                    BoxShadow(
                      color: barColor.withAlpha(isHighlighted || isSelected ? 100 : 40),
                      blurRadius: isHighlighted || isSelected ? 16 : 8,
                      spreadRadius: isHighlighted || isSelected ? 2 : 0,
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  '$val',
                  style: GoogleFonts.orbitron(
                    fontSize: barWidth > 35 ? 11 : 9,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildAlgorithmPicker() {
    final algorithms = [
      {'id': 'bubble', 'name': 'Bubble', 'color': _cyan},
      {'id': 'selection', 'name': 'Selection', 'color': _purple},
      {'id': 'insertion', 'name': 'Insertion', 'color': _orange},
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: algorithms.map((algo) {
        final isSelected = _selectedAlgorithm == algo['id'];
        final color = algo['color'] as Color;
        return GestureDetector(
          onTap: () => setState(() => _selectedAlgorithm = algo['id'] as String),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: isSelected ? color.withAlpha(30) : Colors.white.withAlpha(8),
              border: Border.all(
                color: isSelected ? color : _glassBorder,
                width: isSelected ? 1.5 : 0.5,
              ),
              boxShadow: isSelected
                  ? [BoxShadow(color: color.withAlpha(40), blurRadius: 12)]
                  : null,
            ),
            child: Text(
              algo['name'] as String,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? color : _textTertiary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ========================================================================
  // PHASE 1: LEARN
  // ========================================================================

  Widget _buildLearnPhase() {
    return Column(
      children: [
        // Page indicator
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_learnCards.length, (i) {
              final isActive = i == _learnPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: isActive ? 24 : 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: isActive ? _accent : _textTertiary.withAlpha(60),
                  boxShadow: isActive
                      ? [BoxShadow(color: _accent.withAlpha(60), blurRadius: 8)]
                      : null,
                ),
              );
            }),
          ),
        ),

        Expanded(
          child: PageView.builder(
            controller: _learnPageCtrl,
            onPageChanged: (i) => setState(() => _learnPage = i),
            itemCount: _learnCards.length,
            itemBuilder: (context, i) {
              final card = _learnCards[i];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: _glassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: _accent.withAlpha(20),
                            ),
                            child: Icon(card.icon, color: _accent, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              card.title,
                              style: GoogleFonts.orbitron(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: _textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      ...card.points.asMap().entries.map((e) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                margin: const EdgeInsets.only(top: 6, right: 10),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _accent,
                                  boxShadow: [
                                    BoxShadow(
                                      color: _accent.withAlpha(60),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  e.value,
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: 14,
                                    color: _textSecondary,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ).animate().fadeIn(
                              delay: Duration(milliseconds: 200 + e.key * 100),
                              duration: 400.ms,
                            );
                      }),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        Padding(
          padding: const EdgeInsets.all(20),
          child: _neonButton(
            _learnPage < _learnCards.length - 1 ? 'NEXT' : 'START QUIZ',
            _learnPage < _learnCards.length - 1
                ? Icons.arrow_forward_rounded
                : Icons.quiz_rounded,
            _accent,
            onTap: () {
              if (_learnPage < _learnCards.length - 1) {
                _learnPageCtrl.nextPage(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutCubic,
                );
              } else {
                _advanceToQuiz();
              }
            },
          ),
        ),
      ],
    );
  }

  // ========================================================================
  // PHASE 2: QUIZ
  // ========================================================================

  Widget _buildQuizPhase() {
    final q = _quizQuestions[_quizIndex];

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Progress
          Row(
            children: [
              Text(
                'Question ${_quizIndex + 1}/${_quizQuestions.length}',
                style: GoogleFonts.orbitron(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _accent,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (_quizIndex + 1) / _quizQuestions.length,
                    minHeight: 6,
                    backgroundColor: Colors.white.withAlpha(15),
                    valueColor: AlwaysStoppedAnimation<Color>(_accent),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: _gold.withAlpha(20),
                  border: Border.all(color: _gold.withAlpha(60)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_rounded, size: 14, color: _gold),
                    const SizedBox(width: 4),
                    Text(
                      '$_quizCorrect',
                      style: GoogleFonts.orbitron(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _gold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Question
          _glassCard(
            child: Text(
              q.question,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: _textPrimary,
                height: 1.5,
              ),
            ),
          ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05),

          const SizedBox(height: 20),

          // Options
          ...q.options.asMap().entries.map((e) {
            final idx = e.key;
            final opt = e.value;
            final isSelected = _selectedAnswer == idx;
            final isCorrect = idx == q.correctIndex;

            Color optColor = Colors.white.withAlpha(8);
            Color borderColor = _glassBorder;
            Color textColor = _textPrimary;

            if (_answered) {
              if (isCorrect) {
                optColor = _green.withAlpha(25);
                borderColor = _green;
                textColor = _green;
              } else if (isSelected && !isCorrect) {
                optColor = _red.withAlpha(25);
                borderColor = _red;
                textColor = _red;
              }
            } else if (isSelected) {
              optColor = _accent.withAlpha(15);
              borderColor = _accent;
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: _answered
                    ? null
                    : () {
                        setState(() {
                          _selectedAnswer = idx;
                          _answered = true;
                          if (isCorrect) _quizCorrect++;
                        });
                      },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: optColor,
                    border: Border.all(color: borderColor, width: _answered && (isCorrect || isSelected) ? 1.5 : 0.5),
                    boxShadow: _answered && isCorrect
                        ? [BoxShadow(color: _green.withAlpha(30), blurRadius: 12)]
                        : null,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected ? borderColor.withAlpha(30) : Colors.white.withAlpha(8),
                          border: Border.all(color: borderColor.withAlpha(100)),
                        ),
                        alignment: Alignment.center,
                        child: _answered && isCorrect
                            ? Icon(Icons.check_rounded, size: 16, color: _green)
                            : _answered && isSelected && !isCorrect
                                ? Icon(Icons.close_rounded, size: 16, color: _red)
                                : Text(
                                    String.fromCharCode(65 + idx),
                                    style: GoogleFonts.orbitron(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: textColor,
                                    ),
                                  ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          opt,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: textColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ).animate().fadeIn(
                  delay: Duration(milliseconds: 100 + idx * 80),
                  duration: 400.ms,
                );
          }),

          if (_answered) ...[
            const SizedBox(height: 12),
            _glassCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    _selectedAnswer == q.correctIndex
                        ? Icons.lightbulb_rounded
                        : Icons.info_rounded,
                    color: _selectedAnswer == q.correctIndex ? _gold : _cyan,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      q.explanation,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 13,
                        color: _textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1),
            const Spacer(),
            _neonButton(
              _quizIndex < _quizQuestions.length - 1 ? 'NEXT QUESTION' : 'SEE RESULTS',
              Icons.arrow_forward_rounded,
              _accent,
              onTap: () {
                if (_quizIndex < _quizQuestions.length - 1) {
                  setState(() {
                    _quizIndex++;
                    _selectedAnswer = null;
                    _answered = false;
                  });
                } else {
                  _advanceToResults();
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  // ========================================================================
  // PHASE 3: RESULTS
  // ========================================================================

  Widget _buildResultsPhase() {
    _saveProgress();
    final pct = (_quizCorrect / _quizQuestions.length * 100).round();

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Stars
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (i) {
                final earned = i < _starCount;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(
                    earned ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: i == 1 ? 60 : 48,
                    color: earned ? _gold : _textTertiary.withAlpha(60),
                  ),
                )
                    .animate()
                    .fadeIn(delay: Duration(milliseconds: 300 + i * 200), duration: 500.ms)
                    .scale(
                      begin: const Offset(0.3, 0.3),
                      delay: Duration(milliseconds: 300 + i * 200),
                      duration: 600.ms,
                      curve: Curves.elasticOut,
                    );
              }),
            ),

            const SizedBox(height: 24),

            // Score
            Text(
              '$_quizCorrect / ${_quizQuestions.length}',
              style: GoogleFonts.orbitron(
                fontSize: 42,
                fontWeight: FontWeight.w900,
                color: _textPrimary,
              ),
            ).animate().fadeIn(delay: 600.ms, duration: 500.ms),

            Text(
              pct >= 80
                  ? 'Algorithm Master!'
                  : pct >= 50
                      ? 'Good Progress!'
                      : 'Keep Practicing!',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: _accent,
              ),
            ).animate().fadeIn(delay: 800.ms, duration: 500.ms),

            const SizedBox(height: 32),

            // XP card
            _glassCard(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _gold.withAlpha(20),
                      boxShadow: [
                        BoxShadow(color: _gold.withAlpha(40), blurRadius: 12),
                      ],
                    ),
                    child: const Icon(Icons.bolt_rounded, color: _gold, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '+$_totalXp XP',
                        style: GoogleFonts.orbitron(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: _gold,
                        ),
                      ),
                      Text(
                        'Experience Earned',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 12,
                          color: _textTertiary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 1000.ms, duration: 500.ms).slideY(begin: 0.15),

            if (_userSorted) ...[
              const SizedBox(height: 12),
              _glassCard(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.swap_vert_rounded, color: _cyan, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Sorted in $_swapCount swaps',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 13,
                        color: _textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (_swapCount <= _optimalSwaps + 3) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: _green.withAlpha(20),
                          border: Border.all(color: _green.withAlpha(60)),
                        ),
                        child: Text(
                          'EFFICIENT!',
                          style: GoogleFonts.orbitron(
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            color: _green,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ).animate().fadeIn(delay: 1200.ms, duration: 400.ms),
            ],

            const SizedBox(height: 32),

            _neonButton(
              'CONTINUE',
              Icons.arrow_forward_rounded,
              _accent,
              onTap: () => context.pop(),
            ).animate().fadeIn(delay: 1400.ms, duration: 500.ms),
          ],
        ),
      ),
    );
  }

  // ========================================================================
  // SHARED WIDGETS
  // ========================================================================

  Widget _glassCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white.withAlpha(10),
            border: Border.all(color: _glassBorder),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _neonButton(String label, IconData icon, Color color, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(colors: [color, color.withAlpha(180)]),
          boxShadow: [
            BoxShadow(color: color.withAlpha(60), blurRadius: 16, spreadRadius: -2),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.orbitron(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: color.withAlpha(15),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
