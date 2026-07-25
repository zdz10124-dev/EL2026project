# 综合健康分析 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将饮食与运动记录聚合为可解释的 7/30 天健康指标，并生成带依据、可缓存、可降级的饮食/运动/休息建议。

**Architecture:** 本地 `HealthMetricsService` 负责可验证计算，`HealthAgentService` 只解释结构化摘要，`HealthAnalysisRepository` 负责指纹、缓存与陈旧状态。页面不直接拼 Prompt 或读写 SharedPreferences/SQLite。

**Tech Stack:** Flutter、Dart、SharedPreferences、sqflite、crypto、现有 LLM 传输层。

## Global Constraints

- 依赖运动记录 MVP 已完成。
- 不配置或升级本机环境；缺少依赖时记录待远程执行的命令。
- 不基于缺失身体数据生成精确热量缺口、最大心率百分比或体重预测。
- 每条 AI 建议必须有至少一条 `evidence`；无依据的建议在解析阶段拒绝。

---

### Task 1: 建立健康档案模型和仓库

**Files:**
- Create: `today_eat_app/lib/models/health_profile.dart`
- Create: `today_eat_app/lib/services/health_profile_repository.dart`
- Test: `today_eat_app/test/services/health_profile_repository_test.dart`

**Interfaces:**
- Produces: `HealthGoal`、`HealthProfile`。
- Produces: `Future<HealthProfile> load()`、`Future<void> save(HealthProfile profile)`。

- [ ] **Step 1: 写失败测试**

```dart
test('loads safe defaults and persists optional fields', () async {
  final repository = HealthProfileRepository(store: fakeStore);
  expect((await repository.load()).goal, HealthGoal.generalHealth);
  await repository.save(const HealthProfile(
    goal: HealthGoal.endurance,
    preferredActivities: {ActivityType.running},
    availableDaysPerWeek: 3,
  ));
  expect((await repository.load()).availableDaysPerWeek, 3);
});
```

- [ ] **Step 2: 运行并确认失败**

Run: `cd today_eat_app && flutter test test/services/health_profile_repository_test.dart`

Expected: FAIL。

- [ ] **Step 3: 实现模型和 SharedPreferences 适配器**

```dart
enum HealthGoal { generalHealth, fatLoss, endurance, habit, performance }

class HealthProfile {
  const HealthProfile({
    this.goal = HealthGoal.generalHealth,
    this.preferredActivities = const {},
    this.availableDaysPerWeek,
    this.maxSessionMinutes,
    this.birthYear,
    this.heightCm,
    this.weightKg,
  });
  // fields + toJson/fromJson/copyWith
}
```

仓库将整个对象编码为一个版本化 JSON 键 `health_profile_v1`。解析失败时返回默认对象，不覆盖原值，方便诊断。

- [ ] **Step 4: 运行测试并提交**

Run: `cd today_eat_app && flutter test test/services/health_profile_repository_test.dart`

```bash
git add today_eat_app/lib/models/health_profile.dart today_eat_app/lib/services/health_profile_repository.dart today_eat_app/test/services/health_profile_repository_test.dart
git commit -m "feat: persist optional health profile"
```

### Task 2: 定义确定性指标并实现计算服务

**Files:**
- Create: `today_eat_app/lib/models/health_metrics.dart`
- Create: `today_eat_app/lib/services/health_metrics_service.dart`
- Test: `today_eat_app/test/services/health_metrics_service_test.dart`

**Interfaces:**
- Produces: `HealthMetrics calculate({required DateTime start, required DateTime end, required List<MealRecord> meals, required List<ExerciseRecord> exercises})`。
- Produces: `DataQuality` 和去标识 `toPromptJson()`。

- [ ] **Step 1: 写边界测试**

