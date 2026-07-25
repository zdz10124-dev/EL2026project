# 健康平台主信息架构迁移 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将底部导航迁移为“今日 / 记录 / 健康 / 我的”，统一饮食与运动入口，同时保证所有原功能可达。

**Architecture:** 先建立集中依赖装配和页面契约，再逐个创建一级页面，最后替换 `HomeShell`。旧页面保持功能组件，不在导航迁移阶段重写内部业务逻辑。

**Tech Stack:** Flutter Material、现有主题系统、MealRepository、ExerciseRepository、HealthAnalysisRepository。

## Global Constraints

- 依赖运动记录 MVP 和综合健康分析计划完成。
- 不安装环境；无法执行 Widget 测试时记录未执行。
- 不删除旧页面，不改变数据库 schema，不重写社区接口。
- 四个旧核心能力必须可达：吃什么、饮食日记、统计分析、联网推荐。

---

### Task 1: 集中应用依赖装配

**Files:**
- Create: `today_eat_app/lib/app/app_dependencies.dart`
- Modify: `today_eat_app/lib/main.dart`
- Modify: `today_eat_app/lib/screens/home_shell.dart`
- Test: `today_eat_app/test/app/app_dependencies_test.dart`

**Interfaces:**
- Produces: `AppDependencies.create()`、`initialize()`、`dispose()`。
- 暴露：meal、exercise、healthProfile、healthAnalysis、llm、healthAgent。

- [ ] **Step 1: 写生命周期失败测试**

```dart
test('initializes repositories once and disposes streams', () async {
  final dependencies = AppDependencies.testing(
    meals: fakeMeal,
    exercises: fakeExercise,
    healthProfile: fakeHealthProfile,
    healthAnalysis: fakeHealthAnalysis,
    llm: fakeLlm,
    healthAgent: fakeHealthAgent,
  );
  await dependencies.initialize();
  await dependencies.initialize();
  expect(fakeMeal.initializeCalls, 1);
  await dependencies.dispose();
  expect(fakeExercise.disposed, isTrue);
});
```

- [ ] **Step 2: 运行并确认失败**

Run: `cd today_eat_app && flutter test test/app/app_dependencies_test.dart`

Expected: FAIL。

- [ ] **Step 3: 实现依赖容器**

```dart
class AppDependencies {
  final MealRepository meals;
  final ExerciseRepository exercises;
  final HealthProfileRepository healthProfile;
  final HealthAnalysisRepository healthAnalysis;
  final LlmService llm;
  final HealthAgentService healthAgent;

  Future<void> initialize();
  Future<void> dispose();
}
```

`main.dart` 完成异步初始化后再构建 `HomeShell`；初始化失败显示可重试错误页，不创建半初始化页面。

- [ ] **Step 4: 运行测试并提交**

Run: `cd today_eat_app && flutter test test/app/app_dependencies_test.dart`

```bash
git add today_eat_app/lib/app/app_dependencies.dart today_eat_app/lib/main.dart today_eat_app/lib/screens/home_shell.dart today_eat_app/test/app/app_dependencies_test.dart
git commit -m "refactor: centralize app dependencies"
```

### Task 2: 建立今日页

**Files:**
- Create: `today_eat_app/lib/screens/today/today_screen.dart`
- Create: `today_eat_app/lib/models/today_summary.dart`
- Create: `today_eat_app/lib/services/today_summary_service.dart`
- Test: `today_eat_app/test/screens/today_screen_test.dart`
- Test: `today_eat_app/test/services/today_summary_service_test.dart`

**Interfaces:**
- Produces: `TodaySummary build(DateTime now, meals, exercises, healthState)`。
- 消费快捷回调：`onAddMeal`、`onAddExercise`、`onDecideMeal`。

- [ ] **Step 1: 写摘要和页面失败测试**

验证当天边界按本地零点计算；最高优先级建议优先 high，再按 diet/exercise/rest 稳定排序；无 AI 时仍展示记录计数和快捷操作。

- [ ] **Step 2: 运行并确认失败**

Run: `cd today_eat_app && flutter test test/services/today_summary_service_test.dart test/screens/today_screen_test.dart`

Expected: FAIL。

- [ ] **Step 3: 实现今日页**

页面顺序固定为日期/目标、今日建议主卡、饮食与运动摘要、两个快捷记录按钮、“今天吃什么”入口、最近记录。不得自动触发 AI 请求；分析由健康仓库缓存状态提供。

- [ ] **Step 4: 运行测试并提交**

Run: `cd today_eat_app && flutter test test/services/today_summary_service_test.dart test/screens/today_screen_test.dart`

```bash
git add today_eat_app/lib/screens/today today_eat_app/lib/models/today_summary.dart today_eat_app/lib/services/today_summary_service.dart today_eat_app/test/screens/today_screen_test.dart today_eat_app/test/services/today_summary_service_test.dart
git commit -m "feat: add daily health action dashboard"
```

### Task 3: 建立统一记录时间线

**Files:**
- Create: `today_eat_app/lib/models/health_timeline_item.dart`
- Create: `today_eat_app/lib/services/health_timeline_service.dart`
- Create: `today_eat_app/lib/screens/records/records_screen.dart`
- Create: `today_eat_app/lib/widgets/meal_record_card.dart`
- Test: `today_eat_app/test/services/health_timeline_service_test.dart`
- Test: `today_eat_app/test/screens/records_screen_test.dart`

**Interfaces:**
- Produces: `List<HealthTimelineItem> merge(meals, exercises)`。
- 筛选：`all | meals | exercises`。

- [ ] **Step 1: 写合并与页面失败测试**

