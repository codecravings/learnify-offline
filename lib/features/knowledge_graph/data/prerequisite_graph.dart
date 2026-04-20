// ──────────────────���─────────────────────────���────────────────────────────────
// Prerequisite Knowledge Graph — Static concept dependency data for Physics & Math
// ───────────────────────────���────────────────────────────��────────────────────

/// A single concept node in the prerequisite knowledge graph.
class ConceptNode {
  final String id;
  final String name;
  final String subject; // 'physics', 'math'
  final String description;
  final List<String> prerequisiteIds;
  final List<String> relatedIds; // cross-subject links
  final String difficulty; // 'foundational', 'intermediate', 'advanced'

  const ConceptNode({
    required this.id,
    required this.name,
    required this.subject,
    required this.description,
    this.prerequisiteIds = const [],
    this.relatedIds = const [],
    this.difficulty = 'intermediate',
  });
}

/// Static prerequisite graph with traversal utilities.
class PrerequisiteGraph {
  PrerequisiteGraph._();

  // ═══════════════════════════════════════════════════════════════════════════
  // Concept Node Data
  // ═��═════════════════════════════════════════════════════════════════════════

  static final List<ConceptNode> concepts = [
    // ── Math: Foundational ──────────────────────────────────────────────────
    const ConceptNode(
      id: 'math_arithmetic',
      name: 'Arithmetic',
      subject: 'math',
      description: 'Basic operations: addition, subtraction, multiplication, division, order of operations.',
      difficulty: 'foundational',
    ),
    const ConceptNode(
      id: 'math_number_systems',
      name: 'Number Systems',
      subject: 'math',
      description: 'Natural, whole, integer, rational, irrational, and real numbers.',
      prerequisiteIds: ['math_arithmetic'],
      difficulty: 'foundational',
    ),
    const ConceptNode(
      id: 'math_algebra',
      name: 'Algebra',
      subject: 'math',
      description: 'Variables, expressions, equations, polynomials, factoring.',
      prerequisiteIds: ['math_arithmetic', 'math_number_systems'],
      difficulty: 'foundational',
    ),
    const ConceptNode(
      id: 'math_linear_equations',
      name: 'Linear Equations',
      subject: 'math',
      description: 'Solving linear equations and inequalities, graphing lines, slope-intercept form.',
      prerequisiteIds: ['math_algebra'],
      difficulty: 'foundational',
    ),
    const ConceptNode(
      id: 'math_quadratic_equations',
      name: 'Quadratic Equations',
      subject: 'math',
      description: 'Factoring, completing the square, quadratic formula, discriminant.',
      prerequisiteIds: ['math_algebra'],
      difficulty: 'intermediate',
    ),

    // ── Math: Geometry & Coordinate ─────���───────────────────────────────────
    const ConceptNode(
      id: 'math_geometry_basics',
      name: 'Geometry Basics',
      subject: 'math',
      description: 'Points, lines, angles, triangles, circles, area, perimeter.',
      prerequisiteIds: ['math_arithmetic'],
      difficulty: 'foundational',
    ),
    const ConceptNode(
      id: 'math_coordinate_geometry',
      name: 'Coordinate Geometry',
      subject: 'math',
      description: 'Cartesian plane, distance formula, section formula, area of triangles.',
      prerequisiteIds: ['math_algebra', 'math_geometry_basics'],
      difficulty: 'intermediate',
    ),
    const ConceptNode(
      id: 'math_trigonometry',
      name: 'Trigonometry',
      subject: 'math',
      description: 'Sine, cosine, tangent, identities, equations, inverse trig functions.',
      prerequisiteIds: ['math_geometry_basics', 'math_algebra'],
      relatedIds: ['phys_oscillations'],
      difficulty: 'intermediate',
    ),

    // ── Math: Vectors & Matrices ─────────��──────────────────────────────��───
    const ConceptNode(
      id: 'math_vectors',
      name: 'Vectors',
      subject: 'math',
      description: 'Vector algebra, dot product, cross product, scalar and vector quantities.',
      prerequisiteIds: ['math_trigonometry', 'math_coordinate_geometry'],
      relatedIds: ['phys_vectors_scalars'],
      difficulty: 'intermediate',
    ),
    const ConceptNode(
      id: 'math_matrices',
      name: 'Matrices & Determinants',
      subject: 'math',
      description: 'Matrix operations, determinants, inverse, system of equations.',
      prerequisiteIds: ['math_algebra', 'math_linear_equations'],
      difficulty: 'intermediate',
    ),

    // ── Math: Functions & Calculus ───────────────────────────────────────────
    const ConceptNode(
      id: 'math_functions',
      name: 'Functions',
      subject: 'math',
      description: 'Domain, range, composition, types of functions, graphing.',
      prerequisiteIds: ['math_algebra', 'math_coordinate_geometry'],
      difficulty: 'intermediate',
    ),
    const ConceptNode(
      id: 'math_limits',
      name: 'Limits & Continuity',
      subject: 'math',
      description: 'Limit evaluation, L\'Hôpital\'s rule, continuity, indeterminate forms.',
      prerequisiteIds: ['math_functions'],
      difficulty: 'intermediate',
    ),
    const ConceptNode(
      id: 'math_derivatives',
      name: 'Derivatives',
      subject: 'math',
      description: 'Differentiation rules, chain rule, implicit, applications (maxima/minima, rate of change).',
      prerequisiteIds: ['math_limits', 'math_trigonometry'],
      relatedIds: ['phys_kinematics'],
      difficulty: 'advanced',
    ),
    const ConceptNode(
      id: 'math_integration',
      name: 'Integration',
      subject: 'math',
      description: 'Indefinite/definite integrals, techniques (substitution, parts), area under curves.',
      prerequisiteIds: ['math_derivatives'],
      relatedIds: ['phys_work_energy'],
      difficulty: 'advanced',
    ),
    const ConceptNode(
      id: 'math_differential_equations',
      name: 'Differential Equations',
      subject: 'math',
      description: 'ODE formation, variable separable, linear first-order, applications.',
      prerequisiteIds: ['math_integration'],
      difficulty: 'advanced',
    ),

    // ── Math: Probability & Statistics ──────────────────────────────────────
    const ConceptNode(
      id: 'math_probability',
      name: 'Probability',
      subject: 'math',
      description: 'Events, conditional probability, Bayes theorem, distributions.',
      prerequisiteIds: ['math_algebra', 'math_number_systems'],
      difficulty: 'intermediate',
    ),
    const ConceptNode(
      id: 'math_statistics',
      name: 'Statistics',
      subject: 'math',
      description: 'Mean, median, mode, variance, standard deviation, data analysis.',
      prerequisiteIds: ['math_arithmetic', 'math_probability'],
      difficulty: 'intermediate',
    ),

    // ── Physics: Foundational ────────���─────────────────────────────��────────
    const ConceptNode(
      id: 'phys_units_measurements',
      name: 'Units & Measurements',
      subject: 'physics',
      description: 'SI units, dimensional analysis, significant figures, error analysis.',
      difficulty: 'foundational',
    ),
    const ConceptNode(
      id: 'phys_vectors_scalars',
      name: 'Vectors & Scalars',
      subject: 'physics',
      description: 'Vector addition, resolution, components, unit vectors.',
      prerequisiteIds: ['phys_units_measurements'],
      relatedIds: ['math_vectors', 'math_trigonometry'],
      difficulty: 'foundational',
    ),

    // ── Physics: Mechanics ─────��────────────────────────────────────────────
    const ConceptNode(
      id: 'phys_kinematics',
      name: 'Kinematics',
      subject: 'physics',
      description: 'Motion in 1D/2D, equations of motion, projectile motion, relative motion.',
      prerequisiteIds: ['phys_vectors_scalars'],
      relatedIds: ['math_derivatives'],
      difficulty: 'foundational',
    ),
    const ConceptNode(
      id: 'phys_newtons_laws',
      name: 'Newton\'s Laws',
      subject: 'physics',
      description: 'Three laws of motion, free-body diagrams, friction, tension, normal force.',
      prerequisiteIds: ['phys_kinematics', 'phys_vectors_scalars'],
      difficulty: 'intermediate',
    ),
    const ConceptNode(
      id: 'phys_work_energy',
      name: 'Work-Energy Theorem',
      subject: 'physics',
      description: 'Work done, kinetic/potential energy, work-energy theorem, power.',
      prerequisiteIds: ['phys_newtons_laws'],
      relatedIds: ['math_integration'],
      difficulty: 'intermediate',
    ),
    const ConceptNode(
      id: 'phys_energy_conservation',
      name: 'Energy Conservation',
      subject: 'physics',
      description: 'Conservation of energy, conservative forces, potential energy curves.',
      prerequisiteIds: ['phys_work_energy'],
      difficulty: 'intermediate',
    ),
    const ConceptNode(
      id: 'phys_momentum',
      name: 'Momentum & Collisions',
      subject: 'physics',
      description: 'Linear momentum, impulse, conservation of momentum, elastic/inelastic collisions.',
      prerequisiteIds: ['phys_newtons_laws'],
      difficulty: 'intermediate',
    ),
    const ConceptNode(
      id: 'phys_rotational_motion',
      name: 'Rotational Motion',
      subject: 'physics',
      description: 'Angular velocity, torque, moment of inertia, angular momentum.',
      prerequisiteIds: ['phys_newtons_laws', 'phys_work_energy'],
      relatedIds: ['math_trigonometry'],
      difficulty: 'advanced',
    ),
    const ConceptNode(
      id: 'phys_gravitation',
      name: 'Gravitation',
      subject: 'physics',
      description: 'Newton\'s law of gravitation, orbital mechanics, escape velocity, Kepler\'s laws.',
      prerequisiteIds: ['phys_newtons_laws', 'phys_energy_conservation'],
      difficulty: 'advanced',
    ),

    // ── Physics: Thermodynamics ──���──────────────────────────────────────────
    const ConceptNode(
      id: 'phys_thermal_properties',
      name: 'Thermal Properties',
      subject: 'physics',
      description: 'Temperature, heat, specific heat, calorimetry, thermal expansion.',
      prerequisiteIds: ['phys_units_measurements'],
      difficulty: 'foundational',
    ),
    const ConceptNode(
      id: 'phys_kinetic_theory',
      name: 'Kinetic Theory of Gases',
      subject: 'physics',
      description: 'Ideal gas law, kinetic energy of molecules, degrees of freedom.',
      prerequisiteIds: ['phys_thermal_properties', 'phys_newtons_laws'],
      relatedIds: ['math_probability'],
      difficulty: 'intermediate',
    ),
    const ConceptNode(
      id: 'phys_thermodynamics',
      name: 'Thermodynamics',
      subject: 'physics',
      description: 'Laws of thermodynamics, heat engines, entropy, Carnot cycle.',
      prerequisiteIds: ['phys_energy_conservation', 'phys_kinetic_theory'],
      difficulty: 'advanced',
    ),

    // ── Physics: Waves & Oscillations ───���───────────────────────────────────
    const ConceptNode(
      id: 'phys_oscillations',
      name: 'Oscillations (SHM)',
      subject: 'physics',
      description: 'Simple harmonic motion, pendulum, spring, energy in SHM, damping.',
      prerequisiteIds: ['phys_newtons_laws', 'phys_energy_conservation'],
      relatedIds: ['math_trigonometry', 'math_derivatives'],
      difficulty: 'intermediate',
    ),
    const ConceptNode(
      id: 'phys_waves',
      name: 'Wave Properties',
      subject: 'physics',
      description: 'Transverse/longitudinal waves, speed, frequency, wavelength, superposition.',
      prerequisiteIds: ['phys_oscillations'],
      difficulty: 'intermediate',
    ),
    const ConceptNode(
      id: 'phys_sound',
      name: 'Sound Waves',
      subject: 'physics',
      description: 'Speed of sound, resonance, beats, Doppler effect, standing waves.',
      prerequisiteIds: ['phys_waves'],
      difficulty: 'intermediate',
    ),

    // ── Physics: Optics ─────────────────────────────────────────────────────
    const ConceptNode(
      id: 'phys_ray_optics',
      name: 'Ray Optics',
      subject: 'physics',
      description: 'Reflection, refraction, Snell\'s law, lenses, mirrors, optical instruments.',
      prerequisiteIds: ['phys_waves'],
      relatedIds: ['math_geometry_basics'],
      difficulty: 'intermediate',
    ),
    const ConceptNode(
      id: 'phys_wave_optics',
      name: 'Wave Optics',
      subject: 'physics',
      description: 'Interference, diffraction, Young\'s double slit, polarization.',
      prerequisiteIds: ['phys_waves', 'phys_ray_optics'],
      difficulty: 'advanced',
    ),

    // ── Physics: Electricity ────────���───────────────────────────────────────
    const ConceptNode(
      id: 'phys_electric_charge',
      name: 'Electric Charge & Field',
      subject: 'physics',
      description: 'Coulomb\'s law, electric field, field lines, dipoles, Gauss\'s law.',
      prerequisiteIds: ['phys_vectors_scalars'],
      relatedIds: ['math_integration'],
      difficulty: 'intermediate',
    ),
    const ConceptNode(
      id: 'phys_electric_potential',
      name: 'Electric Potential',
      subject: 'physics',
      description: 'Potential energy, voltage, equipotential surfaces, capacitance.',
      prerequisiteIds: ['phys_electric_charge', 'phys_energy_conservation'],
      difficulty: 'intermediate',
    ),
    const ConceptNode(
      id: 'phys_current_electricity',
      name: 'Current Electricity',
      subject: 'physics',
      description: 'Ohm\'s law, resistance, circuits, Kirchhoff\'s laws, Wheatstone bridge.',
      prerequisiteIds: ['phys_electric_potential'],
      difficulty: 'intermediate',
    ),

    // ── Physics: Magnetism ────���─────────────────────────────────────────────
    const ConceptNode(
      id: 'phys_magnetic_fields',
      name: 'Magnetic Fields',
      subject: 'physics',
      description: 'Biot-Savart law, Ampere\'s law, magnetic force, moving charges in fields.',
      prerequisiteIds: ['phys_current_electricity', 'phys_vectors_scalars'],
      difficulty: 'advanced',
    ),
    const ConceptNode(
      id: 'phys_electromagnetic_induction',
      name: 'Electromagnetic Induction',
      subject: 'physics',
      description: 'Faraday\'s law, Lenz\'s law, self/mutual inductance, AC generator.',
      prerequisiteIds: ['phys_magnetic_fields'],
      relatedIds: ['math_derivatives'],
      difficulty: 'advanced',
    ),
    const ConceptNode(
      id: 'phys_ac_circuits',
      name: 'AC Circuits',
      subject: 'physics',
      description: 'AC voltage/current, impedance, resonance, transformers, power.',
      prerequisiteIds: ['phys_electromagnetic_induction', 'phys_current_electricity'],
      relatedIds: ['math_trigonometry'],
      difficulty: 'advanced',
    ),

    // ── Physics: Modern Physics ─���───────────────────────────────────────────
    const ConceptNode(
      id: 'phys_dual_nature',
      name: 'Dual Nature of Matter',
      subject: 'physics',
      description: 'Photoelectric effect, de Broglie wavelength, wave-particle duality.',
      prerequisiteIds: ['phys_wave_optics', 'phys_energy_conservation'],
      difficulty: 'advanced',
    ),
    const ConceptNode(
      id: 'phys_atoms_nuclei',
      name: 'Atoms & Nuclei',
      subject: 'physics',
      description: 'Bohr model, hydrogen spectrum, radioactivity, nuclear reactions, binding energy.',
      prerequisiteIds: ['phys_dual_nature', 'phys_electric_potential'],
      difficulty: 'advanced',
    ),

    // ── AI/ML: Foundational ────────────────────────────────────────────────
    const ConceptNode(
      id: 'ai_python_basics',
      name: 'Python Basics',
      subject: 'ai_ml',
      description: 'Variables, loops, functions, data types, libraries (NumPy, Pandas).',
      difficulty: 'foundational',
    ),
    const ConceptNode(
      id: 'ai_linear_algebra',
      name: 'Linear Algebra for ML',
      subject: 'ai_ml',
      description: 'Vectors, matrices, dot product, eigenvalues, matrix transformations.',
      prerequisiteIds: ['math_algebra'],
      relatedIds: ['math_linear_equations'],
      difficulty: 'foundational',
    ),
    const ConceptNode(
      id: 'ai_statistics',
      name: 'Statistics & Probability',
      subject: 'ai_ml',
      description: 'Mean, variance, distributions, Bayes theorem, hypothesis testing.',
      prerequisiteIds: ['math_arithmetic'],
      difficulty: 'foundational',
    ),
    const ConceptNode(
      id: 'ai_data_preprocessing',
      name: 'Data Preprocessing',
      subject: 'ai_ml',
      description: 'Cleaning, normalization, feature scaling, encoding, train-test split.',
      prerequisiteIds: ['ai_python_basics', 'ai_statistics'],
      difficulty: 'foundational',
    ),

    // ── AI/ML: Intermediate ────────────────────────────────────────────────
    const ConceptNode(
      id: 'ai_linear_regression',
      name: 'Linear Regression',
      subject: 'ai_ml',
      description: 'Simple & multiple regression, cost function, gradient descent, R-squared.',
      prerequisiteIds: ['ai_linear_algebra', 'ai_statistics', 'ai_data_preprocessing'],
      difficulty: 'intermediate',
    ),
    const ConceptNode(
      id: 'ai_logistic_regression',
      name: 'Logistic Regression',
      subject: 'ai_ml',
      description: 'Binary classification, sigmoid function, decision boundary, cross-entropy loss.',
      prerequisiteIds: ['ai_linear_regression'],
      difficulty: 'intermediate',
    ),
    const ConceptNode(
      id: 'ai_decision_trees',
      name: 'Decision Trees',
      subject: 'ai_ml',
      description: 'Entropy, information gain, pruning, random forests, ensemble methods.',
      prerequisiteIds: ['ai_data_preprocessing', 'ai_statistics'],
      difficulty: 'intermediate',
    ),
    const ConceptNode(
      id: 'ai_svm',
      name: 'Support Vector Machines',
      subject: 'ai_ml',
      description: 'Hyperplanes, margin maximization, kernel trick, soft margin classification.',
      prerequisiteIds: ['ai_linear_algebra', 'ai_logistic_regression'],
      difficulty: 'intermediate',
    ),
    const ConceptNode(
      id: 'ai_clustering',
      name: 'Clustering',
      subject: 'ai_ml',
      description: 'K-means, DBSCAN, hierarchical clustering, silhouette score.',
      prerequisiteIds: ['ai_linear_algebra', 'ai_data_preprocessing'],
      difficulty: 'intermediate',
    ),
    const ConceptNode(
      id: 'ai_evaluation',
      name: 'Model Evaluation',
      subject: 'ai_ml',
      description: 'Accuracy, precision, recall, F1, ROC-AUC, confusion matrix, cross-validation.',
      prerequisiteIds: ['ai_logistic_regression'],
      difficulty: 'intermediate',
    ),

    // ── AI/ML: Advanced (Deep Learning) ────────────────────────────────────
    const ConceptNode(
      id: 'ai_neural_networks',
      name: 'Neural Networks',
      subject: 'ai_ml',
      description: 'Perceptron, activation functions, backpropagation, gradient descent, MLP.',
      prerequisiteIds: ['ai_linear_regression', 'ai_logistic_regression', 'ai_linear_algebra'],
      difficulty: 'advanced',
    ),
    const ConceptNode(
      id: 'ai_cnn',
      name: 'CNNs (Computer Vision)',
      subject: 'ai_ml',
      description: 'Convolution, pooling, filters, image classification, transfer learning.',
      prerequisiteIds: ['ai_neural_networks'],
      difficulty: 'advanced',
    ),
    const ConceptNode(
      id: 'ai_rnn',
      name: 'RNNs & LSTMs',
      subject: 'ai_ml',
      description: 'Sequential data, vanishing gradient, LSTM gates, text and time series.',
      prerequisiteIds: ['ai_neural_networks'],
      difficulty: 'advanced',
    ),
    const ConceptNode(
      id: 'ai_transformers',
      name: 'Transformers & LLMs',
      subject: 'ai_ml',
      description: 'Self-attention, multi-head attention, BERT, GPT, tokenization, fine-tuning.',
      prerequisiteIds: ['ai_rnn', 'ai_neural_networks'],
      difficulty: 'advanced',
    ),
    const ConceptNode(
      id: 'ai_generative',
      name: 'Generative AI',
      subject: 'ai_ml',
      description: 'GANs, VAEs, diffusion models, prompt engineering, RLHF.',
      prerequisiteIds: ['ai_transformers', 'ai_cnn'],
      difficulty: 'advanced',
    ),
    const ConceptNode(
      id: 'ai_reinforcement',
      name: 'Reinforcement Learning',
      subject: 'ai_ml',
      description: 'Markov decision process, Q-learning, policy gradient, reward shaping.',
      prerequisiteIds: ['ai_neural_networks', 'ai_statistics'],
      difficulty: 'advanced',
    ),
  ];

