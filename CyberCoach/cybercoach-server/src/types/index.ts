export type SportType = 'running' | 'swimming';
export type SwimStyle = 'freestyle' | 'breaststroke' | 'backstroke' | 'butterfly' | 'mixed';
export type RecordSource = 'manual' | 'ocr';
export type IntensityLevel = 'low' | 'medium' | 'high';
export type GoalType = 'fitness' | 'fat_loss' | 'endurance' | 'habit' | 'test_prep';

export interface RunningDetail {
  pace_sec_per_km: number;
  cadence_spm: number;
  stride_cm: number;
}

export interface SwimmingDetail {
  swim_style: SwimStyle;
  laps: number;
  pace_sec_per_100m: number;
}

export interface SportRecord {
  record_id: string;
  user_id: string;
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
  source: RecordSource;
  created_at: string;
  updated_at: string;
}

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

export interface OcrDraft {
  draft_id: string;
  sport_type: SportType;
  confidence: number;
  parsed: Partial<{
    recorded_at: string;
    duration_s: number;
    distance_m: number;
    avg_hr_bpm: number;
    peak_hr_bpm: number;
    running_detail: Partial<RunningDetail>;
    swimming_detail: Partial<SwimmingDetail>;
  }>;
  raw_text: string;
  warnings: string[];
}

export interface SportReport {
  report_id: string;
  record_id: string;
  intensity_level: IntensityLevel;
  intensity_reason: string[];
  recovery_advice: {
    rest_hours: number;
    stretch: string;
    hydration_ml: number;
  };
  next_workout_advice: {
    sport_type: SportType;
    duration_s: number;
    target_intensity: IntensityLevel;
  };
  encouragement: string;
  risk_alerts: { message: string; severity: 'warning' | 'danger' }[];
  disclaimer: string;
  generated_at: string;
}

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

export interface ReminderSettings {
  enabled: boolean;
  train_reminder_time: string;
  makeup_reminder_enabled: boolean;
  timezone: string;
}

export interface UpdateReminderRequest {
  enabled: boolean;
  train_reminder_time: string;
  makeup_reminder_enabled: boolean;
  timezone: string;
}

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
