# 🎓 Learnify — Emotionally Adaptive Offline Learning 📚⚡

> **An emotionally adaptive offline AI learning companion.**
> One Gemma 4 E2B model running locally via LiteRT-LM —
> stories that read like a WhatsApp group chat, characters
> pulled from 80 of your favourite franchises, and a
> Learner Twin that actually remembers you.
>
> 🚫 No cloud calls
> 🚫 No API keys
> 🚫 No data leaves the device
> ✅ 100% private, fast, offline-first

Built for the **Kaggle Gemma 4 Good Hackathon** 🌍✨ *(Future of Education)*

![flutter](https://img.shields.io/badge/flutter-3.x-blue)
![gemma](https://img.shields.io/badge/gemma-4--E2B-purple)
![runtime](https://img.shields.io/badge/runtime-on--device-green)
![franchises](https://img.shields.io/badge/franchises-80-magenta)

---

# 💡 Why Learnify?

Most AI education apps depend on the internet.
That means they **fail exactly where learning matters most**:

📶 Rural schools with weak signals
🚫 Campuses with blocked Wi-Fi
📱 Students surviving on 2G data
🚌 Long commutes on buses or trains
🏝 Remote villages and islands
🔌 Places where connection drops daily

### Learnify changes that.

Once installed, it works **forever offline**.
Your tutor, planner, storyteller, and study companion live **inside your phone** ❤️📱

---

# 🌟 What Makes Learnify Special?

## 💬 Story Learning — like a group chat, not a textbook

The flagship moment. Type any topic, pick a vibe, and the lesson arrives as a real chat conversation between 2 characters reacting, joking, paraphrasing, getting it wrong, then getting it right.

🎭 Two modes:

* 🛠 **Practical** — friend-group chat, daily-life examples *("bro why do bikes skid in the rain?" / "less friction" / "wait so friction is actually GOOD??")*
* 🎬 **Movie / TV** — pick from **80 franchises** (anime, cartoons, K-drama, gaming, Indian TV, movies). Naruto, Stranger Things, Money Heist, Goku, Walter White, MS Dhoni, Itachi… they teach in their own voice.

⚡ **Wave-based generation**: the first 6 scenes stream in, then up to 2 more continuation waves push the lesson to 16–18 messages — depth without the small model getting overwhelmed by a single mega-prompt. Each wave re-injects the persona block so cast voices don't drift.

🔁 Each message auto-reveals on a 1.7 s typing-pill cadence (like a real chat), scrolls into a chat feed, and the cast + speaker order is locked in code so Gemma can't drift off-character or monologue as one person. We also filter out mascot characters (Pikachu, etc.) at cast-build time — they have rich voice samples but can't carry a teaching dialogue in English.

---

## 🧠 Learner Twin — your AI that remembers

Your study companion that builds a private model of YOU over time, fully on-device.

Ask:

📝 What should I study next?
😵 Where am I weakest?
📈 How am I improving?
🔥 Motivate me today

Every chat compounds — it doesn't reset between sessions. Every quiz, every mood check-in, every story you finished feeds the same SQLite memory.

---

## 🗺 Mastery Path — the primary entry point

Type any topic into **Learn Anything** and the default action now builds a Duolingo-style stepped path: **4 steps at basics**, **7 at intermediate**, **11 at advanced**. Each step has concept tags + a difficulty badge, and ticks fill in as you pass at ≥70% accuracy.

Each step is one short stepped story. Want a single throwaway chat instead? The chip below the input — *"Skip the path · just chat about it →"* — bypasses the path and goes straight to a one-shot lesson.

🪶 **Mastery generation has belt-and-braces JSON parsing**: tight prompt → schema-shape validation → retry with key-names spelled out → last-resort prose salvage that extracts "Stage N: title" headings from any markdown the model emits. The user never sees a dead end.

---

## 🎓 Teach It Back (Feynman Mode)

After a strong score (≥70%) on a franchise lesson, the tables flip — the character admits they didn't quite get it and asks **you** to teach them. Three deterministic turns (opening question → follow-up → lightbulb moment), all in their authentic voice. Teaching is mastery.

---

## 😊 Emotionally Aware

Daily mood check-in (calm / hyped / curious / anxious / sad) quietly reshapes the tone of every story and the picker's franchise suggestions — anxious days lean toward calmer, gentler casts; hyped days unlock loud bombastic ones.

---

## ♿ Accessibility, opt-in

* **Dyslexia-friendly mode** — Atkinson Hyperlegible font, BionicText word emphasis, prompts auto-shorten sentences.
* **Read-aloud (TTS)** — every chat bubble can be spoken aloud with karaoke-style word highlighting via the device's offline TTS engine.

Both default OFF. Zero footprint when not used.

---

## 🔒 Privacy First

No tracking. No ads. No cloud syncing. No surveillance.

Your learning belongs to **you** ❤️

---

# 🛠 Tech Stack

| Layer         | Choice                                                              |
| ------------- | ------------------------------------------------------------------- |
| 🧠 Model      | `litert-community/gemma-4-E2B-it-litert-lm` (~2.58 GB, sideloadable) |
| ⚙ Runtime     | `flutter_gemma` v0.13.5 (LiteRT-LM)                                 |
| 📱 Framework  | Flutter 3.x · Dart                                                  |
| 🧭 Navigation | go_router                                                           |
| 💾 Storage    | SQLite via `sqflite` (6 tables, multi-profile)                      |
| 🗣 TTS        | `flutter_tts` — device-local, lazy init                             |
| 🎨 UI         | Dark glassmorphism + neon · Atkinson Hyperlegible (a11y)            |
| 🎭 Personas   | 80 franchises × 6 characters × 5+ sample dialogues (JSON asset)     |

---

# 🚀 Build & Run

```bash
# Deps
flutter pub get

# Code generation (Riverpod / Freezed / JSON)
dart run build_runner build --delete-conflicting-outputs

# Run on a connected device
flutter devices
flutter run -d <DEVICE_ID>

# Optional: pass a Hugging Face token for in-app download
flutter run -d <DEVICE_ID> --dart-define=HF_TOKEN=<token>
```

### 📥 Three ways to get the model on device

1. **In-app download** (recommended) — tap *Download Gemma 4 E2B* on first launch. The download runs in the background via `flutter_downloader` with a system notification, survives screen-lock / app-backgrounding, and resumes on partial network drops. On completion the engine auto-installs and warms — no second tap.
2. **Sideload via ADB** — if you already have the `.litertlm`:
   ```bash
   adb push gemma-4-E2B-it.litertlm \
     /storage/emulated/0/Android/data/com.vidyasetu.vidyasetu/files/
   ```
   First launch detects the file and silently imports + warms it. You'll see the new **BootstrapScreen** (branded splash + progress bar + status text) rather than the old mute black splash.
3. **Pick from device** — if the file is sitting in Downloads or shared from another app, tap *"Pick a .litertlm file from your device"* on the setup screen. Works for files anywhere `image_picker` / `file_picker` can read.

### 📱 Device Requirements

✅ Android 12+ (`minSdk = 31`, hard requirement for LiteRT-LM)
✅ ≥ 4 GB RAM
✅ ≥ 5 GB free storage (model is ~2.58 GB + temp copy during install)

---

# 🎉 First Launch Experience

1️⃣ Pick a model: background download (~2.58 GB), ADB sideload, or browser-download + file picker
2️⃣ Wait through the **BootstrapScreen** (progress bar + status) while LiteRT-LM warms the engine — ~25 s on a mid-range Android, ~50 s if it's also copying from sdcard
3️⃣ Enter name + grade + language
4️⃣ Optionally toggle dyslexia-friendly mode + read-aloud
5️⃣ Done forever ✅

After that:

✈ Turn on airplane mode
📴 Disconnect Wi-Fi
🌍 Go anywhere

**Learnify still works perfectly.**

### Try this demo path

1. **Mood check** → tap *Curious*
2. **Learn Anything** → type *"why the sky is blue"*
3. **Movie / TV** → pick a franchise that matches your mood
4. **Watch the chat** unfold scene by scene
5. **Ace the quiz** → unlock **TEACH ${CHARACTER}** and flip the table

---

# 🏗 Architecture

```bash
lib/
├── core/
│   ├── ai/           # GemmaService, GemmaOrchestrator, AgentPrompts
│   ├── db/           # SQLite (profiles, topics, quiz, memory, paths)
│   ├── franchises/   # FranchiseLoader + persona models (80 franchises)
│   ├── services/     # LocalProfileService, LocalMemoryService, TTS
│   ├── theme/        # Dark glassmorphism + dyslexic font variant
│   └── widgets/      # GlassContainer, NeonButton, BionicText, KaraokeText
├── features/
│   ├── setup/        # Model download / sideload + profile creation
│   ├── auth/         # Home shell + dashboard
│   ├── story_learning/  # Chat-bubble Story + Feynman screen
│   ├── companion/    # Learner Twin chat
│   ├── mastery_path/ # Duolingo-style stepped UI
│   ├── scan/         # Multimodal textbook capture
│   └── profile/
└── routes/           # /lesson, /feynman, /scan, /mastery-path, /home/*
```

---

# 🧠 Multi-Agent Design

One Gemma model in RAM. Identity = system prompt. The orchestrator routes intent and threads `language` + `mood` + `dyslexic` flags into every call.

```text
User → GemmaOrchestrator
   ├── 📖 Story            (16–18-scene chat lessons via wave continuations)
   ├── 🧠 Tutor            (concept explanation)
   ├── ❓ Quiz             (5 questions w/ concept tags, weak-area aware)
   ├── 📅 Planner          (7-day study schedule)
   ├── 🔍 Explorer         (sub-topic decomposition)
   ├── 🗺 Mastery          (4 / 7 / 11 step paths, JSON-strict + prose salvage)
   ├── 👤 Learner Twin     (Companion chat, names recent weak concepts)
   ├── 📷 Scan Textbook    (ML Kit OCR → text-only Gemma; multimodal isn't viable on the .litertlm E2B build)
   └── 🎓 Feynman          (role-reversal teaching)
```

⚡ Shared weights — one model, all agents
⚡ Progressive streaming on Story (intro paints in seconds, tail arrives in background)
⚡ Cast locked in Dart so Gemma can't invent off-character names
⚡ Add a new agent = a new prompt + an orchestrator method

---

# 🌍 Why This Matters

Education should not depend on internet speed.

A child in a village deserves the same AI tutor as a student in a smart city.
A learner on a train deserves help even without signal.
A classroom deserves intelligence without surveillance.

**Learnify brings equal opportunity through offline AI.** ❤️

---

# 🏆 Built For

**Kaggle Gemma 4 Good Hackathon**
Theme: **Future of Education**

---

# 📜 License

Built on Gemma, subject to Gemma Terms of Use.

---

# ⭐ Final Line

> **The future of education should fit in your pocket — and feel like a friend.** 📱❤️✨
