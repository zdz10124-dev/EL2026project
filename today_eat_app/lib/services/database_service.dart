import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/meal_record.dart';

class DatabaseService {
  DatabaseService._();

  static final DatabaseService instance = DatabaseService._();
  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, 'today_eat_app.db');
    _database = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE meal_records(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            year INTEGER NOT NULL,
            month INTEGER NOT NULL,
            day INTEGER NOT NULL,
            hour INTEGER NOT NULL,
            minute INTEGER NOT NULL,
            created_at TEXT NOT NULL,
            image_path TEXT NOT NULL,
            dish_name TEXT NOT NULL,
            location TEXT NOT NULL,
            price REAL,
            province TEXT,
            city TEXT,
            street TEXT,
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
      },
    );
    return _database!;
  }

  Future<int> insertRecord(MealRecord record) async {
    final db = await database;
    return db.insert('meal_records', record.toMap());
  }

  Future<List<MealRecord>> fetchRecords() async {
    final db = await database;
    final maps = await db.query('meal_records', orderBy: 'created_at DESC');
    return maps.map(MealRecord.fromMap).toList();
  }
}
