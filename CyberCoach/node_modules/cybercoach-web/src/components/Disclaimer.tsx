import { DISCLAIMER_TEXT } from '../constants';

/** 非医疗免责声明组件，展示在报告和分析结果底部 */
export default function Disclaimer() {
  return (
    <div className="disclaimer">
      <span className="disclaimer-icon">⚠️</span>
      <span className="disclaimer-text">{DISCLAIMER_TEXT}</span>
    </div>
  );
}
