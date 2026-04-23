# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## The pivot (read this first)

This repo was previously a cloud-AI + Firebase app (DeepSeek/Groq/Hindsight, Firestore, Cloud Functions). It has been rewritten for the **Kaggle Gemma 4 Good Hackathon** as a **fully on-device, offline-after-bootstrap** app:

- **AI:** All inference runs locally via `flutter_gemma` (LiteRT-LM) using `gemma-4-E4B-it.litertlm` (~3.65 GB). No DeepSeek, no Groq, no Hindsight, no Gemini API.
- **Storage:** SQLite (`sqflite`) via `lib/core/db/app_database.dart`. No Firestore, no Firebase Auth, no Cloud Functions.
- **Profiles:** Local-only via `LocalProfileService` — name/grade/language, multiple profiles supported (student + teacher demo mode). No login, no password.
- **Memory:** `LocalMemoryService` replaces Hindsight — same "retrieve past events → inject into prompt" pattern, but reads from SQLite.

Stale artifacts still present but not wired in: `functions/`, `firebase.json`, `firestore.rules`, `storage.rules`, `firestore.indexes.json`, unused models (`battle_model.dart`, `challenge_model.dart`, `forum_post_model.dart`, `learning_path_model.dart`, `user_model.dart`, `achievement_model.dart`). Treat these as dead weight — don't extend them.

## Build & Run

```bash
# Deps
flutter pub get

# Code generation (Riverpod / Freezed / JSON serialization)
dart run build_runner build --delete-conflicting-outputs

# Run on connected Android device (Android 12+, ≥6 GB RAM, ≥5 GB free)
flutter devices
flutter run -d <DEVICE_ID> --dart-define=HF_TOKEN=<optional_hf_token>

# Build
flutter build apk --debug
flutter install -d <DEVICE_ID> --debug

# Static analysis
flutter analyze
```

`HF_TOKEN` is only needed if downloading the model from Hugging Face in-app; sideloading (see below) works without a token.

### Model acquisition — two paths

1. **Network download** (`ModelDownloadScreen` → `GemmaService.initialize`): pulls from `huggingface.co/litert-community/gemma-4-E4B-it-litert-lm`.
2. **Sideload** (`GemmaService.initializeFromFile`): push the `.litertlm` file to `/storage/emulated/0/Android/data/com.vidyasetu.vidyasetu/files/gemma-4-E4B-it.litertlm` via adb or Files app, then the setup screen offers an "Import from device" option. The service then copies the file to internal app storage (sdcard mmap is flaky on Android) before `FlutterGemma.installModel().fromFile()`.

Either way, after install `GemmaService` eagerly calls `getActiveModel` to warm the engine so errors surface at setup, not on first chat.

### Android requirements (`android/app/build.gradle.kts`)

