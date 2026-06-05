# 今天吃什么 · 赛博教练

本项目包含两个独立的应用以及一个后端服务，统一托管在此仓库中。

---

## 项目总览

```
C--Projects-2026EL/
├── today_eat_app/        # Flutter 移动应用 "今天吃什么"
│   └── lib/              # Flutter Dart 源码
├── backend/              # Python 后端 "联网推荐" 服务
├── CyberCoach/           # Web 应用 "赛博教练" (CyberCoach)
│   ├── cybercoach-server/# Hono 后端
│   └── cybercoach-web/   # React 前端
├── 文档/                  # 项目根目录的文档文件
└── 启动脚本/              # .bat 启动脚本
```

所有源码文件统一使用 **UTF-8** 编码。

---

## 一、today_eat_app — Flutter 移动应用（今天吃什么）

美食记录与推荐应用，支持拍照记录菜品、日记生成、营养分析、偏好分析等功能。

### 启动方式

```bash
cd today_eat_app
flutter pub get
flutter run
```

### 目录结构

```
today_eat_app/lib/
├── main.dart                              # 应用入口，初始化配置并启动 MaterialApp
├── models/                                # 数据模型层
│   ├── ai_analysis.dart                   # AI 图片识别结果模型
│   ├── food_diary.dart                    # 美食日记数据模型
│   ├── meal_draft.dart                    # 拍照/填写的临时草稿模型
│   ├── meal_record.dart                   # 用餐记录核心模型（菜名、价格、评分等）
│   ├── nutrition_analysis.dart            # AI 营养分析结果模型
│   ├── preference_analysis.dart           # AI 偏好分析结果模型
│   ├── recommendation_models.dart         # 联网推荐接口的数据模型分桶、查询、推荐项
│   ├── recommendation_upload_task.dart    # 推荐上传任务的状态模型
│   ├── style_presets.dart                 # 应用主题/日记样式预设
│   └── ui_config.dart                     # UI 配置数据模型（从 XML 反序列化）
│
├── screens/                               # 页面层
│   ├── home_shell.dart                    # 主页壳层，底部导航栏切换各页面
│   ├── capture_screen.dart                # 拍照/选图 + 填写菜品信息页面
│   ├── decide_screen.dart                 # "今天吃什么" 决策页面（随机/偏好模式）
│   ├── diary_screen.dart                  # AI 美食日记生成页面
│   ├── insights_screen.dart               # 概览页：日记、营养、偏好、联网推荐的入口
│   ├── journal_notebook_page.dart         # 美食日记翻书视图（支持导出长图/PDF）
│   ├── network_recommendation_screen.dart # 联网推荐列表页（筛选、点赞、点踩、举报）
│   ├── nutrition_screen.dart              # AI 营养分析页面
│   ├── preference_screen.dart             # AI 偏好分析页面
│   └── settings_screen.dart               # 设置页（账号、AI、样式、关于）
│
├── services/                              # 服务层
│   ├── agent_service.dart                 # AI 智能体高层接口（图片识别、日记、营养、偏好）
│   ├── app_settings_service.dart          # 本地持久化设置（SharedPreferences）
│   ├── database_service.dart              # SQLite 数据库操作（增删改查、上传任务管理）
│   ├── llm_service.dart                   # LLM 调用层（直连模式/代理模式双模式）
│   ├── location_service.dart              # GPS 定位服务（坐标 → 地址逆地理编码）
│   ├── meal_repository.dart               # 数据仓库层（图片处理、草稿、记录 CRUD、日记拼装等）
│   ├── recommendation_api_service.dart    # 联网推荐 API 调用（搜索、详情、上传记录）
│   ├── ui_config_loader.dart              # XML UI 配置加载器
│   └── upload_image_compressor.dart       # 上传图片激进压缩
│
├── widgets/                               # 可复用组件
│   ├── rating_stars.dart                  # 星级评分交互组件
│   ├── section_card.dart                  # 通用卡片容器
│   └── themed_page_background.dart        # 带主题渐变和装饰的背景组件
│
├── assets/                                # 静态资源
│   └── config/ui_config.xml               # UI 文案与样式配置文件（支持直接修改题目、页签等）
│
├── test/                                  # 单元测试
│   ├── rating_stars_test.dart             # 评分星星的点击定位测试
│   └── widget_test.dart                   # 应用渲染冒烟测试
│
├── docs/
│   └── 编码与文案协作约定.md               # 编码规范与团队协作约定
│
├── android/                               # Android 平台配置
│   ├── app/build.gradle.kts               # 应用级 Gradle 构建配置
│   ├── app/src/main/AndroidManifest.xml    # Android 权限声明
│   ├── app/src/main/kotlin/.../MainActivity.kt  # Android 入口
│   ├── build.gradle.kts                   # 项目级 Gradle 配置
│   ├── gradle.properties                  # Gradle 属性
│   ├── settings.gradle.kts                # Gradle 项目设置
│   └── gradlew.bat                        # Gradle 包装器
│
└── pubspec.yaml                           # Flutter 依赖配置
```

