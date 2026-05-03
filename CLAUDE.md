# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## The pivot (read this first)

This repo was previously a cloud-AI + Firebase app (DeepSeek/Groq/Hindsight, Firestore, Cloud Functions). It has been rewritten for the **Kaggle Gemma 4 Good Hackathon** as a **fully on-device, offline-after-bootstrap** app:

- **AI:** All inference runs locally via `flutter_gemma` (LiteRT-LM) using `gemma-4-E2B-it.litertlm` (~2.58 GB). No DeepSeek, no Groq, no Hindsight, no Gemini API.
- **Storage:** SQLite (`sqflite`) via `lib/core/db/app_database.dart`. No Firestore, no Firebase Auth, no Cloud Functions.
- **Profiles:** Local-only via `LocalProfileService` — name/grade/language/mood/dyslexic-mode/tts-flag, multiple profiles supported. No login, no password.
- **Memory:** `LocalMemoryService` replaces Hindsight — same "retrieve past events → inject into prompt" pattern, but reads from SQLite.

The legacy Firebase Functions tree (`functions/`) is still on disk but not wired in. Treat as dead weight — don't extend it.

## Build & Run

```bash
# Deps
flutter pub get

# Code generation (Riverpod / Freezed / JSON serialization)
dart run build_runner build --delete-conflicting-outputs

# Run on connected Android device (Android 12+, ≥6 GB RAM, ≥5 GB free)
flutter devices
flutter run -d <DEVICE_ID> --dart-define=HF_TOKEN=<optional_hf_token>

# Run the Franchise Lab subapp instead (separate entrypoint, isolated DB,
# requires the main app to have already installed the model)
flutter run -t lib/franchise_lab/main.dart -d <DEVICE_ID>

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

E2B is the only supported model. The earlier E4B variant + variant-switching API was removed — don't reintroduce it without a strong reason.

### Android requirements (`android/app/build.gradle.kts`)

- `minSdk = 31` (hard requirement for LiteRT-LM)
- `androidResources.noCompress += ["tflite", "litertlm", "task", "bin"]` — model files must be stored uncompressed for mmap
- `applicationId = "com.vidyasetu.vidyasetu"` — don't rename; the documented sideload path depends on this exact value
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
│   ├── services/     # LocalProfileService, LocalMemoryService, TextToSpeechService (lazy)
│   ├── theme/        # AppTheme (incl. dyslexic font variant), ThemeProvider
│   ├── widgets/      # GlassContainer, NeonButton, BionicText, KaraokeText, ParticleBackground
│   ├── constants/    # AppConstants
│   └── utils/
├── features/
│   ├── setup/, auth/, story_learning/, companion/, scan/, profile/,
│   ├── courses/, achievements/, skill_tree/, knowledge_graph/, search/
│   └── mastery_path/   # Duolingo-style path UI (Wave 1)
├── franchise_lab/    # Parallel experimental subapp — own main.dart, isolated DB,
│                     # franchise-persona Story Learn + Companion + Profile + Comic Album + Feynman
├── routes/app_router.dart
└── main.dart         # FlutterGemma.initialize → LocalProfileService.initialize → runApp
```

### Three-layer AI stack

1. **`GemmaService`** (`core/ai/gemma_service.dart`) — Singleton wrapper over `flutter_gemma`. Owns model lifecycle (download, sideload, install, warm). Exposes `generate`, `generateStream`, `generateFromImage`, `createCompanionChat`.
2. **`GemmaOrchestrator`** (`core/ai/gemma_orchestrator.dart`) — Singleton. **Seven agents** (Story, Tutor, Quiz, Explorer, Planner, LearnerTwin, **Mastery** + Image Analysis + intent Orchestrator) share one Gemma instance; identity is the system prompt. The orchestrator pulls memory context from `LocalMemoryService`, threads `language`, `mood`, and `dyslexic` flags from the active profile, calls `GemmaService`, then parses JSON with a tolerant extractor (`_parseJsonAny`) that strips markdown fences and finds the first balanced `{...}` / `[...]`. Gemma frequently prefixes output with prose — don't skip this step.
3. **`AgentPrompts`** (`core/ai/agent_prompts.dart`) — Pure system prompt templates. Every prompt enforces `Language: {language}` and "Return ONLY valid JSON — no markdown fences". Composable blocks: `_styleBlock` (desi_meme/practical/movie_tv/exam/beginner), `_moodBlock` (calm/hyped/anxious/sad/curious), `_a11yBlock` (dyslexic mode → shorter sentences, plainer words).

