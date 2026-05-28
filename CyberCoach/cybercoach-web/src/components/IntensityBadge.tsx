import type { IntensityLevel } from '../types';
import { INTENSITY_OPTIONS } from '../constants';
import { getIntensityColor } from '../utils/format';

/** 强度等级徽章 */
export default function IntensityBadge({ level }: { level: IntensityLevel }) {
  const label = INTENSITY_OPTIONS.find(o => o.value === level)?.label || level;
  return (
    <span
      className="intensity-badge"
      style={{ backgroundColor: getIntensityColor(level) }}
    >
      {label}
    </span>
  );
}
