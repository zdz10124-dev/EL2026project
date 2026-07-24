import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/meal_record.dart';
import '../models/recommendation_upload_task.dart';
import '../models/exercise_record.dart';
import '../models/integrated_health_analysis.dart';
import '../models/recovery_check_in.dart';

class DatabaseService implements RecoveryStore {
  DatabaseService._();

  static final DatabaseService instance = DatabaseService._();
  static const int databaseVersion = 8;
  static const List<String> agentTableSql = [
    '''CREATE TABLE IF NOT EXISTS recovery_check_ins(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      local_date TEXT NOT NULL UNIQUE,
      sleep_quality INTEGER NOT NULL,
      fatigue INTEGER NOT NULL,
      soreness INTEGER NOT NULL,
      energy INTEGER NOT NULL,
      note TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )''',
    '''CREATE TABLE IF NOT EXISTS daily_agent_plans(
      local_date TEXT PRIMARY KEY,
      data_fingerprint TEXT NOT NULL,
      summary TEXT NOT NULL,
      source TEXT NOT NULL,
      needs_refresh INTEGER NOT NULL DEFAULT 0,
      generated_at TEXT NOT NULL
    )''',
    '''CREATE TABLE IF NOT EXISTS agent_actions(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      client_action_id TEXT NOT NULL UNIQUE,
      plan_date TEXT NOT NULL,
      category TEXT NOT NULL,
      priority TEXT NOT NULL,
      title TEXT NOT NULL,
      action_text TEXT NOT NULL,
      evidence_json TEXT NOT NULL,
      target TEXT NOT NULL,
      status TEXT NOT NULL,
      difficulty TEXT,
      feedback_note TEXT,
      valid_until TEXT NOT NULL,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )''',
    'CREATE INDEX IF NOT EXISTS idx_agent_actions_date_status '
        'ON agent_actions(plan_date, status)',
    'CREATE INDEX IF NOT EXISTS idx_agent_actions_updated '
        'ON agent_actions(updated_at DESC)',
  ];

