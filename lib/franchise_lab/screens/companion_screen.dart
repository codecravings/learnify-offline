import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
import '../services/lab_memory_service.dart';
import '../services/lab_orchestrator.dart';

class _ChatTurn {
  _ChatTurn({required this.fromUser, required this.text});
  final bool fromUser;
  String text;
}

class CompanionScreen extends StatefulWidget {
  const CompanionScreen({super.key});

  @override
  State<CompanionScreen> createState() => _CompanionScreenState();
}

class _CompanionScreenState extends State<CompanionScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  final _orchestrator = LabOrchestrator.instance;
  final _memory = LabMemoryService.instance;
  final List<_ChatTurn> _turns = [];
  bool _streaming = false;

  static const _suggestions = [
    'What should I study next?',
    'Where am I weak?',
    'Quiz me on my weak topics',
    'Make a 7-day study plan',
  ];

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send([String? prefilled]) async {
    final question = (prefilled ?? _ctrl.text).trim();
    if (question.isEmpty || _streaming) return;
    _ctrl.clear();

    setState(() {
      _turns.add(_ChatTurn(fromUser: true, text: question));
      _turns.add(_ChatTurn(fromUser: false, text: ''));
      _streaming = true;
    });
    _scrollToBottom();

    final reply = StringBuffer();
    try {
      await for (final token in _orchestrator.companionStream(question)) {
        reply.write(token);
        if (!mounted) return;
        setState(() => _turns.last.text = reply.toString());
        _scrollToBottom();
      }
      await _memory.retainChatExchange(
        question: question,
        answer: reply.toString(),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _turns.last.text = 'Error: $e');
      }
    } finally {
      if (mounted) setState(() => _streaming = false);
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
    return Scaffold(
      backgroundColor: AppTheme.backgroundPrimary,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _turns.isEmpty ? _buildEmpty() : _buildChat(),
            ),
            _buildInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: const LinearGradient(
                colors: [AppTheme.accentMagenta, AppTheme.accentPurple],
              ),
            ),
            child: const Icon(Icons.psychology_rounded, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Learner Twin',
                  style: GoogleFonts.orbitron(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  )),
              Text('On-device · streaming',
                  style: AppTheme.bodyStyle(
                    fontSize: 11,
                    color: AppTheme.textTertiary,
                  )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Spacer(),
          Icon(Icons.auto_awesome_rounded,
              size: 56, color: AppTheme.accentMagenta),
          const SizedBox(height: 14),
          Text('Ask your Twin anything',
              style: GoogleFonts.orbitron(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              )),
          const SizedBox(height: 8),
          Text(
            'Your Twin remembers what you studied, what you missed, and what you '
            'mastered — all on-device.',
            textAlign: TextAlign.center,
            style: AppTheme.bodyStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: _suggestions
                .map((s) => InkWell(
                      onTap: () => _send(s),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: Colors.white.withAlpha(15),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Text(
                          s,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ))
                .toList(),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildChat() {
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: _turns.length,
      itemBuilder: (_, i) {
        final t = _turns[i];
        return Align(
          alignment: t.fromUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.82,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: t.fromUser
                  ? AppTheme.accentMagenta.withAlpha(60)
                  : Colors.white.withAlpha(15),
              border: Border.all(
                color: t.fromUser
                    ? AppTheme.accentMagenta.withAlpha(120)
                    : Colors.white24,
              ),
            ),
            child: Text(
              t.text.isEmpty ? '…' : t.text,
              style: const TextStyle(color: Colors.white, height: 1.4),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInput() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        12,
        8,
        12,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: AppTheme.backgroundPrimary,
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _ctrl,
              enabled: !_streaming,
              style: const TextStyle(color: Colors.white),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              decoration: InputDecoration(
                hintText: _streaming ? 'Twin is replying…' : 'Ask your Twin…',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.white.withAlpha(15),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide:
                      BorderSide(color: AppTheme.accentMagenta, width: 1.4),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _streaming ? null : () => _send(),
            icon: Icon(Icons.send_rounded,
                color: _streaming ? Colors.white24 : AppTheme.accentMagenta),
          ),
        ],
      ),
    );
  }
}
