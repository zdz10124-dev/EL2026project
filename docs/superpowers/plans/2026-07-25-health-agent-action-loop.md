# 食动智衡健康 Agent 行动闭环 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在现有饮食、运动和综合健康分析之上，建立恢复感知、每日行动、执行反馈、受控重规划和健康场景饮食决策组成的个人健康 Agent 闭环。

**Architecture:** 保留 `MealRepository`、`ExerciseRepository`、`HealthAnalysisRepository` 和现有 LLM 双模式，在其上增加恢复仓库、纯计算健康上下文、每日 Agent 仓库和结构化行动模型。页面只消费仓库状态；本地程序生成证据白名单和数据指纹，AI 只排序并解释行动。

**Tech Stack:** Flutter 3.44、Dart 3.12、sqflite、SharedPreferences、http、crypto、FastAPI、Pydantic、httpx、SQLite。

## Global Constraints

- 所有代码和提交只能位于 `ftcutter` 或由它创建的 `codex/*` 分支，禁止修改 `main`。
- 优先使用现有依赖，不增加状态管理、路由、通知或健康平台依赖。
- SQLite 数据库版本只从 7 升级到 8，升级只新增表和索引，不删除现有数据。
- 首期不增加通用聊天入口。
- 恢复评分范围固定为 1 到 5，恢复备注不发送给 AI。
- 每日 AI 行动最多三条，每条必须引用 `allowedEvidence` 中至少一条依据。
- AI 不能直接写入饮食、运动或恢复记录。
- 禁止疾病诊断、处方、治疗建议和缺少依据的精确热量结论。
- 无 AI 或网络失败时必须保留记录、恢复打卡、确定性上下文和本地降级行动。
- 饮食与运动保存路径不得等待每日 Agent 网络刷新。
- 修改前保留当前工作区中的 Android 缓存、本地代理配置和无关文档，不使用 `git add -A`。
- Flutter 和 Dart 命令默认在 `D:\Repos\EL2026project\today_eat_app` 执行；Python 后端命令默认在 `D:\Repos\EL2026project` 执行。

---

## File Structure

新增文件职责：

- `today_eat_app/lib/models/recovery_check_in.dart`：恢复打卡模型和草稿。
- `today_eat_app/lib/services/recovery_repository.dart`：恢复打卡持久化和日期流。
- `today_eat_app/lib/models/health_context.dart`：去标识的确定性 Agent 上下文。
- `today_eat_app/lib/services/health_context_service.dart`：纯函数上下文计算和证据生成。
- `today_eat_app/lib/services/daily_agent_fingerprint.dart`：每日 Agent 数据指纹。
- `today_eat_app/lib/models/agent_action.dart`：行动、计划、状态和反馈模型。
- `today_eat_app/lib/services/agent_plan_parser.dart`：严格解析 AI 每日计划。
- `today_eat_app/lib/services/agent_action_repository.dart`：计划和行动表的数据库适配。
- `today_eat_app/lib/services/daily_agent_repository.dart`：上下文、缓存、AI 和状态转换编排。
- `today_eat_app/lib/screens/recovery/recovery_check_in_screen.dart`：20 秒恢复打卡页。
- `today_eat_app/lib/widgets/agent_action_card.dart`：今日主行动与反馈组件。
- `today_eat_app/lib/services/contextual_meal_service.dart`：健康场景饮食决策。
- `today_eat_app/lib/screens/health/agent_history_screen.dart`：近七天行动历史和执行率。

修改文件职责：

- `today_eat_app/lib/services/database_service.dart`：版本 8 迁移和三张新表的 CRUD。
- `today_eat_app/lib/services/health_agent_service.dart`：每日计划和场景饮食 AI 方法。
- `today_eat_app/lib/services/health_api_service.dart`：服务端每日计划代理。
- `today_eat_app/lib/screens/home_shell.dart`：装配 Agent 依赖。
- `today_eat_app/lib/screens/today/today_screen.dart`：改为 Agent 工作台。
- `today_eat_app/lib/screens/decide_screen.dart`：增加健康场景模式。
- `today_eat_app/lib/screens/health/health_hub_screen.dart`：增加 Agent 行动历史入口。
- `today_eat_app/lib/services/demo_data_service.dart`：导入恢复和行动演示数据。
- `today_eat_app/assets/demo/demo_health_records.json`：补充 Agent 演示 fixture。
- `backend/main.py`：增加经过鉴权和校验的每日计划端点。

---

### Task 1: 建立恢复打卡模型、校验和数据库迁移

**Files:**
- Create: `today_eat_app/lib/models/recovery_check_in.dart`
- Create: `today_eat_app/lib/services/recovery_repository.dart`
- Modify: `today_eat_app/lib/services/database_service.dart`
- Test: `today_eat_app/test/services/recovery_repository_test.dart`
- Test: `today_eat_app/test/services/database_v8_migration_test.dart`

**Interfaces:**
- Produces: `RecoveryCheckInDraft`、`RecoveryCheckIn`。
- Produces: `Future<RecoveryCheckIn?> RecoveryRepository.findByDate(DateTime date)`。
- Produces: `Future<RecoveryCheckIn> RecoveryRepository.save(RecoveryCheckInDraft draft)`。
- Produces: `Stream<RecoveryCheckIn?> RecoveryRepository.watchDate(DateTime date)`。
- Produces: `DatabaseService.fetchRecoveryCheckIn(String localDate)` 和 `upsertRecoveryCheckIn(Map<String, Object?> values)`。

- [ ] **Step 1: 写评分范围和同日覆盖失败测试**

