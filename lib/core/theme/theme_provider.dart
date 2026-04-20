import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Singleton provider for theme mode switching with SharedPreferences persistence.
///
/// Default is dark mode, matching the app's neon/glassmorphism aesthetic.
/// Stores the user's preference under the key `theme_mode` with values
/// `'dark'`, `'light'`, or `'system'`.
class ThemeProvider extends ChangeNotifier {
  ThemeProvider._internal();

  static final ThemeProvider _instance = ThemeProvider._internal();

  static ThemeProvider get instance => _instance;

  factory ThemeProvider() => _instance;

  static const String _prefsKey = 'theme_mode';

  ThemeMode _themeMode = ThemeMode.dark;

  /// The current [ThemeMode].
  ThemeMode get themeMode => _themeMode;

  /// Initializes the provider by loading the saved preference.
  /// Safe to call multiple times; only the first invocation reads from disk.
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    if (saved != null) {
      _themeMode = _themeModeFromString(saved);
    }
    // No notifyListeners here — called before the widget tree is built.
  }

  /// Cycles through theme modes: dark -> light -> system -> dark.
  void toggleTheme() {
    switch (_themeMode) {
      case ThemeMode.dark:
        setThemeMode(ThemeMode.light);
        break;
      case ThemeMode.light:
        setThemeMode(ThemeMode.system);
        break;
      case ThemeMode.system:
        setThemeMode(ThemeMode.dark);
        break;
    }
  }

  /// Sets the theme mode and persists the choice.
  void setThemeMode(ThemeMode mode) {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    _persist(mode);
  }

  /// Fire-and-forget persistence — never blocks the UI.
  Future<void> _persist(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, _themeModeToString(mode));
  }

  static String _themeModeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.light:
        return 'light';
      case ThemeMode.system:
        return 'system';
    }
  }

  static ThemeMode _themeModeFromString(String value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'system':
        return ThemeMode.system;
      case 'dark':
      default:
        return ThemeMode.dark;
    }
  }
}
