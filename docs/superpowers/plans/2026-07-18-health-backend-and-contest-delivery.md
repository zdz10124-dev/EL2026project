# 健康 AI 服务端与比赛交付 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将运动识别和综合健康分析收敛到现有 FastAPI 服务，默认保护模型密钥，并完成比赛演示、隐私和创新点材料。

**Architecture:** 从单文件 `backend/main.py` 抽取 AI transport、schema 和 route，保留现有 URL 兼容；Flutter 正式模式调用领域化端点，客户端直连保留为明确标注的开发选项。服务端只处理本次请求，不持久化完整健康记录。

**Tech Stack:** FastAPI、Pydantic、httpx、pytest、Flutter http、JWT。

## Global Constraints

- 不安装 Python、Flutter 或测试依赖；不可运行时记录远程环境命令。
- 不引入 CyberCoach Hono 服务为第二正式后端。
- 服务端日志禁止输出 API Key、JWT、base64 图片和完整健康请求。
- 保留 `/v1/ai/chat` 兼容接口，迁移完成前不删除。
- 领域化接口必须 JWT 鉴权、限制图片数和请求大小。

---

### Task 1: 抽取 AI 上游客户端和结构化错误

**Files:**
- Create: `backend/services/ai_client.py`
- Create: `backend/services/__init__.py`
- Create: `backend/models/ai.py`
- Create: `backend/models/__init__.py`
- Modify: `backend/main.py`
- Create: `backend/tests/test_ai_client.py`

**Interfaces:**
- Produces: `AiClient.chat(messages, temperature, response_format) -> dict`。
- Produces: `AiUpstreamError(code, public_message, status_code)`。

- [ ] **Step 1: 写上游失败测试**

```python
@pytest.mark.anyio
async def test_ai_client_maps_timeout_without_leaking_key(httpx_mock):
    httpx_mock.add_exception(httpx.ReadTimeout("slow"))
    client = AiClient(api_key="secret-key", base_url="https://model.test/v1")
    with pytest.raises(AiUpstreamError) as error:
        await client.chat(messages=[], temperature=0.3)
    assert error.value.code == "AI_TIMEOUT"
    assert "secret-key" not in str(error.value)
```

- [ ] **Step 2: 运行并确认失败**

Run: `cd backend && python -m pytest tests/test_ai_client.py -q`

Expected: FAIL，模块不存在。若 pytest/httpx mock 不可用，不执行 pip install，记录依赖和命令。

- [ ] **Step 3: 实现客户端**

```python
class AiUpstreamError(RuntimeError):
    def __init__(self, code: str, public_message: str, status_code: int = 502):
        super().__init__(public_message)
        self.code = code
        self.public_message = public_message
        self.status_code = status_code

class AiClient:
    def __init__(self, api_key: str, base_url: str, model: str = "gpt-4o"):
        self.api_key = api_key
        self.base_url = base_url.rstrip("/")
        self.model = model

    async def chat(
        self,
        messages: list[dict[str, Any]],
        temperature: float = 0.3,
        response_format: dict[str, str] | None = None,
    ) -> dict[str, Any]:
        body: dict[str, Any] = {
            "model": self.model,
            "messages": messages,
            "temperature": temperature,
        }
        if response_format is not None:
            body["response_format"] = response_format
        try:
            async with httpx.AsyncClient(timeout=45.0) as client:
                response = await client.post(
                    f"{self.base_url}/chat/completions",
                    headers={"Authorization": f"Bearer {self.api_key}"},
                    json=body,
                )
        except httpx.TimeoutException as error:
            raise AiUpstreamError("AI_TIMEOUT", "AI 服务响应超时", 504) from error
        except httpx.HTTPError as error:
            raise AiUpstreamError("AI_UNAVAILABLE", "AI 服务暂时不可用") from error
        if not response.is_success:
            raise AiUpstreamError("AI_UPSTREAM_ERROR", "AI 服务返回错误")
        try:
            data = response.json()
        except ValueError as error:
            raise AiUpstreamError("AI_INVALID_JSON", "AI 服务返回格式异常") from error
        if not data.get("choices"):
            raise AiUpstreamError("AI_EMPTY_RESPONSE", "AI 服务未返回内容")
        return data
```

统一处理 timeout、连接失败、非 2xx、空 choices 和非法 JSON。异常仅包含状态码与公共描述。

- [ ] **Step 4: 运行测试并提交**

Run: `cd backend && python -m pytest tests/test_ai_client.py -q`

```bash
git add backend/services backend/models backend/main.py backend/tests/test_ai_client.py
git commit -m "refactor: isolate ai upstream transport"
```

### Task 2: 增加运动图片识别端点

**Files:**
- Create: `backend/routes/ai.py`
- Create: `backend/routes/__init__.py`
- Modify: `backend/models/ai.py`
- Modify: `backend/main.py`
- Create: `backend/tests/test_exercise_recognition_api.py`

**Interfaces:**
- Produces: `POST /v1/ai/exercise-recognition`。
- Request: `activity_type` + 1..4 个 `images` multipart 文件。
- Response: `{success, data: ExerciseRecognitionResult}`。

