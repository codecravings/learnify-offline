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

The flagship moment. Type any topic, pick a vibe, and the lesson arrives as a real chat conversation between 2–3 characters reacting, joking, paraphrasing, getting it wrong, then getting it right.

🎭 Two modes:

* 🛠 **Practical** — friend-group chat, daily-life examples *("bro why do bikes skid in the rain?" / "less friction" / "wait so friction is actually GOOD??")*
* 🎬 **Movie / TV** — pick from **80 franchises** (anime, cartoons, K-drama, gaming, Indian TV, movies). Naruto, Stranger Things, Money Heist, Goku, Walter White, MS Dhoni, Itachi… they teach in their own voice.

⚡ **Progressive generation**: scenes 1–4 paint within seconds while Gemma writes the rest in the background — the small on-device model never feels slow.

🔁 Each message reveals on tap, scrolls into a chat feed, and the cast is locked in code so Gemma can't drift off-character.

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

## 🗺 Mastery Path — Duolingo-style spine

Type a topic → Gemma decomposes it into 5–7 progressive steps with concept tags + difficulty. Each step is one short story (~3 minutes). Tiny wins, visible progress, ticks fill in as you pass each step at ≥70% accuracy.

---

## 📸 Scan Any Textbook Page

Point your camera at a page... and magic begins ✨

📚 Detects chapter + topic
🧩 Extracts concepts
🎯 Generates the same chat-style lesson instantly
🗣 In your level + language

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
flutter pub get
flutter devices
flutter run -d <DEVICE_ID>
```

### 📱 Device Requirements

✅ Android 12+
✅ 4GB+ RAM
✅ ~3GB free storage

---

# 🎉 First Launch Experience

1️⃣ Enter name + grade + language
2️⃣ One-time Gemma model download (~2.58 GB)
3️⃣ Done forever ✅

After that:

✈ Turn on airplane mode
📴 Disconnect Wi-Fi
🌍 Go anywhere

**Learnify still works perfectly.**

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
   ├── 📖 Story            (chat-bubble lessons, franchise persona)
   ├── 🧠 Tutor            (concept explanation)
   ├── ❓ Quiz             (targeted questions, weak-area aware)
   ├── 📅 Planner          (7-day study schedule)
   ├── 🔍 Explorer         (sub-topic decomposition)
   ├── 🗺 Mastery          (5–7 step progressive paths)
   ├── 👤 Learner Twin     (Companion chat with memory)
   ├── 📷 Image Analysis   (textbook scan)
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

> **The future of education should fit in your pocket — and work anywhere.** 📱🌍✨