### 功能说明

| 功能 | 说明 |
|------|------|
| 📷 拍照记录 | 拍照或从相册选择美食图，填写菜名、地点、价格、评分 |
| 🤔 吃什么 | 随机模式 / 偏好模式推荐吃过的主菜 |
| 📖 美食日记 | AI 生成带样式的美食日记（翻书视图），支持导出长图/PDF |
| 🥗 营养分析 | AI 分析饮食营养均衡度 |
| 📊 偏好分析 | AI 分析口味偏好、菜系偏好 |
| 🌐 联网推荐 | 在社区推荐中搜索菜品，支持距离/价格筛选、点赞点踩举报 |
| ⚙️ 设置 | AI 模型配置、样式切换、数据管理、清空缓存 |
| 🎨 多主题 | 集市日 / 复古餐厅 / 抹茶工坊等主题风格 |

---

## 二、backend — Python 后端服务（联网推荐 API）

FastAPI 构建的推荐服务后端，为联网推荐功能提供 REST API。

### 启动方式

```bash
cd backend
pip install -r requirements.txt
python -m uvicorn main:app --host 0.0.0.0 --port 8000
```

或双击 `启动后端服务.bat`。

### 功能

```
backend/
├── main.py                   # FastAPI 应用主文件，包含：
│                             # - 用户注册/登录/鉴权 (JWT)
│                             # - 记录上传（含图片存储）
│                             # - 推荐搜索（距离/价格筛选、聚合、排序）
│                             # - 推荐详情查询
│                             # - 点赞/点踩/举报（含自动隐藏机制）
│                             # - AI 代理接口（服务端持有 API Key）
│                             # - SQLite 数据库初始化与迁移
│
├── requirements.txt          # Python 依赖清单
└── uploads/                  # 上传图片存储目录
```

**依赖：** fastapi, uvicorn, python-multipart, pyjwt, bcrypt, httpx

**API 接口一览：**

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/` | 根路径，服务状态 |
| GET | `/health` | 健康检查 |
| POST | `/v1/recommendations/upload-record` | 上传用餐记录（含图片） |
| POST | `/v1/recommendations/search` | 搜索推荐项 |
| GET | `/v1/recommendations/{record_id}` | 推荐详情 |
| POST | `/v1/recommendations/{record_id}/vote` | 点赞/点踩 |
| POST | `/v1/recommendations/{record_id}/report` | 举报 |
| POST | `/v1/auth/register` | 用户注册 |
| POST | `/v1/auth/login` | 用户登录 |
| GET | `/v1/auth/me` | 当前用户信息 |
| POST | `/v1/ai/chat` | AI 代理转发 |

---

## 三、CyberCoach — 赛博教练

面向校园场景的 AI 运动记录与分析 Web 应用。

### 启动方式

```bash
cd CyberCoach
npm install         # 安装依赖
npm run dev         # 同时启动前后端
```

或双击 `start.bat`（Windows）。

- 前端: http://localhost:5173
- 后端: http://localhost:3001

### 后端 (cybercoach-server)

```
cybercoach-server/src/
├── index.ts                            # 应用入口，Hono 框架配置与路由挂载
├── db/
│   ├── index.ts                        # SQLite 数据库初始化与连接
│   ├── schema.ts                       # 数据库表定义（运动记录、报告、提醒）
│   └── seed.ts                         # 测试种子数据
├── routes/
│   ├── records.ts                      # 运动记录 CRUD（手动录入 + 分页查询）
│   ├── ocr.ts                          # 运动截图 OCR 解析（LLM/Mock 双模式）
│   ├── reports.ts                      # 运动报告生成与周报统计
│   ├── plans.ts                        # AI 训练计划生成
│   └── reminders.ts                    # 提醒设置管理
├── middleware/
│   └── auth.ts                         # 认证中间件（API Key 验证）
├── services/
│   └── ai.ts                           # LLM 调用层（分析、报告、计划生成）
├── types/
│   └── index.ts                        # TypeScript 类型定义
└── utils/
    ├── errors.ts                       # 错误码定义
    ├── id.ts                           # ID 生成工具
    ├── response.ts                     # 统一响应格式
    └── validator.ts                    # 请求参数校验 (Zod)
