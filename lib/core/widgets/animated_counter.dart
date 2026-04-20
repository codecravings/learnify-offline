import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';

/// Animates a number from 0 up to [value] over [duration].
///
/// Useful for XP counters, rank numbers, streaks, etc.
class AnimatedCounter extends StatefulWidget {
  const AnimatedCounter({
    super.key,
    required this.value,
    this.duration = const Duration(milliseconds: 1200),
    this.style,
    this.prefix,
    this.suffix,
    this.curve = Curves.easeOutCubic,
  });

  /// Target integer value to count up to.
  final int value;

  /// Animation duration.
  final Duration duration;

  /// Text style for the number.
  final TextStyle? style;

  /// Text shown before the number (e.g. "#").
  final String? prefix;

  /// Text shown after the number (e.g. "XP", "d").
  final String? suffix;

  /// Animation curve.
  final Curve curve;

  @override
  State<AnimatedCounter> createState() => _AnimatedCounterState();
}

class _AnimatedCounterState extends State<AnimatedCounter>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant AnimatedCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final defaultStyle = GoogleFonts.orbitron(
      fontSize: 20,
      fontWeight: FontWeight.w800,
      color: AppTheme.textPrimary,
    );

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        final current = (_animation.value * widget.value).round();
        final text = '${widget.prefix ?? ''}$current${widget.suffix ?? ''}';

        return Text(
          text,
          style: widget.style ?? defaultStyle,
        );
      },
    );
  }
}