```dart
test('calculates exercise totals and post-workout meal coverage', () {
  final metrics = service.calculate(
    start: day,
    end: day.add(const Duration(days: 7)),
    meals: [mealAt(day.add(const Duration(hours: 10)))],
    exercises: [exerciseAt(day.add(const Duration(hours: 8)))],
  );
  expect(metrics.exerciseCount, 1);
  expect(metrics.totalExerciseSeconds, 1800);
  expect(metrics.postWorkoutMealCoverage, 1.0);
});

test('does not infer intensity when heart rate and rpe are absent', () {
  final metrics = service.calculate(
    start: day,
    end: day.add(const Duration(days: 7)),
    meals: const [],
    exercises: [exerciseAt(day.add(const Duration(hours: 8)))],
  );
  expect(metrics.highLoadDays, isEmpty);
  expect(metrics.dataQuality.missingFields, contains('exercise_intensity'));
});
```

- [ ] **Step 2: 运行并确认失败**

Run: `cd today_eat_app && flutter test test/services/health_metrics_service_test.dart`

Expected: FAIL。

- [ ] **Step 3: 实现纯函数指标**

计算项目固定为：饮食次数、活跃饮食天数、餐次时间分布、常见食材/饮品；运动次数、时长、距离、平均 RPE、RPE `>= 7` 的高负荷天数；运动结束后四小时内饮食覆盖率；输入数据完整度。

不得通过菜名猜测卡路里，不得通过年龄缺省值推算最大心率。

- [ ] **Step 4: 运行测试并提交**

Run: `cd today_eat_app && flutter test test/services/health_metrics_service_test.dart`

```bash
git add today_eat_app/lib/models/health_metrics.dart today_eat_app/lib/services/health_metrics_service.dart today_eat_app/test/services/health_metrics_service_test.dart
git commit -m "feat: calculate deterministic health metrics"
```

### Task 3: 定义综合分析输出和严格解析

**Files:**
- Create: `today_eat_app/lib/models/integrated_health_analysis.dart`
- Create: `today_eat_app/lib/services/health_analysis_parser.dart`
- Test: `today_eat_app/test/services/health_analysis_parser_test.dart`

**Interfaces:**
- Produces: `AnalysisPeriod { sevenDays, thirtyDays }`、`RecommendationCategory`、`RecommendationPriority`、`HealthRecommendation`、`IntegratedHealthAnalysis`。
- Produces: `IntegratedHealthAnalysis parseHealthAnalysis(Map<String, dynamic> json, AnalysisContext context)`。

- [ ] **Step 1: 写严格解析失败测试**

```dart
test('rejects recommendations without evidence', () {
  expect(
    () => parseHealthAnalysis({
      'overview': '总体稳定',
      'recommendations': [
        {'category': 'rest', 'priority': 'high', 'title': '休息', 'action': '今天休息', 'evidence': []}
      ],
      'risk_alerts': [],
    }, context),
    throwsFormatException,
  );
});
```

- [ ] **Step 2: 运行并确认失败**

Run: `cd today_eat_app && flutter test test/services/health_analysis_parser_test.dart`

Expected: FAIL。

- [ ] **Step 3: 实现模型和解析器**

```dart
enum AnalysisPeriod { sevenDays, thirtyDays }
enum RecommendationCategory { diet, exercise, rest }
enum RecommendationPriority { low, medium, high }
```

解析器校验类别、优先级、非空标题/行动/evidence，并由应用注入统一免责声明。`validUntil` 缺失时使用分析周期结束后一天，不接受模型返回的医疗诊断词作为 `riskAlerts`。

- [ ] **Step 4: 运行测试并提交**

Run: `cd today_eat_app && flutter test test/services/health_analysis_parser_test.dart`

```bash
git add today_eat_app/lib/models/integrated_health_analysis.dart today_eat_app/lib/services/health_analysis_parser.dart today_eat_app/test/services/health_analysis_parser_test.dart
git commit -m "feat: validate integrated health recommendations"
```

### Task 4: 增加分析缓存表和数据指纹

