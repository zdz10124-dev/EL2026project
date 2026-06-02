import type { CreateRecordRequest } from '../types';
import { FIELD_RANGES } from '../constants';

export interface ValidationError {
  field: string;
  message: string;
}

export function validateCreateRecord(data: CreateRecordRequest): ValidationError[] {
  const errors: ValidationError[] = [];

  // 时长 > 0
  if (data.duration_s <= 0) {
    errors.push({ field: 'duration_s', message: '运动时长必须大于 0' });
  }

  // 距离 > 0
  if (data.distance_m <= 0) {
    errors.push({ field: 'distance_m', message: '运动距离必须大于 0' });
  }

  // 峰值心率 >= 平均心率
  if (data.peak_hr_bpm < data.avg_hr_bpm) {
    errors.push({ field: 'peak_hr_bpm', message: '峰值心率不能低于平均心率' });
  }

  // 心率范围
  if (data.avg_hr_bpm < FIELD_RANGES.avg_hr_bpm.min || data.avg_hr_bpm > FIELD_RANGES.avg_hr_bpm.max) {
    errors.push({ field: 'avg_hr_bpm', message: `平均心率范围为 ${FIELD_RANGES.avg_hr_bpm.min}-${FIELD_RANGES.avg_hr_bpm.max} bpm` });
  }
  if (data.peak_hr_bpm < FIELD_RANGES.peak_hr_bpm.min || data.peak_hr_bpm > FIELD_RANGES.peak_hr_bpm.max) {
    errors.push({ field: 'peak_hr_bpm', message: `峰值心率范围为 ${FIELD_RANGES.peak_hr_bpm.min}-${FIELD_RANGES.peak_hr_bpm.max} bpm` });
  }

  // sport_type 必须附带扩展字段
  if (data.sport_type === 'running' && !data.running_detail) {
    errors.push({ field: 'running_detail', message: '跑步类型必须填写跑步扩展信息' });
  }
  if (data.sport_type === 'swimming' && !data.swimming_detail) {
    errors.push({ field: 'swimming_detail', message: '游泳类型必须填写游泳扩展信息' });
  }

  return errors;
}

export function formatValidationErrors(errors: ValidationError[]): string {
  return errors.map(e => e.message).join('；');
}