- [ ] **Step 1: 写接口失败测试**

覆盖无 JWT 为 401、五张图片为 422、非图片为 415、合法上游响应为 200。

```python
def test_exercise_recognition_rejects_more_than_four_images(client, token):
    files = [("images", (f"{i}.jpg", b"image", "image/jpeg")) for i in range(5)]
    response = client.post(
        "/v1/ai/exercise-recognition",
        headers={"Authorization": f"Bearer {token}"},
        data={"activity_type": "running"},
        files=files,
    )
    assert response.status_code == 422
```

- [ ] **Step 2: 运行并确认失败**

Run: `cd backend && python -m pytest tests/test_exercise_recognition_api.py -q`

Expected: FAIL/404。

- [ ] **Step 3: 实现 schema、限制和 route**

允许 `image/jpeg`、`image/png`、`image/webp`，单图上限 5 MiB，总请求图片上限 12 MiB。Prompt 与 Flutter schema 一致，无法识别字段返回 null 和 warning。

- [ ] **Step 4: 运行测试并提交**

Run: `cd backend && python -m pytest tests/test_exercise_recognition_api.py -q`

```bash
git add backend/routes backend/models/ai.py backend/main.py backend/tests/test_exercise_recognition_api.py
git commit -m "feat: proxy exercise image recognition"
```

### Task 3: 增加综合健康分析端点

**Files:**
- Modify: `backend/routes/ai.py`
- Modify: `backend/models/ai.py`
- Create: `backend/tests/test_health_analysis_api.py`

**Interfaces:**
- Produces: `POST /v1/ai/health-analysis`。
- Request: `period`、可选 `profile`、确定性 `metrics`。
- Response: `{success, data: IntegratedHealthAdvice}`。

- [ ] **Step 1: 写接口契约测试**

覆盖非法周期、超长字符串、空 evidence、模型医疗诊断措辞和正常响应。

```python
def test_health_analysis_requires_evidence(client, token, fake_ai):
    fake_ai.response = {
        "overview": "稳定",
        "recommendations": [{
            "category": "rest", "priority": "high",
            "title": "休息", "action": "休息一天", "evidence": []
        }],
        "risk_alerts": [],
    }
    response = client.post("/v1/ai/health-analysis", headers=auth(token), json=valid_payload())
    assert response.status_code == 502
    assert response.json()["detail"]["code"] == "AI_SCHEMA_INVALID"
```

- [ ] **Step 2: 运行并确认失败**

Run: `cd backend && python -m pytest tests/test_health_analysis_api.py -q`

Expected: FAIL/404。

- [ ] **Step 3: 实现 Pydantic schema 和安全校验**

限制 recommendations 最多六条、evidence 每条 1..5 项、文本字段长度。服务端追加免责声明，不信任模型返回的免责声明。发现诊断、处方或治疗断言时拒绝响应并返回 `AI_SCHEMA_INVALID`。

- [ ] **Step 4: 运行测试并提交**

Run: `cd backend && python -m pytest tests/test_health_analysis_api.py -q`

```bash
git add backend/routes/ai.py backend/models/ai.py backend/tests/test_health_analysis_api.py
git commit -m "feat: proxy validated health analysis"
```

### Task 4: Flutter 接入领域化代理端点

**Files:**
- Create: `today_eat_app/lib/services/health_api_service.dart`
- Modify: `today_eat_app/lib/services/health_agent_service.dart`
- Modify: `today_eat_app/lib/services/llm_service.dart`
- Modify: `today_eat_app/lib/screens/settings_screen.dart`
- Test: `today_eat_app/test/services/health_api_service_test.dart`

**Interfaces:**
- Produces: `recognizeExercise`、`analyzeHealth`。
- 服务端模式通过 `HealthApiService`；直连模式继续通过 `LlmService`。

- [ ] **Step 1: 写客户端失败测试**

fake HTTP 验证 JWT header、multipart 图片、UTF-8 解码和结构化错误映射。验证服务端模式不调用客户端 `/chat/completions`。

- [ ] **Step 2: 运行并确认失败**

Run: `cd today_eat_app && flutter test test/services/health_api_service_test.dart`

Expected: FAIL。

- [ ] **Step 3: 实现 API service 和模式路由**

```dart
class HealthApiService {
  Future<Map<String, dynamic>> recognizeExercise({
    required ActivityType activityType,
    required List<String> imagePaths,
  });
  Future<Map<String, dynamic>> analyzeHealth({
    required AnalysisPeriod period,
    required HealthProfile profile,
    required HealthMetrics metrics,
  });
}
```

设置页将“服务端代理”标为推荐，将“客户端直连”放入开发选项并显示密钥存储风险。不删除已有用户配置。

- [ ] **Step 4: 运行测试并提交**

Run: `cd today_eat_app && flutter test test/services/health_api_service_test.dart`

```bash
git add today_eat_app/lib/services/health_api_service.dart today_eat_app/lib/services/health_agent_service.dart today_eat_app/lib/services/llm_service.dart today_eat_app/lib/screens/settings_screen.dart today_eat_app/test/services/health_api_service_test.dart
git commit -m "feat: use domain health ai proxy"
```

