import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/ai/gemma_service.dart';
import '../core/theme/app_theme.dart';
import 'data/franchise_loader.dart';
import 'screens/lab_setup_screen.dart';
import 'screens/lab_shell.dart';
import 'services/lab_profile_service.dart';

/// Franchise Lab entry point.
///
/// Run with: flutter run -t lib/franchise_lab/main.dart
///
/// Prereq: open the main app first to install the Gemma .litertlm model.
/// The lab assumes the model is already on disk; it will not download.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Bootstrap shared Gemma runtime + try to warm a previously-installed model.
  await GemmaService.instance.bootstrap();
  await GemmaService.instance.resumeIfInstalled();

  // If still not ready but a sideloaded file exists, install silently.
  if (!GemmaService.instance.isReady &&
      await GemmaService.instance.hasSideloadedFile()) {
    try {
      await GemmaService.instance.initializeFromFile();
    } catch (_) {/* surfaced in UI */}
  }

  // Lab uses isolated DB.
  await LabProfileService.instance.initialize();

  // Pre-warm dataset so the first picker open is instant.
  unawaited(FranchiseLoader.instance.all());

  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const FranchiseLabApp());
}

class FranchiseLabApp extends StatefulWidget {
  const FranchiseLabApp({super.key});

  @override
  State<FranchiseLabApp> createState() => _FranchiseLabAppState();
}

class _FranchiseLabAppState extends State<FranchiseLabApp> {
  @override
  void initState() {
    super.initState();
    LabProfileService.instance.addListener(_onProfileChanged);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppTheme.backgroundPrimary,
      systemNavigationBarIconBrightness: Brightness.light,
    ));
  }

  @override
  void dispose() {
    LabProfileService.instance.removeListener(_onProfileChanged);
    super.dispose();
  }

  void _onProfileChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Franchise Lab',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme.copyWith(
        textTheme: GoogleFonts.spaceGroteskTextTheme(AppTheme.darkTheme.textTheme),
      ),
      home: _decideHome(),
    );
  }

  Widget _decideHome() {
    if (!GemmaService.instance.isReady) {
      return const _ModelMissingScreen();
    }
    if (!LabProfileService.instance.hasProfile) {
      return const LabSetupScreen();
    }
    return const LabShell();
  }
}

/// Shown when the lab is launched without the model on disk.
class _ModelMissingScreen extends StatelessWidget {
  const _ModelMissingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundPrimary,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.psychology_alt_rounded,
                    size: 56, color: AppTheme.accentMagenta),
                const SizedBox(height: 16),
                Text('Model not installed',
                    style: AppTheme.headerStyle(fontSize: 24)),
                const SizedBox(height: 8),
                Text(
                  'Franchise Lab uses the same Gemma 4 model as the main Learnify app. '
                  'Open the main app first, install the model from the setup screen, '
                  'then come back here.',
                  style: AppTheme.bodyStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tiny shim so `unawaited()` doesn't need a separate import.
void unawaited(Future<void> f) {}
