# 运动记录 MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在不破坏现有饮食功能的前提下，交付运动记录的手动录入、图片 AI 识别草稿、SQLite 持久化和独立记录列表。

**Architecture:** 新建独立的运动模型、仓库和页面；复用现有图片选择与 `LlmService` 传输层，但不让运动逻辑进入 `MealRecord` 或 `MealRepository`。先从现有洞察页提供临时入口，主导航统一迁移留到第三阶段。

**Tech Stack:** Flutter、Dart、sqflite、image_picker、path_provider、现有 `LlmService`。

## Global Constraints

- 只在 `ftcutter` 或 `codex/*` 分支工作；开始前运行 `git branch --show-current`。
- 不安装或升级本地环境；测试命令不可用时记录为“未执行”。
- 保留 `meal_records` 表和所有现有饮食路径。
- 运动记录最低必填为运动类型、开始时间和正数时长。
- AI 图片最多四张，识别结果只填入草稿，不直接写数据库。

---

### Task 1: 建立统一 AI JSON 响应解析

**Files:**
- Create: `today_eat_app/lib/services/llm_json_parser.dart`
- Modify: `today_eat_app/lib/services/llm_service.dart`
- Test: `today_eat_app/test/services/llm_json_parser_test.dart`

**Interfaces:**
- Produces: `Map<String, dynamic> parseLlmJsonObject(String content)`。
- Consumes: OpenAI 兼容响应中的 `choices[0].message.content` 字符串。

- [ ] **Step 1: 写失败测试**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:today_eat_app/services/llm_json_parser.dart';

void main() {
  test('parses plain and fenced JSON objects', () {
    expect(parseLlmJsonObject('{"value":1}')['value'], 1);
    expect(
      parseLlmJsonObject('```json\n{"value":2}\n```')['value'],
      2,
    );
  });

  test('rejects empty or non-object responses', () {
    expect(() => parseLlmJsonObject(''), throwsFormatException);
    expect(() => parseLlmJsonObject('[1,2]'), throwsFormatException);
  });
}
```

- [ ] **Step 2: 运行测试并确认失败**

Run: `cd today_eat_app && flutter test test/services/llm_json_parser_test.dart`

Expected: FAIL，提示 `llm_json_parser.dart` 或 `parseLlmJsonObject` 不存在。若 Flutter 不可用，记录命令和原因，不安装环境。

- [ ] **Step 3: 实现最小解析器**

```dart
import 'dart:convert';

Map<String, dynamic> parseLlmJsonObject(String content) {
  var normalized = content.trim();
  if (normalized.startsWith('```')) {
    normalized = normalized
        .replaceFirst(RegExp(r'^```(?:json)?\s*', caseSensitive: false), '')
        .replaceFirst(RegExp(r'\s*```$'), '')
        .trim();
  }
  if (normalized.isEmpty) {
    throw const FormatException('LLM returned empty content');
  }
  final decoded = jsonDecode(normalized);
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('LLM response must be a JSON object');
  }
  return decoded;
}
```

将 `LlmService._parseResponse` 和 `_callServerChat` 中直接 `jsonDecode(content)` 的位置统一改为该函数；保留 HTTP 状态与空响应检查。

- [ ] **Step 4: 运行测试和静态检查**

Run: `cd today_eat_app && flutter test test/services/llm_json_parser_test.dart`

Run: `cd today_eat_app && flutter analyze lib/services/llm_service.dart lib/services/llm_json_parser.dart`

Expected: PASS，且无 analyzer error；环境不可用时只记录未执行。

- [ ] **Step 5: 提交**

```bash
git add today_eat_app/lib/services/llm_json_parser.dart today_eat_app/lib/services/llm_service.dart today_eat_app/test/services/llm_json_parser_test.dart
git commit -m "refactor: centralize structured llm parsing"
```

### Task 2: 定义运动记录、草稿和校验规则

**Files:**
- Create: `today_eat_app/lib/models/exercise_record.dart`
- Create: `today_eat_app/lib/models/exercise_draft.dart`
- Create: `today_eat_app/lib/services/exercise_validator.dart`
- Test: `today_eat_app/test/models/exercise_record_test.dart`
- Test: `today_eat_app/test/services/exercise_validator_test.dart`

**Interfaces:**
- Produces: `ActivityType`、`ExerciseSource`、`ExerciseRecord`、`ExerciseDraft`。
- Produces: `List<String> validateExerciseDraft(ExerciseDraft draft)`。

- [ ] **Step 1: 写模型和校验失败测试**

```dart
test('round trips an exercise record map', () {
  final record = ExerciseRecord(
    id: 3,
    clientRecordId: 'exercise_1',
    activityType: ActivityType.running,
    startedAt: DateTime.utc(2026, 7, 18, 8),
    durationSeconds: 1800,
    distanceMeters: 5000,
    averageHeartRateBpm: 150,
    peakHeartRateBpm: 175,
    imagePaths: const ['a.jpg'],
    source: ExerciseSource.manual,
    createdAt: DateTime.utc(2026, 7, 18, 9),
    updatedAt: DateTime.utc(2026, 7, 18, 9),
  );
  expect(ExerciseRecord.fromMap(record.toMap()).clientRecordId, 'exercise_1');
});