  // ═══════════════════════════════════════════════════════════════════════════
  // Lookup Helpers
  // ══════���══════════════════════════════════════════════════��═════════════════

  static final Map<String, ConceptNode> _byId = {
    for (final c in concepts) c.id: c,
  };

  /// All concept IDs.
  static Set<String> get allIds => _byId.keys.toSet();

  /// Get a concept by ID. Returns null if not found.
  static ConceptNode? getById(String id) => _byId[id];

  /// Get all concepts for a subject.
  static List<ConceptNode> getBySubject(String subject) =>
      concepts.where((c) => c.subject == subject).toList();

  // ═���═══════════════════════��══════════════════════════════��══════════════════
  // Graph Traversal
  // ═══════════════════════════════════════════════════════���═══════════════════

  /// Direct prerequisites of a concept.
  static List<ConceptNode> getPrerequisites(String conceptId) {
    final node = _byId[conceptId];
    if (node == null) return [];
    return node.prerequisiteIds
        .map((id) => _byId[id])
        .whereType<ConceptNode>()
        .toList();
  }

  /// Full prerequisite chain (BFS) — all ancestors from root to this concept.
  /// Returns list ordered from deepest prerequisite (root) to direct parent.
  static List<ConceptNode> getPrerequisiteChain(String conceptId) {
    final visited = <String>{};
    final chain = <ConceptNode>[];
    final queue = <String>[conceptId];

    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      final node = _byId[current];
      if (node == null) continue;

      for (final prereqId in node.prerequisiteIds) {
        if (!visited.contains(prereqId)) {
          visited.add(prereqId);
          final prereq = _byId[prereqId];
          if (prereq != null) {
            chain.add(prereq);
            queue.add(prereqId);
          }
        }
      }
    }

