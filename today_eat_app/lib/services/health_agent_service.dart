import 'dart:convert';
import 'dart:io';

import '../models/exercise_draft.dart';
import '../models/exercise_record.dart';
import '../models/health_metrics.dart';
import '../models/health_profile.dart';
import '../models/health_context.dart';
import '../models/agent_action.dart';
import '../models/integrated_health_analysis.dart';
import 'health_api_service.dart';
import 'agent_plan_parser.dart';
import 'llm_service.dart';

class HealthAgentService {
  HealthAgentService({
    required LlmService llmService,
    HealthApiService? apiService,
  })  : _llm = llmService,
        _api = apiService ?? HealthApiService(llmService: llmService);

  final LlmService _llm;
  final HealthApiService _api;
  bool get isAvailable => _llm.isConfigured;

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

  Future<ExerciseDraft> analyzeExerciseImages(
    ActivityType activityType,
    List<String> imagePaths,
  ) async {
    if (imagePaths.isEmpty) throw const FormatException('请先选择运动截图');
    final selectedPaths = imagePaths.take(4).toList();
    for (final path in selectedPaths) {
      if (!await File(path).exists()) throw FormatException('图片不存在：$path');
    }
    final Map<String, dynamic> json;
    if (_api.shouldUseServer) {
      json = await _api.recognizeExercise(
        activityType: activityType.name,
        imagePaths: selectedPaths,
      );
    } else {
      final images = <String>[];
      for (final path in selectedPaths) {
        images.add(base64Encode(await File(path).readAsBytes()));
      }
      json = await _llm.callLlmWithImages(
        systemPrompt: _exercisePrompt,
        text: '运动类型为 ${activityType.label}。只提取截图中明确出现的数据，无法确认的字段返回 null。',
        imageBase64List: images,
        temperature: 0.1,
      );
    }
    final startedAt = DateTime.tryParse(json['started_at']?.toString() ?? '');
    final detail = json['detail'];
    final detailValues = detail is Map
        ? detail.map((key, value) => MapEntry(key.toString(), value))
        : <String, Object?>{};
    if (json['confidence'] != null) {
      detailValues['ai_confidence'] = json['confidence'];
    }
    if (json['warnings'] is List) {
      detailValues['ai_warnings'] = json['warnings'];
    }
    return ExerciseDraft(
      activityType: activityType,
      startedAt: startedAt ?? DateTime.now(),
      durationSeconds: _intValue(json['duration_seconds']) ?? 0,
      distanceMeters: _intValue(json['distance_meters']),
      averageHeartRateBpm: _intValue(json['average_heart_rate_bpm']),
      peakHeartRateBpm: _intValue(json['peak_heart_rate_bpm']),
      caloriesKcal: _intValue(json['calories_kcal']),
      rpe: _intValue(json['rpe']),
      detail: detailValues,
      imagePaths: selectedPaths,
      source: ExerciseSource.aiImage,
    );
  }

  Future<IntegratedHealthAnalysis> analyzeIntegratedHealth({
    required AnalysisPeriod period,
    required DateTime periodStart,
    required DateTime periodEnd,
    required String dataFingerprint,
    required HealthProfile profile,
    required HealthMetrics metrics,
  }) async {
    final allowedEvidence = _metricEvidence(metrics);
    final json = _api.shouldUseServer
        ? await _api.analyzeHealth(
            period: period,
            profile: profile,
            metrics: metrics,
            allowedEvidence: allowedEvidence,
          )
        : await _llm.callLlm(
            systemPrompt: _healthPrompt,
            userPrompt: jsonEncode({
              'period': period.key,
              'profile': profile.toJson(),
              'metrics': metrics.toJson(),
              'allowed_evidence': allowedEvidence,
            }),
            temperature: 0.3,
          );
    final recommendations = <HealthRecommendation>[];
    for (final raw in (json['recommendations'] as List? ?? const []).take(6)) {
      if (raw is! Map) continue;
      final item = raw.cast<String, dynamic>();
      final evidence = (item['evidence'] as List? ?? const [])
          .map((value) => value.toString().trim())
          .where(allowedEvidence.contains)
          .take(5)
          .toList();
      final title = item['title']?.toString().trim() ?? '';
      final action = item['action']?.toString().trim() ?? '';
      if (evidence.isEmpty ||
          title.isEmpty ||
          action.isEmpty ||
          _containsMedicalClaim('$title $action')) {
        continue;
      }
      recommendations.add(HealthRecommendation(
        category: _category(item['category']?.toString()),
        priority: _priority(item['priority']?.toString()),
        title: title,
        action: action,
        evidence: evidence,
        validUntil: periodEnd.add(const Duration(days: 1)),
      ));
    }
    recommendations.sort(
      (left, right) => _priorityWeight(right.priority)
          .compareTo(_priorityWeight(left.priority)),
    );
    return IntegratedHealthAnalysis(
      periodStart: periodStart,
      periodEnd: periodEnd,
      generatedAt: DateTime.now(),
      dataFingerprint: dataFingerprint,
      overview: json['overview']?.toString().trim().isNotEmpty == true
          ? json['overview'].toString().trim()
          : '已有数据不足以生成可靠的综合结论。',
      recommendations: recommendations,
      riskAlerts: (json['risk_alerts'] as List? ?? const [])
          .map((value) => value.toString())
          .where((value) => !_containsMedicalClaim(value))
          .take(3)
          .toList(),
      disclaimer: healthDisclaimer,
    );
  }