```dart
test('rejects recovery ratings outside 1 to 5', () {
  final draft = RecoveryCheckInDraft(
    date: DateTime(2026, 7, 25),
    sleepQuality: 0,
    fatigue: 3,
    soreness: 2,
    energy: 4,
  );

  expect(() => draft.validate(), throwsFormatException);
});

test('saving twice on the same local date updates one record', () async {
  await repository.save(RecoveryCheckInDraft(
    date: DateTime(2026, 7, 25),
    sleepQuality: 3,
    fatigue: 3,
    soreness: 2,
    energy: 3,
  ));
  await repository.save(RecoveryCheckInDraft(
    date: DateTime(2026, 7, 25, 21),
    sleepQuality: 4,
    fatigue: 2,
    soreness: 1,
    energy: 4,
  ));

  final saved = await repository.findByDate(DateTime(2026, 7, 25));
  expect(saved!.sleepQuality, 4);
  expect(await database.countRows('recovery_check_ins'), 1);
});
```

- [ ] **Step 2: 运行测试并确认失败**

Run:

```powershell
flutter test test/services/recovery_repository_test.dart test/services/database_v8_migration_test.dart
```

Expected: FAIL，因为模型、仓库和版本 8 表尚不存在。

- [ ] **Step 3: 实现恢复模型和日期键**

```dart
String recoveryDateKey(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

class RecoveryCheckInDraft {
  const RecoveryCheckInDraft({
    required this.date,
    required this.sleepQuality,
    required this.fatigue,
    required this.soreness,
    required this.energy,
    this.note,
  });

  final DateTime date;
  final int sleepQuality;
  final int fatigue;
  final int soreness;
  final int energy;
  final String? note;

  void validate() {
    final values = [sleepQuality, fatigue, soreness, energy];
    if (values.any((value) => value < 1 || value > 5)) {
      throw const FormatException('恢复评分必须在 1 到 5 之间');
    }
  }
}
```

`RecoveryCheckIn` 实现 `toMap()`、`fromMap()` 和 `copyWith()`；备注先 `trim()`，空字符串保存为 `null`。

- [ ] **Step 4: 实现数据库版本 8 迁移**

将 `_databaseVersion` 改为 `8`，在创建和升级路径调用：

```dart
Future<void> _createAgentTables(Database db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS recovery_check_ins(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      local_date TEXT NOT NULL UNIQUE,
      sleep_quality INTEGER NOT NULL,
      fatigue INTEGER NOT NULL,
      soreness INTEGER NOT NULL,
      energy INTEGER NOT NULL,
      note TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS daily_agent_plans(
      local_date TEXT PRIMARY KEY,
      data_fingerprint TEXT NOT NULL,
      summary TEXT NOT NULL,
      source TEXT NOT NULL,
      needs_refresh INTEGER NOT NULL DEFAULT 0,
      generated_at TEXT NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS agent_actions(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      client_action_id TEXT NOT NULL UNIQUE,
      plan_date TEXT NOT NULL,
      category TEXT NOT NULL,
      priority TEXT NOT NULL,
      title TEXT NOT NULL,
      action_text TEXT NOT NULL,
      evidence_json TEXT NOT NULL,
      target TEXT NOT NULL,
      status TEXT NOT NULL,
      difficulty TEXT,
      feedback_note TEXT,
      valid_until TEXT NOT NULL,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
  ''');
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_agent_actions_date_status '
    'ON agent_actions(plan_date, status)',
  );
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_agent_actions_updated '
    'ON agent_actions(updated_at DESC)',
  );
}
```

在 `onUpgrade` 中仅当 `oldVersion < 8` 时调用 `_createAgentTables(db)`。

- [ ] **Step 5: 实现 RecoveryRepository**

仓库保存时先校验，再通过 `INSERT ... ON CONFLICT(local_date) DO UPDATE` 保持同日唯一；成功后向对应日期的广播流发送最新值。

- [ ] **Step 6: 运行测试**

Run:

```powershell
flutter test test/services/recovery_repository_test.dart test/services/database_v8_migration_test.dart
```

Expected: PASS，数据库升级后旧饮食与运动表仍存在，恢复记录同日覆盖。

- [ ] **Step 7: 提交**

```powershell
git add today_eat_app/lib/models/recovery_check_in.dart today_eat_app/lib/services/recovery_repository.dart today_eat_app/lib/services/database_service.dart today_eat_app/test/services/recovery_repository_test.dart today_eat_app/test/services/database_v8_migration_test.dart
git commit -m "feat: persist daily recovery check-ins"
```

---

### Task 2: 建立确定性 HealthContext 和数据指纹

**Files:**
- Create: `today_eat_app/lib/models/health_context.dart`
- Create: `today_eat_app/lib/services/health_context_service.dart`
- Create: `today_eat_app/lib/services/daily_agent_fingerprint.dart`
- Test: `today_eat_app/test/services/health_context_service_test.dart`
- Test: `today_eat_app/test/services/daily_agent_fingerprint_test.dart`

**Interfaces:**
- Consumes: `HealthProfile`、`MealRecord`、`ExerciseRecord`、`RecoveryCheckIn`、`HealthMetricsService`。
- Produces: `AgentFeedbackSummary`。
- Produces: `HealthContext HealthContextService.build(...)`。
- Produces: `String buildDailyAgentFingerprint(HealthContext context)`。

- [ ] **Step 1: 写日期边界、证据和门槛失败测试**

```dart
test('builds evidence from meals exercises recovery and profile', () {
  final context = service.build(
    now: DateTime(2026, 7, 25, 9),
    profile: const HealthProfile(goal: HealthGoal.endurance),
    meals: [mealAt(DateTime(2026, 7, 25, 8))],
    exercises: [exerciseAt(DateTime(2026, 7, 24, 18), rpe: 8)],
    recovery: recoveryAt('2026-07-25', fatigue: 4),
    feedback: const AgentFeedbackSummary(
      completed: 2,
      skipped: 1,
      tooHard: 1,
    ),
  );

  expect(context.todayMealCount, 1);
  expect(context.allowedEvidence, contains('今日疲劳评分 4/5'));
  expect(context.allowedEvidence, contains('健康目标为耐力提升'));
  expect(context.canGenerateAiPlan, isTrue);
});

test('requires today recovery and recent health records for ai plan', () {
  final context = service.build(
    now: DateTime(2026, 7, 25),
    profile: const HealthProfile(),
    meals: const [],
    exercises: const [],
    recovery: null,
    feedback: AgentFeedbackSummary.empty,
  );

  expect(context.canGenerateAiPlan, isFalse);
  expect(context.missingInputs, contains('today_recovery'));
  expect(context.missingInputs, contains('recent_records'));
});
```

