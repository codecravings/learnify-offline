import 'package:flutter/material.dart';

/// Bionic Reading — bolds the first ~40% of each word so the eye anchors
/// on the strong cue and reads faster. Useful for dyslexic readers and
/// fast-skim contexts. Pure presentation, no deps.
///
/// Example:
///   BionicText(
///     text: 'Plants are like ninjas — they steal energy from the sun!',
///     style: GoogleFonts.spaceGrotesk(fontSize: 14),
///   )
class BionicText extends StatelessWidget {
  const BionicText({
    super.key,
    required this.text,
    required this.style,
    this.boldRatio = 0.4,
    this.textAlign = TextAlign.start,
    this.maxLines,
    this.overflow,
  });

  final String text;
  final TextStyle style;

  /// Fraction of each word's letters to bold from the start (0.0 – 1.0).
  /// Default 0.4 — research suggests ~40% gives the readability boost
  /// without making text feel artificial.
  final double boldRatio;
  final TextAlign textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(children: _buildSpans()),
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.clip,
    );
  }

  List<InlineSpan> _buildSpans() {
    final spans = <InlineSpan>[];
    final boldStyle = style.copyWith(fontWeight: FontWeight.w800);
    // Split preserving whitespace so we can rebuild the original layout.
    final tokens = text.split(RegExp(r'(\s+)'));
    for (final token in tokens) {
      if (token.isEmpty) continue;
      if (RegExp(r'^\s+$').hasMatch(token)) {
        spans.add(TextSpan(text: token, style: style));
        continue;
      }
      final cut = _bionicCut(token);
      if (cut == 0) {
        spans.add(TextSpan(text: token, style: style));
        continue;
      }
      spans.add(TextSpan(text: token.substring(0, cut), style: boldStyle));
      if (cut < token.length) {
        spans.add(TextSpan(text: token.substring(cut), style: style));
      }
    }
    return spans;
  }

  /// How many leading characters to bold. Skip non-letters at the start
  /// (quotes, parens, etc.) so the bold lands on actual letters.
  int _bionicCut(String word) {
    final letters = RegExp(r'[A-Za-zÀ-ɏऀ-ॿ]');
    var first = -1;
    for (var i = 0; i < word.length; i++) {
      if (letters.hasMatch(word[i])) {
        first = i;
        break;
      }
    }
    if (first < 0) return 0;
    final lettersOnly = word.substring(first);
    final boldLetters = (lettersOnly.length * boldRatio).ceil().clamp(1, lettersOnly.length);
    return first + boldLetters;
  }
}
