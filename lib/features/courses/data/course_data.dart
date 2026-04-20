// ─────────────────────────────────────────────────────────────────────────────
// Course Data Models & Static Content for Learnify
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

/// A single piece of lesson content (one card in the content phase).
class LessonContent {
  final String type; // 'text', 'code', 'highlight', 'example'
  final String title;
  final String body;

  const LessonContent({
    required this.type,
    required this.title,
    required this.body,
  });
}

/// A quiz question with 4 options.
class QuizQuestion {
  final String question;
  final List<String> options;
  final int correctIndex;
  final String explanation;

  const QuizQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });
}

/// A single lesson containing content cards and quiz questions.
class Lesson {
  final String id;
  final String title;
  final String description;
  final List<LessonContent> content;
  final List<QuizQuestion> quiz;
  final int xpReward;
  final String gameType; // 'interactive', 'quiz', 'simulation'

  const Lesson({
    required this.id,
    required this.title,
    this.description = '',
    required this.content,
    required this.quiz,
    this.xpReward = 100,
    this.gameType = 'quiz',
  });
}

/// A chapter within a subject.
class CourseChapter {
  final String id;
  final String title;
  final String description;
  final List<Lesson> lessons;

  const CourseChapter({
    required this.id,
    required this.title,
    required this.description,
    required this.lessons,
  });
}

/// A top-level subject / course.
class CourseSubject {
  final String id;
  final String name;
  final String icon;
  final Color accentColor;
  final List<CourseChapter> chapters;
  final bool comingSoon;

  const CourseSubject({
    required this.id,
    required this.name,
    required this.icon,
    required this.accentColor,
    required this.chapters,
    this.comingSoon = false,
  });
}

/// Static course catalogue.
class CourseData {
  CourseData._();

