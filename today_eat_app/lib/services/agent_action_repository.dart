import 'dart:convert';

import '../models/agent_action.dart';
import '../models/health_context.dart';
import 'database_service.dart';

class AgentActionRepository {
  AgentActionRepository({AgentActionStore? store})
    : _store = store ?? DatabaseService.instance;

  static const _allowedTransitions = {
    AgentActionStatus.pending: {
      AgentActionStatus.completed,
      AgentActionStatus.skipped,
      AgentActionStatus.expired,
    },
    AgentActionStatus.completed: <AgentActionStatus>{},
    AgentActionStatus.skipped: <AgentActionStatus>{},
    AgentActionStatus.expired: <AgentActionStatus>{},
  };

  final AgentActionStore _store;

  Future<DailyAgentPlan?> findPlan(String localDate) async {
    final map = await _store.fetchDailyAgentPlan(localDate);
    if (map == null) {
      return null;
    }
    final generatedAt = DateTime.parse(map['generated_at'] as String);
    final actions = await _store.fetchAgentActionsForDate(localDate);
    return DailyAgentPlan(
      localDate: localDate,
      dataFingerprint: map['data_fingerprint'] as String,
      summary: map['summary'] as String,
      generatedAt: generatedAt,
      source: AgentPlanSource.values.byName(map['source'] as String),
      needsRefresh: (map['needs_refresh'] as num).toInt() == 1,
      actions: actions
          .map(AgentActionMapper.fromMap)
          .where((action) => !action.createdAt.isBefore(generatedAt))
          .toList(),
    );
  }

  Future<void> replaceCurrentPlan(DailyAgentPlan plan) =>
      _store.replaceDailyAgentPlan(
        {
          'local_date': plan.localDate,
          'data_fingerprint': plan.dataFingerprint,
          'summary': plan.summary,
          'source': plan.source.name,
          'needs_refresh': plan.needsRefresh ? 1 : 0,
          'generated_at': plan.generatedAt.toIso8601String(),
        },
        plan.actions.map(AgentActionMapper.toMap).toList(),
      );

  Future<void> updateAction(
    String clientActionId, {
    required AgentActionStatus status,
    AgentActionDifficulty? difficulty,
    String? feedbackNote,
  }) async {
    final action = await _findAction(clientActionId);
    if (action == null) {
      throw StateError('行动不存在：$clientActionId');
    }
    if (!_allowedTransitions[action.status]!.contains(status)) {
      throw StateError('不允许从 ${action.status.name} 转换为 ${status.name}');
    }
    if (difficulty != null && status != AgentActionStatus.skipped) {
      throw StateError('难度反馈只能用于跳过行动');
    }
    final updated = await _store.updateAgentAction(clientActionId, {
      'status': status.name,
      'difficulty': difficulty?.name,
      'feedback_note': _nullableText(feedbackNote),
      'updated_at': DateTime.now().toIso8601String(),
    });
    if (updated != 1) {
      throw StateError('行动更新失败：$clientActionId');
    }
  }

  Future<AgentFeedbackSummary> summarizeFeedback(DateTime since) async {
    final actions = await fetchActionsSince(since);
    return AgentFeedbackSummary(
      completed: actions
          .where((action) => action.status == AgentActionStatus.completed)
          .length,
      skipped: actions
          .where((action) => action.status == AgentActionStatus.skipped)
          .length,
      tooHard: actions
          .where((action) => action.difficulty == AgentActionDifficulty.tooHard)
          .length,
    );
  }

  Future<List<AgentAction>> fetchActionsSince(DateTime since) async =>
      (await _store.fetchAgentActionsSince(since.toIso8601String()))
          .map(AgentActionMapper.fromMap)
          .toList();

  Future<void> markNeedsRefresh(String localDate) async {
    await _store.markDailyAgentPlanNeedsRefresh(localDate);
  }

  Future<AgentAction?> _findAction(String clientActionId) async {
    final actions = await _store.fetchAgentActionsSince(
      DateTime(2000).toIso8601String(),
    );
    for (final map in actions) {
      if (map['client_action_id'] == clientActionId) {
        return AgentActionMapper.fromMap(map);
      }
    }
    return null;
  }

  String? _nullableText(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}

abstract final class AgentActionMapper {
  static AgentAction fromMap(Map<String, Object?> map) => AgentAction(
    id: (map['id'] as num?)?.toInt(),
    clientActionId: map['client_action_id'] as String,
    planDate: map['plan_date'] as String,
    category: AgentActionCategory.values.byName(map['category'] as String),
    priority: AgentActionPriority.values.byName(map['priority'] as String),
    title: map['title'] as String,
    action: map['action_text'] as String,
    evidence: (jsonDecode(map['evidence_json'] as String) as List<dynamic>)
        .cast<String>(),
    target: AgentActionTarget.values.byName(map['target'] as String),
    status: AgentActionStatus.values.byName(map['status'] as String),
    difficulty: map['difficulty'] == null
        ? null
        : AgentActionDifficulty.values.byName(map['difficulty'] as String),
    feedbackNote: map['feedback_note'] as String?,
    validUntil: DateTime.parse(map['valid_until'] as String),
    createdAt: DateTime.parse(map['created_at'] as String),
    updatedAt: DateTime.parse(map['updated_at'] as String),
  );

  static Map<String, Object?> toMap(AgentAction action) => {
    'id': action.id,
    'client_action_id': action.clientActionId,
    'plan_date': action.planDate,
    'category': action.category.name,
    'priority': action.priority.name,
    'title': action.title,
    'action_text': action.action,
    'evidence_json': jsonEncode(action.evidence),
    'target': action.target.name,
    'status': action.status.name,
    'difficulty': action.difficulty?.name,
    'feedback_note': action.feedbackNote,
    'valid_until': action.validUntil.toIso8601String(),
    'created_at': action.createdAt.toIso8601String(),
    'updated_at': action.updatedAt.toIso8601String(),
  };
}
