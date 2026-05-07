import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/ai/gemma_service.dart';
import '../core/services/local_profile_service.dart';
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
  static const String home = '/home';
  static const String lesson = '/lesson';
  static const String feynman = '/feynman';
  static const String scan = '/scan';
  static const String masteryPath = '/mastery-path';
  static const String userProfile = '/profile';
}

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.home,
    debugLogDiagnostics: true,
    redirect: (BuildContext context, GoRouterState state) {
      final hasProfile = LocalProfileService.instance.hasProfile;
      final modelReady = GemmaService.instance.isReady;
      final loc = state.matchedLocation;

      // Always allow setup screens
      if (loc.startsWith('/setup')) return null;

      // Model must be loaded before any feature screen — if a cold relaunch
      // couldn't resume it (e.g. flutter_gemma registry wiped but file still
      // on disk), bounce back to setup so the user can re-import instantly.
      if (!modelReady) return AppRoutes.setup;

      // Model ready but no profile yet
      if (!hasProfile) return AppRoutes.setupProfile;

      return null;
    },
    routes: [
      // ── Setup flow ────────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.setup,
        builder: (_, __) => const ModelDownloadScreen(),
      ),
      GoRoute(
        path: AppRoutes.setupProfile,
        builder: (_, __) => const ProfileSetupScreen(),
      ),

      // ── Home shell (bottom nav: Home / Companion / Profile) ───────────────
      ShellRoute(
        builder: (context, state, child) => HomeScreen(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            builder: (_, __) => const HomeDashboard(),
          ),
          GoRoute(
            path: '/home/companion',
            builder: (_, __) => const StudyCompanionScreen(),
          ),
          GoRoute(
            path: '/home/profile',
            builder: (_, __) => const ProfileScreen(),
          ),
        ],
      ),

      // ── Story Learn (custom topic or mastery-path step) ──────────────────
      GoRoute(
        path: AppRoutes.lesson,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return StoryScreen(
            customTopic: extra['customTopic'] as String?,
            preselectedLevel:
                (extra['preselectedLevel'] ?? extra['level']) as String?,
            preselectedStyle: extra['preselectedStyle'] as String?,
            franchiseName: extra['franchiseName'] as String?,
            pathTopicKey: extra['pathTopicKey'] as String?,
            pathStepIndex: extra['pathStepIndex'] as int?,
          );
        },
      ),

      // ── Feynman "Teach it back" mode ─────────────────────────────────────
      GoRoute(
        path: AppRoutes.feynman,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          final topic = extra['topic'] as String? ?? '';
          final franchise = extra['franchise'] as Franchise?;
          final character = extra['character'] as FranchisePersona?;
          if (franchise == null || character == null || topic.isEmpty) {
            return const Scaffold(
              body: Center(
                child: Text(
                  'Feynman session needs a franchise + character.',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            );
          }
          return FeynmanScreen(
            topic: topic,
            franchise: franchise,
            character: character,
          );
        },
      ),

      // ── Scan / Mastery / Profile ─────────────────────────────────────────
      GoRoute(
        path: AppRoutes.scan,
        builder: (_, __) => const ScanTextbookScreen(),
      ),
      GoRoute(
        path: AppRoutes.masteryPath,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return MasteryPathScreen(
            topic: extra['topic'] as String? ?? '',
            level: extra['level'] as String? ?? 'basics',
          );
        },
      ),
      GoRoute(
        path: AppRoutes.userProfile,
        builder: (_, __) => const ProfileScreen(),
      ),
    ],
  );
});
