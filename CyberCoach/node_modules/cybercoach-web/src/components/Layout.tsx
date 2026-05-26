import { Outlet, NavLink } from 'react-router-dom';
import { APP_NAME } from '../constants';
import './Layout.css';

/**
 * 全局布局组件
 * - 顶部导航栏，底部内容区
 * - 响应式设计，适配 PC 和移动端
 */
export default function Layout() {
  return (
    <div className="layout">
      <header className="layout-header">
        <h1 className="layout-title">{APP_NAME}</h1>
        <nav className="layout-nav">
          <NavLink to="/records" className={({ isActive }) => isActive ? 'nav-link active' : 'nav-link'}>
            记录
          </NavLink>
          <NavLink to="/records/new" className={({ isActive }) => isActive ? 'nav-link active' : 'nav-link'}>
            新增
          </NavLink>
          <NavLink to="/screenshot" className={({ isActive }) => isActive ? 'nav-link active' : 'nav-link'}>
            截图
          </NavLink>
          <NavLink to="/weekly" className={({ isActive }) => isActive ? 'nav-link active' : 'nav-link'}>
            周报
          </NavLink>
          <NavLink to="/plan" className={({ isActive }) => isActive ? 'nav-link active' : 'nav-link'}>
            计划
          </NavLink>
        </nav>
      </header>
      <main className="layout-main">
        <Outlet />
      </main>
    </div>
  );
}
