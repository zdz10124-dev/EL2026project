import 'dotenv/config';
import { initDatabase, db } from './index.ts';
import { sportRecords, reminderSettings } from './schema.ts';

initDatabase();

const userId = 'usr_seed_001';
const now = new Date();

const seedData = [
  {
    record_id: 'rec_seed_001',
    user_id: userId,
    sport_type: 'running' as const,
    recorded_at: new Date(now.getTime() - 86400000).toISOString(),
    duration_s: 2100,
    distance_m: 6000,
    avg_hr_bpm: 155,
    peak_hr_bpm: 175,
    rpe: 6,
    note: '傍晚操场跑',
    detail_json: JSON.stringify({ pace_sec_per_km: 350, cadence_spm: 170, stride_cm: 100 }),
    source: 'manual' as const,
    created_at: now.toISOString(),
    updated_at: now.toISOString(),
  },
  {
    record_id: 'rec_seed_002',
    user_id: userId,
    sport_type: 'running' as const,
    recorded_at: new Date(now.getTime() - 3 * 86400000).toISOString(),
    duration_s: 1500,
    distance_m: 4000,
    avg_hr_bpm: 162,
    peak_hr_bpm: 185,
    rpe: 7,
    note: '间歇跑训练',
    detail_json: JSON.stringify({ pace_sec_per_km: 375, cadence_spm: 175, stride_cm: 95 }),
    source: 'manual' as const,
    created_at: now.toISOString(),
    updated_at: now.toISOString(),
  },
  {
    record_id: 'rec_seed_003',
    user_id: userId,
    sport_type: 'swimming' as const,
    recorded_at: new Date(now.getTime() - 5 * 86400000).toISOString(),
    duration_s: 2700,
    distance_m: 1500,
    avg_hr_bpm: 145,
    peak_hr_bpm: 165,
    rpe: 5,
    note: '游泳馆自由泳',
    detail_json: JSON.stringify({ swim_style: 'freestyle', laps: 60, pace_sec_per_100m: 108 }),
    source: 'manual' as const,
    created_at: now.toISOString(),
    updated_at: now.toISOString(),
  },
];

async function seed() {
  // 清空并插入种子数据
  await db.delete(sportRecords);
  await db.delete(reminderSettings);

  for (const record of seedData) {
    await db.insert(sportRecords).values(record);
  }

  await db.insert(reminderSettings).values({
    user_id: userId,
    enabled: true,
    train_reminder_time: '19:00',
    makeup_reminder_enabled: true,
    timezone: 'Asia/Shanghai',
    updated_at: now.toISOString(),
  });

  console.log(`✅ 已插入 ${seedData.length} 条种子记录`);
  process.exit(0);
}

seed().catch((err) => {
  console.error('种子数据插入失败:', err);
  process.exit(1);
});
