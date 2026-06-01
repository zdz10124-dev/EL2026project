# 今天吃什么 — AI 架构说明

## 项目结构

```
today_eat_app/                  # Flutter 应用
├── lib/
│   ├── models/
│   │   ├── ai_analysis.dart        # 图片/视频分析结果模型
│   │   ├── food_diary.dart         # 美食日记模型
│   │   ├── nutrition_analysis.dart # 营养分析模型
│   │   └── preference_analysis.dart# 偏好分析模型
│   ├── services/
│   │   ├── llm_service.dart        # LLM 调用层（双模式：直连/代理）
│   │   ├── agent_service.dart      # 智能体服务（高层 AI 接口）
│   │   └── ...
│   └── screens/
│       ├── diary_screen.dart       # AI 美食日记页
│       ├── nutrition_screen.dart   # AI 营养分析页
│       ├── preference_screen.dart  # AI 偏好分析页
│       └── capture_screen.dart     # 拍照记录（含 AI 识别 + GPS）
backend/                            # Python 后端
├── main.py                         # FastAPI 服务
├── requirements.txt                # Python 依赖
└── uploads/                        # 用户上传图片
```

## AI 系统架构

支持**两种模式**，在设置中切换：

### 模式一：直接连接（Direct API）— 备选方案

```
Flutter App ──→ OpenAI API
  （API Key 存在设备本地）
```

- API Key 通过 `flutter_secure_storage` 加密存储在设备上
- 适合个人使用、测试、或无后端部署条件时
- 所有 AI 调用直接发往 OpenAI（或兼容 API）

### 模式二：服务器代理（Server Proxy）— 推荐方案

```
Flutter App ──→ 你的后端 ──→ OpenAI API
  （JWT 认证）   （持有 API Key）
```

- API Key 存储在服务端环境变量，客户端不接触
- 用户通过用户名/密码注册登录，后端返回 JWT token
- 分发到多用户时必须使用此模式

---

## 后端部署

### 环境要求

- Python 3.11+
- 可访问 OpenAI API 的网络环境

### 安装依赖

```bash
cd backend
pip install -r requirements.txt
```

### 配置环境变量

```bash
export OPENAI_API_KEY="sk-..."           # 必需的 OpenAI API Key
export OPENAI_BASE_URL="https://api.openai.com/v1"  # 可选，兼容第三方 API
export JWT_SECRET="your-secret-key"      # 可选，JWT 签名密钥
```

### 启动服务

```bash
# 开发环境
uvicorn main:app --reload --host 0.0.0.0 --port 8000

# 生产环境（使用 systemd / supervisor 管理）
uvicorn main:app --host 0.0.0.0 --port 8000 --workers 2
```

### 后端 API 一览

| 端点 | 认证 | 说明 |
|---|---|---|
| `GET /health` | 否 | 健康检查 |
| `POST /v1/auth/register` | 否 | 用户注册 |
| `POST /v1/auth/login` | 否 | 用户登录，返回 JWT |
| `GET /v1/auth/me` | 是 | 验证 token |
| `POST /v1/ai/chat` | 是 | AI 代理——转发到 OpenAI |
| `POST /v1/recommendations/search` | 否 | 搜索公开推荐 |
| `POST /v1/recommendations/upload-record` | 否 | 上传公开记录 |
| `GET /v1/recommendations/{id}` | 否 | 推荐详情 |

---

## AI 功能流程

### AI 功能一览

| 功能 | 入口 | 调用 AI | AI 未配置时 |
|---|---|---|---|
| 图片识别分析 | 拍照编辑页 → AI 识别图片 | ✅ | 弹窗提示 |
| 视频分析 | 主页面 → 视频按钮 | ✅ | 弹窗提示 |
| AI 美食日记 | 其他功能 → 美食日记（AI） | ✅ | 弹窗提示 |
| 营养分析 | 其他功能 → 营养分析 | ✅ | 页面显示「功能准备中」 |
| 偏好分析 | 其他功能 → 偏好分析 | ✅ | 页面显示「功能准备中」 |
| 决定吃什么 | 底部 Tab「决定吃什么」 | ❌ 仅本地数据库 | — |
| 笔记本风格日记 | 其他功能 → 美食日记 | ❌ 仅按日期分组展示 | — |
| 统计分析 | 其他功能 → 统计分析 | ❌ 本地计算 | — |
| 联网推荐 | 其他功能 → 联网推荐 | ❌ 调后端 API | — |

### 1. 图片分析

```
拍照/选图 → 编辑界面 → 点击"AI 识别图片"
  → AgentService.analyzeFoodImage(path)
    → LlmService.callLlmWithImage()
      → Direct: POST OpenAI (Vision API)
      → Server: POST /v1/ai/chat → 转发 OpenAI
  → 返回: 菜品、主配菜、辣度、食材、菜系
```

### 2. 视频分析

```
选择视频 → 提取 5 帧关键帧
  → AgentService.analyzeFoodVideo(path)
    → 逐帧提取缩略图 (VideoThumbnail)
    → LlmService.callLlmWithImages(多帧)
      → Direct: POST OpenAI (多图 Vision)
      → Server: POST /v1/ai/chat → 转发
  → 展示分析结果
```

### 3. 美食日记

```
选择日期范围 → 获取记录 → AgentService.generateFoodDiary()
  → 格式化记录文本
  → LlmService.callLlm() (diary 风格 prompt)
  → 返回: 标题、正文、摘要、心情
```

### 4. 偏好分析

```
获取历史记录 → AgentService.analyzePreferences()
  → 格式化记录文本
  → LlmService.callLlm() (偏好分析 prompt)
  → 返回: 最爱菜系、食材、菜品、地点、趋势
```

### 5. 营养分析

```
获取历史记录 → AgentService.analyzeNutrition()
  → 格式化记录文本
  → LlmService.callLlm() (营养分析 prompt)
  → 返回: 总评、蔬菜/蛋白质评分、建议
```

---

## 系统 Prompt

所有 AI prompt 定义在 `agent_service.dart` 中，包括：
- `_imageAnalysisPrompt` — 图片分析
- `_diaryPrompt` — 美食日记
- `_preferencePrompt` — 偏好分析
- `_nutritionPrompt` — 营养分析

修改 prompt 后无需更新后端（直连模式）或无需更新客户端（代理模式，由后端控制）。

---

## 配置存储

存储位置：`flutter_secure_storage`（Android  encrypted SharedPreferences / iOS Keychain）

| Key | 说明 |
|---|---|
| `llm_mode` | `direct` 或 `server` |
| `llm_api_key` | 直连模式的 API Key |
| `llm_base_url` | 直连模式的 API 地址 |
| `llm_model` | 直连模式的模型名 |
| `llm_server_url` | 代理模式的服务器地址 |
| `llm_auth_token` | 代理模式的 JWT token |
| `llm_username` | 代理模式的登录用户名 |
