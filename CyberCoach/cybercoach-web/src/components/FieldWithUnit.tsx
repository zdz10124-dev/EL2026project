/**
 * 带单位的字段输入组件
 * - label：字段名
 * - unit：单位
 * - 其余 props 透传给 input
 */
export default function FieldWithUnit({
  label,
  unit,
  ...inputProps
}: {
  label: string;
  unit: string;
} & React.InputHTMLAttributes<HTMLInputElement>) {
  return (
    <div className="field">
      <label className="field-label">
        {label}
        <span className="field-unit">（{unit}）</span>
      </label>
      <div className="field-input-wrapper">
        <input className="field-input" {...inputProps} />
        <span className="field-unit-suffix">{unit}</span>
      </div>
    </div>
  );
}
