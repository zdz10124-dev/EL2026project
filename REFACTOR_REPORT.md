# 重构报告

生成时间：2026-06-15

## 范围

本次按 `C:\Users\zdz10\.claude\skills\refactor-code\SKILL.md` 的要求，对 `C:\Projects\2026EL` 做项目级重构。考虑到项目说明文档可能不是最新版本，本次以实际代码结构为准。

重点处理对象是 `backend/main.py`：重构前它约 1200 行，混合了配置、数据库、模型、算法、反馈治理、认证、AI 代理和所有路由，是当前项目中最影响可维护性的单体文件。

## 已完成改动

### 后端拆分

- `backend/main.py`：压缩为 FastAPI 入口，只负责暴露 `app`。
- 新增 `backend/app_factory.py`：统一装配 FastAPI、CORS、静态资源、startup 初始化、根路径和健康检查。
- 新增 `backend/settings.py`：集中配置路径、推荐阈值、JWT、AI 代理配置。
- 新增 `backend/schemas.py`：集中 Pydantic 请求模型。
- 新增 `backend/database.py`：集中 SQLite 连接、表结构创建与迁移。
- 新增 `backend/utils.py`：集中通用文本、数值、时间、距离和客户端指纹函数。
- 新增 `backend/recommendation_engine.py`：集中推荐聚合、评分、加权抽样和响应构造。
- 新增 `backend/feedback.py`：集中点赞/点踩/举报统计和隐藏阈值治理。
- 新增 `backend/recommendation_routes.py`：集中 `/v1/recommendations` 路由。
- 新增 `backend/auth.py`：集中 `/v1/auth` 路由和 JWT 认证依赖。
- 新增 `backend/ai_proxy.py`：集中 `/v1/ai/chat` 代理。
- 更新 `backend/config.py`：改为兼容旧脚本的 re-export，不再维护一份过期配置。
- 新增 `backend/ARCHITECTURE.md`：说明当前后端真实结构，避免继续依赖滞后说明文档。
- 修正推荐候选距离回填逻辑：使用 `is not None` 判断代表记录距离，避免 `0.0` 被布尔短路误判。

### Flutter 服务层整理

- 重构 `today_eat_app/lib/services/llm_service.dart`：将文本、单图、多图三种 AI 调用统一收敛到 `_callChatCompletion`。
- 新增 `_callDirectChat` / `_callServerChat` 的共同响应解析 `_parseOpenAiJsonResponse`，减少重复 HTTP 组包和 JSON 解析代码。
- 将 OpenAI-compatible 响应内容提取拆出 `_extractOpenAiContent`，避免复杂 null-aware 索引链造成分析器兼容风险，并补充 choices/message/content 结构校验。
- 保持 `callLlm`、`callLlmWithImage`、`callLlmWithImages` 三个公开方法签名不变。
- 拆分 `today_eat_app/lib/services/meal_repository.dart`：将推荐决策、日记分组、统计汇总和容量格式化提取到同库 part `meal_repository_analysis.dart`，主仓库文件从约 949 行降到约 761 行。
- 新增 `today_eat_app/lib/services/README.md`：说明服务层职责边界和后续维护约定。

### 行为保持

以下对外行为保持不变：

- 数据库仍使用 `backend/recommendations.db`。
- 静态图片仍挂载在 `/media`。
- `GET /` 与 `GET /health` 保持原返回结构。
- `/v1/recommendations/*`、`/v1/auth/*`、`/v1/ai/chat` 路径保持不变。
- 推荐评分、分页、反馈隐藏阈值、上传记录、评论、可见性、投票、举报、认证和 AI 代理逻辑保持等价拆分。
- Flutter 端 AI 服务的公开 API 保持不变，调用模式仍支持 direct 与 server 两种。
- Flutter 端 `MealRepository` 的原有公开调用名保持不变，统计/推荐决策方法通过同库 extension 继续以实例方法形式使用。

## 复用性和可测试性改进

- 推荐算法从路由中提取到 `recommendation_engine.py`，后续可以单独构造记录输入测试评分与排序。
- 数据库初始化从业务路由中提取到 `database.py`，避免启动逻辑和接口逻辑互相污染。
- 反馈治理从推荐详情和投票/举报接口中提取到 `feedback.py`，避免阈值逻辑散落。
- 请求模型集中到 `schemas.py`，便于后续新增字段或复用 schema。
- `main.py` 现在只有入口职责，后续 AI 或开发者阅读范围显著缩小。
- `llm_service.dart` 统一了 direct/server 调用分发与 OpenAI JSON 响应解析，后续新增图片/文本混合调用时不需要再复制 HTTP 细节。

## 验证情况

- 已做源码级静态巡检：确认主要模块能按入口依赖顺序装配，公开路由前缀与原路径一致，数据库文件名未改变。
- 已复查后端拆分后的关键导入链：`main.py -> app_factory.py -> recommendation_routes.py/auth.py/ai_proxy.py`。
- 已复查 Flutter `llm_service.dart` 的公开方法签名和 direct/server 分发路径，并加固 OpenAI-compatible 响应解析。
- 已复查 `meal_repository.dart` 与 `meal_repository_analysis.dart` 的同库 part 关系，公开方法名保持不变。
- 已做常见密钥扫描：`**/*.{py,dart,ts,tsx,js,json,md,yaml,yml}` 未发现常见密钥泄露。
- 未杀掉、重启或主动停止任何服务器进程。
- 当前控制工具的 shell / Python / Git 执行能力仍返回 `FileNotFoundError(2)` 类路径/可执行文件解析错误，无法在本次会话里实际运行 `py_compile`、`flutter analyze`、`uvicorn` 或接口请求验证。因此本次验证仍以静态验证为准；建议你在本地终端运行：

```bash
cd C:\Projects\2026EL\backend
python -m py_compile main.py app_factory.py settings.py schemas.py database.py utils.py feedback.py recommendation_engine.py recommendation_routes.py auth.py ai_proxy.py config.py
```

Flutter 端建议运行：

```bash
cd C:\Projects\2026EL\today_eat_app
flutter analyze
```

如需不影响共享服务，可另开端口做冒烟测试：

```bash
cd C:\Projects\2026EL\backend
uvicorn main:app --host 127.0.0.1 --port 18080
```

然后访问：

```text
http://127.0.0.1:18080/health
```

## 风险提示

- 如果当前线上进程以热重载方式运行，后端文件变化可能触发自动 reload；本次没有主动终止任何进程。
- Flutter 端 `network_recommendation_screen.dart` 仍然偏大，但它主要是 UI 状态与组件组合；本次没有强行拆屏，避免在缺少 `flutter analyze` 的情况下引入路由或状态回归。
- CyberCoach 已经有相对明确的 server/web 分层，本次没有强行搬动目录，避免表面重构引入不必要风险。
