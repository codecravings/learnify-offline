import 'package:flutter/material.dart';

/// Renders text with one word visually highlighted — matches the
/// TextToSpeechService.wordIndexStream so the UI shows a karaoke-style
/// follow-along while the TTS engine speaks.
///
/// Word splitting MUST match TextToSpeechService._rebuildWordBoundaries
/// (`RegExp(r'\S+')`) so indices align with the engine's progress callbacks.
class KaraokeText extends StatelessWidget {
  const KaraokeText({
    super.key,
    required this.text,
    required this.style,
    required this.activeWordIndex,
    this.highlightColor,
    this.highlightBackground,
    this.textAlign = TextAlign.start,
  });

  final String text;
  final TextStyle style;

  /// Index of the word to highlight, or -1 for no highlight.
  final int activeWordIndex;

  /// Foreground color for the active word. Defaults to neon cyan.
  final Color? highlightColor;

  /// Background tint behind the active word. Defaults to a subtle cyan glow.
  final Color? highlightBackground;

  final TextAlign textAlign;

  static const _defaultHighlight = Color(0xFF00F5FF);
  static const _defaultHighlightBg = Color(0x3300F5FF);

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(children: _buildSpans()),
      style: style,
      textAlign: textAlign,
    );
  }

  List<InlineSpan> _buildSpans() {
    final spans = <InlineSpan>[];
    final wordPattern = RegExp(r'\S+');
    final highlightFg = highlightColor ?? _defaultHighlight;
    final highlightBg = highlightBackground ?? _defaultHighlightBg;

    var lastEnd = 0;
    var wordIdx = 0;
    for (final m in wordPattern.allMatches(text)) {
      // Whitespace before this word.
      if (m.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, m.start), style: style));
      }
      final isActive = wordIdx == activeWordIndex && activeWordIndex >= 0;
      spans.add(TextSpan(
        text: m.group(0),
        style: isActive
            ? style.copyWith(
                color: highlightFg,
                fontWeight: FontWeight.w800,
                backgroundColor: highlightBg,
              )
            : style,
      ));
      lastEnd = m.end;
      wordIdx++;
    }
    // Trailing whitespace.
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd), style: style));
    }
    return spans;
  }
}
