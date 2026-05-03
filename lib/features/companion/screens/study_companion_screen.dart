import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../../core/ai/gemma_orchestrator.dart';
import '../../../core/services/local_memory_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../routes/app_router.dart';

/// Learner Twin chat — powered by on-device Gemma 4 over the student's local memory.
/// Every exchange is retained in SQLite so cross-session context compounds.
class StudyCompanionScreen extends StatefulWidget {
  const StudyCompanionScreen({super.key});

  @override
  State<StudyCompanionScreen> createState() => _StudyCompanionScreenState();
}

class _StudyCompanionScreenState extends State<StudyCompanionScreen> {
  final _orchestrator = GemmaOrchestrator.instance;
  final _memory = LocalMemoryService.instance;
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();

  final List<_ChatMsg> _messages = [];
  String? _studyPulse;
  bool _pulseLoading = true;
  bool _generating = false;
  Map<String, dynamic>? _activePath;

  static const _quickActions = [
    _QuickAction('What should I study next?', Icons.explore_rounded,
        AppTheme.accentCyan),
    _QuickAction('Quiz me on my weak spots', Icons.quiz_rounded,
        AppTheme.accentPurple),
    _QuickAction('Plan my week', Icons.calendar_month_rounded,
        AppTheme.accentGreen),
    _QuickAction('Where am I struggling?', Icons.troubleshoot_rounded,
        AppTheme.accentOrange),
  ];

