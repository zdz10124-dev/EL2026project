# 食动智衡健康 Agent 行动闭环设计规格

## 1. 背景与目标

`today_eat_app` 已经具备饮食记录、运动记录、运动截图识别、健康档案、确定性健康指标和 7/30 天综合 AI 分析。当前不足是 AI 主要以“用户进入分析页后生成报告”的方式工作，缺少持续状态、行动执行和反馈调整，因此产品仍容易被理解为饮食记录 App、运动记录 App 或健康报表工具。

本次改造将“食动智衡”定位为：

> 能理解用户饮食、运动与恢复状态，并持续安排下一步行动的个人健康 Agent。

首期目标不是增加聊天页面，也不是扩展更多统计图表，而是建立可演示、可追踪的闭环：

```text
记录与打卡
-> 本地计算健康上下文
-> Agent 选择今日行动
-> 用户执行、完成或跳过
-> 记录反馈
-> Agent 调整后续行动
```

## 2. 产品原则

### 2.1 行动优先

首页首先回答“现在最值得做什么”，而不是展示大量历史统计。每次最多突出一个主行动，并允许查看其他次级行动。

### 2.2 本地事实与 AI 推断分离

次数、时长、距离、连续高负荷日、运动后饮食覆盖、恢复打卡趋势等由本地程序计算。AI 只解释结构化上下文、排序行动并生成自然语言。

### 2.3 有依据才能进入行动列表

每条 AI 行动必须引用由本地服务提供的 `allowedEvidence`。引用为空、引用不在白名单、包含医疗诊断或操作目标非法时，该行动被拒绝。

### 2.4 用户保留最终控制权

AI 不能自动写入饮食或运动记录，不能自动把行动标记为完成，也不能替用户生成医疗结论。用户可以完成、跳过或反馈“太难”。

### 2.5 本地优先与可降级

无网络或未配置 AI 时，记录、恢复打卡、确定性上下文和已有行动仍可使用。系统可以展示保守的本地行动，但必须标注来源。

### 2.6 不以聊天作为 Agent 证明

首期不新增通用聊天入口。Agent 能力通过“感知、决策、行动、反馈、重规划”的状态变化体现。

## 3. 范围

### 3.1 首期必须交付

- 每日恢复打卡：睡眠质量、疲劳、肌肉酸痛、精力和可选备注。
- 本地 `HealthContextService`：联合当天记录、7 天指标、恢复打卡和健康目标。
- 每日 Agent 计划：最多三个饮食、运动或休息行动。
- 今日页主行动卡：依据、有效时间、执行入口和状态。
- 行动反馈：完成、跳过、太难。
- 数据变化后的指纹失效和受控重规划。
- “吃什么”增加健康场景模式，消费相同的健康上下文。
- AI 未配置、数据不足、网络失败和陈旧计划状态。
- 比赛演示数据增加恢复打卡和已完成行动。

### 3.2 后续阶段

- 基于健康目标和可用时间生成一周行动安排。
- 融合 CyberCoach 的下一次训练建议和单次运动恢复反馈。
- 应用内提醒与计划执行率。
- 经用户授权后接入系统通知或系统健康数据。

### 3.3 首期不做

- 不接入穿戴设备、Health Connect 或 Apple Health。
- 不自动采集睡眠、心率或 GPS 轨迹。
- 不提供疾病诊断、处方、治疗方案或紧急医疗判断。
- 不建设运动社区、排行榜或挑战系统。
- 不删除现有联网推荐、美食日记和统计功能，只降低其一级曝光。
- 不引入新的状态管理框架。
- 不实现通用工具调用框架或开放式 Agent 插件系统。

## 4. 用户体验闭环

### 4.1 首次进入

用户尚无当天恢复打卡时，今日页主卡显示“完成 20 秒状态打卡”。打卡完成后，本地上下文立即刷新；满足数据门槛且 AI 可用时生成当日计划。

### 4.2 日常记录

新增饮食或运动记录后，数据指纹发生变化。系统不阻塞保存流程，也不立即连续调用 AI，而是将计划标记为需要更新。用户返回今日页或主动刷新时触发受控重规划。

### 4.3 执行动作

主行动根据 `actionTarget` 打开相应页面：

- `recordMeal`：饮食记录页。
- `recordExercise`：运动记录页。
- `decideMeal`：健康场景“吃什么”。
- `recoveryCheckIn`：恢复打卡。
- `openHealth`：健康依据页。
- `none`：仅展示文字行动。

### 4.4 反馈