- [ ] **Step 2: 运行测试并确认失败**

Run:

```powershell
flutter test test/services/health_context_service_test.dart test/services/daily_agent_fingerprint_test.dart
```

Expected: FAIL，因为上下文服务尚不存在。

- [ ] **Step 3: 实现 HealthContext 数据结构**

```dart
class AgentFeedbackSummary {
  const AgentFeedbackSummary({
    required this.completed,
    required this.skipped,
    required this.tooHard,
  });

  static const empty = AgentFeedbackSummary(
    completed: 0,
    skipped: 0,
    tooHard: 0,
  );

  final int completed;
  final int skipped;
  final int tooHard;

  Map<String, int> toJson() => {
    'completed': completed,
    'skipped': skipped,
    'too_hard': tooHard,
  };
}
```

`HealthContext` 提供 `toPromptJson()`，只输出目标、当天计数、七天指标、恢复评分、反馈汇总、缺失项和白名单依据；不得输出恢复备注、地点、图片路径和本地 ID。

- [ ] **Step 4: 实现 HealthContextService**

复用 `HealthMetricsService.calculate()` 计算七天窗口。证据顺序固定为目标、恢复、今日记录、七天饮食、七天运动、运动后饮食和反馈，确保指纹稳定。

```dart
final missingInputs = <String>[
  if (recovery == null) 'today_recovery',
  if (sevenDayMetrics.mealCount == 0 &&
      sevenDayMetrics.exerciseCount == 0)
    'recent_records',
];

return HealthContext(
  date: DateTime(now.year, now.month, now.day),
  profile: profile,
  todayMealCount: todayMeals.length,
  todayExerciseMinutes: todayExercises.fold(
    0,
    (sum, item) => sum + (item.durationSeconds / 60).round(),
  ),
  sevenDayMetrics: sevenDayMetrics,
  recovery: recovery,
  feedback: feedback,
  allowedEvidence: evidence,
  missingInputs: missingInputs,
);
```

- [ ] **Step 5: 实现稳定指纹**

```dart
String buildDailyAgentFingerprint(HealthContext context) {
  final canonical = jsonEncode(context.toFingerprintJson());
  return sha256.convert(utf8.encode(canonical)).toString();
}
```

`toFingerprintJson()` 中集合必须先排序，时间统一为 ISO 8601 日期或秒级时间，不包含 `generatedAt`。

- [ ] **Step 6: 运行测试**

Run:

```powershell
flutter test test/services/health_context_service_test.dart test/services/daily_agent_fingerprint_test.dart
```

Expected: PASS；相同输入指纹一致，恢复评分或记录变化后指纹变化。

- [ ] **Step 7: 提交**

```powershell
git add today_eat_app/lib/models/health_context.dart today_eat_app/lib/services/health_context_service.dart today_eat_app/lib/services/daily_agent_fingerprint.dart today_eat_app/test/services/health_context_service_test.dart today_eat_app/test/services/daily_agent_fingerprint_test.dart
git commit -m "feat: calculate daily agent health context"
```

---

### Task 3: 定义 Agent 行动模型和严格解析器

**Files:**
- Create: `today_eat_app/lib/models/agent_action.dart`
- Create: `today_eat_app/lib/services/agent_plan_parser.dart`
- Test: `today_eat_app/test/services/agent_plan_parser_test.dart`

**Interfaces:**
- Produces: `AgentActionCategory`、`AgentActionPriority`、`AgentActionStatus`、`AgentActionTarget`、`AgentActionDifficulty`、`AgentPlanSource`。
- Produces: `AgentAction`、`DailyAgentPlan`、`DailyAgentState`。
- Produces: `DailyAgentPlan parseAgentPlan(Map<String, dynamic> json, AgentPlanParseContext context)`。

- [ ] **Step 1: 写非法证据、枚举、医疗措辞和数量失败测试**

```dart
test('filters actions whose evidence is not allowed', () {
  expect(
    () => parseAgentPlan({
      'summary': '今天保持稳定',
      'actions': [{
        'category': 'rest',
        'priority': 'high',
        'title': '休息',
        'action': '卧床一天',
        'evidence': ['模型自己推断的依据'],
        'target': 'none',
      }],
    }, context),
    throwsFormatException,
  );
});

test('rejects unknown action target instead of defaulting', () {
  expect(
    () => parseAgentPlan(validJson(target: 'openUnknown'), context),
    throwsFormatException,
  );
});

test('keeps at most three valid actions', () {
  final plan = parseAgentPlan(fourValidActionsJson(), context);
  expect(plan.actions, hasLength(3));
});
```

- [ ] **Step 2: 运行测试并确认失败**

Run:

```powershell
flutter test test/services/agent_plan_parser_test.dart
```

Expected: FAIL，因为模型和解析器尚不存在。

- [ ] **Step 3: 实现枚举严格解析**

```dart
T parseEnum<T extends Enum>(
  List<T> values,
  Object? raw,
  String field,
) {
  final value = raw?.toString();
  for (final item in values) {
    if (item.name == value) return item;
  }
  throw FormatException('AI 返回非法 $field: $value');
}
```

不要使用 `orElse` 将未知类别映射为休息或未知目标映射为 `none`。

- [ ] **Step 4: 实现行动校验和计划解析**

```dart
final evidence = (raw['evidence'] as List? ?? const [])
    .map((value) => value.toString().trim())
    .where(context.allowedEvidence.contains)
    .toSet()
    .take(5)
    .toList();

if (evidence.isEmpty) {
  throw const FormatException('AI 行动缺少可信依据');
}
if (containsMedicalClaim('$title $action')) {
  throw const FormatException('AI 行动包含医疗诊断或治疗措辞');
}
```

