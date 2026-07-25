import 'dart:convert';

import '../models/health_metrics.dart';
import '../models/health_profile.dart';
import '../models/integrated_health_analysis.dart';
import 'database_service.dart';
import 'exercise_repository.dart';
import 'health_agent_service.dart';
import 'health_data_fingerprint.dart';
import 'health_metrics_service.dart';
import 'health_profile_repository.dart';
import 'meal_repository.dart';

enum HealthAnalysisStatus {
  insufficientData,
  aiUnavailable,
  fresh,
  cached,
  staleCache,
  failure,
}

class HealthAnalysisState {
  const HealthAnalysisState({
    required this.status,
    required this.metrics,
    this.analysis,
    this.message,
  });
  final HealthAnalysisStatus status;
  final HealthMetrics metrics;
  final IntegratedHealthAnalysis? analysis;
  final String? message;
}

class HealthAnalysisRepository {
  HealthAnalysisRepository({
    required MealRepository mealRepository,
    required ExerciseRepository exerciseRepository,
    required HealthProfileRepository profileRepository,
    required HealthAgentService agentService,
    DatabaseService? databaseService,
    HealthMetricsService? metricsService,
  })  : _meals = mealRepository,
        _exercises = exerciseRepository,
        _profiles = profileRepository,
        _agent = agentService,
        _database = databaseService ?? DatabaseService.instance,
        _metrics = metricsService ?? HealthMetricsService();

  final MealRepository _meals;
  final ExerciseRepository _exercises;
  final HealthProfileRepository _profiles;
  final HealthAgentService _agent;
  final DatabaseService _database;
  final HealthMetricsService _metrics;

  Future<IntegratedHealthAnalysis?> fetchCachedAnalysis(AnalysisPeriod period) async {
    final end = DateTime.now();
    final start = end.subtract(Duration(days: period.days));
    final meals = (await _meals.fetchRecords())
        .where((item) => !item.createdAt.isBefore(start))
        .toList();
    final exercises = (await _exercises.fetchRecords())
        .where((item) => !item.startedAt.isBefore(start))
        .toList();
    final profile = await _profiles.load();
    final fingerprint = buildHealthDataFingerprint(
      period: period,
      meals: meals,
      exercises: exercises,
      profile: profile,
    );
    final cache = await _database.fetchHealthAnalysisCache(period.key);
    if (cache?.dataFingerprint != fingerprint) return null;
    return _decodeCache(cache);
  }

  Future<void> clearCache() => _database.deleteAllHealthAnalysisCache();

  Future<HealthAnalysisState> load(
    AnalysisPeriod period, {
    bool forceRefresh = false,
  }) async {
    final end = DateTime.now();
    final start = end.subtract(Duration(days: period.days));
    final meals = await _meals.fetchRecords();
    final exercises = await _exercises.fetchRecords();
    final profile = await _profiles.load();
    final metrics = _metrics.calculate(
      start: start,
      end: end,
      meals: meals,
      exercises: exercises,
    );
    final fingerprint = buildHealthDataFingerprint(
      period: period,
      meals: meals.where((item) => !item.createdAt.isBefore(start)).toList(),
      exercises:
          exercises.where((item) => !item.startedAt.isBefore(start)).toList(),
      profile: profile,
    );
    final cache = await _database.fetchHealthAnalysisCache(period.key);
    final cachedAnalysis = _decodeCache(cache);
    if (!forceRefresh && cache?.dataFingerprint == fingerprint && cachedAnalysis != null) {
      return HealthAnalysisState(
        status: HealthAnalysisStatus.cached,
        metrics: metrics,
        analysis: cachedAnalysis,
      );
    }
    if (metrics.dataQuality.activeDays < 2) {
      return HealthAnalysisState(
        status: HealthAnalysisStatus.insufficientData,
        metrics: metrics,
        analysis: cachedAnalysis,
        message: '至少记录两天饮食或运动后，才能生成可靠的综合建议。',
      );
    }
    if (!_agent.isAvailable) {
      return HealthAnalysisState(
        status: HealthAnalysisStatus.aiUnavailable,
        metrics: metrics,
        analysis: cachedAnalysis,
        message: '请先在“我的”中配置 AI 模型。',
      );
    }
    try {
      final analysis = await _agent.analyzeIntegratedHealth(
        period: period,
        periodStart: start,
        periodEnd: end,
        dataFingerprint: fingerprint,
        profile: profile,
        metrics: metrics,
      );
      await _database.saveHealthAnalysisCache(HealthAnalysisCache(
        periodKey: period.key,
        dataFingerprint: fingerprint,
        contentJson: jsonEncode(analysis.toJson()),
        generatedAt: analysis.generatedAt,
      ));
      return HealthAnalysisState(
        status: HealthAnalysisStatus.fresh,
        metrics: metrics,
        analysis: analysis,
      );
    } catch (error) {
      return HealthAnalysisState(
        status: cachedAnalysis == null
            ? HealthAnalysisStatus.failure
            : HealthAnalysisStatus.staleCache,
        metrics: metrics,
        analysis: cachedAnalysis,
        message: cachedAnalysis == null
            ? '健康分析失败：$error'
            : '数据已变化，当前展示上次分析。',
      );
    }
  }

  IntegratedHealthAnalysis? _decodeCache(HealthAnalysisCache? cache) {
    if (cache == null) return null;
    try {
      return IntegratedHealthAnalysis.fromJson(
        (jsonDecode(cache.contentJson) as Map).cast<String, dynamic>(),
      );
    } catch (_) {
      return null;
    }
  }
}
