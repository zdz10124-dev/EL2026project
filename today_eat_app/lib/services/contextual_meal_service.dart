import '../models/agent_action.dart';
import '../models/contextual_meal_suggestion.dart';
import '../models/health_context.dart';
import '../models/meal_record.dart';

class ContextualMealService {
  Future<ContextualMealSuggestion> suggest(
    HealthContext context,
    List<MealRecord> records,
  ) async {
    final highFatigue = context.recovery?.fatigue != null &&
        context.recovery!.fatigue >= 4;
    final title = highFatigue
        ? '一餐温和的蛋白质与蔬菜组合'
        : '一餐包含蛋白质、蔬菜和主食的组合';
    final evidence = context.allowedEvidence.take(2).toList();
    return ContextualMealSuggestion(
      title: title,
      reason: highFatigue
          ? '今天主观疲劳较高，优先选择规律、易准备的组合，并根据恢复状态调整运动强度。'
          : '先用均衡组合补全今天的饮食记录，再结合运动与恢复状态调整。',
      evidence: evidence,
      source: AgentPlanSource.localFallback,
      sourceRecord: records.isEmpty ? null : records.first,
    );
  }
}
