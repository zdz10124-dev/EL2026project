import '../models/agent_action.dart';
import '../models/health_context.dart';
import '../models/recovery_check_in.dart';
import 'agent_action_repository.dart';
import 'daily_agent_fingerprint.dart';
import 'exercise_repository.dart';
import 'health_agent_service.dart';
import 'health_context_service.dart';
import 'health_profile_repository.dart';
import 'meal_repository.dart';
import 'recovery_repository.dart';

class DailyAgentRepository {
  DailyAgentRepository({
    required MealRepository mealRepository,
    required ExerciseRepository exerciseRepository,
    required RecoveryRepository recoveryRepository,
    required HealthProfileRepository profileRepository,
    required AgentActionRepository actionRepository,
    required HealthContextService contextService,
    required HealthAgentService agentService,
    DateTime Function()? clock,
  }) : _meals = mealRepository,
       _exercises = exerciseRepository,
       _recovery = recoveryRepository,
       _profiles = profileRepository,
       _actions = actionRepository,
       _contexts = contextService,
       _agent = agentService,
       _clock = clock ?? DateTime.now;

  final MealRepository _meals;
  final ExerciseRepository _exercises;
  final RecoveryRepository _recovery;
  final HealthProfileRepository _profiles;
  final AgentActionRepository _actions;
  final HealthContextService _contexts;
  final HealthAgentService _agent;
  final DateTime Function() _clock;

  Future<DailyAgentState> load(
    DateTime date, {
    bool forceRefresh = false,
  }) async {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final profile = await _profiles.load();
    final meals = await _meals.fetchRecords();
    final exercises = await _exercises.fetchRecords();
    final recovery = await _recovery.findByDate(normalizedDate);
    final feedback = await _actions.summarizeFeedback(
      normalizedDate.subtract(const Duration(days: 7)),
    );
    final context = _contexts.build(
      now: normalizedDate,
      profile: profile,
      meals: meals,
      exercises: exercises,
      recovery: recovery,
      feedback: feedback,
    );
    final fingerprint = buildDailyAgentFingerprint(context);
    final cached = await _actions.findPlan(recoveryDateKey(normalizedDate));
    if (!forceRefresh &&
        cached != null &&
        cached.dataFingerprint == fingerprint &&
        !cached.needsRefresh) {
      return DailyAgentState(status: DailyAgentStatus.cached, plan: cached);
    }
    if (!context.canGenerateAiPlan || !_agent.isAvailable) {
      return DailyAgentState(
        status: DailyAgentStatus.localFallback,
        plan: _localPlan(context, fingerprint),
        message: context.canGenerateAiPlan ? 'AI 暂不可用，已提供本地行动。' : '补全恢复或近期记录后，可生成更贴合的行动。',
      );
    }
    try {
      final plan = await _agent.generateDailyPlan(
        context: context,
        dataFingerprint: fingerprint,
      );
      await _actions.replaceCurrentPlan(plan);
      return DailyAgentState(status: DailyAgentStatus.fresh, plan: plan);
    } catch (_) {
      if (cached != null) {
        return DailyAgentState(
          status: DailyAgentStatus.stale,
          plan: cached,
          message: '数据已变化，当前展示上次计划。',
        );
      }
      return DailyAgentState(
        status: DailyAgentStatus.failure,
        plan: _localPlan(context, fingerprint),
        message: '暂时无法生成 AI 计划，已提供本地行动。',
      );
    }
  }

  Future<void> completeAction(String clientActionId) => _actions.updateAction(
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

  Future<void> markNeedsRefresh(DateTime date) =>
      _actions.markNeedsRefresh(recoveryDateKey(date));

  DailyAgentPlan _localPlan(HealthContext context, String fingerprint) {
    final now = _clock();
    final action = context.recovery == null
        ? _action(
            context: context,
            fingerprint: fingerprint,
            category: AgentActionCategory.rest,
            title: '先完成恢复打卡',
            text: '记录睡眠、疲劳、酸痛和精力，让今天的建议更贴近你的状态。',
            evidence: const ['今日尚未完成恢复打卡'],
            target: AgentActionTarget.recoveryCheckIn,
            now: now,
          )
        : _action(
            context: context,
            fingerprint: fingerprint,
            category: AgentActionCategory.diet,
            title: context.todayMealCount == 0 ? '记录今天的第一餐' : '查看今天的健康分析',
            text: context.todayMealCount == 0
                ? '先记录一餐，为饮食与运动的关联分析补充依据。'
                : '查看已计算的饮食、运动与恢复趋势。',
            evidence: context.todayMealCount == 0
                ? const ['今日尚未记录饮食']
                : context.allowedEvidence.take(1).toList(),
            target: context.todayMealCount == 0
                ? AgentActionTarget.recordMeal
                : AgentActionTarget.openHealth,
            now: now,
          );
    return DailyAgentPlan(
      localDate: recoveryDateKey(context.date),
      dataFingerprint: fingerprint,
      summary: '先完成一项能补全健康状态的行动。',
      actions: [action],
      generatedAt: now,
      source: AgentPlanSource.localFallback,
      needsRefresh: false,
    );
  }

  AgentAction _action({
    required HealthContext context,
    required String fingerprint,
    required AgentActionCategory category,
    required String title,
    required String text,
    required List<String> evidence,
    required AgentActionTarget target,
    required DateTime now,
  }) => AgentAction(
    clientActionId: 'local_${fingerprint.substring(0, 12)}_${target.name}',
    planDate: recoveryDateKey(context.date),
    category: category,
    priority: AgentActionPriority.high,
    title: title,
    action: text,
    evidence: evidence,
    target: target,
    status: AgentActionStatus.pending,
    validUntil: context.date.add(const Duration(days: 1)),
    createdAt: now,
    updatedAt: now,
  );
}
