# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## The pivot (read this first)

This repo was previously a cloud-AI + Firebase app (DeepSeek/Groq/Hindsight, Firestore, Cloud Functions). It has been rewritten for the **Kaggle Gemma 4 Good Hackathon** as a **fully on-device, offline-after-bootstrap** app:

- **AI:** All inference runs locally via `flutter_gemma` (LiteRT-LM) using `gemma-4-E2B-it.litertlm` (~2.58 GB). No DeepSeek, no Groq, no Hindsight, no Gemini API.
- **Storage:** SQLite (`sqflite`) via `lib/core/db/app_database.dart`. No Firestore, no Firebase Auth, no Cloud Functions.
- **Profiles:** Local-only via `LocalProfileService` — name/grade/language/mood/dyslexic-mode/tts-flag, multiple profiles supported. No login, no password.
- **Memory:** `LocalMemoryService` replaces Hindsight — same "retrieve past events → inject into prompt" pattern, but reads from SQLite.

The legacy Firebase Functions tree (`functions/`) is still on disk but not wired in. Treat as dead weight — don't extend it. Same goes for `lib/core/config/api_keys.dart` — it still defines `groqApiKey` / `hindsightApiKey` / `deepseekApiKey` constants pointing at cloud base URLs from the pre-pivot era. Nothing imports it. Don't wire it back up; if anything, delete it on sight.

### The simplification pivot (Story-first)

The app was previously feature-heavy (Franchise Lab subapp, Comic Album, Knowledge Graph, Skill Tree, Achievements, Courses, Topic Explorer, Search, …). It has since been **sharpened down to a single emotionally-intelligent learning experience** centred on Story Learning.

Five core pillars: **Story Learning**, **Learner Twin** (Companion), **Mastery Path**, **Scan Textbook**, **on-device Gemma**. Everything else was removed in a deliberate cut. If you find yourself adding a fresh tab, dashboard tile, or feature route, stop — the brief is to *delete*, not add.

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

1. **Network download** (`ModelDownloadScreen` → `GemmaService.initialize`): pulls from `huggingface.co/litert-community/gemma-4-E2B-it-litert-lm`.
2. **Sideload** (`GemmaService.initializeFromFile`): push the `.litertlm` file to `/storage/emulated/0/Android/data/com.vidyasetu.vidyasetu/files/gemma-4-E2B-it.litertlm` via adb or Files app, then the setup screen offers an "Import from device" option. The service then copies the file to internal app storage (sdcard mmap is flaky on Android) before `FlutterGemma.installModel().fromFile()`.

Either way, after install `GemmaService` eagerly calls `getActiveModel` to warm the engine so errors surface at setup, not on first chat.

E2B is the only supported model. Don't reintroduce E4B variant-switching without a strong reason.

### Android requirements (`android/app/build.gradle.kts`)

- `minSdk = 31` (hard requirement for LiteRT-LM)
- `androidResources.noCompress += ["tflite", "litertlm", "task", "bin"]` — model files must be stored uncompressed for mmap
- `applicationId = "com.vidyasetu.vidyasetu"` — don't rename; the documented sideload path depends on this exact value. The user-facing brand is **Learnify** (see `README.md`), but `pubspec.yaml`'s `name: vidyasetu` and the Android applicationId are intentionally the legacy package identifier — leave them alone.
- Java 17

### Analyzer config

`deprecated_member_use` warnings are suppressed in `analysis_options.yaml`.

## Architecture

Feature-first Flutter app. Riverpod is declared but used only for `appRouterProvider` and `ThemeProvider`; all other state is local (`StatefulWidget` + `setState`, `ChangeNotifier` for global).

```
lib/
├── core/
│   ├── ai/           # GemmaService, GemmaOrchestrator, AgentPrompts
│   ├── db/           # AppDatabase (SQLite)
│   ├── franchises/   # FranchiseLoader + Franchise/FranchisePersona models
│   ├── services/     # LocalProfileService, LocalMemoryService, TextToSpeechService
│   ├── theme/        # AppTheme (incl. dyslexic font variant), ThemeProvider
│   ├── widgets/      # GlassContainer, NeonButton, BionicText, KaraokeText, ParticleBackground
│   ├── constants/    # AppConstants
│   └── utils/
├── features/
│   ├── setup/, auth/, companion/, scan/, profile/
│   ├── mastery_path/   # Duolingo-style stepped path
│   └── story_learning/
│       ├── screens/  # story_screen.dart (chat-bubble feed), feynman_screen.dart
│       ├── widgets/  # franchise_picker_sheet.dart, etc.
│       └── models/   # story_response.dart (incl. StoryChunk), story_scene.dart, story_style.dart
├── routes/app_router.dart
└── main.dart         # FlutterGemma.initialize → LocalProfileService.initialize → runApp
```

