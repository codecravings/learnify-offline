import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// Isolated SQLite database for the Franchise Lab experiments.
///
/// Lives alongside the main app DB but in its own file (`franchise_lab.db`)
/// so lab activity never pollutes the production student data.
class LabDatabase {
  LabDatabase._();
  static final LabDatabase instance = LabDatabase._();

  Database? _db;

  Future<Database> get db async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    return openDatabase(
      join(dbPath, 'franchise_lab.db'),
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldV, int newV) async {
    if (oldV < 2) await _createComics(db);
  }

  Future<void> _createComics(Database db) async {
    await db.execute('''
      CREATE TABLE lab_comics (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        profile_id INTEGER NOT NULL,
        topic TEXT NOT NULL,
        franchise_id TEXT,
        franchise_name TEXT,
        title TEXT NOT NULL,
        panels_json TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE lab_profile (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        created_at TEXT NOT NULL,
        xp INTEGER NOT NULL DEFAULT 0,
        streak INTEGER NOT NULL DEFAULT 0,
        last_active TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE lab_topics (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        profile_id INTEGER NOT NULL,
        topic_key TEXT NOT NULL,
        topic_name TEXT NOT NULL,
        level TEXT NOT NULL DEFAULT 'basics',
        accuracy INTEGER NOT NULL DEFAULT 0,
        stars INTEGER NOT NULL DEFAULT 0,
        quiz_count INTEGER NOT NULL DEFAULT 0,
        last_studied TEXT,
        UNIQUE(profile_id, topic_key)
      )
    ''');

    await db.execute('''
      CREATE TABLE lab_quiz_results (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        profile_id INTEGER NOT NULL,
        topic TEXT NOT NULL,
        level TEXT NOT NULL,
        style TEXT NOT NULL,
        score INTEGER NOT NULL,
        total INTEGER NOT NULL,
        missed_questions TEXT,
        concepts TEXT,
        taken_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE lab_memory_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        profile_id INTEGER NOT NULL,
        type TEXT NOT NULL,
        content TEXT NOT NULL,
        topic TEXT,
        tags TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE lab_franchise_usage (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        profile_id INTEGER NOT NULL,
        franchise_id TEXT NOT NULL,
        franchise_name TEXT NOT NULL,
        use_count INTEGER NOT NULL DEFAULT 0,
        last_used TEXT,
        UNIQUE(profile_id, franchise_id)
      )
    ''');

    await _createComics(db);
  }

  // ── COMICS ───────────────────────────────────────────────────────────────────

  Future<int> insertComic(int profileId, Map<String, dynamic> data) async {
    final d = await db;
    return d.insert('lab_comics', {'profile_id': profileId, ...data});
  }

  Future<List<Map<String, dynamic>>> getComics(int profileId, {int limit = 50}) async {
    final d = await db;
    return d.query(
      'lab_comics',
      where: 'profile_id = ?',
      whereArgs: [profileId],
      orderBy: 'created_at DESC',
      limit: limit,
    );
  }

  Future<Map<String, dynamic>?> getComic(int profileId, int id) async {
    final d = await db;
    final rows = await d.query(
      'lab_comics',
      where: 'profile_id = ? AND id = ?',
      whereArgs: [profileId, id],
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> deleteComic(int profileId, int id) async {
    final d = await db;
    await d.delete(
      'lab_comics',
      where: 'profile_id = ? AND id = ?',
      whereArgs: [profileId, id],
    );
  }

  // ── PROFILE ──────────────────────────────────────────────────────────────────

  Future<int> insertProfile(Map<String, dynamic> data) async {
    final d = await db;
    return d.insert('lab_profile', data);
  }

  Future<Map<String, dynamic>?> getProfile(int id) async {
    final d = await db;
    final rows = await d.query('lab_profile', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : rows.first;
  }

  Future<Map<String, dynamic>?> getFirstProfile() async {
    final d = await db;
    final rows = await d.query('lab_profile', limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> updateProfile(int id, Map<String, dynamic> data) async {
    final d = await db;
    await d.update('lab_profile', data, where: 'id = ?', whereArgs: [id]);
  }

  // ── TOPICS ───────────────────────────────────────────────────────────────────

  Future<void> upsertTopic(int profileId, Map<String, dynamic> data) async {
    final d = await db;
    await d.insert(
      'lab_topics',
      {'profile_id': profileId, ...data},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getTopics(int profileId) async {
    final d = await db;
    return d.query(
      'lab_topics',
      where: 'profile_id = ?',
      whereArgs: [profileId],
      orderBy: 'last_studied DESC',
    );
  }

  Future<Map<String, dynamic>?> getTopic(int profileId, String topicKey) async {
    final d = await db;
    final rows = await d.query(
      'lab_topics',
      where: 'profile_id = ? AND topic_key = ?',
      whereArgs: [profileId, topicKey],
    );
    return rows.isEmpty ? null : rows.first;
  }

  // ── QUIZ RESULTS ─────────────────────────────────────────────────────────────

  Future<int> insertQuizResult(int profileId, Map<String, dynamic> data) async {
    final d = await db;
    return d.insert('lab_quiz_results', {'profile_id': profileId, ...data});
  }

  Future<List<Map<String, dynamic>>> getQuizResults(int profileId,
      {String? topic, int limit = 50}) async {
    final d = await db;
    return d.query(
      'lab_quiz_results',
      where: topic != null ? 'profile_id = ? AND topic = ?' : 'profile_id = ?',
      whereArgs: topic != null ? [profileId, topic] : [profileId],
      orderBy: 'taken_at DESC',
      limit: limit,
    );
  }

  // ── MEMORY EVENTS ────────────────────────────────────────────────────────────

  Future<int> insertMemoryEvent(int profileId, Map<String, dynamic> data) async {
    final d = await db;
    return d.insert('lab_memory_events', {'profile_id': profileId, ...data});
  }

  Future<List<Map<String, dynamic>>> getMemoryEvents(int profileId,
      {String? topic, String? type, int limit = 100, bool ascending = false}) async {
    final d = await db;
    final clauses = <String>['profile_id = ?'];
    final args = <Object>[profileId];
    if (topic != null) {
      clauses.add('topic = ?');
      args.add(topic);
    }
    if (type != null) {
      clauses.add('type = ?');
      args.add(type);
    }
    return d.query(
      'lab_memory_events',
      where: clauses.join(' AND '),
      whereArgs: args,
      orderBy: ascending ? 'created_at ASC' : 'created_at DESC',
      limit: limit,
    );
  }

  // ── FRANCHISE USAGE ──────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> getFranchiseUsage(
      int profileId, String franchiseId) async {
    final d = await db;
    final rows = await d.query(
      'lab_franchise_usage',
      where: 'profile_id = ? AND franchise_id = ?',
      whereArgs: [profileId, franchiseId],
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> upsertFranchiseUsage(
      int profileId, Map<String, dynamic> data) async {
    final d = await db;
    await d.insert(
      'lab_franchise_usage',
      {'profile_id': profileId, ...data},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getTopFranchises(int profileId,
      {int limit = 3}) async {
    final d = await db;
    return d.query(
      'lab_franchise_usage',
      where: 'profile_id = ?',
      whereArgs: [profileId],
      orderBy: 'use_count DESC, last_used DESC',
      limit: limit,
    );
  }

  // ── HELPERS ──────────────────────────────────────────────────────────────────

  static String sanitizeKey(String topic) =>
      topic.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');

  static String encodeList(List<String> list) => jsonEncode(list);

  static List<String> decodeList(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) return decoded.map((e) => e.toString()).toList();
      return [];
    } catch (_) {
      return [];
    }
  }
}
