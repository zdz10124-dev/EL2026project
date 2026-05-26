import { useState } from 'react';
import SportSelector from '../components/SportSelector';
import { api } from '../utils/api';
import type { SportType, OcrDraft } from '../types';

/**
 * 截图上传与识别确认页
 * - 选择运动类型 + 上传截图
 * - 展示 OCR 草稿结果（可编辑）
 * - 确认后调用创建记录接口入库
 */
export default function ScreenshotUploadPage() {
  const [sportType, setSportType] = useState<SportType>('running');
  const [file, setFile] = useState<File | null>(null);
  const [preview, setPreview] = useState<string | null>(null);
  const [draft, setDraft] = useState<OcrDraft | null>(null);
  const [editedFields, setEditedFields] = useState<Record<string, string>>({});
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // 处理文件选择，生成预览
  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const f = e.target.files?.[0];
    if (!f) return;
    setFile(f);
    setPreview(URL.createObjectURL(f));
    setDraft(null);
  };

  // 上传并解析
  const handleParse = async () => {
    if (!file) return;
    setLoading(true);
    setError(null);
    try {
      const res = await api.parseOcr(sportType, file);
      if (res.code === 0) {
        setDraft(res.data as OcrDraft);
      } else {
        setError(res.message);
      }
    } catch {
      setError('解析失败，请重试');
    } finally {
      setLoading(false);
    }
  };

  // OCR 草稿字段编辑
  const parsed = draft?.parsed;
  const editField = (key: string, value: string) =>
    setEditedFields(prev => ({ ...prev, [key]: value }));

  const getFieldValue = (key: string) =>
    editedFields[key] !== undefined ? editedFields[key] : String(parsed?.[key as keyof typeof parsed] ?? '');

  return (
    <div className="page">
      <div className="page-header">
        <h2>截图上传识别</h2>
      </div>

      <form className="form" onSubmit={e => e.preventDefault()}>
        <SportSelector value={sportType} onChange={setSportType} />

        {/* 文件上传区域 */}
        <div className="upload-zone">
          {preview ? (
            <img src={preview} alt="截图预览" className="upload-preview" />
          ) : (
            <label className="upload-placeholder">
              <span>点击选择截图</span>
              <input type="file" accept="image/*" onChange={handleFileChange} hidden />
            </label>
          )}
          {preview && (
            <button type="button" className="btn btn--text" onClick={() => { setFile(null); setPreview(null); setDraft(null); }}>
              重新选择
            </button>
          )}
        </div>

        {file && !draft && (
          <button className="btn btn--primary btn--full" onClick={handleParse} disabled={loading}>
            {loading ? '解析中...' : '开始识别'}
          </button>
        )}

        {error && <div className="error-banner">{error}</div>}

        {/* OCR 草稿编辑区 */}
        {draft && (
          <div className="draft-section">
            <div className="draft-header">
              <h3>识别结果</h3>
              <span className="draft-confidence">置信度：{Math.round(draft.confidence * 100)}%</span>
            </div>

            {draft.warnings.length > 0 && (
              <div className="warning-banner">
                {draft.warnings.map((w, i) => <p key={i}>⚠ {w}</p>)}
              </div>
            )}

            <div className="draft-fields">
              <div className="field">
                <label className="field-label">运动时长（秒）</label>
                <input className="field-input" value={getFieldValue('duration_s')} onChange={e => editField('duration_s', e.target.value)} />
              </div>
              <div className="field">
                <label className="field-label">距离（米）</label>
                <input className="field-input" value={getFieldValue('distance_m')} onChange={e => editField('distance_m', e.target.value)} />
              </div>
              <div className="field">
                <label className="field-label">平均心率（bpm）</label>
                <input className="field-input" value={getFieldValue('avg_hr_bpm')} onChange={e => editField('avg_hr_bpm', e.target.value)} />
              </div>
              <div className="field">
                <label className="field-label">峰值心率（bpm）</label>
                <input className="field-input" value={getFieldValue('peak_hr_bpm')} onChange={e => editField('peak_hr_bpm', e.target.value)} />
              </div>
            </div>

            <button className="btn btn--primary btn--full">
              确认并保存记录
            </button>
          </div>
        )}
      </form>
    </div>
  );
}
