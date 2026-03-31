import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import '../models/episode.dart';
import '../models/speaking_attempt.dart';
import '../models/speaking_session.dart';
import '../models/speaking_stats.dart';

class LocalDatabaseService {
  static final LocalDatabaseService _instance = LocalDatabaseService._internal();
  factory LocalDatabaseService() => _instance;
  LocalDatabaseService._internal();

  static const String _dbName = 'learning_english_cache.db';
  static const int _dbVersion = 4;
  static const int noYear = -1;

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWeb;
      return databaseFactory.openDatabase(
        _dbName,
        options: OpenDatabaseOptions(
          version: _dbVersion,
          onCreate: _onCreate,
          onUpgrade: _onUpgrade,
        ),
      );
    }

    if (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final dir = await getApplicationDocumentsDirectory();
      final dbPath = p.join(dir.path, _dbName);
      return databaseFactory.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: _dbVersion,
          onCreate: _onCreate,
          onUpgrade: _onUpgrade,
        ),
      );
    }

    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, _dbName);
    return openDatabase(
      dbPath,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE categories (
        category TEXT NOT NULL,
        year INTEGER NOT NULL,
        last_fetched TEXT NOT NULL,
        PRIMARY KEY (category, year)
      )
    ''');

    await db.execute('''
      CREATE TABLE episodes (
        id TEXT PRIMARY KEY,
        category TEXT NOT NULL,
        year INTEGER,
        episode_name TEXT,
        summary TEXT,
        transcript TEXT,
        published_date TEXT,
        data TEXT NOT NULL
      )
    ''');

    await db.execute('CREATE INDEX idx_episodes_category_year ON episodes(category, year)');
    await db.execute('CREATE INDEX idx_episodes_name ON episodes(episode_name)');

    await db.execute('''
      CREATE TABLE api_daily_cache (
        cache_key TEXT PRIMARY KEY,
        last_fetched TEXT NOT NULL,
        payload_json TEXT NOT NULL
      )
    ''');

    await _createSpeakingTables(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createSpeakingTables(db);
    }
    if (oldVersion < 3) {
      await _upgradeSpeakingToV3(db);
    }
    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS api_daily_cache (
          cache_key TEXT PRIMARY KEY,
          last_fetched TEXT NOT NULL,
          payload_json TEXT NOT NULL
        )
      ''');
    }
  }

  Future<void> _upgradeSpeakingToV3(Database db) async {
    try {
      await db.execute(
        'ALTER TABLE speaking_sessions ADD COLUMN episode_title TEXT NOT NULL DEFAULT ""',
      );
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE speaking_attempts ADD COLUMN feedback_json TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE speaking_attempts ADD COLUMN user_recording_path TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE speaking_attempts ADD COLUMN line_start_ms INTEGER');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE speaking_attempts ADD COLUMN line_end_ms INTEGER');
    } catch (_) {}
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_speaking_attempts_line ON speaking_attempts(episode_id, mode, line_index)',
    );
  }

  Future<void> _createSpeakingTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS speaking_sessions (
        id TEXT PRIMARY KEY,
        episode_id TEXT NOT NULL,
        episode_title TEXT NOT NULL DEFAULT '',
        mode TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        total_attempts INTEGER NOT NULL,
        average_score REAL NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS speaking_attempts (
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        episode_id TEXT NOT NULL,
        mode TEXT NOT NULL,
        line_index INTEGER,
        speaker TEXT,
        line_text TEXT NOT NULL,
        recognized_text TEXT NOT NULL,
        score REAL NOT NULL,
        feedback TEXT NOT NULL,
        feedback_json TEXT,
        user_recording_path TEXT,
        line_start_ms INTEGER,
        line_end_ms INTEGER,
        duration_ms INTEGER NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('CREATE INDEX IF NOT EXISTS idx_speaking_session_episode ON speaking_sessions(episode_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_speaking_attempts_session ON speaking_attempts(session_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_speaking_attempts_episode ON speaking_attempts(episode_id)');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_speaking_attempts_line ON speaking_attempts(episode_id, mode, line_index)',
    );
  }

  Future<DateTime?> getCategoryLastFetched(String category, int year) async {
    final db = await database;
    final rows = await db.query(
      'categories',
      where: 'category = ? AND year = ?',
      whereArgs: [category, year],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    final value = rows.first['last_fetched']?.toString();
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  Future<void> upsertCategoryFetch(String category, int year, DateTime fetchedAt) async {
    final db = await database;
    await db.insert(
      'categories',
      {
        'category': category,
        'year': year,
        'last_fetched': fetchedAt.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Cache JSON theo key, tối đa một lần fetch mỗi ngày (dùng cho HomePage, Grammar list, …).
  Future<String?> getApiDailyCachePayload(String cacheKey) async {
    final db = await database;
    final rows = await db.query(
      'api_daily_cache',
      where: 'cache_key = ?',
      whereArgs: [cacheKey],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['payload_json']?.toString();
  }

  Future<DateTime?> getApiDailyLastFetched(String cacheKey) async {
    final db = await database;
    final rows = await db.query(
      'api_daily_cache',
      columns: ['last_fetched'],
      where: 'cache_key = ?',
      whereArgs: [cacheKey],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final value = rows.first['last_fetched']?.toString();
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  Future<void> upsertApiDailyCache(String cacheKey, String payloadJson, DateTime fetchedAt) async {
    final db = await database;
    await db.insert(
      'api_daily_cache',
      {
        'cache_key': cacheKey,
        'last_fetched': fetchedAt.toIso8601String(),
        'payload_json': payloadJson,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertEpisodesIfMissing(
    String category,
    int year,
    List<Episode> episodes,
  ) async {
    if (episodes.isEmpty) return;
    final db = await database;
    final batch = db.batch();

    for (final episode in episodes) {
      final row = _episodeToRow(category, year, episode);
      batch.insert(
        'episodes',
        row,
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }

    await batch.commit(noResult: true);
  }

  Future<void> upsertEpisode(Episode episode, {int? yearOverride}) async {
    final db = await database;
    final year = yearOverride ?? int.tryParse(episode.year ?? '') ?? noYear;
    final row = _episodeToRow(episode.category, year, episode);
    await db.insert(
      'episodes',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getEpisodeFileUrl(String episodeId) async {
    final db = await database;
    final rows = await db.query(
      'episodes',
      columns: ['data'],
      where: 'id = ?',
      whereArgs: [episodeId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final dataString = rows.first['data']?.toString();
    if (dataString == null || dataString.isEmpty) return null;
    try {
      final decoded = jsonDecode(dataString);
      if (decoded is Map<String, dynamic>) {
        return decoded['fileUrl']?.toString();
      }
    } catch (e) {
      debugPrint('Error decoding episode data: $e');
    }
    return null;
  }

  Future<List<Episode>> getEpisodesByCategoryYear(String category, int year) async {
    final db = await database;
    final List<Map<String, dynamic>> rows;
    if (year == noYear) {
      rows = await db.query(
        'episodes',
        where: 'category = ?',
        whereArgs: [category],
        orderBy: 'published_date DESC',
      );
    } else {
      rows = await db.query(
        'episodes',
        where: 'category = ? AND year = ?',
        whereArgs: [category, year],
        orderBy: 'published_date DESC',
      );
    }

    return rows.map(_episodeFromRow).toList();
  }

  Future<List<Episode>> searchEpisodes(String query, {int limit = 50}) async {
    final db = await database;
    final trimmed = query.trim().toLowerCase();
    if (trimmed.isEmpty) return [];
    final like = '%$trimmed%';

    final rows = await db.rawQuery(
      '''
      SELECT * FROM episodes
      WHERE lower(episode_name) LIKE ?
         OR lower(summary) LIKE ?
         OR lower(transcript) LIKE ?
      ORDER BY
        CASE
          WHEN lower(episode_name) LIKE ? THEN 0
          WHEN lower(summary) LIKE ? THEN 1
          WHEN lower(transcript) LIKE ? THEN 2
          ELSE 3
        END,
        published_date DESC
      LIMIT ?
      ''',
      [like, like, like, like, like, like, limit],
    );

    return rows.map(_episodeFromRow).toList();
  }

  Future<void> insertSpeakingSession(SpeakingSession session) async {
    final db = await database;
    await db.insert(
      'speaking_sessions',
      session.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateSpeakingSession(SpeakingSession session) async {
    final db = await database;
    await db.update(
      'speaking_sessions',
      session.toMap(),
      where: 'id = ?',
      whereArgs: [session.id],
    );
  }

  Future<void> insertSpeakingAttempt(SpeakingAttempt attempt) async {
    final db = await database;
    await db.insert(
      'speaking_attempts',
      attempt.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<SpeakingSession>> getSpeakingSessions({
    int limit = 50,
    int offset = 0,
    String? episodeId,
  }) async {
    final db = await database;
    final rows = await db.query(
      'speaking_sessions',
      where: episodeId != null ? 'episode_id = ?' : null,
      whereArgs: episodeId != null ? [episodeId] : null,
      orderBy: 'updated_at DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map(SpeakingSession.fromMap).toList();
  }

  /// Map `episode_id` → `episode_name` cho màn history (một truy vấn).
  Future<Map<String, String>> getEpisodeDisplayNamesByIds(
    Set<String> episodeIds,
  ) async {
    final ids = episodeIds.where((id) => id.isNotEmpty).toList();
    if (ids.isEmpty) return {};
    final db = await database;
    final placeholders = List.filled(ids.length, '?').join(',');
    final rows = await db.rawQuery(
      'SELECT id, episode_name FROM episodes WHERE id IN ($placeholders)',
      ids,
    );
    final map = <String, String>{};
    for (final row in rows) {
      final id = row['id']?.toString();
      final name = row['episode_name']?.toString() ?? '';
      if (id != null && id.isNotEmpty && name.isNotEmpty) {
        map[id] = name;
      }
    }
    return map;
  }

  Future<List<SpeakingAttempt>> getSpeakingAttempts(String sessionId) async {
    final db = await database;
    final rows = await db.query(
      'speaking_attempts',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'created_at DESC',
    );
    return rows.map(SpeakingAttempt.fromMap).toList();
  }

  Future<SpeakingStats> getSpeakingStats({String? episodeId}) async {
    final db = await database;
    final where = episodeId != null ? 'episode_id = ?' : null;
    final whereArgs = episodeId != null ? [episodeId] : null;

    final sessions = Sqflite.firstIntValue(await db.rawQuery(
      '''
      SELECT COUNT(*) FROM speaking_sessions
      ${where != null ? 'WHERE $where' : ''}
      ''',
      whereArgs,
    ));

    final attempts = await db.rawQuery(
      '''
      SELECT COUNT(*) AS total_attempts,
             AVG(score) AS avg_score,
             MAX(created_at) AS last_practice
      FROM speaking_attempts
      ${where != null ? 'WHERE $where' : ''}
      ''',
      whereArgs,
    );

    if (attempts.isEmpty) {
      return SpeakingStats.empty();
    }

    final row = attempts.first;
    final totalAttempts = (row['total_attempts'] as int?) ?? 0;
    final avgScore = (row['avg_score'] as num?)?.toDouble() ?? 0;
    final lastPracticeRaw = row['last_practice']?.toString();
    final lastPracticedAt =
        lastPracticeRaw != null ? DateTime.tryParse(lastPracticeRaw) : null;

    return SpeakingStats(
      totalSessions: sessions ?? 0,
      totalAttempts: totalAttempts,
      averageScore: avgScore,
      lastPracticedAt: lastPracticedAt,
    );
  }

  Map<String, dynamic> _episodeToRow(String category, int year, Episode episode) {
    final storedData = episode.toJson();
    final resolvedYear = year == noYear
        ? (int.tryParse(episode.year ?? '') ?? noYear)
        : year;
    final id = episode.resolvedStorageId;

    return {
      'id': id,
      'category': category,
      'year': resolvedYear,
      'episode_name': episode.episodeName,
      'summary': episode.summary ?? '',
      'transcript': episode.transcript,
      'published_date': episode.publishedDate.toIso8601String(),
      'data': jsonEncode(storedData),
    };
  }

  Episode _episodeFromRow(Map<String, dynamic> row) {
    final dataString = row['data']?.toString();
    if (dataString != null && dataString.isNotEmpty) {
      try {
        final decoded = jsonDecode(dataString);
        if (decoded is Map<String, dynamic>) {
          return _episodeFromStoredMap(decoded);
        }
      } catch (e) {
        debugPrint('Error decoding episode data: $e');
      }
    }

    return Episode(
      actor: '',
      category: row['category']?.toString() ?? '',
      duration: '0:00',
      publishedDate: DateTime.tryParse(row['published_date']?.toString() ?? '') ?? DateTime.now(),
      episodeName: row['episode_name']?.toString() ?? '',
      transcript: row['transcript']?.toString() ?? '',
      thumbImage: '',
      id: row['id']?.toString(),
      summary: row['summary']?.toString(),
      year: row['year']?.toString(),
    );
  }

  Episode _episodeFromStoredMap(Map<String, dynamic> map) {
    return Episode(
      id: map['id']?.toString(),
      actor: map['actor']?.toString() ?? '',
      category: map['category']?.toString() ?? '',
      duration: map['duration']?.toString() ?? '0:00',
      publishedDate: DateTime.tryParse(map['publishedDate']?.toString() ?? '') ?? DateTime.now(),
      episodeName: map['episodeName']?.toString() ?? '',
      transcript: map['transcript']?.toString() ?? '',
      thumbImage: map['thumbImage']?.toString() ?? '',
      fileUrl: map['fileUrl']?.toString(),
      secondFileUrl: map['secondFileUrl']?.toString(),
      summary: map['summary']?.toString(),
      year: map['year']?.toString(),
      transcriptHtml: map['transcriptHtml']?.toString(),
      vocabulary: map['vocabulary']?.toString(),
      vocabularies: map['vocabularies'] as List<dynamic>?,
    );
  }

  /// Episode không có Firebase id — cùng quy tắc với [Episode.resolvedStorageId].
  String fallbackEpisodeId(String category, Episode episode) {
    final safeName = episode.episodeName.replaceAll(RegExp(r'\s+'), '_');
    final date = episode.publishedDate.toIso8601String();
    return '$category-$date-$safeName';
  }

  Future<Episode?> getEpisodeById(String episodeId) async {
    if (episodeId.isEmpty) return null;
    final db = await database;
    final rows = await db.query(
      'episodes',
      where: 'id = ?',
      whereArgs: [episodeId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _episodeFromRow(rows.first);
  }

  /// Lịch sử attempt theo dòng (repeat/roleplay), speaker khớp khi có.
  Future<List<SpeakingAttempt>> getSpeakingAttemptsForLine({
    required String episodeId,
    required String mode,
    required int lineIndex,
    String? speaker,
    int limit = 30,
  }) async {
    if (episodeId.isEmpty) return [];
    final db = await database;
    final sp = speaker ?? '';
    final rows = await db.query(
      'speaking_attempts',
      where:
          'episode_id = ? AND mode = ? AND line_index = ? AND ifnull(speaker, \'\') = ?',
      whereArgs: [episodeId, mode, lineIndex, sp],
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return rows.map(SpeakingAttempt.fromMap).toList();
  }

  Future<SpeakingAttempt?> getSpeakingAttemptById(String attemptId) async {
    if (attemptId.isEmpty) return null;
    final db = await database;
    final rows = await db.query(
      'speaking_attempts',
      where: 'id = ?',
      whereArgs: [attemptId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return SpeakingAttempt.fromMap(rows.first);
  }
}
