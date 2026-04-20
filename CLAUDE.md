# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run Commands

```bash
# Get dependencies
flutter pub get

# Code generation (Riverpod, Freezed, JSON serialization)
dart run build_runner build --delete-conflicting-outputs

# Run on a connected device (pass API keys via --dart-define)
flutter devices
flutter run -d <DEVICE_ID> \
  --dart-define=DEEPSEEK_API_KEY=your_key \
  --dart-define=GROQ_API_KEY=your_key \
  --dart-define=HINDSIGHT_API_KEY=your_key

# Build debug APK
flutter build apk --debug

# Install on connected device
flutter install -d <DEVICE_ID> --debug

# Static analysis
flutter analyze
```

### API Keys (`lib/core/config/api_keys.dart`)
All AI service keys are loaded via `String.fromEnvironment()` and must be passed at build time with `--dart-define`. Keys: `DEEPSEEK_API_KEY`, `GROQ_API_KEY`, `HINDSIGHT_API_KEY`. Some services also read the key directly via `String.fromEnvironment()` in their own files (e.g., `deepseek_service.dart`, `topic_explorer_screen.dart`, `coding_arena_screen.dart`). No `OPENAI_API_KEY` is needed — image generation uses DiceBear avatars with Pollinations.ai as fallback (both free, no key).

### Cloud Functions (`functions/`)

```bash
cd functions
npm install
npm run build          # TypeScript compile
npm run serve          # Build + start Firebase emulators
npm run lint           # ESLint
firebase deploy --only functions
```

### Firebase Deployment

```bash
firebase deploy --only firestore:rules
firebase deploy --only storage
firebase deploy --only functions
```

**Android minSdk**: Uses `flutter.minSdkVersion` in `android/app/build.gradle.kts`.

**Analyzer config**: `deprecated_member_use` warnings are suppressed in `analysis_options.yaml`.

## Architecture

**Feature-first modular architecture** with Go Router navigation, Firebase backend, and Hindsight Memory for persistent AI memory. Riverpod is declared but minimally used — only `appRouterProvider` exists. All feature state is managed locally via StatefulWidget + setState.

### Core Pattern
```
lib/
├── core/          # Shared theme, widgets, services (FirebaseService, HindsightService), constants, utils
├── features/      # Feature modules, each with screens/services/widgets
├── models/        # Shared data models (UserModel, BattleModel, etc.)
├── routes/        # Single app_router.dart with all route definitions
└── main.dart      # Firebase init, portrait-only orientation lock, ProviderScope
```

Each feature module is self-contained: `features/<name>/screens/`, `services/`, `widgets/`.

### Service Constructor Pattern
Services accept optional Firebase instances, falling back to the `FirebaseService` singleton:
```dart
BattleService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseService.instance.firestore;
```
`FirebaseService` (`core/services/firebase_service.dart`) is a true singleton that initializes Firestore with unlimited offline cache.

### Navigation Flow
Splash → (auth check → Login if needed) → (checks Firestore `onboardingComplete`) → Onboarding OR Home

Home uses a `ShellRoute` with **3-tab bottom nav**: Home, Companion, Profile.

Route guard in `app_router.dart` redirects unauthenticated users to login. Route data is passed via `state.extra as Map<String, dynamic>` — no type-safe route parameters. Additional standalone routes: `/courses` (course catalogue), `/chat` and `/chat/detail` (peer messaging).

### Home Dashboard Layout
Welcome Header → Hero Card (3 learning styles + CTA) → Learn Anything (custom topic search) → AI Recommends (Hindsight Reflect) → Your Topics (always visible, empty state when no topics) → Continue Learning (numbered steps) → Streak + Daily Goal row (with progress bar).

**Auto-refresh**: `HomeDashboard` implements `WidgetsBindingObserver`. Data reloads on app resume (`didChangeAppLifecycleState`) and tab switch (`didChangeDependencies`). Pull-to-refresh via `RefreshIndicator`.

**Local caching**: User data is cached to `SharedPreferences` (`user_data_{uid}`) for instant UI on launch. Timestamps are converted to ISO8601 strings for JSON serialization. The load pattern is: show cached data immediately → fetch fresh Firestore data in background → update UI + cache.

The AI Recommends card calls `HindsightService.reflect()` on load with a 15-second timeout and fallback string. Your Topics reads from `studiedTopics` map in the user's Firestore document — each card shows topic name, level badge, stars, accuracy %, last studied date, and tapping continues at the next level. The `_studiedTopics` getter handles both `Timestamp` (Firestore) and `String` (cached) for sorting and date display. "See All" navigates to dedicated `YourTopicsScreen` (`/topics`) which loads both Firestore topics and Hindsight AI insights.

