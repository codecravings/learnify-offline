# Learnify — Offline AI Learning Companion

> A fully on-device, multi-agent learning app powered by **Gemma 4 E2B** running
> locally via LiteRT-LM. Zero cloud calls. Zero API keys. Zero data leaves the
> device. Built for the **Kaggle Gemma 4 Good Hackathon** (Future of Education).

![flutter](https://img.shields.io/badge/flutter-3.x-blue)
![gemma](https://img.shields.io/badge/gemma-4--E4B-purple)
![offline](https://img.shields.io/badge/runtime-on--device-green)

## Why

Every other "AI for education" app on the planet calls OpenAI / Claude / Gemini
over the network. That breaks in the exact places education needs to work:
rural classrooms, boarding schools with blocked Wi-Fi, phones on 2G data plans,
the back of a bus, an island, a basement. Learnify runs the model *on the
phone*. Once it's installed, the app never touches the internet again.

## What's inside

- **7 specialized agents** sharing one Gemma 4 E2B instance (Story, Tutor, Quiz,
  Planner, Explorer, Learner Twin, Teacher, Image Analysis) — routed via
  system prompts through a single orchestrator
- **Multimodal scanning** — point the camera at any textbook page, Gemma
  detects the topic + concepts and generates a personalized lesson
- **Story-based learning** — 6-phase flow: level select → style select
  (Desi Meme / Practical / Movie-TV) → AI-generated visual novel → quiz →
  XP + stars
- **Learner Twin (Study Companion)** — persistent chat with memory of every
  past lesson; answers "what should I study?", "where am I struggling?"
- **Teacher Copilot** — class-wide dashboard. Aggregates all local student
  profiles. One tap: lesson plan, worksheet, struggling-students report
- **Skill Tree + Knowledge Graph** — visual progress across topics
- **Local-first everything** — SQLite for persistence, `ChangeNotifier` for
  state. No Firebase, no Firestore, no Auth, no network calls after bootstrap

## Tech

| Layer           | Choice                                        |
|-----------------|-----------------------------------------------|
| Model           | `litert-community/gemma-4-E4B-it-litert-lm`   |
| Runtime         | `flutter_gemma` v0.13.5 (LiteRT-LM)           |
| Framework       | Flutter 3.x                                   |
| Navigation      | go_router (ShellRoute 3-tab bottom nav)       |
| Persistence     | sqflite (SQLite)                              |
| Theme           | Dark glassmorphism + neon accents             |

## Build & run

```bash
# Deps
flutter pub get

# Connect an Android phone (Android 12+, ≥6 GB RAM, ~5 GB free)
flutter devices

# Run
flutter run -d <DEVICE_ID>
```

### First launch

1. Setup screen asks for name + grade + language
2. Model download screen pulls Gemma 4 E2B (~2.5 GB, one-time)
3. App becomes permanently offline

### Want to test in airplane mode?

Yes — do it. That's the pitch. After the one-time download, toggle airplane
mode. Every feature still works.

## Architecture

```
lib/
├── core/
│   ├── ai/          # GemmaService, AgentPrompts, GemmaOrchestrator (multi-agent)
│   ├── db/          # AppDatabase (SQLite schema)
│   ├── services/    # LocalProfileService, LocalMemoryService
│   ├── theme/       # AppTheme, ThemeProvider
│   └── widgets/     # GlassContainer, NeonButton, ParticleBackground
├── features/
│   ├── auth/        # Shell (3-tab bottom nav)
│   ├── setup/       # Profile setup + model download
│   ├── story_learning/   # 6-phase lesson flow
│   ├── courses/     # Physics, Math, DSA, Coding Arena
│   ├── scan/        # Multimodal textbook scanner
│   ├── companion/   # Learner Twin chat
│   ├── teacher/     # Teacher Copilot dashboard
│   ├── profile/     # Profile + stats + settings
│   ├── achievements/# Dynamic achievements
│   ├── skill_tree/  # Bezier-curve progress graph
│   └── knowledge_graph/  # Concept map explorer
└── routes/
    └── app_router.dart
```

## Multi-agent design

One Gemma instance. Seven agents. Each agent is just a different system prompt
injected at chat creation time. The orchestrator routes intent → agent.

```
User ──► GemmaOrchestrator
              ├── generateStory()        → Story agent
              ├── analyzeTextbookImage() → Image agent (multimodal)
              ├── exploreTopic()         → Explorer agent
              ├── queryLearnerTwin()     → Learner Twin agent
              ├── teacherQuery()         → Teacher agent
              ├── assessTopicLevel()     → Planner agent
              └── getStudyPulse()        → Planner agent
```

All seven agents share the same model weights in RAM. The "cost" of adding a
new agent is a ~200-token system prompt.

## License

Built on Gemma, subject to the
[Gemma Terms of Use](https://ai.google.dev/gemma/terms).
