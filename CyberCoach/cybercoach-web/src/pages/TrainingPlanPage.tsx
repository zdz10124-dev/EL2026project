import { useState } from 'react';
import { usePlan } from '../hooks/useReport';
import LoadingSpinner from '../components/LoadingSpinner';
import IntensityBadge from '../components/IntensityBadge';
import Disclaimer from '../components/Disclaimer';
import { SPORT_TYPE_OPTIONS, GOAL_OPTIONS } from '../constants';
import { formatDuration, formatWeekday } from '../utils/format';
import type { GoalType, SportType } from '../types';
import type { GeneratePlanRequest } from '../types';

/**
 * 训练计划页
 * - 用户设置目标和可用时间
 * - 系统生成 7 天安排
 * - 支持一键重生成
 */
export default function TrainingPlanPage() {
  const [goal, setGoal] = useState<GoalType>('fitness');
  const [availableDays, setAvailableDays] = useState(3);
  const [maxDuration, setMaxDuration] = useState(45);
  const [preferredSports, setPreferredSports] = useState<SportType[]>(['running']);
  const { plan, loading, error, generatePlan } = usePlan();

  const handleGenerate = () => {
    const payload: GeneratePlanRequest = {
      goal,
      available_days_per_week: availableDays,
      max_duration_s_per_session: maxDuration * 60,
      preferred_sports: preferredSports,
    };
    generatePlan(payload);
  };

  const toggleSport = (s: SportType) => {
    setPreferredSports(prev =>
      prev.includes(s) ? prev.filter(x => x !== s) : [...prev, s]
    );
  };

  const sportLabel = (s: SportType) => SPORT_TYPE_OPTIONS.find(o => o.value === s)?.label || s;

  return (
    <div className="page">
      <div className="page-header">
        <h2>训练计划</h2>
      </div>

      {/* 设置表单 */}
      <form className="form" onSubmit={e => { e.preventDefault(); handleGenerate(); }}>
        <div className="field">
          <label className="field-label">运动目标</label>
          <select className="field-select" value={goal} onChange={e => setGoal(e.target.value as GoalType)}>
            {GOAL_OPTIONS.map(o => (
              <option key={o.value} value={o.value}>{o.label}</option>
            ))}
          </select>
        </div>

        <div className="field">
          <label className="field-label">每周可训练天数</label>
          <input
            className="field-input"
            type="number"
            min={1} max={7}
            value={availableDays}
            onChange={e => setAvailableDays(Number(e.target.value))}
          />
        </div>

        <div className="field">
          <label className="field-label">单次最长时长（分钟）</label>
          <input
            className="field-input"
            type="number"
            min={10} max={120}
            value={maxDuration}
            onChange={e => setMaxDuration(Number(e.target.value))}
          />
        </div>

        <div className="field">
          <label className="field-label">偏好运动</label>
          <div className="checkbox-group">
            {SPORT_TYPE_OPTIONS.map(o => (
              <label key={o.value} className="checkbox-label">
                <input
                  type="checkbox"
                  checked={preferredSports.includes(o.value)}
                  onChange={() => toggleSport(o.value)}
                />
                {o.label}
              </label>
            ))}
          </div>
        </div>

        <button className="btn btn--primary btn--full" type="submit" disabled={loading}>
          {loading ? '生成中...' : '生成计划'}
        </button>
      </form>

      {error && <div className="error-banner">{error}</div>}

      {loading && <LoadingSpinner text="正在生成训练计划..." />}

      {/* 计划展示 */}
      {plan && !loading && (
        <>
          <section className="plan-result">
            <h3>本周训练安排</h3>
            <div className="plan-grid">
              {plan.week_plan.map((day, i) => (
                <div key={i} className="plan-day-card">
                  <div className="plan-day-header">{formatWeekday(day.day)}</div>
                  <div className="plan-day-body">
                    <span className="plan-day-sport">{sportLabel(day.type)}</span>
                    <span className="plan-day-duration">{formatDuration(day.duration_s)}</span>
                    <IntensityBadge level={day.intensity} />
                    <p className="plan-day-notes">{day.notes}</p>
                  </div>
                </div>
              ))}
            </div>
          </section>

          <button className="btn btn--text btn--full" onClick={handleGenerate}>
            一键重生成
          </button>

          <Disclaimer />
        </>
      )}
    </div>
  );
}
