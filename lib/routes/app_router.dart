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
import '../features/story_learning/screens/topic_explorer_screen.dart';
import '../features/story_learning/screens/your_topics_screen.dart';
import '../features/knowledge_graph/screens/concept_map_screen.dart';
import '../features/skill_tree/screens/skill_tree_screen.dart';
import '../features/search/screens/search_screen.dart';
import '../features/achievements/screens/achievements_screen.dart';
import '../features/courses/screens/courses_screen.dart';
import '../features/courses/screens/coding_arena_screen.dart';
import '../features/scan/screens/scan_textbook_screen.dart';
import '../features/teacher/screens/teacher_copilot_screen.dart';

abstract class AppRoutes {
  static const String setup = '/setup';
  static const String setupProfile = '/setup/profile';
  static const String home = '/home';
  static const String lesson = '/lesson';
  static const String topicExplorer = '/topic-explorer';
  static const String topics = '/topics';
  static const String conceptMap = '/concept-map';
  static const String skillTree = '/skill-tree';
  static const String search = '/search';
  static const String achievements = '/achievements';
  static const String courses = '/courses';
  static const String codingArena = '/coding-arena';
  static const String scan = '/scan';
  static const String teacher = '/teacher';
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

      // No profile → download model first
      if (!hasProfile && !modelReady) return AppRoutes.setup;

      // Profile created but model not ready (shouldn't happen normally)
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

      // ── Learning ──────────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.lesson,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return StoryScreen(
            lessonId: extra['lessonId'] as String?,
            subjectId: extra['subjectId'] as String?,
            chapterId: extra['chapterId'] as String?,
            customTopic: extra['customTopic'] as String?,
            preselectedLevel: extra['level'] as String?,
            preselectedStyle: extra['preselectedStyle'] as String?,
            franchiseName: extra['franchiseName'] as String?,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.topicExplorer,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return TopicExplorerScreen(
            topic: extra['topic'] as String? ?? '',
          );
        },
      ),
      GoRoute(
        path: AppRoutes.topics,
        builder: (_, __) => const YourTopicsScreen(),
      ),
      GoRoute(
        path: AppRoutes.conceptMap,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return ConceptMapScreen(
            focusConcept: extra['focusConcept'] as String?,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.skillTree,
        builder: (_, __) => const SkillTreeScreen(),
      ),

      // ── Utilities ─────────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.search,
        builder: (_, __) => const SearchScreen(),
      ),
      GoRoute(
        path: AppRoutes.achievements,
        builder: (_, __) => const AchievementsScreen(),
      ),
      GoRoute(
        path: AppRoutes.courses,
        builder: (_, __) => const CoursesScreen(),
      ),
      GoRoute(
        path: AppRoutes.codingArena,
        builder: (_, __) => const CodingArenaScreen(),
      ),
      GoRoute(
        path: AppRoutes.scan,
        builder: (_, __) => const ScanTextbookScreen(),
      ),
      GoRoute(
        path: AppRoutes.teacher,
        builder: (_, __) => const TeacherCopilotScreen(),
      ),
      GoRoute(
        path: AppRoutes.userProfile,
        builder: (_, __) => const ProfileScreen(),
      ),
    ],
  );
});
