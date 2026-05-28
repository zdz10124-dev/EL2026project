import { createBrowserRouter, Navigate } from 'react-router-dom';
import Layout from '../components/Layout';
import LoginPage from '../pages/LoginPage';
import RecordListPage from '../pages/RecordListPage';
import NewRecordPage from '../pages/NewRecordPage';
import ScreenshotUploadPage from '../pages/ScreenshotUploadPage';
import ReportPage from '../pages/ReportPage';
import WeeklyReportPage from '../pages/WeeklyReportPage';
import TrainingPlanPage from '../pages/TrainingPlanPage';

/**
 * 路由配置
 * 对应需求文档第 5.1 节页面列表
 */
export const router = createBrowserRouter([
  {
    path: '/',
    element: <LoginPage />,
  },
  {
    path: '/',
    element: <Layout />,
    children: [
      { index: true, element: <Navigate to="/records" replace /> },
      { path: 'records', element: <RecordListPage /> },
      { path: 'records/new', element: <NewRecordPage /> },
      { path: 'records/:recordId', element: <ReportPage /> },
      { path: 'screenshot', element: <ScreenshotUploadPage /> },
      { path: 'weekly', element: <WeeklyReportPage /> },
      { path: 'plan', element: <TrainingPlanPage /> },
    ],
  },
]);
