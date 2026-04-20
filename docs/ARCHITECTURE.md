# VidyaSetu - System Architecture

> **VidyaSetu** (Knowledge Bridge) - A gamified, AI-powered competitive learning platform that transforms education into an engaging battle arena.

---

## System Overview

```
+------------------------------------------------------------------+
|                        CLIENT LAYER                               |
|                                                                   |
|   +---------------------------+  +----------------------------+   |
|   |    Flutter Mobile App     |  |    Flutter Web App          |   |
|   |   (iOS / Android / Web)   |  |   (Progressive Web App)    |   |
|   +------------+--------------+  +-------------+--------------+   |
|                |                               |                  |
+----------------|-------------------------------|------------------+
                 |                               |
                 v                               v
+------------------------------------------------------------------+
|                     FIREBASE PLATFORM                             |
|                                                                   |
|  +-------------------+  +------------------+  +----------------+  |
|  | Firebase Auth      |  | Cloud Firestore  |  | Cloud Storage  |  |
|  | - Email/Password   |  | - Users          |  | - Avatars      |  |
|  | - Google Sign-In   |  | - Battles        |  | - Challenge    |  |
|  | - Anonymous        |  | - Challenges     |  |   Assets       |  |
|  +-------------------+  | - Forum Posts     |  +----------------+  |
|                         | - Leaderboards    |                     |
|  +-------------------+  | - Achievements    |  +----------------+  |
|  | Firebase Analytics |  | - Learning Paths |  | Cloud Messaging|  |
|  | - User Engagement  |  | - Daily Challs.  |  | - Battle Invs. |  |
|  | - Battle Metrics   |  +------------------+  | - Achievements |  |
|  +-------------------+                         +----------------+  |
|                                                                   |
+----------------------------+--------------------------------------+
                             |
                             v
+------------------------------------------------------------------+
|                   CLOUD FUNCTIONS LAYER                           |
|                                                                   |
|  +---------------------+  +--------------------+                  |
|  | Battle Engine        |  | Matchmaking        |                 |
|  | - onBattleCreated    |  | - Skill-based      |                 |
|  | - onAnswerSubmitted  |  |   pairing           |                |
|  | - calculateResult    |  | - Queue management  |                |
|  +---------------------+  +--------------------+                  |
|                                                                   |
|  +---------------------+  +--------------------+                  |
|  | Scheduled Jobs       |  | XP & League Engine |                 |
|  | - updateLeaderboards |  | - onUserXPChanged  |                 |
|  | - generateDaily      |  | - Achievement check|                 |
|  |   Challenge          |  | - Rank promotions  |                 |
|  +---------------------+  +--------------------+                  |
|                                                                   |
+----------------------------+--------------------------------------+
                             |
                             v
+------------------------------------------------------------------+
|                    AI / EXTERNAL APIs                             |
|                                                                   |
|  +---------------------+  +--------------------+                  |
|  | Gemini API           |  | OpenAI API         |                 |
|  | - Challenge Gen      |  | - Fallback LLM     |                |
|  | - Hint Generation    |  | - Answer Eval      |                |
|  | - Answer Evaluation  |  +--------------------+                 |
|  | - Scenario Battles   |                                         |
|  +---------------------+  +--------------------+                  |
|                            | Judge0 API         |                 |
|  +---------------------+  | - Code Execution   |                 |
|  | Custom ML Models     |  | - Test Case Runner |                |
|  | - Difficulty Tuning  |  +--------------------+                 |
|  | - Skill Assessment   |                                         |
|  +---------------------+                                          |
|                                                                   |
+------------------------------------------------------------------+
```

---

## Database Schema (High-Level)

### Collections Overview

```
firestore/
  |
  +-- users/                    # Player profiles, XP, stats
  |     +-- {userId}/
  |           +-- achievements/  # Subcollection: unlocked achievements
  |
  +-- battles/                  # Real-time battle state
  +-- challenges/               # Community & AI-generated challenges
  +-- forum_posts/              # Discussion forum
  |     +-- {postId}/
  |           +-- solutions/    # Subcollection: solution attempts
  |
  +-- leaderboards/             # Pre-computed ranking tables
  +-- achievements/             # Global achievement definitions
  +-- learning_paths/           # Structured learning curricula
  +-- daily_challenges/         # Daily rotating challenges
  +-- matchmaking_queue/        # Temporary matchmaking state
```

### Key Document Structures

