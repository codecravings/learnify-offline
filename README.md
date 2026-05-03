# 🎓 Learnify — Offline AI Learning Companion 📚⚡

> **A fully on-device, multi-agent learning app powered by Gemma 4 E2B** running locally via LiteRT-LM.
> 🚫 No cloud calls
> 🚫 No API keys
> 🚫 No data leaves the device
> ✅ 100% private, fast, and offline-first

Built for the **Kaggle Gemma 4 Good Hackathon** 🌍✨ *(Future of Education)*

![flutter](https://img.shields.io/badge/flutter-3.x-blue)
![gemma](https://img.shields.io/badge/gemma-4--E2B-purple)
![offline](https://img.shields.io/badge/runtime-on--device-green)

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

## 🤖 6 AI Agents, One Brain

Powered by a single Gemma model with specialized roles:

📖 Story Agent
🧠 Tutor Agent
❓ Quiz Agent
📅 Planner Agent
🔍 Explorer Agent
👤 Learner Twin Agent
📷 Image Analysis Agent

All coordinated through one smart orchestrator.

---

## 📸 Scan Any Textbook Page

Point your camera at a page... and magic begins ✨

📚 Detects chapter + topic
🧩 Extracts concepts
🎯 Generates a personalized lesson instantly
🗣 Explains in your level + language

---

## 🎮 Story-Based Learning

Learning becomes addictive:

🎚 Choose difficulty
🎭 Choose style:

* 😂 Meme Mode
* 🛠 Practical Mode
* 🎬 Movie / TV Style

Then get:

📖 AI-generated visual story
🧠 Quiz battle
⭐ XP rewards
🏆 Stars & streaks

---

## 👤 Learner Twin (Study Companion)

Your AI study partner that remembers everything locally ❤️

Ask:

📝 What should I study next?
😵 Where am I weakest?
📈 How am I improving?
🔥 Motivate me today

---

## 🌳 Skill Tree + Knowledge Graph

Watch growth visually:

🌱 Skills unlock over time
🕸 Concept relationships shown clearly
🎯 Track mastery journey

---

## 🔒 Privacy First

No tracking. No ads. No cloud syncing. No surveillance.

Your learning belongs to **you** ❤️

---

# 🛠 Tech Stack

| Layer         | Choice                                      |
| ------------- | ------------------------------------------- |
| 🧠 Model      | `litert-community/gemma-4-E2B-it-litert-lm` |
| ⚙ Runtime     | `flutter_gemma` v0.13.5                     |
| 📱 Framework  | Flutter 3.x                                 |
| 🧭 Navigation | go_router                                   |
| 💾 Database   | SQLite                                      |
| 🎨 UI         | Dark glassmorphism + neon glow              |

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
│   ├── ai/
│   ├── db/
│   ├── services/
│   ├── theme/
│   └── widgets/
├── features/
│   ├── setup/
│   ├── story_learning/
│   ├── scan/
│   ├── companion/
│   ├── profile/
│   ├── skill_tree/
│   └── knowledge_graph/
└── routes/
```

---

# 🧠 Multi-Agent Design

One Gemma instance. Six personalities. Infinite possibilities.

```text
User → Orchestrator
   ├── Story Agent
   ├── Tutor Agent
   ├── Quiz Agent
   ├── Planner Agent
   ├── Explorer Agent
   └── Learner Twin
```

⚡ Shared weights in RAM
⚡ Ultra efficient
⚡ Add new agents with only prompts

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
