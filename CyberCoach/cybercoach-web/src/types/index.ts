// ===== 运动类型枚举 =====
export type SportType = 'running' | 'swimming';
export type SwimStyle = 'freestyle' | 'breaststroke' | 'backstroke' | 'butterfly' | 'mixed';
export type RecordSource = 'manual' | 'ocr';
export type IntensityLevel = 'low' | 'medium' | 'high';
export type GoalType = 'fitness' | 'fat_loss' | 'endurance' | 'habit' | 'test_prep';

// ===== 运动详情 =====
export interface RunningDetail {
  pace_sec_per_km: number;    // 每公里用时（秒）
  cadence_spm: number;        // 步频
  stride_cm: number;          // 步幅（厘米）
}

export interface SwimmingDetail {
  swim_style: SwimStyle;
  laps: number;               // 趟数
  pace_sec_per_100m: number;  // 每 100 米用时（秒）
}

// ===== 运动记录 =====
export interface SportRecord {
  record_id: string;
  user_id: string;
  sport_type: SportType;
  recorded_at: string;        // ISO 8601
  duration_s: number;         // 秒
  distance_m: number;         // 米
  avg_hr_bpm: number;
  peak_hr_bpm: number;
  rpe?: number;               // 主观疲劳评分 1-10
  note?: string;
  running_detail?: RunningDetail;
  swimming_detail?: SwimmingDetail;
  source: RecordSource;
  created_at: string;
  updated_at: string;
}

// ===== 创建记录请求 =====
export interface CreateRecordRequest {
  sport_type: SportType;
  recorded_at: string;
  duration_s: number;
  distance_m: number;
  avg_hr_bpm: number;
  peak_hr_bpm: number;
  rpe?: number;
  note?: string;
  running_detail?: RunningDetail;
  swimming_detail?: SwimmingDetail;
}

// ===== OCR 相关 =====
export interface OcrParseRequest {
  sport_type: SportType;
  image: File;
}

export interface OcrDraft {
  draft_id: string;
  sport_type: SportType;
  confidence: number;
  parsed: ParsedFields;
  raw_text: string;
  warnings: string[];
}

export interface ParsedFields {
  recorded_at?: string;
  duration_s?: number;
  distance_m?: number;
  avg_hr_bpm?: number;
  peak_hr_bpm?: number;
  running_detail?: Partial<RunningDetail>;
  swimming_detail?: Partial<SwimmingDetail>;
}

// ===== 报告相关 =====
export interface GenerateReportRequest {
  record_id: string;
}

export interface RecoveryAdvice {
  rest_hours: number;
  stretch: string;
  hydration_ml: number;
}

export interface NextWorkoutAdvice {
  sport_type: SportType;
  duration_s: number;
  target_intensity: IntensityLevel;
}

export interface RiskAlert {
  message: string;
  severity: 'warning' | 'danger';
}

export interface SportReport {
  report_id: string;
  record_id: string;
  intensity_level: IntensityLevel;
  intensity_reason: string[];
  recovery_advice: RecoveryAdvice;
  next_workout_advice: NextWorkoutAdvice;
  encouragement: string;
  risk_alerts: RiskAlert[];
  disclaimer: string;
  generated_at: string;
}

// ===== 周报 =====
export interface WeeklyReport {
  week_start: string;
  week_end: string;
  workout_count: number;
  total_duration_s: number;
  total_distance_m: number;
  avg_hr_bpm: number;
  intensity_distribution: Record<IntensityLevel, number>;
  highlights: string[];
  suggestions: string[];
}

// ===== 训练计划 =====
export interface GeneratePlanRequest {
  goal: GoalType;
  available_days_per_week: number;
  max_duration_s_per_session: number;
  preferred_sports: SportType[];
}

export interface PlanDay {
  day: string;
  type: SportType;
  duration_s: number;
  intensity: IntensityLevel;
  notes: string;
}

export interface TrainingPlan {
  plan_id: string;
  week_plan: PlanDay[];
  generated_at: string;
}

// ===== 提醒设置 =====
export interface ReminderSettings {
  enabled: boolean;
  train_reminder_time: string;   // HH:mm
  makeup_reminder_enabled: boolean;
  timezone: string;
}

export interface UpdateReminderRequest {
  enabled: boolean;
  train_reminder_time: string;
  makeup_reminder_enabled: boolean;
  timezone: string;
}

// ===== API 通用响应 =====
export interface ApiResponse<T> {
  code: number;
  message: string;
  data: T;
}

export interface Pagination {
  page: number;
  page_size: number;
  total: number;
}

export interface PaginatedList<T> {
  list: T[];
  pagination: Pagination;
}