### Three-layer AI stack

1. **`GemmaService`** (`core/ai/gemma_service.dart`) — Singleton wrapper over `flutter_gemma`. Owns model lifecycle (download, sideload, install, warm). Exposes `generate`, `generateStream`, `generateFromImage`, `createCompanionChat`.
2. **`GemmaOrchestrator`** (`core/ai/gemma_orchestrator.dart`) — Singleton. **Seven agents** (Story, Tutor, Quiz, Explorer, Planner, LearnerTwin, **Mastery** + Image Analysis + intent Orchestrator + Feynman role-reversal) share one Gemma instance; identity is the system prompt. The orchestrator pulls memory context from `LocalMemoryService`, threads `language`, `mood`, and `dyslexic` flags from the active profile, calls `GemmaService`, then parses JSON with a tolerant extractor (`_parseJsonAny`) that strips markdown fences and finds the first balanced `{...}` / `[...]`. Gemma frequently prefixes output with prose — don't skip this step.
3. **`AgentPrompts`** (`core/ai/agent_prompts.dart`) — Pure system prompt templates. Every prompt enforces `Language: {language}` and "Return ONLY valid JSON — no markdown fences". Composable blocks: mood, accessibility, franchise persona.

When adding a new feature that calls AI: add a method to `GemmaOrchestrator`, add a template to `AgentPrompts`, keep `GemmaService` untouched.

### Memory pattern (local replacement for Hindsight)

`LocalMemoryService` mirrors the old `HindsightService` API surface:

- **Retain** — `retainQuizResult` (also auto-advances the active mastery path step on ≥70% accuracy when path keys are passed), `retainTopicInterest`, `retainChatExchange`, **`retainFeynmanSession`** (records "student taught X to character Y — N stars"). `retainQuizResult` upserts the `topics` row (level promotion on ≥70%) and calls `LocalProfileService.addXP(35 + perfect_bonus)`.
- **Recall** — `getStudyContext(topic)` formats past quiz results + events for prompt injection. `getFormattedHistory()` returns everything for Learner Twin / Planner. `getRecentChatContext()` pulls the last 8 chat exchanges so the Companion is no longer amnesiac across sessions. `getWeakAreas(topic)` extracts repeated misses for adaptive quizzing.
- **Mastery** — `saveMasteryPath`, `getMasteryPath`, `getActiveMasteryPaths`, `markStepComplete`. Backed by the `topic_paths` table.
- **Progress** — `getAllTopicProgress()` returns `[{name, level, accuracy, stars}]` for the Planner agent.

All retain calls are fire-and-forget from call sites; all recall calls must run before the Gemma prompt is built.

### Local SQLite schema (`app_database.dart`, version 4)

Six tables, all keyed by `profile_id` (supports multiple profiles on one device):

- `profiles` — `name`, `language`, `grade`, `xp`, `streak`, `interests` (JSON array), `current_mood`, `last_mood_date`, `dyslexic_mode`, `tts_enabled`
- `topics` — per-profile per-topic progress (`topic_key`, `level`, `accuracy`, `stars`, `quiz_count`, `last_studied`). Unique on `(profile_id, topic_key)`.
- `quiz_results` — raw history (`missed_questions` + `concepts` as JSON arrays)
- `memory_events` — narrative events for RAG-style recall (`type` ∈ {`topic_interest`, `feynman_taught`, …}, `content`, `topic`, `tags`)
- `chat_history` — per-agent chat log (`agent = 'companion' | ...`)
- `topic_paths` — Mastery Agent output: `topic_key`, `topic_name`, `steps_json` (4/7/11 steps by level), `current_step_index`, `completed_step_indices` (JSON array of ints), `estimated_minutes`. Unique on `(profile_id, topic_key)`.

Migrations are idempotent and additive: v1 → v2 adds `topic_paths`, v2 → v3 adds the mood columns, v3 → v4 adds the a11y columns. `topic_key` is always `topic.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')`.

On first DB open, `_wipeLegacyLabDb` best-effort deletes any `franchise_lab.db` left over from the now-removed Lab subapp.

### Mastery Agent + Path UI (Wave 1 — the spine)

