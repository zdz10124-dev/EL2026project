# 赛博教练 (CyberCoach)

面向校园场景的 AI 运动记录与分析 Web 应用。

## 技术栈

- **前端**: React 19 + TypeScript + Vite
- **后端**: Node.js + Hono + SQLite (Drizzle ORM)
- **AI**: LLM API（OpenAI 兼容接口）
- **样式**: 纯 CSS（响应式布局，适配 PC 与 390px 移动端）

## 快速开始

### 前置要求

- Node.js >= 20
- npm >= 9

### 安装并启动

```bash
# 1. 克隆仓库
git clone <repo-url>
cd CyberCoach

# 2. 一键安装所有依赖（根目录 workspaces 会自动处理前后端）
npm install

# 3. 一键启动前后端
npm run dev
```

- 前端: http://localhost:5173
- 后端: http://localhost:3001

### 两种运行模式

项目默认使用 **Mock 模式**（`useMock = true`），前端自带模拟数据，无需后端即可运行。

切换到真实后端模式：

1. **后端**: `.env` 中配置 `LLM_API_KEY`（可选，不配置时 AI 接口返回模拟数据）
2. **前端**: 修改 [api.ts](src/utils/api.ts#L18) 的 `useMock` 为 `false`

### 单独启动

```bash
# 只启动后端
npm run dev:server

# 只启动前端
npm run dev:web

# 插入测试数据
npm run seed
```

### Windows 一键启动

双击 `start.bat` 即可自动清理端口、安装依赖、启动前后端。

## 项目结构

```
CyberCoach/
├── package.json              # 根 workspaces 配置
├── start.bat                 # Windows 一键启动
├── cybercoach-web/           # 前端项目
│   ├── src/
│   │   ├── components/       # 通用组件
│   │   ├── pages/            # 7 个页面
│   │   ├── hooks/            # 自定义 Hooks
│   │   ├── utils/api.ts      # API 客户端（内含 Mock 开关）
│   │   ├── routes/           # 路由配置
│   │   ├── types/            # TypeScript 类型
│   │   └── constants/        # 常量定义
│   └── ...
└── cybercoach-server/        # 后端项目
    ├── src/
    │   ├── routes/           # 5 个路由模块
    │   ├── services/ai.ts    # LLM API 调用
    │   ├── db/               # 数据库 schema + 连接
    │   └── middleware/       # 认证中间件
    └── .env.example          # 环境变量模板
```

## API 文档

详见 [接口与数据契约.md](../接口与数据契约.md)。

## 功能清单

- [x] 手动录入运动记录（跑步/游泳）
- [x] 截图上传 + OCR 识别草稿
- [x] 单次运动报告（强度、恢复、建议）
- [x] 运动周报（统计、强度分布、改进建议）
- [x] 训练计划生成
- [x] 训练提醒设置
- [x] 匿名登录模式
- [x] 响应式设计
