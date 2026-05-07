import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/ai/gemma_orchestrator.dart';
import '../../../core/franchises/franchise_loader.dart';
import '../../../core/services/local_memory_service.dart';
import '../../../core/services/local_profile_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../core/widgets/neon_button.dart';

/// "Teach it back" — role-reversal where the kid teaches the franchise
/// character. Three deterministic Gemma turns: opening / followUp / lightbulb.
/// Shown after a strong Story Learn result (≥70% accuracy + a franchise
/// was used). Score is a length-based heuristic over the kid's two replies.
class FeynmanScreen extends StatefulWidget {
  const FeynmanScreen({
    super.key,
    required this.topic,
    required this.franchise,
    required this.character,
  });

  final String topic;
  final Franchise franchise;
  final FranchisePersona character;

  @override
  State<FeynmanScreen> createState() => _FeynmanScreenState();
}

enum _Phase { intro, chat, results }

class _Turn {
  _Turn({required this.fromCharacter, required this.text});
  final bool fromCharacter;
  String text;
}

class _FeynmanScreenState extends State<FeynmanScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  final _orchestrator = GemmaOrchestrator.instance;
  final _memory = LocalMemoryService.instance;
  final _profile = LocalProfileService.instance;

  _Phase _phase = _Phase.intro;
  final List<_Turn> _transcript = [];
  int _characterTurnsCompleted = 0; // 0 → opening; 1 → followUp; 2 → lightbulb
  bool _streaming = false;

  int _stars = 1;
  int _xp = 0;

  Color get _charColor {
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

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _begin() async {
    setState(() => _phase = _Phase.chat);
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
      final stream = _orchestrator.streamFeynmanTurn(
        topic: widget.topic,
        franchise: widget.franchise,
        character: widget.character,
        turn: turn,
        transcript: _transcript
            .where((t) => t.text.isNotEmpty)
            .map((t) => (
                  role: t.fromCharacter ? 'character' : 'student',
                  text: t.text,
                ))
            .toList(),
      );
      await for (final chunk in stream) {
        buf.write(chunk);
        if (mounted) {
          setState(() => _transcript.last.text = buf.toString());
          _scrollToBottom();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _transcript.last.text = '...');
      }
    }

    if (mounted) {
      setState(() {
        _streaming = false;
        _characterTurnsCompleted++;
      });
    }

    if (turn == FeynmanTurn.lightbulb) {
      await _finalize();
    }
  }

  Future<void> _onStudentSend() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _streaming) return;
    setState(() {
      _transcript.add(_Turn(fromCharacter: false, text: text));
      _ctrl.clear();
    });
    _scrollToBottom();

    if (_characterTurnsCompleted == 1) {
      await _runCharacterTurn(FeynmanTurn.followUp);
    } else if (_characterTurnsCompleted == 2) {
      await _runCharacterTurn(FeynmanTurn.lightbulb);
    }
  }

  Future<void> _finalize() async {
    final replies = _transcript.where((t) => !t.fromCharacter).toList();
    final shorter = replies.isEmpty
        ? 0
        : replies.map((r) => r.text.length).reduce((a, b) => a < b ? a : b);

    int stars;
    int xp;
    if (shorter >= 80) {
      stars = 3;
      xp = 60;
    } else if (shorter >= 30) {
      stars = 2;
      xp = 45;
    } else {
      stars = 1;
      xp = 30;
    }

    await _profile.addXP(xp);
    await _memory.retainFeynmanSession(
      topic: widget.topic,
      franchiseName: widget.franchise.name,
      characterName: widget.character.name,
      stars: stars,
    );

    if (!mounted) return;
    setState(() {
      _stars = stars;
      _xp = xp;
      _phase = _Phase.results;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundPrimary,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: AppTheme.backgroundGradient,
            ),
          ),
          SafeArea(
            child: switch (_phase) {
              _Phase.intro => _buildIntro(),
              _Phase.chat => _buildChat(),
              _Phase.results => _buildResults(),
            },
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            child: IconButton(
              onPressed: () => context.pop(),
              icon: const Icon(Icons.close_rounded, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // ── INTRO ──────────────────────────────────────────────────────────────

  Widget _buildIntro() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TEACH IT BACK',
            style: GoogleFonts.orbitron(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _charColor,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.character.name,
            style: GoogleFonts.orbitron(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          Text(
            'wants to learn ${widget.topic} from you.',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 15,
              color: AppTheme.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          GlassContainer(
            borderColor: _charColor.withAlpha(80),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.lightbulb_outline_rounded,
                        color: _charColor, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'THE FEYNMAN TECHNIQUE',
                      style: GoogleFonts.orbitron(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _charColor,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'If you can teach it, you understand it. ${widget.character.name} '
                  'will ask you a few questions in their voice. Reply like you\'re '
                  'really teaching them — short answers are fine.',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          NeonButton(
            label: 'BEGIN',
            icon: Icons.play_arrow_rounded,
            colors: [_charColor, AppTheme.accentCyan],
            onTap: _begin,
          ),
        ],
      ),
    );
  }

  // ── CHAT ───────────────────────────────────────────────────────────────

  Widget _buildChat() {
    final composerEnabled = !_streaming &&
        (_characterTurnsCompleted == 1 || _characterTurnsCompleted == 2) &&
        _transcript.isNotEmpty &&
        _transcript.last.fromCharacter;

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 56, 0, 0),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: _charColor.withAlpha(28),
                    border: Border.all(color: _charColor.withAlpha(80), width: 0.6),
                  ),
                  child: Text(
                    'TEACHING ${widget.character.name.toUpperCase()}',
                    style: GoogleFonts.orbitron(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: _charColor,
                      letterSpacing: 1.4,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  '${_characterTurnsCompleted.clamp(0, 3)}/3',
                  style: GoogleFonts.orbitron(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _transcript.length,
              itemBuilder: (_, i) => _buildBubble(_transcript[i], i),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              MediaQuery.of(context).viewInsets.bottom + 12,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    enabled: composerEnabled,
                    minLines: 1,
                    maxLines: 4,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: composerEnabled
                          ? 'Teach ${widget.character.name}…'
                          : (_streaming
                              ? '${widget.character.name} is thinking…'
                              : 'Listen…'),
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: Colors.white.withAlpha(12),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(color: _charColor.withAlpha(60)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(color: _charColor.withAlpha(60)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(color: _charColor, width: 1.5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: composerEnabled ? _onStudentSend : null,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: composerEnabled
                            ? [_charColor, AppTheme.accentCyan]
                            : [Colors.white12, Colors.white24],
                      ),
                    ),
                    child: const Icon(Icons.arrow_upward_rounded,
                        color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBubble(_Turn t, int i) {
    final fromChar = t.fromCharacter;
    final color = fromChar ? _charColor : AppTheme.accentCyan;
    final initial = fromChar
        ? widget.character.name[0].toUpperCase()
        : (_profile.currentProfile?.name.isNotEmpty == true
            ? _profile.currentProfile!.name[0].toUpperCase()
            : 'U');

    final avatar = Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: [color, color.withAlpha(120)]),
      ),
      child: Center(
        child: Text(
          initial,
          style: GoogleFonts.orbitron(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
      ),
    );

    final bubble = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.72,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(fromChar ? 4 : 16),
          bottomRight: Radius.circular(fromChar ? 16 : 4),
        ),
        color: color.withAlpha(28),
        border: Border.all(color: color.withAlpha(95), width: 0.7),
      ),
      child: Text(
        t.text.isEmpty ? '…' : t.text,
        style: GoogleFonts.spaceGrotesk(
          fontSize: 14,
          color: AppTheme.textPrimary,
          height: 1.45,
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            fromChar ? MainAxisAlignment.start : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: fromChar
            ? [avatar, const SizedBox(width: 8), Flexible(child: bubble)]
            : [Flexible(child: bubble), const SizedBox(width: 8), avatar],
      ),
    ).animate(key: ValueKey('feynman-bubble-$i'))
        .fadeIn(duration: 240.ms)
        .slideY(begin: 0.12, end: 0, duration: 280.ms);
  }

  // ── RESULTS ────────────────────────────────────────────────────────────

  Widget _buildResults() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 80, 20, 40),
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [_charColor, AppTheme.accentPurple],
              ),
              boxShadow: [
                BoxShadow(
                  color: _charColor.withAlpha(120),
                  blurRadius: 40,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: const Icon(Icons.school_rounded,
                size: 60, color: Colors.white),
          ),
        ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
        const SizedBox(height: 20),
        Text(
          '${widget.character.name.toUpperCase()} GETS IT',
          textAlign: TextAlign.center,
          style: GoogleFonts.orbitron(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: _charColor,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 4),
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
                i < _stars ? Icons.star_rounded : Icons.star_border_rounded,
                size: 42,
                color: i < _stars ? AppTheme.accentGold : AppTheme.textTertiary,
              )
                  .animate(delay: (i * 200).ms)
                  .scale(duration: 400.ms, curve: Curves.elasticOut),
            ),
          ),
        ),
        const SizedBox(height: 24),
        GlassContainer(
          borderColor: AppTheme.accentGold.withAlpha(60),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const Icon(Icons.bolt_rounded,
                  color: AppTheme.accentGold, size: 20),
              const SizedBox(width: 8),
              Text(
                '+$_xp XP',
                style: GoogleFonts.orbitron(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.accentGold,
                ),
              ),
              const Spacer(),
              Text(
                'teaching is mastery',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 11,
                  color: AppTheme.textTertiary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        NeonButton(
          label: 'DONE',
          icon: Icons.check_rounded,
          onTap: () => context.pop(),
        ),
      ],
    );
  }
}
