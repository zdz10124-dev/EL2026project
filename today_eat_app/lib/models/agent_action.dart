enum AgentActionCategory { diet, exercise, rest }

enum AgentActionPriority { low, medium, high }

enum AgentActionStatus { pending, completed, skipped, expired }

enum AgentActionTarget {
  recordMeal,
  recordExercise,
  decideMeal,
  recoveryCheckIn,
  openHealth,
  none,
}

enum AgentActionDifficulty { appropriate, tooHard }

enum AgentPlanSource { ai, localFallback }

enum DailyAgentStatus { localFallback, fresh, cached, stale, failure }

class AgentAction {
  const AgentAction({
    required this.clientActionId,
    required this.planDate,
    required this.category,
    required this.priority,
    required this.title,
    required this.action,
    required this.evidence,
    required this.target,
    required this.status,
    required this.validUntil,
    required this.createdAt,
    required this.updatedAt,
    this.id,
    this.difficulty,
    this.feedbackNote,
  });

  final int? id;
  final String clientActionId;
  final String planDate;
  final AgentActionCategory category;
  final AgentActionPriority priority;
  final String title;
  final String action;
  final List<String> evidence;
  final AgentActionTarget target;
  final AgentActionStatus status;
  final AgentActionDifficulty? difficulty;
  final String? feedbackNote;
  final DateTime validUntil;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class DailyAgentPlan {
  const DailyAgentPlan({
    required this.localDate,
    required this.dataFingerprint,
    required this.summary,
    required this.actions,
    required this.generatedAt,
    required this.source,
    required this.needsRefresh,
  });

  final String localDate;
  final String dataFingerprint;
  final String summary;
  final List<AgentAction> actions;
  final DateTime generatedAt;
  final AgentPlanSource source;
  final bool needsRefresh;
}

class DailyAgentState {
  const DailyAgentState({
    required this.status,
    required this.plan,
    this.message,
  });

  final DailyAgentStatus status;
  final DailyAgentPlan? plan;
  final String? message;

  AgentAction? get primaryAction {
    final actions = plan?.actions
            .where((item) => item.status == AgentActionStatus.pending)
            .toList() ??
        const <AgentAction>[];
    return actions.isEmpty ? null : actions.first;
  }
}
