import 'dart:ui';

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/platform.dart';

/// Visual intensity tier for glass surfaces. iOS gets the heavier blur and
/// sheen so it feels native; Android renders a tamer variant to keep frame
/// pacing healthy during Gemma inference (BackdropFilter is GPU-heavy).
enum GlassIntensity { subtle, medium, strong }

/// Reusable glassmorphism container — backdrop-blur frosted surface with an
/// inner top-edge highlight, a diagonal sheen, and optional spring tap-scale.
///
/// API is backward-compatible with the old version: passing `blur:` still
/// works as an explicit override. When `intensity` is given the blur sigma
/// is chosen per-platform (heavier on iOS).
class GlassContainer extends StatefulWidget {
  const GlassContainer({
    super.key,
    required this.child,
    this.intensity = GlassIntensity.medium,
    this.blur,
    this.borderRadius = 16,
    this.borderColor,
    this.borderWidth = 0.8,
    this.padding,
    this.margin,
    this.onTap,
    this.width,
    this.height,
    this.glow,
  });

  final Widget child;

  /// Platform-aware blur tier. Ignored when [blur] is provided.
  final GlassIntensity intensity;

  /// Explicit blur sigma override (legacy API). Overrides [intensity].
  final double? blur;

  final double borderRadius;
  final Color? borderColor;
  final double borderWidth;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final double? width;
  final double? height;

  /// Optional accent glow color rendered as a soft outer halo.
  final Color? glow;

  @override
  State<GlassContainer> createState() => _GlassContainerState();
}

class _GlassContainerState extends State<GlassContainer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scaleCtrl;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: PlatformX.motionFast,
      lowerBound: 0.96,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    super.dispose();
  }

  double _resolveBlur() {
    if (widget.blur != null) return widget.blur!;
    final ios = PlatformX.isIOS;
    switch (widget.intensity) {
      case GlassIntensity.subtle:
        return ios ? 16 : 8;
      case GlassIntensity.medium:
        return ios ? 24 : 12;
      case GlassIntensity.strong:
        return ios ? 36 : 16;
    }
  }

  void _setPressed(bool v) {
    if (v == _pressed) return;
    _pressed = v;
    if (v) {
      _scaleCtrl.animateTo(0.96, curve: PlatformX.springCurve);
    } else {
      _scaleCtrl.animateTo(1.0, curve: PlatformX.springCurve);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = AppTheme.isDark(context);
    final effectiveBorder = widget.borderColor ??
        (dark ? AppTheme.glassBorder : AppTheme.lightGlassBorder);

    final fillColors = dark
        ? [Colors.white.withAlpha(26), Colors.white.withAlpha(13)]
        : [Colors.white.withAlpha(200), Colors.white.withAlpha(140)];

    final blur = _resolveBlur();
    final radius = BorderRadius.circular(widget.borderRadius);

    Widget glass = ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Stack(
          children: [
            // Base frosted fill + border.
            Container(
              width: widget.width,
              height: widget.height,
              padding: widget.padding,
              decoration: BoxDecoration(
                borderRadius: radius,
                border:
                    Border.all(color: effectiveBorder, width: widget.borderWidth),
                gradient: LinearGradient(
                  colors: fillColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: dark
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.black.withAlpha(8),
                          blurRadius: 12,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: widget.child,
            ),
            // Top-edge inner highlight — the bright wet rim iOS surfaces have.
            if (dark)
              IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: radius,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withAlpha(22),
                        Colors.white.withAlpha(0),
                      ],
                      stops: const [0, 0.18],
                    ),
                  ),
                ),
              ),
            // Diagonal sheen — adds depth on iOS, subtle on Android.
            if (PlatformX.isIOS)
              IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: radius,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withAlpha(dark ? 18 : 60),
                        Colors.white.withAlpha(0),
                        Colors.white.withAlpha(0),
                      ],
                      stops: const [0, 0.35, 1],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    // Optional outer glow halo.
    if (widget.glow != null) {
      glass = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: widget.glow!.withAlpha(60),
              blurRadius: 24,
              spreadRadius: 1,
            ),
            BoxShadow(
              color: widget.glow!.withAlpha(20),
              blurRadius: 40,
              spreadRadius: 4,
            ),
          ],
        ),
        child: glass,
      );
    }

    if (widget.margin != null) {
      glass = Padding(padding: widget.margin!, child: glass);
    }

    if (widget.onTap != null) {
      glass = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: () {
          PlatformX.tapHaptic();
          widget.onTap!();
        },
        child: ScaleTransition(scale: _scaleCtrl, child: glass),
      );
    }

    return glass;
  }
}
