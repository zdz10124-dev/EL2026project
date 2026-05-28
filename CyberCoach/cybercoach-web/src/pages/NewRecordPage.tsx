import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import SportSelector from '../components/SportSelector';
import FieldWithUnit from '../components/FieldWithUnit';
import type { CreateRecordRequest, RunningDetail, SwimmingDetail } from '../types';
import { validateCreateRecord, formatValidationErrors } from '../utils/validation';
import { useRecords } from '../hooks/useRecords';
import { SWIM_STYLE_OPTIONS } from '../constants';
import type { SwimStyle } from '../types';

/** 默认表单数据 */
function defaultForm(): CreateRecordRequest & { swimming_detail?: SwimmingDetail } {
  return {
    sport_type: 'running',
    recorded_at: new Date().toISOString().slice(0, 16),
    duration_s: 1800,
    distance_m: 5000,
    avg_hr_bpm: 140,
    peak_hr_bpm: 160,
    rpe: 5,
    note: '',
    running_detail: { pace_sec_per_km: 330, cadence_spm: 170, stride_cm: 100 },
  };
}

/**
 * 新增运动记录页（手动录入）
 * - 根据运动类型显示不同扩展字段
 * - 提交前校验
 */
export default function NewRecordPage() {
  const [form, setForm] = useState(defaultForm());
  const [errors, setErrors] = useState<string[]>([]);
  const { createRecord, loading } = useRecords();
  const navigate = useNavigate();

  const update = <K extends keyof typeof form>(key: K, value: (typeof form)[K]) =>
    setForm(prev => ({ ...prev, [key]: value }));

  // 更新嵌套的 running_detail / swimming_detail 字段
  const updateRunningDetail = (partial: Partial<RunningDetail>) =>
    setForm(prev => ({ ...prev, running_detail: { ...prev.running_detail!, ...partial } as RunningDetail }));

  const updateSwimmingDetail = (partial: Partial<SwimmingDetail>) =>
    setForm(prev => ({ ...prev, swimming_detail: { ...prev.swimming_detail!, ...partial } as SwimmingDetail }));

  const handleSubmit = async () => {
    const validationErrors = validateCreateRecord(form);
    if (validationErrors.length > 0) {
      setErrors(validationErrors.map(e => e.message));
      return;
    }
    setErrors([]);

    // 构建请求体：根据运动类型包含对应 detail
    const payload: CreateRecordRequest = {
      ...form,
      recorded_at: new Date(form.recorded_at).toISOString(),
      running_detail: form.sport_type === 'running' ? (form.running_detail as RunningDetail) : undefined,
      swimming_detail: form.sport_type === 'swimming' ? (form.swimming_detail as SwimmingDetail) : undefined,
    };

    const result = await createRecord(payload);
    if (result) {
      navigate(`/records/${result.record_id}`);
    }
  };

  return (
    <div className="page">
      <div className="page-header">
        <h2>新增运动记录</h2>
      </div>

      {errors.length > 0 && (
        <div className="error-banner">{formatValidationErrors(errors.map(m => ({ field: '', message: m })))}</div>
      )}

      <form className="form" onSubmit={e => { e.preventDefault(); handleSubmit(); }}>
        <SportSelector value={form.sport_type} onChange={v => update('sport_type', v)} />

        <FieldWithUnit
          label="记录时间"
          type="datetime-local"
          unit=""
          value={form.recorded_at}
          onChange={e => update('recorded_at', e.target.value)}
        />

        <FieldWithUnit
          label="运动时长"
          type="number"
          unit="分钟"
          min={1} max={600}
          value={Math.round(form.duration_s / 60)}
          onChange={e => update('duration_s', Number(e.target.value) * 60)}
        />

        <FieldWithUnit
          label="运动距离"
          type="number"
          unit="米"
          min={1}
          value={form.distance_m}
          onChange={e => update('distance_m', Number(e.target.value))}
        />

        <FieldWithUnit
          label="平均心率"
          type="number"
          unit="bpm"
          min={30} max={230}
          value={form.avg_hr_bpm}
          onChange={e => update('avg_hr_bpm', Number(e.target.value))}
        />

        <FieldWithUnit
          label="峰值心率"
          type="number"
          unit="bpm"
          min={30} max={230}
          value={form.peak_hr_bpm}
          onChange={e => update('peak_hr_bpm', Number(e.target.value))}
        />

        <FieldWithUnit
          label="主观疲劳评分"
          type="number"
          unit="1-10"
          min={1} max={10}
          value={form.rpe}
          onChange={e => update('rpe', Number(e.target.value))}
        />

        {/* 跑步扩展字段 */}
        {form.sport_type === 'running' && (
          <>
            <FieldWithUnit
              label="平均配速"
              unit="秒/公里"
              type="number"
              value={form.running_detail?.pace_sec_per_km}
              onChange={e => updateRunningDetail({ pace_sec_per_km: Number(e.target.value) })}
            />
            <FieldWithUnit
              label="平均步频"
              unit="步/分钟"
              type="number"
              value={form.running_detail?.cadence_spm}
              onChange={e => updateRunningDetail({ cadence_spm: Number(e.target.value) })}
            />
            <FieldWithUnit
              label="平均步幅"
              unit="厘米"
              type="number"
              value={form.running_detail?.stride_cm}
              onChange={e => updateRunningDetail({ stride_cm: Number(e.target.value) })}
            />
          </>
        )}

        {/* 游泳扩展字段 */}
        {form.sport_type === 'swimming' && (
          <>
            <div className="field">
              <label className="field-label">泳姿</label>
              <select
                className="field-select"
                value={form.swimming_detail?.swim_style || ''}
                onChange={e => updateSwimmingDetail({ swim_style: e.target.value as SwimStyle })}
              >
                <option value="">请选择</option>
                {SWIM_STYLE_OPTIONS.map(o => (
                  <option key={o.value} value={o.value}>{o.label}</option>
                ))}
              </select>
            </div>
            <FieldWithUnit
              label="趟数"
              unit="趟"
              type="number"
              min={1}
              value={form.swimming_detail?.laps}
              onChange={e => updateSwimmingDetail({ laps: Number(e.target.value) })}
            />
            <FieldWithUnit
              label="平均配速"
              unit="秒/100米"
              type="number"
              value={form.swimming_detail?.pace_sec_per_100m}
              onChange={e => updateSwimmingDetail({ pace_sec_per_100m: Number(e.target.value) })}
            />
          </>
        )}

        <div className="field">
          <label className="field-label">备注（可选）</label>
          <textarea
            className="field-textarea"
            value={form.note}
            onChange={e => update('note', e.target.value)}
            rows={3}
          />
        </div>

        <button className="btn btn--primary btn--full" type="submit" disabled={loading}>
          {loading ? '保存中...' : '保存记录'}
        </button>
      </form>
    </div>
  );
}
