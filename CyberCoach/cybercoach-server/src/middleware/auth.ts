import { Context, Next } from 'hono';
import { fail } from '../utils/response.ts';
import { ErrorCodes } from '../utils/errors.ts';

/** 匿名认证中间件：从 X-Device-Id 获取用户标识 */
export async function authMiddleware(c: Context, next: Next) {
  const deviceId = c.req.header('X-Device-Id');
  if (!deviceId) {
    return fail(c, ErrorCodes.UNAUTHORIZED, 'missing X-Device-Id header', 401);
  }
  c.set('userId', deviceId);
  await next();
}