When adding a new feature that calls AI: add a method to `GemmaOrchestrator`, add a template to `AgentPrompts`, keep `GemmaService` untouched.

### Memory pattern (local replacement for Hindsight)

`LocalMemoryService` mirrors the old `HindsightService` API surface and goes further:

- **Retain** — `retainQuizResult` (also auto-advances the active mastery path step on ≥70% accuracy when path keys are passed), `retainTopicInterest`, `retainChatExchange`. `retainQuizResult` upserts the `topics` row (level promotion on ≥70%) and calls `LocalProfileService.addXP(35 + perfect_bonus)`.
- **Recall** — `getStudyContext(topic)` formats past quiz results + events for prompt injection. `getFormattedHistory()` returns everything for Learner Twin / Planner. **`getRecentChatContext()`** pulls the last 8 chat exchanges so the Companion is no longer amnesiac across sessions. **`getWeakAreas(topic)`** extracts repeated misses for adaptive quizzing.
- **Mastery** — `saveMasteryPath`, `getMasteryPath`, `getActiveMasteryPaths`, `markStepComplete`. Backed by the new `topic_paths` table.
- **Progress** — `getAllTopicProgress()` returns `[{name, level, accuracy, stars}]` for the Planner agent.

All retain calls are fire-and-forget from call sites; all recall calls must run before the Gemma prompt is built.

### Local SQLite schema (`app_database.dart`, version 4)

Six tables, all keyed by `profile_id` (supports multiple profiles on one device):

- `profiles` — `name`, `language`, `grade`, `xp`, `streak`, `interests` (JSON array), **`current_mood`**, **`last_mood_date`**, **`dyslexic_mode`**, **`tts_enabled`**
- `topics` — per-profile per-topic progress (`topic_key`, `level`, `accuracy`, `stars`, `quiz_count`, `last_studied`). Unique on `(profile_id, topic_key)`.
- `quiz_results` — raw history (`missed_questions` + `concepts` as JSON arrays)
- `memory_events` — narrative events for RAG-style recall (`type`, `content`, `topic`, `tags`)
- `chat_history` — per-agent chat log (`agent = 'companion' | ...`)
- **`topic_paths`** — Mastery Agent output: `topic_key`, `topic_name`, `steps_json` (5–7 steps), `current_step_index`, `completed_step_indices` (JSON array of ints), `estimated_minutes`. Unique on `(profile_id, topic_key)`.

Migrations are idempotent and additive: v1 → v2 adds `topic_paths`, v2 → v3 adds the mood columns, v3 → v4 adds the a11y columns. `topic_key` is always `topic.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')`.

### Mastery Agent + Path UI (Wave 1 — the spine)

`AgentPrompts.mastery(...)` decomposes any topic into 5–7 progressive steps with concept tags + difficulty. `GemmaOrchestrator.decomposeMasteryPath` injects the learner's *already-mastered* concepts so the agent can skip basics they already know.

`MasteryPathScreen` (`features/mastery_path/screens/`) is a Duolingo-style stepped UI:
- Self-bootstraps the path on first visit (calls `decomposeMasteryPath` → `saveMasteryPath`)
- Each step card shows status indicator (mastered/current/locked), title, description, concept chips, difficulty badge
- Tapping the current step navigates to `/lesson` with `pathTopicKey` + `pathStepIndex` in `state.extra`
- On return, post-frame `_refreshSilently()` re-pulls the path so completed steps show ticks immediately

Step completion is tied into `retainQuizResult`: if the lesson was launched from a path AND quiz accuracy ≥ 70%, the path's `completed_step_indices` is updated and `current_step_index` advances to the next unfinished step.

### Mood-aware prompts (Wave 2)

`LocalProfile.needsMoodCheckIn` returns true on the first launch of each calendar day. The home dashboard shows a 5-button mood card (calm / hyped / curious / anxious / sad) above the hero card. Selecting a mood calls `LocalProfileService.setMood`, persists it with the date, hides the card.

`AgentPrompts._moodBlock(mood)` injects a tone-shift instruction into Story and Learner Twin prompts. Examples: anxious → "be reassuring, slow down, no scary jargon"; hyped → "punchy sentences, fun analogies, fast pacing". Empty string when no mood is set — keeps prompts unchanged for cold start.

