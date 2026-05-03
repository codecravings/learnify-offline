# 🎓 Learnify — Feature Tour

> **A fully on-device AI learning companion. No cloud. No accounts. No internet after install.**
> Everything below runs locally on your phone, powered by Gemma 4 E2B via LiteRT-LM.

---

## 🧠 The Brain — One Gemma model, seven specialized agents

One ~2.58 GB Gemma 4 E2B model, loaded once. Seven different "personalities" emerge depending on which system prompt is applied:

| Agent | What it does |
|---|---|
| 📖 **Story Agent** | Writes visual-novel lessons where 2–4 characters teach via dialogue |
| 🧠 **Tutor Agent** | Plain-language concept explanations adapted to your level |
| ❓ **Quiz Agent** | Generates targeted questions, auto-injects your past weak spots |
| 🗺️ **Mastery Agent** | Decomposes any topic into 5–7 progressive learning steps |
| 🔍 **Explorer Agent** | Breaks topics into bite-sized sub-topics |
| 📅 **Planner Agent** | Builds 7-day study plans from your learning history |
| 👤 **Learner Twin** | Your AI study buddy — answers "what should I study?", "where am I weak?", remembers prior chats |
| 📷 **Image Analysis** | Reads textbook photos and extracts the topic + concepts |

> 💡 **Why this matters**: shared model weights mean adding a new agent costs ~zero extra RAM. The on-device footprint stays small even as the app grows.

---

## 📚 1. Story-Based Learning — the core loop

Type any topic. Gemma writes a short visual-novel where characters teach the concept through dialogue.

**Example flow:**

```
You type: "Photosynthesis"
   ↓
Pick difficulty: Basics / Intermediate / Advanced
   ↓
Pick style:
   😂 Desi Meme   — Hinglish, cricket + Bollywood analogies
   🛠 Practical   — Real-world applications, every concept tied to daily life
   🎬 Movie/TV    — Pick a franchise (e.g. "Avengers"), characters teach in their voice
   ↓
🤖 Gemma writes a 5–8 scene story locally on your phone
   ↓
🎮 Quiz: 3 questions, 4 options each
   ↓
⭐ Results: 1–3 stars, +35–50 XP, saved to your library
```

Every concept appears in at least one scene with a real-world example. Quizzes target what you got wrong before — so the more you study, the smarter the questions get.

---

## 🗺️ 2. Mastery Path — Duolingo for any topic

This is the **spine** of the app. Type any topic, tap "Build mastery path instead →", and Gemma decomposes it into 5–7 progressive steps.

**Example — "Photosynthesis" path:**

```
✅ Step 1: What is photosynthesis            [basics]
✅ Step 2: Where it happens — chloroplasts   [basics]
🔵 Step 3: Light reactions                    [intermediate]    ← you are here
⚪ Step 4: Calvin cycle                        [intermediate]
⚪ Step 5: Why plants matter for life on Earth [advanced]

Progress: 2/5 mastered • ~45 min estimated
```

- 🟢 Filled green check = mastered (passed the quiz at ≥70%)
- 🔵 Pulsing cyan = your current step
- ⚪ Locked outline = future step

Tap the current step → it launches a story focused on just that step. Pass the quiz → step ✓ ticks → next step pulses. Every path is per-topic and per-profile, stored locally forever.

> 💡 **The addiction loop**: tiny daily wins, visible progress, "Path Complete" celebration. Your kid finishes a step, sees stars, sees the path fill in, wants to do the next one.

---

## 👤 3. Study Companion — Learner Twin chat

Streaming chat with an AI that **remembers everything you've studied**.

**Example conversation (across two sessions):**

**Monday:**
> 👤 You: What should I study next?
> 🤖 Twin: You're 80% on Cells but only 45% on Mitochondria — and you missed "ATP synthesis" twice. Recap that, then move to Photosynthesis. They share the same energy framework.

**Wednesday (you closed the app, came back):**
> 👤 You: How am I doing?
> 🤖 Twin: Better — you fixed the ATP gap on Tuesday and pushed Photosynthesis to intermediate. Calvin cycle is your weakest piece in that chain. Want me to plan a 30-min recap?

The Companion now **compounds across sessions** — every chat exchange is saved to SQLite and the last 8 turns are injected into the next prompt. No more "starting cold every time".

The top **Study Pulse card** also surfaces your active mastery path: *"4/6 · Photosynthesis · Next: Calvin cycle"* — tap to jump straight back.

