# 赛博教练 (CyberCoach)

面向校园场景的 AI 运动记录与分析 Web 应用。

## 技术栈

- **前端**: React 19 + TypeScript + Vite
- **后端**: Hono + SQLite (Drizzle ORM) + tsx
- **AI**: LLM API（OpenAI 兼容接口，不配置时使用 Mock 数据）

## 快速开始

```bash
# 1. 安装依赖
npm install

# 2. 启动（前后端同时启动）
npm run dev
```

- 前端: http://localhost:5173
- 后端: http://localhost:3001

Windows 用户也可直接双击 `start.bat` 一键启动。

## 环境配置

后端通过 `cybercoach-server/.env` 配置，模板见 `.env.example`：

| 变量 | 说明 | 默认值 |
|------|------|--------|
| `PORT` | 后端端口 | 3001 |
| `DATABASE_PATH` | SQLite 数据库路径 | `./data/cybercoach.db` |
| `LLM_API_KEY` | LLM API Key | 留空使用 Mock |
| `LLM_BASE_URL` | LLM API 地址 | `https://api.openai.com/v1` |
| `LLM_MODEL` | 模型名称 | `gpt-4o` |

## 功能

- 手动录入运动记录（跑步/游泳）
- 截图上传 + OCR 识别录入
- 单次运动 AI 分析报告（强度、恢复建议、激励）
- 运动周报统计
- AI 训练计划生成
- 训练提醒设置
- 响应式设计（PC + 移动端）

## 项目结构

```
CyberCoach/
├── package.json              # npm workspaces 根配置
├── start.bat                 # Windows 一键启动脚本
├── cybercoach-server/        # 后端
│   └── src/
│       ├── routes/           # records, ocr, plans, reports, reminders
│       ├── services/ai.ts    # LLM 调用
│       ├── db/               # 数据库 schema + seed
│       └── middleware/       # 认证中间件
└── cybercoach-web/           # 前端
    └── src/
        ├── pages/            # 7 个页面
        ├── components/       # 通用组件
        ├── hooks/            # 自定义 Hooks
        └── utils/api.ts      # API 客户端
```

## 更多文档

- [需求文档](需求文档_React路线.md)
- [功能描述](功能描述.md)
- [接口与数据契约](接口与数据契约.md)
- [实现方法建议](实现方法建议.md)
