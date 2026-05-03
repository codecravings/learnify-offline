import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../db/app_database.dart';

class LocalProfile {
  LocalProfile({
    required this.id,
    required this.name,
    required this.language,
    required this.grade,
    required this.createdAt,
    this.xp = 0,
    this.streak = 0,
    this.interests = const [],
    this.currentMood,
    this.lastMoodDate,
    this.dyslexicMode = false,
    this.ttsEnabled = false,
  });

  final int id;
  final String name;
  final String language;
  final String grade;
  final DateTime createdAt;
  int xp;
  int streak;
  List<String> interests;
  String? currentMood;
  DateTime? lastMoodDate;
  bool dyslexicMode;
  bool ttsEnabled;

  factory LocalProfile.fromMap(Map<String, dynamic> m) => LocalProfile(
        id: m['id'] as int,
        name: m['name'] as String,
        language: m['language'] as String? ?? 'English',
        grade: m['grade'] as String? ?? 'Student',
        createdAt: DateTime.parse(m['created_at'] as String),
        xp: m['xp'] as int? ?? 0,
        streak: m['streak'] as int? ?? 0,
        interests: List<String>.from(
            jsonDecode(m['interests'] as String? ?? '[]') as List),
        currentMood: m['current_mood'] as String?,
        lastMoodDate: m['last_mood_date'] is String
            ? DateTime.tryParse(m['last_mood_date'] as String)
            : null,
        dyslexicMode: (m['dyslexic_mode'] as int? ?? 0) == 1,
        ttsEnabled: (m['tts_enabled'] as int? ?? 0) == 1,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'language': language,
        'grade': grade,
        'created_at': createdAt.toIso8601String(),
        'xp': xp,
        'streak': streak,
        'interests': jsonEncode(interests),
        'current_mood': currentMood,
        'last_mood_date': lastMoodDate?.toIso8601String(),
        'dyslexic_mode': dyslexicMode ? 1 : 0,
        'tts_enabled': ttsEnabled ? 1 : 0,
      };

  bool get needsMoodCheckIn {
    final last = lastMoodDate;
    if (last == null) return true;
    final now = DateTime.now();
    return last.year != now.year ||
        last.month != now.month ||
        last.day != now.day;
  }
}

/// Local profile manager — replaces Firebase Auth.
///
/// No login, no password. Students create a named local profile on first launch.
/// Supports multiple profiles on one device.
class LocalProfileService extends ChangeNotifier {
  LocalProfileService._();
  static final LocalProfileService instance = LocalProfileService._();

  static const _activeProfileKey = 'active_profile_id';

  final _db = AppDatabase.instance;
  LocalProfile? _current;

  LocalProfile? get currentProfile => _current;
  bool get hasProfile => _current != null;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getInt(_activeProfileKey);
    if (savedId != null) {
      final row = await _db.getProfile(savedId);
      if (row != null) {
        _current = LocalProfile.fromMap(row);
        notifyListeners();
      }
    }
  }

  Future<LocalProfile> createProfile({
    required String name,
    required String language,
    required String grade,
    List<String> interests = const [],
  }) async {
    final now = DateTime.now().toIso8601String();
    final id = await _db.insertProfile({
      'name': name,
      'language': language,
      'grade': grade,
      'created_at': now,
      'xp': 0,
      'streak': 0,
      'interests': jsonEncode(interests),
    });

    final profile = LocalProfile(
      id: id,
      name: name,
      language: language,
      grade: grade,
      createdAt: DateTime.parse(now),
      interests: interests,
    );

    await _setActive(profile);
    return profile;
  }

  Future<void> addXP(int amount) async {
    final p = _current;
    if (p == null) return;
    p.xp += amount;
    await _db.updateProfile(p.id, {'xp': p.xp});
    notifyListeners();
  }

  Future<void> updateStreak(int streak) async {
    final p = _current;
    if (p == null) return;
    p.streak = streak;
    await _db.updateProfile(p.id, {'streak': streak});
    notifyListeners();
  }

  Future<void> setDyslexicMode(bool enabled) async {
    final p = _current;
    if (p == null) return;
    p.dyslexicMode = enabled;
    await _db.updateProfile(p.id, {'dyslexic_mode': enabled ? 1 : 0});
    notifyListeners();
  }

  Future<void> setTtsEnabled(bool enabled) async {
    final p = _current;
    if (p == null) return;
    p.ttsEnabled = enabled;
    await _db.updateProfile(p.id, {'tts_enabled': enabled ? 1 : 0});
    notifyListeners();
  }

  Future<void> setMood(String mood) async {
    final p = _current;
    if (p == null) return;
    final now = DateTime.now();
    p.currentMood = mood;
    p.lastMoodDate = now;
    await _db.updateProfile(p.id, {
      'current_mood': mood,
      'last_mood_date': now.toIso8601String(),
    });
    notifyListeners();
  }

  Future<void> updateProfile({
    String? name,
    String? language,
    String? grade,
    List<String>? interests,
  }) async {
    final p = _current;
    if (p == null) return;
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (language != null) updates['language'] = language;
    if (grade != null) updates['grade'] = grade;
    if (interests != null) updates['interests'] = jsonEncode(interests);
    await _db.updateProfile(p.id, updates);
    final row = await _db.getProfile(p.id);
    if (row != null) _current = LocalProfile.fromMap(row);
    notifyListeners();
  }

  Future<void> _setActive(LocalProfile profile) async {
    _current = profile;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_activeProfileKey, profile.id);
    notifyListeners();
  }

  Future<void> switchProfile(int profileId) async {
    final row = await _db.getProfile(profileId);
    if (row == null) return;
    await _setActive(LocalProfile.fromMap(row));
  }
}