---

## 😊 4. Mood Check-in — emotionally aware tutoring

Once per day, the home dashboard shows:

```
HOW ARE YOU FEELING?
🧘 Calm     ⚡ Hyped     🔍 Curious     😰 Anxious     💙 Low
```

Whatever you pick gets quietly threaded into every Gemma prompt that day:

| Mood | The lessons feel like |
|---|---|
| 🧘 **Calm** | Measured, thoughtful pacing. Time taken with explanations. |
| ⚡ **Hyped** | Punchy sentences, exclamations, fast pacing, fun analogies. |
| 🔍 **Curious** | "What if" tangents, surprising connections, rabbit-hole asides. |
| 😰 **Anxious** | Reassuring, slow, tiny steps, no scary jargon. |
| 💙 **Low** | Warm, kind, gently encouraging, celebrates small wins. |

The app **never tells the model your mood out loud** — only adjusts the writing voice. The student just feels like the lesson "gets" them today.

---

## 📷 5. Scan Any Textbook Page

Point your camera at any textbook page. Gemma's multimodal pass extracts:

- 📚 The topic
- 🧩 Key concepts visible
- 🎯 Suggested difficulty level

…then immediately generates a personalized story lesson on it. Ideal for kids who don't know what to ask — they just photograph what's in front of them.

---

## 🎬 6. Franchise Lab — story lessons in your favorite character's voice

A separate, opt-in subapp (`flutter run -t lib/franchise_lab/main.dart`) that goes deeper into franchise-driven learning. **80 franchises × 6 characters each × 5 sample dialogues** loaded from a local JSON file.

**Categories:** 🍙 Anime · 📺 Cartoons · 🎬 Movies · 📡 Live-action TV · 🇮🇳 Indian · 🎮 Gaming · 🇰🇷 K-drama

**The flow:**

```
1. Type topic + difficulty
2. (optional) Pick today's mood → "BEST FOR YOUR MOOD" suggests franchises that match your vibe
3. Browse 80 franchises → pick one
4. Pick a sub-topic from auto-generated breakdown
5. Watch the story unfold — characters speak in their authentic voice
   (Gemma is fed each character's speechStyle / humorStyle / emotionalStyle)
6. Quiz → results → ⭐⭐⭐
```

> 💡 **Mood-aware routing example**: pick "anxious" → the picker surfaces franchises with warm, gentle, supportive characters. Pick "hyped" → loud, fiery, over-the-top characters jump to the top.

---

## 🖼️ 7. Comic Album — your lessons as 4-panel manga

After every Lab story, tap **"SAVE AS COMIC"**. The app picks the 4 most representative scenes and renders them as a manga-style 2×2 grid:

```
┌──────────────────┐ ┌──────────────────┐
│ NARUTO           │ │ HINATA           │
│                  │ │                  │
│   Plants are     │ │   Like a ninja   │
│   like ninjas!   │ │   gathering      │
│                  │ │   chakra…        │
└──────────────────┘ └──────────────────┘
┌──────────────────┐ ┌──────────────────┐
│ SAKURA           │ │ KAKASHI          │
│                  │ │                  │
│   Sun = chakra   │ │   Got it. Tea    │
│   for plants!    │ │   from sunlight. │
└──────────────────┘ └──────────────────┘
```

Each panel has a character-tinted background, a name plate, an emotion pill, and a comic-style speech bubble with a tail — all rendered in pure Flutter (no SVG, no image generation, instant).

**Built-in album** (Profile tab → Comic Album) shows every comic you've saved as a thumbnail grid. Tap to view fullscreen. Long-press to delete.

> 💡 **Why this matters**: kids accumulate a *visible artifact* of weeks of learning. Print one, stick it on your wall, swap with a friend. Bridges digital → physical.

---

## 🧑‍🏫 8. Feynman Mode — "Teach Naruto"

Locked until you **master** a topic (≥70% accuracy at intermediate or higher difficulty using a franchise). Then the results screen unlocks:

> 🟣 **TEACH NARUTO** — Role reversal — explain it back to them.

The role flips. The franchise character becomes your confused junior student. You teach them.

**Example session — teaching Naruto about photosynthesis:**

