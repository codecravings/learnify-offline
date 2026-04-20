# VidyaSetu - AI Prompt Templates

> Reference document for all AI/LLM prompt templates used in VidyaSetu. Each prompt includes the template, variable placeholders, and example input/output pairs.

---

## Table of Contents

1. [Challenge Generation Prompts](#1-challenge-generation-prompts)
   - [Logic Challenges](#11-logic-challenges)
   - [Coding Challenges](#12-coding-challenges)
   - [Reasoning Challenges](#13-reasoning-challenges)
   - [Cybersecurity Challenges](#14-cybersecurity-challenges)
   - [Math Challenges](#15-math-challenges)
2. [Hint Generation Prompt](#2-hint-generation-prompt)
3. [Answer Evaluation Prompt](#3-answer-evaluation-prompt)
4. [Scenario Battle Generation Prompt](#4-scenario-battle-generation-prompt)
5. [Forum Answer Suggestion Prompt](#5-forum-answer-suggestion-prompt)

---

## 1. Challenge Generation Prompts

### 1.1 Logic Challenges

**Prompt Template:**

```
You are VidyaSetu's challenge engine. Generate a logic puzzle for competitive learning.

PARAMETERS:
- Difficulty: {{difficulty}} (easy | medium | hard | expert)
- Target solve time: {{timeLimit}} seconds
- Topic tags: {{tags}}

REQUIREMENTS:
1. Create an original logic puzzle that tests deductive reasoning.
2. The puzzle must have exactly ONE correct answer.
3. Provide the answer in a single word or short phrase.
4. Generate 3 progressive hints (gentle nudge -> moderate help -> near-solution).
5. If multiple choice, provide exactly 4 options with one correct answer.

RESPONSE FORMAT (strict JSON):
{
  "title": "short catchy title",
  "prompt": "the full puzzle text",
  "answerType": "text | multiple_choice | numeric",
  "options": ["A", "B", "C", "D"] or null,
  "correctAnswer": "the answer",
  "hints": ["hint1", "hint2", "hint3"],
  "explanation": "step-by-step solution",
  "tags": ["tag1", "tag2"],
  "estimatedSolveTimeSeconds": number
}
```

**Example Input:**
```
difficulty: "medium"
timeLimit: 120
tags: ["deduction", "pattern"]
```

**Example Output:**
```json
{
  "title": "The Lighthouse Keeper's Code",
  "prompt": "A lighthouse flashes in a pattern: 2 short, 1 long, 3 short, 1 long, 4 short, 1 long. After the pattern repeats 3 times, how many total flashes (short + long) will have occurred?",
  "answerType": "numeric",
  "options": null,
  "correctAnswer": "33",
  "hints": [
    "First, figure out how many flashes are in one complete cycle of the pattern.",
    "One cycle is: 2 + 1 + 3 + 1 + 4 + 1 = 11 flashes total.",
    "Three repetitions: 11 x 3 = 33."
  ],
  "explanation": "The pattern per cycle is 2S + 1L + 3S + 1L + 4S + 1L = 11 flashes. Repeated 3 times: 11 * 3 = 33 total flashes.",
  "tags": ["deduction", "pattern", "sequences"],
  "estimatedSolveTimeSeconds": 90
}
```

---

### 1.2 Coding Challenges

**Prompt Template:**

```
You are VidyaSetu's challenge engine. Generate a coding challenge for competitive learning.

PARAMETERS:
- Difficulty: {{difficulty}} (easy | medium | hard | expert)
- Language: {{language}} (python | javascript | dart | any)
- Target solve time: {{timeLimit}} seconds
- Topic tags: {{tags}}

REQUIREMENTS:
1. Create an original coding problem with clear input/output specification.
2. Provide at least 3 test cases (2 visible, 1+ hidden).
3. The problem must be solvable within the time limit.
4. Include edge cases in hidden test cases.
5. Generate 3 progressive hints.

RESPONSE FORMAT (strict JSON):
{
  "title": "short catchy title",
  "prompt": "full problem statement with input/output format",
  "answerType": "code",
  "starterCode": {
    "python": "def solution(input):\n    pass",
    "javascript": "function solution(input) {\n  \n}"
  },
  "testCases": [
    {"input": "...", "expectedOutput": "...", "isHidden": false},
    {"input": "...", "expectedOutput": "...", "isHidden": false},
    {"input": "...", "expectedOutput": "...", "isHidden": true}
  ],
  "correctAnswer": "reference solution in python",
  "hints": ["hint1", "hint2", "hint3"],
  "explanation": "approach explanation with time complexity",
  "tags": ["tag1", "tag2"],
  "estimatedSolveTimeSeconds": number
}
```

**Example Input:**
```
difficulty: "easy"
language: "python"
timeLimit: 180
tags: ["strings", "beginner"]
```

**Example Output:**
```json
{
  "title": "Palindrome Detector",
  "prompt": "Write a function that takes a string and returns True if it is a palindrome (reads the same forwards and backwards), ignoring spaces and case. Return False otherwise.\n\nInput: a single string\nOutput: True or False",
  "answerType": "code",
  "starterCode": {
    "python": "def solution(s: str) -> bool:\n    pass",
    "javascript": "function solution(s) {\n  \n}"
  },
  "testCases": [
    {"input": "racecar", "expectedOutput": "True", "isHidden": false},
    {"input": "hello", "expectedOutput": "False", "isHidden": false},
    {"input": "A man a plan a canal Panama", "expectedOutput": "True", "isHidden": true},
    {"input": "", "expectedOutput": "True", "isHidden": true}
  ],
  "correctAnswer": "def solution(s: str) -> bool:\n    cleaned = s.replace(' ', '').lower()\n    return cleaned == cleaned[::-1]",
  "hints": [
    "Think about how to compare the string from both ends.",
    "You should normalize the string first: remove spaces and convert to lowercase.",
    "After cleaning, compare the string to its reverse. In Python, you can reverse with [::-1]."
  ],
  "explanation": "Clean the input by removing spaces and lowercasing. Then compare the string with its reverse. Time complexity: O(n), Space complexity: O(n).",
  "tags": ["strings", "beginner", "palindrome"],
  "estimatedSolveTimeSeconds": 120
}
```

---

### 1.3 Reasoning Challenges

**Prompt Template:**

```
You are VidyaSetu's challenge engine. Generate a reasoning/critical-thinking challenge.

PARAMETERS:
- Difficulty: {{difficulty}} (easy | medium | hard | expert)
- Subtopic: {{subtopic}} (lateral_thinking | analogy | verbal_reasoning | spatial | data_interpretation)
- Target solve time: {{timeLimit}} seconds

REQUIREMENTS:
1. Create a challenge that tests analytical and critical thinking.
2. The question should be solvable through reasoning alone (no specialized knowledge).
3. Avoid culturally biased content.
4. Must have exactly ONE defensible correct answer.
5. Generate 3 progressive hints.

RESPONSE FORMAT (strict JSON):
{
  "title": "short catchy title",
  "prompt": "the full challenge text",
  "answerType": "text | multiple_choice",
  "options": ["A", "B", "C", "D"] or null,
  "correctAnswer": "the answer",
  "hints": ["hint1", "hint2", "hint3"],
  "explanation": "reasoning walkthrough",
  "tags": ["tag1", "tag2"],
  "estimatedSolveTimeSeconds": number
}
```

**Example Input:**
```
difficulty: "hard"
subtopic: "lateral_thinking"
timeLimit: 180
```

**Example Output:**
```json
{
  "title": "The Elevator Paradox",
  "prompt": "A man lives on the 25th floor. Every morning, he takes the elevator down to the ground floor and goes to work. When he returns, he takes the elevator to the 15th floor and walks the remaining 10 floors. On rainy days, however, he takes the elevator all the way to the 25th floor. Why?",
  "answerType": "multiple_choice",
  "options": [
    "He enjoys the exercise on sunny days",
    "He is too short to reach the 25th-floor button, but uses his umbrella on rainy days",
    "The elevator only goes to the 15th floor on sunny days",
    "He visits a friend on the 15th floor"
  ],
  "correctAnswer": "He is too short to reach the 25th-floor button, but uses his umbrella on rainy days",
  "hints": [
    "Think about what physical limitation could prevent someone from using an elevator fully.",
    "What does he have on rainy days that he doesn't have on sunny days?",
    "An umbrella can extend your reach. Consider the elevator buttons."
  ],
  "explanation": "The man is short and cannot reach the button for the 25th floor. He can reach the 15th-floor button. On rainy days, he carries an umbrella which he uses to press the higher button.",
  "tags": ["lateral_thinking", "classic", "perspective"],
  "estimatedSolveTimeSeconds": 120
}
```

---

### 1.4 Cybersecurity Challenges

**Prompt Template:**

```
You are VidyaSetu's challenge engine. Generate a cybersecurity challenge for educational purposes.

PARAMETERS:
- Difficulty: {{difficulty}} (easy | medium | hard | expert)
- Subtopic: {{subtopic}} (encryption | network_security | web_security | forensics | social_engineering)
- Target solve time: {{timeLimit}} seconds

REQUIREMENTS:
1. Create an educational cybersecurity puzzle (ethical context only).
2. Focus on defensive security concepts and awareness.
3. Do NOT include any real exploits, malware, or harmful instructions.
4. The challenge should teach a security concept while being engaging.
5. Generate 3 progressive hints.

RESPONSE FORMAT (strict JSON):
{
  "title": "short catchy title",
  "prompt": "the full challenge text",
  "answerType": "text | multiple_choice",
  "options": ["A", "B", "C", "D"] or null,
  "correctAnswer": "the answer",
  "hints": ["hint1", "hint2", "hint3"],
  "explanation": "security concept explanation",
  "tags": ["tag1", "tag2"],
  "learningOutcome": "what the student learns",
  "estimatedSolveTimeSeconds": number
}
```

**Example Input:**
```
difficulty: "medium"
subtopic: "encryption"
timeLimit: 120
```

**Example Output:**
```json
{
  "title": "Caesar's Secret Message",
  "prompt": "You intercepted an encrypted message: 'KHOOR ZRUOG'. Intelligence suggests it was encrypted using a Caesar cipher. The plaintext is a common English greeting. What is the decrypted message and what is the shift key used?",
  "answerType": "text",
  "options": null,
  "correctAnswer": "HELLO WORLD, shift 3",
  "hints": [
    "A Caesar cipher shifts each letter by a fixed number of positions in the alphabet.",
    "Try shifting each letter backwards. Start with small shift values (1-5).",
    "Shift each letter back by 3: K->H, H->E, O->L, O->L, R->O..."
  ],
  "explanation": "A Caesar cipher with shift 3 was used: each letter was shifted 3 positions forward. To decrypt, shift back by 3. K(11)->H(8), H(8)->E(5), etc. This is one of the earliest known encryption methods, used by Julius Caesar. Modern encryption uses far more complex algorithms but the concept of shifting/transforming plaintext remains foundational.",
  "tags": ["encryption", "caesar_cipher", "classical_crypto"],
  "learningOutcome": "Understanding substitution ciphers and the concept of encryption keys",
  "estimatedSolveTimeSeconds": 90
}
```

---

### 1.5 Math Challenges

**Prompt Template:**

```
You are VidyaSetu's challenge engine. Generate a math challenge for competitive learning.

PARAMETERS:
- Difficulty: {{difficulty}} (easy | medium | hard | expert)
- Subtopic: {{subtopic}} (algebra | geometry | probability | number_theory | combinatorics | calculus)
- Target solve time: {{timeLimit}} seconds
- Level: {{level}} (middle_school | high_school | undergraduate)

REQUIREMENTS:
1. Create an original math problem appropriate for the specified level.
2. The answer must be exact (integer, fraction, or simple expression).
3. Avoid problems that require a calculator for large computations.
4. Generate 3 progressive hints that guide thinking, not just give steps.
5. Include the full solution in the explanation.

RESPONSE FORMAT (strict JSON):
{
  "title": "short catchy title",
  "prompt": "the full problem (use LaTeX notation for formulas: $...$)",
  "answerType": "numeric | text",
  "correctAnswer": "exact answer",
  "hints": ["hint1", "hint2", "hint3"],
  "explanation": "complete step-by-step solution",
  "tags": ["tag1", "tag2"],
  "estimatedSolveTimeSeconds": number
}
```

**Example Input:**
```
difficulty: "hard"
subtopic: "probability"
timeLimit: 180
level: "high_school"
```

**Example Output:**
```json
{
  "title": "The Birthday Shortcut",
  "prompt": "In a room of 30 students, what is the probability that at least two students share a birthday? Assume 365 days in a year and birthdays are uniformly distributed. Express your answer as a percentage rounded to the nearest whole number.",
  "answerType": "numeric",
  "correctAnswer": "71",
  "hints": [
    "It's easier to calculate the probability that NO two students share a birthday, then subtract from 1.",
    "The probability that all 30 have different birthdays is: (365/365) * (364/365) * (363/365) * ... * (336/365).",
    "This product equals approximately 0.2937. So P(at least one shared) = 1 - 0.2937 = 0.7063, which is about 71%."
  ],
  "explanation": "Using the complement: P(at least one match) = 1 - P(all different). P(all different) = 365!/((365-30)! * 365^30) = (365 * 364 * 363 * ... * 336) / 365^30 = 0.2937. Therefore P(at least one match) = 1 - 0.2937 = 0.7063 = 71%. This is the famous Birthday Problem, which shows that the probability reaches 50% with just 23 people.",
  "tags": ["probability", "birthday_problem", "combinatorics"],
  "estimatedSolveTimeSeconds": 150
}
```

---

## 2. Hint Generation Prompt

Used when a player requests a hint for any challenge type. Generates 3 levels of progressive assistance.

**Prompt Template:**

```
You are VidyaSetu's hint engine. Generate 3 progressive hints for a challenge.

CHALLENGE:
- Title: {{title}}
- Type: {{type}}
- Difficulty: {{difficulty}}
- Prompt: {{prompt}}
- Correct Answer: {{correctAnswer}}

HINT LEVELS:
- Level 1 (Gentle Nudge): A subtle direction without giving away the approach. Should help the student think about the problem differently.
- Level 2 (Moderate Help): Reveals the general approach or method to use. Narrows down the solution space.
- Level 3 (Strong Hint): Nearly gives the answer but still requires the student to complete the final step.

RULES:
- Each hint must be exactly 1-2 sentences.
- Never reveal the exact answer in any hint.
- Hints should build on each other progressively.
- Use encouraging, educational tone.

RESPONSE FORMAT (strict JSON):
{
  "hints": [
    "Level 1 hint text",
    "Level 2 hint text",
    "Level 3 hint text"
  ],
  "xpPenalty": [0, 5, 10]
}
```

**Example Input:**
```
title: "The Lighthouse Keeper's Code"
type: "logic"
difficulty: "medium"
prompt: "A lighthouse flashes in a pattern: 2 short, 1 long, 3 short, 1 long, 4 short, 1 long. After the pattern repeats 3 times, how many total flashes will have occurred?"
correctAnswer: "33"
```

**Example Output:**
```json
{
  "hints": [
    "Start by identifying the complete repeating pattern. Count carefully -- every flash matters, whether short or long.",
    "The pattern has groups: 2S, 1L, 3S, 1L, 4S, 1L. Add up all the numbers in one complete cycle.",
    "One full cycle has 2+1+3+1+4+1 = 11 flashes. Now multiply by the number of repetitions."
  ],
  "xpPenalty": [0, 5, 10]
}
```

---

## 3. Answer Evaluation Prompt

Used when the correct answer is ambiguous or the challenge requires free-text evaluation. Handles partial credit and flexible answer matching.

**Prompt Template:**

```
You are VidyaSetu's answer evaluator. Evaluate a student's answer against the expected answer.

CHALLENGE:
- Title: {{title}}
- Type: {{type}}
- Prompt: {{prompt}}
- Expected Answer: {{correctAnswer}}
- Answer Type: {{answerType}}

STUDENT SUBMISSION:
- Answer: {{studentAnswer}}
- Time Taken: {{timeTakenMs}}ms

EVALUATION CRITERIA:
1. Determine if the answer is CORRECT, PARTIALLY_CORRECT, or INCORRECT.
2. For text answers, accept equivalent phrasings and reasonable variations.
3. For numeric answers, accept mathematically equivalent forms (e.g., 0.5 = 1/2).
4. For code answers, evaluate based on correctness of logic, not style.
5. Provide brief, encouraging feedback.

RESPONSE FORMAT (strict JSON):
{
  "verdict": "CORRECT | PARTIALLY_CORRECT | INCORRECT",
  "score": number (0-100),
  "feedback": "brief explanation of evaluation",
  "correctAnswer": "the expected answer for learning",
  "partialCreditReason": "why partial credit was given (if applicable)"
}
```

**Example Input:**
```
title: "Caesar's Secret Message"
type: "cybersecurity"
prompt: "Decrypt 'KHOOR ZRUOG' (Caesar cipher, common English greeting). What is the message and shift key?"
correctAnswer: "HELLO WORLD, shift 3"
answerType: "text"
studentAnswer: "Hello World with a shift of 3"
timeTakenMs: 45000
```

**Example Output:**
```json
{
  "verdict": "CORRECT",
  "score": 100,
  "feedback": "Excellent work! You correctly identified both the plaintext message and the Caesar cipher shift key. Your decryption skills are sharp!",
  "correctAnswer": "HELLO WORLD, shift 3",
  "partialCreditReason": null
}
```

**Example (Partial Credit):**

```
studentAnswer: "HELLO WORLD"
```

```json
{
  "verdict": "PARTIALLY_CORRECT",
  "score": 60,
  "feedback": "You correctly decrypted the message to HELLO WORLD, but you didn't identify the shift key (which is 3). Always try to identify the full parameters of the cipher.",
  "correctAnswer": "HELLO WORLD, shift 3",
  "partialCreditReason": "Correct plaintext but missing shift key identification"
}
```

---

## 4. Scenario Battle Generation Prompt

Used for generating real-time battle scenarios where two players compete on the same problem simultaneously.

**Prompt Template:**

```
You are VidyaSetu's battle scenario engine. Generate a multi-round battle scenario.

PARAMETERS:
- Category: {{category}}
- Difficulty: {{difficulty}}
- Number of Rounds: {{totalRounds}}
- Time per Round: {{timeLimitSeconds}} seconds
- Player Skill Ratings: {{player1Rating}}, {{player2Rating}}

REQUIREMENTS:
1. Generate {{totalRounds}} independent questions of similar difficulty.
2. Each question must be solvable within {{timeLimitSeconds}} seconds.
3. Questions should test speed AND accuracy.
4. Prefer questions with short, unambiguous answers.
5. Include variety across rounds (don't repeat the same sub-type).
6. Calibrate difficulty to the average of both players' skill ratings.

RESPONSE FORMAT (strict JSON):
{
  "battleTheme": "catchy battle theme name",
  "rounds": [
    {
      "roundNumber": 1,
      "prompt": "question text",
      "answerType": "text | numeric | multiple_choice",
      "options": [...] or null,
      "correctAnswer": "answer",
      "timeLimit": number,
      "pointValue": number
    }
  ]
}
```

**Example Input:**
```
category: "math"
difficulty: "medium"
totalRounds: 3
timeLimitSeconds: 60
player1Rating: 1340
player2Rating: 1290
```

**Example Output:**
```json
{
  "battleTheme": "Speed Math Showdown",
  "rounds": [
    {
      "roundNumber": 1,
      "prompt": "What is the smallest prime number greater than 50?",
      "answerType": "numeric",
      "options": null,
      "correctAnswer": "53",
      "timeLimit": 60,
      "pointValue": 100
    },
    {
      "roundNumber": 2,
      "prompt": "A triangle has sides of length 5, 12, and 13. What is its area?",
      "answerType": "numeric",
      "options": null,
      "correctAnswer": "30",
      "timeLimit": 60,
      "pointValue": 100
    },
    {
      "roundNumber": 3,
      "prompt": "If f(x) = 2x + 3 and g(x) = x^2, what is f(g(4))?",
      "answerType": "numeric",
      "options": null,
      "correctAnswer": "35",
      "timeLimit": 60,
      "pointValue": 100
    }
  ]
}
```

---

## 5. Forum Answer Suggestion Prompt

Used when a forum post has been unanswered for a period, or when a user explicitly requests AI assistance on a forum post.

**Prompt Template:**

```
You are VidyaSetu's forum assistant. Suggest a helpful answer for a forum question.

FORUM POST:
- Title: {{title}}
- Body: {{body}}
- Tags: {{tags}}
- Related Challenge: {{challengeTitle}} (if any)

EXISTING SOLUTIONS (if any):
{{existingSolutions}}

REQUIREMENTS:
1. Provide a clear, educational explanation.
2. Do NOT give the direct answer to any linked challenge.
3. Guide the student's thinking rather than solving for them.
4. Use examples or analogies to explain concepts.
5. Be encouraging and supportive in tone.
6. If existing solutions are wrong, gently correct them.
7. Use Markdown formatting for readability.

RESPONSE FORMAT (strict JSON):
{
  "suggestedAnswer": "full markdown answer text",
  "confidence": number (0-1),
  "relatedTopics": ["topic1", "topic2"],
  "suggestedResources": ["resource description 1", "resource description 2"]
}
```

**Example Input:**
```
title: "Help with The Escape Room Cipher - am I counting vowels wrong?"
body: "I keep getting 77/5 = 15.4 but the answer says 19. Is Y considered a vowel in CYBERSECURITY?"
tags: ["reasoning", "help", "vowels"]
challengeTitle: "The Escape Room Cipher"
existingSolutions: []
```

**Example Output:**
```json
{
  "suggestedAnswer": "Great question! The debate about whether Y is a vowel is actually at the heart of this puzzle.\n\nHere's a helpful way to think about it:\n\n**When is Y a vowel?**\nIn English, Y is considered a vowel when it sounds like a vowel (like in \"gym\" or \"happy\"). When it sounds like a consonant (like in \"yes\" or \"yellow\"), it's a consonant.\n\n**Apply this to CYBERSECURITY:**\nLook at each Y in the word and ask: does it make a vowel sound or a consonant sound?\n\n- C-**Y**-B-E-R-S-E-C-U-R-I-T-**Y**\n\nThe first Y (in CY-) makes an \"ih\" vowel sound. The final Y makes an \"ee\" vowel sound.\n\nSo the real question is: did the puzzle creator intend Y as a vowel? Try counting both ways and see which gives you the expected answer.\n\nHint: count the vowels as **E, U, I, Y** (the standard \"Y as vowel\" set) and see if that changes your denominator!",
  "confidence": 0.85,
  "relatedTopics": ["English phonetics", "Vowel classification", "Ambiguity in puzzles"],
  "suggestedResources": [
    "Merriam-Webster: 'Is Y a Vowel?' article",
    "Khan Academy: Introduction to phonetics"
  ]
}
```

---

## Prompt Engineering Notes

### Best Practices Used

| Practice | Implementation |
|---|---|
| **Structured output** | All prompts request strict JSON for reliable parsing |
| **Role assignment** | Each prompt begins with a clear role definition |
| **Constraint specification** | Requirements are numbered and explicit |
| **Few-shot examples** | Templates include format examples via the response schema |
| **Safety guardrails** | Cybersecurity prompts explicitly prohibit harmful content |
| **Difficulty calibration** | Parameters allow dynamic difficulty adjustment |
| **Evaluation rubrics** | Answer evaluation has clear criteria for partial credit |

### Token Optimization

| Prompt Type | Avg Input Tokens | Avg Output Tokens | Model |
|---|---|---|---|
| Challenge Generation | ~300 | ~400 | Gemini 1.5 Pro |
| Hint Generation | ~250 | ~150 | Gemini 1.5 Flash |
| Answer Evaluation | ~350 | ~150 | Gemini 1.5 Flash |
| Battle Scenario | ~200 | ~500 | Gemini 1.5 Pro |
| Forum Suggestion | ~400 | ~350 | Gemini 1.5 Flash |

### Error Handling

All AI API calls should:
1. Set a response timeout (5s for Flash, 10s for Pro)
2. Validate JSON response structure before using
3. Fall back to a pre-generated challenge bank on API failure
4. Log prompt/response pairs for quality monitoring
5. Implement retry with exponential backoff (max 3 retries)

---

*Prompt templates version: 1.0 | Last updated: 2026-03-15*
