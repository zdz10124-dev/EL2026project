import 'package:flutter_test/flutter_test.dart';

import 'package:today_eat_app/models/agent_action.dart';
import 'package:today_eat_app/services/agent_action_repository.dart';

void main() {
  late _FakeAgentActionStore store;
  late AgentActionRepository repository;

  setUp(() {
    store = _FakeAgentActionStore();
    repository = AgentActionRepository(store: store);
  });

  test('replacing a plan preserves completed actions as history', () async {
    final firstPlan = _plan(
      generatedAt: DateTime(2026, 7, 25, 8),
      actionId: 'first-action',
    );
    final secondPlan = _plan(
      generatedAt: DateTime(2026, 7, 25, 12),
      actionId: 'second-action',
    );

    await repository.replaceCurrentPlan(firstPlan);
    await repository.updateAction(
      'first-action',
      status: AgentActionStatus.completed,
    );
    await repository.replaceCurrentPlan(secondPlan);

    final history = await repository.fetchActionsSince(DateTime(2026, 7, 25));
    final currentPlan = await repository.findPlan('2026-07-25');

    expect(
      history.where((item) => item.status == AgentActionStatus.completed),
      hasLength(1),
    );
    expect(currentPlan!.actions.single.clientActionId, 'second-action');
  });

  test('too hard feedback increments skipped and too hard counts', () async {
    final plan = _plan(
      generatedAt: DateTime(2026, 7, 25, 8),
      actionId: 'first-action',
    );
    await repository.replaceCurrentPlan(plan);
    await repository.updateAction(
      'first-action',
      status: AgentActionStatus.skipped,
      difficulty: AgentActionDifficulty.tooHard,
    );

    final summary = await repository.summarizeFeedback(DateTime(2026, 7, 19));

    expect(summary.skipped, 1);
    expect(summary.tooHard, 1);
  });
}

DailyAgentPlan _plan({
  required DateTime generatedAt,
  required String actionId,
}) => DailyAgentPlan(
  localDate: '2026-07-25',
  dataFingerprint: 'fingerprint-$actionId',
  summary: '今日优先完成一项健康行动。',
  generatedAt: generatedAt,
  source: AgentPlanSource.localFallback,
  needsRefresh: false,
  actions: [
    AgentAction(
      clientActionId: actionId,
      planDate: '2026-07-25',
      category: AgentActionCategory.rest,
      priority: AgentActionPriority.high,
      title: '完成恢复打卡',
      action: '记录睡眠、疲劳、酸痛和精力。',
      evidence: const ['今日尚未完成恢复打卡'],
      target: AgentActionTarget.recoveryCheckIn,
      status: AgentActionStatus.pending,
      validUntil: DateTime(2026, 7, 26),
      createdAt: generatedAt,
      updatedAt: generatedAt,
    ),
  ],
);

class _FakeAgentActionStore implements AgentActionStore {
  final Map<String, Map<String, Object?>> plans = {};
  final Map<String, Map<String, Object?>> actions = {};

  @override
  Future<List<Map<String, Object?>>> fetchAgentActionsForDate(
    String localDate,
  ) async => actions.values
      .where((item) => item['plan_date'] == localDate)
      .map(Map<String, Object?>.from)
      .toList();

  @override
  Future<List<Map<String, Object?>>> fetchAgentActionsSince(
    String isoDateTime,
  ) async => actions.values
      .where((item) => (item['updated_at'] as String).compareTo(isoDateTime) >= 0)
      .map(Map<String, Object?>.from)
      .toList();

  @override
  Future<Map<String, Object?>?> fetchDailyAgentPlan(String localDate) async =>
      plans[localDate] == null ? null : Map<String, Object?>.from(plans[localDate]!);

  @override
  Future<int> markDailyAgentPlanNeedsRefresh(String localDate) async {
    final plan = plans[localDate];
    if (plan == null) return 0;
    plan['needs_refresh'] = 1;
    return 1;
  }

  @override
  Future<void> replaceDailyAgentPlan(
    Map<String, Object?> plan,
    List<Map<String, Object?>> newActions,
  ) async {
    for (final action in actions.values) {
      if (action['plan_date'] == plan['local_date'] && action['status'] == 'pending') {
        action['status'] = 'expired';
      }
    }
    plans[plan['local_date']! as String] = Map<String, Object?>.from(plan);
    for (final action in newActions) {
      actions[action['client_action_id']! as String] = Map<String, Object?>.from(action);
    }
  }

  @override
  Future<int> updateAgentAction(
    String clientActionId,
    Map<String, Object?> values,
  ) async {
    final action = actions[clientActionId];
    if (action == null) return 0;
    action.addAll(values);
    return 1;
  }
}