test('rejects invalid duration and heart-rate ordering', () {
  final draft = ExerciseDraft.empty().copyWith(
    durationSeconds: 0,
    averageHeartRateBpm: 180,
    peakHeartRateBpm: 160,
  );
  expect(validateExerciseDraft(draft), containsAll(<String>[
    '运动时长必须大于 0',
    '峰值心率不能低于平均心率',
  ]));
});
```

- [ ] **Step 2: 运行测试并确认失败**

Run: `cd today_eat_app && flutter test test/models/exercise_record_test.dart test/services/exercise_validator_test.dart`

Expected: FAIL，提示模型不存在。

- [ ] **Step 3: 实现完整公开类型**

`ExerciseRecord` 必须提供 `toMap`、`fromMap`、`copyWith`；`imagePaths` 使用 JSON 字符串存储，禁止沿用饮食记录的逗号拼接，避免路径中逗号导致损坏。

```dart
enum ActivityType { running, swimming, cycling, walking, other }
enum ExerciseSource { manual, aiImage }

class ExerciseDraft {
  const ExerciseDraft({
    required this.activityType,
    required this.startedAt,
    required this.durationSeconds,
    this.distanceMeters,
    this.averageHeartRateBpm,
    this.peakHeartRateBpm,
    this.caloriesKcal,
    this.rpe,
    this.note,
    this.detail = const {},
    this.imagePaths = const [],
    this.source = ExerciseSource.manual,
  });