**Files:**
- Modify: `today_eat_app/pubspec.yaml`
- Modify: `today_eat_app/lib/services/database_service.dart`
- Create: `today_eat_app/lib/services/health_data_fingerprint.dart`
- Test: `today_eat_app/test/services/health_data_fingerprint_test.dart`
- Test: `today_eat_app/test/services/database_service_health_cache_test.dart`

**Interfaces:**
- Produces: `String buildHealthDataFingerprint({required AnalysisPeriod period, required List<MealRecord> meals, required List<ExerciseRecord> exercises, required HealthProfile profile})`。
- Produces: `saveHealthAnalysisCache`、`fetchHealthAnalysisCache(periodKey)`。

- [ ] **Step 1: 写指纹和缓存失败测试**

验证相同记录不同列表顺序得到相同 SHA-256；任一记录 `updatedAt` 或内容变化必须得到不同指纹。缓存按 `period_key` 保存 `fingerprint`、`content_json`、`generated_at`。

- [ ] **Step 2: 运行并确认失败**

Run: `cd today_eat_app && flutter test test/services/health_data_fingerprint_test.dart test/services/database_service_health_cache_test.dart`

Expected: FAIL。若 `crypto` 不在锁文件中，不自动下载；只将 `crypto: ^3.0.6` 写入计划内变更并记录待远程 `flutter pub get`。

- [ ] **Step 3: 数据库版本升至 7 并创建缓存表**

```sql
CREATE TABLE health_analysis_cache(
  period_key TEXT PRIMARY KEY,
  data_fingerprint TEXT NOT NULL,
  content_json TEXT NOT NULL,
  generated_at TEXT NOT NULL
)
```

指纹输入只包含排序后的记录稳定 ID、`updatedAt` 和参与指标的字段，不包含本地图片绝对路径。

- [ ] **Step 4: 运行测试并提交**

Run: `cd today_eat_app && flutter test test/services/health_data_fingerprint_test.dart test/services/database_service_health_cache_test.dart`

```bash
git add today_eat_app/pubspec.yaml today_eat_app/lib/services/database_service.dart today_eat_app/lib/services/health_data_fingerprint.dart today_eat_app/test/services/health_data_fingerprint_test.dart today_eat_app/test/services/database_service_health_cache_test.dart
git commit -m "feat: cache health analysis by data fingerprint"
```

### Task 5: 实现综合分析 Agent

**Files:**
- Modify: `today_eat_app/lib/services/health_agent_service.dart`
- Test: `today_eat_app/test/services/integrated_health_agent_test.dart`

**Interfaces:**
- Produces: `Future<IntegratedHealthAnalysis> analyzeIntegratedHealth({required HealthProfile profile, required HealthMetrics metrics, required AnalysisContext context})`。

- [ ] **Step 1: 写 Prompt 契约测试**

fake LLM 捕获 messages，验证请求只包含 `profile`、`metrics.toPromptJson()`、周期和免责声明约束，不包含用户昵称、位置、图片路径或数据库 ID。

- [ ] **Step 2: 运行并确认失败**

Run: `cd today_eat_app && flutter test test/services/integrated_health_agent_test.dart`

Expected: FAIL。

- [ ] **Step 3: 实现 Agent**

系统 Prompt 要求只引用输入 evidence key；建议 schema：

```json
{
  "overview": "string",
  "recommendations": [
    {
      "category": "diet|exercise|rest",
      "priority": "low|medium|high",
      "title": "string",
      "action": "string",
      "evidence": ["metric_key: readable value"]
    }
  ],
  "risk_alerts": []
}
```

最多返回六条建议；数据质量低时必须在 overview 中说明限制。

- [ ] **Step 4: 运行测试并提交**

Run: `cd today_eat_app && flutter test test/services/integrated_health_agent_test.dart`

```bash
git add today_eat_app/lib/services/health_agent_service.dart today_eat_app/test/services/integrated_health_agent_test.dart
git commit -m "feat: generate evidence-backed health advice"
```

### Task 6: 编排缓存、指标和 AI 状态

**Files:**
- Create: `today_eat_app/lib/services/health_analysis_repository.dart`
- Test: `today_eat_app/test/services/health_analysis_repository_test.dart`

