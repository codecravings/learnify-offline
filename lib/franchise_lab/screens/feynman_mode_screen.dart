import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass_container.dart';
import '../data/franchise_loader.dart';
import '../services/lab_memory_service.dart';
import '../services/lab_orchestrator.dart';
import '../services/lab_profile_service.dart';

/// Role-reversal mode — the kid teaches the franchise character.
///
/// Three deterministic Gemma turns:
///   1. opening    — character admits confusion + asks first question
///   (kid replies)
///   2. followUp   — character reacts + asks one clarifying follow-up
///   (kid replies)
///   3. lightbulb  — character has the "I get it!" moment + recap
///
/// Score is a length-based heuristic over the kid's two replies; on the
/// final turn we award stars + XP and persist a memory event so the
/// Companion picks up "you taught X to Y" in future sessions.
class FeynmanModeScreen extends StatefulWidget {
  const FeynmanModeScreen({
    super.key,
    required this.topic,
    required this.franchise,
    required this.character,
  });

  final String topic;
  final Franchise franchise;
  final FranchisePersona character;

  @override
  State<FeynmanModeScreen> createState() => _FeynmanModeScreenState();
}

enum _Phase {
  intro,
  characterTurn,
  studentTurn,
  results,
}

class _Turn {
  _Turn({required this.fromCharacter, required this.text});
  final bool fromCharacter;
  String text;
}