- `完成`：行动进入 `completed`，首页提升下一个待执行行动。
- `跳过`：行动进入 `skipped`，记录可选原因。
- `太难`：行动进入 `skipped`，反馈难度为 `tooHard`，下次重规划必须把该反馈作为约束。

完成操作本身不立即请求模型。跳过或“太难”会将当前计划标记为需要更新；下一次计划刷新时纳入反馈摘要。

## 5. 领域模型

### 5.1 RecoveryCheckIn

```dart
class RecoveryCheckIn {
  const RecoveryCheckIn({
    this.id,
    required this.localDate,
    required this.sleepQuality,
    required this.fatigue,
    required this.soreness,
    required this.energy,
    required this.createdAt,
    required this.updatedAt,
    this.note,
  });

  final int? id;
  final String localDate;
  final int sleepQuality;
  final int fatigue;
  final int soreness;
  final int energy;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;
}
```

四个评分范围固定为 1 到 5。`localDate` 使用设备本地日期 `yyyy-MM-dd`，数据库中保持唯一；同一天再次提交视为更新。

### 5.2 HealthContext

`HealthContext` 是只存在于内存中的确定性快照：

- `date`：上下文日期。
- `profile`：健康目标和运动偏好。
- `todayMealCount`、`todayExerciseMinutes`。
- `lastExerciseSummary`。
- `sevenDayMetrics`：复用现有 `HealthMetrics`。
- `recoveryCheckIn`。
- `recentFeedback`：最近七天完成、跳过和太难数量。
- `allowedEvidence`：可供 AI 逐字引用的文本集合。
- `dataQuality`：缺失项和是否允许生成 AI 计划。

首期允许生成计划的最低门槛：

- 已完成当天恢复打卡；并且
- 最近七天至少存在一天饮食或运动记录。

不满足门槛时仍可展示本地引导行动，但不调用 AI。

### 5.3 DailyAgentPlan

```dart
enum AgentPlanSource { ai, localFallback }

class DailyAgentPlan {
  const DailyAgentPlan({
    required this.localDate,
    required this.dataFingerprint,
    required this.summary,
    required this.actions,
    required this.generatedAt,
    required this.source,
    required this.needsRefresh,
  });
}
```

每天保存一个计划元数据，计划中的行动单独存储。新的有效计划覆盖当天旧计划的“当前版本”，但保留已完成和已跳过行动用于反馈统计。

### 5.4 AgentAction

```dart
enum AgentActionCategory { diet, exercise, rest }
enum AgentActionPriority { low, medium, high }
enum AgentActionStatus { pending, completed, skipped, expired }
enum AgentActionTarget {
  recordMeal,
  recordExercise,
  decideMeal,
  recoveryCheckIn,
  openHealth,
  none,
}
enum AgentActionDifficulty { appropriate, tooHard }
```

行动字段：

- `clientActionId`：本地稳定 ID。
- `planDate`：所属本地日期。
- `category`、`priority`。
- `title`、`action`。
- `evidence`：白名单依据。
- `target`：可执行入口。
- `status`。
- `difficulty`：可选。
- `feedbackNote`：可选跳过原因。
- `validUntil`。
- `createdAt`、`updatedAt`。

## 6. 数据库设计

SQLite 版本从 7 升级为 8，新增三张表：

### 6.1 recovery_check_ins

- `id INTEGER PRIMARY KEY AUTOINCREMENT`
- `local_date TEXT NOT NULL UNIQUE`
- `sleep_quality INTEGER NOT NULL`
- `fatigue INTEGER NOT NULL`
- `soreness INTEGER NOT NULL`
- `energy INTEGER NOT NULL`
- `note TEXT`
- `created_at TEXT NOT NULL`
- `updated_at TEXT NOT NULL`

### 6.2 daily_agent_plans

- `local_date TEXT PRIMARY KEY`
- `data_fingerprint TEXT NOT NULL`
- `summary TEXT NOT NULL`
- `source TEXT NOT NULL`
- `needs_refresh INTEGER NOT NULL DEFAULT 0`
- `generated_at TEXT NOT NULL`

### 6.3 agent_actions

- `id INTEGER PRIMARY KEY AUTOINCREMENT`
- `client_action_id TEXT NOT NULL UNIQUE`
- `plan_date TEXT NOT NULL`
- `category TEXT NOT NULL`
- `priority TEXT NOT NULL`
- `title TEXT NOT NULL`
- `action_text TEXT NOT NULL`
- `evidence_json TEXT NOT NULL`
- `target TEXT NOT NULL`
- `status TEXT NOT NULL`
- `difficulty TEXT`
- `feedback_note TEXT`
- `valid_until TEXT NOT NULL`
- `created_at TEXT NOT NULL`
- `updated_at TEXT NOT NULL`