```

**API 接口一览：**

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/api/v1/records` | 创建运动记录 |
| GET | `/api/v1/records` | 获取记录列表（分页） |
| GET | `/api/v1/records/{id}` | 获取记录详情 |
| PUT | `/api/v1/records/{id}` | 更新记录 |
| DELETE | `/api/v1/records/{id}` | 删除记录 |
| POST | `/api/v1/ocr/parse` | 解析运动截图 |
| POST | `/api/v1/reports/generate` | 生成单次运动报告 |
| GET | `/api/v1/reports/weekly` | 获取运动周报 |
| POST | `/api/v1/plans/generate` | 生成训练计划 |
| GET | `/api/v1/reminders` | 获取提醒设置 |
| PUT | `/api/v1/reminders` | 更新提醒设置 |

### 前端 (cybercoach-web)

```
cybercoach-web/src/
├── index.html                          # HTML 入口
├── index.css                           # 全局样式（CSS 变量、布局）
├── components/
│   └── Layout.css                      # 布局组件样式
├── constants/
│   └── index.ts                        # 常量定义（运动类型、泳姿、强度等选项）
├── hooks/
│   ├── useRecords.ts                   # 运动记录列表 Hook
│   ├── useReminder.ts                  # 提醒设置 Hook
│   └── useReport.ts                    # 运动报告 Hook
├── types/
│   └── index.ts                        # 前端 TypeScript 类型定义
└── utils/
    ├── api.ts                          # API 客户端（封装 fetch 请求）
    ├── format.ts                       # 格式化工具（时间、距离、配速、日期）
    └── validation.ts                   # 前端表单校验
```

---

## 四、根目录文档

| 文件 | 说明 |
|------|------|
| `今天吃什么.md` | 需求文档（Flutter 应用功能需求描述） |
| `开发测试日志.md` | 开发与测试记录 |
| `开发测试日志_2026-06-02_追加排查.md` | 追加排查记录 |
| `接口协议草案.md` | 联网推荐 API 协议草案 |
| `测试说明.md` | 测试说明文档 |
| `美术样式需求表.md` | UI 美术资源需求 |
| `想法2.txt` | 功能想法记录 |
| `HowToChat.md` | AI 架构说明文档 |
| `EXPERIENCE.md` | 经验知识库（踩坑记录与用户偏好） |
| `启动后端服务.bat` | 一键启动 Python 后端 |
| `启动服务器.bat` | 一键启动 Cloudflare Tunnel |

## 五、启动脚本

| 脚本 | 功能 |
|------|------|
| `启动后端服务.bat` | 启动 FastAPI 后端 (http://127.0.0.1:8000) |
| `启动服务器.bat` | 启动 Cloudflare Tunnel，将本地服务映射到公网 (https://api.whateattoday.xyz) |

## 六、编码规范

- 所有源码、配置、文档均使用 **UTF-8** 编码
- 详细编码规范请参考 `today_eat_app/docs/编码与文案协作约定.md`
- 本项目在 Windows 环境开发，行尾格式为 CRLF，不影响跨平台使用

---

*最后更新: 2026-06-05*