```
🍥 Naruto: "Wait wait wait — sun makes plants grow? Like, how?
           Believe it! But seriously, I don't get the chakra part."

👤 You: "Plants take light from the sun and use it like fuel.
        They make their own food using the chloroplasts inside their cells."

🍥 Naruto: "Okay so the chloroplasts are like little ramen pots
           cooking sunlight? And the food is what?"

👤 You: "Glucose — sugar. They use it to grow, and they release oxygen
        as a side effect. That's what we breathe."

🍥 Naruto: "WAIT. So plants literally feed the whole planet AND
           give us air?! That's stronger than the Nine-Tails!
           Photosynthesis = ramen for the whole world. I get it now!"
```

Three exchanges. Then ⭐⭐⭐, +60 XP, persisted to memory so the Companion sees "you taught Photosynthesis to Naruto" next session.

> 💡 **Why this works**: Feynman technique is the single most respected learning method in education research — explaining a concept to someone else proves you understand it. Wrapping it in a franchise persona makes a kid actually *want* to do it.

---

## ♿ 9. Accessibility Skin — opt-in, zero footprint when off

Two independent toggles in **Profile → Settings**, both **default OFF**:

### 🔤 Dyslexia-friendly mode

- **Atkinson Hyperlegible font** — designed by the Braille Institute for low-vision and dyslexic readers. Replaces Orbitron + Space Grotesk everywhere.
- **Bionic Reading** — bolds the **fir**st **40%** of **eve**ry **wor**d so the eye anchors on the strong cue. Used in story dialogue, Companion replies, mastery-path step descriptions.
- **Looser line-height + letter-spacing** for easier tracking.
- **Simpler prompts** — when this toggle is on, every Gemma prompt gains a fragment instructing "max 12-word sentences, common words, dialogue ≤ 15 words". The model produces naturally simpler text.

### 🔊 Read aloud (TTS)

- **Lazy-loaded** — the text-to-speech engine never initializes until you tap your first 🔊 button.
- **Karaoke highlight** — as the device speaks, the current word lights up cyan in real time.
- **Three-tier fallback** — tries your language first, falls back to device default, surfaces a friendly error if no TTS pack is installed (with a hint to install one from system Settings).
- Available everywhere there's narrative text — primarily story scenes.

> 💡 **The good thing**: visually-impaired and pre-literate kids unlock the entire app. A hackathon judge with no language pack on their device gets a clean error, not a crash.

---

## 🧬 10. Knowledge Graph + Skill Tree

Two visualizations of what you've learned:

- **🕸 Knowledge Graph** (`/concept-map`) — nodes for studied topics, edges for AI-inferred prerequisites. Pulls from your real DB — not a static curriculum.
- **🌳 Skill Tree** (`/skill-tree`) — 2D layout of all topics grouped by subject. Mastered nodes glow green, in-progress nodes pulse cyan, locked nodes are dim until you unlock the prerequisite.

Both are **fully data-driven** — start with empty graphs that fill in as you learn.

---

## 🔒 11. Privacy & Storage

| What | Where it lives | Leaves your device? |
|---|---|---|
| Profile (name, language, grade) | SQLite on your phone | ❌ Never |
| Study history (topics, quizzes) | SQLite | ❌ Never |
| Mastery paths | SQLite | ❌ Never |
| Mood entries | SQLite | ❌ Never |
| Chat history with Companion | SQLite | ❌ Never |
| Comic Album | SQLite | ❌ Never |
| Feynman sessions | SQLite | ❌ Never |
| Gemma model file | App-internal storage | ❌ Never |

**One-time download:** ~2.58 GB Gemma model from Hugging Face on first install (or sideload via adb — no token needed). After that, *zero network calls*. Airplane mode works perfectly.

No accounts. No login. No analytics. No tracking. No ads. Multiple profiles supported on the same device, each isolated.

---

## 🎯 12. Why this matters — the social mission

Most AI education apps fail exactly where learning matters most:

- 📶 Rural schools with weak signals
- 🚫 Campuses with blocked Wi-Fi
- 📱 Students surviving on 2G
- 🚌 Long bus commutes
- 🏝 Remote villages
- 🔌 Places with daily power cuts

Once installed, **Learnify works forever offline.** A child in a village deserves the same AI tutor as a kid in a smart city. This app is built so they can have it.

---

## 🏆 Built for

**Kaggle Gemma 4 Good Hackathon**
Theme: *Future of Education*

> *The future of education should fit in your pocket — and work anywhere.* 📱🌍✨
