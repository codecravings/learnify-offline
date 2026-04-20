import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/ai/gemma_service.dart';
import '../../../core/services/local_profile_service.dart';

// =============================================================================
// CodingArenaScreen – PYTHON CODING MINI-GAME
//
// Four-phase gamified lesson:
//   Phase 0  PLAY    – Solve Python problems in a terminal-style code editor
//   Phase 1  LEARN   – AI reviews optimal solution + concept explanation
//   Phase 2  QUIZ    – 3 code-related MCQs
//   Phase 3  RESULTS – Stars, XP, code stats, celebration
//
// Anti-cheat: No paste, app-switch detection, FLAG_SECURE
// Evaluation: Groq API (Llama 3.3 70B)
// Design: Hacker terminal aesthetic – green-on-dark, matrix rain, scanlines
// =============================================================================

// ─── Problem model ──────────────────────────────────────────────────────────

enum ProblemType { outputPrediction, bugFix, writeFunction }

class _CodingProblem {
  final String title;
  final String description;
  final String code; // starter code or code to analyze
  final ProblemType type;
  final String expectedAnswer; // for output prediction
  final String hint;
  final int timeLimitSeconds;
  final String difficulty; // easy, medium, hard
  final String concept; // what concept this tests
  final String optimalSolution;

  const _CodingProblem({
    required this.title,
    required this.description,
    required this.code,
    required this.type,
    this.expectedAnswer = '',
    this.hint = '',
    this.timeLimitSeconds = 180,
    this.difficulty = 'easy',
    this.concept = '',
    this.optimalSolution = '',
  });
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
// CodingArenaScreen Widget
// =============================================================================

class CodingArenaScreen extends StatefulWidget {
  final String lessonId;
  final String subjectId;
  final String chapterId;

  const CodingArenaScreen({
    super.key,
    this.lessonId = 'coding_arena',
    this.subjectId = 'coding',
    this.chapterId = 'python_basics',
  });

  @override
  State<CodingArenaScreen> createState() => _CodingArenaScreenState();
}

class _CodingArenaScreenState extends State<CodingArenaScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // ── palette ──────────────────────────────────────────────────────────────
  static const Color _bg = Color(0xFF0A0E1A);
  static const Color _bgTerminal = Color(0xFF0D1117);
  static const Color _glassBorder = Color(0x33FFFFFF);
  static const Color _textPrimary = Color(0xFFF0F0F0);
  static const Color _textSecondary = Color(0xFFB0B0C8);
  static const Color _textTertiary = Color(0xFF6B6B8A);
  static const Color _green = Color(0xFF00FF88);
  static const Color _cyan = Color(0xFF00F5FF);
  static const Color _purple = Color(0xFF8B5CF6);
  static const Color _red = Color(0xFFEF4444);
  static const Color _gold = Color(0xFFF59E0B);
  static const Color _orange = Color(0xFFFF8C00);
  static const Color _accent = Color(0xFF00FF88); // terminal green

  // ── Local Gemma (on-device code evaluator) ──────────────────────────────
  final _gemma = GemmaService.instance;

  // ── phase management ────────────────────────────────────────────────────
  int _phase = 0; // 0=play, 1=learn, 2=quiz, 3=results

  // ── problems ────────────────────────────────────────────────────────────
  late List<_CodingProblem> _problems;
  int _currentProblem = 0;
  final _codeController = TextEditingController();
  final _codeFocus = FocusNode();
  final _answerController = TextEditingController(); // for output prediction

  // ── timer ───────────────────────────────────────────────────────────────
  Timer? _timer;
  int _secondsRemaining = 180;
  bool _timedOut = false;

  // ── scoring ─────────────────────────────────────────────────────────────
  int _totalScore = 0; // 0-100 per problem
  final List<int> _problemScores = [];
  final List<String> _userSolutions = [];
  final List<String> _aiReviews = [];
  int _linesWritten = 0;
  int _totalTimeSpent = 0;
  bool _isEvaluating = false;
  String _evaluationStatus = '';

  // ── anti-cheat ──────────────────────────────────────────────────────────
  int _appSwitchCount = 0;
  bool _showWarning = false;

  // ── quiz state ──────────────────────────────────────────────────────────
  late List<_QuizQuestion> _quizQuestions;
  int _quizIndex = 0;
  int _quizCorrect = 0;
  int? _selectedAnswer;
  bool _quizAnswered = false;

  // ── learn state ─────────────────────────────────────────────────────────
  late List<_LearnCard> _learnCards;
  final PageController _learnPageCtrl = PageController();
  int _learnPage = 0;

  // ── results ─────────────────────────────────────────────────────────────
  bool _resultsSaved = false;
  int _xpEarned = 0;
  int _stars = 0;

  // ── animation controllers ───────────────────────────────────────────────
  late AnimationController _matrixCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _scanlineCtrl;
  late AnimationController _cursorCtrl;
  late AnimationController _celebrationCtrl;

  // ── matrix rain data ────────────────────────────────────────────────────
  late List<_MatrixColumn> _matrixColumns;

  // ── celebration particles ───────────────────────────────────────────────
  List<_CodeParticle> _celebrationParticles = [];

  // ── typewriter ──────────────────────────────────────────────────────────
  String _typewriterText = '';
  int _typewriterIndex = 0;
  Timer? _typewriterTimer;

  // Platform channel for FLAG_SECURE
  static const _securityChannel = MethodChannel('com.vidyasetu/screen_security');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _enableScreenSecurity();

    _problems = _generateProblems();
    _quizQuestions = _generateQuiz();
    _learnCards = _generateLearnCards();