### Story Learning — 6-Phase Flow (`features/story_learning/`)
All lessons (course-based and custom topics) route through `StoryScreen`. The `/lesson` route accepts `customTopic`, `lessonId`/`subjectId`/`chapterId`, and optional `preselectedLevel` (skips level select when continuing from home).

**6 phases** (`_Phase` enum):
1. **LEVEL_SELECT** — Custom topics only. Calls `HindsightService.assessTopicLevel()` (structured Reflect) to determine if student should start at Basics/Intermediate/Advanced. Shows AI recommendation with "I REMEMBER YOU" or "NEW TOPIC DETECTED", past accuracy %, and 3 level cards with an "AI PICK" badge. Course-based lessons and preselected levels skip this phase.
2. **STYLE_SELECT** — Choose narrative style: Desi Meme (Indian humor), Practical (real-world), Movie/TV (franchise-based, user types franchise name).
3. **LOADING** — `StoryGeneratorService` first calls `HindsightService.getStudyContext()` (Recall) to fetch past learning about this topic, then injects that context into the DeepSeek system prompt so the AI adapts the lesson. Custom topics also include level-specific guidance in the prompt (basics = simple language, intermediate = deeper concepts, advanced = expert nuances).
4. **STORY** — Visual novel with typewriter-animated dialogue, character portraits, scene progress bar. Characters are AI-generated per story.
5. **QUIZ** — 3 questions with 4 options each. Tracks `_correctCount` and `_missedQuestions` list.
6. **RESULTS** — Star rating (1-3), XP calculation (35 base + 15 perfect bonus). Saves to Firestore (`xp`, `courseProgress`, `studiedTopics` with level/accuracy/stars) and retains to Hindsight (`retainQuizResult` with topic, level, style, score, missed questions, concept tags).

`StoryScreen` is ~1500 lines. Modify by phase.

### Hindsight Memory Integration (`core/services/hindsight_service.dart`)
Persistent AI memory for each student via the Hindsight API by Vectorize. Solves the context window problem — unlimited history stored externally, only relevant memories retrieved.

**API**: `https://api.hindsight.vectorize.io`, auth via Bearer token. One memory bank per user: `student-{uid}`. Auto-creates bank on first use.

**Three core operations:**
- **Retain** — Store learning events. Used after quizzes, topic searches, companion chats. Tags enable filtering: `topic:*`, `level:*`, `accuracy:*`, `needs_review`, `mastered`.
- **Recall** — Search past memories. Used by `getStudyContext()` to fetch learning history for a topic before story generation. Multi-strategy retrieval (semantic + keyword + graph + temporal).
- **Reflect** — AI reasoning over all memories. Used for study pulse, recommendations, topic level assessment, companion chat answers. Supports `responseSchema` for structured JSON output via `reflectStructured()`.

**Key methods:**
- `retainQuizResult()` — Formats and stores quiz performance (topic, level, style, score, missed questions, concepts)
- `retainChatExchange()` — Stores companion Q&A for cross-session memory
- `retainTopicInterest()` — Tracks topic interest + chosen level
- `getStudyContext(topic)` — Recall → formats as context string injected into DeepSeek prompts
- `assessTopicLevel(topic)` — Structured Reflect returning `{level, reason, has_history, past_accuracy}`
- `getStudiedTopics()` — Structured Reflect returning list of all studied topics with progress

**Budget parameter** controls retrieval depth: `'low'` (fast, less thorough), `'mid'` (default), `'high'` (comprehensive, slower).

### Study Companion (`features/companion/screens/study_companion_screen.dart`)
AI study assistant powered entirely by Hindsight Reflect. Accessible via the "Companion" tab in bottom nav.

- **Study Pulse** — Auto-generated on init, summarizes learning progress in 3-4 sentences
- **Quick Actions** (4 cards) — Pre-built queries: "What should I study?", "Quiz me on weak spots", "Study plan for this week", "Where am I struggling?"
- **Chat** — Free-form questions answered by Reflect reasoning over all memories. Every exchange is retained back to Hindsight via `retainChatExchange()`.
- **Memory badge** — Shows "Answers powered by your learning memory"

### Profile Screen (`features/profile/screens/profile_screen.dart`)
Loads real data from Firestore — no mock stubs. Header shows avatar with cyan glow, username, bio, XP + Streak chips. **No league display** — leagues were removed from the UI.

**4 tabs**: Overview, Achievements, Battle History, Challenges.

