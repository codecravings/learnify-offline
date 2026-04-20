import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/ai/gemma_orchestrator.dart';
import '../../../core/db/app_database.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_container.dart';

class TeacherCopilotScreen extends StatefulWidget {
  const TeacherCopilotScreen({super.key});

  @override
  State<TeacherCopilotScreen> createState() => _TeacherCopilotScreenState();
}

class _TeacherCopilotScreenState extends State<TeacherCopilotScreen> {
  final _orchestrator = GemmaOrchestrator.instance;
  final _db = AppDatabase.instance;
  final _requestCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  List<_StudentStats> _students = const [];
  bool _loadingClass = true;

  bool _generating = false;
  String _responseTitle = '';
  String _responseText = '';

  @override
  void initState() {
    super.initState();
    _loadClass();
  }

  @override
  void dispose() {
    _requestCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadClass() async {
    final profiles = await _db.getAllProfiles();
    final list = <_StudentStats>[];
    for (final p in profiles) {
      final id = p['id'] as int;
      final stats = await _db.getStats(id);
      list.add(_StudentStats(
        id: id,
        name: p['name'] as String,
        grade: p['grade'] as String? ?? 'Student',
        language: p['language'] as String? ?? 'English',
        xp: p['xp'] as int? ?? 0,
        streak: p['streak'] as int? ?? 0,
        topicCount: stats['topicCount'] as int,
        quizCount: stats['quizCount'] as int,
        avgAccuracy: stats['avgAccuracy'] as int,
      ));
    }
    if (!mounted) return;
    setState(() {
      _students = list;
      _loadingClass = false;
    });
  }

  List<Map<String, dynamic>> _classDataForAgent() => _students
      .map((s) => {
            'name': s.name,
            'topicCount': s.topicCount,
            'avgAccuracy': s.avgAccuracy,
            'streak': s.streak,
          })
      .toList();

  Future<void> _runQuickAction(String title, String request) async {
    setState(() {
      _generating = true;
      _responseTitle = title;
      _responseText = '';
    });

    try {
      final text = await _orchestrator.teacherQuery(
        request: request,
        classData: _classDataForAgent(),
      );
      if (!mounted) return;
      setState(() {
        _responseText = text;
        _generating = false;
      });
      await _scrollToResponse();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _responseText = 'Could not generate: $e';
        _generating = false;
      });
    }
  }

  Future<void> _runCustom() async {
    final q = _requestCtrl.text.trim();
    if (q.isEmpty) return;
    _requestCtrl.clear();
    await _runQuickAction('Custom request', q);
  }

  Future<void> _scrollToResponse() async {
    await Future.delayed(const Duration(milliseconds: 80));
    if (!_scrollCtrl.hasClients) return;
    _scrollCtrl.animateTo(
      _scrollCtrl.position.maxScrollExtent,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  // ── Aggregates ───────────────────────────────────────────────────────────

  int get _classSize => _students.length;
  int get _totalTopics => _students.fold(0, (sum, s) => sum + s.topicCount);
  int get _classAvgAccuracy {
    final withQuizzes = _students.where((s) => s.quizCount > 0).toList();
    if (withQuizzes.isEmpty) return 0;
    final sum =
        withQuizzes.fold<int>(0, (acc, s) => acc + s.avgAccuracy);
    return (sum / withQuizzes.length).round();
  }

  int get _activeStreaks => _students.where((s) => s.streak > 0).length;

  List<_StudentStats> get _struggling => _students
      .where((s) => s.quizCount > 0 && s.avgAccuracy < 60)
      .toList()
    ..sort((a, b) => a.avgAccuracy.compareTo(b.avgAccuracy));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('TEACHER COPILOT'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: Container(
        decoration: AppTheme.scaffoldDecorationOf(context),
        child: SafeArea(
          child: _loadingClass
              ? const Center(child: CircularProgressIndicator())
              : _buildBody(context),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            controller: _scrollCtrl,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _buildHeader(context),
              const SizedBox(height: 20),
              _buildAggregateGrid(context),
              const SizedBox(height: 24),
              _buildSectionHeader(context, 'QUICK ACTIONS', Icons.bolt_rounded),
              const SizedBox(height: 12),
              _buildQuickActions(context),
              const SizedBox(height: 24),
              _buildSectionHeader(
                  context, 'STUDENTS', Icons.groups_rounded),
              const SizedBox(height: 12),
              if (_students.isEmpty)
                _emptyStudents(context)
              else
                ..._students.map((s) => _StudentCard(student: s)),
              if (_struggling.isNotEmpty) ...[
                const SizedBox(height: 24),
                _buildSectionHeader(context, 'NEEDS ATTENTION',
                    Icons.priority_high_rounded,
                    color: AppTheme.accentMagentaOf(context)),
                const SizedBox(height: 12),
                ..._struggling.map((s) => _StrugglingRow(student: s)),
              ],
              if (_generating || _responseText.isNotEmpty) ...[
                const SizedBox(height: 24),
                _buildResponseCard(context),
              ],
              const SizedBox(height: 12),
            ],
          ),
        ),
        _buildInputBar(context),
      ],
    );
  }

  // ── Header ───────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(20),
      borderRadius: 20,
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppTheme.primaryGradientOf(context),
              boxShadow:
                  AppTheme.neonGlow(AppTheme.accentCyanOf(context), blur: 18),
            ),
            child: const Icon(Icons.psychology_rounded,
                color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Teacher Copilot',
                    style: AppTheme.headerStyle(
                      fontSize: 18,
                      color: AppTheme.textPrimaryOf(context),
                    )),
                const SizedBox(height: 4),
                Text(
                  'On-device AI for classroom insights',
                  style: AppTheme.bodyStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondaryOf(context),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppTheme.accentGreenOf(context).withAlpha(32),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                  color: AppTheme.accentGreenOf(context).withAlpha(90),
                  width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.wifi_off_rounded,
                    size: 12, color: AppTheme.accentGreenOf(context)),
                const SizedBox(width: 4),
                Text('OFFLINE',
                    style: AppTheme.bodyStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.accentGreenOf(context),
                      letterSpacing: 1.2,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Aggregate Grid ───────────────────────────────────────────────────────

  Widget _buildAggregateGrid(BuildContext context) {
    final cells = [
      _MetricCell(
        icon: Icons.groups_rounded,
        label: 'Students',
        value: '$_classSize',
        color: AppTheme.accentCyanOf(context),
      ),
      _MetricCell(
        icon: Icons.analytics_rounded,
        label: 'Avg Accuracy',
        value: '$_classAvgAccuracy%',
        color: AppTheme.accentGreenOf(context),
      ),
      _MetricCell(
        icon: Icons.auto_stories_rounded,
        label: 'Topics',
        value: '$_totalTopics',
        color: AppTheme.accentPurpleOf(context),
      ),
      _MetricCell(
        icon: Icons.local_fire_department_rounded,
        label: 'Active Streaks',
        value: '$_activeStreaks',
        color: AppTheme.accentOrangeOf(context),
      ),
    ];

    return GridView.count(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      crossAxisCount: 2,
      childAspectRatio: 1.6,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      children: cells,
    );
  }

  // ── Quick Actions ────────────────────────────────────────────────────────

  Widget _buildQuickActions(BuildContext context) {
    final actions = [
      (
        'Class summary',
        'Summarize overall class progress in 4 bullet points: strengths, weaknesses, overall engagement, one concrete recommendation.',
        Icons.summarize_rounded,
        AppTheme.accentCyanOf(context),
      ),
      (
        'Lesson plan',
        'Generate a 45-minute lesson plan for tomorrow that addresses the class\'s weakest areas. Include objectives, activities with timings, and an exit ticket question.',
        Icons.description_rounded,
        AppTheme.accentPurpleOf(context),
      ),
      (
        'Worksheet',
        'Create a 10-question practice worksheet tailored to this class\'s studied topics and current accuracy level. Mix easy, medium and hard. Include answers at the bottom.',
        Icons.assignment_rounded,
        AppTheme.accentGoldOf(context),
      ),
      (
        'Struggling students',
        'Identify which students are struggling, what they are struggling with, and suggest a personalized intervention for each.',
        Icons.warning_amber_rounded,
        AppTheme.accentMagentaOf(context),
      ),
      (
        'Weekly report',
        'Write a weekly progress report for parents: 3-4 sentences covering what was learned, collective wins, and 1 focus area for next week.',
        Icons.mail_outline_rounded,
        AppTheme.accentGreenOf(context),
      ),
      (
        'Discussion prompts',
        'Generate 5 classroom discussion prompts based on the topics students have recently studied. Keep them open-ended and age-appropriate.',
        Icons.forum_rounded,
        AppTheme.accentOrangeOf(context),
      ),
    ];

    return GridView.count(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      crossAxisCount: 2,
      childAspectRatio: 1.25,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      children: [
        for (final a in actions)
          _QuickActionCard(
            icon: a.$3,
            title: a.$1,
            color: a.$4,
            onTap: _generating ? null : () => _runQuickAction(a.$1, a.$2),
          ),
      ],
    );
  }

  // ── Section Header ───────────────────────────────────────────────────────

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    IconData icon, {
    Color? color,
  }) {
    final c = color ?? AppTheme.accentCyanOf(context);
    return Row(
      children: [
        Icon(icon, size: 16, color: c),
        const SizedBox(width: 8),
        Text(
          title,
          style: AppTheme.headerStyle(
            fontSize: 12,
            color: c,
            letterSpacing: 2.0,
          ),
        ),
      ],
    );
  }

  Widget _emptyStudents(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(Icons.group_add_rounded,
              size: 32, color: AppTheme.textTertiaryOf(context)),
          const SizedBox(height: 10),
          Text('No students yet',
              style: AppTheme.bodyStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimaryOf(context),
              )),
          const SizedBox(height: 4),
          Text(
            'Create student profiles on this device to populate the class.',
            style: AppTheme.bodyStyle(
              fontSize: 12,
              color: AppTheme.textSecondaryOf(context),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── Response Card ────────────────────────────────────────────────────────

  Widget _buildResponseCard(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(18),
      borderRadius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded,
                  size: 16, color: AppTheme.accentPurpleOf(context)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _responseTitle.toUpperCase(),
                  style: AppTheme.headerStyle(
                    fontSize: 11,
                    letterSpacing: 1.8,
                    color: AppTheme.accentPurpleOf(context),
                  ),
                ),
              ),
              if (!_generating && _responseText.isNotEmpty)
                IconButton(
                  onPressed: () => setState(() {
                    _responseText = '';
                    _responseTitle = '';
                  }),
                  icon: const Icon(Icons.close_rounded, size: 18),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (_generating)
            Row(
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(
                        AppTheme.accentCyanOf(context)),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Gemma is thinking…',
                  style: AppTheme.bodyStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondaryOf(context),
                  ),
                ),
              ],
            )
          else
            MarkdownBody(
              data: _responseText,
              styleSheet: MarkdownStyleSheet(
                p: AppTheme.bodyStyle(
                  fontSize: 14,
                  color: AppTheme.textPrimaryOf(context),
                  height: 1.55,
                ),
                h1: AppTheme.headerStyle(
                  fontSize: 18,
                  color: AppTheme.textPrimaryOf(context),
                ),
                h2: AppTheme.headerStyle(
                  fontSize: 16,
                  color: AppTheme.textPrimaryOf(context),
                ),
                h3: AppTheme.headerStyle(
                  fontSize: 14,
                  color: AppTheme.textPrimaryOf(context),
                ),
                listBullet: AppTheme.bodyStyle(
                  fontSize: 14,
                  color: AppTheme.textPrimaryOf(context),
                ),
                code: GoogleFonts.jetBrainsMono(
                  fontSize: 12.5,
                  color: AppTheme.accentCyanOf(context),
                  backgroundColor: AppTheme.glassFillOf(context),
                ),
                codeblockDecoration: BoxDecoration(
                  color: AppTheme.glassFillOf(context),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppTheme.glassBorderOf(context), width: 0.8),
                ),
              ),
            ),
        ],
      ),
    ).animate().fadeIn(duration: 200.ms).slideY(begin: 0.05, end: 0);
  }

  // ── Input Bar ────────────────────────────────────────────────────────────

  Widget _buildInputBar(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
        child: GlassContainer(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          borderRadius: 28,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _requestCtrl,
                  enabled: !_generating,
                  onSubmitted: (_) => _runCustom(),
                  decoration: InputDecoration(
                    hintText: 'Ask your Teacher Copilot…',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    hintStyle: AppTheme.bodyStyle(
                      fontSize: 14,
                      color: AppTheme.textTertiaryOf(context),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 12),
                  ),
                  style: AppTheme.bodyStyle(
                    fontSize: 14,
                    color: AppTheme.textPrimaryOf(context),
                  ),
                ),
              ),
              GestureDetector(
                onTap: _generating ? null : _runCustom,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: _generating
                        ? null
                        : AppTheme.primaryGradientOf(context),
                    color: _generating
                        ? AppTheme.textDisabled.withAlpha(80)
                        : null,
                  ),
                  child: const Icon(Icons.arrow_upward_rounded,
                      color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Data + private widgets
// ─────────────────────────────────────────────────────────────────────────────

class _StudentStats {
  const _StudentStats({
    required this.id,
    required this.name,
    required this.grade,
    required this.language,
    required this.xp,
    required this.streak,
    required this.topicCount,
    required this.quizCount,
    required this.avgAccuracy,
  });

  final int id;
  final String name;
  final String grade;
  final String language;
  final int xp;
  final int streak;
  final int topicCount;
  final int quizCount;
  final int avgAccuracy;
}

class _MetricCell extends StatelessWidget {
  const _MetricCell({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(14),
      borderRadius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: color.withAlpha(40),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const Spacer(),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: AppTheme.headerStyle(
                    fontSize: 22,
                    color: AppTheme.textPrimaryOf(context),
                  )),
              const SizedBox(height: 2),
              Text(label,
                  style: AppTheme.bodyStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondaryOf(context),
                    letterSpacing: 0.4,
                  )),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dim = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: dim ? 0.5 : 1.0,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withAlpha(80), width: 1),
            gradient: LinearGradient(
              colors: [color.withAlpha(40), color.withAlpha(14)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withAlpha(60),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              Text(
                title,
                style: AppTheme.bodyStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimaryOf(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudentCard extends StatelessWidget {
  const _StudentCard({required this.student});
  final _StudentStats student;

  Color _accColor(BuildContext context) {
    if (student.quizCount == 0) return AppTheme.textTertiaryOf(context);
    if (student.avgAccuracy >= 80) return AppTheme.accentGreenOf(context);
    if (student.avgAccuracy >= 60) return AppTheme.accentGoldOf(context);
    return AppTheme.accentMagentaOf(context);
  }

  @override
  Widget build(BuildContext context) {
    final accColor = _accColor(context);
    final initial = student.name.isEmpty ? '?' : student.name[0].toUpperCase();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassContainer(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.accentCyanOf(context).withAlpha(38),
                border: Border.all(
                  color: AppTheme.accentCyanOf(context).withAlpha(110),
                  width: 1,
                ),
              ),
              child: Text(
                initial,
                style: AppTheme.headerStyle(
                  fontSize: 16,
                  color: AppTheme.accentCyanOf(context),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    student.name,
                    style: AppTheme.bodyStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimaryOf(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${student.grade} • ${student.language}',
                    style: AppTheme.bodyStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondaryOf(context),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _TinyStat(
                        icon: Icons.auto_stories_rounded,
                        value: '${student.topicCount}',
                      ),
                      const SizedBox(width: 10),
                      _TinyStat(
                        icon: Icons.quiz_rounded,
                        value: '${student.quizCount}',
                      ),
                      const SizedBox(width: 10),
                      _TinyStat(
                        icon: Icons.local_fire_department_rounded,
                        value: '${student.streak}d',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  student.quizCount == 0 ? '—' : '${student.avgAccuracy}%',
                  style: AppTheme.headerStyle(
                    fontSize: 18,
                    color: accColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'accuracy',
                  style: AppTheme.bodyStyle(
                    fontSize: 10,
                    color: AppTheme.textTertiaryOf(context),
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TinyStat extends StatelessWidget {
  const _TinyStat({required this.icon, required this.value});
  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppTheme.textTertiaryOf(context)),
        const SizedBox(width: 3),
        Text(
          value,
          style: AppTheme.bodyStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondaryOf(context),
          ),
        ),
      ],
    );
  }
}

class _StrugglingRow extends StatelessWidget {
  const _StrugglingRow({required this.student});
  final _StudentStats student;

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.accentMagentaOf(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.withAlpha(70), width: 1),
          color: c.withAlpha(18),
        ),
        child: Row(
          children: [
            Icon(Icons.trending_down_rounded, size: 18, color: c),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                student.name,
                style: AppTheme.bodyStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimaryOf(context),
                ),
              ),
            ),
            Text(
              '${student.avgAccuracy}%',
              style: AppTheme.headerStyle(fontSize: 14, color: c),
            ),
          ],
        ),
      ),
    );
  }
}
