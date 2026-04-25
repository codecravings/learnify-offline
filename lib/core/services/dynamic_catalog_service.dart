import 'package:flutter/foundation.dart';

import '../ai/gemma_orchestrator.dart';

/// Session-scoped cache for subject suggestions + prerequisite edges.
///
/// Replaces `CourseData.allCourses` + `PrerequisiteGraph.concepts`. The data
/// is generated on-demand by the Gemma orchestrator and cached here so that
/// the home screen, courses screen, and concept map don't each re-invoke
/// Gemma every time they rebuild.
///
/// Callers that want fresh results after a new topic is studied should call
/// [invalidate] before their next read — `refresh` also invalidates.
class DynamicCatalogService {
  DynamicCatalogService._();
  static final DynamicCatalogService instance = DynamicCatalogService._();

  final _orchestrator = GemmaOrchestrator.instance;

  List<Map<String, dynamic>>? _cachedSubjects;
  Future<List<Map<String, dynamic>>>? _inflightSubjects;

  List<Map<String, dynamic>>? _cachedEdges;
  List<String>? _cachedEdgeTopics;
  Future<List<Map<String, dynamic>>>? _inflightEdges;

  /// 6–8 Gemma-suggested subject cards for the current profile.
  /// First call hits Gemma; subsequent calls return the cache until
  /// [invalidate] is called.
  Future<List<Map<String, dynamic>>> suggestedSubjects({
    bool force = false,
  }) async {
    if (force) invalidateSubjects();
    final cached = _cachedSubjects;
    if (cached != null) return cached;
    final inflight = _inflightSubjects;
    if (inflight != null) return inflight;

    final future = _orchestrator.suggestSubjects().then((list) {
      _cachedSubjects = list;
      _inflightSubjects = null;
      return list;
    }).catchError((e, st) {
      debugPrint('[DynamicCatalog] suggestedSubjects failed: $e');
      _inflightSubjects = null;
      return <Map<String, dynamic>>[];
    });
    _inflightSubjects = future;
    return future;
  }

  /// Prerequisite edges inferred between the given studied [topics].
  /// Caches by the *set* of topic names — if the set changes, re-infers.
  Future<List<Map<String, dynamic>>> prerequisiteEdges(
    List<String> topics, {
    bool force = false,
  }) async {
    final sorted = [...topics]..sort();
    final sameSet = _cachedEdgeTopics != null &&
        listEquals(sorted, _cachedEdgeTopics);
    if (force || !sameSet) {
      _cachedEdges = null;
      _cachedEdgeTopics = null;
    }
    final cached = _cachedEdges;
    if (cached != null) return cached;
    final inflight = _inflightEdges;
    if (inflight != null) return inflight;

    final future = _orchestrator.inferPrerequisites(sorted).then((list) {
      _cachedEdges = list;
      _cachedEdgeTopics = sorted;
      _inflightEdges = null;
      return list;
    }).catchError((e, st) {
      debugPrint('[DynamicCatalog] prerequisiteEdges failed: $e');
      _inflightEdges = null;
      return <Map<String, dynamic>>[];
    });
    _inflightEdges = future;
    return future;
  }

  void invalidateSubjects() {
    _cachedSubjects = null;
    _inflightSubjects = null;
  }

  void invalidateEdges() {
    _cachedEdges = null;
    _cachedEdgeTopics = null;
    _inflightEdges = null;
  }

  void invalidate() {
    invalidateSubjects();
    invalidateEdges();
  }
}