  Database? _database;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }
    final dbPath = await getDatabasePath();
    _database = await openDatabase(
      dbPath,
      version: databaseVersion,
      onCreate: (db, version) async {
        await _createMealRecordsTable(db);
        await _createUploadTaskTable(db);
        await _createExerciseRecordsTable(db);
        await _createHealthAnalysisCacheTable(db);
        await _createAgentTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        await _migrateDatabase(db, oldVersion);
      },
    );
    return _database!;
  }

  Future<String> getDatabasePath() async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, 'today_eat_app.db');
  }

  Future<int> insertRecord(MealRecord record) async {
    final db = await database;
    return db.insert('meal_records', record.toMap()..remove('id'));
  }

  Future<int> updateRecord(MealRecord record) async {
    final db = await database;
    return db.update(
      'meal_records',
      record.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [record.id],
    );
  }

  Future<int> deleteRecord(int id) async {
    final db = await database;
    return db.delete('meal_records', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteAllRecords() async {
    final db = await database;
    await db.delete('recommendation_upload_tasks');
    return db.delete('meal_records');
  }

  Future<List<MealRecord>> fetchRecords() async {
    final db = await database;
    final maps = await db.query('meal_records', orderBy: 'created_at DESC');
    return maps.map(MealRecord.fromMap).toList();
  }

  Future<MealRecord?> fetchRecordById(int id) async {
    final db = await database;
    final maps = await db.query(
      'meal_records',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) {
      return null;
    }
    return MealRecord.fromMap(maps.first);
  }

  Future<int> insertExerciseRecord(ExerciseRecord record) async {
    final db = await database;
    return db.insert('exercise_records', record.toMap()..remove('id'));
  }

  Future<int> updateExerciseRecord(ExerciseRecord record) async {
    final db = await database;
    return db.update(
      'exercise_records',
      record.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [record.id],
    );
  }

  Future<int> deleteExerciseRecord(int id) async {
    final db = await database;
    return db.delete('exercise_records', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteAllExerciseRecords() async {
    final db = await database;
    return db.delete('exercise_records');
  }

  Future<List<ExerciseRecord>> fetchExerciseRecords() async {
    final db = await database;
    final maps = await db.query('exercise_records', orderBy: 'started_at DESC');
    return maps.map(ExerciseRecord.fromMap).toList();
  }

  Future<ExerciseRecord?> fetchExerciseRecordById(int id) async {
    final db = await database;
    final maps = await db.query(
      'exercise_records',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return maps.isEmpty ? null : ExerciseRecord.fromMap(maps.first);
  }

  @override
  Future<Map<String, Object?>?> fetchRecoveryCheckIn(String localDate) async {
    final db = await database;
    final maps = await db.query(
      'recovery_check_ins',
      where: 'local_date = ?',
      whereArgs: [localDate],
      limit: 1,
    );
    return maps.isEmpty ? null : maps.first;
  }

  @override
  Future<void> upsertRecoveryCheckIn(Map<String, Object?> values) async {
    final db = await database;
    await db.insert(
      'recovery_check_ins',
      values..remove('id'),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> saveHealthAnalysisCache(HealthAnalysisCache cache) async {
    final db = await database;
    await db.insert(
      'health_analysis_cache',
      cache.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<HealthAnalysisCache?> fetchHealthAnalysisCache(
    String periodKey,
  ) async {
    final db = await database;
    final maps = await db.query(
      'health_analysis_cache',
      where: 'period_key = ?',
      whereArgs: [periodKey],
      limit: 1,
    );
    return maps.isEmpty ? null : HealthAnalysisCache.fromMap(maps.first);
  }

  Future<void> deleteAllHealthAnalysisCache() async {
    final db = await database;
    await db.delete('health_analysis_cache');
  }

  Future<int> getDatabaseFileSize() async {
    final path = await getDatabasePath();
    final file = File(path);
    if (!await file.exists()) {
      return 0;
    }
    return file.length();
  }

  Future<void> ensureUploadTasksForRecords(List<MealRecord> records) async {
    if (records.isEmpty) {
      return;
    }

    final db = await database;
    final existingMaps = await db.query('recommendation_upload_tasks');
    final existingTasks = {
      for (final map in existingMaps)
        (map['client_record_id'] as String? ?? ''):
            RecommendationUploadTask.fromMap(map),
    };

    final batch = db.batch();
    for (final record in records) {
      if (record.id == null || !record.autoUploadEnabled) {
        continue;
      }

      final task = existingTasks[record.clientRecordId];
      final recordUpdatedAt = record.updatedAt.toIso8601String();
      final shouldReplace =
          task == null ||
          task.recordUpdatedAt.toIso8601String() != recordUpdatedAt ||
          task.status != RecommendationUploadTaskStatus.synced;

      if (!shouldReplace) {
        continue;
      }

      batch.insert(
        'recommendation_upload_tasks',
        RecommendationUploadTask(
          clientRecordId: record.clientRecordId,
          recordId: record.id!,
          recordUpdatedAt: record.updatedAt,
          status: RecommendationUploadTaskStatus.pending,
          attemptCount: 0,
          updatedAt: DateTime.now(),
        ).toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  Future<List<RecommendationUploadTask>> fetchUnsyncedUploadTasks() async {
    final db = await database;
    final maps = await db.query(
      'recommendation_upload_tasks',
      where: 'status != ? AND status != ?',
      whereArgs: [
        RecommendationUploadTaskStatus.synced.dbValue,
        RecommendationUploadTaskStatus.invalid.dbValue,
      ],
      orderBy: 'updated_at ASC',
    );
    return maps.map(RecommendationUploadTask.fromMap).toList();
  }

  Future<void> markUploadTaskFailed({
    required String clientRecordId,
    required String error,
    RecommendationUploadTaskStatus status =
        RecommendationUploadTaskStatus.failed,
  }) async {
    final db = await database;
    final existing = await db.query(
      'recommendation_upload_tasks',
      where: 'client_record_id = ?',
      whereArgs: [clientRecordId],
      limit: 1,
    );
    if (existing.isEmpty) {
      return;
    }

    final task = RecommendationUploadTask.fromMap(existing.first);
    await db.update(
      'recommendation_upload_tasks',
      RecommendationUploadTask(
        clientRecordId: task.clientRecordId,
        recordId: task.recordId,
        recordUpdatedAt: task.recordUpdatedAt,
        status: status,
        attemptCount: task.attemptCount + 1,
        updatedAt: DateTime.now(),
        lastError: error,
      ).toMap(),
      where: 'client_record_id = ?',
      whereArgs: [clientRecordId],
    );
  }

  Future<void> markUploadTaskSynced({
    required String clientRecordId,
    required DateTime recordUpdatedAt,
  }) async {
    final db = await database;
    await db.update(
      'recommendation_upload_tasks',
      {
        'record_updated_at': recordUpdatedAt.toIso8601String(),
        'status': RecommendationUploadTaskStatus.synced.dbValue,
        'last_error': null,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'client_record_id = ?',
      whereArgs: [clientRecordId],
    );
  }

  Future<void> deleteUploadTaskByRecordId(int recordId) async {
    final db = await database;
    await db.delete(
      'recommendation_upload_tasks',
      where: 'record_id = ?',
      whereArgs: [recordId],
    );
  }

  Future<void> deleteUploadTaskByClientRecordId(String clientRecordId) async {
    final db = await database;
    await db.delete(
      'recommendation_upload_tasks',
      where: 'client_record_id = ?',
      whereArgs: [clientRecordId],
    );
  }

  Future<void> updateRecommendationSyncState({
    required int recordId,
    required LocalRecommendationStatus status,
    String? remoteRecommendationId,
    bool? autoUploadEnabled,
  }) async {
    final db = await database;
    final values = <String, Object?>{'recommendation_status': status.dbValue};
    if (remoteRecommendationId != null ||
        status == LocalRecommendationStatus.localOnly) {
      values['remote_recommendation_id'] = remoteRecommendationId;
    }
    if (autoUploadEnabled != null) {
      values['auto_upload_enabled'] = autoUploadEnabled ? 1 : 0;
    }
    await db.update(
      'meal_records',
      values,
      where: 'id = ?',
      whereArgs: [recordId],
    );
  }

  Future<void> _createMealRecordsTable(Database db) async {
    await db.execute('''
      CREATE TABLE meal_records(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        client_record_id TEXT NOT NULL UNIQUE,
        year INTEGER NOT NULL,
        month INTEGER NOT NULL,
        day INTEGER NOT NULL,
        hour INTEGER NOT NULL,
        minute INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        image_path TEXT NOT NULL,
        image_paths TEXT,
        dish_name TEXT NOT NULL,
        location TEXT NOT NULL,
        price REAL,
        comment TEXT,
        remote_recommendation_id TEXT,
        auto_upload_enabled INTEGER NOT NULL DEFAULT 1,
        recommendation_status TEXT NOT NULL DEFAULT 'local_only',
        province TEXT,
        city TEXT,
        district TEXT,
        latitude REAL,
        longitude REAL,
        main_dish TEXT NOT NULL,
        side_dish TEXT,
        drink TEXT,
        snack TEXT,
        rating_score REAL,
        rating_label TEXT NOT NULL,
        spice_level TEXT,
        ingredients TEXT,
        cuisine TEXT
      )
    ''');
  }

  Future<void> _createUploadTaskTable(Database db) async {
    await db.execute('''
      CREATE TABLE recommendation_upload_tasks(
        client_record_id TEXT PRIMARY KEY,
        record_id INTEGER NOT NULL,
        record_updated_at TEXT NOT NULL,
        status TEXT NOT NULL,
        attempt_count INTEGER NOT NULL DEFAULT 0,
        last_error TEXT,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createExerciseRecordsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS exercise_records(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        client_record_id TEXT NOT NULL UNIQUE,
        activity_type TEXT NOT NULL,
        started_at TEXT NOT NULL,
        duration_seconds INTEGER NOT NULL,
        distance_meters INTEGER,
        average_heart_rate_bpm INTEGER,
        peak_heart_rate_bpm INTEGER,
        calories_kcal INTEGER,
        rpe INTEGER,
        note TEXT,
        detail_json TEXT NOT NULL DEFAULT '{}',
        image_paths_json TEXT NOT NULL DEFAULT '[]',
        source TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_exercise_started_at '
      'ON exercise_records(started_at DESC)',
    );
  }

  Future<void> _createHealthAnalysisCacheTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS health_analysis_cache(
        period_key TEXT PRIMARY KEY,
        data_fingerprint TEXT NOT NULL,
        content_json TEXT NOT NULL,
        generated_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createAgentTables(Database db) async {
    for (final statement in agentTableSql) {
      await db.execute(statement);
    }
  }

  Future<void> _migrateDatabase(Database db, int oldVersion) async {
    final columns = await db.rawQuery('PRAGMA table_info(meal_records)');
    final columnNames = columns
        .map((column) => column['name'] as String? ?? '')
        .toSet();

    Future<void> addColumn(String sql, String name) async {
      if (!columnNames.contains(name)) {
        await db.execute(sql);
      }
    }

    await addColumn(
      'ALTER TABLE meal_records ADD COLUMN district TEXT',
      'district',
    );
    await addColumn(
      'ALTER TABLE meal_records ADD COLUMN client_record_id TEXT',
      'client_record_id',
    );
    await addColumn(
      'ALTER TABLE meal_records ADD COLUMN updated_at TEXT',
      'updated_at',
    );
    await addColumn(
      'ALTER TABLE meal_records ADD COLUMN comment TEXT',
      'comment',
    );
    await addColumn(
      'ALTER TABLE meal_records ADD COLUMN latitude REAL',
      'latitude',
    );
    await addColumn(
      'ALTER TABLE meal_records ADD COLUMN longitude REAL',
      'longitude',
    );
    await addColumn(
      'ALTER TABLE meal_records ADD COLUMN remote_recommendation_id TEXT',
      'remote_recommendation_id',
    );
    await addColumn(
      'ALTER TABLE meal_records ADD COLUMN auto_upload_enabled INTEGER NOT NULL DEFAULT 1',
      'auto_upload_enabled',
    );
    await addColumn(
      "ALTER TABLE meal_records ADD COLUMN recommendation_status TEXT NOT NULL DEFAULT 'local_only'",
      'recommendation_status',
    );

    if (!columnNames.contains('district') && columnNames.contains('street')) {
      await db.execute(
        'UPDATE meal_records SET district = street WHERE district IS NULL OR district = ""',
      );
    }

    await db.execute(
      'UPDATE meal_records SET updated_at = COALESCE(updated_at, created_at) '
      'WHERE updated_at IS NULL OR updated_at = ""',
    );
    await db.execute(
      'UPDATE meal_records SET client_record_id = COALESCE(client_record_id, "legacy_" || id) '
      'WHERE client_record_id IS NULL OR client_record_id = ""',
    );
    await db.execute(
      "UPDATE meal_records SET auto_upload_enabled = COALESCE(auto_upload_enabled, 1)",
    );
    await db.execute(
      "UPDATE meal_records SET recommendation_status = COALESCE(recommendation_status, 'local_only')",
    );

    final taskTables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='recommendation_upload_tasks'",
    );
    // v5: add multi-image column + migrate existing single-path records
    await addColumn(
      'ALTER TABLE meal_records ADD COLUMN image_paths TEXT',
      'image_paths',
    );
    await db.execute(
      "UPDATE meal_records SET image_paths = image_path WHERE image_paths IS NULL AND image_path != ''",
    );

    if (taskTables.isEmpty) {
      await _createUploadTaskTable(db);
    }
    if (oldVersion < 6) {
      await _createExerciseRecordsTable(db);
    }
    if (oldVersion < 7) {
      await _createHealthAnalysisCacheTable(db);
    }
    if (oldVersion < 8) {
      await _createAgentTables(db);
    }
  }
}