### Task 5: 修复本地保存阻塞网络上传

**Files:**
- Modify: `today_eat_app/lib/services/meal_repository.dart`
- Test: `today_eat_app/test/services/meal_repository_save_test.dart`

**Interfaces:**
- `saveRecord` 在 SQLite 和 records stream 更新后立即完成。
- 社区同步通过不阻塞 UI 的受控后台任务执行。

- [ ] **Step 1: 写时序失败测试**

```dart
test('meal save completes before slow recommendation upload', () async {
  final uploadGate = Completer<void>();
  fakeApi.uploadGate = uploadGate;
  await saveExampleMeal(repository)
      .timeout(const Duration(milliseconds: 100));
  expect(await repository.fetchRecords(), hasLength(1));
  uploadGate.complete();
});
```

- [ ] **Step 2: 运行并确认失败**

Run: `cd today_eat_app && flutter test test/services/meal_repository_save_test.dart`

Expected: FAIL/timeout，因为当前保存路径等待 `syncPublicRecords()`。

- [ ] **Step 3: 改为本地优先后台同步**

保存后调用已有 `_syncRecordUploadsInBackground()`，不 await 网络；同步失败写入 upload task 状态并刷新，不撤销本地记录。避免裸 `unawaited`，使用 `dart:async` 的 `unawaited` 并在后台方法内部捕获异常。

- [ ] **Step 4: 运行测试并提交**

Run: `cd today_eat_app && flutter test test/services/meal_repository_save_test.dart`

```bash
git add today_eat_app/lib/services/meal_repository.dart today_eat_app/test/services/meal_repository_save_test.dart
git commit -m "fix: keep meal saves independent from uploads"
```

### Task 6: 增加日志脱敏、限流和回归测试

**Files:**
- Create: `backend/middleware/request_limits.py`
- Create: `backend/services/safe_logging.py`
- Modify: `backend/main.py`
- Modify: `backend/requirements.txt`
- Create: `backend/tests/test_ai_security.py`

**Interfaces:**
- Produces: 每用户/客户端 AI 请求限流和安全日志字段。

- [ ] **Step 1: 写安全失败测试**

捕获日志，断言 API Key、JWT、base64 和完整 prompt 不出现；连续超限请求返回 429 和 `Retry-After`。

- [ ] **Step 2: 运行并确认失败**

Run: `cd backend && python -m pytest tests/test_ai_security.py -q`

Expected: FAIL。

- [ ] **Step 3: 实现限制**

首期使用进程内滑动窗口：每用户每分钟 10 次 AI 请求；生产多实例部署前明确记录需替换共享限流存储。日志只记录 request ID、用户 ID 哈希、端点、耗时、上游状态和错误码。

- [ ] **Step 4: 运行后端回归并提交**

Run: `cd backend && python -m pytest -q`

```bash
git add backend/middleware backend/services/safe_logging.py backend/main.py backend/requirements.txt backend/tests/test_ai_security.py
git commit -m "feat: protect health ai endpoints"
```

### Task 7: 完成比赛演示与交付文档

**Files:**
- Create: `docs/competition/创新点说明.md`
- Create: `docs/competition/演示脚本.md`
- Create: `docs/competition/隐私与AI边界.md`
- Create: `today_eat_app/assets/demo/demo_health_records.json`
- Modify: `today_eat_app/pubspec.yaml`
- Test: `today_eat_app/test/demo/demo_fixture_test.dart`

**Interfaces:**
- 演示数据仅由 debug/test helper 加载，不进入正式用户数据库。

- [ ] **Step 1: 写演示 fixture 失败测试**

验证 fixture 可解析为饮食、运动、健康档案，且不包含姓名、电话、地址、API Key 或 JWT。

- [ ] **Step 2: 运行并确认失败**

Run: `cd today_eat_app && flutter test test/demo/demo_fixture_test.dart`

Expected: FAIL，fixture 不存在。

- [ ] **Step 3: 编写材料和演示数据**

创新点文档围绕三点：跨域健康关联、可解释证据链、本地确定性指标与 AI 分工。演示脚本固定为：导入运动截图 -> 确认记录 -> 查看跨域建议 -> 展开依据 -> 修改记录后展示缓存失效。隐私文档说明本地数据、传输最小化、AI Key 和非医疗边界。

- [ ] **Step 4: 执行全量远程验收**

Run: `cd today_eat_app && flutter test && flutter analyze`

Run: `cd backend && python -m pytest -q`

Run: `cd today_eat_app && flutter build apk --debug`

Expected: 全部 exit 0，APK 可在 Android 真机完成演示脚本。当前设备缺环境时不得自动安装，只将这些命令交给已配置的远程电脑执行。

- [ ] **Step 5: 提交**

```bash
git add docs/competition today_eat_app/assets/demo today_eat_app/pubspec.yaml today_eat_app/test/demo/demo_fixture_test.dart
git commit -m "docs: prepare integrated health contest demo"
```
