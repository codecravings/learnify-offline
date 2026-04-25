// ─────────────────────────────────────────────────────────────────────────────
// Prerequisite Knowledge Graph — types + (empty) static concept list.
//
// The previously-hardcoded Physics / Math / AI concept inventory has been
// removed. The concept map screen now pulls nodes from the learner's actual
// topic history (via LocalMemoryService) and asks Gemma to infer edges.
// Types and traversal helpers stay in case a future feature repopulates
// `concepts`, so existing widget code (concept_detail_sheet, prerequisite_
// chain_widget, concept_node_painter) keeps compiling.
// ─────────────────────────────────────────────────────────────────────────────

/// A single concept node in the prerequisite knowledge graph.
class ConceptNode {
  final String id;
  final String name;
  final String subject;
  final String description;
  final List<String> prerequisiteIds;
  final List<String> relatedIds;
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

/// Graph helpers. With the hardcoded concept list removed, most getters now
/// return empty results until a caller populates the graph from a dynamic
/// source. Rather than special-case that, we keep the API shape so callers
/// that treat absence as "unknown" (not an error) still work.
class PrerequisiteGraph {
  PrerequisiteGraph._();

  static const List<ConceptNode> concepts = [];

  static final Map<String, ConceptNode> _byId = {
    for (final c in concepts) c.id: c,
  };

  static Set<String> get allIds => _byId.keys.toSet();

  static ConceptNode? getById(String id) => _byId[id];

  static List<ConceptNode> getBySubject(String subject) =>
      concepts.where((c) => c.subject == subject).toList();

  static List<ConceptNode> getPrerequisites(String conceptId) {
    final node = _byId[conceptId];
    if (node == null) return const [];
    return node.prerequisiteIds
        .map((id) => _byId[id])
        .whereType<ConceptNode>()
        .toList();
  }

  static List<ConceptNode> getPrerequisiteChain(String conceptId) {
    final result = <ConceptNode>[];
    final visited = <String>{};
    final queue = <String>[conceptId];
    while (queue.isNotEmpty) {
      final id = queue.removeAt(0);
      if (!visited.add(id)) continue;
      final node = _byId[id];
      if (node == null) continue;
      for (final pid in node.prerequisiteIds) {
        final p = _byId[pid];
        if (p != null && visited.add(pid)) {
          result.add(p);
          queue.add(pid);
        }
      }
    }
    return result;
  }

  static List<ConceptNode> getDependents(String conceptId) {
    return concepts.where((c) => c.prerequisiteIds.contains(conceptId)).toList();
  }

  static List<ConceptNode> findMissingPrerequisites(
    String conceptId,
    Set<String> masteredIds,
  ) {
    return getPrerequisiteChain(conceptId)
        .where((c) => !masteredIds.contains(c.id))
        .toList();
  }

  static List<ConceptNode> getRootCauses(
    String failedConceptId,
    Map<String, double> accuracyByConceptId,
  ) {
    final chain = getPrerequisiteChain(failedConceptId);
    final weak = chain
        .where((c) => (accuracyByConceptId[c.id] ?? 0) < 60)
        .toList();
    weak.sort((a, b) => a.prerequisiteIds.length
        .compareTo(b.prerequisiteIds.length));
    return weak;
  }

  static ConceptNode? findConceptForTopic(String topicName) {
    final words = _extractWords(topicName.toLowerCase());
    ConceptNode? best;
    int bestScore = 0;
    for (final c in concepts) {
      final nodeWords = _extractWords(c.name.toLowerCase());
      final overlap = words.intersection(nodeWords).length;
      if (overlap > bestScore) {
        bestScore = overlap;
        best = c;
      }
    }
    return best;
  }

  static List<ConceptNode> buildStudyPath(
    String targetId,
    Map<String, double> accuracyByConceptId,
  ) {
    final chain = getPrerequisiteChain(targetId);
    chain.sort((a, b) => a.prerequisiteIds.length
        .compareTo(b.prerequisiteIds.length));
    return chain
        .where((c) => (accuracyByConceptId[c.id] ?? 0) < 75)
        .toList();
  }

  static List<(ConceptNode, ConceptNode)> getCrossSubjectLinks() {
    final links = <(ConceptNode, ConceptNode)>[];
    for (final c in concepts) {
      for (final relatedId in c.relatedIds) {
        final related = _byId[relatedId];
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
