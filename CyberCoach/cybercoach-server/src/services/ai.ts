import type { SportRecord, GeneratePlanRequest } from '../types/index.ts';

// ===== LLM 配置 =====

const apiKey = process.env.LLM_API_KEY;
const baseURL = (process.env.LLM_BASE_URL || 'https://api.openai.com/v1').replace(/\/+$/, '');
const model = process.env.LLM_MODEL || 'gpt-4o';

export const hasLLM = !!apiKey;

// ===== HTTP 调用 LLM =====

interface ChatMessage {
  role: 'system' | 'user' | 'assistant';
  content: string | ChatContentPart[];
}

interface ChatContentPart {
  type: 'text' | 'image_url';
  text?: string;
  image_url?: { url: string };
}

async function callLLM(systemPrompt: string, userPrompt: string): Promise<string> {
  const res = await fetch(`${baseURL}/chat/completions`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model,
      messages: [
        { role: 'system', content: systemPrompt },
        { role: 'user', content: userPrompt },
      ],
      response_format: { type: 'json_object' },
      temperature: 0.7,
    }),
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`LLM API 错误 (${res.status}): ${text}`);
  }

  const json = await res.json();
  return json.choices?.[0]?.message?.content || '';
}

async function callLLMWithImage(systemPrompt: string, text: string, imageBase64: string): Promise<string> {
  const res = await fetch(`${baseURL}/chat/completions`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model,
      messages: [
        { role: 'system', content: systemPrompt },
        {
          role: 'user',
          content: [
            { type: 'text', text },
            { type: 'image_url', image_url: { url: `data:image/png;base64,${imageBase64}` } },
          ],
        },
      ],
      response_format: { type: 'json_object' },
      temperature: 0.3,
    }),
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`LLM API 错误 (${res.status}): ${text}`);
  }

  const json = await res.json();
  return json.choices?.[0]?.message?.content || '';
}

// ===== 1. 单次运动报告 =====

const REPORT_SYSTEM_PROMPT = `你是一个专业的运动科学教练，擅长分析运动数据并提供建议。请用中文回复。
分析单次运动记录，输出 JSON，格式：
{
  "intensity_level": "low|medium|high",
  "intensity_reason": ["原因1", "原因2", "原因3"],
  "recovery_advice": {
    "rest_hours": 数字,
    "stretch": "拉伸建议",
    "hydration_ml": 数字
  },
  "next_workout_advice": {
    "sport_type": "running|swimming",
    "duration_s": 数字,
    "target_intensity": "low|medium|high"
  },
  "encouragement": "1-2句激励语",
  "risk_alerts": [{"message": "提示", "severity": "warning|danger"}]
}`;

export async function aiGenerateReport(record: SportRecord) {
  const userPrompt = `运动类型：${record.sport_type}
时长：${Math.round(record.duration_s / 60)} 分钟
距离：${record.distance_m} 米
平均心率：${record.avg_hr_bpm} bpm
峰值心率：${record.peak_hr_bpm} bpm
主观疲劳评分：${record.rpe || '未记录'}
备注：${record.note || '无'}`;

  const content = await callLLM(REPORT_SYSTEM_PROMPT, userPrompt);
  return JSON.parse(content);
}

// ===== 2. 周报 =====

export async function aiGenerateWeeklyReport(records: SportRecord[]) {
  const summary = records.map((r, i) =>
    `[${i + 1}] ${r.sport_type} ${Math.round(r.duration_s / 60)}分钟 ${r.distance_m}米 平均心率${r.avg_hr_bpm}`
  ).join('\n');

  const totalDuration = Math.round(records.reduce((s, r) => s + r.duration_s, 0) / 60);
  const totalDistance = records.reduce((s, r) => s + r.distance_m, 0);

  const userPrompt = `本周共 ${records.length} 次训练
总时长：${totalDuration} 分钟
总距离：${totalDistance} 米
详细记录：
${summary || '无'}`;

  const content = await callLLM(
    `你是一个专业的运动科学教练。分析一周运动数据，输出 JSON，格式：
{
  "highlights": ["亮点1", "亮点2"],
  "suggestions": ["建议1", "建议2"]
}`,
    userPrompt,
  );
  return JSON.parse(content);
}

// ===== 3. 训练计划 =====

export async function aiGeneratePlan(req: GeneratePlanRequest) {
  const userPrompt = `目标：${req.goal}
每周可用天数：${req.available_days_per_week}
每次最长训练时间：${Math.round(req.max_duration_s_per_session / 60)} 分钟
偏好运动：${req.preferred_sports.join('、')}`;

  const content = await callLLM(
    `你是一个专业的运动科学教练。根据用户目标和可用时间制定一周训练计划。输出 JSON，格式：
{
  "week_plan": [
    {"day": "Mon|Tue|Wed|Thu|Fri|Sat|Sun", "type": "running|swimming", "duration_s": 数字, "intensity": "low|medium|high", "notes": "训练说明"}
  ]
}
要求：每周至少安排2天休息。`,
    userPrompt,
  );
  return JSON.parse(content);
}

// ===== 4. OCR 解析 =====

export async function aiParseOcr(imageBase64: string, sportType: string) {
  const content = await callLLMWithImage(
    `你是一个运动截图解析器，从运动 App 截图中提取结构化运动数据。输出 JSON，格式：
{
  "parsed": {
    "duration_s": 数字,
    "distance_m": 数字,
    "avg_hr_bpm": 数字,
    "peak_hr_bpm": 数字
  },
  "confidence": 0.0-1.0,
  "warnings": ["缺失字段或其他问题"],
  "raw_text": "从图片中识别出的原始文本"
}`,
    `请从这张${sportType === 'running' ? '跑步' : '游泳'}截图中提取运动数据。`,
    imageBase64,
  );
  return JSON.parse(content);
}