**Interfaces:**
- Produces: `Future<HealthAnalysisState> load(AnalysisPeriod period, {bool forceRefresh = false})`。
- 状态：`insufficientData`、`aiUnavailable`、`fresh`、`cached`、`staleCache`、`failure`。

- [ ] **Step 1: 写状态机测试**

测试同指纹命中不调用 AI；不同指纹调用 AI；AI 失败且存在旧缓存返回 `staleCache`；无 AI 时仍返回 metrics。

- [ ] **Step 2: 运行并确认失败**

Run: `cd today_eat_app && flutter test test/services/health_analysis_repository_test.dart`

Expected: FAIL。

- [ ] **Step 3: 实现仓库**

最小数据门槛：周期内至少一条饮食或运动记录即可显示 metrics；至少两天记录才允许调用 AI。`forceRefresh` 跳过同指纹缓存，但成功后覆盖当前周期缓存。

- [ ] **Step 4: 运行测试并提交**

Run: `cd today_eat_app && flutter test test/services/health_analysis_repository_test.dart`

```bash
git add today_eat_app/lib/services/health_analysis_repository.dart today_eat_app/test/services/health_analysis_repository_test.dart
git commit -m "feat: orchestrate health analysis lifecycle"
```

### Task 7: 构建综合健康页面和健康档案编辑页

**Files:**
- Create: `today_eat_app/lib/screens/health/integrated_health_screen.dart`
- Create: `today_eat_app/lib/screens/health/health_profile_screen.dart`
- Create: `today_eat_app/lib/widgets/health_recommendation_card.dart`
- Modify: `today_eat_app/lib/screens/insights_screen.dart`
- Modify: `today_eat_app/lib/screens/settings_screen.dart`
- Test: `today_eat_app/test/screens/integrated_health_screen_test.dart`
- Test: `today_eat_app/test/screens/health_profile_screen_test.dart`

**Interfaces:**
- Consumes: `HealthAnalysisRepository`、`HealthProfileRepository`。
- Produces: 7/30 天切换、建议依据展开、刷新和陈旧缓存标记。

- [ ] **Step 1: 写页面状态测试**

```dart
testWidgets('shows stale cache with explicit warning', (tester) async {
  await tester.pumpWidget(testApp(screenWith(
    HealthAnalysisState.staleCache(
      metrics: sampleMetrics,
      analysis: sampleAnalysis,
      currentFingerprint: 'new',
      cachedFingerprint: 'old',
    ),
  )));
  expect(find.text('数据已变化，当前展示上次分析'), findsOneWidget);
  expect(find.text('查看依据'), findsWidgets);
});
```

- [ ] **Step 2: 运行并确认失败**

Run: `cd today_eat_app && flutter test test/screens/integrated_health_screen_test.dart test/screens/health_profile_screen_test.dart`

Expected: FAIL。

- [ ] **Step 3: 实现页面并接入临时入口**

洞察页新增“综合健康”卡；设置页新增“健康目标”入口。页面必须分别渲染无数据、AI 未配置、加载、fresh、cached、staleCache 和 failure，不使用单一 loading bool 混合状态。

- [ ] **Step 4: 运行阶段验证**

Run: `cd today_eat_app && flutter test test/services/health_* test/services/integrated_health_agent_test.dart test/screens/integrated_health_screen_test.dart test/screens/health_profile_screen_test.dart`

Run: `cd today_eat_app && flutter analyze`

Expected: PASS；环境不可用时记录未执行。

- [ ] **Step 5: 提交**

```bash
git add today_eat_app/lib/screens/health today_eat_app/lib/widgets/health_recommendation_card.dart today_eat_app/lib/screens/insights_screen.dart today_eat_app/lib/screens/settings_screen.dart today_eat_app/test/screens/integrated_health_screen_test.dart today_eat_app/test/screens/health_profile_screen_test.dart
git commit -m "feat: present integrated health insights"
```
