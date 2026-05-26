import { randomUUID } from 'node:crypto';

/** 生成短 ID（取 UUID 前 12 位） */
export function v4(): string {
  return randomUUID().replace(/-/g, '').slice(0, 12);
}
