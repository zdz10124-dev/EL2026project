import { Hono } from 'hono';
import { z } from 'zod';
import { validate } from '../utils/validator.ts';
import { db } from '../db/index.ts';
import { sportRecords } from '../db/schema.ts';
import { success, fail } from '../utils/response.ts';
import { ErrorCodes } from '../utils/errors.ts';
import { eq, and, gte, lte, count, desc } from 'drizzle-orm';
import { v4 } from '../utils/id.ts';

const records = new Hono<{ Variables: { userId: string } }>();

// ===== 校验模式 =====

const runningDetailSchema = z.object({
  pace_sec_per_km: z.number().int().positive(),
  cadence_spm: z.number().int().positive(),
  stride_cm: z.number().positive(),
});

const swimmingDetailSchema = z.object({
  swim_style: z.enum(['freestyle', 'breaststroke', 'backstroke', 'butterfly', 'mixed']),
  laps: z.number().int().positive(),
  pace_sec_per_100m: z.number().int().positive(),
});

const createRecordSchema = z.object({
  sport_type: z.enum(['running', 'swimming']),
  recorded_at: z.string(),
  duration_s: z.number().int().positive(),
  distance_m: z.number().int().positive(),
  avg_hr_bpm: z.number().int().min(30).max(230),
  peak_hr_bpm: z.number().int().min(30).max(230),
  rpe: z.number().int().min(1).max(10).optional(),
  note: z.string().max(500).optional(),
  running_detail: runningDetailSchema.optional(),
  swimming_detail: swimmingDetailSchema.optional(),
}).refine(
  data => data.peak_hr_bpm >= data.avg_hr_bpm,
  { message: '峰值心率不能低于平均心率' }
).refine(
  data => !(data.sport_type === 'running' && !data.running_detail),
  { message: '跑步类型必须提供 running_detail' }
).refine(
  data => !(data.sport_type === 'swimming' && !data.swimming_detail),
  { message: '游泳类型必须提供 swimming_detail' }
);

const listQuerySchema = z.object({
  sport_type: z.enum(['running', 'swimming']).optional(),
  start_date: z.string().optional(),
  end_date: z.string().optional(),
  page: z.coerce.number().int().min(1).default(1),
  page_size: z.coerce.number().int().min(1).max(100).default(20),
});

function parseDetail(sportType: string, detailJson: string | null) {
  if (!detailJson) return {};
  const detail = JSON.parse(detailJson);
  if (sportType === 'running') return { running_detail: detail };
  return { swimming_detail: detail };
}

// ===== POST /records =====

records.post('/', async (c) => {
  const userId = c.get('userId');
  const body = validate(createRecordSchema, await c.req.json());
  const now = new Date().toISOString();
  const recordId = `rec_${v4()}`;

  const detailJson = body.sport_type === 'running'
    ? JSON.stringify(body.running_detail)
    : JSON.stringify(body.swimming_detail);

  await db.insert(sportRecords).values({
    record_id: recordId,
    user_id: userId,
    sport_type: body.sport_type,
    recorded_at: body.recorded_at,
    duration_s: body.duration_s,
    distance_m: body.distance_m,
    avg_hr_bpm: body.avg_hr_bpm,
    peak_hr_bpm: body.peak_hr_bpm,
    rpe: body.rpe,
    note: body.note,
    detail_json: detailJson,
    source: 'manual',
    created_at: now,
    updated_at: now,
  });

  return success(c, {
    record_id: recordId,
    user_id: userId,
    sport_type: body.sport_type,
    recorded_at: body.recorded_at,
    duration_s: body.duration_s,
    distance_m: body.distance_m,
    avg_hr_bpm: body.avg_hr_bpm,
    peak_hr_bpm: body.peak_hr_bpm,
    rpe: body.rpe,
    note: body.note,
    ...parseDetail(body.sport_type, detailJson),
    source: 'manual' as const,
    created_at: now,
    updated_at: now,
  }, 201);
});

// ===== GET /records =====

records.get('/', async (c) => {
  const userId = c.get('userId');

  // 解析查询参数
  const rawParams: Record<string, string> = {};
  for (const [key, values] of Object.entries(c.req.queries())) {
    if (values?.[0]) rawParams[key] = values[0];
  }
  const query = validate(listQuerySchema, rawParams);

  const conditions = [eq(sportRecords.user_id, userId)];
  if (query.sport_type) conditions.push(eq(sportRecords.sport_type, query.sport_type));
  if (query.start_date) conditions.push(gte(sportRecords.recorded_at, query.start_date!));
  if (query.end_date) conditions.push(lte(sportRecords.recorded_at, query.end_date!));

  const total = await db.select({ cnt: count() }).from(sportRecords).where(and(...conditions));
  const totalCount = total[0]?.cnt ?? 0;

  const rows = await db.select()
    .from(sportRecords)
    .where(and(...conditions))
    .orderBy(desc(sportRecords.recorded_at))
    .limit(query.page_size!)
    .offset((query.page! - 1) * query.page_size!);

  const list = rows.map(row => ({
    ...row,
    ...parseDetail(row.sport_type, row.detail_json),
    detail_json: undefined,
  }));

  return success(c, {
    list,
    pagination: {
      page: query.page!,
      page_size: query.page_size!,
      total: totalCount,
    },
  });
});

// ===== GET /records/:recordId =====

records.get('/:recordId', async (c) => {
  const userId = c.get('userId');
  const { recordId } = c.req.param();
  const rows = await db.select().from(sportRecords).where(
    and(eq(sportRecords.record_id, recordId), eq(sportRecords.user_id, userId))
  );
  if (!rows.length) {
    return fail(c, ErrorCodes.NOT_FOUND, '记录不存在', 404);
  }
  const row = rows[0];
  return success(c, { ...row, ...parseDetail(row.sport_type, row.detail_json), detail_json: undefined });
});

export default records;
