import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/ai/gemma_service.dart';
import 'core/services/local_profile_service.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'routes/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize flutter_gemma runtime, then warm an already-installed
  // model if one exists (so cold relaunches skip /setup). If a sideloaded
  // file is present but not installed yet, silently install it now so the
  // user is never sent to /setup just because they pushed the file via adb.
  await GemmaService.instance.bootstrap();
  await GemmaService.instance.resumeIfInstalled();
  if (!GemmaService.instance.isReady &&
      await GemmaService.instance.hasSideloadedFile()) {
    try {
      await GemmaService.instance.initializeFromFile();
    } catch (_) {
      // Fall through — router will send the user to /setup where they can
      // retry manually and see the real error.
    }
  }

  // Load saved profile (replaces Firebase Auth state)
  await LocalProfileService.instance.initialize();

  // Load saved theme preference
  await ThemeProvider.instance.initialize();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const ProviderScope(child: LearnifyApp()));
}

class LearnifyApp extends ConsumerStatefulWidget {
  const LearnifyApp({super.key});

  @override
  ConsumerState<LearnifyApp> createState() => _LearnifyAppState();
}

class _LearnifyAppState extends ConsumerState<LearnifyApp> {
  @override
  void initState() {
    super.initState();
    ThemeProvider.instance.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    ThemeProvider.instance.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    setState(() {});
    _applySystemChrome();
  }

  void _applySystemChrome() {
    final isDark = ThemeProvider.instance.themeMode == ThemeMode.dark;
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor:
          isDark ? AppTheme.backgroundPrimary : AppTheme.lightBg,
      systemNavigationBarIconBrightness:
          isDark ? Brightness.light : Brightness.dark,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    _applySystemChrome();

    return MaterialApp.router(
      title: 'Learnify',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeProvider.instance.themeMode,
      routerConfig: router,
    );
  }
}