| Collection | Key Fields | Purpose |
|---|---|---|
| `users` | xp, league, skillRating, stats, categoryXP | Player profile & progression |
| `battles` | players[], status, answers, roundResults, winnerId | Battle state machine |
| `challenges` | type, difficulty, prompt, hints[], correctAnswer | Problem bank |
| `forum_posts` | title, body, tags[], votes, authorId | Community forum |
| `leaderboards` | category, timeframe, rankings[] | Pre-computed leaderboards |
| `daily_challenges` | date, category, challenge, xpReward | Daily engagement hook |

---

## API Endpoints

### Cloud Functions (Callable)

| Function | Trigger | Description |
|---|---|---|
| `matchmaking` | HTTPS Callable | Finds opponent with similar skill rating |
| `calculateBattleResult` | HTTPS Callable | Force-calculates battle result |

### Cloud Functions (Event-Driven)

| Function | Trigger | Description |
|---|---|---|
| `onBattleCreated` | Firestore onCreate | Initializes battle timer & state |
| `onBattleAnswerSubmitted` | Firestore onUpdate | Processes answers, advances rounds |
| `onUserXPChanged` | Firestore onUpdate | League promotions & achievements |

### Cloud Functions (Scheduled)

| Function | Schedule | Description |
|---|---|---|
| `updateLeaderboards` | Every 1 hour | Recalculates all leaderboard rankings |
| `generateDailyChallenge` | Daily at 00:00 UTC | Creates new daily challenge |

---

## Battle Flow Sequence

```
 Player A                   Firebase                    Player B
    |                          |                           |
    |--- matchmaking() ------->|                           |
    |                          |<----- matchmaking() ------|
    |                          |                           |
    |                    [Match Found]                     |
    |                    [Create Battle Doc]               |
    |                          |                           |
    |<-- onBattleCreated ----->|                           |
    |    (timer started)       |                           |
    |                          |                           |
    |===== ROUND 1 ==========================================|
    |                          |                           |
    |--- submit answer ------->|                           |
    |                          |<----- submit answer ------|
    |                          |                           |
    |              [onBattleAnswerSubmitted]                |
    |              [Both answered -> evaluate]              |
    |              [Advance to Round 2]                     |
    |                          |                           |
    |===== ROUND 2 ==========================================|
    |                          |                           |
    |--- submit answer ------->|                           |
    |                          |<----- submit answer ------|
    |                          |                           |
    |              [onBattleAnswerSubmitted]                |
    |              [Both answered -> evaluate]              |
    |              [Advance to Round 3]                     |
    |                          |                           |
    |===== ROUND 3 (FINAL) ====================================|
    |                          |                           |
    |--- submit answer ------->|                           |
    |                          |<----- submit answer ------|
    |                          |                           |
    |           [calculateBattleResultInternal]             |
    |           [Compare scores across all rounds]          |
    |           [Award XP -> triggers onUserXPChanged]      |
    |           [Update stats, streaks, achievements]       |
    |                          |                           |
    |<-- result notification -->|<-- result notification -->|
    |                          |                           |
```

---

## AI Integration Flow

```
+-------------------+         +------------------+        +----------------+
|   Flutter Client  | ------> | Cloud Functions  | -----> |  Gemini API    |
|                   |         |                  |        |                |
|  User requests    |         | 1. Validate req  |        | Generate:      |
|  a challenge      |         | 2. Build prompt  |        | - Problem text |
|                   |         |    from template  |        | - Test cases   |
|                   |         | 3. Call AI API   |        | - Hints (3)    |
|                   |         | 4. Parse response|        | - Solution     |
|                   |  <----- | 5. Store in      | <----- |                |
|  Display to user  |         |    Firestore     |        |                |
+-------------------+         +------------------+        +----------------+
                                      |
                                      v
                              +------------------+
                              | Answer Eval Flow |
                              |                  |
                              | 1. User submits  |
                              | 2. Compare with  |
                              |    correct answer|
                              | 3. If ambiguous, |
                              |    call AI eval  |
                              | 4. Score & XP    |
                              +------------------+
```

### AI Prompt Strategy

| Use Case | Model | Latency Target |
|---|---|---|
| Challenge Generation | Gemini 1.5 Pro | < 3s |
| Hint Generation | Gemini 1.5 Flash | < 1s |
| Answer Evaluation | Gemini 1.5 Flash | < 1.5s |
| Scenario Battles | Gemini 1.5 Pro | < 4s |
| Forum Suggestions | Gemini 1.5 Flash | < 2s |
| Code Execution | Judge0 API | < 5s |

