import { API_BASE_URL } from '../constants';
import type {
  ApiResponse,
  PaginatedList,
  SportRecord,
  CreateRecordRequest,
  OcrDraft,
  SportReport,
  WeeklyReport,
  TrainingPlan,
  GeneratePlanRequest,
  ReminderSettings,
  UpdateReminderRequest,
} from '../types';

// ===== Mock 数据（后端未就绪时使用） =====

const useMock = true;

const mockRecordId = 'rec_01J0xxxxxxxxxxxx';

/** 生成一条模拟跑步记录 */
function makeMockRecord(overrides?: Partial<SportRecord>): SportRecord {
  const now = new Date();
  return {
    record_id: mockRecordId,
    user_id: 'usr_mock_001',
    sport_type: 'running',
    recorded_at: now.toISOString(),
    duration_s: 1800,
    distance_m: 5000,
    avg_hr_bpm: 152,
    peak_hr_bpm: 178,
    rpe: 6,
    note: '晚跑，状态不错',
    running_detail: { pace_sec_per_km: 330, cadence_spm: 172, stride_cm: 105 },
    source: 'manual',
    created_at: now.toISOString(),
    updated_at: now.toISOString(),
    ...overrides,
  } as SportRecord;
}

/** 模拟多条记录 */
const mockRecords: SportRecord[] = [
  makeMockRecord({
    recorded_at: new Date(Date.now() - 86400000).toISOString(),
    duration_s: 2100,
    distance_m: 6000,
  }),
  makeMockRecord({
    recorded_at: new Date(Date.now() - 3 * 86400000).toISOString(),
    duration_s: 1500,
    distance_m: 4000,
    avg_hr_bpm: 160,
  }),
  makeMockRecord({
    sport_type: 'swimming',
    recorded_at: new Date(Date.now() - 5 * 86400000).toISOString(),
    duration_s: 2700,
    distance_m: 1500,
    swimming_detail: { swim_style: 'freestyle', laps: 60, pace_sec_per_100m: 108 },
  }),
];

/** 模拟单次报告 */
const mockReport: SportReport = {
  report_id: 'rep_01J0xxxxxxxxxxxx',
  record_id: mockRecordId,
  intensity_level: 'medium',
  intensity_reason: [
    '平均心率 152 bpm，处于目标心率区间 2-3',
    '配速稳定，最后 2km 无明显掉速',
    '时长完成度 100%',
  ],
  recovery_advice: {
    rest_hours: 20,
    stretch: '下肢拉伸 8-10 分钟，重点放松小腿和股四头肌',
    hydration_ml: 600,
  },
  next_workout_advice: {
    sport_type: 'running',
    duration_s: 2100,
    target_intensity: 'medium',
  },
  encouragement: '今天节奏控制不错，继续保持！',
  risk_alerts: [],
  disclaimer: '本建议仅供运动参考，不作为医疗建议。',
  generated_at: new Date().toISOString(),
};

/** 模拟周报 */
const mockWeekly: WeeklyReport = {
  week_start: '2026-05-18',
  week_end: '2026-05-24',
  workout_count: 4,
  total_duration_s: 7800,
  total_distance_m: 18200,
  avg_hr_bpm: 149,
  intensity_distribution: { low: 1, medium: 2, high: 1 },
  highlights: ['训练频率较上周增加 1 次', '配速稳定性提高'],
  suggestions: ['下周增加 1 次低强度恢复跑', '游泳训练后补充拉伸'],
};

/** 模拟训练计划 */
const mockPlan: TrainingPlan = {
  plan_id: 'plan_01J0xxxxxxxxxxxx',
  week_plan: [
    { day: 'Mon', type: 'running', duration_s: 1800, intensity: 'low', notes: '轻松跑' },
    { day: 'Wed', type: 'swimming', duration_s: 2100, intensity: 'medium', notes: '技术练习 + 匀速' },
    { day: 'Fri', type: 'running', duration_s: 2400, intensity: 'high', notes: '间歇训练' },
    { day: 'Sun', type: 'running', duration_s: 2700, intensity: 'medium', notes: '长距离慢跑' },
  ],
  generated_at: new Date().toISOString(),
};

/** 模拟提醒设置 */
const mockReminder: ReminderSettings = {
  enabled: true,
  train_reminder_time: '19:00',
  makeup_reminder_enabled: true,
  timezone: 'Asia/Shanghai',
};

// ===== API 客户端 =====

class ApiClient {
  private deviceId: string;

  constructor() {
    this.deviceId = localStorage.getItem('device_id') || crypto.randomUUID();
    localStorage.setItem('device_id', this.deviceId);
  }

  private getHeaders(): HeadersInit {
    return {
      'Content-Type': 'application/json',
      'X-Device-Id': this.deviceId,
    };
  }