  @override
  void initState() {
    super.initState();
    _loadPulse();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadPulse() async {
    setState(() => _pulseLoading = true);
    try {
      final paths = await _memory.getActiveMasteryPaths();
      Map<String, dynamic>? active;
      for (final p in paths) {
        final completed = (p['completedStepIndices'] as List).length;
        final total = (p['steps'] as List).length;
        if (completed < total) {
          active = p;
          break;
        }
      }
      final pulse = await _orchestrator.getStudyPulse();
      if (mounted) {
        setState(() {
          _studyPulse = pulse;
          _activePath = active;
          _pulseLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _studyPulse =
              'I\'ll build your learner profile as you study. Try asking me anything below.';
          _pulseLoading = false;
        });
      }
    }
  }

  Future<void> _send([String? text]) async {
    final query = (text ?? _ctrl.text).trim();
    if (query.isEmpty || _generating) return;

    _ctrl.clear();
    final userMsg = _ChatMsg(role: _Role.user, text: query);
    final botMsg = _ChatMsg(role: _Role.twin, text: '');

    setState(() {
      _messages.add(userMsg);
      _messages.add(botMsg);
      _generating = true;
    });
    _scrollToBottom();

    final buf = StringBuffer();
    try {
      await for (final chunk in _orchestrator.queryLearnerTwinStream(query)) {
        if (!mounted) return;
        buf.write(chunk);
        setState(() => botMsg.text = buf.toString());
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() => botMsg.text =
            'Sorry — the twin couldn\'t answer this time. ($e)');
      }
    } finally {
      if (mounted) setState(() => _generating = false);
      await _memory.retainChatExchange(query, buf.toString());
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: ListView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                children: [
                  _buildPulseCard()
                      .animate()
                      .fadeIn(duration: 400.ms)
                      .slideY(begin: 0.03),
                  const SizedBox(height: 16),
                  if (_messages.isEmpty) _buildQuickActions(),
                  ..._messages.map(_buildMessage),
                ],
              ),
            ),
            _buildInput(bottomSafe),
          ],
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: const LinearGradient(
                colors: [AppTheme.accentCyan, AppTheme.accentPurple],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.accentCyan.withAlpha(80),
                  blurRadius: 16,
                ),
              ],
            ),
            child: const Icon(Icons.psychology_rounded,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Learner Twin',
                  style: GoogleFonts.orbitron(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.accentGreen,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'On-device · remembers everything',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 10,
                        color: AppTheme.textTertiary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_messages.isNotEmpty)
            IconButton(
              onPressed: () {
                setState(() => _messages.clear());
              },
              icon: Icon(Icons.refresh_rounded,
                  color: AppTheme.accentCyan.withAlpha(180), size: 20),
              tooltip: 'Clear chat',
            ),
        ],
      ),
    );
  }

  // ── Active mastery path chip (inside pulse card) ───────────────────────

  Widget _buildActivePathChip(Map<String, dynamic> path) {
    final steps = (path['steps'] as List).cast<Map<String, dynamic>>();
    final completed = (path['completedStepIndices'] as List).length;
    final total = steps.length;
    final current = (path['currentStepIndex'] as int).clamp(0, total - 1);
    final topic = path['topic'] as String;
    final nextTitle = steps.isNotEmpty ? (steps[current]['title'] as String? ?? '') : '';

    return GestureDetector(
      onTap: () => context.push(AppRoutes.masteryPath, extra: {'topic': topic}),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.accentCyan.withAlpha(40),
              AppTheme.accentPurple.withAlpha(30),
            ],
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.accentCyan.withAlpha(80)),
        ),
        child: Row(
          children: [
            const Icon(Icons.route_rounded,
                color: AppTheme.accentCyan, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$completed/$total · $topic',
                    style: GoogleFonts.orbitron(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.accentCyan,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Next: $nextTitle',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 12,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                color: AppTheme.accentCyan.withAlpha(150), size: 12),
          ],
        ),
      ),
    );
  }

  // ── Study pulse card ───────────────────────────────────────────────────

  Widget _buildPulseCard() {
    return GlassContainer(
      borderColor: AppTheme.accentPurple.withAlpha(60),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_graph_rounded,
                  color: AppTheme.accentPurple, size: 18),
              const SizedBox(width: 8),
              Text(
                'STUDY PULSE',
                style: GoogleFonts.orbitron(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.accentPurple,
                  letterSpacing: 1.5,
                ),
              ),
              const Spacer(),
              if (_pulseLoading)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.accentPurple,
                  ),
                )
              else
                GestureDetector(
                  onTap: _loadPulse,
                  child: Icon(Icons.refresh_rounded,
                      color: AppTheme.accentPurple.withAlpha(150), size: 16),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (_pulseLoading)
            Container(
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(8),
                borderRadius: BorderRadius.circular(6),
              ),
            )
          else
            Text(
              _studyPulse ?? '',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 13,
                color: AppTheme.textPrimary,
                height: 1.5,
              ),
            ),
          if (_activePath != null) ...[
            const SizedBox(height: 12),
            _buildActivePathChip(_activePath!),
          ],
        ],
      ),
    );
  }

  // ── Quick actions ──────────────────────────────────────────────────────

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            'Try asking',
            style: GoogleFonts.orbitron(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppTheme.textTertiary,
              letterSpacing: 1.5,
            ),
          ),
        ),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.9,
          children: _quickActions
              .map((a) => _buildQuickTile(a))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildQuickTile(_QuickAction a) {
    return GestureDetector(
      onTap: _generating ? null : () => _send(a.text),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: a.color.withAlpha(15),
          border: Border.all(color: a.color.withAlpha(60), width: 0.8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(a.icon, color: a.color, size: 20),
            Text(
              a.text,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ── Messages ────────────────────────────────────────────────────────────

  Widget _buildMessage(_ChatMsg msg) {
    final isUser = msg.role == _Role.user;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [AppTheme.accentCyan, AppTheme.accentPurple],
                ),
              ),
              child: const Icon(Icons.psychology_rounded,
                  color: Colors.white, size: 16),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14).copyWith(
                  topRight:
                      isUser ? const Radius.circular(4) : null,
                  topLeft:
                      isUser ? null : const Radius.circular(4),
                ),
                color: isUser
                    ? AppTheme.accentCyan.withAlpha(30)
                    : Colors.white.withAlpha(8),
                border: Border.all(
                  color: isUser
                      ? AppTheme.accentCyan.withAlpha(80)
                      : AppTheme.glassBorder,
                  width: 0.6,
                ),
              ),
              child: isUser
                  ? Text(
                      msg.text,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 13,
                        color: AppTheme.textPrimary,
                      ),
                    )
                  : msg.text.isEmpty
                      ? _buildTypingIndicator()
                      : MarkdownBody(
                          data: msg.text,
                          styleSheet: _markdownStyle(),
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return SizedBox(
      height: 16,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Container(
              width: 5,
              height: 5,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.accentCyan,
              ),
            )
                .animate(
                  onPlay: (c) => c.repeat(),
                )
                .fadeIn(
                  duration: 400.ms,
                  delay: (i * 150).ms,
                )
                .then()
                .fadeOut(duration: 400.ms),
          );
        }),
      ),
    );
  }

  MarkdownStyleSheet _markdownStyle() => MarkdownStyleSheet(
        p: GoogleFonts.spaceGrotesk(
          fontSize: 13,
          color: AppTheme.textPrimary,
          height: 1.5,
        ),
        strong: GoogleFonts.spaceGrotesk(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppTheme.accentCyan,
        ),
        em: GoogleFonts.spaceGrotesk(
          fontSize: 13,
          color: AppTheme.accentPurple,
          fontStyle: FontStyle.italic,
        ),
        h1: GoogleFonts.orbitron(
            fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
        h2: GoogleFonts.orbitron(
            fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
        code: GoogleFonts.jetBrainsMono(
          fontSize: 12,
          color: AppTheme.accentGreen,
          backgroundColor: Colors.white.withAlpha(10),
        ),
        listBullet: GoogleFonts.spaceGrotesk(
          fontSize: 13,
          color: AppTheme.textPrimary,
        ),
      );

  // ── Input ───────────────────────────────────────────────────────────────

  Widget _buildInput(double bottomSafe) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, bottomSafe + 100),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: AppTheme.glassBorder, width: 0.5),
        ),
        color: AppTheme.backgroundPrimary.withAlpha(220),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _ctrl,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 13,
                color: AppTheme.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Ask the twin anything…',
                hintStyle: GoogleFonts.spaceGrotesk(
                  fontSize: 12,
                  color: AppTheme.textTertiary,
                ),
                filled: true,
                fillColor: Colors.white.withAlpha(10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide(
                      color: AppTheme.accentCyan.withAlpha(50)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide(
                      color: AppTheme.accentCyan.withAlpha(50)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide:
                      const BorderSide(color: AppTheme.accentCyan, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 10),
              ),
              textInputAction: TextInputAction.send,
              enabled: !_generating,
              onSubmitted: (_) => _send(),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _generating ? null : _send,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: _generating
                      ? [Colors.grey.shade800, Colors.grey.shade700]
                      : const [AppTheme.accentCyan, AppTheme.accentPurple],
                ),
              ),
              child: _generating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded,
                      color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMsg {
  _ChatMsg({required this.role, required this.text});
  final _Role role;
  String text;
}

enum _Role { user, twin }

class _QuickAction {
  const _QuickAction(this.text, this.icon, this.color);
  final String text;
  final IconData icon;
  final Color color;
}