`AgentPrompts.mastery(...)` decomposes any topic into a level-scaled set of progressive steps: **basics → 4**, **intermediate → 7**, **advanced → 11** (single source of truth in `GemmaOrchestrator.masteryStepsForLevel`). `decomposeMasteryPath` injects the learner's *already-mastered* concepts so the agent can skip basics they already know.

`MasteryPathScreen` (`features/mastery_path/screens/`) is a Duolingo-style stepped UI:
- Self-bootstraps the path on first visit (calls `decomposeMasteryPath` → `saveMasteryPath`)
- Each step card shows status indicator (mastered/current/locked), title, description, concept chips, difficulty badge
- Tapping the current step navigates to `/lesson` with `pathTopicKey` + `pathStepIndex` in `state.extra`
- On return, post-frame `_refreshSilently()` re-pulls the path so completed steps show ticks immediately

Step completion is tied into `retainQuizResult`: if the lesson was launched from a path AND quiz accuracy ≥ 70%, the path's `completed_step_indices` is updated and `current_step_index` advances.

### Mood-aware prompts (Wave 2)

`LocalProfile.needsMoodCheckIn` returns true on the first launch of each calendar day. The home dashboard shows a 5-button mood card (calm / hyped / curious / anxious / sad) above the hero card. Selecting a mood calls `LocalProfileService.setMood`.

`AgentPrompts._moodBlock(mood)` injects a tone-shift instruction into Story and Learner Twin prompts. The same mood drives the **mood-aware franchise picker**: `FranchisePickerSheet` accepts a `suggestedMood` and surfaces a "BEST FOR YOUR MOOD" header listing the top 3 franchises whose `emotionalStyle`/`speechStyle`/`humorStyle`/`teachingStyle`/`traits` match the mood's keywords (purely on-device heuristic, no model call).

### Accessibility skin (Wave 4 — both toggles default OFF)

- **Dyslexia-friendly mode** (`LocalProfile.dyslexicMode`):
  - `AppTheme.headerStyle/bodyStyle` accept `dyslexic: true` and swap to **Atkinson Hyperlegible** with looser line-height + slight letter spacing.
  - Story dialogue renders through `BionicText` (`core/widgets/bionic_text.dart`) which bolds the first ~40% of each word's letters.
  - `AgentPrompts._a11yBlock(dyslexic: true)` appends "max 12-word sentences, common words, dialogue ≤ 15 words" to Story / LearnerTwin prompts.

- **Read-aloud (TTS)** (`LocalProfile.ttsEnabled`):
  - `TextToSpeechService` (`core/services/text_to_speech_service.dart`) wraps `flutter_tts`. **Lazy init** — engine spins up only on the first `speak()` call. Three-tier language fallback.
  - `KaraokeText` (`core/widgets/karaoke_text.dart`) listens to `wordIndexStream` and highlights the active word in real time.
  - StoryScreen's chat bubbles render a "🔊 Read aloud" pill below dialogue when `ttsEnabled` is true.

When neither toggle is on, everything renders identically — zero footprint for non-a11y users.

### Navigation (`lib/routes/app_router.dart`)

Single `GoRouter` provider with a guard that redirects to `/setup` if model not ready, else `/setup/profile` if no profile. Initial location is `/home`.

Setup flow: `/setup` (model download or sideload import) → `/setup/profile` → `/home`.

Home is a `ShellRoute` with 3-tab bottom nav: `/home`, `/home/companion`, `/home/profile`.

Standalone routes (intentionally minimal): `/lesson` (Story), `/feynman` (Teach it back), `/scan`, `/mastery-path`, `/profile`. Route data is passed via `state.extra as Map<String, dynamic>?`.

### Home dashboard (intentionally lean)

Welcome header → optional Mood Check-In card → Hero "Learn Anything" card (custom topic input + mastery-path shortcut) → Scan Textbook card → Study Pulse card (Companion preview, surfaces active mastery-path chip).

Custom-topic input pushes straight to `/lesson` with the topic. There is **no** subjects carousel, no your-topics carousel, no concept-map / skill-tree row, no separate search route — those have been deliberately removed.

### Story Learning — chat-bubble flow (`features/story_learning/screens/story_screen.dart`)

The story reads like a **WhatsApp / group chat**, not a visual novel. Each scene = one chat message. Locked 2-character cast is built **in Dart** (not Gemma) — Gemma cannot invent new characters because it never gets the option.

Six phases (`_Phase` enum):

