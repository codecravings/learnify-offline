# VidyaSetu - Firestore Database Schema

> Complete schema reference for all Firestore collections, fields, indexes, and example documents.

---

## Table of Contents

1. [users](#1-users)
2. [battles](#2-battles)
3. [challenges](#3-challenges)
4. [forum_posts](#4-forum_posts)
5. [leaderboards](#5-leaderboards)
6. [achievements](#6-achievements)
7. [learning_paths](#7-learning_paths)
8. [daily_challenges](#8-daily_challenges)
9. [matchmaking_queue](#9-matchmaking_queue)
10. [Indexes](#10-composite-indexes)

---

## 1. users

**Path**: `/users/{userId}`

Player profiles containing XP, league, stats, and preferences.

| Field | Type | Description |
|---|---|---|
| `uid` | `string` | Firebase Auth UID (same as doc ID) |
| `displayName` | `string` | Public display name |
| `email` | `string` | Email address |
| `avatarUrl` | `string \| null` | Profile picture URL |
| `bio` | `string` | Short bio (max 160 chars) |
| `xp` | `number` | Total experience points |
| `league` | `string` | Current league: `bronze`, `silver`, `gold`, `platinum`, `diamond`, `master`, `grandmaster` |
| `leagueIcon` | `string` | Asset name for league badge |
| `skillRating` | `number` | ELO-style skill rating (default 1000) |
| `categoryXP` | `map` | XP breakdown by category |
| `categoryXP.logic` | `number` | Logic challenge XP |
| `categoryXP.coding` | `number` | Coding challenge XP |
| `categoryXP.reasoning` | `number` | Reasoning challenge XP |
| `categoryXP.cybersecurity` | `number` | Cybersecurity challenge XP |
| `categoryXP.math` | `number` | Math challenge XP |
| `stats` | `map` | Aggregated statistics |
| `stats.battlesPlayed` | `number` | Total battles played |
| `stats.battlesWon` | `number` | Total battles won |
| `stats.challengesSolved` | `number` | Total challenges solved |
| `stats.currentStreak` | `number` | Current daily streak |
| `stats.longestStreak` | `number` | Best daily streak |
| `stats.achievementsUnlocked` | `number` | Achievement count |
| `stats.forumPosts` | `number` | Forum contributions |
| `preferences` | `map` | User settings |
| `preferences.theme` | `string` | `light` or `dark` |
| `preferences.language` | `string` | Preferred language code |
| `preferences.notifications` | `boolean` | Push notification opt-in |
| `role` | `string` | `user` or `admin` |
| `createdAt` | `timestamp` | Account creation time |
| `lastActiveAt` | `timestamp` | Last app open time |
| `leaguePromotedAt` | `timestamp \| null` | Last league promotion |

### Subcollection: `users/{userId}/achievements`

| Field | Type | Description |
|---|---|---|
| `id` | `string` | Achievement identifier |
| `title` | `string` | Display title |
| `xp` | `number` | Bonus XP awarded |
| `triggerType` | `string` | What triggered it |
| `unlockedAt` | `timestamp` | When it was earned |

### Example Document

```json
{
  "uid": "abc123",
  "displayName": "CodeWarrior42",
  "email": "warrior@example.com",
  "avatarUrl": "https://storage.googleapis.com/vidyasetu/avatars/abc123.png",
  "bio": "Logic puzzle enthusiast. Diamond league grinder.",
  "xp": 7850,
  "league": "diamond",
  "leagueIcon": "diamond_shield",
  "skillRating": 1340,
  "categoryXP": {
    "logic": 2800,
    "coding": 1900,
    "reasoning": 1500,
    "cybersecurity": 850,
    "math": 800
  },
  "stats": {
    "battlesPlayed": 94,
    "battlesWon": 61,
    "challengesSolved": 215,
    "currentStreak": 12,
    "longestStreak": 23,
    "achievementsUnlocked": 18,
    "forumPosts": 7
  },
  "preferences": {
    "theme": "dark",
    "language": "en",
    "notifications": true
  },
  "role": "user",
  "createdAt": "2025-09-15T08:30:00Z",
  "lastActiveAt": "2026-03-15T14:22:00Z",
  "leaguePromotedAt": "2026-02-28T10:15:00Z"
}
```

---

## 2. battles

**Path**: `/battles/{battleId}`

Real-time battle state machine. Each document tracks a complete multi-round battle.

| Field | Type | Description |
|---|---|---|
| `players` | `array<string>` | User IDs of participants (2 players) |
| `playerProfiles` | `map` | Cached display info per player |
| `playerProfiles.{uid}.displayName` | `string` | Player name |
| `playerProfiles.{uid}.avatarUrl` | `string \| null` | Avatar |
| `playerProfiles.{uid}.skillRating` | `number` | Skill at battle start |
| `playerProfiles.{uid}.league` | `string` | League at battle start |
| `category` | `string` | Challenge category |
| `difficulty` | `string` | `easy`, `medium`, or `hard` |
| `status` | `string` | `created`, `active`, `completed`, `cancelled` |
| `totalRounds` | `number` | Number of rounds (default 3) |
| `currentRound` | `number` | Current round number |
| `timeLimitSeconds` | `number` | Per-round time limit |
| `challenges` | `map` | Challenge data per round |
| `challenges.round_{n}` | `map` | Challenge for round n |
| `challenges.round_{n}.prompt` | `string` | Problem statement |
| `challenges.round_{n}.options` | `array<string>` | Multiple choice options (if applicable) |
| `challenges.round_{n}.correctAnswer` | `string` | Correct answer |
| `answers` | `map` | Player answers keyed by UID |
| `answers.{uid}.round_{n}` | `map` | Answer for round n |
| `answers.{uid}.round_{n}.answer` | `string` | Submitted answer |
| `answers.{uid}.round_{n}.timeTakenMs` | `number` | Response time in ms |
| `roundResults` | `map` | Evaluated results per round |
| `roundResults.round_{n}.{uid}` | `map` | Per-player result |
| `roundResults.round_{n}.{uid}.correct` | `boolean` | Was it correct |
| `roundResults.round_{n}.{uid}.timeTakenMs` | `number` | Time taken |
| `roundResults.round_{n}.{uid}.score` | `number` | Points earned |
| `finalScores` | `map<string, number>` | Total score per player |
| `winnerId` | `string \| null` | Winner UID (null if draw) |
| `xpAwards` | `map<string, number>` | XP awarded to each player |
| `createdAt` | `timestamp` | Battle creation time |
| `startedAt` | `timestamp` | When battle became active |
| `scheduledEndAt` | `timestamp` | Auto-end deadline |
| `completedAt` | `timestamp \| null` | When battle finished |

### Example Document

```json
{
  "players": ["abc123", "def456"],
  "playerProfiles": {
    "abc123": {
      "displayName": "CodeWarrior42",
      "avatarUrl": "https://storage.googleapis.com/...",
      "skillRating": 1340,
      "league": "diamond"
    },
    "def456": {
      "displayName": "LogicMaster",
      "avatarUrl": null,
      "skillRating": 1290,
      "league": "platinum"
    }
  },
  "category": "logic",
  "difficulty": "medium",
  "status": "completed",
  "totalRounds": 3,
  "currentRound": 3,
  "timeLimitSeconds": 120,
  "challenges": {
    "round_1": {
      "prompt": "If all Bloops are Razzles and all Razzles are Lazzles, are all Bloops definitely Lazzles?",
      "options": ["Yes", "No", "Cannot determine"],
      "correctAnswer": "Yes"
    },
    "round_2": {
      "prompt": "What is the next number in the sequence: 2, 6, 14, 30, ?",
      "correctAnswer": "62"
    },
    "round_3": {
      "prompt": "A farmer has 17 sheep. All but 9 die. How many sheep are left?",
      "correctAnswer": "9"
    }
  },
  "answers": {
    "abc123": {
      "round_1": { "answer": "Yes", "timeTakenMs": 8400 },
      "round_2": { "answer": "62", "timeTakenMs": 34200 },
      "round_3": { "answer": "9", "timeTakenMs": 5100 }
    },
    "def456": {
      "round_1": { "answer": "Yes", "timeTakenMs": 12100 },
      "round_2": { "answer": "64", "timeTakenMs": 45600 },
      "round_3": { "answer": "9", "timeTakenMs": 7300 }
    }
  },
  "finalScores": { "abc123": 2716, "def456": 1878 },
  "winnerId": "abc123",
  "xpAwards": { "abc123": 65, "def456": 30 },
  "createdAt": "2026-03-15T10:00:00Z",
  "startedAt": "2026-03-15T10:00:01Z",
  "completedAt": "2026-03-15T10:06:42Z"
}
```

---

## 3. challenges

**Path**: `/challenges/{challengeId}`

Problem bank containing both AI-generated and community-created challenges.

| Field | Type | Description |
|---|---|---|
| `title` | `string` | Challenge title |
| `description` | `string` | Full problem statement (Markdown) |
| `type` | `string` | `logic`, `coding`, `reasoning`, `cybersecurity`, `math` |
| `difficulty` | `string` | `easy`, `medium`, `hard`, `expert` |
| `hints` | `array<string>` | Progressive hints (3 levels) |
| `correctAnswer` | `string` | Expected answer |
| `answerType` | `string` | `text`, `multiple_choice`, `code`, `numeric` |
| `options` | `array<string> \| null` | Choices for multiple_choice |
| `testCases` | `array<map> \| null` | For coding challenges |
| `testCases[].input` | `string` | Test input |
| `testCases[].expectedOutput` | `string` | Expected output |
| `testCases[].isHidden` | `boolean` | Hidden from user |
| `tags` | `array<string>` | Searchable tags |
| `xpReward` | `number` | XP for solving |
| `solveCount` | `number` | Times solved |
| `attemptCount` | `number` | Times attempted |
| `averageTimeMs` | `number` | Average solve time |
| `creatorId` | `string` | UID of creator |
| `source` | `string` | `ai_generated`, `community`, `curated` |
| `createdAt` | `timestamp` | Creation time |

### Example Document

```json
{
  "title": "The Escape Room Cipher",
  "description": "You find a locked door with a keypad. The clue reads: 'The key is the sum of all prime numbers less than 20, divided by the number of vowels in CYBERSECURITY.' What code do you enter?",
  "type": "reasoning",
  "difficulty": "medium",
  "hints": [
    "Start by listing all prime numbers less than 20.",
    "The primes are 2, 3, 5, 7, 11, 13, 17, 19. Their sum is 77. Now count the vowels.",
    "CYBERSECURITY has 4 vowels (Y, E, U, I). So 77 / 4 = 19.25. Round down to 19."
  ],
  "correctAnswer": "19",
  "answerType": "numeric",
  "options": null,
  "testCases": null,
  "tags": ["primes", "wordplay", "division", "cipher"],
  "xpReward": 25,
  "solveCount": 342,
  "attemptCount": 891,
  "averageTimeMs": 67000,
  "creatorId": "system",
  "source": "ai_generated",
  "createdAt": "2026-02-10T12:00:00Z"
}
```

---

## 4. forum_posts

**Path**: `/forum_posts/{postId}`

Community discussion forum for challenge help, strategies, and general learning.

| Field | Type | Description |
|---|---|---|
| `title` | `string` | Post title |
| `body` | `string` | Post body (Markdown) |
| `authorId` | `string` | UID of author |
| `authorName` | `string` | Cached display name |
| `authorLeague` | `string` | Cached league badge |
| `challengeId` | `string \| null` | Linked challenge (if discussion about one) |
| `tags` | `array<string>` | Categorization tags |
| `votes` | `number` | Net vote count |
| `viewCount` | `number` | View count |
| `solutionCount` | `number` | Number of solutions |
| `acceptedSolutionId` | `string \| null` | Accepted solution doc ID |
| `isPinned` | `boolean` | Pinned by admin |
| `status` | `string` | `open`, `solved`, `closed` |
| `createdAt` | `timestamp` | Post creation time |
| `updatedAt` | `timestamp` | Last edit time |

### Subcollection: `forum_posts/{postId}/solutions`

| Field | Type | Description |
|---|---|---|
| `body` | `string` | Solution text (Markdown) |
| `authorId` | `string` | UID of author |
| `authorName` | `string` | Cached display name |
| `authorLeague` | `string` | Cached league badge |
| `votes` | `number` | Net vote count |
| `isAccepted` | `boolean` | Marked as accepted answer |
| `isAISuggested` | `boolean` | Generated by AI |
| `createdAt` | `timestamp` | Creation time |

### Example Document

```json
{
  "title": "Help with The Escape Room Cipher - am I counting vowels wrong?",
  "body": "I keep getting 77/5 = 15.4 but the answer says 19. Is Y considered a vowel in CYBERSECURITY?",
  "authorId": "ghi789",
  "authorName": "PuzzledPanda",
  "authorLeague": "silver",
  "challengeId": "challenge_001",
  "tags": ["reasoning", "help", "vowels"],
  "votes": 12,
  "viewCount": 89,
  "solutionCount": 3,
  "acceptedSolutionId": "sol_002",
  "isPinned": false,
  "status": "solved",
  "createdAt": "2026-03-10T16:45:00Z",
  "updatedAt": "2026-03-10T17:20:00Z"
}
```

---

## 5. leaderboards

**Path**: `/leaderboards/{category}_{timeframe}`

Pre-computed leaderboard rankings, updated hourly by Cloud Functions.

| Field | Type | Description |
|---|---|---|
| `category` | `string` | `global`, `logic`, `coding`, `reasoning`, `cybersecurity`, `math` |
| `timeframe` | `string` | `daily`, `weekly`, `allTime` |
| `rankings` | `array<map>` | Top 100 players |
| `rankings[].rank` | `number` | Position (1-100) |
| `rankings[].userId` | `string` | Player UID |
| `rankings[].displayName` | `string` | Display name |
| `rankings[].avatarUrl` | `string \| null` | Avatar |
| `rankings[].xp` | `number` | Relevant XP |
| `rankings[].league` | `string` | Current league |
| `rankings[].streak` | `number` | Current streak |
| `lastUpdated` | `timestamp` | Last recalculation |

### Example Document (`leaderboards/global_allTime`)

```json
{
  "category": "global",
  "timeframe": "allTime",
  "rankings": [
    {
      "rank": 1,
      "userId": "abc123",
      "displayName": "CodeWarrior42",
      "avatarUrl": "https://storage.googleapis.com/.../abc123.png",
      "xp": 31250,
      "league": "grandmaster",
      "streak": 45
    },
    {
      "rank": 2,
      "userId": "xyz789",
      "displayName": "MathWizard",
      "avatarUrl": null,
      "xp": 28400,
      "league": "master",
      "streak": 22
    }
  ],
  "lastUpdated": "2026-03-15T14:00:00Z"
}
```

---

## 6. achievements

**Path**: `/achievements/{achievementId}`

Global achievement definitions (templates). Actual unlocks are in the user subcollection.

| Field | Type | Description |
|---|---|---|
| `id` | `string` | Unique identifier |
| `title` | `string` | Display title |
| `description` | `string` | How to unlock |
| `icon` | `string` | Asset name |
| `category` | `string` | `battle`, `challenge`, `streak`, `league`, `social`, `milestone` |
| `xpReward` | `number` | Bonus XP on unlock |
| `rarity` | `string` | `common`, `uncommon`, `rare`, `epic`, `legendary` |
| `condition` | `map` | Machine-readable unlock condition |
| `condition.type` | `string` | Condition type |
| `condition.value` | `number` | Threshold value |
| `unlockedByCount` | `number` | How many users have it |
| `createdAt` | `timestamp` | Definition creation time |

### Example Document

```json
{
  "id": "diamond_league",
  "title": "Diamond Mind",
  "description": "Reach Diamond League by earning 7,000 XP.",
  "icon": "diamond_achievement",
  "category": "league",
  "xpReward": 100,
  "rarity": "rare",
  "condition": {
    "type": "league_reached",
    "value": "diamond"
  },
  "unlockedByCount": 234,
  "createdAt": "2025-09-01T00:00:00Z"
}
```

---

## 7. learning_paths

**Path**: `/learning_paths/{pathId}`

Structured curricula guiding users through progressive challenges.

| Field | Type | Description |
|---|---|---|
| `title` | `string` | Path name |
| `description` | `string` | What the path teaches |
| `category` | `string` | Primary category |
| `difficulty` | `string` | Overall difficulty level |
| `icon` | `string` | Asset name |
| `estimatedHours` | `number` | Estimated completion time |
| `totalXP` | `number` | Total XP available |
| `modules` | `array<map>` | Ordered list of modules |
| `modules[].title` | `string` | Module title |
| `modules[].description` | `string` | Module summary |
| `modules[].challengeIds` | `array<string>` | Challenge IDs in this module |
| `modules[].xpReward` | `number` | Bonus XP for module completion |
| `enrolledCount` | `number` | Users enrolled |
| `completedCount` | `number` | Users completed |
| `createdAt` | `timestamp` | Creation time |

### Example Document

```json
{
  "title": "Cybersecurity Fundamentals",
  "description": "Learn the basics of cybersecurity through interactive challenges covering encryption, network security, and ethical hacking principles.",
  "category": "cybersecurity",
  "difficulty": "easy",
  "icon": "shield_lock",
  "estimatedHours": 8,
  "totalXP": 500,
  "modules": [
    {
      "title": "Introduction to Encryption",
      "description": "Caesar cipher, substitution, and basic encoding.",
      "challengeIds": ["ch_001", "ch_002", "ch_003", "ch_004"],
      "xpReward": 50
    },
    {
      "title": "Network Basics",
      "description": "Ports, protocols, and packet analysis.",
      "challengeIds": ["ch_010", "ch_011", "ch_012"],
      "xpReward": 75
    }
  ],
  "enrolledCount": 1240,
  "completedCount": 312,
  "createdAt": "2025-10-01T00:00:00Z"
}
```

---

## 8. daily_challenges

**Path**: `/daily_challenges/{YYYY-MM-DD}`

One document per day. Auto-generated by Cloud Functions at midnight UTC.

| Field | Type | Description |
|---|---|---|
| `date` | `string` | ISO date (YYYY-MM-DD) |
| `category` | `string` | Today's category |
| `title` | `string` | Display title |
| `description` | `string` | Flavor text |
| `difficulty` | `string` | Difficulty level |
| `xpReward` | `number` | Base XP for completion |
| `streakBonusXP` | `number` | Bonus XP if streak active |
| `startsAt` | `timestamp` | Start of availability window |
| `endsAt` | `timestamp` | End of availability window |
| `challenge` | `map` | The actual challenge content |
| `challenge.type` | `string` | Challenge type |
| `challenge.prompt` | `string` | Problem statement |
| `challenge.hints` | `array<string>` | 3-level hints |
| `challenge.correctAnswer` | `string \| null` | Correct answer |
| `challenge.timeLimit` | `number` | Time limit in seconds |
| `participants` | `array<string>` | UIDs who attempted |
| `completions` | `number` | Successful completions |
| `createdAt` | `timestamp` | Generation time |

### Example Document (`daily_challenges/2026-03-15`)

```json
{
  "date": "2026-03-15",
  "category": "logic",
  "title": "Daily Logic Challenge",
  "description": "Sharpen your deductive reasoning with today's logic puzzle!",
  "difficulty": "medium",
  "xpReward": 30,
  "streakBonusXP": 10,
  "startsAt": "2026-03-15T00:00:00Z",
  "endsAt": "2026-03-15T23:59:59Z",
  "challenge": {
    "type": "logic",
    "prompt": "Three friends each have a different pet. Use these clues: (1) Alex does not have a cat. (2) The dog owner sits next to Blake. (3) Casey has the fish. Who has the dog?",
    "hints": [
      "Start with what you know for certain from clue 3.",
      "If Casey has the fish, only Alex or Blake can have the dog.",
      "From clue 1, Alex does not have a cat. Since Casey has the fish, Alex must have the dog."
    ],
    "correctAnswer": "Alex",
    "timeLimit": 600
  },
  "participants": ["abc123", "def456", "ghi789"],
  "completions": 2,
  "createdAt": "2026-03-15T00:00:00Z"
}
```

---

## 9. matchmaking_queue

**Path**: `/matchmaking_queue/{userId}`

Temporary documents representing players waiting for a battle match. Cleaned up after matching.

| Field | Type | Description |
|---|---|---|
| `userId` | `string` | Player UID |
| `displayName` | `string` | Cached name |
| `skillRating` | `number` | Current skill rating |
| `category` | `string` | Desired challenge category |
| `difficulty` | `string` | Preferred difficulty |
| `league` | `string` | Current league |
| `status` | `string` | `waiting`, `matched` |
| `joinedAt` | `timestamp` | Queue entry time |

---

## 10. Composite Indexes

Required Firestore composite indexes for the queries used in Cloud Functions and client code.

| Collection | Fields | Order | Purpose |
|---|---|---|---|
| `matchmaking_queue` | `category` ASC, `skillRating` ASC, `status` ASC, `joinedAt` ASC | Query | Matchmaking search |
| `users` | `xp` DESC | Query | Global leaderboard |
| `users` | `categoryXP.logic` DESC | Query | Category leaderboard |
| `users` | `categoryXP.coding` DESC | Query | Category leaderboard |
| `users` | `categoryXP.reasoning` DESC | Query | Category leaderboard |
| `users` | `categoryXP.cybersecurity` DESC | Query | Category leaderboard |
| `users` | `categoryXP.math` DESC | Query | Category leaderboard |
| `challenges` | `type` ASC, `difficulty` ASC, `createdAt` DESC | Query | Challenge filtering |
| `forum_posts` | `tags` ARRAY, `votes` DESC | Query | Forum search |
| `forum_posts` | `challengeId` ASC, `createdAt` DESC | Query | Challenge discussions |
| `battles` | `players` ARRAY, `status` ASC, `createdAt` DESC | Query | User battle history |
| `daily_challenges` | `date` DESC | Query | Recent daily challenges |

### Index Definition File (`firestore.indexes.json`)

```json
{
  "indexes": [
    {
      "collectionGroup": "matchmaking_queue",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "category", "order": "ASCENDING" },
        { "fieldPath": "skillRating", "order": "ASCENDING" },
        { "fieldPath": "status", "order": "ASCENDING" },
        { "fieldPath": "joinedAt", "order": "ASCENDING" }
      ]
    },
    {
      "collectionGroup": "challenges",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "type", "order": "ASCENDING" },
        { "fieldPath": "difficulty", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "forum_posts",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "challengeId", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "battles",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "status", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    }
  ]
}
```

---

*Schema version: 1.0 | Last updated: 2026-03-15*
