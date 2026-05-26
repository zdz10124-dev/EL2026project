import type { SportType } from '../types';

/**
 * 将秒转为 "X分Y秒" 或 "X小时Y分"
 */
export function formatDuration(totalSeconds: number): string {
  if (totalSeconds < 60) return `${totalSeconds}秒`;
  const minutes = Math.floor(totalSeconds / 60);
  if (minutes < 60) return `${minutes}分钟`;
  const hours = Math.floor(minutes / 60);
  const remainMin = minutes % 60;
  return remainMin > 0 ? `${hours}小时${remainMin}分钟` : `${hours}小时`;
}

/**
 * 米 → 带单位的可读距离
 */
export function formatDistance(meters: number, sportType?: SportType): string {
  if (sportType === 'swimming' && meters < 1000) {
    return `${meters}米`;
  }
  if (meters >= 1000) {
    return `${(meters / 1000).toFixed(2)}公里`;
  }
  return `${meters}米`;
}

/**
 * 配速秒/公里 → "5:30/公里"
 */
export function formatPace(seconds: number): string {
  const min = Math.floor(seconds / 60);
  const sec = seconds % 60;
  return `${min}:${sec.toString().padStart(2, '0')}`;
}

/**
 * 格式化日期
 */
export function formatDate(isoString: string): string {
  const d = new Date(isoString);
  const month = d.getMonth() + 1;
  const day = d.getDate();
  return `${month}月${day}日`;
}

export function formatDateTime(isoString: string): string {
  const d = new Date(isoString);
  const month = d.getMonth() + 1;
  const day = d.getDate();
  const hour = d.getHours().toString().padStart(2, '0');
  const minute = d.getMinutes().toString().padStart(2, '0');
  return `${month}月${day}日 ${hour}:${minute}`;
}

export function formatWeekday(day: string): string {
  const map: Record<string, string> = {
    Mon: '周一', Tue: '周二', Wed: '周三', Thu: '周四',
    Fri: '周五', Sat: '周六', Sun: '周日',
  };
  return map[day] || day;
}

export function getIntensityColor(level: string): string {
  switch (level) {
    case 'low': return 'var(--color-intensity-low)';
    case 'medium': return 'var(--color-intensity-medium)';
    case 'high': return 'var(--color-intensity-high)';
    default: return '#666';
  }
}