1. **LEVEL_SELECT** — custom topics only. `GemmaOrchestrator.assessTopicLevel` returns `{level, reason, has_history, past_accuracy}` from the Learner Twin agent over local history. Each level card shows its mastery-path step count (4 / 7 / 11) so the user sees the depth tradeoff up front.
2. **STYLE_SELECT** — only **two** modes visible: **Practical** (friend group chat with daily-life examples) and **Movie / TV** (franchise persona-driven). Movie/TV requires picking a franchise via `FranchisePickerSheet`. The selected level is shown as a small caps pill in the subtitle row.
3. **LOADING** — Gemma orb + status text.
4. **STORY** — vertical chat feed:
   - `_ChatBubble` (in `story_screen.dart`): left/right alignment by character (first char = right, others = left), avatar + name plate + emotion pill, character-color tinted bubble.
   - Scenes auto-reveal on a 1.3 s `Timer.periodic` cadence with a `_WritingPill` ("gemma is typing…") between bubbles. The first scene gets a 600 ms grace so the typing pill is visible at least once. Reveal is decoupled from generation so latency variance is hidden behind the typing pill.
   - BionicText / KaraokeText / TTS still work inside bubbles.
5. **QUIZ** — 3 questions × 4 options. Tracks `_correctCount` and `_missedQuestions`.
6. **RESULTS** — 1–3 stars, XP (35 base + 15 perfect bonus), saves via `retainQuizResult` (awards XP, upserts topic progress, advances mastery path step). When `accuracy ≥ 70` AND `_franchiseObj != null` AND `_level != 'basics'`, the primary CTA becomes **"TEACH ${CHARACTER}"** → `/feynman`.

#### Streaming + parser-enforced alternation (the small-model fixes)

`GemmaOrchestrator.streamStoryChunks` runs the chat as a single streaming call (no separate intro/tail any more). Tokens are buffered, split on newlines, and each `Name|emotion|dialogue` line is parsed into a `StoryScene` and yielded as a tail chunk. The 6-line ABAB speaker order is enforced **in the parser** — `_parsePipeLine` ignores whatever name the model wrote and assigns `cast[sceneIndex % cast.length]`. The small E2B model frequently monologues as cast[0] otherwise.

Quiz is a separate small JSON `generate()` call after the stream closes; it retries once on parse failure (small models drop a brace ~25% of the time). If the chat stream produces zero parseable scenes, the orchestrator throws and `StoryScreen.onError` resets to style-select with a snackbar — no more frozen typing pill.

#### Franchise persona (when Movie/TV is picked)

`AgentPrompts._franchisePersonaBlock(franchise)` injects the top 2 characters' `world_setting`, `speech_style`, `traits`, and first sample dialogue. The orchestrator builds a Dart-side cast (locked `id` slugs); the parser maps every line back to one of those slugs.

Cast capped at **2** — chat-energy stays coherent on the small model and prefill stays under the LiteRT-LM segfault threshold.

### Multimodal scan (`features/scan/screens/scan_textbook_screen.dart`)

`image_picker` → `GemmaOrchestrator.analyzeTextbookImage(bytes)` (returns `{topic, concepts, level, description}`) → `generateStoryFromImage` reuses the Story agent. `FlutterGemma.getActiveModel(supportImage: true)` is required before passing an image message.

### Study Companion (`features/companion/screens/study_companion_screen.dart`)

Uses `GemmaOrchestrator.getStudyPulse` for the auto-generated top card, `queryLearnerTwinStream` for the chat (streaming tokens). Every exchange is persisted via `retainChatExchange` AND prior exchanges are read back via `getRecentChatContext` and injected into the Learner Twin prompt — chat compounds across sessions.

The pulse card surfaces an **active mastery path chip** when one exists: `"4/6 · Photosynthesis · Next: Calvin cycle"` → tap navigates to `/mastery-path`.

### Feynman / "Teach the Character" mode (`features/story_learning/screens/feynman_screen.dart`)

Role-reversal — the kid teaches the franchise character. Reachable only from the Story Results CTA when accuracy ≥ 70%, a real franchise was picked, and level isn't beginner.

The flow is **3 deterministic Gemma turns** (no JSON-decision logic — too unreliable):
1. **opening** — character admits confusion + asks ONE specific question, in their authentic voice
2. *(student types reply)*
3. **followUp** — character paraphrases, asks ONE clarifying follow-up
4. *(student types reply)*
5. **lightbulb** — character has the "I get it!" moment + 1-sentence recap

