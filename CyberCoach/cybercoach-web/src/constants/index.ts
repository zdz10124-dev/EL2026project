import type { SportType, SwimStyle, IntensityLevel, GoalType } from '../types';

export const SPORT_TYPE_OPTIONS: { value: SportType; label: string }[] = [
  { value: 'running', label: '跑步' },
  { value: 'swimming', label: '游泳' },
];

export const SWIM_STYLE_OPTIONS: { value: SwimStyle; label: string }[] = [
  { value: 'freestyle', label: '自由泳' },
  { value: 'breaststroke', label: '蛙泳' },
  { value: 'backstroke', label: '仰泳' },
  { value: 'butterfly', label: '蝶泳' },
  { value: 'mixed', label: '混合' },
];

export const INTENSITY_OPTIONS: { value: IntensityLevel; label: string }[] = [
  { value: 'low', label: '低强度' },
  { value: 'medium', label: '中强度' },
  { value: 'high', label: '高强度' },
];

export const GOAL_OPTIONS: { value: GoalType; label: string }[] = [
  { value: 'fitness', label: '体能提升' },
  { value: 'fat_loss', label: '减脂' },
  { value: 'endurance', label: '耐力训练' },
  { value: 'habit', label: '习惯养成' },
  { value: 'test_prep', label: '体测备考' },
];

export const DAY_OPTIONS = [
  { value: 'Mon', label: '周一' },
  { value: 'Tue', label: '周二' },
  { value: 'Wed', label: '周三' },
  { value: 'Thu', label: '周四' },
  { value: 'Fri', label: '周五' },
  { value: 'Sat', label: '周六' },
  { value: 'Sun', label: '周日' },
];

export const FIELD_UNITS = {
  duration_min: '分钟',
  distance_m: '米',
  avg_hr_bpm: 'bpm',
  peak_hr_bpm: 'bpm',
  rpe: '1-10',
  pace_per_km: '分:秒/公里',
  cadence_spm: '步/分钟',
  stride_cm: '厘米',
  pace_per_100m: '分:秒/100米',
  laps: '趟',
} as const;

export const FIELD_RANGES = {
  duration_min: { min: 1, max: 600, label: '运动时长' },
  distance_m: { min: 1, max: 100000, label: '运动距离' },
  avg_hr_bpm: { min: 30, max: 230, label: '平均心率' },
  peak_hr_bpm: { min: 30, max: 230, label: '峰值心率' },
  rpe: { min: 1, max: 10, label: '主观疲劳评分' },
} as const;

export const API_BASE_URL = '/api/v1';
export const APP_NAME = '赛博教练';

export const DISCLAIMER_TEXT = '本建议仅供运动参考，不作为医疗建议。如有身体不适，请及时就医。';
