import Database from 'better-sqlite3';
import { drizzle } from 'drizzle-orm/better-sqlite3';
import * as schema from './schema.ts';
import { existsSync, mkdirSync } from 'node:fs';
import { dirname, resolve } from 'node:path';

const dbPath = resolve(process.env.DATABASE_PATH || './data/cybercoach.db');
const dbDir = dirname(dbPath);

if (!existsSync(dbDir)) {
  mkdirSync(dbDir, { recursive: true });
}

const sqlite = new Database(dbPath);
sqlite.pragma('journal_mode = WAL');
sqlite.pragma('foreign_keys = ON');

export const db = drizzle(sqlite, { schema });

/** 启动时自动建表 */
export function initDatabase() {
  sqlite.exec(`
    CREATE TABLE IF NOT EXISTS sport_records (
      record_id   TEXT PRIMARY KEY,
      user_id     TEXT NOT NULL,
      sport_type  TEXT NOT NULL CHECK(sport_type IN ('running','swimming')),
      recorded_at TEXT NOT NULL,
      duration_s  INTEGER NOT NULL,
      distance_m  INTEGER NOT NULL,
      avg_hr_bpm  INTEGER,
      peak_hr_bpm INTEGER,
      rpe         INTEGER,
      note        TEXT,
      detail_json TEXT,
      source      TEXT NOT NULL DEFAULT 'manual' CHECK(source IN ('manual','ocr')),
      created_at  TEXT NOT NULL,
      updated_at  TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS sport_reports (
      report_id    TEXT PRIMARY KEY,
      record_id    TEXT NOT NULL REFERENCES sport_records(record_id),
      content_json TEXT NOT NULL,
      generated_at TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS reminder_settings (
      user_id                 TEXT PRIMARY KEY,
      enabled                 INTEGER NOT NULL DEFAULT 1,
      train_reminder_time     TEXT NOT NULL,
      makeup_reminder_enabled INTEGER NOT NULL DEFAULT 1,
      timezone                TEXT NOT NULL DEFAULT 'Asia/Shanghai',
      updated_at              TEXT NOT NULL
    );

    CREATE INDEX IF NOT EXISTS idx_records_user_id ON sport_records(user_id);
    CREATE INDEX IF NOT EXISTS idx_records_recorded_at ON sport_records(recorded_at);
    CREATE INDEX IF NOT EXISTS idx_records_sport_type ON sport_records(sport_type);
    CREATE INDEX IF NOT EXISTS idx_reports_record_id ON sport_reports(record_id);
  `);
}