`parseAgentPlan` 过滤空字符串，按 `high -> medium -> low` 排序，生成客户端稳定 ID，并将有效期固定为下一本地日零点。

- [ ] **Step 5: 运行测试**

Run:

```powershell
flutter test test/services/agent_plan_parser_test.dart
```

Expected: PASS，非法结果不产生可展示行动。

- [ ] **Step 6: 提交**

```powershell
git add today_eat_app/lib/models/agent_action.dart today_eat_app/lib/services/agent_plan_parser.dart today_eat_app/test/services/agent_plan_parser_test.dart
git commit -m "feat: validate evidence-backed agent actions"
```

---

### Task 4: 持久化每日计划、行动状态和反馈汇总

**Files:**
- Create: `today_eat_app/lib/services/agent_action_repository.dart`
- Modify: `today_eat_app/lib/services/database_service.dart`
- Test: `today_eat_app/test/services/agent_action_repository_test.dart`

**Interfaces:**
- Consumes: `DailyAgentPlan`、`AgentAction`。
- Produces: `Future<DailyAgentPlan?> AgentActionRepository.findPlan(String localDate)`。
- Produces: `Future<void> AgentActionRepository.replaceCurrentPlan(DailyAgentPlan plan)`。
- Produces: `Future<void> AgentActionRepository.updateAction(...)`。
- Produces: `Future<AgentFeedbackSummary> AgentActionRepository.summarizeFeedback(DateTime since)`。
- Produces: `Future<void> AgentActionRepository.markNeedsRefresh(String localDate)`。

- [ ] **Step 1: 写替换计划和状态转换失败测试**

```dart
test('replacing a plan preserves completed actions as history', () async {
  await repository.replaceCurrentPlan(firstPlan);
  await repository.updateAction(
    firstPlan.actions.first.clientActionId,
    status: AgentActionStatus.completed,
  );
  await repository.replaceCurrentPlan(secondPlan);

  final history = await repository.fetchActionsSince(DateTime(2026, 7, 25));
  expect(
    history.where((item) => item.status == AgentActionStatus.completed),
    hasLength(1),
  );
  expect((await repository.findPlan('2026-07-25'))!.actions, secondPlan.actions);
});

test('too hard feedback increments skipped and too hard counts', () async {
  await repository.replaceCurrentPlan(firstPlan);
  await repository.updateAction(
    firstPlan.actions.first.clientActionId,
    status: AgentActionStatus.skipped,
    difficulty: AgentActionDifficulty.tooHard,
  );

  final summary = await repository.summarizeFeedback(DateTime(2026, 7, 19));
  expect(summary.skipped, 1);
  expect(summary.tooHard, 1);
});
```

- [ ] **Step 2: 运行测试并确认失败**

Run:

```powershell
flutter test test/services/agent_action_repository_test.dart
```

Expected: FAIL，因为数据库适配尚不存在。

- [ ] **Step 3: 增加 DatabaseService CRUD**

新增：

```dart
Future<Map<String, Object?>?> fetchDailyAgentPlan(String localDate);
Future<List<Map<String, Object?>>> fetchAgentActionsForDate(String localDate);
Future<List<Map<String, Object?>>> fetchAgentActionsSince(String isoDateTime);
Future<void> replaceDailyAgentPlan(
  Map<String, Object?> plan,
  List<Map<String, Object?>> actions,
);
Future<int> updateAgentAction(
  String clientActionId,
  Map<String, Object?> values,
);
Future<int> markDailyAgentPlanNeedsRefresh(String localDate);
```

`replaceDailyAgentPlan` 使用事务：先将当天仍为 `pending` 的旧行动标记为 `expired`，再 upsert 计划元数据并插入新行动。已完成和已跳过行动保持不变。

- [ ] **Step 4: 实现 AgentActionRepository**

只允许状态转换：

```dart
const allowedTransitions = {
  AgentActionStatus.pending: {
    AgentActionStatus.completed,
    AgentActionStatus.skipped,
    AgentActionStatus.expired,
  },
  AgentActionStatus.completed: <AgentActionStatus>{},
  AgentActionStatus.skipped: <AgentActionStatus>{},
  AgentActionStatus.expired: <AgentActionStatus>{},
};
```

非法转换抛出 `StateError`；更新反馈时同步写入 `updated_at`。

- [ ] **Step 5: 运行测试**

Run:

```powershell
flutter test test/services/agent_action_repository_test.dart
```

Expected: PASS，历史反馈可统计，当前计划只包含当前版本行动。

- [ ] **Step 6: 提交**

```powershell
git add today_eat_app/lib/services/agent_action_repository.dart today_eat_app/lib/services/database_service.dart today_eat_app/test/services/agent_action_repository_test.dart
git commit -m "feat: persist daily agent plans and feedback"
```

---

### Task 5: 扩展 HealthAgentService 和服务端每日计划接口

**Files:**
- Modify: `today_eat_app/lib/services/health_agent_service.dart`
- Modify: `today_eat_app/lib/services/health_api_service.dart`
- Modify: `backend/main.py`
- Test: `today_eat_app/test/services/daily_agent_service_test.dart`
- Test: `backend/tests/test_daily_agent_api.py`

**Interfaces:**
- Consumes: `HealthContext`、`AgentPlanParseContext`。
- Produces: `Future<DailyAgentPlan> HealthAgentService.generateDailyPlan(...)`。
- Produces: `Future<Map<String, dynamic>> HealthApiService.generateDailyPlan(...)`。
- Produces: `POST /v1/ai/daily-plan`。

- [ ] **Step 1: 写客户端 Prompt 契约失败测试**