  private async request<T>(path: string, options?: RequestInit): Promise<ApiResponse<T>> {
    try {
      const res = await fetch(`${API_BASE_URL}${path}`, {
        ...options,
        headers: { ...this.getHeaders(), ...options?.headers },
      });
      return res.json();
    } catch {
      // 后端未就绪时返回模拟数据
      throw new Error('后端服务未连接');
    }
  }

  /** 创建运动记录 */
  async createRecord(data: CreateRecordRequest) {
    if (useMock) {
      await delay(300);
      return ok(makeMockRecord({ ...data, record_id: mockRecordId + Date.now() }));
    }
    return this.request<SportRecord>('/records', {
      method: 'POST',
      body: JSON.stringify(data),
    });
  }

  /** 查询记录列表 */
  async getRecords(params?: {
    sport_type?: string;
    start_date?: string;
    end_date?: string;
    page?: number;
    page_size?: number;
  }) {
    if (useMock) {
      await delay(300);
      let list = mockRecords;
      if (params?.sport_type) {
        list = list.filter(r => r.sport_type === params.sport_type);
      }
      return ok<PaginatedList<SportRecord>>({
        list,
        pagination: { page: params?.page || 1, page_size: params?.page_size || 20, total: list.length },
      });
    }
    const q = new URLSearchParams();
    if (params?.sport_type) q.set('sport_type', params.sport_type);
    if (params?.start_date) q.set('start_date', params.start_date);
    if (params?.end_date) q.set('end_date', params.end_date);
    if (params?.page) q.set('page', String(params.page));
    if (params?.page_size) q.set('page_size', String(params.page_size));
    return this.request<PaginatedList<SportRecord>>(`/records?${q.toString()}`);
  }

  /** 查询记录详情 */
  async getRecord(recordId: string) {
    if (useMock) {
      await delay(200);
      return ok(makeMockRecord({ record_id: recordId }));
    }
    return this.request<SportRecord>(`/records/${recordId}`);
  }

  /** 上传截图并解析 OCR 草稿 */
  async parseOcr(sportType: string, file: File) {
    if (useMock) {
      await delay(800);
      return ok<OcrDraft>({
        draft_id: 'draft_01J0xxxxxxxxxxxx',
        sport_type: sportType as 'running' | 'swimming',
        confidence: 0.88,
        parsed: {
          duration_s: 1800,
          distance_m: 5000,
          avg_hr_bpm: 150,
          peak_hr_bpm: 175,
          running_detail: { pace_sec_per_km: 325, cadence_spm: 170, stride_cm: 100 },
        },
        raw_text: '运动时长 30:00\n距离 5.0km\n平均心率 150\n...',
        warnings: ['步频数据未在截图区域找到'],
      });
    }
    const form = new FormData();
    form.append('sport_type', sportType);
    form.append('image', file);
    const res = await fetch(`${API_BASE_URL}/ocr/parse`, {
      method: 'POST',
      headers: { 'X-Device-Id': this.deviceId },
      body: form,
    });
    return res.json() as Promise<ApiResponse<OcrDraft>>;
  }

  /** 生成单次报告 */
  async generateReport(recordId: string) {
    if (useMock) {
      await delay(500);
      return ok<SportReport>({
        ...mockReport,
        record_id: recordId,
        generated_at: new Date().toISOString(),
      });
    }
    return this.request<SportReport>('/reports/generate', {
      method: 'POST',
      body: JSON.stringify({ record_id: recordId }),
    });
  }

  /** 获取周报 */
  async getWeeklyReport(weekStart: string) {
    if (useMock) {
      await delay(400);
      return ok<WeeklyReport>(mockWeekly);
    }
    return this.request<WeeklyReport>(`/reports/weekly?week_start=${weekStart}`);
  }

  /** 生成训练计划 */
  async generatePlan(data: GeneratePlanRequest) {
    if (useMock) {
      await delay(600);
      return ok<TrainingPlan>(mockPlan);
    }
    return this.request<TrainingPlan>('/plans/generate', {
      method: 'POST',
      body: JSON.stringify(data),
    });
  }

  /** 更新提醒设置 */
  async updateReminderSettings(data: UpdateReminderRequest) {
    if (useMock) {
      await delay(200);
      return ok<ReminderSettings>({ ...data, updated_at: new Date().toISOString() } as ReminderSettings);
    }
    return this.request<ReminderSettings>('/reminders/settings', {
      method: 'PUT',
      body: JSON.stringify(data),
    });
  }

  /** 获取提醒设置 */
  async getReminderSettings() {
    if (useMock) {
      await delay(200);
      return ok<ReminderSettings>(mockReminder);
    }
    return this.request<ReminderSettings>('/reminders/settings');
  }
}

/** 构造成功响应 */
function ok<T>(data: T): ApiResponse<T> {
  return { code: 0, message: 'ok', data };
}

/** 模拟网络延迟 */
function delay(ms: number) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

export const api = new ApiClient();
