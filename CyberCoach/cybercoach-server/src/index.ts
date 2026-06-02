import 'dotenv/config';
import { serve } from '@hono/node-server';
import { Hono } from 'hono';
import { cors } from 'hono/cors';
import { initDatabase } from './db/index.ts';
import { authMiddleware } from './middleware/auth.ts';
import { fail } from './utils/response.ts';
import { AppError, ErrorCodes } from './utils/errors.ts';
import recordsRouter from './routes/records.ts';
import ocrRouter from './routes/ocr.ts';
import reportsRouter from './routes/reports.ts';
import plansRouter from './routes/plans.ts';
import remindersRouter from './routes/reminders.ts';

// 初始化数据库
initDatabase();

const app = new Hono();

// 全局中间件
app.use('/*', cors());
app.use('/api/v1/*', authMiddleware);

// 健康检查（不需要认证）
app.get('/health', (c) => c.json({ status: 'ok', time: new Date().toISOString() }));

// 挂载路由
app.route('/api/v1/records', recordsRouter);
app.route('/api/v1/ocr', ocrRouter);
app.route('/api/v1/reports', reportsRouter);
app.route('/api/v1/plans', plansRouter);
app.route('/api/v1/reminders', remindersRouter);

// 全局错误处理
app.onError((err, c) => {
  console.error(err);
  if (err instanceof AppError) {
    return fail(c, err.code, err.message, err.status);
  }
  return fail(c, ErrorCodes.INTERNAL, '服务器内部错误', 500);
});

// 启动
const port = parseInt(process.env.PORT || '3001', 10);
console.log(`🚀 CyberCoach 后端启动成功: http://localhost:${port}`);
console.log(`📋 API 基础路径: /api/v1`);
console.log(`🤖 LLM: ${process.env.LLM_API_KEY ? '已配置 (' + (process.env.LLM_MODEL || 'gpt-4o') + ')' : '未配置（使用 Mock 数据）'}`);

serve({ fetch: app.fetch, port });
