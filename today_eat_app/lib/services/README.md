# Services 目录结构说明

本目录包含 Flutter 端的主要业务服务层。当前重构目标是降低单个服务文件的职责密度，同时保持公开 API 不变。

## 主要文件

- `meal_repository.dart`：餐食记录仓库门面，负责本地记录 CRUD、图片持久化、公开推荐同步和对外统一入口。
- `meal_repository_analysis.dart`：`meal_repository.dart` 的同库 part，承接推荐决策、日记分组、统计汇总和容量格式化等纯分析逻辑；外部仍通过 `MealRepository` 实例调用原方法。
- `database_service.dart`：本地 SQLite 表结构和持久化访问。
- `recommendation_api_service.dart`：联网推荐服务 HTTP 客户端。
- `llm_service.dart`：AI 直连/服务端代理调用封装。
- `app_settings_service.dart`：用户设置、推荐客户端 ID、公开上传开关等配置持久化。

## 维护约定

- 新增本地记录读写优先放在 `MealRepository` 和 `DatabaseService` 的明确职责边界内。
- 新增统计、筛选、日记分组、推荐决策等纯逻辑优先放入 `meal_repository_analysis.dart`，避免主仓库文件重新膨胀。
- 新增联网推荐接口优先放入 `RecommendationApiService`，`MealRepository` 只做客户端 ID、用户资料和本地状态编排。
- 不要在服务层直接依赖 UI 组件，保持可测试性。