  final ActivityType activityType;
  final DateTime startedAt;
  final int durationSeconds;
  final int? distanceMeters;
  final int? averageHeartRateBpm;
  final int? peakHeartRateBpm;
  final int? caloriesKcal;
  final int? rpe;
  final String? note;
  final Map<String, Object?> detail;
  final List<String> imagePaths;
  final ExerciseSource source;
}
```

校验范围：时长 `> 0`；距离、热量非负；心率 `30..230`；RPE `1..10`；峰值心率不得低于平均心率。

- [ ] **Step 4: 运行模型测试**

Run: `cd today_eat_app && flutter test test/models/exercise_record_test.dart test/services/exercise_validator_test.dart`

Expected: PASS。

- [ ] **Step 5: 提交**

```bash
git add today_eat_app/lib/models/exercise_record.dart today_eat_app/lib/models/exercise_draft.dart today_eat_app/lib/services/exercise_validator.dart today_eat_app/test/models/exercise_record_test.dart today_eat_app/test/services/exercise_validator_test.dart
git commit -m "feat: add exercise record domain model"
```

### Task 3: 增加 SQLite 迁移和运动 CRUD

**Files:**
- Modify: `today_eat_app/lib/services/database_service.dart`
- Test: `today_eat_app/test/services/database_service_exercise_test.dart`

**Interfaces:**
- Produces: `insertExerciseRecord`、`updateExerciseRecord`、`deleteExerciseRecord`、`fetchExerciseRecords`、`fetchExerciseRecordById`。
- Consumes: `ExerciseRecord.toMap/fromMap`。

- [ ] **Step 1: 写失败测试**

测试必须覆盖全新建库、当前数据库版本升级、CRUD 排序和删除不影响 `meal_records`。测试通过 `DatabaseService(databaseFactory: testFactory, databasePath: inMemoryDatabasePath)` 注入测试数据库；先调整构造函数以支持注入，生产默认仍使用 `sqflite.databaseFactory`。

```dart
test('exercise CRUD does not alter meal rows', () async {
  final service = DatabaseService.forTesting(databaseFactory: factory);
  final id = await service.insertExerciseRecord(sampleExercise());
  expect((await service.fetchExerciseRecordById(id))!.durationSeconds, 1800);
  expect(await service.fetchExerciseRecords(), hasLength(1));
  await service.deleteExerciseRecord(id);
  expect(await service.fetchExerciseRecords(), isEmpty);
});
```

- [ ] **Step 2: 运行数据库测试并确认失败**

Run: `cd today_eat_app && flutter test test/services/database_service_exercise_test.dart`

Expected: FAIL，提示运动 CRUD 不存在。若测试数据库依赖未在锁文件中，不执行 `flutter pub add`；先记录所需 dev dependency，由有环境设备统一安装。

- [ ] **Step 3: 将数据库版本由 5 升至 6 并创建表**

```sql
CREATE TABLE exercise_records(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  client_record_id TEXT NOT NULL UNIQUE,
  activity_type TEXT NOT NULL,
  started_at TEXT NOT NULL,
  duration_seconds INTEGER NOT NULL,
  distance_meters INTEGER,
  average_heart_rate_bpm INTEGER,
  peak_heart_rate_bpm INTEGER,
  calories_kcal INTEGER,
  rpe INTEGER,
  note TEXT,
  detail_json TEXT NOT NULL DEFAULT '{}',
  image_paths_json TEXT NOT NULL DEFAULT '[]',
  source TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
)
```

在 `_onCreate` 与 `oldVersion < 6` 迁移路径调用同一个幂等 `_createExerciseRecordsTable`。添加 `started_at DESC` 索引。

- [ ] **Step 4: 实现 CRUD 并运行测试**

Run: `cd today_eat_app && flutter test test/services/database_service_exercise_test.dart`

Expected: PASS，运动列表按 `started_at DESC` 返回。

- [ ] **Step 5: 提交**

```bash
git add today_eat_app/lib/services/database_service.dart today_eat_app/test/services/database_service_exercise_test.dart
git commit -m "feat: persist exercise records locally"
```

### Task 4: 实现 ExerciseRepository

**Files:**
- Create: `today_eat_app/lib/services/exercise_repository.dart`
- Test: `today_eat_app/test/services/exercise_repository_test.dart`

**Interfaces:**
- Produces: `Stream<List<ExerciseRecord>> get recordsStream`。
- Produces: `initialize`、`saveDraft`、`updateRecord`、`deleteRecord`、`captureFromCamera`、`pickFromGallery`、`pickMultiFromGallery`。
- Consumes: `DatabaseService`、`ImagePicker`、`ExerciseDraft`。

- [ ] **Step 1: 写仓库失败测试**

使用 fake database gateway 和 fake image storage，验证“数据库成功后立即发布记录流”和“删除记录后删除其私有图片”。不要在单元测试访问真实相册或文件系统。

```dart
test('saveDraft persists then publishes the new list', () async {
  final repository = ExerciseRepository(
    database: fakeDatabase,
    imageStore: fakeImageStore,
  );
  await repository.initialize();
  await repository.saveDraft(validDraft);
  expect(await repository.recordsStream.first, hasLength(1));
});
```

- [ ] **Step 2: 运行测试并确认失败**

Run: `cd today_eat_app && flutter test test/services/exercise_repository_test.dart`

Expected: FAIL，提示 `ExerciseRepository` 不存在。

- [ ] **Step 3: 实现仓库和可注入网关**

仓库保存顺序固定为：校验草稿 -> 复制图片到应用目录 -> 插入 SQLite -> 刷新流。任一步失败均抛出明确异常；不得调用网络。

```dart
abstract interface class ExerciseImageStore {
  Future<String> copyIntoAppDirectory(String sourcePath);
  Future<void> deleteIfOwned(String path);
}

