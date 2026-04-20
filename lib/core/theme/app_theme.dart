import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Learnify design system — clean solid colors for both dark & light modes.
class AppTheme {
  AppTheme._();

  // ─── Unified Solid Accent Palette ──────────────────────────────────
  // Same palette for both dark & light — mid-saturation, readable everywhere.
  static const Color accentCyan = Color(0xFF2563EB);       // solid blue
  static const Color accentPurple = Color(0xFF7C3AED);     // solid purple
  static const Color accentMagenta = Color(0xFFDC2626);    // solid red
  static const Color accentGreen = Color(0xFF16A34A);      // solid green
  static const Color accentGold = Color(0xFFD97706);       // solid amber
  static const Color accentOrange = Color(0xFFEA580C);     // solid orange

  // Slight brightness tweaks for dark backgrounds (a touch brighter).
  static const Color _darkCyan = Color(0xFF3B82F6);
  static const Color _darkPurple = Color(0xFF8B5CF6);
  static const Color _darkMagenta = Color(0xFFEF4444);
  static const Color _darkGreen = Color(0xFF22C55E);
  static const Color _darkGold = Color(0xFFF59E0B);
  static const Color _darkOrange = Color(0xFFF97316);

  /// Theme-adaptive accent colors — slightly brighter on dark, standard on light.
  static Color accentCyanOf(BuildContext context) =>
      isDark(context) ? _darkCyan : accentCyan;
  static Color accentPurpleOf(BuildContext context) =>
      isDark(context) ? _darkPurple : accentPurple;
  static Color accentMagentaOf(BuildContext context) =>
      isDark(context) ? _darkMagenta : accentMagenta;
  static Color accentGreenOf(BuildContext context) =>
      isDark(context) ? _darkGreen : accentGreen;
  static Color accentGoldOf(BuildContext context) =>
      isDark(context) ? _darkGold : accentGold;
  static Color accentOrangeOf(BuildContext context) =>
      isDark(context) ? _darkOrange : accentOrange;

  // ─── Dark Mode Palette ─────────────────────────────────────────────
  static const Color backgroundPrimary = Color(0xFF111827);   // gray-900
  static const Color backgroundSecondary = Color(0xFF1F2937); // gray-800
  static const Color backgroundTertiary = Color(0xFF1E293B);  // slate-800
  static const Color surfaceDark = Color(0xFF1F2937);
  static const Color surfaceLight = Color(0xFF374151);        // gray-700

  static const Color glassFill = Color(0x1AFFFFFF);
  static const Color glassBorder = Color(0x33FFFFFF);
  static const Color glassHighlight = Color(0x0DFFFFFF);

  static const Color textPrimary = Color(0xFFF9FAFB);    // gray-50
  static const Color textSecondary = Color(0xFF9CA3AF);   // gray-400
  static const Color textTertiary = Color(0xFF6B7280);    // gray-500
  static const Color textDisabled = Color(0xFF4B5563);    // gray-600

  // ─── Light Mode Palette ────────────────────────────────────────────
  static const Color lightBg = Color(0xFFF9FAFB);        // gray-50
  static const Color lightBg2 = Color(0xFFF3F4F6);       // gray-100
  static const Color lightBg3 = Color(0xFFE5E7EB);       // gray-200
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurface2 = Color(0xFFF3F4F6);

  static const Color lightGlassFill = Color(0x0A000000);
  static const Color lightGlassBorder = Color(0x14000000);

  static const Color lightTextPrimary = Color(0xFF111827);   // gray-900
  static const Color lightTextSecondary = Color(0xFF4B5563); // gray-600
  static const Color lightTextTertiary = Color(0xFF9CA3AF);  // gray-400
  static const Color lightTextDisabled = Color(0xFFD1D5DB);  // gray-300

  // ─── Semantic Colors ───────────────────────────────────────────────
  static const Color success = accentGreen;
  static const Color error = accentMagenta;
  static const Color warning = accentOrange;
  static const Color info = accentCyan;

  // ─── Gradients ─────────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [accentCyan, accentPurple],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient primaryGradientOf(BuildContext context) =>
      isDark(context)
          ? const LinearGradient(
              colors: [_darkCyan, _darkPurple],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            )
          : primaryGradient;

  static const LinearGradient secondaryGradient = LinearGradient(
    colors: [accentPurple, accentMagenta],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [accentGreen, accentCyan],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [backgroundPrimary, backgroundSecondary, backgroundTertiary],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: [0.0, 0.5, 1.0],
  );

  static const LinearGradient lightBackgroundGradient = LinearGradient(
    colors: [lightBg, lightBg2, lightBg3],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: [0.0, 0.5, 1.0],
  );

  static const RadialGradient glowCyan = RadialGradient(
    colors: [Color(0x222563EB), Color(0x002563EB)],
    radius: 0.8,
  );