```dart
test('daily plan sends only de-identified context and allowed evidence', () async {
  await service.generateDailyPlan(
    context: sampleContext,
    dataFingerprint: 'fingerprint',
  );

  final payload = fakeLlm.lastUserPayload;
  expect(payload, contains('allowed_evidence'));
  expect(payload, isNot(contains('image_path')));
  expect(payload, isNot(contains('location')));
  expect(payload, isNot(contains('note')));
});
```

- [ ] **Step 2: 写后端鉴权和 evidence 失败测试**

```python
def test_daily_plan_requires_auth(client):
    response = client.post("/v1/ai/daily-plan", json=valid_daily_plan_request())
    assert response.status_code == 401

def test_daily_plan_rejects_evidence_outside_allowlist(
    client, token, fake_ai
):
    fake_ai.response = {
        "summary": "状态稳定",
        "actions": [{
            "category": "rest",
            "priority": "high",
            "title": "休息",
            "action": "今天减少负荷",
            "evidence": ["不存在的依据"],
            "target": "none",
        }],
    }
    response = client.post(
        "/v1/ai/daily-plan",
        headers={"Authorization": f"Bearer {token}"},
        json=valid_daily_plan_request(),
    )
    assert response.status_code == 502
```

- [ ] **Step 3: 运行测试并确认失败**

Run:

```powershell
flutter test test/services/daily_agent_service_test.dart
```

Run:

```powershell
python -m pytest backend/tests/test_daily_agent_api.py -q
```

Expected: Flutter 测试 FAIL，后端返回 404。

- [ ] **Step 4: 实现客户端每日计划方法**

```dart
Future<DailyAgentPlan> generateDailyPlan({
  required HealthContext context,
  required String dataFingerprint,
}) async {
  final json = _api.shouldUseServer
      ? await _api.generateDailyPlan(context: context)
      : await _llm.callLlm(
          systemPrompt: _dailyAgentPrompt,
          userPrompt: jsonEncode(context.toPromptJson()),
          temperature: 0.2,
        );
  return parseAgentPlan(
    json,
    AgentPlanParseContext(
      date: context.date,
      dataFingerprint: dataFingerprint,
      allowedEvidence: context.allowedEvidence.toSet(),
      source: AgentPlanSource.ai,
    ),
  );
}
```

系统 Prompt 固定要求最多三个行动、逐字引用依据、使用允许的 target、只输出 JSON、禁止医疗诊断。

- [ ] **Step 5: 实现 FastAPI 请求和响应校验**

新增 Pydantic 模型，限制：

- `allowed_evidence` 1 到 30 项，每项最多 120 字。
- `actions` 1 到 3 项。
- `title` 最多 40 字，`action` 最多 160 字。
- `category`、`priority`、`target` 使用 `Literal`。
- 模型输出 evidence 必须是请求白名单子集。

路由：

```python
@app.post("/v1/ai/daily-plan")
async def generate_daily_plan(
    request: DailyAgentPlanRequest,
    user: dict = Depends(_get_current_user),
) -> dict[str, Any]:
    body = build_daily_agent_body(request)
    result = await _request_structured_ai(body)
    validated = validate_daily_agent_result(
        result,
        set(request.allowed_evidence),
    )
    return {"success": True, "data": validated}
```

日志只保留用户 ID 哈希、端点、耗时和状态，不记录上下文正文。

- [ ] **Step 6: 运行客户端和后端测试**

Run:

```powershell
flutter test test/services/daily_agent_service_test.dart
python -m pytest backend/tests/test_daily_agent_api.py -q
```

Expected: PASS。

- [ ] **Step 7: 提交**

```powershell
git add today_eat_app/lib/services/health_agent_service.dart today_eat_app/lib/services/health_api_service.dart today_eat_app/test/services/daily_agent_service_test.dart backend/main.py backend/tests/test_daily_agent_api.py
git commit -m "feat: generate validated daily agent plans"
```

---

### Task 6: 编排缓存、重规划和本地降级行动

**Files:**
- Create: `today_eat_app/lib/services/daily_agent_repository.dart`
- Modify: `today_eat_app/lib/services/meal_repository.dart`
- Modify: `today_eat_app/lib/services/exercise_repository.dart`
- Modify: `today_eat_app/lib/services/health_profile_repository.dart`
- Test: `today_eat_app/test/services/daily_agent_repository_test.dart`

**Interfaces:**
- Consumes: 饮食、运动、恢复、健康档案、行动持久化和 `HealthAgentService`。
- Produces: `Future<DailyAgentState> load(DateTime date, {bool forceRefresh = false})`。
- Produces: `completeAction`、`skipAction`、`markNeedsRefresh`。
- Produces: `Future<void> Function()? onHealthDataChanged` 非阻塞失效回调参数。

- [ ] **Step 1: 写状态机失败测试**

```dart
test('same fingerprint returns cached plan without calling ai', () async {
  await actionRepository.replaceCurrentPlan(cachedPlan);

  final state = await repository.load(DateTime(2026, 7, 25));

  expect(state.status, DailyAgentStatus.cached);
  expect(fakeAgent.calls, 0);
});

test('ai failure returns stale plan after data changes', () async {
  await actionRepository.replaceCurrentPlan(cachedPlan);
  fakeMeals.add(newMeal);
  fakeAgent.error = LlmException('timeout');

  final state = await repository.load(DateTime(2026, 7, 25));

  expect(state.status, DailyAgentStatus.stale);
  expect(state.plan, isNotNull);
  expect(state.message, '数据已变化，当前展示上次计划。');
});

test('missing recovery returns local check-in action without ai', () async {
  fakeRecovery.value = null;

  final state = await repository.load(DateTime(2026, 7, 25));

  expect(state.status, DailyAgentStatus.localFallback);
  expect(state.primaryAction!.target, AgentActionTarget.recoveryCheckIn);
  expect(fakeAgent.calls, 0);
});
```

- [ ] **Step 2: 运行测试并确认失败**

Run:

```powershell
flutter test test/services/daily_agent_repository_test.dart
```

Expected: FAIL，因为编排仓库尚不存在。

