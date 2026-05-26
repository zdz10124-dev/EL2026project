import { Context } from 'hono';

/** 成功响应包装 */
export function success<T>(c: Context, data: T, status = 200) {
  return c.json({ code: 0, message: 'ok', data }, status);
}

/** 失败响应包装 */
export function fail(c: Context, code: number, message: string, status = 400) {
  return c.json({ code, message, data: null }, status);
}
