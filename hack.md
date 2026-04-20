# EduJu — AI Study Companion That Remembers You

## What It Does

EduJu is a mobile learning app where you type **any topic** and an AI generates an interactive story-based lesson with characters, dialogue, and quizzes — personalized to YOUR learning history using **Hindsight Memory**.

The AI doesn't just teach. It **remembers** what you've studied, what you got wrong, how you scored, and what level you're at. Every lesson adapts based on your past performance. The more you learn, the smarter it gets.

---

## The Problem

Students forget what they struggle with. Traditional study apps are **stateless** — every session starts from zero. The AI has no idea you bombed projectile motion last week or that you already mastered photosynthesis basics. Context windows reset, chat histories vanish, and the student is left managing their own weaknesses manually.

---

## How Hindsight Memory Solves This

Hindsight is the **brain** of EduJu — not a bolt-on, but deeply wired into every learning interaction.

### The Full Memory Loop

```
Student types "Photosynthesis"
        |
        v
   HINDSIGHT REFLECT (structured)
   "Has this student studied this before?"
        |
        v
   LEVEL SELECT SCREEN
   AI recommends: Basics / Intermediate / Advanced
   based on past quiz scores & mistakes
        |
        v
   HINDSIGHT RECALL
   Fetches: past mistakes, weak concepts, mastered areas
        |
        v
   INJECTED INTO AI PROMPT
   DeepSeek generates a PERSONALIZED story
   - More time on weak concepts
   - Skips what's already mastered
   - Quiz targets previous mistakes
        |
        v
   Student completes quiz (2/3 correct)
        |
        v
   HINDSIGHT RETAIN
   Stores: topic, level, score, missed questions,
   concepts covered, learning style used
        |
        v
   NEXT SESSION
   AI remembers EVERYTHING and adapts further
```

### Every Hindsight API Endpoint Used

| Endpoint | Where It's Used | What It Does |
|----------|----------------|--------------|
| **Retain** | After every quiz | Stores score, mistakes, concepts, level, style |
| **Retain** | Topic search | Tracks what topics student is interested in |
| **Retain** | Companion chat | Stores Q&A exchanges for cross-session context |
| **Recall** | Story generation | Fetches past learning to personalize the AI prompt |
| **Reflect** | Level assessment | AI reasons over memory to recommend difficulty |
| **Reflect** | Home dashboard | Generates personalized study recommendation |
| **Reflect** | Study Companion | Answers questions by reasoning over all memories |
| **Reflect (structured)** | Level select | Returns structured JSON: level, reason, history flag, past accuracy |
| **Reflect (structured)** | Topic retrieval | Returns list of studied topics with levels and scores |
| **Memory Banks** | Auto-created | One bank per student (`student-{uid}`) with educational mission |

### The Context Window Problem — Solved

Traditional AI chats lose context after the window fills up. EduJu solves this:

1. **Hindsight stores unlimited history** — every quiz result, every chat exchange, every topic interaction
2. **Only relevant memories surface** — when studying physics, Hindsight's multi-strategy retrieval (semantic + keyword + graph + temporal) finds only physics-related memories
3. **AI prompt stays focused** — instead of cramming 50 past sessions into context, Hindsight distills them into the key facts the AI needs
4. **Companion remembers across sessions** — ask "where am I struggling?" on Monday, get an answer informed by everything you've done since you started

---

## Features Built

### 1. Learn Anything (Enhanced)
- Type **any topic** — Photosynthesis, Blockchain, WW2, Quantum Physics, anything
- AI detects if you've studied it before via Hindsight
- Recommends Basics / Intermediate / Advanced based on your history
- You can override the AI's recommendation
- Story is generated at the chosen difficulty level

### 2. AI Level Assessment
- Before every custom topic lesson, Hindsight Reflect analyzes your memory
- Returns structured data: recommended level, reasoning, whether you have history, past accuracy %
- Shows "I REMEMBER YOU" if you've studied before, or "NEW TOPIC DETECTED" if first time
- Past accuracy displayed so you can see your own progress

### 3. Personalized Story Generation
- DeepSeek generates visual novel stories with characters teaching concepts
- **Before generation**: Hindsight Recall fetches your learning history for this topic
- History is injected directly into the AI system prompt
- AI spends more time on concepts you struggled with
- AI skips or briefly recaps concepts you already mastered
- Quiz questions target your previous weak areas
- Three learning styles: Desi Meme (Indian humor), Practical (real-world), Movie/TV (franchise characters)

### 4. AI Study Companion
- Dedicated screen powered entirely by Hindsight Reflect
- **Study Pulse**: auto-generated insight about your overall learning progress
- **4 Quick Actions**:
  - "What should I study today?" — prioritizes weak areas and unreviewed topics
  - "Quiz me on my weak spots" — generates targeted revision questions from memory
  - "Study plan for this week" — personalized schedule based on learning patterns
  - "Where am I struggling?" — pattern analysis across all past mistakes
- **Free-form chat**: ask anything about your learning, AI reasons over your full history
- Every chat exchange is **retained** back to Hindsight — companion gets smarter over time

### 5. Home Dashboard — Your Topics
- Topics you've studied appear as cards on the home page
- Each card shows: topic name, current level, star rating, accuracy %
- Tap any card to **continue learning** at the next level
- If you scored 70%+ at Basics, next session starts at Intermediate
- AI Recommendation card suggests what to study next (powered by Hindsight Reflect)