- [ ] **Step 3: 实现加载流程**

加载顺序固定为：

```dart
final profile = await _profiles.load();
final meals = await _meals.fetchRecords();
final exercises = await _exercises.fetchRecords();
final recovery = await _recovery.findByDate(date);
final feedback = await _actions.summarizeFeedback(
  date.subtract(const Duration(days: 7)),
);
final context = _contexts.build(
  now: date,
  profile: profile,
  meals: meals,
  exercises: exercises,
  recovery: recovery,
  feedback: feedback,
);
final fingerprint = buildDailyAgentFingerprint(context);
```

同指纹且 `needsRefresh == false` 时返回缓存；不满足门槛时返回本地行动；AI 不可用时返回本地行动；AI 失败且有缓存时返回陈旧计划；AI 失败且无缓存时返回失败状态和本地行动。

- [ ] **Step 4: 实现反馈转换**

```dart
Future<void> completeAction(String clientActionId) =>
    _actions.updateAction(
      clientActionId,
      status: AgentActionStatus.completed,
    );

Future<void> skipAction(
  String clientActionId, {
  AgentActionDifficulty? difficulty,
  String? note,
}) async {
  await _actions.updateAction(
    clientActionId,
    status: AgentActionStatus.skipped,
    difficulty: difficulty,
    feedbackNote: note,
  );
  await markNeedsRefresh(_clock());
}
```

完成行动不立即重规划，只提升当前计划中的下一条 pending 行动。

- [ ] **Step 5: 将记录变化连接到非阻塞失效**

饮食、运动和健康档案保存成功后调用注入的 `Future<void> Function()? onHealthDataChanged`。回调只执行本地 `markNeedsRefresh`，不得调用网络，也不得阻塞保存 Future。

统一使用异步回调签名并在保存完成后触发：

```dart
final Future<void> Function()? onHealthDataChanged;

void notifyHealthDataChanged() {
  final callback = onHealthDataChanged;
  if (callback != null) {
    unawaited(callback());
  }
}
```

- [ ] **Step 6: 运行测试**

Run:

```powershell
flutter test test/services/daily_agent_repository_test.dart
```

Expected: PASS，缓存、陈旧计划、本地降级和反馈状态均可区分。

- [ ] **Step 7: 提交**

```powershell
git add today_eat_app/lib/services/daily_agent_repository.dart today_eat_app/lib/services/meal_repository.dart today_eat_app/lib/services/exercise_repository.dart today_eat_app/lib/services/health_profile_repository.dart today_eat_app/test/services/daily_agent_repository_test.dart
git commit -m "feat: orchestrate daily agent lifecycle"
```

---

### Task 7: 构建恢复打卡页和今日 Agent 工作台

**Files:**
- Create: `today_eat_app/lib/screens/recovery/recovery_check_in_screen.dart`
- Create: `today_eat_app/lib/widgets/agent_action_card.dart`
- Modify: `today_eat_app/lib/screens/today/today_screen.dart`
- Modify: `today_eat_app/lib/screens/home_shell.dart`
- Test: `today_eat_app/test/screens/recovery_check_in_screen_test.dart`
- Test: `today_eat_app/test/screens/today_agent_screen_test.dart`

**Interfaces:**
- Consumes: `RecoveryRepository`、`DailyAgentRepository`、`DailyAgentState`。
- Produces: 恢复量表、主行动、查看依据、执行入口、完成、跳过和太难交互。

- [ ] **Step 1: 写恢复表单和主行动失败测试**

```dart
testWidgets('recovery check-in requires all four ratings', (tester) async {
  await tester.pumpWidget(testApp(RecoveryCheckInScreen(
    repository: fakeRecovery,
    date: DateTime(2026, 7, 25),
  )));

  expect(tester.widget<FilledButton>(
    find.widgetWithText(FilledButton, '保存状态'),
  ).onPressed, isNull);
});

testWidgets('completing primary action promotes next pending action',
    (tester) async {
  await tester.pumpWidget(testApp(todayScreenWith(twoActionState)));
  expect(find.text('先完成恢复打卡'), findsOneWidget);

  await tester.tap(find.text('完成'));
  await tester.pump();

  expect(find.text('记录今天的第一餐'), findsOneWidget);
});
```

- [ ] **Step 2: 运行测试并确认失败**

Run:

```powershell
flutter test test/screens/recovery_check_in_screen_test.dart test/screens/today_agent_screen_test.dart
```

Expected: FAIL，因为新页面和组件尚不存在。

- [ ] **Step 3: 实现恢复打卡页**

四个量表均使用 `SegmentedButton<int>`，值为 1 到 5，标签包含两端语义：

- 睡眠：很差 -> 很好。
- 疲劳：轻松 -> 很疲劳。
- 酸痛：无 -> 明显。
- 精力：很低 -> 很充足。

保存前构建 `RecoveryCheckInDraft` 并调用 `validate()`；保存成功后 `Navigator.pop(context, true)`。

- [ ] **Step 4: 实现 AgentActionCard**

组件参数：

```dart
class AgentActionCard extends StatelessWidget {
  const AgentActionCard({
    super.key,
    required this.action,
    required this.source,
    required this.onOpenEvidence,
    required this.onExecute,
    required this.onComplete,
    required this.onSkip,
    required this.onTooHard,
  });
}
```

AI、本地和陈旧计划使用不同状态标签，但不使用不同页面结构。反馈按钮仅在 `pending` 时显示。

- [ ] **Step 5: 改造 TodayScreen**

`TodayScreen` 新增 `dailyAgentRepository` 和 `recoveryRepository` 参数。`_loadInitialData()` 并行读取饮食、运动和 Agent 状态；页面激活后仅在计划标记需刷新时调用仓库，避免每次底部导航切换都请求 AI。

主行动执行映射：