  static const RadialGradient glowPurple = RadialGradient(
    colors: [Color(0x227C3AED), Color(0x007C3AED)],
    radius: 0.8,
  );

  // ─── Context-Aware Helpers ─────────────────────────────────────────

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  /// Background decoration for scaffold bodies — adapts to theme.
  static BoxDecoration scaffoldDecorationOf(BuildContext context) =>
      BoxDecoration(
        gradient: isDark(context) ? backgroundGradient : lightBackgroundGradient,
      );

  /// Legacy getter for backward compatibility (always dark).
  static BoxDecoration get scaffoldDecoration =>
      const BoxDecoration(gradient: backgroundGradient);

  /// Adaptive glass fill color.
  static Color glassFillOf(BuildContext context) =>
      isDark(context) ? glassFill : lightGlassFill;

  /// Adaptive glass border color.
  static Color glassBorderOf(BuildContext context) =>
      isDark(context) ? glassBorder : lightGlassBorder;

  /// Adaptive text colors.
  static Color textPrimaryOf(BuildContext context) =>
      isDark(context) ? textPrimary : lightTextPrimary;
  static Color textSecondaryOf(BuildContext context) =>
      isDark(context) ? textSecondary : lightTextSecondary;
  static Color textTertiaryOf(BuildContext context) =>
      isDark(context) ? textTertiary : lightTextTertiary;

  /// Adaptive surface colors.
  static Color surfaceDarkOf(BuildContext context) =>
      isDark(context) ? surfaceDark : lightSurface;
  static Color surfaceLightOf(BuildContext context) =>
      isDark(context) ? surfaceLight : lightSurface2;

  // ─── Text Themes ───────────────────────────────────────────────────