索引：

- `agent_actions(plan_date, status)`
- `agent_actions(updated_at DESC)`

升级只新增表和索引，不修改现有饮食、运动与健康分析表，不删除旧数据。

## 7. 服务边界

### 7.1 RecoveryRepository

负责恢复打卡的读取、保存和变化流：

```dart
Future<RecoveryCheckIn?> findByDate(DateTime date);
Future<RecoveryCheckIn> save(RecoveryCheckInDraft draft);
Stream<RecoveryCheckIn?> watchDate(DateTime date);
```

### 7.2 HealthContextService

纯计算服务，不读写数据库，不调用网络：

```dart
HealthContext build({
  required DateTime now,
  required HealthProfile profile,
  required List<MealRecord> meals,
  required List<ExerciseRecord> exercises,
  required RecoveryCheckIn? recovery,
  required AgentFeedbackSummary feedback,
});
```

`allowedEvidence` 只包含程序能够证明的事实。恢复状态使用可解释文本，例如“今日疲劳评分 4/5”，不将评分直接解释为疾病或训练禁忌。

### 7.3 DailyAgentRepository

负责收集仓库数据、构建上下文、管理指纹与缓存、调用 Agent、持久化计划：

```dart
Future<DailyAgentState> load(DateTime date, {bool forceRefresh = false});
Future<void> completeAction(String clientActionId);
Future<void> skipAction(
  String clientActionId, {
  AgentActionDifficulty? difficulty,
  String? note,
});
Future<void> markNeedsRefresh(DateTime date);
```

页面不能直接拼 Prompt、计算指纹或操作 Agent 表。

### 7.4 HealthAgentService

新增：

```dart
Future<DailyAgentPlan> generateDailyPlan({
  required HealthContext context,
  required String dataFingerprint,
});

Future<ContextualMealSuggestion> suggestMealForContext({
  required HealthContext context,
  required List<MealRecord> candidates,
});
```

继续复用当前 `LlmService` 的直连和服务端代理模式。首期不改变现有综合健康分析接口。

## 8. AI 契约

请求只包含：

- 本地日期和健康目标。
- 去标识化的确定性上下文。
- 最近反馈数量和“太难”约束。
- `allowed_evidence`。
- 可用 `action_target` 枚举。

不得包含昵称、精确地点、图片路径、数据库 ID、API Key 或完整备注。

模型输出：

```json
{
  "summary": "今日状态概览",
  "actions": [
    {
      "category": "diet",
      "priority": "high",
      "title": "补充一顿有蔬菜的正餐",
      "action": "下一餐优先选择包含蔬菜和蛋白质的组合",
      "evidence": ["近 7 天常见食材未记录蔬菜"],
      "target": "decideMeal"
    }
  ]
}
```

校验规则：

- 最多三个行动。
- `title`、`action` 非空并限制长度。
- 每条行动至少一条依据，依据必须逐字存在于白名单。
- 枚举值非法时拒绝该行动，不映射到默认类别。
- 拒绝疾病诊断、处方和治疗措辞。
- 所有行动 `validUntil` 由客户端设置为次日凌晨，不信任模型时间。
- 过滤后没有合法行动时返回解析失败，不保存空 AI 计划。

## 9. 本地降级行动

本地降级不伪装为 AI：

- 未打卡：提示完成恢复打卡，目标为 `recoveryCheckIn`。
- 今日无饮食记录且已到中午：提示记录一餐，目标为 `recordMeal`。
- 今日无运动记录：可提示查看健康目标或记录活动，但不强制训练。
- 当日计划全部完成：显示“今日行动已完成”，不继续生成新任务。

本地规则不根据疲劳评分自动下达医学或训练禁令。

## 10. 页面设计

### 10.1 今日页

页面顺序：

1. 日期、健康目标和 Agent 状态。
2. 今日主行动卡。
3. 恢复状态快速入口。
4. 其他待执行行动。
5. 饮食和运动快捷记录。
6. 今日事实摘要。

主行动卡展示：

- 类别和优先级。
- 标题和具体行动。
- 一条折叠后的主要依据。
- “查看依据”。
- 主操作按钮。
- “完成”“跳过”“太难”反馈。
- AI、本地建议或陈旧缓存标记。

### 10.2 恢复打卡页

使用四组 1 到 5 的明确量表，默认不选中任何值。全部评分完成后才允许保存。备注选填，保存后返回今日页。

### 10.3 吃什么

新增 `healthContext` 模式并设为默认：

