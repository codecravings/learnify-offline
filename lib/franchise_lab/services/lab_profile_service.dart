import 'package:flutter/foundation.dart';

import '../data/lab_database.dart';

class LabProfile {
  LabProfile({
    required this.id,
    required this.name,
    required this.createdAt,
    this.xp = 0,
    this.streak = 0,
    this.lastActive,
  });

  final int id;
  final String name;
  final DateTime createdAt;
  int xp;
  int streak;
  DateTime? lastActive;

  factory LabProfile.fromMap(Map<String, dynamic> m) => LabProfile(
        id: m['id'] as int,
        name: m['name'] as String,
        createdAt: DateTime.parse(m['created_at'] as String),
        xp: m['xp'] as int? ?? 0,
        streak: m['streak'] as int? ?? 0,
        lastActive: (m['last_active'] as String?) != null
            ? DateTime.tryParse(m['last_active'] as String)
            : null,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'created_at': createdAt.toIso8601String(),
        'xp': xp,
        'streak': streak,
        'last_active': lastActive?.toIso8601String(),
      };
}

/// Lab-scoped profile manager.
///
/// Mirrors LocalProfileService but reads/writes to the isolated lab DB.
/// Only one lab profile is active at a time — the first row in `lab_profile`.
class LabProfileService extends ChangeNotifier {
  LabProfileService._();
  static final LabProfileService instance = LabProfileService._();

  final _db = LabDatabase.instance;
  LabProfile? _currentProfile;

  LabProfile? get currentProfile => _currentProfile;
  bool get hasProfile => _currentProfile != null;

  Future<void> initialize() async {
    final row = await _db.getFirstProfile();
    if (row != null) {
      _currentProfile = LabProfile.fromMap(row);
      notifyListeners();
    }
  }

  Future<LabProfile> createProfile({required String name}) async {
    final now = DateTime.now().toIso8601String();
    final id = await _db.insertProfile({
      'name': name,
      'created_at': now,
      'xp': 0,
      'streak': 0,
      'last_active': now,
    });

    final profile = LabProfile(
      id: id,
      name: name,
      createdAt: DateTime.parse(now),
      lastActive: DateTime.parse(now),
    );

    _currentProfile = profile;
    notifyListeners();
    return profile;
  }

  Future<void> addXP(int amount) async {
    final p = _currentProfile;
    if (p == null) return;
    p.xp += amount;
    await _db.updateProfile(p.id, {'xp': p.xp});
    notifyListeners();
  }

  Future<void> updateStreak(int newStreak) async {
    final p = _currentProfile;
    if (p == null) return;
    p.streak = newStreak;
    await _db.updateProfile(p.id, {'streak': newStreak});
    notifyListeners();
  }

  Future<void> touchLastActive() async {
    final p = _currentProfile;
    if (p == null) return;
    final now = DateTime.now();
    p.lastActive = now;
    await _db.updateProfile(p.id, {'last_active': now.toIso8601String()});
    notifyListeners();
  }
}
