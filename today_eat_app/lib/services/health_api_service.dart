import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/health_metrics.dart';
import '../models/health_profile.dart';
import '../models/health_context.dart';
import '../models/integrated_health_analysis.dart';
import 'llm_service.dart';

class HealthApiService {
  HealthApiService({required LlmService llmService}) : _llm = llmService;

  final LlmService _llm;

  bool get shouldUseServer => _llm.config?.mode == LlmMode.server;

  Future<Map<String, dynamic>> recognizeExercise({
    required String activityType,
    required List<String> imagePaths,
  }) async {
    final config = _serverConfig();
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${config.serverUrl}/v1/ai/exercise-recognition'),
    )
      ..headers['Authorization'] = 'Bearer ${config.authToken}'
      ..fields['activity_type'] = activityType;
    for (final path in imagePaths.take(4)) {
      request.files.add(await http.MultipartFile.fromPath('images', path));
    }
    final streamed = await request.send().timeout(const Duration(seconds: 120));
    final response = await http.Response.fromStream(streamed);
    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> analyzeHealth({
    required AnalysisPeriod period,
    required HealthProfile profile,
    required HealthMetrics metrics,
    required List<String> allowedEvidence,
  }) async {
    final config = _serverConfig();
    final response = await http.post(
      Uri.parse('${config.serverUrl}/v1/ai/health-analysis'),
      headers: {
        'Authorization': 'Bearer ${config.authToken}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'period': period.key,
        'profile': profile.toJson(),
        'metrics': metrics.toJson(),
        'allowed_evidence': allowedEvidence,
      }),
    ).timeout(const Duration(seconds: 120));
    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> generateDailyPlan({
    required HealthContext context,
  }) async {
    final config = _serverConfig();
    final response = await http.post(
      Uri.parse('${config.serverUrl}/v1/ai/daily-plan'),
      headers: {
        'Authorization': 'Bearer ${config.authToken}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(buildDailyPlanPayload(context)),
    ).timeout(const Duration(seconds: 120));
    return _decodeResponse(response);
  }

  LlmConfig _serverConfig() {
    final config = _llm.config;
    if (config == null ||
        config.mode != LlmMode.server ||
        config.serverUrl == null ||
        config.serverUrl!.isEmpty ||
        config.authToken == null ||
        config.authToken!.isEmpty) {
      throw StateError('当前未配置服务端 AI 模式');
    }
    return config;
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = decoded is Map ? decoded['detail'] : null;
      throw StateError(detail?.toString() ?? 'AI 服务请求失败 (${response.statusCode})');
    }
    if (decoded is! Map || decoded['data'] is! Map) {
      throw const FormatException('AI 服务返回格式错误');
    }
    return (decoded['data'] as Map).cast<String, dynamic>();
  }
}

Map<String, Object?> buildDailyPlanPayload(HealthContext context) => {
  'context': context.toPromptJson(),
  'allowed_evidence': context.allowedEvidence,
};
