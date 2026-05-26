# 赛博教练 (CyberCoach)

面向校园场景的 AI 运动记录与分析 Web 应用。

## 技术栈

- **前端框架**: React 19 + TypeScript
- **构建工具**: Vite
- **路由**: react-router-dom
- **样式**: 纯 CSS（响应式布局，适配 PC 与 390px 移动端）

## 快速开始

```bash
# 安装依赖
npm install

# 启动开发服务器
npm run dev

# 构建生产版本
npm run build
```

## 项目结构

```
src/
├── components/       # 通用组件（Layout、SportSelector、Disclaimer 等）
├── constants/        # 常量定义（运动类型、单位、范围等）
├── hooks/            # 自定义 Hooks（useRecords、useReport、useReminder）
├── pages/            # 页面组件
│   ├── LoginPage.tsx           # 登录页（匿名模式）
│   ├── RecordListPage.tsx      # 记录列表页
│   ├── NewRecordPage.tsx       # 新增记录页（手动录入）
│   ├── ScreenshotUploadPage.tsx # 截图上传与 OCR 识别页
│   ├── ReportPage.tsx          # 单次运动报告页
│   ├── WeeklyReportPage.tsx    # 运动周报页
│   └── TrainingPlanPage.tsx    # 训练计划页
├── routes/           # 路由配置
├── types/            # TypeScript 类型定义
└── utils/            # 工具函数（API 客户端、校验、格式化）
```

## 功能清单

- [x] 手动录入运动记录（跑步/游泳）
- [x] 截图上传 + OCR 识别草稿
- [x] 单次运动报告（强度、恢复、建议）
- [x] 运动周报（统计、强度分布、改进建议）
- [x] 训练计划生成
- [x] 训练提醒设置
- [x] 匿名登录模式
- [x] 响应式设计

## 接口文档

后端 API 契约详见 [接口与数据契约.md](../%E6%8E%A5%E5%8F%A3%E4%B8%8E%E6%95%B0%E6%8D%AE%E5%A5%91%E7%BA%A6.md)。

## 需求文档

完整需求详见 [需求文档_React路线.md](../%E9%9C%80%E6%B1%82%E6%96%87%E6%A1%A3_React%E8%B7%AF%E7%BA%BF.md)。