---

## Folder Structure

```
eduju/
|
+-- android/                    # Android platform files
+-- ios/                        # iOS platform files
+-- web/                        # Web platform files
|
+-- lib/                        # Flutter application source
|   +-- main.dart               # App entry point
|   +-- app/
|   |   +-- app.dart            # MaterialApp configuration
|   |   +-- routes.dart         # Route definitions
|   |   +-- theme.dart          # VidyaSetu design system
|   |
|   +-- core/
|   |   +-- constants/          # App-wide constants
|   |   +-- utils/              # Helper utilities
|   |   +-- errors/             # Custom exceptions
|   |   +-- network/            # API client wrappers
|   |
|   +-- features/
|   |   +-- auth/               # Authentication flow
|   |   |   +-- data/           # Repos, data sources
|   |   |   +-- domain/         # Entities, use cases
|   |   |   +-- presentation/   # Screens, widgets, state
|   |   |
|   |   +-- battles/            # Real-time battles
|   |   |   +-- data/
|   |   |   +-- domain/
|   |   |   +-- presentation/
|   |   |
|   |   +-- challenges/         # Challenge browsing & solving
|   |   +-- forum/              # Community forum
|   |   +-- leaderboard/        # Rankings & leagues
|   |   +-- profile/            # User profile & stats
|   |   +-- daily_challenge/    # Daily challenge feature
|   |   +-- learning_paths/     # Guided learning paths
|   |
|   +-- models/                 # Shared data models
|   +-- services/               # Firebase & API services
|   +-- widgets/                # Reusable UI components
|
+-- functions/                  # Firebase Cloud Functions
|   +-- src/
|   |   +-- index.ts            # All function exports
|   +-- package.json
|   +-- tsconfig.json
|
+-- docs/                       # Documentation
|   +-- ARCHITECTURE.md         # This file
|   +-- DATABASE_SCHEMA.md      # Detailed Firestore schema
|   +-- API_PROMPTS.md          # AI prompt templates
|
+-- firestore.rules             # Security rules
+-- firestore.indexes.json      # Composite index definitions
+-- firebase.json               # Firebase project config
+-- pubspec.yaml                # Flutter dependencies
+-- analysis_options.yaml       # Dart linter config
+-- README.md                   # Project overview
```

---

## Tech Stack Summary

| Layer | Technology | Purpose |
|---|---|---|
| **Frontend** | Flutter 3.x + Dart | Cross-platform UI (iOS, Android, Web) |
| **State Management** | Riverpod 2.x | Reactive state with code generation |
| **Architecture** | Clean Architecture | Feature-first, testable, scalable |
| **Backend** | Firebase (BaaS) | Auth, database, storage, functions |
| **Database** | Cloud Firestore | NoSQL, real-time sync, offline-first |
| **Auth** | Firebase Auth | Email, Google, anonymous sign-in |
| **Functions** | Cloud Functions (TS) | Server-side logic, scheduled jobs |
| **AI Engine** | Gemini 1.5 Pro/Flash | Challenge gen, hints, evaluation |
| **Code Execution** | Judge0 API | Sandboxed code execution |
| **Push Notifications** | Firebase Cloud Messaging | Battle invites, achievements |
| **Analytics** | Firebase Analytics | Engagement tracking, funnel analysis |
| **CI/CD** | GitHub Actions | Automated build, test, deploy |

---

## Security Model

- **Authentication**: Firebase Auth with email/password and Google Sign-In
- **Authorization**: Firestore Security Rules enforce row-level access
- **Admin Operations**: Cloud Functions use Admin SDK (bypasses rules)
- **Data Validation**: Both client-side (Dart models) and server-side (rules)
- **Rate Limiting**: Firebase App Check + function-level throttling
- **Code Execution**: Sandboxed via Judge0 (no direct server access)

---

## Scalability Considerations

| Concern | Solution |
|---|---|
| Real-time battles | Firestore real-time listeners with optimistic UI |
| Leaderboard reads | Pre-computed hourly, cached on client |
| AI API costs | Gemini Flash for low-latency, Pro only for generation |
| Matchmaking at scale | Queue-based with skill tolerance bands |
| Offline support | Firestore offline persistence + sync on reconnect |
| Cold starts | Functions warm-up via min instances (production) |

---

*VidyaSetu - Bridging the gap between learning and competition.*
