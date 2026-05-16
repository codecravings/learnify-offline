import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/ai/gemma_service.dart';
import '../core/services/local_profile_service.dart';
import '../core/utils/platform.dart';
import '../features/setup/screens/bootstrap_screen.dart';
import '../features/setup/screens/model_download_screen.dart';
import '../features/setup/screens/profile_setup_screen.dart';
import '../features/auth/screens/home_screen.dart';
import '../features/companion/screens/study_companion_screen.dart';
import '../features/profile/screens/profile_screen.dart';
import '../features/story_learning/screens/story_screen.dart';
import '../features/story_learning/screens/feynman_screen.dart';
import '../features/scan/screens/scan_textbook_screen.dart';
import '../features/mastery_path/screens/mastery_path_screen.dart';
import '../core/franchises/franchise_loader.dart';

abstract class AppRoutes {
  static const String setup = '/setup';
  static const String setupProfile = '/setup/profile';
  /// Cold-launch warm-up splash — runs the heavy `resumeIfInstalled` flow
  /// with a real progress bar instead of a mute black native splash.
  static const String setupBootstrap = '/setup/bootstrap';
  static const String home = '/home';
  static const String lesson = '/lesson';
  static const String feynman = '/feynman';
  static const String scan = '/scan';
  static const String masteryPath = '/mastery-path';
  static const String userProfile = '/profile';
}

/// CupertinoPage on iOS (swipe-back for free), MaterialPage on Android.
Page<T> _platformPage<T>(GoRouterState state, Widget child) {
  if (PlatformX.isIOS) {
    return CupertinoPage<T>(
      key: state.pageKey,
      name: state.name,
      child: child,
    );
  }
  return MaterialPage<T>(
    key: state.pageKey,
    name: state.name,
    child: child,
  );
}

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.home,
    debugLogDiagnostics: true,
    redirect: (BuildContext context, GoRouterState state) {
      final hasProfile = LocalProfileService.instance.hasProfile;
      final modelReady = GemmaService.instance.isReady;
      final hasFile = GemmaService.instance.hasSideloadedFileSync;
      final loc = state.matchedLocation;

      // Already on a setup-flow screen — let the screen drive transitions.
      if (loc.startsWith('/setup')) return null;

      // Model not yet warmed in this process. If a model file is on disk,
      // route through the bootstrap splash (with progress bar). Otherwise
      // hand off to the download screen.
      if (!modelReady) {
        return hasFile ? AppRoutes.setupBootstrap : AppRoutes.setup;
      }

      // Model ready but no profile yet
      if (!hasProfile) return AppRoutes.setupProfile;

      return null;
    },
    routes: [
      // ── Setup flow ────────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.setup,
        pageBuilder: (_, state) =>
            _platformPage(state, const ModelDownloadScreen()),
      ),
      GoRoute(
        path: AppRoutes.setupBootstrap,
        pageBuilder: (_, state) =>
            _platformPage(state, const BootstrapScreen()),
      ),
      GoRoute(
        path: AppRoutes.setupProfile,
        pageBuilder: (_, state) =>
            _platformPage(state, const ProfileSetupScreen()),
      ),

      // ── Home shell (bottom nav: Home / Companion / Profile) ───────────────
      ShellRoute(
        builder: (context, state, child) => HomeScreen(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            pageBuilder: (_, state) =>
                _platformPage(state, const HomeDashboard()),
          ),
          GoRoute(
            path: '/home/companion',
            pageBuilder: (_, state) =>
                _platformPage(state, const StudyCompanionScreen()),
          ),
          GoRoute(
            path: '/home/profile',
            pageBuilder: (_, state) =>
                _platformPage(state, const ProfileScreen()),
          ),
        ],
      ),

      // ── Story Learn (custom topic or mastery-path step) ──────────────────
      GoRoute(
        path: AppRoutes.lesson,
        pageBuilder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return _platformPage(
            state,
            StoryScreen(
              customTopic: extra['customTopic'] as String?,
              preselectedLevel:
                  (extra['preselectedLevel'] ?? extra['level']) as String?,
              preselectedStyle: extra['preselectedStyle'] as String?,
              franchiseName: extra['franchiseName'] as String?,
              pathTopicKey: extra['pathTopicKey'] as String?,
              pathStepIndex: extra['pathStepIndex'] as int?,
            ),
          );
        },
      ),

      // ── Feynman "Teach it back" mode ─────────────────────────────────────
      GoRoute(
        path: AppRoutes.feynman,
        pageBuilder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          final topic = extra['topic'] as String? ?? '';
          final franchise = extra['franchise'] as Franchise?;
          final character = extra['character'] as FranchisePersona?;
          if (franchise == null || character == null || topic.isEmpty) {
            return _platformPage(
              state,
              const Scaffold(
                body: Center(
                  child: Text(
                    'Feynman session needs a franchise + character.',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ),
            );
          }
          return _platformPage(
            state,
            FeynmanScreen(
              topic: topic,
              franchise: franchise,
              character: character,
            ),
          );
        },
      ),

      // ── Scan / Mastery / Profile ─────────────────────────────────────────
      GoRoute(
        path: AppRoutes.scan,
        pageBuilder: (_, state) =>
            _platformPage(state, const ScanTextbookScreen()),
      ),
      GoRoute(
        path: AppRoutes.masteryPath,
        pageBuilder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return _platformPage(
            state,
            MasteryPathScreen(
              topic: extra['topic'] as String? ?? '',
              level: extra['level'] as String? ?? 'basics',
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.userProfile,
        pageBuilder: (_, state) => _platformPage(state, const ProfileScreen()),
      ),
    ],
  );
});
