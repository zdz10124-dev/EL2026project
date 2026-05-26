import { sqliteTable, text, integer } from 'drizzle-orm/sqlite-core';

/** 运动记录表 */
export const sportRecords = sqliteTable('sport_records', {
  record_id: text('record_id').primaryKey(),
  user_id: text('user_id').notNull(),
  sport_type: text('sport_type', { enum: ['running', 'swimming'] }).notNull(),
  recorded_at: text('recorded_at').notNull(),
  duration_s: integer('duration_s').notNull(),
  distance_m: integer('distance_m').notNull(),
  avg_hr_bpm: integer('avg_hr_bpm'),
  peak_hr_bpm: integer('peak_hr_bpm'),
  rpe: integer('rpe'),
  note: text('note'),
  detail_json: text('detail_json'), // RunningDetail | SwimmingDetail as JSON
  source: text('source', { enum: ['manual', 'ocr'] }).notNull().default('manual'),
  created_at: text('created_at').notNull(),
  updated_at: text('updated_at').notNull(),
});

/** AI 报告缓存 */
export const sportReports = sqliteTable('sport_reports', {
  report_id: text('report_id').primaryKey(),
  record_id: text('record_id').notNull().references(() => sportRecords.record_id),
  content_json: text('content_json').notNull(),
  generated_at: text('generated_at').notNull(),
});

/** 提醒设置 */
export const reminderSettings = sqliteTable('reminder_settings', {
  user_id: text('user_id').primaryKey(),
  enabled: integer('enabled', { mode: 'boolean' }).notNull().default(true),
  train_reminder_time: text('train_reminder_time').notNull(),
  makeup_reminder_enabled: integer('makeup_reminder_enabled', { mode: 'boolean' }).notNull().default(true),
  timezone: text('timezone').notNull().default('Asia/Shanghai'),
  updated_at: text('updated_at').notNull(),
});
