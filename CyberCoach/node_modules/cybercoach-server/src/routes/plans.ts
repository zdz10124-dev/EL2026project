import { Hono } from 'hono';
import { z } from 'zod';
import { validate } from '../utils/validator.ts';
import { success } from '../utils/response.ts';
import { hasLLM, aiGeneratePlan } from '../services/ai.ts';
import { v4 } from '../utils/id.ts';

const plans = new Hono();

const generatePlanSchema = z.object({
  goal: z.enum(['fitness', 'fat_loss', 'endurance', 'habit', 'test_prep']),
  available_days_per_week: z.number().int().min(1).max(7),
  max_duration_s_per_session: z.number().int().positive(),
  preferred_sports: z.array(z.enum(['running', 'swimming'])).min(1),
});

/** Mock 训练计划 */
function mockPlan(req: z.infer<typeof generatePlanSchema>) {
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const plan = days.slice(0, req.available_days_per_week).map((day, i) => ({
    day,
    type: req.preferred_sports[i % req.preferred_sports.length],
    duration_s: Math.min(1800 + i * 300, req.max_duration_s_per_session),
    intensity: (['low', 'medium', 'high', 'medium', 'low', 'high', 'medium'] as const)[i],
    notes: ['轻松跑', '匀速训练', '间歇训练', '恢复游泳', '轻松跑', '长距离拉练', '主动恢复'][i],
  }));
  return {
    plan_id: `plan_${v4()}`,
    week_plan: plan,
    generated_at: new Date().toISOString(),
  };
}

// ===== POST /plans/generate =====

plans.post('/generate', async (c) => {
  const body = validate(generatePlanSchema, await c.req.json());

  if (hasLLM) {
    try {
      const aiResult = await aiGeneratePlan(body);
      return success(c, {
        plan_id: `plan_${v4()}`,
        week_plan: aiResult.week_plan.map(d => ({
          ...d,
          duration_s: Math.min(d.duration_s, body.max_duration_s_per_session),
        })),
        generated_at: new Date().toISOString(),
      });
    } catch {
      // fallback to mock
    }
  }

  await new Promise(r => setTimeout(r, 600));
  return success(c, mockPlan(body));
});

export default plans;