class ExerciseRepository {
  Stream<List<ExerciseRecord>> get recordsStream => _records.stream;
  Future<void> initialize();
  Future<ExerciseRecord> saveDraft(ExerciseDraft draft);
  Future<void> updateRecord(ExerciseRecord record);
  Future<void> deleteRecord(ExerciseRecord record);
}
```

- [ ] **Step 4: 运行仓库测试**

Run: `cd today_eat_app && flutter test test/services/exercise_repository_test.dart`

Expected: PASS。

- [ ] **Step 5: 提交**

```bash
git add today_eat_app/lib/services/exercise_repository.dart today_eat_app/test/services/exercise_repository_test.dart
git commit -m "feat: add local-first exercise repository"
```

### Task 5: 增加运动截图 AI 识别

**Files:**
- Create: `today_eat_app/lib/models/exercise_analysis.dart`
- Create: `today_eat_app/lib/services/health_agent_service.dart`
- Test: `today_eat_app/test/services/health_agent_service_test.dart`

**Interfaces:**
- Produces: `Future<ExerciseDraft> analyzeExerciseImages(ActivityType type, List<String> paths)`。
- Consumes: `LlmService.callLlmWithImages` 和 `parseLlmJsonObject`。

- [ ] **Step 1: 写失败测试**

fake `LlmService` 返回缺失可选字段的合法 JSON，验证默认值、枚举映射和 warning 保留；再返回峰值心率低于平均心率，验证抛出结构化解析异常。

```dart
test('maps AI output into an editable draft', () async {
  final result = await service.analyzeExerciseImages(
    ActivityType.running,
    const ['run.png'],
  );
  expect(result.source, ExerciseSource.aiImage);
  expect(result.durationSeconds, 1800);
  expect(result.imagePaths, const ['run.png']);
});
```

- [ ] **Step 2: 运行测试并确认失败**

Run: `cd today_eat_app && flutter test test/services/health_agent_service_test.dart`

Expected: FAIL。

- [ ] **Step 3: 实现识别 Prompt 和严格映射**

AI JSON schema 固定为：

```json
{
  "started_at": "2026-07-18T08:00:00+08:00",
  "duration_seconds": 1800,
  "distance_meters": 5000,
  "average_heart_rate_bpm": 150,
  "peak_heart_rate_bpm": 175,
  "calories_kcal": 320,
  "rpe": null,
  "detail": {},
  "confidence": 0.9,
  "warnings": []
}
```

禁止模型补造截图中不存在的数值；无法识别的字段必须返回 `null`。`duration_seconds` 缺失时返回可编辑空草稿并带 warning，不自动填固定时长。

- [ ] **Step 4: 运行 Agent 测试**

Run: `cd today_eat_app && flutter test test/services/health_agent_service_test.dart`

Expected: PASS。

- [ ] **Step 5: 提交**

```bash
git add today_eat_app/lib/models/exercise_analysis.dart today_eat_app/lib/services/health_agent_service.dart today_eat_app/test/services/health_agent_service_test.dart
git commit -m "feat: recognize exercise screenshots with ai"
```

### Task 6: 构建运动编辑器

**Files:**
- Create: `today_eat_app/lib/screens/exercise/exercise_editor_screen.dart`
- Create: `today_eat_app/lib/screens/exercise/exercise_field_formatters.dart`
- Test: `today_eat_app/test/screens/exercise_editor_screen_test.dart`

**Interfaces:**
- Consumes: `ExerciseRepository`、`HealthAgentService`、可选 `ExerciseRecord`。
- Produces: 保存成功后 `Navigator.pop(context, true)`。

- [ ] **Step 1: 写 Widget 失败测试**

覆盖手动录入、心率顺序错误、AI 草稿可编辑、AI 失败后字段不清空。

```dart
testWidgets('manual entry saves without AI configuration', (tester) async {
  await tester.pumpWidget(testApp(editor));
  await tester.enterText(find.byKey(const Key('durationMinutes')), '30');
  await tester.tap(find.text('保存运动'));
  await tester.pump();
  expect(fakeRepository.savedDraft.durationSeconds, 1800);
});
```

- [ ] **Step 2: 运行测试并确认失败**

Run: `cd today_eat_app && flutter test test/screens/exercise_editor_screen_test.dart`

Expected: FAIL。

- [ ] **Step 3: 实现表单**

页面包括运动类型、日期时间、时长、距离、心率、热量、RPE、备注、图片选择和 AI 识别按钮。专项字段按运动类型显示；所有数字输入通过纯函数 formatter 转换为模型单位。

保存时先显示字段错误，再调用仓库；AI 识别时禁用重复请求，但不得禁用手动编辑。识别候选使用“已识别”标记，用户修改后标记消失。

- [ ] **Step 4: 运行 Widget 测试**

Run: `cd today_eat_app && flutter test test/screens/exercise_editor_screen_test.dart`

Expected: PASS。

- [ ] **Step 5: 提交**

```bash
git add today_eat_app/lib/screens/exercise/exercise_editor_screen.dart today_eat_app/lib/screens/exercise/exercise_field_formatters.dart today_eat_app/test/screens/exercise_editor_screen_test.dart
git commit -m "feat: add editable exercise capture flow"
```

### Task 7: 增加运动记录列表和临时入口

**Files:**
- Create: `today_eat_app/lib/screens/exercise/exercise_records_screen.dart`
- Create: `today_eat_app/lib/widgets/exercise_record_card.dart`
- Modify: `today_eat_app/lib/screens/insights_screen.dart`
- Modify: `today_eat_app/lib/screens/home_shell.dart`
- Test: `today_eat_app/test/screens/exercise_records_screen_test.dart`

**Interfaces:**
- Consumes: `ExerciseRepository.recordsStream`。
- Produces: 新增、编辑、删除入口；现有洞察页新增“运动记录”卡片。

- [ ] **Step 1: 写列表失败测试**

```dart
testWidgets('lists records newest first and opens editor', (tester) async {
  await tester.pumpWidget(testApp(screen));
  expect(find.text('5.0 km'), findsOneWidget);
  await tester.tap(find.byKey(const Key('addExercise')));
  await tester.pumpAndSettle();
  expect(find.text('新增运动'), findsOneWidget);
});
```

- [ ] **Step 2: 运行测试并确认失败**

Run: `cd today_eat_app && flutter test test/screens/exercise_records_screen_test.dart`

Expected: FAIL。

- [ ] **Step 3: 实现列表并接入依赖**

在 `HomeShell.initState` 创建并初始化一个 `ExerciseRepository`，在 `dispose` 中释放。将它传给 `InsightsScreen`，洞察网格新增运动记录卡片。列表使用现有主题组件，不改底部导航。

- [ ] **Step 4: 运行阶段验证**

Run: `cd today_eat_app && flutter test test/models test/services test/screens/exercise_editor_screen_test.dart test/screens/exercise_records_screen_test.dart`

Run: `cd today_eat_app && flutter analyze`

Expected: 测试 PASS，analyzer 无 error。环境不可用时输出未执行命令清单，不自动配置。

- [ ] **Step 5: 提交**

```bash
git add today_eat_app/lib/screens/exercise today_eat_app/lib/widgets/exercise_record_card.dart today_eat_app/lib/screens/insights_screen.dart today_eat_app/lib/screens/home_shell.dart today_eat_app/test/screens/exercise_records_screen_test.dart
git commit -m "feat: expose exercise recording mvp"
```