- **Overview** — Stats grid (Topics Studied, Quizzes Taken, XP, Streak) + studied topics list with level/accuracy/stars/date + editable interests chips
- **Achievements** — Dynamic achievement grid based on real user data. Unlocked/locked state computed from actual XP, topic count, streak, battles. Tap shows detail popup.
- **Battle History** — Queries Firestore `battles` collection where user is a participant. Shows empty state with "Start a Battle" button if none.
- **Challenges** — Queries Firestore `challenges` collection by `creatorId`. Shows empty state with "Create a Challenge" button if none.

Settings gear icon opens bottom sheet with: Edit Profile, Edit Interests, About, Switch Account, Sign Out. Edit Profile and Edit Interests open their own bottom sheets with Firestore save.

### Achievements System (`features/achievements/`)
Learning-focused categories: **Study**, **Quiz**, **Streak**, **Special** (not battle/forum-oriented).

- Study: First Lesson, Knowledge Seeker (5 topics), Topic Master (10), Scholar Elite (25)
- Quiz: First Quiz, Perfect Score, Advanced Scholar, Quiz Legend (50 quizzes at 70%+)
- Streak: Getting Started (3d), Week Warrior (7d), Fortnight Focus (14d), Monthly Master (30d)
- Special: Early Adopter, Night Owl, XP Legend (5000 XP)

Each has rarity (common/rare/epic/legendary), XP reward, progress tracking. The standalone `AchievementsScreen` uses `AchievementCard` widget with detail popup. The profile's achievements tab computes unlock state dynamically from Firestore user data.

### Additional Features (less documented)
- **Social Feed** (`features/feed/`) — Instagram-style activity feed with emoji reactions (5 types, toggle-based), All/Following toggle, suggested users carousel.
- **Peer Help** (`features/peer_help/`) — StackOverflow-style Q&A. 7 categories, upvoting, accepted answers, tutor badges. XP rewards: +10 ask, +25 accepted answer, +5 per upvote.
- **Topic Explorer** (`features/story_learning/screens/topic_explorer_screen.dart`) — Uses Groq to break any topic into 6-8 sub-topics with difficulty levels.
- **Skill Tree** (`features/skill_tree/`) — Interactive node graph of learning progress with Bezier curve connections and subject filter tabs.
- **Knowledge Graph** (`features/knowledge_graph/`) — Concept map explorer for topic relationships.
- **Forum** (`features/forum/`) — Discussion forum with `ForumPostModel` (votes, accepted solutions, open/solved/closed status).
- **Spectator Mode** (`features/spectator/`) — Live battle watching with esports-style UI.
- **Chat** (`features/chat/`) — Peer direct messaging at `/chat` and `/chat/detail` routes.
- **Learning Paths** (`features/learning_paths/`) — Guided learning sequences.
- **Search** (`features/search/`) — Topic search with AI.

### Theme System (`core/theme/app_theme.dart`)
Dark glassmorphism with neon accents. Key colors:
- Background: `0xFF0A0E21`, Surface: `0xFF0F1328`
- Cyan: `0xFF00F5FF`, Purple: `0xFFB429F9`, Green: `0xFF00FF88`, Gold: `0xFFFFD700`
- Fonts: `Orbitron` (headers), `Space Grotesk` (body)
- Use `AppTheme.*` constants, `GlassContainer`, `NeonButton` for consistent UI

### Course Data (`features/courses/data/course_data.dart`)
Static course catalogue in Dart (not Firestore). Physics and Math have full content. Other subjects have `comingSoon: true`. Each `Lesson` has a `gameType` field (`'interactive'`, `'simulation'`, `'quiz'`). User progress is tracked in Firestore under `courseProgress`. Custom topics bypass course data entirely.

### Firebase
- **Project:** hire-horizon-c47c7
- **App ID:** com.vidyasetu.vidyasetu
- **Services:** Auth (email + Google), Firestore, Storage, Cloud Functions (Node 18 / TypeScript)

### Firestore Security Rules
Rules are granular per collection — **not** a blanket auth check:
- **Users**: Public read, self-write only, no deletes
- **Battles**: Public read, only participants can update
- **Challenges**: Public read, creator can update, admin can delete
- **Forum Posts**: Public read, author can update/delete
- **Leaderboards, Achievements, Daily Challenges**: Read-only — writes are Cloud Functions via admin SDK (bypasses rules)
- **Matchmaking Queue**: Owner-only read/write
- **Storage**: Users can upload up to 5MB to their own folder; challenges folder allows any authenticated write with no size limit