### 6. Smart Progress Tracking
- After every quiz, saved to both **Firestore** (fast UI) and **Hindsight** (AI reasoning)
- Data retained: topic, difficulty level, learning style, quiz score, missed questions, concepts covered
- Tagged in Hindsight: `topic:*`, `level:*`, `accuracy:*`, `needs_review`, `mastered`
- Builds a rich knowledge graph over time that Hindsight uses for retrieval

---

## Technical Architecture

### Stack
- **Flutter** — Cross-platform mobile app
- **Firebase** — Auth (Email + Google), Firestore (user data, progress), Cloud Functions
- **Hindsight Memory** (Vectorize) — Persistent AI memory per student
- **DeepSeek API** — Story/lesson generation (OpenAI-compatible)
- **Dio** — HTTP client for all API calls

### Key Files

| File | Purpose |
|------|---------|
| `lib/core/services/hindsight_service.dart` | Hindsight API wrapper — retain, recall, reflect, assessTopicLevel, getStudyContext, getStudiedTopics |
| `lib/features/companion/screens/study_companion_screen.dart` | AI Study Companion — chat + insights + quick actions |
| `lib/features/story_learning/screens/story_screen.dart` | 6-phase learning flow: Level → Style → Loading → Story → Quiz → Results |
| `lib/features/story_learning/services/story_generator_service.dart` | DeepSeek integration with Hindsight memory context injection |
| `lib/features/auth/screens/home_screen.dart` | Dashboard with Your Topics, AI Recommends, Learn Anything |
| `lib/routes/app_router.dart` | Navigation: Home / Companion / Profile |

### Hindsight Service Design

```dart
class HindsightService {
  // One memory bank per student
  String get _bankId => 'student-${FirebaseAuth.instance.currentUser?.uid}';

  // STORE learning events
  Future<bool> retain({content, context, tags});
  Future<bool> retainQuizResult({topic, style, score, total, missed, concepts, level});
  Future<bool> retainChatExchange({userQuery, aiResponse});
  Future<bool> retainTopicInterest(topic, {level});

  // SEARCH past memories
  Future<List<Map>> recall({query, types, budget});

  // AI REASONING over all memories
  Future<String> reflect({query, budget, maxTokens, responseSchema});
  Future<Map?> reflectStructured({query, responseSchema, budget});

  // INTELLIGENCE
  Future<String> getStudyContext(topic);           // Memory → AI prompt injection
  Future<Map> assessTopicLevel(topic);             // Structured level recommendation
  Future<List<Map>> getStudiedTopics();            // All studied topics with progress
}
```

### Data Flow: How Memory Makes AI Smarter

```
┌─────────────────────────────────────────────────────────────┐
│                    HINDSIGHT MEMORY BANK                     │
│                    (per student, unlimited)                   │
│                                                              │
│  Facts extracted:                                            │
│  - "Student scored 67% on Photosynthesis basics"            │
│  - "Student struggles with light-dependent reactions"        │
│  - "Student mastered chloroplast structure"                  │
│  - "Student prefers Desi Meme learning style"               │
│  - "Student asked about study plan for biology exam"        │
│                                                              │
│  Knowledge graph:                                            │
│  Student ──studies──> Photosynthesis                         │
│  Student ──weak_at──> Light Reactions                        │
│  Student ──mastered──> Chloroplast Structure                 │
│  Photosynthesis ──part_of──> Biology                        │
└─────────────┬───────────────────────────┬───────────────────┘
              │                           │
      RECALL (search)              REFLECT (reason)
              │                           │
              v                           v
   ┌─────────────────┐      ┌──────────────────────┐
   │ Story Generator  │      │ Study Companion       │
   │ "Spend more time │      │ "You struggle with    │
   │  on light rxns,  │      │  light reactions.     │
   │  skip chloroplast│      │  Study that before    │
   │  basics"         │      │  your exam."          │
   └─────────────────┘      └──────────────────────┘
```

---

## What Makes This Different

1. **Memory is in the loop, not beside it** — Hindsight doesn't just store data for display. It actively feeds into the AI that generates lessons. The story you get is different because of your history.

2. **Solves context window limits** — Traditional AI forgets after each session. Hindsight stores unlimited history and surfaces only what's relevant. Ask "where am I weak?" after 50 sessions and it still knows.

3. **Structured + unstructured** — We use both `reflect` (free-form reasoning) and `reflectStructured` (JSON schema output) depending on the use case. Level assessment needs structured data. Study pulse needs natural language.

4. **Progressive difficulty** — The app tracks your level per topic and suggests when you're ready to advance. Score 70%+ at Basics → AI recommends Intermediate next time.

5. **Every interaction builds memory** — Quizzes, topic searches, companion chats — all retained. The knowledge graph grows with every session.

---

## Navigation

| Tab | Screen | Hindsight Usage |
|-----|--------|----------------|
| Home | Dashboard — Learn Anything search, Your Topics cards, AI Recommends, Streak/Stats | Reflect (recommendation), Firestore (topic cards) |
| Companion | AI Study Companion — Study Pulse, Quick Actions, Chat | Reflect (all queries), Retain (chat exchanges) |
| Profile | User stats, XP, achievements | — |

---

## Built With
- Flutter 3.11+ / Dart 3.11+
- Firebase (Auth, Firestore, Cloud Functions)
- Hindsight Memory by Vectorize (Retain, Recall, Reflect APIs)
- DeepSeek API (story generation)
- Dio (HTTP)
- Go Router (navigation)
- Google Fonts (Orbitron + Space Grotesk)
- Dark glassmorphism UI theme