    // Reverse so roots come first
    return chain.reversed.toList();
  }

  /// Find concepts that depend on this concept (children in the graph).
  static List<ConceptNode> getDependents(String conceptId) {
    return concepts
        .where((c) => c.prerequisiteIds.contains(conceptId))
        .toList();
  }

  /// Find missing prerequisites: concepts in the chain that the student
  /// hasn't mastered (not in masteredIds set).
  static List<ConceptNode> findMissingPrerequisites(
    String conceptId,
    Set<String> masteredIds,
  ) {
    final chain = getPrerequisiteChain(conceptId);
    return chain.where((c) => !masteredIds.contains(c.id)).toList();
  }

  /// Root cause analysis: find the deepest prerequisite with low accuracy.
  /// Returns concepts ordered by depth (deepest gap first = root cause).
  static List<ConceptNode> getRootCauses(
    String failedConceptId,
    Map<String, double> accuracyMap,
  ) {
    final chain = getPrerequisiteChain(failedConceptId);
    final weakConcepts = <ConceptNode>[];

    for (final concept in chain) {
      final accuracy = accuracyMap[concept.id] ??
          accuracyMap[concept.name.toLowerCase()] ??
          -1; // -1 = never studied
      if (accuracy < 70) {
        weakConcepts.add(concept);
      }
    }

    // Already ordered root-first from getPrerequisiteChain
    return weakConcepts;
  }

  /// Fuzzy-match a topic name to a concept node.
  /// Tries exact match, then contains match, then word overlap.
  static ConceptNode? findConceptForTopic(String topicName) {
    final lower = topicName.toLowerCase().trim();

    // 1. Exact name match
    for (final c in concepts) {
      if (c.name.toLowerCase() == lower) return c;
    }

    // 2. Name contains topic or topic contains name
    for (final c in concepts) {
      final cLower = c.name.toLowerCase();
      if (cLower.contains(lower) || lower.contains(cLower)) return c;
    }

    // 3. Word overlap scoring
    final topicWords = _extractWords(lower);
    ConceptNode? best;
    int bestScore = 0;

    for (final c in concepts) {
      final conceptWords = _extractWords(c.name.toLowerCase());
      final descWords = _extractWords(c.description.toLowerCase());
      int score = 0;
      for (final tw in topicWords) {
        if (conceptWords.contains(tw)) score += 3;
        if (descWords.contains(tw)) score += 1;
      }
      if (score > bestScore) {
        bestScore = score;
        best = c;
      }
    }

    return bestScore >= 2 ? best : null;
  }

  /// Build the recommended study path: from root cause → target concept.
  static List<ConceptNode> buildStudyPath(
    String targetConceptId,
    Map<String, double> accuracyMap,
  ) {
    final chain = getPrerequisiteChain(targetConceptId);
    final target = _byId[targetConceptId];
    final path = <ConceptNode>[];

    for (final concept in chain) {
      final accuracy = accuracyMap[concept.id] ??
          accuracyMap[concept.name.toLowerCase()] ??
          -1;
      if (accuracy < 80) {
        path.add(concept);
      }
    }

    // Add the target itself if not mastered
    if (target != null) {
      final targetAcc = accuracyMap[target.id] ??
          accuracyMap[target.name.toLowerCase()] ??
          0;
      if (targetAcc < 80) path.add(target);
    }

    return path;
  }

  /// Get all cross-subject relationships as (source, target) pairs.
  static List<(ConceptNode, ConceptNode)> getCrossSubjectLinks() {
    final links = <(ConceptNode, ConceptNode)>[];
    for (final c in concepts) {
      for (final relId in c.relatedIds) {
        final related = _byId[relId];
        if (related != null && related.subject != c.subject) {
          links.add((c, related));
        }
      }
    }
    return links;
  }

  static Set<String> _extractWords(String text) {
    return text
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 2)
        .toSet();
  }
}