Each turn is a fresh `_gemma.generateStream(...)` call with the running transcript. The system prompt (`_buildFeynmanSystemPrompt` in the orchestrator) hard-locks the character's `speechStyle`, `humorStyle`, `emotionalStyle`, `traits`, and first sample dialogue. Score = stars (1–3) based on the *shorter* of the two student replies (≥30 chars → 2, ≥80 → 3). XP = 30/45/60. Persisted as `type='feynman_taught'` row in `memory_events` so the Companion can reference it later.

### Franchise dataset (`assets/data/franchises.json`, v3)

80 franchises × 6 characters × 5 sample dialogues + `teaching_dialogues` (added in v3, used by future expansions).

Schema fields per franchise entry:

```json
{
  "id": "naruto",
  "name": "Naruto",
  "category": "anime",
  "age_rating": "all",
  "world_setting": "One-line setting description injected into the persona block",
  "topic_affinity": ["physics", "biology"],
  "characters": [
    {
      "name": "...", "role": "...", "traits": [],
      "speech_style": "...", "humor_style": "...",
      "emotional_style": "...", "teaching_style": "...",
      "sample_dialogues": [], "teaching_dialogues": []
    }
  ]
}
```

- `age_rating`: `"all"` | `"13+"` | `"16+"` | `"18+"`
- `category`: anime, cartoons, live_action, movies, indian, k_drama, gaming
- `Franchise` Dart model in `lib/core/franchises/franchise_loader.dart` parses everything; loader is a cached singleton with case-insensitive `findByName`.
- `FranchisePickerSheet` handles all 7 categories with distinct colors (k_drama: `0xFFFF6B9D`, gaming: `0xFF00FF88`).

### Theme (`lib/core/theme/app_theme.dart`)

Dark glassmorphism + neon accents. Key colors: bg `0xFF0A0E21`, surface `0xFF0F1328`, cyan `0xFF00F5FF`, purple `0xFFB429F9`, green `0xFF00FF88`, gold `0xFFFFD700`. Default fonts: Orbitron (headers), Space Grotesk (body). Dyslexic mode swaps both to Atkinson Hyperlegible. Use `AppTheme.*`, `GlassContainer`, `NeonButton`. A light theme exists (`AppTheme.lightTheme`) and is selectable via `ThemeProvider`, but the visual language was designed for dark.

## Conventions

- **No cloud calls.** If you're tempted to add `http`, `dio`, `firebase_*`, or a cloud AI SDK — stop. Offline-after-bootstrap is the pitch. The one exception is `flutter_tts` which uses the device's local TTS engine (no network).
- **Riverpod is barely used.** Don't introduce Riverpod providers for new feature state; follow the existing `StatefulWidget` + `ChangeNotifier` pattern unless you have a strong reason.
- **JSON from Gemma is unreliable.** Always parse through `_parseJsonAny` (or replicate its behavior) — never `jsonDecode(raw)` directly on model output. For chat-style flows (Companion, Feynman, Story) use plain text streaming with a regex/parser, not JSON. When you do use JSON (e.g., quiz, mastery, image-analysis), retry once on parse failure — the small model drops a brace surprisingly often.
- **All Gemma prompts must thread `language`.** The user's language is `LocalProfileService.instance.currentProfile?.language` and the orchestrator passes it into every prompt. Mood and dyslexic flags follow the same pattern.
- **Story cast + speaker order are built in Dart, not Gemma.** Locking `characterId` to a known slug list prevents Gemma from inventing new names. ABAB alternation is enforced in `_parsePipeLine` via `cast[sceneIndex % cast.length]` — the model's name token is ignored. The prompt still asks for alternation as a soft hint, but trust the parser.
- **Topic keys are sanitized.** Always round-trip through `_sanitizeKey` / the equivalent regex before reads.
- **A11y is opt-in and lazy.** TTS engine must NOT initialize on app startup — only on first `speak()` call. Both dyslexic and TTS toggles default OFF.
- **Resist re-adding deleted features.** The Franchise Lab subapp, Comic Album, Knowledge Graph, Skill Tree, Achievements, Courses, Topic Explorer, and Search routes were removed in a deliberate Story-first cut. If a hackathon-feature impulse arrives ("we should add a leaderboard…"), check whether it actually serves the five pillars before writing code.
- **Tests are minimal** (`test/widget_test.dart` only). Don't assume a test suite runs in CI.
- **Legacy docs** (`docs/ARCHITECTURE.md`, `docs/DATABASE_SCHEMA.md`, `docs/API_PROMPTS.md`, `hack.md`) describe the old Firebase/cloud version — treat as historical.