class _FeynmanModeScreenState extends State<FeynmanModeScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  final _orchestrator = LabOrchestrator.instance;
  final _memory = LabMemoryService.instance;
  final _profile = LabProfileService.instance;

  _Phase _phase = _Phase.intro;
  final List<_Turn> _transcript = [];
  int _characterTurnsCompleted = 0;
  bool _streaming = false;

  // Scoring state — derived from kid's replies once results phase begins.
  int _stars = 1;
  int _xp = 0;

  Color get _charColor {
    // Stable hash of character name → one of the neon palette colors.
    final palette = [
      AppTheme.accentMagenta,
      AppTheme.accentGold,
      AppTheme.accentGreen,
      AppTheme.accentPurple,
      AppTheme.accentOrange,
    ];
    return palette[widget.character.name.hashCode.abs() % palette.length];
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _begin() async {
    setState(() => _phase = _Phase.characterTurn);
    await _runCharacterTurn(FeynmanTurn.opening);
  }

  Future<void> _runCharacterTurn(FeynmanTurn turn) async {
    setState(() {
      _streaming = true;
      _transcript.add(_Turn(fromCharacter: true, text: ''));
    });
    _scrollToBottom();

    final buf = StringBuffer();
    try {
      await for (final token in _orchestrator.streamFeynmanTurn(
        topic: widget.topic,
        franchise: widget.franchise,
        character: widget.character,
        turn: turn,
        transcript: _transcript
            .where((t) => t.text.trim().isNotEmpty)
            .map((t) => (
                  role: t.fromCharacter ? 'character' : 'student',
                  text: t.text.trim()
                ))
            .toList(),
      )) {
        if (!mounted) return;
        buf.write(token);
        setState(() => _transcript.last.text = buf.toString());
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _transcript.last.text =
            "(${widget.character.name} got distracted — tap retry)");
      }
    } finally {
      if (!mounted) return;
      _characterTurnsCompleted++;
      setState(() => _streaming = false);

      if (_characterTurnsCompleted >= 3) {
        await _finish();
      } else {
        setState(() => _phase = _Phase.studentTurn);
      }
    }
  }

  Future<void> _submitStudentReply() async {
    final reply = _ctrl.text.trim();
    if (reply.isEmpty || _streaming) return;
    _ctrl.clear();

    setState(() {
      _transcript.add(_Turn(fromCharacter: false, text: reply));
      _phase = _Phase.characterTurn;
    });
    _scrollToBottom();

    final nextTurn = _characterTurnsCompleted == 1
        ? FeynmanTurn.followUp
        : FeynmanTurn.lightbulb;
    await _runCharacterTurn(nextTurn);
  }

  Future<void> _finish() async {
    final studentReplies =
        _transcript.where((t) => !t.fromCharacter).toList();
    var stars = 1;
    if (studentReplies.length >= 2) {
      final shortest = studentReplies
          .map((r) => r.text.trim().length)
          .reduce((a, b) => a < b ? a : b);
      if (shortest >= 30) stars = 2;
      if (shortest >= 80) stars = 3;
    }
    final xp = 30 + (stars - 1) * 15;

    await _memory.retainFeynmanSession(
      topic: widget.topic,
      franchiseName: widget.franchise.name,
      characterName: widget.character.name,
      stars: stars,
      xpAwarded: xp,
    );
    await _profile.addXP(xp);

    if (!mounted) return;
    setState(() {
      _stars = stars;
      _xp = xp;
      _phase = _Phase.results;
    });
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
    return Scaffold(
      backgroundColor: AppTheme.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundPrimary,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white70),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'TEACH ${widget.character.name.toUpperCase()}',
              style: GoogleFonts.orbitron(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _charColor,
                letterSpacing: 1.4,
              ),
            ),
            Text(
              widget.topic,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 11,
                color: AppTheme.textTertiary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: switch (_phase) {
          _Phase.intro => _buildIntro(),
          _Phase.characterTurn ||
          _Phase.studentTurn =>
            _buildChat(),
          _Phase.results => _buildResults(),
        },
      ),
    );
  }

  Widget _buildIntro() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [_charColor.withAlpha(120), _charColor.withAlpha(0)],
              ),
            ),
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _charColor.withAlpha(60),
                border: Border.all(color: _charColor, width: 1.5),
              ),
              child: Icon(Icons.school_rounded, color: _charColor, size: 28),
            ),
          ).animate().scale(duration: 400.ms),
          const SizedBox(height: 18),
          Text(
            'Role reversal',
            style: GoogleFonts.orbitron(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _charColor,
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "${widget.character.name} doesn't get ${widget.topic} yet.",
            textAlign: TextAlign.center,
            style: GoogleFonts.orbitron(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Your turn to teach. Three exchanges. The clearer you explain, the faster the lightbulb moment.',
            textAlign: TextAlign.center,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 13,
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 40),
          ElevatedButton.icon(
            onPressed: _begin,
            icon: const Icon(Icons.psychology_rounded),
            label: Text(
              'BEGIN',
              style: GoogleFonts.orbitron(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.6,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _charColor,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChat() {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            itemCount: _transcript.length + (_streaming ? 1 : 0),
            itemBuilder: (context, i) {
              if (i == _transcript.length && _streaming) {
                return _typingDot();
              }
              final turn = _transcript[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: turn.fromCharacter
                    ? _characterBubble(turn.text)
                    : _studentBubble(turn.text),
              );
            },
          ),
        ),
        if (_phase == _Phase.studentTurn) _buildInput(),
      ],
    );
  }

  Widget _characterBubble(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _charColor.withAlpha(60),
            border: Border.all(color: _charColor.withAlpha(120), width: 0.7),
          ),
          child: Text(
            widget.character.name.isNotEmpty
                ? widget.character.name[0].toUpperCase()
                : '?',
            style: GoogleFonts.orbitron(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: _charColor,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.character.name,
                style: GoogleFonts.orbitron(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: _charColor,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: _charColor.withAlpha(20),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(14),
                    bottomRight: Radius.circular(14),
                    bottomLeft: Radius.circular(14),
                  ),
                  border:
                      Border.all(color: _charColor.withAlpha(60), width: 0.7),
                ),
                child: Text(
                  text.isEmpty ? '…' : text,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 14,
                    color: Colors.white,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _studentBubble(String text) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Flexible(
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.accentCyan.withAlpha(40),
                  AppTheme.accentCyan.withAlpha(20),
                ],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(4),
                bottomRight: Radius.circular(14),
                bottomLeft: Radius.circular(14),
              ),
              border: Border.all(
                  color: AppTheme.accentCyan.withAlpha(80), width: 0.7),
            ),
            child: Text(
              text,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 14,
                color: Colors.white,
                height: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _typingDot() {
    return Padding(
      padding: const EdgeInsets.only(left: 40, top: 4, bottom: 12),
      child: Row(
        children: [
          for (var i = 0; i < 3; i++)
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                color: _charColor.withAlpha(180),
                shape: BoxShape.circle,
              ),
            )
                .animate(onPlay: (c) => c.repeat())
                .fadeIn(delay: (120 * i).ms, duration: 240.ms)
                .then()
                .fadeOut(duration: 240.ms),
        ],
      ),
    );
  }

  Widget _buildInput() {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        12,
        8,
        12,
        MediaQuery.of(context).viewInsets.bottom + 12,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _ctrl,
              minLines: 1,
              maxLines: 4,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 14,
                color: Colors.white,
              ),
              decoration: InputDecoration(
                hintText: 'Explain it to ${widget.character.name}…',
                hintStyle: GoogleFonts.spaceGrotesk(
                  fontSize: 13,
                  color: Colors.white38,
                ),
                filled: true,
                fillColor: Colors.white.withAlpha(15),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: _charColor, width: 1.4),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
              ),
              textInputAction: TextInputAction.newline,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _submitStudentReply,
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_charColor, _charColor.withAlpha(140)],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.send_rounded,
                  color: Colors.black, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.psychology_alt_rounded,
                size: 72, color: _charColor),
            const SizedBox(height: 14),
            Text(
              '${widget.character.name.toUpperCase()} GETS IT',
              style: GoogleFonts.orbitron(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _charColor,
                letterSpacing: 1.6,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.topic,
              textAlign: TextAlign.center,
              style: GoogleFonts.orbitron(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                3,
                (i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    i < _stars
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: AppTheme.accentGold,
                    size: 36,
                  ),
                )
                    .animate(delay: (200 * i).ms)
                    .scale(duration: 300.ms, curve: Curves.elasticOut),
              ),
            ),
            const SizedBox(height: 18),
            GlassContainer(
              padding: const EdgeInsets.symmetric(
                  horizontal: 18, vertical: 10),
              borderColor: AppTheme.accentMagenta.withAlpha(80),
              child: Text(
                '+$_xp XP earned',
                style: GoogleFonts.orbitron(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.accentMagenta,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentMagenta,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                    horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'DONE',
                style: GoogleFonts.orbitron(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
