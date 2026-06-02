import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useRecords } from '../hooks/useRecords';
import LoadingSpinner from '../components/LoadingSpinner';
import { formatDateTime, formatDuration, formatDistance } from '../utils/format';
import type { SportType } from '../types';
import { SPORT_TYPE_OPTIONS } from '../constants';

/**
 * 运动记录列表页
 * - 按运动类型、日期筛选
 * - 分页展示
 */
export default function RecordListPage() {
  const { records, loading, error, pagination, fetchRecords } = useRecords();
  const [sportFilter, setSportFilter] = useState<SportType | ''>('');
  const navigate = useNavigate();

  useEffect(() => {
    fetchRecords(sportFilter ? { sport_type: sportFilter } : undefined);
  }, [fetchRecords, sportFilter]);

  const sportLabel = (s: SportType) => SPORT_TYPE_OPTIONS.find(o => o.value === s)?.label || s;

  return (
    <div className="page">
      <div className="page-header">
        <h2>运动记录</h2>
        <button className="btn btn--primary" onClick={() => navigate('/records/new')}>
          新增记录
        </button>
      </div>

      {/* 筛选栏 */}
      <div className="filter-bar">
        <select
          className="field-select"
          value={sportFilter}
          onChange={e => setSportFilter(e.target.value as SportType | '')}
        >
          <option value="">全部运动</option>
          {SPORT_TYPE_OPTIONS.map(o => (
            <option key={o.value} value={o.value}>{o.label}</option>
          ))}
        </select>
      </div>

      {error && <div className="error-banner">{error}</div>}

      {loading ? (
        <LoadingSpinner />
      ) : records.length === 0 ? (
        <div className="empty-state">
          <p>暂无运动记录</p>
          <button className="btn btn--primary" onClick={() => navigate('/records/new')}>
            添加第一条记录
          </button>
        </div>
      ) : (
        <>
          <div className="record-list">
            {records.map(record => (
              <div
                key={record.record_id}
                className="record-card"
                onClick={() => navigate(`/records/${record.record_id}`)}
              >
                <div className="record-card__header">
                  <span className="record-card__sport">{sportLabel(record.sport_type)}</span>
                  <span className="record-card__date">{formatDateTime(record.recorded_at)}</span>
                </div>
                <div className="record-card__stats">
                  <span>⏱ {formatDuration(record.duration_s)}</span>
                  <span>📏 {formatDistance(record.distance_m, record.sport_type)}</span>
                  <span>❤️ {record.avg_hr_bpm} bpm</span>
                </div>
              </div>
            ))}
          </div>

          {/* 分页 */}
          {pagination.total > pagination.page_size && (
            <div className="pagination">
              <span>共 {pagination.total} 条</span>
            </div>
          )}
        </>
      )}
    </div>
  );
}