    _matrixCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 20))..repeat();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))
      ..repeat(reverse: true);
    _scanlineCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
    _cursorCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))
      ..repeat(reverse: true);
    _celebrationCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 3));

    // Init matrix rain
    _matrixColumns = List.generate(25, (i) => _MatrixColumn(
      x: i * 16.0,
      speed: 0.5 + Random().nextDouble() * 1.5,
      chars: List.generate(15, (_) => _randomCodeChar()),
      offset: Random().nextDouble(),
    ));

    // Start first problem
    _startProblem();
  }

  void _enableScreenSecurity() {
    try { _securityChannel.invokeMethod('enableSecure'); } catch (_) {}
  }

  void _disableScreenSecurity() {
    try { _securityChannel.invokeMethod('disableSecure'); } catch (_) {}
  }

  @override
  void dispose() {
    _disableScreenSecurity();
    WidgetsBinding.instance.removeObserver(this);
    _codeController.dispose();
    _codeFocus.dispose();
    _answerController.dispose();
    _learnPageCtrl.dispose();
    _matrixCtrl.dispose();
    _pulseCtrl.dispose();
    _scanlineCtrl.dispose();
    _cursorCtrl.dispose();
    _celebrationCtrl.dispose();
    super.dispose();
  }

  // ── App switch detection ────────────────────────────────────────────────
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_phase != 0) return; // only during coding
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _appSwitchCount++;
      if (_appSwitchCount == 1) {
        setState(() => _showWarning = true);
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => _showWarning = false);
        });
      } else if (_appSwitchCount >= 2) {
        // Auto-submit on second switch
        _submitSolution();
      }
    }
  }

  static String _randomCodeChar() {
    const chars = '{}()[];=<>+-*/&|!?:def return if else for while import print class self True False None 0 1';
    return chars[Random().nextInt(chars.length)];
  }

  // ── Problem generation ──────────────────────────────────────────────────

  List<_CodingProblem> _generateProblems() {
    final allProblems = <List<_CodingProblem>>[
      // ── Output Prediction (Easy) ──
      [
        const _CodingProblem(
          title: 'List Slicing',
          description: 'What will this code print?',
          code: 'nums = [10, 20, 30, 40, 50]\nprint(nums[1:4])',
          type: ProblemType.outputPrediction,
          expectedAnswer: '[20, 30, 40]',
          hint: 'Slicing is [start:end] where end is exclusive',
          timeLimitSeconds: 120,
          difficulty: 'easy',
          concept: 'List slicing',
        ),
        const _CodingProblem(
          title: 'String Methods',
          description: 'What will this code print?',
          code: 'text = "Hello World"\nprint(text.lower().count("l"))',
          type: ProblemType.outputPrediction,
          expectedAnswer: '3',
          hint: '.lower() converts to lowercase first',
          timeLimitSeconds: 120,
          difficulty: 'easy',
          concept: 'String methods',
        ),
        const _CodingProblem(
          title: 'Dictionary Access',
          description: 'What will this code print?',
          code: 'data = {"a": 1, "b": 2, "c": 3}\nprint(list(data.keys())[-1])',
          type: ProblemType.outputPrediction,
          expectedAnswer: 'c',
          hint: 'list() converts dict_keys to a list, [-1] gets last element',
          timeLimitSeconds: 120,
          difficulty: 'easy',
          concept: 'Dictionaries',
        ),
        const _CodingProblem(
          title: 'Loop Logic',
          description: 'What will this code print?',
          code: 'result = 0\nfor i in range(1, 6):\n    if i % 2 == 0:\n        result += i\nprint(result)',
          type: ProblemType.outputPrediction,
          expectedAnswer: '6',
          hint: 'Even numbers in range 1-5 are 2 and 4',
          timeLimitSeconds: 120,
          difficulty: 'easy',
          concept: 'Loops and conditionals',
        ),
      ],
      // ── Bug Fix (Medium) ──
      [
        const _CodingProblem(
          title: 'Fix the Fibonacci',
          description: 'This function should return the nth Fibonacci number, but it has a bug. Fix it.',
          code: 'def fibonacci(n):\n    if n <= 0:\n        return 0\n    if n == 1:\n        return 1\n    return fibonacci(n) + fibonacci(n - 1)',
          type: ProblemType.bugFix,
          expectedAnswer: 'fibonacci(n-1) + fibonacci(n-2)',
          hint: 'Look at the recursive call arguments carefully',
          timeLimitSeconds: 180,
          difficulty: 'medium',
          concept: 'Recursion',
          optimalSolution: 'def fibonacci(n):\n    if n <= 0:\n        return 0\n    if n == 1:\n        return 1\n    return fibonacci(n - 1) + fibonacci(n - 2)',
        ),
        const _CodingProblem(
          title: 'Fix the Palindrome Check',
          description: 'This function should check if a string is a palindrome, but it has a bug. Fix it.',
          code: 'def is_palindrome(s):\n    s = s.lower()\n    left = 0\n    right = len(s)\n    while left < right:\n        if s[left] != s[right]:\n            return False\n        left += 1\n        right -= 1\n    return True',
          type: ProblemType.bugFix,
          expectedAnswer: 'right = len(s) - 1',
          hint: 'Array indices start at 0, so the last index is...',
          timeLimitSeconds: 180,
          difficulty: 'medium',
          concept: 'String manipulation',
          optimalSolution: 'def is_palindrome(s):\n    s = s.lower()\n    left = 0\n    right = len(s) - 1\n    while left < right:\n        if s[left] != s[right]:\n            return False\n        left += 1\n        right -= 1\n    return True',
        ),
        const _CodingProblem(
          title: 'Fix the Binary Search',
          description: 'This binary search has a subtle bug. Find and fix it.',
          code: 'def binary_search(arr, target):\n    low, high = 0, len(arr)\n    while low <= high:\n        mid = (low + high) // 2\n        if arr[mid] == target:\n            return mid\n        elif arr[mid] < target:\n            low = mid\n        else:\n            high = mid - 1\n    return -1',
          type: ProblemType.bugFix,
          expectedAnswer: 'high = len(arr) - 1 and low = mid + 1',
          hint: 'Two bugs: initial high value and low update',
          timeLimitSeconds: 240,
          difficulty: 'medium',
          concept: 'Binary search',
          optimalSolution: 'def binary_search(arr, target):\n    low, high = 0, len(arr) - 1\n    while low <= high:\n        mid = (low + high) // 2\n        if arr[mid] == target:\n            return mid\n        elif arr[mid] < target:\n            low = mid + 1\n        else:\n            high = mid - 1\n    return -1',
        ),
      ],
      // ── Write Function (Hard) ──
      [
        const _CodingProblem(
          title: 'Two Sum',
          description: 'Write a function that takes a list of numbers and a target, and returns the indices of two numbers that add up to the target.\n\nExample: two_sum([2, 7, 11, 15], 9) → [0, 1]',
          code: 'def two_sum(nums, target):\n    # Your code here\n    pass',
          type: ProblemType.writeFunction,
          timeLimitSeconds: 300,
          difficulty: 'hard',
          concept: 'Hash maps / dictionaries',
          optimalSolution: 'def two_sum(nums, target):\n    seen = {}\n    for i, num in enumerate(nums):\n        complement = target - num\n        if complement in seen:\n            return [seen[complement], i]\n        seen[num] = i\n    return []',
        ),
        const _CodingProblem(
          title: 'Flatten Nested List',
          description: 'Write a function that flattens a nested list.\n\nExample: flatten([1, [2, [3, 4], 5], 6]) → [1, 2, 3, 4, 5, 6]',
          code: 'def flatten(lst):\n    # Your code here\n    pass',
          type: ProblemType.writeFunction,
          timeLimitSeconds: 300,
          difficulty: 'hard',
          concept: 'Recursion with lists',
          optimalSolution: 'def flatten(lst):\n    result = []\n    for item in lst:\n        if isinstance(item, list):\n            result.extend(flatten(item))\n        else:\n            result.append(item)\n    return result',
        ),
        const _CodingProblem(
          title: 'Count Words',
          description: 'Write a function that returns a dict of word frequencies in a string (case-insensitive).\n\nExample: count_words("the cat and the dog") → {"the": 2, "cat": 1, "and": 1, "dog": 1}',
          code: 'def count_words(text):\n    # Your code here\n    pass',
          type: ProblemType.writeFunction,
          timeLimitSeconds: 240,
          difficulty: 'hard',
          concept: 'Dictionaries and strings',
          optimalSolution: 'def count_words(text):\n    words = text.lower().split()\n    freq = {}\n    for word in words:\n        freq[word] = freq.get(word, 0) + 1\n    return freq',
        ),
      ],
    ];

    final rng = Random();
    return [
      allProblems[0][rng.nextInt(allProblems[0].length)],
      allProblems[1][rng.nextInt(allProblems[1].length)],
      allProblems[2][rng.nextInt(allProblems[2].length)],
    ];
  }

  List<_QuizQuestion> _generateQuiz() {
    return const [
      _QuizQuestion(
        question: 'What is the time complexity of looking up a key in a Python dictionary?',
        options: ['O(n)', 'O(1) average', 'O(log n)', 'O(n²)'],
        correctIndex: 1,
        explanation: 'Python dicts use hash tables, giving O(1) average lookup. Worst case is O(n) due to hash collisions.',
      ),
      _QuizQuestion(
        question: 'What does "enumerate(list)" return?',
        options: [
          'The length of the list',
          'A reversed list',
          'Pairs of (index, value)',
          'Only the indices',
        ],
        correctIndex: 2,
        explanation: 'enumerate() returns an iterator of tuples: (index, element). Very useful in for loops when you need both.',
      ),
      _QuizQuestion(
        question: 'What happens when you slice beyond a list\'s length: [1,2,3][1:100]?',
        options: [
          'IndexError',
          'Returns [2, 3]',
          'Returns [2, 3] + 97 Nones',
          'Returns empty list',
        ],
        correctIndex: 1,
        explanation: 'Python slicing never raises IndexError — it gracefully stops at the end of the list.',
      ),
    ];
  }

  List<_LearnCard> _generateLearnCards() {
    return [
      _LearnCard(
        title: 'Your Solution Review',
        icon: Icons.rate_review_rounded,
        points: _aiReviews.isNotEmpty
            ? _aiReviews.take(3).map((r) => r.length > 120 ? '${r.substring(0, 120)}...' : r).toList()
            : ['Submit your solutions to get AI-powered code review!'],
      ),
      const _LearnCard(
        title: 'Python Best Practices',
        icon: Icons.auto_awesome_rounded,
        points: [
          'Use list comprehensions for concise filtering: [x for x in lst if x > 0]',
          'Prefer dict.get(key, default) over checking "if key in dict"',
          'Use enumerate() instead of range(len()) when you need indices',
          'f-strings are fastest for string formatting: f"Hello {name}"',
        ],
      ),
      const _LearnCard(
        title: 'Common Pitfalls',
        icon: Icons.warning_amber_rounded,
        points: [
          'Off-by-one errors: range(n) goes 0 to n-1, not n',
          'Mutable default args: def f(lst=[]) shares the same list across calls',
          'Integer division: 7/2=3.5 but 7//2=3 in Python 3',
          'Shallow vs deep copy: list.copy() only copies one level deep',
        ],
      ),
    ];
  }

  // ── Problem flow ────────────────────────────────────────────────────────

  void _startProblem() {
    final problem = _problems[_currentProblem];
    _secondsRemaining = problem.timeLimitSeconds;
    _timedOut = false;

    if (problem.type == ProblemType.bugFix) {
      _codeController.text = problem.code;
    } else if (problem.type == ProblemType.writeFunction) {
      _codeController.text = problem.code;
    } else {
      _codeController.clear();
      _answerController.clear();
    }

    // Typewriter effect for problem description
    _typewriterText = '';
    _typewriterIndex = 0;
    final fullText = '> ${problem.title}\n\n${problem.description}';
    _typewriterTimer?.cancel();
    _typewriterTimer = Timer.periodic(const Duration(milliseconds: 25), (t) {
      if (_typewriterIndex < fullText.length) {
        setState(() {
          _typewriterText = fullText.substring(0, _typewriterIndex + 1);
          _typewriterIndex++;
        });
      } else {
        t.cancel();
      }
    });

    // Start timer
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        t.cancel();
        setState(() => _timedOut = true);
        _submitSolution();
      }
    });
  }

  Future<void> _submitSolution() async {
    _timer?.cancel();
    final problem = _problems[_currentProblem];
    final timeSpent = problem.timeLimitSeconds - _secondsRemaining;
    _totalTimeSpent += timeSpent;

    final userCode = problem.type == ProblemType.outputPrediction
        ? _answerController.text.trim()
        : _codeController.text.trim();

    _userSolutions.add(userCode);
    _linesWritten += userCode.split('\n').length;

    setState(() {
      _isEvaluating = true;
      _evaluationStatus = 'COMPILING...';
    });

    // Simulate compilation phases
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) setState(() => _evaluationStatus = 'RUNNING TESTS...');
    await Future.delayed(const Duration(milliseconds: 400));
    if (mounted) setState(() => _evaluationStatus = 'EVALUATING...');

    // Call Groq for evaluation
    int score = 0;
    String review = 'Could not evaluate — scored based on submission.';

    try {
      final prompt = _buildEvalPrompt(problem, userCode);
      final content = await _gemma.generate(
        systemPrompt:
            'You are a Python code evaluator. Respond ONLY with valid JSON: {"score": 0-100, "review": "one sentence"}.',
        userPrompt: prompt,
        maxTokens: 500,
      );

      final jsonStr = content.contains('{')
          ? content.substring(
              content.indexOf('{'), content.lastIndexOf('}') + 1)
          : '{"score": 50, "review": "Submission received."}';
      final parsed = jsonDecode(jsonStr);
      score = (parsed['score'] as num?)?.toInt() ?? 50;
      review = parsed['review'] as String? ?? 'Evaluated successfully.';
    } catch (e) {
      debugPrint('[CODING] Gemma eval error: $e');
      // Fallback scoring
      if (problem.type == ProblemType.outputPrediction) {
        score = userCode.trim().toLowerCase() == problem.expectedAnswer.trim().toLowerCase() ? 100 : 20;
        review = score == 100 ? 'Correct!' : 'Expected: ${problem.expectedAnswer}';
      } else if (userCode.length > 10) {
        score = 40 + min(30, userCode.split('\n').length * 5);
        review = 'Code submitted. Unable to verify with AI — scored based on length and structure.';
      } else {
        score = _timedOut ? 10 : 20;
        review = _timedOut ? 'Time ran out.' : 'Minimal submission detected.';
      }
    }

    _problemScores.add(score);
    _aiReviews.add('${problem.title}: $review');
    _totalScore += score;

    if (mounted) {
      setState(() {
        _isEvaluating = false;
        _evaluationStatus = '';
      });
    }

    // Next problem or move to learn phase
    if (_currentProblem < _problems.length - 1) {
      setState(() => _currentProblem++);
      _startProblem();
    } else {
      _learnCards = _generateLearnCards(); // refresh with AI reviews
      _transitionToPhase(1);
    }
  }

  String _buildEvalPrompt(_CodingProblem problem, String userCode) {
    switch (problem.type) {
      case ProblemType.outputPrediction:
        return '''
Evaluate this Python output prediction.
Code:
```python
${problem.code}
```
Student's answer: "$userCode"
Correct answer: "${problem.expectedAnswer}"

Respond with JSON: {"score": 0-100, "review": "one sentence feedback"}
Score 100 if correct, 0 if wrong. Be lenient with whitespace/formatting.''';

      case ProblemType.bugFix:
        return '''
Evaluate this Python bug fix.
Original buggy code:
```python
${problem.code}
```
Student's fixed code:
```python
$userCode
```
The bug was: ${problem.expectedAnswer}
Optimal solution:
```python
${problem.optimalSolution}
```

Respond with JSON: {"score": 0-100, "review": "one sentence feedback"}
Score based on: did they fix the bug? Is the logic correct? Partial credit for identifying the bug.''';

      case ProblemType.writeFunction:
        return '''
Evaluate this Python function implementation.
Task: ${problem.description}
Student's code:
```python
$userCode
```
Optimal solution:
```python
${problem.optimalSolution}
```

Respond with JSON: {"score": 0-100, "review": "one sentence feedback"}
Score based on: correctness, efficiency, edge cases. Give partial credit for correct approach even with minor issues.''';
    }
  }

  void _transitionToPhase(int phase) {
    setState(() => _phase = phase);
    if (phase == 3) {
      _calculateResults();
      _startCelebration();
    }
  }

  void _calculateResults() {
    final avgScore = _problemScores.isEmpty ? 0 : _totalScore ~/ _problems.length;
    _stars = avgScore >= 85 ? 3 : avgScore >= 60 ? 2 : avgScore >= 30 ? 1 : 0;
    _xpEarned = 25 + (_stars * 15) + (_quizCorrect * 10);
  }

  void _startCelebration() {
    final rng = Random();
    const codeChars = ['{', '}', '(', ')', '[', ']', '<', '>', '/', '*', '+', '=', ';', ':', '#', 'def', 'if', '0', '1'];
    _celebrationParticles = List.generate(60, (i) {
      return _CodeParticle(
        x: rng.nextDouble() * 400,
        y: 800 + rng.nextDouble() * 200,
        vx: (rng.nextDouble() - 0.5) * 4,
        vy: -(3 + rng.nextDouble() * 6),
        char: codeChars[rng.nextInt(codeChars.length)],
        color: [_green, _cyan, _purple, _gold][rng.nextInt(4)],
        size: 10 + rng.nextDouble() * 14,
        rotation: rng.nextDouble() * 6.28,
        rotationSpeed: (rng.nextDouble() - 0.5) * 3,
      );
    });
    _celebrationCtrl.forward();
  }

  Future<void> _saveProgressAndExit() async {
    if (_resultsSaved) {
      if (mounted) context.pop();
      return;
    }
    setState(() => _resultsSaved = true);

    try {
      await LocalProfileService.instance.addXP(_xpEarned);
    } catch (_) {}

    if (mounted) context.pop();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          // Matrix rain background
          AnimatedBuilder(
            animation: _matrixCtrl,
            builder: (context, _) => CustomPaint(
              size: MediaQuery.of(context).size,
              painter: _MatrixRainPainter(
                columns: _matrixColumns,
                progress: _matrixCtrl.value,
                opacity: _phase == 0 ? 0.15 : 0.06,
              ),
            ),
          ),
          // Scanline overlay
          AnimatedBuilder(
            animation: _scanlineCtrl,
            builder: (context, _) => CustomPaint(
              size: MediaQuery.of(context).size,
              painter: _ScanlinePainter(progress: _scanlineCtrl.value),
            ),
          ),
          // Ambient glows
          _buildAmbientGlows(),
          // Content
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                Expanded(child: _buildPhaseContent()),
              ],
            ),
          ),
          // Anti-cheat warning
          if (_showWarning) _buildCheatWarning(),
          // Evaluation overlay
          if (_isEvaluating) _buildEvaluationOverlay(),
          // Celebration
          if (_phase == 3)
            AnimatedBuilder(
              animation: _celebrationCtrl,
              builder: (context, _) => CustomPaint(
                size: MediaQuery.of(context).size,
                painter: _CodeCelebrationPainter(
                  particles: _celebrationParticles,
                  progress: _celebrationCtrl.value,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAmbientGlows() {
    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (context, _) {
        final pulse = _pulseCtrl.value;
        return Stack(
          children: [
            Positioned(
              top: -80, right: -60,
              child: Container(
                width: 200 + pulse * 40, height: 200 + pulse * 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    _green.withAlpha((12 + pulse * 8).round()),
                    _green.withAlpha(0),
                  ]),
                ),
              ),
            ),
            Positioned(
              bottom: -100, left: -80,
              child: Container(
                width: 250 + pulse * 30, height: 250 + pulse * 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    _purple.withAlpha((8 + pulse * 8).round()),
                    _purple.withAlpha(0),
                  ]),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Top Bar ─────────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withAlpha(8),
                border: Border.all(color: _glassBorder, width: 0.5),
              ),
              child: const Icon(Icons.arrow_back_rounded, color: _green, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [_green, _cyan],
                  ).createShader(bounds),
                  child: Text('CODING ARENA',
                    style: GoogleFonts.orbitron(
                      fontSize: 14, fontWeight: FontWeight.w800,
                      color: Colors.white, letterSpacing: 2,
                    ),
                  ),
                ),
                Text(
                  _phase == 0
                      ? 'Problem ${_currentProblem + 1}/${_problems.length} • ${_problems[_currentProblem].difficulty.toUpperCase()}'
                      : _phase == 1 ? 'CODE REVIEW' : _phase == 2 ? 'KNOWLEDGE CHECK' : 'RESULTS',
                  style: GoogleFonts.spaceGrotesk(fontSize: 10, color: _textTertiary),
                ),
              ],
            ),
          ),
          if (_phase == 0) _buildTimer(),
          // Phase dots
          Row(
            children: List.generate(4, (i) => Container(
              width: 8, height: 8,
              margin: const EdgeInsets.only(left: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i <= _phase ? _green : _glassBorder,
                boxShadow: i <= _phase ? [BoxShadow(color: _green.withAlpha(80), blurRadius: 6)] : null,
              ),
            )),
          ),
        ],
      ),
    );
  }

  Widget _buildTimer() {
    final mins = _secondsRemaining ~/ 60;
    final secs = _secondsRemaining % 60;
    final isLow = _secondsRemaining < 30;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: isLow ? _red.withAlpha(20) : _green.withAlpha(15),
        border: Border.all(color: isLow ? _red.withAlpha(80) : _green.withAlpha(40)),
      ),
      child: Text(
        '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}',
        style: GoogleFonts.orbitron(
          fontSize: 12, fontWeight: FontWeight.w700,
          color: isLow ? _red : _green,
        ),
      ),
    );
  }

  // ── Phase Content ───────────────────────────────────────────────────────

  Widget _buildPhaseContent() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(anim),
          child: child,
        ),
      ),
      child: switch (_phase) {
        0 => _buildPlayPhase(),
        1 => _buildLearnPhase(),
        2 => _buildQuizPhase(),
        3 => _buildResultsPhase(),
        _ => const SizedBox(),
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PHASE 0: PLAY — Code Editor
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildPlayPhase() {
    final problem = _problems[_currentProblem];

    return Padding(
      key: ValueKey('play_$_currentProblem'),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          const SizedBox(height: 8),
          // Problem description with typewriter
          _buildProblemCard(problem),
          const SizedBox(height: 10),
          // Code display (for output prediction)
          if (problem.type == ProblemType.outputPrediction) ...[
            _buildCodeDisplay(problem.code),
            const SizedBox(height: 10),
            _buildAnswerInput(),
          ] else ...[
            // Code editor
            Expanded(child: _buildCodeEditor()),
          ],
          const SizedBox(height: 10),
          _buildSubmitBar(problem),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildProblemCard(_CodingProblem problem) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _bgTerminal,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _green.withAlpha(30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: _difficultyColor(problem.difficulty).withAlpha(20),
                  border: Border.all(color: _difficultyColor(problem.difficulty).withAlpha(60)),
                ),
                child: Text(
                  problem.difficulty.toUpperCase(),
                  style: GoogleFonts.orbitron(
                    fontSize: 8, fontWeight: FontWeight.w700,
                    color: _difficultyColor(problem.difficulty),
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: _purple.withAlpha(15),
                  border: Border.all(color: _purple.withAlpha(40)),
                ),
                child: Text(
                  problem.type == ProblemType.outputPrediction ? 'OUTPUT' :
                  problem.type == ProblemType.bugFix ? 'BUG FIX' : 'WRITE',
                  style: GoogleFonts.orbitron(
                    fontSize: 8, fontWeight: FontWeight.w700, color: _purple, letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Typewriter text
          AnimatedBuilder(
            animation: _cursorCtrl,
            builder: (context, _) => RichText(
              text: TextSpan(
                style: GoogleFonts.firaCode(fontSize: 12, color: _green, height: 1.5),
                children: [
                  TextSpan(text: _typewriterText),
                  if (_typewriterIndex < ('> ${problem.title}\n\n${problem.description}').length)
                    TextSpan(
                      text: '█',
                      style: TextStyle(color: _green.withAlpha((_cursorCtrl.value * 255).round())),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Color _difficultyColor(String d) => switch (d) {
    'easy' => _green,
    'medium' => _gold,
    'hard' => _red,
    _ => _cyan,
  };

  Widget _buildCodeDisplay(String code) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _cyan.withAlpha(25)),
      ),
      child: SelectableText.rich(
        TextSpan(
          style: GoogleFonts.firaCode(fontSize: 13, color: _textPrimary, height: 1.6),
          children: _highlightPython(code),
        ),
      ),
    ).animate().fadeIn(delay: 200.ms, duration: 300.ms);
  }

  List<TextSpan> _highlightPython(String code) {
    // Simple Python syntax highlighting
    final spans = <TextSpan>[];
    final keywords = {'def', 'return', 'if', 'else', 'elif', 'for', 'while', 'in', 'import', 'from', 'class', 'True', 'False', 'None', 'and', 'or', 'not', 'print', 'range', 'len', 'list', 'dict', 'set', 'str', 'int', 'float'};
    final words = code.split(RegExp(r'(\s+|(?=[^\w])|(?<=[^\w]))'));

    for (final word in words) {
      if (keywords.contains(word)) {
        spans.add(TextSpan(text: word, style: TextStyle(color: _purple, fontWeight: FontWeight.w600)));
      } else if (RegExp(r'^\d+$').hasMatch(word)) {
        spans.add(TextSpan(text: word, style: const TextStyle(color: _gold)));
      } else if (word.startsWith('#')) {
        spans.add(TextSpan(text: word, style: TextStyle(color: _textTertiary)));
      } else if (word == '"' || word == "'") {
        spans.add(TextSpan(text: word, style: const TextStyle(color: _green)));
      } else {
        spans.add(TextSpan(text: word));
      }
    }
    return spans;
  }

  Widget _buildAnswerInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: _bgTerminal,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _green.withAlpha(40)),
      ),
      child: Row(
        children: [
          Text('>>> ', style: GoogleFonts.firaCode(fontSize: 14, color: _green, fontWeight: FontWeight.w700)),
          Expanded(
            child: TextField(
              controller: _answerController,
              style: GoogleFonts.firaCode(fontSize: 14, color: _textPrimary),
              decoration: InputDecoration(
                hintText: 'Type the output...',
                hintStyle: GoogleFonts.firaCode(fontSize: 13, color: _textTertiary),
                border: InputBorder.none,
              ),
              // Anti-cheat: no paste
              inputFormatters: [_NoPasteFormatter()],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 400.ms, duration: 300.ms);
  }

  Widget _buildCodeEditor() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _green.withAlpha(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Editor header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _bg.withAlpha(200),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              border: Border(bottom: BorderSide(color: _glassBorder)),
            ),
            child: Row(
              children: [
                // Traffic light dots
                for (final c in [_red, _gold, _green])
                  Container(
                    width: 10, height: 10,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(shape: BoxShape.circle, color: c.withAlpha(180)),
                  ),
                const SizedBox(width: 8),
                Text('solution.py', style: GoogleFonts.firaCode(fontSize: 11, color: _textTertiary)),
                const Spacer(),
                Text('Python', style: GoogleFonts.spaceGrotesk(fontSize: 10, color: _textTertiary)),
              ],
            ),
          ),
          // Code area
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _codeController,
                focusNode: _codeFocus,
                maxLines: null,
                expands: true,
                style: GoogleFonts.firaCode(fontSize: 13, color: _textPrimary, height: 1.6),
                decoration: InputDecoration(
                  hintText: '# Write your Python code here...',
                  hintStyle: GoogleFonts.firaCode(fontSize: 12, color: _textTertiary),
                  border: InputBorder.none,
                  isCollapsed: true,
                ),
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                // Anti-cheat: disable paste
                inputFormatters: [_NoPasteFormatter()],
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms, duration: 300.ms);
  }

  Widget _buildSubmitBar(_CodingProblem problem) {
    return Row(
      children: [
        // Hint button
        GestureDetector(
          onTap: () => _showHint(problem.hint),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: _gold.withAlpha(12),
              border: Border.all(color: _gold.withAlpha(40)),
            ),
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline_rounded, color: _gold, size: 16),
                const SizedBox(width: 6),
                Text('HINT', style: GoogleFonts.orbitron(fontSize: 10, color: _gold, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Submit button
        Expanded(
          child: GestureDetector(
            onTap: _isEvaluating ? null : _submitSolution,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: const LinearGradient(colors: [_green, _cyan]),
                boxShadow: [BoxShadow(color: _green.withAlpha(40), blurRadius: 16, offset: const Offset(0, 4))],
              ),
              alignment: Alignment.center,
              child: Text(
                _currentProblem < _problems.length - 1 ? 'SUBMIT & NEXT' : 'SUBMIT FINAL',
                style: GoogleFonts.orbitron(
                  fontSize: 12, fontWeight: FontWeight.w800,
                  color: _bg, letterSpacing: 1.5,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showHint(String hint) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _bg.withAlpha(250),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(top: BorderSide(color: _gold.withAlpha(60), width: 1.5)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(borderRadius: BorderRadius.circular(2), color: _glassBorder)),
            const SizedBox(height: 16),
            Icon(Icons.lightbulb_rounded, color: _gold, size: 32),
            const SizedBox(height: 12),
            Text(hint, style: GoogleFonts.spaceGrotesk(fontSize: 14, color: _textPrimary, height: 1.5), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text('-10 XP penalty for using hint', style: GoogleFonts.spaceGrotesk(fontSize: 11, color: _textTertiary)),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PHASE 1: LEARN — Code Review
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildLearnPhase() {
    return Column(
      key: const ValueKey('learn'),
      children: [
        const SizedBox(height: 12),
        // Score summary
        _buildScoreSummary(),
        const SizedBox(height: 12),
        // Learn cards
        Expanded(
          child: PageView.builder(
            controller: _learnPageCtrl,
            itemCount: _learnCards.length,
            onPageChanged: (i) => setState(() => _learnPage = i),
            itemBuilder: (_, i) => _buildLearnCard(_learnCards[i], i),
          ),
        ),
        // Page dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_learnCards.length, (i) => Container(
            width: i == _learnPage ? 20 : 8, height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: i == _learnPage ? _green : _glassBorder,
            ),
          )),
        ),
        const SizedBox(height: 12),
        // Continue button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GestureDetector(
            onTap: () => _transitionToPhase(2),
            child: Container(
              width: double.infinity, height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(colors: [_green, _cyan]),
              ),
              alignment: Alignment.center,
              child: Text('CONTINUE TO QUIZ',
                style: GoogleFonts.orbitron(fontSize: 12, fontWeight: FontWeight.w800, color: _bg, letterSpacing: 1.5)),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildScoreSummary() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(6),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _green.withAlpha(30)),
            ),
            child: Row(
              children: _problemScores.asMap().entries.map((e) {
                final score = e.value;
                final color = score >= 80 ? _green : score >= 50 ? _gold : _red;
                return Expanded(
                  child: Column(
                    children: [
                      Text('P${e.key + 1}', style: GoogleFonts.orbitron(fontSize: 9, color: _textTertiary)),
                      const SizedBox(height: 4),
                      Text('$score', style: GoogleFonts.orbitron(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
                      Text('/100', style: GoogleFonts.spaceGrotesk(fontSize: 9, color: _textTertiary)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildLearnCard(_LearnCard card, int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(6),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _glassBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(card.icon, color: _green, size: 24),
                    const SizedBox(width: 10),
                    Text(card.title, style: GoogleFonts.orbitron(fontSize: 13, fontWeight: FontWeight.w700, color: _textPrimary)),
                  ],
                ),
                const SizedBox(height: 16),
                ...card.points.map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 6, height: 6,
                        margin: const EdgeInsets.only(top: 6, right: 10),
                        decoration: BoxDecoration(shape: BoxShape.circle, color: _green),
                      ),
                      Expanded(child: Text(p, style: GoogleFonts.spaceGrotesk(fontSize: 13, color: _textSecondary, height: 1.5))),
                    ],
                  ),
                )),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PHASE 2: QUIZ
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildQuizPhase() {
    final q = _quizQuestions[_quizIndex];
    return Padding(
      key: ValueKey('quiz_$_quizIndex'),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          // Question counter
          Text('QUESTION ${_quizIndex + 1}/${_quizQuestions.length}',
            style: GoogleFonts.orbitron(fontSize: 10, color: _textTertiary, letterSpacing: 2)),
          const SizedBox(height: 12),
          // Question
          Text(q.question, style: GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.w600, color: _textPrimary, height: 1.5)),
          const SizedBox(height: 20),
          // Options
          ...q.options.asMap().entries.map((e) {
            final isSelected = _selectedAnswer == e.key;
            final isCorrect = e.key == q.correctIndex;
            final showResult = _quizAnswered;

            Color borderColor = _glassBorder;
            Color bgColor = Colors.white.withAlpha(4);
            if (showResult && isCorrect) {
              borderColor = _green.withAlpha(150);
              bgColor = _green.withAlpha(15);
            } else if (showResult && isSelected && !isCorrect) {
              borderColor = _red.withAlpha(150);
              bgColor = _red.withAlpha(15);
            } else if (isSelected) {
              borderColor = _cyan.withAlpha(100);
              bgColor = _cyan.withAlpha(10);
            }

            return GestureDetector(
              onTap: _quizAnswered ? null : () {
                setState(() {
                  _selectedAnswer = e.key;
                  _quizAnswered = true;
                  if (isCorrect) _quizCorrect++;
                });
              },
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: bgColor,
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected ? borderColor.withAlpha(30) : Colors.white.withAlpha(6),
                        border: Border.all(color: borderColor),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        String.fromCharCode(65 + e.key),
                        style: GoogleFonts.orbitron(fontSize: 11, fontWeight: FontWeight.w700, color: isSelected ? borderColor : _textTertiary),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(e.value, style: GoogleFonts.spaceGrotesk(fontSize: 14, color: _textPrimary))),
                    if (showResult && isCorrect) const Icon(Icons.check_circle_rounded, color: _green, size: 20),
                    if (showResult && isSelected && !isCorrect) const Icon(Icons.cancel_rounded, color: _red, size: 20),
                  ],
                ),
              ),
            ).animate().fadeIn(delay: (100 * e.key).ms, duration: 300.ms).slideX(begin: 0.05);
          }),
          // Explanation
          if (_quizAnswered) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: _cyan.withAlpha(8),
                border: Border.all(color: _cyan.withAlpha(30)),
              ),
              child: Text(q.explanation, style: GoogleFonts.spaceGrotesk(fontSize: 12, color: _textSecondary, height: 1.5)),
            ).animate().fadeIn(duration: 300.ms),
          ],
          const Spacer(),
          if (_quizAnswered)
            GestureDetector(
              onTap: () {
                if (_quizIndex < _quizQuestions.length - 1) {
                  setState(() {
                    _quizIndex++;
                    _selectedAnswer = null;
                    _quizAnswered = false;
                  });
                } else {
                  _transitionToPhase(3);
                }
              },
              child: Container(
                width: double.infinity, height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: const LinearGradient(colors: [_green, _cyan]),
                ),
                alignment: Alignment.center,
                child: Text(
                  _quizIndex < _quizQuestions.length - 1 ? 'NEXT QUESTION' : 'SEE RESULTS',
                  style: GoogleFonts.orbitron(fontSize: 12, fontWeight: FontWeight.w800, color: _bg, letterSpacing: 1.5),
                ),
              ),
            ).animate().fadeIn(duration: 300.ms),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PHASE 3: RESULTS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildResultsPhase() {
    final avgScore = _problemScores.isEmpty ? 0 : _totalScore ~/ _problems.length;

    return SingleChildScrollView(
      key: const ValueKey('results'),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          const SizedBox(height: 20),
          // Title
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [_green, _cyan],
            ).createShader(bounds),
            child: Text('MISSION COMPLETE',
              style: GoogleFonts.orbitron(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2)),
          ).animate().fadeIn(duration: 600.ms).scale(begin: const Offset(0.8, 0.8)),
          const SizedBox(height: 24),
          // Stars
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Icon(
                i < _stars ? Icons.star_rounded : Icons.star_border_rounded,
                size: 48,
                color: i < _stars ? _gold : _textTertiary,
              ),
            ).animate().fadeIn(delay: (300 + i * 200).ms).scale(begin: const Offset(0.5, 0.5), curve: Curves.elasticOut)),
          ),
          const SizedBox(height: 24),
          // Stats grid
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(6),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _glassBorder),
                ),
                child: Column(
                  children: [
                    Row(children: [
                      _resultStat('AVG SCORE', '$avgScore%', _green),
                      _resultStat('XP EARNED', '+$_xpEarned', _cyan),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      _resultStat('LINES WRITTEN', '$_linesWritten', _purple),
                      _resultStat('TIME', '${_totalTimeSpent ~/ 60}m ${_totalTimeSpent % 60}s', _gold),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      _resultStat('QUIZ', '$_quizCorrect/${_quizQuestions.length}', _cyan),
                      _resultStat('PROBLEMS', '${_problemScores.where((s) => s >= 60).length}/${_problems.length}', _green),
                    ]),
                  ],
                ),
              ),
            ),
          ).animate().fadeIn(delay: 600.ms, duration: 400.ms),
          const SizedBox(height: 16),
          // Problem breakdown
          ...List.generate(_problems.length, (i) => Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: Colors.white.withAlpha(4),
              border: Border.all(color: _glassBorder),
            ),
            child: Row(
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: (_problemScores[i] >= 60 ? _green : _red).withAlpha(20),
                  ),
                  child: Icon(
                    _problemScores[i] >= 60 ? Icons.check_rounded : Icons.close_rounded,
                    color: _problemScores[i] >= 60 ? _green : _red,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_problems[i].title, style: GoogleFonts.spaceGrotesk(fontSize: 13, fontWeight: FontWeight.w600, color: _textPrimary)),
                      Text(_problems[i].concept, style: GoogleFonts.spaceGrotesk(fontSize: 10, color: _textTertiary)),
                    ],
                  ),
                ),
                Text('${_problemScores[i]}', style: GoogleFonts.orbitron(
                  fontSize: 16, fontWeight: FontWeight.w800,
                  color: _problemScores[i] >= 80 ? _green : _problemScores[i] >= 50 ? _gold : _red,
                )),
              ],
            ),
          ).animate().fadeIn(delay: (800 + i * 150).ms, duration: 300.ms)),
          const SizedBox(height: 20),
          // Done button
          GestureDetector(
            onTap: _saveProgressAndExit,
            child: Container(
              width: double.infinity, height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(colors: [_green, _cyan]),
                boxShadow: [BoxShadow(color: _green.withAlpha(40), blurRadius: 20, offset: const Offset(0, 4))],
              ),
              alignment: Alignment.center,
              child: _resultsSaved
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: _bg, strokeWidth: 2.5))
                  : Text('CLAIM XP & EXIT', style: GoogleFonts.orbitron(fontSize: 13, fontWeight: FontWeight.w800, color: _bg, letterSpacing: 1.5)),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _resultStat(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: GoogleFonts.orbitron(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 2),
          Text(label, style: GoogleFonts.spaceGrotesk(fontSize: 9, color: _textTertiary, letterSpacing: 1)),
        ],
      ),
    );
  }

  // ── Overlays ────────────────────────────────────────────────────────────

  Widget _buildCheatWarning() {
    return Positioned.fill(
      child: Container(
        color: _red.withAlpha(30),
        alignment: Alignment.center,
        child: Container(
          margin: const EdgeInsets.all(40),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _bg.withAlpha(240),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _red, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_rounded, color: _red, size: 48),
              const SizedBox(height: 12),
              Text('WARNING', style: GoogleFonts.orbitron(fontSize: 18, fontWeight: FontWeight.w900, color: _red)),
              const SizedBox(height: 8),
              Text(
                'App switch detected! Switching again will auto-submit your current solution.',
                style: GoogleFonts.spaceGrotesk(fontSize: 14, color: _textSecondary, height: 1.5),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 200.ms).shake(hz: 3, duration: 400.ms);
  }

  Widget _buildEvaluationOverlay() {
    return Positioned.fill(
      child: Container(
        color: _bg.withAlpha(200),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Scanning line animation
              SizedBox(
                width: 200, height: 4,
                child: AnimatedBuilder(
                  animation: _scanlineCtrl,
                  builder: (context, _) => CustomPaint(
                    painter: _CompileScanPainter(progress: _scanlineCtrl.value),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(_evaluationStatus,
                style: GoogleFonts.firaCode(fontSize: 14, color: _green, fontWeight: FontWeight.w600, letterSpacing: 2)),
              const SizedBox(height: 8),
              SizedBox(
                width: 28, height: 28,
                child: CircularProgressIndicator(color: _green, strokeWidth: 2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Anti-paste TextInputFormatter
// ═══════════════════════════════════════════════════════════════════════════════

class _NoPasteFormatter extends TextInputFormatter {
  String _lastText = '';

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    // Detect large pastes: if more than 5 characters added at once, reject
    final diff = newValue.text.length - oldValue.text.length;
    if (diff > 5 && oldValue.text.isNotEmpty) {
      return oldValue; // block paste
    }
    _lastText = newValue.text;
    return newValue;
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Matrix Rain Painter
// ═══════════════════════════════════════════════════════════════════════════════

class _MatrixColumn {
  final double x;
  final double speed;
  final List<String> chars;
  final double offset;
  _MatrixColumn({required this.x, required this.speed, required this.chars, required this.offset});
}

class _MatrixRainPainter extends CustomPainter {
  final List<_MatrixColumn> columns;
  final double progress;
  final double opacity;

  _MatrixRainPainter({required this.columns, required this.progress, this.opacity = 0.15});

  @override
  void paint(Canvas canvas, Size size) {
    for (final col in columns) {
      final baseY = ((progress * col.speed + col.offset) % 1.0) * (size.height + 300) - 150;
      for (int i = 0; i < col.chars.length; i++) {
        final y = baseY + i * 18;
        if (y < -20 || y > size.height + 20) continue;
        final fade = (1.0 - i / col.chars.length).clamp(0.0, 1.0);
        final tp = TextPainter(
          text: TextSpan(
            text: col.chars[i],
            style: TextStyle(
              fontSize: 12,
              fontFamily: 'monospace',
              color: Color.fromRGBO(0, 255, 136, opacity * fade),
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        tp.layout();
        tp.paint(canvas, Offset(col.x, y));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MatrixRainPainter old) => true;
}

// ═══════════════════════════════════════════════════════════════════════════════
// Scanline Painter
// ═══════════════════════════════════════════════════════════════════════════════

class _ScanlinePainter extends CustomPainter {
  final double progress;
  _ScanlinePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    // Horizontal scanlines
    final paint = Paint()..color = const Color.fromRGBO(0, 255, 136, 0.02);
    for (double y = 0; y < size.height; y += 3) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    // Moving bright scanline
    final scanY = progress * size.height;
    final scanPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color.fromRGBO(0, 255, 136, 0),
          const Color.fromRGBO(0, 255, 136, 0.06),
          const Color.fromRGBO(0, 255, 136, 0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(0, scanY - 30, size.width, 60));
    canvas.drawRect(Rect.fromLTWH(0, scanY - 30, size.width, 60), scanPaint);
  }

  @override
  bool shouldRepaint(covariant _ScanlinePainter old) => true;
}

// ═══════════════════════════════════════════════════════════════════════════════
// Compile Scan Painter (for evaluation overlay)
// ═══════════════════════════════════════════════════════════════════════════════

class _CompileScanPainter extends CustomPainter {
  final double progress;
  _CompileScanPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    // Background track
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.width, size.height), const Radius.circular(2)),
      Paint()..color = const Color(0xFF1F2937),
    );
    // Moving green bar
    final barWidth = size.width * 0.3;
    final x = (progress * (size.width + barWidth)) - barWidth;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x.clamp(0, size.width - 1), 0, barWidth.clamp(1, size.width - x.clamp(0, size.width)), size.height),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0xFF00FF88),
    );
  }

  @override
  bool shouldRepaint(covariant _CompileScanPainter old) => true;
}

// ═══════════════════════════════════════════════════════════════════════════════
// Code Celebration Painter
// ═══════════════════════════════════════════════════════════════════════════════

class _CodeParticle {
  double x, y, vx, vy;
  final String char;
  final Color color;
  final double size;
  double rotation;
  final double rotationSpeed;

  _CodeParticle({
    required this.x, required this.y,
    required this.vx, required this.vy,
    required this.char, required this.color,
    required this.size, required this.rotation,
    required this.rotationSpeed,
  });
}

class _CodeCelebrationPainter extends CustomPainter {
  final List<_CodeParticle> particles;
  final double progress;

  _CodeCelebrationPainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final t = progress;
      final px = p.x + p.vx * t * 60;
      final py = p.y + p.vy * t * 60 + 0.5 * 4.0 * t * t * 3600; // gravity
      final alpha = (1.0 - t).clamp(0.0, 1.0);

      if (py < -50 || py > size.height + 50 || alpha <= 0) continue;

      canvas.save();
      canvas.translate(px, py);
      canvas.rotate(p.rotation + p.rotationSpeed * t);

      final tp = TextPainter(
        text: TextSpan(
          text: p.char,
          style: TextStyle(
            fontSize: p.size,
            fontFamily: 'monospace',
            fontWeight: FontWeight.w700,
            color: p.color.withAlpha((alpha * 200).round()),
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _CodeCelebrationPainter old) => true;
}