  static TextStyle headerStyle({
    double fontSize = 24,
    FontWeight fontWeight = FontWeight.w700,
    Color color = textPrimary,
    double letterSpacing = 1.2,
  }) {
    return GoogleFonts.orbitron(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle bodyStyle({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w400,
    Color color = textPrimary,
    double? height,
    double? letterSpacing,
  }) {
    return GoogleFonts.spaceGrotesk(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height ?? 1.5,
      letterSpacing: letterSpacing,
    );
  }

  static TextTheme _textTheme(Color primary, Color secondary, Color tertiary) {
    return TextTheme(
      displayLarge: headerStyle(fontSize: 32, fontWeight: FontWeight.w900, color: primary),
      displayMedium: headerStyle(fontSize: 28, fontWeight: FontWeight.w800, color: primary),
      displaySmall: headerStyle(fontSize: 24, color: primary),
      headlineLarge: headerStyle(fontSize: 22, fontWeight: FontWeight.w600, color: primary),
      headlineMedium: headerStyle(fontSize: 20, fontWeight: FontWeight.w600, color: primary),
      headlineSmall: headerStyle(fontSize: 18, fontWeight: FontWeight.w600, color: primary),
      titleLarge: bodyStyle(fontSize: 18, fontWeight: FontWeight.w600, color: primary),
      titleMedium: bodyStyle(fontSize: 16, fontWeight: FontWeight.w600, color: primary),
      titleSmall: bodyStyle(fontSize: 14, fontWeight: FontWeight.w600, color: primary),
      bodyLarge: bodyStyle(fontSize: 16, color: primary),
      bodyMedium: bodyStyle(fontSize: 14, color: primary),
      bodySmall: bodyStyle(fontSize: 12, color: secondary),
      labelLarge: bodyStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.8, color: primary),
      labelMedium: bodyStyle(fontSize: 12, fontWeight: FontWeight.w500, color: primary),
      labelSmall: bodyStyle(fontSize: 10, fontWeight: FontWeight.w500, color: tertiary),
    );
  }

  // ─── Dark ThemeData ────────────────────────────────────────────────

  static ThemeData get darkTheme {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: backgroundPrimary,
      colorScheme: const ColorScheme.dark(
        primary: _darkCyan,
        onPrimary: Colors.white,
        secondary: _darkPurple,
        onSecondary: textPrimary,
        tertiary: _darkMagenta,
        surface: backgroundSecondary,
        onSurface: textPrimary,
        error: _darkMagenta,
        onError: textPrimary,
        outline: glassBorder,
      ),
      textTheme: _textTheme(textPrimary, textSecondary, textTertiary),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: headerStyle(fontSize: 18),
        iconTheme: const IconThemeData(color: _darkCyan, size: 22),
      ),
      cardTheme: CardThemeData(
        color: glassFill,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: glassBorder, width: 0.5),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _darkCyan,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: bodyStyle(fontSize: 14, fontWeight: FontWeight.w700),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _darkCyan,
          side: const BorderSide(color: _darkCyan, width: 1.2),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: bodyStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _darkCyan,
          textStyle: bodyStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: glassFill,
        hintStyle: bodyStyle(color: textTertiary),
        labelStyle: bodyStyle(color: textSecondary),
        prefixIconColor: textTertiary,
        suffixIconColor: textTertiary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: glassBorder, width: 0.8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _darkCyan, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _darkMagenta, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _darkMagenta, width: 1.5),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent,
        selectedItemColor: _darkCyan,
        unselectedItemColor: textTertiary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: glassFill,
        side: const BorderSide(color: glassBorder, width: 0.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        labelStyle: bodyStyle(fontSize: 12),
      ),
      dividerTheme: const DividerThemeData(color: glassBorder, thickness: 0.5, space: 1),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: _darkCyan,
        linearTrackColor: surfaceLight,
        circularTrackColor: surfaceLight,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceLight,
        contentTextStyle: bodyStyle(fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: backgroundSecondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: glassBorder, width: 0.5),
        ),
        titleTextStyle: headerStyle(fontSize: 20),
        contentTextStyle: bodyStyle(fontSize: 14, color: textSecondary),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: surfaceLight,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: glassBorder, width: 0.5),
        ),
        textStyle: bodyStyle(fontSize: 12),
      ),
    );
  }

  // ─── Light ThemeData ───────────────────────────────────────────────

  static ThemeData get lightTheme {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: lightBg,
      colorScheme: ColorScheme.light(
        primary: accentCyan,
        onPrimary: Colors.white,
        secondary: accentPurple,
        onSecondary: Colors.white,
        tertiary: accentMagenta,
        surface: lightSurface,
        onSurface: lightTextPrimary,
        error: accentMagenta,
        onError: Colors.white,
        outline: lightGlassBorder,
        surfaceContainerHighest: lightSurface2,
      ),
      textTheme: _textTheme(lightTextPrimary, lightTextSecondary, lightTextTertiary),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: headerStyle(fontSize: 18, color: lightTextPrimary),
        iconTheme: const IconThemeData(color: accentCyan, size: 22),
      ),
      cardTheme: CardThemeData(
        color: lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: lightGlassBorder, width: 0.5),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentCyan,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: bodyStyle(fontSize: 14, fontWeight: FontWeight.w700),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accentCyan,
          side: const BorderSide(color: accentCyan, width: 1.2),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: bodyStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accentCyan,
          textStyle: bodyStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightSurface,
        hintStyle: bodyStyle(color: lightTextTertiary),
        labelStyle: bodyStyle(color: lightTextSecondary),
        prefixIconColor: lightTextTertiary,
        suffixIconColor: lightTextTertiary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: lightGlassBorder, width: 0.8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accentCyan, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accentMagenta, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accentMagenta, width: 1.5),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent,
        selectedItemColor: accentCyan,
        unselectedItemColor: lightTextTertiary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: lightSurface,
        side: BorderSide(color: lightGlassBorder, width: 0.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        labelStyle: bodyStyle(fontSize: 12, color: lightTextPrimary),
      ),
      dividerTheme: DividerThemeData(color: lightGlassBorder, thickness: 0.5, space: 1),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: accentCyan,
        linearTrackColor: lightBg3,
        circularTrackColor: lightBg3,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: lightSurface,
        contentTextStyle: bodyStyle(fontSize: 14, color: lightTextPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: lightSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: lightGlassBorder, width: 0.5),
        ),
        titleTextStyle: headerStyle(fontSize: 20, color: lightTextPrimary),
        contentTextStyle: bodyStyle(fontSize: 14, color: lightTextSecondary),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: lightSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: lightGlassBorder, width: 0.5),
        ),
        textStyle: bodyStyle(fontSize: 12, color: lightTextPrimary),
      ),
    );
  }

  // ─── Decoration Helpers ────────────────────────────────────────────

  static List<BoxShadow> neonGlow(Color color, {double blur = 20}) {
    return [
      BoxShadow(color: color.withAlpha(40), blurRadius: blur, spreadRadius: 1),
      BoxShadow(color: color.withAlpha(15), blurRadius: blur * 1.5, spreadRadius: 2),
    ];
  }

  static BoxDecoration glassDecoration({
    double borderRadius = 16,
    Color borderColor = glassBorder,
    double borderWidth = 0.8,
    List<Color>? gradientColors,
  }) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: borderColor, width: borderWidth),
      gradient: LinearGradient(
        colors: gradientColors ?? [Colors.white.withAlpha(18), Colors.white.withAlpha(8)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    );
  }

  static Shader textGradientShader(Rect bounds, {Gradient? gradient}) {
    return (gradient ?? primaryGradient).createShader(bounds);
  }
}

/// Extension for quick theme access from BuildContext.
extension ThemeContextX on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colorScheme => theme.colorScheme;
  TextTheme get textTheme => theme.textTheme;
  bool get isDark => theme.brightness == Brightness.dark;
}