```dart
switch (action.target) {
  case AgentActionTarget.recordMeal:
    widget.onRecordMeal();
    break;
  case AgentActionTarget.recordExercise:
    await _recordExercise();
    break;
  case AgentActionTarget.decideMeal:
    await _openDecide(DecisionMode.healthContext);
    break;
  case AgentActionTarget.recoveryCheckIn:
    await _openRecoveryCheckIn();
    break;
  case AgentActionTarget.openHealth:
    widget.onOpenHealth();
    break;
  case AgentActionTarget.none:
    break;
}
```

- [ ] **Step 6: 在 HomeShell 装配依赖**

创建并持有：

- `RecoveryRepository`
- `HealthContextService`
- `AgentActionRepository`
- `DailyAgentRepository`

`dispose()` 时关闭恢复仓库流。继续复用当前 `MealRepository`、`ExerciseRepository`、`HealthAgentService` 和 `HealthProfileRepository`。

- [ ] **Step 7: 运行 Widget 测试**

Run:

```powershell
flutter test test/screens/recovery_check_in_screen_test.dart test/screens/today_agent_screen_test.dart test/widget_test.dart
```

Expected: PASS，原四个底部导航仍可达。

- [ ] **Step 8: 提交**

```powershell
git add today_eat_app/lib/screens/recovery/recovery_check_in_screen.dart today_eat_app/lib/widgets/agent_action_card.dart today_eat_app/lib/screens/today/today_screen.dart today_eat_app/lib/screens/home_shell.dart today_eat_app/test/screens/recovery_check_in_screen_test.dart today_eat_app/test/screens/today_agent_screen_test.dart today_eat_app/test/widget_test.dart
git commit -m "feat: turn today into an agent action workspace"
```

---

### Task 8: 将“吃什么”升级为健康场景决策

**Files:**
- Create: `today_eat_app/lib/models/contextual_meal_suggestion.dart`
- Create: `today_eat_app/lib/services/contextual_meal_service.dart`
- Modify: `today_eat_app/lib/screens/decide_screen.dart`
- Modify: `today_eat_app/lib/services/meal_repository.dart`
- Modify: `today_eat_app/lib/services/health_agent_service.dart`
- Test: `today_eat_app/test/services/contextual_meal_service_test.dart`
- Test: `today_eat_app/test/screens/decide_health_context_test.dart`

**Interfaces:**
- Extends: `DecisionMode` 增加 `healthContext`。
- Produces: `ContextualMealSuggestion`。
- Produces: `Future<ContextualMealSuggestion> ContextualMealService.suggest(HealthContext context)`。
- Consumes: 最近饮食候选和 `HealthAgentService.suggestMealForContext`。

- [ ] **Step 1: 写不伪造餐厅和默认模式失败测试**

```dart
test('contextual suggestion contains health evidence but no invented store',
    () async {
  final suggestion = await service.suggest(sampleContext);

  expect(suggestion.evidence, isNotEmpty);
  expect(suggestion.storeName, isNull);
  expect(sampleContext.allowedEvidence, contains(suggestion.evidence.first));
});

testWidgets('health context is the default decision mode', (tester) async {
  await tester.pumpWidget(testApp(decideScreen));
  expect(find.text('健康场景'), findsOneWidget);
  expect(find.text('根据今天的饮食、运动和恢复状态决定'), findsOneWidget);
});
```

- [ ] **Step 2: 运行测试并确认失败**

Run:

```powershell
flutter test test/services/contextual_meal_service_test.dart test/screens/decide_health_context_test.dart
```

Expected: FAIL，因为 `healthContext` 模式尚不存在。

- [ ] **Step 3: 实现场景饮食模型和本地降级**

```dart
class ContextualMealSuggestion {
  const ContextualMealSuggestion({
    required this.title,
    required this.reason,
    required this.evidence,
    required this.source,
    this.sourceRecord,
    this.storeName,
  });

  final String title;
  final String reason;
  final List<String> evidence;
  final AgentPlanSource source;
  final MealRecord? sourceRecord;
  final String? storeName;
}
```

本地降级只推荐组合类型，例如“包含蔬菜和蛋白质的一餐”，不生成具体餐厅。可从历史记录中选择匹配菜品作为 `sourceRecord`。

- [ ] **Step 4: 增加 AI 场景饮食契约**

AI 输出只包含 `title`、`reason`、`evidence` 和可选 `candidate_client_record_id`。证据必须来自上下文白名单，候选 ID 必须存在于本次传入的去标识候选集合。

- [ ] **Step 5: 改造 DecideScreen**

模式顺序固定为：

1. 健康场景。
2. 历史偏好。
3. 随机选择。

从今日主行动进入时直接选中 `healthContext`。健康场景卡突出“为什么适合现在”，地点、价格和评分不作为首要信息。

- [ ] **Step 6: 运行测试**

Run:

```powershell
flutter test test/services/contextual_meal_service_test.dart test/screens/decide_health_context_test.dart
```

Expected: PASS，AI 不可用时仍返回有来源标识的本地建议。

- [ ] **Step 7: 提交**

```powershell
git add today_eat_app/lib/models/contextual_meal_suggestion.dart today_eat_app/lib/services/contextual_meal_service.dart today_eat_app/lib/screens/decide_screen.dart today_eat_app/lib/services/meal_repository.dart today_eat_app/lib/services/health_agent_service.dart today_eat_app/test/services/contextual_meal_service_test.dart today_eat_app/test/screens/decide_health_context_test.dart
git commit -m "feat: make meal decisions health-context aware"
```

---

### Task 9: 增加行动历史、演示数据和比赛主流程

**Files:**
- Create: `today_eat_app/lib/screens/health/agent_history_screen.dart`
- Modify: `today_eat_app/lib/screens/health/health_hub_screen.dart`
- Modify: `today_eat_app/lib/services/demo_data_service.dart`
- Modify: `today_eat_app/assets/demo/demo_health_records.json`
- Modify: `docs/competition/创新点说明.md`
- Modify: `docs/competition/演示脚本.md`
- Test: `today_eat_app/test/screens/agent_history_screen_test.dart`
- Test: `today_eat_app/test/demo/agent_demo_fixture_test.dart`

