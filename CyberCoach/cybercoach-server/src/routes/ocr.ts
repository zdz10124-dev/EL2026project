import { Hono } from 'hono';
import { z } from 'zod';
import { zValidator } from '../utils/validator.ts';
import { success, fail } from '../utils/response.ts';
import { ErrorCodes } from '../utils/errors.ts';
import { hasLLM, aiParseOcr } from '../services/ai.ts';

const ocr = new Hono();

/** Mock OCR 结果（LLM 未配置时使用） */
function mockOcrResult(sportType: string) {
  return {
    draft_id: `draft_${Date.now()}`,
    sport_type: sportType,
    confidence: 0.85,
    parsed: {
      duration_s: 1800,
      distance_m: 5000,
      avg_hr_bpm: 150,
      peak_hr_bpm: 175,
    },
    raw_text: '运动时长 30:00\n距离 5.0km\n平均心率 150\n峰值心率 175',
    warnings: ['请确认数据是否准确'],
  };
}

// ===== POST /ocr/parse =====

ocr.post('/parse', async (c) => {
  const formData = await c.req.formData();
  const sportType = formData.get('sport_type') as string | null;
  const image = formData.get('image') as File | null;

  if (!sportType || !['running', 'swimming'].includes(sportType)) {
    return fail(c, ErrorCodes.INVALID_PARAM, 'sport_type 必须为 running 或 swimming');
  }
  if (!image) {
    return fail(c, ErrorCodes.INVALID_PARAM, '缺少 image 文件');
  }

  // 使用 LLM 解析
  if (hasLLM) {
    try {
      const buffer = await image.arrayBuffer();
      const base64 = Buffer.from(buffer).toString('base64');
      const result = await aiParseOcr(base64, sportType);
      return success(c, {
        draft_id: `draft_${Date.now()}`,
        sport_type: sportType,
        confidence: result.confidence,
        parsed: result.parsed,
        raw_text: result.raw_text,
        warnings: result.warnings,
      });
    } catch (err) {
      return fail(c, ErrorCodes.OCR_FAILED, `OCR 解析失败: ${(err as Error).message}`, 500);
    }
  }

  // Mock 结果
  await new Promise(r => setTimeout(r, 800));
  return success(c, mockOcrResult(sportType));
});

export default ocr;