- `minSdk = 31` (hard requirement for LiteRT-LM)
- `androidResources.noCompress += ["tflite", "litertlm", "task", "bin"]` — model files must be stored uncompressed for mmap
- `applicationId = "com.vidyasetu.vidyasetu"` (reflects the old name — don't change; the sideload path is derived from this)
- Java 17

### Analyzer config

`deprecated_member_use` warnings are suppressed in `analysis_options.yaml`.

## Architecture

Feature-first Flutter app. Riverpod is declared but used only for `appRouterProvider` and `ThemeProvider`; all other state is local (`StatefulWidget` + `setState`, `ChangeNotifier` for global).

```
lib/
├── core/
│   ├── ai/           # GemmaService (runtime), GemmaOrchestrator (agent routing), AgentPrompts
│   ├── db/           # AppDatabase (SQLite schema + CRUD)
│   ├── services/     # LocalProfileService, LocalMemoryService
│   ├── theme/        # AppTheme, ThemeProvider
│   ├── widgets/      # GlassContainer, NeonButton, ParticleBackground, etc.
│   ├── constants/    # AppConstants
│   ├── config/       # (legacy API key loader — unused)
│   └── utils/
├── features/         # setup/, auth/, story_learning/, companion/, scan/, teacher/,
│                     # courses/, profile/, achievements/, skill_tree/, knowledge_graph/, search/
├── models/           # Mostly legacy; story models live under features/story_learning/models/
├── routes/app_router.dart
└── main.dart         # FlutterGemma.initialize → LocalProfileService.initialize → runApp
```

### Three-layer AI stack

1. **`GemmaService`** (`core/ai/gemma_service.dart`) — Singleton wrapper over `flutter_gemma`. Owns model lifecycle (download, sideload, install, warm). Exposes `generate`, `generateStream`, `generateFromImage`, `createCompanionChat` (returns a persistent `InferenceChat` for multi-turn).
2. **`GemmaOrchestrator`** (`core/ai/gemma_orchestrator.dart`) — Singleton. Seven agents (Story, Tutor, Quiz, Explorer, Planner, LearnerTwin, Teacher + Image Analysis + intent Orchestrator) share one Gemma instance; identity is the system prompt. The orchestrator pulls memory context from `LocalMemoryService`, injects it into `AgentPrompts.*`, calls `GemmaService`, then parses JSON with a tolerant extractor (`_parseJsonAny`) that strips markdown fences and finds the first balanced `{...}` / `[...]`. Gemma frequently prefixes output with prose — don't skip this step.
3. **`AgentPrompts`** (`core/ai/agent_prompts.dart`) — Pure system prompt templates. Every prompt enforces `Language: {language}` and "Return ONLY valid JSON — no markdown fences". Style block (`desi_meme`, `practical`, `movie_tv`, `exam`, `beginner`) is composed into the Story prompt.

When adding a new feature that calls AI: add a method to `GemmaOrchestrator`, add a template to `AgentPrompts`, keep `GemmaService` untouched.

### Memory pattern (local replacement for Hindsight)

`LocalMemoryService` mirrors the old `HindsightService` API surface:

- **Retain** — `retainQuizResult`, `retainTopicInterest`, `retainChatExchange` write rows into `quiz_results`, `memory_events`, `chat_history`. `retainQuizResult` also upserts the `topics` row (level promotion on ≥70% accuracy) and calls `LocalProfileService.addXP(35 + perfect_bonus)`.
- **Recall** — `getStudyContext(topic)` returns a formatted multi-line string used to prepend past quiz results + events to agent prompts. `getFormattedHistory()` returns everything, used by Learner Twin and Planner.
- **Progress** — `getAllTopicProgress()` returns `[{name, level, accuracy, stars}]` for the Planner agent.

All retain calls are fire-and-forget from call sites; all recall calls must run before the Gemma prompt is built.

### Local SQLite schema (`app_database.dart`)

Five tables, all keyed by `profile_id` (supports multiple profiles on one device):

- `profiles` — `name`, `language`, `grade`, `xp`, `streak`, `interests` (JSON array)
- `topics` — per-profile per-topic progress (`topic_key`, `level`, `accuracy`, `stars`, `quiz_count`, `last_studied`). Unique on `(profile_id, topic_key)`.
- `quiz_results` — raw history (`missed_questions` + `concepts` as JSON arrays)
- `memory_events` — narrative events for RAG-style recall (`type`, `content`, `topic`, `tags`)
- `chat_history` — per-agent chat log (`agent = 'companion' | ...`)

`topic_key` is always `topic.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')`. Use `AppDatabase.encodeList` / `decodeList` to store arrays (stored as TEXT/JSON, not native arrays).

### Navigation (`lib/routes/app_router.dart`)

Single `GoRouter` provider with a guard that redirects to `/setup` if no profile AND model not ready, else `/setup/profile` if no profile. Initial location is `/home`.

Setup flow: `/setup` (model download or sideload import) → `/setup/profile` → `/home`.

Home is a `ShellRoute` with 3-tab bottom nav: `/home`, `/home/companion`, `/home/profile`.

Other standalone routes: `/lesson`, `/topic-explorer`, `/topics`, `/concept-map`, `/skill-tree`, `/search`, `/achievements`, `/courses`, `/coding-arena`, `/scan`, `/teacher`, `/profile`. Route data is passed via `state.extra as Map<String, dynamic>?` — there is no type-safe route param system.

### Story Learning — 6-phase flow (`features/story_learning/screens/story_screen.dart`, ~1300 lines)

1. **LEVEL_SELECT** — custom topics only. `GemmaOrchestrator.assessTopicLevel` returns `{level, reason, has_history, past_accuracy}` from the Learner Twin agent over local history.
2. **STYLE_SELECT** — Desi Meme / Practical / Movie-TV (prompts for franchise name).
3. **LOADING** — `StoryGeneratorService` (a thin adapter, `features/story_learning/services/story_generator_service.dart`) calls `GemmaOrchestrator.generateStory`, which internally pulls `getStudyContext(topic)` and injects it into the Story system prompt.
4. **STORY** — visual novel with typewriter dialogue, per-character colors, scene progress bar.
5. **QUIZ** — 3 questions × 4 options. Tracks `_correctCount` and `_missedQuestions`.
6. **RESULTS** — 1–3 stars, XP (35 base + 15 perfect bonus), saves via `LocalMemoryService.retainQuizResult` (which also awards XP and upserts topic progress).

When modifying StoryScreen: work by `_Phase` enum — do not restructure phases.

### Multimodal scan (`features/scan/screens/scan_textbook_screen.dart`)

`image_picker` → `GemmaOrchestrator.analyzeTextbookImage(bytes)` (returns `{topic, concepts, level, description}`) → `generateStoryFromImage` reuses the Story agent. `FlutterGemma.getActiveModel(supportImage: true)` is required before passing an image message.

### Study Companion (`features/companion/screens/study_companion_screen.dart`)

Uses `GemmaOrchestrator.getStudyPulse` for the auto-generated top card, `queryLearnerTwinStream` for the chat (streaming tokens). Every exchange is persisted via `LocalMemoryService.retainChatExchange`.

### Teacher Copilot (`features/teacher/screens/teacher_copilot_screen.dart`)

Aggregates all local profiles (all students on the device) → passes to `GemmaOrchestrator.teacherQuery` with a class-data block.

### Theme (`lib/core/theme/app_theme.dart`)

Dark glassmorphism + neon accents. Key colors: bg `0xFF0A0E21`, surface `0xFF0F1328`, cyan `0xFF00F5FF`, purple `0xFFB429F9`, green `0xFF00FF88`, gold `0xFFFFD700`. Fonts: Orbitron (headers), Space Grotesk (body). Use `AppTheme.*`, `GlassContainer`, `NeonButton`. A light theme exists (`AppTheme.lightTheme`) and is selectable via `ThemeProvider`, but the visual language was designed for dark.

## Conventions

- **No cloud calls.** If you're tempted to add `http`, `dio`, `firebase_*`, or a cloud AI SDK — stop. The pitch of this app is offline-after-bootstrap.
- **Riverpod is barely used.** Don't introduce Riverpod providers for new feature state; follow the existing `StatefulWidget` + `ChangeNotifier` pattern unless you have a strong reason.
- **JSON from Gemma is unreliable.** Always parse through `_parseJsonAny` (or replicate its behavior) — never `jsonDecode(raw)` directly on model output.
- **All Gemma prompts must thread `language`.** The user's language is `LocalProfileService.instance.currentProfile?.language` and the orchestrator passes it into every prompt.
- **Topic keys are sanitized.** Always round-trip through `_sanitizeKey` / the equivalent regex before reads.
- **Freezed + json_serializable are in pubspec but most models are hand-written.** Match the style of the file you're editing.
- **Tests are minimal** (`test/widget_test.dart` only). Don't assume a test suite runs in CI.
- **Legacy docs** (`docs/ARCHITECTURE.md`, `docs/DATABASE_SCHEMA.md`, `docs/API_PROMPTS.md`, `hack.md`) describe the old Firebase/cloud version — treat as historical, not authoritative.
