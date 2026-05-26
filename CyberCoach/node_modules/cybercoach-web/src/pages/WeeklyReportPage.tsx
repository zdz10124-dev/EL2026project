import { useEffect, useState } from 'react';
import { useReport } from '../hooks/useReport';
import LoadingSpinner from '../components/LoadingSpinner';
import Disclaimer from '../components/Disclaimer';
import { formatDuration, formatDistance } from '../utils/format';
import { INTENSITY_OPTIONS } from '../constants';

/**
 * 运动周报页
 * - 展示最近 7 天的统计数据
 * - 显示改进建议
 */
export default function WeeklyReportPage() {
  // 计算上周一的日期
  const getLastWeekStart = () => {
    const d = new Date();
    const day = d.getDay();
    const diff = day === 0 ? 6 : day - 1;
    const lastMonday = new Date(d);
    lastMonday.setDate(d.getDate() - diff - 7);
    return lastMonday.toISOString().slice(0, 10);
  };

  const [weekStart] = useState(getLastWeekStart());
  const { weekly, loading, error, fetchWeekly } = useReport();
  const [retrying, setRetrying] = useState(false);

  useEffect(() => {
    fetchWeekly(weekStart);
  }, [weekStart, fetchWeekly]);

  const handleRetry = () => {
    setRetrying(true);
    fetchWeekly(weekStart).finally(() => setRetrying(false));
  };

  const intensityLabel = (key: string) => INTENSITY_OPTIONS.find(o => o.value === key)?.label || key;

  if (loading && !weekly) return <LoadingSpinner text="正在生成周报..." />;

  if (error && !weekly) {
    return (
      <div className="page page-center">
        <div className="error-banner">{error}</div>
        <button className="btn btn--primary" onClick={handleRetry} disabled={retrying}>
          {retrying ? '重试中...' : '重试'}
        </button>
      </div>
    );
  }

  if (!weekly) return null;

  return (
    <div className="page">
      <div className="page-header">
        <h2>运动周报</h2>
        <span className="page-subtitle">
          {weekly.week_start} ~ {weekly.week_end}
        </span>
      </div>

      {/* 概览统计 */}
      <section className="weekly-stats">
        <div className="stat-card">
          <span className="stat-value">{weekly.workout_count}</span>
          <span className="stat-label">运动次数</span>
        </div>
        <div className="stat-card">
          <span className="stat-value">{formatDuration(weekly.total_duration_s)}</span>
          <span className="stat-label">总时长</span>
        </div>
        <div className="stat-card">
          <span className="stat-value">{formatDistance(weekly.total_distance_m)}</span>
          <span className="stat-label">总距离</span>
        </div>
        <div className="stat-card">
          <span className="stat-value">{weekly.avg_hr_bpm}</span>
          <span className="stat-label">平均心率</span>
        </div>
      </section>

      {/* 强度分布 */}
      <section className="report-block">
        <h3>强度分布</h3>
        <div className="intensity-bars">
          {Object.entries(weekly.intensity_distribution).map(([key, count]) => (
            <div key={key} className="intensity-bar-row">
              <span className="intensity-bar-label">{intensityLabel(key)}</span>
              <div className="intensity-bar-track">
                <div
                  className="intensity-bar-fill"
                  style={{
                    width: `${(count / weekly.workout_count) * 100}%`,
                  }}
                />
              </div>
              <span className="intensity-bar-count">{count}次</span>
            </div>
          ))}
        </div>
      </section>

      {/* 亮点与改进建议 */}
      {weekly.highlights.length > 0 && (
        <section className="report-block">
          <h3>本周亮点</h3>
          <ul className="report-list">
            {weekly.highlights.map((h, i) => <li key={i}>{h}</li>)}
          </ul>
        </section>
      )}

      <section className="report-block">
        <h3>改进建议</h3>
        <ul className="report-list">
          {weekly.suggestions.map((s, i) => <li key={i}>{s}</li>)}
        </ul>
      </section>

      <button className="btn btn--text btn--full" onClick={handleRetry} disabled={retrying}>
        {retrying ? '刷新中...' : '刷新周报'}
      </button>

      <Disclaimer />
    </div>
  );
}
