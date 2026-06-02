import { Hono } from 'hono';
import { z } from 'zod';
import { validate } from '../utils/validator.ts';
import { db } from '../db/index.ts';
import { reminderSettings } from '../db/schema.ts';
import { success } from '../utils/response.ts';
import { eq } from 'drizzle-orm';

const reminders = new Hono<{ Variables: { userId: string } }>();

const updateSchema = z.object({
  enabled: z.boolean(),
  train_reminder_time: z.string().regex(/^\d{2}:\d{2}$/),
  makeup_reminder_enabled: z.boolean(),
  timezone: z.string().min(1),
});

// ===== GET /reminders/settings =====

reminders.get('/settings', async (c) => {
  const userId = c.get('userId');
  const rows = await db.select().from(reminderSettings).where(eq(reminderSettings.user_id, userId));

  if (!rows.length) {
    return success(c, {
      enabled: false,
      train_reminder_time: '19:00',
      makeup_reminder_enabled: true,
      timezone: 'Asia/Shanghai',
    });
  }

  const row = rows[0];
  return success(c, {
    enabled: row.enabled,
    train_reminder_time: row.train_reminder_time,
    makeup_reminder_enabled: row.makeup_reminder_enabled,
    timezone: row.timezone,
  });
});

// ===== PUT /reminders/settings =====

reminders.put('/settings', async (c) => {
  const userId = c.get('userId');
  const body = validate(updateSchema, await c.req.json());
  const now = new Date().toISOString();

  await db.insert(reminderSettings).values({ user_id: userId, ...body, updated_at: now })
    .onConflictDoUpdate({
      target: reminderSettings.user_id,
      set: { ...body, updated_at: now },
    });

  return success(c, { ...body, updated_at: now });
});

export default reminders;