  static final List<CourseSubject> allCourses = [
    // ── Physics ─────────────────────────────────────────────────────────
    CourseSubject(
      id: 'physics',
      name: 'Physics',
      icon: 'physics',
      accentColor: Color(0xFF8B5CF6),
      chapters: [
        // ── Chapter 1: Motion & Forces (Beginner — Class 8-10) ──
        CourseChapter(
          id: 'physics_motion_forces',
          title: 'Motion & Forces',
          description: 'Beginner — Class 8-10: Understand how objects move and what makes them move',
          lessons: [
            // Lesson 1: What is Motion?
            Lesson(
              id: 'phys_what_is_motion',
              title: 'What is Motion?',
              description: 'Drag objects and discover speed, distance and time',
              gameType: 'interactive',
              xpReward: 100,
              content: [
                LessonContent(
                  type: 'text',
                  title: 'Understanding Motion',
                  body:
                      'Motion is the change in position of an object with respect to time. When you walk to school, ride a bicycle, or throw a ball, you are observing motion. An object is said to be in motion if its position changes over time relative to a reference point. Even the Earth itself is in constant motion, orbiting the Sun at roughly 107,000 km/h.',
                ),
                LessonContent(
                  type: 'highlight',
                  title: 'Speed = Distance / Time',
                  body:
                      'Speed tells us how fast an object is moving. It is calculated by dividing the total distance covered by the total time taken. The formula is: Speed = Distance ÷ Time, often written as v = d/t. Speed is a scalar quantity, meaning it has magnitude but no direction.',
                ),
                LessonContent(
                  type: 'code',
                  title: 'Units of Speed',
                  body:
                      'SI unit of speed: metres per second (m/s)\n\nCommon conversions:\n• 1 km/h = 1000 m / 3600 s ≈ 0.278 m/s\n• 1 m/s = 3.6 km/h\n\nExample:\n• A car travels 150 km in 2 hours\n• Speed = 150 / 2 = 75 km/h\n• In m/s: 75 × 0.278 ≈ 20.83 m/s',
                ),
                LessonContent(
                  type: 'example',
                  title: 'Worked Example',
                  body:
                      'A cyclist covers 500 metres in 25 seconds. What is her speed?\n\nStep 1: Identify values — Distance = 500 m, Time = 25 s\nStep 2: Apply v = d/t\nStep 3: v = 500 / 25 = 20 m/s\n\nThe cyclist is moving at 20 m/s (about 72 km/h — pretty fast for a bicycle!).',
                ),
              ],
              quiz: [
                QuizQuestion(
                  question: 'A train travels 360 km in 4 hours. What is its speed in km/h?',
                  options: ['80 km/h', '90 km/h', '100 km/h', '120 km/h'],
                  correctIndex: 1,
                  explanation:
                      'Speed = Distance ÷ Time = 360 ÷ 4 = 90 km/h.',
                ),
                QuizQuestion(
                  question: 'Which of the following is the SI unit of speed?',
                  options: ['km/h', 'm/s', 'miles/h', 'cm/min'],
                  correctIndex: 1,
                  explanation:
                      'The SI (International System) unit of speed is metres per second (m/s).',
                ),
                QuizQuestion(
                  question: 'An object is said to be in motion when:',
                  options: [
                    'It is at rest',
                    'Its position changes with respect to a reference point over time',
                    'It has zero speed',
                    'It is very heavy',
                  ],
                  correctIndex: 1,
                  explanation:
                      'Motion is defined as the change in position of an object relative to a reference point over time.',
                ),
              ],
            ),

            // Lesson 2: Forces & Newton's First Law
            Lesson(
              id: 'phys_newtons_first_law',
              title: "Forces & Newton's First Law",
              description: 'Push and pull objects to discover inertia',
              gameType: 'interactive',
              xpReward: 120,
              content: [
                LessonContent(
                  type: 'text',
                  title: 'What is a Force?',
                  body:
                      'A force is a push or pull that can change the state of motion of an object. Forces can make objects start moving, stop moving, speed up, slow down, or change direction. Forces are measured in Newtons (N) and are vector quantities, meaning they have both magnitude and direction. In everyday life, you experience forces constantly — gravity pulling you down, friction slowing your shoes on the ground, and your muscles pushing doors open.',
                ),
                LessonContent(
                  type: 'highlight',
                  title: "Newton's First Law — The Law of Inertia",
                  body:
                      'An object at rest stays at rest, and an object in motion stays in motion at a constant velocity, unless acted upon by an unbalanced external force. This means that objects naturally resist changes to their state of motion. This resistance is called inertia.',
                ),
                LessonContent(
                  type: 'text',
                  title: 'Understanding Inertia',
                  body:
                      'Inertia is the tendency of an object to resist any change in its motion. The more mass an object has, the more inertia it possesses. A heavy truck is harder to push into motion than a shopping cart because the truck has greater inertia. Similarly, it is harder to stop the moving truck. This is why seatbelts are so important — when a car stops suddenly, your body wants to keep moving forward due to inertia.',
                ),
                LessonContent(
                  type: 'example',
                  title: 'Inertia in Daily Life',
                  body:
                      'Example 1: A ball rolling on a rough surface slows down and stops because friction acts as an unbalanced force.\n\nExample 2: When a bus stops suddenly, passengers lurch forward. Their bodies were in motion and tend to stay in motion (inertia) even after the bus stops.\n\nExample 3: A tablecloth can be pulled quickly from under dishes. The dishes stay in place due to their inertia.',
                ),
              ],
              quiz: [
                QuizQuestion(
                  question: 'What is the SI unit of force?',
                  options: ['Joule', 'Watt', 'Newton', 'Pascal'],
                  correctIndex: 2,
                  explanation:
                      'The SI unit of force is the Newton (N), named after Sir Isaac Newton.',
                ),
                QuizQuestion(
                  question: "Newton's First Law is also known as the law of:",
                  options: ['Acceleration', 'Inertia', 'Gravity', 'Reaction'],
                  correctIndex: 1,
                  explanation:
                      "Newton's First Law is called the Law of Inertia because it describes how objects resist changes in their state of motion.",
                ),
                QuizQuestion(
                  question: 'A book resting on a table stays at rest because:',
                  options: [
                    'There is no gravity acting on it',
                    'The forces on it are balanced',
                    'It has no mass',
                    'It is moving very slowly',
                  ],
                  correctIndex: 1,
                  explanation:
                      'The book stays at rest because the downward gravitational force is balanced by the upward normal force from the table. Since the net force is zero, it remains at rest (Newton\'s First Law).',
                ),
              ],
            ),

            // Lesson 3: F = ma — Newton's Second Law
            Lesson(
              id: 'phys_newtons_second_law',
              title: "F = ma — Newton's Second Law",
              description: 'Throw a ball! Change mass and force to see acceleration',
              gameType: 'interactive',
              xpReward: 150,
              content: [
                LessonContent(
                  type: 'text',
                  title: "Newton's Second Law of Motion",
                  body:
                      "Newton's Second Law states that the acceleration of an object is directly proportional to the net force acting on it and inversely proportional to its mass. This is expressed by the most important equation in mechanics: F = ma. If you double the force on an object, its acceleration doubles. If you double the mass while keeping the force the same, the acceleration is halved.",
                ),
                LessonContent(
                  type: 'highlight',
                  title: 'Mass vs Weight',
                  body:
                      'Mass is the amount of matter in an object, measured in kilograms (kg). It does not change with location. Weight is the gravitational force on an object, calculated as W = mg, where g ≈ 9.8 m/s² on Earth. Your mass on the Moon is the same as on Earth, but your weight is about 1/6 because the Moon\'s gravity is weaker.',
                ),
                LessonContent(
                  type: 'code',
                  title: 'The Unit of Force — Newton',
                  body:
                      'F = m × a\n\nUnit derivation:\n• Mass: kilograms (kg)\n• Acceleration: metres per second squared (m/s²)\n• Force: kg × m/s² = Newton (N)\n\n1 Newton is the force needed to accelerate\na 1 kg mass at 1 m/s².\n\nWeight on Earth:\nW = m × g = m × 9.8 N\nA 50 kg person weighs 50 × 9.8 = 490 N',
                ),
                LessonContent(
                  type: 'example',
                  title: 'Worked Examples',
                  body:
                      'Example 1: A 5 kg box is pushed with a force of 20 N.\na = F/m = 20/5 = 4 m/s²\n\nExample 2: What force is needed to accelerate a 1200 kg car at 3 m/s²?\nF = ma = 1200 × 3 = 3600 N\n\nExample 3: A 0.5 kg ball is hit with a force of 100 N. What is its acceleration?\na = F/m = 100/0.5 = 200 m/s² — that is why a cricket ball flies so fast!',
                ),
              ],
              quiz: [
                QuizQuestion(
                  question: 'A 10 kg object has a net force of 30 N applied. What is its acceleration?',
                  options: ['0.3 m/s²', '3 m/s²', '30 m/s²', '300 m/s²'],
                  correctIndex: 1,
                  explanation:
                      'Using F = ma, we get a = F/m = 30/10 = 3 m/s².',
                ),
                QuizQuestion(
                  question: 'If you double the mass of an object but keep the same force, the acceleration will:',
                  options: ['Double', 'Stay the same', 'Halve', 'Quadruple'],
                  correctIndex: 2,
                  explanation:
                      'Since a = F/m, doubling m with the same F gives a = F/(2m), which is half the original acceleration.',
                ),
                QuizQuestion(
                  question: 'A person has a mass of 60 kg. What is their weight on Earth (g = 9.8 m/s²)?',
                  options: ['60 N', '588 N', '6.12 N', '9.8 N'],
                  correctIndex: 1,
                  explanation:
                      'Weight = mass × g = 60 × 9.8 = 588 N.',
                ),
              ],
            ),
          ],
        ),

        // ── Chapter 2: Energy & Work (Intermediate — Class 11-12) ──
        CourseChapter(
          id: 'physics_energy_work',
          title: 'Energy & Work',
          description: 'Intermediate — Class 11-12: Explore how forces do work and how energy transforms',
          lessons: [
            // Lesson 1: Work Done by a Force
            Lesson(
              id: 'phys_work_done',
              title: 'Work Done by a Force',
              description: 'Pull a box across surfaces and measure work',
              gameType: 'interactive',
              xpReward: 130,
              content: [
                LessonContent(
                  type: 'text',
                  title: 'What is Work in Physics?',
                  body:
                      'In physics, work has a very specific meaning that differs from everyday usage. Work is done when a force causes an object to move in the direction of the force. If you push a wall and it does not move, you have done zero work in the physics sense, even though you might feel tired. Work transfers energy from one system to another and is a scalar quantity.',
                ),
                LessonContent(
                  type: 'code',
                  title: 'The Work Formula',
                  body:
                      'W = F × d × cos(θ)\n\nWhere:\n• W = Work done (Joules, J)\n• F = Applied force (Newtons, N)\n• d = Displacement (metres, m)\n• θ = Angle between force and displacement\n\nSpecial cases:\n• θ = 0° → cos(0°) = 1 → W = F × d (maximum work)\n• θ = 90° → cos(90°) = 0 → W = 0 (no work done)\n• θ = 180° → cos(180°) = −1 → W = −F × d (negative work)',
                ),
                LessonContent(
                  type: 'highlight',
                  title: 'The Joule — Unit of Work and Energy',
                  body:
                      'One Joule (J) is the work done when a force of 1 Newton moves an object through 1 metre in the direction of the force. It is named after James Prescott Joule. For context, lifting an apple (about 1 N) by 1 metre requires approximately 1 Joule of work.',
                ),
                LessonContent(
                  type: 'example',
                  title: 'Worked Examples',
                  body:
                      'Example 1: You push a box with 50 N of force across 4 m of floor (θ = 0°).\nW = 50 × 4 × cos(0°) = 50 × 4 × 1 = 200 J\n\nExample 2: You carry a 10 kg bag while walking 100 m horizontally. The carrying force is vertical (upward) while movement is horizontal, so θ = 90°.\nW = F × d × cos(90°) = 0 J — no work done!\n\nExample 3: Friction of 20 N acts on a sliding box over 3 m. Friction opposes motion (θ = 180°).\nW = 20 × 3 × cos(180°) = −60 J (negative work — energy removed from the box).',
                ),
              ],
              quiz: [
                QuizQuestion(
                  question: 'A person pushes a crate with 80 N of force over 5 m along the floor. How much work is done?',
                  options: ['16 J', '75 J', '400 J', '85 J'],
                  correctIndex: 2,
                  explanation:
                      'W = F × d × cos(0°) = 80 × 5 × 1 = 400 J. The force is in the direction of motion, so θ = 0°.',
                ),
                QuizQuestion(
                  question: 'When is zero work done by a force?',
                  options: [
                    'When the force is very large',
                    'When the force is perpendicular to the displacement',
                    'When the object is heavy',
                    'When the object moves fast',
                  ],
                  correctIndex: 1,
                  explanation:
                      'When the force is perpendicular (90°) to the displacement, cos(90°) = 0, so W = 0.',
                ),
                QuizQuestion(
                  question: 'What is the SI unit of work?',
                  options: ['Newton', 'Watt', 'Joule', 'Pascal'],
                  correctIndex: 2,
                  explanation:
                      'The SI unit of work is the Joule (J), equivalent to 1 N·m.',
                ),
              ],
            ),

            // Lesson 2: Kinetic & Potential Energy
            Lesson(
              id: 'phys_ke_pe',
              title: 'Kinetic & Potential Energy',
              description: 'Build a roller coaster and watch energy transform',
              gameType: 'simulation',
              xpReward: 150,
              content: [
                LessonContent(
                  type: 'text',
                  title: 'Two Faces of Mechanical Energy',
                  body:
                      'Mechanical energy comes in two main forms: kinetic energy (energy of motion) and potential energy (stored energy due to position). A ball held high has gravitational potential energy. When released, that potential energy converts to kinetic energy as it falls. At every point during the fall, the total mechanical energy remains constant (assuming no air resistance). This is the principle of conservation of energy.',
                ),
                LessonContent(
                  type: 'code',
                  title: 'Key Formulas',
                  body:
                      'Kinetic Energy:\nKE = ½ × m × v²\n• m = mass (kg)\n• v = velocity (m/s)\n\nGravitational Potential Energy:\nPE = m × g × h\n• m = mass (kg)\n• g = 9.8 m/s² (acceleration due to gravity)\n• h = height above reference point (m)\n\nConservation of Energy:\nKE₁ + PE₁ = KE₂ + PE₂\n½mv₁² + mgh₁ = ½mv₂² + mgh₂',
                ),
                LessonContent(
                  type: 'highlight',
                  title: 'Conservation of Energy',
                  body:
                      'Energy cannot be created or destroyed — it can only be transformed from one form to another. In a roller coaster, at the top of a hill, energy is mostly potential. At the bottom, it is mostly kinetic. The total mechanical energy stays constant if we ignore friction and air resistance. This is one of the most fundamental laws in all of physics.',
                ),
                LessonContent(
                  type: 'example',
                  title: 'Roller Coaster Example',
                  body:
                      'A 500 kg roller coaster car is at the top of a 40 m hill, starting from rest.\n\nAt the top: PE = mgh = 500 × 9.8 × 40 = 196,000 J, KE = 0 J\nTotal energy = 196,000 J\n\nAt the bottom (h = 0): PE = 0 J, KE = 196,000 J\n½mv² = 196,000\nv² = (196,000 × 2) / 500 = 784\nv = 28 m/s ≈ 100.8 km/h\n\nThe car reaches about 101 km/h at the bottom!',
                ),
              ],
              quiz: [
                QuizQuestion(
                  question: 'A 2 kg ball moves at 5 m/s. What is its kinetic energy?',
                  options: ['10 J', '25 J', '50 J', '5 J'],
                  correctIndex: 1,
                  explanation:
                      'KE = ½mv² = ½ × 2 × 5² = ½ × 2 × 25 = 25 J.',
                ),
                QuizQuestion(
                  question: 'A 3 kg book is on a shelf 2 m high. What is its gravitational potential energy? (g = 9.8 m/s²)',
                  options: ['6 J', '29.4 J', '58.8 J', '19.6 J'],
                  correctIndex: 2,
                  explanation:
                      'PE = mgh = 3 × 9.8 × 2 = 58.8 J.',
                ),
                QuizQuestion(
                  question: 'At the highest point of a pendulum swing, the energy is mostly:',
                  options: [
                    'Kinetic energy',
                    'Potential energy',
                    'Heat energy',
                    'Sound energy',
                  ],
                  correctIndex: 1,
                  explanation:
                      'At the highest point, the pendulum momentarily stops (KE ≈ 0) and has maximum height, so the energy is mostly gravitational potential energy.',
                ),
              ],
            ),
          ],
        ),

        // ── Chapter 3: Waves & Optics (College) ──
        CourseChapter(
          id: 'physics_waves_optics',
          title: 'Waves & Optics',
          description: 'College level: Dive into wave behaviour, light, and optical phenomena',
          lessons: [
            // Lesson 1: Wave Properties
            Lesson(
              id: 'phys_wave_properties',
              title: 'Wave Properties',
              description: 'Create ripples and explore frequency, wavelength, amplitude',
              gameType: 'simulation',
              xpReward: 160,
              content: [
                LessonContent(
                  type: 'text',
                  title: 'What is a Wave?',
                  body:
                      'A wave is a disturbance that transfers energy from one place to another without transferring matter. When you drop a stone into a pond, the ripples carry energy outward, but the water itself only moves up and down — it does not travel with the wave. Waves are found everywhere in nature: sound waves, light waves, seismic waves, and even gravitational waves predicted by Einstein.',
                ),
                LessonContent(
                  type: 'highlight',
                  title: 'Transverse vs Longitudinal',
                  body:
                      'In transverse waves, particles oscillate perpendicular to the direction of wave travel (like light waves and waves on a string). In longitudinal waves, particles oscillate parallel to the wave direction (like sound waves). The key difference is the direction of particle vibration relative to wave propagation. Some waves, like water surface waves, are a combination of both.',
                ),
                LessonContent(
                  type: 'code',
                  title: 'The Wave Equation',
                  body:
                      'v = f × λ\n\nWhere:\n• v = wave speed (m/s)\n• f = frequency (Hz = cycles per second)\n• λ (lambda) = wavelength (m)\n\nKey terms:\n• Amplitude (A): Maximum displacement from rest\n• Period (T): Time for one complete cycle; T = 1/f\n• Frequency (f): Number of cycles per second\n\nExample: A wave has f = 500 Hz and λ = 0.68 m\nv = 500 × 0.68 = 340 m/s (speed of sound in air!)',
                ),
                LessonContent(
                  type: 'example',
                  title: 'Wave Calculation',
                  body:
                      'A radio station broadcasts at a frequency of 100 MHz. What is the wavelength? (Speed of light c = 3 × 10⁸ m/s)\n\nStep 1: Convert frequency — 100 MHz = 100 × 10⁶ = 10⁸ Hz\nStep 2: Use v = fλ, so λ = v/f\nStep 3: λ = (3 × 10⁸) / (10⁸) = 3 m\n\nThe radio wave has a wavelength of 3 metres. FM radio waves are much longer than visible light waves (400-700 nm).',
                ),
              ],
              quiz: [
                QuizQuestion(
                  question: 'In a transverse wave, particles move:',
                  options: [
                    'Parallel to the wave direction',
                    'Perpendicular to the wave direction',
                    'In circles',
                    'They do not move',
                  ],
                  correctIndex: 1,
                  explanation:
                      'In transverse waves, the oscillation of particles is perpendicular (at right angles) to the direction the wave travels.',
                ),
                QuizQuestion(
                  question: 'A wave has a frequency of 200 Hz and a wavelength of 1.7 m. What is the wave speed?',
                  options: ['340 m/s', '117.6 m/s', '200 m/s', '1.7 m/s'],
                  correctIndex: 0,
                  explanation:
                      'v = f × λ = 200 × 1.7 = 340 m/s.',
                ),
                QuizQuestion(
                  question: 'Sound is an example of a:',
                  options: [
                    'Transverse wave',
                    'Longitudinal wave',
                    'Electromagnetic wave',
                    'Standing wave',
                  ],
                  correctIndex: 1,
                  explanation:
                      'Sound is a longitudinal wave — air molecules oscillate back and forth parallel to the direction the sound travels, creating compressions and rarefactions.',
                ),
              ],
            ),
          ],
        ),
      ],
    ),

    // ── Mathematics ─────────────────────────────────────────────────────
    CourseSubject(
      id: 'math',
      name: 'Mathematics',
      icon: 'math',
      accentColor: Color(0xFFF59E0B),
      chapters: [
        // ── Chapter 1: Number Systems & Arithmetic (Beginner) ──
        CourseChapter(
          id: 'math_number_systems',
          title: 'Number Systems & Arithmetic',
          description: 'Beginner: Master the building blocks of all mathematics',
          lessons: [
            // Lesson 1: The Number Line
            Lesson(
              id: 'math_number_line',
              title: 'The Number Line',
              description: 'Tap and drag numbers on the number line',
              gameType: 'interactive',
              xpReward: 100,
              content: [
                LessonContent(
                  type: 'text',
                  title: 'Natural Numbers & Counting',
                  body:
                      'Natural numbers are the counting numbers: 1, 2, 3, 4, 5, and so on. They are the most basic type of number, used for counting objects. When we include zero, we call them whole numbers: 0, 1, 2, 3, ... Natural numbers extend infinitely — there is no largest natural number, because you can always add one more.',
                ),
                LessonContent(
                  type: 'highlight',
                  title: 'Integers — Positive, Negative, and Zero',
                  body:
                      'Integers extend natural numbers to include negative numbers: ..., -3, -2, -1, 0, 1, 2, 3, ... They are essential for representing things like temperatures below zero, debts, or elevations below sea level. On the number line, positive integers are to the right of zero and negative integers are to the left.',
                ),
                LessonContent(
                  type: 'text',
                  title: 'Rational Numbers',
                  body:
                      'A rational number is any number that can be expressed as a fraction p/q, where p and q are integers and q is not zero. Examples include 1/2, -3/4, 7 (which is 7/1), and 0.333... (which is 1/3). Every integer is also a rational number. The decimal form of a rational number either terminates (like 0.25) or repeats (like 0.333...).',
                ),
                LessonContent(
                  type: 'example',
                  title: 'The Number Line Concept',
                  body:
                      'Imagine a straight horizontal line stretching infinitely in both directions.\n\n• Mark a point as 0 (the origin)\n• Equal spaces to the right: 1, 2, 3, 4, ...\n• Equal spaces to the left: -1, -2, -3, -4, ...\n• Between any two integers, you can place fractions: e.g., 1/2 is exactly halfway between 0 and 1\n• Between ANY two rational numbers, there is always another rational number — the number line is dense!',
                ),
              ],
              quiz: [
                QuizQuestion(
                  question: 'Which of these is NOT a natural number?',
                  options: ['1', '42', '0', '100'],
                  correctIndex: 2,
                  explanation:
                      'Natural numbers start from 1. Zero is a whole number but not a natural number (by the most common convention).',
                ),
                QuizQuestion(
                  question: 'Which number lies between -2 and -1 on the number line?',
                  options: ['-3', '-1.5', '0', '1.5'],
                  correctIndex: 1,
                  explanation:
                      '-1.5 is between -2 and -1 on the number line. It is greater than -2 and less than -1.',
                ),
                QuizQuestion(
                  question: 'The fraction 3/4 expressed as a decimal is:',
                  options: ['0.25', '0.34', '0.75', '1.33'],
                  correctIndex: 2,
                  explanation:
                      '3 ÷ 4 = 0.75. You can verify: 0.75 × 4 = 3.',
                ),
              ],
            ),

            // Lesson 2: Fractions & Decimals
            Lesson(
              id: 'math_fractions_decimals',
              title: 'Fractions & Decimals',
              description: 'Slice shapes to understand fractions visually',
              gameType: 'interactive',
              xpReward: 120,
              content: [
                LessonContent(
                  type: 'text',
                  title: 'What is a Fraction?',
                  body:
                      'A fraction represents a part of a whole. It is written as two numbers separated by a line: the numerator (top) tells how many parts we have, and the denominator (bottom) tells how many equal parts the whole is divided into. For example, 3/4 means we have 3 parts out of 4 equal parts. Fractions are one of the most important concepts in mathematics and appear everywhere in daily life.',
                ),
                LessonContent(
                  type: 'highlight',
                  title: 'Equivalent Fractions',
                  body:
                      'Equivalent fractions are different fractions that represent the same value. You get an equivalent fraction by multiplying or dividing both the numerator and denominator by the same non-zero number. For example: 1/2 = 2/4 = 3/6 = 50/100. The fraction 1/2 and the fraction 50/100 look different, but they represent exactly the same amount.',
                ),
                LessonContent(
                  type: 'code',
                  title: 'Fraction to Decimal Conversion',
                  body:
                      'To convert a fraction to a decimal, divide the\nnumerator by the denominator.\n\nExamples:\n• 1/2 = 1 ÷ 2 = 0.5\n• 1/4 = 1 ÷ 4 = 0.25\n• 3/8 = 3 ÷ 8 = 0.375\n• 1/3 = 1 ÷ 3 = 0.333... (repeating)\n• 2/3 = 2 ÷ 3 = 0.666... (repeating)\n\nTo convert back: 0.75 = 75/100 = 3/4',
                ),
                LessonContent(
                  type: 'example',
                  title: 'Pizza Fractions',
                  body:
                      'You have a pizza cut into 8 equal slices.\n\n• You eat 3 slices → You ate 3/8 of the pizza\n• Your friend eats 2 slices → They ate 2/8 = 1/4 of the pizza\n• Together you ate 3/8 + 2/8 = 5/8 of the pizza\n• Remaining: 8/8 - 5/8 = 3/8 of the pizza\n\nNotice: when adding fractions with the same denominator, just add the numerators!',
                ),
              ],
              quiz: [
                QuizQuestion(
                  question: 'Which fraction is equivalent to 2/5?',
                  options: ['4/10', '3/6', '2/10', '5/2'],
                  correctIndex: 0,
                  explanation:
                      '2/5 = (2×2)/(5×2) = 4/10. Multiply both numerator and denominator by 2.',
                ),
                QuizQuestion(
                  question: 'What is 3/4 + 1/4?',
                  options: ['4/8', '1', '3/4', '4/4'],
                  correctIndex: 1,
                  explanation:
                      '3/4 + 1/4 = 4/4 = 1. When denominators are the same, add the numerators: 3+1 = 4, and 4/4 = 1 whole.',
                ),
                QuizQuestion(
                  question: 'Convert the fraction 5/8 to a decimal:',
                  options: ['0.58', '0.625', '0.8', '0.525'],
                  correctIndex: 1,
                  explanation:
                      '5 ÷ 8 = 0.625. You can verify: 0.625 × 8 = 5.',
                ),
              ],
            ),
          ],
        ),

        // ── Chapter 2: Algebra Foundations (Intermediate) ──
        CourseChapter(
          id: 'math_algebra_foundations',
          title: 'Algebra Foundations',
          description: 'Intermediate: Learn the language of mathematics with variables and equations',
          lessons: [
            // Lesson 1: Variables & Expressions
            Lesson(
              id: 'math_variables_expressions',
              title: 'Variables & Expressions',
              description: 'Balance the equation by placing weights',
              gameType: 'interactive',
              xpReward: 130,
              content: [
                LessonContent(
                  type: 'text',
                  title: 'What is a Variable?',
                  body:
                      'A variable is a symbol (usually a letter like x, y, or n) that represents an unknown or changeable value. Variables are the foundation of algebra — they allow us to write general rules and formulas that work for many numbers at once. For instance, the area of any rectangle is A = l × w, where l and w are variables representing length and width.',
                ),
                LessonContent(
                  type: 'highlight',
                  title: 'Expressions vs Equations',
                  body:
                      'An algebraic expression is a combination of variables, numbers, and operations (like 3x + 5 or 2y² - 7). An equation is a statement that two expressions are equal (like 3x + 5 = 20). Expressions are simplified; equations are solved. The difference matters: you simplify expressions but solve equations to find the value of the variable.',
                ),
                LessonContent(
                  type: 'code',
                  title: 'Simplifying Expressions',
                  body:
                      'Combine like terms (same variable, same power):\n\n• 3x + 5x = 8x\n• 2y + 3 + 4y - 1 = 6y + 2\n• 5a² + 3a - 2a² + a = 3a² + 4a\n\nDistributive property:\n• 2(x + 3) = 2x + 6\n• -3(2y - 4) = -6y + 12\n\nRemember: you can only combine terms with\nthe same variable AND the same exponent.',
                ),
                LessonContent(
                  type: 'example',
                  title: 'Evaluating Expressions',
                  body:
                      'Evaluate 2x² + 3x - 5 when x = 4:\n\nStep 1: Substitute x = 4\n= 2(4)² + 3(4) - 5\n\nStep 2: Calculate powers first\n= 2(16) + 3(4) - 5\n\nStep 3: Multiply\n= 32 + 12 - 5\n\nStep 4: Add and subtract\n= 39\n\nSo when x = 4, the expression equals 39.',
                ),
              ],
              quiz: [
                QuizQuestion(
                  question: 'Simplify: 4x + 2x - 3x',
                  options: ['3x', '9x', '3x²', 'x'],
                  correctIndex: 0,
                  explanation:
                      'Combine like terms: 4x + 2x - 3x = (4 + 2 - 3)x = 3x.',
                ),
                QuizQuestion(
                  question: 'What is the value of 3a + 7 when a = 5?',
                  options: ['15', '22', '35', '12'],
                  correctIndex: 1,
                  explanation:
                      'Substitute a = 5: 3(5) + 7 = 15 + 7 = 22.',
                ),
                QuizQuestion(
                  question: 'Expand: 4(y - 2)',
                  options: ['4y - 2', '4y + 8', '4y - 8', 'y - 8'],
                  correctIndex: 2,
                  explanation:
                      'Apply the distributive property: 4(y - 2) = 4×y + 4×(-2) = 4y - 8.',
                ),
              ],
            ),

            // Lesson 2: Solving Linear Equations
            Lesson(
              id: 'math_linear_equations',
              title: 'Solving Linear Equations',
              description: 'Manipulate both sides to isolate x',
              gameType: 'interactive',
              xpReward: 150,
              content: [
                LessonContent(
                  type: 'text',
                  title: 'What is a Linear Equation?',
                  body:
                      'A linear equation is an equation where the highest power of the variable is 1. Examples include 2x + 5 = 11 and 3y - 7 = 2y + 1. The word "linear" comes from "line" — when you graph these equations, they produce straight lines. Solving a linear equation means finding the value of the variable that makes the equation true.',
                ),
                LessonContent(
                  type: 'highlight',
                  title: 'The Golden Rule of Equations',
                  body:
                      'Whatever you do to one side of an equation, you must do to the other side. This keeps the equation balanced. You can add, subtract, multiply, or divide both sides by the same number (except dividing by zero). The goal is to isolate the variable on one side of the equation.',
                ),
                LessonContent(
                  type: 'code',
                  title: 'Solving ax + b = c',
                  body:
                      'General strategy:\n1. Simplify each side if needed\n2. Move variable terms to one side\n3. Move constant terms to the other side\n4. Divide by the coefficient of the variable\n\nSolve 3x + 7 = 22:\n  3x + 7 = 22\n  3x = 22 - 7      (subtract 7 from both sides)\n  3x = 15\n  x = 15 / 3       (divide both sides by 3)\n  x = 5\n\nCheck: 3(5) + 7 = 15 + 7 = 22  ✓',
                ),
                LessonContent(
                  type: 'example',
                  title: 'Variables on Both Sides',
                  body:
                      'Solve 5x - 3 = 2x + 9:\n\nStep 1: Move variable terms to the left\n5x - 2x - 3 = 9\n3x - 3 = 9\n\nStep 2: Move constants to the right\n3x = 9 + 3\n3x = 12\n\nStep 3: Divide by coefficient\nx = 12 / 3 = 4\n\nCheck: 5(4) - 3 = 17, and 2(4) + 9 = 17 ✓',
                ),
              ],
              quiz: [
                QuizQuestion(
                  question: 'Solve: 2x + 6 = 14',
                  options: ['x = 3', 'x = 4', 'x = 10', 'x = 8'],
                  correctIndex: 1,
                  explanation:
                      '2x + 6 = 14 → 2x = 14 - 6 → 2x = 8 → x = 4.',
                ),
                QuizQuestion(
                  question: 'Solve: 5y - 10 = 3y + 4',
                  options: ['y = 7', 'y = -3', 'y = 3', 'y = 14'],
                  correctIndex: 0,
                  explanation:
                      '5y - 3y = 4 + 10 → 2y = 14 → y = 7.',
                ),
                QuizQuestion(
                  question: 'What is the first step in solving 4(x - 1) = 12?',
                  options: [
                    'Divide both sides by 4',
                    'Expand the brackets: 4x - 4 = 12',
                    'Subtract 1 from both sides',
                    'Add 4 to both sides',
                  ],
                  correctIndex: 1,
                  explanation:
                      'The first step is to expand (distribute) the brackets: 4(x - 1) = 4x - 4 = 12. Alternatively, you can divide both sides by 4 first, but expanding is the standard approach.',
                ),
              ],
            ),
          ],
        ),

        // ── Chapter 3: Calculus Fundamentals (College) ──
        CourseChapter(
          id: 'math_calculus',
          title: 'Calculus Fundamentals',
          description: 'College level: Unlock the mathematics of change and motion',
          lessons: [
            // Lesson 1: Introduction to Limits
            Lesson(
              id: 'math_limits',
              title: 'Introduction to Limits',
              description: 'Zoom in on curves to discover what limits really mean',
              gameType: 'simulation',
              xpReward: 160,
              content: [
                LessonContent(
                  type: 'text',
                  title: 'The Intuitive Idea of a Limit',
                  body:
                      'A limit describes the value that a function approaches as the input gets closer and closer to some value. Imagine walking toward a wall — you cover half the remaining distance each step. You never touch the wall, but you get infinitely close. The wall is your "limit". In calculus, limits let us study what happens at points where functions might not be directly computable, forming the foundation for derivatives and integrals.',
                ),
                LessonContent(
                  type: 'highlight',
                  title: 'Formal Definition',
                  body:
                      'We write lim(x→a) f(x) = L to mean: as x gets arbitrarily close to a (but not equal to a), f(x) gets arbitrarily close to L. Crucially, the function does not need to be defined at x = a, and even if it is, f(a) does not need to equal L. The limit is about the trend, not the actual value at the point.',
                ),
                LessonContent(
                  type: 'code',
                  title: 'Evaluating Limits',
                  body:
                      'Methods for evaluating limits:\n\n1. Direct substitution:\n   lim(x→3) (2x + 1) = 2(3) + 1 = 7\n\n2. Factoring (when direct substitution gives 0/0):\n   lim(x→2) (x² - 4)/(x - 2)\n   = lim(x→2) (x+2)(x-2)/(x-2)\n   = lim(x→2) (x+2) = 4\n\n3. Rationalization:\n   Multiply by conjugate for radical expressions\n\n4. L\'Hôpital\'s Rule (for 0/0 or ∞/∞):\n   lim(x→a) f(x)/g(x) = lim(x→a) f\'(x)/g\'(x)',
                ),
                LessonContent(
                  type: 'example',
                  title: 'Indeterminate Forms',
                  body:
                      'Some limits give forms like 0/0 or ∞/∞ on direct substitution. These are called indeterminate forms — they do not tell us the answer directly.\n\nExample: lim(x→0) sin(x)/x\nDirect substitution: sin(0)/0 = 0/0 (indeterminate!)\n\nUsing a table or L\'Hôpital\'s Rule:\nlim(x→0) sin(x)/x = lim(x→0) cos(x)/1 = cos(0) = 1\n\nThis famous limit equals 1, and it is fundamental to calculus.',
                ),
              ],
              quiz: [
                QuizQuestion(
                  question: 'What is lim(x→3) (x² - 9)/(x - 3)?',
                  options: ['0', '3', '6', 'undefined'],
                  correctIndex: 2,
                  explanation:
                      'Factor: (x²-9)/(x-3) = (x+3)(x-3)/(x-3) = x+3. At x→3: 3+3 = 6.',
                ),
                QuizQuestion(
                  question: 'If direct substitution gives 0/0, the limit is:',
                  options: [
                    'Always zero',
                    'Always undefined',
                    'An indeterminate form that needs more work',
                    'Always infinity',
                  ],
                  correctIndex: 2,
                  explanation:
                      '0/0 is an indeterminate form. You need techniques like factoring, rationalization, or L\'Hôpital\'s Rule to evaluate the actual limit.',
                ),
                QuizQuestion(
                  question: 'What is lim(x→5) (2x + 1)?',
                  options: ['10', '11', '5', '6'],
                  correctIndex: 1,
                  explanation:
                      'For a continuous function, use direct substitution: 2(5) + 1 = 11.',
                ),
              ],
            ),

            // Lesson 2: Derivatives — Rate of Change
            Lesson(
              id: 'math_derivatives',
              title: 'Derivatives — Rate of Change',
              description: 'Draw tangent lines and see how slopes change',
              gameType: 'simulation',
              xpReward: 170,
              content: [
                LessonContent(
                  type: 'text',
                  title: 'The Derivative as Slope',
                  body:
                      'The derivative of a function at a point tells you the slope of the tangent line at that point — in other words, the instantaneous rate of change. If a function represents position over time, the derivative gives velocity. If it represents cost over quantity, the derivative gives marginal cost. The derivative is defined as the limit of the difference quotient: f\'(x) = lim(h→0) [f(x+h) - f(x)] / h.',
                ),
                LessonContent(
                  type: 'code',
                  title: 'The Power Rule',
                  body:
                      'The Power Rule — the most used differentiation rule:\n\nIf f(x) = xⁿ, then f\'(x) = n × xⁿ⁻¹\n\nExamples:\n• f(x) = x³   → f\'(x) = 3x²\n• f(x) = x⁵   → f\'(x) = 5x⁴\n• f(x) = x     → f\'(x) = 1\n• f(x) = x⁻²  → f\'(x) = -2x⁻³\n• f(x) = √x = x^(1/2) → f\'(x) = (1/2)x^(-1/2)\n\nConstants: d/dx [c] = 0\nScalar multiple: d/dx [cf(x)] = c·f\'(x)',
                ),
                LessonContent(
                  type: 'highlight',
                  title: 'The Chain Rule — Intro',
                  body:
                      'The chain rule handles composite functions — functions inside functions. If y = f(g(x)), then dy/dx = f\'(g(x)) × g\'(x). Think of it as the "outer derivative times the inner derivative". For example, if y = (3x + 1)⁵, let u = 3x+1, so y = u⁵. Then dy/dx = 5u⁴ × 3 = 15(3x+1)⁴.',
                ),
                LessonContent(
                  type: 'example',
                  title: 'Worked Examples',
                  body:
                      'Example 1: Find the derivative of f(x) = 4x³ - 2x + 7\nf\'(x) = 12x² - 2\n(Apply power rule to each term; derivative of constant is 0)\n\nExample 2: Find the slope of f(x) = x² at x = 3\nf\'(x) = 2x\nf\'(3) = 2(3) = 6\nThe tangent line at x = 3 has slope 6.\n\nExample 3: Differentiate y = (2x - 5)⁴\nUsing chain rule: dy/dx = 4(2x - 5)³ × 2 = 8(2x - 5)³',
                ),
              ],
              quiz: [
                QuizQuestion(
                  question: 'What is the derivative of f(x) = x⁴?',
                  options: ['x³', '4x³', '4x⁴', 'x⁴'],
                  correctIndex: 1,
                  explanation:
                      'Using the power rule: d/dx [x⁴] = 4x³.',
                ),
                QuizQuestion(
                  question: 'The derivative of a function at a point represents:',
                  options: [
                    'The area under the curve',
                    'The slope of the tangent line (instantaneous rate of change)',
                    'The maximum value of the function',
                    'The y-intercept',
                  ],
                  correctIndex: 1,
                  explanation:
                      'The derivative at a point gives the slope of the tangent line at that point, which is the instantaneous rate of change of the function.',
                ),
                QuizQuestion(
                  question: 'Find the derivative of f(x) = 3x² + 5x - 8',
                  options: ['6x + 5', '3x + 5', '6x² + 5', '6x - 8'],
                  correctIndex: 0,
                  explanation:
                      'Apply the power rule term by term: d/dx[3x²] = 6x, d/dx[5x] = 5, d/dx[-8] = 0. So f\'(x) = 6x + 5.',
                ),
              ],
            ),
          ],
        ),
      ],
    ),

    // ── Coming Soon Subjects ───────────────────────────────────────────
    CourseSubject(
      id: 'ai',
      name: 'Artificial Intelligence',
      icon: 'ai',
      accentColor: Color(0xFF3B82F6),
      chapters: [],
      comingSoon: true,
    ),

    CourseSubject(
      id: 'dsa',
      name: 'Data Structures & Algorithms',
      icon: 'dsa',
      accentColor: Color(0xFF22C55E),
      chapters: [],
      comingSoon: true,
    ),

    CourseSubject(
      id: 'cyber',
      name: 'Cybersecurity',
      icon: 'cyber',
      accentColor: Color(0xFFEF4444),
      chapters: [],
      comingSoon: true,
    ),

    CourseSubject(
      id: 'chemistry',
      name: 'Chemistry',
      icon: 'chemistry',
      accentColor: Color(0xFFFF6B6B),
      chapters: [],
      comingSoon: true,
    ),

    CourseSubject(
      id: 'webdev',
      name: 'Web Development',
      icon: 'webdev',
      accentColor: Color(0xFFFF8C00),
      chapters: [],
      comingSoon: true,
    ),

    CourseSubject(
      id: 'ml',
      name: 'Machine Learning',
      icon: 'ml',
      accentColor: Color(0xFF39FF14),
      chapters: [],
      comingSoon: true,
    ),
  ];
}
