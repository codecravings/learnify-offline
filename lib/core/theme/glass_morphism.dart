import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:vidyasetu/core/theme/app_theme.dart';

/// A frosted-glass container that wraps its [child] in a translucent,
/// blurred surface with configurable glow borders and gradient overlays.
///
/// ```dart
/// GlassMorphism(
///   blur: 12,
///   borderRadius: 20,
///   child: Padding(
///     padding: EdgeInsets.all(16),
///     child: Text('Hello, glass world'),
///   ),
/// )
/// ```
class GlassMorphism extends StatelessWidget {
  const GlassMorphism({
    super.key,
    required this.child,
    this.blur = 10.0,
    this.borderRadius = 16.0,
    this.borderColor,
    this.borderWidth = 0.8,
    this.opacity = 0.1,
    this.glowColor,
    this.glowBlurRadius = 0,
    this.gradientColors,
    this.gradientBegin = Alignment.topLeft,
    this.gradientEnd = Alignment.bottomRight,
    this.shadowColor,
    this.shadowBlurRadius = 16,
    this.shadowOffset = Offset.zero,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.alignment,
  });

  /// The widget rendered inside the glass surface.
  final Widget child;

  /// Strength of the backdrop blur (both sigma X & Y).
  final double blur;

  /// Corner radius of the glass card.
  final double borderRadius;

  /// Color of the thin border stroke. Defaults to [AppTheme.glassBorder].
  final Color? borderColor;

  /// Thickness of the border stroke.
  final double borderWidth;

  /// Opacity of the white fill overlay (0..1).
  final double opacity;

  /// Optional neon-glow color drawn behind the glass surface.
  /// When non-null a blurred shadow ring is painted around the card.
  final Color? glowColor;

  /// Blur radius of the outer glow effect.
  final double glowBlurRadius;

  /// Colors for the gradient overlay on the glass surface.
  /// Defaults to a subtle white-to-transparent sweep.
  final List<Color>? gradientColors;

  /// Start alignment of the gradient overlay.
  final AlignmentGeometry gradientBegin;

  /// End alignment of the gradient overlay.
  final AlignmentGeometry gradientEnd;

  /// Shadow color beneath the glass card.
  final Color? shadowColor;

  /// Blur radius of the drop shadow.
  final double shadowBlurRadius;

  /// Offset of the drop shadow.
  final Offset shadowOffset;

  /// Inner padding.
  final EdgeInsetsGeometry? padding;

  /// Outer margin.
  final EdgeInsetsGeometry? margin;

  /// Fixed width (optional).
  final double? width;

  /// Fixed height (optional).
  final double? height;

  /// Content alignment inside the container.
  final AlignmentGeometry? alignment;

  // ─── Named Constructors ────────────────────────────────────────────

  /// Prominent card with a colored neon glow.
  const GlassMorphism.glow({
    super.key,
    required this.child,
    required Color this.glowColor,
    this.blur = 14.0,
    this.borderRadius = 20.0,
    this.borderColor,
    this.borderWidth = 1.0,
    this.opacity = 0.12,
    this.glowBlurRadius = 24,
    this.gradientColors,
    this.gradientBegin = Alignment.topLeft,
    this.gradientEnd = Alignment.bottomRight,
    this.shadowColor,
    this.shadowBlurRadius = 24,
    this.shadowOffset = Offset.zero,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.alignment,
  });

  /// Subtle glass for background panels and nav bars.
  const GlassMorphism.subtle({
    super.key,
    required this.child,
    this.blur = 6.0,
    this.borderRadius = 12.0,
    this.borderColor,
    this.borderWidth = 0.5,
    this.opacity = 0.06,
    this.glowColor,
    this.glowBlurRadius = 0,
    this.gradientColors,
    this.gradientBegin = Alignment.topLeft,
    this.gradientEnd = Alignment.bottomRight,
    this.shadowColor,
    this.shadowBlurRadius = 8,
    this.shadowOffset = Offset.zero,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.alignment,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBorderColor = borderColor ?? AppTheme.glassBorder;
    final effectiveGlowColor = glowColor;

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(borderRadius),
    );

    final defaultGradient = [
      Colors.white.withAlpha((opacity * 255).round()),
      Colors.white.withAlpha((opacity * 0.3 * 255).round()),
    ];

    return Container(
      width: width,
      height: height,
      margin: margin,
      alignment: alignment,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          // Outer neon glow
          if (effectiveGlowColor != null && glowBlurRadius > 0)
            BoxShadow(
              color: effectiveGlowColor.withAlpha(50),
              blurRadius: glowBlurRadius,
              spreadRadius: 1,
            ),
          // Drop shadow
          BoxShadow(
            color: (shadowColor ?? Colors.black).withAlpha(40),
            blurRadius: shadowBlurRadius,
            offset: shadowOffset,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: ShapeDecoration(
              shape: shape.copyWith(
                side: BorderSide(
                  color: effectiveBorderColor,
                  width: borderWidth,
                ),
              ),
              gradient: LinearGradient(
                colors: gradientColors ?? defaultGradient,
                begin: gradientBegin,
                end: gradientEnd,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Convenience extension for adding a glass effect to any widget.
extension GlassMorphismX on Widget {
  /// Wraps this widget inside a [GlassMorphism] container.
  Widget withGlass({
    double blur = 10,
    double borderRadius = 16,
    Color? glowColor,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
  }) {
    return GlassMorphism(
      blur: blur,
      borderRadius: borderRadius,
      glowColor: glowColor,
      padding: padding,
      margin: margin,
      child: this,
    );
  }
}
