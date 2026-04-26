# Franchise Lab

Experimental test-app inside `learnify-offline` for validating whether a small
on-device Gemma model can deliver a "magical" franchise-style story-learning
experience + a useful Learner Twin companion **before** merging into the main
Learnify product.

The lab is **additive** — it lives in a separate folder, runs as a separate
Flutter target, and uses an isolated SQLite file so experimental runs do not
pollute the main app's profile/topic data.

---

## Run

```bash
# main app must have already installed the Gemma .litertlm model
flutter run -t lib/franchise_lab/main.dart -d <device_id>
```

If the model isn't present on disk, the lab shows a "Model not installed"
screen telling you to open the main Learnify app first.

---

## What's inside

3 tabs, kept deliberately focused:

1. **Story Learn** — `topic → difficulty → franchise → loading → story → quiz → results`.
   Generates a 3-5 scene visual novel using one of 26 curated franchise personas.
2. **Companion** — Learner Twin chat backed by the lab's isolated memory
   (streaming tokens). Persists every exchange.
3. **Profile** — XP, streak, topics mastered, weak topics, top 3 favorite
   franchises, last 10 activity events.

---

## Dataset

`assets/data/franchises.json` — 26 franchises × 4 characters × 3 dialogues
(~312 lines of vibe-based persona content). Schema:

```json
{
  "version": 1,
  "franchises": [
    {
      "id": "kebab-case-slug",
      "name": "Display Name",
      "category": "anime|cartoons|live_action|movies|indian",
      "characters": [
        {
          "name": "generic role label",
          "role": "short label",
          "traits": ["..."],
          "speech_style": "...",
          "humor_style": "...",
          "emotional_style": "...",
          "teaching_style": "...",
          "sample_dialogues": ["...", "...", "..."]
        }
      ]
    }
  ]
}
```

**No actual character names.** All characters use generic role labels
("ninja apprentice" instead of the real name) and dialogue lines are original
vibe-references — no verbatim catchphrases — to dodge IP issues.

---

## Architecture

| File | Purpose |
|---|---|
| `lib/franchise_lab/main.dart` | Entry point; bootstraps `GemmaService` + lab DB; refuses to launch if model not installed. |
| `lib/franchise_lab/data/franchise_loader.dart` | Lazy-loads `franchises.json` once; case-insensitive name lookup. |
| `lib/franchise_lab/data/lab_database.dart` | Isolated `franchise_lab.db` SQLite. 5 tables. |
| `lib/franchise_lab/services/lab_profile_service.dart` | ChangeNotifier wrapping the lab profile (single row). |
| `lib/franchise_lab/services/lab_memory_service.dart` | Mirrors `LocalMemoryService` API but writes to lab DB. Adds `bumpFranchiseUsage`. |
| `lib/franchise_lab/services/lab_orchestrator.dart` | Custom system prompt builder that swaps in franchise persona blocks; reuses `GemmaService.generate`. Story-retry on parse failure. |
| `lib/franchise_lab/screens/lab_setup_screen.dart` | First-run "Lab name" prompt. |
| `lib/franchise_lab/screens/lab_shell.dart` | 3-tab bottom-nav shell. |
| `lib/franchise_lab/screens/story_learn_screen.dart` | 7-phase Story Learn state machine. |
| `lib/franchise_lab/screens/companion_screen.dart` | Streaming chat with Learner Twin. |
| `lib/franchise_lab/screens/profile_screen.dart` | Stats, mastered/weak topics, favorites, activity. |
| `lib/franchise_lab/widgets/franchise_picker.dart` | Searchable bottom-sheet picker over the dataset. |

### What's reused from the main app (read-only)

- `GemmaService` — model lifecycle + `generate`/`generateStream`
- `StoryResponse` / `StoryScene` / `StoryQuizQuestion` / `FranchiseCharacter` models
- `AppTheme` — colors + dark theme
- `pubspec.yaml` — single additive line registering `assets/data/`

The lab does **not** touch any production source file.

---

## Success metrics — fill in while testing

| Metric | Score (1-5) | Notes |
|---|---|---|
| Story believability | | does the scene actually teach the topic? |
| Franchise vibe match | | can a fan recognise the franchise without the name? |
| Companion usefulness | | did the Twin reference your real history? |
| Generation latency | | seconds from "Generate" tap to story rendered |
| Parse failure rate | | how often does the JSON retry kick in? |

---

## Known weak spots of small Gemma to watch for

1. **Persona drift mid-story** — characters start as the franchise vibe but
   slide back to generic textbook voice by scene 4. Prompt currently puts the
   persona block above the story rules; if drift is high, promote it further.
2. **Schema drift** — Gemma sometimes emits `name`/`reason` instead of
   `title`/`description`. Story shape uses `dialogue`/`narration` so this is
   less likely here, but watch for it. `[Lab.story] raw` lines in logcat show
   exactly what Gemma returned.
3. **JSON truncation on long outputs** — current cap is 4096 tokens. If the
   story is too elaborate it gets cut off. Retry prompt explicitly asks for
   shorter scenes.
4. **Refusal to use franchise vibe when topic is dry** — for very technical
   topics the model may default to generic teacher voice. The persona block
   tries to counter this but can be made more aggressive if it shows up.
5. **Indian franchise persona quality** — Chhota Bheem, Motu Patlu, Sholay,
   3 Idiots may be less familiar to the small model. If quality drops, the
   dataset can be edited without touching code.

---

## Verify isolation

```bash
adb shell run-as com.vidyasetu.vidyasetu ls databases/
# should list both:
#   app_database.db       <- main app
#   franchise_lab.db      <- lab
```

Killing or wiping one does not affect the other.
