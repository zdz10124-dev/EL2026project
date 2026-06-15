# Backend architecture

该目录是“今天吃什么”联网推荐与 AI 代理服务。旧说明文档可能滞后，后端当前以代码为准。

## 入口

- `main.py`：仅负责创建 `app`，兼容 `uvicorn main:app`。
- `app_factory.py`：装配 FastAPI、CORS、静态媒体、启动初始化、根路径与健康检查。

## 模块职责

- `settings.py`：路径、阈值、JWT、OpenAI 代理等运行配置。
- `database.py`：SQLite 连接、表结构创建和轻量迁移。
- `schemas.py`：Pydantic 请求模型。
- `utils.py`：时间、文本清洗、菜名归一化、距离计算、客户端指纹等通用函数。
- `recommendation_engine.py`：推荐聚合、评分、加权抽样、分页前排序和响应条目构造。
- `feedback.py`：点赞/点踩/举报统计，以及达到阈值后的隐藏治理。
- `recommendation_routes.py`：`/v1/recommendations` 下所有公开推荐接口。
- `auth.py`：用户注册、登录、当前用户读取和 JWT 认证依赖。
- `ai_proxy.py`：服务端持有 API Key 的 `/v1/ai/chat` 代理。
- `config.py`：兼容旧脚本的导出层，新代码不应继续扩展它。

## 保持不变的外部行为

- 数据库文件仍是 `backend/recommendations.db`。
- 图片静态路径仍挂载在 `/media`。
- 公开 API 路径和返回结构保持与重构前一致。
- 未增加新的业务功能；重构重点是拆分职责和减少单文件耦合。

## 后续维护建议

新增接口时优先放到单独 route 模块；算法、数据库和请求模型不要再堆回 `main.py`。如果需要替换数据库或推荐算法，优先改 `database.py` 或 `recommendation_engine.py`，让 route 层保持薄封装。
