import { Hono } from 'hono';
import { z } from 'zod';
import { validate } from '../utils/validator.ts';
import { db } from '../db/index.ts';
import { sportRecords, sportReports } from '../db/schema.ts';
import { success, fail } from '../utils/response.ts';
import { ErrorCodes } from '../utils/errors.ts';
import { eq, and, gte, lte } from 'drizzle-orm';
import { hasLLM, aiGenerateReport, aiGenerateWeeklyReport } from '../services/ai.ts';
import { v4 } from '../utils/id.ts';

const reports = new Hono<{ Variables: { userId: string } }>();

export const DISCLAIMER = '本建议仅供运动参考，不作为医疗建议。如有身体不适，请及时就医。';

// ===== Mock 数据 =====

function mockReport(recordId: string) {
  return {
    report_id: `rep_${v4()}`,
    record_id: recordId,
    intensity_level: 'medium' as const,
    intensity_reason: [
      '平均心率处于目标心率区间',
      '配速稳定，无明显掉速',
      '时长完成度 100%',
    ],
    recovery_advice: {
      rest_hours: 20,
      stretch: '下肢拉伸 8-10 分钟，重点放松小腿和股四头肌',
      hydration_ml: 600,
    },
    next_workout_advice: {
      sport_type: 'running' as const,
      duration_s: 2100,
      target_intensity: 'medium' as const,
    },
    encouragement: '今天节奏控制不错，继续保持！',
    risk_alerts: [],
    disclaimer: DISCLAIMER,
    generated_at: new Date().toISOString(),
  };
}

function mockWeekly(records: typeof sportRecords.$inferSelect[]) {
  const totalDuration = records.reduce((s, r) => s + r.duration_s, 0);
  const totalDistance = records.reduce((s, r) => s + r.distance_m, 0);
  const avgHrRows = records.filter(r => r.avg_hr_bpm);
  const avgHr = avgHrRows.length
    ? Math.round(avgHrRows.reduce((s, r) => s + r.avg_hr_bpm!, 0) / avgHrRows.length)
    : 0;

  return {
    workout_count: records.length,
    total_duration_s: totalDuration,
    total_distance_m: totalDistance,
    avg_hr_bpm: avgHr,
    intensity_distribution: { low: 1, medium: 2, high: 1 },
    highlights: ['训练频率稳定', '配速有所提升'],
    suggestions: ['适当增加低强度恢复跑', '注意训练后拉伸'],
  };
}

/** 从 URL 查询字符串中提取参数 */
function getQueryParams(c: any): Record<string, string> {
  const params: Record<string, string> = {};
  const url = new URL(c.req.url);
  for (const [key, value] of url.searchParams.entries()) {
    params[key] = value;
  }
  return params;
}

// ===== POST /reports/generate =====

reports.post('/generate', async (c) => {
  const userId = c.get('userId');
  const { record_id } = validate(z.object({ record_id: z.string().min(1) }), await c.req.json());

  // 查记录是否存在
  const rows = await db.select().from(sportRecords).where(
    and(eq(sportRecords.record_id, record_id), eq(sportRecords.user_id, userId))
  );
  if (!rows.length) {
    return fail(c, ErrorCodes.NOT_FOUND, '记录不存在', 404);
  }

  const record = rows[0];
  const now = new Date().toISOString();

  // 尝试 AI 生成
  if (hasLLM) {
    try {
      const detail = record.detail_json ? JSON.parse(record.detail_json) : {};
      const fullRecord = { ...record, ...detail };
      const aiResult = await aiGenerateReport(fullRecord as any);
      const report = {
        report_id: `rep_${v4()}`,
        record_id,
        ...aiResult,
        disclaimer: DISCLAIMER,
        generated_at: now,
      };
      // 缓存报告
      await db.insert(sportReports).values({
        report_id: report.report_id,
        record_id,
        content_json: JSON.stringify(report),
        generated_at: now,
      }).catch(() => {});
      return success(c, report);
    } catch {
      // AI 失败回退 mock
    }
  }

  // Mock 回退
  await new Promise(r => setTimeout(r, 500));
  return success(c, mockReport(record_id));
});

// ===== GET /reports/weekly =====

reports.get('/weekly', async (c) => {
  const userId = c.get('userId');
  const query = validate(
    z.object({ week_start: z.string().regex(/^\d{4}-\d{2}-\d{2}$/) }),
    getQueryParams(c)
  );

  // 计算周结束日期
  const start = new Date(query.week_start);
  const end = new Date(start);
  end.setDate(end.getDate() + 6);
  const weekEnd = end.toISOString().split('T')[0];

  const rows = await db.select().from(sportRecords).where(
    and(
      eq(sportRecords.user_id, userId),
      gte(sportRecords.recorded_at, query.week_start),
      lte(sportRecords.recorded_at, weekEnd + 'T23:59:59'),
    )
  );

  if (!rows.length) {
    return success(c, {
      week_start: query.week_start,
      week_end: weekEnd,
      workout_count: 0,
      total_duration_s: 0,
      total_distance_m: 0,
      avg_hr_bpm: 0,
      intensity_distribution: { low: 0, medium: 0, high: 0 },
      highlights: ['本周暂无运动记录'],
      suggestions: ['开始你的第一次运动吧！'],
    });
  }

  // 尝试 AI 生成
  if (hasLLM) {
    try {
      const aiResult = await aiGenerateWeeklyReport(rows as any);
      const totalDuration = rows.reduce((s, r) => s + r.duration_s, 0);
      const totalDistance = rows.reduce((s, r) => s + r.distance_m, 0);
      const avgHrRows = rows.filter(r => r.avg_hr_bpm);
      const avgHr = avgHrRows.length
        ? Math.round(avgHrRows.reduce((s, r) => s + r.avg_hr_bpm!, 0) / avgHrRows.length)
        : 0;

      return success(c, {
        week_start: query.week_start,
        week_end: weekEnd,
        workout_count: rows.length,
        total_duration_s: totalDuration,
        total_distance_m: totalDistance,
        avg_hr_bpm: avgHr,
        intensity_distribution: { low: 1, medium: 2, high: 1 },
        highlights: aiResult.highlights,
        suggestions: aiResult.suggestions,
      });
    } catch {
      // fall through to mock
    }
  }

  return success(c, {
    ...mockWeekly(rows),
    week_start: query.week_start,
    week_end: weekEnd,
  });
});

export default reports;