```dart
test('merges meal and exercise records by event time', () {
  final items = service.merge([mealAt(hour: 12)], [exerciseAt(hour: 8)]);
  expect(items.map((e) => e.kind), [TimelineKind.meal, TimelineKind.exercise]);
});
```

Widget 测试点击浮动按钮后显示“记录饮食 / 记录运动”选择；筛选运动后不展示饮食卡。

- [ ] **Step 2: 运行并确认失败**

Run: `cd today_eat_app && flutter test test/services/health_timeline_service_test.dart test/screens/records_screen_test.dart`

Expected: FAIL。

- [ ] **Step 3: 实现时间线**

使用 sealed timeline item 适配旧 `MealRecord` 与新 `ExerciseRecord`，不创建重复数据库实体。提取旧 Capture 页面中的饮食卡为 `meal_record_card.dart`，保持编辑、删除和上传开关行为。

- [ ] **Step 4: 运行测试并提交**

Run: `cd today_eat_app && flutter test test/services/health_timeline_service_test.dart test/screens/records_screen_test.dart`

```bash
git add today_eat_app/lib/models/health_timeline_item.dart today_eat_app/lib/services/health_timeline_service.dart today_eat_app/lib/screens/records/records_screen.dart today_eat_app/lib/widgets/meal_record_card.dart today_eat_app/test/services/health_timeline_service_test.dart today_eat_app/test/screens/records_screen_test.dart
git commit -m "feat: unify meal and exercise timeline"
```

### Task 4: 建立健康工具页和我的页

**Files:**
- Create: `today_eat_app/lib/screens/health/health_hub_screen.dart`
- Create: `today_eat_app/lib/screens/profile/profile_screen.dart`
- Modify: `today_eat_app/lib/screens/insights_screen.dart`
- Modify: `today_eat_app/lib/screens/settings_screen.dart`
- Test: `today_eat_app/test/screens/health_hub_screen_test.dart`
- Test: `today_eat_app/test/screens/profile_screen_test.dart`

**Interfaces:**
- 健康页入口：综合健康、营养、运动记录/统计、偏好、日记、统计、社区。
- 我的页入口：健康目标、AI 配置、昵称头像、主题、数据管理、关于。

- [ ] **Step 1: 写可达性失败测试**

测试每个原有工具标题均存在并可 push 到对应页面；AI 未配置只禁用需要 AI 的动作，不禁用确定性统计。

- [ ] **Step 2: 运行并确认失败**

Run: `cd today_eat_app && flutter test test/screens/health_hub_screen_test.dart test/screens/profile_screen_test.dart`

Expected: FAIL。

- [ ] **Step 3: 实现两个一级页**

将 `InsightsScreen` 的工具网格提取为健康页组件，将 `SettingsScreen` 作为我的页的二级内容或拆出的设置组。避免复制旧页面逻辑。

- [ ] **Step 4: 运行测试并提交**

Run: `cd today_eat_app && flutter test test/screens/health_hub_screen_test.dart test/screens/profile_screen_test.dart`

```bash
git add today_eat_app/lib/screens/health/health_hub_screen.dart today_eat_app/lib/screens/profile/profile_screen.dart today_eat_app/lib/screens/insights_screen.dart today_eat_app/lib/screens/settings_screen.dart today_eat_app/test/screens/health_hub_screen_test.dart today_eat_app/test/screens/profile_screen_test.dart
git commit -m "refactor: organize health and profile tools"
```

### Task 5: 切换 HomeShell 导航并验证旧功能

**Files:**
- Modify: `today_eat_app/lib/screens/home_shell.dart`
- Modify: `today_eat_app/lib/models/ui_config.dart`
- Modify: `today_eat_app/lib/services/ui_config_loader.dart`
- Modify: `today_eat_app/assets/config/ui_config.xml`
- Modify: `today_eat_app/test/widget_test.dart`
- Create: `today_eat_app/test/screens/home_shell_navigation_test.dart`

**Interfaces:**
- 四个 destination：today、records、health、profile。
- `IndexedStack` 保持各页滚动和筛选状态。

- [ ] **Step 1: 写导航回归失败测试**

```dart
testWidgets('shows four health platform destinations', (tester) async {
  await tester.pumpWidget(testApp(homeShell));
  expect(find.text('今日'), findsOneWidget);
  expect(find.text('记录'), findsOneWidget);
  expect(find.text('健康'), findsOneWidget);
  expect(find.text('我的'), findsOneWidget);
});
```

补充用例验证从新导航可进入吃什么、饮食编辑器、日记、统计、社区推荐和 AI 设置。

- [ ] **Step 2: 运行并确认失败**

Run: `cd today_eat_app && flutter test test/widget_test.dart test/screens/home_shell_navigation_test.dart`

Expected: FAIL，仍显示旧四导航。

- [ ] **Step 3: 替换导航和 XML 文案**

更新 `PagesConfig` 为 `todayTab`、`recordTab`、`healthTab`、`profileTab`；loader 对旧 XML 标签保留默认值兼容，避免配置缺失导致启动失败。

- [ ] **Step 4: 运行阶段验证**

Run: `cd today_eat_app && flutter test`

Run: `cd today_eat_app && flutter analyze`

Expected: 全部 PASS，无 analyzer error；若环境不可用，记录未执行命令和远程验证要求。

- [ ] **Step 5: 提交**

```bash
git add today_eat_app/lib/screens/home_shell.dart today_eat_app/lib/models/ui_config.dart today_eat_app/lib/services/ui_config_loader.dart today_eat_app/assets/config/ui_config.xml today_eat_app/test/widget_test.dart today_eat_app/test/screens/home_shell_navigation_test.dart
git commit -m "feat: migrate app to health platform navigation"
```
