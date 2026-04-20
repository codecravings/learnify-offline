import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';

/// A gradient button with a neon glow shadow effect.
///
/// Supports a loading spinner, disabled state, and an optional leading icon.
class NeonButton extends StatelessWidget {
  const NeonButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.colors = const [AppTheme.accentCyan, AppTheme.accentPurple],
    this.isLoading = false,
    this.isDisabled = false,
    this.height = 48,
    this.borderRadius = 12,
    this.fontSize = 13,
  });

  /// Button label text.
  final String label;

  /// Tap callback. Ignored when [isLoading] or [isDisabled].
  final VoidCallback onTap;

  /// Optional leading icon.
  final IconData? icon;

  /// Gradient colors. First is leading, second is trailing.
  final List<Color> colors;

  /// Shows a spinner instead of the label.
  final bool isLoading;

  /// Dims the button and ignores taps.
  final bool isDisabled;

  /// Fixed height.
  final double height;

  /// Corner radius.
  final double borderRadius;

  /// Label font size.
  final double fontSize;

  bool get _disabled => isLoading || isDisabled;

  @override
  Widget build(BuildContext context) {
    final gradient = LinearGradient(colors: colors);

    return GestureDetector(
      onTap: _disabled ? null : onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: _disabled ? 0.45 : 1.0,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(borderRadius),
            boxShadow: _disabled
                ? null
                : [
                    BoxShadow(
                      color: colors.first.withAlpha(80),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: colors.last.withAlpha(50),
                      blurRadius: 24,
                      offset: const Offset(0, 6),
                    ),
                  ],
          ),
          alignment: Alignment.center,
          child: isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, color: Colors.white, size: 18),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      label,
                      style: GoogleFonts.orbitron(
                        fontSize: fontSize,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
