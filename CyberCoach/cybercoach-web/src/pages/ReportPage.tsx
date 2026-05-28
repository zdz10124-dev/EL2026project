import { useEffect, useState } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { useReport } from '../hooks/useReport';
import LoadingSpinner from '../components/LoadingSpinner';
import IntensityBadge from '../components/IntensityBadge';
import Disclaimer from '../components/Disclaimer';
import { formatDuration } from '../utils/format';

/**
 * 单次运动报告页
 * 固定展示三个区块：强度分析、恢复建议、下次运动建议
 */
export default function ReportPage() {
  const { recordId } = useParams<{ recordId: string }>();
  const { report, loading, error, generateReport } = useReport();
  const [retrying, setRetrying] = useState(false);
  const navigate = useNavigate();

  useEffect(() => {
    if (recordId) generateReport(recordId);
  }, [recordId, generateReport]);

  const handleRetry = () => {
    if (recordId) {
      setRetrying(true);
      generateReport(recordId).finally(() => setRetrying(false));
    }
  };

  if (loading && !report) return <LoadingSpinner text="正在生成报告..." />;

  if (error && !report) {
    return (
      <div className="page page-center">
        <div className="error-banner">{error}</div>
        <button className="btn btn--primary" onClick={handleRetry} disabled={retrying}>
          {retrying ? '重试中...' : '重试'}
        </button>
      </div>
    );
  }

  if (!report) return null;

  return (
    <div className="page">
      <div className="page-header">
        <h2>运动报告</h2>
        <button className="btn btn--text" onClick={() => navigate('/records')}>
          返回记录
        </button>
      </div>

      {/* 风险提示 */}
      {report.risk_alerts.length > 0 && (
        <div className="risk-alerts">
          {report.risk_alerts.map((alert, i) => (
            <div key={i} className={`risk-alert risk-alert--${alert.severity}`}>
              {alert.message}
            </div>
          ))}
        </div>
      )}

      {/* 区块 1：运动强度 */}
      <section className="report-block">
        <h3>运动强度</h3>
        <div className="report-row">
          <IntensityBadge level={report.intensity_level} />
        </div>
        <ul className="report-list">
          {report.intensity_reason.map((reason, i) => (
            <li key={i}>{reason}</li>
          ))}
        </ul>
      </section>

      {/* 区块 2：恢复建议 */}
      <section className="report-block">
        <h3>恢复建议</h3>
        <div className="report-details">
          <div className="report-detail-item">
            <span className="detail-label">建议休息</span>
            <span className="detail-value">{report.recovery_advice.rest_hours} 小时</span>
          </div>
          <div className="report-detail-item">
            <span className="detail-label">拉伸建议</span>
            <span className="detail-value">{report.recovery_advice.stretch}</span>
          </div>
          <div className="report-detail-item">
            <span className="detail-label">补水建议</span>
            <span className="detail-value">{report.recovery_advice.hydration_ml} ml</span>
          </div>
        </div>
      </section>

      {/* 区块 3：下次运动建议 */}
      <section className="report-block">
        <h3>下次运动建议</h3>
        <div className="report-details">
          <div className="report-detail-item">
            <span className="detail-label">运动项目</span>
            <span className="detail-value">
              {report.next_workout_advice.sport_type === 'running' ? '跑步' : '游泳'}
            </span>
          </div>
          <div className="report-detail-item">
            <span className="detail-label">建议时长</span>
            <span className="detail-value">{formatDuration(report.next_workout_advice.duration_s)}</span>
          </div>
          <div className="report-detail-item">
            <span className="detail-label">目标强度</span>
            <span className="detail-value">
              <IntensityBadge level={report.next_workout_advice.target_intensity} />
            </span>
          </div>
        </div>
      </section>

      {/* 激励语 */}
      <div className="encouragement">{report.encouragement}</div>

      {/* 免责声明 */}
      <Disclaimer />
    </div>
  );
}
