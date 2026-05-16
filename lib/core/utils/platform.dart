import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Platform-aware UX helpers. Glass intensity, motion curves, transitions
/// and haptics all branch on iOS vs Android through this single module so
/// the rest of the codebase stays platform-agnostic.
class PlatformX {
  PlatformX._();

  static bool get isIOS => Platform.isIOS;
  static bool get isAndroid => Platform.isAndroid;

  /// Apple-style spring curve, lifted from iOS Sheet / Sheet detent feel.
  /// Slightly overshoots, settles fast — used for tap-scale and pill move.
  static const Curve springCurve = Cubic(0.32, 0.72, 0, 1);

  static const Duration motionFast = Duration(milliseconds: 220);
  static const Duration motionMedium = Duration(milliseconds: 320);
  static const Duration motionSlow = Duration(milliseconds: 480);

  /// Light tap feedback (button / chip press). No-op on platforms without
  /// haptics. Cheap to call — Flutter dedupes within a frame.
  static void tapHaptic() {
    if (isIOS) {
      HapticFeedback.lightImpact();
    } else {
      HapticFeedback.selectionClick();
    }
  }

  /// Heavier confirmation feedback (sheet expand, primary CTA).
  static void thunkHaptic() {
    if (isIOS) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.heavyImpact();
    }
  }
}
