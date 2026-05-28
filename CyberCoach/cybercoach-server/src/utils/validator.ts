import type { ZodSchema } from 'zod';
import { fromError } from 'zod-validation-error';
import { AppError, ErrorCodes } from './errors.ts';

/** 校验数据，失败抛出 AppError */
export function validate<T>(schema: ZodSchema<T>, data: unknown): T {
  const result = schema.safeParse(data);
  if (!result.success) {
    const message = fromError(result.error).message;
    throw new AppError(ErrorCodes.INVALID_PARAM, message);
  }
  return result.data;
}