### Cloud Functions (`functions/src/index.ts`)
All server-side logic:
- `onBattleCreated` — Firestore trigger: marks battle active, sets auto-end deadline via setTimeout
- `onBattleAnswerSubmitted` — Firestore trigger: checks if round is complete, advances or calculates final result
- `calculateBattleResult` — HTTP callable: tallies scores, determines winner, awards XP (winner=50+bonus, loser=15+bonus), updates user profiles via batch write
- `updateLeaderboards` — Scheduled hourly: recalculates global and category leaderboards (top 100 by XP)
- `generateDailyChallenge` — Scheduled daily at 00:00 UTC: creates daily challenge document
- `onUserXPChanged` — Firestore trigger: checks XP against league thresholds, promotes user, awards achievements
- `matchmaking` — HTTP callable: finds opponent within ±200 skill rating, creates battle or adds to queue

### AI Integration
- **DeepSeek** (`features/story_learning/services/deepseek_service.dart`) — Story/lesson generation via OpenAI-compatible API at `api.deepseek.com/v1`. Auto-continuation support for truncated responses.
- **Groq** (`api.groq.com/openai/v1`, Llama 3.3 70B) — Fast sub-topic generation in Topic Explorer (`topic_explorer_screen.dart`) and code evaluation in Coding Arena (`coding_arena_screen.dart`). Both read `GROQ_API_KEY` directly via `String.fromEnvironment()`.
- **Hindsight Memory** (`core/services/hindsight_service.dart`) — Persistent student memory. See section above.
- **Gemini** (`features/challenges/services/ai_challenge_service.dart`) — Challenge generation/evaluation (1.5 Pro/Flash). Also supports OpenAI and Anthropic. See `docs/API_PROMPTS.md` for prompt templates.
- **Character Images** (`core/services/openai_image_service.dart`) — Character portrait generation. Singleton with in-memory cache keyed by `"characterName|franchiseName"`. Primary: DiceBear (instant stylized avatars, always works, no API key). Fallback: Pollinations.ai (free AI image gen, no key). No OpenAI/DALL-E dependency.

### Key Models
- `UserModel` — includes `interests`, `onboardingComplete`, `courseProgress`, `studiedTopics`, `currentStreak`, `xp`
- `BattleModel` — **two versions exist** (known issue):
  - `lib/models/battle_model.dart` — uses `BattleMode` enum, typed fields, more complete
  - `lib/features/battle/models/battle_model.dart` — uses plain strings for mode/status, simpler
- `ChallengeModel` — includes `type` enum, `difficulty` (1-5), `solution`, `hints`, `testCases`
- `ForumPostModel` — includes `votes`, `acceptedSolutionId`, status (open/solved/closed)

### XP System
Leagues are defined in `AppConstants` (6 fantasy-themed tiers) and Cloud Functions (7 ranked tiers) but **not displayed in the UI** — the profile shows raw XP + streak instead.

XP rewards are constants in `AppConstants`. Difficulty multipliers: Easy 1.0×, Medium 1.5×, Hard 2.0×, Expert 3.0×. Streak bonus: +2% per day, capped at 2.0×. Hint penalties are cumulative: 25%, 50%, 75%. Dynamic calculation in `core/utils/xp_calculator.dart`.

## Documentation
- `docs/ARCHITECTURE.md` — System architecture, data flow, AI integration strategy
- `docs/DATABASE_SCHEMA.md` — Full Firestore schema for all 9 collections with field types
- `docs/API_PROMPTS.md` — AI prompt templates for challenge generation and evaluation
- `hack.md` — Hackathon submission writeup: features, Hindsight integration, architecture

## Important Conventions
- All UI uses the dark neon/glassmorphism aesthetic — never use light themes or Material defaults
- Google Sign-In: use `GoogleSignIn().signOut()` for switch account, `GoogleSignIn().disconnect()` for full sign out
- Auth service wraps Firestore calls in try/catch so auth succeeds even if Firestore is down
- Assets live in `assets/images/`, `assets/animations/`, `assets/icons/` — already registered in pubspec
- Models use `fromJson()`/`toJson()` for Firestore serialization (hand-written, not code-generated despite Freezed being in pubspec)
- Tests are minimal (`test/widget_test.dart` only)
- Hindsight API calls should never block the learning flow — all retain calls are fire-and-forget, reflect calls have timeout + fallback strings
- `studiedTopics` in Firestore uses sanitized topic keys: `topic.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')`
- When reading `studiedTopics`, handle both `Timestamp` (fresh Firestore) and `String` (SharedPreferences cache) for `lastStudied` field
- Home dashboard caches user data to SharedPreferences for offline/instant loading — always convert Timestamps to ISO8601 before caching
