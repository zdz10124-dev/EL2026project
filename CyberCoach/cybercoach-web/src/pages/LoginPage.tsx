import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { APP_NAME } from '../constants';

/**
 * 登录页
 * MVP 阶段优先支持匿名模式（输入昵称即可进入）
 */
export default function LoginPage() {
  const [nickname, setNickname] = useState('');
  const navigate = useNavigate();

  const handleEnter = () => {
    if (nickname.trim()) {
      localStorage.setItem('nickname', nickname.trim());
    }
    navigate('/records');
  };

  return (
    <div className="page-center">
      <div className="login-card">
        <h1 className="login-title">{APP_NAME}</h1>
        <p className="login-subtitle">你的智能运动助手</p>
        <div className="field">
          <label className="field-label">昵称（可选）</label>
          <input
            className="field-input"
            placeholder="输入昵称开始体验"
            value={nickname}
            onChange={e => setNickname(e.target.value)}
            onKeyDown={e => e.key === 'Enter' && handleEnter()}
          />
        </div>
        <button className="btn btn--primary btn--full" onClick={handleEnter}>
          进入
        </button>
        <p className="login-hint">匿名模式，无需注册</p>
      </div>
    </div>
  );
}