In the Lab (`franchise_lab/`), the same mood values flow through `streamFranchiseStory` to `_buildSystemPrompt(mood:)` AND power the **mood-aware franchise picker**: `FranchisePickerSheet` accepts an optional `suggestedMood` and surfaces a "BEST FOR YOUR MOOD" header listing the top 3 franchises whose `emotionalStyle`/`speechStyle`/`humorStyle`/`teachingStyle`/`traits` match the mood's keywords (purely on-device heuristic, no model call).

### Accessibility skin (Wave 4 — both toggles default OFF)

- **Dyslexia-friendly mode** — when enabled on `LocalProfile.dyslexicMode`:
  - `AppTheme.headerStyle/bodyStyle` accept `dyslexic: true` and swap to **Atkinson Hyperlegible** (Braille Institute's accessibility font, available via `google_fonts` — no asset bundling) with looser line-height and slight letter spacing.
  - Story dialogue renders through `BionicText` (`core/widgets/bionic_text.dart`) which bolds the first ~40% of each word's letters using `TextSpan` runs.
  - `AgentPrompts._a11yBlock(dyslexic: true)` appends "max 12-word sentences, common words, dialogue ≤ 15 words" to Story / LearnerTwin prompts so generated text is naturally simpler.

- **Read-aloud (TTS)** — when enabled on `LocalProfile.ttsEnabled`:
  - `TextToSpeechService` (`core/services/text_to_speech_service.dart`) is a singleton wrapping `flutter_tts`. **Lazy init** — engine spins up only on the first `speak()` call. Three-tier language fallback: requested BCP-47 lang → device default → typed `TtsResult(TtsStatus.engineUnavailable)` (never throws).
  - `KaraokeText` (`core/widgets/karaoke_text.dart`) listens to `wordIndexStream` and highlights the active word in neon cyan in real time. Word boundaries match TTS's `RegExp(r'\S+')` so indices line up.
  - StoryScreen renders a "🔊 Read aloud" pill below each scene's dialogue *only* when `ttsEnabled` is true. Tapping it speaks; tapping again stops. Errors surface as friendly snackbars ("TTS not available — install a language pack from Settings").

When neither toggle is on, everything renders identically to before — zero footprint for non-a11y users.

### Navigation (`lib/routes/app_router.dart`)

Single `GoRouter` provider with a guard that redirects to `/setup` if model not ready, else `/setup/profile` if no profile. Initial location is `/home`.

Setup flow: `/setup` (model download or sideload import) → `/setup/profile` → `/home`.

Home is a `ShellRoute` with 3-tab bottom nav: `/home`, `/home/companion`, `/home/profile`.

Other standalone routes: `/lesson`, `/topic-explorer`, `/topics`, `/concept-map`, `/skill-tree`, `/search`, `/achievements`, `/courses`, `/scan`, `/mastery-path`, `/profile`. Route data is passed via `state.extra as Map<String, dynamic>?` — there is no type-safe route param system. The `/lesson` route forwards `pathTopicKey` + `pathStepIndex` so quiz completion can advance the active mastery path.

### Story Learning — 6-phase flow (`features/story_learning/screens/story_screen.dart`, ~1500 lines)

1. **LEVEL_SELECT** — custom topics only. `GemmaOrchestrator.assessTopicLevel` returns `{level, reason, has_history, past_accuracy}` from the Learner Twin agent over local history.
2. **STYLE_SELECT** — Desi Meme / Practical / Movie-TV (prompts for franchise name).
3. **LOADING** — `StoryGeneratorService` (`features/story_learning/services/story_generator_service.dart`) calls `GemmaOrchestrator.generateStory`, which internally pulls `getStudyContext(topic)`, mood, and dyslexic flag and injects them into the Story system prompt.
4. **STORY** — visual novel with typewriter dialogue, per-character colors, scene progress bar. Dialogue rendering picks BionicText (dyslexic + idle), KaraokeText (TTS speaking), or plain Text via `_buildDialogue()`.
5. **QUIZ** — 3 questions × 4 options. Tracks `_correctCount` and `_missedQuestions`.
6. **RESULTS** — 1–3 stars, XP (35 base + 15 perfect bonus), saves via `LocalMemoryService.retainQuizResult` (which awards XP, upserts topic progress, AND advances the mastery path step if `widget.pathTopicKey` was passed).

When modifying StoryScreen: work by `_Phase` enum — do not restructure phases.

### Multimodal scan (`features/scan/screens/scan_textbook_screen.dart`)

`image_picker` → `GemmaOrchestrator.analyzeTextbookImage(bytes)` (returns `{topic, concepts, level, description}`) → `generateStoryFromImage` reuses the Story agent. `FlutterGemma.getActiveModel(supportImage: true)` is required before passing an image message.

### Study Companion (`features/companion/screens/study_companion_screen.dart`)

Uses `GemmaOrchestrator.getStudyPulse` for the auto-generated top card, `queryLearnerTwinStream` for the chat (streaming tokens). Every exchange is persisted via `LocalMemoryService.retainChatExchange` AND prior exchanges are read back via `getRecentChatContext` and injected into the Learner Twin prompt — chat compounds across sessions instead of starting cold every time.

The pulse card surfaces an **active mastery path chip** when one exists: `"4/6 · Photosynthesis · Next: Calvin cycle"` → tap navigates to `/mastery-path`.

## Franchise Lab (parallel subapp)

`lib/franchise_lab/` is an **additive, isolated** experimental app that lives alongside the main Learnify build. Run it via `flutter run -t lib/franchise_lab/main.dart`. Shares only `GemmaService`, `AppTheme`, the story-response models, and the new a11y widgets with production code. It does **not** modify any main-app source.

Why it exists: validate franchise-persona-driven story-learning, comic-album generation, and Feynman role-reversal experiments before merging anything back.

Key boundaries:

- **Isolated DB** — `lab_database.dart` opens `franchise_lab.db` (separate SQLite file from the main app's `app_database.db`). Killing one does not affect the other. Schema v2: adds `lab_comics` table.
- **Mirror services** — `LabProfileService` and `LabMemoryService` mirror the API of the main `LocalProfileService` / `LocalMemoryService` but write to the lab DB. `LabMemoryService` also handles franchise usage tracking, comic persistence, Feynman session retention, and **`getRecentChatContext()`** for cross-session chat continuity.
- **`LabOrchestrator`** — does **not** use `GemmaOrchestrator`. It builds its own system prompts that swap in **franchise persona blocks** loaded from `assets/data/franchises.json` (**80 franchises × 6 characters × 5 dialogues each**, IP-safe generic-role characters). It calls `GemmaService.generate` directly and retries on JSON parse failure with a "shorter scenes" prompt. `_buildCast` limits the story cast to `take(4)` for coherence; `_franchisePersonaBlock` injects `world_setting`, `speechStyle`, and first dialogue only — extra dialogues in DB don't add prompt tokens. Continuation prompts (scenes 2/3) inject the previous scenes' dialogue text so the model doesn't regurgitate. Mood and Feynman methods are gated alongside the story flow.
- **Refuses to launch without the model** — shows `_ModelMissingScreen` if `GemmaService.isReady` is false. The lab does not run model setup itself; the user must open the main app first.

3-tab `LabShell`: **Story Learn** (7-phase flow with mood gate at STEP 3), **Companion** (streaming Learner Twin with chat memory loop-back), **Profile** (XP/streak/mastered/weak topics + favorite franchises + recent activity + **Comic Album entry tile**).

### Comic Album (Lab — Wave 3)

After completing a Lab story, the results screen shows a **"SAVE AS COMIC"** button. `LabOrchestrator.buildComicPayload(topic, story, franchise)` is **deterministic, no extra Gemma call** — it picks 4 representative scenes (1st, ~⅓, ~⅔, last), packs character names/colors/emotions/dialogue into a JSON payload, and `LabMemoryService.saveComic` persists it to `lab_comics`.

`ComicAlbumScreen` (accessed from Lab Profile) renders the saved comics in a 2-column `GlassContainer` grid using `ComicPanelGrid(compact: true)` thumbnails. Tapping opens a fullscreen viewer with `ComicPanelGrid(compact: false)`. Long-press deletes after a confirm dialog.

`ComicPanelGrid` (`franchise_lab/widgets/comic_panel_grid.dart`) renders 4 panels in a 2×2 grid using pure Flutter primitives — no SVG, no image gen. Each panel has a comic-style black border, a character-tinted gradient background, a name plate (top-left), an emotion pill (top-right), a speech bubble (bottom) clipped via `_SpeechBubbleClipper` with a classic comic tail, and optional manga "speed lines" via `_SpeedLinesPainter`.

### Feynman / "Teach the Character" mode (Lab — Wave 5)

When a Lab story finishes with **accuracy ≥ 70%, difficulty ≠ beginner, AND a franchise was used**, the results screen unlocks a purple **"TEACH ${CHARACTER}"** CTA. Tapping it opens `FeynmanModeScreen` — a role-reversal where the kid teaches the franchise character.

The flow is **3 deterministic Gemma turns** (no JSON-decision logic — too unreliable):
1. **opening** — character admits confusion + asks ONE specific question, in their authentic voice
2. *(student types reply)*
3. **followUp** — character paraphrases, asks ONE clarifying follow-up
4. *(student types reply)*
5. **lightbulb** — character has the "I get it!" moment + 1-sentence recap in their voice

Each turn is a fresh `_gemma.generateStream(...)` call with the running transcript. The system prompt (`_buildFeynmanSystemPrompt`) hard-locks the character's `speechStyle`, `humorStyle`, `emotionalStyle`, `traits`, and first sample dialogue. Score = stars (1–3) based on the *shorter* of the two student replies (≥30 chars → 2 stars, ≥80 chars → 3). XP = 30/45/60. Persisted as `type='feynman_taught'` row in `lab_memory_events`.

### Franchise dataset (`assets/data/franchises.json`)

**Version 2** — 80 franchises, 6 characters each, 5 dialogues per character.

Category breakdown: anime (21), live_action (14), movies (12), cartoons (11), indian (11), gaming (5), k_drama (6).

Schema fields per franchise entry:

```json
{
  "id": "naruto",
  "name": "Naruto",
  "category": "anime",
  "age_rating": "all",
  "world_setting": "One-line setting description injected into the persona block",
  "topic_affinity": ["physics", "biology"],
  "characters": [{ "name": "...", "role": "...", "traits": [], "speech_style": "...", "humor_style": "...", "emotional_style": "...", "teaching_style": "...", "sample_dialogues": [] }]
}
```

- `age_rating`: `"all"` | `"13+"` | `"16+"` | `"18+"` — reserved for future content filtering
- `category`: anime, cartoons, live_action, movies, indian, k_drama, gaming
- `Franchise` Dart model in `franchise_loader.dart` has corresponding `ageRating`, `worldSetting`, `topicAffinity` fields
- `FranchisePickerSheet` handles all 7 categories with distinct colors (k_drama: `0xFFFF6B9D`, gaming: `0xFF00FF88`)

When extending the lab: keep it self-contained. If you need a feature from the main app, copy or shim it inside `franchise_lab/`. The whole point is that the lab can be deleted without breaking the main app.

### Theme (`lib/core/theme/app_theme.dart`)

Dark glassmorphism + neon accents. Key colors: bg `0xFF0A0E21`, surface `0xFF0F1328`, cyan `0xFF00F5FF`, purple `0xFFB429F9`, green `0xFF00FF88`, gold `0xFFFFD700`. Default fonts: Orbitron (headers), Space Grotesk (body). Dyslexic mode swaps both to Atkinson Hyperlegible. Use `AppTheme.*`, `GlassContainer`, `NeonButton`. A light theme exists (`AppTheme.lightTheme`) and is selectable via `ThemeProvider`, but the visual language was designed for dark.

## Conventions

- **No cloud calls.** If you're tempted to add `http`, `dio`, `firebase_*`, or a cloud AI SDK — stop. The pitch of this app is offline-after-bootstrap. The one exception is `flutter_tts` which uses the device's local TTS engine (no network).
- **Riverpod is barely used.** Don't introduce Riverpod providers for new feature state; follow the existing `StatefulWidget` + `ChangeNotifier` pattern unless you have a strong reason.
- **JSON from Gemma is unreliable.** Always parse through `_parseJsonAny` (or replicate its behavior) — never `jsonDecode(raw)` directly on model output. For chat-style flows (Companion, Feynman) use plain text streaming instead.
- **All Gemma prompts must thread `language`.** The user's language is `LocalProfileService.instance.currentProfile?.language` and the orchestrator passes it into every prompt. Mood and dyslexic flags follow the same pattern.
- **Topic keys are sanitized.** Always round-trip through `_sanitizeKey` / the equivalent regex before reads.
- **A11y is opt-in and lazy.** TTS engine must NOT initialize on app startup — only on first `speak()` call. Both dyslexic and TTS toggles default OFF.
- **Freezed + json_serializable are in pubspec but most models are hand-written.** Match the style of the file you're editing.
- **Tests are minimal** (`test/widget_test.dart` only). Don't assume a test suite runs in CI.
- **Legacy docs** (`docs/ARCHITECTURE.md`, `docs/DATABASE_SCHEMA.md`, `docs/API_PROMPTS.md`, `hack.md`) describe the old Firebase/cloud version — treat as historical, not authoritative.