**Interfaces:**
- Consumes: `AgentActionRepository.fetchActionsSince`。
- Produces: 七天完成、跳过、太难数量和行动列表。
- Produces: 可重复导入且不包含个人信息的 Agent 演示 fixture。

- [ ] **Step 1: 写历史统计和 fixture 失败测试**

```dart
testWidgets('shows seven day execution summary', (tester) async {
  await tester.pumpWidget(testApp(AgentHistoryScreen(
    repository: fakeActionsWithHistory,
  )));

  expect(find.text('完成 3'), findsOneWidget);
  expect(find.text('跳过 1'), findsOneWidget);
  expect(find.text('太难 1'), findsOneWidget);
});

test('agent demo fixture contains recovery and no sensitive fields', () async {
  final json = await loadFixture('assets/demo/demo_health_records.json');
  expect(json['recovery_check_ins'], isNotEmpty);
  final text = jsonEncode(json).toLowerCase();
  expect(text, isNot(contains('api_key')));
  expect(text, isNot(contains('token')));
  expect(text, isNot(contains('phone')));
});
```

- [ ] **Step 2: 运行测试并确认失败**

Run:

```powershell
flutter test test/screens/agent_history_screen_test.dart test/demo/agent_demo_fixture_test.dart
```

Expected: FAIL，因为历史页和恢复 fixture 尚不存在。

- [ ] **Step 3: 实现 AgentHistoryScreen**

页面只展示近七天：

- 完成数量和完成率。
- 跳过数量。
- 太难数量。
- 按更新时间倒序的行动列表。

不增加排行榜、社交分享或积分体系。

- [ ] **Step 4: 更新健康页入口**

在“综合健康分析”之后新增“Agent 行动记录”，描述为“查看近七天行动完成、跳过和难度反馈”。“饮食洞察工具”保持最后一个业务入口。

- [ ] **Step 5: 扩充演示数据**

fixture 增加最近两天恢复评分和三条行动历史。`DemoDataService.import()` 先按本地日期检查是否存在，再写入，重复导入不重复添加。

- [ ] **Step 6: 更新比赛材料**

演示主线改为：

```text
导入演示数据
-> 完成今日恢复打卡
-> Agent 生成一个主行动
-> 展开可信依据
-> 完成或反馈太难
-> 新增运动记录
-> 展示计划待刷新和调整
```

明确联网推荐、美食日记和价格统计不是主演示路径。

- [ ] **Step 7: 运行测试**

Run:

```powershell
flutter test test/screens/agent_history_screen_test.dart test/demo/agent_demo_fixture_test.dart
```

Expected: PASS。

- [ ] **Step 8: 提交**

```powershell
git add today_eat_app/lib/screens/health/agent_history_screen.dart today_eat_app/lib/screens/health/health_hub_screen.dart today_eat_app/lib/services/demo_data_service.dart today_eat_app/assets/demo/demo_health_records.json docs/competition/创新点说明.md docs/competition/演示脚本.md today_eat_app/test/screens/agent_history_screen_test.dart today_eat_app/test/demo/agent_demo_fixture_test.dart
git commit -m "feat: expose agent execution history and demo flow"
```

---

### Task 10: 全量回归、真机演示和文档收口

**Files:**
- Modify: `README.md`
- Modify: `today_eat_app/README.md`
- Modify: `docs/competition/隐私与AI边界.md`
- Test: existing and all new tests from Tasks 1-9

**Interfaces:**
- Produces: 可在 Android 真机执行的完整 Agent 演示版本。

- [ ] **Step 1: 更新项目定位和隐私边界**

README 首段使用：

```markdown
食动智衡是一款运动、饮食与恢复一体化的个人健康 Agent。
它通过多模态记录、确定性健康上下文、带依据的每日行动和用户反馈，
形成“感知 -> 决策 -> 行动 -> 调整”的持续闭环。
```

隐私文档补充恢复评分发送边界、备注不发送、每日计划日志脱敏和行动反馈本地保存。

- [ ] **Step 2: 运行格式化**

Run:

```powershell
dart format lib test
```

Expected: exit 0，格式化只涉及本次修改的 Dart 文件。

- [ ] **Step 3: 运行 Flutter 测试**

Run:

```powershell
flutter test
```

Expected: 全部测试 PASS，0 failures。

- [ ] **Step 4: 运行静态分析**

Run:

```powershell
flutter analyze
```

Expected: 0 errors。现有 info/warning 若不属于本次文件，单独记录但不借机重构无关代码。

- [ ] **Step 5: 运行后端测试**

Run:

```powershell
python -m pytest backend/tests -q
```

Expected: 全部测试 PASS。

- [ ] **Step 6: 构建调试 APK**

Run:

```powershell
flutter build apk --debug
```

Expected: exit 0，保留 Flutter 所需 `app-debug.apk`，同时生成现有品牌 APK 副本。

- [ ] **Step 7: 真机执行比赛主流程**

Run:

```powershell
flutter run -d AHHSUT5915000779
```

验证：

- 恢复打卡能够保存和更新。
- 今日页生成或展示主行动。
- 查看依据、完成、跳过和太难均能更新状态。
- 新增饮食或运动后计划显示待刷新。
- 健康场景“吃什么”不以餐厅和价格为主。
- 网络断开时旧计划和本地行动仍可查看。

- [ ] **Step 8: 提交**

```powershell
git add README.md today_eat_app/README.md docs/competition/隐私与AI边界.md
git commit -m "docs: describe the health agent action loop"
```

## Deferred Follow-up

周计划、系统通知和 Health Connect 不属于本计划。前三阶段稳定并完成比赛演示验收后，单独编写“周级健康 Agent 计划”设计与实施计划，复用本计划的 `HealthContext`、行动状态和反馈统计，不在当前任务中预埋通知依赖。
