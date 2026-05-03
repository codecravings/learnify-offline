import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// Local SQLite database — replaces Firebase Firestore.
/// All student data stays on-device, fully private.
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Database? _db;

  Future<Database> get db async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    return openDatabase(
      join(dbPath, 'learnify.db'),
      version: 4,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldV, int newV) async {
    if (oldV < 2) await _createTopicPaths(db);
    if (oldV < 3) await _addMoodColumns(db);
    if (oldV < 4) await _addA11yColumns(db);
  }

  Future<void> _addMoodColumns(Database db) async {
    await db.execute("ALTER TABLE profiles ADD COLUMN current_mood TEXT");
    await db.execute("ALTER TABLE profiles ADD COLUMN last_mood_date TEXT");
  }

  Future<void> _addA11yColumns(Database db) async {
    await db.execute(
        "ALTER TABLE profiles ADD COLUMN dyslexic_mode INTEGER DEFAULT 0");
    await db.execute(
        "ALTER TABLE profiles ADD COLUMN tts_enabled INTEGER DEFAULT 0");
  }

  Future<void> _createTopicPaths(Database db) async {
    await db.execute('''
      CREATE TABLE topic_paths (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        profile_id INTEGER NOT NULL,
        topic_key TEXT NOT NULL,
        topic_name TEXT NOT NULL,
        steps_json TEXT NOT NULL,
        current_step_index INTEGER NOT NULL DEFAULT 0,
        completed_step_indices TEXT NOT NULL DEFAULT '[]',
        estimated_minutes INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        UNIQUE(profile_id, topic_key),
        FOREIGN KEY (profile_id) REFERENCES profiles(id)
      )
    ''');
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE profiles (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        language TEXT DEFAULT 'English',
        grade TEXT DEFAULT 'Student',
        created_at TEXT NOT NULL,
        xp INTEGER DEFAULT 0,
        streak INTEGER DEFAULT 0,
        last_active TEXT,
        interests TEXT DEFAULT '[]',
        current_mood TEXT,
        last_mood_date TEXT,
        dyslexic_mode INTEGER DEFAULT 0,
        tts_enabled INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE topics (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        profile_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        topic_key TEXT NOT NULL,
        level TEXT DEFAULT 'basics',
        accuracy REAL DEFAULT 0.0,
        stars INTEGER DEFAULT 0,
        quiz_count INTEGER DEFAULT 0,
        last_studied TEXT,
        UNIQUE(profile_id, topic_key),
        FOREIGN KEY (profile_id) REFERENCES profiles(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE quiz_results (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        profile_id INTEGER NOT NULL,
        topic TEXT NOT NULL,
        level TEXT NOT NULL,
        style TEXT NOT NULL,
        score INTEGER NOT NULL,
        total INTEGER NOT NULL,
        missed_questions TEXT DEFAULT '[]',
        concepts TEXT DEFAULT '[]',
        timestamp TEXT NOT NULL,
        FOREIGN KEY (profile_id) REFERENCES profiles(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE memory_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        profile_id INTEGER NOT NULL,
        type TEXT NOT NULL,
        content TEXT NOT NULL,
        topic TEXT,
        tags TEXT DEFAULT '[]',
        timestamp TEXT NOT NULL,
        FOREIGN KEY (profile_id) REFERENCES profiles(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE chat_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        profile_id INTEGER NOT NULL,
        query TEXT NOT NULL,
        response TEXT NOT NULL,
        agent TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        FOREIGN KEY (profile_id) REFERENCES profiles(id)
      )
    ''');

    await _createTopicPaths(db);
  }

  // ── TOPIC PATHS ──────────────────────────────────────────────────────────────

  Future<void> upsertTopicPath(int profileId, Map<String, dynamic> data) async {
    final d = await db;
    await d.insert(
      'topic_paths',
      {'profile_id': profileId, ...data},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getTopicPath(int profileId, String topicKey) async {
    final d = await db;
    final rows = await d.query(
      'topic_paths',
      where: 'profile_id = ? AND topic_key = ?',
      whereArgs: [profileId, topicKey],
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<List<Map<String, dynamic>>> getAllTopicPaths(int profileId) async {
    final d = await db;
    return d.query(
      'topic_paths',
      where: 'profile_id = ?',
      whereArgs: [profileId],
      orderBy: 'updated_at DESC',
    );
  }

  Future<void> updateTopicPathProgress(
    int profileId,
    String topicKey, {
    required int currentStepIndex,
    required List<int> completedStepIndices,
  }) async {
    final d = await db;
    await d.update(
      'topic_paths',
      {
        'current_step_index': currentStepIndex,
        'completed_step_indices': encodeList(completedStepIndices),
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'profile_id = ? AND topic_key = ?',
      whereArgs: [profileId, topicKey],
    );
  }

  // ── PROFILES ─────────────────────────────────────────────────────────────────

  Future<int> insertProfile(Map<String, dynamic> data) async {
    final d = await db;
    return d.insert('profiles', data);
  }

  Future<Map<String, dynamic>?> getProfile(int id) async {
    final d = await db;
    final rows = await d.query('profiles', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : rows.first;
  }

  Future<Map<String, dynamic>?> getFirstProfile() async {
    final d = await db;
    final rows = await d.query('profiles', limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  Future<List<Map<String, dynamic>>> getAllProfiles() async {
    final d = await db;
    return d.query('profiles', orderBy: 'created_at ASC');
  }

  Future<void> updateProfile(int id, Map<String, dynamic> data) async {
    final d = await db;
    await d.update('profiles', data, where: 'id = ?', whereArgs: [id]);
  }

  // ── TOPICS ───────────────────────────────────────────────────────────────────

  Future<void> upsertTopic(int profileId, Map<String, dynamic> data) async {
    final d = await db;
    await d.insert(
      'topics',
      {'profile_id': profileId, ...data},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getTopics(int profileId) async {
    final d = await db;
    return d.query(
      'topics',
      where: 'profile_id = ?',
      whereArgs: [profileId],
      orderBy: 'last_studied DESC',
    );
  }

  Future<Map<String, dynamic>?> getTopic(int profileId, String topicKey) async {
    final d = await db;
    final rows = await d.query(
      'topics',
      where: 'profile_id = ? AND topic_key = ?',
      whereArgs: [profileId, topicKey],
    );
    return rows.isEmpty ? null : rows.first;
  }

  // ── QUIZ RESULTS ─────────────────────────────────────────────────────────────

  Future<int> insertQuizResult(int profileId, Map<String, dynamic> data) async {
    final d = await db;
    return d.insert('quiz_results', {'profile_id': profileId, ...data});
  }

  Future<List<Map<String, dynamic>>> getQuizResults(int profileId,
      {String? topic, int limit = 50}) async {
    final d = await db;
    return d.query(
      'quiz_results',
      where: topic != null ? 'profile_id = ? AND topic = ?' : 'profile_id = ?',
      whereArgs: topic != null ? [profileId, topic] : [profileId],
      orderBy: 'timestamp DESC',
      limit: limit,
    );
  }

  // ── MEMORY EVENTS ────────────────────────────────────────────────────────────

  Future<int> insertMemoryEvent(int profileId, Map<String, dynamic> data) async {
    final d = await db;
    return d.insert('memory_events', {'profile_id': profileId, ...data});
  }

  Future<List<Map<String, dynamic>>> getMemoryEvents(int profileId,
      {String? topic, int limit = 100}) async {
    final d = await db;
    return d.query(
      'memory_events',
      where: topic != null ? 'profile_id = ? AND topic = ?' : 'profile_id = ?',
      whereArgs: topic != null ? [profileId, topic] : [profileId],
      orderBy: 'timestamp DESC',
      limit: limit,
    );
  }

  // ── CHAT HISTORY ─────────────────────────────────────────────────────────────

  Future<int> insertChatMessage(int profileId, Map<String, dynamic> data) async {
    final d = await db;
    return d.insert('chat_history', {'profile_id': profileId, ...data});
  }

  Future<List<Map<String, dynamic>>> getChatHistory(int profileId,
      {String agent = 'companion', int limit = 30}) async {
    final d = await db;
    return d.query(
      'chat_history',
      where: 'profile_id = ? AND agent = ?',
      whereArgs: [profileId, agent],
      orderBy: 'timestamp ASC',
      limit: limit,
    );
  }

  // ── STATS ────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getStats(int profileId) async {
    final d = await db;

    final topicCount = Sqflite.firstIntValue(await d.rawQuery(
      'SELECT COUNT(*) FROM topics WHERE profile_id = ?', [profileId],
    )) ?? 0;

    final quizCount = Sqflite.firstIntValue(await d.rawQuery(
      'SELECT COUNT(*) FROM quiz_results WHERE profile_id = ?', [profileId],
    )) ?? 0;

    final avgAccuracy = (await d.rawQuery(
      'SELECT AVG(CAST(score AS REAL)/total*100) as avg FROM quiz_results WHERE profile_id = ?',
      [profileId],
    )).first['avg'];

    return {
      'topicCount': topicCount,
      'quizCount': quizCount,
      'avgAccuracy': avgAccuracy != null ? (avgAccuracy as double).round() : 0,
    };
  }

  // ── HELPERS ──────────────────────────────────────────────────────────────────

  static String encodeList(List list) => jsonEncode(list);
  static List decodeList(String? json) =>
      json == null ? [] : jsonDecode(json) as List;
}