- 显示当前场景依据。
- 优先给出饮食类型或组合建议，不伪造餐厅。
- 可以引用用户历史菜品作为候选。
- 保留“随机”和“历史偏好”作为次级模式。

### 10.4 健康页

“综合健康分析”继续保留。新增“Agent 行动记录”入口，展示近七天完成率、跳过与太难反馈；周计划在后续阶段加入。

### 10.5 原有美食社区功能

联网推荐、美食日记、地点、价格与评分统计继续位于“饮食洞察工具”。今日页和健康页首屏不展示社区上传、点赞或价格筛选。

## 11. 重规划与缓存策略

`dataFingerprint` 包含：

- 当天日期。
- 健康档案。
- 最近七天饮食和运动记录的稳定字段。
- 当天恢复打卡。
- 最近七天行动反馈摘要。

以下事件调用 `markNeedsRefresh`：

- 保存、修改或删除饮食记录。
- 保存、修改或删除运动记录。
- 保存恢复打卡。
- 跳过行动或反馈“太难”。
- 健康档案发生变化。

以下事件不强制请求 AI：

- 仅切换底部导航。
- 展开建议依据。
- 将行动标记为完成。

同一天、同一指纹且 `needsRefresh == false` 时直接使用缓存。网络失败时展示旧计划并标记“数据已变化，当前展示上次计划”。用户主动刷新可以跳过缓存，但仍应防止按钮连点产生并发请求。

## 12. 错误处理

- AI 未配置：展示本地行动和配置入口。
- 数据不足：展示缺失项，不调用 AI。
- 网络超时：保留旧计划和用户反馈。
- AI JSON 非法：不保存结果，展示可重试错误。
- 恢复评分越界：阻止保存并指出字段。
- 数据库升级失败：不删除旧数据库。
- 行动已过期：标记 `expired`，不允许再完成或跳过。
- 并发刷新：后发请求复用当前 Future，避免重复模型调用。

## 13. 隐私与安全

- 恢复备注默认不发送给 AI；首期只发送评分。
- 精确地点、价格、图片、昵称和本地 ID 不进入每日计划请求。
- 服务端 API Key 只保存在服务端；客户端直连继续标记为开发模式。
- 服务端日志不记录完整健康上下文和模型正文。
- 每日计划继续显示非医疗声明。

## 14. 测试策略

单元测试：

- 恢复评分校验和同日覆盖。
- 数据库 7 -> 8 升级和全新安装。
- 健康上下文日期边界、证据白名单和数据门槛。
- 指纹稳定性与记录变化。
- Agent 输出枚举、证据、医疗措辞和空结果过滤。
- 同指纹缓存、陈旧计划和重规划。
- 完成、跳过、太难状态转换。
- 健康场景饮食建议不伪造餐厅。

Widget 测试：

- 今日页无打卡、生成中、AI 计划、本地计划、陈旧计划和错误状态。
- 恢复打卡未完成时不能保存。
- 主行动执行入口正确导航。
- 完成后提升下一条待执行行动。
- 跳过和太难反馈正确显示。
- 吃什么默认进入健康场景模式。

后端测试：

- 每日计划接口需要 JWT。
- 输入长度、行动数量和枚举限制。
- evidence 不在白名单时拒绝。
- 医疗诊断措辞拒绝。
- 日志不包含 JWT、API Key 或完整上下文。

## 15. 分阶段交付

### 阶段一：恢复感知与健康上下文

交付恢复打卡、数据库迁移、上下文计算和证据白名单。即使无 AI，也能演示产品已经联合饮食、运动和恢复。

### 阶段二：每日 Agent 行动闭环

交付每日计划、主行动卡、完成/跳过/太难、缓存与重规划。这是比赛创新主线。

### 阶段三：场景化饮食决策与教练中心

改造“吃什么”，增加行动历史和执行率，降低社区功能曝光。

### 阶段四：周计划与提醒

融合 CyberCoach 的训练计划和恢复反馈，形成周级计划。系统通知需要新依赖和权限，单独评估后再实施。

## 16. 验收标准

- 用户可在 20 秒内完成当天恢复打卡。
- Agent 上下文同时消费饮食、运动、恢复和健康目标。
- 每日最多三个行动，首页只突出一个主行动。
- 每条 AI 行动至少有一条可展示且可验证的依据。
- 用户可以完成、跳过或反馈行动太难。
- 反馈和记录变化会使计划进入待刷新状态。
- 未配置 AI 或网络失败时仍可使用记录、打卡和本地行动。
- “吃什么”默认依据健康上下文，不以餐厅、价格和评分为主。
- 比赛主演示路径不进入联网推荐社区。
- 不增加通用聊天入口，不引入新的状态管理依赖。
