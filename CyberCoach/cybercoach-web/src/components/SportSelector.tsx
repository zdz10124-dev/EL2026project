import type { SportType } from '../types';
import { SPORT_TYPE_OPTIONS } from '../constants';

/** 运动类型选择器 */
export default function SportSelector({
  value,
  onChange,
}: {
  value: SportType;
  onChange: (v: SportType) => void;
}) {
  return (
    <div className="field">
      <label className="field-label">运动类型</label>
      <div className="radio-group">
        {SPORT_TYPE_OPTIONS.map(opt => (
          <button
            key={opt.value}
            type="button"
            className={`radio-btn ${value === opt.value ? 'radio-btn--active' : ''}`}
            onClick={() => onChange(opt.value)}
          >
            {opt.label}
          </button>
        ))}
      </div>
    </div>
  );
}