  int? _intValue(dynamic value) => value is num
      ? value.round()
      : int.tryParse(value?.toString() ?? '');

  RecommendationCategory _category(String? value) =>
      RecommendationCategory.values.firstWhere(
        (item) => item.name == value,
        orElse: () => RecommendationCategory.rest,
      );

  RecommendationPriority _priority(String? value) =>
      RecommendationPriority.values.firstWhere(
        (item) => item.name == value,
        orElse: () => RecommendationPriority.medium,
      );

  int _priorityWeight(RecommendationPriority priority) => switch (priority) {
        RecommendationPriority.low => 1,
        RecommendationPriority.medium => 2,
        RecommendationPriority.high => 3,
      };

  List<String> _metricEvidence(HealthMetrics metrics) => <String>[
        '饮食记录 ${metrics.mealCount} 次',
        '饮食记录覆盖 ${metrics.activeMealDays} 天',
        '运动记录 ${metrics.exerciseCount} 次',
        '运动总时长 ${(metrics.totalExerciseSeconds / 60).round()} 分钟',
        '运动总距离 ${(metrics.totalDistanceMeters / 1000).toStringAsFixed(1)} 公里',
        '有效记录覆盖 ${metrics.dataQuality.activeDays} 天',
        if (metrics.averageRpe != null)
          '平均 RPE ${metrics.averageRpe!.toStringAsFixed(1)}',
        if (metrics.highLoadDays.isNotEmpty)
          '高负荷日期 ${metrics.highLoadDays.join('、')}',
        if (metrics.postWorkoutMealCoverage != null)
          '运动后 4 小时饮食覆盖率 ${(metrics.postWorkoutMealCoverage! * 100).round()}%',
        if (metrics.commonIngredients.isNotEmpty)
          '常见食材 ${metrics.commonIngredients.join('、')}',
        if (metrics.commonDrinks.isNotEmpty)
          '常见饮品 ${metrics.commonDrinks.join('、')}',
      ];

  bool _containsMedicalClaim(String value) {
    const forbidden = ['诊断', '处方', '停药', '用药', '治疗方案', '治愈', '疾病确诊'];
    return forbidden.any(value.contains);
  }
}

const _exercisePrompt = '''你是运动截图结构化识别助手。请用中文理解截图，但只输出 JSON 对象。
禁止根据常识猜测截图中未出现的数值；无法识别的字段必须为 null。
detail 使用运动类型对应键：跑步 average_pace/cadence_spm，游泳 stroke/laps，骑行 average_speed_kmh/elevation_gain_m，步行 steps/average_speed_kmh。
输出格式：
{
  "started_at": "ISO-8601 或 null",
  "duration_seconds": 数字或 null,
  "distance_meters": 数字或 null,
  "average_heart_rate_bpm": 数字或 null,
  "peak_heart_rate_bpm": 数字或 null,
  "calories_kcal": 数字或 null,
  "rpe": 数字或 null,
  "detail": {},
  "confidence": 0.0,
  "warnings": []
}''';

const _healthPrompt = '''你是生活方式健康教练。输入中的 metrics 已由程序计算，请勿重新计算或编造数据。
根据饮食和运动指标给出最多 6 条可执行建议，可分别属于 diet、exercise、rest。
每条建议的 evidence 必须逐字选自 allowed_evidence，不允许改写或新增依据。数据不足时明确说明限制。
禁止疾病诊断、处方、治疗建议、精确热量缺口和缺少依据的最大心率百分比。
只输出 JSON：
{
  "overview": "总体概览",
  "recommendations": [{
    "category": "diet|exercise|rest",
    "priority": "low|medium|high",
    "title": "标题",
    "action": "具体行动",
    "evidence": ["指标依据"]
  }],
  "risk_alerts": ["保守风险提示"]
}''';

const _dailyAgentPrompt = '''你是个人健康 Agent 的行动规划器。输入数据已由程序在本地计算，
只能根据 allowed_evidence 逐字引用依据。只输出 JSON 对象，包含 summary 和 actions。
actions 最多三条；每条必须包含 category(diet|exercise|rest)、priority(low|medium|high)、
title、action、evidence 和 target(recordMeal|recordExercise|decideMeal|recoveryCheckIn|openHealth|none)。
禁止疾病诊断、处方、治疗、药物或精确热量结论。''';
