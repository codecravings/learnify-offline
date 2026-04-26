import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// One character inside a franchise persona.
class FranchisePersona {
  const FranchisePersona({
    required this.name,
    required this.role,
    required this.traits,
    required this.speechStyle,
    required this.humorStyle,
    required this.emotionalStyle,
    required this.teachingStyle,
    required this.sampleDialogues,
  });

  final String name;
  final String role;
  final List<String> traits;
  final String speechStyle;
  final String humorStyle;
  final String emotionalStyle;
  final String teachingStyle;
  final List<String> sampleDialogues;

  factory FranchisePersona.fromJson(Map<String, dynamic> j) => FranchisePersona(
        name: j['name'] as String? ?? 'character',
        role: j['role'] as String? ?? '',
        traits: (j['traits'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        speechStyle: j['speech_style'] as String? ?? '',
        humorStyle: j['humor_style'] as String? ?? '',
        emotionalStyle: j['emotional_style'] as String? ?? '',
        teachingStyle: j['teaching_style'] as String? ?? '',
        sampleDialogues:
            (j['sample_dialogues'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      );
}

/// One franchise entry.
class Franchise {
  const Franchise({
    required this.id,
    required this.name,
    required this.category,
    required this.characters,
  });

  final String id;
  final String name;
  final String category; // 'anime' | 'cartoons' | 'live_action' | 'movies' | 'indian'
  final List<FranchisePersona> characters;

  factory Franchise.fromJson(Map<String, dynamic> j) => Franchise(
        id: j['id'] as String,
        name: j['name'] as String,
        category: j['category'] as String? ?? 'misc',
        characters: (j['characters'] as List?)
                ?.map((e) => FranchisePersona.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
      );
}

/// Loads `assets/data/franchises.json` once and serves it from memory.
/// Lookup by name is case-insensitive and tolerant of whitespace + partial matches.
class FranchiseLoader {
  FranchiseLoader._();
  static final FranchiseLoader instance = FranchiseLoader._();

  List<Franchise>? _cache;
  Future<List<Franchise>>? _inflight;

  Future<List<Franchise>> all() {
    final cached = _cache;
    if (cached != null) return Future.value(cached);
    final inflight = _inflight;
    if (inflight != null) return inflight;
    final future = _load();
    _inflight = future;
    return future;
  }

  Future<List<Franchise>> _load() async {
    final raw = await rootBundle.loadString('assets/data/franchises.json');
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final list = (decoded['franchises'] as List)
        .map((e) => Franchise.fromJson(e as Map<String, dynamic>))
        .toList();
    _cache = list;
    _inflight = null;
    return list;
  }

  /// Find by display name. First exact (case-insensitive) match, then a
  /// substring match, else null. Trims whitespace defensively.
  Future<Franchise?> findByName(String name) async {
    final query = name.trim().toLowerCase();
    if (query.isEmpty) return null;
    final list = await all();
    for (final f in list) {
      if (f.name.toLowerCase() == query || f.id.toLowerCase() == query) return f;
    }
    for (final f in list) {
      if (f.name.toLowerCase().contains(query) || query.contains(f.name.toLowerCase())) {
        return f;
      }
    }
    return null;
  }
}
